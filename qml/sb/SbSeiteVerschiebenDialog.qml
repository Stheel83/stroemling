import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog „Seite verschieben" — ausgelagert aus SeitenBaum.qml (REFACTOR-QML-01).
Dialog {
    id: root
    required property var theme

    title: qsTr("Seite verschieben")
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 380
    padding: 20

    property int seiteId: -1

    ListModel { id: anlageModelVers }
    ListModel { id: ortModelVers }

    onOpened: {
        anlageModelVers.clear()
        var anlagen = seitenModel.anlagenListe()
        for (var i = 0; i < anlagen.length; i++)
            anlageModelVers.append(anlagen[i])
        cmbVersAnlage.currentIndex = 0
    }

    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

    contentItem: ColumnLayout {
        spacing: 10
        Text { text: qsTr("Anlage"); color: root.theme.textMuted; font.pixelSize: 12 }
        ComboBox {
            id: cmbVersAnlage
            Layout.fillWidth: true
            model: anlageModelVers
            textRole: "label"
            onCurrentIndexChanged: {
                if (currentIndex >= 0 && anlageModelVers.count > 0) {
                    var anlId = anlageModelVers.get(currentIndex).itemId
                    ortModelVers.clear()
                    var orte = seitenModel.orteListe(anlId)
                    for (var i = 0; i < orte.length; i++)
                        ortModelVers.append(orte[i])
                    cmbVersOrt.currentIndex = 0
                }
            }
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { leftPadding: 8; text: cmbVersAnlage.displayText; color: root.theme.textPrimary;
                                font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
        }
        Text { text: qsTr("Ort"); color: root.theme.textMuted; font.pixelSize: 12 }
        ComboBox {
            id: cmbVersOrt
            Layout.fillWidth: true
            model: ortModelVers
            textRole: "label"
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { leftPadding: 8; text: cmbVersOrt.displayText; color: root.theme.textPrimary;
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
                enabled: cmbVersOrt.currentIndex >= 0 && ortModelVers.count > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    var ortId = ortModelVers.get(cmbVersOrt.currentIndex).itemId
                    seitenModel.seiteVerschieben(root.seiteId, ortId)
                    root.close()
                }
            }
        }
    }
}
