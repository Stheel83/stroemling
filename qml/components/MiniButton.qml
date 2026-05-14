import QtQuick
import QtQuick.Controls

Rectangle {
    id: mbRoot

    required property var theme

    property string label:   ""
    property string tooltip: ""
    property bool   aktiv:   false
    property real   breite:  40
    property real   hoehe:   28
    property bool   mono:    false
    signal klick()

    width: breite; height: hoehe; radius: 4
    color:        aktiv ? theme.activeItemAlt : (mbMaus.containsMouse ? theme.hover : theme.inputBg)
    border.color: aktiv ? theme.accent : theme.border

    Text {
        anchors.centerIn: parent
        text:           mbRoot.label
        font.pixelSize: 10
        font.family:    mbRoot.mono ? "monospace" : ""
        color:          mbRoot.aktiv ? theme.accent : theme.textMuted
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
