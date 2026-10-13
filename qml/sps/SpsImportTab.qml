import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// SPS-IMPORT-01: CSV-Import von SPS/PLS-Adresslisten (Bestandsanlagen).
// Gleiche Zweispalten-Gestaltung wie SpsExportTab: links Datei + Spaltenzuordnung
// (Auto-Erkennung über die Spaltentitel), rechts Optionen, Live-Prüfung
// (Trockenlauf, schreibt nichts) und Importieren. Fehlerhafte Zeilen werden
// gemeldet und übersprungen, der Rest läuft in einer Transaktion.
Item {
    id: root

    required property var theme
    property int projektId: -1

    // bericht: Ergebnis von spsImportAusfuehren (u.a. racksNeu/racksBetroffen)
    signal importiert(var bericht)

    // ── Zustand ──
    property string _pfad: ""
    property string _lesefehler: ""
    property var    _kopf: []
    property int    _datenzeilen: 0
    property var    _bericht: ({})
    property var    _feldOptionen: []   // [{feld, text}] importierbare Felder
    property int    _pruefAnsicht: 0    // 0 = Kanäle (Vorschau), 1 = Hinweise/Fehler
    property bool   _skipZeigen: false  // unveränderte/übersprungene Kanäle in der Vorschau

    ListModel { id: zuordnung }         // spalte (Titel), beispiel, feld

    readonly property var _modusOptionen: [
        { text: qsTr("Nur leere Felder auffüllen (Standard)"), wert: "auffuellen" },
        { text: qsTr("Vorhandene Kanäle überspringen"),         wert: "ueberspringen" },
        { text: qsTr("Felder aus der CSV überschreiben"),       wert: "ueberschreiben" }
    ]
    readonly property var _systemOptionen: [
        { text: qsTr("PLS (Rack / Slot / Kanal)"), wert: "PLS" },
        { text: qsTr("SPS (Byte / Bit-Adressen)"), wert: "SPS" }
    ]

    function _pfadBereinigen(s) {
        s = String(s)
        if (s.startsWith("file:///")) return s.substring(7)
        if (s.startsWith("file://"))  return s.substring(7)
        return s
    }

    function _zuruecksetzen() {
        _pfad = ""; _lesefehler = ""; _kopf = []; _datenzeilen = 0; _bericht = ({})
        zuordnung.clear()
        pfadFeld.text = ""
    }

    function _felderLaden() {
        // importierbare Felder = Export-Katalog ohne reine Schaltplan-/Textfelder
        var kat = db.spsExportFeldKatalog()
        var o = [{ feld: "", text: qsTr("— ignorieren —") }]
        for (var i = 0; i < kat.length; i++) {
            var f = kat[i].feld
            if (kat[i].importierbar === false) continue
            o.push({ feld: f, text: kat[i].titel })
        }
        _feldOptionen = o
    }

    Component.onCompleted: _felderLaden()
    onProjektIdChanged: _zuruecksetzen()

    function _datei(pfad) {
        _pfad = _pfadBereinigen(pfad)
        pfadFeld.text = _pfad
        var r = db.spsImportLesen(_pfad)
        _lesefehler = r.fehler || ""
        zuordnung.clear()
        _kopf = []; _datenzeilen = 0; _bericht = ({})
        if (_lesefehler !== "") return
        _kopf = r.kopf
        _datenzeilen = r.zeilen
        var bsp = r.beispiel.length > 0 ? r.beispiel[0] : []
        for (var i = 0; i < r.kopf.length; i++)
            zuordnung.append({ spalte: r.kopf[i], beispiel: i < bsp.length ? bsp[i] : "",
                               feld: r.vorschlag[i] || "" })
        _pruefenPlanen()
    }

    function _konfigJson() {
        var sp = []
        for (var i = 0; i < zuordnung.count; i++) sp.push(zuordnung.get(i).feld)
        return JSON.stringify({
            spalten: sp,
            kopfzeile: true,
            dezimal: dezimalCombo.currentIndex === 0 ? "," : ".",
            systemStandard: _systemOptionen[systemCombo.currentIndex].wert,
            vorhandene: _modusOptionen[modusCombo.currentIndex].wert,
            hardwareAnlegen: hwCheck.checked
        })
    }

    function _pruefenPlanen() { pruefTimer.restart() }

    function _pruefen() {
        if (_pfad === "" || zuordnung.count === 0) { _bericht = ({}); return }
        _bericht = db.spsImportPruefen(root.projektId, _pfad, _konfigJson())
    }

    function _importieren() {
        var b = db.spsImportAusfuehren(root.projektId, root._pfad, root._konfigJson())
        if (b.ausgefuehrt) {
            var ort = ""
            if ((b.racksNeu || []).length > 0)
                ort = qsTr(" – neu: Rack %1").arg(b.racksNeu.join(", "))
            else if ((b.racksBetroffen || []).length > 0)
                ort = qsTr(" – Rack %1").arg(b.racksBetroffen.join(", "))
            meldungManager.zeigen(qsTr("Import abgeschlossen: %1 neue Kanäle, %2 aktualisiert")
                                  .arg(b.neueKanaele).arg(b.aktualisiert) + ort, true)
            root._zuruecksetzen()
            root.importiert(b)
        } else {
            root._bericht = b
        }
    }

    readonly property bool _kannImportieren:
        _pfad !== "" && _lesefehler === "" && (_bericht.fehler === undefined || _bericht.fehler === "")
        && ((_bericht.neueKanaele || 0) + (_bericht.aktualisiert || 0)) > 0

    Timer { id: pruefTimer; interval: 200; onTriggered: root._pruefen() }

    FileDialog {
        id: dateiDialog
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("CSV-Dateien (*.csv *.txt)"), qsTr("Alle Dateien (*)")]
        onAccepted: root._datei(selectedFile)
    }

    // Theme wird explizit durchgereicht (Inline-Komponenten sehen die ids der Datei nicht zuverlässig).
    component KnopfText: Text {
        required property var thm
        color: thm.textMuted; font.pixelSize: 11
    }

    component KonfigCombo: ComboBox {
        required property var thm
        property var optionen: []
        signal geaendert()
        model: optionen.map(function(o) { return o.text })
        Layout.fillWidth: true
        implicitHeight: 30
        background: Rectangle { color: thm.inputBg; border.color: thm.border; radius: 4 }
        contentItem: Text {
            text: parent.displayText; color: thm.textPrimary; font.pixelSize: 12
            leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        onActivated: geaendert()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        // ── Links: Datei + Spaltenzuordnung ──────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 8

            Text { text: qsTr("CSV-Datei"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                TextField {
                    id: pfadFeld
                    Layout.fillWidth: true
                    implicitHeight: 30
                    placeholderText: qsTr("/pfad/zur/datei.csv")
                    color: root.theme.textPrimary
                    font.pixelSize: 12
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    onAccepted: if (text.trim() !== "") root._datei(text.trim())
                }
                Button {
                    text: qsTr("Durchsuchen …"); implicitHeight: 30
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                    onClicked: dateiDialog.open()
                }
                Button {
                    text: qsTr("Laden"); implicitHeight: 30
                    enabled: pfadFeld.text.trim() !== ""
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled && parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                    onClicked: root._datei(pfadFeld.text.trim())
                }
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: root._lesefehler !== "" ? "#cc6666" : root.theme.textMuted
                text: root._lesefehler !== "" ? root._lesefehler
                      : root._kopf.length > 0
                        ? qsTr("%1 Datenzeile(n), %2 Spalte(n). Spaltentitel wurden – soweit erkennbar – automatisch zugeordnet.")
                              .arg(root._datenzeilen).arg(root._kopf.length)
                        : qsTr("Bestandsliste als CSV wählen (Trennzeichen und Kodierung werden erkannt).")
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Text { text: qsTr("Spaltenzuordnung"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                Text {
                    visible: zuordnung.count > 0
                    text: qsTr("CSV-Spalte · Beispielwert · Zielfeld")
                    color: root.theme.textMuted; font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.theme.surface
                border.color: root.theme.border
                radius: 4

                Text {
                    anchors.centerIn: parent
                    visible: zuordnung.count === 0
                    text: qsTr("Noch keine Datei geladen")
                    color: root.theme.textMuted; font.pixelSize: 12
                }

                ListView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    model: zuordnung
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        id: zeile
                        required property int index
                        required property string spalte
                        required property string beispiel
                        required property string feld
                        width: ListView.view.width
                        height: 34
                        color: index % 2 ? root.theme.surface : root.theme.surfaceDeep

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            Text {
                                text: zeile.spalte
                                color: root.theme.textPrimary; font.pixelSize: 12; font.bold: true
                                elide: Text.ElideRight
                                Layout.preferredWidth: 150
                            }
                            Text {
                                text: zeile.beispiel
                                color: root.theme.textMuted; font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            ComboBox {
                                Layout.preferredWidth: 190
                                implicitHeight: 26
                                model: root._feldOptionen.map(function(o) { return o.text })
                                currentIndex: {
                                    for (var i = 0; i < root._feldOptionen.length; i++)
                                        if (root._feldOptionen[i].feld === zeile.feld) return i
                                    return 0
                                }
                                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                                contentItem: Text {
                                    text: parent.displayText; font.pixelSize: 12
                                    color: zeile.feld === "" ? root.theme.textMuted : root.theme.textPrimary
                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                }
                                onActivated: function(i) {
                                    zuordnung.setProperty(zeile.index, "feld", root._feldOptionen[i].feld)
                                    root._pruefenPlanen()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Rechts: Optionen, Prüfung, Importieren ───────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 8

            Text { text: qsTr("Optionen"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13 }

            GridLayout {
                columns: 2
                columnSpacing: 10
                rowSpacing: 6
                Layout.fillWidth: true

                KnopfText { thm: root.theme; text: qsTr("System, wenn nicht erkennbar") }
                KonfigCombo {
                    id: systemCombo; thm: root.theme
                    optionen: root._systemOptionen
                    onGeaendert: root._pruefenPlanen()
                }

                KnopfText { thm: root.theme; text: qsTr("Vorhandene Kanäle") }
                KonfigCombo {
                    id: modusCombo; thm: root.theme
                    optionen: root._modusOptionen
                    onGeaendert: root._pruefenPlanen()
                }

                KnopfText { thm: root.theme; text: qsTr("Dezimalzeichen in der CSV") }
                KonfigCombo {
                    id: dezimalCombo; thm: root.theme
                    optionen: [{ text: qsTr("Komma ( 12,5 )"), wert: "," }, { text: qsTr("Punkt ( 12.5 )"), wert: "." }]
                    onGeaendert: root._pruefenPlanen()
                }

                KnopfText { thm: root.theme; text: "" }
                CheckBox {
                    id: hwCheck
                    text: qsTr("Fehlende Racks/Baugruppen anlegen")
                    checked: true
                    onToggled: root._pruefenPlanen()
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Text { text: qsTr("Prüfung"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                Text {
                    visible: root._bericht.neueKanaele !== undefined
                    text: qsTr("Trockenlauf – schreibt nichts")
                    color: root.theme.textMuted; font.pixelSize: 11
                }
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                color: (root._bericht.fehler || "") !== "" ? "#cc6666" : root.theme.textPrimary
                text: {
                    var b = root._bericht
                    if ((b.fehler || "") !== "") return b.fehler
                    if (b.neueKanaele === undefined)
                        return qsTr("Nach dem Laden einer Datei erscheint hier, was der Import tun würde.")
                    var t = qsTr("%1 neue Kanäle · %2 aktualisiert · %3 unverändert/übersprungen")
                                .arg(b.neueKanaele).arg(b.aktualisiert).arg(b.uebersprungen)
                    if ((b.abweichend || 0) > 0)
                        t += "\n" + qsTr("%1 Kanal/Kanäle weichen von der CSV ab, werden aber nicht überschrieben – Option „Felder aus der CSV überschreiben“ wählen, um sie zu übernehmen.").arg(b.abweichend)
                    if (b.neueRacks > 0 || b.neueBaugruppen > 0)
                        t += qsTr(" · neu angelegt: %1 Rack(s), %2 Baugruppe(n)").arg(b.neueRacks).arg(b.neueBaugruppen)
                    if (b.fehlerhaft > 0)
                        t += "\n" + qsTr("%1 fehlerhafte Zeile(n) werden NICHT importiert (siehe Liste).").arg(b.fehlerhaft)
                    return t
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                readonly property int nMeld: (root._bericht.meldungen || []).length
                Repeater {
                    model: [
                        { text: qsTr("Kanäle (%1)").arg((root._bericht.kanalVorschau || []).length), idx: 0 },
                        { text: qsTr("Hinweise / Fehler (%1)").arg(parent.nMeld), idx: 1 }
                    ]
                    delegate: Button {
                        required property var modelData
                        readonly property bool aktiv: root._pruefAnsicht === modelData.idx
                        text: modelData.text
                        implicitHeight: 28
                        implicitWidth: 170
                        contentItem: Text { text: parent.text; font.pixelSize: 12
                            color: parent.aktiv ? "#ffffff" : root.theme.textPrimary
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle {
                            color: parent.aktiv ? root.theme.accent : (parent.hovered ? root.theme.inputBg : "transparent")
                            border.color: parent.aktiv ? root.theme.accent : root.theme.border
                            radius: 4 }
                        onClicked: root._pruefAnsicht = modelData.idx
                    }
                }
                Item { Layout.fillWidth: true }
                CheckBox {
                    visible: root._pruefAnsicht === 0
                    text: qsTr("Unveränderte anzeigen")
                    checked: root._skipZeigen
                    onToggled: root._skipZeigen = checked
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 11
                        leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.theme.inputBg
                border.color: root.theme.border
                radius: 4

                // Kanal-Vorschau (nach Aktion gefiltert)
                readonly property var kanalListe: {
                    var l = root._bericht.kanalVorschau || []
                    if (root._skipZeigen) return l
                    var r = []
                    for (var i = 0; i < l.length; i++) if (l[i].aktion !== "skip") r.push(l[i])
                    return r
                }

                Text {
                    anchors.centerIn: parent
                    visible: root._pruefAnsicht === 1 ? (root._bericht.meldungen || []).length === 0
                                                      : parent.kanalListe.length === 0
                    text: {
                        if (root._bericht.neueKanaele === undefined) return ""
                        if (root._pruefAnsicht === 1) return qsTr("Keine Hinweise oder Fehler")
                        return qsTr("Keine neuen oder geänderten Kanäle")
                    }
                    color: root.theme.textMuted; font.pixelSize: 12
                }

                ListView {
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: root._pruefAnsicht === 0
                    clip: true
                    spacing: 2
                    model: parent.kanalListe
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Text {
                        required property var modelData
                        width: ListView.view.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: modelData.aktion === "neu" ? "#4caf50"
                             : modelData.aktion === "update" ? "#e0a800"
                             : modelData.aktion === "abweichung" ? "#e07a00" : root.theme.textMuted
                        text: qsTr("Zeile %1: ").arg(modelData.zeile)
                              + (modelData.aktion === "neu" ? qsTr("NEU  ")
                                 : modelData.aktion === "update" ? qsTr("ÄNDERN  ")
                                 : modelData.aktion === "abweichung" ? qsTr("ABWEICHUNG  ") : qsTr("ÜBERSPRUNGEN  "))
                              + modelData.adresse
                              + (modelData.variable !== "" ? "  ·  " + modelData.variable : "")
                              + (modelData.detail !== "" ? "  –  " + modelData.detail : "")
                    }
                }

                ListView {
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: root._pruefAnsicht === 1
                    clip: true
                    spacing: 2
                    model: root._bericht.meldungen || []
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Text {
                        required property var modelData
                        width: ListView.view.width
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: modelData.fehler ? "#cc6666" : "#e0a800"
                        text: (modelData.zeile > 0 ? qsTr("Zeile %1: ").arg(modelData.zeile) : "") + modelData.text
                    }
                }
            }

            Button {
                text: qsTr("Importieren")
                Layout.alignment: Qt.AlignRight
                implicitHeight: 34
                implicitWidth: 200
                enabled: root._kannImportieren
                contentItem: Text { text: parent.text; font.pixelSize: 13
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                onClicked: root._importieren()
            }
        }
    }
}
