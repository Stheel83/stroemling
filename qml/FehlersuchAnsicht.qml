import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property var theme

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 12

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "🔍"
            font.pixelSize: 48
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Fehlersuchmodus")
            font.pixelSize: 20; font.weight: Font.Medium
            color: root.theme.textPrimary
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("In Entwicklung – L9")
            font.pixelSize: 13
            color: root.theme.textMuted
        }
    }
}
