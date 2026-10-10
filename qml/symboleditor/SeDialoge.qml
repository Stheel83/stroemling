import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Kleine Eingabe-/Rückfrage-Dialoge des Symboleditors. Die Dialoge halten keinen
// Editor-Zustand: der Aufrufer übergibt Parameter und reagiert auf die Signale.
Item {
    id: root
    required property var theme

    // Text-Primitiv einfügen: Position (Normkoordinaten) wird durchgereicht.
    signal textBestaetigt(string text, bool fett, real x, real y)
    signal loeschenBestaetigt(string symbolId)
    signal verwerfenBestaetigt()
    signal verwerfenAbgelehnt()

    property real   _textX: 0
    property real   _textY: 0
    property string _loeschenId:   ""
    property string _loeschenName: ""

    function textEingabeOeffnen(x, y) {
        _textX = x; _textY = y
        textEingabeDialog.open()
    }
    function speichernFehlerZeigen(text) {
        speichernFehlerText.text = text
        speichernFehlerDialog.open()
    }
    function loeschenFragen(symbolId, symbolName) {
        _loeschenId = symbolId; _loeschenName = symbolName
        loeschenConfirmDialog.open()
    }
    // SE-UNGESPEICHERT-WARNUNG-01: Rückfrage vor dem Verwerfen ungespeicherter Änderungen.
    function verwerfenFragen() { ungespeichertDialog.open() }

    Dialog {
        id:      textEingabeDialog
        title:   qsTr("Text-Primitiv einfügen")
        modal:   true
        parent:  Overlay.overlay
        anchors.centerIn: parent
        width:   340
        padding: 16

        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }

        ColumnLayout { spacing: 8; width: parent.width
            Text { text: qsTr("Textinhalt:"); color: root.theme.textMuted; font.pixelSize: 11 }
            TextField {
                id: textFeld
                Layout.fillWidth: true
                placeholderText: "M, 3~, ..."
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                color: root.theme.textPrimary; font.pixelSize: 13
            }
            Row {
                spacing: 12
                Text { text: qsTr("Fett:"); color: root.theme.textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                CheckBox { id: textFettCheck }
            }
        }
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (textFeld.text.length > 0)
                root.textBestaetigt(textFeld.text, textFettCheck.checked, root._textX, root._textY)
            textFeld.text = ""
        }
    }

    Dialog {
        id: speichernFehlerDialog
        title: qsTr("Fehler beim Speichern")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 340; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            id: speichernFehlerText
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Ok
    }

    Dialog {
        id:    loeschenConfirmDialog
        title: qsTr("Symbol löschen")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 340; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            text: qsTr("Symbol «%1» wirklich löschen?\nDieser Vorgang kann nicht rückgängig gemacht werden.").arg(root._loeschenName)
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            var id = root._loeschenId
            root._loeschenId = ""
            root._loeschenName = ""
            root.loeschenBestaetigt(id)
        }
    }

    Dialog {
        id:    ungespeichertDialog
        title: qsTr("Ungespeicherte Änderungen")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 340; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            text: qsTr("Dieses Symbol hat ungespeicherte Änderungen, die dabei verloren gehen. Trotzdem fortfahren?")
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: root.verwerfenBestaetigt()
        onRejected: root.verwerfenAbgelehnt()
    }
}
