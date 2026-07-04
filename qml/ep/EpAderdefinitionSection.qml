import QtQuick
import QtQuick.Controls
import "../components"
import "../Normwerte.js" as NW

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
            MiniButton { theme: root.theme; label: "0°";  aktiv: panel.s("rotation", 0) === 0;  breite: 56
                onKlick: panel.canvas.eigenschaftAktualisieren("rotation", 0)  }
            MiniButton { theme: root.theme; label: "90°"; aktiv: panel.s("rotation", 0) === 90; breite: 56
                onKlick: panel.canvas.eigenschaftAktualisieren("rotation", 90) }
        }
        Item { height: 8 }

        InputField {
            label: qsTr("Adernummer")
            value: panel.el ? ((panel.el.extraDaten || {}).bezeichnung || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("bezeichnung", t) }
        }

        FeldLabel { text: qsTr("Aderfarbe (IEC 60757)") }
        Flow {
            width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4; bottomPadding: 4
            Repeater {
                model: ["BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK","GNYE","CL"]
                delegate: Rectangle {
                    property bool aktiv: panel.el && (panel.el.extraDaten || {}).aderfarbe === modelData
                    property string sName: ({"BK":"Schwarz","BN":"Braun","RD":"Rot",
                        "OG":"Orange","YE":"Gelb","GN":"Grün","BU":"Blau","VT":"Violett",
                        "GY":"Grau","WH":"Weiß","PK":"Rosa","GNYE":"Grün-Gelb (PE)",
                        "CL":"Farblos"})[modelData] || modelData
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
                    ToolTip.visible:  abMaus.containsMouse
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
                model: NW.QUERSCHNITT_WERTE
                MiniButton { theme: root.theme;
                    label: modelData + ""; breite: 40; hoehe: 24
                    tooltip: qsTr("Ø %1 mm (Leiter, eindrähtig, rechnerisch – reale Außenmaße je nach Isolierung/Litzenzahl abweichend)")
                        .arg((2 * Math.sqrt(modelData / Math.PI)).toFixed(2).replace('.', ','))
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
            theme: root.theme
            onCommit: function(t) { var v = parseFloat(t.replace(',', '.')); root.extraSetzen("laenge_m", isNaN(v) ? 0 : v) }
        }
        Item { height: 4 }
    }
}
