import QtQuick
import QtQuick.Controls

Slider {
    id: ssRoot

    required property var theme

    property real von:    0.0
    property real bis:    1.0
    property real schritt: 0.05
    property real wert:   0.5
    signal geaendert(real v)

    from: von; to: bis; stepSize: schritt; value: wert
    onMoved: ssRoot.geaendert(value)

    background: Rectangle {
        x: ssRoot.leftPadding; y: ssRoot.topPadding + ssRoot.availableHeight / 2 - 2
        width: ssRoot.availableWidth; height: 4; radius: 2; color: theme.border
        Rectangle {
            width: ssRoot.visualPosition * parent.width
            height: parent.height; radius: 2; color: theme.accent
        }
    }
    handle: Rectangle {
        x: ssRoot.leftPadding + ssRoot.visualPosition * ssRoot.availableWidth - 7
        y: ssRoot.topPadding  + ssRoot.availableHeight / 2 - 7
        width: 14; height: 14; radius: 7
        color: theme.accent; border.color: "#ffffff"; border.width: 1
    }
}
