import QtQuick

Item {
    id: mfRoot

    required property var theme

    property string label:   ""
    property string einheit: ""
    property real   wert:    0
    signal wertGeaendert(real wert)

    width: parent.width; height: 28

    Row {
        anchors { left: mfRoot.left; leftMargin: 12; verticalCenter: mfRoot.verticalCenter }
        spacing: 8

        Text {
            text: mfRoot.label; width: 56
            color: theme.borderLight; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            width: 76; height: 22; radius: 4
            color: theme.inputBg; border.color: tf.activeFocus ? theme.accent : theme.border
            anchors.verticalCenter: parent.verticalCenter

            TextInput {
                id: tf
                anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                color: theme.textSecondary; font.pixelSize: 11; verticalAlignment: TextInput.AlignVCenter
                validator: DoubleValidator { bottom: -9999; top: 9999; decimals: 1; notation: DoubleValidator.StandardNotation }

                text: mfRoot.wert.toFixed(1)
                Binding on text {
                    when: !tf.activeFocus
                    value: mfRoot.wert.toFixed(1)
                }
                onEditingFinished: {
                    var v = parseFloat(text)
                    if (!isNaN(v)) mfRoot.wertGeaendert(v)
                }
                Keys.onEscapePressed: { text = mfRoot.wert.toFixed(1); focus = false }
            }
        }
        Text {
            text: mfRoot.einheit
            color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
        }
    }
}
