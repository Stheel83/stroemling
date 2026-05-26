import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    required property var theme
    required property var textArea

    signal bildEinfuegenAngefordert()

    Layout.fillWidth: true
    height: visible ? 36 : 0
    color: root.theme.surfaceDeep

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 1; color: root.theme.border
    }

    // ── Formatier-Funktionen ──────────────────────────────────

    function _fmtWrap(vor, nach) {
        var sel = root.textArea.selectedText
        if (sel.length > 0) {
            var start = root.textArea.selectionStart
            var end   = root.textArea.selectionEnd
            root.textArea.remove(start, end)
            root.textArea.insert(start, vor + sel + nach)
            root.textArea.select(start + vor.length, start + vor.length + sel.length)
        } else {
            var pos = root.textArea.cursorPosition
            root.textArea.insert(pos, vor + nach)
            root.textArea.cursorPosition = pos + vor.length
        }
        root.textArea.forceActiveFocus()
    }

    function _fmtZeile(praefix) {
        var pos   = root.textArea.cursorPosition
        var txt   = root.textArea.text
        var start = pos
        while (start > 0 && txt[start - 1] !== '\n') start--
        if (txt.substring(start, start + praefix.length) === praefix)
            root.textArea.remove(start, start + praefix.length)
        else {
            root.textArea.insert(start, praefix)
            root.textArea.cursorPosition = pos + praefix.length
        }
        root.textArea.forceActiveFocus()
    }

    function _fmtEinfuegen(text) {
        root.textArea.insert(root.textArea.cursorPosition, text)
        root.textArea.forceActiveFocus()
    }

    function _fmtLink() {
        var sel   = root.textArea.selectedText
        var ltext = sel.length > 0 ? sel : "Linktext"
        var start = sel.length > 0 ? root.textArea.selectionStart : root.textArea.cursorPosition
        if (sel.length > 0)
            root.textArea.remove(root.textArea.selectionStart, root.textArea.selectionEnd)
        root.textArea.insert(start, "[" + ltext + "](https://)")
        root.textArea.cursorPosition = start + ltext.length + 11
        root.textArea.forceActiveFocus()
    }

    // ── Toolbar-Buttons ───────────────────────────────────────

    Row {
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 3

        // ── Inline-Formatierung ───────────────
        Rectangle {
            width: 26; height: 24; radius: 3
            color: tbBMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbBMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Fett (Ctrl+B)"
            Text { anchors.centerIn: parent; text: "B"; font.bold: true; font.pixelSize: 12; color: root.theme.textPrimary }
            MouseArea { id: tbBMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtWrap("**", "**") }
        }
        Rectangle {
            width: 26; height: 24; radius: 3
            color: tbIMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbIMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Kursiv (Ctrl+I)"
            Text { anchors.centerIn: parent; text: "I"; font.italic: true; font.pixelSize: 12; color: root.theme.textPrimary }
            MouseArea { id: tbIMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtWrap("*", "*") }
        }
        Rectangle {
            width: 26; height: 24; radius: 3
            color: tbSMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbSMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Durchgestrichen"
            Text { anchors.centerIn: parent; text: "S"; font.strikeout: true; font.pixelSize: 12; color: root.theme.textPrimary }
            MouseArea { id: tbSMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtWrap("~~", "~~") }
        }
        Rectangle {
            width: 26; height: 24; radius: 3
            color: tbCodeMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbCodeMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Code (inline)"
            Text { anchors.centerIn: parent; text: "`"; font.family: "monospace"; font.pixelSize: 13; color: root.theme.textPrimary }
            MouseArea { id: tbCodeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtWrap("`", "`") }
        }
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbLinkMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbLinkMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Link einfügen"
            Text { anchors.centerIn: parent; text: "🔗"; font.pixelSize: 11 }
            MouseArea { id: tbLinkMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtLink() }
        }

        Rectangle { width: 1; height: 20; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }

        // ── Überschriften ─────────────────────
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbH1Mouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbH1Mouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Überschrift 1"
            Text { anchors.centerIn: parent; text: "H1"; font.bold: true; font.pixelSize: 10; color: root.theme.textPrimary }
            MouseArea { id: tbH1Mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("# ") }
        }
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbH2Mouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbH2Mouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Überschrift 2"
            Text { anchors.centerIn: parent; text: "H2"; font.bold: true; font.pixelSize: 10; color: root.theme.textPrimary }
            MouseArea { id: tbH2Mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("## ") }
        }
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbH3Mouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbH3Mouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Überschrift 3"
            Text { anchors.centerIn: parent; text: "H3"; font.bold: true; font.pixelSize: 10; color: root.theme.textPrimary }
            MouseArea { id: tbH3Mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("### ") }
        }

        Rectangle { width: 1; height: 20; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }

        // ── Listen & Struktur ─────────────────
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbUlMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbUlMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Aufzählungsliste"
            Text { anchors.centerIn: parent; text: "• —"; font.pixelSize: 10; color: root.theme.textPrimary }
            MouseArea { id: tbUlMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("- ") }
        }
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbOlMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbOlMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Nummerierte Liste"
            Text { anchors.centerIn: parent; text: "1."; font.pixelSize: 10; color: root.theme.textPrimary }
            MouseArea { id: tbOlMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("1. ") }
        }
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbQMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbQMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Zitat"
            Text { anchors.centerIn: parent; text: "❝"; font.pixelSize: 12; color: root.theme.textPrimary }
            MouseArea { id: tbQMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("> ") }
        }

        Rectangle { width: 1; height: 20; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }

        // ── Trennlinie & Umbruch ──────────────
        Rectangle {
            width: 36; height: 24; radius: 3
            color: tbHrMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbHrMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Trennlinie"
            Text { anchors.centerIn: parent; text: "───"; font.pixelSize: 10; color: root.theme.textPrimary }
            MouseArea { id: tbHrMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtEinfuegen("\n\n---\n\n") }
        }
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbBrMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbBrMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Zeilenumbruch (innerhalb Absatz)"
            Text { anchors.centerIn: parent; text: "↵"; font.pixelSize: 13; color: root.theme.textPrimary }
            MouseArea { id: tbBrMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtEinfuegen("\\\n") }
        }

        Rectangle { width: 1; height: 20; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }

        // ── Bild einfügen ─────────────────────
        Rectangle {
            width: 28; height: 24; radius: 3
            color: tbImgMouse.containsMouse ? root.theme.hover : "transparent"
            border.color: root.theme.border
            ToolTip.visible: tbImgMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Bild in Text einfügen"
            Text { anchors.centerIn: parent; text: "🖼"; font.pixelSize: 12 }
            MouseArea { id: tbImgMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.bildEinfuegenAngefordert() }
        }
    }
}
