import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

// Austausch von Bibliotheksinhalten als JSON-Bündel (Blattvorlagen S2, Makros S3): Export, Import erst als Analyse
// (neu / gleich / abweichend), dann nur die vom Nutzer gewählten Aktionen. Gleiche Bedienung wie der Bauteil-Austausch.
// Die Datenbankaufrufe kommen als Funktionen herein, damit derselbe Dialog für Vorlagen und Makros dient:
//   fnExport(pfad) → {ok, anzahl, fehler}, fnAnalyse(pfad) → {ok, fehler, eintraege[{uid,name,art,status,vorschlag,aktionen,...}], ...},
//   fnAusfuehren(pfad, entscheidungen) → {ok, fehler, angelegt, ersetzt, kopien, uebersprungen}
Item {
    id: root
    required property var theme

    property string titel: qsTr("Austausch")
    property string inhaltName: qsTr("Einträge")                 // Mehrzahl, z. B. „Vorlagen“
    property string dateiPrefix: "buendel"
    property string exportErklaerung: ""
    property var fnExport: function (pfad) { return { ok: false, fehler: "" } }
    property var fnAnalyse: function (pfad) { return { ok: false, fehler: "" } }
    property var fnAusfuehren: function (pfad, e) { return { ok: false, fehler: "" } }

    signal importiert()

    function open() { dlg.open() }

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
                analysieren.clicked()
            }
        }
    }

    readonly property var statusText: ({ "neu": qsTr("neu"), "gleich": qsTr("gleich"), "abweichend": qsTr("abweichend") })
    readonly property var statusFarbe: ({ "neu": "#1e8449", "gleich": theme.textMuted, "abweichend": "#b9770e" })
    readonly property var aktionText: ({
        "anlegen": qsTr("Neu anlegen"), "ueberspringen": qsTr("Überspringen"),
        "ersetzen": qsTr("Lokales ersetzen"), "kopie": qsTr("Als Kopie anlegen")
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
        title: root.titel
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: Math.min(760, parent ? parent.width - 40 : 760)
        height: Math.min(560, parent ? parent.height - 40 : 560)
        padding: 16
        closePolicy: Popup.CloseOnEscape

        property var    analyse: null
        property var    entscheidungen: ({})
        property string ergebnis: ""
        property bool   ergebnisOk: true

        onOpened: {
            exportPfad.text = root._dokumente() + "/" + root.dateiPrefix + "_" + Qt.formatDate(new Date(), "yyyy-MM-dd") + ".json"
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

                ColumnLayout {
                    spacing: 10
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        color: root.theme.textSecondary; font.pixelSize: 12
                        text: root.exportErklaerung
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
                                waehler.titelText = qsTr("Exportieren nach …")
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
                            var r = root.fnExport(pfad)
                            dlg.ergebnisOk = r.ok
                            dlg.ergebnis = r.ok ? qsTr("%1 %2 exportiert nach %3").arg(r.anzahl).arg(root.inhaltName).arg(pfad) : r.fehler
                            if (r.ok) meldungManager.zeigen(qsTr("%1 %2 exportiert.").arg(r.anzahl).arg(root.inhaltName), true)
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

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
                                waehler.titelText = qsTr("Bündel auswählen")
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
                                var a = root.fnAnalyse(root._pfad(importPfad.text))
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
                              ? qsTr("%1 neu · %2 gleich · %3 abweichend").arg(dlg.analyse.anzahlNeu).arg(dlg.analyse.anzahlGleich).arg(dlg.analyse.anzahlAbweichend)
                              : ""
                    }

                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 2
                        model: dlg.analyse && dlg.analyse.ok ? dlg.analyse.eintraege : []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Rectangle {
                            id: zeile
                            required property var modelData
                            width: ListView.view.width - 10
                            height: 48
                            color: root.theme.inputBg; radius: 4
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 6; spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 1
                                    Text { text: zeile.modelData.name; color: root.theme.textPrimary; font.pixelSize: 12
                                           font.weight: Font.Medium; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { color: root.theme.textMuted; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
                                           text: (zeile.modelData.art ? zeile.modelData.art + " · " : "") + qsTr("Bündel v%1").arg(zeile.modelData.bundleVersion)
                                                 + (zeile.modelData.lokaleVersion !== undefined ? qsTr(" · lokal v%1").arg(zeile.modelData.lokaleVersion) : "") }
                                }
                                Text {
                                    text: root.statusText[zeile.modelData.status]
                                    color: root.statusFarbe[zeile.modelData.status]; font.pixelSize: 11; font.weight: Font.Medium
                                    Layout.preferredWidth: 90; elide: Text.ElideRight
                                }
                                ComboBox {
                                    Layout.preferredWidth: 200
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
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        color: root.theme.textMuted; font.pixelSize: 11
                        text: qsTr("„Überspringen“ lässt das Vorhandene unverändert. Nichts wird überschrieben, solange du es nicht ausdrücklich wählst. Vor dem Import wird die Bibliothek gesichert.")
                    }
                    Button {
                        text: qsTr("Importieren")
                        enabled: dlg.analyse && dlg.analyse.ok && dlg.analyse.eintraege.length > 0
                        onClicked: {
                            var r = root.fnAusfuehren(root._pfad(importPfad.text), dlg.entscheidungen)
                            dlg.ergebnisOk = r.ok
                            if (r.ok) {
                                dlg.ergebnis = qsTr("%1 angelegt · %2 ersetzt · %3 Kopien · %4 übersprungen").arg(r.angelegt).arg(r.ersetzt).arg(r.kopien).arg(r.uebersprungen)
                                meldungManager.zeigen(qsTr("Import abgeschlossen."), true)
                                dlg.analyse = root.fnAnalyse(root._pfad(importPfad.text))
                                root.importiert()
                            } else {
                                dlg.ergebnis = r.fehler
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
