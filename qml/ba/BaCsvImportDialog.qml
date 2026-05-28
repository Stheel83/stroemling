import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// CSV-Import: FileDialog → Spalten-Mapping-Dialog → Import.
Item {
    id: root
    required property var theme

    function open() { csvFileDialog.open() }

    FileDialog {
        id:          csvFileDialog
        title:       qsTr("CSV-Datei auswählen")
        nameFilters: [qsTr("CSV-Dateien (*.csv *.txt)"), qsTr("Alle Dateien (*)")]
        onAccepted: {
            dlgCsvMapping._pfad = selectedFile.toString().replace("file://", "")
            dlgCsvMapping.open()
        }
    }

    Dialog {
        id:    dlgCsvMapping
        title: qsTr("CSV-Datei importieren")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: 540; padding: 0
        closePolicy: Popup.CloseOnEscape

        property string _pfad:       ""
        property var    _spalten:    []
        property var    _kategorien: []
        property int    _importiert: -1

        onOpened: {
            _spalten    = db.csvKopfzeile(_pfad)
            _kategorien = db.bauteilAlleKategorienFlach()
            _importiert = -1
        }

        background: Rectangle {
            color: root.theme.sidebar; radius: 6
            border.color: root.theme.border; border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            // ── Kopf ──────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 20; Layout.bottomMargin: 12
                spacing: 6
                Text {
                    text:           dlgCsvMapping.title
                    font.pixelSize: 15; font.weight: Font.Medium
                    color:          root.theme.textPrimary
                }
                Text {
                    visible:          dlgCsvMapping._spalten.length > 0
                    text:             qsTr("%1 Spalten erkannt: %2")
                                          .arg(dlgCsvMapping._spalten.length)
                                          .arg(dlgCsvMapping._spalten.join(", "))
                    font.pixelSize:   10; color: root.theme.textMuted
                    wrapMode:         Text.Wrap; Layout.fillWidth: true
                }
                Text {
                    visible:        dlgCsvMapping._spalten.length === 0
                    text:           qsTr("Keine Spalten erkannt – Datei prüfen")
                    font.pixelSize: 10; color: "#e74c3c"
                }
                Text {
                    visible:        dlgCsvMapping._importiert >= 0
                    text:           qsTr("%1 Bauteile importiert").arg(dlgCsvMapping._importiert)
                    font.pixelSize: 11; color: "#27ae60"; font.weight: Font.Medium
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // ── Zielkategorie ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 20; Layout.topMargin: 12; Layout.bottomMargin: 8
                spacing: 10
                Text {
                    text: qsTr("Zielkategorie:")
                    font.pixelSize: 12; color: root.theme.textMuted; width: 130
                }
                ComboBox {
                    id:               cmbZielkat
                    Layout.fillWidth: true
                    model:            dlgCsvMapping._kategorien
                    textRole:         "name"
                    font.pixelSize:   12
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text {
                        leftPadding: 8; text: cmbZielkat.displayText; font: cmbZielkat.font
                        color: root.theme.textPrimary; verticalAlignment: Text.AlignVCenter
                    }
                    delegate: ItemDelegate {
                        width: cmbZielkat.width
                        contentItem: Text {
                            text: modelData.name; font: cmbZielkat.font
                            color: root.theme.textPrimary; verticalAlignment: Text.AlignVCenter
                        }
                        highlighted: cmbZielkat.highlightedIndex === index
                        background: Rectangle { color: highlighted ? root.theme.hover : root.theme.inputBg }
                    }
                    popup: Popup {
                        y: cmbZielkat.height; width: cmbZielkat.width; padding: 1
                        contentItem: ListView {
                            clip: true; implicitHeight: Math.min(contentHeight, 200)
                            model: cmbZielkat.delegateModel
                            ScrollIndicator.vertical: ScrollIndicator {}
                        }
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }

            // ── Spalten-Zuordnung ──────────────────────────────
            Text {
                text:           qsTr("Spalten zuordnen:")
                font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textMuted
                Layout.margins: 20; Layout.bottomMargin: 6
            }

            Repeater {
                id: feldRepeater
                model: [
                    { dbFeld: "bezeichnung",   label: qsTr("Bezeichnung *") },
                    { dbFeld: "hersteller",    label: qsTr("Hersteller") },
                    { dbFeld: "artikelnummer", label: qsTr("Artikelnummer") },
                    { dbFeld: "lieferant",     label: qsTr("Lieferant") },
                    { dbFeld: "bestellnummer", label: qsTr("Bestellnummer") },
                    { dbFeld: "preis_eur",     label: qsTr("Preis (EUR)") },
                    { dbFeld: "spannung_v",    label: qsTr("Spannung (V)") },
                    { dbFeld: "strom_a",       label: qsTr("Strom (A)") },
                    { dbFeld: "leistung_w",    label: qsTr("Leistung (W)") },
                    { dbFeld: "bemerkung",     label: qsTr("Bemerkung") }
                ]

                delegate: RowLayout {
                    property string dbFeld:    modelData.dbFeld
                    property int    csvColIdx: cmbFeld.currentIndex - 1

                    Layout.fillWidth: true
                    Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.bottomMargin: 3
                    spacing: 10

                    Text {
                        text:           modelData.label
                        font.pixelSize: 12
                        color:          modelData.dbFeld === "bezeichnung"
                                        ? root.theme.textPrimary : root.theme.textMuted
                        width:          130
                    }
                    ComboBox {
                        id:               cmbFeld
                        Layout.fillWidth: true; implicitHeight: 28; font.pixelSize: 11
                        model:            [qsTr("(nicht importieren)")].concat(dlgCsvMapping._spalten)
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                        contentItem: Text {
                            leftPadding: 8; text: cmbFeld.displayText; font: cmbFeld.font
                            color: cmbFeld.currentIndex === 0 ? root.theme.textMuted : root.theme.textPrimary
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 12 }

            // ── Buttons ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 16; Layout.topMargin: 12
                spacing: 8

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Schließen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    onClicked: dlgCsvMapping.close()
                }

                Button {
                    text:          qsTr("Importieren")
                    implicitWidth: 110; implicitHeight: 34
                    enabled:       dlgCsvMapping._spalten.length > 0 && feldRepeater.count > 0 &&
                                   feldRepeater.itemAt(0) !== null &&
                                   feldRepeater.itemAt(0).csvColIdx >= 0
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                    }
                    onClicked: {
                        var mapping = {}
                        for (var i = 0; i < feldRepeater.count; i++) {
                            var item = feldRepeater.itemAt(i)
                            if (item && item.csvColIdx >= 0)
                                mapping[item.dbFeld] = item.csvColIdx
                        }
                        var katId = (dlgCsvMapping._kategorien.length > 0 && cmbZielkat.currentIndex >= 0)
                            ? dlgCsvMapping._kategorien[cmbZielkat.currentIndex].id : -1
                        var n = db.csvBauteileImportieren(dlgCsvMapping._pfad, katId, mapping)
                        dlgCsvMapping._importiert = n
                        if (n >= 0) {
                            bauteilModel.laden(-1)
                            kategorieModel.laden()
                        }
                    }
                }
            }
        }
    }
}
