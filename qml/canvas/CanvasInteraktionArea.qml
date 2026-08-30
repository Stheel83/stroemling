import QtQuick
import "../SymbolKlassen.js" as SK

// Werkzeug-Zustandsmaschine des SchaltplanCanvas.
// Verarbeitet alle Mausereignisse (Klick, Drag, Release, DoubleClick).
// Setzt Werkzeuge, Auswahl, Verschieben, Rubber-Band, Zeichnen und Platzieren um.
// Kommuniziert ausschließlich über `canvas` (SchaltplanCanvas-Referenz).
MouseArea {
    id: root

    required property var canvas

    property string tooltipText: ""

    // Cursor-naher Tooltip für Klemmenanschlüsse
    Rectangle {
        id: kaTooltip
        visible: false; z: 999
        color: "#1e2233"; radius: 4
        border.color: "#3a4060"; border.width: 1
        width:  ttText.implicitWidth  + 16
        height: ttText.implicitHeight + 10
        Text {
            id: ttText
            anchors.centerIn: parent
            text: root.tooltipText
            font.pixelSize: 11; color: "#c8cfe4"
            lineHeight: 1.4; wrapMode: Text.NoWrap
        }
        Timer {
            id: ttTimer; interval: 700; repeat: false
            onTriggered: kaTooltip.visible = (root.tooltipText !== "")
        }
    }

    enabled:         canvas.seiteId >= 0
    acceptedButtons: Qt.LeftButton
    hoverEnabled:    true
    cursorShape: {
        if (canvas.aktivesWerkzeug !== "zeiger")  return Qt.CrossCursor
        if (canvas.aktiverGriff >= 0)             return Qt.SizeAllCursor
        if (canvas.amVerschieben)                 return Qt.SizeAllCursor
        if (canvas.labelDragAktiv)                return Qt.SizeAllCursor
        if (canvas.mausUeberGriff)                return Qt.SizeAllCursor
        if (canvas.mausUeberAderKreuzung)         return Qt.PointingHandCursor
        if (canvas.mausUeberLabel)                return Qt.SizeAllCursor
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

        // Koordinatenanzeige (Fußzeile): für alle Werkzeuge einheitlich, auch
        // den Zeiger – vorher griff der unbedingte "return" am Ende des
        // Zeiger-Zweigs zu früh, sodass die Anzeige nur beim Zeichnen lief.
        var w = toWelt(mouse.x, mouse.y)
        canvas.koordinatenTextSetzen(
            "X " + Math.round(w.x / canvas.mmToPx) + " mm "
            + "Y " + Math.round(w.y / canvas.mmToPx) + " mm")

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
                           || eg.typ === "schirm" || eg.typ === "notiz") {
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

            // Hover-Cursor: Griff, Label oder Element unter Maus?
            if (!canvas.amVerschieben && !canvas.amRubberband) {
                canvas.mausUeberGriff   = (canvas.griffBeiPosition(vp.x, vp.y) >= 0)
                canvas.mausUeberAderKreuzung = !canvas.mausUeberGriff
                                               && (canvas.kabelKreuzungBeiPosition(vp.x, vp.y) !== null)
                canvas.mausUeberLabel   = !canvas.mausUeberGriff && !canvas.mausUeberAderKreuzung
                                          && (canvas.labelTreffenTest(vp.x, vp.y) >= 0)
                var hIdx = canvas.elementBeiPosition(vp.x, vp.y)
                canvas.mausUeberElement = !canvas.mausUeberGriff && (hIdx >= 0)
                // Tooltip für klemme_anschluss
                if (hIdx >= 0 && !canvas.mausUeberGriff) {
                    var hEl = em.element(hIdx)
                    if (hEl && hEl.typ === "symbol" && hEl.symbolId === "klemme_anschluss") {
                        var hed    = hEl.extraDaten || {}
                        var hBez   = hed.anschlussBezeichnung || ""
                        var hRaw   = hed.bmk || ""
                        var hBase  = (hBez !== "" && hRaw.endsWith(":" + hBez))
                                     ? hRaw.slice(0, hRaw.length - hBez.length - 1) : hRaw
                        var hColon  = hBase.lastIndexOf(":")
                        var hLeiste = hColon >= 0 ? hBase.slice(0, hColon) : hBase
                        var hNr     = hColon >= 0 ? hBase.slice(hColon + 1) : ""
                        var hParts  = []
                        if (hLeiste) hParts.push("Leiste    " + hLeiste)
                        if (hNr)     hParts.push("Klemme    Nr. " + hNr)
                        if (hBez)    hParts.push("Anschluss " + hBez)
                        // Gegenstelle(n) derselben Klemme/Ebene (KLEMMENANSCHLUSS-
                        // PARTNER-01): macht die sonst unsichtbare Verbindung zu
                        // einem einzeln platzierten zweiten Anschluss greifbar.
                        var hPartner = canvas._klemmeAnschlussPartnerMap
                                       ? canvas._klemmeAnschlussPartnerMap[hIdx] : undefined
                        if (hPartner && hPartner.length > 0) {
                            for (var hpi = 0; hpi < hPartner.length; hpi++)
                                hParts.push("↔ " + hPartner[hpi].label)
                        }
                        if (hed.geist === true) hParts.push("⚠ Platzhalter – echten Anschluss direkt darauf setzen")
                        root.tooltipText = hParts.join("\n")
                        kaTooltip.x = mouse.x + 14
                        kaTooltip.y = mouse.y + 14
                        kaTooltip.visible = false
                        ttTimer.restart()
                    } else {
                        root.tooltipText = ""
                        ttTimer.stop(); kaTooltip.visible = false
                    }
                } else {
                    root.tooltipText = ""
                    ttTimer.stop(); kaTooltip.visible = false
                }
            }

            // Label-Drag: Beschriftung live verschieben
            if (canvas.labelDragAktiv && canvas.labelDragIdx >= 0) {
                var ldx = (vp.x - canvas.labelDragMausVpX) / canvas.zoom
                var ldy = (vp.y - canvas.labelDragMausVpY) / canvas.zoom
                var ldEl = em.element(canvas.labelDragIdx)
                var ldEd = Object.assign({}, ldEl.extraDaten || {})
                var ldSid = ldEl.symbolId || ""
                var ldRot = ((ldEl.rotation || 0) % 360 + 360) % 360
                // Potenzial/GA: pin rechts bei 0°, Text links/rechts (waagerecht) oder oben/unten (senkrecht)
                // OX = horizontale Verschiebung, OY = vertikale Verschiebung (intuitiv)
                if (ldSid === "potenzial" || ldSid === "geraeteanschluss") {
                    ldEd.bmkOffsetX = canvas.labelDragStartOx + ldx
                    ldEd.bmkOffsetY = canvas.labelDragStartOy + ldy
                } else {
                    // LABEL-DRAG-BMKSEITE-02: Achsentausch wie im Renderer/Hit-Test
                    // (LABEL-DRAG-BMKSEITE-01) bmk_seite-bewusst bestimmen, nicht nur
                    // aus der Rotation - sonst läuft der Text bei Symbolen mit
                    // bmk_seite='vertikal' (schliesser/oeffner/… bei 0°/180°) beim
                    // Ziehen quer zur Maus, weil CanvasRenderHandler.qml::_renderSymbol()
                    // dort bmkOffsetY als horizontale und bmkOffsetX als vertikale
                    // Verschiebung interpretiert (senkrechter Textblock), der Drag hier
                    // aber unverändert die "normale" Zuordnung schrieb. Klemme_anschluss
                    // & alle anderen Symbole ohne bmk_seite='vertikal' verhalten sich
                    // unverändert (bmkSeite fällt auf "auto" zurück → reiner
                    // Rotations-Tausch wie vorher).
                    var ldSymInfo   = symbolDefinitionModel.symbolInfo(ldSid)
                    var ldBmkSeite  = (ldSymInfo && ldSymInfo.bmkSeite) ? ldSymInfo.bmkSeite : "auto"
                    var ldSenkrecht = ldBmkSeite === "vertikal"
                                      ? (ldRot === 0 || ldRot === 180)
                                      : (ldRot === 90 || ldRot === 270)
                    if (ldSenkrecht) {
                        ldEd.bmkOffsetX = canvas.labelDragStartOx + ldy
                        ldEd.bmkOffsetY = canvas.labelDragStartOy + ldx
                    } else {
                        ldEd.bmkOffsetX = canvas.labelDragStartOx + ldx
                        ldEd.bmkOffsetY = canvas.labelDragStartOy + ldy
                    }
                }
                em.eigenschaftSetzen(canvas.labelDragIdx, "extraDaten", ldEd)
                canvas.neuZeichnen()
                return
            }

            // Element(e) verschieben (nur wenn bereits selektiert + Drag-Schwelle)
            if (canvas.verschiebenErlaubt && canvas.auswahl.length > 0) {
                var dvpX = vp.x - canvas.verschiebenMausVpX
                var dvpY = vp.y - canvas.verschiebenMausVpY

                if (!canvas.amVerschieben && Math.sqrt(dvpX*dvpX + dvpY*dvpY) < 5)
                    return

                canvas.amVerschieben = true

                // Shift+Drag: X/Y-Achsen-Constraint
                if (mouse.modifiers & Qt.ShiftModifier) {
                    if (canvas.axisLock === "" && Math.sqrt(dvpX*dvpX + dvpY*dvpY) >= 10)
                        canvas.axisLock = Math.abs(dvpX) >= Math.abs(dvpY) ? "x" : "y"
                    if (canvas.axisLock === "x") dvpY = 0
                    else if (canvas.axisLock === "y") dvpX = 0
                } else {
                    canvas.axisLock = ""
                }

                var dwX = dvpX / canvas.zoom
                var dwY = dvpY / canvas.zoom

                // Snap: Referenzpunkt (erstes Element) einrasten
                var sp0 = canvas.verschiebenStartPos ? canvas.verschiebenStartPos[0]
                                                     : { x1: canvas.verschiebenStartX1, y1: canvas.verschiebenStartY1 }
                if (canvas.rastend) {
                    var snapEl0  = canvas.auswahl.length > 0 ? em.element(canvas.auswahl[0]) : null
                    var snapOffX = 0, snapOffY = 0
                    // Anker-Pin (nicht x1/y1) einrasten (SYMBOL-ANKER-01) —
                    // deckt den bisherigen aderdefinition-Sonderfall mit ab
                    // (kein Pin registriert → Fallback Bbox-Mittelpunkt,
                    // identisch zum alten Verhalten).
                    if (snapEl0 && snapEl0.typ === "symbol") {
                        var off = canvas.ankerOffsetFuerElement(snapEl0)
                        snapOffX = off.x; snapOffY = off.y
                    }
                    var sn = canvas.rasterPunkt(sp0.x1 + dwX + snapOffX, sp0.y1 + dwY + snapOffY)
                    dwX = sn.x - snapOffX - sp0.x1; dwY = sn.y - snapOffY - sp0.y1
                }

                // Nur die ausgewählten Elemente patchen statt die ganze Seite
                // neu zu bauen (OPT-DRAG-BATCH-01) — bei vielen Elementen pro
                // Seite sonst O(Seitengröße) statt O(Auswahlgröße) pro Mausbewegung.
                var selArr   = canvas.auswahl.slice()
                var startArr = canvas.verschiebenStartPos
                var updates = []
                for (var si = 0; si < selArr.length; si++) {
                    var idx = selArr[si]
                    var elS = em.element(idx)
                    var sp  = startArr ? startArr[si]
                                       : { x1: canvas.verschiebenStartX1, y1: canvas.verschiebenStartY1,
                                           x2: canvas.verschiebenStartX2, y2: canvas.verschiebenStartY2 }
                    var upd2 = { idx: idx,
                                 x1: sp.x1 + dwX, y1: sp.y1 + dwY,
                                 x2: sp.x2 + dwX, y2: sp.y2 + dwY }
                    if (elS.typ === "polygonlinie" && sp.punkte)
                        upd2.punkte = sp.punkte.map(function(p) { return { x: p.x + dwX, y: p.y + dwY } })
                    updates.push(upd2)
                }
                em.elementeAktualisieren(updates)
                canvas.auswahl = selArr
                canvas.neuZeichnen()
            }
            return
        }

        // Zeichenwerkzeug: Vorschau (Koordinatenanzeige läuft bereits oben für alle Werkzeuge)

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
        root.tooltipText = ""
        ttTimer.stop(); kaTooltip.visible = false
        if (canvas.aktivesWerkzeug !== "zeiger") canvas.koordinatenTextSetzen("")
        if (canvas.aktivesWerkzeug === "symbol" || canvas.aktivesWerkzeug === "bild")
            { canvas.vorschau = null; canvas.neuZeichnen() }
        if (canvas.aktivesWerkzeug === "duplizieren")
            { canvas.duplizierVorschau = null; canvas.neuZeichnen() }
    }

    onPressed: function(mouse) {
        canvas.forceActiveFocus()

        // ── Fehlersuchmodus: Klick wählt Startelement ────────
        if (canvas.fehlersuchModus) {
            var fsvp  = toViewport(mouse.x, mouse.y)
            var fsIdx = canvas.elementBeiPosition(fsvp.x, fsvp.y)
            var shift = !!(mouse.modifiers & Qt.ShiftModifier)
            if (fsIdx >= 0) {
                var fsEl = canvas.elementeModel.element(fsIdx)
                canvas.fehlersuchPfadBerechnen(fsEl.id || -1, shift)
            } else if (!shift) {
                // Shift + Klick ins Leere: nichts tun (Pfade bleiben)
                canvas.fehlersuchPfadZuruecksetzen()
            }
            return
        }

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

            // Klick auf Ader-Nr. an Kabel-Kreuzung: Inline-Picker öffnen
            // statt Auswahl/Drag (Canvas-Redesign §6.5.2).
            if ((mouse.modifiers & Qt.ControlModifier) === 0) {
                var kreuzTreffer = canvas.kabelKreuzungBeiPosition(vp.x, vp.y)
                if (kreuzTreffer !== null) {
                    canvas.aderKreuzungPickerOeffnen(kreuzTreffer)
                    return
                }
            }

            var idx = canvas.elementBeiPosition(vp.x, vp.y)

            // Label-Drag: Klick direkt auf BMK-Beschriftung – aber nur, wenn
            // kein präziseres Element (Symbolkörper/Linie/Kastenrand) an
            // dieser Position liegt. labelTreffenTest() hat aus Klickbarkeits-
            // Gründen ein festes Mindestpolster, das bei weit rausgezoomten,
            // eng am Symbol sitzenden BMK-Texten (Default-Offset 0, z.B.
            // "Potenzial") sonst den exakten, nicht gepolsterten Symbolkörper
            // überstimmt (HIT-DETECTION-03) – der Nutzer wollte das Symbol
            // verschieben, traf aber den Text.
            if (idx < 0 && (mouse.modifiers & Qt.ControlModifier) === 0) {
                var labelIdx = canvas.labelTreffenTest(vp.x, vp.y)
                if (labelIdx >= 0) {
                    var lEl = em.element(labelIdx)
                    var lEd = lEl.extraDaten || {}
                    canvas.labelDragAktiv    = true
                    canvas.labelDragIdx      = labelIdx
                    canvas.labelDragMausVpX  = vp.x
                    canvas.labelDragMausVpY  = vp.y
                    canvas.labelDragStartOx  = lEd.bmkOffsetX !== undefined ? lEd.bmkOffsetX : 0
                    var lSid = lEl.symbolId || ""
                    var lTyp = lEl.typ || ""
                    var lIsBox = (lTyp === "geraetekasten" || lTyp === "strukturkasten" || lTyp === "makrokasten")
                    var lDefOy = (lSid === "potenzial" || lSid === "geraeteanschluss" || lSid === "klemme_anschluss" || lIsBox) ? 0 : -14
                    canvas.labelDragStartOy  = lEd.bmkOffsetY !== undefined ? lEd.bmkOffsetY : lDefOy
                    canvas.schnapshotVorMove = em.snapshot()
                    canvas.auswahl = canvas.auswahlFuerElement(labelIdx)
                    canvas.neuZeichnen()
                    return
                }
            }
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
                canvas.auswahl            = canvas.auswahlFuerElement(idx)
                canvas.verschiebenErlaubt = false
            }
            canvas.neuZeichnen()

        } else if (canvas.aktivesWerkzeug === "symbol" && canvas.paletteSymbolId !== "") {
            var wSym = toWelt(mouse.x, mouse.y)
            var prev = canvas.symbolVorschauErstellen(wSym.x, wSym.y)

            // Geist-Erkennung: verknüpfter Klemmenanschluss auf Geist-Platzhalter abgelegt?
            var _geist = null
            var _snap  = em.snapshot()
            if (canvas.paletteSymbolId === "klemme_anschluss"
                    && canvas.paletteExtraDaten
                    && canvas.paletteExtraDaten.platziermodus === "verknuepft") {
                var _ncx = (prev.x1 + prev.x2) / 2, _ncy = (prev.y1 + prev.y2) / 2
                for (var _gi = 0; _gi < _snap.length; _gi++) {
                    var _ge = _snap[_gi]
                    if (_ge.typ !== "symbol" || _ge.symbolId !== "klemme_anschluss") continue
                    if (!(_ge.extraDaten && _ge.extraDaten.geist === true)) continue
                    var _gcx = (_ge.x1 + _ge.x2) / 2, _gcy = (_ge.y1 + _ge.y2) / 2
                    var _tol = Math.max(Math.abs(_ge.x2 - _ge.x1), Math.abs(_ge.y2 - _ge.y1))
                    if (Math.sqrt((_ncx-_gcx)*(_ncx-_gcx) + (_ncy-_gcy)*(_ncy-_gcy)) <= _tol) {
                        _geist = { idx: _gi, el: _ge }; break
                    }
                }
            }

            var elSym = {
                typ:              "symbol",
                x1: _geist ? _geist.el.x1 : prev.x1,
                y1: _geist ? _geist.el.y1 : prev.y1,
                x2: _geist ? _geist.el.x2 : prev.x2,
                y2: _geist ? _geist.el.y2 : prev.y2,
                symbolId:         canvas.paletteSymbolId,
                rotation:         canvas.paletteSymbolRotation,
                spiegelX:         false, spiegelY: false,
                extraDaten:       JSON.parse(JSON.stringify(canvas.paletteExtraDaten)),
                betriebsmittelId: canvas.paletteBetriebsmittelId > 0
                                  ? canvas.paletteBetriebsmittelId : undefined,
                strichFarbe:      canvas.stilVorlage.strichFarbe,
                strichBreite:     canvas.stilVorlage.strichBreite,
                strichArt:        canvas.stilVorlage.strichArt,
                fuell:            false,
                fuellFarbe:       canvas.stilVorlage.fuellFarbe,
                fuellOpazitaet:   canvas.stilVorlage.fuellOpazitaet,
                opazitaet:        canvas.stilVorlage.opazitaet,
                eckenRadius:      0
            }

            // NKZ-05 (konzept/features/07_normkennzeichnung.md §7): automatisches
            // Platzhalter-BMK fuer freihaendig aus der Symbolpalette platzierte
            // Symbole (kein bauteilId - der Bauteil-first-Weg bekommt seinen
            // Vorschlag stattdessen im BMK-Dialog aus bauteil.bmk_vorlage, siehe
            // SchaltplanCanvas.qml bmkNachPlatzierenDialog.onOpened, da dort erst
            // ein echter betriebsmittel-Datensatz angelegt wird). Verbindungs-
            // helfer (SK.istVerbHelper) und bereits vorbelegte BMKs (z.B. aus dem
            // GERAETE-Kontaktworkflow, paletteExtraDaten.bmk) bleiben unberuehrt.
            if (!SK.istVerbHelper(elSym.symbolId) && !elSym.extraDaten.bmk
                    && !(canvas.paletteExtraDaten && canvas.paletteExtraDaten.bauteilId)
                    && canvas.projektId >= 0) {
                var _sinfo = symbolDefinitionModel.symbolInfo(elSym.symbolId)
                var _praefix = (_sinfo && _sinfo.bmkKennbuchstabe) ? _sinfo.bmkKennbuchstabe.trim() : ""
                if (_praefix !== "" && !_praefix.startsWith("-")) _praefix = "-" + _praefix
                if (_praefix !== "") {
                    elSym.extraDaten.bmk          = db.naechsteBmkNummer(canvas.projektId, _praefix)
                    elSym.extraDaten.bmkVorlaeufig = true
                }
            }

            if (_geist) {
                var _ohneGeist = _snap.filter(function(_, i) { return i !== _geist.idx })
                canvas.aktionAusfuehren(_ohneGeist.concat([elSym]))
                meldungManager.zeigen(qsTr("Geist-Anschluss ersetzt – Verdrahtung am neuen Anschluss prüfen."), true)
            } else {
                canvas.aktionAusfuehren(_snap.concat([elSym]))
            }
            achievementManager.ereignis("element_platziert",
                { "typ": "symbol", "elementeAufSeite": em.anzahl })
            if (canvas.paletteSymbolId === "klemme_anschluss"
                    || canvas.paletteBetriebsmittelId > 0
                    || (canvas.paletteExtraDaten && canvas.paletteExtraDaten.bauteilId)
                    || (canvas.paletteExtraDaten && canvas.paletteExtraDaten.platziermodus === "verknuepft")) {
                // Klemmenanschluss, BM-Kontakt, Bauteil, verknüpfter Kontakt (Steckverbinder-
                // Position u.ä.): nur einmal platzierbar → zurück zum Zeiger
                var _bauteilId  = canvas.paletteExtraDaten ? canvas.paletteExtraDaten.bauteilId  : 0
                var _bauteilBez = canvas.paletteExtraDaten ? (canvas.paletteExtraDaten.bezeichnung || "") : ""
                canvas.paletteBetriebsmittelId = 0
                canvas.aktivesWerkzeug = "zeiger"
                canvas.vorschau = null
                if (_bauteilId) {
                    var newElId = db.letzteGrafikElementId(canvas.seiteId)
                    canvas.bauteilNachPlatzierenAusfuehren(newElId, _bauteilBez, _bauteilId)
                }
            } else {
                // CE-03: Symbol-Modus bleibt aktiv – Vorschau für nächste Platzierung neu aufbauen.
                canvas.vorschau = canvas.symbolVorschauErstellen(wSym.x, wSym.y)
            }
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
            var vorMakro = canvas.elementeModel.snapshot()
            var newElIds = db.makroElementeEinfuegen(canvas.makroEinfuegenId, canvas.seiteId, wMk.x, wMk.y)
            if (newElIds.length > 0) {
                canvas.elementeModel.laden(canvas.seiteId)
                canvas.elementeModel.undoCheckpointFromSnapshot(vorMakro)
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

        } else if (["linie","rechteck","kreis","kabellinie"].indexOf(canvas.aktivesWerkzeug) >= 0) {
            // Klick-Bewegen-Klick (wie Polygonlinie), statt Drag-to-draw: erster
            // Klick bestätigt Startpunkt/Mittelpunkt, die Form folgt danach der
            // Maus (onPositionChanged), zweiter Klick bestätigt Endpunkt/Radius.
            // Auf Nutzerwunsch von Rechteck/Kreis (ursprünglich nur Linie) auf
            // dieselbe Interaktion umgestellt, statt Punkt nur per Hover
            // "anzudeuten" und erst Drag-Release zu bestätigen. Kabellinie
            // (KABEL-UEBERARBEITUNG-01 Punkt 4) folgte bis dahin als einzige
            // "linienartige" Form noch dem alten Drag-to-draw-Muster (fiel in
            // den generischen else-Zweig unten) — beim damaligen Umbau
            // offenbar schlicht übersehen.
            var wKk  = toWelt(mouse.x, mouse.y)
            var typKk = canvas.aktivesWerkzeug
            if (!canvas.amZeichnen) {
                canvas.zeichenStartX = wKk.x; canvas.zeichenStartY = wKk.y
                canvas.amZeichnen    = true
                canvas.vorschau      = { typ: typKk, x1: wKk.x, y1: wKk.y, x2: wKk.x, y2: wKk.y }
                canvas.neuZeichnen()
            } else {
                var elKk = Object.assign(
                    { typ: typKk, x1: canvas.zeichenStartX, y1: canvas.zeichenStartY,
                      x2: wKk.x, y2: wKk.y },
                    canvas.stilVorlage)
                // Beide Klicks auf denselben Punkt: Standardgröße statt Nullgröße
                if (Math.abs(elKk.x2-elKk.x1) <= 0.5 && Math.abs(elKk.y2-elKk.y1) <= 0.5) {
                    var defSKk = canvas.gridPx * 2
                    if      (typKk === "linie")      { elKk.x2 = elKk.x1 + defSKk;     elKk.y2 = elKk.y1 }
                    else if (typKk === "rechteck")   { elKk.x2 = elKk.x1 + defSKk;     elKk.y2 = elKk.y1 + defSKk }
                    else if (typKk === "kreis")      { elKk.x2 = elKk.x1 + defSKk / 2; elKk.y2 = elKk.y1 }
                    else if (typKk === "kabellinie") { elKk.x2 = elKk.x1 + defSKk;     elKk.y2 = elKk.y1 }
                }
                if (typKk === "kabellinie") {
                    elKk.strichFarbe = "#e07000"
                    elKk.extraDaten  = { bezeichnung: "", kabeltyp: "", aderzahl: 0, querschnittMm2: 0 }
                }
                canvas.aktionAusfuehren(canvas.elementeModel.snapshot().concat([elKk]))
                canvas.aktivesWerkzeug = "zeiger"
                var newIdxKk = canvas.elementeModel.anzahl - 1
                canvas.auswahl = [newIdxKk]
                canvas.vorschau = null; canvas.amZeichnen = false
                canvas.neuZeichnen()
                if (typKk === "kabellinie") {
                    achievementManager.ereignis("kabel_gezogen")
                    canvas.kabellinieDialogFuerNeuOeffnen(newIdxKk)
                } else {
                    achievementManager.ereignis("element_platziert",
                        { "typ": typKk, "elementeAufSeite": canvas.elementeModel.anzahl })
                }
            }

        } else {
            // Zeichnen starten (geraetekasten, strukturkasten, makrokasten, schirm, …) – Drag-to-draw
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

            // Label-Drag abschließen
            if (canvas.labelDragAktiv) {
                canvas.labelDragAktiv = false
                if (canvas.labelDragIdx >= 0) {
                    em.undoCheckpointFromSnapshot(canvas.schnapshotVorMove)
                    canvas.grafikSpeichernJetzt()
                    canvas.labelDragIdx = -1
                }
                return
            }

            // Rubber-Band abschließen
            // AutoCAD-Konvention: links→rechts gezogen = Fenster (Element muss
            // komplett umschlossen sein), rechts→links gezogen = Schneiden
            // (Überlappung reicht). Richtung anhand x2 < x1 (Endpunkt vs. Startpunkt).
            if (canvas.amRubberband) {
                canvas.amRubberband = false
                var rb = canvas.rubberbandRect
                if (rb && (Math.abs(rb.x2 - rb.x1) > 5 || Math.abs(rb.y2 - rb.y1) > 5)) {
                    var rx1 = Math.min(rb.x1, rb.x2), ry1 = Math.min(rb.y1, rb.y2)
                    var rx2 = Math.max(rb.x1, rb.x2), ry2 = Math.max(rb.y1, rb.y2)
                    var _ueberlappModus = rb.x2 < rb.x1
                    var gefunden = []
                    var _rbEls = em.snapshot()
                    for (var ri = 0; ri < _rbEls.length; ri++) {
                        var re = _rbEls[ri]
                        var ex1 = Math.min(re.x1, re.x2) * canvas.zoom + canvas.worldX
                        var ey1 = Math.min(re.y1, re.y2) * canvas.zoom + canvas.worldY
                        var ex2 = Math.max(re.x1, re.x2) * canvas.zoom + canvas.worldX
                        var ey2 = Math.max(re.y1, re.y2) * canvas.zoom + canvas.worldY
                        var treffer = _ueberlappModus
                            ? (ex1 <= rx2 && ex2 >= rx1 && ey1 <= ry2 && ey2 >= ry1)
                            : (ex1 >= rx1 && ey1 >= ry1 && ex2 <= rx2 && ey2 <= ry2)
                        if (treffer) gefunden.push(ri)
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
                canvas.netzCacheInvalidieren()
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
                canvas.axisLock      = ""
                canvas.netzCacheInvalidieren()
                canvas.grafikSpeichernJetzt()
            }
            canvas.verschiebenErlaubt = false
            return
        }

        // "linie"/"rechteck"/"kreis"/"kabellinie" werden jetzt per
        // Klick-Bewegen-Klick in onPressed abgeschlossen, nicht per
        // Drag-Release (s.o.) – hier nichts tun, sonst würde der erste Klick
        // (press+release ohne Drag) die Form sofort mit Standardgröße
        // fertigstellen, bevor der zweite Klick kommt.
        if (!canvas.amZeichnen || ["linie","rechteck","kreis","kabellinie"].indexOf(canvas.aktivesWerkzeug) >= 0) return
        var wR = toWelt(mouse.x, mouse.y)
        var elR = Object.assign(
            { typ: canvas.aktivesWerkzeug,
              x1: canvas.zeichenStartX, y1: canvas.zeichenStartY,
              x2: wR.x, y2: wR.y },
            canvas.stilVorlage)
        // Bei Klick ohne Drag: Standard-Größe einsetzen
        if (Math.abs(elR.x2-elR.x1) <= 0.5 && Math.abs(elR.y2-elR.y1) <= 0.5) {
            var defS = canvas.gridPx * 2
            if      (elR.typ === "geraetekasten")  { elR.x2 = elR.x1 + defS * 3;   elR.y2 = elR.y1 + defS * 2 }
            else if (elR.typ === "strukturkasten") { elR.x2 = elR.x1 + defS * 5;   elR.y2 = elR.y1 + defS * 4 }
            else if (elR.typ === "makrokasten")    { elR.x2 = elR.x1 + defS * 5;   elR.y2 = elR.y1 + defS * 4 }
            else if (elR.typ === "schirm")         { elR.x2 = elR.x1 + defS * 2;   elR.y2 = elR.y1 + defS }
            else if (elR.typ === "notiz")          { elR.x2 = elR.x1 + defS * 4;   elR.y2 = elR.y1 + defS * 3 }
        }
        // Starteigenschaften nach Element-Typ
        if (elR.typ === "geraetekasten") {
            // GK-1: Teal statt Orange-Braun – kollidierte visuell mit Kabellinie (#e07000)
            elR.strichFarbe = "#0088aa"; elR.strichArt = "gestrichelt"
            elR.fuell = true; elR.fuellFarbe = "#003344"; elR.fuellOpazitaet = 0.15
            elR.extraDaten = { bmk: "", bezeichnung: "" }
        } else if (elR.typ === "strukturkasten") {
            elR.strichFarbe = "#00aacc"; elR.strichArt = "gestrichelt"; elR.fuell = false
            elR.extraDaten  = { bezeichnung: "", anlage: "", ort: "", anlageUO: "", ortUO: "" }
        } else if (elR.typ === "makrokasten") {
            elR.strichFarbe = "#aa44cc"; elR.strichArt = "gestrichelt"; elR.fuell = false
            elR.extraDaten  = { name: "", beschreibung: "", kategorie: "", makroId: 0 }
        } else if (elR.typ === "schirm") {
            elR.strichFarbe = "#888888"; elR.strichArt = "gestrichelt"; elR.fuell = false
            elR.extraDaten  = { bezeichnung: "SH", anschlussSeite: "links", schirmtyp: "" }
        } else if (elR.typ === "notiz") {
            elR.strichFarbe = "#cccc22"; elR.fuell = true
            elR.fuellFarbe  = "#1a1a00"; elR.fuellOpazitaet = 0.9
            elR.textInhalt = "Notiz"
            elR.extraDaten  = { schriftgroesse: canvas.stilVorlage.schriftgroesse || 3.5 }
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
        achievementManager.ereignis("element_platziert",
            { "typ": elR.typ, "elementeAufSeite": em.anzahl })
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
