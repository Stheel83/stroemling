import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "symboleditor"
import "symboleditor/SeGroesse.js" as SeGroesse
import "symboleditor/SeAuswahl.js" as SeAuswahl

// ============================================================
// SymbolEditorAnsicht – visueller Symboleditor (Phase D)
//
// Eigenschaften die vom Elternelement gesetzt werden müssen:
//   theme          – Theme-Objekt aus Main.qml
//   editSymbolId   – ID des zu bearbeitenden Symbols ("" = neues Symbol)
//
// Signals:
//   gespeichert(string symbolId) – nach erfolgreichem Speichern
//   abgebrochen()               – nach Abbrechen
// ============================================================

Item {
    id: root
    focus: true

    // ── Öffentliche Properties ─────────────────────────────────────
    property string editSymbolId: ""
    property var    theme
    property bool   debug: false

    signal gespeichert(string symbolId)
    signal abgebrochen()

    // ── Innerer Zustand ────────────────────────────────────────────
    property string nameText:      qsTr("Neues Symbol")
    property string kategorieText: ""
    property int    breiteMm:      32
    property int    hoeheMm:       16
    property string rolleText:     "durchleiter"
    // BMK-Label-Position (SYMBOL-BMKSEITE-EDITOR-01): "auto" (0°/180°→oben,
    // 90°/270°→seitlich) oder "vertikal" (umgekehrt — für Symbole deren
    // Grundausrichtung bei 0° bereits vertikal ist, z.B. Kontakte nach
    // SYMBOL-VERTIKAL-01). Siehe CanvasRenderHandler.qml maleElement().
    property string bmkSeiteText:  "auto"
    // NKZ-05: BMK-Kennbuchstaben-Vorschlaege (z.B. "M" fuer Motor) - mehrere
    // moeglich, da ein Symbol je nach Geraet unterschiedliche Buchstaben
    // tragen kann (Spule = Schuetz "K" oder Leistungsschalter "Q"). Ein
    // Eintrag als Standard markiert wird beim Platzieren automatisch
    // vorbelegt, die uebrigen erscheinen im EP als Umschalt-Chips.
    // Eintrag: {kennbuchstabe, istStandard}. Reine Klassifikations-Metadatur
    // ohne Geometriebezug - bewusst unabhaengig vom Builtin-Schreibschutz
    // speicherbar, siehe speichern().
    property var bmkKennbuchstaben: []

    function bmkBuchstabeHinzufuegen(text) {
        var kb = (text || "").trim().toUpperCase()
        if (kb === "") return
        for (var i = 0; i < bmkKennbuchstaben.length; i++)
            if (bmkKennbuchstaben[i].kennbuchstabe === kb) return  // schon vorhanden
        var liste = bmkKennbuchstaben.slice()
        liste.push({ kennbuchstabe: kb, istStandard: liste.length === 0 })
        bmkKennbuchstaben = liste
    }
    function bmkBuchstabeEntfernen(index) {
        var liste = bmkKennbuchstaben.slice()
        var warStandard = liste[index] && liste[index].istStandard
        liste.splice(index, 1)
        if (warStandard && liste.length > 0) liste[0] = Object.assign({}, liste[0], { istStandard: true })
        bmkKennbuchstaben = liste
    }
    function bmkStandardSetzen(index) {
        var liste = bmkKennbuchstaben.map(function(e, i) {
            return Object.assign({}, e, { istStandard: i === index })
        })
        bmkKennbuchstaben = liste
    }
    // Symbolweite Schriftgröße (mm) für Pin-Beschriftungen im Canvas/PDF-Export
    // (PIN-LABEL-SCHRIFTGROESSE-01) — eng bestückte Symbole (Arduino, SPS-
    // Baugruppen im 4mm-Raster) brauchen kleinere Schrift als Symbole mit
    // wenigen, weit auseinanderstehenden Pins.
    property real   pinSchriftMm:  2.0
    property bool   istBuiltin:    false
    property string vorlageId:     ""   // wenn gesetzt: Geometrie aus diesem Symbol als Vorlage laden
    property bool   _kopierModus:  false
    property real   _seZoom: 1.0
    property real   _sePanX: 0.0
    property real   _sePanY: 0.0
    // Vorschau-Drehung (SYMBOL-TEXT-LESBAR-01-Folge): rein visuelle Kontrolle im
    // Editor, ob Primitive/Text bei allen 4 Symbol-Rotationen + Spiegelungen noch
    // in die Box passen - ändert NICHT die gespeicherten Daten, nur die Anzeige.
    property int    _sePreviewRotation:  0       // 0 | 90 | 180 | 270
    property bool   _sePreviewSpiegelX:  false
    property bool   _sePreviewSpiegelY:  false

    property var    primitive:          []   // array of QVariantMap
    property var    pins:               []   // array of {name, x, y, offenX, offenY, signaltyp, kontext}
    // Snapshot-basiertes Undo (SE-UNDO-VOLLSTAENDIG-01): jeder Eintrag ist eine
    // Kopie von {primitive, pins} VOR der jeweiligen Änderung - deckt damit
    // auch Löschen/Verschieben ab, nicht nur Hinzufügen wie zuvor
    // (undoStack speicherte vorher nur {typ: "primitiv"|"pin"} und konnte
    // ausschließlich das zuletzt hinzugefügte Element entfernen).
    property var    undoStack:          []
    readonly property int _undoMax: 50

    // SE-UNGESPEICHERT-WARNUNG-01: true sobald sich primitive/pins/Stammdaten
    // seit dem letzten Laden/Speichern geändert haben - Grundlage für die
    // Rückfrage vor dem Verwerfen (verwerfenUndFortfahren()).
    property bool   _unsavedChanges:    false
    property var    _ausstehendeAktion: null
    onPrimitiveChanged:     _unsavedChanges = true
    onPinsChanged:          _unsavedChanges = true
    onNameTextChanged:      _unsavedChanges = true
    onKategorieTextChanged: _unsavedChanges = true
    onBreiteMmChanged:      _unsavedChanges = true
    onHoeheMmChanged:       _unsavedChanges = true
    onRolleTextChanged:     _unsavedChanges = true
    onBmkSeiteTextChanged:  _unsavedChanges = true
    onPinSchriftMmChanged:  _unsavedChanges = true
    onBmkKennbuchstabenChanged: _unsavedChanges = true

    // Führt aktion() sofort aus, wenn nichts Ungespeichertes vorliegt - sonst
    // erst nach Bestätigung im Dialog (verhindert stillschweigenden
    // Datenverlust beim Wechseln/Neuanlegen/Kopieren/Abbrechen während einer
    // laufenden Bearbeitung, s. Nutzerfeedback zum Symboleditor-Audit).
    function verwerfenUndFortfahren(aktion) {
        if (_unsavedChanges) {
            _ausstehendeAktion = aktion
            ungespeichertDialog.open()
        } else {
            aktion()
        }
    }

    property string aktivesWerkzeug:    "auswahl"
    property int    ausgewaehltPrimIdx: -1
    property int    ausgewaehltPinIdx:  -1
    // Mehrfachauswahl (SE-MEHRFACHAUSWAHL-01): Index-Listen, nur bei >= 2 Elementen gesetzt.
    // Bei genau einem Element gilt wie bisher ausgewaehltPrimIdx/ausgewaehltPinIdx.
    property var    multiPrim:          []
    property var    multiPins:          []
    property bool   _internAuswahl:     false
    readonly property int auswahlAnzahl: (multiPrim.length + multiPins.length > 1)
        ? multiPrim.length + multiPins.length
        : (ausgewaehltPrimIdx >= 0 ? 1 : 0) + (ausgewaehltPinIdx >= 0 ? 1 : 0)
    // Gummiband-Rahmen (Normkoordinaten, ungeclampt)
    property bool   _rbAktiv:           false
    property var    _rbA:               ({x: 0, y: 0})
    property var    _rbB:               ({x: 0, y: 0})
    property var    _rbBasisPrim:       []
    property var    _rbBasisPins:       []
    property bool   _pfeilUndoOffen:    false
    // Direkte Zuweisung von ausgewaehlt*Idx (Pin-Liste, Pin setzen …) beendet die Mehrfachauswahl
    onAusgewaehltPrimIdxChanged: if (!_internAuswahl && ausgewaehltPrimIdx >= 0) { multiPrim = []; multiPins = [] }
    onAusgewaehltPinIdxChanged:  if (!_internAuswahl && ausgewaehltPinIdx  >= 0) { multiPrim = []; multiPins = [] }
    Timer { id: pfeilUndoTimer; interval: 1000; onTriggered: root._pfeilUndoOffen = false }
    property string aktLinienart:       "solid"
    property bool   aktGefuellt:        false
    // Feste absolute Größe für das "Punkt"-Werkzeug (mm), s. addPrimitiv-Aufruf
    // im "punkt"-Case weiter unten.
    readonly property real _punktRadiusMm: 0.5

    // Zwischenpunkte für Mehrstufenwerkzeuge (Linie, Rechteck, Kreis, Bogen)
    property var    werkzeugPunkte: []
    property var    mausNormPos:    ({x: -1, y: -1})
    property bool   mausImCanvas:   false

    // ── Symbolliste: Zustand ────────────────────────────────────────
    property var    listenSymbole:     []
    property string aktiveListenId:    ""
    property string listeFilter:       ""
    property string loeschenSymbolId:  ""
    property string loeschenSymbolName: ""

    // Vergleichs-Warteschlange (SE-VERGLEICH-01, Entwicklungsphase-Werkzeug):
    // rein sitzungsbasierte Merkliste (kein DB-Feld, kein Schema-Update) zum
    // schnellen Durchblättern mehrerer ähnlicher Symbole, ohne die Liste/
    // Suche jedes Mal neu zu bedienen. Geht beim Schließen des Editors verloren.
    property var    vergleichsListe:   []

    property var gefilterteSymbole: {
        var f = listeFilter.toLowerCase()
        var result = f ? listenSymbole.filter(function(s) {
            return s.name.toLowerCase().indexOf(f) >= 0 ||
                   (s.kategorie || "").toLowerCase().indexOf(f) >= 0
        }) : listenSymbole.slice()
        var ordnung = ["kontakte","schutz","antriebe","passive","signalgeraete",
                       "klemmen","sps_pls","kfz","arduino","sensoren"]
        result.sort(function(a, b) {
            var ia = ordnung.indexOf(a.kategorie || ""); if (ia < 0) ia = 999
            var ib = ordnung.indexOf(b.kategorie || ""); if (ib < 0) ib = 999
            if (ia !== ib) return ia - ib
            return (a.name || "").localeCompare(b.name || "")
        })
        return result
    }

    function normToMmX(v) { return v * root.breiteMm }
    function normToMmY(v) { return v * root.hoeheMm }
    function normToMmForField(name, v) {
        return (name === "y1" || name === "y2" || name === "y3") ? v * root.hoeheMm : v * root.breiteMm
    }
    function mmToNormForField(name, v) {
        return (name === "y1" || name === "y2" || name === "y3") ? v / root.hoeheMm : v / root.breiteMm
    }
    function istPositionsfeld(name) {
        return ["x1","y1","x2","y2","x3","y3","radius"].indexOf(name) >= 0
    }

    // ── Daten laden ────────────────────────────────────────────────
    Component.onCompleted: { ladeDaten(); symbollisteAktualisieren() }
    onEditSymbolIdChanged:  ladeDaten()
    onVorlageIdChanged:     ladeDaten()

    function ladeDaten() {
        if (_kopierModus) return
        undoStack          = []
        ausgewaehltPrimIdx = -1
        ausgewaehltPinIdx  = -1
        multiPrim          = []
        multiPins          = []
        werkzeugPunkte     = []
        _sePreviewRotation = 0
        _sePreviewSpiegelX = false
        _sePreviewSpiegelY = false

        if (editSymbolId === "" && vorlageId !== "") {
            // Vorlage laden – Geometrie kopieren, Symbol-ID bleibt leer (wird beim Speichern neu vergeben)
            var vInfo = symbolDefinitionModel.symbolInfo(vorlageId)
            nameText      = qsTr("Kopie von ") + (vInfo.name || vorlageId)
            kategorieText = vInfo.kategorie || ""
            breiteMm      = vInfo.breiteMm  || 32
            hoeheMm       = vInfo.hoeheMm   || 16
            rolleText     = vInfo.rolle     || "durchleiter"
            bmkSeiteText  = vInfo.bmkSeite  || "auto"
            pinSchriftMm  = vInfo.pinSchriftMm || 2.0
            bmkKennbuchstaben = symbolDefinitionModel.bmkKennbuchstabenFuerSymbol(vorlageId)
            istBuiltin    = false

            var vPrims   = symbolDefinitionModel.primitiveFuerSymbol(vorlageId)
            var vPinList = symbolDefinitionModel.pinsForSymbol(vorlageId)
            var vPins    = []
            for (var vi = 0; vi < vPinList.length; vi++) {
                var vp = vPinList[vi]
                vPins.push({
                    name:      vp.name,
                    x:         vp.x,
                    y:         vp.y,
                    offenX:    vp.offenX !== undefined ? vp.offenX : (vp.offen ? vp.offen.x : -1),
                    offenY:    vp.offenY !== undefined ? vp.offenY : (vp.offen ? vp.offen.y : 0),
                    signaltyp: vp.signaltyp || "neutral",
                    kontext:   vp.kontext   || "",
                    knotenGruppe: vp.knotenGruppe !== undefined ? vp.knotenGruppe : 0,
                    rolle:     vp.rolle || ""
                })
            }
            primitive = vPrims.slice()
            pins      = vPins
        } else if (editSymbolId === "") {
            nameText      = qsTr("Neues Symbol")
            kategorieText = ""
            breiteMm      = 32
            hoeheMm       = 16
            rolleText     = "durchleiter"
            bmkSeiteText  = "auto"
            pinSchriftMm  = 2.0
            bmkKennbuchstaben = []
            istBuiltin    = false
            primitive     = []
            pins          = []
        } else {
            var info = symbolDefinitionModel.symbolInfo(editSymbolId)
            nameText      = info.name      || editSymbolId
            kategorieText = info.kategorie || ""
            breiteMm      = info.breiteMm  || 32
            hoeheMm       = info.hoeheMm   || 16
            rolleText     = info.rolle     || "durchleiter"
            bmkSeiteText  = info.bmkSeite  || "auto"
            pinSchriftMm  = info.pinSchriftMm || 2.0
            bmkKennbuchstaben = symbolDefinitionModel.bmkKennbuchstabenFuerSymbol(editSymbolId)
            istBuiltin    = info.ist_builtin     || false

            var prims = symbolDefinitionModel.primitiveFuerSymbol(editSymbolId)
            var pinList = symbolDefinitionModel.pinsForSymbol(editSymbolId)

            // Pins mit offenX/offenY flach machen für interne Nutzung
            var flatPins = []
            for (var i = 0; i < pinList.length; i++) {
                var p = pinList[i]
                flatPins.push({
                    name:      p.name,
                    x:         p.x,
                    y:         p.y,
                    offenX:    p.offenX !== undefined ? p.offenX : (p.offen ? p.offen.x : -1),
                    offenY:    p.offenY !== undefined ? p.offenY : (p.offen ? p.offen.y : 0),
                    signaltyp: p.signaltyp || "neutral",
                    kontext:   p.kontext   || "",
                    knotenGruppe: p.knotenGruppe !== undefined ? p.knotenGruppe : 0,
                    rolle:     p.rolle || ""
                })
            }
            primitive = prims.slice()
            pins      = flatPins
        }
        _unsavedChanges = false
        zeichneCanvas.requestPaint()
    }

    function symbollisteAktualisieren() {
        listenSymbole = symbolDefinitionModel.alleSymbole()
        if (vergleichsListe.length > 0) {
            var gueltigeIds = listenSymbole.map(function(s) { return s.id })
            vergleichsListe = vergleichsListe.filter(function(id) { return gueltigeIds.indexOf(id) >= 0 })
        }
    }

    // Vergleichs-Warteschlange: Symbol hinzufügen/entfernen, dann sequentiell
    // durchblättern (vergleichVor/vergleichZurueck) — lädt jeweils wie ein
    // normaler Listenklick, nur ohne die Liste erneut anzufassen.
    function vergleichToggle(symbolId) {
        var idx = vergleichsListe.indexOf(symbolId)
        var neu = vergleichsListe.slice()
        if (idx >= 0) neu.splice(idx, 1)
        else neu.push(symbolId)
        vergleichsListe = neu
    }

    function vergleichLeeren() {
        vergleichsListe = []
    }

    function _vergleichSpringeZu(symbolId) {
        aktiveListenId = symbolId
        vorlageId      = ""
        editSymbolId   = symbolId
    }

    function vergleichVor() {
        if (vergleichsListe.length < 2) return
        var idx  = vergleichsListe.indexOf(editSymbolId)
        var next = (idx < 0) ? 0 : (idx + 1) % vergleichsListe.length
        _vergleichSpringeZu(vergleichsListe[next])
    }

    function vergleichZurueck() {
        if (vergleichsListe.length < 2) return
        var idx  = vergleichsListe.indexOf(editSymbolId)
        var prev = (idx < 0) ? 0 : (idx - 1 + vergleichsListe.length) % vergleichsListe.length
        _vergleichSpringeZu(vergleichsListe[prev])
    }

    // Löschmarkierung umschalten (SYM-LOESCH-MARKIERUNG-01, Entwicklungsphase-
    // Werkzeug) — funktioniert für built-in UND eigene Symbole, im Gegensatz
    // zum harten Löschen-Button (nur eigene). Reiner Merker, löscht nichts.
    function markierungLoeschenToggle(symbolId) {
        var alt = false
        for (var i = 0; i < listenSymbole.length; i++) {
            if (listenSymbole[i].id === symbolId) { alt = !!listenSymbole[i].markiertLoeschen; break }
        }
        symbolDefinitionModel.markierungLoeschenSetzen(symbolId, !alt)
        symbollisteAktualisieren()
    }

    function neuesSymbol() {
        aktiveListenId = ""
        vorlageId      = ""
        if (editSymbolId !== "") { editSymbolId = "" } else { ladeDaten() }
    }

    function kopieErstellen() {
        _kopierModus   = true
        var quelle     = editSymbolId !== "" ? editSymbolId : vorlageId
        aktiveListenId = ""
        vorlageId      = quelle
        editSymbolId   = ""
        istBuiltin     = false
        nameText       = qsTr("Kopie von ") + nameText
        _kopierModus   = false
    }

    // ── Snap-to-Grid (0.5-mm-Raster) ──────────────────────────────
    // Snap auf 0.5mm: breiteMm * 2 Schritte in X, hoeheMm * 2 Schritte in Y
    function snapX(v) { return Math.round(v * root.breiteMm * 2) / (root.breiteMm * 2) }
    function snapY(v) { return Math.round(v * root.hoeheMm  * 2) / (root.hoeheMm  * 2) }

    // ── Undo-Snapshot (SE-UNDO-VOLLSTAENDIG-01) ─────────────────────
    // Vor JEDER destruktiven/hinzufügenden Änderung aufrufen - Undo stellt
    // den kompletten {primitive, pins}-Stand von davor wieder her, deckt
    // damit auch Löschen und Verschieben ab (nicht nur "zuletzt hinzugefügt").
    function pushUndoSnapshot() {
        var snap = {
            primitive: primitive.map(function(p) { return Object.assign({}, p) }),
            pins:      pins.map(function(p) { return Object.assign({}, p) }),
            breiteMm:  breiteMm,
            hoeheMm:   hoeheMm
        }
        var neu = undoStack.concat([snap])
        undoStack = neu.length > _undoMax ? neu.slice(neu.length - _undoMax) : neu
    }

    // ── Primitiv hinzufügen ────────────────────────────────────────
    function addPrimitiv(p) {
        pushUndoSnapshot()
        primitive = primitive.concat([p])
        zeichneCanvas.requestPaint()
    }

    // ── Pin hinzufügen ─────────────────────────────────────────────
    // SE-KNOTENGRUPPE-02: bei rolle='verbraucher' soll ein neuer Pin nicht
    // auf den Default-Knoten 0 fallen, da ein Verbraucher-Pin i.d.R. ein
    // eigener, vom Rest galvanisch getrennter Anschluss ist (s.
    // konzept/features/04_symbolsystem.md §21) - Ersteller kann die Zahl
    // danach weiterhin von Hand auf eine bestehende Gruppe zurücksetzen.
    function naechsteFreieKnotenGruppe() {
        var maxKg = -1
        for (var i = 0; i < pins.length; i++) {
            var kg = pins[i].knotenGruppe
            if (kg !== undefined && kg > maxKg) maxKg = kg
        }
        return maxKg + 1
    }

    function addPin(nx, ny) {
        pushUndoSnapshot()
        var kg = rolleText === "verbraucher" ? naechsteFreieKnotenGruppe() : 0
        var neu = {name: "P" + (pins.length + 1), x: nx, y: ny, offenX: -1, offenY: 0, signaltyp: "neutral", kontext: "", knotenGruppe: kg}
        pins = pins.concat([neu])
        ausgewaehltPinIdx = pins.length - 1
        zeichneCanvas.requestPaint()
    }

    // ── Undo (Strg+Z) ──────────────────────────────────────────────
    function undo() {
        if (undoStack.length === 0) return
        var last = undoStack[undoStack.length - 1]
        undoStack = undoStack.slice(0, undoStack.length - 1)
        primitive = last.primitive
        pins      = last.pins
        // Größe mitzurücksetzen: Primitive/Pins sind relativ zur Größe normiert (SE-GROESSE-01)
        if (last.breiteMm !== undefined) breiteMm = last.breiteMm
        if (last.hoeheMm  !== undefined) hoeheMm  = last.hoeheMm
        if (ausgewaehltPrimIdx >= primitive.length) ausgewaehltPrimIdx = -1
        if (ausgewaehltPinIdx  >= pins.length)       ausgewaehltPinIdx  = -1
        multiPrim = []; multiPins = []      // Indizes der Mehrfachauswahl wären veraltet
        zeichneCanvas.requestPaint()
    }

    // Größe ändern, ohne den Inhalt zu verzerren (SE-GROESSE-01): absolute mm-Maße
    // von Primitiven und Pins bleiben erhalten, das Symbol wächst nach rechts/unten.
    function groesseAendern(neueBreite, neueHoehe) {
        var nb = Math.max(4, Math.round(neueBreite))
        var nh = Math.max(4, Math.round(neueHoehe))
        if (nb === breiteMm && nh === hoeheMm) return
        pushUndoSnapshot()
        var r = SeGroesse.skaliere(primitive, pins, breiteMm, hoeheMm, nb, nh)
        primitive = r.primitive
        pins      = r.pins
        breiteMm  = nb
        hoeheMm   = nh
        zeichneCanvas.requestPaint()
    }

    // ── Mehrfachauswahl (SE-MEHRFACHAUSWAHL-01) ─────────────────────────
    // Setzt die Auswahl konsistent: 0/1 Element → Einzel-Modus (EP bearbeitbar),
    // ab 2 Elementen → Index-Listen multiPrim/multiPins.
    function setzeAuswahl(prims, pinsL) {
        _internAuswahl = true
        if (prims.length + pinsL.length <= 1) {
            multiPrim = []; multiPins = []
            ausgewaehltPrimIdx = prims.length === 1 ? prims[0] : -1
            ausgewaehltPinIdx  = pinsL.length === 1 ? pinsL[0] : -1
        } else {
            ausgewaehltPrimIdx = -1; ausgewaehltPinIdx = -1
            multiPrim = prims; multiPins = pinsL
        }
        _internAuswahl = false
        zeichneCanvas.requestPaint()
    }
    function auswahlPrimListe() {
        if (multiPrim.length + multiPins.length > 1) return multiPrim
        return ausgewaehltPrimIdx >= 0 ? [ausgewaehltPrimIdx] : []
    }
    function auswahlPinListe() {
        if (multiPrim.length + multiPins.length > 1) return multiPins
        return ausgewaehltPinIdx >= 0 ? [ausgewaehltPinIdx] : []
    }
    function alleMarkieren() {
        aktivesWerkzeug = "auswahl"; werkzeugPunkte = []
        var pl = [], nl = []
        for (var i = 0; i < primitive.length; i++) pl.push(i)
        for (var j = 0; j < pins.length; j++)      nl.push(j)
        setzeAuswahl(pl, nl)
    }
    function auswahlLoeschen() {
        var pl = auswahlPrimListe(), nl = auswahlPinListe()
        if (pl.length + nl.length === 0) return
        pushUndoSnapshot()
        primitive = primitive.filter(function(_, i) { return pl.indexOf(i) < 0 })
        pins      = pins.filter(function(_, i) { return nl.indexOf(i) < 0 })
        setzeAuswahl([], [])
    }
    // Verschiebt die Auswahl um (ddx,ddy) relativ zu den Basis-Arrays (Drag: Stand bei
    // Gestenbeginn; Pfeiltasten: aktueller Stand). Versatz wird auf den Rand begrenzt.
    function verschiebeAuswahlUm(basisPrim, basisPins, pl, nl, ddx, ddy) {
        var d = SeAuswahl.gruppenDelta(basisPrim, basisPins, pl, nl, ddx, ddy)
        var np = basisPrim.slice(), npin = basisPins.slice()
        pl.forEach(function(i) { np[i] = SeAuswahl.verschiebePrimitiv(basisPrim[i], d.dx, d.dy) })
        nl.forEach(function(i) {
            var q = Object.assign({}, basisPins[i]); q.x += d.dx; q.y += d.dy; npin[i] = q
        })
        primitive = np
        pins      = npin
        zeichneCanvas.requestPaint()
    }
    // Pfeiltasten: aufeinanderfolgende Tastendrücke = ein Undo-Schritt (1 s Pause beendet ihn)
    function pfeilVerschieben(dxMm, dyMm) {
        var pl = auswahlPrimListe(), nl = auswahlPinListe()
        if (pl.length + nl.length === 0) return false
        if (!_pfeilUndoOffen) { pushUndoSnapshot(); _pfeilUndoOffen = true }
        pfeilUndoTimer.restart()
        verschiebeAuswahlUm(primitive, pins, pl, nl, dxMm / breiteMm, dyMm / hoeheMm)
        return true
    }
    // Rahmen a→b (Normkoordinaten): links→rechts = Fenster, rechts→links = Schneiden
    function rahmenAuswahlAnwenden(a, b, basisPrim, basisPins) {
        var fenster = b.x >= a.x
        var r = { x1: a.x, y1: a.y, x2: b.x, y2: b.y }
        var pl = basisPrim.slice(), nl = basisPins.slice()
        for (var i = 0; i < primitive.length; i++) {
            if (pl.indexOf(i) >= 0) continue
            if (SeAuswahl.trifftRahmen(SeAuswahl.bboxPrimitiv(primitive[i], breiteMm, hoeheMm), r, fenster)) pl.push(i)
        }
        for (var j = 0; j < pins.length; j++) {
            if (nl.indexOf(j) >= 0) continue
            var pn = pins[j]
            if (SeAuswahl.trifftRahmen({ x1: pn.x, y1: pn.y, x2: pn.x, y2: pn.y }, r, fenster)) nl.push(j)
        }
        setzeAuswahl(pl, nl)
    }

    // Farbe je Knoten-Gruppe für die Pin-Darstellung auf der Zeichenfläche
    // (SE-KNOTEN-VISUALISIERUNG-01) - macht sichtbar, welche Pins intern
    // verbunden sind, ohne dass man die Zahlenfelder einzeln vergleichen muss.
    readonly property var _knotenFarben: ["#4a9eff","#ff6b6b","#5ce65c","#ffcc00",
                                           "#c77dff","#00d4d4","#ff9f4a","#e05fc4"]
    function knotenFarbe(kg) {
        var i = (kg || 0) % _knotenFarben.length
        if (i < 0) i += _knotenFarben.length
        return _knotenFarben[i]
    }

    // SE-VERBRAUCHER-WARNUNG-01: true wenn dieses Symbol als "Verbraucher"
    // markiert ist, aber zwei oder mehr Pins dieselbe Knoten-Gruppe teilen -
    // genau die Fehlerklasse, die im Symboleditor-Audit mehrfach gefunden
    // wurde (lampe/heizelement/wp_heizstab u.a.). Frühwarnung im Editor statt
    // erst per Migration/DB-Audit im Nachhinein.
    function gemeinsameKnotenBeiVerbraucher() {
        if (rolleText !== "verbraucher" || pins.length < 2) return false
        var gesehen = {}
        for (var i = 0; i < pins.length; i++) {
            var kg = pins[i].knotenGruppe || 0
            if (gesehen[kg]) return true
            gesehen[kg] = true
        }
        return false
    }

    // ── Speichern ──────────────────────────────────────────────────
    function speichern() {
        // NKZ-05: Kennbuchstabe ist reine Klassifikations-Metadatur ohne
        // Geometriebezug - bewusst VOR dem Builtin-Schreibschutz gespeichert,
        // damit auch eingebaute Symbole (Motor, Sicherung, ...) einen
        // BMK-Kennbuchstaben bekommen koennen, ohne den Geometrieschutz
        // aufzuweichen.
        if (istBuiltin && editSymbolId !== "")
            symbolDefinitionModel.bmkKennbuchstabenSpeichern(editSymbolId, bmkKennbuchstaben)

        if (istBuiltin) {
            meldungManager.zeigen(qsTr("Kennbuchstaben gespeichert. Geometrie eingebauter Symbole bleibt geschützt – dafür «Als Vorlage kopieren» nutzen."), true)
            return
        }

        // SE-PIN-DUPLIKAT-01: doppelte Pin-Namen innerhalb desselben Symbols
        // waren bisher unbemerkt speicherbar - verwirrend beim Platzieren
        // (welcher "A1" ist gemeint?) und für BMK-/DRC-Logik, die Pins über
        // den Namen anspricht.
        var pinNamenGesehen = {}
        for (var pn = 0; pn < pins.length; pn++) {
            var pname = (pins[pn].name || "").trim()
            if (pname !== "" && pinNamenGesehen[pname]) {
                speichernFehlerText.text = qsTr("Pin-Name «%1» ist mehrfach vergeben. Bitte eindeutige Namen verwenden.").arg(pname)
                speichernFehlerDialog.open()
                return
            }
            pinNamenGesehen[pname] = true
        }

        var sid = editSymbolId
        if (sid === "") {
            // ID aus Name generieren
            sid = nameText.toLowerCase()
                    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss")
                    .replace(/[^a-z0-9]/g, "_").replace(/_+/g, "_").replace(/^_|_$/g, "")
            if (sid === "") sid = "symbol_" + Date.now()
        }

        if (editSymbolId === "") {
            if (!symbolDefinitionModel.symbolAnlegen(sid, nameText, kategorieText, breiteMm, hoeheMm, rolleText, bmkSeiteText, pinSchriftMm, vorlageId)) {
                speichernFehlerText.text = qsTr("Symbol-ID bereits vergeben. Bitte anderen Namen wählen.")
                speichernFehlerDialog.open()
                return
            }
        } else {
            symbolDefinitionModel.symbolAktualisieren(sid, nameText, kategorieText, breiteMm, hoeheMm, rolleText, bmkSeiteText, pinSchriftMm)
        }
        symbolDefinitionModel.bmkKennbuchstabenSpeichern(sid, bmkKennbuchstaben)

        symbolDefinitionModel.primitivAlleLoeschen(sid)
        for (var i = 0; i < primitive.length; i++) {
            var p = Object.assign({}, primitive[i])
            p.reihenfolge = i
            symbolDefinitionModel.primitivHinzufuegen(sid, p)
        }

        symbolDefinitionModel.pinAlleLoeschen(sid)
        for (var j = 0; j < pins.length; j++) {
            symbolDefinitionModel.pinHinzufuegen(sid, pins[j])
        }

        symbollisteAktualisieren()
        aktiveListenId  = sid
        editSymbolId    = sid
        _unsavedChanges = false
        meldungManager.zeigen(qsTr("Symbol gespeichert."), true)
        root.gespeichert(sid)
    }

    // ── Tastenkürzel ───────────────────────────────────────────────
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            undo(); event.accepted = true; return
        }
        if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            alleMarkieren(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Escape) {
            if (aktivesWerkzeug === "auswahl" && auswahlAnzahl > 0) setzeAuswahl([], [])
            werkzeugPunkte = []; zeichneCanvas.requestPaint()
            event.accepted = true; return
        }
        if (aktivesWerkzeug === "auswahl" && !(event.modifiers & Qt.ControlModifier) && auswahlAnzahl > 0) {
            var schrittMm = (event.modifiers & Qt.ShiftModifier) ? 4 : 0.5
            var pdx = 0, pdy = 0
            if      (event.key === Qt.Key_Left)  pdx = -schrittMm
            else if (event.key === Qt.Key_Right) pdx =  schrittMm
            else if (event.key === Qt.Key_Up)    pdy = -schrittMm
            else if (event.key === Qt.Key_Down)  pdy =  schrittMm
            if ((pdx !== 0 || pdy !== 0) && pfeilVerschieben(pdx, pdy)) { event.accepted = true; return }
        }
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            auswahlLoeschen()
            event.accepted = true; return
        }
        if (!event.isAutoRepeat) {
            if (event.key === Qt.Key_A) { aktivesWerkzeug = "auswahl";     werkzeugPunkte = [] }
            if (event.key === Qt.Key_L) { aktivesWerkzeug = "linie";       werkzeugPunkte = [] }
            if (event.key === Qt.Key_R) { aktivesWerkzeug = "rechteck";    werkzeugPunkte = [] }
            if (event.key === Qt.Key_K) { aktivesWerkzeug = "kreis_offen"; werkzeugPunkte = [] }
            if (event.key === Qt.Key_B) { aktivesWerkzeug = "bogen";       werkzeugPunkte = [] }
            if (event.key === Qt.Key_P) { aktivesWerkzeug = "punkt";       werkzeugPunkte = [] }
            if (event.key === Qt.Key_T) { aktivesWerkzeug = "text";        werkzeugPunkte = [] }
            if (event.key === Qt.Key_I) { aktivesWerkzeug = "pin";         werkzeugPunkte = [] }
        }
    }

    // ── Hit-Test Hilfsfunktionen ───────────────────────────────────
    function distPunktZuSegment(px, py, x1, y1, x2, y2) {
        var dx = x2 - x1, dy = y2 - y1
        var lenSq = dx * dx + dy * dy
        if (lenSq < 0.00001) return Math.sqrt((px-x1)*(px-x1)+(py-y1)*(py-y1))
        var t = Math.max(0, Math.min(1, ((px-x1)*dx+(py-y1)*dy)/lenSq))
        var cx = x1 + t*dx, cy = y1 + t*dy
        return Math.sqrt((px-cx)*(px-cx)+(py-cy)*(py-cy))
    }

    // Rotiert einen Normkoordinaten-Punkt um das Primitiv-Zentrum zurück in
    // dessen unrotierten lokalen Rahmen — im mm-Raum (uniformer Maßstab),
    // nicht in normierten 0..1-Koordinaten, da breiteMm != hoeheMm sonst eine
    // Rotation zu einer Scherung verzerren würde. Vorzeichen (-rotation)
    // entspricht der Umkehrung des ctx.rotate(rotation)-Renderings.
    function entdreheNormPunkt(p, nx, ny) {
        if (!p.rotation) return {x: nx, y: ny}
        var cx = ((p.x1||0) + (p.x2||0)) / 2
        var cy = ((p.y1||0) + (p.y2||0)) / 2
        var mmX = (nx - cx) * root.breiteMm
        var mmY = (ny - cy) * root.hoeheMm
        var rad = -p.rotation * Math.PI / 180
        var cos = Math.cos(rad), sin = Math.sin(rad)
        var rx = mmX * cos - mmY * sin
        var ry = mmX * sin + mmY * cos
        return { x: cx + rx / root.breiteMm, y: cy + ry / root.hoeheMm }
    }

    function distZuPrimitiv(p, nx, ny) {
        if (p.rotation && (p.typ === "rechteck" || p.typ === "rechteck_gefuellt")) {
            var lokal = entdreheNormPunkt(p, nx, ny)
            nx = lokal.x; ny = lokal.y
        }
        switch (p.typ) {
        case "linie":
            return distPunktZuSegment(nx, ny, p.x1, p.y1, p.x2, p.y2)
        case "rechteck":
            return Math.min(
                distPunktZuSegment(nx, ny, p.x1, p.y1, p.x2, p.y1),
                distPunktZuSegment(nx, ny, p.x2, p.y1, p.x2, p.y2),
                distPunktZuSegment(nx, ny, p.x1, p.y2, p.x2, p.y2),
                distPunktZuSegment(nx, ny, p.x1, p.y1, p.x1, p.y2))
        case "rechteck_gefuellt":
            if (nx >= Math.min(p.x1,p.x2) && nx <= Math.max(p.x1,p.x2) &&
                ny >= Math.min(p.y1,p.y2) && ny <= Math.max(p.y1,p.y2)) return 0
            return Math.min(
                distPunktZuSegment(nx, ny, p.x1, p.y1, p.x2, p.y1),
                distPunktZuSegment(nx, ny, p.x2, p.y1, p.x2, p.y2),
                distPunktZuSegment(nx, ny, p.x1, p.y2, p.x2, p.y2),
                distPunktZuSegment(nx, ny, p.x1, p.y1, p.x1, p.y2))
        case "kreis_offen":
            return Math.abs(Math.sqrt((nx-p.x1)*(nx-p.x1)+(ny-p.y1)*(ny-p.y1))-p.radius)
        case "kreis_gefuellt":
            return Math.sqrt((nx-p.x1)*(nx-p.x1)+(ny-p.y1)*(ny-p.y1))
        case "text":
        case "bogen":
        case "dreieck_gefuellt":
            return Math.sqrt((nx-p.x1)*(nx-p.x1)+(ny-p.y1)*(ny-p.y1))
        default:
            return 999
        }
    }

    function treffePrimitiv(nx, ny) {
        var bestIdx = -1, bestDist = 0.07
        for (var i = 0; i < primitive.length; i++) {
            var d = distZuPrimitiv(primitive[i], nx, ny)
            if (d < bestDist) { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }

    function treffePin(nx, ny) {
        var bestIdx = -1, bestDist = 0.07
        for (var i = 0; i < pins.length; i++) {
            var pin = pins[i]
            var d = Math.sqrt((nx-pin.x)*(nx-pin.x)+(ny-pin.y)*(ny-pin.y))
            if (d < bestDist) { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }


    function repaintAll() { zeichneCanvas.requestPaint() }
    // ── Dialoge ────────────────────────────────────────────────────

    property var textEingabePos: ({x: 0, y: 0})

    Dialog {
        id:      textEingabeDialog
        title:   qsTr("Text-Primitiv einfügen")
        modal:   true
        parent:  Overlay.overlay
        anchors.centerIn: parent
        width:   340
        padding: 16

        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }

        ColumnLayout { spacing: 8; width: parent.width
            Text { text: qsTr("Textinhalt:"); color: root.theme.textMuted; font.pixelSize: 11 }
            TextField {
                id: textFeld
                Layout.fillWidth: true
                placeholderText: "M, 3~, ..."
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                color: root.theme.textPrimary; font.pixelSize: 13
            }
            Row {
                spacing: 12
                Text { text: qsTr("Fett:"); color: root.theme.textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                CheckBox { id: textFettCheck }
            }
        }
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (textFeld.text.length > 0)
                root.addPrimitiv({typ: "text", x1: root.textEingabePos.x, y1: root.textEingabePos.y,
                    text_inhalt: textFeld.text, schrift_relativ: 0.15,
                    schrift_fett: textFettCheck.checked, text_align: "center", text_baseline: "middle",
                    linienart: "solid"})
            textFeld.text = ""
        }
    }

    Dialog {
        id: speichernFehlerDialog
        title: qsTr("Fehler beim Speichern")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 340; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            id: speichernFehlerText
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Ok
    }

    Dialog {
        id:    loeschenConfirmDialog
        title: qsTr("Symbol löschen")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 340; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            text: qsTr("Symbol «%1» wirklich löschen?\nDieser Vorgang kann nicht rückgängig gemacht werden.").arg(root.loeschenSymbolName)
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            if (root.editSymbolId === root.loeschenSymbolId || root.aktiveListenId === root.loeschenSymbolId) {
                root.editSymbolId   = ""
                root.vorlageId      = ""
                root.aktiveListenId = ""
                root.ladeDaten()
            }
            symbolDefinitionModel.symbolLoeschen(root.loeschenSymbolId)
            root.symbollisteAktualisieren()
            root.loeschenSymbolId   = ""
            root.loeschenSymbolName = ""
        }
    }

    // SE-UNGESPEICHERT-WARNUNG-01: Rückfrage vor dem Verwerfen ungespeicherter
    // Änderungen (Symbolwechsel, "+ Neu", "Als Vorlage kopieren", Kopie-Button,
    // Abbrechen) - s. verwerfenUndFortfahren().
    Dialog {
        id:    ungespeichertDialog
        title: qsTr("Ungespeicherte Änderungen")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 340; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            text: qsTr("Dieses Symbol hat ungespeicherte Änderungen, die dabei verloren gehen. Trotzdem fortfahren?")
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            var aktion = root._ausstehendeAktion
            root._ausstehendeAktion = null
            if (aktion) aktion()
        }
        onRejected: root._ausstehendeAktion = null
    }

    // ── Hauptlayout ────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Symbolliste (links) ──────────────────────────────────
        SeSymbolListe {
            id:                symbolListePanel
            editor:            root
            Layout.fillHeight: true
            onLoeschenAngefordert: function(sid, sname) {
                root.loeschenSymbolId   = sid
                root.loeschenSymbolName = sname
                loeschenConfirmDialog.open()
            }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.border }

        // ── Editor (rechts) ─────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            // ── Header-Leiste ────────────────────────────────────────
            SeEditorHeader {
                editor: root
                Layout.fillWidth: true
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // ── Mitte + Pins: vertikal ziehbar ───────────────────────
            SplitView {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                orientation: Qt.Vertical
                handle: Rectangle {
                    implicitHeight: 5
                    color: SplitHandle.pressed ? root.theme.accent
                         : SplitHandle.hovered  ? root.theme.activeItem : root.theme.border
                }

            // ── Mitte: Toolbar | Zeichenfläche | Eigenschaften ────────
            RowLayout {
                SplitView.fillHeight: true
                SplitView.minimumHeight: 120
                spacing: 0


                // ── Werkzeug-Toolbar ─────────────────────────────────
                SeWerkzeugToolbar {
                    editor: root
                    Layout.fillHeight: true
                }

                // ── Zeichenfläche ─────────────────────────────────────
                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    clip: true

                    // Hintergrund
                    Rectangle { anchors.fill: parent; color: root.theme.surfaceDeep }

                    Canvas {
                        id: zeichneCanvas
                        anchors.fill: parent
                        renderStrategy: Canvas.Threaded

                        // Rechteckiger Zeichenbereich – Seitenverhältnis = breiteMm : hoeheMm
                        readonly property real padding:  36
                        readonly property real baseSize: Math.min(width - 2*padding, height - 2*padding)
                        readonly property real drawW:    baseSize * root._seZoom * root.breiteMm / Math.max(root.breiteMm, root.hoeheMm)
                        readonly property real drawH:    baseSize * root._seZoom * root.hoeheMm  / Math.max(root.breiteMm, root.hoeheMm)
                        readonly property real drawX:    (width  - drawW) / 2 + root._sePanX
                        readonly property real drawY:    (height - drawH) / 2 + root._sePanY

                        function n2sx(n) { return drawX + n * drawW }
                        function n2sy(n) { return drawY + n * drawH }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var dw = drawW, dh = drawH, dx = drawX, dy = drawY

                            // ── Hintergrund der Zeichenfläche ──────────
                            ctx.fillStyle = "#fdf8e8"
                            ctx.fillRect(dx, dy, dw, dh)

                            // ── Punkt-Raster (0.5-mm-Schritte) ───────────────────
                            var stepsX = root.breiteMm * 2   // 0.5mm pro Schritt
                            var stepsY = root.hoeheMm  * 2
                            ctx.fillStyle = "#2a3a5a"
                            for (var gi = 0; gi <= stepsX; gi++) {
                                for (var gj = 0; gj <= stepsY; gj++) {
                                    ctx.beginPath()
                                    ctx.arc(dx + gi/stepsX*dw, dy + gj/stepsY*dh, 1.5, 0, 2*Math.PI)
                                    ctx.fill()
                                }
                            }
                            // 4-mm-Rasterpunkte größer hervorheben
                            var grid4X = Math.round(root.breiteMm / 4)
                            var grid4Y = Math.round(root.hoeheMm  / 4)
                            ctx.fillStyle = "#5577aa"
                            for (var gx4 = 0; gx4 <= grid4X; gx4++) {
                                for (var gy4 = 0; gy4 <= grid4Y; gy4++) {
                                    ctx.beginPath()
                                    ctx.arc(dx + gx4/grid4X*dw, dy + gy4/grid4Y*dh, 3.0, 0, 2*Math.PI)
                                    ctx.fill()
                                }
                            }

                            // ── mm-Lineal (oben und links) ────────────
                            var pxPerMmX = dw / root.breiteMm
                            var pxPerMmY = dh / root.hoeheMm
                            ctx.save()
                            ctx.lineWidth = 0.7
                            // X-Lineal oben
                            for (var mx = 0; mx <= root.breiteMm; mx++) {
                                var isLabeledX = (mx % 4 === 0)
                                var tickLenX   = isLabeledX ? 8 : 4
                                var xtx = dx + mx * pxPerMmX
                                ctx.strokeStyle = "#6688aa"
                                ctx.beginPath(); ctx.moveTo(xtx, dy - tickLenX); ctx.lineTo(xtx, dy); ctx.stroke()
                                if (isLabeledX) {
                                    ctx.fillStyle = "#6688aa"; ctx.font = "9px sans-serif"
                                    ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                                    ctx.fillText(mx, xtx, dy - tickLenX - 1)
                                }
                            }
                            // Y-Lineal links
                            for (var my = 0; my <= root.hoeheMm; my++) {
                                var isLabeledY = (my % 4 === 0)
                                var tickLenY   = isLabeledY ? 8 : 4
                                var yty = dy + my * pxPerMmY
                                ctx.strokeStyle = "#6688aa"
                                ctx.beginPath(); ctx.moveTo(dx - tickLenY, yty); ctx.lineTo(dx, yty); ctx.stroke()
                                if (isLabeledY) {
                                    ctx.fillStyle = "#6688aa"; ctx.font = "9px sans-serif"
                                    ctx.textAlign = "right"; ctx.textBaseline = "middle"
                                    ctx.fillText(my, dx - tickLenY - 3, yty)
                                }
                            }
                            // Einheit "mm" an der Ecke
                            ctx.fillStyle = "#445566"; ctx.font = "8px sans-serif"
                            ctx.textAlign = "right"; ctx.textBaseline = "bottom"
                            ctx.fillText("mm", dx - 2, dy - 2)
                            ctx.restore()

                            // ── Rand der Zeichenfläche ─────────────────
                            ctx.strokeStyle = "#3a4a6a"
                            ctx.lineWidth   = 1
                            ctx.setLineDash([4, 4])
                            ctx.strokeRect(dx + 0.5, dy + 0.5, dw - 1, dh - 1)
                            ctx.setLineDash([])

                            // ── Primitive ─────────────────────────────
                            // Vorschau-Drehung (SYMBOL-TEXT-LESBAR-01-Folge): translate/rotate/
                            // scale/translate(-dw/2,-dh/2), identisch zum Muster in
                            // CanvasRenderHandler.qml::_renderSymbol() - kollabiert bei
                            // Rotation 0°/keine Spiegelung zur Identität (translate(dx,dy)),
                            // daher hier immer angewendet statt bedingt verzweigt.
                            ctx.lineCap  = "round"
                            ctx.lineJoin = "round"
                            var _pvRad = root._sePreviewRotation * Math.PI / 180
                            var _pvAktiv = root._sePreviewRotation !== 0 ||
                                           root._sePreviewSpiegelX || root._sePreviewSpiegelY

                            ctx.save()
                            ctx.translate(dx + dw/2, dy + dh/2)
                            if (_pvRad !== 0) ctx.rotate(_pvRad)
                            if (root._sePreviewSpiegelX) ctx.scale(-1, 1)
                            if (root._sePreviewSpiegelY) ctx.scale(1, -1)
                            ctx.translate(-dw/2, -dh/2)

                            for (var pi = 0; pi < root.primitive.length; pi++) {
                                var p = root.primitive[pi]
                                var isSel = (pi === root.ausgewaehltPrimIdx) || root.multiPrim.indexOf(pi) >= 0
                                ctx.strokeStyle = isSel ? "#00e5a0" : "#0b5394"
                                ctx.lineWidth   = isSel ? 3.0 : 2.0

                                var la = p.linienart || "solid"
                                if      (la === "dash")    ctx.setLineDash([8, 4])
                                else if (la === "dot")     ctx.setLineDash([2, 4])
                                else if (la === "dashdot") ctx.setLineDash([8, 4, 2, 4])
                                else                       ctx.setLineDash([])

                                // dx/dy=0: Ursprung liegt bereits durch obiges translate() an
                                // der (ggf. gedrehten/gespiegelten) Box-Ecke.
                                zeichneCanvas.zeichnePrimitiv(ctx, p, 0, 0, dw, dh)
                                ctx.setLineDash([])

                                // Immer sichtbarer Anfasspunkt-Hinweis (Nutzerwunsch): Linien/
                                // Rechtecke lassen sich überall auf der gezeichneten Kontur
                                // treffen, Text/Kreis/Bogen aber nur über ihren einzelnen
                                // Ankerpunkt (x1,y1) - der ist ohne Markierung schwer zu finden,
                                // v.a. bei Text (Anker je nach text_align/-baseline nicht immer
                                // unter dem sichtbaren Zeichen). Nur wenn NICHT ausgewählt
                                // gezeichnet, sonst überdeckt vom größeren Auswahl-Griff unten.
                                if (!isSel && (p.typ === "text" || p.typ === "kreis_offen" ||
                                               p.typ === "kreis_gefuellt" || p.typ === "bogen")) {
                                    ctx.save()
                                    ctx.fillStyle   = "#ff8800"
                                    ctx.strokeStyle = "#3a1f00"
                                    ctx.lineWidth   = 1.2
                                    ctx.beginPath()
                                    ctx.arc((p.x1||0)*dw, (p.y1||0)*dh, 5, 0, 2*Math.PI)
                                    ctx.fill()
                                    ctx.stroke()
                                    ctx.restore()
                                }
                            }
                            ctx.restore()

                            // Griffe + Koordinaten-Label bei Auswahl nur in Basis-Orientierung
                            // (Nutzerwunsch: X1/Y1/X2/Y2 direkt am Primitiv) - bei aktiver
                            // Vorschau-Drehung würde die unrotierte n2sx/n2sy-Position nicht
                            // mehr zur gezeichneten (gedrehten) Primitiv-Position passen.
                            if (!_pvAktiv && root.ausgewaehltPrimIdx >= 0) {
                                var pSel = root.primitive[root.ausgewaehltPrimIdx]
                                if (pSel) {
                                    ctx.strokeStyle = "#00e5a0"
                                    // Bei rotierten Rechtecken zeigen die Griffe die tatsächliche
                                    // (gedrehte) Bildschirmposition der Ecken, sonst würden sie
                                    // sichtbar neben dem gezeichneten Rechteck schweben.
                                    var g1x = n2sx(pSel.x1 || 0), g1y = n2sy(pSel.y1 || 0)
                                    var g2x = n2sx(pSel.x2 || 0), g2y = n2sy(pSel.y2 || 0)
                                    if (pSel.rotation && (pSel.typ === "rechteck" || pSel.typ === "rechteck_gefuellt")) {
                                        var gcx = n2sx(((pSel.x1||0)+(pSel.x2||0))/2), gcy = n2sy(((pSel.y1||0)+(pSel.y2||0))/2)
                                        var grad = pSel.rotation * Math.PI / 180
                                        var gcos = Math.cos(grad), gsin = Math.sin(grad)
                                        var d1x = g1x - gcx, d1y = g1y - gcy
                                        var d2x = g2x - gcx, d2y = g2y - gcy
                                        g1x = gcx + d1x*gcos - d1y*gsin; g1y = gcy + d1x*gsin + d1y*gcos
                                        g2x = gcx + d2x*gcos - d2y*gsin; g2y = gcy + d2x*gsin + d2y*gcos
                                    }
                                    zeichneCanvas.zeichneGriff(ctx, g1x, g1y)
                                    zeichneCanvas.zeichneKoordLabel(ctx, g1x, g1y,
                                        "X1", "Y1", root.normToMmX(pSel.x1 || 0), root.normToMmY(pSel.y1 || 0))
                                    if (pSel.typ === "linie" || pSel.typ === "rechteck" || pSel.typ === "rechteck_gefuellt") {
                                        zeichneCanvas.zeichneGriff(ctx, g2x, g2y)
                                        zeichneCanvas.zeichneKoordLabel(ctx, g2x, g2y,
                                            "X2", "Y2", root.normToMmX(pSel.x2 || 0), root.normToMmY(pSel.y2 || 0))
                                    }
                                }
                            }

                            // ── "Lesbar halten"-Text-Primitive (SYMBOL-TEXT-LESBAR-01) ──
                            // Werden in zeichnePrimitiv() übersprungen (s.dort) und hier separat
                            // aufrecht an der transformierten Ankerposition gezeichnet - exakt
                            // dieselbe Formel wie in CanvasRenderHandler.qml::_renderSymbol().
                            for (var lti = 0; lti < root.primitive.length; lti++) {
                                var ltp = root.primitive[lti]
                                if (ltp.typ !== "text" || !ltp.lesbar_halten) continue
                                var ox = (ltp.x1||0)*dw - dw/2
                                var oy = (ltp.y1||0)*dh - dh/2
                                if (root._sePreviewSpiegelX) ox = -ox
                                if (root._sePreviewSpiegelY) oy = -oy
                                var tx = ox*Math.cos(_pvRad) - oy*Math.sin(_pvRad)
                                var ty = ox*Math.sin(_pvRad) + oy*Math.cos(_pvRad)
                                ctx.save()
                                ctx.fillStyle = (lti === root.ausgewaehltPrimIdx || root.multiPrim.indexOf(lti) >= 0) ? "#00e5a0" : "#0b5394"
                                ctx.font = ((ltp.schrift_fett ? "bold " : "") +
                                            Math.round((ltp.schrift_relativ||0.15)*dh) + "px sans-serif")
                                ctx.textAlign    = ltp.text_align    || "center"
                                ctx.textBaseline = ltp.text_baseline || "middle"
                                ctx.fillText(ltp.text_inhalt||"?", dx+dw/2+tx, dy+dh/2+ty)
                                ctx.restore()
                            }

                            // ── Vorschau-Linie (aktuelles Werkzeug) ───
                            if (root.mausImCanvas && root.werkzeugPunkte.length > 0) {
                                ctx.strokeStyle = "#ffcc00"
                                ctx.lineWidth   = 1.5
                                ctx.setLineDash([4, 4])
                                var pts = root.werkzeugPunkte
                                var mx  = root.mausNormPos.x, my = root.mausNormPos.y

                                if (root.aktivesWerkzeug === "linie") {
                                    ctx.beginPath()
                                    ctx.moveTo(n2sx(pts[0].x), n2sy(pts[0].y))
                                    ctx.lineTo(n2sx(mx), n2sy(my))
                                    ctx.stroke()
                                } else if (root.aktivesWerkzeug === "rechteck") {
                                    ctx.strokeRect(n2sx(pts[0].x), n2sy(pts[0].y), (mx-pts[0].x)*dw, (my-pts[0].y)*dh)
                                } else if (root.aktivesWerkzeug === "kreis_offen") {
                                    var kd = Math.sqrt(Math.pow((mx-pts[0].x)*dw, 2) + Math.pow((my-pts[0].y)*dh, 2))
                                    ctx.beginPath()
                                    ctx.arc(n2sx(pts[0].x), n2sy(pts[0].y), kd, 0, 2*Math.PI)
                                    ctx.stroke()
                                } else if (root.aktivesWerkzeug === "bogen") {
                                    if (pts.length === 1) {
                                        ctx.beginPath()
                                        ctx.moveTo(n2sx(pts[0].x), n2sy(pts[0].y))
                                        ctx.lineTo(n2sx(mx), n2sy(my))
                                        ctx.stroke()
                                    } else if (pts.length === 2) {
                                        var bRad = Math.sqrt(Math.pow((pts[1].x-pts[0].x)*dw, 2) + Math.pow((pts[1].y-pts[0].y)*dh, 2))
                                        var bW1  = Math.atan2((pts[1].y-pts[0].y)*dh, (pts[1].x-pts[0].x)*dw)
                                        var bW2  = Math.atan2((my-pts[0].y)*dh, (mx-pts[0].x)*dw)
                                        ctx.beginPath()
                                        ctx.arc(n2sx(pts[0].x), n2sy(pts[0].y), bRad, bW1, bW2, false)
                                        ctx.stroke()
                                    }
                                }
                                ctx.setLineDash([])
                            }

                            // ── Pins ──────────────────────────────────
                            // SE-KNOTEN-VISUALISIERUNG-01: Pin-Farbe zeigt die Knoten-Gruppe,
                            // damit sichtbar wird, welche Pins intern verbunden sind, statt die
                            // Zahlenfelder in der Liste einzeln vergleichen zu müssen. Die
                            // Gruppennummer wird nur an die Beschriftung angehängt, wenn das
                            // Symbol tatsächlich mehr als eine Gruppe hat.
                            var _knotenSet = {}
                            for (var _kpi = 0; _kpi < root.pins.length; _kpi++)
                                _knotenSet[root.pins[_kpi].knotenGruppe || 0] = true
                            var _mehrereKnoten = Object.keys(_knotenSet).length > 1
                            for (var pii = 0; pii < root.pins.length; pii++) {
                                var pin = root.pins[pii]
                                var isSelP  = (pii === root.ausgewaehltPinIdx) || root.multiPins.indexOf(pii) >= 0
                                var kFarbe  = root.knotenFarbe(pin.knotenGruppe || 0)
                                ctx.beginPath()
                                ctx.arc(n2sx(pin.x), n2sy(pin.y), isSelP ? 6 : 4, 0, 2*Math.PI)
                                ctx.fillStyle   = isSelP ? "#ff8800" : kFarbe
                                ctx.strokeStyle = isSelP ? "#7f4400" : "#0a2040"
                                ctx.lineWidth   = 1; ctx.fill(); ctx.stroke()
                                // Pin-Bezeichnung
                                ctx.save()
                                ctx.fillStyle = isSelP ? "#ff8800" : kFarbe
                                ctx.font = "10px sans-serif"
                                ctx.textAlign = "left"; ctx.textBaseline = "bottom"
                                var pinLabel = (pin.name || "") + (_mehrereKnoten ? " ·" + (pin.knotenGruppe || 0) : "")
                                ctx.fillText(pinLabel, n2sx(pin.x)+8, n2sy(pin.y)-1)
                                ctx.restore()
                                // Richtungspfeil (offen-Vektor)
                                ctx.strokeStyle = isSelP ? "#ff8800" : kFarbe
                                ctx.lineWidth   = 1.5
                                ctx.beginPath()
                                ctx.moveTo(n2sx(pin.x), n2sy(pin.y))
                                ctx.lineTo(n2sx(pin.x) + (pin.offenX||0)*12, n2sy(pin.y) + (pin.offenY||0)*12)
                                ctx.stroke()
                            }

                            // ── Auswahlrahmen (SE-MEHRFACHAUSWAHL-01) ──
                            if (root._rbAktiv) {
                                var rbFenster = root._rbB.x >= root._rbA.x
                                var rx = n2sx(Math.min(root._rbA.x, root._rbB.x)), ry = n2sy(Math.min(root._rbA.y, root._rbB.y))
                                var rw = Math.abs(n2sx(root._rbB.x) - n2sx(root._rbA.x)), rh = Math.abs(n2sy(root._rbB.y) - n2sy(root._rbA.y))
                                ctx.save()
                                ctx.fillStyle   = rbFenster ? "#4a9eff22" : "#4ec94e22"
                                ctx.strokeStyle = rbFenster ? "#4a9eff"   : "#4ec94e"
                                ctx.lineWidth   = 1.5
                                ctx.setLineDash(rbFenster ? [] : [6, 4])
                                ctx.fillRect(rx, ry, rw, rh)
                                ctx.strokeRect(rx, ry, rw, rh)
                                ctx.restore()
                            }

                            // ── Fadenkreuz ────────────────────────────
                            if (root.mausImCanvas && root.aktivesWerkzeug !== "auswahl") {
                                var scx2 = n2sx(root.mausNormPos.x), scy2 = n2sy(root.mausNormPos.y)
                                ctx.strokeStyle = "#ffcc0066"; ctx.lineWidth = 1
                                ctx.setLineDash([2, 2])
                                ctx.beginPath(); ctx.moveTo(dx, scy2); ctx.lineTo(dx+ds, scy2); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(scx2, dy); ctx.lineTo(scx2, dy+ds); ctx.stroke()
                                ctx.setLineDash([])
                                ctx.beginPath()
                                ctx.arc(scx2, scy2, 4, 0, 2*Math.PI)
                                ctx.strokeStyle = "#ffcc00"; ctx.lineWidth = 1.5; ctx.stroke()
                            }
                        }

                        function zeichneGriff(ctx, px, py) {
                            ctx.save()
                            ctx.fillStyle = "#00e5a0"; ctx.strokeStyle = "#004d35"; ctx.lineWidth = 1.5
                            ctx.beginPath(); ctx.arc(px, py, 5, 0, 2*Math.PI); ctx.fill(); ctx.stroke()
                            ctx.restore()
                        }

                        // Koordinaten-Label neben einem Griff (mm, aus Normkoordinaten
                        // umgerechnet) — Nutzerwunsch: Orientierung direkt am Primitiv.
                        function zeichneKoordLabel(ctx, px, py, labelX, labelY, mmX, mmY) {
                            ctx.save()
                            ctx.font = "10px sans-serif"
                            ctx.textAlign    = "left"
                            ctx.textBaseline = "top"
                            var text = labelX + ": " + mmX.toFixed(2) + "mm   " + labelY + ": " + mmY.toFixed(2) + "mm"
                            var boxX = px + 8, boxY = py + 8
                            var tw   = ctx.measureText(text).width
                            ctx.fillStyle = "rgba(10, 20, 15, 0.78)"
                            ctx.fillRect(boxX - 3, boxY - 2, tw + 6, 15)
                            ctx.fillStyle = "#00e5a0"
                            ctx.fillText(text, boxX, boxY)
                            ctx.restore()
                        }

                        function zeichnePrimitiv(ctx, p, dx, dy, dw, dh) {
                            switch (p.typ) {
                            case "linie":
                                ctx.beginPath()
                                ctx.moveTo(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
                                ctx.lineTo(dx+(p.x2||0)*dw, dy+(p.y2||0)*dh)
                                ctx.stroke()
                                break
                            case "rechteck": {
                                var rrw = ((p.x2||0)-(p.x1||0))*dw, rrh = ((p.y2||0)-(p.y1||0))*dh
                                if (p.rotation) {
                                    ctx.save()
                                    ctx.translate(dx+((p.x1||0)+(p.x2||0))/2*dw, dy+((p.y1||0)+(p.y2||0))/2*dh)
                                    ctx.rotate(p.rotation * Math.PI / 180)
                                    ctx.strokeRect(-rrw/2, -rrh/2, rrw, rrh)
                                    ctx.restore()
                                } else {
                                    ctx.strokeRect(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, rrw, rrh)
                                }
                                break
                            }
                            case "rechteck_gefuellt": {
                                var rgw = ((p.x2||0)-(p.x1||0))*dw, rgh = ((p.y2||0)-(p.y1||0))*dh
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                if (p.rotation) {
                                    ctx.translate(dx+((p.x1||0)+(p.x2||0))/2*dw, dy+((p.y1||0)+(p.y2||0))/2*dh)
                                    ctx.rotate(p.rotation * Math.PI / 180)
                                    ctx.fillRect(-rgw/2, -rgh/2, rgw, rgh)
                                } else {
                                    ctx.fillRect(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, rgw, rgh)
                                }
                                ctx.restore()
                                break
                            }
                            case "kreis_offen":
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.1)*dw, 0, 2*Math.PI)
                                ctx.stroke()
                                break
                            case "kreis_gefuellt":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.04)*dw, 0, 2*Math.PI)
                                ctx.fill(); ctx.restore()
                                break
                            case "bogen": {
                                var ra = (p.winkel_von||0) * Math.PI/180
                                var re = (p.winkel_bis||90) * Math.PI/180
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.1)*dw,
                                        ra, re, p.bogen_gegen_uhrzeiger ? true : false)
                                ctx.stroke()
                                break
                            }
                            case "text":
                                // SYMBOL-TEXT-LESBAR-01: wird stattdessen in einem separaten
                                // aufrechten Pass gezeichnet, s. onPaint.
                                if (p.lesbar_halten) break
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.font = ((p.schrift_fett ? "bold " : "") +
                                            Math.round((p.schrift_relativ||0.15)*dh) + "px sans-serif")
                                ctx.textAlign    = p.text_align    || "center"
                                ctx.textBaseline = p.text_baseline || "middle"
                                if (p.rotation) {
                                    ctx.translate(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
                                    ctx.rotate(p.rotation * Math.PI / 180)
                                    ctx.fillText(p.text_inhalt||"?", 0, 0)
                                } else {
                                    ctx.fillText(p.text_inhalt||"?", dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
                                }
                                ctx.restore()
                                break
                            case "dreieck_gefuellt":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.beginPath()
                                ctx.moveTo(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
                                ctx.lineTo(dx+(p.x2||0)*dw, dy+(p.y2||0)*dh)
                                ctx.lineTo(dx+((p.x3||p.x1)||0)*dw, dy+((p.y3||p.y1)||0)*dh)
                                ctx.closePath(); ctx.fill(); ctx.restore()
                                break
                            }
                        }

                        // ── Maus-Interaktion ──────────────────────────
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            // Drag-Zustand (Auswahl-Werkzeug)
                            property bool dragAktiv:       false
                            property bool dragIstPin:      false
                            property bool dragBewegteSich: false
                            property var  dragStartNorm:   ({x: 0, y: 0})
                            property var  dragObjStart:    null
                            // Gruppen-Drag (Mehrfachauswahl, SE-MEHRFACHAUSWAHL-01)
                            property bool _gruppeAktiv:      false
                            property var  _gruppeBasisPrim:  []
                            property var  _gruppeBasisPins:  []
                            property var  _gruppePl:         []
                            property var  _gruppeNl:         []
                            property bool _rbBewegt:         false

                            // Pan-Zustand (mittlere Maustaste)
                            property bool _panAktiv:  false
                            property var  _panStart:  ({x: 0, y: 0})
                            property real _panStartX: 0
                            property real _panStartY: 0

                            function mausZuNorm(mx, my) {
                                var nx = (mx - zeichneCanvas.drawX) / zeichneCanvas.drawW
                                var ny = (my - zeichneCanvas.drawY) / zeichneCanvas.drawH
                                nx = Math.max(0, Math.min(1, root.snapX(nx)))
                                ny = Math.max(0, Math.min(1, root.snapY(ny)))
                                return {x: nx, y: ny}
                            }

                            // Wie mausZuNorm, aber ohne Raster/Begrenzung (Auswahlrahmen darf
                            // außerhalb des Symbols beginnen/enden, z. B. für „Schneiden")
                            function mausZuNormFrei(mx, my) {
                                return {x: (mx - zeichneCanvas.drawX) / zeichneCanvas.drawW,
                                        y: (my - zeichneCanvas.drawY) / zeichneCanvas.drawH}
                            }

                            onPressed: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) {
                                    _panAktiv  = true
                                    _panStart  = {x: mouse.x, y: mouse.y}
                                    _panStartX = root._sePanX
                                    _panStartY = root._sePanY
                                    return
                                }
                                _rbBewegt = false
                                if (root.aktivesWerkzeug !== "auswahl") return
                                if (mouse.button !== Qt.LeftButton) return
                                var nm = mausZuNorm(mouse.x, mouse.y)
                                var additiv = (mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier)) !== 0
                                var pi = root.treffePin(nm.x, nm.y)
                                var priIdx = pi >= 0 ? -1 : root.treffePrimitiv(nm.x, nm.y)

                                if (pi < 0 && priIdx < 0) {
                                    // Leere Fläche → Auswahlrahmen aufziehen
                                    root._rbBasisPrim = additiv ? root.auswahlPrimListe().slice() : []
                                    root._rbBasisPins = additiv ? root.auswahlPinListe().slice()  : []
                                    if (!additiv) root.setzeAuswahl([], [])
                                    root._rbA = mausZuNormFrei(mouse.x, mouse.y)
                                    root._rbB = root._rbA
                                    root._rbAktiv = true
                                    zeichneCanvas.requestPaint()
                                    return
                                }

                                // Treffer: Auswahl anpassen (Shift/Strg = umschalten, sonst ersetzen
                                // – außer das Element gehört schon zur Auswahl, dann bleibt sie bestehen)
                                var pl = root.auswahlPrimListe().slice(), nl = root.auswahlPinListe().slice()
                                var istSel = (pi >= 0) ? nl.indexOf(pi) >= 0 : pl.indexOf(priIdx) >= 0
                                if (additiv) {
                                    if (pi >= 0) nl = istSel ? nl.filter(function(v) { return v !== pi })     : nl.concat([pi])
                                    else         pl = istSel ? pl.filter(function(v) { return v !== priIdx }) : pl.concat([priIdx])
                                    root.setzeAuswahl(pl, nl)
                                    if (istSel) return          // gerade abgewählt → nicht ziehen
                                } else if (!istSel) {
                                    root.setzeAuswahl(priIdx >= 0 ? [priIdx] : [], pi >= 0 ? [pi] : [])
                                }
                                dragStartNorm = {x: nm.x, y: nm.y}
                                dragAktiv     = true
                                if (root.auswahlAnzahl >= 2) {
                                    // Gruppen-Drag: Stand bei Gestenbeginn merken
                                    _gruppeAktiv     = true
                                    _gruppeBasisPrim = root.primitive.slice()
                                    _gruppeBasisPins = root.pins.slice()
                                    _gruppePl        = root.auswahlPrimListe().slice()
                                    _gruppeNl        = root.auswahlPinListe().slice()
                                } else if (pi >= 0) {
                                    dragIstPin   = true
                                    dragObjStart = {x: root.pins[pi].x, y: root.pins[pi].y}
                                } else {
                                    dragIstPin   = false
                                    dragObjStart = Object.assign({}, root.primitive[priIdx])
                                }
                                zeichneCanvas.requestPaint()
                            }

                            onReleased: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) {
                                    _panAktiv = false
                                    return
                                }
                                if (root._rbAktiv) {
                                    root._rbAktiv = false
                                    if (_rbBewegt)
                                        root.rahmenAuswahlAnwenden(root._rbA, root._rbB, root._rbBasisPrim, root._rbBasisPins)
                                    else
                                        root.setzeAuswahl(root._rbBasisPrim, root._rbBasisPins)
                                    zeichneCanvas.requestPaint()
                                }
                                dragAktiv     = false
                                dragObjStart  = null
                                _gruppeAktiv  = false
                            }

                            onPositionChanged: function(mouse) {
                                if (_panAktiv) {
                                    root._sePanX = _panStartX + (mouse.x - _panStart.x)
                                    root._sePanY = _panStartY + (mouse.y - _panStart.y)
                                    zeichneCanvas.requestPaint()
                                    return
                                }
                                var nm = mausZuNorm(mouse.x, mouse.y)
                                root.mausNormPos  = nm
                                root.mausImCanvas = true

                                if (root._rbAktiv) {
                                    root._rbB = mausZuNormFrei(mouse.x, mouse.y)
                                    // erst ab ~4 px als Rahmen werten (sonst ist es ein einfacher Klick)
                                    var rbPx = Math.max(Math.abs(root._rbB.x - root._rbA.x) * zeichneCanvas.drawW,
                                                        Math.abs(root._rbB.y - root._rbA.y) * zeichneCanvas.drawH)
                                    if (rbPx > 4) _rbBewegt = true
                                    zeichneCanvas.requestPaint()
                                    return
                                }

                                if (dragAktiv && _gruppeAktiv) {
                                    // Versatz auf 0,5-mm-Raster runden (relative Geometrie der Auswahl bleibt erhalten)
                                    var gdx = Math.round((nm.x - dragStartNorm.x) * root.breiteMm * 2) / 2 / root.breiteMm
                                    var gdy = Math.round((nm.y - dragStartNorm.y) * root.hoeheMm  * 2) / 2 / root.hoeheMm
                                    if (!dragBewegteSich && (gdx !== 0 || gdy !== 0)) {
                                        root.pushUndoSnapshot()
                                        dragBewegteSich = true
                                    }
                                    if (dragBewegteSich)
                                        root.verschiebeAuswahlUm(_gruppeBasisPrim, _gruppeBasisPins, _gruppePl, _gruppeNl, gdx, gdy)
                                    return
                                }

                                if (dragAktiv && dragObjStart !== null) {
                                    // Snapshot einmalig beim ersten tatsächlichen Verschieben dieser
                                    // Drag-Geste (nicht bei jedem Mausereignis, sonst würde Strg+Z nur
                                    // einen winzigen Teilschritt zurücknehmen statt der ganzen Bewegung).
                                    if (!dragBewegteSich) root.pushUndoSnapshot()
                                    var ddx = nm.x - dragStartNorm.x
                                    var ddy = nm.y - dragStartNorm.y
                                    if (dragIstPin && root.ausgewaehltPinIdx >= 0) {
                                        var arrP = root.pins.slice()
                                        var pp   = Object.assign({}, arrP[root.ausgewaehltPinIdx])
                                        pp.x = Math.max(0, Math.min(1, root.snapX(dragObjStart.x + ddx)))
                                        pp.y = Math.max(0, Math.min(1, root.snapY(dragObjStart.y + ddy)))
                                        arrP[root.ausgewaehltPinIdx] = pp
                                        root.pins = arrP
                                        dragBewegteSich = true
                                    } else if (!dragIstPin && root.ausgewaehltPrimIdx >= 0) {
                                        var idx = root.ausgewaehltPrimIdx
                                        var arr = root.primitive.slice()
                                        var p   = Object.assign({}, arr[idx])
                                        var o   = dragObjStart
                                        p.x1 = Math.max(0, Math.min(1, root.snapX((o.x1 || 0) + ddx)))
                                        p.y1 = Math.max(0, Math.min(1, root.snapY((o.y1 || 0) + ddy)))
                                        if (p.typ === "linie" || p.typ === "rechteck" || p.typ === "rechteck_gefuellt") {
                                            p.x2 = Math.max(0, Math.min(1, root.snapX((o.x2 || 0) + ddx)))
                                            p.y2 = Math.max(0, Math.min(1, root.snapY((o.y2 || 0) + ddy)))
                                        }
                                        if (p.typ === "dreieck_gefuellt") {
                                            p.x2 = Math.max(0, Math.min(1, root.snapX((o.x2 || 0) + ddx)))
                                            p.y2 = Math.max(0, Math.min(1, root.snapY((o.y2 || 0) + ddy)))
                                            p.x3 = Math.max(0, Math.min(1, root.snapX((o.x3 || 0) + ddx)))
                                            p.y3 = Math.max(0, Math.min(1, root.snapY((o.y3 || 0) + ddy)))
                                        }
                                        arr[idx] = p
                                        root.primitive = arr
                                        dragBewegteSich = true
                                    }
                                }

                                zeichneCanvas.requestPaint()
                            }

                            onExited: {
                                root.mausImCanvas = false
                                zeichneCanvas.requestPaint()
                            }

                            onClicked: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) return
                                if (dragBewegteSich) { dragBewegteSich = false; return }
                                if (_rbBewegt) { _rbBewegt = false; root.forceActiveFocus(); return }
                                root.forceActiveFocus()
                                var nm = mausZuNorm(mouse.x, mouse.y)
                                var nx = nm.x, ny = nm.y

                                if (mouse.button === Qt.RightButton) {
                                    root.werkzeugPunkte = []
                                    zeichneCanvas.requestPaint()
                                    return
                                }

                                switch (root.aktivesWerkzeug) {
                                case "auswahl":
                                    // Auswahl wird seit SE-MEHRFACHAUSWAHL-01 vollständig in onPressed/onReleased gesetzt
                                    break

                                case "linie":
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else {
                                        root.addPrimitiv({typ:"linie",x1:root.werkzeugPunkte[0].x,y1:root.werkzeugPunkte[0].y,x2:nx,y2:ny,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break

                                case "rechteck":
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else {
                                        var rx1=Math.min(root.werkzeugPunkte[0].x,nx), ry1=Math.min(root.werkzeugPunkte[0].y,ny)
                                        var rx2=Math.max(root.werkzeugPunkte[0].x,nx), ry2=Math.max(root.werkzeugPunkte[0].y,ny)
                                        root.addPrimitiv({typ:(root.aktGefuellt?"rechteck_gefuellt":"rechteck"),x1:rx1,y1:ry1,x2:rx2,y2:ry2,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break

                                case "kreis_offen": {
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else {
                                        var kdw = zeichneCanvas.drawW, kdh = zeichneCanvas.drawH
                                        var krad = Math.sqrt(Math.pow((nx-root.werkzeugPunkte[0].x)*kdw, 2) + Math.pow((ny-root.werkzeugPunkte[0].y)*kdh, 2)) / kdw
                                        root.addPrimitiv({typ:(root.aktGefuellt?"kreis_gefuellt":"kreis_offen"),x1:root.werkzeugPunkte[0].x,y1:root.werkzeugPunkte[0].y,radius:krad,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break
                                }

                                case "bogen":
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else if (root.werkzeugPunkte.length === 1) {
                                        root.werkzeugPunkte = root.werkzeugPunkte.concat([{x:nx,y:ny}])
                                    } else {
                                        var bdw = zeichneCanvas.drawW, bdh = zeichneCanvas.drawH
                                        var bcx = root.werkzeugPunkte[0].x, bcy = root.werkzeugPunkte[0].y
                                        var bRad2 = Math.sqrt(Math.pow((root.werkzeugPunkte[1].x-bcx)*bdw, 2) + Math.pow((root.werkzeugPunkte[1].y-bcy)*bdh, 2)) / bdw
                                        var bWv = Math.atan2((root.werkzeugPunkte[1].y-bcy)*bdh,(root.werkzeugPunkte[1].x-bcx)*bdw)*180/Math.PI
                                        var bWb = Math.atan2((ny-bcy)*bdh,(nx-bcx)*bdw)*180/Math.PI
                                        if (bWv < 0) bWv += 360; if (bWb < 0) bWb += 360
                                        root.addPrimitiv({typ:"bogen",x1:bcx,y1:bcy,radius:bRad2,winkel_von:bWv,winkel_bis:bWb,bogen_gegen_uhrzeiger:false,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break

                                case "punkt":
                                    // Feste absolute Größe statt relativ zu breiteMm (vorher 0.04
                                    // normiert -> 0,64mm bei 16mm-Symbol, aber 4,16mm bei einem
                                    // 104mm-Symbol wie Arduino Mega) - radius bleibt im Schema
                                    // relativ zu breite_mm gespeichert (Konvention aller Renderer),
                                    // daher hier umgekehrt aus der gewünschten mm-Größe berechnet.
                                    root.addPrimitiv({typ:"kreis_gefuellt",x1:nx,y1:ny,radius:root._punktRadiusMm/root.breiteMm,linienart:"solid"})
                                    break

                                case "text":
                                    root.textEingabePos = {x:nx,y:ny}
                                    textEingabeDialog.open()
                                    break

                                case "pin":
                                    root.addPin(nx, ny)
                                    break
                                }
                            }
                        }
                    } // Canvas

                    // Scroll-Zoom (Mausrad zoomt auf Cursor-Position)
                    WheelHandler {
                        onWheel: function(event) {
                            var dy = event.angleDelta.y !== 0 ? event.angleDelta.y
                                                              : event.pixelDelta.y * 4
                            if (Math.abs(dy) < 1) { event.accepted = false; return }
                            var factor   = Math.pow(1.001, dy)
                            var newZoom  = Math.max(0.15, Math.min(8.0, root._seZoom * factor))
                            var scale    = newZoom / root._seZoom
                            var newDrawW = zeichneCanvas.drawW * scale
                            var newDrawH = zeichneCanvas.drawH * scale
                            var newDrawX = event.x - (event.x - zeichneCanvas.drawX) * scale
                            var newDrawY = event.y - (event.y - zeichneCanvas.drawY) * scale
                            root._sePanX = newDrawX - (zeichneCanvas.width  - newDrawW) / 2
                            root._sePanY = newDrawY - (zeichneCanvas.height - newDrawH) / 2
                            root._seZoom = newZoom
                            zeichneCanvas.requestPaint()
                            event.accepted = true
                        }
                    }

                    // Vorschau-Drehung (SYMBOL-TEXT-LESBAR-01-Folge, oben links): rein
                    // visuelle Kontrolle, ob Primitive/Text bei allen 4 Symbol-Rotationen +
                    // Spiegelungen noch in die Box passen - ändert keine gespeicherten Daten.
                    Row {
                        anchors { top: parent.top; left: parent.left; topMargin: 4; leftMargin: 6 }
                        spacing: 3

                        Text {
                            text: qsTr("Vorschau:")
                            color: root.theme.textMuted; font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                            rightPadding: 3
                        }

                        Repeater {
                            model: [0, 90, 180, 270]
                            Button {
                                required property int modelData
                                text: modelData + "°"
                                flat: true; checkable: true; implicitWidth: 32; implicitHeight: 24
                                checked: root._sePreviewRotation === modelData
                                ToolTip.text: qsTr("Symbol in der Vorschau um %1° drehen").arg(modelData)
                                ToolTip.visible: hovered; ToolTip.delay: 500
                                onClicked: {
                                    root._sePreviewRotation = modelData
                                    zeichneCanvas.requestPaint()
                                }
                                contentItem: Text {
                                    text: parent.text; font.pixelSize: 10
                                    color: parent.checked ? root.theme.accent : root.theme.textMuted
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: parent.checked ? root.theme.hover : "transparent"
                                    radius: 4; border.color: root.theme.border
                                }
                            }
                        }
                        Button {
                            text: qsTr("↔ H"); flat: true; checkable: true; implicitWidth: 42; implicitHeight: 24
                            checked: root._sePreviewSpiegelX
                            ToolTip.text: qsTr("Vorschau horizontal spiegeln"); ToolTip.visible: hovered; ToolTip.delay: 500
                            onClicked: { root._sePreviewSpiegelX = checked; zeichneCanvas.requestPaint() }
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 10
                                color: parent.checked ? root.theme.accent : root.theme.textMuted
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.checked ? root.theme.hover : "transparent"
                                radius: 4; border.color: root.theme.border
                            }
                        }
                        Button {
                            text: qsTr("↕ V"); flat: true; checkable: true; implicitWidth: 42; implicitHeight: 24
                            checked: root._sePreviewSpiegelY
                            ToolTip.text: qsTr("Vorschau vertikal spiegeln"); ToolTip.visible: hovered; ToolTip.delay: 500
                            onClicked: { root._sePreviewSpiegelY = checked; zeichneCanvas.requestPaint() }
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 10
                                color: parent.checked ? root.theme.accent : root.theme.textMuted
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.checked ? root.theme.hover : "transparent"
                                radius: 4; border.color: root.theme.border
                            }
                        }
                    }

                    // Zoom-Steuerung (oben rechts, analog zu CanvasHeaderBar)
                    Row {
                        anchors { top: parent.top; right: parent.right; topMargin: 4; rightMargin: 6 }
                        spacing: 0

                        Button {
                            text: qsTr("−"); flat: true; implicitWidth: 26; implicitHeight: 26
                            contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4 }
                            onClicked: {
                                var s = Math.max(0.15, root._seZoom / 1.25) / root._seZoom
                                root._sePanX = root._sePanX * s; root._sePanY = root._sePanY * s
                                root._seZoom = Math.max(0.15, root._seZoom / 1.25)
                                zeichneCanvas.requestPaint()
                            }
                        }
                        Text {
                            text: Math.round(root._seZoom * 100) + "%"
                            color: root.theme.accent; font.pixelSize: 12; font.weight: Font.Medium
                            leftPadding: 2; rightPadding: 2
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root._seZoom = 1.0; root._sePanX = 0.0; root._sePanY = 0.0
                                    zeichneCanvas.requestPaint()
                                }
                            }
                        }
                        Button {
                            text: "+"; flat: true; implicitWidth: 26; implicitHeight: 26
                            contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4 }
                            onClicked: {
                                var s = Math.min(8.0, root._seZoom * 1.25) / root._seZoom
                                root._sePanX = root._sePanX * s; root._sePanY = root._sePanY * s
                                root._seZoom = Math.min(8.0, root._seZoom * 1.25)
                                zeichneCanvas.requestPaint()
                            }
                        }
                    }

                    // Koordinaten-Anzeige
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                        color: "#80000018"; radius: 3
                        width: koordinatenLbl.implicitWidth + 22; height: 30
                        Text {
                            id: koordinatenLbl
                            anchors.centerIn: parent
                            text: root.mausImCanvas
                                  ? "x: " + root.normToMmX(root.mausNormPos.x).toFixed(1) + " mm   y: " + root.normToMmY(root.mausNormPos.y).toFixed(1) + " mm"
                                  : ""
                            font.pixelSize: 13; color: "#aabbcc"
                        }
                    }

                    // Werkzeug-Status
                    Rectangle {
                        anchors { bottom: parent.bottom; right: parent.right; margins: 6 }
                        color: "#80000018"; radius: 3
                        width: werkzeugStatusLbl.implicitWidth + 12; height: 20
                        visible: root.werkzeugPunkte.length > 0
                        Text {
                            id: werkzeugStatusLbl
                            anchors.centerIn: parent
                            text: {
                                switch (root.aktivesWerkzeug) {
                                case "linie":
                                case "rechteck":
                                case "kreis_offen": return qsTr("Endpunkt klicken")
                                case "bogen":
                                    if (root.werkzeugPunkte.length === 1) return qsTr("Startwinkel klicken")
                                    return qsTr("Endwinkel klicken")
                                default: return ""
                                }
                            }
                            font.pixelSize: 11; color: "#ffcc66"
                        }
                    }
                } // Zeichenfläche

                Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.sidebar }


                // ── Eigenschaften-Panel ───────────────────────────────
                SeEigenschaftenPanel {
                    editor: root
                    Layout.fillHeight: true
                }
            } // inner RowLayout

            // ── Pin-Liste ──────────────────────────────────────────────
            SePinListe {
                editor: root
                SplitView.preferredHeight: 190
                SplitView.minimumHeight:   80
            }
            } // SplitView
        } // ColumnLayout
    } // outer RowLayout

    DebugLabel { panelName: qsTr("Symbol-Editor"); visible: root.debug }
}
