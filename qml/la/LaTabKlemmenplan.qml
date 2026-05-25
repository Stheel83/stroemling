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
        title: qsTr("Klemmenplan als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.klemmenplanCsvSpeichern(panel.projektId, selectedFile)
    }

    LaCsvLeiste {
        theme: theme
        listenName: qsTr("Klemmenplan")
        anzahl: panel.klemmenplanZaehler
        onCsvKlick: csvDialog.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    Rectangle {
        Layout.fillWidth: true; height: 30; color: theme.tableHeader
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Repeater {
                model: panel.kpCols
                delegate: Text { width: modelData.w; text: modelData.header;
                    font.pixelSize: 11; font.weight: Font.Medium; color: theme.textSubtle }
            }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ListView {
        id: kpView
        Layout.fillWidth: true; Layout.fillHeight: true
        model: panel._klemmenplanModel; clip: true
        ScrollBar.vertical: ScrollBar {}
        Rectangle { anchors.fill: parent; color: theme.surface; z: -1 }

        delegate: Rectangle {
            width: kpView.width
            height: model.typ === "leiste" ? 26 : 28
            color: model.typ === "leiste" ? theme.tableHeader
                   : (index % 2 === 0 ? theme.tableEven : theme.tableOdd)

            // Leisten-Gruppen-Header
            Row {
                visible: model.typ === "leiste"
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 8
                Text { text: model.typ === "leiste" ? model.bmk : ""; font.pixelSize: 11;
                       font.weight: Font.Bold; color: theme.accent }
                Text { text: model.typ === "leiste" ? "– " + model.bezeichnung : "";
                       font.pixelSize: 11; color: theme.textSubtle }
            }

            // Klemmen-Zeile
            Row {
                visible: model.typ === "klemme"
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 0
                Text { width: panel.kpCols[0].w; text: model.typ === "klemme" ? (model.nummer     || "–") : ""; font.pixelSize: 12; color: theme.textSecondary;  elide: Text.ElideRight }
                Text { width: panel.kpCols[1].w; text: model.typ === "klemme" ? (model.bauteilBez || "–") : ""; font.pixelSize: 12; color: theme.textSecondary;  elide: Text.ElideRight }
                Text { width: panel.kpCols[2].w; text: model.typ === "klemme" ? (model.anschlussTyp || "–") : ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                Text { width: panel.kpCols[3].w; text: model.typ === "klemme" ? (model.querschnitt || "–") : ""; font.pixelSize: 12; color: theme.textSecondary;  elide: Text.ElideRight }
                Row {
                    width: panel.kpCols[4].w; spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 10; height: 10; radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        visible: model.typ === "klemme" && model.farbeHex !== ""
                        color: model.typ === "klemme" ? (model.farbeHex || "transparent") : "transparent"
                        border.color: theme.border; border.width: 1
                    }
                    Text { width: panel.kpCols[4].w - 18;
                           text: model.typ === "klemme" ? (model.farbeBez || "–") : "";
                           font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                }
                Text { width: panel.kpCols[5].w; text: model.typ === "klemme" ? (model.potenzial || "–") : "";
                       font.pixelSize: 12; color: model.typ === "klemme" && model.potenzial ? theme.accent : theme.borderDark; elide: Text.ElideRight }
                Text { width: panel.kpCols[6].w; text: model.typ === "klemme" ? (model.ortKz || "–") : "";
                       font.pixelSize: 12; color: theme.borderLight; elide: Text.ElideRight }
            }
        }
    }
    Column {
        visible: panel.klemmenplanZaehler === 0
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: panel.projektId >= 0 ? qsTr("Keine Klemmenleisten im Projekt") : qsTr("Kein Projekt ausgewählt")
            font.pixelSize: 14; color: theme.borderDark
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: panel.projektId >= 0
            text: qsTr("Klemmenleisten unter Bauteile → Klemmenreihen anlegen.")
            font.pixelSize: 11; font.italic: true; color: theme.textMuted
        }
    }
}
