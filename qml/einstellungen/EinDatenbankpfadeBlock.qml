import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sektion "Datenbankpfade": alle App-Datenbanken (Zentrale DB, Wiki, Makro- und
// Bauteil-Bibliothek) sowie das Backup-Verzeichnis liegen fest im selben
// App-Datenverzeichnis (QStandardPaths::AppLocalDataLocation) - der Nutzer kann
// keine abweichenden Pfade konfigurieren. Daher: Ordnerpfad einmal oben, darunter
// nur noch die Dateinamen (Kopieren-Button pro Zeile für den vollen Pfad).
ColumnLayout {
    id: root

    required property var theme
    property  var infos: ({})

    Layout.fillWidth: true
    spacing: 0

    // Liefert den übergeordneten Ordner eines Datei-Pfades.
    function ordnerPfad(pfad) {
        if (pfad === "") return pfad
        var idx = Math.max(pfad.lastIndexOf("/"), pfad.lastIndexOf("\\"))
        return idx >= 0 ? pfad.substring(0, idx) : pfad
    }

    // Liefert nur den Datei-/Ordnernamen (letztes Pfadsegment) - für backupDir
    // (das selbst schon ein Ordnerpfad ist) wird ein evtl. Trailing-Slash zuerst entfernt.
    function basisName(pfad) {
        if (pfad === "") return ""
        var p   = pfad.replace(/[\\/]+$/, "")
        var idx = Math.max(p.lastIndexOf("/"), p.lastIndexOf("\\"))
        return idx >= 0 ? p.substring(idx + 1) : p
    }

    readonly property string appOrdner: root.ordnerPfad(root.infos["launcherDb"] || "")

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

    // ── App-Datenverzeichnis (einmalig, gemeinsamer Ordner für alle Einträge unten) ──
    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        height:             60
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 8

            Text { text: "📁"; font.pixelSize: 14; Layout.alignment: Qt.AlignVCenter }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing:          4

                Text {
                    Layout.fillWidth: true
                    text:             qsTr("App-Datenverzeichnis")
                    font.pixelSize:   11
                    font.weight:      Font.Medium
                    color:            root.theme.textMuted
                }
                Text {
                    Layout.fillWidth: true
                    text:             root.appOrdner || qsTr("–")
                    font.pixelSize:   11
                    font.family:      "monospace"
                    color:            root.theme.textPrimary
                    elide:            Text.ElideMiddle
                }
            }

            Rectangle {
                width:            28; height: 28; radius: 4
                color:            ordKopMouse.containsMouse ? root.theme.hover : "transparent"
                border.color:     root.theme.border
                Layout.alignment: Qt.AlignVCenter
                visible:          root.appOrdner !== ""

                Text {
                    anchors.centerIn: parent
                    text:             ordKopTimer.running ? "✓" : "⎘"
                    font.pixelSize:   13
                    color:            ordKopTimer.running ? root.theme.accent : root.theme.textMuted
                }
                Timer { id: ordKopTimer; interval: 1200 }
                MouseArea {
                    id:           ordKopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        clipboard.text = root.appOrdner
                        clipboard.selectAll()
                        clipboard.copy()
                        ordKopTimer.restart()
                    }
                }
                ToolTip { visible: ordKopMouse.containsMouse; text: qsTr("Ordnerpfad kopieren"); delay: 600 }
            }

            Rectangle {
                width:            28; height: 28; radius: 4
                color:            ordOeffMouse.containsMouse ? root.theme.hover : "transparent"
                border.color:     root.theme.border
                Layout.alignment: Qt.AlignVCenter
                visible:          root.appOrdner !== ""

                Text { anchors.centerIn: parent; text: "📂"; font.pixelSize: 12 }
                MouseArea {
                    id:           ordOeffMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (root.appOrdner !== "") Qt.openUrlExternally("file://" + root.appOrdner)
                }
                ToolTip { visible: ordOeffMouse.containsMouse; text: qsTr("Im Dateimanager öffnen"); delay: 600 }
            }
        }
    }

    Item { implicitHeight: 8 }

    // ── Einzelne Dateien/Ordner innerhalb des App-Datenverzeichnisses ──
    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        height:             5 * 44
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        Column {
            anchors.fill: parent

            Repeater {
                model: [
                    { label: qsTr("Zentrale Datenbank"), key: "launcherDb",   icon: "🗄" },
                    { label: qsTr("Wiki-Datenbank"),     key: "wikiDb",       icon: "📚" },
                    { label: qsTr("Makro-Bibliothek"),   key: "makrosDb",     icon: "⚙" },
                    { label: qsTr("Bauteil-Bibliothek"), key: "bibliothekDb", icon: "🧩" },
                    { label: qsTr("Backup-Verzeichnis"), key: "backupDir",    icon: "💾" }
                ]

                delegate: Item {
                    width:  parent.width
                    height: 44

                    Rectangle {
                        visible:        index < 4
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
                            font.pixelSize:   13
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text:             modelData.label
                            font.pixelSize:   11
                            color:            root.theme.textMuted
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text:             root.basisName(root.infos[modelData.key] || "") || qsTr("–")
                            font.pixelSize:   11
                            font.family:      "monospace"
                            color:            root.theme.textPrimary
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
                            ToolTip { visible: kopMouse.containsMouse; text: qsTr("Vollen Pfad kopieren"); delay: 600 }
                        }
                    }
                }
            }
        }
    }

    TextEdit { id: clipboard; visible: false }
}
