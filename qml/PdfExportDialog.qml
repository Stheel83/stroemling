import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "components"

Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  400
    padding: 20

    required property var theme
    required property int projektId
    required property int seiteId
    property bool         debug: false

    title: qsTr("PDF-Export")

    background: Rectangle {
        color:        root.theme.sidebar
        border.color: root.theme.border
        border.width: 1; radius: 6
    }

    FileDialog {
        id: speicherDialog
        title:         qsTr("PDF speichern unter")
        fileMode:      FileDialog.SaveFile
        nameFilters:   [qsTr("PDF-Datei (*.pdf)"), qsTr("Alle Dateien (*)")]
        defaultSuffix: "pdf"
        onAccepted: tfPfad.text = selectedFile
    }

    contentItem: ColumnLayout {
        spacing: 12

        // Seiten-Auswahl
        Text {
            text:           qsTr("Seiten")
            color:          root.theme.textMuted
            font.pixelSize: 11
        }

        ColumnLayout {
            spacing: 6

            RadioButton {
                id: rbAlle
                checked: true
                contentItem: Text {
                    text:           qsTr("Alle Seiten")
                    color:          root.theme.textPrimary
                    font.pixelSize: 12
                    leftPadding:    rbAlle.indicator.width + rbAlle.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RadioButton {
                id: rbAktuell
                enabled: root.seiteId > 0
                contentItem: Text {
                    text:           qsTr("Aktuelle Seite")
                    color:          rbAktuell.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    leftPadding:    rbAktuell.indicator.width + rbAktuell.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RadioButton {
                id: rbVoll
                enabled: root.seiteId > 0
                onCheckedChanged: if (checked) cbNormblatt.checked = false
                contentItem: Text {
                    text:           qsTr("Ganzes Canvas (aktuelle Seite)")
                    color:          rbVoll.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    leftPadding:    rbVoll.indicator.width + rbVoll.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Normblatt-Option (im Ganzes-Canvas-Modus nicht sinnvoll)
        CheckBox {
            id: cbNormblatt
            checked: true
            enabled: !rbVoll.checked
            contentItem: Text {
                text:           qsTr("Normblatt einschließen")
                color:          cbNormblatt.enabled ? root.theme.textPrimary : root.theme.textMuted
                font.pixelSize: 12
                leftPadding:    cbNormblatt.indicator.width + cbNormblatt.spacing
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // Dateipfad
        Text {
            text:           qsTr("Speichern als")
            color:          root.theme.textMuted
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: tfPfad
                Layout.fillWidth: true
                placeholderText:  qsTr("Dateipfad …")
                color:            root.theme.textPrimary
                font.pixelSize:   12
                background: Rectangle {
                    color:        root.theme.inputBg
                    radius:       4
                    border.color: root.theme.border
                }
            }

            Button {
                text:          "📁"
                implicitWidth: 32
                implicitHeight: 32
                contentItem: Text {
                    text:  parent.text
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius:       4
                    border.color: root.theme.border
                }
                onClicked: speicherDialog.open()
            }
        }

        // Status-/Fehlermeldung
        Text {
            id: statusText
            Layout.fillWidth: true
            text:           ""
            color:          root.theme.accent
            font.pixelSize: 11
            wrapMode:       Text.WordWrap
            visible:        text.length > 0
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text:           qsTr("Abbrechen")
                Layout.fillWidth: true
                implicitHeight: 32
                contentItem: Text {
                    text:  parent.text
                    color: root.theme.textSecondary
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius:       4
                    border.color: root.theme.border
                }
                onClicked: root.reject()
            }

            Button {
                id:             btnExport
                text:           qsTr("Exportieren")
                Layout.fillWidth: true
                implicitHeight: 32
                enabled:        tfPfad.text.trim().length > 0
                contentItem: Text {
                    text:  parent.text
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.enabled
                           ? (parent.hovered ? root.theme.accent : root.theme.inputBg)
                           : root.theme.inputBg
                    radius:       4
                    border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    statusText.text = ""
                    var pfad = tfPfad.text.trim()
                    var nb   = cbNormblatt.checked
                    var ok = false
                    if (rbVoll.checked)
                        ok = db.canvasSeiteExportieren(root.seiteId, pfad, false, true)
                    else if (rbAlle.checked)
                        ok = db.canvasPdfExportieren(root.projektId, pfad, nb)
                    else
                        ok = db.canvasSeiteExportieren(root.seiteId, pfad, nb, false)

                    if (ok) {
                        root.accept()
                    } else {
                        statusText.text = qsTr("Export fehlgeschlagen. Pfad prüfen.")
                    }
                }
            }
        }
    }

    DebugLabel { parent: root.contentItem; panelName: qsTr("PDF-Export-Dialog"); visible: root.debug && root.visible }
}
