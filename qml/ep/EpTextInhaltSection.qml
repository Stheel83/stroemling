import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "text") ? textCol.implicitHeight : 0
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
        id: textCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("TEXT") }

        FeldLabel { text: qsTr("Inhalt (Shift + Enter = neue Zeile)") }
        Rectangle {
            width: root.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: txtEdit.implicitHeight + 10
            color: theme.inputBg; radius: 3
            border.color: txtEdit.activeFocus ? theme.accent : theme.border

            TextEdit {
                id: txtEdit
                anchors { fill: parent; margins: 5 }
                color: theme.textSecondary; font.pixelSize: 11
                wrapMode: TextEdit.NoWrap
                text: panel.s("textInhalt", "")
                Binding on text {
                    when: !txtEdit.activeFocus
                    value: panel.s("textInhalt", "")
                }
                Keys.onReturnPressed: function(event) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        event.accepted = false
                    } else {
                        var t = text.replace(/^\n+|\n+$/g, "").trim()
                        if (t !== "") panel.canvas.eigenschaftAktualisieren("textInhalt", t)
                        focus = false
                        event.accepted = true
                    }
                }
                Keys.onEscapePressed: { text = panel.s("textInhalt", ""); focus = false }
                onEditingFinished: {
                    var t = text.replace(/^\n+|\n+$/g, "").trim()
                    if (t !== "") panel.canvas.eigenschaftAktualisieren("textInhalt", t)
                }
            }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Ausrichtung") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: [
                    { anzeige: qsTr("◄ Links"),    wert: "links"  },
                    { anzeige: qsTr("◄► Mitte"),   wert: "mitte"  },
                    { anzeige: qsTr("Rechts ►"),   wert: "rechts" }
                ]
                MiniButton { theme: theme;
                    label:   modelData.anzeige
                    aktiv:   panel.s("textAusrichtung", "links") === modelData.wert
                    breite:  52
                    onKlick: panel.canvas.eigenschaftAktualisieren("textAusrichtung", modelData.wert)
                }
            }
        }
        Item { height: 6 }

        Row {
            leftPadding: 12; height: 30; spacing: 8
            Rectangle {
                width: 20; height: 20; radius: 4; anchors.verticalCenter: parent.verticalCenter
                color: panel.s("textEinpassen", false) ? theme.accent : theme.inputBg
                border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✓"); color: "#ffffff"
                       font.pixelSize: 12; visible: panel.s("textEinpassen", false) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.canvas.eigenschaftAktualisieren("textEinpassen",
                                   !panel.s("textEinpassen", false)) }
            }
            Text { text: qsTr("Text in Rahmen einpassen"); color: theme.textMuted; font.pixelSize: 11
                   anchors.verticalCenter: parent.verticalCenter }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Richtung") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: theme;
                label:   qsTr("→ Waagrecht")
                aktiv:   (panel.s("rotation", 0) % 180) === 0
                breite:  86
                onKlick: panel.canvas.eigenschaftAktualisieren("rotation", 0)
            }
            MiniButton { theme: theme;
                label:   qsTr("↑ Senkrecht")
                aktiv:   (panel.s("rotation", 0) % 180) !== 0
                breite:  86
                onKlick: panel.canvas.eigenschaftAktualisieren("rotation", 90)
            }
        }
        Item { height: 4 }
    }
}
