import QtQuick

Item {
    id: mfRoot

    required property var theme

    property string label:   ""
    property string einheit: ""
    property real   wert:    0
    // ZAHLENFELD-SPINNER-01: Schrittweite/Grenzen für die Hoch/Runter-Buttons.
    // Defaults passen für die bisherigen Aufrufer (X/Y/Breite/Höhe in mm).
    property real   schritt: 1
    property real   minWert: -9999
    property real   maxWert: 9999
    signal wertGeaendert(real wert)

    width: parent.width; height: 28

    function _schrittAnwenden(delta) {
        var v = Math.min(mfRoot.maxWert, Math.max(mfRoot.minWert, mfRoot.wert + delta))
        mfRoot.wertGeaendert(v)
    }

    Row {
        anchors { left: mfRoot.left; leftMargin: 12; verticalCenter: mfRoot.verticalCenter }
        spacing: 8

        Text {
            text: mfRoot.label; width: 56
            color: theme.borderLight; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 64; height: 22; radius: 4
                color: theme.inputBg; border.color: tf.activeFocus ? theme.accent : theme.border

                TextInput {
                    id: tf
                    anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                    color: theme.textSecondary; font.pixelSize: 11; verticalAlignment: TextInput.AlignVCenter
                    validator: DoubleValidator { bottom: -9999; top: 9999; decimals: 1; notation: DoubleValidator.StandardNotation }

                    text: mfRoot.wert.toFixed(1)
                    Binding on text {
                        when: !tf.activeFocus
                        value: mfRoot.wert.toFixed(1)
                    }
                    // BILD-WINKEL-FOKUS-01-Muster: Commit darf nicht am Fokusverlust
                    // hängen (Klicks auf die Spinner-Buttons oder andere EP-Elemente
                    // fordern keinen Tastaturfokus an, editingFinished feuert dann nie).
                    // BILD-WINKEL-DEBOUNCE-01-Muster: trotzdem nicht bei JEDEM
                    // Tastendruck sofort committen – das löst die volle
                    // eigenschaftAktualisieren()-Pipeline (undoCheckpoint +
                    // grafikSpeichernJetzt-DB-Rewrite) reentrant im Sekundentakt aus und
                    // kann beim schnellen Löschen+Neutippen den Fokus mitten in der
                    // Eingabe kosten (nachfolgende Backspace-Tasten lösen dann den
                    // globalen Delete-Shortcut aus statt im Feld zu löschen). Commit
                    // läuft daher entprellt (350 ms nach der letzten Eingabe),
                    // onEditingFinished flusht sofort bei Enter/echtem Fokusverlust.
                    function commitWert() {
                        var v = parseFloat(text)
                        if (!isNaN(v)) mfRoot.wertGeaendert(v)
                    }
                    onTextEdited:      wertCommitTimer.restart()
                    onEditingFinished: { wertCommitTimer.stop(); commitWert() }
                    Keys.onEscapePressed: { wertCommitTimer.stop(); text = mfRoot.wert.toFixed(1); focus = false }

                    Timer { id: wertCommitTimer; interval: 350; onTriggered: tf.commitWert() }
                }
            }

            // Hoch/Runter-Spinner (ZAHLENFELD-SPINNER-01)
            Column {
                width: 14; height: 22
                Rectangle {
                    id: spinUp
                    width: 14; height: 11; radius: 2
                    color: spinUpMa.containsMouse ? theme.hover : theme.inputBg
                    border.color: theme.border
                    Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 6; color: theme.borderLight }
                    MouseArea {
                        id: spinUpMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onPressed:  { mfRoot._schrittAnwenden(mfRoot.schritt); spinRepeat.richtung = 1; spinRepeat.erster = true; spinRepeat.restart() }
                        onReleased: spinRepeat.stop()
                        onExited:   spinRepeat.stop()
                    }
                }
                Rectangle {
                    id: spinDown
                    width: 14; height: 11; radius: 2
                    color: spinDownMa.containsMouse ? theme.hover : theme.inputBg
                    border.color: theme.border
                    Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 6; color: theme.borderLight }
                    MouseArea {
                        id: spinDownMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onPressed:  { mfRoot._schrittAnwenden(-mfRoot.schritt); spinRepeat.richtung = -1; spinRepeat.erster = true; spinRepeat.restart() }
                        onReleased: spinRepeat.stop()
                        onExited:   spinRepeat.stop()
                    }
                }
            }
        }

        Text {
            text: mfRoot.einheit
            color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
        }
    }

    Timer {
        id: spinRepeat
        property int  richtung: 1
        property bool erster:   true
        interval: erster ? 400 : 80
        repeat: true
        onTriggered: { erster = false; mfRoot._schrittAnwenden(mfRoot.schritt * richtung) }
    }
}
