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
            var rx1 = Math.round(el.x1 / g) * g
            var ry1 = Math.round(el.y1 / g) * g
            var w   = el.x2 - el.x1
            var h   = el.y2 - el.y1
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
            } else {
                cv.elementeModel.eigenschaftSetzen(i, key, value)
            }
        })

        cv.auswahl = selSnapshot
        cv.grafikSpeichernJetzt()

        // Stilvorlagen nur bei Einzelauswahl übernehmen
        if (cv.auswahl.length === 1) {
            var stilKeys = ["strichFarbe","strichBreite","strichArt","fuell",
                            "fuellFarbe","fuellOpazitaet","opazitaet","eckenRadius"]
            if (stilKeys.indexOf(key) >= 0) {
                var vl = {}; for (var sk in cv.stilVorlage) vl[sk] = cv.stilVorlage[sk]
                vl[key] = value; cv.stilVorlage = vl
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

    // Viewport-Hit-Test auf BMK-Beschriftung eines Symbols.
    // Gibt Element-Index zurück oder -1 wenn kein Label getroffen.
    function labelTreffenTest(vpX, vpY) {
        var n = cv.elementeModel.anzahl
        for (var i = n - 1; i >= 0; i--) {
            var el = cv.elementeModel.element(i)
            if (el.typ !== "symbol") continue
            var bmkEd  = el.extraDaten || {}
            var vx1 = el.x1 * cv.zoom + cv.worldX
            var vy1 = el.y1 * cv.zoom + cv.worldY
            var vx2 = el.x2 * cv.zoom + cv.worldX
            var vy2 = el.y2 * cv.zoom + cv.worldY
            var pad   = 8
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
                var bmkStr = bmkEd.bmk || ""
                if (bmkStr === "") continue
                var bmkOx = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0)  * cv.zoom
                var bmkOy = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : -14) * cv.zoom
                var schrift = bmkEd.schriftgroesse !== undefined ? bmkEd.schriftgroesse : 2.5
                var bmkFs = Math.max(8, Math.round(schrift * cv.mmToPx * cv.zoom))
                if (senkrecht) {
                    var bkAx = Math.min(vx1, vx2) + bmkOy
                    var bkCy = (vy1 + vy2) / 2 + bmkOx
                    var hitW = Math.max(40, bmkFs * 4)
                    hx1 = bkAx - hitW; hx2 = bkAx + pad
                    hy1 = bkCy - Math.max(14, bmkFs) - pad; hy2 = bkCy + pad
                } else {
                    var bkCx = (vx1 + vx2) / 2 + bmkOx
                    var bkTy = Math.min(vy1, vy2) + bmkOy
                    var hitW2 = Math.max(40, bmkFs * 3)
                    hx1 = bkCx - hitW2; hx2 = bkCx + hitW2
                    hy1 = bkTy - Math.max(14, bmkFs) - pad; hy2 = bkTy + pad
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
        } else {
            var neu = cv.zwischenablagen.slice()
            neu[s] = inhalt
            cv.zwischenablagen = neu
        }
    }

    function einfuegen(slot) {
        var s = (slot === undefined) ? 0 : slot
        var quelle = (s === 0) ? cv.zwischenablage : cv.zwischenablagen[s]
        if (!quelle || quelle.length === 0 || cv.seiteId < 0) return
        cv.duplizierVorlage   = quelle
        cv.duplizierMitDialog = false
        cv.aktivesWerkzeug    = "duplizieren"
        _duplizierVorschauAktualisieren(cv.letzteMausWeltX, cv.letzteMausWeltY)
    }

    function duplizieren() {
        if (cv.auswahl.length === 0 || cv.seiteId < 0) return
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

    function ausschneiden() {
        if (cv.auswahl.length === 0) return
        kopieren()
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
        var els = cv.duplizierVorlage
        if (!els || n < 1) { abbruch(); return }
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
