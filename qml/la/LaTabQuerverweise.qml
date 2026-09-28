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
        id: csvDialogQV
        fileMode: FileDialog.SaveFile
        title: qsTr("Querverweisliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.querverweislisteCsvSpeichern(panel.projektId, selectedFile)
    }
    LaPdfExportDialog {
        id: pdfDialogQV
        theme: root.theme
        dateiname: "querverweisliste.pdf"
        titelText: qsTr("Querverweisliste exportieren")
        onExportAngefordert: (pfad) => {
            var spalten = panel.qvCols.map(function (c) { return c.header })
            var zeilen = panel.qvAnzeige.map(function (r) {
                return [r.signalname || "", r.richtung || "", r.seite || "", r.zielSeite || "", ""]
            })
            erfolgReagieren(db.listePdfSpeichern(qsTr("Querverweisliste"), panel.projektName, spalten, zeilen, pfad))
        }
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Querverweisliste")
        anzahl: panel.qvAnzeige.length
        filterText: panel.qvFilter
        onFilterTextChanged: panel.qvFilter = filterText
        onCsvKlick: csvDialogQV.open()
        onPdfKlick: pdfDialogQV.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    LaSpaltenHeader {
        panel: root.panel; theme: root.theme; colsProp: "qvCols"
        sortFeld: panel.qvSortFeld; sortAsc: panel.qvSortAsc
        onSpalteKlick: (feld) => panel.sortSetzen("qvSortFeld", "qvSortAsc", feld)
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentWidth: availableWidth
        background: Rectangle { color: root.theme.surface }

        Column {
            width: parent.width

            Column {
                visible: panel.qvAnzeige.length === 0
                width: parent.width; topPadding: 40
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId < 0 ? qsTr("Kein Projekt ausgewählt")
                        : (panel.qvFilter ? qsTr("Kein Treffer für den Filter") : qsTr("Keine Querverweise im Projekt"))
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0 && !panel.qvFilter
                    text: qsTr("Querverweis-Linien im Canvas zeichnen (Werkzeug: ∿), um Querverweise zu erzeugen.")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            Repeater {
                model: panel.qvAnzeige
                delegate: Rectangle {
                    width: parent.width; height: 30
                    color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { width: panel.qvCols[0].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.signalname || "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.qvCols[1].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.richtung   || ""; font.pixelSize: 12;
                               color: modelData.richtung === "ausgang" ? root.theme.accent : "#66ddaa"; elide: Text.ElideRight }
                        Text { width: panel.qvCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.seite      || ""; font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight }
                        Text { width: panel.qvCols[3].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.zielSeite  || "–"; font.pixelSize: 12;
                               color: modelData.zielSeite ? root.theme.accentLight : root.theme.borderDark; elide: Text.ElideRight }
                        Item {
                            width: panel.qvCols[4].w; height: 30
                            Rectangle {
                                anchors.centerIn: parent; width: 20; height: 18; radius: 3
                                color: qvSprungMa.containsMouse ? root.theme.accent : "transparent"
                                border.color: qvSprungMa.containsMouse ? root.theme.accent : root.theme.border
                                Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 10;
                                       color: qvSprungMa.containsMouse ? "#ffffff" : root.theme.accent }
                                MouseArea {
                                    id: qvSprungMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    enabled: panel.canvas !== null && (modelData.seiteId || 0) > 0
                                    onClicked: panel.canvas.bmElementSprungAnfordern(
                                        modelData.seiteId, modelData.seite, modelData.seiteBez, modelData.weltX, modelData.weltY)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
