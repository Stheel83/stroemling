import QtQuick
import "../SymbolKlassen.js" as SK

// Render-Helferfunktionen fürs Canvas-Zeichnen (Normblatt, Element-Dispatch,
// Primitiv-Renderer je Elementtyp inkl. Symbol-Rendering, Kabelschnitte/
// Auto-Verbindungen).
// cv: Referenz auf SchaltplanCanvas (root). REFACTOR-01 Stufe 5a+5b.
QtObject {
    id: handler
    required property var cv

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
        if (!cv.normblattDaten) return
        if (!cv.normblattDaten.normblattAnzeigen) return

        var nd   = cv.normblattDaten
        var z    = cv.zoom
        var mpx  = cv.mmToPx   // world-px per mm

        // mm → screen pixels
        function s(mm) { return mm * mpx * z }
        // world-px → screen
        function sx(wx) { return wx * z + cv.worldX }
        function sy(wy) { return wy * z + cv.worldY }

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
                    if (cv.normblattLogoUrl && cv._drawCanvas.isImageLoaded(cv.normblattLogoUrl)) {
                        ctx.save()
                        ctx.beginPath(); ctx.rect(_fx+1, _fy+1, _fw-2, _fh-2); ctx.clip()
                        var _pad = s(2)
                        ctx.drawImage(cv.normblattLogoUrl, _fx+_pad, _fy+_pad, _fw-2*_pad, _fh-2*_pad)
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

            if (cv.normblattLogoUrl && cv._drawCanvas.isImageLoaded(cv.normblattLogoUrl)) {
                ctx.save()
                var lx = cX[0], ly = rowY[1], lw = cX[1]-cX[0], lh = rowH
                ctx.beginPath(); ctx.rect(lx+1, ly+1, lw-2, lh-2); ctx.clip()
                var pad = s(2)
                ctx.drawImage(cv.normblattLogoUrl, lx+pad, ly+pad, lw-2*pad, lh-2*pad)
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
            zelle("REV.",         cv.revisionKennung || "–", cX[3], rowY[2], cX[4]-cX[3], rowH)

            ctx.strokeStyle = "#4a7ab0"
            ctx.lineWidth   = Math.max(1, s(0.7))
            ctx.strokeRect(iX0, sfY0, iW, sfH)
        }

        ctx.restore()
    }

    // ── Außenbereich-Overlay: Bereich außerhalb der Seite abdunkeln ──
    function drawNormblattAussenoverlay(ctx) {
        if (!cv.normblattDaten) return
        if (!cv.normblattDaten.normblattAnzeigen) return
        if (!cv.normblattDaten.aussenOverlay) return
        var nd  = cv.normblattDaten
        var z   = cv.zoom
        var mpx = cv.mmToPx
        function sx(wx) { return wx * z + cv.worldX }
        function sy(wy) { return wy * z + cv.worldY }
        var bMm = nd.breiteMm || 297, hMm = nd.hoeheMm || 210
        var pX0 = sx(0),         pY0 = sy(0)
        var pX1 = sx(bMm * mpx), pY1 = sy(hMm * mpx)
        ctx.save()
        ctx.fillStyle = "rgba(0,0,0,0.28)"
        if (pY0 > 0)            ctx.fillRect(0,    0,    cv._drawCanvas.width, pY0)
        if (pY1 < cv._drawCanvas.height) ctx.fillRect(0, pY1, cv._drawCanvas.width, cv._drawCanvas.height - pY1)
        if (pX0 > 0)            ctx.fillRect(0,   pY0, pX0,                        pY1 - pY0)
        if (pX1 < cv._drawCanvas.width)  ctx.fillRect(pX1, pY0, cv._drawCanvas.width - pX1, pY1 - pY0)
        ctx.restore()
    }

    function maleElement(ctx, el, idx) {
        var vorschau  = (idx < 0)
        var gewaehlt  = (!vorschau && cv.auswahl.indexOf(idx) >= 0)
        var _skipText = !vorschau && cv.bewegungAktiv

        // ── Fehlersuchmodus: Dimm-Faktor ─────────────────────
        var dimFaktor = 1.0
        if (!vorschau && cv.fehlersuchModus) {
            var pfadKeys = Object.keys(cv.fehlersuchPfadIds)
            if (pfadKeys.length > 0) {
                if (cv.fehlersuchPfadIds[(el.id || -1)] !== undefined) {
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
        if (!vorschau && cv.fehlersuchModus && cv.fehlersuchPfadIds[(el.id || -1)] !== undefined &&
                (el.typ === "linie" || el.typ === "polygonlinie")) {
            sf = cv.theme.accent
            sb = sb + 0.8
        }

        var vx1 = el.x1 * cv.zoom + cv.worldX
        var vy1 = el.y1 * cv.zoom + cv.worldY
        var vx2 = el.x2 * cv.zoom + cv.worldX
        var vy2 = el.y2 * cv.zoom + cv.worldY

        // Viewport-Culling: Elemente außerhalb des Sichtbereichs überspringen.
        // Puffer 200px für Labels/BMK-Texte die über die Bounding-Box hinausragen.
        if (!vorschau) {
            var _margin = 200
            if (Math.max(vx1, vx2) + _margin < 0        || Math.min(vx1, vx2) - _margin > cv._drawCanvas.width  ||
                Math.max(vy1, vy2) + _margin < 0        || Math.min(vy1, vy2) - _margin > cv._drawCanvas.height)
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
        if (gewaehlt && cv.auswahl.length === 1) {
            var pts = cv.geometrie.griffPunkte(el)
            ctx.fillStyle="#f0a030"; ctx.strokeStyle="#ffffff"
            ctx.lineWidth=1; ctx.setLineDash([])
            for (var i=0; i<pts.length; i++) {
                var gx=pts[i].x*cv.zoom+cv.worldX, gy=pts[i].y*cv.zoom+cv.worldY
                ctx.fillRect(gx-5,gy-5,10,10); ctx.strokeRect(gx-5,gy-5,10,10)
            }
        }

        // Debug: Element-Beschriftung (Strg+Shift+D)
        if (cv.debug && !vorschau && !_skipText) {
            ctx.save()
            var dbgLabel = idx + ": " + el.typ
            if (el.typ === "symbol") dbgLabel += "/" + (el.symbolId || "?")
            if (el.id) dbgLabel += " #" + el.id
            var dbgFs = Math.max(8, Math.round(7 * cv.zoom))
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
            var klGesamtLinien = (klKabelId > 0 && cv._kabelLinienCache[klKabelId]) || 0
            if (klGesamtLinien > 1) {
                var klWeitere = klGesamtLinien - 1
                klZeilen.push({ text: "→ +" + klWeitere + " " + (klWeitere === 1 ? qsTr("Linie") : qsTr("Linien")), bold: false })
            }
            if (klZeilen.length > 0 && 2.5 * cv.mmToPx * cv.zoom >= 7) {
                // Senkrechte zur Linie, auf der "oben"-Seite (negativstes y in Viewport)
                var klDxL = vx2 - vx1, klDyL = vy2 - vy1
                var klLLen = Math.sqrt(klDxL*klDxL + klDyL*klDyL) || 1
                var ccwXL = -klDyL/klLLen, ccwYL = klDxL/klLLen
                var cwXL  =  klDyL/klLLen, cwYL  = -klDxL/klLLen
                var useCC = (ccwYL < cwYL) || (ccwYL === cwYL && ccwXL < cwXL)
                var klNxL = useCC ? ccwXL : cwXL
                var klNyL = useCC ? ccwYL : cwYL
                var klFs  = Math.max(10, Math.round(2.5 * cv.mmToPx * cv.zoom))
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
            ctx.moveTo(plPts[0].x * cv.zoom + cv.worldX, plPts[0].y * cv.zoom + cv.worldY)
            for (var plI = 1; plI < plPts.length; plI++)
                ctx.lineTo(plPts[plI].x * cv.zoom + cv.worldX, plPts[plI].y * cv.zoom + cv.worldY)
            ctx.stroke()
        }
    }

    function _renderRechteck(ctx, el, rc) {
        var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
        var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
        var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
        var rr  = er * cv.mmToPx * cv.zoom
        // Eckenradius (roundRect) setzt positive Breite/Höhe voraus – anders als
        // fillRect/strokeRect, die mit negativer Breite/Höhe (Aufziehen in beliebiger
        // Richtung) bereits korrekt umgehen. Daher hier immer normalisieren, analog zu
        // _renderGeraetekasten/_renderStrukturkasten/_renderMakrokasten.
        var rrx = Math.min(vx1, vx2), rry = Math.min(vy1, vy2)
        var rrw = Math.abs(vx2 - vx1), rrh = Math.abs(vy2 - vy1)
        if (fu && !vorschau) {
            ctx.fillStyle = ff; ctx.globalAlpha = fo
            if (rr>0.5) { roundRect(ctx,rrx,rry,rrw,rrh,rr); ctx.fill() }
            else          ctx.fillRect(rrx,rry,rrw,rrh)
            ctx.globalAlpha = op
        }
        ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
        if (rr>0.5) { roundRect(ctx,rrx,rry,rrw,rrh,rr); ctx.stroke() }
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
            var txtRot    = normTextRot(el.rotation || 0)
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
                txtFsPx = ((el.extraDaten && el.extraDaten.schriftgroesse) || 3.5) * cv.mmToPx * cv.zoom
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
            if (cv._drawCanvas.isImageLoaded(bUrl)) {
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
                cv._drawCanvas.loadImage(bUrl)
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
                var nFsPx  = ((el.extraDaten && el.extraDaten.schriftgroesse) || 3.5) * cv.mmToPx * cv.zoom
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

    function _renderGeraetekasten(ctx, el, rc) {
        var vorschau = rc.vorschau, gewaehlt = rc.gewaehlt, _skipText = rc.skipText
        var sf = rc.sf, sb = rc.sb, sa = rc.sa, fu = rc.fu, ff = rc.ff, fo = rc.fo, op = rc.op, er = rc.er
        var vx1 = rc.vx1, vy1 = rc.vy1, vx2 = rc.vx2, vy2 = rc.vy2, lw = rc.lw, idx = rc.idx
        // Gerätekasten: abgerundetes Rechteck mit leichter Füllung und Label oben links
        ctx.lineCap = "butt"
        var gkRx = Math.min(vx1, vx2), gkRy = Math.min(vy1, vy2)
        var gkRw = Math.abs(vx2 - vx1), gkRh = Math.abs(vy2 - vy1)
        var gkR  = er > 0 ? er * cv.mmToPx * cv.zoom : 4 * cv.zoom
        // GK-1: eigene Standardfarbe Teal statt generischem Blau, unterscheidet sich
        // von Strukturkasten (Grau) und Makrokasten (Violett)
        var gkFarbe = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : (el.strichFarbe || "#0088aa"))
        if (fu && !vorschau) {
            ctx.fillStyle  = ff
            ctx.globalAlpha = op * fo
            roundRect(ctx, gkRx, gkRy, gkRw, gkRh, gkR)
            ctx.fill()
            ctx.globalAlpha = op
        }
        ctx.strokeStyle = gkFarbe
        roundRect(ctx, gkRx, gkRy, gkRw, gkRh, gkR)
        ctx.stroke()
        if (!vorschau && !_skipText && gkRw > 20 && gkRh > 12) {
            var gkEd  = el.extraDaten || {}
            var gkBmk = gkEd.bmk        || ""
            var gkBez = gkEd.bezeichnung || ""
            if (gkBmk !== "" || gkBez !== "") {
                ctx.save()
                ctx.setLineDash([])
                var gkSch = (gkEd.schriftgroesse !== undefined ? gkEd.schriftgroesse : 2.5)
                var gkFs  = Math.max(5, Math.round(gkSch * cv.mmToPx * cv.zoom))
                var gkFsB = Math.max(4, Math.round(gkSch * 0.85 * cv.mmToPx * cv.zoom))
                var gkPad = Math.round(5 * cv.zoom)
                var gkOx  = (gkEd.bmkOffsetX !== undefined ? gkEd.bmkOffsetX : 0) * cv.zoom
                var gkOy  = (gkEd.bmkOffsetY !== undefined ? gkEd.bmkOffsetY : 0) * cv.zoom
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
        var skR = er > 0 ? er * cv.mmToPx * cv.zoom : 0
        if (fu && !vorschau) {
            ctx.fillStyle   = ff; ctx.globalAlpha = op * fo
            if (skR > 0) { roundRect(ctx, skRx, skRy, skRw, skRh, skR); ctx.fill() }
            else ctx.fillRect(skRx, skRy, skRw, skRh)
            ctx.globalAlpha = op
        }
        ctx.strokeStyle = gewaehlt ? "#f0a030" : (vorschau ? "#4a9eff" : sf)
        if (skR > 0) { roundRect(ctx, skRx, skRy, skRw, skRh, skR); ctx.stroke() }
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
            var skFs  = Math.max(5, Math.round(skSch * cv.mmToPx * cv.zoom))
            ctx.font        = "bold " + skFs + "px sans-serif"
            ctx.textBaseline = "top"
            ctx.fillStyle   = gewaehlt ? "#f0a030" : sf
            ctx.globalAlpha = op
            var skOx  = (skEd.bmkOffsetX !== undefined ? skEd.bmkOffsetX : 0) * cv.zoom
            var skOy  = (skEd.bmkOffsetY !== undefined ? skEd.bmkOffsetY : 0) * cv.zoom
            var skFsB = Math.max(4, Math.round(skSch * 0.85 * cv.mmToPx * cv.zoom))
            var skPad = Math.round(5 * cv.zoom)
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
        var mkR = er > 0 ? er * cv.mmToPx * cv.zoom : 0
        if (fu && !vorschau) {
            ctx.fillStyle   = ff; ctx.globalAlpha = op * fo
            if (mkR > 0) { roundRect(ctx, mkRx, mkRy, mkRw, mkRh, mkR); ctx.fill() }
            else ctx.fillRect(mkRx, mkRy, mkRw, mkRh)
            ctx.globalAlpha = op
        }
        ctx.strokeStyle = mkFarbe
        if (mkR > 0) { roundRect(ctx, mkRx, mkRy, mkRw, mkRh, mkR); ctx.stroke() }
        else ctx.strokeRect(mkRx, mkRy, mkRw, mkRh)
        if (!vorschau && !_skipText && mkRw > 20) {
            ctx.save()
            ctx.setLineDash([])
            var mkFs = Math.max(5, Math.round(2.2 * cv.mmToPx * cv.zoom))
            ctx.font        = mkFs + "px sans-serif"
            ctx.textBaseline = "top"
            ctx.textAlign    = "center"
            ctx.fillStyle   = mkFarbe
            ctx.globalAlpha = op
            var mkOx   = (mkEd.bmkOffsetX !== undefined ? mkEd.bmkOffsetX : 0) * cv.zoom
            var mkOy   = (mkEd.bmkOffsetY !== undefined ? mkEd.bmkOffsetY : 0) * cv.zoom
            var mkPfx  = mkSaved ? "✓ " : "⬜ "
            var mkName = mkEd.name || qsTr("Makro")
            var mkNameZ = mkName.split("\n")
            var mkTy = mkRy + Math.round(4 * cv.zoom) + mkOy
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
            stadiumPfad(ctx, shX, shY, shW, shH); ctx.fill()
            ctx.globalAlpha = op
        }
        ctx.strokeStyle = shFarbe
        stadiumPfad(ctx, shX, shY, shW, shH); ctx.stroke()

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
                ctx.font = Math.max(8, Math.round(2.5 * cv.mmToPx * cv.zoom)) + "px sans-serif"
                ctx.fillStyle  = shFarbe
                ctx.globalAlpha = op
                ctx.fillText(shBez, shCx, shCy)
                ctx.restore()
            }
        }
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
        var schnitte = cv.geometrie.kabelSchnittNetzeBerechnenCached(el, netze)
        if (schnitte.length === 0) return

        var _rawAdn       = el.extraDaten ? el.extraDaten.adern : null
        var klAdern       = (_rawAdn && _rawAdn.length > 0) ? _rawAdn : []
        var aderZuordnung = (el.extraDaten && el.extraDaten.aderZuordnung)
                            ? el.extraDaten.aderZuordnung : null
        var klColor = el.strichFarbe || "#e07000"

        // Senkrechter Einheitsvektor zur Linie (Seite: visuell oben im Viewport)
        var nx = -kDyW/kLenW, ny = kDxW/kLenW
        if (ny > 0) { nx = -nx; ny = -ny }  // immer nach oben zeigen

        var kLabelFs = Math.max(6, Math.round(1.8 * cv.mmToPx * cv.zoom))
        var kTickLen = 5 * cv.zoom / 10

        ctx.save()
        for (var sci = 0; sci < schnitte.length; sci++) {
            var sc = schnitte[sci]
            var wx = kx1 + sc.t * kDxW
            var wy = ky1 + sc.t * kDyW
            var vx = wx * cv.zoom + cv.worldX
            var vy = wy * cv.zoom + cv.worldY

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
            var zugeordnet = cv.netzberechnung._netLookup(aderZuordnung, [sc.aderKey, sc.netKey, sc.legacyNetKey])
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
            if (!cv.bewegungAktiv && 1.8 * cv.mmToPx * cv.zoom >= 7) {
                ctx.fillStyle = klColor
                ctx.fillText(labelText, lx, ly)
            }
        }
        ctx.restore()
    }

    function maleAutoVerbindungen(ctx, netze) {
        if (netze === undefined) netze = cv.netzberechnung.autoNetzeBerechnenCached()
        if (netze.length === 0) return

        var _fsPfadKeys = Object.keys(cv.fehlersuchPfadIds)
        var _fsAktiv    = cv.fehlersuchModus && _fsPfadKeys.length > 0

        var kreuzungsLuecken = cv.geometrie._kreuzungsLuecken(netze)

        // Alle Aderdefinitionspunkte sammeln
        var adpList = []
        var _mavEls = cv.elementeModel.snapshot()
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
            var segAdps = cv.geometrie.adpFuerNetSegmente(segs, adpList)

            for (var si = 0; si < segs.length; si++) {
                var seg = segs[si]
                if (seg.logisch) continue   // logische QV-Brücke nicht zeichnen
                var sAdps = segAdps[si]

                // Fehlersuchmodus: Segment ausblenden wenn nicht im aktiven Pfad
                if (_fsAktiv) {
                    var _eA = cv.elementeModel.element(seg.elIdxA)
                    var _eB = cv.elementeModel.element(seg.elIdxB)
                    var _imPfad = cv.fehlersuchPfadIds[(_eA.id || -1)] !== undefined
                               && cv.fehlersuchPfadIds[(_eB.id || -1)] !== undefined
                    ctx.globalAlpha = _imPfad ? 1.0 : 0.12
                } else {
                    ctx.globalAlpha = 1.0
                }

                var lineClr = cv.geometrie.signaltypFarbe(net.signaltyp)
                if (net.signaltyp !== "konflikt" && sAdps.length > 0 && sAdps[0].ed.aderfarbe)
                    lineClr = cv.geometrie.aderFarbeZuCanvas(sAdps[0].ed.aderfarbe)

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
                    var luecke  = 4 / cv.zoom
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
                            ctx.moveTo(pos * cv.zoom + cv.worldX, hy * cv.zoom + cv.worldY)
                            ctx.lineTo(ls  * cv.zoom + cv.worldX, hy * cv.zoom + cv.worldY)
                            ctx.stroke()
                        }
                        pos = le
                    }
                    if (pos < hx2) {
                        ctx.beginPath()
                        ctx.moveTo(pos * cv.zoom + cv.worldX, hy * cv.zoom + cv.worldY)
                        ctx.lineTo(hx2 * cv.zoom + cv.worldX, hy * cv.zoom + cv.worldY)
                        ctx.stroke()
                    }
                    ctx.restore()
                } else {
                    ctx.beginPath()
                    ctx.moveTo(seg.x1 * cv.zoom + cv.worldX, seg.y1 * cv.zoom + cv.worldY)
                    ctx.lineTo(seg.x2 * cv.zoom + cv.worldX, seg.y2 * cv.zoom + cv.worldY)
                    ctx.stroke()
                }

                if (sAdps.length >= 4 && !cv.bewegungAktiv) {
                    var mvx = (seg.x1 + seg.x2) / 2 * cv.zoom + cv.worldX
                    var mvy = (seg.y1 + seg.y2) / 2 * cv.zoom + cv.worldY
                    ctx.save()
                    ctx.font = "bold " + Math.max(8, Math.round(9 * cv.zoom)) + "px sans-serif"
                    ctx.fillStyle = lineClr
                    ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                    ctx.fillText("" + sAdps.length, mvx, mvy - 3)
                    ctx.restore()
                }
            }
        }

        ctx.lineWidth = 1.5

        // Ausgewählte Verbindungssegmente hervorheben
        if (cv.ausgewaehltVerbindung) {
            var sel = cv.ausgewaehltVerbindung
            ctx.lineWidth = 3.5; ctx.globalAlpha = 0.65; ctx.strokeStyle = "#ffffff"
            for (var si3 = 0; si3 < sel.segmente.length; si3++) {
                var s = sel.segmente[si3]
                ctx.beginPath()
                ctx.moveTo(s.x1*cv.zoom+cv.worldX, s.y1*cv.zoom+cv.worldY)
                ctx.lineTo(s.x2*cv.zoom+cv.worldX, s.y2*cv.zoom+cv.worldY)
                ctx.stroke()
            }
            ctx.lineWidth = 1.5; ctx.globalAlpha = 1.0
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
                    if (cv.bewegungAktiv) break
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
        var _steBuOk   = (!vorschau && _istSteBu) ? cv.hatLogischeVerbindung(idx) : false
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
            drawByPrimitiv(ctx, el.symbolId || "", Math.abs(sw), Math.abs(sh), _steBuFarbe)
            // Erweiterungsmodifier im lokalen Koordinatensystem (dreht/spiegelt mit)
            if (!vorschau) {
                var erw = (el.extraDaten && Array.isArray(el.extraDaten.erweiterungen))
                          ? el.extraDaten.erweiterungen : []
                if (erw.length > 0)
                    maleModifier(ctx, erw, Math.abs(sw), Math.abs(sh))
            }
            ctx.restore()

            // Pin-Marker zeichnen (immer sichtbar, selektiert = hervorgehoben)
            if (!vorschau) {
                var pins = el.symbolId === "querverweis"
                           ? cv.geometrie.querverweisPin(el)
                           : symbolDefinitionModel.pinsForSymbol(el.symbolId || "")
                ctx.setLineDash([])
                for (var pi = 0; pi < pins.length; pi++) {
                    var pp = cv.geometrie.pinViewportPos(el, pins[pi].x, pins[pi].y)
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
                        var _pbFs = Math.max(6, Math.round(1.8 * cv.mmToPx * cv.zoom))
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
                            var _pbPos = cv.geometrie.pinViewportPos(el, _pbPin.x, _pbPin.y)
                            // Richtungsvektor mit Spiegelung + Rotation transformieren
                            // (identisch zur Transformation in pinViewportPos)
                            var _pbOx = _pbPin.offenX || 0
                            var _pbOy = _pbPin.offenY || 0
                            if (el.spiegelX) _pbOx = -_pbOx
                            if (el.spiegelY) _pbOy = -_pbOy
                            var _pbRad = ((el.rotation || 0) * Math.PI / 180)
                            var _pbTx  = _pbOx * Math.cos(_pbRad) - _pbOy * Math.sin(_pbRad)
                            var _pbTy  = _pbOx * Math.sin(_pbRad) + _pbOy * Math.cos(_pbRad)
                            var _pbOff = 4 * cv.zoom
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
                        var bmkFs   = Math.max(5, Math.round(schrift * cv.mmToPx * cv.zoom))
                        var ftFs    = Math.max(4, Math.round(schrift * 0.85 * cv.mmToPx * cv.zoom))
                        var bmkOx   = (bmkEd.bmkOffsetX !== undefined ? bmkEd.bmkOffsetX : 0)  * cv.zoom
                        var bmkOy   = (bmkEd.bmkOffsetY !== undefined ? bmkEd.bmkOffsetY : -14) * cv.zoom
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
                            var ftOff = bkCy + 2 * cv.zoom
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
                            var ftY = Math.max(vy1, vy2) + 3 * cv.zoom
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
            if (!vorschau && cv.ibnModus) {
                var _ibnBmk = (el.extraDaten || {}).bmk || ""
                if (_ibnBmk !== "") {
                    var _ibnSt = cv.ibnStatusMap[_ibnBmk] || "offen"
                    var _ibnClr = _ibnSt === "abgeschlossen" ? "#3cb371"
                                : _ibnSt === "in_arbeit"     ? "#f0a030"
                                                              : "#cc4444"
                    var _ibnCx = Math.max(vx1, vx2) - 5 * cv.zoom / cv.mmToPx
                    var _ibnCy = Math.min(vy1, vy2) + 5 * cv.zoom / cv.mmToPx
                    var _ibnR  = Math.max(3, 3 * cv.zoom)
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
            if (!vorschau && (el.id || 0) > 0 && cv._spsKonfliktSet[el.id]) {
                var _spsR  = Math.max(3, 3 * cv.zoom)
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
            if (!vorschau && cv.fehlersuchModus) {
                var _fsPfadNr = cv.fehlersuchPfadIds[(el.id || -1)]
                if (_fsPfadNr !== undefined &&
                        cv.fehlersuchStartIds[_fsPfadNr] === (el.id || -1)) {
                    var _fsR  = Math.max(4, 4 * cv.zoom)
                    var _fsCx = (vx1 + vx2) / 2
                    var _fsCy = (vy1 + vy2) / 2
                    ctx.save()
                    ctx.globalAlpha = 0.85
                    ctx.beginPath()
                    ctx.arc(_fsCx, _fsCy, _fsR, 0, Math.PI * 2)
                    ctx.strokeStyle = cv._fehlersuchPfadFarben[
                        _fsPfadNr % cv._fehlersuchPfadFarben.length]
                    ctx.lineWidth   = 2.5
                    ctx.stroke()
                    ctx.restore()
                }
            }

            // ── Fehlersuch-Unterbrechungsmarker (Trenner) ────────
            if (!vorschau && cv.fehlersuchModus &&
                    cv.fehlersuchUnterbrechungen[(el.id || -1)] !== undefined) {
                var _fuR  = Math.max(5, 5 * cv.zoom)
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
                var _hfRef = cv._hfReferenzMap[el.betriebsmittelId]
                if (_hfRef
                        && _hfRef.hauptElementId !== (el.id || -1)
                        && _hfRef.seiteId        !== cv.seiteId) {
                    var _hfTxt = "← /" + _hfRef.blattnummer
                    var _hfEd  = el.extraDaten || {}
                    var _hfFs  = Math.max(4, Math.round(
                        (_hfEd.schriftgroesse !== undefined ? _hfEd.schriftgroesse : 2.5)
                        * 0.75 * cv.mmToPx * cv.zoom))
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
                                     Math.max(vx1, vx2) + 3 * cv.zoom,
                                     (vy1 + vy2) / 2)
                    } else {
                        ctx.textAlign    = "center"
                        ctx.textBaseline = "top"
                        ctx.fillText(_hfTxt,
                                     (vx1 + vx2) / 2,
                                     Math.max(vy1, vy2) + 2 * cv.zoom)
                    }
                    ctx.restore()
                }
            }

            // Querverweis: Signalname + Partnerseite – BMK-Stil
            if (!vorschau && !_skipText && el.symbolId === "querverweis") {
                var qed     = el.extraDaten || {}
                var qSn     = qed.signalname || ""
                var _qpInfo  = cv._querverweisPartnerMap[idx]
                var qPartner = _qpInfo ? (_qpInfo.label || "") : ""
                if (qSn !== "" || qPartner !== "") {
                    var qFs   = Math.max(10, Math.round(2.0 * cv.mmToPx * cv.zoom))
                    var qFsS  = Math.max(6, Math.round(1.6 * cv.mmToPx * cv.zoom))
                    var qRot  = ((el.rotation || 0) % 360 + 360) % 360
                    var qSenk = (qRot === 90 || qRot === 270)
                    var qCx   = (vx1 + vx2) / 2
                    var qCy   = (vy1 + vy2) / 2
                    ctx.save()
                    ctx.globalAlpha = 1.0
                    if (qSenk) {
                        var qX = Math.min(vx1, vx2) - 4 * cv.zoom
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
                        var qY = Math.min(vy1, vy2) - 3 * cv.zoom
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
                    var _gaEls = cv._drawCanvas._gkListe
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

                    var gaFs   = Math.max(10, Math.round(2.0 * cv.mmToPx * cv.zoom))
                    var gaRot  = ((el.rotation || 0) % 360 + 360) % 360
                    var gaSenk = (gaRot === 90 || gaRot === 270)
                    var gaCx   = (vx1 + vx2) / 2
                    var gaCy   = (vy1 + vy2) / 2
                    var gaOx   = (gaed.bmkOffsetX !== undefined ? gaed.bmkOffsetX : 0) * cv.zoom
                    var gaOy   = (gaed.bmkOffsetY !== undefined ? gaed.bmkOffsetY : 0) * cv.zoom
                    ctx.save()
                    ctx.globalAlpha = 1.0
                    ctx.font = "bold " + gaFs + "px sans-serif"
                    ctx.fillStyle = gewaehlt ? "#f0a030" : "#4488cc"
                    if (gaSenk) {
                        // 90°: pin unten → Text oben  |  270°: pin oben → Text unten
                        var gaPinUnten = (gaRot === 90)
                        var gaY = gaPinUnten
                                  ? Math.min(vy1, vy2) - 3 * cv.zoom + gaOy
                                  : Math.max(vy1, vy2) + 3 * cv.zoom + gaOy
                        ctx.textAlign = "center"
                        ctx.textBaseline = gaPinUnten ? "bottom" : "top"
                        ctx.fillText(gaLabel, gaCx + gaOx, gaY)
                    } else {
                        // 0°: pin rechts → Text links  |  180°: pin links → Text rechts
                        var gaPinRechts = (gaRot === 0)
                        var gaX = gaPinRechts
                                  ? Math.min(vx1, vx2) - 4 * cv.zoom + gaOx
                                  : Math.max(vx1, vx2) + 4 * cv.zoom + gaOx
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
                    var paFs   = Math.max(5, Math.round(paSchrift * cv.mmToPx * cv.zoom))
                    var paFtFs = Math.max(4, Math.round(paSchrift * 0.85 * cv.mmToPx * cv.zoom))
                    var paRot  = ((el.rotation || 0) % 360 + 360) % 360
                    var paSenk = (paRot === 90 || paRot === 270)
                    var paCx   = (vx1 + vx2) / 2
                    var paCy   = (vy1 + vy2) / 2
                    var paOx   = (paed.bmkOffsetX !== undefined ? paed.bmkOffsetX : 0) * cv.zoom
                    var paOy   = (paed.bmkOffsetY !== undefined ? paed.bmkOffsetY : 0) * cv.zoom
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
                                    ? Math.min(vy1, vy2) - 3 * cv.zoom + paOy
                                    : Math.max(vy1, vy2) + 3 * cv.zoom + paOy
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
                                   ? Math.min(vx1, vx2) - 4 * cv.zoom + paOx
                                   : Math.max(vx1, vx2) + 4 * cv.zoom + paOx
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
                    && 2.0 * cv.mmToPx * cv.zoom >= 7) {
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
                var kaFs    = Math.max(6, Math.round(1.5 * cv.mmToPx * cv.zoom))
                var kaBmkFs = Math.max(10, Math.round(2.2 * cv.mmToPx * cv.zoom))
                var kaRot   = ((el.rotation || 0) % 360 + 360) % 360
                var kaSenk  = (kaRot === 90 || kaRot === 270)
                var kaCx    = (vx1 + vx2) / 2
                var kaCy    = (vy1 + vy2) / 2
                var kaOx    = (kaed.bmkOffsetX !== undefined ? kaed.bmkOffsetX : 0) * cv.zoom
                var kaOy    = (kaed.bmkOffsetY !== undefined ? kaed.bmkOffsetY : 0) * cv.zoom
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
                                ? Math.min(vx1, vx2) - 4 * cv.zoom + kaOy
                                : Math.max(vx1, vx2) + 4 * cv.zoom + kaOy
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
                                ? Math.min(vy1, vy2) - 3 * cv.zoom + kaOy
                                : Math.max(vy1, vy2) + 3 * cv.zoom + kaOy
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
                    && 2.0 * cv.mmToPx * cv.zoom >= 7) {
                var aed = el.extraDaten || {}
                var adpZeilen = []
                if (aed.bezeichnung) adpZeilen.push({ text: aed.bezeichnung, bold: true })
                var adpFarb = aed.aderfarbe || "", adpQuer = aed.querschnitt_mm2
                if (adpFarb !== "" || (adpQuer !== undefined && adpQuer > 0))
                    adpZeilen.push({ text: (adpFarb || "–") + (adpQuer > 0 ? "  " + (adpQuer + "").replace('.', ',') + " mm²" : ""), bold: false })
                if (aed.laenge_m && aed.laenge_m > 0)
                    adpZeilen.push({ text: qsTr("\u2192 ") + (aed.laenge_m + "").replace('.', ',') + " m", bold: false })
                if (adpZeilen.length > 0) {
                    var adpFs    = Math.max(6, Math.round(2.0 * cv.mmToPx * cv.zoom))
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
                        var adpLx = Math.min(vx1, vx2) - 4 * cv.zoom
                        var adpLy = adpCy - adpZeilen.length * adpLineH / 2
                        ctx.textAlign = "right"; ctx.textBaseline = "top"
                        for (var az1 = 0; az1 < adpZeilen.length; az1++) {
                            ctx.font = (adpZeilen[az1].bold ? "bold " : "") + adpFs + "px sans-serif"
                            ctx.fillStyle = adpTextFarbe
                            ctx.fillText(adpZeilen[az1].text, adpLx, adpLy + az1 * adpLineH)
                        }
                    } else {
                        // Waagerecht: Text über dem Symbol, horizontal zentriert
                        var adpOy = Math.min(vy1, vy2) - 3 * cv.zoom
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
}
