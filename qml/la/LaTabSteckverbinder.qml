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
        id: csvDialog
        fileMode: FileDialog.SaveFile
        title: qsTr("Steckverbinderliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.steckverbinderlisteCsvSpeichern(panel.projektId, selectedFile)
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Steckverbinder")
        anzahl: panel._svDaten.length
        onCsvKlick: csvDialog.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    // Spalten-Header
    Rectangle {
        Layout.fillWidth: true; height: 30; color: root.theme.tableHeader
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Repeater {
                model: panel.svCols
                delegate: Text {
                    width: modelData.w; text: modelData.header
                    font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle
                }
            }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentWidth: availableWidth
        background: Rectangle { color: root.theme.surface }

        Column {
            width: parent.width

            Text {
                visible: panel._svDaten.length === 0
                width: parent.width; padding: 24
                text: panel.projektId >= 0
                    ? qsTr("Keine Steckverbinder-Gerätekästen im Projekt.\nGerätekasten zeichnen (G), dann im BAUTEILE-Panel ein Steckverbinder-Bauteil verknüpfen.")
                    : qsTr("Kein Projekt ausgewählt")
                font.pixelSize: 12; color: root.theme.textMuted
                font.italic: true; wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: panel._svDaten
                delegate: Rectangle {
                    width: parent.width; height: 30
                    color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd

                    // linker teal-Streifen
                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: 3; color: "#0088aa"
                    }

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { width: panel.svCols[0].w; text: modelData.bmk          || ""; font.pixelSize: 12; color: root.theme.accent;        elide: Text.ElideRight }
                        Text { width: panel.svCols[1].w; text: modelData.gkBezeichnung|| ""; font.pixelSize: 12; color: root.theme.textSecondary;  elide: Text.ElideRight }
                        Text { width: panel.svCols[2].w; text: modelData.bauteilBez   || ""; font.pixelSize: 12; color: root.theme.textPrimary;    elide: Text.ElideRight }
                        Text { width: panel.svCols[3].w; text: modelData.hersteller   || ""; font.pixelSize: 12; color: root.theme.textSecondary;  elide: Text.ElideRight }
                        Text { width: panel.svCols[4].w; text: modelData.polzahl > 0 ? modelData.polzahl + qsTr("-pol") : ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.svCols[5].w; text: modelData.ipGesteckt  || ""; font.pixelSize: 12; color: root.theme.textMuted;       elide: Text.ElideRight }
                        Text { width: panel.svCols[6].w; text: modelData.kodierung   || ""; font.pixelSize: 12; color: root.theme.textMuted;       elide: Text.ElideRight }
                        // Geschirmt-Badge
                        Item {
                            width: panel.svCols[7].w; height: 30
                            Rectangle {
                                visible: modelData.geschirmt
                                anchors.verticalCenter: parent.verticalCenter
                                width: shText.implicitWidth + 8; height: 16; radius: 3
                                color: "#1a2a1a"; border.color: "#44aa44"; border.width: 1
                                Text { id: shText; anchors.centerIn: parent; text: "SH"; font.pixelSize: 10; color: "#66cc66" }
                            }
                            Text {
                                visible: !modelData.geschirmt
                                anchors.verticalCenter: parent.verticalCenter
                                text: "–"; font.pixelSize: 12; color: root.theme.borderDark
                            }
                        }
                        Text { width: panel.svCols[8].w; text: modelData.blattnr || ""; font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight }
                    }
                }
            }
        }
    }
}
