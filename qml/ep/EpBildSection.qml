import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "bild") ? bildCol.implicitHeight : 0
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
        id: bildCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("BILD") }

        FeldLabel { text: qsTr("Rotation") }
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
                    aktiv:   panel.s("rotation", 0) === modelData.wert
                    breite:  40
                    onKlick: canvas.eigenschaftAktualisieren("rotation", modelData.wert)
                }
            }
        }
        Item { height: 4 }

        Item {
            width: root.width; height: 28
            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("Freier Winkel"); color: theme.panelMid; font.pixelSize: 10
            }
            Row {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 3
                Rectangle {
                    width: 48; height: 22; radius: 3
                    color: theme.inputBg; border.color: bildRotTf.activeFocus ? theme.accent : theme.border
                    TextInput {
                        id: bildRotTf
                        anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                        horizontalAlignment: TextInput.AlignRight
                        color: theme.textSecondary; font.pixelSize: 10
                        verticalAlignment: TextInput.AlignVCenter
                        validator: DoubleValidator {
                            bottom: 0; top: 359.9; decimals: 1
                            notation: DoubleValidator.StandardNotation
                        }
                        text: panel.s("rotation", 0).toFixed(1)
                        Binding on text {
                            when: !bildRotTf.activeFocus
                            value: panel.s("rotation", 0).toFixed(1)
                        }
                        onEditingFinished: {
                            var v = parseFloat(text)
                            if (!isNaN(v)) canvas.eigenschaftAktualisieren("rotation", ((v % 360) + 360) % 360)
                        }
                        Keys.onEscapePressed: { text = panel.s("rotation", 0).toFixed(1); focus = false }
                    }
                }
                Text { text: "°"; color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Spiegelung") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: theme;
                label:   qsTr("↔ H")
                tooltip: qsTr("Horizontal spiegeln (Taste X)")
                aktiv:   panel.s("spiegelX", false)
                breite:  56
                onKlick: canvas.eigenschaftAktualisieren("spiegelX", !panel.s("spiegelX", false))
            }
            MiniButton { theme: theme;
                label:   qsTr("↕ V")
                tooltip: qsTr("Vertikal spiegeln (Taste Y)")
                aktiv:   panel.s("spiegelY", false)
                breite:  56
                onKlick: canvas.eigenschaftAktualisieren("spiegelY", !panel.s("spiegelY", false))
            }
        }
        Item { height: 8 }

        Trennlinie {}
        AbschnittTitel { text: qsTr("GRÖßENÄNDERUNG") }
        Row {
            leftPadding: 12; height: 32; spacing: 8
            Rectangle {
                width: 20; height: 20; radius: 4; anchors.verticalCenter: parent.verticalCenter
                color: panel.s("proportional", false) ? theme.accent : theme.inputBg
                border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✓"); color: "#ffffff"
                       font.pixelSize: 12; visible: panel.s("proportional", false) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: canvas.eigenschaftAktualisieren("proportional",
                                   !panel.s("proportional", false)) }
            }
            Text { text: qsTr("Seitenverhältnis beibehalten"); color: theme.textMuted
                   font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
        }

        Trennlinie {}
        AbschnittTitel { text: qsTr("AUSSCHNITT") }

        Item {
            width: root.width; height: 22
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                   text: qsTr("Links  ") + Math.round(panel.s("ausschnittLinks", 0) * 100) + " %"
                   color: theme.panelMid; font.pixelSize: 10 }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3; visible: panel.s("ausschnittLinks", 0) > 0
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✕"); font.pixelSize: 9; color: theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: canvas.eigenschaftAktualisieren("ausschnittLinks", 0) }
            }
        }
        StilSlider { theme: theme; height: 36; width: root.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittLinks", 0)
            onGeaendert: function(v) { canvas.eigenschaftAktualisieren("ausschnittLinks", v) } }

        Item {
            width: root.width; height: 22
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                   text: qsTr("Rechts  ") + Math.round(panel.s("ausschnittRechts", 0) * 100) + " %"
                   color: theme.panelMid; font.pixelSize: 10 }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3; visible: panel.s("ausschnittRechts", 0) > 0
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✕"); font.pixelSize: 9; color: theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: canvas.eigenschaftAktualisieren("ausschnittRechts", 0) }
            }
        }
        StilSlider { theme: theme; height: 36; width: root.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittRechts", 0)
            onGeaendert: function(v) { canvas.eigenschaftAktualisieren("ausschnittRechts", v) } }

        Item {
            width: root.width; height: 22
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                   text: qsTr("Oben  ") + Math.round(panel.s("ausschnittOben", 0) * 100) + " %"
                   color: theme.panelMid; font.pixelSize: 10 }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3; visible: panel.s("ausschnittOben", 0) > 0
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✕"); font.pixelSize: 9; color: theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: canvas.eigenschaftAktualisieren("ausschnittOben", 0) }
            }
        }
        StilSlider { theme: theme; height: 36; width: root.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittOben", 0)
            onGeaendert: function(v) { canvas.eigenschaftAktualisieren("ausschnittOben", v) } }

        Item {
            width: root.width; height: 22
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                   text: qsTr("Unten  ") + Math.round(panel.s("ausschnittUnten", 0) * 100) + " %"
                   color: theme.panelMid; font.pixelSize: 10 }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3; visible: panel.s("ausschnittUnten", 0) > 0
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✕"); font.pixelSize: 9; color: theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: canvas.eigenschaftAktualisieren("ausschnittUnten", 0) }
            }
        }
        StilSlider { theme: theme; height: 36; width: root.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittUnten", 0)
            onGeaendert: function(v) { canvas.eigenschaftAktualisieren("ausschnittUnten", v) } }

        Item { height: 4 }
    }
}
