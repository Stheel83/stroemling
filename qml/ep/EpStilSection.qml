import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  stilCol.implicitHeight

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

    component SchriftgrosseSelektor: Item {
        id: sgRoot
        property real wert: 2.5
        signal wertGeaendert(real neuerWert)

        readonly property var  schritte: [1.5, 2.0, 2.5, 3.5, 5.0, 7.0, 10.0, 15.0, 20.0, 30.0, 40.0]
        readonly property int  aktIdx: {
            var best = 0, bestD = 9999
            for (var i = 0; i < schritte.length; i++) {
                var d = Math.abs(schritte[i] - wert)
                if (d < bestD) { bestD = d; best = i }
            }
            return best
        }

        width: parent.width; height: 32

        Row {
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgKlMa.containsMouse ? theme.border : theme.inputBg
                border.color: sgRoot.aktIdx > 0 ? theme.border : theme.divider
                Text { anchors.centerIn: parent; text: qsTr("◄"); font.pixelSize: 11
                       color: sgRoot.aktIdx > 0 ? theme.accent : theme.borderDark }
                MouseArea {
                    id: sgKlMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; enabled: sgRoot.aktIdx > 0
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx - 1])
                }
            }
            Rectangle {
                width: 60; height: 28; radius: 4
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; color: theme.textSecondary; font.pixelSize: 11
                       text: sgRoot.wert.toFixed(1) + " mm" }
            }
            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgGrMa.containsMouse ? theme.border : theme.inputBg
                border.color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? theme.border : theme.divider
                Text { anchors.centerIn: parent; text: qsTr("►"); font.pixelSize: 11
                       color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? theme.accent : theme.borderDark }
                MouseArea {
                    id: sgGrMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: sgRoot.aktIdx < sgRoot.schritte.length - 1
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx + 1])
                }
            }
        }
    }

    Column {
        id: stilCol
        width: parent.width; spacing: 0

        AbschnittTitel { text: qsTr("STIL") }

        FeldLabel {
            visible: !panel.el || panel.el.typ !== "bild"
            text: (panel.el && (panel.el.typ === "text" || panel.el.typ === "notiz"))
                  ? qsTr("Schriftfarbe") : qsTr("Farbe")
        }
        ColorPalette {
            visible: !panel.el || panel.el.typ !== "bild"
            height:  visible ? implicitHeight : 0
            model:   panel.farbpalette
            value:   panel.s("strichFarbe", theme.accent)
            theme:   theme
            onColorSelected: function(c) { panel.canvas.eigenschaftAktualisieren("strichFarbe", c) }
        }
        Item { height: 8; visible: !panel.el || panel.el.typ !== "bild" }

        Item {
            width: parent.width
            height: (panel.el && panel.el.typ !== "text" && panel.el.typ !== "notiz" && panel.el.typ !== "bild") ? strichCol.implicitHeight : 0
            visible: height > 0; clip: true
            Column {
                id: strichCol
                width: parent.width; spacing: 0
                FeldLabel { text: qsTr("Strichstärke") }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    Repeater {
                        model: [
                            { anzeige: "0.5", wert: 0.5 }, { anzeige: "1",   wert: 1.0 },
                            { anzeige: "1.5", wert: 1.5 }, { anzeige: "2",   wert: 2.0 },
                            { anzeige: "3",   wert: 3.0 }, { anzeige: "5",   wert: 5.0 }
                        ]
                        MiniButton { theme: theme;
                            label:   modelData.anzeige
                            tooltip: modelData.anzeige + " mm"
                            aktiv:   Math.abs(panel.s("strichBreite", 1.5) - modelData.wert) < 0.01
                            breite:  32
                            onKlick: panel.canvas.eigenschaftAktualisieren("strichBreite", modelData.wert)
                        }
                    }
                }
                Item { height: 8 }
            }
        }

        Item {
            width: parent.width
            height: (panel.el && (panel.el.typ === "text" || panel.el.typ === "notiz")) ? txtSchriftCol.implicitHeight : 0
            visible: height > 0; clip: true
            Column {
                id: txtSchriftCol
                width: parent.width; spacing: 0
                FeldLabel { text: qsTr("Schriftgröße") }
                SchriftgrosseSelektor {
                    wert: panel.s("strichBreite", 3.5)
                    onWertGeaendert: function(v) {
                        panel.canvas.eigenschaftAktualisieren("strichBreite", v)
                    }
                }
                Item { height: 8 }
            }
        }

        FeldLabel { text: qsTr("Linienart"); visible: !panel.el || (panel.el.typ !== "bild" && panel.el.typ !== "notiz") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            visible: !panel.el || (panel.el.typ !== "bild" && panel.el.typ !== "notiz")
            height: visible ? implicitHeight : 0
            Repeater {
                model: [
                    { anzeige: "——",    wert: "solid",       tip: qsTr("Durchgehend")  },
                    { anzeige: "- -  -",          wert: "gestrichelt", tip: qsTr("Gestrichelt")  },
                    { anzeige: "·····", wert: "gepunktet", tip: qsTr("Gepunktet") }
                ]
                MiniButton { theme: theme;
                    label:   modelData.anzeige
                    tooltip: modelData.tip
                    aktiv:   panel.s("strichArt", "solid") === modelData.wert
                    breite:  58
                    mono:    true
                    onKlick: panel.canvas.eigenschaftAktualisieren("strichArt", modelData.wert)
                }
            }
        }
        Item { height: 8; visible: !panel.el || (panel.el.typ !== "bild" && panel.el.typ !== "notiz") }

        Item {
            width: root.width; height: 22
            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("Deckkraft"); color: theme.panelMid; font.pixelSize: 10
            }
            Row {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 3
                Rectangle {
                    width: 36; height: 18; radius: 3; anchors.verticalCenter: parent.verticalCenter
                    color: theme.inputBg; border.color: opTf.activeFocus ? theme.accent : theme.border
                    TextInput {
                        id: opTf
                        anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                        horizontalAlignment: TextInput.AlignRight
                        color: theme.textSecondary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter
                        validator: IntValidator { bottom: 5; top: 100 }
                        text: Math.round(panel.s("opazitaet", 1.0) * 100)
                        Binding on text {
                            when: !opTf.activeFocus
                            value: Math.round(panel.s("opazitaet", 1.0) * 100)
                        }
                        onEditingFinished: {
                            var v = parseInt(text)
                            if (!isNaN(v)) panel.canvas.eigenschaftAktualisieren("opazitaet", Math.max(0.05, Math.min(1.0, v/100)))
                        }
                        Keys.onEscapePressed: { text = Math.round(panel.s("opazitaet", 1.0) * 100); focus = false }
                    }
                }
                Text { text: "%"; color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        StilSlider { theme: theme;
            width: root.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            von: 0.05; bis: 1.0; schritt: 0.05
            wert: panel.s("opazitaet", 1.0)
            onGeaendert: function(v) { panel.canvas.eigenschaftAktualisieren("opazitaet", v) }
        }
    }
}
