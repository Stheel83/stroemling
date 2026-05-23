import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.symbolId === "aderdefinition") ? adrCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

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
        id: adrCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("ADERDEFINITION") }

        FeldLabel { text: qsTr("Rotation") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: theme; label: "0°";  aktiv: panel.s("rotation", 0) === 0;  breite: 56
                onKlick: panel.canvas.eigenschaftAktualisieren("rotation", 0)  }
            MiniButton { theme: theme; label: "90°"; aktiv: panel.s("rotation", 0) === 90; breite: 56
                onKlick: panel.canvas.eigenschaftAktualisieren("rotation", 90) }
        }
        Item { height: 8 }

        InputField {
            label: qsTr("Bezeichnung")
            value: panel.el ? ((panel.el.extraDaten || {}).bezeichnung || "") : ""
            theme: theme
            onCommit: function(t) { root.extraSetzen("bezeichnung", t) }
        }

        FeldLabel { text: qsTr("Aderfarbe (IEC 60757)") }
        Flow {
            width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4; bottomPadding: 4
            Repeater {
                model: ["BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK","GNYE"]
                delegate: Rectangle {
                    property bool aktiv: panel.el && (panel.el.extraDaten || {}).aderfarbe === modelData
                    property string sName: ({"BN":"Brauno – L1","BK":"Schwärzchen – L2",
                        "GY":"Grausel – L3","BU":"Blaubertha – N","GNYE":"Erdikus – PE"})[modelData] || ""
                    width: 50; height: 24; radius: 4
                    color:        aktiv ? theme.activeItemAlt : (abMaus.containsMouse ? theme.hover : theme.inputBg)
                    border.color: aktiv ? theme.accent : theme.border

                    Row {
                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        AderfarbenSwatch {
                            aderCode: modelData; width: 10; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData; font.pixelSize: 9
                            color: aktiv ? theme.accent : theme.textMuted
                        }
                    }
                    MouseArea {
                        id: abMaus; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var cur = panel.el ? ((panel.el.extraDaten || {}).aderfarbe || "") : ""
                            root.extraSetzen("aderfarbe", cur === modelData ? "" : modelData)
                        }
                    }
                    ToolTip.visible:  sName !== "" && abMaus.containsMouse
                    ToolTip.text:     sName
                    ToolTip.delay:    500
                }
            }
        }

        FeldLabel { text: qsTr("Querschnitt mm²") }
        Flow {
            width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4; bottomPadding: 4
            Repeater {
                model: [0.14, 0.25, 0.34, 0.5, 0.75, 1.0, 1.5, 2.5, 4.0, 6.0,
                        10.0, 16.0, 25.0, 35.0, 50.0, 70.0, 95.0, 120.0, 150.0,
                        185.0, 240.0, 300.0]
                MiniButton { theme: theme;
                    label: modelData + ""; breite: 40; hoehe: 24
                    aktiv: {
                        var q = panel.el ? ((panel.el.extraDaten || {}).querschnitt_mm2 || 0) : 0
                        return Math.abs(q - modelData) < 0.01
                    }
                    onKlick: {
                        var q = panel.el ? ((panel.el.extraDaten || {}).querschnitt_mm2 || 0) : 0
                        root.extraSetzen("querschnitt_mm2",
                            Math.abs(q - modelData) < 0.01 ? 0 : modelData)
                    }
                }
            }
        }

        InputField {
            label: qsTr("Länge (m)")
            value: { var v = panel.el ? ((panel.el.extraDaten || {}).laenge_m || 0) : 0; return v > 0 ? (v + "").replace('.', ',') : "" }
            theme: theme
            onCommit: function(t) { var v = parseFloat(t.replace(',', '.')); root.extraSetzen("laenge_m", isNaN(v) ? 0 : v) }
        }
        Item { height: 4 }
    }
}
