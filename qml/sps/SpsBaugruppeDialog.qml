import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Dialog {
    id: root

    property var theme
    property int rackId: -1

    property bool _istNeu: true
    property int  _editId: -1

    signal gespeichert(int newId)
    signal fehler(string meldung)

    title: _istNeu ? qsTr("Baugruppe anlegen") : qsTr("Baugruppe bearbeiten")
    modal: true
    anchors.centerIn: parent
    width: 400
    standardButtons: Dialog.Ok | Dialog.Cancel

    ColumnLayout {
        width: parent.width
        spacing: 8

        Label { text: qsTr("Slot"); color: root.theme.textPrimary }
        SpinBox {
            id: bgSlotSpin; from: 0; to: 31; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }

        Label { text: qsTr("Typ"); color: root.theme.textPrimary }
        ComboBox {
            id: bgTypCombo
            model: ["CPU","PS","DI","DO","DIO","AI","AO","AIO","CP","FM","andere"]
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }
        Label { text: qsTr("Bezeichnung"); color: root.theme.textPrimary }
        NavTextField {
            id: bgBezField; placeholderText: "SM 321"
            tabTarget: bgArtNrField; backtabTarget: bgArtNrField
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
            color: root.theme.textPrimary
        }
        Label { text: qsTr("Artikel-Nr."); color: root.theme.textPrimary }
        NavTextField {
            id: bgArtNrField; placeholderText: "6ES7 321-..."
            tabTarget: bgBezField; backtabTarget: bgBezField
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
            color: root.theme.textPrimary
        }
        Label { text: qsTr("Kanäle"); color: root.theme.textPrimary }
        SpinBox {
            id: bgKanaeleSpin; from: 1; to: 128; value: 8; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
        Label { text: qsTr("Startbyte (SPS)"); color: root.theme.textPrimary }
        SpinBox {
            id: bgStartbyteSpin; from: 0; to: 9999; value: 0; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
    }

    function oeffnenNeu() {
        _istNeu = true; _editId = -1
        bgSlotSpin.value = 0; bgTypCombo.currentIndex = 2
        bgBezField.text = ""; bgArtNrField.text = ""
        bgKanaeleSpin.value = 8; bgStartbyteSpin.value = 0
        open()
    }

    function oeffnenEdit(bg) {
        _istNeu = false; _editId = bg.id
        bgSlotSpin.value = bg.slot
        bgTypCombo.currentIndex = Math.max(0, bgTypCombo.model.indexOf(bg.typ))
        bgBezField.text = bg.bezeichnung
        bgArtNrField.text = bg.artikel_nr
        bgKanaeleSpin.value = bg.kanaele
        bgStartbyteSpin.value = bg.adress_byte_start
        open()
    }

    onAccepted: {
        if (_istNeu) {
            var newId = db.spsBaugruppeAnlegen(root.rackId,
                                                bgSlotSpin.value,
                                                bgTypCombo.currentText,
                                                bgBezField.text.trim(),
                                                bgKanaeleSpin.value,
                                                bgStartbyteSpin.value)
            if (newId < 0) root.fehler(qsTr("Baugruppe konnte nicht angelegt werden (Slot bereits belegt?)"))
            else           root.gespeichert(newId)
        } else {
            var ok = db.spsBaugruppeAktualisieren(_editId,
                                                   bgSlotSpin.value, bgTypCombo.currentText,
                                                   bgBezField.text.trim(), bgArtNrField.text.trim(),
                                                   bgKanaeleSpin.value, "BOOL",
                                                   bgStartbyteSpin.value, "")
            if (!ok) root.fehler(qsTr("Baugruppe konnte nicht gespeichert werden"))
            else     root.gespeichert(-1)
        }
    }
}
