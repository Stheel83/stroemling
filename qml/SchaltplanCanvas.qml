import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import "components"
import "canvas"

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
    property string hintergrundFarbe: "#080f1c"

    required property var theme
    property bool debug: false
    onDebugChanged: drawCanvas.requestPaint()
    required property var elementeModel

    signal hintergrundGeaendert(string farbe)
    signal querverweisNavigieren(int seiteId)
    signal gkSprungAngefordert(int seiteId, string blattnr, string seiteBez, real wx, real wy)
    signal makroListeGeaendert()
    signal drcKlick()

    property bool drcAktiv: false

    property real zoom:    1.0
    property real minZoom: 0.1
    property real maxZoom: 8.0

    property real worldX: 0
    property real worldY: 0

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
    property string paletteSymbolId:       ""
    property int    paletteSymbolRotation: 0    // 0 / 90 / 180 / 270 – Vorab-Rotation beim Platzieren
    property var    paletteExtraDaten:     ({})  // Extra-Daten für das nächste platzierte Symbol
    property real   letzteMausWeltX:       0    // letzte bekannte Cursor-Weltposition (für Tab-Rotate)
    property real   letzteMausWeltY:       0

    onPaletteSymbolIdChanged: {
        paletteSymbolRotation = 0
        paletteExtraDaten = {}
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

    // Auswahl & Verschieben (Zeiger-Werkzeug)
    property var  auswahl:             []     // Indizes aller selektierten Elemente
    onAuswahlChanged: {
        // Re-focus canvas after EP becomes visible (EP's ScrollView can grab focus synchronously)
        if (root.auswahl.length > 0 && !root.textEditAktiv)
            Qt.callLater(function() { root.forceActiveFocus() })
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
    property var  _querverweisZielPos:   null
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
        eckenRadius:    0
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

    // ── Inbetriebnahme-Modus ─────────────────────────────────
    property bool ibnModus:    false
    property var  ibnStatusMap:    ({})   // bmk → "offen"|"in_arbeit"|"abgeschlossen"
    property var  _spsKonfliktSet: ({})   // elementId → true  (mehr als 1 Kanal zugewiesen)

    // ── Fehlersuchmodus ──────────────────────────────────────
    property bool fehlersuchModus:        false
    property var  fehlersuchPfadIds:      ({})  // elementId → true (im Pfad)
    property int  fehlersuchStartId:      -1
    property var  fehlersuchQuerverweise: []    // [{x, y, bezeichnung}]

    signal fehlersuchPfadGefunden(var querverweise)

    function fehlersuchPfadZuruecksetzen() {
        root.fehlersuchPfadIds      = {}
        root.fehlersuchStartId      = -1
        root.fehlersuchQuerverweise = []
        root.fehlersuchPfadGefunden([])
        drawCanvas.requestPaint()
    }

    function fehlersuchPfadBerechnen(startElementId) {
        var elems = elementeModel.snapshot()

        // Snapshot-Index für startElementId ermitteln
        var startIdx = -1
        for (var _ii = 0; _ii < elems.length; _ii++) {
            if ((elems[_ii].id || 0) === startElementId) { startIdx = _ii; break }
        }
        if (startIdx < 0) { fehlersuchPfadZuruecksetzen(); return }

        // Verbindungsgraph – dieselbe Quelle wie autoNetzeBerechnen
        var vbs = symbolDefinitionModel.autoVerbindungenBerechnen(
            elems, root.gridPx, root.normblattDaten || {}
        )

        // ── KLEMME-NET-01: gleiche Injektion wie in autoNetzeBerechnen ────────
        var _kGruppen = {}, _kElMap = {}
        for (var _ki = 0; _ki < elems.length; _ki++) {
            var _kel = elems[_ki]
            if (!_kel || _kel.typ !== "symbol" || _kel.symbolId !== "klemme_anschluss") continue
            var _ked = _kel.extraDaten || {}
            var _kId = _ked.klemmeId || 0
            if (_kId <= 0) continue
            var _bez = _ked.anschlussBezeichnung || ""
            var _ebe = (_bez === "PE" || _bez === "") ? _bez : _bez.split(".")[0]
            if (!_ebe) continue
            if (!_kElMap[_kId]) _kElMap[_kId] = []
            _kElMap[_kId].push({ elIdx: _ki, ebene: _ebe })
            var _gKey = _kId + ":" + _ebe
            if (!_kGruppen[_gKey]) _kGruppen[_gKey] = []
            _kGruppen[_gKey].push(_ki)
        }
        var _addLog = function(idxA, idxB) {
            var _eA = elems[idxA], _eB = elems[idxB]
            vbs.push({ elIdxA: idxA, elIdxB: idxB,
                       x1: (_eA.x1+_eA.x2)/2, y1: (_eA.y1+_eA.y2)/2,
                       x2: (_eB.x1+_eB.x2)/2, y2: (_eB.y1+_eB.y2)/2,
                       rolleA: "durchleiter", rolleB: "durchleiter",
                       quellSigA: "neutral", quellSigB: "neutral",
                       signaltyp: "neutral", logisch: true })
        }
        for (var _gk in _kGruppen) {
            var _grp = _kGruppen[_gk]
            for (var _gi = 1; _gi < _grp.length; _gi++) _addLog(_grp[0], _grp[_gi])
        }
        if (root.projektId >= 0) {
            var _stege = db.klemmenStegbrueckenGruppen(root.projektId)
            for (var _si = 0; _si < _stege.length; _si++) {
                var _steg = _stege[_si], _sEbe = String(_steg.ebene), _sIdxs = []
                for (var _ski = 0; _ski < _steg.klemmeIds.length; _ski++) {
                    var _ents = _kElMap[_steg.klemmeIds[_ski]] || []
                    for (var _ei = 0; _ei < _ents.length; _ei++)
                        if (String(_ents[_ei].ebene) === _sEbe) _sIdxs.push(_ents[_ei].elIdx)
                }
                for (var _sii = 1; _sii < _sIdxs.length; _sii++) _addLog(_sIdxs[0], _sIdxs[_sii])
            }
        }
        // ─────────────────────────────────────────────────────────────────────

        // Adjazenzliste (Snapshot-Index → [Snapshot-Index])
        var adj = {}
        for (var _vi = 0; _vi < vbs.length; _vi++) {
            var _vb = vbs[_vi]
            var _a = _vb.elIdxA, _b = _vb.elIdxB
            if (!adj[_a]) adj[_a] = []
            if (!adj[_b]) adj[_b] = []
            adj[_a].push(_b)
            adj[_b].push(_a)
        }

        // BFS ab Startindex
        var pfadIds = {}, besucht = {}, queue = [startIdx], querv = []
        besucht[startIdx] = true
        pfadIds[elems[startIdx].id] = true

        while (queue.length > 0) {
            var curIdx = queue.shift()
            var nachbarn = adj[curIdx] || []
            for (var _ni = 0; _ni < nachbarn.length; _ni++) {
                var nbIdx = nachbarn[_ni]
                if (besucht[nbIdx]) continue
                besucht[nbIdx] = true
                var nb = elems[nbIdx]
                pfadIds[nb.id] = true

                if (nb.typ === "symbol") {
                    var _sid = nb.symbolId || ""
                    if (_sid === "querverweis") {
                        var _ed = nb.extraDaten || {}
                        var _z  = db.fehlersuchQuerverweisZiel(root.seiteId, nb.id || -1)
                        querv.push({ x: (nb.x1+nb.x2)/2, y: (nb.y1+nb.y2)/2,
                                     bezeichnung: _ed.signalname || "",
                                     nachSeiteId: _z.nachSeiteId !== undefined ? _z.nachSeiteId : -1,
                                     zielX: _z.zielX || 0, zielY: _z.zielY || 0 })
                        // Querverweis: nicht weiterverfolgen
                    } else {
                        var _rolle = symbolDefinitionModel.rolleForSymbol(_sid)
                        if (_rolle !== "verbraucher" && _rolle !== "trenner")
                            queue.push(nbIdx)
                        // verbraucher/trenner: im Pfad, aber nicht weiterverfolgen
                    }
                } else {
                    queue.push(nbIdx)
                }
            }
        }

        root.fehlersuchPfadIds      = pfadIds
        root.fehlersuchStartId      = startElementId
        root.fehlersuchQuerverweise = querv
        root.fehlersuchPfadGefunden(querv)
        drawCanvas.requestPaint()
    }

    function zentriereAuf(wx, wy) {
        root.worldX = wx - (drawCanvas.width  / (2 * root.zoom * root.mmToPx))
        root.worldY = wy - (drawCanvas.height / (2 * root.zoom * root.mmToPx))
        drawCanvas.requestPaint()
    }

    function neuZeichnen() { drawCanvas.requestPaint() }

    // Brücken-Funktionen für CanvasInteraktionArea
    function verbindungBeiPosition(x, y)   { return drawCanvas.verbindungBeiPosition(x, y) }
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
            while (step < 10)  step *= 2
            while (step > 120) step /= 2
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

    // --------------------------------------------------------
    // Zeichenebene
    // --------------------------------------------------------
    Canvas {
        id: drawCanvas
        anchors.fill: parent
        visible: root.seiteId >= 0

        // Wenn ein Bild asynchron fertig geladen ist → neu zeichnen
        onImageLoaded: drawCanvas.requestPaint()

        Connections {
            target: elementeModel
            function onGeaendert() { drawCanvas.requestPaint() }
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
                var a = nd.anlageKuerzel || "", o = nd.ortKuerzel || "", bn = nd.blattnummer || ""
                var kz = ""
                if (a) kz += "=" + a
                if (o) kz += "+" + o
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
        function drawByPrimitiv(ctx, symbolId, w, h) {
            var prims = symbolDefinitionModel.primitiveFuerSymbol(symbolId)
            for (var i = 0; i < prims.length; i++) {
                var p = prims[i]

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
            ctx.setLineDash([])
        }

        function maleElement(ctx, el, idx) {
            var vorschau = (idx < 0)
            var gewaehlt = (!vorschau && root.auswahl.indexOf(idx) >= 0)

            // ── Fehlersuchmodus: Dimm-Faktor ─────────────────────
            var dimFaktor = 1.0
            if (!vorschau && root.fehlersuchModus) {
                var pfadKeys = Object.keys(root.fehlersuchPfadIds)
                if (pfadKeys.length > 0) {
                    if (root.fehlersuchPfadIds[(el.id || -1)]) {
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
            if (!vorschau && root.fehlersuchModus && root.fehlersuchPfadIds[(el.id || -1)] &&
                    (el.typ === "linie" || el.typ === "polygonlinie")) {
                sf = root.theme.accent
                sb = sb + 0.8
            }

            var vx1 = el.x1 * root.zoom + root.worldX
            var vy1 = el.y1 * root.zoom + root.worldY
            var vx2 = el.x2 * root.zoom + root.worldX
            var vy2 = el.y2 * root.zoom + root.worldY

            ctx.globalAlpha = vorschau ? 0.55 : op

            var lw = gewaehlt ? sb + 0.5 : sb
            if (vorschau)           { ctx.setLineDash([5,4]);              ctx.lineCap = "butt"  }
            else if (sa==="gestrichelt") { ctx.setLineDash([lw*5,lw*3]);   ctx.lineCap = "butt"  }
            else if (sa==="gepunktet")   { ctx.setLineDash([0.1,lw*3]);    ctx.lineCap = "round" }
            else                    { ctx.setLineDash([]);                 ctx.lineCap = "butt"  }

            ctx.lineWidth   = lw
            ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)

            if (el.typ === "linie") {
                ctx.beginPath(); ctx.moveTo(vx1,vy1); ctx.lineTo(vx2,vy2); ctx.stroke()
            } else if (el.typ === "kabellinie") {
                // Kabeldefinitionslinie: dicke, orange gestrichelte Linie mit Pfeilspitzen
                var klColor = gewaehlt ? "#f0a030" : (vorschau ? "#4a9effaa" : (el.strichFarbe || "#e07000"))
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
                    if (klZeilen.length > 0) {
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
                        ctx.strokeStyle  = "#000000"
                        ctx.lineWidth    = 3
                        ctx.lineJoin     = "round"
                        ctx.textAlign    = klNxL >= 0 ? "left" : "right"
                        ctx.textBaseline = "bottom"
                        var klY = klAY
                        for (var kzI = klZeilen.length - 1; kzI >= 0; kzI--) {
                            ctx.font = (klZeilen[kzI].bold ? "bold " : "") + klFs + "px sans-serif"
                            ctx.strokeText(klZeilen[kzI].text, klAX, klY)
                            ctx.fillStyle = (klZeilen[kzI].bold && !gewaehlt) ? klColor : (gewaehlt ? "#f0a030" : "#c0d8f0")
                            ctx.fillText(klZeilen[kzI].text, klAX, klY)
                            klY -= klLH
                        }
                    }
                }
                ctx.restore()
            } else if (el.typ === "polygonlinie") {
                var plPts = el.punkte || []
                if (plPts.length >= 2) {
                    ctx.beginPath()
                    ctx.moveTo(plPts[0].x * root.zoom + root.worldX, plPts[0].y * root.zoom + root.worldY)
                    for (var plI = 1; plI < plPts.length; plI++)
                        ctx.lineTo(plPts[plI].x * root.zoom + root.worldX, plPts[plI].y * root.zoom + root.worldY)
                    ctx.stroke()
                }
            } else if (el.typ === "rechteck") {
                var rr = er * root.mmToPx * root.zoom
                if (fu && !vorschau) {
                    ctx.fillStyle = ff; ctx.globalAlpha = fo
                    if (rr>0.5) { drawCanvas.roundRect(ctx,vx1,vy1,vx2-vx1,vy2-vy1,rr); ctx.fill() }
                    else          ctx.fillRect(vx1,vy1,vx2-vx1,vy2-vy1)
                    ctx.globalAlpha = op
                }
                ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
                if (rr>0.5) { drawCanvas.roundRect(ctx,vx1,vy1,vx2-vx1,vy2-vy1,rr); ctx.stroke() }
                else          ctx.strokeRect(vx1,vy1,vx2-vx1,vy2-vy1)
            } else if (el.typ === "kreis") {
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
            } else if (el.typ === "text") {
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
                        txtFsPx = (el.strichBreite || 3.5) * root.mmToPx * root.zoom
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
                    for (var li2 = 0; li2 < txtLines.length; li2++)
                        ctx.fillText(txtLines[li2], 0, li2 * txtLineH)
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
            } else if (el.typ === "bild") {
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
            } else if (el.typ === "notiz") {
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
                    if (nText !== "") {
                        var nFsPx  = (el.strichBreite || 3.5) * root.mmToPx * root.zoom
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
            } else if (el.typ === "symbol") {
                var sw = vx2 - vx1, sh = vy2 - vy1
                if (Math.abs(sw) > 0.5 && Math.abs(sh) > 0.5) {
                    var scx = vx1 + sw/2, scy = vy1 + sh/2
                    var rot = (el.rotation || 0) * Math.PI / 180

                    ctx.save()
                    ctx.translate(scx, scy)
                    if (rot !== 0) ctx.rotate(rot)
                    if (el.spiegelX) ctx.scale(-1, 1)
                    if (el.spiegelY) ctx.scale(1, -1)
                    ctx.translate(-Math.abs(sw)/2, -Math.abs(sh)/2)
                    drawCanvas.drawByPrimitiv(ctx, el.symbolId || "", Math.abs(sw), Math.abs(sh))
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
                            ctx.beginPath(); ctx.arc(pp.x, pp.y, pr, 0, 2 * Math.PI)
                            ctx.fillStyle   = gewaehlt ? "#00e5a0" : "#4a9eff"
                            ctx.strokeStyle = gewaehlt ? "#004d35" : "#0a2040"
                            ctx.lineWidth   = 1.0
                            ctx.fill(); ctx.stroke()
                        }
                        ctx.globalAlpha = op
                    }

                    // BMK-Label und Freitexte am Symbol rendern (konzeptgemäß, Abschnitt 7).
                    // Text ist immer waagerecht.
                    // 0°/180° → über dem Symbol  (Anker: Oberkante, Mitte X)
                    // 90°/270° → links neben dem Symbol (Anker: linke Kante, Mitte Y)
                    // Verbindungshelfer erhalten keine Beschriftung.
                    if (!vorschau) {
                        var bmkSid = el.symbolId || ""
                        var verbHelper = bmkSid === "winkel" || bmkSid === "treffpunkt" || bmkSid === "treffpunkt_l"
                                      || bmkSid === "geraeteanschluss" || bmkSid === "unterbrechung"
                                      || bmkSid === "querverweis"     || bmkSid === "aderdefinition"
                                      || bmkSid === "klemme_anschluss"
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
                                var senkrecht = (symRot === 90 || symRot === 270)
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

                    // ── Fehlersuch-Startpunkt-Marker ─────────────────────
                    if (!vorschau && root.fehlersuchModus &&
                            (el.id || -1) === root.fehlersuchStartId) {
                        var _fsR  = Math.max(4, 4 * root.zoom)
                        var _fsCx = (vx1 + vx2) / 2
                        var _fsCy = (vy1 + vy2) / 2
                        ctx.save()
                        ctx.globalAlpha = 0.85
                        ctx.beginPath()
                        ctx.arc(_fsCx, _fsCy, _fsR, 0, Math.PI * 2)
                        ctx.strokeStyle = root.theme.accent
                        ctx.lineWidth   = 2.5
                        ctx.stroke()
                        ctx.restore()
                    }

                    // ── HF-Querverweis-Hinweis (Kontaktspiegel) ──────────
                    // Erscheint nur bei Nebenfunktionen auf einer anderen Seite
                    // als die Hauptfunktion.
                    if (!vorschau && !verbHelper && (el.betriebsmittelId || 0) > 0) {
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
                    if (!vorschau && el.symbolId === "querverweis") {
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
                    if (!vorschau && el.symbolId === "geraeteanschluss") {
                        var gaed  = el.extraDaten || {}
                        var gaAnk = gaed.anschlusskennzeichnung || ""
                        if (gaAnk !== "") {
                            // Umschließenden Gerätekasten suchen (kleinster)
                            var gaCxF = (el.x1 + el.x2) / 2, gaCyF = (el.y1 + el.y2) / 2
                            var bestGk = null, bestGkA = Infinity
                            var _gaEls = elementeModel.snapshot()
                            for (var gi = 0; gi < _gaEls.length; gi++) {
                                var gke = _gaEls[gi]
                                if (gke.typ !== "geraetekasten") continue
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

                            var gaFs  = Math.max(7, Math.round(2.0 * root.mmToPx * root.zoom))
                            var gaRot = ((el.rotation || 0) % 360 + 360) % 360
                            var gaSenk = (gaRot === 90 || gaRot === 270)
                            var gaCx  = (vx1 + vx2) / 2
                            var gaCy  = (vy1 + vy2) / 2
                            ctx.save()
                            ctx.globalAlpha = 1.0
                            ctx.font = "bold " + gaFs + "px sans-serif"
                            ctx.strokeStyle = "#000000"; ctx.lineWidth = 3; ctx.lineJoin = "round"
                            if (gaSenk) {
                                ctx.textAlign = "left"; ctx.textBaseline = "middle"
                                var gaX = Math.max(vx1, vx2) + 4 * root.zoom
                                ctx.strokeText(gaLabel, gaX, gaCy)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#c0d8f0"
                                ctx.fillText(gaLabel, gaX, gaCy)
                            } else {
                                ctx.textAlign = "center"; ctx.textBaseline = "top"
                                var gaY = Math.max(vy1, vy2) + 3 * root.zoom
                                ctx.strokeText(gaLabel, gaCx, gaY)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#c0d8f0"
                                ctx.fillText(gaLabel, gaCx, gaY)
                            }
                            ctx.restore()
                        }
                    }

                    // Klemmen-Anschluss: Bezeichnung + BMK neben dem Symbol (draggable via bmkOffsetX/Y)
                    if (!vorschau && el.symbolId === "klemme_anschluss") {
                        var kaed    = el.extraDaten || {}
                        var kaAnz   = kaed.anschlussBezeichnung || ""
                        var kaBmk   = kaed.bmk || ""
                        var kaBmkVis = kaBmk !== "" && kaed.bmkSichtbar !== false
                        var kaFs    = Math.max(7, Math.round(2.0 * root.mmToPx * root.zoom))
                        var kaBmkFs = Math.max(6, Math.round(1.5 * root.mmToPx * root.zoom))
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
                        ctx.strokeStyle = "#000000"; ctx.lineWidth = 3; ctx.lineJoin = "round"
                        if (kaSenk) {
                            var kaPinRechts = (kaRot === 90)
                            var kaX   = kaPinRechts
                                        ? Math.min(vx1, vx2) - 4 * root.zoom + kaOy
                                        : Math.max(vx1, vx2) + 4 * root.zoom + kaOy
                            var kaAlg = kaPinRechts ? "right" : "left"
                            var kaCyO = kaCy + kaOx
                            if (kaAnz !== "") {
                                ctx.font = "bold " + kaFs + "px sans-serif"
                                ctx.textAlign = kaAlg; ctx.textBaseline = "middle"
                                var kaAy = kaBmkVis ? kaCyO - kaBmkFs * 0.6 : kaCyO
                                ctx.strokeText(kaAnz, kaX, kaAy)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#90e0a0"
                                ctx.fillText(kaAnz, kaX, kaAy)
                            }
                            if (kaBmkVis) {
                                ctx.font = kaBmkFs + "px sans-serif"
                                ctx.textAlign = kaAlg; ctx.textBaseline = "middle"
                                var kaBmkY = kaAnz !== "" ? kaCyO + kaBmkFs * 0.8 : kaCyO
                                ctx.strokeText(kaBmk, kaX, kaBmkY)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#a0c0e0"
                                ctx.fillText(kaBmk, kaX, kaBmkY)
                            }
                        } else {
                            var kaPinUnten = (kaRot === 180)
                            var kaY   = kaPinUnten
                                        ? Math.min(vy1, vy2) - 3 * root.zoom + kaOy
                                        : Math.max(vy1, vy2) + 3 * root.zoom + kaOy
                            var kaBl  = kaPinUnten ? "bottom" : "top"
                            var kaCxO = kaCx + kaOx
                            if (kaAnz !== "") {
                                ctx.font = "bold " + kaFs + "px sans-serif"
                                ctx.textAlign = "center"; ctx.textBaseline = kaBl
                                ctx.strokeText(kaAnz, kaCxO, kaY)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#90e0a0"
                                ctx.fillText(kaAnz, kaCxO, kaY)
                            }
                            if (kaBmkVis) {
                                ctx.font = kaBmkFs + "px sans-serif"
                                ctx.textAlign = "center"; ctx.textBaseline = kaBl
                                var kaBmkYh = kaPinUnten ? kaY - kaFs - 1 : kaY + kaFs + 1
                                ctx.strokeText(kaBmk, kaCxO, kaBmkYh)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#a0c0e0"
                                ctx.fillText(kaBmk, kaCxO, kaBmkYh)
                            }
                        }
                        ctx.restore()
                    }

                    // Aderdefinitionspunkt: Textblock – Positionierung wie BMK an Symbolen
                    // 0° (waagerecht): Text über dem Symbol | 90° (senkrecht): Text links
                    if (!vorschau && el.symbolId === "aderdefinition") {
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
                            var adpTextFarbe = gewaehlt ? "#f0a030" : "#c0d8f0"
                            if (adpSenk) {
                                // Senkrecht: Text links, vertikal zentriert
                                var adpLx = Math.min(vx1, vx2) - 4 * root.zoom
                                var adpLy = adpCy - adpZeilen.length * adpLineH / 2
                                ctx.textAlign = "right"; ctx.textBaseline = "top"
                                for (var az1 = 0; az1 < adpZeilen.length; az1++) {
                                    ctx.font = (adpZeilen[az1].bold ? "bold " : "") + adpFs + "px sans-serif"
                                    ctx.strokeStyle = "#000000"; ctx.lineWidth = 3; ctx.lineJoin = "round"
                                    ctx.strokeText(adpZeilen[az1].text, adpLx, adpLy + az1 * adpLineH)
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
                                    ctx.strokeStyle = "#000000"; ctx.lineWidth = 3; ctx.lineJoin = "round"
                                    ctx.strokeText(adpZeilen[az2].text, adpOx, adpOy)
                                    ctx.fillStyle = adpTextFarbe
                                    ctx.fillText(adpZeilen[az2].text, adpOx, adpOy)
                                    adpOy -= adpLineH
                                }
                            }
                            ctx.restore()
                        }
                    }
                }
            } else if (el.typ === "geraetekasten") {
                // Gerätekasten: abgerundetes Rechteck mit leichter Füllung und Label oben links
                ctx.setLineDash([])
                ctx.lineCap = "butt"
                var gkRx = Math.min(vx1, vx2), gkRy = Math.min(vy1, vy2)
                var gkRw = Math.abs(vx2 - vx1), gkRh = Math.abs(vy2 - vy1)
                var gkR  = 4 * root.zoom
                if (fu && !vorschau) {
                    ctx.fillStyle  = ff
                    ctx.globalAlpha = op * fo
                    drawCanvas.roundRect(ctx, gkRx, gkRy, gkRw, gkRh, gkR)
                    ctx.fill()
                    ctx.globalAlpha = op
                }
                ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
                drawCanvas.roundRect(ctx, gkRx, gkRy, gkRw, gkRh, gkR)
                ctx.stroke()
                if (!vorschau && gkRw > 20 && gkRh > 12) {
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
                        ctx.textAlign    = "left"
                        ctx.textBaseline = "top"
                        ctx.fillStyle    = gewaehlt ? "#f0a030" : sf
                        ctx.globalAlpha  = op
                        var gkTy = gkRy + gkPad
                        if (gkBmk !== "") {
                            ctx.font = "bold " + gkFs + "px sans-serif"
                            ctx.fillText(gkBmk, gkRx + gkPad, gkTy)
                            gkTy += gkFs * 1.3
                        }
                        if (gkBez !== "") {
                            ctx.font = gkFsB + "px sans-serif"
                            ctx.fillText(gkBez, gkRx + gkPad, gkTy)
                        }
                        ctx.restore()
                    }
                }
            } else if (el.typ === "strukturkasten") {
                // Strukturkasten: gestricheltes Rechteck mit Anlage/Ort-Label oben rechts
                var skRx = Math.min(vx1, vx2), skRy = Math.min(vy1, vy2)
                var skRw = Math.abs(vx2 - vx1), skRh = Math.abs(vy2 - vy1)
                ctx.setLineDash([8 * root.zoom, 5 * root.zoom])
                ctx.lineCap    = "butt"
                ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
                ctx.strokeRect(skRx, skRy, skRw, skRh)
                if (!vorschau && skRw > 20) {
                    var skEd  = el.extraDaten || {}
                    var skAnl = skEd.anlage      || ""
                    var skOrt = skEd.ort         || ""
                    var skAUO = skEd.anlageUO    || ""
                    var skOUO = skEd.ortUO       || ""
                    var skBez = skEd.bezeichnung || ""
                    ctx.save()
                    ctx.setLineDash([])
                    var skSch = (skEd.schriftgroesse !== undefined ? skEd.schriftgroesse : 2.5)
                    var skFs  = Math.max(5, Math.round(skSch * root.mmToPx * root.zoom))
                    ctx.font        = "bold " + skFs + "px sans-serif"
                    ctx.textBaseline = "top"
                    ctx.fillStyle   = gewaehlt ? "#f0a030" : sf
                    ctx.globalAlpha = op
                    var skOff = Math.round(4 * root.zoom)
                    // Anlage/Ort-Label oben rechts
                    var skLbl = ""
                    if (skAUO) skLbl += "==" + skAUO + " "
                    if (skOUO) skLbl += "++" + skOUO + " "
                    if (skAnl) skLbl += "="  + skAnl + " "
                    if (skOrt) skLbl += "+"  + skOrt
                    if (skLbl !== "") {
                        ctx.textAlign = "right"
                        ctx.fillText(skLbl.trim(), skRx + skRw - Math.round(5 * root.zoom), skRy + skOff)
                    }
                    // Bezeichnung oben links
                    if (skBez !== "") {
                        ctx.textAlign = "left"
                        ctx.font      = skFs + "px sans-serif"
                        ctx.fillText(skBez, skRx + Math.round(5 * root.zoom), skRy + skOff)
                    }
                    ctx.restore()
                }
            } else if (el.typ === "makrokasten") {
                // Makrokasten: violett gestrichelt, Label oben-mitte
                var mkRx = Math.min(vx1, vx2), mkRy = Math.min(vy1, vy2)
                var mkRw = Math.abs(vx2 - vx1), mkRh = Math.abs(vy2 - vy1)
                var mkEd   = el.extraDaten || {}
                var mkSaved = mkEd.makroId > 0
                ctx.setLineDash([6 * root.zoom, 4 * root.zoom])
                ctx.lineCap     = "butt"
                ctx.lineWidth   = mkSaved ? 1.5 : 1.0
                ctx.strokeStyle = gewaehlt ? "#f0a030" : "#aa44cc"
                ctx.strokeRect(mkRx, mkRy, mkRw, mkRh)
                if (!vorschau && mkRw > 20) {
                    ctx.save()
                    ctx.setLineDash([])
                    var mkFs = Math.max(5, Math.round(2.2 * root.mmToPx * root.zoom))
                    ctx.font        = mkFs + "px sans-serif"
                    ctx.textBaseline = "top"
                    ctx.textAlign    = "center"
                    ctx.fillStyle   = gewaehlt ? "#f0a030" : "#aa44cc"
                    ctx.globalAlpha = op
                    var mkPfx  = mkSaved ? "✓ " : "⬜ "
                    var mkName = mkEd.name || qsTr("Makro")
                    ctx.fillText(mkPfx + mkName, mkRx + mkRw / 2, mkRy + Math.round(4 * root.zoom))
                    ctx.restore()
                }
            }

            ctx.setLineDash([]); ctx.lineCap="butt"; ctx.globalAlpha=1.0

            if (!vorschau && el.typ !== "symbol" && el.typ !== "polygonlinie"
                         && el.typ !== "rechteck" && el.typ !== "geraetekasten"
                         && el.typ !== "strukturkasten" && el.typ !== "makrokasten"
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
            if (root.debug && !vorschau) {
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
                    || el.typ==="makrokasten" || el.typ==="bild" || el.typ==="notiz")
                return [Qt.point(el.x1,el.y1), Qt.point(el.x2,el.y1),
                        Qt.point(el.x2,el.y2), Qt.point(el.x1,el.y2)]
            if (el.typ==="kreis")    return [Qt.point(el.x1,el.y1), Qt.point(el.x2,el.y2)]
            if (el.typ==="symbol") return []  // Größe ist DB-definiert, kein Resize
            return []
        }


        // Gibt Farbe für einen Signaltyp zurück
        function signaltypFarbe(sig) {
            if (sig === "power")           return "#cc3300"
            if (sig === "pe")              return "#88cc00"
            if (sig === "n")               return "#4488ff"
            if (sig === "input_digital")   return "#44aaff"
            if (sig === "output_digital")  return "#44cc66"
            if (sig === "input_analog")    return "#88bbff"
            if (sig === "output_analog")   return "#66ddaa"
            if (sig === "kommunikation")   return "#aa44cc"
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


        // Gruppiert Auto-Verbindungssegmente zu elektrischen Netzen.
        // Gibt [{netKey, bezeichnung, signaltyp, farbe, querschnitt,
        //        verbindungId, segmente:[{x1,y1,x2,y2}], querverweise:[...]}] zurück.
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
                net.netKey = pins.join("|")
                delete net.pinSet
                var ann = root.verbindungAnnotationenCache[net.netKey] || {}
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
            var schnitte = kabelSchnittNetzeBerechnen(el, netze)
            if (schnitte.length === 0) return

            var klAdern       = (el.extraDaten && Array.isArray(el.extraDaten.adern))
                                ? el.extraDaten.adern : []
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

                // Ader-Label: aderZuordnung (netKey→aderNr) hat Vorrang, sonst positionsbasiert
                var aderNr = sci + 1
                if (aderZuordnung && sc.netKey && aderZuordnung[sc.netKey] !== undefined)
                    aderNr = aderZuordnung[sc.netKey]
                var labelText = "" + aderNr
                // Farbe aus klAdern holen (Suche nach aderNr)
                for (var ai = 0; ai < klAdern.length; ai++) {
                    var klAd = klAdern[ai]
                    if ((klAd.aderNr !== undefined ? klAd.aderNr : (ai + 1)) === aderNr && klAd.farbe) {
                        labelText += "  " + klAd.farbe
                        break
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
                ctx.strokeStyle = "#000000"; ctx.lineWidth = 2.5; ctx.lineJoin = "round"
                ctx.strokeText(labelText, lx, ly)
                ctx.fillStyle = klColor
                ctx.fillText(labelText, lx, ly)
            }
            ctx.restore()
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

        function maleAutoVerbindungen(ctx) {
            var netze = drawCanvas.autoNetzeBerechnen()
            if (netze.length === 0) return

            var _fsPfadKeys = Object.keys(root.fehlersuchPfadIds)
            var _fsAktiv    = root.fehlersuchModus && _fsPfadKeys.length > 0

            var kreuzungsLuecken = drawCanvas._kreuzungsLuecken(netze)
            if (root.debug) {
                var _nKreuz = Object.keys(kreuzungsLuecken).length
                if (_nKreuz > 0)
                    console.log("[CANVAS-CROSS] " + _nKreuz + " Kreuzung(en) erkannt:", JSON.stringify(kreuzungsLuecken))
                else
                    console.log("[CANVAS-CROSS] Keine Kreuzungen erkannt. Netze:", netze.length)
            }

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
                        var _imPfad = !!(root.fehlersuchPfadIds[(_eA.id || -1)]
                                      && root.fehlersuchPfadIds[(_eB.id || -1)])
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

                    if (sAdps.length >= 4) {
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
            for (var i=0; i<elemente.length; i++)
                drawCanvas.maleElement(ctx, elemente[i], i)
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
            drawCanvas.maleAutoVerbindungen(ctx)
            // Schnittpunkte aller Kabellinien mit Auto-Verbindungen (Phase 5)
            var kabelNetze = drawCanvas.autoNetzeBerechnen()
            for (var kli = 0; kli < elemente.length; kli++) {
                if (elemente[kli].typ === "kabellinie")
                    drawCanvas.maleKabelSchnitte(ctx, elemente[kli], kabelNetze)
            }
            // Rubber-Band Auswahlrahmen
            if (root.amRubberband && root.rubberbandRect) {
                var rb = root.rubberbandRect
                var rx = Math.min(rb.x1, rb.x2), ry = Math.min(rb.y1, rb.y2)
                var rw = Math.abs(rb.x2 - rb.x1), rh = Math.abs(rb.y2 - rb.y1)
                ctx.save()
                ctx.setLineDash([4, 3])
                ctx.strokeStyle = "#4a9eff"; ctx.lineWidth = 1
                ctx.fillStyle   = "rgba(74, 158, 255, 0.07)"
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
        drcAktiv: root.drcAktiv
        onDrcKlick: root.drcKlick()
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

    // ── M11: Verdrahtungsweg-Algorithmus (Stufe 2) ──────────────
    // Berechnet Von/Nach-Gerät:Pin für alle kabel_adern dieses Projekts,
    // deren Kabellinie auf der aktuellen Seite liegt.
    // Stufe 2: per-Ader-Traversal mit Treffpunkt-Routing.
    function verdrahtungswegeAktualisieren() {
        if (root.projektId < 0 || root.seiteId < 0) return
        var adern = db.kabelAderListeMitVerbindung(root.projektId)
        if (!adern || adern.length === 0) return

        var netze = drawCanvas.autoNetzeBerechnen()
        // verbindungId → net
        var verbNetMap = {}
        for (var ni = 0; ni < netze.length; ni++) {
            var n = netze[ni]
            if ((n.verbindungId || 0) > 0) verbNetMap[n.verbindungId] = n
        }

        // grafik_element.id → Elementindex in elementeModel
        var _verEls = elementeModel.snapshot()
        var idxByGeid = {}
        for (var ei = 0; ei < _verEls.length; ei++)
            if (_verEls[ei].id > 0) idxByGeid[_verEls[ei].id] = ei

        var ergebnisse = []
        for (var ai = 0; ai < adern.length; ai++) {
            var ad = adern[ai]
            var vId  = ad.verbindungId || 0
            var geid = ad.kabellinieGrafikElementId || 0

            // Nur Adern, deren Kabellinie auf dieser Seite liegt
            if (geid <= 0 || idxByGeid[geid] === undefined) continue

            var net = verbNetMap[vId]
            var res = net ? _endpunkteFuerAder(net, idxByGeid[geid])
                          : {von: "", nach: ""}
            ergebnisse.push({kabelId: ad.kabelId, aderNr: ad.aderNr,
                             von: res.von, nach: res.nach})
        }

        if (ergebnisse.length > 0)
            db.kabelAderEndpunkteBulkSetzen(root.projektId, ergebnisse)
    }

    // Per-Ader-Traversal: Startet am Kreuzungspunkt der Kabellinie mit dem Net
    // und traversiert in beide Richtungen zum Endpunkt.
    function _endpunkteFuerAder(net, kabellinieElIdx) {
        // Adjazenz mit Pin-Positionen aufbauen:
        // adj[elIdx] = [{neighbor, connPosOnSelf}]
        // connPosOnSelf = Weltpos. des eigenen Pins, der zu diesem Nachbar führt
        var adj = {}
        for (var si = 0; si < net.segmente.length; si++) {
            var seg = net.segmente[si]
            if (seg.logisch) continue
            var a = seg.elIdxA, b = seg.elIdxB
            if (!adj[a]) adj[a] = []
            if (!adj[b]) adj[b] = []
            adj[a].push({neighbor: b, connPosOnSelf: {x: seg.x1, y: seg.y1}})
            adj[b].push({neighbor: a, connPosOnSelf: {x: seg.x2, y: seg.y2}})
        }

        // Gekreuztes Segment bestimmen
        var crossed = _netSegmentKreuzungBerechnen(elementeModel.element(kabellinieElIdx), net)
        if (!crossed) {
            // Kein geometrischer Schnittpunkt – Fallback: einfache Endpunktsuche
            return _endpunkteFuerNetFallback(net, adj)
        }

        var von  = _traversiereEndpunkt(crossed.elIdxA, crossed.elIdxB, adj, net, 60)
        var nach = _traversiereEndpunkt(crossed.elIdxB, crossed.elIdxA, adj, net, 60)
        return {von: von, nach: nach}
    }

    // Findet das erste Segment des Nets, das die Kabellinie kreuzt.
    // Rückgabe: {elIdxA, elIdxB, x1, y1, x2, y2} oder null.
    function _netSegmentKreuzungBerechnen(kabelEl, net) {
        if (!kabelEl) return null
        var kx1 = kabelEl.x1, ky1 = kabelEl.y1
        var kdx = kabelEl.x2 - kx1, kdy = kabelEl.y2 - ky1
        if (kdx * kdx + kdy * kdy < 0.25) return null

        for (var si = 0; si < net.segmente.length; si++) {
            var seg = net.segmente[si]
            if (seg.logisch) continue
            var dax = seg.x2 - seg.x1, day = seg.y2 - seg.y1
            var D = kdx * day - kdy * dax
            if (Math.abs(D) < 0.001) continue
            var t = ((seg.x1 - kx1) * day - (seg.y1 - ky1) * dax) / D
            var s = ((seg.x1 - kx1) * kdy - (seg.y1 - ky1) * kdx) / D
            if (t >= -0.01 && t <= 1.01 && s >= -0.01 && s <= 1.01)
                return seg
        }
        return null
    }

    // Fallback: einfache Endpunktsuche wenn kein Schnittpunkt gefunden.
    function _endpunkteFuerNetFallback(net, adj) {
        var endpoints = []
        for (var idxStr in adj) {
            var el = elementeModel.element(parseInt(idxStr))
            if (!el || !el.typ) continue
            var sid = el.symbolId || ""
            if (sid === "geraeteanschluss" || sid === "potenzial" ||
                sid === "klemme_anschluss" || sid === "isoliert_gelegte_ader")
                endpoints.push(el)
        }
        var hatQv = net.segmente.some(function(s) { return s.logisch })
        var von  = endpoints.length >= 1 ? _formatEndpunkt(endpoints[0], net) : "⚠ Kein Endpunkt"
        var nach = endpoints.length >= 2 ? _formatEndpunkt(endpoints[1], net)
                 : (hatQv ? "→ Querverweis" : "⚠ Kein Endpunkt")
        return {von: von, nach: nach}
    }

    // Gerichtete DFS-Traversal: startet bei startElIdx (aus Richtung vonElIdx).
    // Liefert den formatierten Endpunkt-String.
    function _traversiereEndpunkt(startElIdx, vonElIdx, adj, net, tiefe) {
        if (tiefe <= 0) return "⚠ Zyklus"
        var el = elementeModel.element(startElIdx)
        if (!el || !el.typ) return "⚠ Kein Endpunkt"
        var sid = el.symbolId || ""

        // Endpunkt-Symbole: Traversal hält hier
        if (sid === "geraeteanschluss" || sid === "potenzial" ||
            sid === "klemme_anschluss" || sid === "isoliert_gelegte_ader")
            return _formatEndpunkt(el, net)

        // Querverweis: Cross-page traversal (Partnerseite laden und dort weitersuchen)
        if (sid === "querverweis") {
            var partnerInfo = root._querverweisPartnerMap[startElIdx]
            if (!partnerInfo) return "→ Querverweis"
            return _traversiereEndpunktCrossPage(el, partnerInfo, net, tiefe)
        }

        // Treffpunkt: Routing-Regeln anwenden
        if (sid === "treffpunkt" || sid === "treffpunkt_l") {
            // Welchen Arm hat vonElIdx? → connPosOnSelf in adj[startElIdx] für neighbor=vonElIdx
            var adjSelf = adj[startElIdx] || []
            var connPos = null
            for (var ai = 0; ai < adjSelf.length; ai++) {
                if (adjSelf[ai].neighbor === vonElIdx) { connPos = adjSelf[ai].connPosOnSelf; break }
            }
            var vonArm = connPos ? _treffpunktArmBestimmen(el, connPos) : null

            if (vonArm === "s1" || vonArm === "s2") {
                // Ankunft von s-Arm → weiter zum ziel-Arm
                var zielNb = _treffpunktNachbarFuerArm(el, startElIdx, adj, "ziel")
                if (zielNb !== null)
                    return _traversiereEndpunkt(zielNb, startElIdx, adj, net, tiefe - 1)
                return "⚠ Kein Ziel"
            } else if (vonArm === "ziel") {
                // Ankunft vom ziel-Arm → alle s-Arme versuchen, ersten Treffer nehmen
                for (var sArm of ["s1", "s2"]) {
                    var sNb = _treffpunktNachbarFuerArm(el, startElIdx, adj, sArm)
                    if (sNb !== null && sNb !== vonElIdx) {
                        var res = _traversiereEndpunkt(sNb, startElIdx, adj, net, tiefe - 1)
                        if (res.indexOf("⚠") < 0) return res
                    }
                }
                return "⚠ Treffpunkt (ziel)"
            }
            return "⚠ Treffpunkt"
        }

        // Transparente Elemente (winkel, aderdefinition, …): nächsten Nachbar folgen
        var nbList = adj[startElIdx] || []
        for (var ni = 0; ni < nbList.length; ni++) {
            if (nbList[ni].neighbor !== vonElIdx)
                return _traversiereEndpunkt(nbList[ni].neighbor, startElIdx, adj, net, tiefe - 1)
        }
        return "⚠ Kein Endpunkt"
    }

    // Bestimmt welcher Arm (s1/s2/ziel) an connPos ankommt.
    // connPos = Weltpos. des Treffpunkt-Pins der mit dem eingehenden Segment verbunden ist.
    function _treffpunktArmBestimmen(el, connPos) {
        var pins = symbolDefinitionModel.pinsForSymbol(el.symbolId || "")
        var bestArm = null, bestDist = Infinity
        for (var pi = 0; pi < pins.length; pi++) {
            var wp = root.pinWeltPos(el, pins[pi].x, pins[pi].y)
            var dx = wp.x - connPos.x, dy = wp.y - connPos.y
            var d2 = dx * dx + dy * dy
            if (d2 < bestDist) { bestDist = d2; bestArm = pins[pi].name }
        }
        return bestArm
    }

    // Gibt den Nachbar-Elementindex zurück, der am Arm armName des Treffpunkts hängt.
    function _treffpunktNachbarFuerArm(el, trElIdx, adj, armName) {
        var pins = symbolDefinitionModel.pinsForSymbol(el.symbolId || "")
        var armPos = null
        for (var pi = 0; pi < pins.length; pi++) {
            if (pins[pi].name === armName) { armPos = root.pinWeltPos(el, pins[pi].x, pins[pi].y); break }
        }
        if (!armPos) return null
        var entries = adj[trElIdx] || []
        for (var ai = 0; ai < entries.length; ai++) {
            var cp = entries[ai].connPosOnSelf
            var dx = cp.x - armPos.x, dy = cp.y - armPos.y
            if (dx * dx + dy * dy < 0.5) return entries[ai].neighbor
        }
        return null
    }

    // Formatiert den Bezeichner eines Endpunkt-Symbols.
    function _formatEndpunkt(el, net) {
        var sid = el.symbolId || ""
        var ed  = el.extraDaten || {}

        if (sid === "geraeteanschluss") {
            var ank = ed.anschlusskennzeichnung || ""
            var cx  = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
            var bestGk = null, bestGkA = Infinity
            var _fmtEls = elementeModel.snapshot()
            for (var gi = 0; gi < _fmtEls.length; gi++) {
                var gke = _fmtEls[gi]
                if (gke.typ !== "geraetekasten") continue
                var gkx1 = Math.min(gke.x1, gke.x2), gkx2 = Math.max(gke.x1, gke.x2)
                var gky1 = Math.min(gke.y1, gke.y2), gky2 = Math.max(gke.y1, gke.y2)
                if (cx >= gkx1 && cx <= gkx2 && cy >= gky1 && cy <= gky2) {
                    var gkA = (gkx2 - gkx1) * (gky2 - gky1)
                    if (gkA < bestGkA) { bestGkA = gkA; bestGk = gke }
                }
            }
            var bmk = bestGk ? ((bestGk.extraDaten || {}).bmk || "") : ""
            return bmk ? (bmk + ":" + ank) : (ank || "GA")
        }

        if (sid === "potenzial")
            return net.bezeichnung || ed.signalname || "Potenzial"

        if (sid === "klemme_anschluss") {
            var kaAnz = ed.anschlussBezeichnung || ""
            var kaBmk = ed.bmk || ""
            return kaBmk ? (kaBmk + ":" + kaAnz) : (kaAnz || "KA")
        }

        if (sid === "isoliert_gelegte_ader")
            return "isoliert"

        return sid
    }

    // Ermittelt den Signaltyp der Union-Find-Gruppe von elIdx in verbindungen.
    // Wird für den seitenübergreifenden Potenzialimport (KLEMME-NET-01) genutzt.
    function _signaltypInVerbindungen(elIdx, verbindungen) {
        var _sp = {}
        var _sf = function(x) {
            if (_sp[x] === undefined) _sp[x] = x
            while (_sp[x] !== x) { _sp[x] = _sp[_sp[x]]; x = _sp[x] }
            return x
        }
        for (var _si = 0; _si < verbindungen.length; _si++) {
            var _ra = _sf(verbindungen[_si].elIdxA), _rb = _sf(verbindungen[_si].elIdxB)
            if (_ra !== _rb) _sp[_ra] = _rb
        }
        var _ziel = _sf(elIdx)
        for (var _sj = 0; _sj < verbindungen.length; _sj++) {
            var _sv = verbindungen[_sj]
            if (_sf(_sv.elIdxA) === _ziel || _sf(_sv.elIdxB) === _ziel) {
                var _ssig = _sv.signaltyp || "neutral"
                if (_ssig !== "neutral" && _ssig !== "unversorgt") return _ssig
            }
        }
        return "neutral"
    }

    // Baut pin-basierten Adj-Graph aus einem db.grafikLaden()-Ergebnis.
    function _adjFuerElemente(elemente) {
        var posMap = {}
        for (var i = 0; i < elemente.length; i++) {
            var el = elemente[i]
            if (!el || el.typ !== "symbol" || !(el.symbolId || "")) continue
            var pins = symbolDefinitionModel.pinsForSymbol(el.symbolId)
            for (var pi = 0; pi < pins.length; pi++) {
                var wp  = root.pinWeltPos(el, pins[pi].x, pins[pi].y)
                var key = Math.round(wp.x * 2) + "_" + Math.round(wp.y * 2)
                if (!posMap[key]) posMap[key] = []
                posMap[key].push({elIdx: i, connPos: wp})
            }
        }
        var adj = {}
        for (var pkey in posMap) {
            var entries = posMap[pkey]
            if (entries.length < 2) continue
            for (var a = 0; a < entries.length; a++) {
                for (var b = a + 1; b < entries.length; b++) {
                    var ai = entries[a].elIdx, bi = entries[b].elIdx
                    if (!adj[ai]) adj[ai] = []
                    if (!adj[bi]) adj[bi] = []
                    adj[ai].push({neighbor: bi, connPosOnSelf: entries[a].connPos})
                    adj[bi].push({neighbor: ai, connPosOnSelf: entries[b].connPos})
                }
            }
        }
        return adj
    }

    // Formatiert Endpunkt-Symbol auf einer Fremdseite (sucht Gerätekasten in elemente[]).
    function _formatEndpunktInElemente(el, net, elemente) {
        var sid = el.symbolId || ""
        var ed  = el.extraDaten || {}
        if (sid === "geraeteanschluss") {
            var ank = ed.anschlusskennzeichnung || ""
            var cx  = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
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
            return bmk ? (bmk + ":" + ank) : (ank || "GA")
        }
        if (sid === "potenzial")       return net.bezeichnung || ed.signalname || "Potenzial"
        if (sid === "klemme_anschluss") {
            var kaAnz = ed.anschlussBezeichnung || ""
            var kaBmk = ed.bmk || ""
            return kaBmk ? (kaBmk + ":" + kaAnz) : (kaAnz || "KA")
        }
        if (sid === "isoliert_gelegte_ader") return "isoliert"
        return sid
    }

    // DFS-Traversal auf Fremdseite; kein weiterer Cross-page-Hop (Rekursionsschutz).
    function _traversiereEndpunktInElemente(startElIdx, vonElIdx, adj, elemente, net, partnerSeiteId, tiefe) {
        if (tiefe <= 0) return "⚠ Zyklus"
        var el = elemente[startElIdx]
        if (!el || !el.typ) return "⚠ Kein Endpunkt"
        var sid = el.symbolId || ""

        if (sid === "geraeteanschluss" || sid === "potenzial" ||
            sid === "klemme_anschluss" || sid === "isoliert_gelegte_ader")
            return _formatEndpunktInElemente(el, net, elemente)

        // Querverweis auf Fremdseite: Label ermitteln, kein weiterer Hop
        if (sid === "querverweis") {
            var ed = el.extraDaten || {}
            var sn = ed.signalname || ""
            if (!sn) return "→ Querverweis"
            var alle = db.querverweiseLadenProjekt(root.projektId)
            for (var k = 0; k < alle.length; k++) {
                var qv = alle[k]
                if (qv.signalname !== sn) continue
                if (qv.seiteId === partnerSeiteId &&
                    Math.abs(qv.x1 - el.x1) < 0.5 && Math.abs(qv.y1 - el.y1) < 0.5) continue
                return "→ S." + qv.blattnummer + (qv.seitenBezeichnung ? " " + qv.seitenBezeichnung : "")
            }
            return "→ Querverweis"
        }

        // Treffpunkt: Routing-Regeln (identisch zur Haupttraversal)
        if (sid === "treffpunkt" || sid === "treffpunkt_l") {
            var adjSelf = adj[startElIdx] || []
            var connPos = null
            for (var ai = 0; ai < adjSelf.length; ai++) {
                if (adjSelf[ai].neighbor === vonElIdx) { connPos = adjSelf[ai].connPosOnSelf; break }
            }
            var vonArm = connPos ? _treffpunktArmBestimmen(el, connPos) : null
            if (vonArm === "s1" || vonArm === "s2") {
                var zielNb = _treffpunktNachbarFuerArm(el, startElIdx, adj, "ziel")
                if (zielNb !== null)
                    return _traversiereEndpunktInElemente(zielNb, startElIdx, adj, elemente, net, partnerSeiteId, tiefe - 1)
                return "⚠ Kein Ziel"
            } else if (vonArm === "ziel") {
                for (var sArm of ["s1", "s2"]) {
                    var sNb = _treffpunktNachbarFuerArm(el, startElIdx, adj, sArm)
                    if (sNb !== null && sNb !== vonElIdx) {
                        var res = _traversiereEndpunktInElemente(sNb, startElIdx, adj, elemente, net, partnerSeiteId, tiefe - 1)
                        if (res.indexOf("⚠") < 0) return res
                    }
                }
                return "⚠ Treffpunkt (ziel)"
            }
            return "⚠ Treffpunkt"
        }

        // Transparente Elemente (winkel, aderdefinition, …)
        var nbList = adj[startElIdx] || []
        for (var ni = 0; ni < nbList.length; ni++) {
            if (nbList[ni].neighbor !== vonElIdx)
                return _traversiereEndpunktInElemente(nbList[ni].neighbor, startElIdx, adj, elemente, net, partnerSeiteId, tiefe - 1)
        }
        return "⚠ Kein Endpunkt"
    }

    // Lädt Partnerseite und führt Traversal dort weiter.
    function _traversiereEndpunktCrossPage(qvEl, partnerInfo, net, tiefe) {
        var label = "→ S." + partnerInfo.label
        if (tiefe <= 1) return label

        var elemente = db.grafikLaden(partnerInfo.seiteId)
        if (!elemente || elemente.length === 0) return label

        // Partner-Querverweis auf Zielseite: gleicher Signalname, selbe DB-Position
        var sn = (qvEl.extraDaten && qvEl.extraDaten.signalname) || ""
        var partnerIdx = -1
        for (var i = 0; i < elemente.length; i++) {
            var e = elemente[i]
            if (!e || e.typ !== "symbol" || e.symbolId !== "querverweis") continue
            var esn = (e.extraDaten && e.extraDaten.signalname) || ""
            if (esn !== sn) continue
            var dx = e.x1 - partnerInfo.x1, dy = e.y1 - partnerInfo.y1
            if (dx*dx + dy*dy < 1.0) { partnerIdx = i; break }
        }
        if (partnerIdx < 0) return label

        var adj    = _adjFuerElemente(elemente)
        var nbList = adj[partnerIdx] || []
        if (nbList.length === 0) return label

        return _traversiereEndpunktInElemente(nbList[0].neighbor, partnerIdx, adj, elemente, net, partnerInfo.seiteId, tiefe - 1)
    }

    function verbindungAnnotationenNeuLaden() {
        var annListe = db.verbindungAnnotationenLaden(root.seiteId)
        var cache = {}
        for (var i = 0; i < annListe.length; i++) cache[annListe[i].netKey] = annListe[i]
        root.verbindungAnnotationenCache = cache
        // Ausgewählte Verbindung im Cache aktualisieren
        if (root.ausgewaehltVerbindung) {
            var ann = cache[root.ausgewaehltVerbindung.netKey]
            if (ann) {
                var upd = {}; for (var k in root.ausgewaehltVerbindung) upd[k] = root.ausgewaehltVerbindung[k]
                upd.verbindungId = ann.verbindungId
                upd.bezeichnung  = ann.bezeichnung  || upd.bezeichnung
                upd.farbe        = ann.farbe        || upd.farbe
                upd.querschnitt  = ann.querschnitt_mm2 || upd.querschnitt
                root.ausgewaehltVerbindung = upd
            }
        }
    }

    function verbindungAnnotationAktualisieren(key, value) {
        if (!root.ausgewaehltVerbindung) return
        var vb = {}; for (var k in root.ausgewaehltVerbindung) vb[k] = root.ausgewaehltVerbindung[k]
        vb[key] = value
        root.ausgewaehltVerbindung = vb
        // Cache aktualisieren
        var cache = {}; for (var ck in root.verbindungAnnotationenCache) cache[ck] = root.verbindungAnnotationenCache[ck]
        var entry = {}; if (cache[vb.netKey]) { for (var ek in cache[vb.netKey]) entry[ek] = cache[vb.netKey][ek] }
        entry[key] = value
        cache[vb.netKey] = entry
        root.verbindungAnnotationenCache = cache
        // In DB persistieren
        if (vb.verbindungId > 0)
            db.verbindungAktualisieren(vb.verbindungId, vb.bezeichnung || "", vb.farbe || "", vb.querschnitt || 0)
        drawCanvas.requestPaint()
    }

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

    // CE-11: Batch-Nummerierung – setzt BMKs auf ausgewählte Symbole in Links→Rechts-Reihenfolge
    function batchBmkNummerieren(praefix, startNr) {
        var symbole = []
        for (var i = 0; i < root.auswahl.length; i++) {
            var el = elementeModel.element(root.auswahl[i])
            if (el && el.typ === "symbol")
                symbole.push({ idx: root.auswahl[i], x: el.x1, y: el.y1 })
        }
        if (symbole.length === 0) return
        symbole.sort(function(a, b) { return a.x !== b.x ? a.x - b.x : a.y - b.y })

        elementeModel.undoCheckpoint()
        var selSnapshot = root.auswahl.slice()
        var num = startNr
        symbole.forEach(function(s) {
            var cur = elementeModel.element(s.idx)
            var ed  = cur.extraDaten ? JSON.parse(JSON.stringify(cur.extraDaten)) : {}
            ed.bmk  = praefix + num++
            elementeModel.eigenschaftSetzen(s.idx, "extraDaten", ed)
        })
        root.auswahl = selSnapshot
        root.grafikSpeichernJetzt()
        root.neuZeichnen()
    }

    // CE-06: Ausrichten & Verteilen
    // richtung: "links"|"rechts"|"oben"|"unten"|"mitte_h"|"mitte_v"|"verteilen_h"|"verteilen_v"
    function elementeAusrichten(richtung) {
        if (root.auswahl.length < 2) return
        var verteilen = (richtung === "verteilen_h" || richtung === "verteilen_v")
        if (verteilen && root.auswahl.length < 3) return

        var els = root.auswahl.map(function(idx) {
            var el = elementeModel.element(idx)
            return { idx: idx, x1: el.x1, y1: el.y1, x2: el.x2, y2: el.y2 }
        })
        var minX1 = els[0].x1, maxX2 = els[0].x2
        var minY1 = els[0].y1, maxY2 = els[0].y2
        for (var i = 1; i < els.length; i++) {
            if (els[i].x1 < minX1) minX1 = els[i].x1
            if (els[i].x2 > maxX2) maxX2 = els[i].x2
            if (els[i].y1 < minY1) minY1 = els[i].y1
            if (els[i].y2 > maxY2) maxY2 = els[i].y2
        }
        var centerX = (minX1 + maxX2) / 2
        var centerY = (minY1 + maxY2) / 2

        elementeModel.undoCheckpoint()
        var selSnapshot = root.auswahl.slice()

        if (verteilen) {
            var sorted, firstC, lastC, vstep, n, j, ev, vw, vh, newV1
            n = els.length
            if (richtung === "verteilen_h") {
                sorted = els.slice().sort(function(a, b) { return (a.x1 + a.x2) - (b.x1 + b.x2) })
                firstC = (sorted[0].x1     + sorted[0].x2)     / 2
                lastC  = (sorted[n-1].x1   + sorted[n-1].x2)   / 2
                vstep  = (lastC - firstC) / (n - 1)
                for (j = 1; j < n - 1; j++) {
                    ev = sorted[j]; vw = ev.x2 - ev.x1
                    newV1 = firstC + j * vstep - vw / 2
                    elementeModel.elementAktualisieren(ev.idx, { x1: newV1, y1: ev.y1, x2: newV1 + vw, y2: ev.y2 })
                }
            } else {
                sorted = els.slice().sort(function(a, b) { return (a.y1 + a.y2) - (b.y1 + b.y2) })
                firstC = (sorted[0].y1     + sorted[0].y2)     / 2
                lastC  = (sorted[n-1].y1   + sorted[n-1].y2)   / 2
                vstep  = (lastC - firstC) / (n - 1)
                for (j = 1; j < n - 1; j++) {
                    ev = sorted[j]; vh = ev.y2 - ev.y1
                    newV1 = firstC + j * vstep - vh / 2
                    elementeModel.elementAktualisieren(ev.idx, { x1: ev.x1, y1: newV1, x2: ev.x2, y2: newV1 + vh })
                }
            }
        } else {
            for (var m = 0; m < els.length; m++) {
                var em = els[m]
                var ew = em.x2 - em.x1, eh = em.y2 - em.y1
                var nx1 = em.x1, ny1 = em.y1
                if      (richtung === "links")   nx1 = minX1
                else if (richtung === "rechts")  nx1 = maxX2 - ew
                else if (richtung === "mitte_h") nx1 = centerX - ew / 2
                if      (richtung === "oben")    ny1 = minY1
                else if (richtung === "unten")   ny1 = maxY2 - eh
                else if (richtung === "mitte_v") ny1 = centerY - eh / 2
                elementeModel.elementAktualisieren(em.idx, { x1: nx1, y1: ny1, x2: nx1 + ew, y2: ny1 + eh })
            }
        }

        root.auswahl = selSnapshot
        root.grafikSpeichernJetzt()
        root.neuZeichnen()
    }

    function aktionAusfuehren(neueElemente) {
        elementeModel.undoCheckpoint()
        elementeModel.fromVariantList(neueElemente)
        root.auswahl   = []
        root.grafikSpeichernJetzt()
    }

    function eigenschaftAktualisieren(key, value) {
        if (root.auswahl.length === 0) return
        var selSnapshot = root.auswahl.slice()
        elementeModel.undoCheckpoint()

        root.auswahl.forEach(function(i) {
            var el = elementeModel.element(i)
            // Winkel: bei Rotationsänderung Bbox verschieben damit die grafische Ecke ortsfest bleibt
            if (key === "rotation" && el.symbolId === "winkel") {
                var g    = root.gridPx
                var cxEl = (el.x1 + el.x2) / 2, cyEl = (el.y1 + el.y2) / 2
                var cox  = -g / 2, coy = g / 2
                var oldRad   = (el.rotation || 0) * Math.PI / 180
                var cornerWx = cxEl + cox * Math.cos(oldRad) - coy * Math.sin(oldRad)
                var cornerWy = cyEl + cox * Math.sin(oldRad) + coy * Math.cos(oldRad)
                var newRad   = value * Math.PI / 180
                var newCx    = cornerWx - (cox * Math.cos(newRad) - coy * Math.sin(newRad))
                var newCy    = cornerWy - (cox * Math.sin(newRad) + coy * Math.cos(newRad))
                elementeModel.elementAktualisieren(i, {
                    rotation: value,
                    x1: newCx - g / 2, y1: newCy - g / 2,
                    x2: newCx + g / 2, y2: newCy + g / 2
                })
            } else {
                elementeModel.eigenschaftSetzen(i, key, value)
            }
        })

        root.auswahl = selSnapshot
        root.grafikSpeichernJetzt()

        // Stilvorlagen nur bei Einzelauswahl übernehmen
        if (root.auswahl.length === 1) {
            var stilKeys = ["strichFarbe","strichBreite","strichArt","fuell",
                            "fuellFarbe","fuellOpazitaet","opazitaet","eckenRadius"]
            if (stilKeys.indexOf(key) >= 0) {
                var vl = {}; for (var sk in root.stilVorlage) vl[sk] = root.stilVorlage[sk]
                vl[key] = value; root.stilVorlage = vl
            }
        }
        // Kabel-DB-Metadaten aktualisieren wenn Kabellinie-extraDaten geändert wurden
        if (key === "extraDaten" && root.auswahl.length === 1) {
            var klIdx = root.auswahl[0]
            var klEl  = elementeModel.element(klIdx)
            if (klEl && klEl.typ === "kabellinie") {
                var ed2 = value
                var kabelId = ed2.kabelId || (klEl.extraDaten && klEl.extraDaten.kabelId) || 0
                if (kabelId > 0) {
                    db.kabelMetaAktualisieren(kabelId,
                                    ed2.bezeichnung    || "",
                                    ed2.kabeltyp       || "",
                                    ed2.aderzahl       || 0,
                                    ed2.querschnittMm2 || 0.0)
                }
            }
        }
        drawCanvas.requestPaint()
    }

    // Format-Pinsel: Stileigenschaften des ausgewählten Elements speichern
    // Viewport-Hit-Test auf BMK-Beschriftung eines Symbols.
    // Gibt Element-Index zurück oder -1 wenn kein Label getroffen.
    function labelTreffenTest(vpX, vpY) {
        var n = elementeModel.anzahl
        for (var i = n - 1; i >= 0; i--) {
            var el = elementeModel.element(i)
            if (el.typ !== "symbol") continue
            var bmkEd  = el.extraDaten || {}
            var vx1 = el.x1 * root.zoom + root.worldX
            var vy1 = el.y1 * root.zoom + root.worldY
            var vx2 = el.x2 * root.zoom + root.worldX
            var vy2 = el.y2 * root.zoom + root.worldY
            var pad   = 8
            var symRot = ((el.rotation || 0) % 360 + 360) % 360
            var senkrecht = (symRot === 90 || symRot === 270)
            var hx1, hy1, hx2, hy2

            if (el.symbolId === "klemme_anschluss") {
                // Klemme-spezifische Hit-Box: Anschlussbezeichnung + BMK
                var kaAnzH = bmkEd.anschlussBezeichnung || ""
                var kaBmkH = bmkEd.bmk || ""
                if (kaAnzH === "" && kaBmkH === "") continue
                var kaFsH    = Math.max(7, Math.round(2.0 * root.mmToPx * root.zoom))
                var kaBmkFsH = Math.max(6, Math.round(1.5 * root.mmToPx * root.zoom))
                var kaOxH = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0) * root.zoom
                var kaOyH = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : 0) * root.zoom
                var textH = kaFsH + kaBmkFsH + pad
                if (senkrecht) {
                    var kaPinRH = (symRot === 90)
                    var kaHX  = kaPinRH
                                 ? Math.min(vx1, vx2) - 4 * root.zoom + kaOyH
                                 : Math.max(vx1, vx2) + 4 * root.zoom + kaOyH
                    var kaHCY = (vy1 + vy2) / 2 + kaOxH
                    var hitWH = Math.max(40, kaFsH * 4)
                    hx1 = kaPinRH ? kaHX - hitWH : kaHX - pad
                    hx2 = kaPinRH ? kaHX + pad   : kaHX + hitWH
                    hy1 = kaHCY - kaFsH - pad; hy2 = kaHCY + kaBmkFsH + pad
                } else {
                    var kaPinUH = (symRot === 180)
                    var kaHY  = kaPinUH
                                 ? Math.min(vy1, vy2) - 3 * root.zoom + kaOyH
                                 : Math.max(vy1, vy2) + 3 * root.zoom + kaOyH
                    var kaHCX = (vx1 + vx2) / 2 + kaOxH
                    hx1 = kaHCX - Math.max(30, kaFsH * 3); hx2 = kaHCX + Math.max(30, kaFsH * 3)
                    hy1 = kaPinUH ? kaHY - textH : kaHY - pad
                    hy2 = kaPinUH ? kaHY + pad   : kaHY + textH
                }
            } else {
                var bmkStr = bmkEd.bmk || ""
                if (bmkStr === "") continue
                var bmkOx = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0)  * root.zoom
                var bmkOy = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : -14) * root.zoom
                var schrift = bmkEd.schriftgroesse !== undefined ? bmkEd.schriftgroesse : 2.5
                var bmkFs = Math.max(8, Math.round(schrift * root.mmToPx * root.zoom))
                if (senkrecht) {
                    var bkAx = Math.min(vx1, vx2) + bmkOy
                    var bkCy = (vy1 + vy2) / 2 + bmkOx
                    var hitW = Math.max(40, bmkFs * 4)
                    hx1 = bkAx - hitW; hx2 = bkAx + pad
                    hy1 = bkCy - Math.max(14, bmkFs) - pad; hy2 = bkCy + pad
                } else {
                    var bkCx = (vx1 + vx2) / 2 + bmkOx
                    var bkTy = Math.min(vy1, vy2) + bmkOy
                    var hitW2 = Math.max(40, bmkFs * 3)
                    hx1 = bkCx - hitW2; hx2 = bkCx + hitW2
                    hy1 = bkTy - Math.max(14, bmkFs) - pad; hy2 = bkTy + pad
                }
            }

            if (vpX >= hx1 && vpX <= hx2 && vpY >= hy1 && vpY <= hy2)
                return i
        }
        return -1
    }

    function formatKopieren() {
        if (root.auswahl.length !== 1) return
        var el = elementeModel.element(root.auswahl[0])
        if (!el) return
        var stilKeys = ["strichFarbe","strichBreite","strichArt","fuell",
                        "fuellFarbe","fuellOpazitaet","opazitaet","eckenRadius"]
        var vl = {}
        for (var i = 0; i < stilKeys.length; i++) {
            var k = stilKeys[i]
            if (el[k] !== undefined) vl[k] = el[k]
        }
        if (el.typ === "symbol") {
            var ed = el.extraDaten || {}
            vl._bmkOffsetX = ed.bmkOffsetX !== undefined ? ed.bmkOffsetX : 0
            vl._bmkOffsetY = ed.bmkOffsetY !== undefined ? ed.bmkOffsetY : -14
        }
        root._formatVorlage = vl
        root.formatZaehler  = root.formatZaehler + 1
    }

    // Format-Pinsel: gespeichertes Stilformat auf alle selektierten Elemente anwenden
    function formatZuweisen() {
        if (!root._formatVorlage || root.auswahl.length === 0) return
        var selSnapshot = root.auswahl.slice()
        elementeModel.undoCheckpoint()
        var stilKeys = ["strichFarbe","strichBreite","strichArt","fuell",
                        "fuellFarbe","fuellOpazitaet","opazitaet","eckenRadius"]
        var hatLabelOffset = root._formatVorlage._bmkOffsetX !== undefined
        for (var i = 0; i < selSnapshot.length; i++) {
            for (var j = 0; j < stilKeys.length; j++) {
                var k = stilKeys[j]
                if (root._formatVorlage[k] !== undefined)
                    elementeModel.eigenschaftSetzen(selSnapshot[i], k, root._formatVorlage[k])
            }
            if (hatLabelOffset) {
                var tEl = elementeModel.element(selSnapshot[i])
                if (tEl && tEl.typ === "symbol") {
                    var ted = Object.assign({}, tEl.extraDaten || {})
                    ted.bmkOffsetX = root._formatVorlage._bmkOffsetX
                    ted.bmkOffsetY = root._formatVorlage._bmkOffsetY
                    elementeModel.eigenschaftSetzen(selSnapshot[i], "extraDaten", ted)
                }
            }
        }
        root.auswahl = selSnapshot
        root.grafikSpeichernJetzt()
        drawCanvas.requestPaint()
    }

    // Mehrfachauswahl um gemeinsamen Pivot rotieren (nur 90°-Schritte).
    // Pivot = weltweit am weitesten links liegender Pin der selektierten Symbole;
    // für Elemente ohne Pins gilt die linke obere Ecke der Bbox als Kandidat.
    // delta: 90 (CW), 270 (CCW) oder 180.
    function multiRotationUmPivot(delta) {
        if (root.auswahl.length < 2) return

        // ── 1. Pivot bestimmen ───────────────────────────────────────────────
        var pivotX = Infinity, pivotY = Infinity

        function updatePivot(wx, wy) {
            if (wx < pivotX || (wx === pivotX && wy < pivotY)) {
                pivotX = wx; pivotY = wy
            }
        }

        // Zuerst Pin-Kandidaten aus allen selektierten Symbolen sammeln
        var pinKandidaten = false
        var _mreAnz = elementeModel.anzahl
        for (var ii = 0; ii < root.auswahl.length; ii++) {
            var idxA = root.auswahl[ii]
            if (idxA < 0 || idxA >= _mreAnz) continue
            var elA = elementeModel.element(idxA)
            if (elA.typ !== "symbol") continue
            var pins = symbolDefinitionModel.pinsForSymbol(elA.symbolId || "")
            for (var pi = 0; pi < pins.length; pi++) {
                var pos = root.pinWeltPos(elA, pins[pi].x, pins[pi].y)
                updatePivot(pos.x, pos.y)
                pinKandidaten = true
            }
        }

        // Fallback: keine Pins gefunden → Bbox-Ecken aller Elemente
        if (!pinKandidaten) {
            for (var ij = 0; ij < root.auswahl.length; ij++) {
                var idxB = root.auswahl[ij]
                if (idxB < 0 || idxB >= _mreAnz) continue
                var elB = elementeModel.element(idxB)
                if (elB.typ === "polygonlinie") {
                    var pts = elB.punkte || []
                    for (var pk = 0; pk < pts.length; pk++) updatePivot(pts[pk].x, pts[pk].y)
                } else {
                    updatePivot(elB.x1, elB.y1)
                }
            }
        }

        if (!isFinite(pivotX)) return

        // ── 2. Rotationsmatrix für 90°-Schritte (exakt, ganzzahlig) ─────────
        var rad  = delta * Math.PI / 180
        var cosD = Math.round(Math.cos(rad))   // 0, ±1
        var sinD = Math.round(Math.sin(rad))   // 0, ±1

        function rotPt(x, y) {
            var dx = x - pivotX, dy = y - pivotY
            return { x: pivotX + cosD * dx - sinD * dy,
                     y: pivotY + sinD * dx + cosD * dy }
        }

        // ── 3. Alle selektierten Elemente transformieren ─────────────────────
        var selSet = {}
        root.auswahl.forEach(function(i) { selSet[i] = true })

        var neu = elementeModel.snapshot().map(function(el, i) {
            if (!selSet[i]) return el
            var upd = {}; for (var k in el) upd[k] = el[k]

            if (el.typ === "linie") {
                // Beide Endpunkte einzeln rotieren
                var np1 = rotPt(el.x1, el.y1), np2 = rotPt(el.x2, el.y2)
                upd.x1 = np1.x; upd.y1 = np1.y
                upd.x2 = np2.x; upd.y2 = np2.y

            } else if (el.typ === "polygonlinie") {
                upd.punkte = (el.punkte || []).map(function(p) { return rotPt(p.x, p.y) })
                // x1/y1/x2/y2 als Hüllrechteck aktualisieren
                var xs = upd.punkte.map(function(p) { return p.x })
                var ys = upd.punkte.map(function(p) { return p.y })
                upd.x1 = Math.min.apply(null, xs); upd.x2 = Math.max.apply(null, xs)
                upd.y1 = Math.min.apply(null, ys); upd.y2 = Math.max.apply(null, ys)

            } else {
                // Alle anderen: Mittelpunkt um Pivot drehen, Rotation-Winkel anpassen
                var cx = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
                var hw = (el.x2 - el.x1) / 2,  hh = (el.y2 - el.y1) / 2
                var nc = rotPt(cx, cy)
                upd.x1 = nc.x - hw; upd.x2 = nc.x + hw
                upd.y1 = nc.y - hh; upd.y2 = nc.y + hh
                upd.rotation = ((el.rotation || 0) + delta) % 360
            }
            return upd
        })

        var selSnapshot = root.auswahl.slice()
        elementeModel.undoCheckpoint()
        elementeModel.fromVariantList(neu); root.auswahl = selSnapshot
        root.grafikSpeichernJetzt()
        drawCanvas.requestPaint()
    }

    function eigenschaftenSetzen(updates) {
        if (root.ausgewaehlt < 0) return
        var oldIdx = root.ausgewaehlt
        elementeModel.undoCheckpoint()
        elementeModel.elementAktualisieren(oldIdx, updates)
        root.auswahl = [oldIdx]
        root.grafikSpeichernJetzt()
        drawCanvas.requestPaint()
    }

    function zReihenfolgeAendern(richtung) {
        if (root.ausgewaehlt < 0) return
        var idx=root.ausgewaehlt, n=elementeModel.anzahl
        var neu=elementeModel.snapshot(), el=neu[idx], newIdx=idx
        if      (richtung==="vorne1"    && idx<n-1) { neu.splice(idx,1); neu.splice(idx+1,0,el); newIdx=idx+1 }
        else if (richtung==="hinten1"   && idx>0)   { neu.splice(idx,1); neu.splice(idx-1,0,el); newIdx=idx-1 }
        else if (richtung==="ganzVorne")             { neu.splice(idx,1); neu.push(el);           newIdx=n-1   }
        else if (richtung==="ganzHinten")            { neu.splice(idx,1); neu.unshift(el);        newIdx=0     }
        else return
        elementeModel.undoCheckpoint()
        elementeModel.fromVariantList(neu); root.auswahl=[newIdx]
        root.grafikSpeichernJetzt()
        drawCanvas.requestPaint()
    }

    function undo() {
        if (!elementeModel.undoMoeglich) return
        elementeModel.undo()
        root.auswahl = []
        root.grafikSpeichernJetzt()
        drawCanvas.requestPaint()
    }

    function redo() {
        if (!elementeModel.redoMoeglich) return
        elementeModel.redo()
        root.auswahl = []
        root.grafikSpeichernJetzt()
        drawCanvas.requestPaint()
    }

    function loeschen() {
        if (root.auswahl.length === 0) return
        // Kabel-Einträge für Kabellinien zuerst aufräumen
        for (var ki = 0; ki < root.auswahl.length; ki++) {
            var delEl = elementeModel.element(root.auswahl[ki])
            if (delEl && delEl.typ === "kabellinie") {
                var delKabelId = delEl.extraDaten && delEl.extraDaten.kabelId || 0
                if (delKabelId <= 0 && delEl.id > 0) {
                    // Fallback: über grafik_element_id suchen
                    var kabelDetails = db.kabelLinieDetails(delEl.id)
                    delKabelId = kabelDetails && kabelDetails.id || 0
                }
                if (delKabelId > 0) db.kabelLoeschen(delKabelId)
            }
        }
        // Von hinten löschen damit Indizes stabil bleiben
        var sorted = root.auswahl.slice().sort(function(a, b) { return b - a })
        var neu = elementeModel.snapshot()
        for (var i = 0; i < sorted.length; i++) neu.splice(sorted[i], 1)
        elementeModel.undoCheckpoint()
        elementeModel.fromVariantList(neu); root.auswahl = []
        root.grafikSpeichernJetzt()
        root.kabelLinienCacheAktualisieren()
        drawCanvas.requestPaint()
    }

    function alleAuswaehlen() {
        if (elementeModel.anzahl === 0 || root.seiteId < 0) return
        var sel = []; for (var i = 0; i < elementeModel.anzahl; i++) sel.push(i)
        root.auswahl = sel
        drawCanvas.requestPaint()
    }

    function kopieren(slot) {
        if (root.auswahl.length === 0) return
        var inhalt = root.auswahl.map(function(i) {
            var el = elementeModel.element(i)
            var copy = Object.assign({}, el)
            delete copy.gruppeId
            return copy
        })
        var s = (slot === undefined) ? 0 : slot
        if (s === 0) {
            root.zwischenablage = inhalt
        } else {
            var neu = root.zwischenablagen.slice()
            neu[s] = inhalt
            root.zwischenablagen = neu
        }
    }

    function einfuegen(slot) {
        var s = (slot === undefined) ? 0 : slot
        var quelle = (s === 0) ? root.zwischenablage : root.zwischenablagen[s]
        if (!quelle || quelle.length === 0 || root.seiteId < 0) return
        root.duplizierVorlage   = quelle
        root.duplizierMitDialog = false
        root.aktivesWerkzeug    = "duplizieren"
        root._duplizierVorschauAktualisieren(root.letzteMausWeltX, root.letzteMausWeltY)
    }

    function duplizieren() {
        if (root.auswahl.length === 0 || root.seiteId < 0) return
        root.duplizierVorlage = root.auswahl.map(function(i) {
            var el   = elementeModel.element(i)
            var copy = Object.assign({}, el)
            delete copy.gruppeId   // Gruppe nicht auf Kopie übertragen
            return copy
        })
        root.duplizierMitDialog = true
        root.aktivesWerkzeug    = "duplizieren"
        root._duplizierVorschauAktualisieren(root.letzteMausWeltX, root.letzteMausWeltY)
    }

    function ausschneiden() {
        if (root.auswahl.length === 0) return
        root.kopieren()
        root.loeschen()
    }

    // Signal: EigenschaftenPanel-Button soll BMK-Nummerierungsdialog öffnen.
    // CanvasNavigationHandler hört darauf und öffnet den Dialog (hat db-Zugriff).
    signal batchBmkDialogOeffnen()

    // Gibt die vollständige Gruppenauswahl zurück wenn idx zu einer Gruppe gehört,
    // sonst [idx].
    function auswahlFuerElement(idx) {
        if (idx < 0) return []
        var gId = elementeModel.gruppeVonElement(idx)
        if (gId >= 0) {
            var mitgl = elementeModel.gruppenMitglieder(gId)
            return mitgl.map(function(v) { return parseInt(v) })
        }
        return [idx]
    }

    function gruppeErstellen() {
        if (root.auswahl.length < 2 || root.seiteId < 0) return
        elementeModel.undoCheckpoint()
        elementeModel.gruppeErstellen(root.auswahl)
        root.grafikSpeichernJetzt()
        root.neuZeichnen()
    }

    function gruppeAufloesen() {
        if (root.auswahl.length === 0 || root.seiteId < 0) return
        var gId = elementeModel.gruppeVonElement(root.auswahl[0])
        if (gId < 0) return
        elementeModel.undoCheckpoint()
        var mitgl = elementeModel.gruppenMitglieder(gId)
        elementeModel.gruppeAufloesen(gId)
        root.auswahl = mitgl.map(function(v) { return parseInt(v) })
        root.grafikSpeichernJetzt()
        root.neuZeichnen()
    }

    function _duplizierVorschauAktualisieren(wx, wy) {
        var els = root.duplizierVorlage
        if (!els || els.length === 0) return
        var minX = els[0].x1, minY = els[0].y1, maxX = els[0].x2, maxY = els[0].y2
        for (var i = 1; i < els.length; i++) {
            if (els[i].x1 < minX) minX = els[i].x1
            if (els[i].y1 < minY) minY = els[i].y1
            if (els[i].x2 > maxX) maxX = els[i].x2
            if (els[i].y2 > maxY) maxY = els[i].y2
        }
        var dx = wx - (minX + maxX) / 2
        var dy = wy - (minY + maxY) / 2
        root.duplizierVorschau = els.map(function(el) {
            var upd = {}; for (var k in el) upd[k] = el[k]
            upd.x1 += dx; upd.y1 += dy; upd.x2 += dx; upd.y2 += dy
            upd.id = -1
            return upd
        })
        root.neuZeichnen()
    }

    function _duplizierAnzahlAnfordern(dx, dy) {
        root.duplizierOffsetX  = dx
        root.duplizierOffsetY  = dy
        root.duplizierVorschau = null
        root.neuZeichnen()
        if (root.duplizierMitDialog)
            duplizierAnzahlDialog.open()
        else
            root._duplizierAnzahlPlatzieren(1)
    }

    function _duplizierAnzahlPlatzieren(n) {
        var els = root.duplizierVorlage
        if (!els || n < 1) { root.abbruch(); return }
        var neueEl = []
        for (var c = 1; c <= n; c++) {
            var dx = root.duplizierOffsetX * c
            var dy = root.duplizierOffsetY * c
            for (var j = 0; j < els.length; j++) {
                var upd = {}; for (var k in els[j]) upd[k] = els[j][k]
                upd.x1 += dx; upd.y1 += dy; upd.x2 += dx; upd.y2 += dy
                neueEl.push(upd)
            }
        }
        var anzahl = neueEl.length
        root.aktionAusfuehren(elementeModel.snapshot().concat(neueEl))
        var start = elementeModel.anzahl - anzahl
        var sel = []; for (var s = 0; s < anzahl; s++) sel.push(start + s)
        root.auswahl          = sel
        root.aktivesWerkzeug  = "zeiger"
        root.duplizierVorlage  = null
        root.duplizierVorschau = null
        root.neuZeichnen()
    }

    function abbruch() {
        root.amZeichnen       = false; root.vorschau = null
        root.aktiverGriff     = -1
        root.amRubberband     = false; root.rubberbandRect = null
        root.textEditAktiv    = false
        root.paletteImageData = ""
        root.amPolyZeichnen   = false
        root.polyPunkte       = []
        root.polyCursorWelt   = null
        root.duplizierVorlage   = null
        root.duplizierVorschau  = null
        root.duplizierMitDialog = true
        drawCanvas.requestPaint()
    }

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
                    if (sed.anlage) anlage = sed.anlage
                    if (sed.ort)    ort    = sed.ort
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
        var elCx = (vx1 + vx2) / 2
        var elCy = (vy1 + vy2) / 2
        var pad = 20
        var visRight = width - epBreite - pad
        var visLeft  = tlW + pad
        var visTop   = topH + pad
        var visBot   = height - botH - pad
        // Nur pan wenn Element wirklich verdeckt oder außerhalb
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
            root.fehlersuchPfadIds      = {}
            root.fehlersuchStartId      = -1
            root.fehlersuchQuerverweise = []
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
                Layout.fillWidth: true; height: 32; radius: 4
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

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

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
}
