import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    required property var theme

    property int    projektId:   -1
    property string projektName: ""

    signal projektGeloescht(int id)

    modal: true; parent: Overlay.overlay; anchors.centerIn: parent
    width: 340; padding: 20

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 8
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: qsTr("Projekt löschen?")
            font.pixelSize: 14; font.weight: Font.Medium; color: root.theme.textPrimary
        }
        Text {
            Layout.fillWidth: true
            text: root.projektName
            font.pixelSize: 13; color: root.theme.accent; elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Alle Seiten, Elemente und Leitungen dieses Projekts werden unwiederbringlich gelöscht.")
            font.pixelSize: 11; color: "#ff8888"; wrapMode: Text.WordWrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); implicitHeight: 30; implicitWidth: 100
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg;
                                        radius: 4; border.color: root.theme.border }
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 11;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: root.close()
            }
            Button {
                text: qsTr("Löschen"); implicitHeight: 30; implicitWidth: 100
                background: Rectangle { color: parent.hovered ? "#cc2222" : root.theme.inputBg;
                                        radius: 4; border.color: "#ff4444" }
                contentItem: Text { text: parent.text; color: parent.hovered ? "white" : "#ff4444";
                                    font.pixelSize: 11;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: {
                    var pid = root.projektId
                    projektModel.loeschen(pid)
                    root.projektId   = -1
                    root.projektName = ""
                    root.close()
                    root.projektGeloescht(pid)
                }
            }
        }
    }
}
