import QtQuick

Item {
    width: 52; height: 52
    property color iconBg: "#0d1b2a"

    Rectangle {
        anchors.fill: parent
        color: parent.iconBg
    }

    Image {
        anchors.fill: parent
        anchors.margins: 3
        source: "qrc:/assets/gruener_fisch_logo.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
    }
}
