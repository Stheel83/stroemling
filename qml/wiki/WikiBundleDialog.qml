import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Installierte Bundles (WIKI-EXP-01): Überblick über die eingespielten Bundle-Stände.
// Importieren und Exportieren laufen über die gemeinsamen Knöpfe „Wiki importieren/exportieren“ (Konzept 25 §12).
Item {
    id: root

    required property var theme

    function open() {
        _liste = db.wikiBundleAktiveListe()
        bundlePopup.open()
    }

    property var _liste: []

    Popup {
        id:           bundlePopup
        anchors.centerIn: parent
        width:        360
        height:       inhalt.implicitHeight + 40
        modal:        true
        padding:      0
        closePolicy:  Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.theme.surface; radius: 6; border.color: root.theme.border
        }

        ColumnLayout {
            id: inhalt
            anchors { fill: parent; margins: 20 }
            spacing: 10

            Text {
                text: qsTr("Installierte Bundles")
                font.pixelSize: 14; font.weight: Font.Medium
                color: root.theme.textPrimary
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.theme.divider }

            Text {
                Layout.fillWidth: true
                visible: root._liste.length === 0
                wrapMode: Text.WordWrap
                font.pixelSize: 11; color: root.theme.textMuted
                text: qsTr("Es ist noch kein Bundle installiert.")
            }
            Repeater {
                model: root._liste
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Text {
                        text: "🗂 " + modelData.kennung
                        font.pixelSize: 11; color: root.theme.textPrimary
                        Layout.fillWidth: true
                    }
                    Text {
                        text: qsTr("Version %1").arg(modelData.version)
                        font.pixelSize: 11; color: root.theme.textMuted
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 11; color: root.theme.textMuted
                text: qsTr("Bundles installierst du mit „Wiki importieren“ (↓) – die Datei wird als Bundle erkannt. "
                           + "Eigene Bundles erstellst du mit „Wiki exportieren“ (↑) und der Wahl „Bundle für andere“.")
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 70; implicitHeight: 30; radius: 3
                    color: schliessenHover.hovered ? root.theme.hover : "transparent"
                    border.color: root.theme.border
                    Text { anchors.centerIn: parent; text: qsTr("Schließen"); font.pixelSize: 11; color: root.theme.textMuted }
                    HoverHandler { id: schliessenHover }
                    TapHandler { onTapped: bundlePopup.close() }
                }
            }
        }
    }
}
