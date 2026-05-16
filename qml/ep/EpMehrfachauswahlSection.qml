import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    readonly property bool hatSymbole: {
        for (var i = 0; i < panel.canvas.auswahl.length; i++) {
            var idx = panel.canvas.auswahl[i]
            if (idx >= 0 && idx < elementeModel.anzahl
                    && elementeModel.element(idx).typ === "symbol") return true
        }
        return false
    }

    width:   parent ? parent.width : 0
    height:  (panel.canvas.auswahl.length > 1 && hatSymbole) ? multiCol.implicitHeight : 0
    visible: height > 0
    clip:    true

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

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    Column {
        id: multiCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("ROTATION") }

        FeldLabel { text: qsTr("Alle Symbole auf:") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: [
                    { anzeige: "0°",   wert: 0   },
                    { anzeige: "90°",  wert: 90  },
                    { anzeige: "180°", wert: 180 },
                    { anzeige: "270°", wert: 270 }
                ]
                MiniButton { theme: theme;
                    label:   modelData.anzeige
                    breite:  40
                    onKlick: panel.canvas.eigenschaftAktualisieren("rotation", modelData.wert)
                }
            }
        }

        Item { height: 4 }
        FeldLabel { text: qsTr("Um Pivot drehen:") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: theme; label: qsTr("↺ 90°");  breite: 56; tooltip: qsTr("90° gegen Uhrzeigersinn um linken Pin"); onKlick: panel.canvas.multiRotationUmPivot(270) }
            MiniButton { theme: theme; label: qsTr("180°");   breite: 40; tooltip: qsTr("180° um linken Pin");                    onKlick: panel.canvas.multiRotationUmPivot(180) }
            MiniButton { theme: theme; label: qsTr("90° ↻");  breite: 56; tooltip: qsTr("90° im Uhrzeigersinn um linken Pin");    onKlick: panel.canvas.multiRotationUmPivot(90)  }
        }
        Item { height: 8 }
    }
}
