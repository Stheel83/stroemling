import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "components"
import "canvas"
import "SymbolKlassen.js" as SK

Item {
    id: root
    focus: true          // Tastatureingaben landen hier wenn forceActiveFocus() gerufen wurde
    activeFocusOnTab: false  // Canvas nicht in Tab-Fokus-Reihenfolge

    // Tab-Rotation VOR Platzierung: Keys statt Shortcut, weil Qt Tab
    // vor Shortcuts an das Fokus-System weitergibt.
    Keys.onTabPressed: {
        if (root.aktivesWerkzeug === "symbol" && root.paletteSymbolId !== "") {
            root.paletteSymbolRotation = (root.paletteSymbolRotation + 90) % 360
            root.vorschau = root.symbolVorschauErstellen(root.letzteMausWeltX, root.letzteMausWeltY)
            drawCanvas.requestPaint()
        }
        event.accepted = true
    }
    // --------------------------------------------------------
    // Öffentliche Properties
    // --------------------------------------------------------
    property int    seiteId:          -1
    property int    projektId:        -1
    property string seiteName:        ""
    property string hintergrundFarbe: "#fdf8e8"

    required property var theme
    property bool debug: false
    onDebugChanged: drawCanvas.requestPaint()
    required property var elementeModel

    signal hintergrundGeaendert(string farbe)
    signal querverweisNavigieren(int seiteId)
    signal gkSprungAngefordert(int seiteId, string blattnr, string seiteBez, real wx, real wy)
    signal klemmeImSeitenBaumAnzeigen(int klemmeId, string anschlussBezeichnung)
    signal kabelImSeitenBaumAnzeigen(int kabelId)
    signal geraetekastenImSeitenBaumAnzeigen(int gkId, string gkBmk)
    signal makroListeGeaendert()

    function bmElementSprungAnfordern(seiteId, blattnr, seiteBez, wx, wy) {
        gkSprungAngefordert(seiteId, blattnr, seiteBez, wx, wy)
    }
    signal drcKlick()
    signal suchKlick()

    property bool drcAktiv:  false
    property bool suchAktiv: false

    property real zoom:    1.0
    property real minZoom: 0.1
    property real maxZoom: 8.0

    property real worldX: 0
    property real worldY: 0

    // Wird von CanvasNavigationHandler während Pan/Zoom gesetzt.
    // Solange true überspringt maleElement alle fillText/strokeText-Aufrufe (LOD).
    property bool bewegungAktiv: false

    property var  _zoomPanCache:   ({})  // seiteId → {zoom, worldX, worldY}
    property int  _vorherSeiteId:  -1    // seiteId vor dem letzten Seitenwechsel

    property string revisionStatus:  ""  // '', 'entwurf', 'freigegeben', 'veraltet'
    property string revisionKennung: ""  // z.B. "A", "B", "1.0"

    property real gridMm:  4.0
    property real mmToPx:  4.0
    property bool rastend: true

    property var    normblattDaten:   null
    property string normblattLogoUrl: ""

    property bool minimapSichtbar: false

    onNormblattLogoUrlChanged: {
        if (normblattLogoUrl)
            drawCanvas.loadImage(normblattLogoUrl)
    }

    readonly property real gridPx: gridMm * mmToPx

    // --------------------------------------------------------
    // Werkzeug-State
    // --------------------------------------------------------
    property string aktivesWerkzeug: "zeiger"

    // Symbol-Werkzeug: ID des aus der Palette gewählten Symbols
    property string paletteSymbolId:          ""
    property int    paletteSymbolRotation:    0    // 0 / 90 / 180 / 270 – Vorab-Rotation beim Platzieren
    property var    paletteExtraDaten:        ({})  // Extra-Daten für das nächste platzierte Symbol
    property int    paletteBetriebsmittelId:  0    // >0: Symbol wird nach Platzierung mit BM verknüpft
    property int    _bmkBauteilId:           0    // bauteilId aus paletteExtraDaten – für BM-Anlegen
    property real   letzteMausWeltX:          0
    property real   letzteMausWeltY:          0

    onPaletteSymbolIdChanged: {
        paletteSymbolRotation   = 0
        paletteExtraDaten       = {}
        paletteBetriebsmittelId = 0
    }

    // Bild-Werkzeug: Base64-Data-URL des gewählten Bildes (leer = kein Bild geladen)
    property string paletteImageData: ""

    // Makro-Einfügen-Modus
    property int    makroEinfuegenId:       0
    property string makroEinfuegenName:     ""
    property var    makroVorschauElemente:  []

    onMakroEinfuegenIdChanged: {
        makroVorschauElemente = (makroEinfuegenId > 0)
            ? db.makroElementeVorschau(makroEinfuegenId)
            : []
    }

    // Duplizieren-Modus (Ctrl+D) und Einfügen-Modus (Ctrl+V)
    property var  duplizierVorlage:   null  // Quell-Elemente
    property var  duplizierVorschau:  null  // verschobene Kopien für die Vorschau
    property real duplizierOffsetX:   0     // Versatz beim ersten Klick
    property real duplizierOffsetY:   0
    property bool duplizierMitDialog: true  // false = Einfügen (kein Anzahl-Dialog)

    // COPY-CROSS-01: nach Cross-Projekt-Einfügen (Quelle = anderes Projekt)
    // wird nach dem Platzieren ein "Als Makro behalten?"-Hinweis angeboten.
    property bool _nachEinfuegenMakroAnbieten: false
    property var  _crossProjektBbox: null  // { x1, y1, x2, y2 } der frisch eingefügten Elemente

    onAktivesWerkzeugChanged: {
        if (aktivesWerkzeug !== "bild") root.paletteImageData = ""
    }

    // Klemmen-Highlight (KLEMME-HL-01): beim Anklicken eines klemme_anschluss
    // werden alle Anschlüsse derselben Klemme auf der Seite hervorgehoben.
    property bool _klemmeHlAktiv:  true
    property int  _hlKlemmeId:     -1
    function setKlemmeHlAktiv(v) { _klemmeHlAktiv = v; klemmeHlSettings.aktiv = v }
    Settings {
        id:       klemmeHlSettings
        category: "ep_panel"
        property bool aktiv: true
        Component.onCompleted: root._klemmeHlAktiv = aktiv
    }

    // Auswahl & Verschieben (Zeiger-Werkzeug)
    property var  auswahl:             []     // Indizes aller selektierten Elemente
    onAuswahlChanged: {
        // Re-focus canvas after EP becomes visible (EP's ScrollView can grab focus synchronously)
        if (root.auswahl.length > 0 && !root.textEditAktiv)
            Qt.callLater(function() { root.forceActiveFocus() })
        // Highlight gleiche Klemme (KLEMME-HL-01)
        if (root._klemmeHlAktiv && root.auswahl.length === 1) {
            var _hlEl = root.elementeModel.element(root.auswahl[0])
            if (_hlEl && _hlEl.typ === "symbol" && _hlEl.symbolId === "klemme_anschluss") {
                var _hlEd = _hlEl.extraDaten || {}
                var _hlKId = (_hlEd.klemmeId !== undefined) ? _hlEd.klemmeId : -1
                // Per-Leiste-Override: wenn klemmenreiheModel die passende Leiste geladen hat,
                // highlightOverride=0 deaktiviert Highlight für diese Leiste.
                var _override = null
                if (klemmenreiheModel.hatLeiste) {
                    var _kl = klemmenreiheModel.klemmen
                    for (var _ki = 0; _ki < _kl.length; _ki++) {
                        if (_kl[_ki].klemmeId === _hlKId) {
                            _override = klemmenreiheModel.leiste["highlightOverride"]
                            break
                        }
                    }
                }
                root._hlKlemmeId = (_override === 0) ? -1 : _hlKId
            } else {
                root._hlKlemmeId = -1
            }
        } else {
            root._hlKlemmeId = -1
        }
    }
    // Compat-Alias: -1 wenn Mehrfachauswahl, sonst der einzelne Index
    readonly property int ausgewaehlt:        auswahl.length === 1 ? auswahl[0] : -1
    readonly property int auswahlLaenge:      auswahl.length
    readonly property int symbolAuswahlAnzahl: {
        var sel = auswahl; var cnt = 0
        for (var i = 0; i < sel.length; i++) {
            var el = elementeModel.element(sel[i])
            if (el && el.typ === "symbol") cnt++
        }
        return cnt
    }
    onAusgewaehltChanged: Qt.callLater(autoPanFuerAuswahl)
    property bool amVerschieben:       false
    property real verschiebenMausVpX:  0
    property real verschiebenMausVpY:  0
    property real verschiebenStartX1:  0      // Legacy (Handle-Drag + Einzel-Move)
    property real verschiebenStartY1:  0
    property real verschiebenStartX2:  0
    property real verschiebenStartY2:  0
    property var  verschiebenStartPos: null   // Array {x1,y1,x2,y2} für Multi-Move
    property var  schnapshotVorMove:   null   // elemente-Kopie vor dem Drag
    property bool mausUeberElement:    false  // für Cursor-Wechsel
    property int  aktiverGriff:        -1     // Handle-Index der gezogen wird (-1 = keiner)
    property bool mausUeberGriff:      false  // Maus über einem Handle
    property bool   verschiebenErlaubt:  false  // nur true wenn auf bereits-selektiertes Element geklickt
    property string axisLock:            ""     // "" | "x" | "y" — Shift+Drag-Constraint
    // Querverweis-Navigation: Index (elementIdx) → Blattnummer der Gegenseite
    property var  _querverweisPartnerMap: ({})
    // Kabellinien: kabelId → Gesamtzahl aller Linien dieses Kabels (seitenübergreifend)
    property var  _kabelLinienCache: ({})
    // HF-Referenz: betriebsmittelId → {hauptElementId, blattnummer, seiteId}
    property var  _hfReferenzMap: ({})
    // Pending-Zielposition nach seitenübergreifender QV-Navigation
    property var  _querverweisZielPos:      null
    // Pending-Auto-Weiterverfolgen: BFS direkt nach Seitenladem starten
    property int  _fehlersuchAutoStartId:   -1
    // Rubber-Band Mehrfachauswahl
    property bool amRubberband:        false
    property real rubberbandVpX:       0
    property real rubberbandVpY:       0
    property var  rubberbandRect:      null   // { x1,y1,x2,y2 } Viewport-Koordinaten
    // Zwischenablage (Slot 0 = Ctrl+C/V, Slots 1-4 = Ctrl+Shift+1-4 / Ctrl+1-4)
    property var  zwischenablage:      []
    property var  zwischenablagen:     [[], [], [], [], []]

    // Verbindungsauswahl: angeklickte Auto-Verbindung (null = keine)
    // { netKey, verbindungId, bezeichnung, signaltyp, segmente, adps, x1,y1,x2,y2 }
    property var ausgewaehltVerbindung: null

    function aderFarbeZuCanvas(code) { return geometrieHandler.aderFarbeZuCanvas(code) }
    // Cache der DB-Annotationen: netKey → {verbindungId, bezeichnung, farbe, querschnitt_mm2, signaltyp}
    property var verbindungAnnotationenCache: ({})
    // OPT-KABEL-GEO-01: Netz-Geometrie-Cache (invalidiert bei elementeModel.geaendert)
    property var _cachedNetze:        null   // autoNetzeBerechnen()-Ergebnis
    property var _cachedKabelSchnitte: ({})  // elId → schnitte[]

    // --------------------------------------------------------
    // Text-Werkzeug: Inline-Editor
    // --------------------------------------------------------
    property bool textEditAktiv:    false   // Overlay sichtbar
    property real textEditVpX:      0       // Viewport-Position der linken oberen Ecke
    property real textEditVpY:      0
    property real textEditWeltX:    0       // Weltkoordinaten des Ankerpunkts
    property real textEditWeltY:    0
    property int  textEditElIdx:    -1      // -1 = neues Element, ≥0 = vorhandenes editieren
    property var  textEditSnapshot: null    // Snapshot vor dem Editieren (Undo-Basis)


    // Rubber-Band-Vorschau (Zeichnen)
    property var  vorschau:      null
    property bool amZeichnen:    false
    property real zeichenStartX: 0
    property real zeichenStartY: 0

    // Polygonlinie-Zeichenmodus
    property var  polyPunkte:     []    // bisher geklickte Punkte (Weltkoordinaten)
    property bool amPolyZeichnen: false // Multi-Klick-Modus aktiv
    property var  polyCursorWelt: null  // aktueller Cursor für Live-Vorschausegment

    // Stilvorlage für neue Elemente
    property var stilVorlage: ({
        strichFarbe:    "#4a9eff",
        strichBreite:   1.5,
        strichArt:      "solid",
        fuell:          false,
        fuellFarbe:     "#1a3a6a",
        fuellOpazitaet: 0.3,
        opazitaet:      1.0,
        eckenRadius:    0,
        schriftgroesse: 3.5
    })

    // Format-Pinsel: gespeichertes Stilformat (null = noch nichts kopiert)
    property var _formatVorlage: null
    property int formatZaehler:  0    // zählt jedes formatKopieren(); als Proxy in EigenschaftenPanel reaktiv

    // Label-Drag: Beschriftung eines Symbols verschieben
    property bool labelDragAktiv:    false
    property int  labelDragIdx:      -1
    property real labelDragMausVpX:  0.0
    property real labelDragMausVpY:  0.0
    property real labelDragStartOx:  0.0
    property real labelDragStartOy:  0.0
    property bool mausUeberLabel:    false
    property bool mausUeberAderKreuzung: false  // Hover über klickbarer Ader-Nr. an Kabel-Kreuzung

    // ── Inbetriebnahme-Modus ─────────────────────────────────
    property bool ibnModus:    false
    property var  ibnStatusMap:    ({})   // bmk → "offen"|"in_arbeit"|"abgeschlossen"
    property var  _spsKonfliktSet: ({})   // elementId → true  (mehr als 1 Kanal zugewiesen)

    // ── Fehlersuchmodus ──────────────────────────────────────
    property bool fehlersuchModus:           false
    property var  fehlersuchPfadIds:         ({})  // elementId → pfadNr (int, 0-indexed)
    property int  fehlersuchStartId:         -1    // zuletzt gestarteter Pfad (für §8.6 History)
    property var  fehlersuchStartIds:        []    // startElementId je Pfad (Index = pfadNr)
    property var  fehlersuchQuerverweise:    []    // [{x, y, bezeichnung, ...}]
    property var  fehlersuchUnterbrechungen: ({})  // elementId → bmk-String (Trenner)

    // Farbpalette für Parallelpfade (pfadNr 0 = accent, 1 = orange, …)
    readonly property var _fehlersuchPfadFarben: [
        theme.accent, "#e08030", "#30c060", "#c030c0", "#30c0c0"
    ]

    // Aliases damit CanvasAktionenHandler auf interne IDs zugreifen kann
    property alias _drawCanvas:    drawCanvas
    property alias _duplizierDialog: duplizierAnzahlDialog
    property alias _dialogLayer: dialogLayer

    signal fehlersuchPfadGefunden(var querverweise)

    function fehlersuchPfadZuruecksetzen() { fehlersuchHandler.fehlersuchPfadZuruecksetzen() }
    function fehlersuchPfadBerechnen(startElementId, addierZuPfad) { fehlersuchHandler.fehlersuchPfadBerechnen(startElementId, addierZuPfad) }

    CanvasFehlersuchHandler { id: fehlersuchHandler; cv: root }

    function zentriereAuf(wx, wy) {
        root.worldX = wx - (drawCanvas.width  / (2 * root.zoom * root.mmToPx))
        root.worldY = wy - (drawCanvas.height / (2 * root.zoom * root.mmToPx))
        drawCanvas.requestPaint()
    }

    function neuZeichnen() { drawCanvas.requestPaint() }

    // Prüft ob das Element mit Index idx an einer "logischen" Auto-Verbindung
    // teilnimmt (Querverweis-Brücke, Klemmen-Durchleitung oder Stecker/Buchse
    // Pin-2-Kopplung). Für EP-Statusanzeige (z.B. "Verbunden"-Badge bei Pin 2).
    function hatLogischeVerbindung(idx) {
        if (idx < 0) return false
        var netze = netzHandler.autoNetzeBerechnenCached()
        for (var n = 0; n < netze.length; n++) {
            var segs = netze[n].segmente
            for (var s = 0; s < segs.length; s++) {
                var sg = segs[s]
                if (sg.logisch && (sg.elIdxA === idx || sg.elIdxB === idx)) return true
            }
        }
        return false
    }

    // Brücken-Funktionen für CanvasInteraktionArea
    function verbindungBeiPosition(x, y)   { return geometrieHandler.verbindungBeiPosition(x, y) }
    function kabelKreuzungBeiPosition(x, y) { return geometrieHandler.kabelKreuzungBeiPosition(x, y) }
    function koordinatenTextSetzen(text)   { footerBar.koordinatenText = text }
    function bildLaden(url)                { drawCanvas.loadImage(url) }

    function textEditorNeuOeffnen(vpX, vpY, weltX, weltY) {
        root.textEditVpX      = vpX;  root.textEditVpY  = vpY
        root.textEditWeltX    = weltX; root.textEditWeltY = weltY
        root.textEditElIdx    = -1
        root.textEditSnapshot = elementeModel.snapshot()
        root.textEditAktiv    = true
        textEditorKomp.oeffnen("", false)
    }
    function textEditorBestehendesOeffnen(idx) {
        var el = elementeModel.element(idx)
        root.auswahl          = [idx]
        root.textEditWeltX    = el.x1;  root.textEditWeltY = el.y1
        var vpos              = geometrieHandler.weltZuViewport(el.x1, el.y1)
        root.textEditVpX      = vpos.x; root.textEditVpY   = vpos.y
        root.textEditElIdx    = idx
        root.textEditSnapshot = elementeModel.snapshot()
        root.textEditAktiv    = true
        textEditorKomp.oeffnen(el.textInhalt || "", true)
    }
    function kabellinieDialogFuerNeuOeffnen(elIdx) { dialogLayer.kabellinieNeuOeffnen(elIdx) }
    function makrobenennDialogFuerNeuOeffnen(elIdx) { dialogLayer.makrobenennNeuOeffnen(elIdx) }
    function crossProjektEinfuegenDialogOeffnen()   { dialogLayer.crossProjektEinfuegenOeffnen() }

    // Aderzuordnungsdialog vorbereiten (drawCanvas-Zugriffe bleiben hier) und öffnen
    function kabellinieNachSpeichernAderZuordnung(newKabelId, bezeichnung, kabeltyp, aderzahl, bkAdern, freshKlEl) {
        var neueNetze = netzHandler.autoNetzeBerechnen()
        var schnitte  = geometrieHandler.kabelSchnittNetzeBerechnen(freshKlEl, neueNetze)
        if (schnitte.length > 0) {
            dialogLayer.aderzuordnungOeffnen(
                newKabelId, bezeichnung, kabeltyp, aderzahl, bkAdern,
                schnitte, {}, freshKlEl.id || 0, cacheHandler._pinNummernFuerNetze(neueNetze))
        }
    }

    // --------------------------------------------------------
    // Hintergrund
    // --------------------------------------------------------
    Rectangle { anchors.fill: parent; color: root.hintergrundFarbe }

    // --------------------------------------------------------
    // Gitter
    // --------------------------------------------------------
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: root.seiteId >= 0

        // Raster neu zeichnen wenn Hintergrundfarbe wechselt
        Connections {
            target: root
            function onHintergrundFarbeChanged() { gridCanvas.requestPaint() }
        }

        // Bestimmt ob der Hintergrund hell ist (für adaptive Rasterfarben)
        function istHell() {
            var f = root.hintergrundFarbe
            if (f.length < 7) return false
            var r = parseInt(f.substr(1,2),16), g = parseInt(f.substr(3,2),16), b = parseInt(f.substr(5,2),16)
            return (0.299*r + 0.587*g + 0.114*b) > 128
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var step = root.gridPx * root.zoom
            while (step < 10) step *= 2
            var ox = ((root.worldX % step) + step) % step
            var oy = ((root.worldY % step) + step) % step
            var hell = istHell()
            ctx.strokeStyle = hell ? (root.rastend ? "rgba(0,0,0,0.12)" : "rgba(0,0,0,0.08)")
                                   : (root.rastend ? "#0e2840" : "#0d2035")
            ctx.lineWidth   = 0.5
            ctx.beginPath()
            for (var x = ox; x <= width + 1; x += step) {
                var px = Math.round(x) + 0.5; ctx.moveTo(px, 0); ctx.lineTo(px, height)
            }
            for (var y = oy; y <= height + 1; y += step) {
                var py = Math.round(y) + 0.5; ctx.moveTo(0, py); ctx.lineTo(width, py)
            }
            ctx.stroke()
            ctx.strokeStyle = hell ? "rgba(0,0,0,0.2)" : "#1a3a6a"
            ctx.lineWidth = 1.0; ctx.beginPath()
            var wx = Math.round(root.worldX) + 0.5
            var wy = Math.round(root.worldY) + 0.5
            if (wx >= 0 && wx <= width)  { ctx.moveTo(wx, 0); ctx.lineTo(wx, height) }
            if (wy >= 0 && wy <= height) { ctx.moveTo(0, wy); ctx.lineTo(width, wy)  }
            ctx.stroke()
        }
    }

    // Aktionslogik ausgelagert (Undo/Redo, Clipboard, Ausrichten, …)
    CanvasAktionenHandler { id: aktionenHandler; cv: root }

    // Elektrische Netzberechnung ausgelagert (REFACTOR-01 Stufe 2)
    CanvasNetzberechnung { id: netzHandler; cv: root }
    property alias netzberechnung: netzHandler

    // Geometrie/Hit-Test-Funktionen ausgelagert (REFACTOR-01 Stufe 3)
    CanvasGeometrie { id: geometrieHandler; cv: root }
    property alias geometrie: geometrieHandler

    // Render-Helferfunktionen ausgelagert (REFACTOR-01 Stufe 5a).
    // _renderSymbol bleibt vorerst in drawCanvas (Stufe 5b).
    CanvasRenderHandler { id: renderHandler; cv: root }

    // --------------------------------------------------------
    // Zeichenebene
    // --------------------------------------------------------
    Canvas {
        id: drawCanvas
        renderTarget: Canvas.FramebufferObject
        anchors.fill: parent
        visible: root.seiteId >= 0

        // Vorab gefilterte Gerätekasten-Liste — wird in onPaint einmalig aus dem Snapshot
        // gebaut und im GA-Rendering-Block genutzt (verhindert O(n²) snapshot()-Aufrufe)
        property var _gkListe: []

        // Wenn ein Bild asynchron fertig geladen ist → neu zeichnen
        onImageLoaded: drawCanvas.requestPaint()

        Connections {
            target: elementeModel
            function onGeaendert() {
                root._cachedNetze = null
                root._cachedKabelSchnitte = {}
                drawCanvas.requestPaint()
            }
        }

        // ── Generischer Primitiv-Renderer (Phase B Symboleditor) ──────
        // Zeichnet Erweiterungsmodifier über dem Grundsymbol im lokalen Koordinatensystem
        // (0..w × 0..h, nach Rotation/Spiegelung des Symbols transformiert).
        function maleModifier(ctx, erweiterungen, w, h) {
            if (!erweiterungen || erweiterungen.length === 0) return
            ctx.save()
            ctx.setLineDash([])
            ctx.lineWidth = Math.max(1.0, h * 0.055)

            for (var ei = 0; ei < erweiterungen.length; ei++) {
                var ew = erweiterungen[ei]

                if (ew === "zeit_an") {
                    // Anzugsverzögert: ∩-Bogen (öffnet nach unten) + kleines Rechteck
                    ctx.beginPath()
                    ctx.arc(w * 0.5, h * 0.22, h * 0.10, Math.PI, 0, false) // ∩
                    ctx.stroke()
                    ctx.strokeRect(w * 0.44, h * 0.04, w * 0.12, h * 0.09)

                } else if (ew === "zeit_ab") {
                    // Abfallverzögert: ∪-Bogen (öffnet nach oben) + kleines Rechteck
                    ctx.beginPath()
                    ctx.arc(w * 0.5, h * 0.12, h * 0.10, 0, Math.PI, false) // ∪
                    ctx.stroke()
                    ctx.strokeRect(w * 0.44, h * 0.04, w * 0.12, h * 0.09)

                } else if (ew === "voreilung") {
                    // Voreilung: kleiner Pfeil (↑) links neben Pin 1
                    var vx = w * 0.09, vy = h * 0.42, vl = h * 0.18
                    ctx.beginPath()
                    ctx.moveTo(vx, vy)
                    ctx.lineTo(vx, vy - vl)
                    ctx.lineTo(vx - vl * 0.35, vy - vl * 0.55)
                    ctx.moveTo(vx, vy - vl)
                    ctx.lineTo(vx + vl * 0.35, vy - vl * 0.55)
                    ctx.stroke()

                } else if (ew === "nacheilung") {
                    // Nacheilung: kleiner Pfeil (↓) rechts neben Pin 2
                    var nx = w * 0.91, ny = h * 0.25, nl = h * 0.18
                    ctx.beginPath()
                    ctx.moveTo(nx, ny)
                    ctx.lineTo(nx, ny + nl)
                    ctx.lineTo(nx - nl * 0.35, ny + nl * 0.55)
                    ctx.moveTo(nx, ny + nl)
                    ctx.lineTo(nx + nl * 0.35, ny + nl * 0.55)
                    ctx.stroke()
                }
            }
            ctx.restore()
        }

        // Liest Primitive aus symbol_primitiv über symbolDefinitionModel und
        // zeichnet sie in den Koordinaten 0..w × 0..h.
        // ctx.strokeStyle und ctx.lineWidth werden vom Aufrufer gesetzt.
        // farbUeberschreibung (optional): { primitivIndex: "#farbe" } – überschreibt
        // ctx.strokeStyle für einzelne Primitive (Reihenfolge-Index = Array-Index).
        function drawByPrimitiv(ctx, symbolId, w, h, farbUeberschreibung) {
            var prims = symbolDefinitionModel.primitiveFuerSymbol(symbolId)
            var _basisStroke = ctx.strokeStyle
            for (var i = 0; i < prims.length; i++) {
                var p = prims[i]
                ctx.strokeStyle = (farbUeberschreibung && farbUeberschreibung[i] !== undefined)
                                   ? farbUeberschreibung[i] : _basisStroke

                // Linienart
                switch (p.linienart) {
                    case "dash":    ctx.setLineDash([6, 3]);         break
                    case "dot":     ctx.setLineDash([2, 3]);         break
                    case "dashdot": ctx.setLineDash([6, 3, 2, 3]);   break
                    default:        ctx.setLineDash([]);             break
                }

                switch (p.typ) {
                    case "linie":
                        ctx.beginPath()
                        ctx.moveTo(p.x1 * w, p.y1 * h)
                        ctx.lineTo(p.x2 * w, p.y2 * h)
                        ctx.stroke()
                        break
                    case "rechteck":
                        ctx.strokeRect(p.x1 * w, p.y1 * h,
                                       (p.x2 - p.x1) * w, (p.y2 - p.y1) * h)
                        break
                    case "kreis_offen":
                        ctx.beginPath()
                        ctx.arc(p.x1 * w, p.y1 * h, p.radius * w, 0, 2 * Math.PI)
                        ctx.stroke()
                        break
                    case "kreis_gefuellt":
                        ctx.save()
                        ctx.fillStyle = ctx.strokeStyle
                        ctx.beginPath()
                        ctx.arc(p.x1 * w, p.y1 * h, p.radius * w, 0, 2 * Math.PI)
                        ctx.fill()
                        ctx.restore()
                        break
                    case "bogen":
                        ctx.beginPath()
                        ctx.arc(p.x1 * w, p.y1 * h,
                                p.radius * w,
                                p.winkel_von * Math.PI / 180,
                                p.winkel_bis * Math.PI / 180,
                                p.bogen_gegen_uhrzeiger)
                        ctx.stroke()
                        break
                    case "text":
                        if (root.bewegungAktiv) break
                        ctx.save()
                        ctx.fillStyle    = ctx.strokeStyle
                        ctx.font         = (p.schrift_fett ? "bold " : "") +
                                           Math.round(p.schrift_relativ * h) + "px sans-serif"
                        ctx.textAlign    = p.text_align    || "center"
                        ctx.textBaseline = p.text_baseline || "middle"
                        ctx.fillText(p.text_inhalt, p.x1 * w, p.y1 * h)
                        ctx.restore()
                        break
                    case "dreieck_gefuellt":
                        ctx.save()
                        ctx.fillStyle = ctx.strokeStyle
                        ctx.beginPath()
                        ctx.moveTo(p.x1 * w, p.y1 * h)
                        ctx.lineTo(p.x2 * w, p.y2 * h)
                        ctx.lineTo(p.x3 * w, p.y3 * h)
                        ctx.closePath()
                        ctx.fill()
                        ctx.restore()
                        break
                }
            }
            ctx.strokeStyle = _basisStroke
            ctx.setLineDash([])
        }

        function _renderSymbol(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            var sw = vx2 - vx1, sh = vy2 - vy1
            // Stecker/Buchse: Verbindungsstatus einmal ermitteln (Pin-Marker + Primitiv-Einfärbung)
            var _istSteBu  = (el.symbolId === "stecker" || el.symbolId === "buchse")
            var _steBuOk   = (!vorschau && _istSteBu) ? root.hatLogischeVerbindung(idx) : false
            if (Math.abs(sw) > 0.5 && Math.abs(sh) > 0.5) {
                var scx = vx1 + sw/2, scy = vy1 + sh/2
                var rot = (el.rotation || 0) * Math.PI / 180

                ctx.save()
                ctx.translate(scx, scy)
                if (rot !== 0) ctx.rotate(rot)
                if (el.spiegelX) ctx.scale(-1, 1)
                if (el.spiegelY) ctx.scale(1, -1)
                ctx.translate(-Math.abs(sw)/2, -Math.abs(sh)/2)
                // Bei gestecktem Zustand: Bogen der Buchse / Rechteck des Steckers
                // (jeweils Primitiv-Index 1) grün einfärben.
                var _steBuFarbe = _steBuOk ? { 1: "#00e5a0" } : undefined
                drawCanvas.drawByPrimitiv(ctx, el.symbolId || "", Math.abs(sw), Math.abs(sh), _steBuFarbe)
                // Erweiterungsmodifier im lokalen Koordinatensystem (dreht/spiegelt mit)
                if (!vorschau) {
                    var erw = (el.extraDaten && Array.isArray(el.extraDaten.erweiterungen))
                              ? el.extraDaten.erweiterungen : []
                    if (erw.length > 0)
                        drawCanvas.maleModifier(ctx, erw, Math.abs(sw), Math.abs(sh))
                }
                ctx.restore()

                // Pin-Marker zeichnen (immer sichtbar, selektiert = hervorgehoben)
                if (!vorschau) {
                    var pins = el.symbolId === "querverweis"
                               ? geometrieHandler.querverweisPin(el)
                               : symbolDefinitionModel.pinsForSymbol(el.symbolId || "")
                    ctx.setLineDash([])
                    for (var pi = 0; pi < pins.length; pi++) {
                        var pp = geometrieHandler.pinViewportPos(el, pins[pi].x, pins[pi].y)
                        var pr = gewaehlt ? 2.5 : 1.5
                        ctx.globalAlpha = gewaehlt ? 1.0 : 0.55
                        // Stecker/Buchse Pin 2 (fiktive Steckverbindung): grün = gesteckt,
                        // orange = offen – unabhängig von der Auswahl-Hervorhebung.
                        if (_istSteBu && pins[pi].name === "2") {
                            pr = Math.max(pr, 2.0)
                            ctx.beginPath(); ctx.arc(pp.x, pp.y, pr, 0, 2 * Math.PI)
                            ctx.fillStyle   = _steBuOk ? "#00e5a0" : "#f0a030"
                            ctx.strokeStyle = _steBuOk ? "#004d35" : "#7a4400"
                            ctx.lineWidth   = 1.0
                            ctx.fill(); ctx.stroke()
                            continue
                        }
                        ctx.beginPath(); ctx.arc(pp.x, pp.y, pr, 0, 2 * Math.PI)
                        ctx.fillStyle   = gewaehlt ? "#00e5a0" : "#4a9eff"
                        ctx.strokeStyle = gewaehlt ? "#004d35" : "#0a2040"
                        ctx.lineWidth   = 1.0
                        ctx.fill(); ctx.stroke()
                    }
                    ctx.globalAlpha = op
                }

                // Pin-Bezeichnungen rendern: Default = Pin-Name aus der Pinbelegung
                // (symbol_pin.name), ueberschreibbar je Instanz via extraDaten.pinBez.
                // Format pinBez: { "pinName": "Anzeige-Label" }.
                // Nicht für Verbindungshelfer (querverweis, winkel, treffpunkt, klemme_anschluss,
                // geraeteanschluss, potenzial) – die haben eigene Beschriftungslogik.
                if (!vorschau && !_skipText) {
                    var _pbEd  = el.extraDaten || {}
                    var _pbBez = _pbEd.pinBez || {}
                    var _pbSkip = { "querverweis":1,"winkel":1,"treffpunkt":1,"treffpunkt_l":1,
                                    "klemme_anschluss":1,"geraeteanschluss":1,"potenzial":1,"aderdefinition":1,
                                    "isoliert_gelegte_ader":1 }
                    if (!_pbSkip[el.symbolId || ""]) {
                        var _pbPins = symbolDefinitionModel.pinsForSymbol(el.symbolId || "")
                        if (_pbPins.length > 0) {
                            var _pbFs = Math.max(6, Math.round(1.8 * root.mmToPx * root.zoom))
                            ctx.save()
                            ctx.font      = _pbFs + "px sans-serif"
                            ctx.fillStyle = gewaehlt ? "#f0a030" : "#8ac4e0"
                            ctx.globalAlpha = 1.0
                            for (var _pbI = 0; _pbI < _pbPins.length; _pbI++) {
                                var _pbPin   = _pbPins[_pbI]
                                // Stecker/Buchse Pin 2 (fiktive Steckverbindung) braucht keine
                                // Beschriftung – der Verbindungsstatus wird stattdessen farblich
                                // am Pin-Punkt und an Bogen/Rechteck angezeigt (s.u.).
                                if ((el.symbolId === "stecker" || el.symbolId === "buchse") &&
                                    _pbPin.name === "2") continue
                                var _pbLabel = _pbBez[_pbPin.name] || _pbPin.name
                                var _pbPos = geometrieHandler.pinViewportPos(el, _pbPin.x, _pbPin.y)
                                // Richtungsvektor mit Spiegelung + Rotation transformieren
                                // (identisch zur Transformation in pinViewportPos)
                                var _pbOx = _pbPin.offenX || 0
                                var _pbOy = _pbPin.offenY || 0
                                if (el.spiegelX) _pbOx = -_pbOx
                                if (el.spiegelY) _pbOy = -_pbOy
                                var _pbRad = ((el.rotation || 0) * Math.PI / 180)
                                var _pbTx  = _pbOx * Math.cos(_pbRad) - _pbOy * Math.sin(_pbRad)
                                var _pbTy  = _pbOx * Math.sin(_pbRad) + _pbOy * Math.cos(_pbRad)
                                var _pbOff = 4 * root.zoom
                                var _pbX, _pbY
                                // Vertikal dominanter Richtungsvektor → Label rechts
                                // Horizontal dominanter Richtungsvektor → Label oben
                                if (Math.abs(_pbTy) > Math.abs(_pbTx)) {
                                    _pbX = _pbPos.x + _pbOff
                                    _pbY = _pbPos.y
                                    ctx.textAlign    = "left"
                                    ctx.textBaseline = "middle"
                                } else {
                                    _pbX = _pbPos.x
                                    _pbY = _pbPos.y - _pbOff
                                    ctx.textAlign    = "center"
                                    ctx.textBaseline = "bottom"
                                }
                                ctx.fillText(_pbLabel, _pbX, _pbY)
                            }
                            ctx.restore()
                        }
                    }
                }

                // BMK-Label und Freitexte am Symbol rendern (konzeptgemäß, Abschnitt 7).
                // Text ist immer waagerecht.
                // 0°/180° → über dem Symbol  (Anker: Oberkante, Mitte X)
                // 90°/270° → links neben dem Symbol (Anker: linke Kante, Mitte Y)
                // Verbindungshelfer erhalten keine Beschriftung.
                if (!vorschau && !_skipText) {
                    var bmkSid = el.symbolId || ""
                    var verbHelper = SK.hatEigenenBeschriftungsBlock(bmkSid)
                    if (!verbHelper) {
                        var bmkEd  = el.extraDaten || {}
                        var bmkStr = bmkEd.bmk || ""
                        // Geordnete, sichtbare Freitext-Zeilen aufbauen
                        var ftRhlg  = bmkEd.textReihenfolge || ["freitext1", "freitext2"]
                        var ftZeilen = []
                        for (var fti = 0; fti < ftRhlg.length; fti++) {
                            var ftK = ftRhlg[fti]
                            if (bmkEd[ftK + "Sichtbar"] !== false && (bmkEd[ftK] || "") !== "")
                                ftZeilen.push(bmkEd[ftK])
                        }
                        if (bmkStr !== "" || ftZeilen.length > 0) {
                            // Schriftgröße aus extra_daten (mm), Standard 2.5 mm
                            var schrift = (bmkEd.schriftgroesse !== undefined
                                           ? bmkEd.schriftgroesse : 2.5)
                            var bmkFs   = Math.max(5, Math.round(schrift * root.mmToPx * root.zoom))
                            var ftFs    = Math.max(4, Math.round(schrift * 0.85 * root.mmToPx * root.zoom))
                            var bmkOx   = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0)  * root.zoom
                            var bmkOy   = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : -14) * root.zoom
                            var bmkClr  = gewaehlt ? "#f0a030" : (el.strichFarbe || "#4a9eff")
                            var ftClr   = gewaehlt ? "#f0a030" : "#8ab4d4"
                            var symRot    = ((el.rotation || 0) % 360 + 360) % 360
                            var _symInfo  = symbolDefinitionModel.symbolInfo(el.symbolId || "")
                            var _bmkSeite = (_symInfo && _symInfo.bmkSeite) ? _symInfo.bmkSeite : "auto"
                            var senkrecht = _bmkSeite === "vertikal"
                                            ? (symRot === 0 || symRot === 180)
                                            : (symRot === 90 || symRot === 270)
                            ctx.save()
                            ctx.globalAlpha = 1.0
                            ctx.textAlign   = senkrecht ? "right" : "center"
                            ctx.fillStyle   = bmkClr
                            if (senkrecht) {
                                var bkAx = Math.min(vx1, vx2) + bmkOy
                                var bkCy = (vy1 + vy2) / 2 + bmkOx
                                if (bmkStr !== "") {
                                    ctx.font         = "bold " + bmkFs + "px sans-serif"
                                    ctx.textBaseline = "bottom"
                                    ctx.fillText(bmkStr, bkAx, bkCy)
                                }
                                ctx.font      = ftFs + "px sans-serif"
                                ctx.fillStyle = ftClr
                                ctx.textBaseline = "top"
                                var ftOff = bkCy + 2 * root.zoom
                                for (var fi = 0; fi < ftZeilen.length; fi++) {
                                    ctx.fillText(ftZeilen[fi], bkAx, ftOff)
                                    ftOff += ftFs * 1.25
                                }
                            } else {
                                var bkCx = (vx1 + vx2) / 2 + bmkOx
                                var bkTy = Math.min(vy1, vy2) + bmkOy
                                if (bmkStr !== "") {
                                    ctx.font         = "bold " + bmkFs + "px sans-serif"
                                    ctx.textBaseline = "bottom"
                                    ctx.fillText(bmkStr, bkCx, bkTy)
                                }
                                ctx.font      = ftFs + "px sans-serif"
                                ctx.fillStyle = ftClr
                                ctx.textBaseline = "top"
                                var ftY = Math.max(vy1, vy2) + 3 * root.zoom
                                for (var fj = 0; fj < ftZeilen.length; fj++) {
                                    ctx.fillText(ftZeilen[fj], bkCx, ftY)
                                    ftY += ftFs * 1.25
                                }
                            }
                            ctx.restore()
                        }
                    }
                }

                // ── IBN-Statusdot ────────────────────────────────────
                if (!vorschau && root.ibnModus) {
                    var _ibnBmk = (el.extraDaten || {}).bmk || ""
                    if (_ibnBmk !== "") {
                        var _ibnSt = root.ibnStatusMap[_ibnBmk] || "offen"
                        var _ibnClr = _ibnSt === "abgeschlossen" ? "#3cb371"
                                    : _ibnSt === "in_arbeit"     ? "#f0a030"
                                                                  : "#cc4444"
                        var _ibnCx = Math.max(vx1, vx2) - 5 * root.zoom / root.mmToPx
                        var _ibnCy = Math.min(vy1, vy2) + 5 * root.zoom / root.mmToPx
                        var _ibnR  = Math.max(3, 3 * root.zoom)
                        ctx.save()
                        ctx.globalAlpha = 0.9
                        ctx.beginPath()
                        ctx.arc(_ibnCx, _ibnCy, _ibnR, 0, Math.PI * 2)
                        ctx.fillStyle = _ibnClr
                        ctx.fill()
                        ctx.restore()
                    }
                }

                // ── SPS-Konflikt-Dot ─────────────────────────────────
                // Rotes "!"-Dot oben-links wenn Element mehr als einem Kanal zugewiesen
                if (!vorschau && (el.id || 0) > 0 && root._spsKonfliktSet[el.id]) {
                    var _spsR  = Math.max(3, 3 * root.zoom)
                    var _spsCx = Math.min(vx1, vx2) + _spsR + 2
                    var _spsCy = Math.min(vy1, vy2) + _spsR + 2
                    ctx.save()
                    ctx.globalAlpha = 0.92
                    ctx.beginPath()
                    ctx.arc(_spsCx, _spsCy, _spsR, 0, Math.PI * 2)
                    ctx.fillStyle = "#cc2222"
                    ctx.fill()
                    ctx.globalAlpha = 1.0
                    ctx.fillStyle   = "#ffffff"
                    ctx.font        = "bold " + Math.max(6, Math.round(_spsR * 1.5)) + "px sans-serif"
                    ctx.textAlign    = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillText("!", _spsCx, _spsCy)
                    ctx.restore()
                }

                // ── Fehlersuch-Startpunkt-Marker (farbig je Pfad) ───
                if (!vorschau && root.fehlersuchModus) {
                    var _fsPfadNr = root.fehlersuchPfadIds[(el.id || -1)]
                    if (_fsPfadNr !== undefined &&
                            root.fehlersuchStartIds[_fsPfadNr] === (el.id || -1)) {
                        var _fsR  = Math.max(4, 4 * root.zoom)
                        var _fsCx = (vx1 + vx2) / 2
                        var _fsCy = (vy1 + vy2) / 2
                        ctx.save()
                        ctx.globalAlpha = 0.85
                        ctx.beginPath()
                        ctx.arc(_fsCx, _fsCy, _fsR, 0, Math.PI * 2)
                        ctx.strokeStyle = root._fehlersuchPfadFarben[
                            _fsPfadNr % root._fehlersuchPfadFarben.length]
                        ctx.lineWidth   = 2.5
                        ctx.stroke()
                        ctx.restore()
                    }
                }

                // ── Fehlersuch-Unterbrechungsmarker (Trenner) ────────
                if (!vorschau && root.fehlersuchModus &&
                        root.fehlersuchUnterbrechungen[(el.id || -1)] !== undefined) {
                    var _fuR  = Math.max(5, 5 * root.zoom)
                    var _fuCx = (vx1 + vx2) / 2
                    var _fuCy = (vy1 + vy2) / 2
                    ctx.save()
                    ctx.globalAlpha = 0.9
                    ctx.beginPath()
                    ctx.arc(_fuCx, _fuCy, _fuR, 0, Math.PI * 2)
                    ctx.strokeStyle = "#e04040"
                    ctx.lineWidth   = 2.5
                    ctx.stroke()
                    ctx.restore()
                }

                // ── HF-Querverweis-Hinweis (Kontaktspiegel) ──────────
                // Erscheint nur bei Nebenfunktionen auf einer anderen Seite
                // als die Hauptfunktion.
                if (!vorschau && !_skipText && !verbHelper && (el.betriebsmittelId || 0) > 0) {
                    var _hfRef = root._hfReferenzMap[el.betriebsmittelId]
                    if (_hfRef
                            && _hfRef.hauptElementId !== (el.id || -1)
                            && _hfRef.seiteId        !== root.seiteId) {
                        var _hfTxt = "← /" + _hfRef.blattnummer
                        var _hfEd  = el.extraDaten || {}
                        var _hfFs  = Math.max(4, Math.round(
                            (_hfEd.schriftgroesse !== undefined ? _hfEd.schriftgroesse : 2.5)
                            * 0.75 * root.mmToPx * root.zoom))
                        var _hfRot  = ((el.rotation || 0) % 360 + 360) % 360
                        var _hfSenk = (_hfRot === 90 || _hfRot === 270)
                        ctx.save()
                        ctx.globalAlpha = 0.75
                        ctx.fillStyle   = gewaehlt ? "#f0a030" : "#6899c4"
                        ctx.font        = _hfFs + "px sans-serif"
                        if (_hfSenk) {
                            ctx.textAlign    = "left"
                            ctx.textBaseline = "middle"
                            ctx.fillText(_hfTxt,
                                         Math.max(vx1, vx2) + 3 * root.zoom,
                                         (vy1 + vy2) / 2)
                        } else {
                            ctx.textAlign    = "center"
                            ctx.textBaseline = "top"
                            ctx.fillText(_hfTxt,
                                         (vx1 + vx2) / 2,
                                         Math.max(vy1, vy2) + 2 * root.zoom)
                        }
                        ctx.restore()
                    }
                }

                // Querverweis: Signalname + Partnerseite – BMK-Stil
                if (!vorschau && !_skipText && el.symbolId === "querverweis") {
                    var qed     = el.extraDaten || {}
                    var qSn     = qed.signalname || ""
                    var _qpInfo  = root._querverweisPartnerMap[idx]
                    var qPartner = _qpInfo ? (_qpInfo.label || "") : ""
                    if (qSn !== "" || qPartner !== "") {
                        var qFs   = Math.max(10, Math.round(2.0 * root.mmToPx * root.zoom))
                        var qFsS  = Math.max(6, Math.round(1.6 * root.mmToPx * root.zoom))
                        var qRot  = ((el.rotation || 0) % 360 + 360) % 360
                        var qSenk = (qRot === 90 || qRot === 270)
                        var qCx   = (vx1 + vx2) / 2
                        var qCy   = (vy1 + vy2) / 2
                        ctx.save()
                        ctx.globalAlpha = 1.0
                        if (qSenk) {
                            var qX = Math.min(vx1, vx2) - 4 * root.zoom
                            if (qSn !== "") {
                                ctx.fillStyle    = gewaehlt ? "#f0a030" : "#c0d8f0"
                                ctx.font         = "bold " + qFs + "px sans-serif"
                                ctx.textAlign    = "right"
                                ctx.textBaseline = qPartner !== "" ? "bottom" : "middle"
                                ctx.fillText(qSn, qX, qCy)
                            }
                            if (qPartner !== "") {
                                ctx.fillStyle    = gewaehlt ? "#f0a030" : "#7aaacc"
                                ctx.font         = qFsS + "px sans-serif"
                                ctx.textAlign    = "right"
                                ctx.textBaseline = "top"
                                ctx.fillText("→ " + qPartner, qX, qCy)
                            }
                        } else {
                            var qY = Math.min(vy1, vy2) - 3 * root.zoom
                            if (qSn !== "") {
                                ctx.fillStyle    = gewaehlt ? "#f0a030" : "#c0d8f0"
                                ctx.font         = "bold " + qFs + "px sans-serif"
                                ctx.textAlign    = "center"
                                ctx.textBaseline = "bottom"
                                ctx.fillText(qSn, qCx, qY)
                            }
                            if (qPartner !== "") {
                                ctx.fillStyle    = gewaehlt ? "#f0a030" : "#7aaacc"
                                ctx.font         = qFsS + "px sans-serif"
                                ctx.textAlign    = "center"
                                ctx.textBaseline = "bottom"
                                ctx.fillText("→ " + qPartner, qCx, qY - qFs - 1)
                            }
                        }
                        ctx.restore()
                    }
                }

                // Geräteanschluss: Anschlusskennzeichnung, ggf. mit GK-BMK (z.B. "-X1:L1")
                // Pin ist bei 0° rechts: 0°→Text links | 90°→Text oben | 180°→Text rechts | 270°→Text unten
                if (!vorschau && !_skipText && el.symbolId === "geraeteanschluss") {
                    var gaed  = el.extraDaten || {}
                    var gaAnk = gaed.anschlusskennzeichnung || ""
                    if (gaAnk !== "") {
                        // Umschließenden Gerätekasten suchen (kleinster)
                        // _gkListe wurde einmalig in onPaint vorberechnet
                        var gaCxF = (el.x1 + el.x2) / 2, gaCyF = (el.y1 + el.y2) / 2
                        var bestGk = null, bestGkA = Infinity
                        var _gaEls = drawCanvas._gkListe
                        for (var gi = 0; gi < _gaEls.length; gi++) {
                            var gke = _gaEls[gi]
                            var gkx1 = Math.min(gke.x1,gke.x2), gkx2 = Math.max(gke.x1,gke.x2)
                            var gky1 = Math.min(gke.y1,gke.y2), gky2 = Math.max(gke.y1,gke.y2)
                            if (gaCxF >= gkx1 && gaCxF <= gkx2 && gaCyF >= gky1 && gaCyF <= gky2) {
                                var gkA = (gkx2-gkx1)*(gky2-gky1)
                                if (gkA < bestGkA) { bestGkA = gkA; bestGk = gke }
                            }
                        }
                        var gaLabel = gaAnk
                        if (bestGk) {
                            var gkBmkGA = (bestGk.extraDaten || {}).bmk || ""
                            if (gkBmkGA) gaLabel = gkBmkGA + ":" + gaAnk
                        }

                        var gaFs   = Math.max(10, Math.round(2.0 * root.mmToPx * root.zoom))
                        var gaRot  = ((el.rotation || 0) % 360 + 360) % 360
                        var gaSenk = (gaRot === 90 || gaRot === 270)
                        var gaCx   = (vx1 + vx2) / 2
                        var gaCy   = (vy1 + vy2) / 2
                        var gaOx   = (gaed.bmkOffsetX !== undefined ? gaed.bmkOffsetX : 0) * root.zoom
                        var gaOy   = (gaed.bmkOffsetY !== undefined ? gaed.bmkOffsetY : 0) * root.zoom
                        ctx.save()
                        ctx.globalAlpha = 1.0
                        ctx.font = "bold " + gaFs + "px sans-serif"
                        ctx.fillStyle = gewaehlt ? "#f0a030" : "#4488cc"
                        if (gaSenk) {
                            // 90°: pin unten → Text oben  |  270°: pin oben → Text unten
                            var gaPinUnten = (gaRot === 90)
                            var gaY = gaPinUnten
                                      ? Math.min(vy1, vy2) - 3 * root.zoom + gaOy
                                      : Math.max(vy1, vy2) + 3 * root.zoom + gaOy
                            ctx.textAlign = "center"
                            ctx.textBaseline = gaPinUnten ? "bottom" : "top"
                            ctx.fillText(gaLabel, gaCx + gaOx, gaY)
                        } else {
                            // 0°: pin rechts → Text links  |  180°: pin links → Text rechts
                            var gaPinRechts = (gaRot === 0)
                            var gaX = gaPinRechts
                                      ? Math.min(vx1, vx2) - 4 * root.zoom + gaOx
                                      : Math.max(vx1, vx2) + 4 * root.zoom + gaOx
                            ctx.textAlign = gaPinRechts ? "right" : "left"
                            ctx.textBaseline = "middle"
                            ctx.fillText(gaLabel, gaX, gaCy + gaOy)
                        }
                        ctx.restore()
                    }
                }

                // Potenzial: BMK + Freitext neben dem Symbol (pin-seitig, draggbar via bmkOffsetX/Y)
                // Pin ist bei 0° rechts: 0°→Text links | 90°→Text oben | 180°→Text rechts | 270°→Text unten
                if (!vorschau && !_skipText && el.symbolId === "potenzial") {
                    var paed    = el.extraDaten || {}
                    var paBmk   = paed.bmk || ""
                    var paFtRhlg = paed.textReihenfolge || ["freitext1", "freitext2"]
                    var paFt    = []
                    for (var pfi = 0; pfi < paFtRhlg.length; pfi++) {
                        var pftK = paFtRhlg[pfi]
                        if (paed[pftK + "Sichtbar"] !== false && (paed[pftK] || "") !== "")
                            paFt.push(paed[pftK])
                    }
                    if (paBmk !== "" || paFt.length > 0) {
                        var paSchrift = paed.schriftgroesse !== undefined ? paed.schriftgroesse : 2.5
                        var paFs   = Math.max(5, Math.round(paSchrift * root.mmToPx * root.zoom))
                        var paFtFs = Math.max(4, Math.round(paSchrift * 0.85 * root.mmToPx * root.zoom))
                        var paRot  = ((el.rotation || 0) % 360 + 360) % 360
                        var paSenk = (paRot === 90 || paRot === 270)
                        var paCx   = (vx1 + vx2) / 2
                        var paCy   = (vy1 + vy2) / 2
                        var paOx   = (paed.bmkOffsetX !== undefined ? paed.bmkOffsetX : 0) * root.zoom
                        var paOy   = (paed.bmkOffsetY !== undefined ? paed.bmkOffsetY : 0) * root.zoom
                        var paBmkClr = gewaehlt ? "#f0a030" : (el.strichFarbe || "#4a9eff")
                        var paFtClr  = gewaehlt ? "#f0a030" : "#8ab4d4"
                        ctx.save()
                        ctx.globalAlpha = 1.0
                        if (paSenk) {
                            // 90°: pin unten → Text oben  |  270°: pin oben → Text unten
                            var paPinUnten = (paRot === 90)
                            var paBl  = paPinUnten ? "bottom" : "top"
                            var paDir = paPinUnten ? -1 : 1
                            var paY   = paPinUnten
                                        ? Math.min(vy1, vy2) - 3 * root.zoom + paOy
                                        : Math.max(vy1, vy2) + 3 * root.zoom + paOy
                            var paCxO = paCx + paOx
                            ctx.textAlign = "center"
                            if (paBmk !== "") {
                                ctx.font = "bold " + paFs + "px sans-serif"
                                ctx.textBaseline = paBl
                                ctx.fillStyle = paBmkClr; ctx.fillText(paBmk, paCxO, paY)
                            }
                            if (paFt.length > 0) {
                                ctx.font = paFtFs + "px sans-serif"
                                ctx.fillStyle = paFtClr
                                var paFtY = paY + paDir * (paBmk !== "" ? paFs + 2 : 0)
                                for (var pfi2 = 0; pfi2 < paFt.length; pfi2++) {
                                    ctx.textBaseline = paBl
                                    ctx.fillText(paFt[pfi2], paCxO, paFtY)
                                    paFtY += paDir * paFtFs * 1.3
                                }
                            }
                        } else {
                            // 0°: pin rechts → Text links  |  180°: pin links → Text rechts
                            var paPinRechts = (paRot === 0)
                            var paAl = paPinRechts ? "right" : "left"
                            var paX  = paPinRechts
                                       ? Math.min(vx1, vx2) - 4 * root.zoom + paOx
                                       : Math.max(vx1, vx2) + 4 * root.zoom + paOx
                            var paCyO = paCy + paOy
                            var paLineH = (paBmk !== "" ? paFs : 0) + paFt.length * paFtFs * 1.3
                            var paCurY = paCyO - paLineH / 2
                            ctx.textBaseline = "top"
                            if (paBmk !== "") {
                                ctx.font = "bold " + paFs + "px sans-serif"
                                ctx.textAlign = paAl
                                ctx.fillStyle = paBmkClr; ctx.fillText(paBmk, paX, paCurY)
                                paCurY += paFs * 1.1
                            }
                            if (paFt.length > 0) {
                                ctx.font = paFtFs + "px sans-serif"
                                ctx.textAlign = paAl; ctx.fillStyle = paFtClr
                                for (var pfi3 = 0; pfi3 < paFt.length; pfi3++) {
                                    ctx.fillText(paFt[pfi3], paX, paCurY)
                                    paCurY += paFtFs * 1.3
                                }
                            }
                        }
                        ctx.restore()
                    }
                }

                // Klemmen-Anschluss: Bezeichnung + BMK neben dem Symbol (draggable via bmkOffsetX/Y)
                if (!vorschau && !_skipText && el.symbolId === "klemme_anschluss"
                        && 2.0 * root.mmToPx * root.zoom >= 7) {
                    var kaed     = el.extraDaten || {}
                    var kaIstGeist = kaed.geist === true
                    var kaAnz    = kaed.anschlussBezeichnung || ""
                    var kaBmkRaw = kaed.bmk || ""
                    // Redundantes ":anschlussBezeichnung" am Ende entfernen – steht bereits auf Zeile 1
                    var kaBmkBase = (kaAnz !== "" && kaBmkRaw.endsWith(":" + kaAnz))
                                    ? kaBmkRaw.slice(0, kaBmkRaw.length - kaAnz.length - 1)
                                    : kaBmkRaw
                    // Granulare BMK-Sichtbarkeit: Leiste / Anlage / Ort / Gerät
                    var kaBmkColon = kaBmkBase.lastIndexOf(":")
                    var kaBmk, kaBmkVis
                    if (kaBmkColon >= 0) {
                        var kaBmkStrip = kaBmkBase.slice(0, kaBmkColon + 1)
                        var kaBmkNr    = kaBmkBase.slice(kaBmkColon + 1)
                        var kaBmkPrefix = ""
                        if (kaed.bmkSichtbar !== false) {
                            var kaAnlAn = kaed.anlageAnzeigen !== false
                            var kaOrtAn = kaed.ortAnzeigen    !== false
                            var kaGkAn  = kaed.geraetAnzeigen !== false
                            if (kaAnlAn && kaOrtAn && kaGkAn) {
                                kaBmkPrefix = kaBmkStrip
                            } else {
                                var kaS = kaBmkStrip.endsWith(":") ? kaBmkStrip.slice(0, -1) : kaBmkStrip
                                var kaTok = kaS.match(/(==\w+|\+\+\w+|=\w+|\+\w+|-\w+)/g) || [kaS]
                                var kaLM = -1
                                for (var kaI = kaTok.length - 1; kaI >= 0; kaI--) {
                                    if (kaTok[kaI].charAt(0) === "-") { kaLM = kaI; break }
                                }
                                var kaR = ""
                                for (var kaJ = 0; kaJ < kaTok.length; kaJ++) {
                                    var kaT = kaTok[kaJ]; var kaTC = kaT.charAt(0)
                                    if      (kaTC === "=") { if (kaAnlAn) kaR += kaT }
                                    else if (kaTC === "+") { if (kaOrtAn) kaR += kaT }
                                    else if (kaTC === "-") { if (kaJ === kaLM || kaGkAn) kaR += kaT }
                                }
                                kaBmkPrefix = kaR + ":"
                            }
                        }
                        kaBmk    = kaBmkPrefix + kaBmkNr
                        kaBmkVis = kaBmk !== ""
                    } else {
                        kaBmk    = kaBmkBase
                        kaBmkVis = kaBmkBase !== "" && kaed.bmkSichtbar !== false
                    }
                    var kaFs    = Math.max(6, Math.round(1.5 * root.mmToPx * root.zoom))
                    var kaBmkFs = Math.max(10, Math.round(2.2 * root.mmToPx * root.zoom))
                    var kaRot   = ((el.rotation || 0) % 360 + 360) % 360
                    var kaSenk  = (kaRot === 90 || kaRot === 270)
                    var kaCx    = (vx1 + vx2) / 2
                    var kaCy    = (vy1 + vy2) / 2
                    var kaOx    = (kaed.bmkOffsetX !== undefined ? kaed.bmkOffsetX : 0) * root.zoom
                    var kaOy    = (kaed.bmkOffsetY !== undefined ? kaed.bmkOffsetY : 0) * root.zoom
                    // Textposition: immer gegenüber dem Pin
                    // 0°  → Pin oben   → Text unten
                    // 90° → Pin rechts → Text links
                    // 180°→ Pin unten  → Text oben
                    // 270°→ Pin links  → Text rechts
                    ctx.save()
                    ctx.globalAlpha = 1.0
                    if (kaSenk) {
                        var kaPinRechts = (kaRot === 90)
                        var kaX   = kaPinRechts
                                    ? Math.min(vx1, vx2) - 4 * root.zoom + kaOy
                                    : Math.max(vx1, vx2) + 4 * root.zoom + kaOy
                        var kaAlg = kaPinRechts ? "right" : "left"
                        var kaCyO = kaCy + kaOx
                        var kaAy   = kaBmkVis ? kaCyO - kaBmkFs * 0.6 : kaCyO
                        var kaBmkY = kaAnz !== "" ? kaCyO + kaBmkFs * 0.8 : kaCyO
                        if (kaAnz !== "") {
                            ctx.font = "bold " + kaFs + "px sans-serif"
                            ctx.textAlign = kaAlg; ctx.textBaseline = "middle"
                            ctx.fillStyle = gewaehlt ? "#f0a030" : (kaIstGeist ? "#888888" : "#33bb66")
                            ctx.fillText(kaAnz, kaX, kaAy)
                        }
                        if (kaBmkVis) {
                            ctx.font = "bold " + kaBmkFs + "px sans-serif"
                            ctx.textAlign = kaAlg; ctx.textBaseline = "middle"
                            ctx.fillStyle = gewaehlt ? "#f0a030" : (kaIstGeist ? "#888888" : "#4488cc")
                            ctx.fillText(kaBmk, kaX, kaBmkY)
                        }
                    } else {
                        var kaPinUnten = (kaRot === 180)
                        var kaY   = kaPinUnten
                                    ? Math.min(vy1, vy2) - 3 * root.zoom + kaOy
                                    : Math.max(vy1, vy2) + 3 * root.zoom + kaOy
                        var kaBl  = kaPinUnten ? "bottom" : "top"
                        var kaCxO = kaCx + kaOx
                        var kaBmkYh = kaPinUnten ? kaY - kaFs - 1 : kaY + kaFs + 1
                        if (kaAnz !== "") {
                            ctx.font = "bold " + kaFs + "px sans-serif"
                            ctx.textAlign = "center"; ctx.textBaseline = kaBl
                            ctx.fillStyle = gewaehlt ? "#f0a030" : (kaIstGeist ? "#888888" : "#33bb66")
                            ctx.fillText(kaAnz, kaCxO, kaY)
                        }
                        if (kaBmkVis) {
                            ctx.font = "bold " + kaBmkFs + "px sans-serif"
                            ctx.textAlign = "center"; ctx.textBaseline = kaBl
                            ctx.fillStyle = gewaehlt ? "#f0a030" : (kaIstGeist ? "#888888" : "#4488cc")
                            ctx.fillText(kaBmk, kaCxO, kaBmkYh)
                        }
                    }
                    ctx.restore()
                }

                // Aderdefinitionspunkt: Textblock – Positionierung wie BMK an Symbolen
                // 0° (waagerecht): Text über dem Symbol | 90° (senkrecht): Text links
                if (!vorschau && !_skipText && el.symbolId === "aderdefinition"
                        && 2.0 * root.mmToPx * root.zoom >= 7) {
                    var aed = el.extraDaten || {}
                    var adpZeilen = []
                    if (aed.bezeichnung) adpZeilen.push({ text: aed.bezeichnung, bold: true })
                    var adpFarb = aed.aderfarbe || "", adpQuer = aed.querschnitt_mm2
                    if (adpFarb !== "" || (adpQuer !== undefined && adpQuer > 0))
                        adpZeilen.push({ text: (adpFarb || "–") + (adpQuer > 0 ? "  " + (adpQuer + "").replace('.', ',') + " mm²" : ""), bold: false })
                    if (aed.laenge_m && aed.laenge_m > 0)
                        adpZeilen.push({ text: qsTr("\u2192 ") + (aed.laenge_m + "").replace('.', ',') + " m", bold: false })
                    if (adpZeilen.length > 0) {
                        var adpFs    = Math.max(6, Math.round(2.0 * root.mmToPx * root.zoom))
                        var adpLineH = adpFs * 1.3
                        var adpRot   = ((el.rotation || 0) % 360 + 360) % 360
                        var adpSenk  = (adpRot === 90 || adpRot === 270)
                        var adpCx    = (vx1 + vx2) / 2
                        var adpCy    = (vy1 + vy2) / 2
                        ctx.save()
                        ctx.globalAlpha = 1.0
                        var adpTextFarbe = gewaehlt ? "#f0a030" : "#4488cc"
                        if (adpSenk) {
                            // Senkrecht: Text links, vertikal zentriert
                            var adpLx = Math.min(vx1, vx2) - 4 * root.zoom
                            var adpLy = adpCy - adpZeilen.length * adpLineH / 2
                            ctx.textAlign = "right"; ctx.textBaseline = "top"
                            for (var az1 = 0; az1 < adpZeilen.length; az1++) {
                                ctx.font = (adpZeilen[az1].bold ? "bold " : "") + adpFs + "px sans-serif"
                                ctx.fillStyle = adpTextFarbe
                                ctx.fillText(adpZeilen[az1].text, adpLx, adpLy + az1 * adpLineH)
                            }
                        } else {
                            // Waagerecht: Text über dem Symbol, horizontal zentriert
                            var adpOy = Math.min(vy1, vy2) - 3 * root.zoom
                            var adpOx = adpCx
                            ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                            // Zeilen von unten nach oben (letzte Zeile oben)
                            for (var az2 = adpZeilen.length - 1; az2 >= 0; az2--) {
                                ctx.font = (adpZeilen[az2].bold ? "bold " : "") + adpFs + "px sans-serif"
                                ctx.fillStyle = adpTextFarbe
                                ctx.fillText(adpZeilen[az2].text, adpOx, adpOy)
                                adpOy -= adpLineH
                            }
                        }
                        ctx.restore()
                    }
                }
            }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0,0,width,height)
            renderHandler.drawNormblatt(ctx)
            var elemente = elementeModel.snapshot()
            // Gerätekasten-Liste einmalig filtern — GA-Rendering nutzt drawCanvas._gkListe
            var _gkBuf = []
            for (var _gi = 0; _gi < elemente.length; _gi++)
                if (elemente[_gi] && elemente[_gi].typ === "geraetekasten") _gkBuf.push(elemente[_gi])
            drawCanvas._gkListe = _gkBuf
            for (var i=0; i<elemente.length; i++)
                renderHandler.maleElement(ctx, elemente[i], i)

            // Klemmen-Highlight-Pass (KLEMME-HL-01)
            if (root._hlKlemmeId >= 0) {
                ctx.save()
                ctx.strokeStyle = "#00d0a0"
                ctx.lineWidth   = 2.5
                ctx.setLineDash([4, 3])
                ctx.globalAlpha = 0.85
                for (var hi = 0; hi < elemente.length; hi++) {
                    var hEl = elemente[hi]
                    if (!hEl || hEl.typ !== "symbol" || hEl.symbolId !== "klemme_anschluss") continue
                    if (root.auswahl.indexOf(hi) >= 0) continue
                    var hEd = hEl.extraDaten || {}
                    if ((hEd.klemmeId !== undefined ? hEd.klemmeId : -1) !== root._hlKlemmeId) continue
                    var hvx1 = hEl.x1 * root.zoom + root.worldX
                    var hvy1 = hEl.y1 * root.zoom + root.worldY
                    var hvx2 = hEl.x2 * root.zoom + root.worldX
                    var hvy2 = hEl.y2 * root.zoom + root.worldY
                    var hbx  = Math.min(hvx1, hvx2), hby = Math.min(hvy1, hvy2)
                    var hbw  = Math.abs(hvx2 - hvx1), hbh = Math.abs(hvy2 - hvy1)
                    ctx.strokeRect(hbx - 2, hby - 2, hbw + 4, hbh + 4)
                }
                ctx.restore()
            }

            if (root.vorschau !== null)
                renderHandler.maleElement(ctx, root.vorschau, -1)
            if (root.vorschau !== null && root.vorschau.typ === "makrokasten"
                    && root.makroVorschauElemente.length > 0) {
                var ox = root.vorschau.x1
                var oy = root.vorschau.y1
                for (var mpi = 0; mpi < root.makroVorschauElemente.length; mpi++) {
                    var mpe = root.makroVorschauElemente[mpi]
                    renderHandler.maleElement(ctx, {
                        typ:            mpe.typ,
                        x1:             mpe.x1 + ox,
                        y1:             mpe.y1 + oy,
                        x2:             mpe.x2 + ox,
                        y2:             mpe.y2 + oy,
                        strichFarbe:    mpe.strichFarbe,
                        strichBreite:   mpe.strichBreite,
                        strichArt:      mpe.strichArt,
                        fuell:          mpe.fuell,
                        fuellFarbe:     mpe.fuellFarbe,
                        fuellOpazitaet: mpe.fuellOpazitaet,
                        opazitaet:      mpe.opazitaet,
                        eckenRadius:    mpe.eckenRadius,
                        rotation:       mpe.rotation,
                        spiegelX:       mpe.spiegelX,
                        spiegelY:       mpe.spiegelY,
                        symbolId:       mpe.symbolId,
                        extraDaten:     mpe.extraDaten
                    }, -1)
                }
            }
            if (root.duplizierVorschau) {
                for (var dvi = 0; dvi < root.duplizierVorschau.length; dvi++)
                    renderHandler.maleElement(ctx, root.duplizierVorschau[dvi], -1)
            }
            // Polygonlinie Live-Vorschau (bereits gezeichnete Segmente + offenes Segment zum Cursor)
            if (root.amPolyZeichnen && root.polyPunkte.length > 0) {
                ctx.save()
                ctx.globalAlpha = 0.7
                ctx.strokeStyle = "#4a9eff"
                ctx.lineWidth   = root.stilVorlage.strichBreite || 1.5
                ctx.setLineDash([])
                ctx.lineCap     = "round"
                ctx.beginPath()
                var pp0 = root.polyPunkte[0]
                ctx.moveTo(pp0.x * root.zoom + root.worldX, pp0.y * root.zoom + root.worldY)
                for (var ppI = 1; ppI < root.polyPunkte.length; ppI++) {
                    var ppN = root.polyPunkte[ppI]
                    ctx.lineTo(ppN.x * root.zoom + root.worldX, ppN.y * root.zoom + root.worldY)
                }
                if (root.polyCursorWelt !== null) {
                    ctx.setLineDash([5, 4])
                    ctx.lineTo(root.polyCursorWelt.x * root.zoom + root.worldX,
                               root.polyCursorWelt.y * root.zoom + root.worldY)
                }
                ctx.stroke()
                // Bereits gesetzte Punkte als kleine Kreise
                ctx.setLineDash([])
                for (var ppV = 0; ppV < root.polyPunkte.length; ppV++) {
                    var ppVp = root.polyPunkte[ppV]
                    ctx.beginPath()
                    ctx.arc(ppVp.x * root.zoom + root.worldX, ppVp.y * root.zoom + root.worldY, 3, 0, 2 * Math.PI)
                    ctx.fillStyle = "#4a9eff"; ctx.fill()
                }
                ctx.restore()
            }
            var _repaintNetze = netzHandler.autoNetzeBerechnenCached()
            renderHandler.maleAutoVerbindungen(ctx, _repaintNetze)
            // Schnittpunkte aller Kabellinien mit Auto-Verbindungen (Phase 5)
            for (var kli = 0; kli < elemente.length; kli++) {
                if (elemente[kli].typ === "kabellinie")
                    renderHandler.maleKabelSchnitte(ctx, elemente[kli], _repaintNetze)
            }
            // Rubber-Band Auswahlrahmen
            // AutoCAD-Konvention: links→rechts = Fenster (komplett umschlossene
            // Elemente), rechts→links = Schneiden (Überlappung reicht). Farbe/
            // Linienart geben während des Ziehens visuelles Feedback zum Modus.
            if (root.amRubberband && root.rubberbandRect) {
                var rb = root.rubberbandRect
                var rx = Math.min(rb.x1, rb.x2), ry = Math.min(rb.y1, rb.y2)
                var rw = Math.abs(rb.x2 - rb.x1), rh = Math.abs(rb.y2 - rb.y1)
                var _ueberlapp = rb.x2 < rb.x1
                ctx.save()
                if (_ueberlapp) {
                    ctx.setLineDash([4, 3])
                    ctx.strokeStyle = "#00e5a0"
                    ctx.fillStyle   = "rgba(0, 229, 160, 0.08)"
                } else {
                    ctx.setLineDash([])
                    ctx.strokeStyle = "#4a9eff"
                    ctx.fillStyle   = "rgba(74, 158, 255, 0.07)"
                }
                ctx.lineWidth = 1
                ctx.fillRect(rx, ry, rw, rh)
                ctx.strokeRect(rx, ry, rw, rh)
                ctx.restore()
            }
            // Gruppenindikator: gestricheltes Rechteck um Gruppen in der Auswahl
            if (root.auswahl.length > 0) {
                var gruppenSet = {}
                for (var gai = 0; gai < root.auswahl.length; gai++) {
                    var gaEl = elementeModel.element(root.auswahl[gai])
                    if (gaEl && gaEl.gruppeId !== undefined && gaEl.gruppeId >= 0)
                        gruppenSet[gaEl.gruppeId] = true
                }
                for (var gKey in gruppenSet) {
                    var gId = parseInt(gKey)
                    var mitgl = elementeModel.gruppenMitglieder(gId)
                    if (mitgl.length === 0) continue
                    var gMinX = Infinity, gMinY = Infinity, gMaxX = -Infinity, gMaxY = -Infinity
                    for (var gmi = 0; gmi < mitgl.length; gmi++) {
                        var gmEl = elementeModel.element(parseInt(mitgl[gmi]))
                        if (!gmEl) continue
                        gMinX = Math.min(gMinX, Math.min(gmEl.x1, gmEl.x2))
                        gMinY = Math.min(gMinY, Math.min(gmEl.y1, gmEl.y2))
                        gMaxX = Math.max(gMaxX, Math.max(gmEl.x1, gmEl.x2))
                        gMaxY = Math.max(gMaxY, Math.max(gmEl.y1, gmEl.y2))
                    }
                    var gPad = 6
                    ctx.save()
                    ctx.strokeStyle = "#60c8ff"
                    ctx.lineWidth   = 1.5
                    ctx.setLineDash([6, 4])
                    ctx.strokeRect(
                        gMinX * root.zoom + root.worldX - gPad,
                        gMinY * root.zoom + root.worldY - gPad,
                        (gMaxX - gMinX) * root.zoom + 2 * gPad,
                        (gMaxY - gMinY) * root.zoom + 2 * gPad
                    )
                    ctx.restore()
                }
            }
            // Stapel-Indikator: oranges Badge wenn ≥2 Elemente am gleichen Ort liegen
            var stapelMap = {}
            for (var si = 0; si < elemente.length; si++) {
                var sel = elemente[si]
                var sKey = Math.round((sel.x1 + sel.x2) / 2) + "_" + Math.round((sel.y1 + sel.y2) / 2)
                if (!stapelMap[sKey]) stapelMap[sKey] = { anzahl: 0, x2: sel.x2, y1: sel.y1 }
                stapelMap[sKey].anzahl++
                if (sel.x2 > stapelMap[sKey].x2) stapelMap[sKey].x2 = sel.x2
                if (sel.y1 < stapelMap[sKey].y1) stapelMap[sKey].y1 = sel.y1
            }
            ctx.save()
            ctx.setLineDash([])
            for (var sK in stapelMap) {
                var st = stapelMap[sK]
                if (st.anzahl < 2) continue
                var br  = 9
                var bvx = st.x2 * root.zoom + root.worldX + br * 0.5
                var bvy = st.y1 * root.zoom + root.worldY - br * 0.5
                ctx.globalAlpha = 1.0
                ctx.fillStyle   = "#f97316"
                ctx.beginPath(); ctx.arc(bvx, bvy, br, 0, 2 * Math.PI); ctx.fill()
                ctx.fillStyle    = "#ffffff"
                ctx.font         = "bold 10px sans-serif"
                ctx.textAlign    = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(st.anzahl, bvx, bvy)
            }
            ctx.restore()
            renderHandler.drawNormblattAussenoverlay(ctx)
            // Revisionsmarker-Wasserzeichen
            if (root.revisionStatus !== "") {
                var wmText = ""
                var wmColor = "#888888"
                if (root.revisionStatus === "entwurf") {
                    wmText  = "ENTWURF"
                    wmColor = "#d97706"
                } else if (root.revisionStatus === "freigegeben") {
                    wmText  = "FREIGEGEBEN" + (root.revisionKennung ? "  REV. " + root.revisionKennung : "")
                    wmColor = "#16a34a"
                } else if (root.revisionStatus === "veraltet") {
                    wmText  = "VERALTET"
                    wmColor = "#dc2626"
                }
                if (wmText !== "") {
                    ctx.save()
                    ctx.translate(width / 2, height / 2)
                    ctx.rotate(-Math.PI / 6)
                    ctx.globalAlpha = 0.10
                    ctx.fillStyle   = wmColor
                    ctx.textAlign   = "center"
                    ctx.textBaseline = "middle"
                    ctx.font        = "bold " + Math.round(Math.min(width, height) / 5) + "px sans-serif"
                    ctx.fillText(wmText, 0, 0)
                    ctx.restore()
                }
            }
        }
    }

    // --------------------------------------------------------
    // Welt-Item (für spätere Symbole)
    // --------------------------------------------------------
    Item {
        id: worldItem
        x: root.worldX; y: root.worldY; width: 1; height: 1
        scale: root.zoom; transformOrigin: Item.TopLeft
    }

    // --------------------------------------------------------
    // Platzhalter (Pokestr\u00f6m)
    // --------------------------------------------------------
    PokestroemPlaceholder {
        anchors.fill: parent
        visible: root.seiteId < 0
        theme:   root.theme
    }

    // --------------------------------------------------------
    // Kopfzeile
    // --------------------------------------------------------
    CanvasHeaderBar {
        id: headerBar
        canvas: root
        visible: root.seiteId >= 0
        anchors { top: parent.top; left: parent.left; right: parent.right }
    }

    // Zoom-Shortcuts (Ctrl+Shift+H / Ctrl+Shift+N) → Main.qml

    // --------------------------------------------------------
    // Fußzeile
    // --------------------------------------------------------
    CanvasFooterBar {
        id: footerBar
        canvas: root
        visible: root.seiteId >= 0
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        drcAktiv:  root.drcAktiv
        suchAktiv: root.suchAktiv
        onDrcKlick:  root.drcKlick()
        onSuchKlick: root.suchKlick()
    }

    // --------------------------------------------------------
    // Werkzeugleiste (links)
    // --------------------------------------------------------
    CanvasWerkzeugLeiste {
        id: werkzeugLeiste
        canvas: root
        visible: root.seiteId >= 0
        anchors { top: headerBar.bottom; bottom: footerBar.top; left: parent.left }
        onBildWerkzeugAngefordert: bildWerkzeug.dialogOeffnen()
    }

    // --------------------------------------------------------
    // Interaktionsfläche
    // WICHTIG: rechts NICHT über das Panel – so fressen wir keine
    // Panel-Klicks und das Panel bleibt beim Editieren sichtbar.
    // --------------------------------------------------------
    CanvasInteraktionArea {
        id: interaktionArea
        canvas: root
        anchors {
            top:    headerBar.bottom
            bottom: footerBar.top
            left:   werkzeugLeiste.right
            right:  eigenschaftenPanel.visible ? eigenschaftenPanel.left : parent.right
        }
    }


    // --------------------------------------------------------
    // Pan / Zoom / Pinch / Rechtsklick-Kontextmenü
    // --------------------------------------------------------
    CanvasNavigationHandler {
        id: navigationHandler
        canvas: root
        anchors.fill: parent
    }

    // --------------------------------------------------------
    // Tastaturkürzel
    // --------------------------------------------------------
    // Alle Shortcuts (V/L/R/…, Ctrl+Z/A/C/V/X, Escape, F, …) → Main.qml
    // Verhindert Ambiguität wenn zwei Canvas-Instanzen im Split-Modus sichtbar sind.

    function handleEscape() {
        if (root.amZeichnen) {
            root.abbruch()
        } else {
            root.auswahl      = []
            root.aktiverGriff = -1
            root.amRubberband = false
            root.aktivesWerkzeug = "zeiger"
            root.vorschau = null
            drawCanvas.requestPaint()
        }
    }

    // --------------------------------------------------------
    // Eigenschaften-Panel (rechts, NACH interaktionArea deklariert
    // → höherer Z-Index → bekommt alle Klicks zuerst)
    // --------------------------------------------------------
    Settings {
        id: epBreitenSettings
        category: "ep_panel"
        property int breite: 220
    }

    MouseArea {
        id: epResizeGriff
        visible:      eigenschaftenPanel.visible
        z:            eigenschaftenPanel.z + 1
        width:        4
        cursorShape:  Qt.SizeHorCursor
        hoverEnabled: true
        anchors {
            top:    headerBar.bottom
            bottom: footerBar.top
            right:  eigenschaftenPanel.left
        }

        property real _startX: 0
        property real _startW: 0

        Rectangle {
            anchors.fill: parent
            color: parent.containsMouse || parent.pressed ? theme.accent : theme.border
        }

        onPressed: function(mouse) {
            _startX = mapToItem(root, mouse.x, 0).x
            _startW = eigenschaftenPanel.width
        }
        onPositionChanged: function(mouse) {
            if (!pressed) return
            var currX = mapToItem(root, mouse.x, 0).x
            var delta = currX - _startX
            var newW = Math.max(150, Math.min(450, _startW - delta))
            eigenschaftenPanel.width = newW
            epBreitenSettings.breite = newW
        }
    }

    Rectangle {
        id: eigenschaftenPanel
        visible:  (root.auswahl.length > 0 || root.ausgewaehltVerbindung !== null) && root.seiteId >= 0
        anchors { top: headerBar.bottom; bottom: footerBar.top; right: parent.right }
        width: epBreitenSettings.breite
        color: theme.surfaceDeep; border.color: theme.border; border.width: 1

        EigenschaftenPanel { anchors.fill: parent; canvas: root; theme: root.theme; debug: root.debug }
    }

    // --------------------------------------------------------
    // Bild-Werkzeug (FileDialog + Drag-Drop)
    // --------------------------------------------------------
    CanvasBildWerkzeug {
        id: bildWerkzeug
        canvas: root
        anchors {
            top:    headerBar.bottom
            bottom: footerBar.top
            left:   werkzeugLeiste.right
            right:  eigenschaftenPanel.visible ? eigenschaftenPanel.left : parent.right
        }
    }

    // --------------------------------------------------------
    // Dialog-Layer (Kabellinie / Aderzuordnung / Makrobenennen)
    // --------------------------------------------------------
    CanvasDialogLayer {
        id:    dialogLayer
        canvas: root
        theme: root.theme
        debug: root.debug
    }

    // --------------------------------------------------------
    // Text-Editor-Overlay
    // --------------------------------------------------------
    CanvasTextEditor {
        id: textEditorKomp
        canvas: root
        theme:  root.theme
    }

    // --------------------------------------------------------
    // Minimap-Overlay
    // --------------------------------------------------------
    CanvasMinimap {
        anchors { right: parent.right; bottom: parent.bottom; margins: 12 }
        visible:          root.minimapSichtbar && root.seiteId >= 0
        zoom:             root.zoom
        worldX:           root.worldX
        worldY:           root.worldY
        canvasWidth:      root.width
        canvasHeight:     root.height
        normblattDaten:   root.normblattDaten
        mmToPx:           root.mmToPx
        theme:            root.theme
        hintergrundFarbe: root.hintergrundFarbe
        onPanRequest: function(wx, wy) {
            root.worldX = wx
            root.worldY = wy
            root.repaintAll()
        }
    }

    // --------------------------------------------------------
    // Aktions-Funktionen
    // --------------------------------------------------------
    // Speichert die aktuelle Elementliste in der DB (wenn Seite offen und kein Ladevorgang)
    function grafikSpeichernJetzt() {
        if (root.seiteId >= 0) {
            db.grafikSpeichern(root.seiteId, elementeModel.snapshot())
            var netze = netzHandler.autoNetzeBerechnen()
            db.verbindungenSynchronisieren(root.seiteId, root.projektId, netze)
            root.verbindungAnnotationenNeuLaden()
        }
    }

    function verdrahtungswegeAktualisieren()              { verdrahtungsHandler.verdrahtungswegeAktualisieren() }
    function verbindungAnnotationenNeuLaden()             { verdrahtungsHandler.verbindungAnnotationenNeuLaden() }
    function verbindungAnnotationAktualisieren(key, value){ verdrahtungsHandler.verbindungAnnotationAktualisieren(key, value) }
    function _signaltypInVerbindungen(elIdx, vbs)         { return verdrahtungsHandler._signaltypInVerbindungen(elIdx, vbs) }

    CanvasVerdrahtungsHandler { id: verdrahtungsHandler; cv: root }

    // Cache-Refresh + Ader-Dialog-Orchestrierung ausgelagert (REFACTOR-01 Stufe 4)
    CanvasCacheHandler { id: cacheHandler; cv: root }
    function spsKonfliktAktualisieren()      { cacheHandler.spsKonfliktAktualisieren() }
    function hfKarteAktualisieren()          { cacheHandler.hfKarteAktualisieren() }
    function kabelLinienCacheAktualisieren() { cacheHandler.kabelLinienCacheAktualisieren() }
    function aderzuordnungDialogOeffnen(el)  { cacheHandler.aderzuordnungDialogOeffnen(el) }
    function aderKreuzungPickerOeffnen(treffer) { cacheHandler.aderKreuzungPickerOeffnen(treffer) }

    // --------------------------------------------------------
    // Querverweis-Navigation
    // --------------------------------------------------------

    // Zentriert die Canvas-Ansicht auf eine Weltkoordinate.
    function _zoomZuWeltPosition(wx, wy) { navigationHandler._zoomZuWeltPosition(wx, wy) }

    // Sichtbare Randbreiten der Chrome-Leisten (headerBar/footerBar/werkzeugLeiste/
    // eigenschaftenPanel sind private Ids dieser Datei) — Bridge für
    // CanvasNavigationHandler.qml, das die Zoom-Funktionen enthält (REFACTOR-01).
    function _viewportRand() {
        return {
            topH:       headerBar.visible ? headerBar.height : 0,
            botH:       footerBar.visible ? footerBar.height : 0,
            tlW:        werkzeugLeiste.visible ? werkzeugLeiste.width : 0,
            epSichtbar: eigenschaftenPanel.visible,
            epBreite:   eigenschaftenPanel.width + 16
        }
    }

    // Navigiert vom selektierten Querverweis zur Gegenstelle (f-Taste / Doppelklick).
    function querverweisZurGegenseiteNavigieren() {
        if (root.auswahl.length !== 1) return
        var el = elementeModel.element(root.auswahl[0])
        if (!el || el.typ !== "symbol" || el.symbolId !== "querverweis") return
        var sn = (el.extraDaten && el.extraDaten.signalname) || ""
        if (!sn || root.projektId < 0) return
        var alle = db.querverweiseLadenProjekt(root.projektId)
        for (var k = 0; k < alle.length; k++) {
            var qv = alle[k]
            if (qv.signalname !== sn) continue
            if (qv.seiteId === root.seiteId && Math.abs(qv.x1 - el.x1) < 0.5 && Math.abs(qv.y1 - el.y1) < 0.5) continue
            if (qv.seiteId === root.seiteId) {
                _zoomZuWeltPosition(qv.x1, qv.y1)
            } else {
                root._querverweisZielPos = { x: qv.x1, y: qv.y1 }
                root.querverweisNavigieren(qv.seiteId)
            }
            return
        }
    }

    // Berechnet die Schnittpunkt-Netze einer Kabellinie (für Aderzuordnungsdialog).
    // Gibt [{t, netKey, verbindungId, bezeichnung, signaltyp}] sortiert nach t zurück.
    function kabelSchnittNetzeBerechnen(el) {
        return geometrieHandler.kabelSchnittNetzeBerechnen(el, netzHandler.autoNetzeBerechnen())
    }


    // --------------------------------------------------------
    // Aktionen – delegiert an CanvasAktionenHandler (aktionenHandler)
    // --------------------------------------------------------
    function batchBmkNummerieren(praefix, startNr)  { aktionenHandler.batchBmkNummerieren(praefix, startNr) }
    function elementeAufRasterSnappen()             { aktionenHandler.elementeAufRasterSnappen() }
    function elementeAusrichten(richtung)            { aktionenHandler.elementeAusrichten(richtung) }
    function aktionAusfuehren(neueElemente)          { aktionenHandler.aktionAusfuehren(neueElemente) }
    function eigenschaftAktualisieren(key, value)   { aktionenHandler.eigenschaftAktualisieren(key, value) }
    function labelTreffenTest(vpX, vpY)             { return aktionenHandler.labelTreffenTest(vpX, vpY) }
    function formatKopieren()                        { aktionenHandler.formatKopieren() }
    function formatZuweisen()                        { aktionenHandler.formatZuweisen() }
    function multiRotationUmPivot(delta)             { aktionenHandler.multiRotationUmPivot(delta) }
    function schirmDrehen()                          { aktionenHandler.schirmDrehen() }
    function eigenschaftenSetzen(updates)            { aktionenHandler.eigenschaftenSetzen(updates) }
    function zReihenfolgeAendern(richtung)           { aktionenHandler.zReihenfolgeAendern(richtung) }
    function undo()                                  { aktionenHandler.undo() }
    function redo()                                  { aktionenHandler.redo() }
    function loeschen()                              { aktionenHandler.loeschen() }
    function alleAuswaehlen()                        { aktionenHandler.alleAuswaehlen() }
    function kopieren(slot)                          { aktionenHandler.kopieren(slot) }
    function einfuegen(slot)                         { aktionenHandler.einfuegen(slot) }
    function duplizieren()                           { aktionenHandler.duplizieren() }
    function ausschneiden()                          { aktionenHandler.ausschneiden() }
    function crossProjektMakroErstellen()            { aktionenHandler.crossProjektMakroErstellen() }
    function auswahlFuerElement(idx)                 { return aktionenHandler.auswahlFuerElement(idx) }
    function gruppeErstellen()                       { aktionenHandler.gruppeErstellen() }
    function gruppeAufloesen()                       { aktionenHandler.gruppeAufloesen() }
    function _duplizierVorschauAktualisieren(wx, wy) { aktionenHandler._duplizierVorschauAktualisieren(wx, wy) }
    function _duplizierAnzahlAnfordern(dx, dy)       { aktionenHandler._duplizierAnzahlAnfordern(dx, dy) }
    function _duplizierAnzahlPlatzieren(n)           { aktionenHandler._duplizierAnzahlPlatzieren(n) }
    function abbruch()                               { aktionenHandler.abbruch() }

    // Signal: EigenschaftenPanel-Button soll BMK-Nummerierungsdialog öffnen.
    // CanvasNavigationHandler hört darauf und öffnet den Dialog (hat db-Zugriff).
    signal batchBmkDialogOeffnen()

    // Hilfsfunktion: Symbol-Vorschau-Objekt für gegebene Weltkoordinaten erstellen
    // Berücksichtigt paletteSymbolId, paletteSymbolRotation und Sondereinfügepunkte (Winkel).
    function symbolVorschauErstellen(wx, wy) {
        var sid  = root.paletteSymbolId
        var rot  = root.paletteSymbolRotation
        var info = symbolDefinitionModel.symbolInfo(sid)
        var defW = (info.breiteMm || 16) * root.mmToPx
        var defH = (info.hoeheMm  || 16) * root.mmToPx
        var x1, y1
        if (sid === "winkel") {
            // Ankerpunkt = grafische Ecke (0,h) — Rotation dreht die Eckenrichtung
            if      (rot === 0)   { x1 = wx;        y1 = wy - defH }
            else if (rot === 90)  { x1 = wx;        y1 = wy        }
            else if (rot === 180) { x1 = wx - defW; y1 = wy        }
            else                  { x1 = wx - defW; y1 = wy - defH }
        } else {
            x1 = wx - defW / 2; y1 = wy - defH / 2
        }
        return { typ: "symbol", symbolId: sid,
            x1: x1, y1: y1, x2: x1 + defW, y2: y1 + defH,
            rotation: rot, spiegelX: false, spiegelY: false }
    }

    // Hilfsfunktion: Bbox aus aktuellem Editorinhalt berechnen
    // --------------------------------------------------------
    // Koordinaten-Hilfsfunktionen/Treffer-Test ausgelagert (REFACTOR-01
    // Stufe 3, qml/canvas/CanvasGeometrie.qml). Dünne Wrapper hier, da
    // extern über canvas.xxx()/cv.xxx() aufgerufen (CanvasInteraktionArea,
    // CanvasNavigationHandler, CanvasBildWerkzeug, CanvasVerdrahtungsHandler,
    // CanvasAktionenHandler, EpVerbindungSection).
    // --------------------------------------------------------
    function rasterPunkt(weltX, weltY)     { return geometrieHandler.rasterPunkt(weltX, weltY) }
    function viewportZuWelt(vpX, vpY)      { return geometrieHandler.viewportZuWelt(vpX, vpY) }
    function elementBeiPosition(vpX, vpY)  { return geometrieHandler.elementBeiPosition(vpX, vpY) }
    function griffBeiPosition(vpX, vpY)    { return geometrieHandler.griffBeiPosition(vpX, vpY) }
    function pinWeltPos(el, pinX, pinY)    { return geometrieHandler.pinWeltPos(el, pinX, pinY) }

    // --------------------------------------------------------
    // Ansicht
    // --------------------------------------------------------
    function repaintAll() { gridCanvas.requestPaint(); drawCanvas.requestPaint() }

    function zoomAnpassen(factor)     { navigationHandler.zoomAnpassen(factor) }
    function ansichtZuruecksetzen()   { navigationHandler.ansichtZuruecksetzen() }
    function autoPanFuerAuswahl()     { navigationHandler.autoPanFuerAuswahl() }
    function zoomNormblattEinpassen() { navigationHandler.zoomNormblattEinpassen() }
    function zoomAllesEinpassen()     { navigationHandler.zoomAllesEinpassen() }
    function zoomAuswahlEinpassen()   { navigationHandler.zoomAuswahlEinpassen() }

    function seiteNeuLaden() {
        if (seiteId >= 0) {
            elementeModel.laden(seiteId)
            cacheHandler.hfReferenzMapAktualisieren()
            spsKonfliktAktualisieren()
            netzHandler.autoVerbindungenBerechnen()
            repaintAll()
        }
    }

    function normblattNeuLaden() {
        if (seiteId >= 0) {
            normblattDaten   = db.normblattDatenLaden(seiteId)
            normblattLogoUrl = normblattDaten ? (normblattDaten.logoDataUrl || "") : ""
            revisionStatus   = normblattDaten ? (normblattDaten.revisionStatus  || "") : ""
            revisionKennung  = normblattDaten ? (normblattDaten.revisionKennung || "") : ""
            repaintAll()
        }
    }

    onSeiteIdChanged: {
        if (root.fehlersuchModus) {
            root.fehlersuchPfadIds          = {}
            root.fehlersuchStartId          = -1
            root.fehlersuchStartIds         = []
            root.fehlersuchQuerverweise     = []
            root.fehlersuchUnterbrechungen  = {}
            root.fehlersuchPfadGefunden([])
        }
        if (seiteId < 0) {
            root._zoomPanCache  = {}
            root._vorherSeiteId = -1
            root.auswahl        = []
            root.vorschau       = null
            root.normblattDaten = null
            elementeModel.laden(-1)
            root.repaintAll()
            return
        }
        if (seiteId >= 0) {
            // Zoom/Pan der verlassenen Seite sichern
            if (root._vorherSeiteId >= 0) {
                var saveCache = root._zoomPanCache
                saveCache[root._vorherSeiteId] = {zoom: root.zoom, worldX: root.worldX, worldY: root.worldY}
                root._zoomPanCache = saveCache
            }
            root._vorherSeiteId = seiteId

            root.auswahl = []; root.vorschau  = null; root.amZeichnen = false
            root.amVerschieben   = false; root.mausUeberElement = false
            root.aktiverGriff    = -1; root.mausUeberGriff = false; root.verschiebenErlaubt = false
            var mm = seitenModel.seiteRasterMm(seiteId), rs = seitenModel.seiteRastend(seiteId)
            footerBar.rasterLaden(mm, rs)
            // Gespeicherte Elemente laden
            elementeModel.laden(seiteId)
            root.ausgewaehltVerbindung = null
            root.verbindungAnnotationenCache = {}
            // Gespeicherte Verbindungsannotationen laden
            var annListe = db.verbindungAnnotationenLaden(seiteId)
            var cache = {}
            for (var i = 0; i < annListe.length; i++) cache[annListe[i].netKey] = annListe[i]
            root.verbindungAnnotationenCache = cache
            // Normblatt-Daten laden (enthält auch revisionStatus/revisionKennung)
            root.normblattDaten    = db.normblattDatenLaden(seiteId)
            root.normblattLogoUrl  = root.normblattDaten ? (root.normblattDaten.logoDataUrl || "") : ""
            root.revisionStatus    = root.normblattDaten ? (root.normblattDaten.revisionStatus  || "") : ""
            root.revisionKennung   = root.normblattDaten ? (root.normblattDaten.revisionKennung || "") : ""
            // Querverweis-Partner-Cache aufbauen
            cacheHandler.querverweisPartnerCacheAktualisieren()
            // Kabellinien-Anzahl-Cache aufbauen
            root.kabelLinienCacheAktualisieren()
            // HF-Referenz-Map aufbauen
            cacheHandler.hfReferenzMapAktualisieren()
            // SPS-Konflikt-Set aufbauen
            root.spsKonfliktAktualisieren()
            // Ansicht wiederherstellen oder zurücksetzen
            var _pendingZielPos = root._querverweisZielPos
            root._querverweisZielPos = null
            var _pendingAutoStart = root._fehlersuchAutoStartId
            root._fehlersuchAutoStartId = -1
            if (_pendingZielPos) {
                ansichtZuruecksetzen()
                Qt.callLater(function() { root._zoomZuWeltPosition(_pendingZielPos.x, _pendingZielPos.y) })
            } else {
                var saved = root._zoomPanCache[seiteId]
                if (saved !== undefined) {
                    root.zoom   = saved.zoom
                    root.worldX = saved.worldX
                    root.worldY = saved.worldY
                    root.repaintAll()
                } else {
                    ansichtZuruecksetzen()
                }
            }
            if (_pendingAutoStart > 0)
                Qt.callLater(function() { root.fehlersuchPfadBerechnen(_pendingAutoStart) })
        } else {
            root.normblattDaten   = null
            root.normblattLogoUrl = ""
            root.revisionStatus   = ""
            root.revisionKennung  = ""
            root.repaintAll()
        }
    }
    onWidthChanged:  root.repaintAll()
    onHeightChanged: root.repaintAll()

    DebugLabel { panelName: qsTr("Schaltplan-Canvas"); visible: root.debug }

    Dialog {
        id: duplizierAnzahlDialog
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: 260; padding: 20
        standardButtons: Dialog.NoButton

        background: Rectangle {
            color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 8
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: qsTr("Wie viele Dublikate?")
                font.pixelSize: 14; font.weight: Font.Medium; color: root.theme.textPrimary
            }

            Rectangle {
                Layout.fillWidth: true; implicitHeight: 32; radius: 4
                color: root.theme.inputBg
                border.color: anzahlField.activeFocus ? root.theme.accent : root.theme.border

                TextInput {
                    id: anzahlField
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                    font.pixelSize: 13; color: root.theme.textPrimary
                    text: "1"; selectByMouse: true; clip: true
                    validator: IntValidator { bottom: 1; top: 999 }
                    Keys.onReturnPressed: { duplizierAnzahlDialog.close(); root._duplizierAnzahlPlatzieren(parseInt(anzahlField.text) || 1) }
                    Keys.onEscapePressed: { duplizierAnzahlDialog.close(); root.abbruch() }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.theme.border }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: 90; implicitHeight: 30; radius: 4
                    color: abbMaus.containsMouse ? root.theme.hover : root.theme.inputBg
                    border.color: root.theme.border
                    Text { anchors.centerIn: parent; text: qsTr("Abbrechen"); font.pixelSize: 11; color: root.theme.textPrimary }
                    MouseArea { id: abbMaus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { duplizierAnzahlDialog.close(); root.abbruch() } }
                }

                Rectangle {
                    implicitWidth: 100; implicitHeight: 30; radius: 4
                    color: okMaus.containsMouse ? root.theme.accent : root.theme.inputBg
                    border.color: root.theme.accent
                    Text { anchors.centerIn: parent; text: qsTr("Platzieren"); font.pixelSize: 11; font.weight: Font.Medium
                           color: okMaus.containsMouse ? "white" : root.theme.accent }
                    MouseArea { id: okMaus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { var n = parseInt(anzahlField.text) || 1; duplizierAnzahlDialog.close(); root._duplizierAnzahlPlatzieren(n) } }
                }
            }
        }

        onOpened: { anzahlField.text = "1"; anzahlField.selectAll(); anzahlField.forceActiveFocus() }
    }

    // ── Sprungziel-Markierung ─────────────────────────────────────────────────
    property real _markerWeltX: 0
    property real _markerWeltY: 0

    function _zeigeMarker(wx, wy) {
        root._markerWeltX = wx
        root._markerWeltY = wy
        sprungMarker.visible = true
        sprungMarker.opacity = 1.0
        sprungMarkerAnim.restart()
    }

    Rectangle {
        id: sprungMarker
        visible: false
        x: root.worldX + root._markerWeltX * root.zoom - width  / 2
        y: root.worldY + root._markerWeltY * root.zoom - height / 2
        width: 64; height: 64; radius: 32
        color: "transparent"
        border.color: root.theme.accent
        border.width: 3
        opacity: 0

        SequentialAnimation {
            id: sprungMarkerAnim
            NumberAnimation { target: sprungMarker; property: "opacity"; to: 0.15; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: sprungMarker; property: "opacity"; to: 1.0;  duration: 140 }
            NumberAnimation { target: sprungMarker; property: "opacity"; to: 0.15; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: sprungMarker; property: "opacity"; to: 1.0;  duration: 140 }
            NumberAnimation { target: sprungMarker; property: "opacity"; to: 0.0;  duration: 700; easing.type: Easing.InQuart }
            ScriptAction { script: sprungMarker.visible = false }
        }
    }

    // ── BMK-Eingabe nach Bauteil-Platzierung ─────────────────────────────────
    property int    _bmkElementId:   -1
    property string _bmkBauteilBez:  ""

    function bauteilNachPlatzierenAusfuehren(elementId, bauteilBez, bauteilId) {
        if (elementId <= 0) return
        root._bmkElementId  = elementId
        root._bmkBauteilBez = bauteilBez
        root._bmkBauteilId  = bauteilId || 0
        bmkNachPlatzierenDialog.open()
    }

    Dialog {
        id: bmkNachPlatzierenDialog
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: 300; padding: 20
        standardButtons: Dialog.NoButton

        background: Rectangle {
            color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 8
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: qsTr("Betriebsmittelkennzeichen (BMK)")
                font.pixelSize: 14; font.weight: Font.Medium; color: root.theme.textPrimary
            }

            Text {
                visible: root._bmkBauteilBez.length > 0
                text: root._bmkBauteilBez
                font.pixelSize: 12; color: root.theme.textMuted
            }

            Rectangle {
                Layout.fillWidth: true; implicitHeight: 32; radius: 4
                color: root.theme.inputBg
                border.color: bmkField.activeFocus ? root.theme.accent : root.theme.border

                TextInput {
                    id: bmkField
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                    font.pixelSize: 13; color: root.theme.textPrimary
                    selectByMouse: true; clip: true
                    Keys.onReturnPressed: bmkNachPlatzierenDialog.bmkAnlegenUndSchliessen()
                    Keys.onEscapePressed: { bmkNachPlatzierenDialog.close() }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.theme.border }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: 90; implicitHeight: 30; radius: 4
                    color: uebMaus.containsMouse ? root.theme.hover : root.theme.inputBg
                    border.color: root.theme.border
                    Text { anchors.centerIn: parent; text: qsTr("Überspringen"); font.pixelSize: 11; color: root.theme.textPrimary }
                    MouseArea { id: uebMaus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: bmkNachPlatzierenDialog.close() }
                }

                Rectangle {
                    implicitWidth: 90; implicitHeight: 30; radius: 4
                    color: bmkOkMaus.containsMouse ? root.theme.accent : root.theme.inputBg
                    border.color: root.theme.accent
                    Text { anchors.centerIn: parent; text: qsTr("Anlegen"); font.pixelSize: 11; font.weight: Font.Medium
                           color: bmkOkMaus.containsMouse ? "white" : root.theme.accent }
                    MouseArea { id: bmkOkMaus; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: bmkNachPlatzierenDialog.bmkAnlegenUndSchliessen() }
                }
            }
        }

        function bmkAnlegenUndSchliessen() {
            var kz = bmkField.text.trim()
            if (kz.length > 0 && root._bmkElementId > 0) {
                var bmId = db.betriebsmittelAnlegen(root.projektId, kz, root._bmkBauteilBez, root._bmkBauteilId)
                if (bmId > 0) {
                    db.grafikElementVerknuepfen(root._bmkElementId, bmId)
                    db.betriebsmittelHauptfunktionSetzen(bmId, root._bmkElementId)
                    db.betriebsmittelBmkSynchronisieren(bmId)
                    root.seiteNeuLaden()
                    root.hfKarteAktualisieren()
                }
            }
            bmkNachPlatzierenDialog.close()
        }

        onOpened: { bmkField.text = ""; bmkField.forceActiveFocus() }
    }
}
