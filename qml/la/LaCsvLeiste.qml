import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property var theme
    property string listenName: ""
    property int    anzahl:     0
    property bool   hatDaten:   anzahl > 0
    signal csvKlick

    Layout.fillWidth: true
    height: 32
    color: theme.surface

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
        spacing: 8
        Text { text: root.listenName; font.pixelSize: 11; color: theme.textSubtle }
        Item { Layout.fillWidth: true }
        Rectangle {
            width: csvBtnTxt.implicitWidth + 20; height: 24; radius: 4
            color: csvBtnMa.containsMouse ? theme.activeItemAlt : theme.hover
            border.color: theme.border
            visible: root.hatDaten
            Text {
                id: csvBtnTxt; anchors.centerIn: parent
                text: qsTr("CSV exportieren"); font.pixelSize: 11; color: theme.textSecondary
            }
            MouseArea {
                id: csvBtnMa; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.csvKlick()
            }
        }
    }
}
