import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    required property var theme
    property int    itemId:  -1
    property string altName: ""

    title:  qsTr("Kategorie bearbeiten")
    modal:  true; parent: Overlay.overlay; anchors.centerIn: parent
    width:  340; padding: 20

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6
    }

    onOpened: editKatName.text = root.altName

    contentItem: ColumnLayout {
        spacing: 10
        Text { text: qsTr("Kategorie bearbeiten"); font.pixelSize: 15; font.weight: Font.Medium; color: root.theme.textPrimary }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }
        Text { text: qsTr("Name"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: editKatName; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 4 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }
            Button {
                text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                enabled: editKatName.text.trim().length > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    kategorieModel.bearbeiten(root.itemId, editKatName.text.trim())
                    root.close()
                }
            }
        }
    }
}
