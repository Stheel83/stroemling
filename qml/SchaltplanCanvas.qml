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
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (root.aktivesWerkzeug === "symbol" && root.paletteSymbolId !== "") {
                root.abbruch()
                root.paletteSymbolId = ""
                root.aktivesWerkzeug = "zeiger"
            } else {
                root.loeschen()
            }
            event.accepted = true
        }
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
    required property var elementeModel

    signal hintergrundGeaendert(string farbe)
    // Wird ausgelöst wenn der Nutzer auf ein Querverweis-Symbol doppelklickt.
    signal querverweisNavigieren(int seiteId)
    // Wird ausgelöst wenn ein Makro gespeichert oder gelöscht wurde.
    signal makroListeGeaendert()

    property real zoom:    1.0
    property real minZoom: 0.1
    property real maxZoom: 8.0

    property real worldX: 0
    property real worldY: 0

    property var  _zoomPanCache:   ({})  // seiteId → {zoom, worldX, worldY}
    property int  _vorherSeiteId:  -1    // seiteId vor dem letzten Seitenwechsel

    property real gridMm:  4.0
    property real mmToPx:  4.0
    property bool rastend: true

    property var    normblattDaten:   null
    property string normblattLogoUrl: ""

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
    property int    makroEinfuegenId:   0
    property string makroEinfuegenName: ""

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
    readonly property int ausgewaehlt: auswahl.length === 1 ? auswahl[0] : -1
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
    property bool verschiebenErlaubt:  false  // nur true wenn auf bereits-selektiertes Element geklickt
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

    // ── Inbetriebnahme-Modus ─────────────────────────────────
    property bool ibnModus:    false
    property var  ibnStatusMap:    ({})   // bmk → "offen"|"in_arbeit"|"abgeschlossen"
    property var  _spsKonfliktSet: ({})   // elementId → true  (mehr als 1 Kanal zugewiesen)

    function zentriereAuf(wx, wy) {
        root.worldX = wx - (drawCanvas.width  / (2 * root.zoom * root.mmToPx))
        root.worldY = wy - (drawCanvas.height / (2 * root.zoom * root.mmToPx))
        drawCanvas.requestPaint()
    }

    function neuZeichnen() { drawCanvas.requestPaint() }

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
                zelle("INDEX",        "–",                   cX[3], rowY[2], cX[4]-cX[3], rowH)

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

            var sf  = el.strichFarbe     !== undefined ? el.strichFarbe     : "#4a9eff"
            var sb  = el.strichBreite    !== undefined ? el.strichBreite    : 1.5
            var sa  = el.strichArt       !== undefined ? el.strichArt       : "solid"
            var fu  = el.fuell           !== undefined ? el.fuell           : false
            var ff  = el.fuellFarbe      !== undefined ? el.fuellFarbe      : "#1a3a6a"
            var fo  = el.fuellOpazitaet  !== undefined ? el.fuellOpazitaet  : 0.3
            var op  = el.opazitaet       !== undefined ? el.opazitaet       : 1.0
            var er  = el.eckenRadius      !== undefined ? el.eckenRadius      : 0

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
                    ctx.fillStyle = ff; ctx.globalAlpha = op * fo
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
                        ctx.fillStyle=ff; ctx.globalAlpha=op*fo; ctx.fill()
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
                    ctx.save()
                    ctx.translate(vx1, vy1)
                    if (txtRot !== 0) ctx.rotate(txtRot)
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
                        var selW = txtRot !== 0 ? txtBhPx : txtBwPx
                        var selH = txtRot !== 0 ? txtBwPx : txtBhPx
                        var bxOff = txtAlign === "mitte" ? -selW / 2
                                  : txtAlign === "rechts" ? -selW : 0
                        ctx.strokeStyle = "#f0a030"; ctx.lineWidth = 1
                        ctx.setLineDash([3, 3])
                        ctx.strokeRect(bxOff - 2, -2, selW + 4, selH + 4)
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
                    ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : (el.strichFarbe || "#cccc22"))
                    ctx.lineWidth   = 1.5
                    ctx.setLineDash([])
                    ctx.strokeRect(nRx, nRy, nRw, nRh)
                    // Text
                    var nText = el.textInhalt || ""
                    if (nText !== "") {
                        var nFsPx  = (el.schriftGroesse || 3.5) * root.mmToPx * root.zoom
                        var nLines = nText.split("\n")
                        var nLineH = nFsPx * 1.3
                        var nPad   = Math.max(4, nFsPx * 0.35)

                        ctx.save()
                        ctx.beginPath()
                        ctx.rect(nRx + 1, nRy + 1, nRw - 2, nRh - 2)
                        ctx.clip()

                        ctx.fillStyle    = el.textFarbe || el.strichFarbe || "#cccc22"
                        ctx.font         = nFsPx + "px sans-serif"
                        ctx.textBaseline = "top"
                        ctx.textAlign    = "left"

                        for (var nLi = 0; nLi < nLines.length; nLi++) {
                            if (nRy + nPad + nLi * nLineH > nRy + nRh - nPad) break
                                ctx.fillText(nLines[nLi], nRx + nPad, nRy + nPad + nLi * nLineH)
                            }
                        }
                        ctx.restore()
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

                    // Klemmen-Anschluss: Bezeichnung + BMK neben dem Symbol
                    if (!vorschau && el.symbolId === "klemme_anschluss") {
                        var kaed   = el.extraDaten || {}
                        var kaAnz  = kaed.anschlussBezeichnung || ""
                        var kaBmk  = kaed.bmk || ""
                        var kaFs   = Math.max(7, Math.round(2.0 * root.mmToPx * root.zoom))
                        var kaBmkFs = Math.max(6, Math.round(1.5 * root.mmToPx * root.zoom))
                        var kaRot  = ((el.rotation || 0) % 360 + 360) % 360
                        var kaSenk = (kaRot === 90 || kaRot === 270)
                        var kaCx   = (vx1 + vx2) / 2
                        var kaCy   = (vy1 + vy2) / 2
                        ctx.save()
                        ctx.globalAlpha = 1.0
                        ctx.strokeStyle = "#000000"; ctx.lineWidth = 3; ctx.lineJoin = "round"
                        if (kaSenk) {
                            var kaX = Math.max(vx1, vx2) + 4 * root.zoom
                            if (kaAnz !== "") {
                                ctx.font = "bold " + kaFs + "px sans-serif"
                                ctx.textAlign = "left"; ctx.textBaseline = "middle"
                                var kaAy = kaBmk !== "" ? kaCy - kaBmkFs * 0.6 : kaCy
                                ctx.strokeText(kaAnz, kaX, kaAy)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#90e0a0"
                                ctx.fillText(kaAnz, kaX, kaAy)
                            }
                            if (kaBmk !== "") {
                                ctx.font = kaBmkFs + "px sans-serif"
                                ctx.textAlign = "left"; ctx.textBaseline = "middle"
                                var kaBmkY = kaAnz !== "" ? kaCy + kaBmkFs * 0.8 : kaCy
                                ctx.strokeText(kaBmk, kaX, kaBmkY)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#a0c0e0"
                                ctx.fillText(kaBmk, kaX, kaBmkY)
                            }
                        } else {
                            var kaY = Math.min(vy1, vy2) - 3 * root.zoom
                            if (kaAnz !== "") {
                                ctx.font = "bold " + kaFs + "px sans-serif"
                                ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                                ctx.strokeText(kaAnz, kaCx, kaY)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#90e0a0"
                                ctx.fillText(kaAnz, kaCx, kaY)
                            }
                            if (kaBmk !== "") {
                                ctx.font = kaBmkFs + "px sans-serif"
                                ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                                var kaBmkYh = kaY - kaFs - 1
                                ctx.strokeText(kaBmk, kaCx, kaBmkYh)
                                ctx.fillStyle = gewaehlt ? "#f0a030" : "#a0c0e0"
                                ctx.fillText(kaBmk, kaCx, kaBmkYh)
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
                    || el.typ==="makrokasten" || el.typ==="bild")
                return [Qt.point(el.x1,el.y1), Qt.point(el.x2,el.y1),
                        Qt.point(el.x2,el.y2), Qt.point(el.x1,el.y2)]
            if (el.typ==="kreis")    return [Qt.point(el.x1,el.y1), Qt.point(el.x2,el.y2)]
            if (el.typ==="symbol") return []  // Größe ist DB-definiert, kein Resize
            return []
        }

        // ── Auto-Verbindungen ─────────────────────────────────
        // Berechnet Linien zwischen Pins die auf gleicher H- oder V-Lane liegen.
        // Pins mit richtung:"H" nehmen nur an H-Lanes teil, richtung:"V" nur an V-Lanes.
        // Pins ohne richtung nehmen an beiden teil (Kompatibilität mit bestehenden Symbolen).
        //
        // Bei Rotation 90° / 270° tauschen H↔V (Richtungsvektor dreht sich 90°).
        // Bei 0° / 180° bleibt die Richtung gleich.
        function pinEffektiveRichtung(richtung, rotation) {
            if (!richtung) return ""
            var rot = ((rotation || 0) % 360 + 360) % 360
            if (rot === 90 || rot === 270)
                return richtung === "H" ? "V" : "H"
            return richtung
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

        function autoVerbindungenBerechnen() {
            var elemente = elementeModel.snapshot()
            // ── 1. Alle Pin-Weltpositionen mit Rolle und Quell-Signaltyp ──
            var allePins = []
            for (var i = 0; i < elemente.length; i++) {
                var el = elemente[i]
                if (el.typ !== "symbol") continue
                var elPins = el.symbolId === "querverweis"
                             ? drawCanvas.querverweisPin(el)
                             : symbolDefinitionModel.pinsForSymbol(el.symbolId || "")
                var rad  = (el.rotation || 0) * Math.PI / 180
                var cosR = Math.cos(rad), sinR = Math.sin(rad)

                // Rolle des Elements bestimmen
                var rolle = symbolDefinitionModel.rolleForSymbol(el.symbolId || "")
                if (rolle === "variabel") {
                    var edV = el.extraDaten || {}
                    rolle = edV.rolle || "ziel"
                }
                // Signaltyp nur relevant wenn Quelle
                var quellSig = "neutral"
                if (rolle === "quelle") {
                    var edQ = el.extraDaten || {}
                    quellSig = edQ.signaltyp || "neutral"
                }

                for (var pi = 0; pi < elPins.length; pi++) {
                    var pos = root.pinWeltPos(el, elPins[pi].x, elPins[pi].y)
                    var effRichtung = drawCanvas.pinEffektiveRichtung(
                                          elPins[pi].richtung || "",
                                          el.rotation || 0)
                    var offenEff = null
                    if (elPins[pi].offen) {
                        var o = elPins[pi].offen
                        var ox = el.spiegelX ? -o.x : o.x
                        var oy = el.spiegelY ? -o.y : o.y
                        offenEff = { x: ox * cosR - oy * sinR,
                                     y: ox * sinR + oy * cosR }
                    }
                    allePins.push({ x: pos.x, y: pos.y, elIdx: i,
                                    richtung: effRichtung, offenEff: offenEff,
                                    rolle: rolle, quellSig: quellSig })
                }
            }

            var verbindungen = []
            var eps = 0.1

            // ── 2. Blockierende Elemente (Unterbrechung + Querverweis) ──
            var unterbrechungen = []
            for (var ui = 0; ui < elemente.length; ui++) {
                var uel = elemente[ui]
                if (uel.typ !== "symbol" || (uel.symbolId !== "unterbrechung" && uel.symbolId !== "querverweis")) continue
                var ucx = (uel.x1 + uel.x2) / 2, ucy = (uel.y1 + uel.y2) / 2
                var uhw = Math.abs(uel.x2 - uel.x1) / 2, uhh = Math.abs(uel.y2 - uel.y1) / 2
                unterbrechungen.push({ cx: ucx, cy: ucy, hw: uhw, hh: uhh })
            }

            function hBlockiert(ax, bx, y) {
                var xMin = Math.min(ax, bx), xMax = Math.max(ax, bx)
                for (var bi = 0; bi < unterbrechungen.length; bi++) {
                    var u = unterbrechungen[bi]
                    if (Math.abs(u.cy - y) <= u.hh + root.gridPx * 0.5
                            && u.cx > xMin && u.cx < xMax) return true
                }
                return false
            }
            function vBlockiert(x, ay, by) {
                var yMin = Math.min(ay, by), yMax = Math.max(ay, by)
                for (var bi2 = 0; bi2 < unterbrechungen.length; bi2++) {
                    var u2 = unterbrechungen[bi2]
                    if (Math.abs(u2.cx - x) <= u2.hw + root.gridPx * 0.5
                            && u2.cy > yMin && u2.cy < yMax) return true
                }
                return false
            }

            // ── 3. H-Lanes ───────────────────────────────────────
            var hLanes = {}
            for (var pi2 = 0; pi2 < allePins.length; pi2++) {
                var p = allePins[pi2]
                if (p.richtung === "V") continue
                var yKey = Math.round(p.y / root.gridPx)
                if (!hLanes[yKey]) hLanes[yKey] = []
                hLanes[yKey].push(p)
            }
            for (var yKey in hLanes) {
                var lane = hLanes[yKey]
                if (lane.length < 2) continue
                lane.sort(function(a, b) { return a.x - b.x })
                for (var li = 0; li < lane.length - 1; li++) {
                    var a = lane[li], b = lane[li+1]
                    if (a.elIdx === b.elIdx) continue
                    var aOk = (!a.offenEff || a.offenEff.x >  eps)
                    var bOk = (!b.offenEff || b.offenEff.x < -eps)
                    if (aOk && bOk && !hBlockiert(a.x, b.x, a.y))
                        verbindungen.push({ x1: a.x, y1: a.y, x2: b.x, y2: b.y,
                                            elIdxA: a.elIdx, rolleA: a.rolle, quellSigA: a.quellSig,
                                            elIdxB: b.elIdx, rolleB: b.rolle, quellSigB: b.quellSig,
                                            signaltyp: "neutral" })
                }
            }

            // ── 4. V-Lanes ───────────────────────────────────────
            var vLanes = {}
            for (var pi3 = 0; pi3 < allePins.length; pi3++) {
                var pv = allePins[pi3]
                if (pv.richtung === "H") continue
                var xKey = Math.round(pv.x / root.gridPx)
                if (!vLanes[xKey]) vLanes[xKey] = []
                vLanes[xKey].push(pv)
            }
            for (var xKey in vLanes) {
                var vlane = vLanes[xKey]
                if (vlane.length < 2) continue
                vlane.sort(function(a, b) { return a.y - b.y })
                for (var vli = 0; vli < vlane.length - 1; vli++) {
                    var va = vlane[vli], vb = vlane[vli+1]
                    if (va.elIdx === vb.elIdx) continue
                    var vaOk = (!va.offenEff || va.offenEff.y >  eps)
                    var vbOk = (!vb.offenEff || vb.offenEff.y < -eps)
                    if (vaOk && vbOk && !vBlockiert(va.x, va.y, vb.y))
                        verbindungen.push({ x1: va.x, y1: va.y, x2: vb.x, y2: vb.y,
                                            elIdxA: va.elIdx, rolleA: va.rolle, quellSigA: va.quellSig,
                                            elIdxB: vb.elIdx, rolleB: vb.rolle, quellSigB: vb.quellSig,
                                            signaltyp: "neutral" })
                }
            }

            // ── 4b. Querverweis-Signalname-Pairing ──────────────
            // suchmodus "signal": Match nur per Signalname (projektweiter Scope)
            // suchmodus "bmk":    Match per Signalname + Anlage+Ort-Kontext
            var qvBySignal = {}
            for (var qvI = 0; qvI < elemente.length; qvI++) {
                var qvEl = elemente[qvI]
                if (qvEl.typ !== "symbol" || qvEl.symbolId !== "querverweis") continue
                var qvSn = (qvEl.extraDaten && qvEl.extraDaten.signalname) || ""
                if (!qvSn) continue
                var qvMode = (qvEl.extraDaten && qvEl.extraDaten.suchmodus) || "signal"
                var qvKey  = qvSn
                if (qvMode === "bmk") {
                    var qvAO = root.anlageOrtFuer(qvEl)
                    qvKey = qvSn + "|" + qvAO.anlage + "+" + qvAO.ort
                }
                if (!qvBySignal[qvKey]) qvBySignal[qvKey] = []
                qvBySignal[qvKey].push(qvI)
            }
            for (var qvSn2 in qvBySignal) {
                var grp = qvBySignal[qvSn2]
                for (var grpI = 1; grpI < grp.length; grpI++) {
                    var qvA = elemente[grp[0]]
                    var qvB = elemente[grp[grpI]]
                    var qvPinAx = (qvA.extraDaten && qvA.extraDaten.richtung === "eingang") ? 1.0 : 0.0
                    var qvPinBx = (qvB.extraDaten && qvB.extraDaten.richtung === "eingang") ? 1.0 : 0.0
                    var posQvA = root.pinWeltPos(qvA, qvPinAx, 0.5)
                    var posQvB = root.pinWeltPos(qvB, qvPinBx, 0.5)
                    verbindungen.push({
                        x1: posQvA.x, y1: posQvA.y, x2: posQvB.x, y2: posQvB.y,
                        elIdxA: grp[0], rolleA: "durchleiter", quellSigA: "neutral",
                        elIdxB: grp[grpI], rolleB: "durchleiter", quellSigB: "neutral",
                        signaltyp: "neutral", logisch: true
                    })
                }
            }

            // ── 5. Potenzial-Propagation (BFS von Quellen) ───────
            if (verbindungen.length > 0) {
                // Adjazenzliste: elIdx → [{nb, ci}]
                var adj = {}
                for (var ci = 0; ci < verbindungen.length; ci++) {
                    var c = verbindungen[ci]
                    if (!adj[c.elIdxA]) adj[c.elIdxA] = []
                    if (!adj[c.elIdxB]) adj[c.elIdxB] = []
                    adj[c.elIdxA].push({ nb: c.elIdxB, ci: ci })
                    adj[c.elIdxB].push({ nb: c.elIdxA, ci: ci })
                }
                // Quellen in Queue laden
                var besucht = {}, queue = []
                for (var qi = 0; qi < verbindungen.length; qi++) {
                    var qc = verbindungen[qi]
                    if (qc.rolleA === "quelle" && besucht[qc.elIdxA] === undefined) {
                        besucht[qc.elIdxA] = qc.quellSigA; queue.push({ idx: qc.elIdxA, sig: qc.quellSigA })
                    }
                    if (qc.rolleB === "quelle" && besucht[qc.elIdxB] === undefined) {
                        besucht[qc.elIdxB] = qc.quellSigB; queue.push({ idx: qc.elIdxB, sig: qc.quellSigB })
                    }
                }
                // BFS
                while (queue.length > 0) {
                    var item = queue.shift()
                    var curIdx = item.idx, curSig = item.sig
                    var nbList = adj[curIdx] || []
                    for (var ni = 0; ni < nbList.length; ni++) {
                        var nb = nbList[ni]
                        var conn = verbindungen[nb.ci]
                        // Verbindungsfarbe setzen oder Konflikt markieren
                        if (conn.signaltyp === "neutral")          conn.signaltyp = curSig
                        else if (conn.signaltyp !== curSig)        conn.signaltyp = "konflikt"
                        // Nachbar-Rolle bestimmen
                        var nbRolle = (conn.elIdxA === curIdx) ? conn.rolleB : conn.rolleA
                        if (nbRolle === "verbraucher" || nbRolle === "ziel") continue
                        if (besucht[nb.nb] !== undefined) {
                            if (besucht[nb.nb] !== curSig) conn.signaltyp = "konflikt"
                            continue
                        }
                        besucht[nb.nb] = curSig
                        queue.push({ idx: nb.nb, sig: curSig })
                    }
                }
            }

            // Netze mit Ziel-Elementen aber ohne jede Quelle als "unversorgt" markieren
            for (var ci2 = 0; ci2 < verbindungen.length; ci2++) {
                var c2 = verbindungen[ci2]
                if (c2.signaltyp !== "neutral") continue
                // Wurde keiner der beiden Endpunkte vom BFS einer Quelle erreicht?
                if (besucht[c2.elIdxA] !== undefined || besucht[c2.elIdxB] !== undefined) continue
                var hatZiel = (c2.rolleA === "ziel" || c2.rolleA === "verbraucher" ||
                               c2.rolleB === "ziel" || c2.rolleB === "verbraucher")
                if (hatZiel) c2.signaltyp = "unversorgt"
            }

            return verbindungen
        }

        // Gruppiert Auto-Verbindungssegmente zu elektrischen Netzen.
        // Gibt [{netKey, bezeichnung, signaltyp, farbe, querschnitt,
        //        verbindungId, segmente:[{x1,y1,x2,y2}], querverweise:[...]}] zurück.
        function autoNetzeBerechnen() {
            var vbs = autoVerbindungenBerechnen()
            if (vbs.length === 0) return []
            var elemente = elementeModel.snapshot()

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
                ctx.textAlign    = nx >= 0 ? "left" : "right"
                ctx.textBaseline = "middle"
                var lx = vx + nx * (kTickLen + 3)
                var ly = vy + ny * (kTickLen + 3)
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
            drawCanvas.drawNormblattAussenoverlay(ctx)
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
    }

    // --------------------------------------------------------
    // Werkzeugleiste (links)
    // --------------------------------------------------------
    CanvasWerkzeugLeiste {
        id: werkzeugLeiste
        canvas: root
        visible: root.seiteId >= 0
        anchors { top: headerBar.bottom; bottom: footerBar.top; left: parent.left }
        onBildWerkzeugAngefordert: bildDialog.open()
    }

    // --------------------------------------------------------
    // Interaktionsfläche
    // WICHTIG: rechts NICHT über das Panel – so fressen wir keine
    // Panel-Klicks und das Panel bleibt beim Editieren sichtbar.
    // --------------------------------------------------------
    MouseArea {
        id: interaktionArea
        anchors {
            top:    headerBar.bottom
            bottom: footerBar.top
            left:   werkzeugLeiste.right
            // Endet an der linken Kante des Panels, wenn dieses sichtbar ist
            right:  eigenschaftenPanel.visible ? eigenschaftenPanel.left : parent.right
        }
        enabled:         root.seiteId >= 0
        acceptedButtons: Qt.LeftButton
        hoverEnabled:    true
        cursorShape: {
            if (root.aktivesWerkzeug !== "zeiger")  return Qt.CrossCursor
            if (root.aktiverGriff >= 0)             return Qt.SizeAllCursor
            if (root.amVerschieben)                 return Qt.SizeAllCursor
            if (root.mausUeberGriff)                return Qt.SizeAllCursor
            if (root.mausUeberElement)              return Qt.SizeAllCursor
            return Qt.ArrowCursor
        }

        // Hilfsfunktionen für Koordinatenumrechnung
        function toViewport(mx, my) {
            var p = interaktionArea.mapToItem(root, mx, my); return Qt.point(p.x, p.y)
        }
        function toWelt(mx, my) {
            var vp = toViewport(mx, my)
            var w  = root.viewportZuWelt(vp.x, vp.y)
            return root.rastend ? root.rasterPunkt(w.x, w.y) : w
        }

        onPositionChanged: function(mouse) {
            if (root.aktivesWerkzeug === "zeiger") {
                var vp = toViewport(mouse.x, mouse.y)

                // Rubber-Band: Auswahl-Rechteck live aktualisieren
                if (root.amRubberband) {
                    root.rubberbandRect = { x1: root.rubberbandVpX, y1: root.rubberbandVpY,
                                            x2: vp.x, y2: vp.y }
                    drawCanvas.requestPaint()
                    return
                }

                // Handle-Drag: Griff zieht → Größe anpassen (nur Einzelauswahl)
                if (root.aktiverGriff >= 0 && root.ausgewaehlt >= 0) {
                    var wgRaw = toWelt(mouse.x, mouse.y)
                    var wg    = root.rastend ? root.rasterPunkt(wgRaw.x, wgRaw.y) : wgRaw
                    var eg = elementeModel.element(root.ausgewaehlt)
                    var upd = {}; for (var kk in eg) upd[kk] = eg[kk]
                    var g = root.aktiverGriff
                    if (eg.typ === "linie" || eg.typ === "kabellinie") {
                        if (g === 0) { upd.x1 = wg.x; upd.y1 = wg.y }
                        else         { upd.x2 = wg.x; upd.y2 = wg.y }
                    } else if (eg.typ === "rechteck" || eg.typ === "geraetekasten"
                               || eg.typ === "strukturkasten" || eg.typ === "makrokasten"
                               || eg.typ === "notiz") {
                        if      (g === 0) { upd.x1 = wg.x; upd.y1 = wg.y }
                        else if (g === 1) { upd.x2 = wg.x; upd.y1 = wg.y }
                        else if (g === 2) { upd.x2 = wg.x; upd.y2 = wg.y }
                        else              { upd.x1 = wg.x; upd.y2 = wg.y }
                    } else if (eg.typ === "kreis") {
                        if (g === 0) {
                            var rdx = eg.x2 - eg.x1; var rdy = eg.y2 - eg.y1
                            upd.x1 = wg.x; upd.y1 = wg.y
                            upd.x2 = wg.x + rdx; upd.y2 = wg.y + rdy
                        } else {
                            upd.x2 = wg.x; upd.y2 = wg.y
                        }
                    } else if (eg.typ === "polygonlinie") {
                        var plNeu = eg.punkte.map(function(p, pi) {
                            return pi === g ? { x: wg.x, y: wg.y } : p
                        })
                        upd.punkte = plNeu
                        var plMnX = plNeu[0].x, plMnY = plNeu[0].y, plMxX = plNeu[0].x, plMxY = plNeu[0].y
                        for (var plBi = 1; plBi < plNeu.length; plBi++) {
                            if (plNeu[plBi].x < plMnX) plMnX = plNeu[plBi].x
                            if (plNeu[plBi].y < plMnY) plMnY = plNeu[plBi].y
                            if (plNeu[plBi].x > plMxX) plMxX = plNeu[plBi].x
                            if (plNeu[plBi].y > plMxY) plMxY = plNeu[plBi].y
                        }
                        upd.x1 = plMnX; upd.y1 = plMnY; upd.x2 = plMxX; upd.y2 = plMxY
                    } else if (eg.typ === "bild") {
                        var origW = Math.abs(eg.x2 - eg.x1), origH = Math.abs(eg.y2 - eg.y1)
                        var ratio = origH > 0 ? origW / origH : 1
                        if      (g === 0) { upd.x1 = wg.x; upd.y1 = wg.y }
                        else if (g === 1) { upd.x2 = wg.x; upd.y1 = wg.y }
                        else if (g === 2) { upd.x2 = wg.x; upd.y2 = wg.y }
                        else              { upd.x1 = wg.x; upd.y2 = wg.y }
                        if (eg.proportional && origW > 0 && origH > 0) {
                            var newW = Math.abs(upd.x2 - upd.x1), newH = Math.abs(upd.y2 - upd.y1)
                            // Passe die kleinere Achse an – Anker-Ecke bleibt fest
                            if (g === 0) {
                                var hFromW = newW / ratio
                                upd.y1 = upd.y2 - hFromW
                            } else if (g === 1) {
                                upd.y1 = upd.y2 - newW / ratio
                            } else if (g === 2) {
                                upd.y2 = upd.y1 + newW / ratio
                            } else {
                                upd.y2 = upd.y1 + newW / ratio
                            }
                        }
                    }
                    var gIdx = root.ausgewaehlt
                    elementeModel.elementAktualisieren(gIdx, upd)
                    root.auswahl  = [gIdx]
                    drawCanvas.requestPaint()
                    return
                }

                // Hover-Cursor: Griff oder Element unter Maus?
                if (!root.amVerschieben) {
                    root.mausUeberGriff   = (root.griffBeiPosition(vp.x, vp.y) >= 0)
                    root.mausUeberElement = (root.elementBeiPosition(vp.x, vp.y) >= 0)
                }

                // Element(e) verschieben (nur wenn bereits selektiert + Drag-Schwelle)
                if (root.verschiebenErlaubt && root.auswahl.length > 0) {
                    var dvpX = vp.x - root.verschiebenMausVpX
                    var dvpY = vp.y - root.verschiebenMausVpY

                    if (!root.amVerschieben && Math.sqrt(dvpX*dvpX + dvpY*dvpY) < 5)
                        return

                    root.amVerschieben = true

                    var dwX = dvpX / root.zoom
                    var dwY = dvpY / root.zoom

                    // Snap: Referenzpunkt (erstes Element) einrasten
                    var sp0 = root.verschiebenStartPos ? root.verschiebenStartPos[0]
                                                        : { x1: root.verschiebenStartX1, y1: root.verschiebenStartY1 }
                    if (root.rastend) {
                        // Aderdefinition: Mittelpunkt einrasten, nicht Ecke
                        var snapEl0 = root.auswahl.length > 0 ? elementeModel.element(root.auswahl[0]) : null
                        var snapOffX = 0, snapOffY = 0
                        if (snapEl0 && snapEl0.typ === "symbol" && snapEl0.symbolId === "aderdefinition") {
                            snapOffX = (snapEl0.x2 - snapEl0.x1) / 2
                            snapOffY = (snapEl0.y2 - snapEl0.y1) / 2
                        }
                        var sn = root.rasterPunkt(sp0.x1 + dwX + snapOffX, sp0.y1 + dwY + snapOffY)
                        dwX = sn.x - snapOffX - sp0.x1; dwY = sn.y - snapOffY - sp0.y1
                    }

                    // Alle selektierten Elemente live verschieben (kein Undo-Schritt)
                    var selArr  = root.auswahl.slice()
                    var startArr = root.verschiebenStartPos
                    var neu = elementeModel.snapshot().map(function(el, i) {
                        var si = selArr.indexOf(i)
                        if (si < 0) return el
                        var upd = {}; for (var k in el) upd[k] = el[k]
                        var sp = startArr ? startArr[si]
                                          : { x1: root.verschiebenStartX1, y1: root.verschiebenStartY1,
                                              x2: root.verschiebenStartX2, y2: root.verschiebenStartY2 }
                        upd.x1 = sp.x1 + dwX; upd.y1 = sp.y1 + dwY
                        upd.x2 = sp.x2 + dwX; upd.y2 = sp.y2 + dwY
                        if (el.typ === "polygonlinie" && sp.punkte)
                            upd.punkte = sp.punkte.map(function(p) { return { x: p.x + dwX, y: p.y + dwY } })
                        return upd
                    })
                    elementeModel.fromVariantList(neu)
                    root.auswahl  = selArr
                    drawCanvas.requestPaint()
                }
                return
            }

            // Zeichenwerkzeug: Koordinatenanzeige + Vorschau
            var w = toWelt(mouse.x, mouse.y)
            footerBar.koordinatenText =
                "X " + Math.round(w.x / root.mmToPx) + " mm\u2002"
                + "Y " + Math.round(w.y / root.mmToPx) + " mm"

            // Symbol-Werkzeug: Vorschau folgt dem Cursor
            if (root.aktivesWerkzeug === "symbol" && root.paletteSymbolId !== "") {
                root.letzteMausWeltX = w.x; root.letzteMausWeltY = w.y
                root.vorschau = root.symbolVorschauErstellen(w.x, w.y)
                drawCanvas.requestPaint()
                return
            }

            // Makro-Einfügen: Vorschau-Rechteck folgt dem Cursor
            if (root.aktivesWerkzeug === "makroEinfuegen" && root.makroEinfuegenId > 0) {
                var makroMeta = db.makroListe().find(function(m) { return m.id === root.makroEinfuegenId }) || null
                var mkW = makroMeta ? makroMeta.kastenBreite || (root.gridPx * 10) : root.gridPx * 10
                var mkH = makroMeta ? makroMeta.kastenHoehe  || (root.gridPx * 8)  : root.gridPx * 8
                root.vorschau = { typ: "makrokasten",
                                  x1: w.x, y1: w.y,
                                  x2: w.x + mkW, y2: w.y + mkH,
                                  strichFarbe: "#aa44cc", fuell: false,
                                  opazitaet: 1.0,
                                  extraDaten: { name: root.makroEinfuegenName, makroId: root.makroEinfuegenId } }
                drawCanvas.requestPaint()
                return
            }

            // Bild-Werkzeug: Vorschau folgt dem Cursor
            if (root.aktivesWerkzeug === "bild" && root.paletteImageData !== "") {
                var bDefW = root.gridPx * 8; var bDefH = root.gridPx * 8
                root.vorschau = { typ: "bild", bildDaten: root.paletteImageData,
                                  x1: w.x - bDefW/2, y1: w.y - bDefH/2,
                                  x2: w.x + bDefW/2, y2: w.y + bDefH/2,
                                  opazitaet: 1.0 }
                drawCanvas.requestPaint()
                return
            }

            if (root.amPolyZeichnen) {
                root.polyCursorWelt = root.rastend ? root.rasterPunkt(w.x, w.y) : w
                drawCanvas.requestPaint()
                return
            }
            if (!root.amZeichnen) return
            root.vorschau = { typ: root.aktivesWerkzeug,
                              x1: root.zeichenStartX, y1: root.zeichenStartY,
                              x2: w.x, y2: w.y }
            drawCanvas.requestPaint()
        }

        onExited: {
            root.mausUeberElement = false
            if (root.aktivesWerkzeug !== "zeiger") footerBar.koordinatenText = ""
            if (root.aktivesWerkzeug === "symbol" || root.aktivesWerkzeug === "bild")
                { root.vorschau = null; drawCanvas.requestPaint() }
        }

        onPressed: function(mouse) {
            root.forceActiveFocus()
            if (root.aktivesWerkzeug === "zeiger") {
                var vp = toViewport(mouse.x, mouse.y)

                // Griff-Klick prüfen (höhere Priorität als Element-Klick)
                if (root.ausgewaehlt >= 0) {
                    var griff = root.griffBeiPosition(vp.x, vp.y)
                    if (griff >= 0) {
                        root.aktiverGriff      = griff
                        root.schnapshotVorMove = elementeModel.snapshot()
                        return
                    }
                }

                var idx = root.elementBeiPosition(vp.x, vp.y)
                root.aktiverGriff = -1
                var ctrlGehalten = (mouse.modifiers & Qt.ControlModifier) !== 0

                if (idx < 0) {
                    // Kein Element – prüfen ob Auto-Verbindung getroffen
                    var conn = drawCanvas.verbindungBeiPosition(vp.x, vp.y)
                    if (conn !== null) {
                        root.auswahl = []
                        root.ausgewaehltVerbindung = conn
                        drawCanvas.requestPaint()
                        return
                    }
                    root.ausgewaehltVerbindung = null
                    // Leere Fläche: Rubber-Band starten (Auswahl erst bei Release festlegen)
                    root.auswahl            = []
                    root.amRubberband       = true
                    root.rubberbandVpX      = vp.x
                    root.rubberbandVpY      = vp.y
                    root.rubberbandRect     = null
                    root.verschiebenErlaubt = false
                } else if (ctrlGehalten) {
                    root.ausgewaehltVerbindung = null
                    // Ctrl + Klick: Element zur Auswahl hinzufügen / daraus entfernen
                    var sel = root.auswahl.slice()
                    var pos = sel.indexOf(idx)
                    if (pos >= 0) sel.splice(pos, 1)
                    else          sel.push(idx)
                    root.auswahl            = sel
                    root.verschiebenErlaubt = false
                } else if (root.auswahl.indexOf(idx) >= 0) {
                    root.ausgewaehltVerbindung = null
                    // Bereits selektiertes Element → Verschieben aller Ausgewählten vorbereiten
                    root.verschiebenErlaubt  = true
                    root.amVerschieben       = false
                    root.verschiebenMausVpX  = vp.x
                    root.verschiebenMausVpY  = vp.y
                    root.verschiebenStartPos = root.auswahl.map(function(si) {
                        var e = elementeModel.element(si)
                        var snap = { x1: e.x1, y1: e.y1, x2: e.x2, y2: e.y2 }
                        if (e.typ === "polygonlinie" && e.punkte) snap.punkte = JSON.parse(JSON.stringify(e.punkte))
                        return snap
                    })
                    var elV = elementeModel.element(idx)
                    root.verschiebenStartX1 = elV.x1; root.verschiebenStartY1 = elV.y1
                    root.verschiebenStartX2 = elV.x2; root.verschiebenStartY2 = elV.y2
                    root.schnapshotVorMove  = elementeModel.snapshot()
                } else {
                    root.ausgewaehltVerbindung = null
                    // Anderes Element → Einzelauswahl
                    root.auswahl            = [idx]
                    root.verschiebenErlaubt = false
                }
                drawCanvas.requestPaint()
            } else if (root.aktivesWerkzeug === "symbol" && root.paletteSymbolId !== "") {
                // Symbol sofort platzieren (kein Drag nötig)
                var wSym = toWelt(mouse.x, mouse.y)
                var prev = root.symbolVorschauErstellen(wSym.x, wSym.y)
                var elSym = {
                    typ: "symbol",
                    x1: prev.x1, y1: prev.y1,
                    x2: prev.x2, y2: prev.y2,
                    symbolId:       root.paletteSymbolId,
                    rotation:       root.paletteSymbolRotation,
                    spiegelX:       false,
                    spiegelY:       false,
                    extraDaten:     JSON.parse(JSON.stringify(root.paletteExtraDaten)),
                    strichFarbe:    root.stilVorlage.strichFarbe,
                    strichBreite:   root.stilVorlage.strichBreite,
                    strichArt:      root.stilVorlage.strichArt,
                    fuell:          false,
                    fuellFarbe:     root.stilVorlage.fuellFarbe,
                    fuellOpazitaet: root.stilVorlage.fuellOpazitaet,
                    opazitaet:      root.stilVorlage.opazitaet,
                    eckenRadius:    0
                }
                root.aktionAusfuehren(elementeModel.snapshot().concat([elSym]))
                root.aktivesWerkzeug = "zeiger"
                var newIdxSym = elementeModel.anzahl - 1
                root.auswahl         = [newIdxSym]
                var vprSym = toViewport(mouse.x, mouse.y)
                var newElSym = elementeModel.element(newIdxSym)
                root.amVerschieben       = false
                root.verschiebenMausVpX  = vprSym.x
                root.verschiebenMausVpY  = vprSym.y
                root.verschiebenStartX1  = newElSym.x1; root.verschiebenStartY1 = newElSym.y1
                root.verschiebenStartX2  = newElSym.x2; root.verschiebenStartY2 = newElSym.y2
                root.verschiebenStartPos = [{ x1: newElSym.x1, y1: newElSym.y1, x2: newElSym.x2, y2: newElSym.y2 }]
                root.schnapshotVorMove   = elementeModel.snapshot()
                root.vorschau = null
                drawCanvas.requestPaint()
            } else if (root.aktivesWerkzeug === "bild" && root.paletteImageData !== "") {
                // Bild platzieren
                var wBild = toWelt(mouse.x, mouse.y)
                var bW2 = root.gridPx * 8; var bH2 = root.gridPx * 8
                var elBild = {
                    typ:            "bild",
                    x1:             wBild.x - bW2/2,  y1: wBild.y - bH2/2,
                    x2:             wBild.x + bW2/2,  y2: wBild.y + bH2/2,
                    bildDaten:      root.paletteImageData,
                    strichFarbe:    root.stilVorlage.strichFarbe,
                    strichBreite:   root.stilVorlage.strichBreite,
                    strichArt:      root.stilVorlage.strichArt,
                    fuell:          false,
                    fuellFarbe:     "#000000",
                    fuellOpazitaet: 0,
                    opazitaet:      1.0,
                    eckenRadius:    0,
                    rotation:          0,
                    spiegelX:          false,
                    spiegelY:          false,
                    proportional:      false,
                    ausschnittLinks:   0,
                    ausschnittRechts:  0,
                    ausschnittOben:    0,
                    ausschnittUnten:   0
                }
                root.aktionAusfuehren(elementeModel.snapshot().concat([elBild]))
                root.aktivesWerkzeug = "zeiger"
                var newIdxBild = elementeModel.anzahl - 1
                root.auswahl         = [newIdxBild]
                var vprBild = toViewport(mouse.x, mouse.y)
                var newElBild = elementeModel.element(newIdxBild)
                root.amVerschieben       = false
                root.verschiebenMausVpX  = vprBild.x
                root.verschiebenMausVpY  = vprBild.y
                root.verschiebenStartX1  = newElBild.x1; root.verschiebenStartY1 = newElBild.y1
                root.verschiebenStartX2  = newElBild.x2; root.verschiebenStartY2 = newElBild.y2
                root.verschiebenStartPos = [{ x1: newElBild.x1, y1: newElBild.y1, x2: newElBild.x2, y2: newElBild.y2 }]
                root.schnapshotVorMove   = elementeModel.snapshot()
                root.vorschau = null
                drawCanvas.requestPaint()
            } else if (root.aktivesWerkzeug === "makroEinfuegen" && root.makroEinfuegenId > 0) {
                // Makro an Klick-Position einfügen
                var wMk = toWelt(mouse.x, mouse.y)
                var newElIds = db.makroElementeEinfuegen(root.makroEinfuegenId, root.seiteId, wMk.x, wMk.y)
                if (newElIds.length > 0) {
                    elementeModel.laden(root.seiteId)
                    root.grafikSpeichernJetzt()
                }
                root.aktivesWerkzeug    = "zeiger"
                root.makroEinfuegenId   = 0
                root.makroEinfuegenName = ""
                root.vorschau = null
                drawCanvas.requestPaint()
            } else if (root.aktivesWerkzeug === "text") {
                // Text-Werkzeug: Editor am Klick-Punkt öffnen (neues Element)
                var wTxt = toWelt(mouse.x, mouse.y)
                var rTxt = root.rastend ? root.rasterPunkt(wTxt.x, wTxt.y) : wTxt
                root.textEditVpX    = mouse.x
                root.textEditVpY    = mouse.y
                root.textEditWeltX  = rTxt.x
                root.textEditWeltY  = rTxt.y
                root.textEditElIdx    = -1
                root.textEditSnapshot = elementeModel.snapshot()
                root.textEditAktiv    = true
                textEditor.text = ""
                textEditor.forceActiveFocus()
            } else if (root.aktivesWerkzeug === "polygonlinie") {
                var wPoly = toWelt(mouse.x, mouse.y)
                var rPoly = root.rastend ? root.rasterPunkt(wPoly.x, wPoly.y) : wPoly
                root.polyPunkte = root.polyPunkte.concat([{ x: rPoly.x, y: rPoly.y }])
                root.amPolyZeichnen = true
                root.polyCursorWelt = rPoly
                drawCanvas.requestPaint()
            } else {
                // Zeichnen starten
                var w = toWelt(mouse.x, mouse.y)
                root.zeichenStartX = w.x; root.zeichenStartY = w.y
                root.amZeichnen    = true
                root.vorschau      = { typ: root.aktivesWerkzeug, x1: w.x, y1: w.y, x2: w.x, y2: w.y }
                drawCanvas.requestPaint()
            }
        }

        onReleased: function(mouse) {
            if (root.aktivesWerkzeug === "zeiger") {

                // Rubber-Band abschließen → Elemente im Rechteck selektieren
                if (root.amRubberband) {
                    root.amRubberband = false
                    var rb = root.rubberbandRect
                    if (rb && (Math.abs(rb.x2 - rb.x1) > 5 || Math.abs(rb.y2 - rb.y1) > 5)) {
                        var rx1 = Math.min(rb.x1, rb.x2), ry1 = Math.min(rb.y1, rb.y2)
                        var rx2 = Math.max(rb.x1, rb.x2), ry2 = Math.max(rb.y1, rb.y2)
                        var gefunden = []
                        var _rbEls = elementeModel.snapshot()
                        for (var ri = 0; ri < _rbEls.length; ri++) {
                            var re = _rbEls[ri]
                            var ex1 = Math.min(re.x1, re.x2) * root.zoom + root.worldX
                            var ey1 = Math.min(re.y1, re.y2) * root.zoom + root.worldY
                            var ex2 = Math.max(re.x1, re.x2) * root.zoom + root.worldX
                            var ey2 = Math.max(re.y1, re.y2) * root.zoom + root.worldY
                            if (ex1 >= rx1 && ey1 >= ry1 && ex2 <= rx2 && ey2 <= ry2)
                                gefunden.push(ri)
                        }
                        root.auswahl = gefunden
                    }
                    root.rubberbandRect = null
                    drawCanvas.requestPaint()
                    return
                }

                // Griff losgelassen → Undo-Schritt speichern
                if (root.aktiverGriff >= 0) {
                    elementeModel.undoCheckpointFromSnapshot(root.schnapshotVorMove)
                    root.aktiverGriff = -1
                    if (root.ausgewaehlt >= 0 && root.ausgewaehlt < elementeModel.anzahl) {
                        var rEl = elementeModel.element(root.ausgewaehlt)
                        var vpR = toViewport(mouse.x, mouse.y)
                        root.verschiebenMausVpX  = vpR.x
                        root.verschiebenMausVpY  = vpR.y
                        root.verschiebenStartX1  = rEl.x1; root.verschiebenStartY1 = rEl.y1
                        root.verschiebenStartX2  = rEl.x2; root.verschiebenStartY2 = rEl.y2
                        root.verschiebenStartPos = [{ x1: rEl.x1, y1: rEl.y1, x2: rEl.x2, y2: rEl.y2 }]
                        root.schnapshotVorMove   = elementeModel.snapshot()
                        root.verschiebenErlaubt  = true
                    }
                    root.grafikSpeichernJetzt()
                    return
                }
                if (root.amVerschieben) {
                    elementeModel.undoCheckpointFromSnapshot(root.schnapshotVorMove)
                    root.amVerschieben = false
                    root.grafikSpeichernJetzt()
                }
                root.verschiebenErlaubt = false
                return
            }

            if (!root.amZeichnen) return
            var w  = toWelt(mouse.x, mouse.y)
            var el = Object.assign(
                { typ: root.aktivesWerkzeug, x1: root.zeichenStartX, y1: root.zeichenStartY, x2: w.x, y2: w.y },
                root.stilVorlage
            )
            // Bei Klick ohne Drag: Standard-Größe einsetzen
            if (Math.abs(el.x2-el.x1) <= 0.5 && Math.abs(el.y2-el.y1) <= 0.5) {
                var defS = root.gridPx * 2
                if (el.typ === "linie")         { el.x2 = el.x1 + defS;      el.y2 = el.y1 }
                else if (el.typ === "rechteck") { el.x2 = el.x1 + defS;      el.y2 = el.y1 + defS }
                else if (el.typ === "kreis")    { el.x2 = el.x1 + defS / 2;  el.y2 = el.y1 }
                else if (el.typ === "geraetekasten")  { el.x2 = el.x1 + defS * 3; el.y2 = el.y1 + defS * 2 }
                else if (el.typ === "strukturkasten") { el.x2 = el.x1 + defS * 5; el.y2 = el.y1 + defS * 4 }
                else if (el.typ === "makrokasten")    { el.x2 = el.x1 + defS * 5; el.y2 = el.y1 + defS * 4 }
                else if (el.typ === "notiz")          { el.x2 = el.x1 + defS * 4; el.y2 = el.y1 + defS * 3 }
            }
            // Starteigenschaften für Geräte-/Strukturkasten setzen
            if (el.typ === "geraetekasten") {
                el.strichFarbe    = "#cc7700"
                el.fuell          = true
                el.fuellFarbe     = "#331a00"
                el.fuellOpazitaet = 0.15
                el.extraDaten     = { bmk: "", bezeichnung: "" }
            } else if (el.typ === "strukturkasten") {
                el.strichFarbe    = "#00aacc"
                el.fuell          = false
                el.extraDaten     = { bezeichnung: "", anlage: "", ort: "", anlageUO: "", ortUO: "" }
            } else if (el.typ === "kabellinie") {
                el.strichFarbe = "#e07000"
                el.extraDaten  = { bezeichnung: "", kabeltyp: "", aderzahl: 0, querschnittMm2: 0 }
            } else if (el.typ === "makrokasten") {
                el.strichFarbe = "#aa44cc"
                el.fuell       = false
                el.extraDaten  = { name: "", beschreibung: "", kategorie: "", makroId: 0 }
            } else if (el.typ === "notiz") {
                el.strichFarbe    = "#cccc22"
                el.fuell          = true
                el.fuellFarbe     = "#1a1a00"
                el.fuellOpazitaet = 0.9
                el.strichBreite   = 3.0
                el.textInhalt     = "Notiz"
            }
            root.aktionAusfuehren(elementeModel.snapshot().concat([el]))
            // Nach dem Zeichnen → Zeiger-Werkzeug, neues Element auswählen
            root.aktivesWerkzeug = "zeiger"
            var newIdx = elementeModel.anzahl - 1
            root.auswahl = [newIdx]
            var vpr = toViewport(mouse.x, mouse.y)
            var newEl = elementeModel.element(newIdx)
            root.amVerschieben       = false
            root.verschiebenMausVpX  = vpr.x
            root.verschiebenMausVpY  = vpr.y
            root.verschiebenStartX1  = newEl.x1; root.verschiebenStartY1 = newEl.y1
            root.verschiebenStartX2  = newEl.x2; root.verschiebenStartY2 = newEl.y2
            root.verschiebenStartPos = [{ x1: newEl.x1, y1: newEl.y1, x2: newEl.x2, y2: newEl.y2 }]
            root.schnapshotVorMove   = elementeModel.snapshot()
            root.vorschau = null; root.amZeichnen = false
            drawCanvas.requestPaint()
            // Kabellinie-Dialog öffnen damit der Nutzer sofort Kabeldaten eingibt
            if (el.typ === "kabellinie") {
                kabellinieDialog.elementIndex    = newIdx
                kabellinieDialog.bezeichnung     = ""
                kabellinieDialog.kabeltyp        = ""
                kabellinieDialog.aderzahl        = 0
                kabellinieDialog.querschnittMm2  = 0
                kabellinieDialog.bauteilKabelId  = 0
                kabellinieDialog.vonOrt          = ""
                kabellinieDialog.nachOrt         = ""
                kabellinieDialog.bestehendesKabelId = 0
                kabellinieDialog.vorhandeneKabel = (root.projektId >= 0)
                                                   ? db.kabelListe(root.projektId) : []
                kabellinieDialog.open()
            }
            // Makrokasten: Dialog für Name/Beschreibung/Kategorie
            if (el.typ === "makrokasten") {
                makrobenennDialog.elementIndex = newIdx
                makrobenennDialog.open()
            }
        }

        onDoubleClicked: function(mouse) {
            // Polygonlinie abschließen.
            // onPressed hat den zweiten Klick als Duplikat hinzugefügt → letzten Punkt immer entfernen.
            if (root.aktivesWerkzeug === "polygonlinie" && root.amPolyZeichnen) {
                var pts = root.polyPunkte.slice()
                if (pts.length >= 1) pts = pts.slice(0, pts.length - 1)
                if (pts.length >= 2) {
                    // Bounding-Box für Move/Rubber-band
                    var minX = pts[0].x, minY = pts[0].y, maxX = pts[0].x, maxY = pts[0].y
                    for (var bi = 1; bi < pts.length; bi++) {
                        if (pts[bi].x < minX) minX = pts[bi].x
                        if (pts[bi].y < minY) minY = pts[bi].y
                        if (pts[bi].x > maxX) maxX = pts[bi].x
                        if (pts[bi].y > maxY) maxY = pts[bi].y
                    }
                    var elPoly = Object.assign(
                        { typ: "polygonlinie", punkte: pts,
                          x1: minX, y1: minY, x2: maxX, y2: maxY },
                        root.stilVorlage
                    )
                    root.aktionAusfuehren(elementeModel.snapshot().concat([elPoly]))
                    root.auswahl = [elementeModel.anzahl - 1]
                }
                root.amPolyZeichnen  = false
                root.polyPunkte      = []
                root.polyCursorWelt  = null
                root.aktivesWerkzeug = "zeiger"
                drawCanvas.requestPaint()
                return
            }
            if (root.aktivesWerkzeug !== "zeiger") return
            var vp  = toViewport(mouse.x, mouse.y)
            var idx = root.elementBeiPosition(vp.x, vp.y)
            if (idx < 0) return

            // Doppelklick auf Querverweis → Querverweis-Navigation zur Gegenseite
            var hit = elementeModel.element(idx)
            if (hit.typ === "symbol" && hit.symbolId === "querverweis") {
                root.auswahl = [idx]
                root.querverweisZurGegenseiteNavigieren()
                return
            }

            // Doppelklick auf Text- oder Notiz-Element → zum Bearbeiten öffnen
            if (hit.typ !== "text" && hit.typ !== "notiz") return
            var el = hit
            root.auswahl        = [idx]
            root.textEditWeltX  = el.x1
            root.textEditWeltY  = el.y1
            var vpos = root.weltZuViewport(el.x1, el.y1)
            root.textEditVpX    = vpos.x
            root.textEditVpY    = vpos.y
            root.textEditElIdx    = idx
            root.textEditSnapshot = elementeModel.snapshot()
            root.textEditAktiv    = true
            textEditor.text       = el.textInhalt || ""
            textEditor.forceActiveFocus()
            textEditor.selectAll()
        }
    }

    // --------------------------------------------------------
    // Pan – Rechts-/Mittelklick
    // --------------------------------------------------------
    DragHandler {
        id: panHandler
        target: null          // Wichtig: root-Item NICHT physisch verschieben
        enabled: root.seiteId >= 0
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        property real startX: 0; property real startY: 0
        onActiveChanged: { if (active) { startX = root.worldX; startY = root.worldY } }
        onTranslationChanged: {
            root.worldX = startX + translation.x
            root.worldY = startY + translation.y
            root.repaintAll()
        }
    }

    // --------------------------------------------------------
    // Rechtsklick-Kontextmenü
    // TapHandler koexistiert mit DragHandler (panHandler) für denselben Button:
    // Drag beyond threshold → Pan; sauberer Klick → Menü
    // --------------------------------------------------------
    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled:         root.seiteId >= 0
        onTapped: function(eventPoint) {
            if (root.aktivesWerkzeug !== "zeiger") return
            var vpX = eventPoint.position.x
            var vpY = eventPoint.position.y
            // Element unter Maus auto-selektieren wenn noch nicht in Auswahl
            var hitIdx = root.elementBeiPosition(vpX, vpY)
            if (hitIdx >= 0 && root.auswahl.indexOf(hitIdx) < 0)
                root.auswahl = [hitIdx]
            canvasKontextMenu.popup(vpX, vpY)
        }
    }

    Menu {
        id: canvasKontextMenu

        MenuItem {
            text:      "Kopieren\t(Ctrl+C)"
            enabled:   root.auswahl.length > 0
            onTriggered: root.kopieren(0)
        }
        MenuItem {
            text:      "Ausschneiden\t(Ctrl+X)"
            enabled:   root.auswahl.length > 0
            onTriggered: { root.kopieren(0); root.loeschen() }
        }
        MenuItem {
            text:      "Einfuegen\t(Ctrl+V)"
            enabled:   root.zwischenablage.length > 0 && root.seiteId >= 0
            onTriggered: root.einfuegen(0)
        }
        MenuSeparator {}
        MenuItem {
            text: "Drehen 90 Grad"
            enabled: {
                if (root.auswahl.length === 0) return false
                for (var i = 0; i < root.auswahl.length; i++)
                    if (elementeModel.element(root.auswahl[i]).typ === "symbol") return true
                return false
            }
            onTriggered: {
                if (root.auswahl.length === 1) {
                    var el = elementeModel.element(root.ausgewaehlt)
                    root.eigenschaftAktualisieren("rotation", ((el.rotation || 0) + 90) % 360)
                } else {
                    root.multiRotationUmPivot(90)
                }
            }
        }
        MenuSeparator {}
        MenuItem {
            text:      "Loeschen\t(Del)"
            enabled:   root.auswahl.length > 0
            onTriggered: root.loeschen()
        }
        MenuSeparator {}
        MenuItem {
            text:      "Alles auswaehlen\t(Ctrl+A)"
            onTriggered: root.alleAuswaehlen()
        }
        MenuItem {
            text:      "Auswahl aufheben\t(Esc)"
            enabled:   root.auswahl.length > 0
            onTriggered: { root.auswahl = []; drawCanvas.requestPaint() }
        }
    }

    // --------------------------------------------------------
    // Zoom – Mausrad + Touchpad-Scroll
    // --------------------------------------------------------
    WheelHandler {
        enabled: root.seiteId >= 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        // Ctrl + Pinch auf Touchpad liefert pixelDelta; normales Scrollen angleDelta
        onWheel: function(event) {
            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y
                                                 : event.pixelDelta.y * 3
            if (delta === 0) return
            var factor  = delta > 0 ? 1.12 : (1 / 1.12)
            var newZoom = Math.max(root.minZoom, Math.min(root.maxZoom, root.zoom * factor))
            root.worldX = event.x - (event.x - root.worldX) * (newZoom / root.zoom)
            root.worldY = event.y - (event.y - root.worldY) * (newZoom / root.zoom)
            root.zoom   = newZoom; root.repaintAll()
        }
    }

    // --------------------------------------------------------
    // Zoom – Touchpad-Pinch (zwei Finger aufziehen / zusammenziehen)
    // --------------------------------------------------------
    PinchHandler {
        id: pinchHandler
        target: null
        enabled: root.seiteId >= 0
        property real startZoom: 1.0
        onActiveChanged: { if (active) startZoom = root.zoom }
        onActiveScaleChanged: {
            var newZoom = Math.max(root.minZoom, Math.min(root.maxZoom, startZoom * activeScale))
            var cx = centroid.position.x
            var cy = centroid.position.y
            root.worldX = cx - (cx - root.worldX) * (newZoom / root.zoom)
            root.worldY = cy - (cy - root.worldY) * (newZoom / root.zoom)
            root.zoom   = newZoom; root.repaintAll()
        }
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
    // Text-Editor-Overlay
    // --------------------------------------------------------
    Rectangle {
        id: textEditorOverlay
        visible:  root.textEditAktiv && root.seiteId >= 0
        x:        root.textEditVpX - 4
        y:        root.textEditVpY - 4
        z:        200
        color:    theme.sidebar
        border.color: theme.accent; border.width: 1
        radius:   2

        // Breite und Höhe passen sich dem Inhalt an (Mindestbreite 120px)
        width:  Math.max(120, textEditor.implicitWidth + 16)
        height: textEditor.implicitHeight + 10

        TextEdit {
            id: textEditor
            anchors { fill: parent; margins: 5 }
            color:        theme.textSecondary
            font.pixelSize: Math.max(10, (root.stilVorlage.strichBreite || 3.5) * root.mmToPx * root.zoom)
            font.bold:    true
            selectionColor:    theme.activeItemAlt
            selectedTextColor: "#ffffff"
            wrapMode:     TextEdit.NoWrap
            focus:        root.textEditAktiv

            // Enter = bestätigen | Shift+Enter = Zeilenumbruch
            Keys.onReturnPressed: function(event) {
                if (event.modifiers & Qt.ShiftModifier) {
                    event.accepted = false   // TextEdit fügt \n ein
                } else {
                    root.textEditorBestaetigen()
                    event.accepted = true
                }
            }
            Keys.onEscapePressed: root.textEditorAbbrechen()
            onActiveFocusChanged: {
                if (!activeFocus && root.textEditAktiv) root.textEditorBestaetigen()
            }
            onTextChanged: root.textBboxAktualisieren()
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

        // Elemente neu laden damit el.id aktuelle grafik_element_id enthält
        var savedAuswahl = root.auswahl.slice()
        elementeModel.laden(root.seiteId)
        root.auswahl = savedAuswahl
        var reloaded = elementeModel.snapshot()

        // Frisches Element per kabelId finden
        var freshEl = null
        for (var i = 0; i < reloaded.length; i++) {
            var fe = reloaded[i]
            if (fe.typ === "kabellinie" && fe.extraDaten && fe.extraDaten.kabelId === kabelId) {
                freshEl = fe; break
            }
        }
        var currentEl = freshEl || el
        var freshGeid = currentEl.id || 0

        var details = db.kabelLinieDetails(freshGeid)
        var netze   = drawCanvas.autoNetzeBerechnen()
        var schnitte = drawCanvas.kabelSchnittNetzeBerechnen(currentEl, netze)
        aderzuordnungDialog.kabelId                    = kabelId
        aderzuordnungDialog.kabelBezeichnung           = ed.bezeichnung || ""
        aderzuordnungDialog.kabeltyp                   = ed.kabeltyp    || ""
        aderzuordnungDialog.aderzahl                   = ed.aderzahl    || 0
        aderzuordnungDialog.adern                      = details.adern  || []
        aderzuordnungDialog.schnittNetze               = schnitte
        aderzuordnungDialog.aderZuordnung              = ed.aderZuordnung || {}
        aderzuordnungDialog.kabellinieGrafikElementId  = freshGeid
        aderzuordnungDialog.pinNummernMap              = _pinNummernFuerNetze(netze)
        aderzuordnungDialog.open()
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
        var inhalt = root.auswahl.map(function(i) { return elementeModel.element(i) })
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
        var off = root.gridPx
        var neueEl = quelle.map(function(el) {
            var upd = {}; for (var k in el) upd[k] = el[k]
            upd.x1 += off; upd.y1 += off; upd.x2 += off; upd.y2 += off
            return upd
        })
        var anzahl = neueEl.length
        root.aktionAusfuehren(elementeModel.snapshot().concat(neueEl))
        var start = elementeModel.anzahl - anzahl
        var sel = []; for (var j = 0; j < anzahl; j++) sel.push(start + j)
        root.auswahl = sel
        drawCanvas.requestPaint()
    }

    function abbruch() {
        root.amZeichnen      = false; root.vorschau = null
        root.aktiverGriff    = -1
        root.amRubberband    = false; root.rubberbandRect = null
        root.textEditAktiv   = false
        root.paletteImageData = ""
        root.amPolyZeichnen  = false
        root.polyPunkte      = []
        root.polyCursorWelt  = null
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
    function textBboxBerechnen(inhalt, strichBreite) {
        var lines = inhalt.split("\n")
        var longestLen = 1
        for (var li = 0; li < lines.length; li++)
            if (lines[li].length > longestLen) longestLen = lines[li].length
        var fsPx = (strichBreite || 3.5) * root.mmToPx
        return { w: longestLen * fsPx * 0.62, h: lines.length * fsPx * 1.3 }
    }

    // Live-Aktualisierung der Bbox während der Texteingabe
    function textBboxAktualisieren() {
        if (!root.textEditAktiv) return
        var inhalt = textEditor.text.replace(/^\n+|\n+$/g, "").trim()

        if (root.textEditElIdx >= 0) {
            // Vorhandenes Element live aktualisieren (kein Undo-Schritt)
            var idx = root.textEditElIdx
            var el  = elementeModel.element(idx)
            if (el.textEinpassen) return   // Einpassen-Modus: Bbox bleibt fest
            if (el.typ === "notiz")    return   // Notiz: feste Größe, kein Auto-Resize

            var updEl = {}; for (var k in el) updEl[k] = el[k]
            if (inhalt !== "") {
                var bb = root.textBboxBerechnen(inhalt, el.strichBreite)
                updEl.x2 = updEl.x1 + bb.w
                updEl.y2 = updEl.y1 + bb.h
            }
            updEl.textInhalt = inhalt
            elementeModel.elementAktualisieren(idx, updEl)
            drawCanvas.requestPaint()
        } else {
            // Neues Element: Vorschau setzen
            if (inhalt === "") {
                root.vorschau = null
            } else {
                var bb2 = root.textBboxBerechnen(inhalt, root.stilVorlage.strichBreite)
                root.vorschau = {
                    typ:             "text",
                    x1:              root.textEditWeltX,
                    y1:              root.textEditWeltY,
                    x2:              root.textEditWeltX + bb2.w,
                    y2:              root.textEditWeltY + bb2.h,
                    textInhalt:      inhalt,
                    textAusrichtung: "links",
                    textEinpassen:   false,
                    rotation:        0,
                    strichFarbe:     root.stilVorlage.strichFarbe,
                    strichBreite:    root.stilVorlage.strichBreite,
                    strichArt:       "solid",
                    fuell:           false,
                    fuellFarbe:      root.stilVorlage.fuellFarbe,
                    fuellOpazitaet:  root.stilVorlage.fuellOpazitaet,
                    opazitaet:       root.stilVorlage.opazitaet,
                    eckenRadius:     0
                }
            }
            drawCanvas.requestPaint()
        }
    }

    function textEditorBestaetigen() {
        if (!root.textEditAktiv) return
        var inhalt = textEditor.text.replace(/^\n+|\n+$/g, "").trim()
        root.textEditAktiv = false
        root.vorschau      = null

        if (inhalt === "") {
            // Abbruch: live Änderungen am bestehenden Element zurückrollen
            if (root.textEditElIdx >= 0 && root.textEditSnapshot)
                elementeModel.fromVariantList(root.textEditSnapshot)
            drawCanvas.requestPaint()
            return
        }

        if (root.textEditElIdx >= 0) {
            // Vorhandenes Element: Snapshot als Undo-Basis, live-aktualisiertes
            // Element ist bereits in elementeModel drin → einfach speichern
            var idx = root.textEditElIdx
            // Snapshot als Undo-Eintrag (nicht den live-modifizierten Zustand)
            elementeModel.undoCheckpointFromSnapshot(root.textEditSnapshot)
            elementeModel.eigenschaftSetzen(idx, "textInhalt", inhalt)
            root.auswahl   = [idx]
            root.grafikSpeichernJetzt()
        } else {
            // Neues Text-Element anlegen
            var bb = root.textBboxBerechnen(inhalt, root.stilVorlage.strichBreite)
            var textEl = {
                typ:             "text",
                x1:              root.textEditWeltX,
                y1:              root.textEditWeltY,
                x2:              root.textEditWeltX + bb.w,
                y2:              root.textEditWeltY + bb.h,
                textInhalt:      inhalt,
                textAusrichtung: "links",
                textEinpassen:   false,
                rotation:        0,
                strichFarbe:     root.stilVorlage.strichFarbe,
                strichBreite:    root.stilVorlage.strichBreite,
                strichArt:       "solid",
                fuell:           false,
                fuellFarbe:      root.stilVorlage.fuellFarbe,
                fuellOpazitaet:  root.stilVorlage.fuellOpazitaet,
                opazitaet:       root.stilVorlage.opazitaet,
                eckenRadius:     0
            }
            // Snapshot als Undo-Basis (statt aktionAusfuehren, das den aktuellen Stand nimmt)
            elementeModel.undoCheckpointFromSnapshot(root.textEditSnapshot)
            elementeModel.fromVariantList(elementeModel.snapshot().concat([textEl]))
            root.auswahl   = [elementeModel.anzahl - 1]
            root.aktivesWerkzeug = "zeiger"
            root.grafikSpeichernJetzt()
        }
        drawCanvas.requestPaint()
    }

    function textEditorAbbrechen() {
        // Live-Änderungen zurückrollen
        if (root.textEditElIdx >= 0 && root.textEditSnapshot)
            elementeModel.fromVariantList(root.textEditSnapshot)
        root.vorschau      = null
        root.textEditAktiv = false
        drawCanvas.requestPaint()
    }

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
            repaintAll()
        }
    }

    onSeiteIdChanged: {
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
            // Normblatt-Daten laden
            root.normblattDaten   = db.normblattDatenLaden(seiteId)
            root.normblattLogoUrl = root.normblattDaten ? (root.normblattDaten.logoDataUrl || "") : ""
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
            root.repaintAll()
        }
    }
    onWidthChanged:  root.repaintAll()
    onHeightChanged: root.repaintAll()

    // --------------------------------------------------------
    // Dateidialog: Bild auswählen
    // --------------------------------------------------------
    FileDialog {
        id:           bildDialog
        title:        qsTr("Bild auswählen (max. 5 MB)")
        nameFilters:  ["Bilder (*.png *.jpg *.jpeg *.bmp *.gif *.webp)", "Alle Dateien (*)"]

        onAccepted: {
            var result = db.bildAlsDataUrl(selectedFile.toString())
            if (result.startsWith("error:")) {
                bildFehlerText.text = result.substring(6)
                bildFehlerDialog.open()
                root.aktivesWerkzeug = "zeiger"
            } else {
                root.paletteImageData = result
                // Bild vorladen damit Vorschau sofort erscheint
                drawCanvas.loadImage(result)
                root.aktivesWerkzeug = "bild"
            }
        }
        onRejected: {
            root.aktivesWerkzeug = "zeiger"
        }
    }

    // Fehlermeldung wenn Bild zu groß oder nicht lesbar
    Dialog {
        id:           bildFehlerDialog
        title:        qsTr("Bild konnte nicht geladen werden")
        modal:        true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        Label {
            id:    bildFehlerText
            color: "#c05050"
            wrapMode: Text.Wrap
            width:    300
        }
    }

    // --------------------------------------------------------
    // Drag & Drop: Bilder per Datei-Drag aus dem Dateimanager
    // --------------------------------------------------------
    DropArea {
        id: bildDropArea
        anchors {
            top:    headerBar.bottom
            bottom: footerBar.top
            left:   werkzeugLeiste.right
            right:  eigenschaftenPanel.visible ? eigenschaftenPanel.left : parent.right
        }
        enabled: root.seiteId >= 0
        keys: ["text/uri-list"]

        // Visuelles Feedback während des Drags
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#4a9eff"
            border.width: 3
            visible: bildDropArea.containsDrag
            z: 9999

            Rectangle {
                anchors.centerIn: parent
                width:  hintText.implicitWidth + 32
                height: 44
                color:  "#cc0d1a2b"
                radius: 8

                Text {
                    id:   hintText
                    anchors.centerIn: parent
                    text: qsTr("Bild hier ablegen")
                    color: "#4a9eff"
                    font.pixelSize: 16
                    font.bold: true
                }
            }
        }

        onDropped: function(drop) {
            if (!drop.hasUrls) return
            var urls = drop.urls
            for (var i = 0; i < urls.length; i++) {
                var url = urls[i].toString()
                if (!/\.(png|jpg|jpeg|bmp|gif|webp)$/i.test(url)) continue
                var result = db.bildAlsDataUrl(url)
                if (result.startsWith("error:")) {
                    bildFehlerText.text = result.substring(6)
                    bildFehlerDialog.open()
                    continue
                }
                // Drop-Position in Weltkoordinaten umrechnen
                var vp = bildDropArea.mapToItem(root, drop.x, drop.y)
                var w  = root.viewportZuWelt(vp.x, vp.y)
                if (root.rastend) w = root.rasterPunkt(w.x, w.y)
                // Bild in gleicher Größe wie Klick-Platzierung einfügen
                drawCanvas.loadImage(result)
                var hs = root.gridPx * 4
                var elBild = {
                    typ:            "bild",
                    x1: w.x - hs,  y1: w.y - hs,
                    x2: w.x + hs,  y2: w.y + hs,
                    bildDaten:      result,
                    strichFarbe:    root.stilVorlage.strichFarbe,
                    strichBreite:   root.stilVorlage.strichBreite,
                    strichArt:      root.stilVorlage.strichArt,
                    fuell:          false, fuellFarbe: "#000000", fuellOpazitaet: 0,
                    opazitaet:      1.0, eckenRadius: 0,
                    rotation: 0, spiegelX: false, spiegelY: false, proportional: false,
                    ausschnittLinks: 0, ausschnittRechts: 0, ausschnittOben: 0, ausschnittUnten: 0
                }
                root.aktionAusfuehren(elementeModel.snapshot().concat([elBild]))
                root.auswahl = [elementeModel.anzahl - 1]
                break  // nur das erste Bild verarbeiten
            }
            drop.accepted = true
        }
    }

    // --------------------------------------------------------
    // Kabellinie-Dialog: öffnet sich direkt nach dem Zeichnen
    // --------------------------------------------------------
    KabellinieDialog {
        id:         kabellinieDialog
        theme:      root.theme
        debug:      root.debug
        projektId:  root.projektId

        onAccepted: {
            var idx = elementIndex
            if (idx < 0 || idx >= elementeModel.anzahl) return
            // extraDaten des Elements im Canvas aktualisieren
            var el = Object.assign({}, elementeModel.element(idx))
            var savedX1 = el.x1, savedY1 = el.y1
            el.extraDaten = {
                bezeichnung:    kabellinieDialog.bezeichnung,
                kabeltyp:       kabellinieDialog.kabeltyp,
                aderzahl:       kabellinieDialog.aderzahl,
                querschnittMm2: kabellinieDialog.querschnittMm2,
                bauteilKabelId: kabellinieDialog.bauteilKabelId,
                vonOrt:         kabellinieDialog.vonOrt,
                nachOrt:        kabellinieDialog.nachOrt
            }
            elementeModel.eigenschaftSetzen(idx, "extraDaten", el.extraDaten)
            root.grafikSpeichernJetzt()
            // grafik_element-ID holen (nach Speichern in DB vorhanden)
            elementeModel.laden(root.seiteId)
            var reloaded = elementeModel.snapshot()
            for (var ri = 0; ri < reloaded.length; ri++) {
                var re = reloaded[ri]
                if (re.typ === "kabellinie"
                        && Math.abs(re.x1 - savedX1) < 0.01
                        && Math.abs(re.y1 - savedY1) < 0.01) {
                    if (root.projektId < 0) break

                    var newKabelId = 0
                    var bkAdern   = []

                    if (kabellinieDialog.bestehendesKabelId > 0) {
                        // Bestehende Kabellinie – nur verknüpfen, kein neues kabel anlegen
                        newKabelId = kabellinieDialog.bestehendesKabelId
                        // Von/Nach aktualisieren falls gesetzt
                        if (kabellinieDialog.vonOrt || kabellinieDialog.nachOrt) {
                            db.kabelMetaAktualisieren(newKabelId,
                                kabellinieDialog.bezeichnung,
                                kabellinieDialog.kabeltyp,
                                kabellinieDialog.aderzahl,
                                kabellinieDialog.querschnittMm2,
                                kabellinieDialog.vonOrt,
                                kabellinieDialog.nachOrt)
                        }
                        var existDetails = db.kabelLinieDetails(re.id || 0)
                        bkAdern = existDetails.adern || []
                    } else {
                        newKabelId = db.kabelAnlegen(root.projektId,
                                        kabellinieDialog.bezeichnung,
                                        kabellinieDialog.kabeltyp,
                                        kabellinieDialog.aderzahl,
                                        kabellinieDialog.querschnittMm2,
                                        re.id || 0,
                                        kabellinieDialog.vonOrt,
                                        kabellinieDialog.nachOrt)
                        if (newKabelId > 0 && kabellinieDialog.bauteilKabelId > 0) {
                            var bkMeta = db.kabelBauteilKabelSetzen(newKabelId, kabellinieDialog.bauteilKabelId)
                            bkAdern = bkMeta.adern || []
                        }
                    }

                    // kabelId stabil in extraDaten speichern (überlebt DELETE+INSERT in grafikSpeichern)
                    if (newKabelId > 0) {
                        var el2 = Object.assign({}, elementeModel.element(ri))
                        el2.extraDaten = Object.assign({}, el2.extraDaten || {})
                        el2.extraDaten.kabelId = newKabelId
                        if (bkAdern.length > 0) el2.extraDaten.adern = bkAdern
                        elementeModel.eigenschaftSetzen(ri, "extraDaten", el2.extraDaten)
                        root.grafikSpeichernJetzt()  // speichert kabelId → grafikSpeichern verlinkt kabel.grafik_element_id
                        root.kabelLinienCacheAktualisieren()

                        // Elemente neu laden – zweites grafikSpeichern hat DELETE+INSERT durchgeführt,
                        // daher hat das Element eine neue DB-ID; frische ID per kabelId suchen
                        elementeModel.laden(root.seiteId)
                        var freshReloaded = elementeModel.snapshot()

                        var freshKlEl = null
                        for (var fi = 0; fi < freshReloaded.length; fi++) {
                            var fe = freshReloaded[fi]
                            if (fe.typ === "kabellinie" && fe.extraDaten && fe.extraDaten.kabelId === newKabelId) {
                                freshKlEl = fe; break
                            }
                        }

                        // Aderzuordnungsdialog öffnen wenn Schnittpunkte vorhanden (Phase 6)
                        if (freshKlEl) {
                            var neueNetze  = drawCanvas.autoNetzeBerechnen()
                            var schnitte   = drawCanvas.kabelSchnittNetzeBerechnen(freshKlEl, neueNetze)
                            if (schnitte.length > 0) {
                                aderzuordnungDialog.kabelId                   = newKabelId
                                aderzuordnungDialog.kabelBezeichnung          = kabellinieDialog.bezeichnung
                                aderzuordnungDialog.kabeltyp                  = kabellinieDialog.kabeltyp
                                aderzuordnungDialog.aderzahl                  = kabellinieDialog.aderzahl
                                aderzuordnungDialog.adern                     = bkAdern
                                aderzuordnungDialog.schnittNetze              = schnitte
                                aderzuordnungDialog.aderZuordnung             = {}
                                aderzuordnungDialog.kabellinieGrafikElementId = freshKlEl.id || 0
                                aderzuordnungDialog.pinNummernMap             = _pinNummernFuerNetze(neueNetze)
                                aderzuordnungDialog.open()
                            }
                        }
                    }
                    break
                }
            }
            drawCanvas.requestPaint()
        }

        onRejected: {
            // Linie wieder aus den Elementen entfernen
            var idx = elementIndex
            if (idx >= 0 && idx < elementeModel.anzahl) {
                var cleaned = elementeModel.snapshot()
                cleaned.splice(idx, 1)
                root.aktionAusfuehren(cleaned)
                drawCanvas.requestPaint()
            }
        }
    }

    AderzuordnungDialog {
        id:    aderzuordnungDialog
        theme: root.theme
        debug: root.debug
        onAccepted: drawCanvas.requestPaint()
        onZuordnungGespeichert: function(netKeyMap) {
            console.log("onZuordnungGespeichert: ausgewaehlt=", root.ausgewaehlt,
                        "netKeyMap=", JSON.stringify(netKeyMap))
            var idx = root.ausgewaehlt
            if (idx < 0 || idx >= elementeModel.anzahl) {
                console.log("  → abgebrochen: idx ungültig")
                return
            }
            var el = elementeModel.element(idx)
            if (!el || el.typ !== "kabellinie") {
                console.log("  → abgebrochen: kein kabellinie, typ=", el ? el.typ : "null")
                return
            }
            var el2 = Object.assign({}, el)
            el2.extraDaten = Object.assign({}, el2.extraDaten || {})
            el2.extraDaten.aderZuordnung = netKeyMap
            elementeModel.eigenschaftSetzen(idx, "extraDaten", el2.extraDaten)
            root.grafikSpeichernJetzt()
            root.kabelLinienCacheAktualisieren()
            // Elemente neu laden damit die EP-Bindings die aktuelle grafik_element_id erhalten
            elementeModel.laden(root.seiteId)
            root.verdrahtungswegeAktualisieren()
        }
    }

    // --------------------------------------------------------
    // Makrokasten-Dialog: öffnet sich direkt nach dem Zeichnen
    // --------------------------------------------------------
    MakrobenennDialog {
        id:    makrobenennDialog
        theme: root.theme

        property int elementIndex: -1

        onAccepted: {
            var idx = elementIndex
            if (idx < 0 || idx >= elementeModel.anzahl) return
            var snap = elementeModel.snapshot()
            var el = Object.assign({}, snap[idx])
            el.extraDaten = {
                name:         makrobenennDialog.name,
                beschreibung: makrobenennDialog.beschreibung,
                kategorie:    makrobenennDialog.kategorie,
                makroId:      0
            }
            snap[idx] = el
            root.aktionAusfuehren(snap)
            root.grafikSpeichernJetzt()   // Element bekommt DB-id nach Reload

            // Sofort als Makro in DB speichern – dann erscheint es gleich in der Seitenleiste
            var savedEl = elementeModel.element(idx)
            if (savedEl && (savedEl.id || 0) > 0) {
                var newMakroId = db.makroSpeichern(savedEl.id, root.seiteId)
                if (newMakroId > 0) {
                    var el2 = Object.assign({}, elementeModel.element(idx))
                    el2.extraDaten = Object.assign({}, el2.extraDaten, { makroId: newMakroId })
                    elementeModel.eigenschaftSetzen(idx, "extraDaten", el2.extraDaten)
                    root.makroListeGeaendert()
                    drawCanvas.requestPaint()
                }
            }
        }

        onRejected: {
            // Kasten wieder entfernen
            var idx = elementIndex
            if (idx >= 0 && idx < elementeModel.anzahl) {
                var updated = elementeModel.snapshot()
                updated.splice(idx, 1)
                root.aktionAusfuehren(updated)
                root.grafikSpeichernJetzt()
            }
            root.auswahl = []
        }
    }

    DebugLabel { panelName: qsTr("Schaltplan-Canvas"); visible: root.debug }
}
