import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Dialog {
    id: root

    property var theme
    property int rackId: -1
    property int projektId: -1

    property bool _istNeu: true
    property int  _editId: -1
    property int  _betriebsmittelId: 0
    property string _betriebsmittelKz: ""

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

        Label {
            text: qsTr("Platzierung")
            color: root.theme.textPrimary
            visible: !root._istNeu
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !root._istNeu
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root._betriebsmittelId > 0
                      ? qsTr("verknüpft mit %1").arg(root._betriebsmittelKz)
                      : qsTr("nicht platziert")
                color: root._betriebsmittelId > 0 ? root.theme.textPrimary : root.theme.textMuted
                elide: Text.ElideRight
            }
            Button {
                text: root._betriebsmittelId > 0 ? qsTr("Ändern…") : qsTr("Verknüpfen…")
                onClicked: verknuepfenPopup.open()
            }
            Button {
                text: qsTr("Entfernen")
                visible: root._betriebsmittelId > 0
                onClicked: {
                    db.spsBaugruppeBetriebsmittelSetzen(root._editId, 0)
                    root._betriebsmittelId = 0
                    root._betriebsmittelKz = ""
                }
            }
        }
    }

    Popup {
        id: verknuepfenPopup
        parent: Overlay.overlay
        modal: true
        anchors.centerIn: parent
        width: 280
        height: 320
        padding: 8

        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 5 }

        ColumnLayout {
            anchors.fill: parent
            spacing: 6

            Text {
                text: qsTr("Betriebsmittel wählen")
                color: root.theme.textPrimary
                font.pixelSize: 13; font.weight: Font.Medium
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: verknuepfenPopup.visible ? db.betriebsmittelListe(root.projektId) : []
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 30
                    color: bmMa.containsMouse ? root.theme.hover : "transparent"
                    Text {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        verticalAlignment: Text.AlignVCenter
                        color: root.theme.textPrimary
                        text: (modelData.kz || "") + "  " + (modelData.bezeichnung || "")
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: bmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            db.spsBaugruppeBetriebsmittelSetzen(root._editId, modelData.id)
                            root._betriebsmittelId = modelData.id
                            root._betriebsmittelKz = modelData.kz || ""
                            verknuepfenPopup.close()
                        }
                    }
                }
            }
        }
    }

    function oeffnenNeu() {
        _istNeu = true; _editId = -1
        bgSlotSpin.value = 0; bgTypCombo.currentIndex = 2
        bgBezField.text = ""; bgArtNrField.text = ""
        bgKanaeleSpin.value = 8; bgStartbyteSpin.value = 0
        _betriebsmittelId = 0; _betriebsmittelKz = ""
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
        _betriebsmittelId = bg.betriebsmittel_id || 0
        _betriebsmittelKz = bg.betriebsmittel_kz || ""
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
