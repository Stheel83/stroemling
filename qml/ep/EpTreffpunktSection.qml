import QtQuick

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "symbol"
              && (panel.el.symbolId === "treffpunkt"
               || panel.el.symbolId === "treffpunkt_l")) ? treffCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    readonly property string zielRichtung: {
        var r = panel.s("rotation", 0)
        if      (r === 0)   return "↓  Unten"
        else if (r === 90)  return "←  Links"
        else if (r === 180) return "↑  Oben"
        else                return "→  Rechts"
    }

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
        id: treffCol
        width: parent.width
        spacing: 0

        Trennlinie {}
        AbschnittTitel {
            text: (panel.el && panel.el.symbolId === "treffpunkt_l")
                  ? "TREFFPUNKT L  (Quellen 90°)" : "TREFFPUNKT  (Quellen 180°)"
        }

        FeldLabel { text: qsTr("Ziel-Richtung") }
        Rectangle {
            width: parent.width - 16; height: 28; radius: 4
            anchors.horizontalCenter: parent.horizontalCenter
            color: theme.surface; border.color: theme.border; border.width: 1
            Text {
                anchors { fill: parent; leftMargin: 8 }
                verticalAlignment: Text.AlignVCenter
                text:           root.zielRichtung
                color:          theme.accent
                font.pixelSize: 12
            }
        }
        Item { height: 6 }
    }
}
