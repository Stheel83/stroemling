import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// „Neues Projekt anlegen" (GIT-00: Ordner-pro-Projekt) inkl. Speicherort-Auswahl.
// Bei fehlgeschlagenem Anlegen wird `fehlgeschlagen` gesendet (Aufrufer zeigt Fehler-Popup).
Item {
    id: root
    required property var theme

    signal fehlgeschlagen()

    function open() { neuProjektPopup.open() }

    function _slug(name) {
        return name.trim()
                   .replace(/[\/\\:*?"<>|]/g, "_")
                   .replace(/\s+/g, "-")
                   .replace(/-+/g, "-")
                   .replace(/^-+|-+$/g, "")
                   .substring(0, 64)
               || "Neues-Projekt"
    }

    FolderDialog {
        id: projektOrtDialog
        title: qsTr("Speicherort wählen")
        onAccepted: {
            var p = selectedFolder.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            neuProjektPopup._ort = p
        }
    }

    Popup {
        id: neuProjektPopup
        modal: true
        padding: 0
        anchors.centerIn: Overlay.overlay

        property string _name: ""
        property string _ort:  ""

        onOpened: {
            if (_ort === "") _ort = db.standardProjektOrdner()
            _name = ""
            nameInputField.text = ""
            nameInputField.forceActiveFocus()
        }

        background: Rectangle {
            color:        root.theme.surface
            border.color: root.theme.border
            radius:       8
        }

        contentItem: ColumnLayout {
            width: 400
            spacing: 0

            // Header
            Item {
                Layout.fillWidth: true
                height: 48
                Text {
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    text:           qsTr("Neues Projekt anlegen")
                    font.pixelSize: 14; font.weight: Font.Medium
                    color:          root.theme.textPrimary
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: root.theme.border
                }
            }

            // Felder
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins:   24
                spacing:          20

                // Projektname
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: qsTr("Projektname"); font.pixelSize: 11; color: root.theme.textMuted }
                    TextField {
                        id:               nameInputField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("z. B. Schaltschrank Halle 3")
                        color:            root.theme.textPrimary; font.pixelSize: 13
                        background: Rectangle {
                            color:        root.theme.inputBg
                            border.color: nameInputField.activeFocus ? root.theme.accent : root.theme.border
                            radius:       4
                        }
                        onTextChanged: neuProjektPopup._name = text
                        Keys.onReturnPressed: { if (neuProjektPopup._name.trim()) anlegenBtn.clicked() }
                        Keys.onEscapePressed: neuProjektPopup.close()
                    }
                }

                // Speicherort
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: qsTr("Speicherort"); font.pixelSize: 11; color: root.theme.textMuted }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text:           neuProjektPopup._ort.replace(/^\/home\/[^/]+/, "~")
                            font.pixelSize: 11; font.family: "monospace"
                            color:          root.theme.textPrimary; elide: Text.ElideLeft
                        }
                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color:        ortBtnMa.containsMouse ? root.theme.hover : root.theme.inputBg
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "📂"; font.pixelSize: 13 }
                            MouseArea {
                                id:           ortBtnMa; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: projektOrtDialog.open()
                            }
                        }
                    }
                }

                // Pfad-Vorschau
                Rectangle {
                    Layout.fillWidth: true
                    visible:          neuProjektPopup._name.trim() !== ""
                    implicitHeight:   vorschauCol.implicitHeight + 16
                    color:            root.theme.surfaceDeep
                    radius:           4
                    border.color:     root.theme.borderLight

                    Column {
                        id: vorschauCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 2
                        Text {
                            width: parent.width
                            text: neuProjektPopup._ort.replace(/^\/home\/[^/]+/, "~")
                                  + "/" + root._slug(neuProjektPopup._name) + "/"
                            font.pixelSize: 10; font.family: "monospace"
                            color: root.theme.textMuted; wrapMode: Text.WrapAnywhere
                        }
                        Text {
                            text:           "  projekt.strl"
                            font.pixelSize: 10; font.family: "monospace"
                            color:          root.theme.accent
                        }
                    }
                }
            }

            // Footer-Buttons
            Item {
                Layout.fillWidth: true; height: 52
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width; height: 1; color: root.theme.border
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    Button {
                        text: qsTr("Abbrechen"); implicitHeight: 32; implicitWidth: 95
                        contentItem: Text {
                            text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered ? root.theme.hover : root.theme.inputBg
                            radius: 4; border.color: root.theme.border
                        }
                        onClicked: neuProjektPopup.close()
                    }
                    Button {
                        id: anlegenBtn
                        text: qsTr("Anlegen ›"); implicitHeight: 32; implicitWidth: 95
                        enabled: neuProjektPopup._name.trim() !== ""
                        contentItem: Text {
                            text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            opacity: parent.enabled ? 1.0 : 0.45
                        }
                        background: Rectangle {
                            color:        parent.hovered && parent.enabled ? root.theme.accent : root.theme.inputBg
                            radius:       4
                            border.color: parent.enabled ? root.theme.accent : root.theme.border
                        }
                        onClicked: {
                            var slug    = root._slug(neuProjektPopup._name)
                            var ordner  = neuProjektPopup._ort + "/" + slug
                            var pfad    = ordner + "/projekt.strl"
                            var name    = neuProjektPopup._name
                            neuProjektPopup.close()
                            if (db.createProjekt(pfad, name))
                                db.gitProjektInit(ordner)  // GIT-01: init + erster Commit
                            else
                                root.fehlgeschlagen()
                        }
                    }
                }
            }
        }
    }
}
