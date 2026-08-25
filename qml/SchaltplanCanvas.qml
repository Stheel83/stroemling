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
    // OPT-VERBRENDER-CACHE-01: von maleAutoVerbindungen() pro Repaint aus
    // _cachedNetze abgeleitete Geometrie — sonst wurden Kreuzungslücken
    // (O(h×v)-Doppelschleife) und die Aderdefinitionspunkt-Liste bei JEDEM
    // Repaint neu berechnet, auch beim reinen Schwenken/Zoomen ohne Modelländerung.
    property var _cachedKreuzungsLuecken: null   // {segKey → [x, …]}
    property var _cachedAdpList:          null   // [{cx, cy, ed}, …]
    property var _cachedRoutingFarben:    null   // berechneRoutingSymbolFarben()-Ergebnis

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
        strichBreite:   0.35,
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
    // Anzeige-Toggle: false = Signaltyp-/Kategorie-Farbe (Default beim Eintritt
    // in den Modus), true = Aderfarbe (für Abgleich mit der Dokumentation).
    // Wird beim erneuten Öffnen des Fehlersuchmodus in Main.qml zurückgesetzt.
    property bool fehlersuchZeigeAderfarbe:  false
    onFehlersuchZeigeAderfarbeChanged: drawCanvas.requestPaint()
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

    // Render-Helferfunktionen ausgelagert (REFACTOR-01 Stufe 5a+5b)
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
                // OPT-DRAG-NETZ-DEFER-01: während eines aktiven Verschieben-/
                // Griff-Drags feuert geaendert() bei JEDER Mausbewegung — die
                // Netz-/Verbindungslinien-Caches hier trotzdem jedes Mal zu
                // invalidieren macht die volle Neuberechnung (Union-Find +
                // Kreuzungslücken + Bänderung) zum Flaschenhals des Drags
                // (real gemessen: ~150-220ms von ~250-300ms Frame-Zeit).
                // Während des Drags bleiben Netzfarben/Verbindungslinien daher
                // auf dem letzten Stand (bei einem schnellen Zug ohnehin nicht
                // ablesbar) — root.netzCacheInvalidieren() wird stattdessen
                // einmal beim Loslassen aufgerufen (CanvasInteraktionArea.qml).
                if (!root.amVerschieben && root.aktiverGriff < 0 && !root.labelDragAktiv) {
                    root._cachedNetze = null
                    root._cachedKabelSchnitte = {}
                    root._cachedKreuzungsLuecken = null
                    root._cachedAdpList          = null
                    root._cachedRoutingFarben     = null
                }
                drawCanvas.requestPaint()
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
            // Netzberechnung vorab: Winkel/Treffpunkt brauchen die Segmentfarbe
            // schon in der Elemente-Schleife (transparenter Durchlauf, s.o.)
            var _repaintNetze   = netzHandler.autoNetzeBerechnenCached()
            var _routingFarben  = renderHandler.berechneRoutingSymbolFarben(_repaintNetze)
            for (var i=0; i<elemente.length; i++)
                renderHandler.maleElement(ctx, elemente[i], i, _routingFarben)

            renderHandler.maleKlemmenHighlight(ctx, elemente)

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
            renderHandler.malePolygonVorschau(ctx)
            renderHandler.maleAutoVerbindungen(ctx, _repaintNetze)
            // Schnittpunkte aller Kabellinien mit Auto-Verbindungen (Phase 5)
            for (var kli = 0; kli < elemente.length; kli++) {
                if (elemente[kli].typ === "kabellinie")
                    renderHandler.maleKabelSchnitte(ctx, elemente[kli], _repaintNetze)
            }
            renderHandler.maleRubberband(ctx)
            renderHandler.maleGruppenindikator(ctx)
            renderHandler.maleStapelIndikator(ctx, elemente)
            renderHandler.drawNormblattAussenoverlay(ctx)
            renderHandler.maleRevisionsWasserzeichen(ctx)
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
            root._konfliktNeuentstehungPruefen(netze)
        }
    }

    // AALS-OB-01: reagiert nur auf NEU entstandene Potenzialkonflikte (nicht auf
    // bereits bestehende), ausgelöst beim Loslassen der Maus (grafikSpeichernJetzt()
    // läuft nach jeder Drag-/Resize-/Lösch-Interaktion). _bekannteKonfliktNetze ist
    // null direkt nach einem Seitenwechsel (onSeiteIdChanged) — der erste Check
    // danach legt nur die Baseline an, ohne zu feuern (verhindert Fehlalarm bei
    // einer Seite, die schon mit bestehendem Konflikt geöffnet wird).
    property var _bekannteKonfliktNetze: null
    signal verbindungKonfliktNeu()
    function _konfliktNeuentstehungPruefen(netze) {
        var aktuell = {}
        for (var i = 0; i < netze.length; i++) {
            if (netze[i].signaltyp !== "konflikt") continue
            var k = netze[i].netKey || netze[i].legacyNetKey
            if (k) aktuell[k] = true
        }
        if (root._bekannteKonfliktNetze !== null) {
            for (var key in aktuell) {
                if (!root._bekannteKonfliktNetze[key]) {
                    root.verbindungKonfliktNeu()
                    break
                }
            }
        }
        root._bekannteKonfliktNetze = aktuell
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
            // Anker-Pin (nicht der Bbox-Mittelpunkt) landet auf dem
            // gesnappten Mauspunkt (SYMBOL-ANKER-01) — wichtig bei Symbolen
            // mit ungeraden Rastereinheiten (z.B. 12mm-Kontakte), deren
            // Mittelpunkt sonst nicht selbst aufs 4mm-Raster fiele.
            var pos = geometrieHandler.boxPositionFuerAnker(sid, defW, defH, rot, wx, wy)
            x1 = pos.x1; y1 = pos.y1
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
    function ankerOffsetFuerElement(el)    { return geometrieHandler.ankerOffsetFuerElement(el) }

    // --------------------------------------------------------
    // Ansicht
    // --------------------------------------------------------
    function repaintAll() { gridCanvas.requestPaint(); drawCanvas.requestPaint() }

    // OPT-DRAG-NETZ-DEFER-01: einmalige Netz-/Verbindungslinien-Cache-
    // Invalidierung beim Loslassen eines Verschieben-/Griff-Drags (s.
    // elementeModel.onGeaendert oben, das während des Drags absichtlich
    // NICHT invalidiert).
    function netzCacheInvalidieren() {
        root._cachedNetze            = null
        root._cachedKabelSchnitte    = {}
        root._cachedKreuzungsLuecken = null
        root._cachedAdpList          = null
        root._cachedRoutingFarben    = null
        drawCanvas.requestPaint()
    }

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
        root._bekannteKonfliktNetze = null
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

    DebugLabel { panelName: qsTr("Schaltplan-Canvas"); corner: "bl"; visible: root.debug }

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
