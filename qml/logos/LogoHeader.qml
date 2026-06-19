import QtQuick

Item {
    id: root

    property var theme: null   // AppTheme-Objekt; optional, Fallback = dunkel

    width:  parent ? parent.width : 200
    height: 72

    readonly property color _textMain:
        root.theme ? root.theme.textPrimary : "#e8f4f8"
    readonly property color _teal: "#3ecfcf"

    // Logo (links), feste Bilddatei statt rotierender Icons
    Image {
        id: logoImage
        x: 4
        y: (root.height - height) / 2
        height: 60
        width: 88
        fillMode: Image.PreserveAspectFit
        source: "qrc:/assets/stroemling_logo.png"
        smooth: true
    }

    // Text (rechts)
    Column {
        anchors {
            left:           logoImage.right
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
