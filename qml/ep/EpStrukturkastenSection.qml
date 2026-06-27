import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "strukturkasten") ? skCol.implicitHeight : 0
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
        id: skCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("STRUKTURKASTEN") }

        // Bezeichnung: mehrzeilige Eingabe (Zeilenumbruch mit Enter)
        Item {
            width: parent.width
            implicitHeight: skBezLabel.height + skBezRect.height
            Item {
                id: skBezLabel
                width: parent.width; height: 20
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("Bezeichnung"); font.pixelSize: 10; color: root.theme.panelMid
                }
            }
            Rectangle {
                id: skBezRect
                anchors { top: skBezLabel.bottom; horizontalCenter: parent.horizontalCenter }
                width: parent.width - 16
                height: Math.max(28, skBezTa.implicitHeight + 8)
                radius: 3; color: root.theme.inputBg
                border.color: skBezTa.activeFocus ? root.theme.accent : root.theme.border
                TextArea {
                    id: skBezTa
                    anchors { fill: parent; margins: 4 }
                    color: root.theme.textSecondary; font.pixelSize: 11
                    wrapMode: TextArea.Wrap; background: null
                    placeholderText: qsTr("Bezeichnung …")
                    placeholderTextColor: root.theme.textMuted
                    text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                    Binding on text {
                        when: !skBezTa.activeFocus
                        value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                        delayed: true
                    }
                    onFocusChanged: if (!activeFocus) root.extraSetzen("bezeichnung", text)
                    Keys.onEscapePressed: focus = false
                }
            }
        }
        Item { height: 6 }

        InputField {
            label: qsTr("Übergeordnete Anlage (==)")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.anlageUO || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("anlageUO", t.trim()) }
        }
        Item { height: 6 }

        InputField {
            label: qsTr("Übergeordneter Ort (++)")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.ortUO || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("ortUO", t.trim()) }
        }
        Item { height: 6 }

        InputField {
            label: qsTr("Anlage (=)")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.anlage || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("anlage", t.trim()) }
        }
        Item { height: 6 }

        InputField {
            label: qsTr("Ort (+)")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.ort || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("ort", t.trim()) }
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

        // ── Textposition ──────────────────────────────────────────
        Trennlinie {}
        AbschnittTitel { text: qsTr("TEXTPOSITION") }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Column {
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Versatz X"); color: root.theme.panelMid; font.pixelSize: 10 }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: root.theme.inputBg; border.color: skOxTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: skOxTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetX !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetX : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !skOxTf.activeFocus; value: (skOxTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetX", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Column {
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Versatz Y"); color: root.theme.panelMid; font.pixelSize: 10 }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: root.theme.inputBg; border.color: skOyTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: skOyTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetY !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetY : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !skOyTf.activeFocus; value: (skOyTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetY", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: 32; height: 22; radius: 3
                color: skResetMa.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 12; color: root.theme.textMuted }
                MouseArea {
                    id: skResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.extraSetzen("bmkOffsetX", 0); root.extraSetzen("bmkOffsetY", 0) }
                }
                ToolTip { visible: skResetMa.containsMouse; text: qsTr("Textposition zurücksetzen"); delay: 500 }
            }
        }
        Item { height: 4 }
    }
}
