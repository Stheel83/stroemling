import QtQuick

Item {
    id: root

    property int logoIndex: 0

    width:  parent ? parent.width : 200
    height: 60

    readonly property var _icons: [
        "LogoIconSinus.qml",
        "LogoIconAtom.qml",
        "LogoIconBernstein.qml",
        "LogoIconCee.qml",
        "LogoIconOstsee.qml",
        "LogoIconFischKondensator.qml",
        "LogoIconFischSpule.qml",
        "LogoIconFischWiderstand.qml",
        "LogoIconFischDiode.qml"
    ]

    // Icon (links)
    Loader {
        id: iconLoader
        x: 4; y: 4
        width: 52; height: 52
        source: Qt.resolvedUrl(_icons[root.logoIndex % _icons.length])
    }

    // Text (rechts)
    Column {
        anchors {
            left:           iconLoader.right
            leftMargin:     8
            verticalCenter: parent.verticalCenter
        }
        spacing: 1

        Text {
            text:            "Strömling"
            font.family:     "Courier New"
            font.pixelSize:  15
            font.weight:     Font.Bold
            color:           "#e8f4f8"
        }
        Text {
            text:            "DESIGN"
            font.family:     "Courier New"
            font.pixelSize:  8
            font.letterSpacing: 4
            color:           "#3ecfcf"
            opacity:         0.9
        }
        Rectangle {
            width:  parent.width + 4
            height: 1
            color:  "#3ecfcf"
            opacity: 0.25
        }
        Text {
            text:            "CAE · OPEN SOURCE"
            font.family:     "Courier New"
            font.pixelSize:  6
            font.letterSpacing: 1
            color:           "#3ecfcf"
            opacity:         0.55
        }
    }
}
