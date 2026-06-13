import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Dialog {
    id: root

    property var theme
    property int projektId: -1

    property bool _istNeu: true
    property int  _editId: -1

    signal gespeichert(int newId)
    signal fehler(string meldung)

    title: _istNeu ? qsTr("Rack anlegen") : qsTr("Rack bearbeiten")
    modal: true
    anchors.centerIn: parent
    width: 380
    standardButtons: Dialog.Ok | Dialog.Cancel

    ColumnLayout {
        width: parent.width
        spacing: 8

        Label { text: qsTr("Rack-Nummer"); color: root.theme.textPrimary }
        SpinBox {
            id: rackNrSpin
            from: 0; to: 99
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
        Label { text: qsTr("System-Typ"); color: root.theme.textPrimary }
        ComboBox {
            id: systemTypCombo
            model: ["SPS", "PLS"]
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }
        Label { text: qsTr("Bezeichnung"); color: root.theme.textPrimary }
        NavTextField {
            id: rackBezField
            placeholderText: "Rack 0"
            tabTarget: rackHerstellerField; backtabTarget: rackHerstellerField
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
            color: root.theme.textPrimary
        }
        Label { text: qsTr("Hersteller"); color: root.theme.textPrimary }
        NavTextField {
            id: rackHerstellerField
            placeholderText: "Siemens"
            tabTarget: rackBezField; backtabTarget: rackBezField
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
            color: root.theme.textPrimary
        }
    }

    function oeffnenNeu() {
        _istNeu = true; _editId = -1
        rackNrSpin.value = 0
        systemTypCombo.currentIndex = 0
        rackBezField.text = ""
        rackHerstellerField.text = ""
        open()
    }

    function oeffnenEdit(rack) {
        _istNeu = false; _editId = rack.id
        rackNrSpin.value = rack.rack_nr
        systemTypCombo.currentIndex = rack.system_typ === "PLS" ? 1 : 0
        rackBezField.text = rack.bezeichnung
        rackHerstellerField.text = rack.hersteller
        open()
    }

    onAccepted: {
        var bez = rackBezField.text.trim() || ("Rack " + rackNrSpin.value)
        if (_istNeu) {
            var newId = db.spsRackAnlegen(root.projektId,
                                           rackNrSpin.value,
                                           systemTypCombo.currentText,
                                           bez,
                                           rackHerstellerField.text.trim())
            if (newId > 0) root.gespeichert(newId)
            else           root.fehler(qsTr("Rack konnte nicht angelegt werden (Rack-Nr. bereits vergeben?)"))
        } else {
            var ok = db.spsRackAktualisieren(_editId, rackNrSpin.value,
                                              systemTypCombo.currentText,
                                              bez, "", rackHerstellerField.text.trim())
            if (ok) root.gespeichert(-1)
            else    root.fehler(qsTr("Rack konnte nicht gespeichert werden"))
        }
    }
}
