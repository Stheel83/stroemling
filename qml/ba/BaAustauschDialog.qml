import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

// BIB-IMPORT-01: Austausch der Bauteil-Bibliothek zwischen Rechnern (Konzept 56).
// Export als JSON-Bündel; Import erst als Analyse (neu / gleich / abweichend / gleicher Inhalt / ähnlich), dann nur die vom
// Nutzer gewählten Aktionen. Pfade als eigenes Eingabefeld (kein nativer Dateidialog – AppImage-Problem, wie bei den PDF-Exporten).
Item {
    id: root
    required property var theme

    function open() { dlg.open() }

    // Eigener Dateiwähler; `ziel` merkt, für welches Feld er geöffnet wurde
    DateiWaehlerDialog {
        id: waehler
        theme: root.theme
        property string ziel: ""
        endungen: [".json"]
        dateiEndung: ".json"
        onGewaehlt: function (pfad) {
            if (ziel === "export") {
                exportPfad.text = pfad
            } else {
                importPfad.text = pfad
                analysieren.clicked()      // direkt analysieren: nach der Dateiwahl gibt es nichts mehr zu tippen
            }
        }
    }

    readonly property var statusText: ({
        "neu": qsTr("neu"), "gleich": qsTr("gleich"), "abweichend": qsTr("abweichend"),
        "gleicherInhalt": qsTr("gleicher Inhalt, andere UID"), "aehnlich": qsTr("ähnlich (gleiche Bezeichnung)")
    })
    readonly property var statusFarbe: ({
        "neu": "#1e8449", "gleich": theme.textMuted, "abweichend": "#b9770e",
        "gleicherInhalt": "#2874a6", "aehnlich": "#b9770e"
    })
    readonly property var aktionText: ({
        "anlegen": qsTr("Neu anlegen"), "ueberspringen": qsTr("Überspringen"),
        "ueberschreiben": qsTr("Lokales überschreiben"), "kopie": qsTr("Als Kopie anlegen"),
        "verknuepfen": qsTr("Mit lokalem verknüpfen")
    })

    function _pfad(s) {
        s = String(s).trim()
        if (s.startsWith("file:///")) return s.substring(7)
        if (s.startsWith("file://")) return s.substring(7)
        return s
    }
    function _dokumente() {
        return _pfad(StandardPaths.writableLocation(StandardPaths.DocumentsLocation))
    }

    Dialog {
        id: dlg
        title: qsTr("Bauteil-Austausch")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: Math.min(820, parent ? parent.width - 40 : 820)
        height: Math.min(640, parent ? parent.height - 40 : 640)
        padding: 16
        closePolicy: Popup.CloseOnEscape

        property var    analyse: null          // Ergebnis von db.bauteileImportAnalysieren
        property var    entscheidungen: ({})   // uid → Aktion
        property string ergebnis: ""
        property bool   ergebnisOk: true

        onOpened: {
            exportPfad.text = root._dokumente() + "/bauteile_" + Qt.formatDate(new Date(), "yyyy-MM-dd") + ".json"
            importPfad.text = ""
            analyse = null; entscheidungen = ({}); ergebnis = ""
            tabs.currentIndex = 0
        }

        background: Rectangle { color: root.theme.sidebar; radius: 6; border.color: root.theme.border; border.width: 1 }

        header: Text {
            text: dlg.title; font.pixelSize: 15; font.weight: Font.Medium; color: root.theme.textPrimary
            leftPadding: 16; topPadding: 14; bottomPadding: 4
        }

        contentItem: ColumnLayout {
            spacing: 10

            TabBar {
                id: tabs
                Layout.fillWidth: true
                background: Rectangle { color: "transparent" }
                TabButton { text: qsTr("Exportieren") }
                TabButton { text: qsTr("Importieren") }
            }

            StackLayout {
                currentIndex: tabs.currentIndex
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── Export ───────────────────────────────────────────
                ColumnLayout {
                    spacing: 10
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        color: root.theme.textSecondary; font.pixelSize: 12
                        text: qsTr("Schreibt deine Bauteile samt Kabeladern, Klemmen, Steckverbindern und Querverweisen in eine JSON-Datei, "
                                   + "die du auf einem anderen Rechner importieren kannst. Jedes Bauteil behält seine UID.")
                    }
                    CheckBox {
                        id: mitSystem
                        text: qsTr("Mitgelieferte Bauteile einschließen")
                        Layout.fillWidth: true
                        contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                            leftPadding: parent.indicator.width + parent.spacing; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    }
                    Text { text: qsTr("Zieldatei"); color: root.theme.textMuted; font.pixelSize: 11 }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: exportPfad
                            Layout.fillWidth: true; selectByMouse: true
                            color: root.theme.textPrimary; font.pixelSize: 12
                            background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        }
                        Button {
                            text: qsTr("Durchsuchen …")
                            onClicked: {
                                waehler.ziel = "export"
                                waehler.modus = "speichern"
                                waehler.titelText = qsTr("Bauteile exportieren nach …")
                                waehler.vorschlagName = dateiBrowser.dateiname(exportPfad.text)
                                waehler.oeffnenMit(exportPfad.text)
                            }
                        }
                    }
                    Button {
                        text: qsTr("Exportieren")
                        enabled: exportPfad.text.trim().length > 0
                        onClicked: {
                            var pfad = root._pfad(exportPfad.text)
                            if (!pfad.endsWith(".json")) pfad += ".json"
                            var r = db.bauteileExportieren(pfad, mitSystem.checked)
                            dlg.ergebnisOk = r.ok
                            dlg.ergebnis = r.ok ? qsTr("%1 Bauteile exportiert nach %2").arg(r.anzahl).arg(pfad) : r.fehler
                            if (r.ok) meldungManager.zeigen(qsTr("%1 Bauteile exportiert.").arg(r.anzahl), true)
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

                // ── Import ───────────────────────────────────────────
                ColumnLayout {
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: importPfad
                            Layout.fillWidth: true; selectByMouse: true
                            placeholderText: qsTr("Pfad der Bündel-Datei (.json)")
                            color: root.theme.textPrimary; font.pixelSize: 12
                            background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                            onAccepted: analysieren.clicked()
                        }
                        Button {
                            text: qsTr("Durchsuchen …")
                            onClicked: {
                                waehler.ziel = "import"
                                waehler.modus = "oeffnen"
                                waehler.titelText = qsTr("Bauteil-Bündel auswählen")
                                waehler.vorschlagName = ""
                                waehler.oeffnenMit(importPfad.text.length > 0 ? importPfad.text : exportPfad.text)
                            }
                        }
                        Button {
                            id: analysieren
                            text: qsTr("Analysieren")
                            enabled: importPfad.text.trim().length > 0
                            onClicked: {
                                dlg.ergebnis = ""
                                var a = db.bauteileImportAnalysieren(root._pfad(importPfad.text))
                                dlg.analyse = a
                                var e = ({})
                                if (a.ok) for (var i = 0; i < a.eintraege.length; ++i) e[a.eintraege[i].uid] = a.eintraege[i].vorschlag
                                dlg.entscheidungen = e
                                if (!a.ok) { dlg.ergebnisOk = false; dlg.ergebnis = a.fehler }
                            }
                        }
                    }

                    Text {
                        visible: dlg.analyse && dlg.analyse.ok
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        color: root.theme.textSecondary; font.pixelSize: 12
                        text: dlg.analyse && dlg.analyse.ok
                              ? qsTr("%1 neu · %2 gleich · %3 abweichend · %4 gleicher Inhalt mit anderer UID · %5 ähnlich")
                                    .arg(dlg.analyse.anzahlNeu).arg(dlg.analyse.anzahlGleich).arg(dlg.analyse.anzahlAbweichend)
                                    .arg(dlg.analyse.anzahlGleicherInhalt).arg(dlg.analyse.anzahlAehnlich)
                              : ""
                    }

                    ListView {
                        id: liste
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 2
                        model: dlg.analyse && dlg.analyse.ok ? dlg.analyse.eintraege : []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Rectangle {
                            id: zeile
                            required property var modelData
                            width: ListView.view.width - 10
                            height: 52
                            color: root.theme.inputBg; radius: 4
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 6; spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 1
                                    Text { text: zeile.modelData.bezeichnung; color: root.theme.textPrimary; font.pixelSize: 12
                                           font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { color: root.theme.textMuted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
                                           text: [zeile.modelData.typ, zeile.modelData.hersteller, zeile.modelData.artikelnummer]
                                                     .filter(function (t) { return t && t.length > 0 }).join(" · ")
                                                 + (zeile.modelData.lokaleBezeichnung.length > 0 && zeile.modelData.lokaleBezeichnung !== zeile.modelData.bezeichnung
                                                    ? "   ↔ " + zeile.modelData.lokaleBezeichnung : "") }
                                }
                                Text {
                                    text: root.statusText[zeile.modelData.status]
                                    color: root.statusFarbe[zeile.modelData.status]; font.pixelSize: 11; font.weight: Font.Medium
                                    Layout.preferredWidth: 150; elide: Text.ElideRight
                                }
                                ComboBox {
                                    Layout.preferredWidth: 230
                                    model: zeile.modelData.aktionen.map(function (a) { return root.aktionText[a] })
                                    currentIndex: Math.max(0, zeile.modelData.aktionen.indexOf(dlg.entscheidungen[zeile.modelData.uid]))
                                    enabled: zeile.modelData.aktionen.length > 1
                                    onActivated: function (i) {
                                        var e = dlg.entscheidungen
                                        e[zeile.modelData.uid] = zeile.modelData.aktionen[i]
                                        dlg.entscheidungen = e
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        visible: dlg.analyse && dlg.analyse.ok && dlg.analyse.eintraege.length === 0
                        text: qsTr("Das Bündel enthält keine Bauteile."); color: root.theme.textMuted; font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        color: root.theme.textMuted; font.pixelSize: 11
                        text: qsTr("„Überspringen“ lässt das lokale Bauteil unverändert. Nichts wird überschrieben, solange du es nicht ausdrücklich wählst. Vor dem Import wird die Bibliothek gesichert.")
                    }
                    Button {
                        text: qsTr("Importieren")
                        enabled: dlg.analyse && dlg.analyse.ok && dlg.analyse.eintraege.length > 0
                        onClicked: {
                            var r = db.bauteileImportAusfuehren(root._pfad(importPfad.text), dlg.entscheidungen)
                            dlg.ergebnisOk = r.ok
                            if (r.ok) {
                                dlg.ergebnis = qsTr("%1 angelegt · %2 überschrieben · %3 verknüpft · %4 Kopien · %5 übersprungen")
                                                   .arg(r.angelegt).arg(r.ueberschrieben).arg(r.verknuepft).arg(r.kopien).arg(r.uebersprungen)
                                               + (r.warnungen.length > 0 ? "\n" + qsTr("Hinweise:") + "\n• " + r.warnungen.join("\n• ") : "")
                                bauteilModel.laden(bauteilModel.aktiveKategorieId)
                                meldungManager.zeigen(qsTr("Bauteil-Import abgeschlossen."), true)
                                dlg.analyse = db.bauteileImportAnalysieren(root._pfad(importPfad.text))
                            } else {
                                dlg.ergebnis = r.fehler + (r.warnungen.length > 0 ? "\n• " + r.warnungen.join("\n• ") : "")
                            }
                        }
                    }
                }
            }

            Text {
                visible: dlg.ergebnis.length > 0
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: dlg.ergebnis; font.pixelSize: 12
                color: dlg.ergebnisOk ? "#1e8449" : "#c0392b"
            }
        }

        footer: DialogButtonBox {
            background: Rectangle { color: "transparent" }
            Button { text: qsTr("Schließen"); DialogButtonBox.buttonRole: DialogButtonBox.RejectRole; onClicked: dlg.close() }
        }
    }
}
