import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// Sektion "Datensicherung": Komplettarchiv exportieren / importieren.
ColumnLayout {
    id: root

    required property var theme

    Layout.fillWidth: true
    spacing: 0

    Item { implicitHeight: 28 }
    Text {
        Layout.leftMargin:   20
        text:                qsTr("Datensicherung")
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
        implicitHeight:     sicherungCol.implicitHeight + 20
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        property string _status: ""

        FolderDialog {
            id: exportDialog
            title: qsTr("Archiv-Zielordner wählen")
            onAccepted: {
                var result = db.komplettarchivExportieren(selectedFolder)
                parent._status = result.meldung || ""
            }
        }

        FolderDialog {
            id: importDialog
            title: qsTr("Archivordner wählen")
            onAccepted: {
                var result = db.komplettarchivImportieren(selectedFolder)
                parent._status = result.meldung || ""
            }
        }

        ColumnLayout {
            id:             sicherungCol
            anchors {
                left:  parent.left;  leftMargin:  12
                right: parent.right; rightMargin: 12
                top:   parent.top;   topMargin:   10
            }
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: qsTr("Alle Projekte + Wiki in einen Ordner sichern oder aus einer Sicherung wiederherstellen.")
                font.pixelSize: 11
                color:          root.theme.textMuted
                wrapMode:       Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    text:           qsTr("Exportieren …")
                    implicitHeight: 32
                    Layout.fillWidth: true
                    contentItem: Text {
                        text:  parent.text
                        color: root.theme.textPrimary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius:       4
                        border.color: root.theme.border
                    }
                    onClicked: exportDialog.open()
                }

                Button {
                    text:           qsTr("Importieren …")
                    implicitHeight: 32
                    Layout.fillWidth: true
                    contentItem: Text {
                        text:  parent.text
                        color: root.theme.textPrimary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius:       4
                        border.color: root.theme.border
                    }
                    onClicked: importDialog.open()
                }
            }

            Text {
                Layout.fillWidth: true
                text:       parent.parent._status
                visible:    text.length > 0
                font.pixelSize: 11
                color:          root.theme.accent
                wrapMode:       Text.WordWrap
            }

            Item { implicitHeight: 2 }
        }
    }
}
