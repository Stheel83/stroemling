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

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Stückliste")
        anzahl: panel._stuecklisteModel.count
        onCsvKlick: csvDialogStueckliste.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    Rectangle {
        Layout.fillWidth: true; height: 30; color: theme.tableHeader
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Repeater {
                model: panel.slCols
                delegate: Text { width: modelData.w; text: modelData.header;
                    font.pixelSize: 11; font.weight: Font.Medium; color: theme.textSubtle }
            }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

        ListView {
            id: slView
            model: panel._stuecklisteModel; clip: true

            Column {
                visible: panel._stuecklisteModel.count === 0
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId >= 0 ? qsTr("Keine Symbole im Projekt") : qsTr("Kein Projekt ausgewählt")
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0
                    text: qsTr("Symbole auf dem Schaltplan platzieren, um die Stückliste zu befüllen.")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            delegate: Rectangle {
                width: slView.width; height: 30
                property bool istGk: model.typ === "geraetekasten"
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
                    Text { width: panel.slCols[0].w; text: model.bmk       || ""; font.pixelSize: 12; color: root.theme.accent;       elide: Text.ElideRight }
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
                            width: parent.width; text: model.symbolId || ""
                            font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                        }
                    }
                    Text { width: panel.slCols[2].w; text: model.freitext1 || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.slCols[3].w; text: model.freitext2 || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.slCols[4].w; text: model.seite     || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                    Text { width: panel.slCols[5].w; text: model.anlageUO  || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                    Text { width: panel.slCols[6].w; text: model.ortUO     || ""; font.pixelSize: 12; color: root.theme.accentLight;   elide: Text.ElideRight }
                    Text { width: panel.slCols[7].w; text: model.anlageKz  || ""; font.pixelSize: 12; color: root.theme.borderLight;   elide: Text.ElideRight }
                    Text { width: panel.slCols[8].w; text: model.ortKz     || ""; font.pixelSize: 12; color: root.theme.borderLight;   elide: Text.ElideRight }
                }
            }
        }
    }
}
