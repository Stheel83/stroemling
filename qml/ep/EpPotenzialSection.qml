import QtQuick
import QtQuick.Controls
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

    function textpositionZuruecksetzen() {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        delete ed.bmkOffsetX
        delete ed.bmkOffsetY
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
                // Potenzial-Punkte markieren Speise-/Bezugspotenziale (AC/DC + PE/N) –
                // die Digital-/Analog-/Kommunikations-Kategorien der Geräteanschluss-
                // Sektion sind hier bewusst nicht enthalten (Nutzerentscheidung Jul 2026).
                model: [
                    { key: "neutral",   label: qsTr("Neutral"), farbe: "#4a9eff" },
                    { key: "power",     label: "L",             farbe: "#cc3300" },
                    { key: "dc_plus",   label: "DC+",           farbe: "#dd5500" },
                    { key: "dc_minus",  label: "DC−",      farbe: "#334488" },
                    { key: "pe",        label: "PE",            farbe: "#88cc00" },
                    { key: "n",         label: "N",             farbe: "#4488ff" }
                ]
                delegate: Rectangle {
                    width:  sigMa.implicitWidth + 16; height: 24; radius: 4
                    color:  root.aktuellSig === modelData.key
                            ? Qt.rgba(
                                  parseInt(modelData.farbe.slice(1,3),16)/255,
                                  parseInt(modelData.farbe.slice(3,5),16)/255,
                                  parseInt(modelData.farbe.slice(5,7),16)/255,
                                  0.25)
                            : (root.theme ? root.theme.inputBg : "transparent")
                    border.color: root.aktuellSig === modelData.key
                                  ? modelData.farbe : (root.theme ? root.theme.border : "transparent")
                    border.width: 1
                    Text {
                        id: sigMa
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 10
                        color: root.aktuellSig === modelData.key
                               ? modelData.farbe : (root.theme ? root.theme.panelMid : "gray")
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
                        color: root.theme.inputBg; border.color: paOxTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: paOxTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetX !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetX : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !paOxTf.activeFocus; value: (paOxTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
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
                        color: root.theme.inputBg; border.color: paOyTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: paOyTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetY !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetY : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !paOyTf.activeFocus; value: (paOyTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
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
                color: paResetMa.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 12; color: root.theme.textMuted }
                MouseArea {
                    id: paResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.textpositionZuruecksetzen()
                }
                ToolTip { visible: paResetMa.containsMouse; text: qsTr("Textposition zurücksetzen"); delay: 500 }
            }
        }
        Item { height: 8 }
    }
}
