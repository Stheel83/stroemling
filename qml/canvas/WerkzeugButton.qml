import QtQuick
import QtQuick.Controls
import stroemling

Rectangle {
    id: root
    property string werkzeug: ""
    property string symbol: ""
    property string tooltip: ""
    property bool deaktiviert: false
    required property var canvas

    width: 36; height: 36; radius: 6
    color: deaktiviert ? "transparent"
         : canvas.aktivesWerkzeug === werkzeug ? AppTheme.activeItemAlt
         : wbMaus.containsMouse ? AppTheme.hover : "transparent"
    border.color: (!deaktiviert && canvas.aktivesWerkzeug === werkzeug) ? AppTheme.accent : "transparent"

    Text {
        anchors.centerIn: parent; text: root.symbol; font.pixelSize: 17
        color: root.deaktiviert ? AppTheme.btnDisabled
             : canvas.aktivesWerkzeug === root.werkzeug ? AppTheme.accent
             : wbMaus.containsMouse ? AppTheme.accentLight
             : AppTheme.panelMid
    }
    MouseArea {
        id: wbMaus; anchors.fill: parent; hoverEnabled: true
        enabled: !root.deaktiviert
        cursorShape: root.deaktiviert ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        onClicked: canvas.aktivesWerkzeug = root.werkzeug
    }
    ToolTip.visible: wbMaus.containsMouse; ToolTip.text: root.tooltip; ToolTip.delay: 500
}
