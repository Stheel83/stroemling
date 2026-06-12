import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sektion "Datenbankpfade": zeigt Haupt-DB, Wiki-DB und Backup-Verzeichnis.
ColumnLayout {
    id: root

    required property var theme
    property  var infos: ({})

    Layout.fillWidth: true
    spacing: 0

    Item { implicitHeight: 24 }
    Text {
        Layout.leftMargin:   20
        text:                qsTr("Datenbankpfade")
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
        height:             4 * 60
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        Column {
            anchors.fill: parent

            Repeater {
                model: [
                    { label: qsTr("Zentrale Datenbank"), key: "launcherDb", icon: "🗄" },
                    { label: qsTr("Wiki-Datenbank"),     key: "wikiDb",     icon: "📚" },
                    { label: qsTr("Makro-Bibliothek"),   key: "makrosDb",   icon: "⚙" },
                    { label: qsTr("Backup-Verzeichnis"), key: "backupDir",  icon: "💾" }
                ]

                delegate: Item {
                    width:  parent.width
                    height: 60

                    Rectangle {
                        visible:        index < 3
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
                                text:             root.infos[modelData.key] || qsTr("–")
                                font.pixelSize:   11
                                font.family:      "monospace"
                                color:            root.theme.textPrimary
                                elide:            Text.ElideMiddle
                            }
                        }

                        Rectangle {
                            id:               kopBtn
                            width:            28; height: 28; radius: 4
                            color:            kopMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color:     root.theme.border
                            Layout.alignment: Qt.AlignVCenter
                            visible:          (root.infos[modelData.key] || "") !== ""

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
                                    clipboard.text = root.infos[modelData.key] || ""
                                    clipboard.selectAll()
                                    clipboard.copy()
                                    kopTimer.restart()
                                }
                            }
                            ToolTip { visible: kopMouse.containsMouse; text: qsTr("Pfad kopieren"); delay: 600 }
                        }

                        Rectangle {
                            width:            28; height: 28; radius: 4
                            color:            oeffMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color:     root.theme.border
                            Layout.alignment: Qt.AlignVCenter
                            visible:          (root.infos[modelData.key] || "") !== ""

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
                                    var p = root.infos[modelData.key] || ""
                                    if (p !== "") Qt.openUrlExternally("file://" + p)
                                }
                            }
                            ToolTip { visible: oeffMouse.containsMouse; text: qsTr("Im Dateimanager öffnen"); delay: 600 }
                        }
                    }
                }
            }
        }
    }

    TextEdit { id: clipboard; visible: false }
}
