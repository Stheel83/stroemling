import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Backup wiederherstellen (BACKUP-OEFFNEN-01): Liste der Projekt-Backups; Auswahl legt ein neues
// Projekt an und öffnet es. Bei Öffnungsfehler wird `fehlgeschlagen` gesendet.
Item {
    id: root
    required property var theme

    signal fehlgeschlagen()

    function open() {
        backupPopup.backups = db.projektBackups()
        backupPopup.open()
    }

    Popup {
        id: backupPopup
        property var backups: []
        modal: true; anchors.centerIn: Overlay.overlay; padding: 20
        width: 460
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Backup wiederherstellen"); color: root.theme.textPrimary; font.pixelSize: 14; font.bold: true }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: qsTr("Das gewählte Backup wird als neues Projekt neben diesem angelegt und geöffnet. Das aktuelle Projekt bleibt unverändert.")
                color: root.theme.textMuted; font.pixelSize: 11
            }
            Text {
                visible: backupPopup.backups.length === 0
                text: qsTr("Für dieses Projekt gibt es noch keine Backups.")
                color: root.theme.textMuted; font.pixelSize: 12
            }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 240)
                clip: true; spacing: 4
                model: backupPopup.backups
                delegate: Rectangle {
                    width: ListView.view.width; height: 36; radius: 4
                    color: bkMa.containsMouse ? root.theme.hover : root.theme.inputBg
                    border.color: root.theme.border
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        Text { text: modelData.zeit; color: root.theme.textPrimary; font.pixelSize: 12; Layout.fillWidth: true }
                        Text { text: qsTr("Schema v") + modelData.version; color: root.theme.textMuted; font.pixelSize: 11 }
                        Text { text: modelData.groesse; color: root.theme.textMuted; font.pixelSize: 11 }
                    }
                    MouseArea {
                        id: bkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var neu = db.backupWiederherstellen(modelData.pfad)
                            backupPopup.close()
                            if (neu === "") {
                                meldungManager.zeigen(qsTr("Backup konnte nicht wiederhergestellt werden"), false)
                            } else if (db.openProjekt(neu)) {
                                db.gitProjektInit(neu.substring(0, neu.lastIndexOf("/")))
                                meldungManager.zeigen(qsTr("Backup als neues Projekt geöffnet"), true)
                            } else {
                                root.fehlgeschlagen()
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: qsTr("Backup-Ordner öffnen")
                    onClicked: Qt.openUrlExternally("file://" + db.projektOrdner + "/backups")
                    background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4; border.color: root.theme.border }
                    contentItem: Text { text: parent.text; color: root.theme.textMuted; horizontalAlignment: Text.AlignHCenter; leftPadding: 8; rightPadding: 8 }
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); onClicked: backupPopup.close()
                    background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg; radius: 4; border.color: root.theme.accent }
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; horizontalAlignment: Text.AlignHCenter }
                }
            }
        }
    }
}
