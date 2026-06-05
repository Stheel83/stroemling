import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  panel.auswahlLaenge >= 1 ? fpCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    // panel.formatZaehler ist der AOT-sichere Proxy (wie panel.auswahlLaenge).
    // Direktes Binding auf canvas.X aus required property var heraus funktioniert im AOT-Modus nicht.
    readonly property bool _hatFormat:    panel ? panel.formatZaehler > 0 : false
    readonly property bool _kannKopieren: panel ? panel.auswahlLaenge === 1 : false

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    Column {
        id: fpCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("FORMAT-PINSEL") }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            MiniButton {
                theme: root.theme
                label:   qsTr("Format kopieren")
                tooltip: qsTr("Stilformat des markierten Elements speichern (nur bei Einzelauswahl)")
                breite:  112
                opacity: root._kannKopieren ? 1.0 : 0.4
                onKlick: panel.canvas.formatKopieren()
            }

            MiniButton {
                theme: root.theme
                label:   qsTr("Format zuweisen")
                tooltip: root._hatFormat
                          ? qsTr("Gespeichertes Stilformat auf alle markierten Elemente anwenden")
                          : qsTr("Zuerst ein Element markieren und \"Format kopieren\" klicken")
                breite:  112
                opacity: root._hatFormat ? 1.0 : 0.4
                onKlick: panel.canvas.formatZuweisen()
            }
        }

        // Statuszeile: gibt klare Rückmeldung ob ein Format gespeichert ist
        Item {
            width: parent.width; height: 24

            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 6

                // Farbswatch der gespeicherten Linienfarbe
                Rectangle {
                    visible: root._hatFormat
                    width: 12; height: 12; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: (root._hatFormat && canvas._formatVorlage)
                           ? (canvas._formatVorlage.strichFarbe || "#4a9eff") : "transparent"
                    border.color: root.theme.border; border.width: 1
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 10
                    color: root._hatFormat ? root.theme.accent : root.theme.borderLight
                    text:  root._hatFormat
                           ? qsTr("Format gespeichert")
                           : qsTr("Kein Format gespeichert")
                }
            }
        }

        Item { height: 4 }
    }
}
