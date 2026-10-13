import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../la"

// SPS-EXPORT-02: frei konfigurierbarer CSV-Export der SPS/PLS-Adressliste.
// Der Anwender stellt Spalten (Auswahl, Reihenfolge, Titel, feste Textspalten),
// Format und Filter selbst zusammen und kann das als Vorlage speichern.
// Vorlagen sind global (App-Einstellungen, nicht in der Projektdatei) – so lässt
// sich ein Zielformat (Leitsystem-Import, Excel-Vorlage) einmal bauen und in
// jedem Projekt wiederverwenden. Die Datenaufbereitung selbst liegt in C++
// (Database_SpsExport.cpp); diese Datei ist nur Konfigurations-Oberfläche.
// SPS-EXPORT-04: Neben dem Standard-Schema kann jede Signalart (DI/DO/AI/AO) ein
// eigenes Spaltenschema haben; Signalarten ohne eigenes Schema nutzen den Standard.
Item {
    id: root

    required property var theme
    property int   projektId: -1
    property var   racks: []         // db.spsRackListe(...) – für den Rack-Filter
    property int   kanalAnzahl: 0
    property string projektName: ""

    // ── Globale Ablage (Vorlagen + zuletzt bearbeiteter Stand) ───
    Settings {
        id: einst
        category: "sps_export"
        property string vorlagen: "[]"   // JSON: [{name, konfig}]
        property string zuletzt:  ""     // JSON der zuletzt bearbeiteten Konfiguration
    }

    ListModel { id: spaltenModel }       // feld, titel, standardTitel, gruppe, aktiv, wert

    property var  _vorlagen: []
    property bool _laedt: false
    property string _vorschauText: ""
    property string _vorschauFehler: ""
    property int    _vorschauZeilen: 0
    property int    _aktiveSpalten: 0

    // Schemata: Schlüssel → Spaltenliste [{feld,titel,standardTitel,gruppe,aktiv,wert}].
    // "Standard" ist immer vorhanden. Das gerade bearbeitete Schema liegt live in
    // spaltenModel (Stand hier erst nach _schemataAktuell()/_schemaWechseln()).
    // Nur per Neuzuweisung ändern, sonst feuern die Bindings nicht.
    property string _schema: "Standard"
    property var    _schemata: ({})
    property var    _gruppen: []          // Ergebnis der Vorschau: [{schema, zeilen, text}]
    readonly property bool _schemaEigen: _schemata[_schema] !== undefined
    readonly property var  _schemaSchluessel: ["Standard", "DI", "DO", "AI", "AO"]

    readonly property var _trennOptionen: [
        { text: qsTr("Semikolon ( ; )"),   wert: ";" },
        { text: qsTr("Komma ( , )"),       wert: "," },
        { text: qsTr("Tabulator"),         wert: "\t" },
        { text: qsTr("Senkrechter Strich ( | )"), wert: "|" }
    ]
    readonly property var _dezimalOptionen: [
        { text: qsTr("Komma ( 12,5 )"),  wert: "," },
        { text: qsTr("Punkt ( 12.5 )"),  wert: "." }
    ]
    readonly property var _ausgabeOptionen: [
        { text: qsTr("Eine Datei je Schema (…_AI.csv)"), wert: "einzeln" },
        { text: qsTr("Eine Datei mit Abschnitten"),     wert: "eine_datei" }
    ]
    readonly property var _anfuehrungOptionen: [
        { text: qsTr("Immer"),            wert: "immer" },
        { text: qsTr("Nur bei Bedarf"),   wert: "bei_bedarf" }
    ]
    readonly property var _signalOptionen: [
        { text: qsTr("alle Signale"), wert: "" },
        { text: "DI", wert: "DI" }, { text: "DO", wert: "DO" },
        { text: "AI", wert: "AI" }, { text: "AO", wert: "AO" }
    ]
    readonly property var _systemOptionen: [
        { text: qsTr("SPS und PLS"), wert: "" },
        { text: "SPS", wert: "SPS" }, { text: "PLS", wert: "PLS" }
    ]
    readonly property var _belegungOptionen: [
        { text: qsTr("alle Kanäle"),            wert: "alle" },
        { text: qsTr("nur mit Element"),        wert: "mit_element" },
        { text: qsTr("nur ohne Element"),       wert: "ohne_element" }
    ]
    readonly property var _rackOptionen: {
        var o = [{ text: qsTr("alle Racks"), wert: "" }]
        for (var i = 0; i < racks.length; i++)
            o.push({ text: "R" + racks[i].rack_nr + " – " + (racks[i].bezeichnung || "") + " [" + racks[i].system_typ + "]",
                     wert: String(racks[i].rack_nr) })
        return o
    }

    function _idx(optionen, wert) {
        for (var i = 0; i < optionen.length; i++) if (optionen[i].wert === wert) return i
        return 0
    }

    // ── Konfiguration ⇄ Oberfläche ───────────────────────────────
    function _modellAlsListe() {
        var a = []
        for (var i = 0; i < spaltenModel.count; i++) {
            var m = spaltenModel.get(i)
            a.push({ feld: m.feld, titel: m.titel, standardTitel: m.standardTitel,
                     gruppe: m.gruppe, aktiv: m.aktiv, wert: m.wert })
        }
        return a
    }

    function _modellFuellen(liste) {
        spaltenModel.clear()
        for (var i = 0; i < liste.length; i++) spaltenModel.append(liste[i])
    }

    // Kopie aller Schemata inkl. des live bearbeiteten Stands
    function _schemataAktuell() {
        var n = Object.assign({}, _schemata)
        if (n[_schema] !== undefined) n[_schema] = _modellAlsListe()
        return n
    }

    function _spaltenExport(liste) {
        var sp = []
        for (var i = 0; i < liste.length; i++) {
            var m = liste[i]
            if (!m.aktiv) continue
            var o = { feld: m.feld, titel: m.titel }
            if (m.feld === "fest") o.wert = m.wert
            sp.push(o)
        }
        return sp
    }

    function _konfigObjekt() {
        var sch = _schemataAktuell()
        var eigene = {}
        for (var key in sch)
            if (key !== "Standard") eigene[key] = { spalten: _spaltenExport(sch[key]) }
        return {
            spalten:      _spaltenExport(sch["Standard"] || []),
            schemata:     eigene,
            ausgabe:      _ausgabeOptionen[ausgabeCombo.currentIndex].wert,
            trennzeichen: _trennOptionen[trennCombo.currentIndex].wert,
            dezimal:      _dezimalOptionen[dezimalCombo.currentIndex].wert,
            kopfzeile:    kopfCheck.checked,
            bom:          bomCheck.checked,
            anfuehrung:   _anfuehrungOptionen[anfuehrungCombo.currentIndex].wert,
            filter: {
                system:   _systemOptionen[systemCombo.currentIndex].wert,
                rack:     _rackOptionen[rackCombo.currentIndex].wert,
                signal:   _signalOptionen[signalCombo.currentIndex].wert,
                belegung: _belegungOptionen[belegungCombo.currentIndex].wert
            }
        }
    }

    // Spaltenliste aus Konfig-Spalten: gewählte zuerst (in Reihenfolge), dann die übrigen Katalogfelder
    function _listeAusSpalten(sp, kat) {
        var katMap = {}
        for (var c = 0; c < kat.length; c++) katMap[kat[c].feld] = kat[c]
        var liste = []
        var benutzt = {}
        var festVorhanden = false
        for (var i = 0; i < sp.length; i++) {
            var d = katMap[sp[i].feld]
            if (!d) continue
            liste.push({ feld: d.feld,
                         titel: sp[i].titel !== undefined ? sp[i].titel : d.titel,
                         standardTitel: d.titel, gruppe: d.gruppe, aktiv: true,
                         wert: sp[i].wert || "" })
            if (d.feld === "fest") festVorhanden = true
            else benutzt[d.feld] = true
        }
        for (var j = 0; j < kat.length; j++) {
            var e = kat[j]
            if (benutzt[e.feld]) continue
            if (e.feld === "fest" && festVorhanden) continue
            liste.push({ feld: e.feld, titel: e.titel, standardTitel: e.titel,
                         gruppe: e.gruppe, aktiv: false, wert: "" })
        }
        return liste
    }

    function _konfigLaden(k) {
        _laedt = true
        var kat = db.spsExportFeldKatalog()
        var n = {}
        n["Standard"] = _listeAusSpalten(k.spalten || [], kat)
        var sc = k.schemata || {}
        for (var key in sc) {
            if (key === "Standard") continue
            n[key] = _listeAusSpalten((sc[key] && sc[key].spalten) || [], kat)
        }
        _schemata = n
        _schema = "Standard"
        _modellFuellen(n["Standard"])

        trennCombo.currentIndex     = _idx(_trennOptionen, k.trennzeichen !== undefined ? k.trennzeichen : ";")
        dezimalCombo.currentIndex   = _idx(_dezimalOptionen, k.dezimal !== undefined ? k.dezimal : ",")
        ausgabeCombo.currentIndex   = _idx(_ausgabeOptionen, k.ausgabe || "einzeln")
        kopfCheck.checked           = k.kopfzeile !== false
        bomCheck.checked            = k.bom !== false
        anfuehrungCombo.currentIndex = _idx(_anfuehrungOptionen, k.anfuehrung || "immer")
        var f = k.filter || {}
        systemCombo.currentIndex    = _idx(_systemOptionen, f.system || "")
        rackCombo.currentIndex      = _idx(_rackOptionen, f.rack || "")
        signalCombo.currentIndex    = _idx(_signalOptionen, f.signal || "")
        belegungCombo.currentIndex  = _idx(_belegungOptionen, f.belegung || "alle")
        _laedt = false
        _geaendert()
    }

    function _standardLaden() {
        _konfigLaden(JSON.parse(db.spsExportStandardKonfig()))
    }

    // ── Schema-Auswahl ───────────────────────────────────────────
    function _schemaWechseln(key) {
        if (key === _schema) return
        _laedt = true
        _schemata = _schemataAktuell()     // live-Stand des bisherigen Schemas sichern
        _schema = key
        if (_schemata[key] !== undefined) _modellFuellen(_schemata[key])
        else spaltenModel.clear()
        _laedt = false
    }

    // Eigenes Schema = Kopie des Standards ohne die für die Signalart irrelevanten Felder
    function _eigenesSchemaAnlegen() {
        var irr = db.spsExportSchemaIrrelevanteFelder(_schema)
        var std = _schemata["Standard"] || []
        var arr = []
        for (var i = 0; i < std.length; i++) {
            var m = Object.assign({}, std[i])
            if (m.aktiv && irr.indexOf(m.feld) >= 0) m.aktiv = false
            arr.push(m)
        }
        var n = Object.assign({}, _schemata)
        n[_schema] = arr
        _laedt = true
        _schemata = n
        _modellFuellen(arr)
        _laedt = false
        _geaendert()
    }

    function _schemaVerwerfen() {
        var n = Object.assign({}, _schemata)
        delete n[_schema]
        _schemata = n
        spaltenModel.clear()
        _geaendert()
    }

    // Hinweis für die Erfolgsmeldung: bei mehreren Dateien die Schema-Suffixe nennen
    function _csvErfolgText() {
        var einzeln = _ausgabeOptionen[ausgabeCombo.currentIndex].wert === "einzeln"
        if (!einzeln || _gruppen.length < 2) return qsTr("I/O-Liste exportiert.")
        var teile = _gruppen.map(function(g) { return "_" + g.schema })
        return qsTr("I/O-Liste exportiert: %1 Dateien (%2).").arg(_gruppen.length).arg(teile.join(", "))
    }

    function _geaendert() {
        if (_laedt) return
        aktualisierTimer.restart()
    }

    function _vorschauAktualisieren() {
        if (root.projektId < 0) { _vorschauText = ""; _vorschauFehler = ""; _vorschauZeilen = 0; return }
        var json = JSON.stringify(_konfigObjekt())
        var v = db.spsExportVorschau(root.projektId, json, 8)
        var gruppen = v.gruppen || []
        var t = ""
        if (gruppen.length > 1) {
            for (var gi = 0; gi < gruppen.length; gi++)
                t += "── " + gruppen[gi].schema + " · " + qsTr("%1 Zeile(n)").arg(gruppen[gi].zeilen)
                     + " ──\n" + gruppen[gi].text + "\n"
        } else {
            t = v.text || ""
        }
        _gruppen        = gruppen
        _vorschauText   = t
        _vorschauFehler = v.fehler || ""
        _vorschauZeilen = v.zeilen || 0
        var kfg = _konfigObjekt()
        var maxSp = kfg.spalten.length
        for (var sk in kfg.schemata) maxSp = Math.max(maxSp, kfg.schemata[sk].spalten.length)
        _aktiveSpalten  = maxSp
        einst.zuletzt = json
    }

    function _vorlagenSpeichern() { einst.vorlagen = JSON.stringify(_vorlagen) }

    function _vorlageSpeichern(name) {
        var konfig = _konfigObjekt()
        var neu = _vorlagen.slice()
        var gefunden = -1
        for (var i = 0; i < neu.length; i++) if (neu[i].name === name) gefunden = i
        if (gefunden >= 0) neu[gefunden] = { name: name, konfig: konfig }
        else neu.push({ name: name, konfig: konfig })
        _vorlagen = neu
        _vorlagenSpeichern()
        vorlageCombo.currentIndex = _idxVorlage(name)
        meldungManager.zeigen(qsTr("Vorlage \"%1\" gespeichert").arg(name), true)
    }

    function _idxVorlage(name) {
        for (var i = 0; i < _vorlagen.length; i++) if (_vorlagen[i].name === name) return i + 1
        return 0
    }

    function _vorlageLoeschen() {
        var i = vorlageCombo.currentIndex - 1
        if (i < 0 || i >= _vorlagen.length) return
        var neu = _vorlagen.slice()
        neu.splice(i, 1)
        _vorlagen = neu
        _vorlagenSpeichern()
        vorlageCombo.currentIndex = 0
    }

    Timer {
        id: aktualisierTimer
        interval: 150
        onTriggered: root._vorschauAktualisieren()
    }

    onProjektIdChanged: _geaendert()
    onKanalAnzahlChanged: _geaendert()

    Component.onCompleted: {
        try { _vorlagen = JSON.parse(einst.vorlagen) || [] } catch (e) { _vorlagen = [] }
        var start = null
        if (einst.zuletzt) { try { start = JSON.parse(einst.zuletzt) } catch (e2) { start = null } }
        if (start && start.spalten && start.spalten.length > 0) _konfigLaden(start)
        else _standardLaden()
    }

    // ── Hilfskomponente: einheitlich gestaltete ComboBox ─────────
    // Theme wird explizit durchgereicht (Inline-Komponenten sehen die ids der
    // umgebenden Datei nicht zuverlässig).
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

    component KnopfLabel: Text {
        required property var thm
        color: thm.textMuted; font.pixelSize: 11
    }

    // ── Dialoge ──────────────────────────────────────────────────
    LaPdfExportDialog {
        id: exportDialog
        theme: root.theme
        dateiname: "io_liste.csv"
        dateiEndung: ".csv"
        titelText: qsTr("I/O-Liste als CSV exportieren")
        speichernTitel: qsTr("CSV speichern unter")
        erfolgText: qsTr("I/O-Liste exportiert.")
        onExportAngefordert: function(pfad) {
            exportDialog.erfolgText = root._csvErfolgText()
            var ok = db.spsExportCsvSpeichern(root.projektId, pfad, JSON.stringify(root._konfigObjekt()))
            exportDialog.erfolgReagieren(ok)
        }
    }

    LaPdfExportDialog {
        id: pdfDialog
        theme: root.theme
        dateiname: "io_liste.pdf"
        titelText: qsTr("I/O-Liste als PDF exportieren")
        onExportAngefordert: function(pfad) {
            var ok = db.spsExportPdfSpeichern(root.projektId, root.projektName, pfad,
                                              JSON.stringify(root._konfigObjekt()))
            pdfDialog.erfolgReagieren(ok)
        }
    }

    Dialog {
        id: nameDialog
        title: qsTr("Vorlage speichern")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }
        onOpened: {
            var i = vorlageCombo.currentIndex - 1
            nameFeld.text = (i >= 0 && i < root._vorlagen.length) ? root._vorlagen[i].name : ""
            nameFeld.forceActiveFocus()
        }
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                text: qsTr("Name der Vorlage (vorhandener Name wird überschrieben):")
                color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            TextField {
                id: nameFeld
                Layout.fillWidth: true
                color: root.theme.textPrimary
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onAccepted: okKnopf.clicked()
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Button {
                    text: qsTr("Abbrechen"); Layout.fillWidth: true; implicitHeight: 32
                    contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                    onClicked: nameDialog.close()
                }
                Button {
                    id: okKnopf
                    text: qsTr("Speichern"); Layout.fillWidth: true; implicitHeight: 32
                    enabled: nameFeld.text.trim().length > 0
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                    onClicked: {
                        if (!enabled) return
                        root._vorlageSpeichern(nameFeld.text.trim())
                        nameDialog.close()
                    }
                }
            }
        }
    }

    // ── Layout ───────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        // ── Links: Vorlage + Spalten ─────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 8

            Text { text: qsTr("Vorlage"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                ComboBox {
                    id: vorlageCombo
                    Layout.fillWidth: true
                    implicitHeight: 30
                    model: [qsTr("(Standard)")].concat(root._vorlagen.map(function(v) { return v.name }))
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text {
                        text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                        leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                    }
                    onActivated: function(i) {
                        if (i === 0) root._standardLaden()
                        else root._konfigLaden(root._vorlagen[i - 1].konfig)
                    }
                }
                Button {
                    text: qsTr("Speichern unter …"); implicitHeight: 30
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius: 4; border.color: root.theme.accent }
                    onClicked: nameDialog.open()
                }
                Button {
                    text: qsTr("Löschen"); implicitHeight: 30
                    enabled: vorlageCombo.currentIndex > 0
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textSecondary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered && parent.enabled ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                    onClicked: root._vorlageLoeschen()
                }
            }

            // ── Schema (Signalart) ───────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Text { text: qsTr("Schema"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                Text {
                    text: qsTr("Signalarten ohne eigenes Schema nutzen das Standard-Schema")
                    color: root.theme.textMuted; font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root._schemaSchluessel
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool aktiv: root._schema === modelData
                        readonly property bool eigen: modelData === "Standard" || root._schemata[modelData] !== undefined
                        implicitWidth: 64
                        implicitHeight: 28
                        radius: 14
                        color: aktiv ? root.theme.accent : (chipMa.containsMouse ? root.theme.hover : root.theme.inputBg)
                        border.color: eigen ? root.theme.accent : root.theme.border
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: chip.modelData
                            font.pixelSize: 12
                            font.bold: chip.eigen
                            color: chip.aktiv || chip.eigen ? root.theme.textPrimary : root.theme.textMuted
                        }
                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._schemaWechseln(chip.modelData)
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 400
                            ToolTip.text: chip.modelData === "Standard"
                                          ? qsTr("Standard-Schema – gilt für alle Signalarten ohne eigenes Schema")
                                          : (chip.eigen ? qsTr("%1 hat ein eigenes Schema").arg(chip.modelData)
                                                        : qsTr("%1 nutzt das Standard-Schema").arg(chip.modelData))
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            RowLayout {
                visible: root._schema !== "Standard"
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: root.theme.textSecondary
                    font.pixelSize: 12
                    text: root._schemaEigen
                          ? qsTr("Eigenes Schema für %1").arg(root._schema)
                          : qsTr("%1 nutzt das Standard-Schema.").arg(root._schema)
                }
                Button {
                    text: root._schemaEigen ? qsTr("Zurück zum Standard") : qsTr("Eigenes Schema anlegen")
                    implicitHeight: 28
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? (root._schemaEigen ? root.theme.hover : root.theme.accent) : root.theme.inputBg
                        radius: 4; border.color: root._schemaEigen ? root.theme.border : root.theme.accent }
                    ToolTip.visible: hovered
                    ToolTip.delay: 400
                    ToolTip.text: root._schemaEigen
                                  ? qsTr("Eigenes Schema verwerfen – %1 nutzt wieder das Standard-Schema").arg(root._schema)
                                  : qsTr("Kopiert die Standard-Spalten ohne die für %1 unpassenden Felder (z.B. Alarmgrenzen) – danach frei änderbar").arg(root._schema)
                    onClicked: root._schemaEigen ? root._schemaVerwerfen() : root._eigenesSchemaAnlegen()
                }
            }

            RowLayout {
                visible: root._schemaEigen
                Layout.fillWidth: true
                Layout.topMargin: 6
                Text { text: qsTr("Spalten"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                Text {
                    text: qsTr("Haken = exportieren · ▲▼ = Reihenfolge · Titel frei änderbar")
                    color: root.theme.textMuted; font.pixelSize: 11
                }
            }

            Item { visible: !root._schemaEigen; Layout.fillWidth: true; Layout.fillHeight: true }

            Rectangle {
                visible: root._schemaEigen
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.theme.surface
                border.color: root.theme.border
                radius: 4

                ListView {
                    id: spaltenListe
                    anchors.fill: parent
                    anchors.margins: 1
                    model: spaltenModel
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        id: zeile
                        required property int index
                        required property string feld
                        required property string titel
                        required property string standardTitel
                        required property string gruppe
                        required property bool aktiv
                        required property string wert

                        width: ListView.view.width
                        height: 34
                        color: index % 2 ? root.theme.surface : root.theme.surfaceDeep
                        opacity: aktiv ? 1.0 : 0.6

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 4

                            CheckBox {
                                checked: zeile.aktiv
                                onToggled: {
                                    spaltenModel.setProperty(zeile.index, "aktiv", checked)
                                    root._geaendert()
                                }
                            }
                            ToolButton {
                                text: "▲"
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                enabled: zeile.index > 0
                                onClicked: { spaltenModel.move(zeile.index, zeile.index - 1, 1); root._geaendert() }
                            }
                            ToolButton {
                                text: "▼"
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                enabled: zeile.index < spaltenModel.count - 1
                                onClicked: { spaltenModel.move(zeile.index, zeile.index + 1, 1); root._geaendert() }
                            }
                            Text {
                                text: zeile.feld === "fest" ? qsTr("Fester Text") : zeile.standardTitel
                                color: root.theme.textPrimary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.preferredWidth: 130
                                ToolTip.visible: _lblMa.containsMouse
                                ToolTip.text: zeile.gruppe
                                ToolTip.delay: 400
                                MouseArea { id: _lblMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            }
                            TextField {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                text: zeile.titel
                                placeholderText: qsTr("Spaltentitel")
                                color: root.theme.textPrimary
                                font.pixelSize: 12
                                background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                onTextEdited: { spaltenModel.setProperty(zeile.index, "titel", text); root._geaendert() }
                            }
                            TextField {
                                visible: zeile.feld === "fest"
                                Layout.preferredWidth: 110
                                implicitHeight: 26
                                text: zeile.wert
                                placeholderText: qsTr("Wert")
                                color: root.theme.textPrimary
                                font.pixelSize: 12
                                background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.accent }
                                onTextEdited: { spaltenModel.setProperty(zeile.index, "wert", text); root._geaendert() }
                            }
                            ToolButton {
                                visible: zeile.feld === "fest"
                                text: "✕"
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                onClicked: { spaltenModel.remove(zeile.index); root._geaendert() }
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Textspalte entfernen")
                            }
                        }
                    }
                }
            }

            Button {
                visible: root._schemaEigen
                text: qsTr("＋ Feste Textspalte")
                implicitHeight: 28
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Spalte mit immer gleichem Inhalt (z.B. Stationsname) – für Import-Vorlagen")
                onClicked: {
                    spaltenModel.append({ feld: "fest", titel: qsTr("Text"), standardTitel: qsTr("Fester Text"),
                                          gruppe: "Sonstiges", aktiv: true, wert: "" })
                    root._geaendert()
                }
            }
        }

        // ── Rechts: Format, Filter, Vorschau, Export ─────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 8

            Text { text: qsTr("Format"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13 }

            GridLayout {
                columns: 2
                columnSpacing: 10
                rowSpacing: 6
                Layout.fillWidth: true

                KnopfLabel { thm: root.theme; text: qsTr("Ausgabe") }
                KonfigCombo { id: ausgabeCombo; thm: root.theme; optionen: root._ausgabeOptionen; onGeaendert: root._geaendert()
                    ToolTip.visible: hovered
                    ToolTip.delay: 400
                    ToolTip.text: qsTr("Gilt nur, wenn mehrere Schemata verwendet werden (CSV). Das PDF enthält immer eine Tabelle je Schema.") }

                KnopfLabel { thm: root.theme; text: qsTr("Trennzeichen") }
                KonfigCombo { id: trennCombo; thm: root.theme; optionen: root._trennOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Dezimalzeichen") }
                KonfigCombo { id: dezimalCombo; thm: root.theme; optionen: root._dezimalOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Anführungszeichen") }
                KonfigCombo { id: anfuehrungCombo; thm: root.theme; optionen: root._anfuehrungOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: "" }
                CheckBox {
                    id: kopfCheck
                    text: qsTr("Kopfzeile (Spaltentitel) ausgeben")
                    checked: true
                    onToggled: root._geaendert()
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
                }
                KnopfLabel { thm: root.theme; text: "" }
                CheckBox {
                    id: bomCheck
                    text: qsTr("UTF-8-BOM (für Excel)")
                    checked: true
                    onToggled: root._geaendert()
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
                }
            }

            Text { text: qsTr("Filter"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.topMargin: 6 }

            GridLayout {
                columns: 2
                columnSpacing: 10
                rowSpacing: 6
                Layout.fillWidth: true

                KnopfLabel { thm: root.theme; text: qsTr("System") }
                KonfigCombo { id: systemCombo; thm: root.theme; optionen: root._systemOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Rack") }
                KonfigCombo { id: rackCombo; thm: root.theme; optionen: root._rackOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Signal") }
                KonfigCombo { id: signalCombo; thm: root.theme; optionen: root._signalOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Belegung") }
                KonfigCombo { id: belegungCombo; thm: root.theme; optionen: root._belegungOptionen; onGeaendert: root._geaendert() }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Text { text: qsTr("Vorschau"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                Text {
                    text: root._vorschauFehler !== "" ? root._vorschauFehler
                          : qsTr("%1 Zeile(n) – Vorschau zeigt die ersten 8").arg(root._vorschauZeilen)
                    color: root._vorschauFehler !== "" ? "#cc6666" : root.theme.textMuted
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.theme.inputBg
                border.color: root.theme.border
                radius: 4

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    TextArea {
                        readOnly: true
                        text: root._vorschauText
                        wrapMode: TextArea.NoWrap
                        font.family: "monospace"
                        font.pixelSize: 11
                        color: root.theme.textPrimary
                        background: null
                        selectByMouse: true
                    }
                }
            }

            Text {
                visible: root._aktiveSpalten > 10
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#e0a800"
                font.pixelSize: 11
                text: qsTr("%1 Spalten ausgewählt – im PDF (A4 quer) wird es eng. Für das PDF besser eine Vorlage mit wenigen Spalten verwenden.").arg(root._aktiveSpalten)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Als PDF exportieren …")
                implicitHeight: 34
                implicitWidth: 200
                enabled: root.projektId >= 0 && root._vorschauFehler === "" && root._vorschauZeilen > 0
                contentItem: Text { text: parent.text; font.pixelSize: 13
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                onClicked: pdfDialog.open()
            }
            Button {
                text: qsTr("Als CSV exportieren …")
                implicitHeight: 34
                implicitWidth: 200
                enabled: root.projektId >= 0 && root._vorschauFehler === "" && root._vorschauZeilen > 0
                contentItem: Text { text: parent.text; font.pixelSize: 13
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                onClicked: exportDialog.open()
            }
            }
        }
    }
}
