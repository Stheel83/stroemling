import QtQuick

// Einheitliches Label + Texteingabe-Feld für das EigenschaftenPanel.
// Ersetzt das Muster: FeldLabel { } + Rectangle { h:28 } + TextInput { }
//
// Verwendung:
//   InputField {
//       label:  qsTr("BMK")
//       value:  panel.s("bmk", "")
//       theme:  theme
//       onCommit: function(t) { canvas.eigenschaftAktualisieren("bmk", t) }
//   }
Item {
    id: root

    required property var    theme
    property  string         label:    ""
    property  var            value:    ""
    property  bool           readOnly: false

    signal commit(string text)

    width:          parent ? parent.width : 0
    implicitHeight: labelItem.height + boxRect.height

    // ── Label ────────────────────────────────────────────────────────────
    Item {
        id: labelItem
        width: parent.width
        height: root.label !== "" ? 20 : 0
        visible: root.label !== ""

        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text:           root.label
            font.pixelSize: 10
            color:          root.theme.panelMid
        }
    }

    // ── Eingabebox ───────────────────────────────────────────────────────
    Rectangle {
        id: boxRect
        anchors.top:              labelItem.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width:  parent.width - 16
        height: 28
        radius: 3
        color:        root.theme.inputBg
        border.color: tf.activeFocus ? root.theme.accent : root.theme.border
        opacity:      root.readOnly ? 0.6 : 1.0

        TextInput {
            id: tf
            anchors { fill: parent; margins: 5 }
            color:             root.readOnly ? root.theme.textMuted : root.theme.textSecondary
            font.pixelSize:    11
            verticalAlignment: TextInput.AlignVCenter
            readOnly:          root.readOnly

            text: root.value !== undefined ? (root.value + "") : ""

            Binding on text {
                when:    !tf.activeFocus
                value:   root.value !== undefined ? (root.value + "") : ""
                delayed: true
            }

            onEditingFinished: if (!root.readOnly) root.commit(text)
            Keys.onEscapePressed: { text = root.value !== undefined ? (root.value + "") : ""; focus = false }
        }
    }
}
