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

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Querverweisliste")
        anzahl: panel._querverweisModel.count
        onCsvKlick: csvDialogQV.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    Rectangle {
        Layout.fillWidth: true; height: 30; color: theme.tableHeader
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Repeater {
                model: panel.qvCols
                delegate: Text { width: modelData.w; text: modelData.header;
                    font.pixelSize: 11; font.weight: Font.Medium; color: theme.textSubtle }
            }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

        ListView {
            id: qvView
            model: panel._querverweisModel; clip: true

            Column {
                visible: panel._querverweisModel.count === 0
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId >= 0 ? qsTr("Keine Querverweise im Projekt") : qsTr("Kein Projekt ausgewählt")
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0
                    text: qsTr("Querverweis-Linien im Canvas zeichnen (Werkzeug: ∿), um Querverweise zu erzeugen.")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            delegate: Rectangle {
                width: qvView.width; height: 30
                color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd
                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Text { width: panel.qvCols[0].w; anchors.verticalCenter: parent.verticalCenter; text: model.signalname || "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                    Text { width: panel.qvCols[1].w; anchors.verticalCenter: parent.verticalCenter; text: model.richtung   || ""; font.pixelSize: 12;
                           color: model.richtung === "ausgang" ? root.theme.accent : "#66ddaa"; elide: Text.ElideRight }
                    Text { width: panel.qvCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: model.seite      || ""; font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight }
                    Text { width: panel.qvCols[3].w; anchors.verticalCenter: parent.verticalCenter; text: model.zielSeite  || "–"; font.pixelSize: 12;
                           color: model.zielSeite ? root.theme.accentLight : root.theme.borderDark; elide: Text.ElideRight }
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
                                enabled: panel.canvas !== null && (model.seiteId || 0) > 0
                                onClicked: panel.canvas.bmElementSprungAnfordern(
                                    model.seiteId, model.seite, model.seiteBez, model.weltX, model.weltY)
                            }
                        }
                    }
                }
            }
        }
    }
}
