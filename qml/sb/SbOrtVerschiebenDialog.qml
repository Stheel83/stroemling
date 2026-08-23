import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog „Ort verschieben" — ausgelagert aus SeitenBaum.qml (REFACTOR-QML-01).
Dialog {
    id: root
    required property var theme

    title: qsTr("Ort verschieben")
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 380
    padding: 20

    property int ortId: -1

    ListModel { id: anlageModelOrtVers }

    onOpened: {
        anlageModelOrtVers.clear()
        var anlagen = seitenModel.anlagenListe()
        for (var i = 0; i < anlagen.length; i++)
            anlageModelOrtVers.append(anlagen[i])
        cmbVersOrtAnlage.currentIndex = 0
    }

    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

    contentItem: ColumnLayout {
        spacing: 10
        Text { text: qsTr("Anlage"); color: root.theme.textMuted; font.pixelSize: 12 }
        ComboBox {
            id: cmbVersOrtAnlage
            Layout.fillWidth: true
            model: anlageModelOrtVers
            textRole: "label"
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { leftPadding: 8; text: cmbVersOrtAnlage.displayText; color: root.theme.textPrimary;
                                font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
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
                text: qsTr("Verschieben"); implicitWidth: 100; implicitHeight: 34
                enabled: cmbVersOrtAnlage.currentIndex >= 0 && anlageModelOrtVers.count > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    var anlId = anlageModelOrtVers.get(cmbVersOrtAnlage.currentIndex).itemId
                    seitenModel.ortVerschieben(root.ortId, anlId)
                    root.close()
                }
            }
        }
    }
}
