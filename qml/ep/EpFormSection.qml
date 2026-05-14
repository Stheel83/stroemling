import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "rechteck") ? formCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    Column {
        id: formCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("FORM") }

        FeldLabel { text: qsTr("Eckenradius  ") + Math.round(panel.s("eckenRadius", 0)) + " mm" }
        StilSlider { theme: theme;
            height: 36
            width: root.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 20; schritt: 1
            wert: panel.s("eckenRadius", 0)
            onGeaendert: function(v) { canvas.eigenschaftAktualisieren("eckenRadius", v) }
        }
    }
}
