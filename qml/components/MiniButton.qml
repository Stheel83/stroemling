import QtQuick
import QtQuick.Controls

Rectangle {
    id: mbRoot

    property var theme

    property string label:   ""
    property string tooltip: ""
    property bool   aktiv:   false
    property real   breite:  40
    property real   hoehe:   28
    property bool   mono:    false
    signal klick()

    width: breite; height: hoehe; radius: 4
    color:        theme ? (aktiv ? theme.activeItemAlt : (mbMaus.containsMouse ? theme.hover : theme.inputBg)) : "transparent"
    border.color: theme ? (aktiv ? theme.accent : theme.border) : "transparent"

    Text {
        anchors.centerIn: parent
        text:           mbRoot.label
        font.pixelSize: 10
        font.family:    mbRoot.mono ? "monospace" : ""
        color:          theme ? (mbRoot.aktiv ? theme.accent : theme.textMuted) : "transparent"
    }
    MouseArea {
        id: mbMaus; anchors.fill: parent; hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked:   mbRoot.klick()
    }
    ToolTip.visible: mbRoot.tooltip !== "" && mbMaus.containsMouse
    ToolTip.text:    mbRoot.tooltip
    ToolTip.delay:   500
}
