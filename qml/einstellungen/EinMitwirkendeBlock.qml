import QtQuick
import QtQuick.Layouts

// Sektion "Mitwirkende": kurzer Dank + Link zur Danke-Seite auf der Website
// (Namen werden dort gepflegt, nicht mehr hartkodiert im QML — kein Rebuild
// mehr nötig, wenn jemand Neues hinzukommt).
ColumnLayout {
    id: root

    required property var theme
    readonly property string dankeUrl: "https://stheelke.de/danke"

    Layout.fillWidth: true
    spacing: 0

    Item { implicitHeight: 28 }
    Text {
        Layout.leftMargin:   20
        text:                qsTr("Mitwirkende")
        font.pixelSize:      11
        font.weight:         Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing:  1
        color:               root.theme.textMuted
    }
    Item { implicitHeight: 8 }

    Rectangle {
        id:                 mitwCard
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        implicitHeight:     mitwCol.implicitHeight + 24
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        ColumnLayout {
            id: mitwCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            Text {
                Layout.fillWidth: true
                text:     qsTr("Herzlichen Dank an alle, die durch Fehlermeldungen, Tests, Designfeedback und andere Beiträge zu diesem Projekt beitragen.")
                font.pixelSize: 12
                color:    root.theme.textPrimary
                wrapMode: Text.WordWrap
            }

            RowLayout {
                spacing: 6
                Text {
                    text:           qsTr("Wer dabei mitgeholfen hat, steht auf der")
                    font.pixelSize: 12; color: root.theme.textPrimary
                }
                Text {
                    id:             dankeLink
                    text:           qsTr("Danke-Seite")
                    font.pixelSize: 12; font.underline: dankeMa.containsMouse
                    color:          root.theme.accent
                    MouseArea {
                        id:           dankeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    Qt.openUrlExternally(root.dankeUrl)
                    }
                }
                Text {
                    text:           qsTr("meiner Website.")
                    font.pixelSize: 12; color: root.theme.textPrimary
                }
            }

            Text {
                Layout.fillWidth: true
                text:           root.dankeUrl
                font.pixelSize: 11; color: root.theme.textMuted
            }
        }
    }
}
