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

    readonly property real _gesamtEur: {
        var s = 0
        for (var i = 0; i < panel.boAnzeige.length; i++) s += (panel.boAnzeige[i].summeEur || 0)
        return s
    }

    FileDialog {
        id: csvDialogBestellliste
        fileMode: FileDialog.SaveFile
        title: qsTr("Bestellliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.bestellisteCsvSpeichern(panel.projektId, selectedFile)
    }
    LaPdfExportDialog {
        id: pdfDialogBestellliste
        theme: root.theme
        dateiname: "bestellliste.pdf"
        titelText: qsTr("Bestellliste exportieren")
        onExportAngefordert: (pfad) => {
            var spalten = panel.boCols.map(function (c) { return c.header })
            var zeilen = panel.boAnzeige.map(function (r) {
                return [r.bezeichnung || "", r.hersteller || "", r.artikelnummer || "", r.bestellnummer || "",
                        r.lieferant || "",
                        (r.einheit === "Stk" ? r.menge.toFixed(0) : r.menge.toFixed(2)) + " " + (r.einheit || ""),
                        r.preisEur > 0 ? r.preisEur.toFixed(2) : "–",
                        r.summeEur > 0 ? r.summeEur.toFixed(2) : "–"]
            })
            erfolgReagieren(db.listePdfSpeichern(qsTr("Bestellliste"), panel.projektName, spalten, zeilen, pfad))
        }
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Bestellliste")
        anzahl: panel.boAnzeige.length
        filterText: panel.boFilter
        onFilterTextChanged: panel.boFilter = filterText
        onCsvKlick: csvDialogBestellliste.open()
        onPdfKlick: pdfDialogBestellliste.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    LaSpaltenHeader {
        panel: root.panel; theme: root.theme; colsProp: "boCols"
        sortFeld: panel.boSortFeld; sortAsc: panel.boSortAsc
        onSpalteKlick: (feld) => panel.sortSetzen("boSortFeld", "boSortAsc", feld)
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

        ListView {
            id: boView
            model: panel.boAnzeige; clip: true

            Column {
                visible: panel.boAnzeige.length === 0
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId < 0 ? qsTr("Kein Projekt ausgewählt")
                        : (panel.boFilter ? qsTr("Kein Treffer für den Filter") : qsTr("Keine bestellbaren Bauteile im Projekt"))
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0 && !panel.boFilter
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
                    Text { width: panel.boCols[0].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.bezeichnung   || ""; font.pixelSize: 12; color: root.theme.accent;         elide: Text.ElideRight }
                    Text { width: panel.boCols[1].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.hersteller    || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.boCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.artikelnummer || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.boCols[3].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.bestellnummer || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.boCols[4].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.lieferant     || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text {
                        width: panel.boCols[5].w; anchors.verticalCenter: parent.verticalCenter
                        text: (modelData.einheit === "Stk" ? modelData.menge.toFixed(0) : modelData.menge.toFixed(2)) + " " + (modelData.einheit || "")
                        font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                    }
                    Text {
                        width: panel.boCols[6].w; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.preisEur > 0 ? modelData.preisEur.toFixed(2) : "–"
                        font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                    }
                    Text {
                        width: panel.boCols[7].w; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.summeEur > 0 ? modelData.summeEur.toFixed(2) : "–"
                        font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // Fußzeile: Gesamtsumme EUR (LISTEN-IDEEN-01)
    Rectangle {
        visible: panel.boAnzeige.length > 0
        Layout.fillWidth: true; height: 28; color: theme.tableHeader
        Text {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: qsTr("Gesamtsumme: %1 EUR").arg(root._gesamtEur.toFixed(2))
            font.pixelSize: 12; font.weight: Font.Medium; color: theme.accentLight
        }
    }
}
