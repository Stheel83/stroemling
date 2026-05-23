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

    LaCsvLeiste {
        theme: theme
        listenName: qsTr("Aderliste")
        anzahl: panel._aderlisteModel.count
        onCsvKlick: csvDialogAder.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    Rectangle {
        Layout.fillWidth: true; height: 30; color: theme.tableHeader
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Repeater {
                model: panel.alCols
                delegate: Text { width: modelData.w; text: modelData.header;
                    font.pixelSize: 11; font.weight: Font.Medium; color: theme.textSubtle }
            }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ListView {
        id: alView
        Layout.fillWidth: true; Layout.fillHeight: true
        model: panel._aderlisteModel; clip: true
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            width: alView.width; height: 30
            color: index % 2 === 0 ? theme.tableEven : theme.tableOdd
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 0
                Text { width: panel.alCols[0].w; text: model.bezeichnung    || "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                Item {
                    width: panel.alCols[1].w; height: 30
                    AderfarbenSwatch {
                        id: alSwatch
                        aderCode: model.aderfarbe || ""
                        width: 14; height: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        anchors { left: alSwatch.right; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        width: parent.width - (model.aderfarbe ? 18 : 0)
                        text: model.aderfarbe || "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight
                    }
                }
                Text { width: panel.alCols[2].w; text: model.querschnittMm2 > 0 ? model.querschnittMm2 + " mm²" : "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                Text { width: panel.alCols[3].w; text: model.laengeM        > 0 ? model.laengeM + " m"    : "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                Text { width: panel.alCols[4].w; text: model.seite          || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                Text { width: panel.alCols[5].w; text: model.anlageUO       || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                Text { width: panel.alCols[6].w; text: model.ortUO          || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                Text { width: panel.alCols[7].w; text: model.anlageKz       || ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                Text { width: panel.alCols[8].w; text: model.ortKz          || ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
            }
        }
    }
    Text {
        visible: panel._aderlisteModel.count === 0
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        text: panel.projektId >= 0 ? qsTr("Keine Aderdefinitionen im Projekt") : qsTr("Kein Projekt ausgewählt")
        font.pixelSize: 14; color: theme.borderDark
    }
}
