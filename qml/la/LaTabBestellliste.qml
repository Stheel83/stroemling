import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import stroemling

ColumnLayout {
    id: root
    required property var panel
    required property var theme
    spacing: 0

    FileDialog {
        id: csvDialogBestellliste
        fileMode: FileDialog.SaveFile
        title: qsTr("Bestellliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.bestellisteCsvSpeichern(panel.projektId, selectedFile)
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Bestellliste")
        anzahl: panel._bestellisteModel.count
        onCsvKlick: csvDialogBestellliste.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    LaSpaltenHeader { panel: root.panel; theme: root.theme; colsProp: "boCols" }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

        ListView {
            id: boView
            model: panel._bestellisteModel; clip: true

            Column {
                visible: panel._bestellisteModel.count === 0
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId >= 0 ? qsTr("Keine bestellbaren Bauteile im Projekt") : qsTr("Kein Projekt ausgewählt")
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0
                    text: qsTr("Nur Klemmen, Kabel und Geräte mit Bauteil-Verknüpfung erscheinen hier (v1).")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            delegate: Rectangle {
                width: boView.width; height: 30
                color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd

                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Text { width: panel.boCols[0].w; anchors.verticalCenter: parent.verticalCenter; text: model.bezeichnung   || ""; font.pixelSize: 12; color: root.theme.accent;         elide: Text.ElideRight }
                    Text { width: panel.boCols[1].w; anchors.verticalCenter: parent.verticalCenter; text: model.hersteller    || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.boCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: model.artikelnummer || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.boCols[3].w; anchors.verticalCenter: parent.verticalCenter; text: model.bestellnummer || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.boCols[4].w; anchors.verticalCenter: parent.verticalCenter; text: model.lieferant     || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text {
                        width: panel.boCols[5].w; anchors.verticalCenter: parent.verticalCenter
                        text: (model.einheit === "Stk" ? model.menge.toFixed(0) : model.menge.toFixed(2)) + " " + (model.einheit || "")
                        font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                    }
                    Text {
                        width: panel.boCols[6].w; anchors.verticalCenter: parent.verticalCenter
                        text: model.preisEur > 0 ? model.preisEur.toFixed(2) : "–"
                        font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                    }
                    Text {
                        width: panel.boCols[7].w; anchors.verticalCenter: parent.verticalCenter
                        text: model.summeEur > 0 ? model.summeEur.toFixed(2) : "–"
                        font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
