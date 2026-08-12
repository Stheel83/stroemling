import QtQuick
import QtQuick.Controls
import "../components"

Rectangle {
    id: root
    required property var editor

    width: 72
    color: editor.theme.sidebar

    Column {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
        spacing: 4

        Repeater {
            model: [
                {id: "auswahl",     icon: "↖", tooltip: qsTr("Auswahl (A)")},
                {id: "linie",       icon: "╱", tooltip: qsTr("Linie (L)")},
                {id: "rechteck",    icon: "□", tooltip: qsTr("Rechteck (R)")},
                {id: "kreis_offen", icon: "○", tooltip: qsTr("Kreis (K)")},
                {id: "bogen",       icon: "⌒", tooltip: qsTr("Bogen (B)")},
                {id: "punkt",       icon: "●", tooltip: qsTr("Punkt (P)")},
                {id: "text",        icon: "A", tooltip: qsTr("Text (T)")},
                {id: "pin",         icon: "⊕", tooltip: qsTr("Pin (I)")},
            ]
            delegate: Rectangle {
                width: 38; height: 38; radius: 6
                color: editor.aktivesWerkzeug === modelData.id
                       ? editor.theme.accent
                       : (btnArea.containsMouse ? editor.theme.badge : "transparent")
                ToolTip.visible: btnArea.containsMouse
                ToolTip.delay: 600
                ToolTip.text: modelData.tooltip
                Text {
                    anchors.centerIn: parent
                    text:           modelData.icon
                    font.pixelSize: 18
                    color: editor.aktivesWerkzeug === modelData.id ? "white" : editor.theme.textPrimary
                }
                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        editor.aktivesWerkzeug = modelData.id
                        editor.werkzeugPunkte  = []
                        editor.forceActiveFocus()
                    }
                }
            }
        }

        Rectangle { width: 36; height: 1; color: editor.theme.border; anchors.horizontalCenter: parent.horizontalCenter }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Strich:")
            font.pixelSize: 9; color: editor.theme.textMuted
        }
        ComboBox {
            width: 64
            model: ["—", "- -", "···", "-·-"]
            currentIndex: ["durchgehend","gestrichelt","gepunktet","Strich-Punkt"].indexOf(editor.aktLinienart)
            onCurrentIndexChanged: editor.aktLinienart = ["durchgehend","gestrichelt","gepunktet","Strich-Punkt"][currentIndex]
            font.pixelSize: 10; implicitHeight: 24
            background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
            contentItem: Text { text: parent.displayText; color: editor.theme.textPrimary; font.pixelSize: 10;
                                leftPadding: 6; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }

        Rectangle {
            width: 64; height: 26; radius: 4
            color: editor.aktGefuellt ? editor.theme.accent : editor.theme.inputBg
            border.color: editor.theme.border
            ToolTip.visible: fuellArea.containsMouse
            ToolTip.delay: 600
            ToolTip.text: qsTr("Rechteck/Kreis gefüllt zeichnen")
            Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "■"
                    font.pixelSize: 11
                    color: editor.aktGefuellt ? "white" : editor.theme.textPrimary
                }
                Text {
                    text: qsTr("Gefüllt")
                    font.pixelSize: 9
                    color: editor.aktGefuellt ? "white" : editor.theme.textMuted
                }
            }
            MouseArea {
                id: fuellArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: editor.aktGefuellt = !editor.aktGefuellt
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⌘Z"
            font.pixelSize: 9; color: editor.theme.textMuted
            topPadding: 4
            ToolTip.visible: undoArea.containsMouse
            ToolTip.delay: 600
            ToolTip.text: qsTr("Strg+Z: Letztes rückgängig")
            MouseArea { id: undoArea; anchors.fill: parent; hoverEnabled: true }
        }
    }
    DebugLabel { panelName: qsTr("SE Werkzeuge"); visible: editor.debug }
}
