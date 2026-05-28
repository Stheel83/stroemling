import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    required property var theme

    title:  qsTr("Neues Projekt anlegen")
    width:  320
    anchors.centerIn: parent
    standardButtons: Dialog.Ok | Dialog.Cancel

    ColumnLayout {
        width: parent.width
        spacing: 10

        Label { text: qsTr("Projektname *"); color: root.theme.textBright }
        TextField {
            id:              nameField
            placeholderText: qsTr("z.B. Hausinstallation EFH")
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.sidebar; radius: 4; border.color: root.theme.border }
            color: root.theme.textPrimary
        }

        Label { text: qsTr("Projektnummer"); color: root.theme.textBright }
        TextField {
            id:              nummerField
            placeholderText: qsTr("z.B. 2024-001")
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.sidebar; radius: 4; border.color: root.theme.border }
            color: root.theme.textPrimary
        }
    }

    onAccepted: {
        if (nameField.text.trim() !== "") {
            projektModel.anlegen(nameField.text.trim(), nummerField.text.trim())
            nameField.text   = ""
            nummerField.text = ""
        }
    }
}
