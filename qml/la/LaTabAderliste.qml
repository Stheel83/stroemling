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

    FileDialog {
        id: csvDialogAder
        fileMode: FileDialog.SaveFile
        title: qsTr("Aderliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.aderlisteCsvSpeichern(panel.projektId, selectedFile)
    }
    FileDialog {
        id: pdfDialogAder
        fileMode: FileDialog.SaveFile
        title: qsTr("Aderliste als PDF speichern")
        nameFilters: ["PDF-Dateien (*.pdf)", "Alle Dateien (*)"]
        defaultSuffix: "pdf"
        onAccepted: {
            var spalten = panel.alCols.map(function (c) { return c.header })
            var zeilen = panel.alAnzeige.map(function (r) {
                var farbe = r.aderfarbe ? (r.aderfarbe + (r.aderfarbe2 ? "/" + r.aderfarbe2 : "")) : "–"
                return [r.bezeichnung || "", farbe,
                        r.querschnittMm2 > 0 ? r.querschnittMm2 + " mm²" : "–",
                        r.laengeM > 0 ? r.laengeM + " m" : "–",
                        r.seite || "", r.anlageUO || "", r.ortUO || "", r.anlageKz || "", r.ortKz || "", ""]
            })
            db.listePdfSpeichern(qsTr("Aderliste"), panel.projektName, spalten, zeilen, selectedFile)
        }
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Aderliste")
        anzahl: panel.alAnzeige.length
        filterText: panel.alFilter
        onFilterTextChanged: panel.alFilter = filterText
        onCsvKlick: csvDialogAder.open()
        onPdfKlick: pdfDialogAder.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    LaSpaltenHeader {
        panel: root.panel; theme: root.theme; colsProp: "alCols"
        sortFeld: panel.alSortFeld; sortAsc: panel.alSortAsc
        onSpalteKlick: (feld) => panel.sortSetzen("alSortFeld", "alSortAsc", feld)
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentWidth: availableWidth
        background: Rectangle { color: root.theme.surface }

        Column {
            width: parent.width

            Column {
                visible: panel.alAnzeige.length === 0
                width: parent.width; topPadding: 40
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId < 0 ? qsTr("Kein Projekt ausgewählt")
                        : (panel.alFilter ? qsTr("Kein Treffer für den Filter") : qsTr("Keine Aderdefinitionen im Projekt"))
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0 && !panel.alFilter
                    text: qsTr("Kabel im Bauteilkatalog anlegen und dort Adern mit Querschnitt definieren.")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            Repeater {
                model: panel.alAnzeige
                delegate: Rectangle {
                    width: parent.width; height: 30
                    color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { width: panel.alCols[0].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.bezeichnung    || "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Item {
                            width: panel.alCols[1].w; height: 30
                            AderfarbenSwatch {
                                id: alSwatch
                                aderCode:  modelData.aderfarbe  || ""
                                aderCode2: modelData.aderfarbe2 || ""
                                width: 14; height: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                anchors { left: alSwatch.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                width: parent.width - (modelData.aderfarbe ? 18 : 0)
                                text: modelData.aderfarbe ? (modelData.aderfarbe + (modelData.aderfarbe2 ? "/" + modelData.aderfarbe2 : "")) : "–"
                                font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                            }
                        }
                        Text { width: panel.alCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.querschnittMm2 > 0 ? modelData.querschnittMm2 + " mm²" : "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.alCols[3].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.laengeM        > 0 ? modelData.laengeM + " m"    : "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.alCols[4].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.seite          || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                        Text { width: panel.alCols[5].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.anlageUO       || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                        Text { width: panel.alCols[6].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.ortUO          || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                        Text { width: panel.alCols[7].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.anlageKz       || ""; font.pixelSize: 12; color: root.theme.borderLight;   elide: Text.ElideRight }
                        Text { width: panel.alCols[8].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.ortKz          || ""; font.pixelSize: 12; color: root.theme.borderLight;   elide: Text.ElideRight }
                        Item {
                            width: panel.alCols[9].w; height: 30
                            Rectangle {
                                anchors.centerIn: parent; width: 20; height: 18; radius: 3
                                color: alSprungMa.containsMouse ? root.theme.accent : "transparent"
                                border.color: alSprungMa.containsMouse ? root.theme.accent : root.theme.border
                                Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 10;
                                       color: alSprungMa.containsMouse ? "#ffffff" : root.theme.accent }
                                MouseArea {
                                    id: alSprungMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    enabled: panel.canvas !== null && (modelData.seiteId || 0) > 0
                                    onClicked: panel.canvas.bmElementSprungAnfordern(
                                        modelData.seiteId, modelData.seite, "", modelData.weltX, modelData.weltY)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
