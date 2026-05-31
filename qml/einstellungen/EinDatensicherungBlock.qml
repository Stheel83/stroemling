import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// Sektion "Datensicherung": Auto-Backup-Status + manueller Vollexport/Import.
ColumnLayout {
    id: root

    required property var theme
    property var infos: ({})

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

    // ── Auto-Backup-Status ────────────────────────────────────────
    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        implicitHeight:     autoCol.implicitHeight + 20
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        ColumnLayout {
            id: autoCol
            anchors {
                left:  parent.left;  leftMargin:  12
                right: parent.right; rightMargin: 12
                top:   parent.top;   topMargin:   12
            }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text:           "💾"
                    font.pixelSize: 14
                }
                Text {
                    Layout.fillWidth: true
                    text:             qsTr("Automatisches Backup")
                    font.pixelSize:   12
                    font.weight:      Font.Medium
                    color:            root.theme.textPrimary
                }
                Text {
                    text: {
                        var d = root.infos["letztesSicherung"] || ""
                        return d ? qsTr("Zuletzt: ") + d : qsTr("Noch kein Backup")
                    }
                    font.pixelSize: 11
                    color:          root.theme.textMuted
                }
            }

            Text {
                Layout.fillWidth: true
                text: {
                    var n = root.infos["backupAnzahl"] || 0
                    var dir = root.infos["backupDir"] || ""
                    if (!dir) return qsTr("Beim App-Start werden makros.db und wiki.db täglich gesichert (max. 7 Sicherungen).")
                    return qsTr("Makros + Wiki täglich gesichert · %1 Sicherung(en) in backups/").arg(n)
                }
                font.pixelSize: 11
                color:          root.theme.textMuted
                wrapMode:       Text.WordWrap
            }
        }
    }

    Item { implicitHeight: 12 }

    // ── Manueller Vollexport / Import ─────────────────────────────
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
                if (result.neustartNoetig) neustartHinweis.visible = true
            }
        }

        // Import-Bestätigungsdialog
        Dialog {
            id:    importBestaetigung
            title: qsTr("Sicherung wiederherstellen")
            modal: true
            width: 380
            anchors.centerIn: Overlay.overlay

            contentItem: Text {
                text: qsTr("Die Sicherung überschreibt Makros und Wiki.\n\nProjektdateien werden nach \"importierte_projekte/\" kopiert und erscheinen dann in der Projektliste.\n\nFortfahren?")
                font.pixelSize: 12
                color:          root.theme.textPrimary
                wrapMode:       Text.WordWrap
            }

            footer: RowLayout {
                spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen")
                    implicitHeight: 32
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
                    onClicked: importBestaetigung.close()
                }
                Button {
                    text: qsTr("Importieren")
                    implicitHeight: 32
                    contentItem: Text {
                        text:  parent.text
                        color: root.theme.textPrimary
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius:       4
                        border.color: root.theme.accent
                    }
                    onClicked: {
                        importBestaetigung.close()
                        importDialog.open()
                    }
                }
                Item { implicitWidth: 4 }
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
                text: qsTr("Vollständige Sicherung: alle Projekte, Makros, Wiki und Anhänge in einen Ordner exportieren oder daraus wiederherstellen.")
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
                    ToolTip.visible: hovered
                    ToolTip.text:    qsTr("Alle Projekte, Makros und Wiki in einen Ordner sichern")
                    ToolTip.delay:   500
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
                    onClicked: importBestaetigung.open()
                    ToolTip.visible: hovered
                    ToolTip.text:    qsTr("Sicherung wiederherstellen – Archivordner wählen")
                    ToolTip.delay:   500
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

            // Neustart-Hinweis nach Import
            Rectangle {
                id:               neustartHinweis
                Layout.fillWidth: true
                implicitHeight:   neustartText.implicitHeight + 16
                visible:          false
                color:            Qt.rgba(1, 0.8, 0.1, 0.15)
                radius:           4
                border.color:     Qt.rgba(1, 0.8, 0.1, 0.5)

                Text {
                    id:            neustartText
                    anchors {
                        left:  parent.left;  leftMargin:  10
                        right: parent.right; rightMargin: 10
                        top:   parent.top;   topMargin:   8
                    }
                    text:           qsTr("Makros und Wiki werden beim nächsten App-Start wiederhergestellt.")
                    font.pixelSize: 11
                    color:          root.theme.textPrimary
                    wrapMode:       Text.WordWrap
                }
            }

            Item { implicitHeight: 2 }
        }
    }
}
