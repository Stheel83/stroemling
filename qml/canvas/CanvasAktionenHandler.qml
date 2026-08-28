import QtQuick

// Aktionslogik des SchaltplanCanvas: Undo/Redo, Clipboard, Ausrichten,
// Rotation, Format-Pinsel, Gruppen, Eigenschaften.
// cv: Referenz auf SchaltplanCanvas (root). IDs drawCanvas/_duplizierDialog
// werden über property aliases am Canvas exponiert.
QtObject {
    id: handler
    required property var cv

    // CE-11: Batch-Nummerierung – setzt BMKs auf ausgewählte Symbole in Links→Rechts-Reihenfolge
    function batchBmkNummerieren(praefix, startNr) {
        var symbole = []
        for (var i = 0; i < cv.auswahl.length; i++) {
            var el = cv.elementeModel.element(cv.auswahl[i])
            if (el && el.typ === "symbol")
                symbole.push({ idx: cv.auswahl[i], x: el.x1, y: el.y1 })
        }
        if (symbole.length === 0) return
        symbole.sort(function(a, b) { return a.x !== b.x ? a.x - b.x : a.y - b.y })

        cv.elementeModel.undoCheckpoint()
        var selSnapshot = cv.auswahl.slice()
        var num = startNr
        symbole.forEach(function(s) {
            var cur = cv.elementeModel.element(s.idx)
            var ed  = cur.extraDaten ? JSON.parse(JSON.stringify(cur.extraDaten)) : {}
            ed.bmk  = praefix + num++
            cv.elementeModel.eigenschaftSetzen(s.idx, "extraDaten", ed)
        })
        cv.auswahl = selSnapshot
        cv.grafikSpeichernJetzt()
        cv.neuZeichnen()
    }

    // CE-06: Ausrichten & Verteilen
    // richtung: "links"|"rechts"|"oben"|"unten"|"mitte_h"|"mitte_v"|"verteilen_h"|"verteilen_v"
    function elementeAufRasterSnappen() {
        if (cv.auswahl.length === 0) return
        var selSnapshot = cv.auswahl.slice()
        for (var i = 0; i < selSnapshot.length; i++) {
            var idx = selSnapshot[i]
            var el  = cv.elementeModel.element(idx)
            if (!el) continue
            var g   = cv.gridPx
            var w   = el.x2 - el.x1
            var h   = el.y2 - el.y1
            var rx1, ry1
            if (el.typ === "symbol") {
                // Anker-Pin einrasten statt x1/y1 (SYMBOL-ANKER-01) — sonst
                // "snappt" diese Funktion die Bbox-Ecke, während der Pin bei
                // ungeraden Rastereinheiten weiterhin daneben liegt.
                var off = cv.ankerOffsetFuerElement(el)
                var ax  = Math.round((el.x1 + off.x) / g) * g
                var ay  = Math.round((el.y1 + off.y) / g) * g
                rx1 = ax - off.x; ry1 = ay - off.y
            } else {
                rx1 = Math.round(el.x1 / g) * g
                ry1 = Math.round(el.y1 / g) * g
            }
            if (rx1 !== el.x1 || ry1 !== el.y1)
                cv.elementeModel.elementAktualisieren(idx, { x1: rx1, y1: ry1, x2: rx1 + w, y2: ry1 + h })
        }
        cv.auswahl = selSnapshot
        cv.grafikSpeichernJetzt()
    }

    function elementeAusrichten(richtung) {
        if (cv.auswahl.length < 2) return
        var verteilen = (richtung === "verteilen_h" || richtung === "verteilen_v")
        if (verteilen && cv.auswahl.length < 3) return

        var els = cv.auswahl.map(function(idx) {
            var el = cv.elementeModel.element(idx)
            return { idx: idx, x1: el.x1, y1: el.y1, x2: el.x2, y2: el.y2 }
        })
        var minX1 = els[0].x1, maxX2 = els[0].x2
        var minY1 = els[0].y1, maxY2 = els[0].y2
        for (var i = 1; i < els.length; i++) {
            if (els[i].x1 < minX1) minX1 = els[i].x1
            if (els[i].x2 > maxX2) maxX2 = els[i].x2
            if (els[i].y1 < minY1) minY1 = els[i].y1
            if (els[i].y2 > maxY2) maxY2 = els[i].y2
        }
        var centerX = (minX1 + maxX2) / 2
        var centerY = (minY1 + maxY2) / 2

        cv.elementeModel.undoCheckpoint()
        var selSnapshot = cv.auswahl.slice()

        if (verteilen) {
            var sorted, firstC, lastC, vstep, n, j, ev, vw, vh, newV1
            n = els.length
            if (richtung === "verteilen_h") {
                sorted = els.slice().sort(function(a, b) { return (a.x1 + a.x2) - (b.x1 + b.x2) })
                firstC = (sorted[0].x1   + sorted[0].x2)   / 2
                lastC  = (sorted[n-1].x1 + sorted[n-1].x2) / 2
                vstep  = (lastC - firstC) / (n - 1)
                for (j = 1; j < n - 1; j++) {
                    ev = sorted[j]; vw = ev.x2 - ev.x1
                    newV1 = firstC + j * vstep - vw / 2
                    cv.elementeModel.elementAktualisieren(ev.idx, { x1: newV1, y1: ev.y1, x2: newV1 + vw, y2: ev.y2 })
                }
            } else {
                sorted = els.slice().sort(function(a, b) { return (a.y1 + a.y2) - (b.y1 + b.y2) })
                firstC = (sorted[0].y1   + sorted[0].y2)   / 2
                lastC  = (sorted[n-1].y1 + sorted[n-1].y2) / 2
                vstep  = (lastC - firstC) / (n - 1)
                for (j = 1; j < n - 1; j++) {
                    ev = sorted[j]; vh = ev.y2 - ev.y1
                    newV1 = firstC + j * vstep - vh / 2
                    cv.elementeModel.elementAktualisieren(ev.idx, { x1: ev.x1, y1: newV1, x2: ev.x2, y2: newV1 + vh })
                }
            }
        } else {
            for (var m = 0; m < els.length; m++) {
                var em = els[m]
                var ew = em.x2 - em.x1, eh = em.y2 - em.y1
                var nx1 = em.x1, ny1 = em.y1
                if      (richtung === "links")   nx1 = minX1
                else if (richtung === "rechts")  nx1 = maxX2 - ew
                else if (richtung === "mitte_h") nx1 = centerX - ew / 2
                if      (richtung === "oben")    ny1 = minY1
                else if (richtung === "unten")   ny1 = maxY2 - eh
                else if (richtung === "mitte_v") ny1 = centerY - eh / 2
                cv.elementeModel.elementAktualisieren(em.idx, { x1: nx1, y1: ny1, x2: nx1 + ew, y2: ny1 + eh })
            }
        }

        cv.auswahl = selSnapshot
        cv.grafikSpeichernJetzt()
        cv.neuZeichnen()
    }

    function aktionAusfuehren(neueElemente) {
        cv.elementeModel.undoCheckpoint()
        cv.elementeModel.fromVariantList(neueElemente)
        cv.auswahl = []
        cv.grafikSpeichernJetzt()
    }

    function eigenschaftAktualisieren(key, value) {
        if (cv.auswahl.length === 0) return
        var selSnapshot = cv.auswahl.slice()
        cv.elementeModel.undoCheckpoint()

        cv.auswahl.forEach(function(i) {
            var el = cv.elementeModel.element(i)
            // Winkel: bei Rotationsänderung Bbox verschieben damit die grafische Ecke ortsfest bleibt
            if (key === "rotation" && el.symbolId === "winkel") {
                var g    = cv.gridPx
                var cxEl = (el.x1 + el.x2) / 2, cyEl = (el.y1 + el.y2) / 2
                var cox  = -g / 2, coy = g / 2
                var oldRad   = (el.rotation || 0) * Math.PI / 180
                var cornerWx = cxEl + cox * Math.cos(oldRad) - coy * Math.sin(oldRad)
                var cornerWy = cyEl + cox * Math.sin(oldRad) + coy * Math.cos(oldRad)
                var newRad   = value * Math.PI / 180
                var newCx    = cornerWx - (cox * Math.cos(newRad) - coy * Math.sin(newRad))
                var newCy    = cornerWy - (cox * Math.sin(newRad) + coy * Math.cos(newRad))
                cv.elementeModel.elementAktualisieren(i, {
                    rotation: value,
                    x1: newCx - g / 2, y1: newCy - g / 2,
                    x2: newCx + g / 2, y2: newCy + g / 2
                })
            } else if (key === "rotation" && el.typ === "symbol") {
                // SYMBOL-ANKER-ROTATION-01 (Aug 2026): Rotation läuft im Renderer
                // um den Bbox-Mittelpunkt, nicht um den Anker-Pin — dessen Versatz
                // vom Mittelpunkt ist aber nicht zwingend ein Vielfaches von 4mm
                // (z.B. schliesser: Anker-Pin am Rand, halbe Höhe 6mm). Ohne
                // Korrektur fiele der Anker-Pin bei jeder 90°-Drehung vom Raster.
                // Analog zum winkel-Sonderfall oben: Bbox so verschieben, dass der
                // Anker-Pin exakt an seiner alten Weltposition stehen bleibt (nicht
                // nur nachträglich aufs Raster runden — bleibt exakt, da er vorher
                // schon dort stand, siehe SYMBOL-ANKER-01 Platzieren/Verschieben).
                var w2  = el.x2 - el.x1, h2 = el.y2 - el.y1
                var cx2 = el.x1 + w2 / 2, cy2 = el.y1 + h2 / 2
                var ap2 = cv.geometrie.ankerPinFuerSymbolId(el.symbolId)
                var ox2 = (ap2.x - 0.5) * w2, oy2 = (ap2.y - 0.5) * h2
                var oldRad2 = (el.rotation || 0) * Math.PI / 180
                var ankerWx = cx2 + ox2 * Math.cos(oldRad2) - oy2 * Math.sin(oldRad2)
                var ankerWy = cy2 + ox2 * Math.sin(oldRad2) + oy2 * Math.cos(oldRad2)
                var newRad2 = value * Math.PI / 180
                var newCx2  = ankerWx - (ox2 * Math.cos(newRad2) - oy2 * Math.sin(newRad2))
                var newCy2  = ankerWy - (ox2 * Math.sin(newRad2) + oy2 * Math.cos(newRad2))
                cv.elementeModel.elementAktualisieren(i, {
                    rotation: value,
                    x1: newCx2 - w2 / 2, y1: newCy2 - h2 / 2,
                    x2: newCx2 + w2 / 2, y2: newCy2 + h2 / 2
                })
            } else {
                cv.elementeModel.eigenschaftSetzen(i, key, value)
            }
        })

        // FOKUS-AUSWAHL-REASSIGN-01: nur neu zuweisen wenn sich die Auswahl während der
        // Schleife tatsächlich geändert hat. Eine Reassignment mit identischem Inhalt
        // feuert trotzdem onAuswahlChanged (neue Array-Referenz) – und SchaltplanCanvas.qml
        // holt sich dort per Qt.callLater(canvas.forceActiveFocus()) den Tastaturfokus vom
        // Canvas zurück (gedacht gegen das EP-ScrollView, das beim Erscheinen synchron
        // fokussiert). Bei jedem eigenschaftAktualisieren()-Aufruf (z.B. debounced Commit
        // eines EP-Zahlenfelds) riss das so dem gerade editierten Feld mitten in der
        // Eingabe den Fokus weg – die nächste Backspace-Taste landete dann beim globalen
        // Lösch-Shortcut statt im Textfeld (BILD-WINKEL-AUSWAHL-FOKUS-01).
        if (JSON.stringify(cv.auswahl) !== JSON.stringify(selSnapshot)) cv.auswahl = selSnapshot
        cv.grafikSpeichernJetzt()

        // Stilvorlagen nur bei Einzelauswahl übernehmen
        if (cv.auswahl.length === 1) {
            var stilKeys = ["strichFarbe","strichBreite","strichArt","fuell",
                            "fuellFarbe","fuellOpazitaet","opazitaet","eckenRadius"]
            if (stilKeys.indexOf(key) >= 0) {
                var vl = {}; for (var sk in cv.stilVorlage) vl[sk] = cv.stilVorlage[sk]
                vl[key] = value; cv.stilVorlage = vl
            }
            // Schriftgröße liegt in extraDaten (eigenständig von strichBreite/Strichstärke,
            // siehe SCHRIFT-STRICH-01) — separat in die Stilvorlage übernehmen
            if (key === "extraDaten" && value && value.schriftgroesse !== undefined) {
                var vl2 = {}; for (var sk2 in cv.stilVorlage) vl2[sk2] = cv.stilVorlage[sk2]
                vl2.schriftgroesse = value.schriftgroesse; cv.stilVorlage = vl2
            }
        }
        // Kabel-DB-Metadaten aktualisieren wenn Kabellinie-extraDaten geändert wurden
        if (key === "extraDaten" && cv.auswahl.length === 1) {
            var klIdx = cv.auswahl[0]
            var klEl  = cv.elementeModel.element(klIdx)
            if (klEl && klEl.typ === "kabellinie") {
                var ed2 = value
                var kabelId = ed2.kabelId || (klEl.extraDaten && klEl.extraDaten.kabelId) || 0
                if (kabelId > 0) {
                    db.kabelMetaAktualisieren(kabelId,
                                    ed2.bezeichnung    || "",
                                    ed2.kabeltyp       || "",
                                    ed2.aderzahl       || 0,
                                    ed2.querschnittMm2 || 0.0)
                }
            }
        }
        cv._drawCanvas.requestPaint()
    }

    // Schirm-Symbol um 90° (im Uhrzeigersinn) drehen: Kapselform hat kein
    // eigenes rotation-Feld — Breite/Höhe der Bbox um den Mittelpunkt tauschen
    // (exakt äquivalent zu einer echten 90°-Drehung eines achsenparallelen
    // Rechtecks) + Anschluss-Seite zyklisch weiterschalten.
    function schirmDrehen() {
        if (cv.auswahl.length === 0) return
        var seiteNachCW = { links: "oben", oben: "rechts", rechts: "unten", unten: "links" }
        cv.elementeModel.undoCheckpoint()
        cv.auswahl.forEach(function(i) {
            var el = cv.elementeModel.element(i)
            if (!el || el.typ !== "schirm") return
            var cx = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
            var hw = Math.abs(el.x2 - el.x1) / 2, hh = Math.abs(el.y2 - el.y1) / 2
            var ed = el.extraDaten ? JSON.parse(JSON.stringify(el.extraDaten)) : {}
            ed.anschlussSeite = seiteNachCW[ed.anschlussSeite || "links"] || "links"
            cv.elementeModel.elementAktualisieren(i, {
                x1: cx - hh, x2: cx + hh, y1: cy - hw, y2: cy + hw,
                extraDaten: ed
            })
        })
        cv.grafikSpeichernJetzt()
        cv._drawCanvas.requestPaint()
    }

    // Viewport-Hit-Test auf BMK-Beschriftung eines Symbols.
    // Gibt Element-Index zurück oder -1 wenn kein Label getroffen.
    function labelTreffenTest(vpX, vpY) {
        var n = cv.elementeModel.anzahl
        var pad = 8

        // Durchlauf 1: Kastenbeschriftungen haben Vorrang vor Symbolbeschriftungen
        // (Symbole im Kasten haben höhere Indizes und würden sonst fälschlich treffen)
        for (var bi = n - 1; bi >= 0; bi--) {
            var bel = cv.elementeModel.element(bi)
            if (bel.typ !== "geraetekasten" && bel.typ !== "strukturkasten" && bel.typ !== "makrokasten") continue
            var bed  = bel.extraDaten || {}
            var bvx1 = bel.x1 * cv.zoom + cv.worldX, bvy1 = bel.y1 * cv.zoom + cv.worldY
            var bvx2 = bel.x2 * cv.zoom + cv.worldX, bvy2 = bel.y2 * cv.zoom + cv.worldY
            var bRx  = Math.min(bvx1, bvx2), bRy = Math.min(bvy1, bvy2)
            var bOx  = (bed.bmkOffsetX !== undefined ? bed.bmkOffsetX : 0) * cv.zoom
            var bOy  = (bed.bmkOffsetY !== undefined ? bed.bmkOffsetY : 0) * cv.zoom
            var bPad = Math.round(5 * cv.zoom)
            var bSch = bed.schriftgroesse !== undefined ? bed.schriftgroesse : 2.5
            var bFs  = Math.max(5, Math.round(bSch * cv.mmToPx * cv.zoom))
            var bTx  = bRx + bPad + bOx
            var bTy  = bRy + bPad + bOy
            var bhx1, bhy1, bhx2, bhy2
            if (bel.typ === "geraetekasten") {
                var gkBmkH = bed.bmk || "", gkBezH = bed.bezeichnung || ""
                if (gkBmkH === "" && gkBezH === "") continue
                var gkLines = (gkBmkH ? gkBmkH.split("\n").length : 0) + (gkBezH ? gkBezH.split("\n").length : 0)
                bhx1 = bTx - pad; bhx2 = bTx + Math.max(60, bFs * 6)
                bhy1 = bTy - pad; bhy2 = bTy + Math.max(gkLines, 1) * bFs * 1.4 + pad
            } else if (bel.typ === "strukturkasten") {
                var skBezH = bed.bezeichnung || ""
                var skLblH = ((bed.anlageUO ? "==" + bed.anlageUO + " " : "") +
                              (bed.ortUO    ? "++" + bed.ortUO    + " " : "") +
                              (bed.anlage   ? "="  + bed.anlage   + " " : "") +
                              (bed.ort      ? "+"  + bed.ort            : "")).trim()
                if (skBezH === "" && skLblH === "") continue
                var skLines = (skLblH ? skLblH.split("\n").length : 0) + (skBezH ? skBezH.split("\n").length : 0)
                bhx1 = bTx - pad; bhx2 = bTx + Math.max(60, bFs * 6)
                bhy1 = bTy - pad; bhy2 = bTy + Math.max(skLines, 1) * bFs * 1.4 + pad
            } else {
                var mkNameH = bed.name || "Makro"
                var mkCxH = (Math.min(bvx1, bvx2) + Math.max(bvx1, bvx2)) / 2 + bOx
                bhx1 = mkCxH - Math.max(40, bFs * 4); bhx2 = mkCxH + Math.max(40, bFs * 4)
                bhy1 = bTy - pad; bhy2 = bTy + mkNameH.split("\n").length * bFs * 1.4 + pad
            }
            if (vpX >= bhx1 && vpX <= bhx2 && vpY >= bhy1 && vpY <= bhy2)
                return bi
        }

        // Durchlauf 2: Symbolbeschriftungen (klemme_anschluss, geraeteanschluss, potenzial, BMK)
        for (var i = n - 1; i >= 0; i--) {
            var el = cv.elementeModel.element(i)
            if (el.typ !== "symbol") continue
            var bmkEd  = el.extraDaten || {}
            var vx1 = el.x1 * cv.zoom + cv.worldX
            var vy1 = el.y1 * cv.zoom + cv.worldY
            var vx2 = el.x2 * cv.zoom + cv.worldX
            var vy2 = el.y2 * cv.zoom + cv.worldY
            var symRot = ((el.rotation || 0) % 360 + 360) % 360
            var senkrecht = (symRot === 90 || symRot === 270)
            var hx1, hy1, hx2, hy2

            if (el.symbolId === "klemme_anschluss") {
                // Klemme-spezifische Hit-Box: Anschlussbezeichnung + BMK
                var kaAnzH = bmkEd.anschlussBezeichnung || ""
                var kaBmkH = bmkEd.bmk || ""
                if (kaAnzH === "" && kaBmkH === "") continue
                var kaFsH    = Math.max(7, Math.round(2.0 * cv.mmToPx * cv.zoom))
                var kaBmkFsH = Math.max(6, Math.round(1.5 * cv.mmToPx * cv.zoom))
                var kaOxH = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0) * cv.zoom
                var kaOyH = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : 0) * cv.zoom
                var textH = kaFsH + kaBmkFsH + pad
                if (senkrecht) {
                    var kaPinRH = (symRot === 90)
                    var kaHX  = kaPinRH
                                 ? Math.min(vx1, vx2) - 4 * cv.zoom + kaOyH
                                 : Math.max(vx1, vx2) + 4 * cv.zoom + kaOyH
                    var kaHCY = (vy1 + vy2) / 2 + kaOxH
                    var hitWH = Math.max(40, kaFsH * 4)
                    hx1 = kaPinRH ? kaHX - hitWH : kaHX - pad
                    hx2 = kaPinRH ? kaHX + pad   : kaHX + hitWH
                    hy1 = kaHCY - kaFsH - pad; hy2 = kaHCY + kaBmkFsH + pad
                } else {
                    var kaPinUH = (symRot === 180)
                    var kaHY  = kaPinUH
                                 ? Math.min(vy1, vy2) - 3 * cv.zoom + kaOyH
                                 : Math.max(vy1, vy2) + 3 * cv.zoom + kaOyH
                    var kaHCX = (vx1 + vx2) / 2 + kaOxH
                    hx1 = kaHCX - Math.max(30, kaFsH * 3); hx2 = kaHCX + Math.max(30, kaFsH * 3)
                    hy1 = kaPinUH ? kaHY - textH : kaHY - pad
                    hy2 = kaPinUH ? kaHY + pad   : kaHY + textH
                }
            } else if (el.symbolId === "geraeteanschluss") {
                // GA: pin rechts bei 0° → 0°: links | 90°: oben | 180°: rechts | 270°: unten
                var gaAnkH = bmkEd.anschlusskennzeichnung || ""
                if (gaAnkH === "") continue
                var gaFsH = Math.max(7, Math.round(2.0 * cv.mmToPx * cv.zoom))
                var gaOxH = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0) * cv.zoom
                var gaOyH = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : 0) * cv.zoom
                var gaHitW = Math.max(40, gaFsH * 4)
                if (senkrecht) {
                    var gaHPinU = (symRot === 90)
                    var gaHY = gaHPinU
                               ? Math.min(vy1, vy2) - 3 * cv.zoom + gaOyH
                               : Math.max(vy1, vy2) + 3 * cv.zoom + gaOyH
                    var gaHCX = (vx1 + vx2) / 2 + gaOxH
                    hx1 = gaHCX - gaHitW; hx2 = gaHCX + gaHitW
                    hy1 = gaHPinU ? gaHY - gaFsH - pad : gaHY - pad
                    hy2 = gaHPinU ? gaHY + pad          : gaHY + gaFsH + pad
                } else {
                    var gaHPinR = (symRot === 0)
                    var gaHX = gaHPinR
                               ? Math.min(vx1, vx2) - 4 * cv.zoom + gaOxH
                               : Math.max(vx1, vx2) + 4 * cv.zoom + gaOxH
                    var gaHCY = (vy1 + vy2) / 2 + gaOyH
                    hx1 = gaHPinR ? gaHX - gaHitW : gaHX - pad
                    hx2 = gaHPinR ? gaHX + pad     : gaHX + gaHitW
                    hy1 = gaHCY - gaFsH / 2 - pad; hy2 = gaHCY + gaFsH / 2 + pad
                }
            } else if (el.symbolId === "potenzial") {
                // Potenzial: pin rechts bei 0° → 0°: links | 90°: oben | 180°: rechts | 270°: unten
                var paHBmk = bmkEd.bmk || ""
                var paHFtR = bmkEd.textReihenfolge || ["freitext1", "freitext2"]
                var paHFt = []
                for (var phfi = 0; phfi < paHFtR.length; phfi++) {
                    var phk = paHFtR[phfi]
                    if (bmkEd[phk + "Sichtbar"] !== false && (bmkEd[phk] || "") !== "")
                        paHFt.push(bmkEd[phk])
                }
                if (paHBmk === "" && paHFt.length === 0) continue
                var paHFs   = Math.max(5, Math.round(2.5 * cv.mmToPx * cv.zoom))
                var paHOx   = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0) * cv.zoom
                var paHOy   = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : 0) * cv.zoom
                var paHHitW  = Math.max(40, paHFs * 4)
                var paHTextH = paHFs * ((paHBmk !== "" ? 1 : 0) + paHFt.length) + pad
                if (senkrecht) {
                    var paHPinU = (symRot === 90)
                    var paHY = paHPinU
                               ? Math.min(vy1, vy2) - 3 * cv.zoom + paHOy
                               : Math.max(vy1, vy2) + 3 * cv.zoom + paHOy
                    var paHCX = (vx1 + vx2) / 2 + paHOx
                    hx1 = paHCX - paHHitW; hx2 = paHCX + paHHitW
                    hy1 = paHPinU ? paHY - paHTextH : paHY - pad
                    hy2 = paHPinU ? paHY + pad       : paHY + paHTextH
                } else {
                    var paHPinR = (symRot === 0)
                    var paHX = paHPinR
                               ? Math.min(vx1, vx2) - 4 * cv.zoom + paHOx
                               : Math.max(vx1, vx2) + 4 * cv.zoom + paHOx
                    var paHCY = (vy1 + vy2) / 2 + paHOy
                    hx1 = paHPinR ? paHX - paHHitW : paHX - pad
                    hx2 = paHPinR ? paHX + pad      : paHX + paHHitW
                    hy1 = paHCY - paHTextH / 2 - pad; hy2 = paHCY + paHTextH / 2 + pad
                }
            } else {
                // LABEL-DRAG-FREITEXT-01: bisher wurde ein Label ohne BMK komplett
                // übersprungen (kein Drag möglich), auch wenn Freitext-Zeilen sichtbar
                // gerendert wurden (z.B. Nebenfunktions-Kontakte eines Kontaktspiegels
                // – die BMK zeigt nur die Hauptfunktion, der Kontakt selbst trägt nur
                // seine Anschlusskennzeichnung als Freitext). Rendering-Bedingung
                // (CanvasRenderHandler.qml::_renderSymbol, ~Zeile 2044) ist
                // "bmkStr !== '' || ftZeilen.length > 0" – hier 1:1 nachgebildet,
                // sonst bleiben genau diese Labels beim Wegklicken auf ewig unklickbar.
                var bmkStr = bmkEd.bmk || ""
                var ftRhlgH = bmkEd.textReihenfolge || ["freitext1", "freitext2"]
                var ftZeilenH = []
                for (var fthi = 0; fthi < ftRhlgH.length; fthi++) {
                    var ftkh = ftRhlgH[fthi]
                    if (bmkEd[ftkh + "Sichtbar"] !== false && (bmkEd[ftkh] || "") !== "")
                        ftZeilenH.push(bmkEd[ftkh])
                }
                if ((el.betriebsmittelId || 0) > 0 && bmkEd.kontaktspiegelSichtbar !== false) {
                    var ksListeH = db.betriebsmittelMitglieder(el.betriebsmittelId)
                    var ksIstHFH = false
                    for (var kih = 0; kih < ksListeH.length; kih++) {
                        if (ksListeH[kih].id === el.id && ksListeH[kih].istHauptfunktion) { ksIstHFH = true; break }
                    }
                    if (ksIstHFH) {
                        for (var kjh = 0; kjh < ksListeH.length; kjh++) {
                            if (ksListeH[kjh].istHauptfunktion) continue
                            var kBezH = ksListeH[kjh].anschlusskennzeichnung || "–"
                            ftZeilenH.push(kBezH + "   Bl." + ksListeH[kjh].blattnummer)
                        }
                    }
                }
                if (bmkStr === "" && ftZeilenH.length === 0) continue
                var bmkOx = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0)  * cv.zoom
                var bmkOy = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : -14) * cv.zoom
                var schrift = bmkEd.schriftgroesse !== undefined ? bmkEd.schriftgroesse : 2.5
                var bmkFs = Math.max(8, Math.round(schrift * cv.mmToPx * cv.zoom))
                var ftFsH = Math.max(6, Math.round(schrift * 0.85 * cv.mmToPx * cv.zoom))
                if (senkrecht) {
                    // Freitext hängt hier direkt unter bkCy (unabhängig von bmkStr),
                    // s. _renderSymbol: ftOff = bkCy + 2*zoom, wächst nach unten weiter.
                    var bkAx = Math.min(vx1, vx2) + bmkOy
                    var bkCy = (vy1 + vy2) / 2 + bmkOx
                    var hitW = Math.max(40, bmkFs * 4)
                    var blockH = (bmkStr !== "" ? Math.max(14, bmkFs) : 0) + ftZeilenH.length * ftFsH * 1.25
                    hx1 = bkAx - hitW; hx2 = bkAx + pad
                    hy1 = bkCy - Math.max(14, bmkFs) - pad; hy2 = bkCy + blockH + pad
                } else {
                    var bkCx = (vx1 + vx2) / 2 + bmkOx
                    var hitW2 = Math.max(40, bmkFs * 3)
                    hx1 = bkCx - hitW2; hx2 = bkCx + hitW2
                    if (bmkStr !== "") {
                        // Unverändert wie vorher: Box um die BMK-Position (über dem Symbol).
                        var bkTy = Math.min(vy1, vy2) + bmkOy
                        hy1 = bkTy - Math.max(14, bmkFs) - pad; hy2 = bkTy + pad
                    } else {
                        // Kein BMK, nur Freitext (z.B. Kontaktspiegel-Nebenfunktion ohne
                        // eigenes BMK): der Freitext-Block hängt unabhängig vom
                        // bmkOffset unter der Symbol-Bbox (_renderSymbol: ftY =
                        // Math.max(vy1,vy2) + 3*zoom, folgt NICHT bmkOffsetY).
                        var ftTopY = Math.max(vy1, vy2) + 3 * cv.zoom
                        hy1 = ftTopY - pad; hy2 = ftTopY + ftZeilenH.length * ftFsH * 1.25 + pad
                    }
                }
            }

            if (vpX >= hx1 && vpX <= hx2 && vpY >= hy1 && vpY <= hy2)
                return i
        }
        return -1
    }

    function formatKopieren() {
        if (cv.auswahl.length !== 1) return
        var el = cv.elementeModel.element(cv.auswahl[0])
        if (!el) return
        var stilKeys = ["strichFarbe","strichBreite","strichArt","fuell",
                        "fuellFarbe","fuellOpazitaet","opazitaet","eckenRadius"]
        var vl = {}
        for (var i = 0; i < stilKeys.length; i++) {
            var k = stilKeys[i]
            if (el[k] !== undefined) vl[k] = el[k]
        }
        if (el.typ === "symbol") {
            var ed = el.extraDaten || {}
            vl._bmkOffsetX = ed.bmkOffsetX !== undefined ? ed.bmkOffsetX : 0
            vl._bmkOffsetY = ed.bmkOffsetY !== undefined ? ed.bmkOffsetY : -14
        }
        cv._formatVorlage = vl
        cv.formatZaehler  = cv.formatZaehler + 1
    }

    // Format-Pinsel: gespeichertes Stilformat auf alle selektierten Elemente anwenden
    function formatZuweisen() {
        if (!cv._formatVorlage || cv.auswahl.length === 0) return
        var selSnapshot = cv.auswahl.slice()
        cv.elementeModel.undoCheckpoint()
        var stilKeys = ["strichFarbe","strichBreite","strichArt","fuell",
                        "fuellFarbe","fuellOpazitaet","opazitaet","eckenRadius"]
        var hatLabelOffset = cv._formatVorlage._bmkOffsetX !== undefined
        for (var i = 0; i < selSnapshot.length; i++) {
            for (var j = 0; j < stilKeys.length; j++) {
                var k = stilKeys[j]
                if (cv._formatVorlage[k] !== undefined)
                    cv.elementeModel.eigenschaftSetzen(selSnapshot[i], k, cv._formatVorlage[k])
            }
            if (hatLabelOffset) {
                var tEl = cv.elementeModel.element(selSnapshot[i])
                if (tEl && tEl.typ === "symbol") {
                    var ted = Object.assign({}, tEl.extraDaten || {})
                    ted.bmkOffsetX = cv._formatVorlage._bmkOffsetX
                    ted.bmkOffsetY = cv._formatVorlage._bmkOffsetY
                    cv.elementeModel.eigenschaftSetzen(selSnapshot[i], "extraDaten", ted)
                }
            }
        }
        cv.auswahl = selSnapshot
        cv.grafikSpeichernJetzt()
        cv._drawCanvas.requestPaint()
    }

    // Mehrfachauswahl um gemeinsamen Pivot rotieren (nur 90°-Schritte).
    // Pivot = weltweit am weitesten links liegender Pin der selektierten Symbole;
    // für Elemente ohne Pins gilt die linke obere Ecke der Bbox als Kandidat.
    // delta: 90 (CW), 270 (CCW) oder 180.
    function multiRotationUmPivot(delta) {
        if (cv.auswahl.length < 2) return

        // ── 1. Pivot bestimmen ───────────────────────────────────────────────
        var pivotX = Infinity, pivotY = Infinity

        function updatePivot(wx, wy) {
            if (wx < pivotX || (wx === pivotX && wy < pivotY)) {
                pivotX = wx; pivotY = wy
            }
        }

        // Zuerst Pin-Kandidaten aus allen selektierten Symbolen sammeln
        var pinKandidaten = false
        var _mreAnz = cv.elementeModel.anzahl
        for (var ii = 0; ii < cv.auswahl.length; ii++) {
            var idxA = cv.auswahl[ii]
            if (idxA < 0 || idxA >= _mreAnz) continue
            var elA = cv.elementeModel.element(idxA)
            if (elA.typ !== "symbol") continue
            var pins = symbolDefinitionModel.pinsForSymbol(elA.symbolId || "")
            for (var pi = 0; pi < pins.length; pi++) {
                var pos = cv.pinWeltPos(elA, pins[pi].x, pins[pi].y)
                updatePivot(pos.x, pos.y)
                pinKandidaten = true
            }
        }

        // Fallback: keine Pins gefunden → Bbox-Ecken aller Elemente
        if (!pinKandidaten) {
            for (var ij = 0; ij < cv.auswahl.length; ij++) {
                var idxB = cv.auswahl[ij]
                if (idxB < 0 || idxB >= _mreAnz) continue
                var elB = cv.elementeModel.element(idxB)
                if (elB.typ === "polygonlinie") {
                    var pts = elB.punkte || []
                    for (var pk = 0; pk < pts.length; pk++) updatePivot(pts[pk].x, pts[pk].y)
                } else {
                    updatePivot(elB.x1, elB.y1)
                }
            }
        }

        if (!isFinite(pivotX)) return

        // ── 2. Rotationsmatrix für 90°-Schritte (exakt, ganzzahlig) ─────────
        var rad  = delta * Math.PI / 180
        var cosD = Math.round(Math.cos(rad))   // 0, ±1
        var sinD = Math.round(Math.sin(rad))   // 0, ±1

        function rotPt(x, y) {
            var dx = x - pivotX, dy = y - pivotY
            return { x: pivotX + cosD * dx - sinD * dy,
                     y: pivotY + sinD * dx + cosD * dy }
        }

        // ── 3. Alle selektierten Elemente transformieren ─────────────────────
        var selSet = {}
        cv.auswahl.forEach(function(i) { selSet[i] = true })

        var neu = cv.elementeModel.snapshot().map(function(el, i) {
            if (!selSet[i]) return el
            var upd = {}; for (var k in el) upd[k] = el[k]

            if (el.typ === "linie") {
                var np1 = rotPt(el.x1, el.y1), np2 = rotPt(el.x2, el.y2)
                upd.x1 = np1.x; upd.y1 = np1.y
                upd.x2 = np2.x; upd.y2 = np2.y

            } else if (el.typ === "polygonlinie") {
                upd.punkte = (el.punkte || []).map(function(p) { return rotPt(p.x, p.y) })
                // x1/y1/x2/y2 als Hüllrechteck aktualisieren
                var xs = upd.punkte.map(function(p) { return p.x })
                var ys = upd.punkte.map(function(p) { return p.y })
                upd.x1 = Math.min.apply(null, xs); upd.x2 = Math.max.apply(null, xs)
                upd.y1 = Math.min.apply(null, ys); upd.y2 = Math.max.apply(null, ys)

            } else {
                // Alle anderen: Mittelpunkt um Pivot drehen, Rotation-Winkel anpassen
                var cx = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
                var hw = (el.x2 - el.x1) / 2,  hh = (el.y2 - el.y1) / 2
                var nc = rotPt(cx, cy)
                upd.x1 = nc.x - hw; upd.x2 = nc.x + hw
                upd.y1 = nc.y - hh; upd.y2 = nc.y + hh
                upd.rotation = ((el.rotation || 0) + delta) % 360
            }
            return upd
        })

        var selSnapshot = cv.auswahl.slice()
        cv.elementeModel.undoCheckpoint()
        cv.elementeModel.fromVariantList(neu); cv.auswahl = selSnapshot
        cv.grafikSpeichernJetzt()
        cv._drawCanvas.requestPaint()
    }

    function eigenschaftenSetzen(updates) {
        if (cv.ausgewaehlt < 0) return
        var oldIdx = cv.ausgewaehlt
        cv.elementeModel.undoCheckpoint()
        cv.elementeModel.elementAktualisieren(oldIdx, updates)
        cv.auswahl = [oldIdx]
        cv.grafikSpeichernJetzt()
        cv._drawCanvas.requestPaint()
    }

    function zReihenfolgeAendern(richtung) {
        if (cv.ausgewaehlt < 0) return
        var idx=cv.ausgewaehlt, n=cv.elementeModel.anzahl
        var neu=cv.elementeModel.snapshot(), el=neu[idx], newIdx=idx
        if      (richtung==="vorne1"    && idx<n-1) { neu.splice(idx,1); neu.splice(idx+1,0,el); newIdx=idx+1 }
        else if (richtung==="hinten1"   && idx>0)   { neu.splice(idx,1); neu.splice(idx-1,0,el); newIdx=idx-1 }
        else if (richtung==="ganzVorne")             { neu.splice(idx,1); neu.push(el);           newIdx=n-1   }
        else if (richtung==="ganzHinten")            { neu.splice(idx,1); neu.unshift(el);        newIdx=0     }
        else return
        cv.elementeModel.undoCheckpoint()
        cv.elementeModel.fromVariantList(neu); cv.auswahl=[newIdx]
        cv.grafikSpeichernJetzt()
        cv._drawCanvas.requestPaint()
    }

    function undo() {
        if (!cv.elementeModel.undoMoeglich) return
        cv.elementeModel.undo()
        cv.auswahl = []
        cv.grafikSpeichernJetzt()
        cv._drawCanvas.requestPaint()
        achievementManager.ereignis("undo")
    }

    function redo() {
        if (!cv.elementeModel.redoMoeglich) return
        cv.elementeModel.redo()
        cv.auswahl = []
        cv.grafikSpeichernJetzt()
        cv._drawCanvas.requestPaint()
    }

    function loeschen() {
        if (cv.auswahl.length === 0) return
        // Kabel-Einträge für Kabellinien zuerst aufräumen
        for (var ki = 0; ki < cv.auswahl.length; ki++) {
            var delEl = cv.elementeModel.element(cv.auswahl[ki])
            if (delEl && delEl.typ === "kabellinie") {
                var delKabelId = delEl.extraDaten && delEl.extraDaten.kabelId || 0
                if (delKabelId <= 0 && delEl.id > 0) {
                    var kabelDetails = db.kabelLinieDetails(delEl.id)
                    delKabelId = kabelDetails && kabelDetails.id || 0
                }
                if (delKabelId > 0) db.kabelLoeschen(delKabelId)
            }
        }
        // Von hinten löschen damit Indizes stabil bleiben
        var sorted = cv.auswahl.slice().sort(function(a, b) { return b - a })
        var neu = cv.elementeModel.snapshot()
        for (var i = 0; i < sorted.length; i++) neu.splice(sorted[i], 1)
        var vorher = cv.elementeModel.anzahl
        cv.elementeModel.undoCheckpoint()
        cv.elementeModel.fromVariantList(neu); cv.auswahl = []
        cv.grafikSpeichernJetzt()
        cv.kabelLinienCacheAktualisieren()
        cv._drawCanvas.requestPaint()
        achievementManager.ereignis("element_geloescht", {
            "anzahl":    sorted.length,
            "seiteWar":  vorher,
            "seiteJetzt": cv.elementeModel.anzahl
        })
    }

    function alleAuswaehlen() {
        if (cv.elementeModel.anzahl === 0 || cv.seiteId < 0) return
        var sel = []; for (var i = 0; i < cv.elementeModel.anzahl; i++) sel.push(i)
        cv.auswahl = sel
        cv._drawCanvas.requestPaint()
    }

    function kopieren(slot) {
        if (cv.auswahl.length === 0) return
        var inhalt = cv.auswahl.map(function(i) {
            var el = cv.elementeModel.element(i)
            var copy = Object.assign({}, el)
            delete copy.gruppeId
            return copy
        })
        var s = (slot === undefined) ? 0 : slot
        if (s === 0) {
            cv.zwischenablage = inhalt
            cv.zwischenablageAusgeschnitten = false // KLEMME-AUSSCHNEIDEN-01: normales Kopieren, Original bleibt bestehen
            // COPY-CROSS-01: Slot 0 zusätzlich auf die System-Zwischenablage
            // spiegeln, damit eine ANDERE Prozessinstanz (anderes Projekt)
            // einfügen kann. Slots 1-4 bleiben bewusst rein lokal/in-memory.
            var exportiert = db.elementeFuerExportSanitisieren(inhalt)
            appHelper.systemZwischenablageSchreiben(JSON.stringify({
                version: 1, projektPfad: db.projektPfad, elemente: exportiert
            }))
        } else {
            var neu = cv.zwischenablagen.slice()
            neu[s] = inhalt
            cv.zwischenablagen = neu
            var neuA = cv.zwischenablagenAusgeschnitten.slice()
            neuA[s] = false
            cv.zwischenablagenAusgeschnitten = neuA
        }
    }

    function einfuegen(slot) {
        var s = (slot === undefined) ? 0 : slot
        if (s === 0 && cv.zwischenablage.length === 0) {
            _einfuegenAusSystemZwischenablage()
            return
        }
        var quelle = (s === 0) ? cv.zwischenablage : cv.zwischenablagen[s]
        if (!quelle || quelle.length === 0 || cv.seiteId < 0) return
        cv.duplizierVorlage   = quelle
        cv.duplizierMitDialog = false
        // KLEMME-AUSSCHNEIDEN-01: kam dieser Slot-Inhalt aus Ausschneiden (nicht
        // Kopieren), darf ein verknüpfter Klemmenanschluss beim Platzieren seine
        // reale Verknüpfung behalten (echtes Verschieben, Original existiert
        // nicht mehr) statt zum Geist zu werden – s. _duplizierAnzahlPlatzieren().
        cv._duplizierAusSchnitt  = (s === 0) ? cv.zwischenablageAusgeschnitten : cv.zwischenablagenAusgeschnitten[s]
        cv._duplizierSchnittSlot = s
        cv.aktivesWerkzeug    = "duplizieren"
        _duplizierVorschauAktualisieren(cv.letzteMausWeltX, cv.letzteMausWeltY)
    }

    // COPY-CROSS-01: Fallback wenn die lokale In-Memory-Zwischenablage leer
    // ist (z.B. weil in einer ANDEREN Prozessinstanz kopiert wurde) – liest
    // die System-Zwischenablage, vergleicht die Projektherkunft und saniert
    // bei fremdem Projekt Instanz-Referenzen (betriebsmittelId → Snapshot,
    // analog Makro-Export). Stiller Abbruch bei leerem/ungültigem Inhalt
    // (z.B. Text aus einer anderen App kopiert).
    function _einfuegenAusSystemZwischenablage() {
        if (cv.seiteId < 0) return
        var roh = appHelper.systemZwischenablageLesen()
        if (!roh) return
        var payload
        try { payload = JSON.parse(roh) } catch (e) { console.warn("Zwischenablage: ungültiges JSON", e); return }
        if (!payload || !payload.elemente || payload.elemente.length === 0) return

        var fremdesProjekt = payload.projektPfad !== db.projektPfad
        var quelle = fremdesProjekt
            ? db.elementeFuerImportSanitisieren(payload.elemente, cv.seiteId)
            : payload.elemente
        cv.duplizierVorlage            = quelle
        cv.duplizierMitDialog          = false
        // KLEMME-AUSSCHNEIDEN-01: Cross-Prozess-Einfügen ist nie ein Ausschneiden
        // (die Quellinstanz weiß davon nichts) – verknüpfte Klemmenanschlüsse
        // müssen hier immer zum Geist entkoppelt werden.
        cv._duplizierAusSchnitt        = false
        cv._duplizierSchnittSlot       = -1
        cv._nachEinfuegenMakroAnbieten = fremdesProjekt
        cv.aktivesWerkzeug             = "duplizieren"
        _duplizierVorschauAktualisieren(cv.letzteMausWeltX, cv.letzteMausWeltY)
    }

    function duplizieren() {
        if (cv.auswahl.length === 0 || cv.seiteId < 0) return
        // KLEMME-AUSSCHNEIDEN-01: Duplizieren einer bestehenden Auswahl lässt
        // das Original stehen – nie als Ausschneiden-Platzierung behandeln.
        cv._duplizierAusSchnitt  = false
        cv._duplizierSchnittSlot = -1
        cv.duplizierVorlage = cv.auswahl.map(function(i) {
            var el   = cv.elementeModel.element(i)
            var copy = Object.assign({}, el)
            delete copy.gruppeId   // Gruppe nicht auf Kopie übertragen
            return copy
        })
        cv.duplizierMitDialog = true
        cv.aktivesWerkzeug    = "duplizieren"
        _duplizierVorschauAktualisieren(cv.letzteMausWeltX, cv.letzteMausWeltY)
    }

    function ausschneiden(slot) {
        if (cv.auswahl.length === 0) return
        var s = (slot === undefined) ? 0 : slot
        kopieren(s)
        // KLEMME-AUSSCHNEIDEN-01: erst NACH kopieren() setzen, da kopieren()
        // das Flag für einen normalen Kopiervorgang auf false zurücksetzt.
        // Original wird direkt im Anschluss gelöscht – ein verknüpfter
        // Klemmenanschluss darf beim Einfügen daher seine reale Verknüpfung
        // behalten (Original existiert nicht mehr, keine Kollisionsgefahr).
        if (s === 0) {
            cv.zwischenablageAusgeschnitten = true
        } else {
            var neuA = cv.zwischenablagenAusgeschnitten.slice()
            neuA[s] = true
            cv.zwischenablagenAusgeschnitten = neuA
        }
        loeschen()
    }

    // Gibt die vollständige Gruppenauswahl zurück wenn idx zu einer Gruppe gehört,
    // sonst [idx].
    function auswahlFuerElement(idx) {
        if (idx < 0) return []
        var gId = cv.elementeModel.gruppeVonElement(idx)
        if (gId >= 0) {
            var mitgl = cv.elementeModel.gruppenMitglieder(gId)
            return mitgl.map(function(v) { return parseInt(v) })
        }
        return [idx]
    }

    function gruppeErstellen() {
        if (cv.auswahl.length < 2 || cv.seiteId < 0) return
        cv.elementeModel.undoCheckpoint()
        cv.elementeModel.gruppeErstellen(cv.auswahl)
        cv.grafikSpeichernJetzt()
        cv.neuZeichnen()
    }

    function gruppeAufloesen() {
        if (cv.auswahl.length === 0 || cv.seiteId < 0) return
        var gId = cv.elementeModel.gruppeVonElement(cv.auswahl[0])
        if (gId < 0) return
        cv.elementeModel.undoCheckpoint()
        var mitgl = cv.elementeModel.gruppenMitglieder(gId)
        cv.elementeModel.gruppeAufloesen(gId)
        cv.auswahl = mitgl.map(function(v) { return parseInt(v) })
        cv.grafikSpeichernJetzt()
        cv.neuZeichnen()
    }

    function _duplizierVorschauAktualisieren(wx, wy) {
        var els = cv.duplizierVorlage
        if (!els || els.length === 0) return
        var minX = els[0].x1, minY = els[0].y1, maxX = els[0].x2, maxY = els[0].y2
        for (var i = 1; i < els.length; i++) {
            if (els[i].x1 < minX) minX = els[i].x1
            if (els[i].y1 < minY) minY = els[i].y1
            if (els[i].x2 > maxX) maxX = els[i].x2
            if (els[i].y2 > maxY) maxY = els[i].y2
        }
        var dx = wx - (minX + maxX) / 2
        var dy = wy - (minY + maxY) / 2
        cv.duplizierVorschau = els.map(function(el) {
            var upd = {}; for (var k in el) upd[k] = el[k]
            upd.x1 += dx; upd.y1 += dy; upd.x2 += dx; upd.y2 += dy
            upd.id = -1
            return upd
        })
        cv.neuZeichnen()
    }

    function _duplizierAnzahlAnfordern(dx, dy) {
        cv.duplizierOffsetX  = dx
        cv.duplizierOffsetY  = dy
        cv.duplizierVorschau = null
        cv.neuZeichnen()
        if (cv.duplizierMitDialog)
            cv._duplizierDialog.open()
        else
            _duplizierAnzahlPlatzieren(1)
    }

    function _duplizierAnzahlPlatzieren(n) {
        var elsRoh = cv.duplizierVorlage
        if (!elsRoh || n < 1) { abbruch(); return }

        // KLEMME-AUSSCHNEIDEN-01: kam die Vorlage aus Ausschneiden (nicht
        // Kopieren/Duplizieren), existiert das Original nicht mehr – ein
        // verknüpfter Klemmenanschluss darf dann seine reale Verknüpfung
        // behalten (echtes Verschieben, ggf. seitenübergreifend), statt zum
        // Geist entkoppelt zu werden. Zusätzliche Absicherung gegen
        // Zwischenzeit-Kollisionen (z.B. dieselbe Klemme wurde nach dem
        // Ausschneiden, aber vor dem Einfügen anderweitig real platziert):
        // db.klemmeAnschlussIstPlatziert() prüft den aktuellen DB-Stand pro
        // Element frisch, nicht nur einmal pauschal fürs ganze Slot-Flag.
        var ausSchnitt = cv._duplizierAusSchnitt === true

        // KLEMME-DUP-01: verknüpfte Klemmenanschlüsse (Modus A) sind reale
        // Bauteil-Anschlüsse und lassen sich nicht als Zweitexemplar verknüpfen
        // – jede Kopie trüge denselben klemmeId+anschlussBezeichnung wie das
        // Original. Statt die Kopie zu verwerfen, wird sie zu einem deutlich
        // markierten "Geist" entkoppelt (Modus C/Skizze, extraDaten.geist=true,
        // grau+gestrichelt) – Nutzer hat dadurch eine Orientierung an Position
        // und Bezeichnung, muss aber im Klemmenreihen-Editor eine echte Klemme
        // nachziehen und verknüpfen.
        var els = []
        var anzahlGeister = 0
        for (var b = 0; b < elsRoh.length; b++) {
            var elQ = elsRoh[b]
            var istVerknuepfterKlemmenanschluss = elQ.typ === "symbol" && elQ.symbolId === "klemme_anschluss"
                && elQ.extraDaten && elQ.extraDaten.platziermodus === "verknuepft"
            var behaeltEchteVerknuepfung = istVerknuepfterKlemmenanschluss && ausSchnitt
                && !db.klemmeAnschlussIstPlatziert(elQ.extraDaten.klemmeId, elQ.extraDaten.anschlussBezeichnung)
            if (istVerknuepfterKlemmenanschluss && !behaeltEchteVerknuepfung) {
                var edGeist = Object.assign({}, elQ.extraDaten)
                delete edGeist.klemmeId
                delete edGeist.bauteilKlemmeId
                edGeist.platziermodus = "skizze"
                edGeist.geist = true
                var elGeist = Object.assign({}, elQ)
                elGeist.extraDaten  = edGeist
                elGeist.strichFarbe = "#888888"
                elGeist.strichArt   = "gestrichelt"
                elGeist.opazitaet   = 0.55
                els.push(elGeist)
                anzahlGeister++
            } else {
                els.push(elQ)
            }
        }
        if (anzahlGeister > 0) {
            meldungManager.zeigen(
                anzahlGeister === 1
                    ? qsTr("Klemmenanschluss als Platzhalter eingefügt – im Klemmenreihen-Editor eine echte Klemme anlegen und verknüpfen.")
                    : qsTr("%1 Klemmenanschlüsse als Platzhalter eingefügt – im Klemmenreihen-Editor echte Klemmen anlegen und verknüpfen.").arg(anzahlGeister),
                true
            )
        }
        if (els.length === 0) { abbruch(); return }

        // KLEMME-AUSSCHNEIDEN-01: Schnitt-Flag ist nach diesem einen
        // Einfügevorgang verbraucht – ein weiteres Ctrl+V desselben Slots
        // (Original ist ja jetzt hier platziert) muss wieder normal zum
        // Geist entkoppeln, sonst entstünde beim zweiten Einfügen doch ein
        // echtes Duplikat.
        if (ausSchnitt) {
            cv._duplizierAusSchnitt = false
            var schnittSlot = cv._duplizierSchnittSlot
            if (schnittSlot === 0) {
                cv.zwischenablageAusgeschnitten = false
            } else if (schnittSlot > 0) {
                var neuA2 = cv.zwischenablagenAusgeschnitten.slice()
                neuA2[schnittSlot] = false
                cv.zwischenablagenAusgeschnitten = neuA2
            }
            cv._duplizierSchnittSlot = -1
        }

        var neueEl = []
        for (var c = 1; c <= n; c++) {
            var dx = cv.duplizierOffsetX * c
            var dy = cv.duplizierOffsetY * c
            for (var j = 0; j < els.length; j++) {
                var upd = {}; for (var k in els[j]) upd[k] = els[j][k]
                upd.x1 += dx; upd.y1 += dy; upd.x2 += dx; upd.y2 += dy
                neueEl.push(upd)
            }
        }
        var anzahl = neueEl.length
        aktionAusfuehren(cv.elementeModel.snapshot().concat(neueEl))
        var start = cv.elementeModel.anzahl - anzahl
        var sel = []; for (var s = 0; s < anzahl; s++) sel.push(start + s)
        cv.auswahl          = sel
        cv.aktivesWerkzeug  = "zeiger"
        cv.duplizierVorlage  = null
        cv.duplizierVorschau = null
        cv.neuZeichnen()

        if (cv._nachEinfuegenMakroAnbieten) {
            cv._nachEinfuegenMakroAnbieten = false
            _crossProjektMakroAnbieten(sel)
        }
    }

    // COPY-CROSS-01: Bounding-Box der frisch aus einem anderen Projekt
    // eingefügten Elemente ermitteln und den Bestätigungsdialog öffnen
    // ("Als Makro behalten?" statt Blockade – sanfte statt harte Lenkung,
    // siehe konzept/features/15_makros.md §2c).
    function _crossProjektMakroAnbieten(indizes) {
        if (!indizes || indizes.length === 0) return
        var em = cv.elementeModel
        var erstes = em.element(indizes[0])
        var minX = erstes.x1, minY = erstes.y1, maxX = erstes.x2, maxY = erstes.y2
        for (var i = 1; i < indizes.length; i++) {
            var e = em.element(indizes[i])
            if (e.x1 < minX) minX = e.x1
            if (e.y1 < minY) minY = e.y1
            if (e.x2 > maxX) maxX = e.x2
            if (e.y2 > maxY) maxY = e.y2
        }
        cv._crossProjektBbox = { x1: minX, y1: minY, x2: maxX, y2: maxY }
        cv.crossProjektEinfuegenDialogOeffnen()
    }

    // Wird vom CrossProjektEinfuegenDialog bei "Ja, als Makro behalten"
    // aufgerufen: legt einen Makrokasten um die zuletzt eingefügte Auswahl
    // an – exakt derselbe Flow wie beim manuellen Zeichnen eines
    // Makrokastens (CanvasInteraktionArea.qml → makrobenennDialogFuerNeuOeffnen).
    function crossProjektMakroErstellen() {
        var b = cv._crossProjektBbox
        if (!b) return
        var kasten = Object.assign(
            { typ: "makrokasten", x1: b.x1, y1: b.y1, x2: b.x2, y2: b.y2 },
            cv.stilVorlage)
        kasten.strichFarbe = "#aa44cc"; kasten.strichArt = "gestrichelt"; kasten.fuell = false
        kasten.extraDaten  = { name: "", beschreibung: "", kategorie: "", makroId: 0 }
        aktionAusfuehren(cv.elementeModel.snapshot().concat([kasten]))
        cv.grafikSpeichernJetzt()
        cv.elementeModel.laden(cv.seiteId)   // IDs ändern sich durch DELETE+INSERT
        var newIdx = cv.elementeModel.anzahl - 1
        cv.makrobenennDialogFuerNeuOeffnen(newIdx)
    }

    function abbruch() {
        cv.amZeichnen       = false; cv.vorschau = null
        cv.aktiverGriff     = -1
        cv.amRubberband     = false; cv.rubberbandRect = null
        cv.textEditAktiv    = false
        cv.paletteImageData = ""
        cv.amPolyZeichnen   = false
        cv.polyPunkte       = []
        cv.polyCursorWelt   = null
        cv.duplizierVorlage   = null
        cv.duplizierVorschau  = null
        cv.duplizierMitDialog = true
        cv._drawCanvas.requestPaint()
    }
}
