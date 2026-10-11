import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import stroemling

// MCU-PINBELEGUNG-01: Pinbelegung der Mikrokontroller-Boards (Arduino, ESP32, ...).
// Eine Zeile je Board-Pin × angeschlossenem Pin, aus den gezeichneten Verbindungen
// abgeleitet (nichts zu pflegen). Dazu optional ein #define-Block für den Sketch.
ColumnLayout {
    id: root
    required property var panel
    required property var theme
    spacing: 0

    FileDialog {
        id: csvDialog
        fileMode: FileDialog.SaveFile
        title: qsTr("Pinbelegung als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.mikrocontrollerPinbelegungCsvSpeichern(panel.projektId, selectedFile)
    }
    LaPdfExportDialog {
        id: pdfDialog
        theme: root.theme
        dateiname: "pinbelegung.pdf"
        titelText: qsTr("Pinbelegung exportieren")
        onExportAngefordert: (pfad) => {
            // letzte Spalte (Canvas-Sprung) gehört nicht ins PDF
            var spalten = panel.mcCols.slice(0, panel.mcCols.length - 1).map(function (c) { return c.header })
            var zeilen = panel.mcAnzeige.map(function (r) {
                return [r.boardBmk || "", r.boardName || "", r.pin || "", r.netz || "",
                        r.istFrei ? qsTr("(frei)") : (r.verbundenBmk || ""),
                        r.verbundenSymbol || "", r.verbundenPin || "",
                        r.defineName || "", r.defineWert || "", r.blattnr || ""]
            })
            erfolgReagieren(db.listePdfSpeichern(qsTr("Pinbelegung Mikrokontroller"), panel.projektName, spalten, zeilen, pfad))
        }
    }

    // #define-Ausgabe
    Dialog {
        id: codeDialog
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(640, parent ? parent.width - 40 : 640)
        height: Math.min(460, parent ? parent.height - 40 : 460)
        padding: 16
        title: qsTr("Pin-Definitionen für den Sketch")
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

        property string text: ""
        onAboutToShow: text = db.mikrocontrollerCode(panel.projektId)

        contentItem: ColumnLayout {
            spacing: 8
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: root.theme.textMuted; font.pixelSize: 11
                text: qsTr("Aus den Verbindungen abgeleitet: Name = BMK des angeschlossenen Bauteils + Anschluss, Wert = Pin-Nummer des Boards. Nur Pins mit digitalem/analogem Namen (D7, A0, GPIO21 …) werden ausgegeben.")
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                color: root.theme.inputBg; border.color: root.theme.border; radius: 4
                ScrollView {
                    anchors.fill: parent; anchors.margins: 4; clip: true
                    TextArea {
                        id: codeFeld
                        readOnly: true
                        text: codeDialog.text
                        wrapMode: TextArea.NoWrap
                        font.family: "monospace"; font.pixelSize: 12
                        color: root.theme.textPrimary
                        background: null
                        selectByMouse: true
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("In Zwischenablage kopieren"); implicitHeight: 32
                    enabled: codeDialog.text.length > 0
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                    onClicked: { codeFeld.selectAll(); codeFeld.copy(); codeFeld.deselect() }
                }
                Button {
                    text: qsTr("Schließen"); implicitHeight: 32
                    contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                    onClicked: codeDialog.close()
                }
            }
        }
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Pinbelegung")
        anzahl: panel.mcAnzeige.length
        filterText: panel.mcFilter
        onFilterTextChanged: panel.mcFilter = filterText
        onCsvKlick: csvDialog.open()
        onPdfKlick: pdfDialog.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    // Zusatzleiste: nur belegte Pins / Code
    Rectangle {
        Layout.fillWidth: true; height: 30; color: root.theme.surface
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 8
            Rectangle {
                width: 16; height: 16; radius: 3
                color: root.theme.hover; border.color: panel.mcNurBelegt ? root.theme.accent : root.theme.border
                Text { anchors.centerIn: parent; visible: panel.mcNurBelegt; text: "✓"; font.pixelSize: 11; color: root.theme.accent }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.mcNurBelegt = !panel.mcNurBelegt
                }
            }
            Text { text: qsTr("Freie Pins ausblenden"); font.pixelSize: 11; color: root.theme.textSecondary }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: codeTxt.implicitWidth + 20; height: 22; radius: 4
                color: codeMa.containsMouse ? root.theme.activeItemAlt : root.theme.hover
                border.color: root.theme.border
                visible: panel.mcDaten.length > 0
                Text { id: codeTxt; anchors.centerIn: parent; text: qsTr("#define-Code …"); font.pixelSize: 11; color: root.theme.textSecondary }
                MouseArea {
                    id: codeMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: codeDialog.open()
                }
            }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    LaSpaltenHeader {
        panel: root.panel; theme: root.theme; colsProp: "mcCols"
        sortFeld: panel.mcSortFeld; sortAsc: panel.mcSortAsc
        onSpalteKlick: (feld) => panel.sortSetzen("mcSortFeld", "mcSortAsc", feld)
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentWidth: availableWidth
        background: Rectangle { color: root.theme.surface }

        Column {
            width: parent.width

            Text {
                visible: panel.mcAnzeige.length === 0
                width: parent.width; padding: 24
                text: panel.projektId < 0 ? qsTr("Kein Projekt ausgewählt")
                    : panel.mcFilter ? qsTr("Kein Treffer für den Filter")
                    : qsTr("Keine Mikrokontroller-Boards im Projekt.\nEin Board-Symbol platzieren (z. B. Arduino UNO, Kategorie Arduino) und seine Pins verdrahten.\nEigene Board-Symbole werden im Symboleditor über „Mikrokontroller: Board“ markiert.")
                font.pixelSize: 12; color: root.theme.textMuted
                font.italic: true; wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: panel.mcAnzeige
                delegate: Rectangle {
                    width: parent.width; height: 28
                    color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd
                    opacity: modelData.istFrei ? 0.6 : 1.0

                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: 3; color: modelData.istFrei ? root.theme.border : "#4caf50"
                    }

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { width: panel.mcCols[0].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.boardBmk || ""; font.pixelSize: 12; color: root.theme.accent; elide: Text.ElideRight }
                        Text { width: panel.mcCols[1].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.boardName || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.mcCols[2].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.pin || ""; font.pixelSize: 12; font.bold: true; color: root.theme.textPrimary; elide: Text.ElideRight }
                        Text { width: panel.mcCols[3].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.netz || ""; font.pixelSize: 12; color: root.theme.textMuted; elide: Text.ElideRight }
                        Text { width: panel.mcCols[4].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.istFrei ? qsTr("(frei)") : (modelData.verbundenBmk || "–"); font.pixelSize: 12; color: root.theme.accent; elide: Text.ElideRight }
                        Text { width: panel.mcCols[5].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.verbundenSymbol || ""; font.pixelSize: 12; color: root.theme.textPrimary; elide: Text.ElideRight }
                        Text { width: panel.mcCols[6].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.verbundenPin || ""; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.mcCols[7].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.defineName || ""; font.pixelSize: 12; font.family: "monospace"; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.mcCols[8].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.defineWert || ""; font.pixelSize: 12; font.family: "monospace"; color: root.theme.textSecondary; elide: Text.ElideRight }
                        Text { width: panel.mcCols[9].w; anchors.verticalCenter: parent.verticalCenter; text: modelData.blattnr || ""; font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight }
                        Item {
                            width: panel.mcCols[10].w; height: 28
                            Rectangle {
                                anchors.centerIn: parent; width: 20; height: 18; radius: 3
                                color: mcSprungMa.containsMouse ? root.theme.accent : "transparent"
                                border.color: mcSprungMa.containsMouse ? root.theme.accent : root.theme.border
                                Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 10
                                       color: mcSprungMa.containsMouse ? "#ffffff" : root.theme.accent }
                                MouseArea {
                                    id: mcSprungMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    enabled: panel.canvas !== null && (modelData.seiteId || 0) > 0
                                    onClicked: panel.canvas.bmElementSprungAnfordern(
                                        modelData.seiteId, modelData.blattnr, modelData.seiteBez,
                                        modelData.weltX, modelData.weltY)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
