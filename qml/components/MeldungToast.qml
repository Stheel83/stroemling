import QtQuick
import QtQuick.Layouts

// Status-Toast für nicht-blockierende Erfolgs-/Info-Meldungen – unten rechts,
// slide-in von rechts, analog zu AchievementToast. Queued: mehrere Meldungen
// kurz hintereinander werden nacheinander angezeigt statt sich zu überlagern.
// Verwendung: meldungToast.zeigen(text, erfolg)

Item {
    id: root

    property var theme

    width:  320
    height: toast.height

    property var _warteschlange: []

    function zeigen(text, erfolg) {
        _warteschlange.push({ text: text, erfolg: erfolg !== false })
        if (!slideAnim.running) _naechsteAnzeigen()
    }

    function _naechsteAnzeigen() {
        if (_warteschlange.length === 0) return
        var eintrag = _warteschlange.shift()
        toastText.text = eintrag.text
        toastIcon.text = eintrag.erfolg ? "✓" : "✗"
        toastBalken.color = eintrag.erfolg
            ? (root.theme ? root.theme.accent : "#3cb371")
            : "#c0392b"
        slideAnim.restart()
    }

    SequentialAnimation {
        id: slideAnim

        PropertyAction  { target: root;      property: "x";       value: root.parent ? root.parent.width : 800 }
        PropertyAction  { target: root;      property: "opacity"; value: 0 }
        PropertyAction  { target: root;      property: "visible"; value: true }
        ParallelAnimation {
            NumberAnimation { target: root; property: "x";       to: root.parent ? root.parent.width - root.width - 16 : 16; duration: 320; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "opacity"; to: 1;    duration: 200 }
        }
        PauseAnimation  { duration: 3000 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 400 }
        PropertyAction  { target: root; property: "visible"; value: false }
        ScriptAction    { script: root._naechsteAnzeigen() }
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

        Rectangle {
            id:     toastBalken
            width:  3
            height: parent.height - 12
            radius: 2
            color:  "#3cb371"
            anchors { left: parent.left; leftMargin: 0; verticalCenter: parent.verticalCenter }
        }

        RowLayout {
            id:      toastLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 10; leftMargin: 14 }
            spacing: 8

            Text {
                id:             toastIcon
                text:           "✓"
                font.pixelSize: 15
                color:          toastBalken.color
            }
            Text {
                id:             toastText
                text:           ""
                font.pixelSize: 12
                color:          root.theme ? root.theme.textPrimary : "#e2eaf4"
                Layout.fillWidth: true
                wrapMode:       Text.WordWrap
            }
        }
    }
}
