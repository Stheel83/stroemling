import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root
    required property var theme

    property var _infos: ({})

    TextEdit { id: _clipboard; visible: false }
    function _kopieren(text) {
        _clipboard.text = text
        _clipboard.selectAll()
        _clipboard.copy()
    }

    Component.onCompleted: _infos = db.datenbankInfos()
    onVisibleChanged: if (visible) _infos = db.datenbankInfos()

    Rectangle { anchors.fill: parent; color: root.theme.surfaceDeep }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:           48
            color:            root.theme.surface
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.theme.border }
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text:           qsTr("Einstellungen")
                font.pixelSize: 15
                font.weight:    Font.Medium
                color:          root.theme.textPrimary
            }
        }

        // ── Scrollbarer Inhalt ────────────────────────────────────
        ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentWidth:      availableWidth
            clip:              true

            ColumnLayout {
                width:   parent.width
                spacing: 0

                // ── Sektion: Datenbankpfade ───────────────────────
                Item { height: 24 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Datenbankpfade")
                    font.pixelSize:      11
                    font.weight:         Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing:  1
                    color:               root.theme.textMuted
                }
                Item { height: 8 }

                Rectangle {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  12
                    Layout.rightMargin: 12
                    height:             3 * 60
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    Column {
                        anchors.fill: parent

                        Repeater {
                            model: [
                                { label: qsTr("Projektdatei"),       key: "hauptDb",   icon: "🗄" },
                                { label: qsTr("Wiki-Datenbank"),     key: "wikiDb",    icon: "📚" },
                                { label: qsTr("Backup-Verzeichnis"), key: "backupDir", icon: "💾" }
                            ]

                            delegate: Item {
                                width:  parent.width
                                height: 60

                                Rectangle {
                                    visible:        index < 2
                                    anchors.bottom: parent.bottom
                                    width:          parent.width; height: 1
                                    color:          root.theme.divider
                                }

                                RowLayout {
                                    anchors {
                                        fill:        parent
                                        leftMargin:  12
                                        rightMargin: 8
                                    }
                                    spacing: 8

                                    Text {
                                        text:             modelData.icon
                                        font.pixelSize:   14
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing:          4

                                        Text {
                                            Layout.fillWidth: true
                                            text:             modelData.label
                                            font.pixelSize:   11
                                            font.weight:      Font.Medium
                                            color:            root.theme.textMuted
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text:             root._infos[modelData.key] || qsTr("–")
                                            font.pixelSize:   11
                                            font.family:      "monospace"
                                            color:            root.theme.textPrimary
                                            elide:            Text.ElideMiddle
                                        }
                                    }

                                    // Pfad kopieren
                                    Rectangle {
                                        id:               kopBtn
                                        width:            28; height: 28; radius: 4
                                        color:            kopMouse.containsMouse ? root.theme.hover : "transparent"
                                        border.color:     root.theme.border
                                        Layout.alignment: Qt.AlignVCenter
                                        visible:          (root._infos[modelData.key] || "") !== ""

                                        Text {
                                            anchors.centerIn: parent
                                            text:             kopTimer.running ? "✓" : "⎘"
                                            font.pixelSize:   13
                                            color:            kopTimer.running ? root.theme.accent : root.theme.textMuted
                                        }
                                        Timer { id: kopTimer; interval: 1200 }
                                        MouseArea {
                                            id:           kopMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                root._kopieren(root._infos[modelData.key] || "")
                                                kopTimer.restart()
                                            }
                                        }
                                        ToolTip {
                                            visible: kopMouse.containsMouse
                                            text:    qsTr("Pfad kopieren")
                                            delay:   600
                                        }
                                    }

                                    // Im Dateimanager öffnen
                                    Rectangle {
                                        width:            28; height: 28; radius: 4
                                        color:            oeffMouse.containsMouse ? root.theme.hover : "transparent"
                                        border.color:     root.theme.border
                                        Layout.alignment: Qt.AlignVCenter
                                        visible:          (root._infos[modelData.key] || "") !== ""

                                        Text {
                                            anchors.centerIn: parent
                                            text:             "📂"
                                            font.pixelSize:   12
                                        }
                                        MouseArea {
                                            id:           oeffMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                var p = root._infos[modelData.key] || ""
                                                if (p !== "") Qt.openUrlExternally("file://" + p)
                                            }
                                        }
                                        ToolTip {
                                            visible: oeffMouse.containsMouse
                                            text:    qsTr("Im Dateimanager öffnen")
                                            delay:   600
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Sektion: Versionen ────────────────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Versionen")
                    font.pixelSize:      11
                    font.weight:         Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing:  1
                    color:               root.theme.textMuted
                }
                Item { height: 8 }

                Rectangle {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  12
                    Layout.rightMargin: 12
                    height:             3 * 44
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    Column {
                        anchors.fill: parent

                        Repeater {
                            model: [
                                { label: qsTr("Haupt-DB Schema"),   wert: root._infos["schemaVersion"]     || "–" },
                                { label: qsTr("Wiki-DB Schema"),    wert: root._infos["wikiSchemaVersion"] || "–" },
                                { label: qsTr("Backups vorhanden"), wert: root._infos["backupAnzahl"] !== undefined
                                                                          ? (root._infos["backupAnzahl"] + qsTr(" Datei(en)"))
                                                                          : "–" }
                            ]

                            delegate: Item {
                                width:  parent.width
                                height: 44

                                Rectangle {
                                    visible:        index < 2
                                    anchors.bottom: parent.bottom
                                    width:          parent.width; height: 1
                                    color:          root.theme.divider
                                }

                                RowLayout {
                                    anchors {
                                        fill:        parent
                                        leftMargin:  12
                                        rightMargin: 12
                                    }
                                    Text {
                                        text:             modelData.label
                                        font.pixelSize:   12
                                        color:            root.theme.textPrimary
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text:           modelData.wert.toString()
                                        font.pixelSize: 12
                                        font.family:    "monospace"
                                        color:          root.theme.accent
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Sektion: Datensicherung ───────────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Datensicherung")
                    font.pixelSize:      11
                    font.weight:         Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing:  1
                    color:               root.theme.textMuted
                }
                Item { height: 8 }

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
                                text:          qsTr("Exportieren …")
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
                                text:          qsTr("Importieren …")
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

                        Item { height: 2 }
                    }
                }

                Item { height: 32 }
            }
        }
    }
}
