import QtQuick

Item {
    id: root

    property var theme: null   // AppTheme-Objekt; optional, Fallback = dunkel

    width:  parent ? parent.width : 200
    height: 92

    readonly property color _textMain:
        root.theme ? root.theme.textPrimary : "#e8f4f8"
    readonly property color _fischGruen:
        root.theme ? root.theme.logoGruen : "#55d400"   // pro Theme kontrastoptimiert (AppTheme.qml)

    // Logo (links), feste Bilddatei statt rotierender Icons
    Image {
        id: logoImage
        x: 4
        y: (root.height - height) / 2
        height: 74
        width: 109
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
        spacing: 2

        Text {
            text:               "Strömling"
            font.family:        "Courier New"
            font.pixelSize:     22
            font.weight:        Font.Bold
            color:              root._textMain
        }
        Text {
            text:               "DESIGN"
            font.family:        "Courier New"
            font.pixelSize:     14
            font.letterSpacing: 4
            color:              root._fischGruen
            opacity:            0.9
        }
        Rectangle {
            width:   130
            height:  1
            color:   root._fischGruen
            opacity: 0.25
        }
        Text {
            text:               "CAE · OPEN SOURCE"
            font.family:        "Courier New"
            font.pixelSize:     10
            font.letterSpacing: 0.3
            color:              root._fischGruen
            opacity:            0.7
            elide:              Text.ElideRight
        }
        Text {
            text:               "NORDDEUTSCH"
            font.family:        "Courier New"
            font.pixelSize:     10
            font.letterSpacing: 0.3
            color:              root._fischGruen
            opacity:            0.7
            elide:              Text.ElideRight
        }
    }
}
