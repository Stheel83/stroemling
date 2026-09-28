import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import stroemling
import "../components"

ColumnLayout {
    id: root
    required property var panel
    required property var theme
    spacing: 0

    readonly property real _gesamtLaengeM: {
        var s = 0
        for (var i = 0; i < panel.asAnzeige.length; i++) s += (panel.asAnzeige[i].laengeGesamtM || 0)
        return s
    }

    FileDialog {
        id: csvDialogAderSumme
        fileMode: FileDialog.SaveFile
        title: qsTr("Adersummenliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.aderSummenlisteCsvSpeichern(panel.projektId, selectedFile, panel.asJeAnlageOrt)
    }
    FileDialog {
        id: pdfDialogAderSumme
        fileMode: FileDialog.SaveFile
        title: qsTr("Adersummenliste als PDF speichern")
        nameFilters: ["PDF-Dateien (*.pdf)", "Alle Dateien (*)"]
        defaultSuffix: "pdf"
        onAccepted: {
            var spalten = panel.asJeAnlageOrt
                ? [qsTr("Anlage"), qsTr("Ort")].concat(panel.asCols.map(function (c) { return c.header }))
                : panel.asCols.map(function (c) { return c.header })
            var zeilen = panel.asAnzeige.map(function (r) {
                var farbe = r.aderfarbe ? (r.aderfarbe + (r.aderfarbe2 ? "/" + r.aderfarbe2 : "")) : "–"
                var basis = [farbe, r.querschnittMm2 > 0 ? r.querschnittMm2 + " mm²" : "–",
                             r.anzahl, r.laengeGesamtM > 0 ? r.laengeGesamtM.toFixed(2) + " m" : "–"]
                return panel.asJeAnlageOrt ? [r.anlageKz || "", r.ortKz || ""].concat(basis) : basis
            })
            db.listePdfSpeichern(qsTr("Adersummenliste"), panel.projektName, spalten, zeilen, selectedFile)
        }
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Adersummenliste")
        anzahl: panel.asAnzeige.length
        filterText: panel.asFilter
        onFilterTextChanged: panel.asFilter = filterText
        onCsvKlick: csvDialogAderSumme.open()
        onPdfKlick: pdfDialogAderSumme.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    // Umschalter: gesamt vs. je Anlage/Ort (LISTEN-IDEEN-01)
    Rectangle {
        Layout.fillWidth: true; height: 28; color: theme.surface
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 6
            Rectangle {
                width: 16; height: 16; radius: 3
                color: theme.hover; border.color: panel.asJeAnlageOrt ? theme.accent : theme.border
                Text {
                    anchors.centerIn: parent; visible: panel.asJeAnlageOrt
                    text: "✓"; font.pixelSize: 11; color: theme.accent
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.asJeAnlageOrt = !panel.asJeAnlageOrt
                }
            }
            Text {
                text: qsTr("je Anlage/Ort aufschlüsseln")
                font.pixelSize: 11; color: theme.textSubtle
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: panel.asJeAnlageOrt = !panel.asJeAnlageOrt }
            }
            Item { Layout.fillWidth: true }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    LaSpaltenHeader {
        panel: root.panel; theme: root.theme; colsProp: "asCols"
        sortFeld: panel.asJeAnlageOrt ? "" : panel.asSortFeld
        sortAsc:  panel.asSortAsc
        onSpalteKlick: (feld) => { if (!panel.asJeAnlageOrt) panel.sortSetzen("asSortFeld", "asSortAsc", feld) }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

        Column {
            width: parent.width

            Column {
                visible: panel.asAnzeige.length === 0
                width: parent.width; topPadding: 40
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId < 0 ? qsTr("Kein Projekt ausgewählt")
                        : (panel.asFilter ? qsTr("Kein Treffer für den Filter") : qsTr("Keine Aderdefinitionen im Projekt"))
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0 && !panel.asFilter
                    text: qsTr("Fasst die Aderliste nach Aderfarbe + Querschnitt zusammen, Längen aufsummiert.")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            Repeater {
                model: panel.asAnzeige
                delegate: Column {
                    width: parent.width
                    readonly property bool neueGruppe: panel.asJeAnlageOrt && (index === 0
                        || panel.asAnzeige[index - 1].anlageKz !== modelData.anlageKz
                        || panel.asAnzeige[index - 1].ortKz    !== modelData.ortKz)

                    Rectangle {
                        visible: neueGruppe
                        width: parent.width; height: 24; color: theme.tableHeader
                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: "🏭 " + (modelData.anlageKz || "–") + " · " + (modelData.ortKz || "–")
                            font.pixelSize: 11; font.weight: Font.Medium; color: theme.accentLight
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 30
                        color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd
                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 0
                            Item {
                                width: panel.asCols[0].w; height: 30
                                AderfarbenSwatch {
                                    id: asSwatch
                                    aderCode:  modelData.aderfarbe  || ""
                                    aderCode2: modelData.aderfarbe2 || ""
                                    width: 14; height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    anchors { left: asSwatch.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                    width: parent.width - (modelData.aderfarbe ? 18 : 0)
                                    text: modelData.aderfarbe ? (modelData.aderfarbe + (modelData.aderfarbe2 ? "/" + modelData.aderfarbe2 : "")) : "–"
                                    font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                                }
                            }
                            Text { width: panel.asCols[1].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.querschnittMm2 > 0 ? modelData.querschnittMm2 + " mm²" : "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.asCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.anzahl; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                            Text {
                                width: panel.asCols[3].w; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.laengeGesamtM > 0 ? modelData.laengeGesamtM.toFixed(2) + " m" : "–"
                                font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // Fußzeile: Gesamtlänge (LISTEN-IDEEN-01)
    Rectangle {
        visible: panel.asAnzeige.length > 0
        Layout.fillWidth: true; height: 28; color: theme.tableHeader
        Text {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: qsTr("Gesamtlänge: %1 m").arg(root._gesamtLaengeM.toFixed(2))
            font.pixelSize: 12; font.weight: Font.Medium; color: theme.accentLight
        }
    }
}
