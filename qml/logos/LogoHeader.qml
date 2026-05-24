import QtQuick

Item {
    id: root

    property int logoIndex: 0
    property var theme: null   // AppTheme-Objekt; optional, Fallback = dunkel

    width:  parent ? parent.width : 200
    height: 72

    readonly property var _icons: [
        "LogoIconSinus.qml",
        "LogoIconAtom.qml",
        "LogoIconBernstein.qml",
        "LogoIconCee.qml",
        "LogoIconOstsee.qml",
        "LogoIconGruenerFisch.qml"
    ]

    readonly property color _iconBg:
        root.theme ? root.theme.sidebar : "#0d1b2a"
    readonly property color _textMain:
        root.theme ? root.theme.textPrimary : "#e8f4f8"
    readonly property color _teal: "#3ecfcf"

    // Icon (links)
    Loader {
        id: iconLoader
        x: 4; y: 6
        width: 52; height: 52
        source: Qt.resolvedUrl(_icons[root.logoIndex % _icons.length])
        onLoaded: {
            if (item && item.hasOwnProperty("iconBg"))
                item.iconBg = Qt.binding(function() { return root._iconBg })
        }
    }

    // Hintergrund für Icon-Bereich (Theme-Farbe)
    Rectangle {
        x: 4; y: 6; width: 52; height: 52
        color: root._iconBg
        z: -1
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
            text:               "Strömling"
            font.family:        "Courier New"
            font.pixelSize:     18
            font.weight:        Font.Bold
            color:              root._textMain
        }
        Text {
            text:               "DESIGN"
            font.family:        "Courier New"
            font.pixelSize:     11
            font.letterSpacing: 4
            color:              root._teal
            opacity:            0.9
        }
        Rectangle {
            width:   110
            height:  1
            color:   root._teal
            opacity: 0.25
        }
        Text {
            text:               "CAE · OPEN SOURCE · NORDDEUTSCH"
            font.family:        "Courier New"
            font.pixelSize:     8
            font.letterSpacing: 0.2
            color:              root._teal
            opacity:            0.7
            elide:              Text.ElideRight
        }
    }
}
