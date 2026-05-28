import QtQuick
import QtQuick.Controls

// Text-Editor-Overlay des SchaltplanCanvas.
// Zeigt ein schwebendes Eingabefeld an der Cursor-Position.
// Kommuniziert ausschließlich über `canvas` (SchaltplanCanvas-Referenz).
Rectangle {
    id: root

    required property var canvas
    required property var theme

    visible:      canvas.textEditAktiv && canvas.seiteId >= 0
    x:            canvas.textEditVpX - 4
    y:            canvas.textEditVpY - 4
    z:            200
    color:        theme.sidebar
    border.color: theme.accent
    border.width: 1
    radius:       2

    width:  Math.max(120, textEditor.implicitWidth + 16)
    height: textEditor.implicitHeight + 10

    // Öffnet den Editor mit dem gegebenen Text.
    // alleAuswaehlen = true wenn vorhandenes Element bearbeitet wird.
    function oeffnen(text, alleAuswaehlen) {
        textEditor.text = text
        textEditor.forceActiveFocus()
        if (alleAuswaehlen) textEditor.selectAll()
    }

    function textBboxBerechnen(inhalt, strichBreite) {
        var lines = inhalt.split("\n")
        var longestLen = 1
        for (var li = 0; li < lines.length; li++)
            if (lines[li].length > longestLen) longestLen = lines[li].length
        var fsPx = (strichBreite || 3.5) * canvas.mmToPx
        return { w: longestLen * fsPx * 0.62, h: lines.length * fsPx * 1.3 }
    }

    function textBboxAktualisieren() {
        if (!canvas.textEditAktiv) return
        var inhalt = textEditor.text.replace(/^\n+|\n+$/g, "").trim()

        if (canvas.textEditElIdx >= 0) {
            var idx = canvas.textEditElIdx
            var el  = canvas.elementeModel.element(idx)
            if (el.textEinpassen) return
            if (el.typ === "notiz") return

            var updEl = {}; for (var k in el) updEl[k] = el[k]
            if (inhalt !== "") {
                var bb = textBboxBerechnen(inhalt, el.strichBreite)
                updEl.x2 = updEl.x1 + bb.w
                updEl.y2 = updEl.y1 + bb.h
            }
            updEl.textInhalt = inhalt
            canvas.elementeModel.elementAktualisieren(idx, updEl)
            canvas.neuZeichnen()
        } else {
            if (inhalt === "") {
                canvas.vorschau = null
            } else {
                var bb2 = textBboxBerechnen(inhalt, canvas.stilVorlage.strichBreite)
                canvas.vorschau = {
                    typ:             "text",
                    x1:              canvas.textEditWeltX,
                    y1:              canvas.textEditWeltY,
                    x2:              canvas.textEditWeltX + bb2.w,
                    y2:              canvas.textEditWeltY + bb2.h,
                    textInhalt:      inhalt,
                    textAusrichtung: "links",
                    textEinpassen:   false,
                    rotation:        0,
                    strichFarbe:     canvas.stilVorlage.strichFarbe,
                    strichBreite:    canvas.stilVorlage.strichBreite,
                    strichArt:       "solid",
                    fuell:           false,
                    fuellFarbe:      canvas.stilVorlage.fuellFarbe,
                    fuellOpazitaet:  canvas.stilVorlage.fuellOpazitaet,
                    opazitaet:       canvas.stilVorlage.opazitaet,
                    eckenRadius:     0
                }
            }
            canvas.neuZeichnen()
        }
    }

    function bestaetigen() {
        if (!canvas.textEditAktiv) return
        var inhalt = textEditor.text.replace(/^\n+|\n+$/g, "").trim()
        canvas.textEditAktiv = false
        canvas.vorschau      = null

        if (inhalt === "") {
            if (canvas.textEditElIdx >= 0 && canvas.textEditSnapshot)
                canvas.elementeModel.fromVariantList(canvas.textEditSnapshot)
            canvas.neuZeichnen()
            return
        }

        if (canvas.textEditElIdx >= 0) {
            var idx = canvas.textEditElIdx
            canvas.elementeModel.undoCheckpointFromSnapshot(canvas.textEditSnapshot)
            canvas.elementeModel.eigenschaftSetzen(idx, "textInhalt", inhalt)
            canvas.auswahl = [idx]
            canvas.grafikSpeichernJetzt()
        } else {
            var bb = textBboxBerechnen(inhalt, canvas.stilVorlage.strichBreite)
            var textEl = {
                typ:             "text",
                x1:              canvas.textEditWeltX,
                y1:              canvas.textEditWeltY,
                x2:              canvas.textEditWeltX + bb.w,
                y2:              canvas.textEditWeltY + bb.h,
                textInhalt:      inhalt,
                textAusrichtung: "links",
                textEinpassen:   false,
                rotation:        0,
                strichFarbe:     canvas.stilVorlage.strichFarbe,
                strichBreite:    canvas.stilVorlage.strichBreite,
                strichArt:       "solid",
                fuell:           false,
                fuellFarbe:      canvas.stilVorlage.fuellFarbe,
                fuellOpazitaet:  canvas.stilVorlage.fuellOpazitaet,
                opazitaet:       canvas.stilVorlage.opazitaet,
                eckenRadius:     0
            }
            canvas.elementeModel.undoCheckpointFromSnapshot(canvas.textEditSnapshot)
            canvas.elementeModel.fromVariantList(canvas.elementeModel.snapshot().concat([textEl]))
            canvas.auswahl           = [canvas.elementeModel.anzahl - 1]
            canvas.aktivesWerkzeug   = "zeiger"
            canvas.grafikSpeichernJetzt()
        }
        canvas.neuZeichnen()
    }

    function abbrechen() {
        if (canvas.textEditElIdx >= 0 && canvas.textEditSnapshot)
            canvas.elementeModel.fromVariantList(canvas.textEditSnapshot)
        canvas.vorschau      = null
        canvas.textEditAktiv = false
        canvas.neuZeichnen()
    }

    TextEdit {
        id: textEditor
        anchors { fill: parent; margins: 5 }
        color:             theme.textSecondary
        font.pixelSize:    Math.max(10, (canvas.stilVorlage.strichBreite || 3.5) * canvas.mmToPx * canvas.zoom)
        font.bold:         true
        selectionColor:    theme.activeItemAlt
        selectedTextColor: "#ffffff"
        wrapMode:          TextEdit.NoWrap
        focus:             canvas.textEditAktiv

        // Enter = bestätigen | Shift+Enter = Zeilenumbruch
        Keys.onReturnPressed: function(event) {
            if (event.modifiers & Qt.ShiftModifier) {
                event.accepted = false
            } else {
                root.bestaetigen()
                event.accepted = true
            }
        }
        Keys.onEscapePressed: root.abbrechen()
        onActiveFocusChanged: {
            if (!activeFocus && canvas.textEditAktiv) root.bestaetigen()
        }
        onTextChanged: root.textBboxAktualisieren()
    }
}
