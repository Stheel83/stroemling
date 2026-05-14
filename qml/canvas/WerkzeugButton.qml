import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property string werkzeug: ""
    property string symbol: ""
    property string tooltip: ""
    property bool deaktiviert: false
    required property var canvas
    required property var theme

    width: 36; height: 36; radius: 6
    color: deaktiviert ? "transparent"
         : canvas.aktivesWerkzeug === werkzeug ? (theme ? theme.activeItemAlt : "#1a3a6a")
         : wbMaus.containsMouse ? (theme ? theme.hover : "#0f2540") : "transparent"
    border.color: (!deaktiviert && canvas.aktivesWerkzeug === werkzeug) ? (theme ? theme.accent : "#4a9eff") : "transparent"

    Text {
        anchors.centerIn: parent; text: root.symbol; font.pixelSize: 17
        color: root.deaktiviert ? (theme ? theme.btnDisabled : "#253545")
             : canvas.aktivesWerkzeug === root.werkzeug ? (theme ? theme.accent : "#4a9eff")
             : wbMaus.containsMouse ? (theme ? theme.accentLight : "#7aaddd")
             : (theme ? theme.panelMid : "#5577aa")
    }
    MouseArea {
        id: wbMaus; anchors.fill: parent; hoverEnabled: true
        enabled: !root.deaktiviert
        cursorShape: root.deaktiviert ? Qt.ForbiddenCursor : Qt.PointingHandCursor
        onClicked: canvas.aktivesWerkzeug = root.werkzeug
    }
    ToolTip.visible: wbMaus.containsMouse; ToolTip.text: root.tooltip; ToolTip.delay: 500
}
