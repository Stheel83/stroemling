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
                {id: "auswahl",     icon: "↖", tooltip: qsTr("Auswahl (A)\nRahmen aufziehen: links→rechts = Fenster, rechts→links = Schneiden\nShift/Strg+Klick: mehrere · Strg+A: alles · Pfeiltasten: verschieben")},
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
            id: linienartCombo
            width: 64
            // SE-LINIENART-SPRACHE-01: der gespeicherte symbol_primitiv.linienart-Wert
            // ist "solid"/"dash"/"dot"/"dashdot" (schema.sql, von CanvasRenderHandler.qml/
            // Database_PDF.cpp/FunSprite.qml so gelesen) - Modell hält jetzt genau diese
            // Rohwerte, label() liefert nur die Anzeige. Vorher schrieb dieses Combo
            // deutsche Strings ("gestrichelt" etc.), die kein Renderer außer der
            // Editor-eigenen Vorschau kannte - Strichart war dadurch außerhalb des
            // Editors faktisch wirkungslos (immer durchgezogen).
            model: ["solid", "dash", "dot", "dashdot"]
            function label(key) {
                switch (key) {
                case "dash":    return "- -"
                case "dot":     return "···"
                case "dashdot": return "-·-"
                default:        return "—"
                }
            }
            currentIndex: Math.max(0, model.indexOf(editor.aktLinienart))
            onCurrentIndexChanged: editor.aktLinienart = model[currentIndex]
            font.pixelSize: 10; implicitHeight: 24
            background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
            contentItem: Text { text: linienartCombo.label(linienartCombo.currentText); color: editor.theme.textPrimary; font.pixelSize: 10;
                                leftPadding: 6; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            delegate: ItemDelegate {
                width: linienartCombo.width
                highlighted: linienartCombo.highlightedIndex === index
                contentItem: Text { text: linienartCombo.label(modelData); font.pixelSize: 10;
                                     color: editor.theme.textPrimary; leftPadding: 6;
                                     verticalAlignment: Text.AlignVCenter }
            }
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
            text: qsTr("Strg+Z")
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
