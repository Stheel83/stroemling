import QtQuick

// Werkzeug-Zustandsmaschine des SchaltplanCanvas.
// Verarbeitet alle Mausereignisse (Klick, Drag, Release, DoubleClick).
// Setzt Werkzeuge, Auswahl, Verschieben, Rubber-Band, Zeichnen und Platzieren um.
// Kommuniziert ausschließlich über `canvas` (SchaltplanCanvas-Referenz).
MouseArea {
    id: root

    required property var canvas

    enabled:         canvas.seiteId >= 0
    acceptedButtons: Qt.LeftButton
    hoverEnabled:    true
    cursorShape: {
        if (canvas.aktivesWerkzeug !== "zeiger")  return Qt.CrossCursor
        if (canvas.aktiverGriff >= 0)             return Qt.SizeAllCursor
        if (canvas.amVerschieben)                 return Qt.SizeAllCursor
        if (canvas.mausUeberGriff)                return Qt.SizeAllCursor
        if (canvas.mausUeberElement)              return Qt.SizeAllCursor
        return Qt.ArrowCursor
    }

    // Koordinaten-Hilfsfunktionen
    function toViewport(mx, my) {
        var p = root.mapToItem(canvas, mx, my); return Qt.point(p.x, p.y)
    }
    function toWelt(mx, my) {
        var vp = toViewport(mx, my)
        var w  = canvas.viewportZuWelt(vp.x, vp.y)
        return canvas.rastend ? canvas.rasterPunkt(w.x, w.y) : w
    }

    onPositionChanged: function(mouse) {
        var em = canvas.elementeModel
        if (canvas.aktivesWerkzeug === "zeiger") {
            var vp = toViewport(mouse.x, mouse.y)

            // Rubber-Band: Auswahl-Rechteck live aktualisieren
            if (canvas.amRubberband) {
                canvas.rubberbandRect = { x1: canvas.rubberbandVpX, y1: canvas.rubberbandVpY,
                                          x2: vp.x, y2: vp.y }
                canvas.neuZeichnen()
                return
            }

            // Handle-Drag: Griff zieht → Größe anpassen (nur Einzelauswahl)
            if (canvas.aktiverGriff >= 0 && canvas.ausgewaehlt >= 0) {
                var wgRaw = toWelt(mouse.x, mouse.y)
                var wg    = canvas.rastend ? canvas.rasterPunkt(wgRaw.x, wgRaw.y) : wgRaw
                var eg    = em.element(canvas.ausgewaehlt)
                var upd   = {}; for (var kk in eg) upd[kk] = eg[kk]
                var g = canvas.aktiverGriff
                if (eg.typ === "linie" || eg.typ === "kabellinie") {
                    if (g === 0) { upd.x1 = wg.x; upd.y1 = wg.y }
                    else         { upd.x2 = wg.x; upd.y2 = wg.y }
                } else if (eg.typ === "rechteck" || eg.typ === "geraetekasten"
                           || eg.typ === "strukturkasten" || eg.typ === "makrokasten"
                           || eg.typ === "notiz") {
                    if      (g === 0) { upd.x1 = wg.x; upd.y1 = wg.y }
                    else if (g === 1) { upd.x2 = wg.x; upd.y1 = wg.y }
                    else if (g === 2) { upd.x2 = wg.x; upd.y2 = wg.y }
                    else              { upd.x1 = wg.x; upd.y2 = wg.y }
                } else if (eg.typ === "kreis") {
                    if (g === 0) {
                        var rdx = eg.x2 - eg.x1; var rdy = eg.y2 - eg.y1
                        upd.x1 = wg.x; upd.y1 = wg.y
                        upd.x2 = wg.x + rdx; upd.y2 = wg.y + rdy
                    } else {
                        upd.x2 = wg.x; upd.y2 = wg.y
                    }
                } else if (eg.typ === "polygonlinie") {
                    var plNeu = eg.punkte.map(function(p, pi) {
                        return pi === g ? { x: wg.x, y: wg.y } : p
                    })
                    upd.punkte = plNeu
                    var plMnX = plNeu[0].x, plMnY = plNeu[0].y, plMxX = plNeu[0].x, plMxY = plNeu[0].y
                    for (var plBi = 1; plBi < plNeu.length; plBi++) {
                        if (plNeu[plBi].x < plMnX) plMnX = plNeu[plBi].x
                        if (plNeu[plBi].y < plMnY) plMnY = plNeu[plBi].y
                        if (plNeu[plBi].x > plMxX) plMxX = plNeu[plBi].x
                        if (plNeu[plBi].y > plMxY) plMxY = plNeu[plBi].y
                    }
                    upd.x1 = plMnX; upd.y1 = plMnY; upd.x2 = plMxX; upd.y2 = plMxY
                } else if (eg.typ === "bild") {
                    var origW = Math.abs(eg.x2 - eg.x1), origH = Math.abs(eg.y2 - eg.y1)
                    var ratio = origH > 0 ? origW / origH : 1
                    if      (g === 0) { upd.x1 = wg.x; upd.y1 = wg.y }
                    else if (g === 1) { upd.x2 = wg.x; upd.y1 = wg.y }
                    else if (g === 2) { upd.x2 = wg.x; upd.y2 = wg.y }
                    else              { upd.x1 = wg.x; upd.y2 = wg.y }
                    if (eg.proportional && origW > 0 && origH > 0) {
                        var newW = Math.abs(upd.x2 - upd.x1), newH = Math.abs(upd.y2 - upd.y1)
                        if (g === 0) {
                            upd.y1 = upd.y2 - newW / ratio
                        } else if (g === 1) {
                            upd.y1 = upd.y2 - newW / ratio
                        } else if (g === 2) {
                            upd.y2 = upd.y1 + newW / ratio
                        } else {
                            upd.y2 = upd.y1 + newW / ratio
                        }
                    }
                }
                var gIdx = canvas.ausgewaehlt
                em.elementAktualisieren(gIdx, upd)
                canvas.auswahl = [gIdx]
                canvas.neuZeichnen()
                return
            }

            // Hover-Cursor: Griff oder Element unter Maus?
            if (!canvas.amVerschieben) {
                canvas.mausUeberGriff   = (canvas.griffBeiPosition(vp.x, vp.y) >= 0)
                canvas.mausUeberElement = (canvas.elementBeiPosition(vp.x, vp.y) >= 0)
            }

            // Element(e) verschieben (nur wenn bereits selektiert + Drag-Schwelle)
            if (canvas.verschiebenErlaubt && canvas.auswahl.length > 0) {
                var dvpX = vp.x - canvas.verschiebenMausVpX
                var dvpY = vp.y - canvas.verschiebenMausVpY

                if (!canvas.amVerschieben && Math.sqrt(dvpX*dvpX + dvpY*dvpY) < 5)
                    return

                canvas.amVerschieben = true

                var dwX = dvpX / canvas.zoom
                var dwY = dvpY / canvas.zoom

                // Snap: Referenzpunkt (erstes Element) einrasten
                var sp0 = canvas.verschiebenStartPos ? canvas.verschiebenStartPos[0]
                                                     : { x1: canvas.verschiebenStartX1, y1: canvas.verschiebenStartY1 }
                if (canvas.rastend) {
                    var snapEl0  = canvas.auswahl.length > 0 ? em.element(canvas.auswahl[0]) : null
                    var snapOffX = 0, snapOffY = 0
                    if (snapEl0 && snapEl0.typ === "symbol" && snapEl0.symbolId === "aderdefinition") {
                        snapOffX = (snapEl0.x2 - snapEl0.x1) / 2
                        snapOffY = (snapEl0.y2 - snapEl0.y1) / 2
                    }
                    var sn = canvas.rasterPunkt(sp0.x1 + dwX + snapOffX, sp0.y1 + dwY + snapOffY)
                    dwX = sn.x - snapOffX - sp0.x1; dwY = sn.y - snapOffY - sp0.y1
                }

                var selArr   = canvas.auswahl.slice()
                var startArr = canvas.verschiebenStartPos
                var neu = em.snapshot().map(function(el, i) {
                    var si = selArr.indexOf(i)
                    if (si < 0) return el
                    var upd2 = {}; for (var k in el) upd2[k] = el[k]
                    var sp = startArr ? startArr[si]
                                      : { x1: canvas.verschiebenStartX1, y1: canvas.verschiebenStartY1,
                                          x2: canvas.verschiebenStartX2, y2: canvas.verschiebenStartY2 }
                    upd2.x1 = sp.x1 + dwX; upd2.y1 = sp.y1 + dwY
                    upd2.x2 = sp.x2 + dwX; upd2.y2 = sp.y2 + dwY
                    if (el.typ === "polygonlinie" && sp.punkte)
                        upd2.punkte = sp.punkte.map(function(p) { return { x: p.x + dwX, y: p.y + dwY } })
                    return upd2
                })
                em.fromVariantList(neu)
                canvas.auswahl = selArr
                canvas.neuZeichnen()
            }
            return
        }

        // Zeichenwerkzeug: Koordinatenanzeige + Vorschau
        var w = toWelt(mouse.x, mouse.y)
        canvas.koordinatenTextSetzen(
            "X " + Math.round(w.x / canvas.mmToPx) + " mm "
            + "Y " + Math.round(w.y / canvas.mmToPx) + " mm")

        if (canvas.aktivesWerkzeug === "duplizieren" && canvas.duplizierVorlage) {
            canvas._duplizierVorschauAktualisieren(w.x, w.y)
            return
        }

        if (canvas.aktivesWerkzeug === "symbol" && canvas.paletteSymbolId !== "") {
            canvas.letzteMausWeltX = w.x; canvas.letzteMausWeltY = w.y
            canvas.vorschau = canvas.symbolVorschauErstellen(w.x, w.y)
            canvas.neuZeichnen()
            return
        }

        if (canvas.aktivesWerkzeug === "makroEinfuegen" && canvas.makroEinfuegenId > 0) {
            var makroMeta = db.makroListe().find(function(m) { return m.id === canvas.makroEinfuegenId }) || null
            var mkW = makroMeta ? makroMeta.kastenBreite || (canvas.gridPx * 10) : canvas.gridPx * 10
            var mkH = makroMeta ? makroMeta.kastenHoehe  || (canvas.gridPx * 8)  : canvas.gridPx * 8
            canvas.vorschau = { typ: "makrokasten",
                                x1: w.x, y1: w.y, x2: w.x + mkW, y2: w.y + mkH,
                                strichFarbe: "#aa44cc", fuell: false, opazitaet: 1.0,
                                extraDaten: { name: canvas.makroEinfuegenName, makroId: canvas.makroEinfuegenId } }
            canvas.neuZeichnen()
            return
        }

        if (canvas.aktivesWerkzeug === "bild" && canvas.paletteImageData !== "") {
            var bDefW = canvas.gridPx * 8; var bDefH = canvas.gridPx * 8
            canvas.vorschau = { typ: "bild", bildDaten: canvas.paletteImageData,
                                x1: w.x - bDefW/2, y1: w.y - bDefH/2,
                                x2: w.x + bDefW/2, y2: w.y + bDefH/2,
                                opazitaet: 1.0 }
            canvas.neuZeichnen()
            return
        }

        if (canvas.amPolyZeichnen) {
            canvas.polyCursorWelt = canvas.rastend ? canvas.rasterPunkt(w.x, w.y) : w
            canvas.neuZeichnen()
            return
        }
        if (!canvas.amZeichnen) return
        canvas.vorschau = { typ: canvas.aktivesWerkzeug,
                            x1: canvas.zeichenStartX, y1: canvas.zeichenStartY,
                            x2: w.x, y2: w.y }
        canvas.neuZeichnen()
    }

    onExited: {
        canvas.mausUeberElement = false
        if (canvas.aktivesWerkzeug !== "zeiger") canvas.koordinatenTextSetzen("")
        if (canvas.aktivesWerkzeug === "symbol" || canvas.aktivesWerkzeug === "bild")
            { canvas.vorschau = null; canvas.neuZeichnen() }
        if (canvas.aktivesWerkzeug === "duplizieren")
            { canvas.duplizierVorschau = null; canvas.neuZeichnen() }
    }

    onPressed: function(mouse) {
        canvas.forceActiveFocus()
        var em = canvas.elementeModel
        if (canvas.aktivesWerkzeug === "zeiger") {
            var vp = toViewport(mouse.x, mouse.y)

            // Griff-Klick prüfen
            if (canvas.ausgewaehlt >= 0) {
                var griff = canvas.griffBeiPosition(vp.x, vp.y)
                if (griff >= 0) {
                    canvas.aktiverGriff      = griff
                    canvas.schnapshotVorMove = em.snapshot()
                    return
                }
            }

            var idx = canvas.elementBeiPosition(vp.x, vp.y)
            canvas.aktiverGriff = -1
            var ctrlGehalten = (mouse.modifiers & Qt.ControlModifier) !== 0

            if (idx < 0) {
                var conn = canvas.verbindungBeiPosition(vp.x, vp.y)
                if (conn !== null) {
                    canvas.auswahl = []
                    canvas.ausgewaehltVerbindung = conn
                    canvas.neuZeichnen()
                    return
                }
                canvas.ausgewaehltVerbindung = null
                canvas.auswahl            = []
                canvas.amRubberband       = true
                canvas.rubberbandVpX      = vp.x
                canvas.rubberbandVpY      = vp.y
                canvas.rubberbandRect     = null
                canvas.verschiebenErlaubt = false
            } else if (ctrlGehalten) {
                canvas.ausgewaehltVerbindung = null
                var sel = canvas.auswahl.slice()
                var pos = sel.indexOf(idx)
                if (pos >= 0) sel.splice(pos, 1)
                else          sel.push(idx)
                canvas.auswahl            = sel
                canvas.verschiebenErlaubt = false
            } else if (canvas.auswahl.indexOf(idx) >= 0) {
                canvas.ausgewaehltVerbindung = null
                canvas.verschiebenErlaubt  = true
                canvas.amVerschieben       = false
                canvas.verschiebenMausVpX  = vp.x
                canvas.verschiebenMausVpY  = vp.y
                canvas.verschiebenStartPos = canvas.auswahl.map(function(si) {
                    var e   = em.element(si)
                    var snap = { x1: e.x1, y1: e.y1, x2: e.x2, y2: e.y2 }
                    if (e.typ === "polygonlinie" && e.punkte) snap.punkte = JSON.parse(JSON.stringify(e.punkte))
                    return snap
                })
                var elV = em.element(idx)
                canvas.verschiebenStartX1 = elV.x1; canvas.verschiebenStartY1 = elV.y1
                canvas.verschiebenStartX2 = elV.x2; canvas.verschiebenStartY2 = elV.y2
                canvas.schnapshotVorMove  = em.snapshot()
            } else {
                canvas.ausgewaehltVerbindung = null
                canvas.auswahl            = [idx]
                canvas.verschiebenErlaubt = false
            }
            canvas.neuZeichnen()

        } else if (canvas.aktivesWerkzeug === "symbol" && canvas.paletteSymbolId !== "") {
            var wSym = toWelt(mouse.x, mouse.y)
            var prev = canvas.symbolVorschauErstellen(wSym.x, wSym.y)
            var elSym = {
                typ:            "symbol",
                x1: prev.x1, y1: prev.y1, x2: prev.x2, y2: prev.y2,
                symbolId:       canvas.paletteSymbolId,
                rotation:       canvas.paletteSymbolRotation,
                spiegelX:       false, spiegelY: false,
                extraDaten:     JSON.parse(JSON.stringify(canvas.paletteExtraDaten)),
                strichFarbe:    canvas.stilVorlage.strichFarbe,
                strichBreite:   canvas.stilVorlage.strichBreite,
                strichArt:      canvas.stilVorlage.strichArt,
                fuell:          false,
                fuellFarbe:     canvas.stilVorlage.fuellFarbe,
                fuellOpazitaet: canvas.stilVorlage.fuellOpazitaet,
                opazitaet:      canvas.stilVorlage.opazitaet,
                eckenRadius:    0
            }
            canvas.aktionAusfuehren(em.snapshot().concat([elSym]))
            canvas.aktivesWerkzeug = "zeiger"
            var newIdxSym = em.anzahl - 1
            canvas.auswahl         = [newIdxSym]
            var vprSym = toViewport(mouse.x, mouse.y)
            var newElSym = em.element(newIdxSym)
            canvas.amVerschieben       = false
            canvas.verschiebenMausVpX  = vprSym.x
            canvas.verschiebenMausVpY  = vprSym.y
            canvas.verschiebenStartX1  = newElSym.x1; canvas.verschiebenStartY1 = newElSym.y1
            canvas.verschiebenStartX2  = newElSym.x2; canvas.verschiebenStartY2 = newElSym.y2
            canvas.verschiebenStartPos = [{ x1: newElSym.x1, y1: newElSym.y1,
                                            x2: newElSym.x2, y2: newElSym.y2 }]
            canvas.schnapshotVorMove   = em.snapshot()
            canvas.vorschau = null
            canvas.neuZeichnen()

        } else if (canvas.aktivesWerkzeug === "bild" && canvas.paletteImageData !== "") {
            var wBild = toWelt(mouse.x, mouse.y)
            var bW2 = canvas.gridPx * 8; var bH2 = canvas.gridPx * 8
            var elBild = {
                typ:            "bild",
                x1:             wBild.x - bW2/2,  y1: wBild.y - bH2/2,
                x2:             wBild.x + bW2/2,  y2: wBild.y + bH2/2,
                bildDaten:      canvas.paletteImageData,
                strichFarbe:    canvas.stilVorlage.strichFarbe,
                strichBreite:   canvas.stilVorlage.strichBreite,
                strichArt:      canvas.stilVorlage.strichArt,
                fuell:          false,  fuellFarbe: "#000000", fuellOpazitaet: 0,
                opazitaet:      1.0,    eckenRadius: 0,
                rotation:          0,  spiegelX: false, spiegelY: false,
                proportional:      false,
                ausschnittLinks:   0, ausschnittRechts: 0,
                ausschnittOben:    0, ausschnittUnten:  0
            }
            canvas.aktionAusfuehren(em.snapshot().concat([elBild]))
            canvas.aktivesWerkzeug = "zeiger"
            var newIdxBild = em.anzahl - 1
            canvas.auswahl         = [newIdxBild]
            var vprBild = toViewport(mouse.x, mouse.y)
            var newElBild = em.element(newIdxBild)
            canvas.amVerschieben       = false
            canvas.verschiebenMausVpX  = vprBild.x
            canvas.verschiebenMausVpY  = vprBild.y
            canvas.verschiebenStartX1  = newElBild.x1; canvas.verschiebenStartY1 = newElBild.y1
            canvas.verschiebenStartX2  = newElBild.x2; canvas.verschiebenStartY2 = newElBild.y2
            canvas.verschiebenStartPos = [{ x1: newElBild.x1, y1: newElBild.y1,
                                            x2: newElBild.x2, y2: newElBild.y2 }]
            canvas.schnapshotVorMove   = em.snapshot()
            canvas.vorschau = null
            canvas.neuZeichnen()

        } else if (canvas.aktivesWerkzeug === "duplizieren" && canvas.duplizierVorlage) {
            var wDup = toWelt(mouse.x, mouse.y)
            var elsDup = canvas.duplizierVorlage
            var mnX = elsDup[0].x1, mnY = elsDup[0].y1, mxX = elsDup[0].x2, mxY = elsDup[0].y2
            for (var di = 1; di < elsDup.length; di++) {
                if (elsDup[di].x1 < mnX) mnX = elsDup[di].x1
                if (elsDup[di].y1 < mnY) mnY = elsDup[di].y1
                if (elsDup[di].x2 > mxX) mxX = elsDup[di].x2
                if (elsDup[di].y2 > mxY) mxY = elsDup[di].y2
            }
            canvas._duplizierAnzahlAnfordern(wDup.x - (mnX + mxX) / 2, wDup.y - (mnY + mxY) / 2)

        } else if (canvas.aktivesWerkzeug === "makroEinfuegen" && canvas.makroEinfuegenId > 0) {
            var wMk = toWelt(mouse.x, mouse.y)
            var newElIds = db.makroElementeEinfuegen(canvas.makroEinfuegenId, canvas.seiteId, wMk.x, wMk.y)
            if (newElIds.length > 0) {
                canvas.elementeModel.laden(canvas.seiteId)
                canvas.grafikSpeichernJetzt()
            }
            canvas.aktivesWerkzeug    = "zeiger"
            canvas.makroEinfuegenId   = 0
            canvas.makroEinfuegenName = ""
            canvas.vorschau = null
            canvas.neuZeichnen()

        } else if (canvas.aktivesWerkzeug === "text") {
            var wTxt = toWelt(mouse.x, mouse.y)
            var rTxt = canvas.rastend ? canvas.rasterPunkt(wTxt.x, wTxt.y) : wTxt
            canvas.textEditorNeuOeffnen(mouse.x, mouse.y, rTxt.x, rTxt.y)

        } else if (canvas.aktivesWerkzeug === "polygonlinie") {
            var wPoly = toWelt(mouse.x, mouse.y)
            var rPoly = canvas.rastend ? canvas.rasterPunkt(wPoly.x, wPoly.y) : wPoly
            canvas.polyPunkte    = canvas.polyPunkte.concat([{ x: rPoly.x, y: rPoly.y }])
            canvas.amPolyZeichnen = true
            canvas.polyCursorWelt = rPoly
            canvas.neuZeichnen()

        } else {
            // Zeichnen starten (linie, rechteck, kreis, geraetekasten, strukturkasten, …)
            var wZ = toWelt(mouse.x, mouse.y)
            canvas.zeichenStartX = wZ.x; canvas.zeichenStartY = wZ.y
            canvas.amZeichnen    = true
            canvas.vorschau      = { typ: canvas.aktivesWerkzeug,
                                     x1: wZ.x, y1: wZ.y, x2: wZ.x, y2: wZ.y }
            canvas.neuZeichnen()
        }
    }

    onReleased: function(mouse) {
        var em = canvas.elementeModel
        if (canvas.aktivesWerkzeug === "zeiger") {

            // Rubber-Band abschließen
            if (canvas.amRubberband) {
                canvas.amRubberband = false
                var rb = canvas.rubberbandRect
                if (rb && (Math.abs(rb.x2 - rb.x1) > 5 || Math.abs(rb.y2 - rb.y1) > 5)) {
                    var rx1 = Math.min(rb.x1, rb.x2), ry1 = Math.min(rb.y1, rb.y2)
                    var rx2 = Math.max(rb.x1, rb.x2), ry2 = Math.max(rb.y1, rb.y2)
                    var gefunden = []
                    var _rbEls = em.snapshot()
                    for (var ri = 0; ri < _rbEls.length; ri++) {
                        var re = _rbEls[ri]
                        var ex1 = Math.min(re.x1, re.x2) * canvas.zoom + canvas.worldX
                        var ey1 = Math.min(re.y1, re.y2) * canvas.zoom + canvas.worldY
                        var ex2 = Math.max(re.x1, re.x2) * canvas.zoom + canvas.worldX
                        var ey2 = Math.max(re.y1, re.y2) * canvas.zoom + canvas.worldY
                        if (ex1 >= rx1 && ey1 >= ry1 && ex2 <= rx2 && ey2 <= ry2)
                            gefunden.push(ri)
                    }
                    canvas.auswahl = gefunden
                }
                canvas.rubberbandRect = null
                canvas.neuZeichnen()
                return
            }

            // Griff losgelassen
            if (canvas.aktiverGriff >= 0) {
                em.undoCheckpointFromSnapshot(canvas.schnapshotVorMove)
                canvas.aktiverGriff = -1
                if (canvas.ausgewaehlt >= 0 && canvas.ausgewaehlt < em.anzahl) {
                    var rEl = em.element(canvas.ausgewaehlt)
                    var vpR = toViewport(mouse.x, mouse.y)
                    canvas.verschiebenMausVpX  = vpR.x
                    canvas.verschiebenMausVpY  = vpR.y
                    canvas.verschiebenStartX1  = rEl.x1; canvas.verschiebenStartY1 = rEl.y1
                    canvas.verschiebenStartX2  = rEl.x2; canvas.verschiebenStartY2 = rEl.y2
                    canvas.verschiebenStartPos = [{ x1: rEl.x1, y1: rEl.y1,
                                                    x2: rEl.x2, y2: rEl.y2 }]
                    canvas.schnapshotVorMove   = em.snapshot()
                    canvas.verschiebenErlaubt  = false
                }
                canvas.grafikSpeichernJetzt()
                return
            }
            if (canvas.amVerschieben) {
                em.undoCheckpointFromSnapshot(canvas.schnapshotVorMove)
                canvas.amVerschieben = false
                canvas.grafikSpeichernJetzt()
            }
            canvas.verschiebenErlaubt = false
            return
        }

        if (!canvas.amZeichnen) return
        var wR = toWelt(mouse.x, mouse.y)
        var elR = Object.assign(
            { typ: canvas.aktivesWerkzeug,
              x1: canvas.zeichenStartX, y1: canvas.zeichenStartY,
              x2: wR.x, y2: wR.y },
            canvas.stilVorlage)
        // Bei Klick ohne Drag: Standard-Größe einsetzen
        if (Math.abs(elR.x2-elR.x1) <= 0.5 && Math.abs(elR.y2-elR.y1) <= 0.5) {
            var defS = canvas.gridPx * 2
            if      (elR.typ === "linie")         { elR.x2 = elR.x1 + defS;       elR.y2 = elR.y1 }
            else if (elR.typ === "rechteck")       { elR.x2 = elR.x1 + defS;       elR.y2 = elR.y1 + defS }
            else if (elR.typ === "kreis")          { elR.x2 = elR.x1 + defS / 2;   elR.y2 = elR.y1 }
            else if (elR.typ === "geraetekasten")  { elR.x2 = elR.x1 + defS * 3;   elR.y2 = elR.y1 + defS * 2 }
            else if (elR.typ === "strukturkasten") { elR.x2 = elR.x1 + defS * 5;   elR.y2 = elR.y1 + defS * 4 }
            else if (elR.typ === "makrokasten")    { elR.x2 = elR.x1 + defS * 5;   elR.y2 = elR.y1 + defS * 4 }
            else if (elR.typ === "notiz")          { elR.x2 = elR.x1 + defS * 4;   elR.y2 = elR.y1 + defS * 3 }
        }
        // Starteigenschaften nach Element-Typ
        if (elR.typ === "geraetekasten") {
            elR.strichFarbe = "#cc7700"; elR.fuell = true
            elR.fuellFarbe = "#331a00"; elR.fuellOpazitaet = 0.15
            elR.extraDaten = { bmk: "", bezeichnung: "" }
        } else if (elR.typ === "strukturkasten") {
            elR.strichFarbe = "#00aacc"; elR.fuell = false
            elR.extraDaten  = { bezeichnung: "", anlage: "", ort: "", anlageUO: "", ortUO: "" }
        } else if (elR.typ === "kabellinie") {
            elR.strichFarbe = "#e07000"
            elR.extraDaten  = { bezeichnung: "", kabeltyp: "", aderzahl: 0, querschnittMm2: 0 }
        } else if (elR.typ === "makrokasten") {
            elR.strichFarbe = "#aa44cc"; elR.fuell = false
            elR.extraDaten  = { name: "", beschreibung: "", kategorie: "", makroId: 0 }
        } else if (elR.typ === "notiz") {
            elR.strichFarbe = "#cccc22"; elR.fuell = true
            elR.fuellFarbe  = "#1a1a00"; elR.fuellOpazitaet = 0.9
            elR.strichBreite = 3.0; elR.textInhalt = "Notiz"
        }
        canvas.aktionAusfuehren(em.snapshot().concat([elR]))
        canvas.aktivesWerkzeug = "zeiger"
        var newIdx = em.anzahl - 1
        canvas.auswahl = [newIdx]
        var vprR    = toViewport(mouse.x, mouse.y)
        var newElR  = em.element(newIdx)
        canvas.amVerschieben       = false
        canvas.verschiebenMausVpX  = vprR.x
        canvas.verschiebenMausVpY  = vprR.y
        canvas.verschiebenStartX1  = newElR.x1; canvas.verschiebenStartY1 = newElR.y1
        canvas.verschiebenStartX2  = newElR.x2; canvas.verschiebenStartY2 = newElR.y2
        canvas.verschiebenStartPos = [{ x1: newElR.x1, y1: newElR.y1,
                                        x2: newElR.x2, y2: newElR.y2 }]
        canvas.schnapshotVorMove   = em.snapshot()
        canvas.vorschau = null; canvas.amZeichnen = false
        canvas.verschiebenErlaubt = false
        canvas.neuZeichnen()
        if (elR.typ === "kabellinie") canvas.kabellinieDialogFuerNeuOeffnen(newIdx)
        if (elR.typ === "makrokasten") canvas.makrobenennDialogFuerNeuOeffnen(newIdx)
    }

    onDoubleClicked: function(mouse) {
        var em = canvas.elementeModel
        // Polygonlinie abschließen
        if (canvas.aktivesWerkzeug === "polygonlinie" && canvas.amPolyZeichnen) {
            var pts = canvas.polyPunkte.slice()
            if (pts.length >= 1) pts = pts.slice(0, pts.length - 1)
            if (pts.length >= 2) {
                var minX = pts[0].x, minY = pts[0].y, maxX = pts[0].x, maxY = pts[0].y
                for (var bi = 1; bi < pts.length; bi++) {
                    if (pts[bi].x < minX) minX = pts[bi].x
                    if (pts[bi].y < minY) minY = pts[bi].y
                    if (pts[bi].x > maxX) maxX = pts[bi].x
                    if (pts[bi].y > maxY) maxY = pts[bi].y
                }
                var elPoly = Object.assign(
                    { typ: "polygonlinie", punkte: pts,
                      x1: minX, y1: minY, x2: maxX, y2: maxY },
                    canvas.stilVorlage)
                canvas.aktionAusfuehren(em.snapshot().concat([elPoly]))
                canvas.auswahl = [em.anzahl - 1]
            }
            canvas.amPolyZeichnen  = false
            canvas.polyPunkte      = []
            canvas.polyCursorWelt  = null
            canvas.aktivesWerkzeug = "zeiger"
            canvas.neuZeichnen()
            return
        }
        if (canvas.aktivesWerkzeug !== "zeiger") return
        var vp  = toViewport(mouse.x, mouse.y)
        var idx = canvas.elementBeiPosition(vp.x, vp.y)
        if (idx < 0) return

        var hit = em.element(idx)
        if (hit.typ === "symbol" && hit.symbolId === "querverweis") {
            canvas.auswahl = [idx]
            canvas.querverweisZurGegenseiteNavigieren()
            return
        }
        if (hit.typ !== "text" && hit.typ !== "notiz") return
        canvas.textEditorBestehendesOeffnen(idx)
    }
}
