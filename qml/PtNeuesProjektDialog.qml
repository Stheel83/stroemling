import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: root
    required property var theme

    title:  qsTr("Neues Projekt anlegen")
    width:  380
    modal: true; parent: Overlay.overlay; anchors.centerIn: parent
    standardButtons: Dialog.NoButton

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 8
    }

    FileDialog {
        id:            saveDialog
        title:         qsTr("Projektdatei speichern unter")
        fileMode:      FileDialog.SaveFile
        nameFilters:   ["Strömling Projekte (*.strl)"]
        defaultSuffix: "strl"
        onAccepted: {
            var pfad = selectedFile.toString().replace(/^file:\/\//, "")
            var name = nameField.text.trim()
            db.createProjekt(pfad, name)
            nameField.text   = ""
            nummerField.text = ""
            root.close()
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            text: qsTr("Neues Projekt anlegen")
            font.pixelSize: 14; font.weight: Font.Medium; color: root.theme.textPrimary
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        Text { text: qsTr("Projektname"); font.pixelSize: 12; color: root.theme.textPrimary }
        Rectangle {
            Layout.fillWidth: true; height: 32; radius: 4
            color: root.theme.inputBg
            border.color: nameField.activeFocus ? root.theme.accent : root.theme.border

            TextInput {
                id: nameField
                anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                font.pixelSize: 12; color: root.theme.textPrimary
                selectionColor: root.theme.accent; clip: true

                Text {
                    anchors.fill: parent
                    text: qsTr("z.B. Hausinstallation EFH"); font: parent.font
                    color: root.theme.textMuted; visible: parent.text === ""
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Text { text: qsTr("Projektnummer (optional)"); font.pixelSize: 12; color: root.theme.textPrimary }
        Rectangle {
            Layout.fillWidth: true; height: 32; radius: 4
            color: root.theme.inputBg
            border.color: nummerField.activeFocus ? root.theme.accent : root.theme.border

            TextInput {
                id: nummerField
                anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                font.pixelSize: 12; color: root.theme.textPrimary
                selectionColor: root.theme.accent; clip: true

                Text {
                    anchors.fill: parent
                    text: qsTr("z.B. 2024-001"); font: parent.font
                    color: root.theme.textMuted; visible: parent.text === ""
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: 100; implicitHeight: 30; radius: 4
                color: abbrechMaus.containsMouse ? root.theme.hover : root.theme.inputBg
                border.color: root.theme.border

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Abbrechen"); font.pixelSize: 11
                    color: root.theme.textPrimary
                }
                MouseArea {
                    id: abbrechMaus; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            Rectangle {
                property bool bereit: nameField.text.trim().length > 0
                implicitWidth: 140; implicitHeight: 30; radius: 4
                color: bereit ? (erstellenMaus.containsMouse ? root.theme.accent : root.theme.inputBg)
                               : root.theme.surfaceDeep
                border.color: bereit ? root.theme.accent : root.theme.border

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Speicherort wahlen...")
                    font.pixelSize: 11; font.weight: Font.Medium
                    color: parent.bereit
                           ? (erstellenMaus.containsMouse ? "white" : root.theme.accent)
                           : root.theme.textMuted
                }
                MouseArea {
                    id: erstellenMaus; anchors.fill: parent
                    enabled: parent.bereit; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: saveDialog.open()
                }
            }
        }
    }
}
