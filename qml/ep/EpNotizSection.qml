import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "notiz") ? notizCol.implicitHeight : 0
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
        id: notizCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("NOTIZ") }

        FeldLabel { text: qsTr("Inhalt") }
        Rectangle {
            width: root.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: notizEdit.implicitHeight + 10
            color: theme.inputBg; radius: 3
            border.color: notizEdit.activeFocus ? theme.accent : theme.border
            TextEdit {
                id: notizEdit
                anchors { fill: parent; margins: 5 }
                color: theme.textSecondary; font.pixelSize: 11
                wrapMode: TextEdit.WordWrap
                text: panel.s("textInhalt", "")
                Binding on text {
                    when: !notizEdit.activeFocus
                    value: panel.s("textInhalt", "")
                }
                Keys.onReturnPressed: function(event) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        event.accepted = false
                    } else {
                        var t = text.replace(/^\n+|\n+$/g, "").trim()
                        if (t !== "") panel.canvas.eigenschaftAktualisieren("textInhalt", t)
                        focus = false; event.accepted = true
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

        FeldLabel { text: qsTr("Hintergrundfarbe") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: ["#1a1a00","#001a00","#001a1a","#1a001a","#1a0a00","#0a0a18"]
                Rectangle {
                    width: 22; height: 22; radius: 3
                    color: modelData
                    border.color: (panel.s("fuellFarbe","#1a1a00") === modelData)
                                  ? theme.accent : theme.border
                    border.width: (panel.s("fuellFarbe","#1a1a00") === modelData) ? 2 : 1
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: panel.canvas.eigenschaftAktualisieren("fuellFarbe", modelData)
                    }
                }
            }
        }
        Item { height: 8 }
    }
}
