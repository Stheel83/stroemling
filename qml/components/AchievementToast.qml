import QtQuick
import QtQuick.Layouts

// Steam-style Achievement-Toast – unten rechts, slide-in von rechts
// Verwendung: achievementToast.zeigen(titel, beschreibung)

Item {
    id: root

    property var theme

    width:  320
    height: toast.height

    function zeigen(titel, beschreibung) {
        toastTitel.text       = titel
        toastBeschreibung.text = beschreibung
        slideAnim.restart()
    }

    // Slide-Sequenz: einblenden → warten → ausblenden
    SequentialAnimation {
        id: slideAnim

        PropertyAction  { target: root;      property: "x";       value: root.parent ? root.parent.width : 800 }
        PropertyAction  { target: root;      property: "opacity"; value: 0 }
        PropertyAction  { target: root;      property: "visible"; value: true }
        ParallelAnimation {
            NumberAnimation { target: root; property: "x";       to: root.parent ? root.parent.width - root.width - 16 : 16; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "opacity"; to: 1;    duration: 200 }
        }
        PauseAnimation  { duration: 4500 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 400 }
        PropertyAction  { target: root; property: "visible"; value: false }
    }

    visible: false
    opacity: 0

    Rectangle {
        id:      toast
        width:   root.width
        height:  toastLayout.implicitHeight + 20
        radius:  6
        color:   root.theme ? root.theme.surface      : "#1e2a3a"
        border.color: root.theme ? root.theme.border  : "#2a3a4a"
        border.width: 1

        // Goldener Akzentstreifen links
        Rectangle {
            width:  3
            height: parent.height - 12
            radius: 2
            color:  root.theme ? root.theme.accent : "#c8a84b"
            anchors { left: parent.left; leftMargin: 0; verticalCenter: parent.verticalCenter }
        }

        ColumnLayout {
            id:      toastLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 14 }
            spacing: 2

            RowLayout {
                spacing: 8
                Text {
                    text:           "🏆"
                    font.pixelSize: 18
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    id:             toastTitel
                    text:           ""
                    font.pixelSize: 13
                    font.weight:    Font.Medium
                    color:          root.theme ? root.theme.textPrimary : "#e2eaf4"
                    Layout.fillWidth: true
                    elide:          Text.ElideRight
                }
            }
            Text {
                id:             toastBeschreibung
                text:           ""
                font.pixelSize: 11
                color:          root.theme ? root.theme.textMuted : "#8899aa"
                Layout.fillWidth:  true
                wrapMode:       Text.WordWrap
                leftPadding:    26
            }
        }
    }
}
