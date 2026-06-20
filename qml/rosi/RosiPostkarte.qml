import QtQuick
import QtQuick.Layouts

// Postkarte/Nachricht aus dem Urlaub — bewusst KEIN Pipe-Auftritt von Rosi
// selbst (siehe konzept/features/48_rosi_roehrenaal.md §4), sondern eine
// eigene kleine Toast-Variante, an MeldungToast.qml angelehnt aber unten
// links statt unten rechts verankert und mit Briefumschlag-Icon statt ✓/✗.
// Verwendung: rosiPostkarte.zeigen(text) – ausgelöst von rosiManager.postkarteAngekommen.

Item {
    id: root

    property var theme

    width:  280
    height: karte.height

    function zeigen(text) {
        karteText.text = text
        slideAnim.restart()
    }

    SequentialAnimation {
        id: slideAnim

        PropertyAction  { target: root; property: "x";       value: -root.width }
        PropertyAction  { target: root; property: "opacity"; value: 0 }
        PropertyAction  { target: root; property: "visible"; value: true }
        ParallelAnimation {
            NumberAnimation { target: root; property: "x";       to: 16; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "opacity"; to: 1;  duration: 200 }
        }
        PauseAnimation  { duration: 4000 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 400 }
        PropertyAction  { target: root; property: "visible"; value: false }
    }

    visible: false
    opacity: 0

    Rectangle {
        id:      karte
        width:   root.width
        height:  karteLayout.implicitHeight + 20
        radius:  6
        color:        root.theme ? root.theme.surface : "#1e2a3a"
        border.color: root.theme ? root.theme.border  : "#2a3a4a"
        border.width: 1

        Rectangle {
            width:  3
            height: parent.height - 12
            radius: 2
            color:  "#E91E63"
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        }

        RowLayout {
            id:      karteLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 10; leftMargin: 14 }
            spacing: 8

            Text {
                text:           "✉"
                font.pixelSize: 15
                color:          "#E91E63"
            }
            Text {
                id:               karteText
                text:             ""
                font.pixelSize:   12
                color:            root.theme ? root.theme.textPrimary : "#e2eaf4"
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
            }
        }
    }
}
