import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    required property var theme
    property int    kategorieId:   -1
    property string gewaehlterSymbolId: ""

    title:  qsTr("Neues Bauteil")
    modal:  true; parent: Overlay.overlay; anchors.centerIn: parent
    width:  480; padding: 20

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6
    }

    onOpened: {
        neuForm.bezeichnung   = ""; neuForm.hersteller    = ""
        neuForm.artikelnummer = ""; neuForm.lieferant     = ""
        neuForm.preis         = ""; neuForm.spannung      = ""
        neuForm.strom         = ""; neuForm.leistung      = ""
        neuForm.bemerkung     = ""
        root.gewaehlterSymbolId = ""
    }

    contentItem: ColumnLayout {
        spacing: 0
        Text { text: qsTr("Neues Bauteil"); font.pixelSize: 15; font.weight: Font.Medium;
               color: root.theme.textPrimary; Layout.bottomMargin: 2 }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.bottomMargin: 8 }
        ScrollView {
            Layout.fillWidth: true
            height: Math.min(neuForm.implicitHeight + 16, 460)
            clip: true
            BaFormContent { id: neuForm; theme: root.theme }
        }

        BaSymbolPickerDialog {
            id: neuSymbolPicker
            theme: root.theme
            onAccepted: root.gewaehlterSymbolId = ausgewaehltId
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.topMargin: 4; spacing: 4
            Text { text: qsTr("Symbol (Hauptfunktion)"); color: root.theme.textMuted; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 34
                    color: root.theme.inputBg; border.color: root.theme.border; radius: 4
                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                        text: root.gewaehlterSymbolId !== ""
                              ? root.gewaehlterSymbolId
                              : qsTr("(kein Symbol)")
                        color: root.gewaehlterSymbolId !== ""
                               ? root.theme.textPrimary : root.theme.textMuted
                        font.pixelSize: 13; font.italic: root.gewaehlterSymbolId === ""
                    }
                }
                Button {
                    text: qsTr("Waehlen …"); implicitHeight: 34; implicitWidth: 90
                    contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 12;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg;
                        radius: 4; border.color: root.theme.accent }
                    onClicked: {
                        neuSymbolPicker.aktuelleSymbolId = root.gewaehlterSymbolId
                        neuSymbolPicker.open()
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 12 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8; Layout.topMargin: 10
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }
            Button {
                text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                enabled: neuForm.bezeichnung.trim().length > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    const newId = bauteilModel.anlegen(
                        root.kategorieId,
                        neuForm.bezeichnung.trim(), neuForm.hersteller.trim(),
                        neuForm.artikelnummer.trim(), neuForm.lieferant.trim(),
                        parseFloat(neuForm.preis.replace(",","."))    || 0,
                        parseFloat(neuForm.spannung.replace(",",".")) || 0,
                        parseFloat(neuForm.strom.replace(",","."))    || 0,
                        parseFloat(neuForm.leistung.replace(",",".")) || 0,
                        neuForm.bemerkung.trim(),
                        neuForm.urlHersteller.trim(),
                        neuForm.urlDatenblatt.trim()
                    )
                    if (newId > 0 && root.gewaehlterSymbolId !== "")
                        bauteilModel.symbolSpeichern(newId, root.gewaehlterSymbolId)
                    if (newId > 0 && neuForm.bmkVorlage.trim() !== "")
                        bauteilModel.bmkVorlageSpeichern(newId, neuForm.bmkVorlage.trim())
                    root.close()
                }
            }
        }
    }
}
