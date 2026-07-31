import QtQuick
import QtQuick.Layouts

// Sektion "Hilfe & Kontakt": Direkter Draht zum Projektinhaber bei Problemen
// oder Fragen. Bewusst eigener Block statt Teil von EinEntstehungBlock.qml,
// damit er als klar erkennbarer Support-Einstiegspunkt auffindbar ist.
ColumnLayout {
    id: root

    required property var theme

    Layout.fillWidth: true
    spacing: 0

    Item { implicitHeight: 28 }
    Text {
        Layout.leftMargin:   20
        text:                qsTr("Hilfe & Kontakt")
        font.pixelSize:      11
        font.weight:         Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing:  1
        color:               root.theme.textMuted
    }
    Item { implicitHeight: 8 }

    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border
        implicitHeight:     hilfeCol.implicitHeight + 24

        ColumnLayout {
            id: hilfeCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            Image {
                Layout.fillWidth:         true
                Layout.maximumWidth:      220
                Layout.alignment:         Qt.AlignHCenter
                source:                   "qrc:/assets/hilfe_kontakt.png"
                fillMode:                 Image.PreserveAspectFit
                smooth:                   true; mipmap: true
            }

            Text {
                Layout.fillWidth: true
                text:           qsTr("Ein Problem gefunden oder eine Frage? Meld dich einfach direkt bei mir.")
                font.pixelSize: 12; color: root.theme.textPrimary; wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                id:               kontaktLink
                text:             "stroemling@stheelke.de"
                font.pixelSize:   13; font.weight: Font.Medium
                font.underline:   kontaktMa.containsMouse
                color:            root.theme.accent
                MouseArea {
                    id:           kontaktMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    Qt.openUrlExternally("mailto:stroemling@stheelke.de")
                }
            }

            Text {
                Layout.fillWidth: true
                text:           qsTr("Am besten hilft mir: was genau getan wurde, was erwartet war und was stattdessen passiert ist.")
                font.pixelSize: 10; color: root.theme.textMuted; wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Item { implicitHeight: 2 }
        }
    }
}
