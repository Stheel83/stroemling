import QtQuick
import QtQuick.Controls

// Farbkreis-Auswahl (12 Farben) für das EigenschaftenPanel.
// Ersetzt das Muster: Flow { Repeater { Rectangle { radius:10 ... } } }
//
// Verwendung:
//   ColorPalette {
//       model: panel.farbpalette
//       value: panel.s("strichFarbe", theme.accent)
//       theme: theme
//       onColorSelected: function(c) { canvas.eigenschaftAktualisieren("strichFarbe", c) }
//   }
Item {
    id: root

    required property var    theme
    property  var            model: []
    property  string         value: ""

    signal colorSelected(string hex)

    width:          parent ? parent.width : 0
    implicitHeight: colorFlow.implicitHeight

    Flow {
        id: colorFlow
        width: parent.width - 16
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 5

        Repeater {
            model: root.model

            Rectangle {
                width: 20; height: 20; radius: 10
                color:        modelData
                border.color: root.value === modelData ? "#ffffff" : root.theme.borderDark
                border.width: root.value === modelData ? 2 : 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked:    root.colorSelected(modelData)
                    ToolTip.visible: containsMouse
                    ToolTip.text:    modelData
                    ToolTip.delay:   400
                }
            }
        }
    }
}
