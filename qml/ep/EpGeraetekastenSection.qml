import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "geraetekasten") ? gkCol.implicitHeight : 0
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

    component SchriftgrosseSelektor: Item {
        id: sgRoot
        property real wert: 2.5
        signal wertGeaendert(real neuerWert)

        readonly property var schritte: [1.5, 2.0, 2.5, 3.5, 5.0, 7.0, 10.0, 15.0, 20.0, 30.0, 40.0]
        readonly property int aktIdx: {
            var best = 0, bestD = 9999
            for (var i = 0; i < schritte.length; i++) {
                var d = Math.abs(schritte[i] - wert)
                if (d < bestD) { bestD = d; best = i }
            }
            return best
        }

        width: root.width; height: 32

        Row {
            anchors.centerIn: parent; spacing: 6
            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgKlMa.containsMouse ? root.theme.border : root.theme.inputBg
                border.color: sgRoot.aktIdx > 0 ? root.theme.border : root.theme.divider
                Text { anchors.centerIn: parent; text: "◄"; font.pixelSize: 11
                       color: sgRoot.aktIdx > 0 ? root.theme.accent : root.theme.borderDark }
                MouseArea { id: sgKlMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; enabled: sgRoot.aktIdx > 0
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx - 1]) }
            }
            Rectangle {
                width: 60; height: 28; radius: 4
                color: root.theme.inputBg; border.color: root.theme.border
                Text { anchors.centerIn: parent; color: root.theme.textSecondary; font.pixelSize: 11
                       text: sgRoot.wert.toFixed(1) + " mm" }
            }
            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgGrMa.containsMouse ? root.theme.border : root.theme.inputBg
                border.color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? root.theme.border : root.theme.divider
                Text { anchors.centerIn: parent; text: "►"; font.pixelSize: 11
                       color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? root.theme.accent : root.theme.borderDark }
                MouseArea { id: sgGrMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: sgRoot.aktIdx < sgRoot.schritte.length - 1
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx + 1]) }
            }
        }
    }

    Column {
        id: gkCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("GERÄTEKASTEN") }

        InputField {
            label: qsTr("BMK (Einbauort)")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "") : ""
            theme: theme
            onCommit: function(t) { root.extraSetzen("bmk", t.trim()) }
        }
        Item { height: 6 }

        InputField {
            label: qsTr("Bezeichnung")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
            theme: theme
            onCommit: function(t) { root.extraSetzen("bezeichnung", t.trim()) }
        }
        Item { height: 6 }

        Trennlinie {}
        AbschnittTitel { text: qsTr("SCHRIFTGRÖSSE") }
        SchriftgrosseSelektor {
            wert: (panel.el && panel.el.extraDaten
                   && panel.el.extraDaten.schriftgroesse !== undefined)
                  ? panel.el.extraDaten.schriftgroesse : 2.5
            onWertGeaendert: function(v) { root.extraSetzen("schriftgroesse", v) }
        }
        Item { height: 4 }
    }
}
