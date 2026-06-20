import QtQuick
import stroemling
import "../components"

// Kabel-, Aderzuordnungs- und Makro-Dialoge des SchaltplanCanvas.
// Kommuniziert ausschließlich über `canvas` (SchaltplanCanvas-Referenz).
Item {
    id: root

    required property var canvas
    required property var theme
    required property bool debug

    property int _letzterBauteilKabelId: 0   // CE-12: letzter verwendeter Kabeltyp

    // ── Kabellinie-Dialog öffnen (Aufruf via canvas.kabellinieDialogFuerNeuOeffnen) ──
    function kabellinieNeuOeffnen(elIdx) {
        kabellinieDialog.elementIndex       = elIdx
        kabellinieDialog.bezeichnung        = "";  kabellinieDialog.kabeltyp       = ""
        kabellinieDialog.aderzahl           = 0;   kabellinieDialog.querschnittMm2 = 0
        kabellinieDialog.bauteilKabelId     = root._letzterBauteilKabelId
        kabellinieDialog.vonOrt             = "";  kabellinieDialog.nachOrt        = ""
        kabellinieDialog.bestehendesKabelId = 0
        kabellinieDialog.vorhandeneKabel    = (canvas.projektId >= 0) ? db.kabelListe(canvas.projektId) : []
        kabellinieDialog.open()
    }

    // ── Aderzuordnungsdialog öffnen (Aufruf via canvas.aderzuordnungDialogOeffnen) ──
    function aderzuordnungOeffnen(kabelId, kabelBezeichnung, kabeltyp, aderzahl, adern,
                                   schnittNetze, aderZuordnung,
                                   kabellinieGrafikElementId, pinNummernMap) {
        aderzuordnungDialog.kabelId                   = kabelId
        aderzuordnungDialog.kabelBezeichnung          = kabelBezeichnung
        aderzuordnungDialog.kabeltyp                  = kabeltyp
        aderzuordnungDialog.aderzahl                  = aderzahl
        aderzuordnungDialog.adern                     = adern
        aderzuordnungDialog.schnittNetze              = schnittNetze
        aderzuordnungDialog.aderZuordnung             = aderZuordnung
        aderzuordnungDialog.kabellinieGrafikElementId = kabellinieGrafikElementId
        aderzuordnungDialog.pinNummernMap             = pinNummernMap
        aderzuordnungDialog.open()
    }

    // ── Inline-Ader-Picker öffnen (Aufruf via canvas.aderKreuzungPickerOeffnen) ──
    // vpX/vpY sind Canvas-lokale Viewport-Koordinaten – das Popup hängt an
    // Overlay.overlay, deshalb auf Szenen-Koordinaten umrechnen (gleiche
    // mapToItem(null, ...)-Konvention wie in MakroPalette.qml).
    function aderKreuzungPickerOeffnen(kabelId, kabelGeid, aderKey, verbindungId,
                                        aktuelleAderNr, istLeer, alteAder, freieAdern,
                                        vpX, vpY) {
        var p = canvas.mapToItem(null, vpX, vpY)
        aderKreuzungPicker.oeffnen(kabelId, kabelGeid, aderKey, verbindungId,
            aktuelleAderNr, istLeer, alteAder, freieAdern, p.x, p.y)
    }

    // ── Makrobenennen-Dialog öffnen (Aufruf via canvas.makrobenennDialogFuerNeuOeffnen) ──
    function makrobenennNeuOeffnen(elIdx) {
        makrobenennDialog.elementIndex = elIdx
        makrobenennDialog.open()
    }

    // ── Kabellinie-Dialog ─────────────────────────────────────────────────
    KabellinieDialog {
        id:        kabellinieDialog
        theme:     root.theme
        debug:     root.debug
        projektId: root.canvas.projektId

        onAccepted: {
            if (kabellinieDialog.bauteilKabelId > 0)
                root._letzterBauteilKabelId = kabellinieDialog.bauteilKabelId
            var idx = elementIndex
            if (idx < 0 || idx >= elementeModel.anzahl) return
            var el = Object.assign({}, elementeModel.element(idx))
            var savedX1 = el.x1, savedY1 = el.y1
            el.extraDaten = {
                bezeichnung:    kabellinieDialog.bezeichnung,
                kabeltyp:       kabellinieDialog.kabeltyp,
                aderzahl:       kabellinieDialog.aderzahl,
                querschnittMm2: kabellinieDialog.querschnittMm2,
                bauteilKabelId: kabellinieDialog.bauteilKabelId,
                vonOrt:         kabellinieDialog.vonOrt,
                nachOrt:        kabellinieDialog.nachOrt
            }
            elementeModel.eigenschaftSetzen(idx, "extraDaten", el.extraDaten)
            canvas.grafikSpeichernJetzt()
            elementeModel.laden(canvas.seiteId)
            var reloaded = elementeModel.snapshot()
            for (var ri = 0; ri < reloaded.length; ri++) {
                var re = reloaded[ri]
                if (re.typ === "kabellinie"
                        && Math.abs(re.x1 - savedX1) < 0.01
                        && Math.abs(re.y1 - savedY1) < 0.01) {
                    if (canvas.projektId < 0) break

                    var newKabelId = 0
                    var bkAdern   = []

                    if (kabellinieDialog.bestehendesKabelId > 0) {
                        newKabelId = kabellinieDialog.bestehendesKabelId
                        if (kabellinieDialog.vonOrt || kabellinieDialog.nachOrt) {
                            db.kabelMetaAktualisieren(newKabelId,
                                kabellinieDialog.bezeichnung,
                                kabellinieDialog.kabeltyp,
                                kabellinieDialog.aderzahl,
                                kabellinieDialog.querschnittMm2,
                                kabellinieDialog.vonOrt,
                                kabellinieDialog.nachOrt)
                        }
                        var existDetails = db.kabelLinieDetails(re.id || 0)
                        bkAdern = existDetails.adern || []
                    } else {
                        newKabelId = db.kabelAnlegen(canvas.projektId,
                                        kabellinieDialog.bezeichnung,
                                        kabellinieDialog.kabeltyp,
                                        kabellinieDialog.aderzahl,
                                        kabellinieDialog.querschnittMm2,
                                        re.id || 0,
                                        kabellinieDialog.vonOrt,
                                        kabellinieDialog.nachOrt)
                        if (newKabelId > 0 && kabellinieDialog.bauteilKabelId > 0) {
                            var bkMeta = db.kabelBauteilKabelSetzen(newKabelId, kabellinieDialog.bauteilKabelId)
                            bkAdern = bkMeta.adern || []
                        }
                    }

                    if (newKabelId > 0) {
                        var el2 = Object.assign({}, elementeModel.element(ri))
                        el2.extraDaten = Object.assign({}, el2.extraDaten || {})
                        el2.extraDaten.kabelId = newKabelId
                        if (bkAdern.length > 0) el2.extraDaten.adern = bkAdern
                        elementeModel.eigenschaftSetzen(ri, "extraDaten", el2.extraDaten)
                        canvas.grafikSpeichernJetzt()
                        canvas.kabelLinienCacheAktualisieren()

                        elementeModel.laden(canvas.seiteId)
                        var freshReloaded = elementeModel.snapshot()

                        var freshKlEl = null
                        for (var fi = 0; fi < freshReloaded.length; fi++) {
                            var fe = freshReloaded[fi]
                            if (fe.typ === "kabellinie" && fe.extraDaten
                                    && fe.extraDaten.kabelId === newKabelId) {
                                freshKlEl = fe; break
                            }
                        }

                        if (freshKlEl) {
                            canvas.kabellinieNachSpeichernAderZuordnung(
                                newKabelId,
                                kabellinieDialog.bezeichnung,
                                kabellinieDialog.kabeltyp,
                                kabellinieDialog.aderzahl,
                                bkAdern,
                                freshKlEl)
                        }
                    }
                    break
                }
            }
            canvas.neuZeichnen()
        }

        onRejected: {
            var idx = elementIndex
            if (idx >= 0 && idx < elementeModel.anzahl) {
                var cleaned = elementeModel.snapshot()
                cleaned.splice(idx, 1)
                canvas.aktionAusfuehren(cleaned)
                canvas.neuZeichnen()
            }
        }
    }

    // ── Aderzuordnungs-Dialog ─────────────────────────────────────────────
    AderzuordnungDialog {
        id:    aderzuordnungDialog
        theme: root.theme
        debug: root.debug

        onAccepted: canvas.neuZeichnen()

        onZuordnungGespeichert: function(netKeyMap) {
            var idx = canvas.ausgewaehlt
            if (idx < 0 || idx >= elementeModel.anzahl)
                return
            var el = elementeModel.element(idx)
            if (!el || el.typ !== "kabellinie")
                return
            var el2 = Object.assign({}, el)
            el2.extraDaten = Object.assign({}, el2.extraDaten || {})
            el2.extraDaten.aderZuordnung = netKeyMap
            elementeModel.eigenschaftSetzen(idx, "extraDaten", el2.extraDaten)
            canvas.grafikSpeichernJetzt()
            canvas.kabelLinienCacheAktualisieren()
            elementeModel.laden(canvas.seiteId)
            canvas.verdrahtungswegeAktualisieren()
        }
    }

    // ── Inline-Ader-Picker (Canvas-Redesign §6.5.2) ─────────────────────────
    AderKreuzungPicker {
        id:    aderKreuzungPicker
        theme: root.theme

        onAderZugewiesen: function(kabelId, kabelGeid, aderKey, verbindungId,
                                    neueNr, neueFarbe, neueBezeichnung,
                                    alteNr, alteFarbe, alteBezeichnung) {
            var idx = -1
            for (var i = 0; i < elementeModel.anzahl; i++) {
                var e = elementeModel.element(i)
                if (e && e.typ === "kabellinie" && (e.id || 0) === kabelGeid) { idx = i; break }
            }
            if (idx < 0) return

            var el2 = Object.assign({}, elementeModel.element(idx))
            el2.extraDaten = Object.assign({}, el2.extraDaten || {})
            el2.extraDaten.aderZuordnung = Object.assign({}, el2.extraDaten.aderZuordnung || {})
            el2.extraDaten.aderZuordnung[aderKey] = neueNr
            elementeModel.eigenschaftSetzen(idx, "extraDaten", el2.extraDaten)

            // Alte Ader (falls abweichend) freigeben, neue Ader zuordnen
            if (alteNr > 0 && alteNr !== neueNr)
                db.kabelAderZuordnen(kabelId, alteNr, alteFarbe, alteBezeichnung, 0, 0)
            if (neueNr > 0)
                db.kabelAderZuordnen(kabelId, neueNr, neueFarbe, neueBezeichnung,
                                      verbindungId, kabelGeid)

            canvas.grafikSpeichernJetzt()
            canvas.kabelLinienCacheAktualisieren()
            elementeModel.laden(canvas.seiteId)
            canvas.verdrahtungswegeAktualisieren()
            canvas.neuZeichnen()
        }
    }

    // ── Makrokasten-Dialog ────────────────────────────────────────────────
    MakrobenennDialog {
        id:    makrobenennDialog
        theme: root.theme

        property int elementIndex: -1

        onAccepted: {
            var idx = elementIndex
            if (idx < 0 || idx >= elementeModel.anzahl) return
            var snap = elementeModel.snapshot()
            var el = Object.assign({}, snap[idx])
            el.extraDaten = {
                name:         makrobenennDialog.name,
                beschreibung: makrobenennDialog.beschreibung,
                kategorie:    makrobenennDialog.kategorie,
                makroId:      0
            }
            snap[idx] = el
            canvas.aktionAusfuehren(snap)
            canvas.grafikSpeichernJetzt()
            // grafikSpeichern macht DELETE+INSERT → alle DB-IDs ändern sich; neu laden für frische IDs
            elementeModel.laden(canvas.seiteId)

            var savedEl = elementeModel.element(idx)
            if (savedEl && (savedEl.id || 0) > 0) {
                var newMakroId = db.makroSpeichern(savedEl.id, canvas.seiteId)
                if (newMakroId > 0) {
                    // Nach makroSpeichern extra_daten.makroId aus DB holen
                    elementeModel.laden(canvas.seiteId)
                    canvas.makroListeGeaendert()
                    canvas.neuZeichnen()
                }
            }
        }

        onRejected: {
            var idx = elementIndex
            if (idx >= 0 && idx < elementeModel.anzahl) {
                var updated = elementeModel.snapshot()
                updated.splice(idx, 1)
                canvas.aktionAusfuehren(updated)
                canvas.grafikSpeichernJetzt()
            }
            canvas.auswahl = []
        }
    }

    DebugLabel { panelName: qsTr("Canvas-Dialog-Layer"); visible: root.debug }
}
