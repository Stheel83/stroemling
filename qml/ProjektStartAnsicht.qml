import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"

Item {
    id: root
    required property var theme
    property bool debug: false

    signal zurueck()

    property bool _geaendert:    false
    property bool _ladevorgang:  false

    function _ladenMetaDaten() {
        _ladevorgang = true
        var info = db.ersteProjektInfo()
        nameField.text   = info.name          || ""
        nummerField.text = info.projektnummer  || ""
        agField.text     = info.auftraggeber   || ""
        anField.text     = info.auftragnehmer  || ""
        bearField.text   = info.bearbeiter     || ""
        _ladevorgang = false
        _geaendert   = false
    }

    Component.onCompleted: { if (db.projektOffen) _ladenMetaDaten() }
    onVisibleChanged:       { if (visible && db.projektOffen) _ladenMetaDaten() }

    Connections {
        target: db
        function onProjektOffenChanged() {
            if (db.projektOffen) root._ladenMetaDaten()
            else root._geaendert = false
        }
    }

    // ── Datei-Dialoge ─────────────────────────────────────────────────
    FileDialog {
        id: neuesProjektDialog
        fileMode:      FileDialog.SaveFile
        nameFilters:   ["Strömling Projekte (*.strl)"]
        defaultSuffix: "strl"
        onAccepted: {
            if (!db.createProjekt(selectedFile.toString(), ""))
                fehlerPopup.open()
        }
    }

    FileDialog {
        id: projektOeffnenDialog
        fileMode:    FileDialog.OpenFile
        nameFilters: ["Strömling Projekte (*.strl)", "Alle Dateien (*)"]
        onAccepted: {
            if (!db.openProjekt(selectedFile.toString()))
                fehlerPopup.open()
        }
    }

    // ── Fehler-Popup ──────────────────────────────────────────────────
    Popup {
        id: fehlerPopup
        modal: true; anchors.centerIn: parent; padding: 20
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Column {
            spacing: 12
            Text { text: qsTr("Projekt konnte nicht geöffnet werden."); color: root.theme.textPrimary; font.pixelSize: 13 }
            Text { text: qsTr("Datei beschädigt oder falsches Format."); color: root.theme.textMuted; font.pixelSize: 11 }
            Button {
                text: qsTr("OK"); onClicked: fehlerPopup.close()
                background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg; radius: 4; border.color: root.theme.accent }
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }

    // ── Haupthintergrund ──────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: root.theme.surfaceDeep }

    // ── Zweispaltiges Layout ──────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── LINKE SPALTE: Projektliste ────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: root.theme.sidebar

            Rectangle {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 1; color: root.theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header
                Rectangle {
                    Layout.fillWidth: true; height: 52; color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 10 }
                        spacing: 6
                        Text {
                            text: qsTr("PROJEKTE")
                            font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 1
                            color: root.theme.textMuted
                        }
                        Item { Layout.fillWidth: true }
                        // Öffnen-Button
                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: oeffBtnHov.containsMouse ? root.theme.hover : "transparent"
                            Text { anchors.centerIn: parent; text: "📂"; font.pixelSize: 14 }
                            MouseArea {
                                id: oeffBtnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: projektOeffnenDialog.open()
                                ToolTip.visible: containsMouse; ToolTip.delay: 600; ToolTip.text: qsTr("Projekt öffnen…")
                            }
                        }
                        // Neu-Button
                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: neuBtnHov.containsMouse ? root.theme.accent : root.theme.inputBg
                            border.color: root.theme.accent
                            Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 18; font.weight: Font.Bold; color: root.theme.textPrimary }
                            MouseArea {
                                id: neuBtnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: neuesProjektDialog.open()
                                ToolTip.visible: containsMouse; ToolTip.delay: 600; ToolTip.text: qsTr("Neues Projekt")
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

                // Projektliste
                ListView {
                    id: projektListe
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: db.bekannteProjecte

                    Text {
                        visible: projektListe.count === 0
                        anchors.centerIn: parent
                        text: qsTr("Keine Projekte\nin der Registry")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 12; color: root.theme.textMuted
                    }

                    delegate: Item {
                        id: projektItem
                        width: projektListe.width
                        height: 62

                        readonly property bool istOffen: db.projektOffen && db.projektPfad === modelData.dateiPfad
                        readonly property bool fehlt:    !modelData.dateiExistiert

                        Rectangle {
                            anchors.fill: parent
                            color: projektItem.istOffen
                                   ? (root.theme.accent + "28")
                                   : (itemMa.containsMouse ? root.theme.hover : "transparent")
                        }

                        // Akzent-Streifen links für offenes Projekt
                        Rectangle {
                            visible: projektItem.istOffen
                            width: 3; height: parent.height * 0.55
                            radius: 2; x: 0; anchors.verticalCenter: parent.verticalCenter
                            color: root.theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: projektItem.istOffen ? 14 : 12; rightMargin: 12 }
                            spacing: 10

                            Text {
                                font.pixelSize: 18
                                text: projektItem.fehlt ? "⚠" : "📄"
                                color: projektItem.fehlt ? "#cc8800" : root.theme.textMuted
                            }

                            Column {
                                Layout.fillWidth: true; spacing: 3
                                Text {
                                    width: parent.width
                                    text: modelData.projektName || qsTr("(Unbenannt)")
                                    font.pixelSize: 13
                                    font.weight: projektItem.istOffen ? Font.Medium : Font.Normal
                                    color: projektItem.fehlt ? "#cc8800" : root.theme.textPrimary
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.dateiPfad
                                    font.pixelSize: 10; font.family: "monospace"
                                    color: root.theme.textMuted; elide: Text.ElideMiddle; opacity: 0.75
                                }
                            }
                        }

                        Rectangle {
                            visible: index < projektListe.count - 1
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                            height: 1; color: root.theme.divider
                        }

                        MouseArea {
                            id: itemMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: projektItem.fehlt ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (projektItem.fehlt || projektItem.istOffen) return
                                db.openProjekt(modelData.dateiPfad)
                            }
                        }
                    }
                }
            }
        }

        // ── RECHTE SPALTE: Metadaten-Panel ───────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.theme.surface

            // Platzhalter wenn kein Projekt offen
            Column {
                visible: !db.projektOffen
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📁"; font.pixelSize: 52; opacity: 0.2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Projekt auswählen oder neu anlegen")
                    font.pixelSize: 14; color: root.theme.textMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Klicke in der Liste auf ein Projekt\num es zu öffnen und zu bearbeiten.")
                    font.pixelSize: 11; color: root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; opacity: 0.6
                }
            }

            // Metadaten-Formular wenn Projekt offen
            ColumnLayout {
                visible: db.projektOffen
                anchors { fill: parent; topMargin: 32; bottomMargin: 24; leftMargin: 40; rightMargin: 40 }
                spacing: 0

                Text {
                    text: qsTr("Projektdetails")
                    font.pixelSize: 20; font.weight: Font.Light
                    color: root.theme.textPrimary
                    Layout.bottomMargin: 28
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2; rowSpacing: 14; columnSpacing: 20

                    Text { text: qsTr("Name"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: nameField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: nameField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }

                    Text { text: qsTr("Projektnummer"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: nummerField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: nummerField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }

                    Text { text: qsTr("Auftraggeber"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: agField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: agField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }

                    Text { text: qsTr("Auftragnehmer"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: anField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: anField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }

                    Text { text: qsTr("Bearbeiter"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: bearField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: bearField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }
                }

                Item { height: 24 }

                // Dateipfad
                Text { text: qsTr("DATEI"); font.pixelSize: 10; font.letterSpacing: 1; color: root.theme.textMuted }
                Item { height: 6 }
                Text {
                    Layout.fillWidth: true
                    text: db.projektPfad
                    font.pixelSize: 11; font.family: "monospace"
                    color: root.theme.textMuted; wrapMode: Text.WrapAnywhere; opacity: 0.8
                }

                Item { Layout.fillHeight: true }

                // Button-Leiste
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    // Aus Liste entfernen
                    Rectangle {
                        implicitWidth: 150; height: 34; radius: 4
                        color: entfHov.containsMouse ? root.theme.hover : "transparent"
                        border.color: root.theme.border
                        Text { anchors.centerIn: parent; text: qsTr("Aus Liste entfernen"); font.pixelSize: 11; color: root.theme.textMuted }
                        MouseArea {
                            id: entfHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { db.projektAusRegistryEntfernen(db.projektPfad); db.closeProjekt() }
                            ToolTip.visible: containsMouse; ToolTip.delay: 800
                            ToolTip.text: qsTr("Aus Projektliste entfernen (Datei bleibt erhalten)")
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Speichern-Button (nur leuchtend wenn Änderungen)
                    Rectangle {
                        implicitWidth: 110; height: 34; radius: 4
                        color: root._geaendert
                               ? (speichernHov.containsMouse ? Qt.lighter(root.theme.accent, 1.12) : root.theme.accent)
                               : root.theme.inputBg
                        border.color: root._geaendert ? root.theme.accent : root.theme.border
                        Text {
                            anchors.centerIn: parent; text: qsTr("Speichern"); font.pixelSize: 12
                            color: root._geaendert ? "white" : root.theme.textMuted
                        }
                        MouseArea {
                            id: speichernHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root._geaendert) return
                                if (db.projektMetaDatenSpeichern(nameField.text, nummerField.text,
                                                                  agField.text, anField.text, bearField.text))
                                    root._geaendert = false
                            }
                        }
                    }

                    // Zum Schaltplan
                    Rectangle {
                        implicitWidth: 150; height: 34; radius: 4
                        color: schaltplanHov.containsMouse ? root.theme.accent : root.theme.inputBg
                        border.color: root.theme.accent
                        Text { anchors.centerIn: parent; text: qsTr("Zum Schaltplan ›"); font.pixelSize: 12; color: root.theme.textPrimary }
                        MouseArea {
                            id: schaltplanHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.zurueck()
                        }
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Projekt-Start-Ansicht"); visible: root.debug }
}
