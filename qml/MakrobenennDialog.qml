import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ============================================================
// MakrobenennDialog – Name, Beschreibung und Kategorie für
// einen neuen Makrokasten eingeben.
// Wird direkt nach dem Zeichnen des Makrokastens geöffnet.
// ============================================================

Dialog {
    id: root

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 360
    padding: 20

    required property var theme
    property bool   _debugLokal: false

    // Ausgabe – gelesen von Canvas nach accepted
    property string name:         ""
    property string beschreibung: ""
    property string kategorie:    ""

    title: qsTr("Makro benennen")

    onOpened: {
        tfName.text         = ""
        tfBeschreibung.text = ""
        tfKategorie.text    = ""
        tfName.forceActiveFocus()
    }
    onClosed: root._debugLokal = false

    Shortcut {
        sequence: "Ctrl+Shift+D"
        onActivated: root._debugLokal = !root._debugLokal
    }

    background: Rectangle {
        color: root.theme.sidebar
        border.color: root.theme.border
        border.width: 1; radius: 6
    }

    contentItem: ColumnLayout {
        spacing: 12

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        Text {
            text: qsTr("Name *")
            color: root.theme.textMuted
            font.pixelSize: 11
        }
        TextField {
            id: tfName
            Layout.fillWidth: true
            placeholderText: qsTr("z. B. Motorantrieb")
            color: root.theme.textPrimary
            font.pixelSize: 13
            background: Rectangle {
                color: root.theme.inputBg
                radius: 4
                border.color: root.theme.border
            }
            Keys.onReturnPressed: tfBeschreibung.forceActiveFocus()
        }

        Text {
            text: qsTr("Beschreibung")
            color: root.theme.textMuted
            font.pixelSize: 11
        }
        TextField {
            id: tfBeschreibung
            Layout.fillWidth: true
            placeholderText: qsTr("optional")
            color: root.theme.textPrimary
            font.pixelSize: 13
            background: Rectangle {
                color: root.theme.inputBg
                radius: 4
                border.color: root.theme.border
            }
            Keys.onReturnPressed: tfKategorie.forceActiveFocus()
        }

        Text {
            text: qsTr("Kategorie")
            color: root.theme.textMuted
            font.pixelSize: 11
        }
        TextField {
            id: tfKategorie
            Layout.fillWidth: true
            placeholderText: qsTr("z. B. Antriebe")
            color: root.theme.textPrimary
            font.pixelSize: 13
            background: Rectangle {
                color: root.theme.inputBg
                radius: 4
                border.color: root.theme.border
            }
            Keys.onReturnPressed: btnSpeichern.clicked()
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: qsTr("Abbrechen")
                Layout.fillWidth: true
                implicitHeight: 32
                contentItem: Text {
                    text: parent.text
                    color: root.theme.textSecondary
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4
                    border.color: root.theme.border
                }
                onClicked: root.reject()
            }

            Button {
                id: btnSpeichern
                text: qsTr("Makrokasten anlegen")
                Layout.fillWidth: true
                implicitHeight: 32
                enabled: tfName.text.trim().length > 0
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.enabled
                           ? (parent.hovered ? root.theme.accent : root.theme.inputBg)
                           : root.theme.inputBg
                    radius: 4
                    border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    root.name         = tfName.text.trim()
                    root.beschreibung = tfBeschreibung.text.trim()
                    root.kategorie    = tfKategorie.text.trim()
                    root.accept()
                }
            }
        }
    }
}
