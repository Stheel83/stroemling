import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Wiederverwendbarer Button für die linke Sidebar
// Verwendung:
//   SidebarButton { theme: appTheme; icon: "⚡"; label: "Projekte"; active: true; onClicked: ... }

Item {
    id: root

    property string icon:            "●"
    property string label:           qsTr("Button")
    property bool   active:          false
    property var    theme
    property string tooltip:         ""
    property string tooltipDisabled: ""

    signal clicked()

    Layout.fillWidth: true
    height: 48

    Rectangle {
        anchors.fill: parent
        color: root.active ? theme.activeItem : (hovered ? theme.hoverSidebar : "transparent")
        radius: 6

        Behavior on color { ColorAnimation { duration: 120 } }

        // Linke Markierungslinie wenn aktiv
        Rectangle {
            visible: root.active
            width:   3
            height:  parent.height * 0.6
            color:   theme.accent
            radius:  2
            anchors {
                left:           parent.left
                verticalCenter: parent.verticalCenter
            }
        }

        Row {
            spacing: 10
            anchors {
                left:           parent.left
                leftMargin:     16
                verticalCenter: parent.verticalCenter
            }

            Text {
                text:              root.icon
                font.pixelSize:    16
                height:            24
                verticalAlignment: Text.AlignVCenter
                color:             root.active ? theme.accent : theme.textMuted
            }
            Text {
                text:              root.label
                font.pixelSize:    13
                height:            24
                verticalAlignment: Text.AlignVCenter
                font.weight:       root.active ? Font.Medium : Font.Normal
                color:             root.active ? theme.textPrimary : theme.textMuted
            }
        }

        // Hover-Erkennung
        property bool hovered: false

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered:  parent.hovered = true
            onExited:   parent.hovered = false
            onClicked:  root.clicked()
            cursorShape: Qt.PointingHandCursor
        }

        ToolTip {
            visible: parent.hovered &&
                     ((!root.enabled && root.tooltipDisabled !== "") ||
                      (root.enabled  && root.tooltip          !== ""))
            text:    (!root.enabled && root.tooltipDisabled !== "") ? root.tooltipDisabled : root.tooltip
            delay:   500
        }
    }
}
