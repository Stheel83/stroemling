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
        theme: theme
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

    Rectangle {
        Layout.fillWidth: true; Layout.fillHeight: true
        color: theme.surface

    ListView {
        id: qvView
        anchors.fill: parent
        model: panel._querverweisModel; clip: true
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            width: qvView.width; height: 30
            color: index % 2 === 0 ? theme.tableEven : theme.tableOdd
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 0
                Text { width: panel.qvCols[0].w; text: model.signalname || "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                Text { width: panel.qvCols[1].w; text: model.richtung   || ""; font.pixelSize: 12;
                       color: model.richtung === "ausgang" ? theme.accent : "#66ddaa"; elide: Text.ElideRight }
                Text { width: panel.qvCols[2].w; text: model.seite      || ""; font.pixelSize: 12; color: theme.accentLight; elide: Text.ElideRight }
                Text { width: panel.qvCols[3].w; text: model.zielSeite  || "–"; font.pixelSize: 12;
                       color: model.zielSeite ? theme.accentLight : theme.borderDark; elide: Text.ElideRight }
            }
        }
    }
    } // Rectangle (ListView-Hintergrund)
    Text {
        visible: panel._querverweisModel.count === 0
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        text: panel.projektId >= 0 ? qsTr("Keine Querverweise im Projekt") : qsTr("Kein Projekt ausgewählt")
        font.pixelSize: 14; color: theme.borderDark
    }
}
