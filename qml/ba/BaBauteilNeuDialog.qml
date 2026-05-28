import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    required property var theme
    property int kategorieId: -1

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
                    bauteilModel.anlegen(
                        root.kategorieId,
                        neuForm.bezeichnung.trim(), neuForm.hersteller.trim(),
                        neuForm.artikelnummer.trim(), neuForm.lieferant.trim(),
                        parseFloat(neuForm.preis)    || 0,
                        parseFloat(neuForm.spannung) || 0,
                        parseFloat(neuForm.strom)    || 0,
                        parseFloat(neuForm.leistung) || 0,
                        neuForm.bemerkung.trim()
                    )
                    root.close()
                }
            }
        }
    }
}
