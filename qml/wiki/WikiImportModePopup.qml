import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Import-Modus-Popup — ausgelagert aus WikiAnsicht.qml (REFACTOR-QML-04).
Popup {
    id: root
    required property var panel   // WikiAnsicht-Referenz (_importPfad, _kategorienLaden(), _artIdx, _aktArtikel, _bilder)
    required property var theme

    anchors.centerIn: parent
    width:        340
    height:       160
    modal:        true
    padding:      0
    closePolicy:  Popup.CloseOnEscape

    background: Rectangle {
        color:        theme.surface
        radius:       6
        border.color: theme.border
        border.width: 1
    }

    ColumnLayout {
        anchors { fill: parent; margins: 20 }
        spacing: 16

        Text {
            Layout.fillWidth: true
            text:           qsTr("Wie soll importiert werden?")
            font.pixelSize: 14
            font.weight:    Font.Medium
            color:          theme.textPrimary
            wrapMode:       Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true; height: 32; radius: 3
                color: mergeHover.hovered ? theme.accent : theme.border
                Text {
                    anchors.centerIn: parent
                    text:           qsTr("Zusammenführen")
                    font.pixelSize: 11
                    color:          theme.textPrimary
                }
                HoverHandler { id: mergeHover }
                TapHandler {
                    onTapped: {
                        root.close()
                        const ok = db.wikiImportJson(panel._importPfad, true)
                        panel._kategorienLaden()
                        meldungManager.zeigen(ok ? qsTr("Import erfolgreich") : qsTr("Import fehlgeschlagen"), ok)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; height: 32; radius: 3
                color: replaceHover.hovered ? "#c0392b" : theme.border
                Text {
                    anchors.centerIn: parent
                    text:           qsTr("Ersetzen")
                    font.pixelSize: 11
                    color:          theme.textPrimary
                }
                HoverHandler { id: replaceHover }
                TapHandler {
                    onTapped: {
                        root.close()
                        const ok = db.wikiImportJson(panel._importPfad, false)
                        panel._kategorienLaden()
                        panel._artIdx     = -1
                        panel._aktArtikel = ({})
                        panel._bilder     = []
                        meldungManager.zeigen(ok ? qsTr("Import erfolgreich") : qsTr("Import fehlgeschlagen"), ok)
                    }
                }
            }

            Rectangle {
                width: 70; height: 32; radius: 3
                color: abbrImportHover.hovered ? theme.hover : "transparent"
                border.color: theme.border
                Text {
                    anchors.centerIn: parent
                    text:           qsTr("Abbrechen")
                    font.pixelSize: 11
                    color:          theme.textMuted
                }
                HoverHandler { id: abbrImportHover }
                TapHandler { onTapped: root.close() }
            }
        }
    }
}
