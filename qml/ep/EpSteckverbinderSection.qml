import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && (panel.el.symbolId === "stecker" || panel.el.symbolId === "buchse"))
             ? svCol.implicitHeight : 0
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
        id: svCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("STECKVERBINDER") }

        FeldLabel { text: qsTr("Anschlusstyp") }
        ComboBox {
            width: parent.width - 24
            anchors.horizontalCenter: parent.horizontalCenter
            model: [
                qsTr("Schraubanschluss"),
                qsTr("Federklemmung"),
                qsTr("Crimp"),
                qsTr("Löt")
            ]
            property var _keys: ["schraub", "feder", "crimp", "loet"]
            currentIndex: {
                var t = (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.svAnschlusstyp || "schraub") : "schraub"
                var idx = _keys.indexOf(t)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                if (!panel.el) return
                var ed = panel.el.extraDaten ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                ed.svAnschlusstyp = _keys[currentIndex]
                canvas.eigenschaftAktualisieren("extraDaten", ed)
            }
        }

        FeldLabel { text: qsTr("Querschnitt (mm²)") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            TextField {
                width: 72
                placeholderText: "min"
                text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svQsMin !== undefined)
                      ? String(panel.el.extraDaten.svQsMin).replace(".", ",") : ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onEditingFinished: {
                    if (!panel.el) return
                    var v = parseFloat(text.replace(",", "."))
                    if (isNaN(v)) return
                    var ed = panel.el.extraDaten ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed.svQsMin = v
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
            }
            Text {
                text: "–"
                anchors.verticalCenter: parent.verticalCenter
                color: theme.textSecondary; font.pixelSize: 12
            }
            TextField {
                width: 72
                placeholderText: "max"
                text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svQsMax !== undefined)
                      ? String(panel.el.extraDaten.svQsMax).replace(".", ",") : ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onEditingFinished: {
                    if (!panel.el) return
                    var v = parseFloat(text.replace(",", "."))
                    if (isNaN(v)) return
                    var ed = panel.el.extraDaten ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed.svQsMax = v
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
            }
        }

        FeldLabel { text: qsTr("Kabeldurchmesser max (mm)") }
        TextField {
            width: parent.width - 24
            anchors.horizontalCenter: parent.horizontalCenter
            placeholderText: "z. B. 8,5"
            text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svKabelDmMax !== undefined)
                  ? String(panel.el.extraDaten.svKabelDmMax).replace(".", ",") : ""
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            onEditingFinished: {
                if (!panel.el) return
                var v = parseFloat(text.replace(",", "."))
                if (isNaN(v)) return
                var ed = panel.el.extraDaten ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                ed.svKabelDmMax = v
                canvas.eigenschaftAktualisieren("extraDaten", ed)
            }
        }

        Item { height: 4 }
    }
}
