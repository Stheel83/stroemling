import QtQuick

Rectangle {
    property string panelName: ""
    property string corner:    "tl"   // "tl" | "tr" | "bl" | "br"

    z:                    999
    anchors.top:          (corner === "tl" || corner === "tr") ? parent.top    : undefined
    anchors.bottom:       (corner === "bl" || corner === "br") ? parent.bottom : undefined
    anchors.left:         (corner === "tl" || corner === "bl") ? parent.left   : undefined
    anchors.right:        (corner === "tr" || corner === "br") ? parent.right  : undefined
    anchors.topMargin:    3
    anchors.bottomMargin: 3
    anchors.leftMargin:   3
    anchors.rightMargin:  3
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
