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
    property string steckRolleText: ""   // SYM-STECKKONTAKT-01: "" | "stecker" | "buchse"
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
            seDialoge.verwerfenFragen()
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
            steckRolleText = vInfo.steckRolle || ""
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
                    rolle:     vp.rolle || "",
                    steckkontakt: vp.steckkontakt === true
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
            steckRolleText = ""
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
            steckRolleText = info.steckRolle || ""
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
                    rolle:     p.rolle || "",
                    steckkontakt: p.steckkontakt === true
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
                seDialoge.speichernFehlerZeigen(qsTr("Pin-Name «%1» ist mehrfach vergeben. Bitte eindeutige Namen verwenden.").arg(pname))
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
                seDialoge.speichernFehlerZeigen(qsTr("Symbol-ID bereits vergeben. Bitte anderen Namen wählen."))
                return
            }
        } else {
            symbolDefinitionModel.symbolAktualisieren(sid, nameText, kategorieText, breiteMm, hoeheMm, rolleText, bmkSeiteText, pinSchriftMm)
        }
        symbolDefinitionModel.steckRolleSetzen(sid, steckRolleText)
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
    function textEingabeOeffnen(nx, ny) { seDialoge.textEingabeOeffnen(nx, ny) }
    // ── Dialoge ────────────────────────────────────────────────────

    SeDialoge {
        id:    seDialoge
        theme: root.theme

        onTextBestaetigt: function(text, fett, x, y) {
            root.addPrimitiv({typ: "text", x1: x, y1: y,
                text_inhalt: text, schrift_relativ: 0.15,
                schrift_fett: fett, text_align: "center", text_baseline: "middle",
                linienart: "solid"})
        }
        onLoeschenBestaetigt: function(symbolId) {
            if (root.editSymbolId === symbolId || root.aktiveListenId === symbolId) {
                root.editSymbolId   = ""
                root.vorlageId      = ""
                root.aktiveListenId = ""
                root.ladeDaten()
            }
            symbolDefinitionModel.symbolLoeschen(symbolId)
            root.symbollisteAktualisieren()
        }
        // SE-UNGESPEICHERT-WARNUNG-01 (Rückfrage in SeDialoge): s. verwerfenUndFortfahren().
        onVerwerfenBestaetigt: {
            var aktion = root._ausstehendeAktion
            root._ausstehendeAktion = null
            if (aktion) aktion()
        }
        onVerwerfenAbgelehnt: root._ausstehendeAktion = null
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
                seDialoge.loeschenFragen(sid, sname)
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

                    SeZeichenCanvas {
                        id:     zeichneCanvas
                        editor: root
                    }

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

                    SeZeichenflaechenOverlay {
                        editor: root
                        canvas: zeichneCanvas
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
