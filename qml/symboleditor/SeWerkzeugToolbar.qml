import QtQuick
import QtQuick.Controls

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
                       : (btnHover.containsMouse ? editor.theme.badge : "transparent")
                ToolTip.visible: btnHover.containsMouse
                ToolTip.delay: 600
                ToolTip.text: modelData.tooltip
                Text {
                    anchors.centerIn: parent
                    text:           modelData.icon
                    font.pixelSize: 18
                    color: editor.aktivesWerkzeug === modelData.id ? "white" : editor.theme.textPrimary
                }
                HoverHandler { id: btnHover }
                TapHandler {
                    onTapped: {
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
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "⌘Z"
            font.pixelSize: 9; color: editor.theme.textMuted
            topPadding: 4
            ToolTip.visible: undoHover.containsMouse
            ToolTip.delay: 600
            ToolTip.text: qsTr("Strg+Z: Letztes rückgängig")
            HoverHandler { id: undoHover }
        }
    }
}
