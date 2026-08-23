import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog „Ort bearbeiten" — ausgelagert aus SeitenBaum.qml (REFACTOR-QML-01).
Dialog {
    id: root
    required property var theme

    title: qsTr("Ort bearbeiten")
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 360
    padding: 20

    property int    itemId:             -1
    property string altKuerzel:         ""
    property string altBezeichnung:     ""
    property string altUebergeordnet:   ""

    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

    onOpened: {
        editOrtKuerzel.text = root.altKuerzel
        editOrtBez.text     = root.altBezeichnung
        editOrtUO.text      = root.altUebergeordnet
    }

    contentItem: ColumnLayout {
        spacing: 10
        Text { text: qsTr("Kürzel"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: editOrtKuerzel; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: editOrtBez; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Übergeordneter Ort ++ (optional)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: editOrtUO; Layout.fillWidth: true
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
                enabled: editOrtKuerzel.text.trim().length > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    seitenModel.ortBearbeiten(root.itemId,
                        editOrtKuerzel.text.trim(), editOrtBez.text.trim(), editOrtUO.text.trim())
                    root.close()
                }
            }
        }
    }
}
