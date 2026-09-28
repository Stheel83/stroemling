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
        id: csvDialogStueckliste
        fileMode: FileDialog.SaveFile
        title: qsTr("Stückliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.stuecklisteCsvSpeichern(panel.projektId, selectedFile)
    }
    FileDialog {
        id: pdfDialogStueckliste
        fileMode: FileDialog.SaveFile
        title: qsTr("Stückliste als PDF speichern")
        nameFilters: ["PDF-Dateien (*.pdf)", "Alle Dateien (*)"]
        defaultSuffix: "pdf"
        onAccepted: {
            var spalten = panel.slCols.map(function (c) { return c.header })
            var zeilen = panel.slAnzeige.map(function (r) {
                return [r.bmk || "", r.symbolId || "", r.freitext1 || "", r.freitext2 || "",
                        r.seite || "", r.anlageUO || "", r.ortUO || "", r.anlageKz || "", r.ortKz || "", ""]
            })
            db.listePdfSpeichern(qsTr("Stückliste"), panel.projektName, spalten, zeilen, selectedFile)
        }
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Stückliste")
        anzahl: panel.slAnzeige.length
        filterText: panel.slFilter
        onFilterTextChanged: panel.slFilter = filterText
        onCsvKlick: csvDialogStueckliste.open()
        onPdfKlick: pdfDialogStueckliste.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    LaSpaltenHeader {
        panel: root.panel; theme: root.theme; colsProp: "slCols"
        sortFeld: panel.slSortFeld; sortAsc: panel.slSortAsc
        onSpalteKlick: (feld) => panel.sortSetzen("slSortFeld", "slSortAsc", feld)
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentWidth: availableWidth
        background: Rectangle { color: root.theme.surface }

        Column {
            width: parent.width

            Column {
                visible: panel.slAnzeige.length === 0
                width: parent.width; topPadding: 40
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId < 0 ? qsTr("Kein Projekt ausgewählt")
                        : (panel.slFilter ? qsTr("Kein Treffer für den Filter") : qsTr("Keine Symbole im Projekt"))
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0 && !panel.slFilter
                    text: qsTr("Symbole auf dem Schaltplan platzieren, um die Stückliste zu befüllen.")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            Repeater {
                model: panel.slAnzeige
                delegate: Rectangle {
                    width: parent.width; height: 30
                    property bool istGk: modelData.typ === "geraetekasten"
                    color: istGk
                        ? (index % 2 === 0 ? Qt.rgba(0, 0.53, 0.67, 0.13) : Qt.rgba(0, 0.53, 0.67, 0.08))
                        : (index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd)

                    // linker Akzentstreifen für Gerätekasten-Zeilen
                    Rectangle {
                        visible: istGk
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: 3; color: "#0088aa"
                    }

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { width: panel.slCols[0].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.bmk       || ""; font.pixelSize: 12; color: root.theme.accent;       elide: Text.ElideRight }
                        // Typ-Spalte: für GK mit Badge-Rechteck, für Symbole plain text
                        Item {
                            width: panel.slCols[1].w; height: 30
                            Rectangle {
                                visible: istGk
                                anchors.verticalCenter: parent.verticalCenter
                                width: gkBadgeText.implicitWidth + 10; height: 17; radius: 3
                                color: "#0d2a30"; border.color: "#0088aa"; border.width: 1
                                Text {
                                    id: gkBadgeText
                                    anchors.centerIn: parent
                                    text: "📐 GK"; font.pixelSize: 10; color: "#0088aa"
                                }
                            }
                            Text {
                                visible: !istGk
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; text: modelData.symbolId || ""
                                font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                            }
                        }
                        Text { width: panel.slCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.freitext1 || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.slCols[3].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.freitext2 || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.slCols[4].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.seite     || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                        Text { width: panel.slCols[5].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.anlageUO  || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                        Text { width: panel.slCols[6].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.ortUO     || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                        Text { width: panel.slCols[7].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.anlageKz  || ""; font.pixelSize: 12; color: root.theme.borderLight;   elide: Text.ElideRight }
                        Text { width: panel.slCols[8].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.ortKz     || ""; font.pixelSize: 12; color: root.theme.borderLight;   elide: Text.ElideRight }

                        Item {
                            width: panel.slCols[9].w; height: 30
                            Rectangle {
                                anchors.centerIn: parent
                                width: 20; height: 18; radius: 3
                                color: slSprungMa.containsMouse ? root.theme.accent : "transparent"
                                border.color: slSprungMa.containsMouse ? root.theme.accent : root.theme.border
                                Text {
                                    anchors.centerIn: parent
                                    text: "→"; font.pixelSize: 10
                                    color: slSprungMa.containsMouse ? "#ffffff" : root.theme.accent
                                }
                                MouseArea {
                                    id: slSprungMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    enabled: panel.canvas !== null
                                    onClicked: panel.canvas.bmElementSprungAnfordern(
                                        modelData.seiteId, modelData.seite, modelData.seiteBez,
                                        modelData.weltX, modelData.weltY)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
