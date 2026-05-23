import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"

Item {
    id: root
    required property var theme
    property bool debug: false

    // ── Datei-Dialoge ────────────────────────────────────────────
    FileDialog {
        id: neuesProjektDialog
        fileMode:       FileDialog.SaveFile
        nameFilters:    ["Strömling Projekte (*.stroemling)"]
        defaultSuffix:  "stroemling"
        onAccepted: {
            var pfad = selectedFile.toString().replace(/^file:\/\//, "")
            if (!db.createProjekt(pfad, ""))
                fehlerPopup.open()
        }
    }

    FileDialog {
        id: projektOeffnenDialog
        fileMode:    FileDialog.OpenFile
        nameFilters: ["Strömling Projekte (*.stroemling)", "Alle Dateien (*)"]
        onAccepted: {
            var pfad = selectedFile.toString().replace(/^file:\/\//, "")
            if (!db.openProjekt(pfad))
                fehlerPopup.open()
        }
    }

    // ── Fehler-Popup ─────────────────────────────────────────────
    Popup {
        id:               fehlerPopup
        modal:            true
        anchors.centerIn: parent
        padding:          20
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Column {
            spacing: 12
            Text { text: qsTr("Projekt konnte nicht geöffnet werden."); color: root.theme.textPrimary; font.pixelSize: 13 }
            Text { text: qsTr("Datei beschädigt oder falsches Format."); color: root.theme.textMuted; font.pixelSize: 11 }
            Button {
                text: qsTr("OK"); onClicked: fehlerPopup.close()
                background: Rectangle { color: root.theme.btnPrimary; radius: 4 }
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }

    // ── Hintergrund ──────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: root.theme.surfaceDeep }

    // ── Inhalt (zentriert) ───────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        width:            Math.min(480, parent.width - 40)
        spacing:          0

        // Titel
        Text {
            Layout.alignment:    Qt.AlignHCenter
            text:                "Strömling Design"
            font.pixelSize:      28
            font.weight:         Font.Light
            color:               root.theme.textPrimary
            font.letterSpacing:  2
        }
        Item { height: 6 }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text:             qsTr("E-CAD für Elektrotechnik")
            font.pixelSize:   12
            color:            root.theme.textMuted
            font.letterSpacing: 0.5
        }
        Item { height: 40 }

        // Aktions-Karten
        Rectangle {
            Layout.fillWidth: true
            height:           116
            color:            root.theme.surface
            radius:           8
            border.color:     root.theme.border

            Column {
                anchors.fill: parent

                // Neues Projekt
                Rectangle {
                    width:  parent.width
                    height: 56
                    color:  neuHover.containsMouse ? root.theme.hover : "transparent"
                    radius: 8

                    RowLayout {
                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                        spacing: 14

                        Text { text: "📄"; font.pixelSize: 18 }
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Neues Projekt"); font.pixelSize: 13; font.weight: Font.Medium; color: root.theme.textPrimary }
                            Text { text: qsTr("Leere Projektdatei (.stroemling) anlegen"); font.pixelSize: 10; color: root.theme.textMuted }
                        }
                        Text { text: "›"; font.pixelSize: 16; color: root.theme.textMuted }
                    }
                    MouseArea { id: neuHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: neuesProjektDialog.open() }
                }

                // Trennlinie
                Rectangle { width: parent.width; height: 1; color: root.theme.divider }

                // Projekt öffnen
                Rectangle {
                    width:  parent.width
                    height: 56
                    color:  oeffHover.containsMouse ? root.theme.hover : "transparent"
                    radius: 8

                    RowLayout {
                        anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                        spacing: 14

                        Text { text: "📂"; font.pixelSize: 18 }
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: qsTr("Projekt öffnen"); font.pixelSize: 13; font.weight: Font.Medium; color: root.theme.textPrimary }
                            Text { text: qsTr("Existierende .stroemling-Datei laden"); font.pixelSize: 10; color: root.theme.textMuted }
                        }
                        Text { text: "›"; font.pixelSize: 16; color: root.theme.textMuted }
                    }
                    MouseArea { id: oeffHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: projektOeffnenDialog.open() }
                }
            }
        }

        // Zuletzt geöffnet
        Item { height: 28 }
        Text {
            Layout.leftMargin:   4
            text:                qsTr("ZULETZT GEÖFFNET")
            font.pixelSize:      10
            font.weight:         Font.Medium
            font.letterSpacing:  1
            color:               root.theme.textMuted
        }
        Item { height: 8 }

        Rectangle {
            id:               recentCard
            Layout.fillWidth: true
            height:           recentList.count > 0 ? recentList.count * 52 : 52
            color:            root.theme.surface
            radius:           8
            border.color:     root.theme.border
            visible:          true

            // Platzhalter wenn keine Projekte
            Text {
                anchors.centerIn: parent
                visible:          recentList.count === 0
                text:             qsTr("Noch keine Projekte geöffnet")
                font.pixelSize:   12
                color:            root.theme.textMuted
            }

            Column {
                anchors.fill: parent
                visible:      recentList.count > 0

                Repeater {
                    id: recentList
                    model: db.zuletzGeoeffnete()

                    delegate: Item {
                        width:  parent.width
                        height: 52

                        Rectangle {
                            visible:        index > 0
                            anchors.top:    parent.top
                            width:          parent.width; height: 1
                            color:          root.theme.divider
                        }

                        Rectangle {
                            anchors.fill: parent
                            color:        itemHover.containsMouse ? root.theme.hover : "transparent"

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                spacing: 12

                                Text { text: "📄"; font.pixelSize: 14 }
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        width:          parent.width
                                        text:           modelData.name || qsTr("(Unbenannt)")
                                        font.pixelSize: 12
                                        font.weight:    Font.Medium
                                        color:          root.theme.textPrimary
                                        elide:          Text.ElideRight
                                    }
                                    Text {
                                        width:          parent.width
                                        text:           modelData.pfad
                                        font.pixelSize: 10
                                        font.family:    "monospace"
                                        color:          root.theme.textMuted
                                        elide:          Text.ElideMiddle
                                    }
                                }
                            }

                            MouseArea {
                                id:          itemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    if (!db.openProjekt(modelData.pfad))
                                        fehlerPopup.open()
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { height: 40 }

        // Version
        Text {
            Layout.alignment: Qt.AlignHCenter
            text:             qsTr("Schema v") + db.datenbankInfos()["schemaVersion"] || ""
            font.pixelSize:   10
            color:            root.theme.textMuted
            visible:          false
        }
    }

    DebugLabel { panelName: qsTr("Projekt-Start-Ansicht"); visible: root.debug }
}
