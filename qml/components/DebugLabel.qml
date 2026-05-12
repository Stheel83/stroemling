import QtQuick

Rectangle {
    property string panelName: ""

    z:                   999
    anchors.top:         parent.top
    anchors.left:        parent.left
    anchors.topMargin:   3
    anchors.leftMargin:  3
    width:               lbl.implicitWidth + 10
    height:              18
    radius:              3
    color:               "#cc0a1628"
    border.color:        "#4a9eff"
    border.width:        1

    Text {
        id:              lbl
        anchors.centerIn: parent
        text:            panelName
        font.pixelSize:  9
        font.bold:       true
        color:           "#4a9eff"
    }
}
