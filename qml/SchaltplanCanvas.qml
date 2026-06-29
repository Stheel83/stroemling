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

    function aderFarbeZuCanvas(code) { return drawCanvas.aderFarbeZuCanvas(code) }
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
        var netze = drawCanvas.autoNetzeBerechnenCached()
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
    function verbindungBeiPosition(x, y)   { return drawCanvas.verbindungBeiPosition(x, y) }
    function kabelKreuzungBeiPosition(x, y) { return drawCanvas.kabelKreuzungBeiPosition(x, y) }
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
        var vpos              = root.weltZuViewport(el.x1, el.y1)
        root.textEditVpX      = vpos.x; root.textEditVpY   = vpos.y
        root.textEditElIdx    = idx
        root.textEditSnapshot = elementeModel.snapshot()
        root.textEditAktiv    = true
        textEditorKomp.oeffnen(el.textInhalt || "", true)
    }
    function kabellinieDialogFuerNeuOeffnen(elIdx) { dialogLayer.kabellinieNeuOeffnen(elIdx) }
    function makrobenennDialogFuerNeuOeffnen(elIdx) { dialogLayer.makrobenennNeuOeffnen(elIdx) }

    // Aderzuordnungsdialog vorbereiten (drawCanvas-Zugriffe bleiben hier) und öffnen
    function kabellinieNachSpeichernAderZuordnung(newKabelId, bezeichnung, kabeltyp, aderzahl, bkAdern, freshKlEl) {
        var neueNetze = drawCanvas.autoNetzeBerechnen()
        var schnitte  = drawCanvas.kabelSchnittNetzeBerechnen(freshKlEl, neueNetze)
        if (schnitte.length > 0) {
            dialogLayer.aderzuordnungOeffnen(
                newKabelId, bezeichnung, kabeltyp, aderzahl, bkAdern,
                schnitte, {}, freshKlEl.id || 0, _pinNummernFuerNetze(neueNetze))
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

        // Normgerechte Textrotation: Text darf nie kopfstehen (max. 90°).
        // Gibt den Canvas-Winkel in Radiant zurück:
        //   0° / 180° → 0  (waagrecht, normal)
        //   90° / 270° → −π/2  (senkrecht, von rechts lesbar = CCW 90°)
        function normTextRot(rotation) {
            var r = ((rotation % 360) + 360) % 360
            return (r === 90 || r === 270) ? -Math.PI / 2 : 0
        }

        function roundRect(ctx, x, y, w, h, r) {
            r = Math.min(Math.abs(r), Math.abs(w)/2, Math.abs(h)/2)
            ctx.beginPath()
            ctx.moveTo(x+r,y); ctx.lineTo(x+w-r,y); ctx.quadraticCurveTo(x+w,y,x+w,y+r)
            ctx.lineTo(x+w,y+h-r); ctx.quadraticCurveTo(x+w,y+h,x+w-r,y+h)
            ctx.lineTo(x+r,y+h); ctx.quadraticCurveTo(x,y+h,x,y+h-r)
            ctx.lineTo(x,y+r); ctx.quadraticCurveTo(x,y,x+r,y); ctx.closePath()
        }


        // Weißes Hintergrundfeld hinter einem einzelnen Text-Label.
        // Muss VOR ctx.strokeText/fillText aufgerufen werden.
        // ctx.textAlign und ctx.textBaseline müssen bereits gesetzt sein.
        function textHintergrundFeld(ctx, text, x, y, fs) {
            var w   = ctx.measureText(text).width
            var pad = 2
            var bx  = ctx.textAlign === "center" ? x - w / 2 - pad
                    : ctx.textAlign === "right"  ? x - w - pad
                    :                              x - pad
            var by  = ctx.textBaseline === "bottom" ? y - fs - pad
                    : ctx.textBaseline === "top"    ? y - pad
                    :                                 y - fs * 0.5 - pad
            var savedFill = ctx.fillStyle
            ctx.fillStyle = "rgba(255, 255, 255, 0.65)"
            ctx.fillRect(bx, by, w + 2 * pad, fs + 2 * pad)
            ctx.fillStyle = savedFill
        }

        // Kapsel-/Stadium-Form: zwei echte Halbkreise an den kürzeren Seiten,
        // verbunden durch zwei parallele Geraden (kein echtes Oval). Radius
        // = halbe Breite ODER halbe Höhe, je nachdem welche Dimension kleiner
        // ist — orientierungsabhängig, damit eine hochkant gedrehte Form (z.B.
        // Schirm-Symbol nach 90°-Drehung) korrekt mit Kappen oben/unten statt
        // links/rechts gezeichnet wird. Für das Schirm-Symbol (§2 in 46_schirmung.md).
        function stadiumPfad(ctx, x, y, w, h) {
            ctx.beginPath()
            if (w >= h) {
                var r = h/2, lcx = x+r, rcx = x+w-r, cy = y+h/2
                ctx.moveTo(lcx, y); ctx.lineTo(rcx, y)
                ctx.arc(rcx, cy, r, -Math.PI/2, Math.PI/2, false)
                ctx.lineTo(lcx, y+h)
                ctx.arc(lcx, cy, r, Math.PI/2, 3*Math.PI/2, false)
            } else {
                var r2 = w/2, tcy = y+r2, bcy = y+h-r2, cx = x+w/2
                ctx.moveTo(x+w, tcy); ctx.lineTo(x+w, bcy)
                ctx.arc(cx, bcy, r2, 0, Math.PI, false)
                ctx.lineTo(x, tcy)
                ctx.arc(cx, tcy, r2, Math.PI, 2*Math.PI, false)
            }
            ctx.closePath()
        }

        // ── Normblattrahmen (DIN 6771, vereinfacht) ──────────────────────
        function drawNormblatt(ctx) {
            if (!root.normblattDaten) return
            if (!root.normblattDaten.normblattAnzeigen) return

            var nd   = root.normblattDaten
            var z    = root.zoom
            var mpx  = root.mmToPx   // world-px per mm

            // mm → screen pixels
            function s(mm) { return mm * mpx * z }
            // world-px → screen
            function sx(wx) { return wx * z + root.worldX }
            function sy(wy) { return wy * z + root.worldY }

            var bMm = nd.breiteMm || 297
            var hMm = nd.hoeheMm  || 210
            var mL  = nd.randLinksMm  || 10
            var mR  = nd.randRechtsMm || 10
            var mO  = nd.randObenMm   || 10
            var mU  = nd.randUntenMm  || 10

            // Page corners on screen
            var pX0 = sx(0),           pY0 = sy(0)
            var pX1 = sx(bMm * mpx),   pY1 = sy(hMm * mpx)

            // Inner frame corners on screen
            var iX0 = sx(mL * mpx),              iY0 = sy(mO * mpx)
            var iX1 = sx((bMm - mR) * mpx),      iY1 = sy((hMm - mU) * mpx)
            var iW  = iX1 - iX0,                  iH  = iY1 - iY0

            ctx.save()
            ctx.setLineDash([])
            ctx.lineCap   = "square"
            ctx.lineJoin  = "miter"

            // ── Seitenhintergrund (konfigurierbar; leer = transparent) ──
            var bgFarbe = (nd.hintergrundFarbe || "").toString().trim()
            if (bgFarbe) {
                ctx.fillStyle = bgFarbe
                ctx.fillRect(pX0, pY0, pX1 - pX0, pY1 - pY0)
            }

            // ── Seitenbegrenzung (dünn, gestrichelt) ──
            ctx.strokeStyle = "#2a4a7a"
            ctx.lineWidth   = Math.max(0.5, s(0.25))
            ctx.setLineDash([s(3), s(2)])
            ctx.strokeRect(pX0, pY0, pX1 - pX0, pY1 - pY0)
            ctx.setLineDash([])

            // ── Zeichnungsrahmen (dick) ──
            ctx.strokeStyle = "#4a7ab0"
            ctx.lineWidth   = Math.max(1, s(0.7))
            ctx.strokeRect(iX0, iY0, iW, iH)

            // ── Benutzerdefinierte Felder (Phase 2) ──────────────────────
            var _felder = nd.felder
            if (_felder && _felder.length > 0) {
                var _feldWert = function(f) {
                    var ft = f.feldtyp || "fest"
                    if (ft === "fest")            return f.inhalt || ""
                    if (ft === "datum")           return datumText()
                    if (ft === "vollkennzeichen") return vollkz()
                    if (ft === "format")          return formatText()
                    var qs = f.quelleSpalte || ""
                    var qmap = {
                        "name": nd.projektName,         "projektnummer": nd.projektnummer,
                        "auftraggeber": nd.auftraggeber, "auftragnehmer": nd.auftragnehmer,
                        "bearbeiter": nd.bearbeiter,    "norm": nd.norm,
                        "blattnummer": nd.blattnummer,  "bezeichnung": nd.bezeichnung,
                        "anlage_kuerzel": nd.anlageKuerzel, "ort_kuerzel": nd.ortKuerzel
                    }
                    return (qmap[qs] || "").toString()
                }
                for (var _fi = 0; _fi < _felder.length; _fi++) {
                    var _f = _felder[_fi]
                    var _fx = sx(_f.xMm   * mpx)
                    var _fy = sy(_f.yMm   * mpx)
                    var _fw = s(_f.breiteMm)
                    var _fh = s(_f.hoeheMm)
                    if (_f.feldtyp === "logo") {
                        if (root.normblattLogoUrl && drawCanvas.isImageLoaded(root.normblattLogoUrl)) {
                            ctx.save()
                            ctx.beginPath(); ctx.rect(_fx+1, _fy+1, _fw-2, _fh-2); ctx.clip()
                            var _pad = s(2)
                            ctx.drawImage(root.normblattLogoUrl, _fx+_pad, _fy+_pad, _fw-2*_pad, _fh-2*_pad)
                            ctx.restore()
                        }
                    } else {
                        zelle(_f.label || "", _feldWert(_f), _fx, _fy, _fw, _fh)
                    }
                    if (_f.rahmen) {
                        ctx.strokeStyle = "#2a5080"
                        ctx.lineWidth   = Math.max(0.5, s(0.25))
                        ctx.strokeRect(_fx, _fy, _fw, _fh)
                    }
                }
                ctx.restore()
                return
            }

            var vorlage = (nd.titelblattVorlage || "din6771").toString()

            // ── Schriftfeld ──────────────────────────────────────────────
            if (vorlage === "rahmen") {
                ctx.restore()
                return
            }

            // Hilfsfunktionen (für alle Vorlagen verfügbar)
            function zelle(label, wert, x, y, w, h) {
                ctx.save()
                ctx.beginPath(); ctx.rect(x + 1, y + 1, w - 2, h - 2); ctx.clip()
                // Positionen proportional zur Zeilenhöhe h – funktioniert für 8mm und 13mm
                var lFs = Math.max(5, Math.min(h * 0.22, s(2.8)))
                ctx.font = lFs + "px sans-serif"; ctx.fillStyle = "#5a7aa0"
                ctx.textBaseline = "top"
                ctx.fillText(label, x + s(1.0), y + h * 0.08)
                var vFs = Math.max(7, Math.min(h * 0.38, s(4.5)))
                ctx.font = "600 " + vFs + "px sans-serif"; ctx.fillStyle = "#c8ddf0"
                ctx.fillText(wert || "", x + s(1.2), y + h * 0.42)
                ctx.restore()
            }
            function formatText() {
                var b = nd.breiteMm || 297, h = nd.hoeheMm || 210
                var mx = Math.max(b, h), mn = Math.min(b, h), fmt = ""
                if      (Math.abs(mx - 420) < 5 && Math.abs(mn - 297) < 5) fmt = "A3"
                else if (Math.abs(mx - 297) < 5 && Math.abs(mn - 210) < 5) fmt = "A4"
                else if (Math.abs(mx - 594) < 5 && Math.abs(mn - 420) < 5) fmt = "A2"
                else fmt = Math.round(b) + "×" + Math.round(h)
                return fmt + (b > h ? " QF" : " HF")
            }
            function vollkz() {
                var auo = nd.anlageUO || "", ouo = nd.ortUO || ""
                var a = nd.anlageKuerzel || "", o = nd.ortKuerzel || "", bn = nd.blattnummer || ""
                var kz = ""
                if (auo) kz += "==" + auo
                if (ouo) kz += "++" + ouo
                if (a)   kz += "=" + a
                if (o)   kz += "+" + o
                if (kz) kz += "/"
                return kz + bn
            }
            function datumText() {
                var raw = (nd.erstelltAm || "").toString()
                if (raw.length >= 10) {
                    var parts = raw.substring(0, 10).split("-")
                    if (parts.length === 3) return parts[2] + "." + parts[1] + "." + parts[0]
                }
                return raw
            }

            if (vorlage === "kompakt") {
                // ── Kompakt: 2 Zeilen × 8 mm ────────────────────────────
                var kRowH = s(8)
                var kSfY0 = iY1 - 2 * kRowH
                var kSfH  = 2 * kRowH
                var kCx = [ iX0, iX0 + iW * 0.45, iX0 + iW * 0.72, iX1 ]
                var kRy = [ kSfY0, kSfY0 + kRowH ]

                ctx.strokeStyle = "#2a5080"
                ctx.lineWidth   = Math.max(0.5, s(0.25))
                for (var kc = 1; kc <= 2; kc++) {
                    ctx.beginPath(); ctx.moveTo(kCx[kc], kSfY0); ctx.lineTo(kCx[kc], iY1); ctx.stroke()
                }
                for (var kr = 0; kr < 2; kr++) {
                    ctx.beginPath(); ctx.moveTo(iX0, kRy[kr]); ctx.lineTo(iX1, kRy[kr]); ctx.stroke()
                }

                zelle("PROJEKT",      nd.projektName  || "", kCx[0], kRy[0], kCx[1]-kCx[0], kRowH)
                zelle("BLATT",        nd.blattnummer  || "", kCx[1], kRy[0], kCx[2]-kCx[1], kRowH)
                zelle("DATUM",        datumText(),           kCx[2], kRy[0], kCx[3]-kCx[2], kRowH)
                zelle("BEZEICHNUNG",  nd.bezeichnung  || "", kCx[0], kRy[1], kCx[1]-kCx[0], kRowH)
                zelle("SEITENKENNZ.", vollkz(),              kCx[1], kRy[1], kCx[2]-kCx[1], kRowH)
                zelle("BEARBEITER",   nd.bearbeiter   || "", kCx[2], kRy[1], kCx[3]-kCx[2], kRowH)

                ctx.strokeStyle = "#4a7ab0"
                ctx.lineWidth   = Math.max(1, s(0.7))
                ctx.strokeRect(iX0, kSfY0, iW, kSfH)

            } else {
                // ── DIN 6771: 3 Zeilen × 13 mm ──────────────────────────
                var rowH = s(13)
                var sfY0 = iY1 - 3 * rowH
                var sfH  = iY1 - sfY0

                ctx.fillStyle = "rgba(5, 15, 35, 0.80)"
                ctx.fillRect(iX0, sfY0, iW, sfH)

                var cX = [ iX0, iX0 + iW * 0.21, iX0 + iW * 0.66, iX0 + iW * 0.86, iX1 ]
                var rowY = [ sfY0, sfY0 + rowH, sfY0 + 2 * rowH ]

                ctx.strokeStyle = "#2a5080"
                ctx.lineWidth   = Math.max(0.5, s(0.25))
                for (var c = 1; c <= 3; c++) {
                    ctx.beginPath(); ctx.moveTo(cX[c], sfY0); ctx.lineTo(cX[c], iY1); ctx.stroke()
                }
                for (var r = 0; r < 3; r++) {
                    ctx.beginPath(); ctx.moveTo(iX0, rowY[r]); ctx.lineTo(iX1, rowY[r]); ctx.stroke()
                }

                zelle("AUFTRAGGEBER", nd.auftraggeber  || "", cX[0], rowY[0], cX[1]-cX[0], rowH)
                zelle("PROJEKT",      nd.projektName   || "", cX[1], rowY[0], cX[2]-cX[1], rowH)
                zelle("PROJEKTNR.",   nd.projektnummer || "", cX[2], rowY[0], cX[3]-cX[2], rowH)
                zelle("BLATT",        nd.blattnummer   || "", cX[3], rowY[0], cX[4]-cX[3], rowH)

                if (root.normblattLogoUrl && drawCanvas.isImageLoaded(root.normblattLogoUrl)) {
                    ctx.save()
                    var lx = cX[0], ly = rowY[1], lw = cX[1]-cX[0], lh = rowH
                    ctx.beginPath(); ctx.rect(lx+1, ly+1, lw-2, lh-2); ctx.clip()
                    var pad = s(2)
                    ctx.drawImage(root.normblattLogoUrl, lx+pad, ly+pad, lw-2*pad, lh-2*pad)
                    ctx.restore()
                } else {
                    zelle("AUFTRAGNEHMER", nd.auftragnehmer || "", cX[0], rowY[1], cX[1]-cX[0], rowH)
                }
                zelle("BEZEICHNUNG",  nd.bezeichnung  || "", cX[1], rowY[1], cX[2]-cX[1], rowH)
                zelle("FORMAT",       formatText(),          cX[2], rowY[1], cX[3]-cX[2], rowH)
                zelle("DATUM",        datumText(),           cX[3], rowY[1], cX[4]-cX[3], rowH)

                zelle("BEARBEITER",   nd.bearbeiter || "",   cX[0], rowY[2], cX[1]-cX[0], rowH)
                zelle("SEITENKENNZ.", vollkz(),              cX[1], rowY[2], cX[2]-cX[1], rowH)
                zelle("NORM",         nd.norm || "IEC",      cX[2], rowY[2], cX[3]-cX[2], rowH)
                zelle("REV.",         root.revisionKennung || "–", cX[3], rowY[2], cX[4]-cX[3], rowH)

                ctx.strokeStyle = "#4a7ab0"
                ctx.lineWidth   = Math.max(1, s(0.7))
                ctx.strokeRect(iX0, sfY0, iW, sfH)
            }

            ctx.restore()
        }

        // ── Außenbereich-Overlay: Bereich außerhalb der Seite abdunkeln ──
        function drawNormblattAussenoverlay(ctx) {
            if (!root.normblattDaten) return
            if (!root.normblattDaten.normblattAnzeigen) return
            if (!root.normblattDaten.aussenOverlay) return
            var nd  = root.normblattDaten
            var z   = root.zoom
            var mpx = root.mmToPx
            function sx(wx) { return wx * z + root.worldX }
            function sy(wy) { return wy * z + root.worldY }
            var bMm = nd.breiteMm || 297, hMm = nd.hoeheMm || 210
            var pX0 = sx(0),         pY0 = sy(0)
            var pX1 = sx(bMm * mpx), pY1 = sy(hMm * mpx)
            ctx.save()
            ctx.fillStyle = "rgba(0,0,0,0.28)"
            if (pY0 > 0)            ctx.fillRect(0,    0,    drawCanvas.width, pY0)
            if (pY1 < drawCanvas.height) ctx.fillRect(0, pY1, drawCanvas.width, drawCanvas.height - pY1)
            if (pX0 > 0)            ctx.fillRect(0,   pY0, pX0,                        pY1 - pY0)
            if (pX1 < drawCanvas.width)  ctx.fillRect(pX1, pY0, drawCanvas.width - pX1, pY1 - pY0)
            ctx.restore()
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

        function maleElement(ctx, el, idx) {
            var vorschau  = (idx < 0)
            var gewaehlt  = (!vorschau && root.auswahl.indexOf(idx) >= 0)
            var _skipText = !vorschau && root.bewegungAktiv

            // ── Fehlersuchmodus: Dimm-Faktor ─────────────────────
            var dimFaktor = 1.0
            if (!vorschau && root.fehlersuchModus) {
                var pfadKeys = Object.keys(root.fehlersuchPfadIds)
                if (pfadKeys.length > 0) {
                    if (root.fehlersuchPfadIds[(el.id || -1)] !== undefined) {
                        dimFaktor = 1.0
                    } else {
                        dimFaktor = 0.12
                    }
                }
            }

            var sf  = el.strichFarbe     !== undefined ? el.strichFarbe     : "#4a9eff"
            var sb  = el.strichBreite    !== undefined ? el.strichBreite    : 1.5
            var sa  = el.strichArt       !== undefined ? el.strichArt       : "solid"
            var fu  = el.fuell           !== undefined ? el.fuell           : false
            var ff  = el.fuellFarbe      !== undefined ? el.fuellFarbe      : "#1a3a6a"
            var fo  = el.fuellOpazitaet  !== undefined ? el.fuellOpazitaet  : 0.3
            var op  = (el.opazitaet !== undefined ? el.opazitaet : 1.0) * dimFaktor
            var er  = el.eckenRadius      !== undefined ? el.eckenRadius      : 0

            // Leitungen im Pfad: Akzentfarbe + dickere Linie
            if (!vorschau && root.fehlersuchModus && root.fehlersuchPfadIds[(el.id || -1)] !== undefined &&
                    (el.typ === "linie" || el.typ === "polygonlinie")) {
                sf = root.theme.accent
                sb = sb + 0.8
            }

            var vx1 = el.x1 * root.zoom + root.worldX
            var vy1 = el.y1 * root.zoom + root.worldY
            var vx2 = el.x2 * root.zoom + root.worldX
            var vy2 = el.y2 * root.zoom + root.worldY

            // Viewport-Culling: Elemente außerhalb des Sichtbereichs überspringen.
            // Puffer 200px für Labels/BMK-Texte die über die Bounding-Box hinausragen.
            if (!vorschau) {
                var _margin = 200
                if (Math.max(vx1, vx2) + _margin < 0        || Math.min(vx1, vx2) - _margin > drawCanvas.width  ||
                    Math.max(vy1, vy2) + _margin < 0        || Math.min(vy1, vy2) - _margin > drawCanvas.height)
                    return
            }

            ctx.globalAlpha = vorschau ? 0.55 : op

            var lw = gewaehlt ? sb + 0.5 : sb
            if (vorschau)           { ctx.setLineDash([5,4]);              ctx.lineCap = "butt"  }
            else if (sa==="gestrichelt") { ctx.setLineDash([lw*5,lw*3]);   ctx.lineCap = "butt"  }
            else if (sa==="gepunktet")   { ctx.setLineDash([0.1,lw*3]);    ctx.lineCap = "round" }
            else                    { ctx.setLineDash([]);                 ctx.lineCap = "butt"  }

            ctx.lineWidth   = lw
            ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)

            var rc = { vorschau: vorschau, gewaehlt: gewaehlt, skipText: _skipText,
                       sf: sf, sb: sb, sa: sa, fu: fu, ff: ff, fo: fo, op: op, er: er,
                       vx1: vx1, vy1: vy1, vx2: vx2, vy2: vy2, lw: lw, idx: idx }

            if      (el.typ === "linie")          _renderLinie(ctx, el, rc)
            else if (el.typ === "kabellinie")     _renderKabellinie(ctx, el, rc)
            else if (el.typ === "polygonlinie")   _renderPolygonlinie(ctx, el, rc)
            else if (el.typ === "rechteck")       _renderRechteck(ctx, el, rc)
            else if (el.typ === "kreis")          _renderKreis(ctx, el, rc)
            else if (el.typ === "text")           _renderText(ctx, el, rc)
            else if (el.typ === "bild")           _renderBild(ctx, el, rc)
            else if (el.typ === "notiz")          _renderNotiz(ctx, el, rc)
            else if (el.typ === "symbol")         _renderSymbol(ctx, el, rc)
            else if (el.typ === "geraetekasten")  _renderGeraetekasten(ctx, el, rc)
            else if (el.typ === "strukturkasten") _renderStrukturkasten(ctx, el, rc)
            else if (el.typ === "makrokasten")    _renderMakrokasten(ctx, el, rc)
            else if (el.typ === "schirm")         _renderSchirm(ctx, el, rc)

            ctx.setLineDash([]); ctx.lineCap="butt"; ctx.globalAlpha=1.0

            if (!vorschau && el.typ !== "symbol" && el.typ !== "polygonlinie"
                         && el.typ !== "rechteck" && el.typ !== "kreis"
                         && el.typ !== "geraetekasten"
                         && el.typ !== "strukturkasten" && el.typ !== "makrokasten"
                         && el.typ !== "schirm"
                         && el.typ !== "bild"  && el.typ !== "notiz") {
                ctx.fillStyle = gewaehlt ? "#f0a030" : sf
                ctx.beginPath(); ctx.arc(vx1,vy1,2.5,0,2*Math.PI); ctx.fill()
            }

            // Resize-Griffe nur bei Einzelauswahl
            if (gewaehlt && root.auswahl.length === 1) {
                var pts = drawCanvas.griffPunkte(el)
                ctx.fillStyle="#f0a030"; ctx.strokeStyle="#ffffff"
                ctx.lineWidth=1; ctx.setLineDash([])
                for (var i=0; i<pts.length; i++) {
                    var gx=pts[i].x*root.zoom+root.worldX, gy=pts[i].y*root.zoom+root.worldY
                    ctx.fillRect(gx-5,gy-5,10,10); ctx.strokeRect(gx-5,gy-5,10,10)
                }
            }

            // Debug: Element-Beschriftung (Strg+Shift+D)
            if (root.debug && !vorschau && !_skipText) {
                ctx.save()
                var dbgLabel = idx + ": " + el.typ
                if (el.typ === "symbol") dbgLabel += "/" + (el.symbolId || "?")
                if (el.id) dbgLabel += " #" + el.id
                var dbgFs = Math.max(8, Math.round(7 * root.zoom))
                var dbgCx = (vx1 + vx2) / 2
                var dbgTy = Math.min(vy1, vy2) - 1
                ctx.font         = dbgFs + "px monospace"
                ctx.textAlign    = "center"
                ctx.textBaseline = "bottom"
                ctx.globalAlpha  = 0.9
                ctx.fillStyle    = "#000000"
                ctx.lineWidth    = 2
                ctx.strokeStyle  = "#000000"
                ctx.strokeText(dbgLabel, dbgCx, dbgTy)
                ctx.fillStyle    = "#ff8800"
                ctx.fillText(dbgLabel, dbgCx, dbgTy)
                ctx.restore()
            }
        }

        function _renderLinie(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            ctx.beginPath(); ctx.moveTo(vx1,vy1); ctx.lineTo(vx2,vy2); ctx.stroke()
        }

        function _renderKabellinie(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            // Kabeldefinitionslinie: dicke, orange gestrichelte Linie mit Pfeilspitzen
            var klColor = gewaehlt ? "#f0a030" : (vorschau ? "#1a55cc" : (el.strichFarbe || "#e07000"))
            ctx.save()
            ctx.strokeStyle = klColor
            ctx.lineWidth   = gewaehlt ? 3.5 : 2.5
            ctx.setLineDash([10, 5])
            ctx.lineCap = "round"
            ctx.beginPath(); ctx.moveTo(vx1,vy1); ctx.lineTo(vx2,vy2); ctx.stroke()
            // Endpunkte als kleine Kreise markieren
            ctx.setLineDash([])
            ctx.fillStyle = klColor
            ctx.beginPath(); ctx.arc(vx1,vy1, 4, 0, 2*Math.PI); ctx.fill()
            ctx.beginPath(); ctx.arc(vx2,vy2, 4, 0, 2*Math.PI); ctx.fill()
            // Kabelkopf-Label nach §6.2: mehrzeilig neben dem Startpunkt
            if (!vorschau) {
                var klEx  = el.extraDaten || {}
                var klBez = klEx.bezeichnung    || ""
                var klTyp = klEx.kabeltyp       || ""
                var klAdz = klEx.aderzahl       || 0
                var klQue = klEx.querschnittMm2 || 0
                var klLen = klEx.laenge_m       || 0
                var klZeilen = []
                if (klBez !== "") klZeilen.push({ text: klBez, bold: true })
                if (klTyp !== "") klZeilen.push({ text: klTyp, bold: false })
                // Zeile 3 nur wenn kein 'x'/'×' im Kabeltyp
                var klTypHatX = klTyp !== "" && (klTyp.indexOf("x") >= 0 || klTyp.indexOf("×") >= 0 || klTyp.indexOf("X") >= 0)
                if (!klTypHatX && (klAdz > 0 || klQue > 0)) {
                    var klZ3 = ""
                    if (klAdz > 0 && klQue > 0)
                        klZ3 = klAdz + " × " + (klQue + "").replace(".", ",") + " mm²"
                    else if (klAdz > 0)
                        klZ3 = klAdz + " " + qsTr("Adern")
                    else
                        klZ3 = (klQue + "").replace(".", ",") + " mm²"
                    klZeilen.push({ text: klZ3, bold: false })
                }
                if (klLen > 0)
                    klZeilen.push({ text: "→ " + (klLen + "").replace(".", ",") + " m", bold: false })
                var klKabelId    = klEx.kabelId || 0
                var klGesamtLinien = (klKabelId > 0 && root._kabelLinienCache[klKabelId]) || 0
                if (klGesamtLinien > 1) {
                    var klWeitere = klGesamtLinien - 1
                    klZeilen.push({ text: "→ +" + klWeitere + " " + (klWeitere === 1 ? qsTr("Linie") : qsTr("Linien")), bold: false })
                }
                if (klZeilen.length > 0 && 2.5 * root.mmToPx * root.zoom >= 7) {
                    // Senkrechte zur Linie, auf der "oben"-Seite (negativstes y in Viewport)
                    var klDxL = vx2 - vx1, klDyL = vy2 - vy1
                    var klLLen = Math.sqrt(klDxL*klDxL + klDyL*klDyL) || 1
                    var ccwXL = -klDyL/klLLen, ccwYL = klDxL/klLLen
                    var cwXL  =  klDyL/klLLen, cwYL  = -klDxL/klLLen
                    var useCC = (ccwYL < cwYL) || (ccwYL === cwYL && ccwXL < cwXL)
                    var klNxL = useCC ? ccwXL : cwXL
                    var klNyL = useCC ? ccwYL : cwYL
                    var klFs  = Math.max(7, Math.round(2.5 * root.mmToPx * root.zoom))
                    var klLH  = klFs * 1.3
                    var klOff = klFs * 0.5 + 4
                    var klAX  = vx1 + klNxL * klOff
                    var klAY  = vy1 + klNyL * klOff
                    ctx.globalAlpha  = 1.0
                    ctx.textAlign    = klNxL >= 0 ? "left" : "right"
                    ctx.textBaseline = "bottom"
                    var klY = klAY
                    for (var kzI = klZeilen.length - 1; kzI >= 0; kzI--) {
                        ctx.font = (klZeilen[kzI].bold ? "bold " : "") + klFs + "px sans-serif"
                        ctx.fillStyle = (klZeilen[kzI].bold && !gewaehlt) ? klColor : (gewaehlt ? "#f0a030" : "#bb8800")
                        ctx.fillText(klZeilen[kzI].text, klAX, klY)
                        klY -= klLH
                    }
                }
            }
            ctx.restore()
        }

        function _renderPolygonlinie(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            var plPts = el.punkte || []
            if (plPts.length >= 2) {
                ctx.beginPath()
                ctx.moveTo(plPts[0].x * root.zoom + root.worldX, plPts[0].y * root.zoom + root.worldY)
                for (var plI = 1; plI < plPts.length; plI++)
                    ctx.lineTo(plPts[plI].x * root.zoom + root.worldX, plPts[plI].y * root.zoom + root.worldY)
                ctx.stroke()
            }
        }

        function _renderRechteck(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            var rr  = er * root.mmToPx * root.zoom
            // Eckenradius (roundRect) setzt positive Breite/Höhe voraus – anders als
            // fillRect/strokeRect, die mit negativer Breite/Höhe (Aufziehen in beliebiger
            // Richtung) bereits korrekt umgehen. Daher hier immer normalisieren, analog zu
            // _renderGeraetekasten/_renderStrukturkasten/_renderMakrokasten.
            var rrx = Math.min(vx1, vx2), rry = Math.min(vy1, vy2)
            var rrw = Math.abs(vx2 - vx1), rrh = Math.abs(vy2 - vy1)
            if (fu && !vorschau) {
                ctx.fillStyle = ff; ctx.globalAlpha = fo
                if (rr>0.5) { drawCanvas.roundRect(ctx,rrx,rry,rrw,rrh,rr); ctx.fill() }
                else          ctx.fillRect(rrx,rry,rrw,rrh)
                ctx.globalAlpha = op
            }
            ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
            if (rr>0.5) { drawCanvas.roundRect(ctx,rrx,rry,rrw,rrh,rr); ctx.stroke() }
            else          ctx.strokeRect(rrx,rry,rrw,rrh)
        }

        function _renderKreis(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            var dx=vx2-vx1, dy=vy2-vy1, r=Math.sqrt(dx*dx+dy*dy)
            if (r > 0.5) {
                ctx.beginPath(); ctx.arc(vx1,vy1,r,0,2*Math.PI)
                if (fu && !vorschau) {
                    ctx.fillStyle=ff; ctx.globalAlpha=fo; ctx.fill()
                    ctx.globalAlpha=op; ctx.beginPath(); ctx.arc(vx1,vy1,r,0,2*Math.PI)
                }
                ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
                ctx.stroke()
            }
        }

        function _renderText(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            var txtInhalt = el.textInhalt || ""
            if (txtInhalt !== "") {
                var txtLines  = txtInhalt.split("\n")
                var txtRot    = drawCanvas.normTextRot(el.rotation || 0)
                var txtBwPx   = Math.abs(vx2 - vx1)
                var txtBhPx   = Math.abs(vy2 - vy1)
                var txtAlign  = el.textAusrichtung || "links"
                var txtFsPx   // Schriftgröße in Pixel
                if (el.textEinpassen && txtBwPx > 4 && txtBhPx > 4) {
                    var longestChars = 1
                    for (var tli = 0; tli < txtLines.length; tli++)
                        if (txtLines[tli].length > longestChars) longestChars = txtLines[tli].length
                    txtFsPx = Math.min(txtBwPx / (longestChars * 0.62),
                                       txtBhPx / (txtLines.length * 1.3))
                } else {
                    txtFsPx = ((el.extraDaten && el.extraDaten.schriftgroesse) || 3.5) * root.mmToPx * root.zoom
                }
                var txtLineH = txtFsPx * 1.3
                var txtColor = gewaehlt ? "#f0a030"
                                       : (vorschau ? "#4a9eff88" : (el.strichFarbe || "#c0d8f0"))
                var ctxAlign = txtAlign === "mitte" ? "center"
                             : txtAlign === "rechts" ? "right" : "left"
                var tSelW  = txtRot !== 0 ? txtBhPx : txtBwPx
                var tSelH  = txtRot !== 0 ? txtBwPx : txtBhPx
                var tBxOff = txtAlign === "mitte"  ? -tSelW / 2
                           : txtAlign === "rechts" ? -tSelW : 0
                ctx.save()
                ctx.translate(vx1, vy1)
                if (txtRot !== 0) ctx.rotate(txtRot)
                ctx.globalAlpha = op
                // Hintergrund
                if (!gewaehlt && !vorschau && el.fuell) {
                    ctx.fillStyle   = el.fuellFarbe || "#000000"
                    ctx.globalAlpha = op * (el.fuellOpazitaet !== undefined ? el.fuellOpazitaet : 0.85)
                    ctx.fillRect(tBxOff, 0, tSelW, tSelH)
                    ctx.globalAlpha = op
                }
                // Rahmen
                var tRahmFarbe = el.extraDaten ? el.extraDaten.rahmFarbe : undefined
                if (!gewaehlt && !vorschau && tRahmFarbe) {
                    ctx.strokeStyle = tRahmFarbe; ctx.lineWidth = 1.5; ctx.setLineDash([])
                    ctx.strokeRect(tBxOff, 0, tSelW, tSelH)
                }
                ctx.font         = "bold " + txtFsPx + "px sans-serif"
                ctx.textBaseline = "top"
                ctx.textAlign    = ctxAlign
                ctx.fillStyle    = txtColor
                ctx.globalAlpha  = op
                if (!_skipText) {
                    for (var li2 = 0; li2 < txtLines.length; li2++)
                        ctx.fillText(txtLines[li2], 0, li2 * txtLineH)
                }
                // Selektion-Rahmen (im rotierten Koordinatensystem).
                // Bei –90° (senkrecht) sind Breite und Höhe im Bildschirmraum
                // getauscht; der Rahmen bleibt im lokalen (rotierten) Raum korrekt.
                if (gewaehlt) {
                    ctx.strokeStyle = "#f0a030"; ctx.lineWidth = 1
                    ctx.setLineDash([3, 3])
                    ctx.strokeRect(tBxOff - 2, -2, tSelW + 4, tSelH + 4)
                }
                ctx.restore()
            }
        }

        function _renderBild(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            var bUrl  = el.bildDaten || ""
            var bx    = Math.min(vx1, vx2), by = Math.min(vy1, vy2)
            var bw    = Math.abs(vx2 - vx1), bh = Math.abs(vy2 - vy1)
            var bcx   = bx + bw / 2,  bcy = by + bh / 2
            var bRot  = (el.rotation  || 0) * Math.PI / 180
            var bSx   = el.spiegelX ? -1 : 1
            var bSy   = el.spiegelY ? -1 : 1
            if (bUrl !== "" && bw > 1 && bh > 1) {
                ctx.save()
                ctx.globalAlpha = vorschau ? 0.55 : op
                ctx.translate(bcx, bcy)
                ctx.rotate(bRot)
                ctx.scale(bSx, bSy)
                if (drawCanvas.isImageLoaded(bUrl)) {
                    var aL = el.ausschnittLinks  || 0, aR = el.ausschnittRechts || 0
                    var aO = el.ausschnittOben   || 0, aU = el.ausschnittUnten  || 0
                    var cw = bw * (1 - aL - aR),      ch = bh * (1 - aO - aU)
                    if (cw > 0 && ch > 0) {
                        ctx.beginPath()
                        ctx.rect(-bw/2 + aL * bw, -bh/2 + aO * bh, cw, ch)
                        ctx.clip()
                        ctx.drawImage(bUrl, -bw/2, -bh/2, bw, bh)
                    }
                } else {
                    // Bild noch nicht geladen → Platzhalter zeichnen + laden anstoßen
                    drawCanvas.loadImage(bUrl)
                    ctx.globalAlpha = 0.4
                    ctx.strokeStyle = "#4a9eff"; ctx.lineWidth = 1
                    ctx.setLineDash([])
                    ctx.strokeRect(-bw/2, -bh/2, bw, bh)
                    ctx.beginPath()
                    ctx.moveTo(-bw/2, -bh/2); ctx.lineTo(bw/2,  bh/2)
                    ctx.moveTo( bw/2, -bh/2); ctx.lineTo(-bw/2, bh/2)
                    ctx.stroke()
                }
                ctx.restore()
            }
            // Auswahlrahmen immer ohne Rotation (am Bounding-Box)
            if (gewaehlt) {
                ctx.save()
                ctx.strokeStyle = "#f0a030"; ctx.lineWidth = 1.5; ctx.setLineDash([])
                ctx.strokeRect(bx - 1, by - 1, bw + 2, bh + 2)
                ctx.restore()
            }
        }

        function _renderNotiz(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            var nRx = Math.min(vx1, vx2), nRy = Math.min(vy1, vy2)
            var nRw = Math.abs(vx2 - vx1), nRh = Math.abs(vy2 - vy1)
            if (nRw > 2 && nRh > 2) {
                ctx.save()
                // Hintergrund
                var nFf  = el.fuellFarbe     || "#1a1a00"
                var nFo  = el.fuellOpazitaet !== undefined ? el.fuellOpazitaet : 0.9
                ctx.fillStyle   = nFf
                ctx.globalAlpha = op * nFo
                ctx.fillRect(nRx, nRy, nRw, nRh)
                ctx.globalAlpha = op
                // Rahmen
                var nRahmF = (el.extraDaten && el.extraDaten.rahmFarbe) ? el.extraDaten.rahmFarbe : (el.strichFarbe || "#cccc22")
                ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : nRahmF)
                ctx.lineWidth   = 1.5
                ctx.setLineDash([])
                ctx.strokeRect(nRx, nRy, nRw, nRh)
                // Text mit automatischem Zeilenumbruch
                var nText = el.textInhalt || ""
                if (nText !== "" && !_skipText) {
                    var nFsPx  = ((el.extraDaten && el.extraDaten.schriftgroesse) || 3.5) * root.mmToPx * root.zoom
                    var nLineH = nFsPx * 1.3
                    var nPad   = Math.max(4, nFsPx * 0.35)
                    var nMaxW  = nRw - 2 * nPad

                    ctx.save()
                    ctx.beginPath()
                    ctx.rect(nRx + 1, nRy + 1, nRw - 2, nRh - 2)
                    ctx.clip()

                    ctx.fillStyle    = el.strichFarbe || "#cccc22"
                    ctx.font         = nFsPx + "px sans-serif"
                    ctx.textBaseline = "top"
                    ctx.textAlign    = "left"

                    // Word-wrap: explizite \n beachten, lange Zeilen umbrechen
                    var wrappedLines = []
                    var paraLines = nText.split("\n")
                    for (var nPi = 0; nPi < paraLines.length; nPi++) {
                        var para = paraLines[nPi]
                        if (para === "") { wrappedLines.push(""); continue }
                        var words = para.split(" ")
                        var curLine = ""
                        for (var nWi = 0; nWi < words.length; nWi++) {
                            var testLine = curLine === "" ? words[nWi] : curLine + " " + words[nWi]
                            if (nMaxW > 0 && ctx.measureText(testLine).width > nMaxW && curLine !== "") {
                                wrappedLines.push(curLine)
                                curLine = words[nWi]
                            } else {
                                curLine = testLine
                            }
                        }
                        wrappedLines.push(curLine)
                    }

                    for (var nLi = 0; nLi < wrappedLines.length; nLi++) {
                        var nYPos = nRy + nPad + nLi * nLineH
                        if (nYPos + nLineH > nRy + nRh) break
                        ctx.fillText(wrappedLines[nLi], nRx + nPad, nYPos)
                    }
                    ctx.restore()
                }
            }
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
                               ? drawCanvas.querverweisPin(el)
                               : symbolDefinitionModel.pinsForSymbol(el.symbolId || "")
                    ctx.setLineDash([])
                    for (var pi = 0; pi < pins.length; pi++) {
                        var pp = drawCanvas.pinViewportPos(el, pins[pi].x, pins[pi].y)
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
                                var _pbPos = drawCanvas.pinViewportPos(el, _pbPin.x, _pbPin.y)
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
                        var qFs   = Math.max(7, Math.round(2.0 * root.mmToPx * root.zoom))
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

                        var gaFs   = Math.max(7, Math.round(2.0 * root.mmToPx * root.zoom))
                        var gaRot  = ((el.rotation || 0) % 360 + 360) % 360
                        var gaSenk = (gaRot === 90 || gaRot === 270)
                        var gaCx   = (vx1 + vx2) / 2
                        var gaCy   = (vy1 + vy2) / 2
                        var gaOx   = (gaed.bmkOffsetX !== undefined ? gaed.bmkOffsetX : 0) * root.zoom
                        var gaOy   = (gaed.bmkOffsetY !== undefined ? gaed.bmkOffsetY : 0) * root.zoom
                        ctx.save()
                        ctx.globalAlpha = 1.0
                        ctx.font = "bold " + gaFs + "px sans-serif"
                        ctx.strokeStyle = "#000000"; ctx.lineWidth = 3; ctx.lineJoin = "round"
                        ctx.fillStyle = gewaehlt ? "#f0a030" : "#c0d8f0"
                        if (gaSenk) {
                            // 90°: pin unten → Text oben  |  270°: pin oben → Text unten
                            var gaPinUnten = (gaRot === 90)
                            var gaY = gaPinUnten
                                      ? Math.min(vy1, vy2) - 3 * root.zoom + gaOy
                                      : Math.max(vy1, vy2) + 3 * root.zoom + gaOy
                            ctx.textAlign = "center"
                            ctx.textBaseline = gaPinUnten ? "bottom" : "top"
                            ctx.strokeText(gaLabel, gaCx + gaOx, gaY)
                            ctx.fillText(gaLabel, gaCx + gaOx, gaY)
                        } else {
                            // 0°: pin rechts → Text links  |  180°: pin links → Text rechts
                            var gaPinRechts = (gaRot === 0)
                            var gaX = gaPinRechts
                                      ? Math.min(vx1, vx2) - 4 * root.zoom + gaOx
                                      : Math.max(vx1, vx2) + 4 * root.zoom + gaOx
                            ctx.textAlign = gaPinRechts ? "right" : "left"
                            ctx.textBaseline = "middle"
                            ctx.strokeText(gaLabel, gaX, gaCy + gaOy)
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
                        ctx.strokeStyle = "#000000"; ctx.lineWidth = 3; ctx.lineJoin = "round"
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
                                ctx.strokeText(paBmk, paCxO, paY)
                                ctx.fillStyle = paBmkClr; ctx.fillText(paBmk, paCxO, paY)
                            }
                            if (paFt.length > 0) {
                                ctx.font = paFtFs + "px sans-serif"
                                ctx.fillStyle = paFtClr
                                var paFtY = paY + paDir * (paBmk !== "" ? paFs + 2 : 0)
                                for (var pfi2 = 0; pfi2 < paFt.length; pfi2++) {
                                    ctx.textBaseline = paBl
                                    ctx.strokeText(paFt[pfi2], paCxO, paFtY)
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
                                ctx.strokeText(paBmk, paX, paCurY)
                                ctx.fillStyle = paBmkClr; ctx.fillText(paBmk, paX, paCurY)
                                paCurY += paFs * 1.1
                            }
                            if (paFt.length > 0) {
                                ctx.font = paFtFs + "px sans-serif"
                                ctx.textAlign = paAl; ctx.fillStyle = paFtClr
                                for (var pfi3 = 0; pfi3 < paFt.length; pfi3++) {
                                    ctx.strokeText(paFt[pfi3], paX, paCurY)
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
                    // "BMK anzeigen" blendet nur das Leisten-Präfix (z.B. "-X1:") aus;
                    // die Klemmen-Nummer (z.B. "2") bleibt immer sichtbar
                    var kaBmkColon = kaBmkBase.lastIndexOf(":")
                    var kaBmk, kaBmkVis
                    if (kaBmkColon >= 0) {
                        var kaBmkStrip = kaBmkBase.slice(0, kaBmkColon + 1)
                        var kaBmkNr    = kaBmkBase.slice(kaBmkColon + 1)
                        kaBmk    = (kaed.bmkSichtbar !== false ? kaBmkStrip : "") + kaBmkNr
                        kaBmkVis = kaBmk !== ""
                    } else {
                        kaBmk    = kaBmkBase
                        kaBmkVis = kaBmkBase !== "" && kaed.bmkSichtbar !== false
                    }
                    var kaFs    = Math.max(6, Math.round(1.5 * root.mmToPx * root.zoom))
                    var kaBmkFs = Math.max(7, Math.round(2.2 * root.mmToPx * root.zoom))
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
                if (!vorschau && !_skipText && el.symbolId === "aderdefinition") {
                    var aed = el.extraDaten || {}
                    var adpZeilen = []
                    if (aed.bezeichnung) adpZeilen.push({ text: aed.bezeichnung, bold: true })
                    var adpFarb = aed.aderfarbe || "", adpQuer = aed.querschnitt_mm2
                    if (adpFarb !== "" || (adpQuer !== undefined && adpQuer > 0))
                        adpZeilen.push({ text: (adpFarb || "–") + (adpQuer > 0 ? "  " + (adpQuer + "").replace('.', ',') + " mm²" : ""), bold: false })
                    if (aed.laenge_m && aed.laenge_m > 0)
                        adpZeilen.push({ text: qsTr("\u2192 ") + (aed.laenge_m + "").replace('.', ',') + " m", bold: false })
                    if (adpZeilen.length > 0) {
                        var adpFs    = Math.max(7, Math.round(2.0 * root.mmToPx * root.zoom))
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

        function _renderGeraetekasten(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            // Gerätekasten: abgerundetes Rechteck mit leichter Füllung und Label oben links
            ctx.lineCap = "butt"
            var gkRx = Math.min(vx1, vx2), gkRy = Math.min(vy1, vy2)
            var gkRw = Math.abs(vx2 - vx1), gkRh = Math.abs(vy2 - vy1)
            var gkR  = er > 0 ? er * root.mmToPx * root.zoom : 4 * root.zoom
            // GK-1: eigene Standardfarbe Teal statt generischem Blau, unterscheidet sich
            // von Strukturkasten (Grau) und Makrokasten (Violett)
            var gkFarbe = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : (el.strichFarbe || "#0088aa"))
            if (fu && !vorschau) {
                ctx.fillStyle  = ff
                ctx.globalAlpha = op * fo
                drawCanvas.roundRect(ctx, gkRx, gkRy, gkRw, gkRh, gkR)
                ctx.fill()
                ctx.globalAlpha = op
            }
            ctx.strokeStyle = gkFarbe
            drawCanvas.roundRect(ctx, gkRx, gkRy, gkRw, gkRh, gkR)
            ctx.stroke()
            if (!vorschau && !_skipText && gkRw > 20 && gkRh > 12) {
                var gkEd  = el.extraDaten || {}
                var gkBmk = gkEd.bmk        || ""
                var gkBez = gkEd.bezeichnung || ""
                if (gkBmk !== "" || gkBez !== "") {
                    ctx.save()
                    ctx.setLineDash([])
                    var gkSch = (gkEd.schriftgroesse !== undefined ? gkEd.schriftgroesse : 2.5)
                    var gkFs  = Math.max(5, Math.round(gkSch * root.mmToPx * root.zoom))
                    var gkFsB = Math.max(4, Math.round(gkSch * 0.85 * root.mmToPx * root.zoom))
                    var gkPad = Math.round(5 * root.zoom)
                    var gkOx  = (gkEd.bmkOffsetX !== undefined ? gkEd.bmkOffsetX : 0) * root.zoom
                    var gkOy  = (gkEd.bmkOffsetY !== undefined ? gkEd.bmkOffsetY : 0) * root.zoom
                    ctx.textAlign    = "left"
                    ctx.textBaseline = "top"
                    ctx.fillStyle    = gkFarbe
                    ctx.globalAlpha  = op
                    var gkTx = gkRx + gkPad + gkOx
                    var gkTy = gkRy + gkPad + gkOy
                    if (gkBmk !== "") {
                        ctx.font = "bold " + gkFs + "px sans-serif"
                        var gkBmkZ = gkBmk.split("\n")
                        for (var gki = 0; gki < gkBmkZ.length; gki++) {
                            ctx.fillText(gkBmkZ[gki], gkTx, gkTy)
                            gkTy += gkFs * 1.3
                        }
                    }
                    if (gkBez !== "") {
                        ctx.font = gkFsB + "px sans-serif"
                        var gkBezZ = gkBez.split("\n")
                        for (var gkj = 0; gkj < gkBezZ.length; gkj++) {
                            ctx.fillText(gkBezZ[gkj], gkTx, gkTy)
                            gkTy += gkFsB * 1.3
                        }
                    }
                    ctx.restore()
                }
            }
        }

        function _renderStrukturkasten(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            // Strukturkasten: Rechteck mit Anlage/Ort-Label oben rechts
            var skRx = Math.min(vx1, vx2), skRy = Math.min(vy1, vy2)
            var skRw = Math.abs(vx2 - vx1), skRh = Math.abs(vy2 - vy1)
            ctx.lineCap = "butt"
            var skR = er > 0 ? er * root.mmToPx * root.zoom : 0
            if (fu && !vorschau) {
                ctx.fillStyle   = ff; ctx.globalAlpha = op * fo
                if (skR > 0) { drawCanvas.roundRect(ctx, skRx, skRy, skRw, skRh, skR); ctx.fill() }
                else ctx.fillRect(skRx, skRy, skRw, skRh)
                ctx.globalAlpha = op
            }
            ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
            if (skR > 0) { drawCanvas.roundRect(ctx, skRx, skRy, skRw, skRh, skR); ctx.stroke() }
            else ctx.strokeRect(skRx, skRy, skRw, skRh)
            if (!vorschau && !_skipText && skRw > 20) {
                var skEd  = el.extraDaten || {}
                var skAnl = skEd.skAnlage   || ""
                var skOrt = skEd.skOrt      || ""
                var skAUO = skEd.skAnlageUO || ""
                var skOUO = skEd.skOrtUO    || ""
                var skBez = skEd.bezeichnung || ""
                ctx.save()
                ctx.setLineDash([])
                var skSch = (skEd.schriftgroesse !== undefined ? skEd.schriftgroesse : 2.5)
                var skFs  = Math.max(5, Math.round(skSch * root.mmToPx * root.zoom))
                ctx.font        = "bold " + skFs + "px sans-serif"
                ctx.textBaseline = "top"
                ctx.fillStyle   = gewaehlt ? "#f0a030" : sf
                ctx.globalAlpha = op
                var skOx  = (skEd.bmkOffsetX !== undefined ? skEd.bmkOffsetX : 0) * root.zoom
                var skOy  = (skEd.bmkOffsetY !== undefined ? skEd.bmkOffsetY : 0) * root.zoom
                var skFsB = Math.max(4, Math.round(skSch * 0.85 * root.mmToPx * root.zoom))
                var skPad = Math.round(5 * root.zoom)
                var skTx  = skRx + skPad + skOx
                var skTy  = skRy + skPad + skOy
                // Anlage/Ort-Label oben links (bold) – wie Gerätekasten
                var skLbl = ""
                if (skAUO) skLbl += "==" + skAUO + " "
                if (skOUO) skLbl += "++" + skOUO + " "
                if (skAnl) skLbl += "="  + skAnl + " "
                if (skOrt) skLbl += "+"  + skOrt
                ctx.textAlign = "left"
                if (skLbl !== "") {
                    ctx.font = "bold " + skFs + "px sans-serif"
                    var skLblZ = skLbl.trim().split("\n")
                    for (var skli = 0; skli < skLblZ.length; skli++) {
                        ctx.fillText(skLblZ[skli], skTx, skTy)
                        skTy += skFs * 1.3
                    }
                }
                // Bezeichnung darunter (kleiner) – wie Gerätekasten
                if (skBez !== "") {
                    ctx.font = skFsB + "px sans-serif"
                    var skBezZ = skBez.split("\n")
                    for (var ski = 0; ski < skBezZ.length; ski++) {
                        ctx.fillText(skBezZ[ski], skTx, skTy)
                        skTy += skFsB * 1.3
                    }
                }
                ctx.restore()
            }
        }

        function _renderMakrokasten(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
            // Makrokasten: gestrichelt, Standard-Farbe violett (überschreibbar via Stil)
            var mkRx = Math.min(vx1, vx2), mkRy = Math.min(vy1, vy2)
            var mkRw = Math.abs(vx2 - vx1), mkRh = Math.abs(vy2 - vy1)
            var mkEd    = el.extraDaten || {}
            var mkSaved = mkEd.makroId > 0
            var mkFarbe = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff"
                          : (el.strichFarbe || "#aa44cc"))
            ctx.lineCap = "butt"
            var mkR = er > 0 ? er * root.mmToPx * root.zoom : 0
            if (fu && !vorschau) {
                ctx.fillStyle   = ff; ctx.globalAlpha = op * fo
                if (mkR > 0) { drawCanvas.roundRect(ctx, mkRx, mkRy, mkRw, mkRh, mkR); ctx.fill() }
                else ctx.fillRect(mkRx, mkRy, mkRw, mkRh)
                ctx.globalAlpha = op
            }
            ctx.strokeStyle = mkFarbe
            if (mkR > 0) { drawCanvas.roundRect(ctx, mkRx, mkRy, mkRw, mkRh, mkR); ctx.stroke() }
            else ctx.strokeRect(mkRx, mkRy, mkRw, mkRh)
            if (!vorschau && !_skipText && mkRw > 20) {
                ctx.save()
                ctx.setLineDash([])
                var mkFs = Math.max(5, Math.round(2.2 * root.mmToPx * root.zoom))
                ctx.font        = mkFs + "px sans-serif"
                ctx.textBaseline = "top"
                ctx.textAlign    = "center"
                ctx.fillStyle   = mkFarbe
                ctx.globalAlpha = op
                var mkOx   = (mkEd.bmkOffsetX !== undefined ? mkEd.bmkOffsetX : 0) * root.zoom
                var mkOy   = (mkEd.bmkOffsetY !== undefined ? mkEd.bmkOffsetY : 0) * root.zoom
                var mkPfx  = mkSaved ? "✓ " : "⬜ "
                var mkName = mkEd.name || qsTr("Makro")
                var mkNameZ = mkName.split("\n")
                var mkTy = mkRy + Math.round(4 * root.zoom) + mkOy
                for (var mki = 0; mki < mkNameZ.length; mki++) {
                    ctx.fillText((mki === 0 ? mkPfx : "  ") + mkNameZ[mki], mkRx + mkRw / 2 + mkOx, mkTy)
                    mkTy += mkFs * 1.3
                }
                ctx.restore()
            }
        }

        function _renderSchirm(ctx, el, rc) {
            var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
            var sf = rc.sf, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op
            var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2
            // Schirm-Symbol: Kapsel-/Stadium-Form (kein echtes Oval) — zwei echte
            // Halbkreise links/rechts (Radius = halbe Höhe), verbunden durch zwei
            // parallele Geraden. Strichart (gestrichelt) kommt aus dem gemeinsamen
            // Dash-Setup in maleElement. Pin sitzt am gewählten Rand (anschlussSeite).
            ctx.lineCap = "butt"
            var shCx = (vx1 + vx2) / 2, shCy = (vy1 + vy2) / 2
            var shRx = Math.abs(vx2 - vx1) / 2, shRy = Math.abs(vy2 - vy1) / 2
            var shX  = Math.min(vx1, vx2), shY = Math.min(vy1, vy2)
            var shW  = shRx * 2, shH = shRy * 2
            var shFarbe = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
            if (fu && !vorschau) {
                ctx.fillStyle  = ff
                ctx.globalAlpha = op * fo
                drawCanvas.stadiumPfad(ctx, shX, shY, shW, shH); ctx.fill()
                ctx.globalAlpha = op
            }
            ctx.strokeStyle = shFarbe
            drawCanvas.stadiumPfad(ctx, shX, shY, shW, shH); ctx.stroke()

            var shEd    = el.extraDaten || {}
            var shSeite = shEd.anschlussSeite || "links"
            var shPx = shCx, shPy = shCy
            if      (shSeite === "links")  shPx = Math.min(vx1, vx2)
            else if (shSeite === "rechts") shPx = Math.max(vx1, vx2)
            else if (shSeite === "oben")   shPy = Math.min(vy1, vy2)
            else if (shSeite === "unten")  shPy = Math.max(vy1, vy2)

            if (!vorschau && !_skipText) {
                ctx.save(); ctx.setLineDash([])
                ctx.fillStyle = shFarbe; ctx.globalAlpha = op
                ctx.beginPath(); ctx.arc(shPx, shPy, 2.5, 0, 2 * Math.PI); ctx.fill()
                ctx.restore()
            }

            if (!vorschau && !_skipText && shRx > 10 && shRy > 6) {
                var shBez = shEd.bezeichnung || ""
                if (shBez !== "") {
                    ctx.save(); ctx.setLineDash([])
                    ctx.textAlign = "center"; ctx.textBaseline = "middle"
                    ctx.font = Math.max(8, Math.round(2.5 * root.mmToPx * root.zoom)) + "px sans-serif"
                    ctx.fillStyle  = shFarbe
                    ctx.globalAlpha = op
                    ctx.fillText(shBez, shCx, shCy)
                    ctx.restore()
                }
            }
        }


        // Gibt den korrekten Pin für ein Querverweis-Element zurück.
        // Ausgang: Pin am Schwanz (x=0), Eingang: Pin an der Spitze (x=1).
        function querverweisPin(el) {
            var richtung = (el.extraDaten && el.extraDaten.richtung) || "ausgang"
            var eingang  = (richtung === "eingang")
            return [{ name: "1", x: eingang ? 1.0 : 0.0, y: 0.5,
                      offen: { x: eingang ? 1 : -1, y: 0 }, signaltyp: "neutral" }]
        }

        // Berechnet die Viewport-Position eines Pins auf einem Symbol-Element.
        // pinX/pinY sind normalisierte Koordinaten (0..1) aus dem Pinkatalog.
        function pinViewportPos(el, pinX, pinY) {
            var vx1 = el.x1 * root.zoom + root.worldX
            var vy1 = el.y1 * root.zoom + root.worldY
            var vx2 = el.x2 * root.zoom + root.worldX
            var vy2 = el.y2 * root.zoom + root.worldY
            var sw = vx2 - vx1, sh = vy2 - vy1
            var absSw = Math.abs(sw), absSh = Math.abs(sh)
            var scx = vx1 + sw / 2, scy = vy1 + sh / 2

            // Lokale Koordinaten relativ zum Mittelpunkt
            var cx = (pinX - 0.5) * absSw
            var cy = (pinY - 0.5) * absSh

            // Spiegelung (entspricht dem ctx.scale im Zeichenpfad)
            if (el.spiegelX) cx = -cx
            if (el.spiegelY) cy = -cy

            // Rotation
            var rot = (el.rotation || 0) * Math.PI / 180
            var rx = cx * Math.cos(rot) - cy * Math.sin(rot)
            var ry = cx * Math.sin(rot) + cy * Math.cos(rot)

            return Qt.point(scx + rx, scy + ry)
        }

        function griffPunkte(el) {
            if (el.typ==="linie" || el.typ==="kabellinie")
                                          return [Qt.point(el.x1,el.y1), Qt.point(el.x2,el.y2)]
            if (el.typ==="polygonlinie") {
                var plGriffe = el.punkte || []
                return plGriffe.map(function(p) { return Qt.point(p.x, p.y) })
            }
            if (el.typ==="rechteck" || el.typ==="geraetekasten" || el.typ==="strukturkasten"
                    || el.typ==="makrokasten" || el.typ==="schirm" || el.typ==="bild" || el.typ==="notiz")
                return [Qt.point(el.x1,el.y1), Qt.point(el.x2,el.y1),
                        Qt.point(el.x2,el.y2), Qt.point(el.x1,el.y2)]
            if (el.typ==="kreis")    return [Qt.point(el.x1,el.y1), Qt.point(el.x2,el.y2)]
            if (el.typ==="symbol") return []  // Größe ist DB-definiert, kein Resize
            return []
        }


        // Gibt Farbe für einen Signaltyp zurück
        function signaltypFarbe(sig) {
            if (sig === "power")           return "#cc3300"   // L (AC-Phase)
            if (sig === "pe")              return "#88cc00"
            if (sig === "n")               return "#4488ff"
            if (sig === "dc_plus")         return "#dd5500"
            if (sig === "dc_minus")        return "#334488"
            if (sig === "input_digital")   return "#44aaff"
            if (sig === "output_digital")  return "#44cc66"
            if (sig === "input_analog")    return "#88bbff"
            if (sig === "output_analog")   return "#66ddaa"
            if (sig === "kommunikation")   return "#aa44cc"
            if (sig === "temp")            return "#e07030"
            if (sig === "stepper")         return "#20a890"
            if (sig === "konflikt")        return "#ff2200"
            if (sig === "unversorgt")      return "#ffaa00"
            return "#4a9eff"   // neutral
        }

        // ── Auto-Verbindungen ─────────────────────────────────
        // Delegiert an SymbolDefinitionModel::autoVerbindungenBerechnen() (C++).
        function autoVerbindungenBerechnen() {
            return symbolDefinitionModel.autoVerbindungenBerechnen(
                elementeModel.snapshot(),
                root.gridPx,
                root.normblattDaten || {}
            )
        }


        // Liefert einen stabilen, positionsunabhängigen Bezeichner für einen
        // Netzpunkt (Endpunkt-Element + Pin) — oder "" wenn keiner verfügbar
        // ist (unbeschriftetes Bauteil, reines Routing-Element). Grundlage
        // für netKey (NETZ-01): BMK/Anschlusskennzeichnung ändern sich beim
        // Verschieben nicht, Koordinaten schon.
        function _stabilerPunktSchluessel(el, pinName, elemente) {
            if (!el || el.typ !== "symbol") return ""
            var sid = el.symbolId || ""
            var ed  = el.extraDaten || {}

            if (sid === "geraeteanschluss") {
                var ank = ed.anschlusskennzeichnung || ""
                if (!ank) return ""
                var cx = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
                var bestGk = null, bestGkA = Infinity
                for (var gi = 0; gi < elemente.length; gi++) {
                    var gke = elemente[gi]
                    if (gke.typ !== "geraetekasten") continue
                    var gkx1 = Math.min(gke.x1, gke.x2), gkx2 = Math.max(gke.x1, gke.x2)
                    var gky1 = Math.min(gke.y1, gke.y2), gky2 = Math.max(gke.y1, gke.y2)
                    if (cx >= gkx1 && cx <= gkx2 && cy >= gky1 && cy <= gky2) {
                        var gkA = (gkx2 - gkx1) * (gky2 - gky1)
                        if (gkA < bestGkA) { bestGkA = gkA; bestGk = gke }
                    }
                }
                var bmk = bestGk ? ((bestGk.extraDaten || {}).bmk || "") : ""
                if (!bmk) return ""
                return "GA:" + bmk + ":" + ank
            }

            if (sid === "klemme_anschluss") {
                var kaBmk = ed.bmk || "", kaAnz = ed.anschlussBezeichnung || ""
                if (!kaBmk || !kaAnz) return ""
                return "KA:" + kaBmk + ":" + kaAnz
            }

            if (sid === "potenzial") {
                var sig = ed.signalname || ""
                if (!sig) return ""
                return "POT:" + sig
            }

            // Gewöhnliches Symbol mit eigener BMK (Relais, Klemme, Sensor, ...)
            var bmk2 = ed.bmk || ""
            if (!bmk2 || !pinName) return ""
            return "SYM:" + bmk2 + ":" + pinName
        }

        // Reine Routing-Elemente ohne eigene Identität (NETZ-02): dürfen bei
        // der lokalen Ader-Suche transparent übersprungen werden. Gewöhnliche
        // (auch unbeschriftete) Bauteile gehören NICHT dazu.
        property var _routingSymbolTypen: ({
            "winkel": true, "treffpunkt": true, "treffpunkt_l": true,
            "aderdefinition": true
        })

        // Läuft von elIdx aus (kommend von vonIdx) durch reine Routing-
        // Elemente, bis ein Element mit eigenem stabilen Punkt-Schlüssel
        // gefunden wird, oder gibt "" zurück (kein stabiler Punkt in
        // erreichbarer Nähe / echtes, aber unbeschriftetes Bauteil).
        function _naechsterStabilerPunkt(elIdx, vonIdx, pinName, adj, elemente, tiefe) {
            if (tiefe <= 0) return ""
            var el = elemente[elIdx]
            if (!el) return ""
            var stabil = _stabilerPunktSchluessel(el, pinName, elemente)
            if (stabil) return stabil
            if (!_routingSymbolTypen[el.symbolId || ""]) return ""
            var nbList = adj[elIdx] || []
            for (var i = 0; i < nbList.length; i++) {
                if (nbList[i].nb !== vonIdx)
                    return _naechsterStabilerPunkt(nbList[i].nb, elIdx, nbList[i].pinSelf, adj, elemente, tiefe - 1)
            }
            return ""
        }

        // NETZ-02: lokaler, positionsunabhängiger Schlüssel für EINEN
        // Kreuzungspunkt einer Kabellinie mit einem Netz — anders als
        // net.netKey beschreibt er nur die zwei nächsten "echten" Anschlüsse
        // links/rechts der Kreuzung, nicht das ganze (ggf. über mehrere
        // Bauteile transitiv verschmolzene) Potenzial-Netz. Dadurch bleibt
        // die Kabel-Aderzuordnung stabil, auch wenn sich an einer anderen
        // Stelle desselben Potenzial-Netzes die Topologie ändert.
        function _lokalerAderSchluessel(seg, net, elemente) {
            var adj = {}
            for (var si = 0; si < net.segmente.length; si++) {
                var s = net.segmente[si]
                if (s.logisch) continue
                if (!adj[s.elIdxA]) adj[s.elIdxA] = []
                if (!adj[s.elIdxB]) adj[s.elIdxB] = []
                adj[s.elIdxA].push({ nb: s.elIdxB, pinSelf: s.pinNameB })
                adj[s.elIdxB].push({ nb: s.elIdxA, pinSelf: s.pinNameA })
            }
            var seiteA = _naechsterStabilerPunkt(seg.elIdxA, seg.elIdxB, seg.pinNameA, adj, elemente, 20)
            var seiteB = _naechsterStabilerPunkt(seg.elIdxB, seg.elIdxA, seg.pinNameB, adj, elemente, 20)
            var teile = []
            if (seiteA) teile.push(seiteA)
            if (seiteB) teile.push(seiteB)
            if (teile.length === 0) return ""
            teile.sort()
            return teile.join("|")
        }

        // Schlägt einen Wert nacheinander unter mehreren Keys nach (erster
        // Treffer gewinnt). Für Übergangs-Fallbacks: NETZ-01 (legacyNetKey,
        // positionsbasiert) und NETZ-02 (aderKey vor netKey, lokal statt
        // ganzes Potenzial-Netz) — persistierte Daten können noch unter
        // einem älteren Key-Format liegen, bis sie einmal neu gespeichert wurden.
        function _netLookup(map, keys) {
            if (!map) return undefined
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] && map[keys[i]] !== undefined) return map[keys[i]]
            }
            return undefined
        }

        // Gruppiert Auto-Verbindungssegmente zu elektrischen Netzen.
        // Gibt [{netKey, legacyNetKey, bezeichnung, signaltyp, farbe,
        //        querschnitt, verbindungId, segmente:[{x1,y1,x2,y2}],
        //        querverweise:[...]}] zurück.
        function autoNetzeBerechnen() {
            var vbs      = autoVerbindungenBerechnen()
            var elemente = elementeModel.snapshot()

            // ── KLEMME-NET-01: Klemmen-Durchleitung + Stegbrücken ────────────────
            // Schritt 1: klemme_anschluss-Elemente indizieren
            var _kGruppen = {}   // "klemmeId:ebene" → [elIdx, ...]  (für A↔B-Hop)
            var _kElMap   = {}   // klemmeId → [{elIdx, ebene}]      (für Stegbrücken)
            for (var _ki = 0; _ki < elemente.length; _ki++) {
                var _kel = elemente[_ki]
                if (!_kel || _kel.typ !== "symbol" || _kel.symbolId !== "klemme_anschluss") continue
                var _ked   = _kel.extraDaten || {}
                var _kId   = _ked.klemmeId || 0
                if (_kId <= 0) continue
                var _bez   = _ked.anschlussBezeichnung || ""
                var _ebene = (_bez === "PE" || _bez === "") ? _bez : _bez.split(".")[0]
                if (!_ebene) continue
                if (!_kElMap[_kId])    _kElMap[_kId] = []
                _kElMap[_kId].push({ elIdx: _ki, ebene: _ebene })
                var _gKey = _kId + ":" + _ebene
                if (!_kGruppen[_gKey]) _kGruppen[_gKey] = []
                _kGruppen[_gKey].push(_ki)
            }
            var _addLog = function(idxA, idxB) {
                var _eA = elemente[idxA], _eB = elemente[idxB]
                vbs.push({
                    x1: (_eA.x1+_eA.x2)/2, y1: (_eA.y1+_eA.y2)/2,
                    x2: (_eB.x1+_eB.x2)/2, y2: (_eB.y1+_eB.y2)/2,
                    elIdxA: idxA, rolleA: "durchleiter", quellSigA: "neutral",
                    elIdxB: idxB, rolleB: "durchleiter", quellSigB: "neutral",
                    signaltyp: "neutral", logisch: true
                })
            }
            // Schritt 2: A↔B-Hop – gleiche klemmeId + gleiche Ebene
            for (var _gk in _kGruppen) {
                var _grp = _kGruppen[_gk]
                for (var _gi = 1; _gi < _grp.length; _gi++) _addLog(_grp[0], _grp[_gi])
            }
            // Schritt 3: Stegbrücken – verbindet mehrere klemmeIds gleicher Ebene
            if (root.projektId >= 0) {
                var _stege = db.klemmenStegbrueckenGruppen(root.projektId)
                for (var _si = 0; _si < _stege.length; _si++) {
                    var _steg    = _stege[_si]
                    var _sEbene  = String(_steg.ebene)
                    var _sIds    = _steg.klemmeIds
                    var _sIdxs   = []
                    for (var _ski = 0; _ski < _sIds.length; _ski++) {
                        var _entries = _kElMap[_sIds[_ski]] || []
                        for (var _ei = 0; _ei < _entries.length; _ei++) {
                            if (String(_entries[_ei].ebene) === _sEbene)
                                _sIdxs.push(_entries[_ei].elIdx)
                        }
                    }
                    for (var _sii = 1; _sii < _sIdxs.length; _sii++) _addLog(_sIdxs[0], _sIdxs[_sii])
                }
            }
            // Schritt 4: Interne Ebenen-Brücken – verbindet verschiedene Ebenen derselben klemmeId
            if (root.projektId >= 0) {
                var _iBruecken = db.klemmenInterneBruecken(root.projektId)
                for (var _ibi = 0; _ibi < _iBruecken.length; _ibi++) {
                    var _ib      = _iBruecken[_ibi]
                    var _ibKId   = _ib.klemmeId
                    var _ibVon   = String(_ib.vonEbene)
                    var _ibNach  = String(_ib.nachEbene)
                    var _ibEls   = _kElMap[_ibKId] || []
                    var _vonIdxs = [], _nachIdxs = []
                    for (var _ibEi = 0; _ibEi < _ibEls.length; _ibEi++) {
                        var _ibE = String(_ibEls[_ibEi].ebene)
                        if (_ibE === _ibVon)  _vonIdxs.push(_ibEls[_ibEi].elIdx)
                        if (_ibE === _ibNach) _nachIdxs.push(_ibEls[_ibEi].elIdx)
                    }
                    for (var _ibVi = 0; _ibVi < _vonIdxs.length; _ibVi++)
                        for (var _ibNi = 0; _ibNi < _nachIdxs.length; _ibNi++)
                            _addLog(_vonIdxs[_ibVi], _nachIdxs[_ibNi])
                }
            }
            // ─────────────────────────────────────────────────────────────────────

            if (vbs.length === 0) return []

            // Union-Find auf Elementindizes
            var parent = {}
            function find(x) {
                if (parent[x] === undefined) parent[x] = x
                while (parent[x] !== x) { parent[x] = parent[parent[x]]; x = parent[x] }
                return x
            }
            function union(a, b) { var ra = find(a), rb = find(b); if (ra !== rb) parent[ra] = rb }

            for (var i = 0; i < vbs.length; i++) union(vbs[i].elIdxA, vbs[i].elIdxB)

            // Segmente nach Netz gruppieren
            var netMap = {}
            for (var i = 0; i < vbs.length; i++) {
                var v = vbs[i]
                var rid = "" + find(v.elIdxA)
                if (!netMap[rid]) netMap[rid] = { signaltyp: "neutral", bezeichnung: "", segmente: [], pinSet: {} }
                var net = netMap[rid]
                net.segmente.push({ x1: v.x1, y1: v.y1, x2: v.x2, y2: v.y2,
                                    elIdxA: v.elIdxA, elIdxB: v.elIdxB,
                                    pinNameA: v.pinNameA || "", pinNameB: v.pinNameB || "",
                                    logisch: v.logisch || false })
                if (!v.logisch) {
                    var g = root.gridPx > 0 ? root.gridPx : 1
                    var k1 = Math.round(v.x1/g) + "," + Math.round(v.y1/g)
                    var k2 = Math.round(v.x2/g) + "," + Math.round(v.y2/g)
                    net.pinSet[k1] = true; net.pinSet[k2] = true
                }
                if (v.signaltyp === "konflikt")   net.signaltyp = "konflikt"
                else if (v.signaltyp === "unversorgt" && net.signaltyp !== "konflikt") net.signaltyp = "unversorgt"
                else if (v.signaltyp !== "neutral" && net.signaltyp === "neutral") net.signaltyp = v.signaltyp
            }

            // Querverweis-Symbole: Bezeichnung + Querverweise
            var result = []
            for (var ei = 0; ei < elemente.length; ei++) {
                var el = elemente[ei]
                if (el.typ !== "symbol" || el.symbolId !== "querverweis") continue
                if (parent[ei] === undefined) continue
                var rid2 = "" + find(ei)
                if (!netMap[rid2]) continue
                var ed = el.extraDaten || {}
                if (ed.signalname) netMap[rid2].bezeichnung = ed.signalname
            }

            // NetKey berechnen + Cache-Annotation einlesen
            for (var rid in netMap) {
                var net = netMap[rid]
                var pins = Object.keys(net.pinSet).sort()
                net.legacyNetKey = pins.join("|")
                delete net.pinSet

                // Stabiler Key (NETZ-01): aus BMK/Anschlusskennzeichnung der
                // "echten" Endpunkte statt aus Koordinaten. Fällt auf
                // legacyNetKey zurück, wenn kein Endpunkt im Netz einen
                // stabilen Bezeichner hat (z.B. unbeschriftete Bauteile).
                var stabilSet = {}
                for (var spi = 0; spi < net.segmente.length; spi++) {
                    var seg = net.segmente[spi]
                    var sa = _stabilerPunktSchluessel(elemente[seg.elIdxA], seg.pinNameA, elemente)
                    if (sa) stabilSet[sa] = true
                    var sb = _stabilerPunktSchluessel(elemente[seg.elIdxB], seg.pinNameB, elemente)
                    if (sb) stabilSet[sb] = true
                }
                var stabilKeys = Object.keys(stabilSet).sort()
                net.netKey = stabilKeys.length > 0 ? stabilKeys.join("|") : net.legacyNetKey

                var ann = _netLookup(root.verbindungAnnotationenCache, [net.netKey, net.legacyNetKey]) || {}
                if (ann.bezeichnung && !net.bezeichnung) net.bezeichnung = ann.bezeichnung
                net.verbindungId  = ann.verbindungId  || 0
                net.farbe         = ann.farbe         || ""
                net.querschnitt   = ann.querschnitt_mm2 || 0

                // Querverweise aus Querverweis-Symbolen
                net.querverweise = []
                for (var ei2 = 0; ei2 < elemente.length; ei2++) {
                    var eel = elemente[ei2]
                    if (eel.typ !== "symbol" || eel.symbolId !== "querverweis") continue
                    if (parent[ei2] === undefined || ("" + find(ei2)) !== rid) continue
                    var eed = eel.extraDaten || {}
                    if (eed.zielSeiteId && eed.signalname) {
                        var richtung = eed.richtung || "ausgang"
                        net.querverweise.push({
                            vonSeiteId:      richtung === "ausgang" ? root.seiteId : eed.zielSeiteId,
                            nachSeiteId:     richtung === "ausgang" ? eed.zielSeiteId : root.seiteId,
                            vonBezeichnung:  eed.signalname,
                            nachBezeichnung: eed.signalname
                        })
                    }
                }
                result.push(net)
            }

            // ── Cross-page klemmen signaltyp import (KLEMME-NET-01) ──────────────
            // Für Netze auf dieser Seite die noch kein Potenzial haben:
            // Partner-Anschlüsse gleicher klemmeId+Ebene auf anderen Seiten laden.
            // Die Partnerseite bekommt dieselbe A↔B- und Stegbrücken-Injektion
            // wie die aktuelle Seite, damit Potenziale die nur über Stegbrücken
            // ankommen ebenfalls erkannt werden.
            if (root.projektId >= 0) {
                var _cpAlleKa = db.klemmenAnschlussAlleSeiten(root.projektId)
                var _cpStege  = db.klemmenStegbrueckenGruppen(root.projektId)
                // Fremdseiten: "klemmeId:ebene" → [seiteId, ...]
                var _cpFremd = {}
                for (var _cpI = 0; _cpI < _cpAlleKa.length; _cpI++) {
                    var _cpKa  = _cpAlleKa[_cpI]
                    if (_cpKa.seiteId === root.seiteId) continue
                    var _cpBez = _cpKa.anschlussBezeichnung || ""
                    var _cpEb  = (_cpBez === "PE" || _cpBez.indexOf(".") < 0) ? _cpBez : _cpBez.split(".")[0]
                    if (!_cpEb) continue
                    var _cpKey = _cpKa.klemmeId + ":" + _cpEb
                    if (!_cpFremd[_cpKey]) _cpFremd[_cpKey] = []
                    if (_cpFremd[_cpKey].indexOf(_cpKa.seiteId) < 0)
                        _cpFremd[_cpKey].push(_cpKa.seiteId)
                }
                var _cpCache = {}  // seiteId → {els, vbs}
                for (var _cpRi = 0; _cpRi < result.length; _cpRi++) {
                    var _cpNet = result[_cpRi]
                    if (_cpNet.signaltyp !== "neutral" && _cpNet.signaltyp !== "unversorgt") continue
                    var _cpDone = false
                    for (var _cpSi = 0; _cpSi < _cpNet.segmente.length && !_cpDone; _cpSi++) {
                        var _cpSeg = _cpNet.segmente[_cpSi]
                        for (var _cpSide = 0; _cpSide < 2 && !_cpDone; _cpSide++) {
                            var _cpEIdx = _cpSide === 0 ? _cpSeg.elIdxA : _cpSeg.elIdxB
                            if (_cpEIdx === undefined) continue
                            var _cpEl = elemente[_cpEIdx]
                            if (!_cpEl || _cpEl.symbolId !== "klemme_anschluss") continue
                            var _cpEd  = _cpEl.extraDaten || {}
                            var _cpKId = _cpEd.klemmeId || 0
                            if (_cpKId <= 0) continue
                            var _cpEBez = _cpEd.anschlussBezeichnung || ""
                            var _cpEEb  = (_cpEBez === "PE" || _cpEBez.indexOf(".") < 0) ? _cpEBez : _cpEBez.split(".")[0]
                            var _cpFPs  = _cpFremd[_cpKId + ":" + _cpEEb]
                            if (!_cpFPs || !_cpFPs.length) continue
                            for (var _cpFPi = 0; _cpFPi < _cpFPs.length && !_cpDone; _cpFPi++) {
                                var _cpSId = _cpFPs[_cpFPi]
                                if (!_cpCache[_cpSId]) {
                                    var _cpPEls = db.grafikLaden(_cpSId)
                                    var _cpPVbs = symbolDefinitionModel.autoVerbindungenBerechnen(_cpPEls, root.gridPx, {})
                                    // A↔B- und Stegbrücken-Injektion für die Partnerseite
                                    var _ppKGrp = {}, _ppKMap = {}
                                    for (var _ppI = 0; _ppI < _cpPEls.length; _ppI++) {
                                        var _ppEl = _cpPEls[_ppI]
                                        if (!_ppEl || _ppEl.symbolId !== "klemme_anschluss") continue
                                        var _ppEd = _ppEl.extraDaten || {}
                                        var _ppKId = _ppEd.klemmeId || 0
                                        if (_ppKId <= 0) continue
                                        var _ppBez = _ppEd.anschlussBezeichnung || ""
                                        var _ppEb  = (_ppBez === "PE" || _ppBez.indexOf(".") < 0) ? _ppBez : _ppBez.split(".")[0]
                                        if (!_ppEb) continue
                                        if (!_ppKMap[_ppKId]) _ppKMap[_ppKId] = []
                                        _ppKMap[_ppKId].push({elIdx: _ppI, ebene: _ppEb})
                                        var _ppGk = _ppKId + ":" + _ppEb
                                        if (!_ppKGrp[_ppGk]) _ppKGrp[_ppGk] = []
                                        _ppKGrp[_ppGk].push(_ppI)
                                    }
                                    var _ppLog = function(iA, iB) {
                                        var _ppEA = _cpPEls[iA], _ppEB = _cpPEls[iB]
                                        _cpPVbs.push({
                                            x1: (_ppEA.x1+_ppEA.x2)/2, y1: (_ppEA.y1+_ppEA.y2)/2,
                                            x2: (_ppEB.x1+_ppEB.x2)/2, y2: (_ppEB.y1+_ppEB.y2)/2,
                                            elIdxA: iA, rolleA: "durchleiter", quellSigA: "neutral",
                                            elIdxB: iB, rolleB: "durchleiter", quellSigB: "neutral",
                                            signaltyp: "neutral", logisch: true
                                        })
                                    }
                                    for (var _ppGkk in _ppKGrp) {
                                        var _ppGrp2 = _ppKGrp[_ppGkk]
                                        for (var _ppGi = 1; _ppGi < _ppGrp2.length; _ppGi++) _ppLog(_ppGrp2[0], _ppGrp2[_ppGi])
                                    }
                                    for (var _ppSi = 0; _ppSi < _cpStege.length; _ppSi++) {
                                        var _ppSteg = _cpStege[_ppSi]
                                        var _ppSEb  = String(_ppSteg.ebene)
                                        var _ppSIds = _ppSteg.klemmeIds
                                        var _ppSIdx = []
                                        for (var _ppSkI = 0; _ppSkI < _ppSIds.length; _ppSkI++) {
                                            var _ppEnts = _ppKMap[_ppSIds[_ppSkI]] || []
                                            for (var _ppEiI = 0; _ppEiI < _ppEnts.length; _ppEiI++) {
                                                if (String(_ppEnts[_ppEiI].ebene) === _ppSEb)
                                                    _ppSIdx.push(_ppEnts[_ppEiI].elIdx)
                                            }
                                        }
                                        for (var _ppSii = 1; _ppSii < _ppSIdx.length; _ppSii++) _ppLog(_ppSIdx[0], _ppSIdx[_ppSii])
                                    }
                                    _cpCache[_cpSId] = { els: _cpPEls, vbs: _cpPVbs }
                                }
                                var _cpPC = _cpCache[_cpSId]
                                var _cpSig = "neutral"
                                for (var _cpPEi = 0; _cpPEi < _cpPC.els.length; _cpPEi++) {
                                    var _cpPEl = _cpPC.els[_cpPEi]
                                    if (!_cpPEl || _cpPEl.symbolId !== "klemme_anschluss") continue
                                    var _cpPEd = _cpPEl.extraDaten || {}
                                    if ((_cpPEd.klemmeId || 0) !== _cpKId) continue
                                    var _cpPBez = _cpPEd.anschlussBezeichnung || ""
                                    var _cpPEb  = (_cpPBez === "PE" || _cpPBez.indexOf(".") < 0) ? _cpPBez : _cpPBez.split(".")[0]
                                    if (_cpPEb !== _cpEEb) continue
                                    var _cpCand = root._signaltypInVerbindungen(_cpPEi, _cpPC.vbs)
                                    if (_cpCand !== "neutral" && _cpCand !== "unversorgt") { _cpSig = _cpCand; break }
                                }
                                if (_cpSig !== "neutral" && _cpSig !== "unversorgt") {
                                    _cpNet.signaltyp = _cpSig
                                    _cpDone = true
                                }
                            }
                        }
                    }
                }
            }
            // ─────────────────────────────────────────────────────────────────────
            return result
        }

        // Abstandsberechnung Punkt→Liniensegment (Viewport-Koordinaten)
        function punktZuSegmentAbstand(px, py, x1, y1, x2, y2) {
            var dx = x2-x1, dy = y2-y1, lenSq = dx*dx+dy*dy
            if (lenSq < 0.001) return Math.sqrt((px-x1)*(px-x1)+(py-y1)*(py-y1))
            var t = Math.max(0, Math.min(1, ((px-x1)*dx+(py-y1)*dy)/lenSq))
            var nx = x1+t*dx, ny = y1+t*dy
            return Math.sqrt((px-nx)*(px-nx)+(py-ny)*(py-ny))
        }

        // Gibt Netzdaten des am nächsten liegenden Segments zurück (oder null).
        // vpX/vpY in Viewport-Koordinaten. Trifft nur wenn Abstand ≤ 8 px.
        function verbindungBeiPosition(vpX, vpY) {
            var netze = autoNetzeBerechnen()

            // ADPs für Pfad-Annotation sammeln
            var adpList = []
            var _vbpEls = elementeModel.snapshot()
            for (var eli = 0; eli < _vbpEls.length; eli++) {
                var adpEl = _vbpEls[eli]
                if (adpEl.typ === "symbol" && adpEl.symbolId === "aderdefinition") {
                    adpList.push({ cx: (adpEl.x1 + adpEl.x2) / 2,
                                   cy: (adpEl.y1 + adpEl.y2) / 2,
                                   ed: adpEl.extraDaten || {} })
                }
            }

            var best = null, bestDist = 8, bestSi = -1, bestNet = null
            for (var ni = 0; ni < netze.length; ni++) {
                var net = netze[ni]
                for (var si = 0; si < net.segmente.length; si++) {
                    var seg = net.segmente[si]
                    if (seg.logisch) continue   // logische QV-Brücke nicht anklickbar
                    var vx1 = seg.x1*root.zoom+root.worldX, vy1 = seg.y1*root.zoom+root.worldY
                    var vx2 = seg.x2*root.zoom+root.worldX, vy2 = seg.y2*root.zoom+root.worldY
                    var d = drawCanvas.punktZuSegmentAbstand(vpX, vpY, vx1, vy1, vx2, vy2)
                    if (d < bestDist) {
                        bestDist = d; bestSi = si; bestNet = net
                        best = { netKey: net.netKey, verbindungId: net.verbindungId,
                                 bezeichnung: net.bezeichnung, signaltyp: net.signaltyp,
                                 segmente: net.segmente,
                                 x1: seg.x1, y1: seg.y1, x2: seg.x2, y2: seg.y2 }
                    }
                }
            }

            if (best && bestNet) {
                var segAdps = drawCanvas.adpFuerNetSegmente(bestNet.segmente, adpList)
                best.adps = (bestSi >= 0 && bestSi < segAdps.length) ? segAdps[bestSi] : []
            }
            return best
        }

        // IEC-60757-Farbcode → Canvas-Farbe
        function aderFarbeZuCanvas(code) {
            if (code === "BK")   return "#222222"
            if (code === "BN")   return "#7b3f00"
            if (code === "RD")   return "#cc0000"
            if (code === "OG")   return "#ff6600"
            if (code === "YE")   return "#ccaa00"
            if (code === "GN")   return "#006600"
            if (code === "BU")   return "#0044cc"
            if (code === "VT")   return "#880099"
            if (code === "GY")   return "#666666"
            if (code === "WH")   return "#dddddd"
            if (code === "PK")   return "#ff88aa"
            if (code === "GNYE") return "#88bb00"
            return "#4a9eff"
        }

        // Gibt für jeden Segment-Index die Liste der zugehörigen ADPs zurück.
        // Pfadverfolgung durch Winkeln: Winkeln sind transparent, T-Stücke sind Grenzen.
        function adpFuerNetSegmente(netSegmente, adpList) {
            var n = netSegmente.length
            var directAdp = [], ki
            for (ki = 0; ki < n; ki++) directAdp.push([])

            for (var ai = 0; ai < adpList.length; ai++) {
                var adp = adpList[ai]
                var bestSi = -1, bestD = root.gridPx * 0.75
                for (var si0 = 0; si0 < n; si0++) {
                    var seg0 = netSegmente[si0]
                    if (seg0.logisch) continue   // kein ADP auf logischer QV-Brücke
                    var d0 = drawCanvas.punktZuSegmentAbstand(adp.cx, adp.cy,
                                 seg0.x1, seg0.y1, seg0.x2, seg0.y2)
                    if (d0 < bestD) { bestD = d0; bestSi = si0 }
                }
                if (bestSi >= 0) directAdp[bestSi].push(adp)
            }

            var adj = []
            for (ki = 0; ki < n; ki++) adj.push([])
            for (var si1 = 0; si1 < n; si1++) {
                var sA = netSegmente[si1]
                for (var sj = si1 + 1; sj < n; sj++) {
                    var sB = netSegmente[sj]
                    var cands = [sA.elIdxA, sA.elIdxB]
                    for (var ci = 0; ci < cands.length; ci++) {
                        var idx = cands[ci]
                        if (idx === sB.elIdxA || idx === sB.elIdxB) {
                            if (idx >= 0 && idx < elementeModel.anzahl) {
                                var shEl = elementeModel.element(idx)
                                // Winkel und Querverweis sind transparent für ADP-Propagation
                                if (shEl && (shEl.symbolId === "winkel"
                                             || shEl.symbolId === "querverweis")) {
                                    adj[si1].push(sj); adj[sj].push(si1)
                                }
                            }
                        }
                    }
                }
            }

            var result = []
            for (var si2 = 0; si2 < n; si2++) {
                var visited = {}, queue = [si2], collected = []
                while (queue.length > 0) {
                    var cur = queue.shift()
                    if (visited[cur]) continue
                    visited[cur] = true
                    for (var k0 = 0; k0 < directAdp[cur].length; k0++) collected.push(directAdp[cur][k0])
                    for (var k1 = 0; k1 < adj[cur].length; k1++) {
                        if (!visited[adj[cur][k1]]) queue.push(adj[cur][k1])
                    }
                }
                result.push(collected)
            }
            return result
        }

        // Schnittpunktberechnung Kabellinie × Auto-Verbindungen (Phase 5)
        // Zeichnet Adernummer + Farbe quer zur Kabellinie an jedem Schnittpunkt.
        function maleKabelSchnitte(ctx, el, netze) {
            if (!netze || netze.length === 0) return
            var kx1 = el.x1, ky1 = el.y1, kx2 = el.x2, ky2 = el.y2
            var kDxW = kx2 - kx1, kDyW = ky2 - ky1
            var kLenW = Math.sqrt(kDxW*kDxW + kDyW*kDyW)
            if (kLenW < 0.5) return

            // Schnittpunkte mit netKey berechnen (dedupliziert, sortiert)
            var schnitte = kabelSchnittNetzeBerechnenCached(el, netze)
            if (schnitte.length === 0) return

            var _rawAdn       = el.extraDaten ? el.extraDaten.adern : null
            var klAdern       = (_rawAdn && _rawAdn.length > 0) ? _rawAdn : []
            var aderZuordnung = (el.extraDaten && el.extraDaten.aderZuordnung)
                                ? el.extraDaten.aderZuordnung : null
            var klColor = el.strichFarbe || "#e07000"

            // Senkrechter Einheitsvektor zur Linie (Seite: visuell oben im Viewport)
            var nx = -kDyW/kLenW, ny = kDxW/kLenW
            if (ny > 0) { nx = -nx; ny = -ny }  // immer nach oben zeigen

            var kLabelFs = Math.max(6, Math.round(1.8 * root.mmToPx * root.zoom))
            var kTickLen = 5 * root.zoom / 10

            ctx.save()
            for (var sci = 0; sci < schnitte.length; sci++) {
                var sc = schnitte[sci]
                var wx = kx1 + sc.t * kDxW
                var wy = ky1 + sc.t * kDyW
                var vx = wx * root.zoom + root.worldX
                var vy = wy * root.zoom + root.worldY

                // Kurzer Querstrich
                ctx.strokeStyle = klColor; ctx.lineWidth = 1.5; ctx.setLineDash([])
                ctx.beginPath()
                ctx.moveTo(vx - nx * kTickLen, vy - ny * kTickLen)
                ctx.lineTo(vx + nx * kTickLen, vy + ny * kTickLen)
                ctx.stroke()

                // Ader-Label: aderZuordnung (aderKey→aderNr, 0 = explizit leer) hat
                // Vorrang, sonst positionsbasiert
                var aderNr = sci + 1
                var explizitLeer = false
                var zugeordnet = _netLookup(aderZuordnung, [sc.aderKey, sc.netKey, sc.legacyNetKey])
                if (zugeordnet !== undefined) {
                    if (zugeordnet === 0) explizitLeer = true
                    else aderNr = zugeordnet
                }
                var labelText = explizitLeer ? "–" : ("" + aderNr)
                // Farbe aus klAdern holen (Suche nach aderNr)
                if (!explizitLeer) {
                    for (var ai = 0; ai < klAdern.length; ai++) {
                        var klAd = klAdern[ai]
                        if ((klAd.aderNr !== undefined ? klAd.aderNr : (ai + 1)) === aderNr && klAd.farbe) {
                            labelText += "  " + klAd.farbe
                            break
                        }
                    }
                }

                ctx.font = kLabelFs + "px sans-serif"
                ctx.textBaseline = "bottom"
                var labelAbstand = kTickLen + Math.max(5, kLabelFs * 0.4)
                var lx, ly
                if (Math.abs(ny) < 0.1 || Math.abs(nx) < 0.1) {
                    // Achsenparallele Kabellinien: Label immer rechts vom Kreuzungspunkt
                    lx = vx + labelAbstand
                    ly = vy + ny * labelAbstand
                    ctx.textAlign = "left"
                } else {
                    lx = vx + nx * labelAbstand
                    ly = vy + ny * labelAbstand
                    ctx.textAlign = nx >= 0 ? "left" : "right"
                }
                if (!root.bewegungAktiv && 1.8 * root.mmToPx * root.zoom >= 7) {
                    ctx.fillStyle = klColor
                    ctx.fillText(labelText, lx, ly)
                }
            }
            ctx.restore()
        }

        // Viewport-Hit-Test auf die Ader-Nummer-Beschriftung an Kabel-
        // Kreuzungspunkten (Klickziel für die Inline-Aderzuordnung).
        // Nutzt dieselbe Geometrie wie maleKabelSchnitte(). Gibt bei Treffer
        // {kabelEl, aderKey, verbindungId, aktuelleAderNr, istLeer, vpX, vpY}
        // zurück (vpX/vpY = Anker-Position für das Popup), sonst null.
        function kabelKreuzungBeiPosition(vpX, vpY) {
            var elemente = elementeModel.snapshot()
            var netze    = autoNetzeBerechnen()
            var ctxM     = getContext("2d")
            var kLabelFs = Math.max(6, Math.round(1.8 * root.mmToPx * root.zoom))
            ctxM.font = kLabelFs + "px sans-serif"

            for (var ei = 0; ei < elemente.length; ei++) {
                var el = elemente[ei]
                if (el.typ !== "kabellinie") continue
                var kx1 = el.x1, ky1 = el.y1, kx2 = el.x2, ky2 = el.y2
                var kDxW = kx2 - kx1, kDyW = ky2 - ky1
                var kLenW = Math.sqrt(kDxW*kDxW + kDyW*kDyW)
                if (kLenW < 0.5) continue

                var schnitte = kabelSchnittNetzeBerechnenCached(el, netze)
                if (schnitte.length === 0) continue

                var _rawAdn2      = el.extraDaten ? el.extraDaten.adern : null
                var klAdern       = (_rawAdn2 && _rawAdn2.length > 0) ? _rawAdn2 : []
                var aderZuordnung = (el.extraDaten && el.extraDaten.aderZuordnung)
                                    ? el.extraDaten.aderZuordnung : null

                var nx = -kDyW/kLenW, ny = kDxW/kLenW
                if (ny > 0) { nx = -nx; ny = -ny }
                var kTickLen = 5 * root.zoom / 10

                for (var sci = 0; sci < schnitte.length; sci++) {
                    var sc = schnitte[sci]
                    var wx = kx1 + sc.t * kDxW, wy = ky1 + sc.t * kDyW
                    var vx = wx * root.zoom + root.worldX
                    var vy = wy * root.zoom + root.worldY

                    var aderNr = sci + 1
                    var istLeer = false
                    var zugeordnet = _netLookup(aderZuordnung, [sc.aderKey, sc.netKey, sc.legacyNetKey])
                    if (zugeordnet !== undefined) {
                        if (zugeordnet === 0) istLeer = true
                        else aderNr = zugeordnet
                    }
                    var labelText = istLeer ? "–" : ("" + aderNr)
                    if (!istLeer) {
                        for (var ai = 0; ai < klAdern.length; ai++) {
                            var klAd = klAdern[ai]
                            if ((klAd.aderNr !== undefined ? klAd.aderNr : (ai + 1)) === aderNr && klAd.farbe) {
                                labelText += "  " + klAd.farbe
                                break
                            }
                        }
                    }

                    var labelAbstand = kTickLen + Math.max(5, kLabelFs * 0.4)
                    var lx, ly, alignLeft
                    if (Math.abs(ny) < 0.1 || Math.abs(nx) < 0.1) {
                        lx = vx + labelAbstand; ly = vy + ny * labelAbstand; alignLeft = true
                    } else {
                        lx = vx + nx * labelAbstand; ly = vy + ny * labelAbstand
                        alignLeft = nx >= 0
                    }

                    var tw  = ctxM.measureText(labelText).width
                    var pad = 6
                    var bx1 = alignLeft ? lx - pad : lx - tw - pad
                    var bx2 = alignLeft ? lx + tw + pad : lx + pad
                    var by1 = ly - kLabelFs - pad
                    var by2 = ly + pad

                    if (vpX >= bx1 && vpX <= bx2 && vpY >= by1 && vpY <= by2) {
                        return {
                            kabelEl:       el,
                            aderKey:       sc.aderKey || sc.netKey || sc.legacyNetKey || "",
                            verbindungId:  sc.verbindungId || 0,
                            aktuelleAderNr: istLeer ? 0 : aderNr,
                            istLeer:       istLeer,
                            vpX: lx, vpY: ly
                        }
                    }
                }
            }
            return null
        }

        // Gibt die kreuzenden Verbindungsnetze einer Kabellinie zurück –
        // sortiert nach Position entlang der Linie (t=0..1), dedupliziert nach netKey.
        // Rückgabe: [{t, netKey, verbindungId, bezeichnung, signaltyp}]
        function kabelSchnittNetzeBerechnen(el, netze) {
            if (!netze || netze.length === 0 || !el) return []
            var kx1 = el.x1, ky1 = el.y1, kx2 = el.x2, ky2 = el.y2
            var kDxW = kx2 - kx1, kDyW = ky2 - ky1
            var kLenW = Math.sqrt(kDxW * kDxW + kDyW * kDyW)
            if (kLenW < 0.5) return []
            var elemente = elementeModel.snapshot()
            var gesehen = {}
            var schnitte = []
            for (var ni = 0; ni < netze.length; ni++) {
                var net = netze[ni]
                if (gesehen[net.netKey]) continue
                for (var si = 0; si < net.segmente.length; si++) {
                    var seg = net.segmente[si]
                    if (seg.logisch) continue
                    var dax = seg.x2 - seg.x1, day = seg.y2 - seg.y1
                    var D   = kDxW * day - kDyW * dax
                    if (Math.abs(D) < 0.001) continue
                    var t = ((seg.x1 - kx1) * day - (seg.y1 - ky1) * dax) / D
                    var s = ((seg.x1 - kx1) * kDyW - (seg.y1 - ky1) * kDxW) / D
                    if (t >= -0.005 && t <= 1.005 && s >= -0.005 && s <= 1.005) {
                        schnitte.push({
                            t:            Math.max(0, Math.min(1, t)),
                            netKey:       net.netKey,
                            legacyNetKey: net.legacyNetKey,
                            aderKey:      _lokalerAderSchluessel(seg, net, elemente),
                            verbindungId: net.verbindungId || 0,
                            bezeichnung:  net.bezeichnung  || "",
                            signaltyp:    net.signaltyp    || "neutral"
                        })
                        gesehen[net.netKey] = true
                        break
                    }
                }
            }
            schnitte.sort(function(a, b) { return a.t - b.t })
            return schnitte
        }

        // Gibt für jedes H-Segment (Schlüssel "ni-si") eine sortierte Liste von
        // World-X-Werten zurück, an denen ein V-Segment aus einem anderen Netz kreuzt.
        // Nur strenge Kreuzungen (kein Endpunkt am Schnittpunkt).
        function _kreuzungsLuecken(netze) {
            var hSegs = []
            var vSegs = []
            for (var ni = 0; ni < netze.length; ni++) {
                var segs = netze[ni].segmente
                for (var si = 0; si < segs.length; si++) {
                    var seg = segs[si]
                    if (seg.logisch) continue
                    if (Math.abs(seg.y2 - seg.y1) < 0.5) {
                        hSegs.push({ni: ni, si: si,
                                    x1: Math.min(seg.x1, seg.x2),
                                    x2: Math.max(seg.x1, seg.x2),
                                    y:  (seg.y1 + seg.y2) / 2})
                    } else if (Math.abs(seg.x2 - seg.x1) < 0.5) {
                        vSegs.push({ni: ni,
                                    x:  (seg.x1 + seg.x2) / 2,
                                    y1: Math.min(seg.y1, seg.y2),
                                    y2: Math.max(seg.y1, seg.y2)})
                    }
                }
            }
            var result = {}
            for (var hi = 0; hi < hSegs.length; hi++) {
                var h = hSegs[hi]
                for (var vi = 0; vi < vSegs.length; vi++) {
                    var v = vSegs[vi]
                    if (h.ni === v.ni) continue
                    if (v.x <= h.x1 || v.x >= h.x2) continue
                    if (h.y <= v.y1 || h.y >= v.y2) continue
                    var key = h.ni + "-" + h.si
                    if (!result[key]) result[key] = []
                    result[key].push(v.x)
                }
            }
            for (var k in result)
                result[k].sort(function(a, b) { return a - b })
            return result
        }

        function autoNetzeBerechnenCached() {
            if (root._cachedNetze !== null) return root._cachedNetze
            root._cachedNetze = autoNetzeBerechnen()
            return root._cachedNetze
        }

        function kabelSchnittNetzeBerechnenCached(el, netze) {
            var elId = el ? (el.id || 0) : 0
            if (elId > 0 && root._cachedKabelSchnitte[elId] !== undefined)
                return root._cachedKabelSchnitte[elId]
            var result = kabelSchnittNetzeBerechnen(el, netze)
            if (elId > 0) root._cachedKabelSchnitte[elId] = result
            return result
        }

        function maleAutoVerbindungen(ctx, netze) {
            if (netze === undefined) netze = autoNetzeBerechnenCached()
            if (netze.length === 0) return

            var _fsPfadKeys = Object.keys(root.fehlersuchPfadIds)
            var _fsAktiv    = root.fehlersuchModus && _fsPfadKeys.length > 0

            var kreuzungsLuecken = drawCanvas._kreuzungsLuecken(netze)

            // Alle Aderdefinitionspunkte sammeln
            var adpList = []
            var _mavEls = elementeModel.snapshot()
            for (var eli = 0; eli < _mavEls.length; eli++) {
                var adpEl = _mavEls[eli]
                if (adpEl.typ === "symbol" && adpEl.symbolId === "aderdefinition") {
                    adpList.push({ cx: (adpEl.x1 + adpEl.x2) / 2,
                                   cy: (adpEl.y1 + adpEl.y2) / 2,
                                   ed: adpEl.extraDaten || {} })
                }
            }

            ctx.setLineDash([])
            ctx.lineCap = "square"
            ctx.globalAlpha = 1.0

            for (var ni = 0; ni < netze.length; ni++) {
                var net = netze[ni]
                var segs = net.segmente
                var segAdps = drawCanvas.adpFuerNetSegmente(segs, adpList)

                for (var si = 0; si < segs.length; si++) {
                    var seg = segs[si]
                    if (seg.logisch) continue   // logische QV-Brücke nicht zeichnen
                    var sAdps = segAdps[si]

                    // Fehlersuchmodus: Segment ausblenden wenn nicht im aktiven Pfad
                    if (_fsAktiv) {
                        var _eA = elementeModel.element(seg.elIdxA)
                        var _eB = elementeModel.element(seg.elIdxB)
                        var _imPfad = root.fehlersuchPfadIds[(_eA.id || -1)] !== undefined
                                   && root.fehlersuchPfadIds[(_eB.id || -1)] !== undefined
                        ctx.globalAlpha = _imPfad ? 1.0 : 0.12
                    } else {
                        ctx.globalAlpha = 1.0
                    }

                    var lineClr = drawCanvas.signaltypFarbe(net.signaltyp)
                    if (net.signaltyp !== "konflikt" && sAdps.length > 0 && sAdps[0].ed.aderfarbe)
                        lineClr = drawCanvas.aderFarbeZuCanvas(sAdps[0].ed.aderfarbe)

                    var anz = Math.max(1, sAdps.length)
                    var lw  = anz <= 3 ? anz * 1.5 : 4.5
                    if (net.signaltyp === "konflikt")   lw = lw * 2
                    if (net.signaltyp === "unversorgt") lw = lw * 1.5

                    ctx.strokeStyle = lineClr
                    ctx.lineWidth   = lw
                    var segKey  = ni + "-" + si
                    var kreuzX  = kreuzungsLuecken[segKey]
                    var isHSeg  = Math.abs(seg.y2 - seg.y1) < 0.5
                    if (isHSeg && kreuzX && kreuzX.length > 0) {
                        // Gap-Breite: konstant 8 Pixel sichtbar, unabhängig von Zoom
                        var luecke  = 4 / root.zoom
                        var hx1 = Math.min(seg.x1, seg.x2)
                        var hx2 = Math.max(seg.x1, seg.x2)
                        var hy  = (seg.y1 + seg.y2) / 2
                        var pos = hx1
                        ctx.save()
                        ctx.lineCap = "butt"   // kein Cap-Überhang → exakte Lücke
                        for (var ki = 0; ki < kreuzX.length; ki++) {
                            var cx  = kreuzX[ki]
                            var ls  = cx - luecke
                            var le  = cx + luecke
                            if (ls > pos) {
                                ctx.beginPath()
                                ctx.moveTo(pos * root.zoom + root.worldX, hy * root.zoom + root.worldY)
                                ctx.lineTo(ls  * root.zoom + root.worldX, hy * root.zoom + root.worldY)
                                ctx.stroke()
                            }
                            pos = le
                        }
                        if (pos < hx2) {
                            ctx.beginPath()
                            ctx.moveTo(pos * root.zoom + root.worldX, hy * root.zoom + root.worldY)
                            ctx.lineTo(hx2 * root.zoom + root.worldX, hy * root.zoom + root.worldY)
                            ctx.stroke()
                        }
                        ctx.restore()
                    } else {
                        ctx.beginPath()
                        ctx.moveTo(seg.x1 * root.zoom + root.worldX, seg.y1 * root.zoom + root.worldY)
                        ctx.lineTo(seg.x2 * root.zoom + root.worldX, seg.y2 * root.zoom + root.worldY)
                        ctx.stroke()
                    }

                    if (sAdps.length >= 4 && !root.bewegungAktiv) {
                        var mvx = (seg.x1 + seg.x2) / 2 * root.zoom + root.worldX
                        var mvy = (seg.y1 + seg.y2) / 2 * root.zoom + root.worldY
                        ctx.save()
                        ctx.font = "bold " + Math.max(8, Math.round(9 * root.zoom)) + "px sans-serif"
                        ctx.fillStyle = lineClr
                        ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                        ctx.fillText("" + sAdps.length, mvx, mvy - 3)
                        ctx.restore()
                    }
                }
            }

            ctx.lineWidth = 1.5

            // Ausgewählte Verbindungssegmente hervorheben
            if (root.ausgewaehltVerbindung) {
                var sel = root.ausgewaehltVerbindung
                ctx.lineWidth = 3.5; ctx.globalAlpha = 0.65; ctx.strokeStyle = "#ffffff"
                for (var si3 = 0; si3 < sel.segmente.length; si3++) {
                    var s = sel.segmente[si3]
                    ctx.beginPath()
                    ctx.moveTo(s.x1*root.zoom+root.worldX, s.y1*root.zoom+root.worldY)
                    ctx.lineTo(s.x2*root.zoom+root.worldX, s.y2*root.zoom+root.worldY)
                    ctx.stroke()
                }
                ctx.lineWidth = 1.5; ctx.globalAlpha = 1.0
            }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0,0,width,height)
            drawCanvas.drawNormblatt(ctx)
            var elemente = elementeModel.snapshot()
            // Gerätekasten-Liste einmalig filtern — GA-Rendering nutzt drawCanvas._gkListe
            var _gkBuf = []
            for (var _gi = 0; _gi < elemente.length; _gi++)
                if (elemente[_gi] && elemente[_gi].typ === "geraetekasten") _gkBuf.push(elemente[_gi])
            drawCanvas._gkListe = _gkBuf
            for (var i=0; i<elemente.length; i++)
                drawCanvas.maleElement(ctx, elemente[i], i)

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
                drawCanvas.maleElement(ctx, root.vorschau, -1)
            if (root.vorschau !== null && root.vorschau.typ === "makrokasten"
                    && root.makroVorschauElemente.length > 0) {
                var ox = root.vorschau.x1
                var oy = root.vorschau.y1
                for (var mpi = 0; mpi < root.makroVorschauElemente.length; mpi++) {
                    var mpe = root.makroVorschauElemente[mpi]
                    drawCanvas.maleElement(ctx, {
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
                    drawCanvas.maleElement(ctx, root.duplizierVorschau[dvi], -1)
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
            var _repaintNetze = drawCanvas.autoNetzeBerechnenCached()
            drawCanvas.maleAutoVerbindungen(ctx, _repaintNetze)
            // Schnittpunkte aller Kabellinien mit Auto-Verbindungen (Phase 5)
            for (var kli = 0; kli < elemente.length; kli++) {
                if (elemente[kli].typ === "kabellinie")
                    drawCanvas.maleKabelSchnitte(ctx, elemente[kli], _repaintNetze)
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
            drawCanvas.drawNormblattAussenoverlay(ctx)
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
            var netze = drawCanvas.autoNetzeBerechnen()
            db.verbindungenSynchronisieren(root.seiteId, root.projektId, netze)
            root.verbindungAnnotationenNeuLaden()
        }
    }

    function verdrahtungswegeAktualisieren()              { verdrahtungsHandler.verdrahtungswegeAktualisieren() }
    function verbindungAnnotationenNeuLaden()             { verdrahtungsHandler.verbindungAnnotationenNeuLaden() }
    function verbindungAnnotationAktualisieren(key, value){ verdrahtungsHandler.verbindungAnnotationAktualisieren(key, value) }
    function _signaltypInVerbindungen(elIdx, vbs)         { return verdrahtungsHandler._signaltypInVerbindungen(elIdx, vbs) }

    CanvasVerdrahtungsHandler { id: verdrahtungsHandler; cv: root }

    // --------------------------------------------------------
    // Querverweis-Navigation
    // --------------------------------------------------------
    // Baut den Partner-Cache: elementIdx → Blattnummer der Gegenseite.
    // Wird beim Laden einer Seite einmal aufgerufen.
    function hfReferenzMapAktualisieren() {
        if (root.projektId < 0) { root._hfReferenzMap = {}; return }
        var liste = db.betriebsmittelHfListe(root.projektId)
        var map = {}
        for (var i = 0; i < liste.length; i++) {
            var e = liste[i]
            map[e.betriebsmittelId] = {
                hauptElementId: e.hauptElementId,
                blattnummer:    e.blattnummer,
                seiteId:        e.seiteId
            }
        }
        root._hfReferenzMap = map
    }

    function spsKonfliktAktualisieren() {
        if (root.projektId < 0) { root._spsKonfliktSet = {}; return }
        var ids = db.spsKonfliktElementIds(root.projektId)
        var s = {}
        for (var i = 0; i < ids.length; i++) s[ids[i]] = true
        root._spsKonfliktSet = s
        repaintAll()
    }

    function hfKarteAktualisieren() {
        hfReferenzMapAktualisieren()
        repaintAll()
    }

    function querverweisPartnerCacheAktualisieren() {
        if (root.seiteId < 0 || root.projektId < 0) { root._querverweisPartnerMap = {}; return }
        var alle = db.querverweiseLadenProjekt(root.projektId)
        var map = {}
        var _qvEls = elementeModel.snapshot()
        for (var i = 0; i < _qvEls.length; i++) {
            var el = _qvEls[i]
            if (el.typ !== "symbol" || el.symbolId !== "querverweis") continue
            var sn = (el.extraDaten && el.extraDaten.signalname) || ""
            if (!sn) continue
            for (var k = 0; k < alle.length; k++) {
                var qv = alle[k]
                if (qv.signalname !== sn) continue
                if (qv.seiteId === root.seiteId && Math.abs(qv.x1 - el.x1) < 0.5 && Math.abs(qv.y1 - el.y1) < 0.5) continue
                map[i] = {
                    label:   qv.blattnummer + (qv.seitenBezeichnung ? " " + qv.seitenBezeichnung : ""),
                    seiteId: qv.seiteId,
                    x1:      qv.x1,
                    y1:      qv.y1
                }
                break
            }
        }
        root._querverweisPartnerMap = map
    }

    function kabelLinienCacheAktualisieren() {
        var map = {}
        var _klEls = elementeModel.snapshot()
        for (var i = 0; i < _klEls.length; i++) {
            var el = _klEls[i]
            if (el.typ !== "kabellinie") continue
            var kId = (el.extraDaten && el.extraDaten.kabelId) || 0
            if (kId <= 0 || kId in map) continue
            var linien = db.kabelAlleLinienLaden(kId)
            map[kId] = linien.length
        }
        root._kabelLinienCache = map
    }

    // Zentriert die Canvas-Ansicht auf eine Weltkoordinate.
    function _zoomZuWeltPosition(wx, wy) {
        var topH = headerBar.visible ? headerBar.height : 0
        var botH = footerBar.visible ? footerBar.height : 0
        var tlW  = werkzeugLeiste.visible ? werkzeugLeiste.width : 0
        root.worldX = tlW + (width - tlW) / 2 - wx * root.zoom
        root.worldY = topH + (height - topH - botH) / 2 - wy * root.zoom
        root.repaintAll()
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
        return drawCanvas.kabelSchnittNetzeBerechnen(el, drawCanvas.autoNetzeBerechnen())
    }

    // Baut eine Map netKey → anschlusskennzeichnung des Geräte-Pins am Netzende.
    // Wird für den Aderzuordnungsmodus „Pin-Nummer" (M10) benötigt.
    function _pinNummernFuerNetze(netze) {
        var els = elementeModel.snapshot()
        var map = {}
        for (var ni = 0; ni < netze.length; ni++) {
            var net  = netze[ni]
            var segs = net.segmente
            for (var si = 0; si < segs.length; si++) {
                var seg = segs[si]
                for (var k = 0; k < 2; k++) {
                    var idx = k === 0 ? seg.elIdxA : seg.elIdxB
                    if (idx === undefined) continue
                    var el  = els[idx]
                    if (!el || el.typ !== "symbol" || el.symbolId !== "geraeteanschluss") continue
                    var ank = (el.extraDaten && el.extraDaten.anschlusskennzeichnung) || ""
                    if (ank && !map[net.netKey]) { map[net.netKey] = ank; break }
                }
                if (map[net.netKey]) break
            }
        }
        return map
    }

    // Öffnet den Aderzuordnungsdialog für das übergebene kabellinie-Element
    // (wird aus EigenschaftenPanel aufgerufen).
    function aderzuordnungDialogOeffnen(el) {
        if (!el || el.typ !== "kabellinie") return
        var ed      = el.extraDaten || {}
        var kabelId = ed.kabelId || 0
        if (kabelId <= 0) return

        var savedAuswahl = root.auswahl.slice()
        elementeModel.laden(root.seiteId)
        root.auswahl = savedAuswahl
        var reloaded = elementeModel.snapshot()

        var elId = el.id || 0
        var freshEl = null
        for (var i = 0; i < reloaded.length; i++) {
            if (reloaded[i].id === elId) { freshEl = reloaded[i]; break }
        }
        var currentEl = freshEl || el
        var freshGeid = currentEl.id || 0

        var details  = db.kabelLinieDetails(freshGeid)
        var netze    = drawCanvas.autoNetzeBerechnen()
        var schnitte = drawCanvas.kabelSchnittNetzeBerechnen(currentEl, netze)

        // Vollständige Aderliste aufbauen: DB-Einträge + fehlende aderNr als freie Platzhalter
        var aderzahl = details.aderzahl || ed.aderzahl || 0
        var rawAdern = details.adern || []
        var aderMap  = {}
        for (var ai = 0; ai < rawAdern.length; ai++)
            aderMap[rawAdern[ai].aderNr] = rawAdern[ai]
        var fullAdern = []
        for (var nr = 1; nr <= aderzahl; nr++)
            fullAdern.push(aderMap[nr] || { aderNr: nr, farbe: "", bezeichnung: "", verbindungId: 0, kabellinieGrafikElementId: 0 })

        dialogLayer.aderzuordnungOeffnen(kabelId, ed.bezeichnung || "", ed.kabeltyp || "",
            aderzahl, fullAdern, schnitte, ed.aderZuordnung || {},
            freshGeid, _pinNummernFuerNetze(netze))
    }

    // Liefert die Ader-Nummern 1..aderzahl, die NICHT bereits an einer
    // ANDEREN Kreuzung derselben Kabellinie vergeben sind (eigenerAderKey
    // wird ausgenommen, damit die aktuell zugeordnete Ader selbst nicht
    // fälschlich als "belegt" gilt).
    function _freieAdernFuerKreuzung(aderzahl, aderZuordnung, schnitte, eigenerAderKey) {
        var belegt = {}
        for (var i = 0; i < schnitte.length; i++) {
            var sc  = schnitte[i]
            var key = sc.aderKey || sc.netKey || sc.legacyNetKey || ""
            if (key === eigenerAderKey) continue
            var zugeordnet = drawCanvas._netLookup(aderZuordnung, [sc.aderKey, sc.netKey, sc.legacyNetKey])
            if (zugeordnet !== undefined && zugeordnet !== 0) belegt[zugeordnet] = true
        }
        var frei = []
        for (var nr = 1; nr <= aderzahl; nr++)
            if (!belegt[nr]) frei.push(nr)
        return frei
    }

    // Öffnet das Inline-Popup zur Korrektur EINER Ader-Zuordnung am
    // Kreuzungspunkt (treffer = Rückgabe von kabelKreuzungBeiPosition()).
    function aderKreuzungPickerOeffnen(treffer) {
        if (!treffer || !treffer.kabelEl) return
        var el      = treffer.kabelEl
        var ed      = el.extraDaten || {}
        var kabelId = ed.kabelId || 0
        if (kabelId <= 0) return

        var savedAuswahl = root.auswahl.slice()
        elementeModel.laden(root.seiteId)
        root.auswahl = savedAuswahl
        var reloaded = elementeModel.snapshot()

        var elId = el.id || 0
        var freshEl = null
        for (var i = 0; i < reloaded.length; i++) {
            if (reloaded[i].id === elId) { freshEl = reloaded[i]; break }
        }
        var currentEl = freshEl || el
        var freshGeid = currentEl.id || 0
        var freshEd   = currentEl.extraDaten || {}

        var details  = db.kabelLinieDetails(freshGeid)
        var aderzahl = details.aderzahl || freshEd.aderzahl || 0
        var rawAdern = details.adern || []
        var aderMap  = {}
        for (var ai = 0; ai < rawAdern.length; ai++) aderMap[rawAdern[ai].aderNr] = rawAdern[ai]

        var netze    = drawCanvas.autoNetzeBerechnen()
        var schnitte = drawCanvas.kabelSchnittNetzeBerechnen(currentEl, netze)
        var freieNrn = _freieAdernFuerKreuzung(aderzahl, freshEd.aderZuordnung || {}, schnitte, treffer.aderKey)

        var freieAdern = []
        for (var fi = 0; fi < freieNrn.length; fi++) {
            var nr = freieNrn[fi]
            freieAdern.push(aderMap[nr] || { aderNr: nr, farbe: "", bezeichnung: "" })
        }
        var alteAder = aderMap[treffer.aktuelleAderNr] || { aderNr: treffer.aktuelleAderNr, farbe: "", bezeichnung: "" }

        dialogLayer.aderKreuzungPickerOeffnen(kabelId, freshGeid, treffer.aderKey,
            treffer.verbindungId, treffer.aktuelleAderNr, treffer.istLeer,
            alteAder, freieAdern, treffer.vpX, treffer.vpY)
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
    // Koordinaten-Hilfsfunktionen
    // --------------------------------------------------------
    function rasterPunkt(weltX, weltY) {
        return Qt.point(Math.round(weltX/root.gridPx)*root.gridPx, Math.round(weltY/root.gridPx)*root.gridPx)
    }
    function viewportZuWelt(vpX, vpY) {
        return Qt.point((vpX-root.worldX)/root.zoom, (vpY-root.worldY)/root.zoom)
    }
    function weltZuViewport(wX, wY) {
        return Qt.point(wX*root.zoom+root.worldX, wY*root.zoom+root.worldY)
    }

    // --------------------------------------------------------
    // Treffer-Test
    // --------------------------------------------------------
    function elementBeiPosition(vpX, vpY) {
        return elementeModel.elementBeiPosition(vpX, vpY, root.zoom, root.worldX, root.worldY)
    }

    // Prüft ob Maus über einem Handle des selektierten Elements liegt.
    // Gibt Handle-Index zurück oder -1.
    function griffBeiPosition(vpX, vpY) {
        if (root.ausgewaehlt < 0 || root.ausgewaehlt >= elementeModel.anzahl) return -1
        var el  = elementeModel.element(root.ausgewaehlt)
        var pts = drawCanvas.griffPunkte(el)
        for (var i = 0; i < pts.length; i++) {
            var gvx = pts[i].x * root.zoom + root.worldX
            var gvy = pts[i].y * root.zoom + root.worldY
            var d   = Math.sqrt((vpX-gvx)*(vpX-gvx) + (vpY-gvy)*(vpY-gvy))
            if (d < 10) return i
        }
        return -1
    }

    function punktZuStrecke(px,py,x1,y1,x2,y2) {
        var dx=x2-x1, dy=y2-y1, lenSq=dx*dx+dy*dy
        if (lenSq<0.001) return Math.sqrt((px-x1)*(px-x1)+(py-y1)*(py-y1))
        var t=Math.max(0,Math.min(1,((px-x1)*dx+(py-y1)*dy)/lenSq))
        return Math.sqrt((px-x1-t*dx)*(px-x1-t*dx)+(py-y1-t*dy)*(py-y1-t*dy))
    }

    // Pin-Position in Weltkoordinaten (analog zu drawCanvas.pinViewportPos, aber ohne Zoom)
    // Gibt {anlage, ort} für ein Element zurück – per kleinsten umschließenden
    // Strukturkasten, Fallback auf Seiten-Normblattdaten.
    function anlageOrtFuer(el) {
        var nd     = root.normblattDaten
        var anlage = nd ? (nd.anlageKuerzel || "") : ""
        var ort    = nd ? (nd.ortKuerzel    || "") : ""
        var cx = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
        var bestArea = Infinity
        var _anlEls = elementeModel.snapshot()
        for (var i = 0; i < _anlEls.length; i++) {
            var sk = _anlEls[i]
            if (sk.typ !== "strukturkasten") continue
            var sx1 = Math.min(sk.x1, sk.x2), sx2 = Math.max(sk.x1, sk.x2)
            var sy1 = Math.min(sk.y1, sk.y2), sy2 = Math.max(sk.y1, sk.y2)
            if (cx >= sx1 && cx <= sx2 && cy >= sy1 && cy <= sy2) {
                var area = (sx2 - sx1) * (sy2 - sy1)
                if (area < bestArea) {
                    bestArea = area
                    var sed  = sk.extraDaten || {}
                    if (sed.skAnlage) anlage = sed.skAnlage
                    if (sed.skOrt)    ort    = sed.skOrt
                }
            }
        }
        return { anlage: anlage, ort: ort }
    }

    function pinWeltPos(el, pinX, pinY) {
        var sw = el.x2 - el.x1, sh = el.y2 - el.y1
        var scx = el.x1 + sw / 2, scy = el.y1 + sh / 2
        var cx = (pinX - 0.5) * Math.abs(sw)
        var cy = (pinY - 0.5) * Math.abs(sh)
        if (el.spiegelX) cx = -cx
        if (el.spiegelY) cy = -cy
        var rot = (el.rotation || 0) * Math.PI / 180
        return { x: scx + cx * Math.cos(rot) - cy * Math.sin(rot),
                 y: scy + cx * Math.sin(rot) + cy * Math.cos(rot) }
    }

    // --------------------------------------------------------
    // Ansicht
    // --------------------------------------------------------
    function repaintAll() { gridCanvas.requestPaint(); drawCanvas.requestPaint() }

    function zoomAnpassen(factor) {
        var nz=Math.max(root.minZoom,Math.min(root.maxZoom,root.zoom*factor))
        var topH=headerBar.visible?headerBar.height:0, botH=footerBar.visible?footerBar.height:0
        var tlW=werkzeugLeiste.visible?werkzeugLeiste.width:0
        var cx=tlW+(width-tlW)/2, cy=topH+(height-topH-botH)/2
        root.worldX=cx-(cx-root.worldX)*(nz/root.zoom)
        root.worldY=cy-(cy-root.worldY)*(nz/root.zoom)
        root.zoom=nz; root.repaintAll()
    }

    function ansichtZuruecksetzen() {
        var topH=headerBar.visible?headerBar.height:0, botH=footerBar.visible?footerBar.height:0
        var tlW=werkzeugLeiste.visible?werkzeugLeiste.width:0
        root.zoom=1.0
        root.worldX=tlW+(width-tlW)/2
        root.worldY=topH+(height-topH-botH)/2
        root.repaintAll()
    }

    function autoPanFuerAuswahl() {
        if (root.ausgewaehlt < 0 || !eigenschaftenPanel.visible) return
        var el = elementeModel.element(root.ausgewaehlt)
        if (!el || !el.typ) return
        var epBreite = eigenschaftenPanel.width + 16
        var tlW  = werkzeugLeiste.visible ? werkzeugLeiste.width : 0
        var topH = headerBar.visible ? headerBar.height : 0
        var botH = footerBar.visible ? footerBar.height : 0
        // Viewport-Koordinaten des Elements
        var vx1 = el.x1 * root.zoom + root.worldX
        var vy1 = el.y1 * root.zoom + root.worldY
        var vx2 = el.x2 * root.zoom + root.worldX
        var vy2 = el.y2 * root.zoom + root.worldY
        var elMinX = Math.min(vx1, vx2), elMaxX = Math.max(vx1, vx2)
        var elMinY = Math.min(vy1, vy2), elMaxY = Math.max(vy1, vy2)
        var elCx = (elMinX + elMaxX) / 2
        var elCy = (elMinY + elMaxY) / 2
        var pad = 20
        var visRight = width - epBreite - pad
        var visLeft  = tlW + pad
        var visTop   = topH + pad
        var visBot   = height - botH - pad
        // Kein Pan wenn Element bereits teilweise sichtbar (z.B. Rahmen eines großen Kastens)
        if (elMinX < visRight && elMaxX > visLeft && elMinY < visBot && elMaxY > visTop) return
        // Nur pan wenn Element vollständig außerhalb: Mittelpunkt in Viewport bringen
        var dx = 0, dy = 0
        if (elCx > visRight)  dx = elCx - visRight
        if (elCx < visLeft)   dx = elCx - visLeft
        if (elCy > visBot)    dy = elCy - visBot
        if (elCy < visTop)    dy = elCy - visTop
        if (dx !== 0 || dy !== 0) {
            root.worldX -= dx
            root.worldY -= dy
            root.repaintAll()
        }
    }

    function zoomNormblattEinpassen() {
        var nd = root.normblattDaten
        if (!nd || !nd.breiteMm || !nd.hoeheMm) { ansichtZuruecksetzen(); return }
        var bW  = nd.breiteMm * root.mmToPx
        var bH  = nd.hoeheMm  * root.mmToPx
        var topH = headerBar.visible ? headerBar.height : 0
        var botH = footerBar.visible ? footerBar.height : 0
        var tlW  = werkzeugLeiste.visible ? werkzeugLeiste.width : 0
        var vpW  = width - tlW
        var vpH  = height - topH - botH
        var pad  = 40
        var newZoom = Math.min((vpW - 2*pad) / bW, (vpH - 2*pad) / bH, 4.0)
        newZoom = Math.max(newZoom, 0.05)
        root.zoom   = newZoom
        root.worldX = tlW + vpW/2 - (bW/2) * newZoom
        root.worldY = topH + vpH/2 - (bH/2) * newZoom
        root.repaintAll()
    }

    function zoomAllesEinpassen() {
        var _zaeEls = elementeModel.snapshot()
        if (_zaeEls.length === 0) { ansichtZuruecksetzen(); return }
        var minX=Infinity, minY=Infinity, maxX=-Infinity, maxY=-Infinity
        for (var i = 0; i < _zaeEls.length; i++) {
            var el = _zaeEls[i]
            minX = Math.min(minX, el.x1, el.x2)
            minY = Math.min(minY, el.y1, el.y2)
            maxX = Math.max(maxX, el.x1, el.x2)
            maxY = Math.max(maxY, el.y1, el.y2)
        }
        var topH = headerBar.visible ? headerBar.height : 0
        var botH = footerBar.visible ? footerBar.height : 0
        var tlW  = werkzeugLeiste.visible ? werkzeugLeiste.width : 0
        var vpW  = width - tlW
        var vpH  = height - topH - botH
        var bboxW = maxX - minX, bboxH = maxY - minY
        if (bboxW <= 0 || bboxH <= 0) { ansichtZuruecksetzen(); return }
        var pad = 40
        var newZoom = Math.min((vpW - 2*pad) / bboxW, (vpH - 2*pad) / bboxH, 4.0)
        newZoom = Math.max(newZoom, 0.05)
        root.zoom   = newZoom
        root.worldX = tlW + vpW/2 - (minX + maxX)/2 * newZoom
        root.worldY = topH + vpH/2 - (minY + maxY)/2 * newZoom
        root.repaintAll()
    }

    function zoomAuswahlEinpassen() {
        if (root.auswahl.length === 0) { zoomAllesEinpassen(); return }
        var minX=Infinity, minY=Infinity, maxX=-Infinity, maxY=-Infinity
        for (var i = 0; i < root.auswahl.length; i++) {
            var el = elementeModel.element(root.auswahl[i])
            if (!el) continue
            minX = Math.min(minX, el.x1, el.x2)
            minY = Math.min(minY, el.y1, el.y2)
            maxX = Math.max(maxX, el.x1, el.x2)
            maxY = Math.max(maxY, el.y1, el.y2)
        }
        if (!isFinite(minX)) return
        var topH = headerBar.visible ? headerBar.height : 0
        var botH = footerBar.visible ? footerBar.height : 0
        var tlW  = werkzeugLeiste.visible ? werkzeugLeiste.width : 0
        var vpW  = width - tlW
        var vpH  = height - topH - botH
        var bboxW = maxX - minX
        var bboxH = maxY - minY
        var pad = 60
        var newZoom
        if (bboxW < 2 && bboxH < 2) {
            newZoom = 2.0
        } else {
            newZoom = Math.min((vpW - 2*pad) / Math.max(bboxW, 1),
                               (vpH - 2*pad) / Math.max(bboxH, 1), 4.0)
            newZoom = Math.max(newZoom, 0.1)
        }
        root.zoom   = newZoom
        root.worldX = tlW + vpW/2 - (minX + maxX)/2 * newZoom
        root.worldY = topH + vpH/2 - (minY + maxY)/2 * newZoom
        root.repaintAll()
    }

    function seiteNeuLaden() {
        if (seiteId >= 0) {
            elementeModel.laden(seiteId)
            hfReferenzMapAktualisieren()
            spsKonfliktAktualisieren()
            autoVerbindungenBerechnen()
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
            root.querverweisPartnerCacheAktualisieren()
            // Kabellinien-Anzahl-Cache aufbauen
            root.kabelLinienCacheAktualisieren()
            // HF-Referenz-Map aufbauen
            root.hfReferenzMapAktualisieren()
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
