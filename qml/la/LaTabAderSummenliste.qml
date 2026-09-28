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
        id: csvDialogAderSumme
        fileMode: FileDialog.SaveFile
        title: qsTr("Adersummenliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.aderSummenlisteCsvSpeichern(panel.projektId, selectedFile)
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Adersummenliste")
        anzahl: panel._aderSummenlisteModel.count
        onCsvKlick: csvDialogAderSumme.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    LaSpaltenHeader { panel: root.panel; theme: root.theme; colsProp: "asCols" }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

        ListView {
            id: asView
            model: panel._aderSummenlisteModel; clip: true

            Column {
                visible: panel._aderSummenlisteModel.count === 0
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId >= 0 ? qsTr("Keine Aderdefinitionen im Projekt") : qsTr("Kein Projekt ausgewählt")
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0
                    text: qsTr("Fasst die Aderliste nach Aderfarbe + Querschnitt zusammen, Längen aufsummiert.")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            delegate: Rectangle {
                width: asView.width; height: 30
                color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd
                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Item {
                        width: panel.asCols[0].w; height: 30
                        AderfarbenSwatch {
                            id: asSwatch
                            aderCode:  model.aderfarbe  || ""
                            aderCode2: model.aderfarbe2 || ""
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            anchors { left: asSwatch.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            width: parent.width - (model.aderfarbe ? 18 : 0)
                            text: model.aderfarbe ? (model.aderfarbe + (model.aderfarbe2 ? "/" + model.aderfarbe2 : "")) : "–"
                            font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                        }
                    }
                    Text { width: panel.asCols[1].w; anchors.verticalCenter: parent.verticalCenter; text: model.querschnittMm2 > 0 ? model.querschnittMm2 + " mm²" : "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.asCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: model.anzahl; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text {
                        width: panel.asCols[3].w; anchors.verticalCenter: parent.verticalCenter
                        text: model.laengeGesamtM > 0 ? model.laengeGesamtM.toFixed(2) + " m" : "–"
                        font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
