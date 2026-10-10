import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Fehler-Popup „Projekt konnte nicht geöffnet werden" (mit Backup-Ordner-Button).
Item {
    id: root
    required property var theme

    function open() { fehlerPopup.open() }

    Popup {
        id: fehlerPopup
        property string backupOrdner: ""
        onAboutToShow: backupOrdner = db.letzterBackupOrdner()
        modal: true; anchors.centerIn: Overlay.overlay; padding: 20
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Column {
            spacing: 12
            Text { text: qsTr("Projekt konnte nicht geöffnet werden."); color: root.theme.textPrimary; font.pixelSize: 13 }
            Text { text: qsTr("Datei beschädigt, falsches Format oder Migration fehlgeschlagen."); color: root.theme.textMuted; font.pixelSize: 11 }
            Row {
                spacing: 8
                Button {
                    visible: fehlerPopup.backupOrdner !== ""
                    text: qsTr("Backup-Ordner öffnen")
                    onClicked: Qt.openUrlExternally("file://" + fehlerPopup.backupOrdner)
                    background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg; radius: 4; border.color: root.theme.accent }
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; horizontalAlignment: Text.AlignHCenter; leftPadding: 8; rightPadding: 8 }
                }
                Button {
                    text: qsTr("OK"); onClicked: fehlerPopup.close()
                    background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg; radius: 4; border.color: root.theme.accent }
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; horizontalAlignment: Text.AlignHCenter }
                }
            }
        }
    }
}
