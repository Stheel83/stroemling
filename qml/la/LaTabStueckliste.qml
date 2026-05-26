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
        theme: theme
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
        background: Rectangle { color: "transparent" }

        ListView {
            id: slView
            width: parent.width
            model: panel._stuecklisteModel; clip: true
        delegate: Rectangle {
            width: slView.width; height: 30
            color: index % 2 === 0 ? theme.tableEven : theme.tableOdd
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 0
                Text { width: panel.slCols[0].w; text: model.bmk       || ""; font.pixelSize: 12; color: theme.accent;       elide: Text.ElideRight }
                Text { width: panel.slCols[1].w; text: model.symbolId  || ""; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                Text { width: panel.slCols[2].w; text: model.freitext1 || ""; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                Text { width: panel.slCols[3].w; text: model.freitext2 || ""; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                Text { width: panel.slCols[4].w; text: model.seite     || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                Text { width: panel.slCols[5].w; text: model.anlageUO  || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                Text { width: panel.slCols[6].w; text: model.ortUO     || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                Text { width: panel.slCols[7].w; text: model.anlageKz  || ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                Text { width: panel.slCols[8].w; text: model.ortKz     || ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
            }
        }
    }
    Column {
        visible: panel._stuecklisteModel.count === 0
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: panel.projektId >= 0 ? qsTr("Keine Symbole im Projekt") : qsTr("Kein Projekt ausgewählt")
            font.pixelSize: 14; color: theme.borderDark
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: panel.projektId >= 0
            text: qsTr("Symbole auf dem Schaltplan platzieren, um die Stückliste zu befüllen.")
            font.pixelSize: 11; font.italic: true; color: theme.textMuted
        }
    }
    }
}
