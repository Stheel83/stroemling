import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "symbol"
              && panel.el.symbolId === "potenzial") ? potCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    readonly property string aktuellSig: (panel.el && panel.el.extraDaten
        && panel.el.extraDaten.signaltyp) ? panel.el.extraDaten.signaltyp : "neutral"

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
        id: potCol
        width: parent.width
        spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("SIGNALTYP") }

        FeldLabel { text: qsTr("Potenzialklasse") }
        Flow {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Repeater {
                model: [
                    { key: "neutral",        label: qsTr("Neutral"),  farbe: "#4a9eff" },
                    { key: "power",          label: qsTr("Kraft"),    farbe: "#cc3300" },
                    { key: "pe",             label: "PE",             farbe: "#88cc00" },
                    { key: "n",              label: "N",              farbe: "#4488ff" },
                    { key: "input_digital",  label: "DI",             farbe: "#44aacc" },
                    { key: "output_digital", label: "DO",             farbe: "#aa44cc" },
                    { key: "input_analog",   label: "AI",             farbe: "#88bbff" },
                    { key: "output_analog",  label: "AO",             farbe: "#66ddaa" },
                    { key: "kommunikation",  label: qsTr("Komm."),    farbe: "#cc8800" }
                ]
                delegate: Rectangle {
                    width:  sigMa.implicitWidth + 16; height: 24; radius: 4
                    color:  root.aktuellSig === modelData.key
                            ? Qt.rgba(
                                  parseInt(modelData.farbe.slice(1,3),16)/255,
                                  parseInt(modelData.farbe.slice(3,5),16)/255,
                                  parseInt(modelData.farbe.slice(5,7),16)/255,
                                  0.25)
                            : theme.inputBg
                    border.color: root.aktuellSig === modelData.key
                                  ? modelData.farbe : theme.border
                    border.width: 1
                    Text {
                        id: sigMa
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 10
                        color: root.aktuellSig === modelData.key
                               ? modelData.farbe : theme.panelMid
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.extraSetzen("signaltyp",
                            root.aktuellSig === modelData.key ? "neutral" : modelData.key)
                    }
                }
            }
        }
        Item { height: 8 }
    }
}
