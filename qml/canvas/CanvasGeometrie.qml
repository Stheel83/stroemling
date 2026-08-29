import QtQuick

// Geometrie- und Hit-Test-Funktionen des SchaltplanCanvas: Koordinaten-
// Transformationen (Viewport↔Welt, Raster), Treffertests (Element/Griff/
// Verbindung/Kabelkreuzung), Pin-Positionen, sowie die dazugehörigen reinen
// Hilfsfunktionen (Punkt-Segment-Abstand, ADP-Pfadverfolgung, Farbtabellen).
// Kein Rendering (kein `ctx`-Zeichnen) — nur Berechnung/Abfrage.
// cv: Referenz auf SchaltplanCanvas (root). REFACTOR-01 Stufe 3.
QtObject {
    id: handler
    required property var cv

    // --------------------------------------------------------
    // Koordinaten-Hilfsfunktionen
    // --------------------------------------------------------
    function rasterPunkt(weltX, weltY) {
        return Qt.point(Math.round(weltX/cv.gridPx)*cv.gridPx, Math.round(weltY/cv.gridPx)*cv.gridPx)
    }
    function viewportZuWelt(vpX, vpY) {
        return Qt.point((vpX-cv.worldX)/cv.zoom, (vpY-cv.worldY)/cv.zoom)
    }
    function weltZuViewport(wX, wY) {
        return Qt.point(wX*cv.zoom+cv.worldX, wY*cv.zoom+cv.worldY)
    }

    // --------------------------------------------------------
    // Treffer-Test
    // --------------------------------------------------------
    function elementBeiPosition(vpX, vpY) {
        return cv.elementeModel.elementBeiPosition(vpX, vpY, cv.zoom, cv.worldX, cv.worldY)
    }

    // Prüft ob Maus über einem Handle des selektierten Elements liegt.
    // Gibt Handle-Index zurück oder -1.
    function griffBeiPosition(vpX, vpY) {
        if (cv.ausgewaehlt < 0 || cv.ausgewaehlt >= cv.elementeModel.anzahl) return -1
        var el  = cv.elementeModel.element(cv.ausgewaehlt)
        var pts = griffPunkte(el)
        for (var i = 0; i < pts.length; i++) {
            var gvx = pts[i].x * cv.zoom + cv.worldX
            var gvy = pts[i].y * cv.zoom + cv.worldY
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

    // Gibt {anlage, ort} für ein Element zurück – per kleinsten umschließenden
    // Strukturkasten, Fallback auf Seiten-Normblattdaten.
    function anlageOrtFuer(el) {
        var nd     = cv.normblattDaten
        var anlage = nd ? (nd.anlageKuerzel || "") : ""
        var ort    = nd ? (nd.ortKuerzel    || "") : ""
        var cx = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
        var bestArea = Infinity
        var _anlEls = cv.elementeModel.snapshot()
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

    // Pin-Position in Weltkoordinaten (analog zu pinViewportPos, aber ohne Zoom)
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

    // Anker-Pin eines Symbols (SYMBOL-ANKER-01): der Pin mit der kleinsten ID
    // (= zuerst angelegter Pin, üblich Anschluss "1", pinsForSymbol() liefert
    // ORDER BY id ASC). Symbole ohne Pins (z.B. aderdefinition) fallen auf
    // den Bbox-Mittelpunkt zurück — reproduziert das bisherige Verhalten für
    // diese Fälle unverändert.
    function ankerPinFuerSymbolId(sid) {
        if (!sid) return { x: 0.5, y: 0.5 }
        var pins = symbolDefinitionModel.pinsForSymbol(sid)
        if (!pins || pins.length === 0) return { x: 0.5, y: 0.5 }
        return { x: pins[0].x, y: pins[0].y }
    }

    // Welt-Offset vom Element-Ursprung (x1,y1) zum Anker-Pin, unter
    // Berücksichtigung der aktuellen Rotation/Spiegelung — reine
    // Umformung von pinWeltPos() relativ zu (x1,y1) statt absolut.
    function ankerOffsetFuerElement(el) {
        var ap = ankerPinFuerSymbolId(el.symbolId)
        var wp = pinWeltPos(el, ap.x, ap.y)
        return { x: wp.x - el.x1, y: wp.y - el.y1 }
    }

    // Inverse zu pinWeltPos(): Bbox-Ursprung (x1,y1) so berechnen, dass der
    // Anker-Pin bei gegebener Rotation exakt auf (ankerWeltX, ankerWeltY)
    // landet. Wird beim Platzieren neuer Symbole genutzt, damit der
    // Anker-Pin (nicht der Bbox-Mittelpunkt) aufs Raster einrastet — nötig
    // weil Breite/Höhe nicht immer ein gerades Vielfaches des 4mm-Rasters
    // sind (z.B. 12mm-Kontakte, SYMBOL-GROESSE-01), der Mittelpunkt bei
    // solchen Symbolen also selbst nicht rasterecht ist.
    function boxPositionFuerAnker(sid, w, h, rotDeg, ankerWeltX, ankerWeltY) {
        var ap   = ankerPinFuerSymbolId(sid)
        var cx   = (ap.x - 0.5) * w
        var cy   = (ap.y - 0.5) * h
        var rot  = (rotDeg || 0) * Math.PI / 180
        var offX = cx * Math.cos(rot) - cy * Math.sin(rot)
        var offY = cx * Math.sin(rot) + cy * Math.cos(rot)
        return { x1: ankerWeltX - offX - w / 2, y1: ankerWeltY - offY - h / 2 }
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
        var vx1 = el.x1 * cv.zoom + cv.worldX
        var vy1 = el.y1 * cv.zoom + cv.worldY
        var vx2 = el.x2 * cv.zoom + cv.worldX
        var vy2 = el.y2 * cv.zoom + cv.worldY
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
        if (sig === "sicherheit")      return "#d4a017"
        if (sig === "fe")              return "#4caf7d"
        if (sig === "konflikt")        return "#ff2200"
        if (sig === "unversorgt")      return "#ffaa00"
        return "#4a9eff"   // neutral
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
        var netze = cv.netzberechnung.autoNetzeBerechnen()

        // ADPs für Pfad-Annotation sammeln
        var adpList = []
        var _vbpEls = cv.elementeModel.snapshot()
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
                var vx1 = seg.x1*cv.zoom+cv.worldX, vy1 = seg.y1*cv.zoom+cv.worldY
                var vx2 = seg.x2*cv.zoom+cv.worldX, vy2 = seg.y2*cv.zoom+cv.worldY
                var d = punktZuSegmentAbstand(vpX, vpY, vx1, vy1, vx2, vy2)
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
            var segAdps = adpFuerNetSegmente(bestNet.segmente, adpList)
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
        return "#4a9eff"
    }

    // Adjazenzliste über Segment-Indizes: zwei Segmente gelten als benachbart,
    // wenn sie ein gemeinsames Winkel- oder Querverweis-Element teilen (beide
    // transparent für Ader-/Farb-Propagation). Treffpunkt/Treffpunkt_L sind
    // bewusst KEINE Kante hier – sie sind Verschmelzungs-, keine Durchlauf-
    // punkte (→ berechneRoutingSymbolFarben()/_treffpunktZielBaender() in
    // CanvasRenderHandler.qml für die Sonderbehandlung an Treffpunkten).
    // Gemeinsam genutzt von adpFuerNetSegmente() und der Treffpunkt-
    // Ziel-Bänderung.
    function _winkelAdjazenz(netSegmente) {
        var n = netSegmente.length
        var adj = []
        for (var ki = 0; ki < n; ki++) adj.push([])
        for (var si1 = 0; si1 < n; si1++) {
            var sA = netSegmente[si1]
            for (var sj = si1 + 1; sj < n; sj++) {
                var sB = netSegmente[sj]
                var cands = [sA.elIdxA, sA.elIdxB]
                for (var ci = 0; ci < cands.length; ci++) {
                    var idx = cands[ci]
                    if (idx === sB.elIdxA || idx === sB.elIdxB) {
                        if (idx >= 0 && idx < cv.elementeModel.anzahl) {
                            var shEl = cv.elementeModel.element(idx)
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
        return adj
    }

    // Gibt für jeden Segment-Index die Liste der zugehörigen ADPs zurück.
    // Pfadverfolgung durch Winkeln: Winkeln sind transparent, T-Stücke sind Grenzen.
    function adpFuerNetSegmente(netSegmente, adpList) {
        var n = netSegmente.length
        var directAdp = [], ki
        for (ki = 0; ki < n; ki++) directAdp.push([])

        for (var ai = 0; ai < adpList.length; ai++) {
            var adp = adpList[ai]
            var bestSi = -1, bestD = cv.gridPx * 0.75
            for (var si0 = 0; si0 < n; si0++) {
                var seg0 = netSegmente[si0]
                if (seg0.logisch) continue   // kein ADP auf logischer QV-Brücke
                var d0 = punktZuSegmentAbstand(adp.cx, adp.cy,
                             seg0.x1, seg0.y1, seg0.x2, seg0.y2)
                if (d0 < bestD) { bestD = d0; bestSi = si0 }
            }
            if (bestSi >= 0) directAdp[bestSi].push(adp)
        }

        var adj = _winkelAdjazenz(netSegmente)

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

    // Viewport-Hit-Test auf die Ader-Nummer-Beschriftung an Kabel-
    // Kreuzungspunkten (Klickziel für die Inline-Aderzuordnung).
    // Nutzt dieselbe Geometrie wie maleKabelSchnitte() (drawCanvas). Gibt bei
    // Treffer {kabelEl, aderKey, verbindungId, aktuelleAderNr, istLeer, vpX, vpY}
    // zurück (vpX/vpY = Anker-Position für das Popup), sonst null.
    function kabelKreuzungBeiPosition(vpX, vpY) {
        var elemente = cv.elementeModel.snapshot()
        var netze    = cv.netzberechnung.autoNetzeBerechnen()
        var ctxM     = cv._drawCanvas.getContext("2d")
        var kLabelFs = Math.max(6, Math.round(1.8 * cv.mmToPx * cv.zoom))
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
            // KABEL-ADERFARBE-PROPAGATION-04: dieselbe Nummerierung wie
            // maleKabelSchnitte() (sonst stimmt der Hit-Test nicht mehr mit
            // dem tatsächlich gezeichneten Label überein).
            var kabelId2 = (el.extraDaten && el.extraDaten.kabelId) || 0
            var gepoolt2 = kabelAderProKabelCached(kabelId2)

            var nx = -kDyW/kLenW, ny = kDxW/kLenW
            if (ny > 0) { nx = -nx; ny = -ny }
            var kTickLen = 5 * cv.zoom / 10

            for (var sci = 0; sci < schnitte.length; sci++) {
                var sc = schnitte[sci]
                var wx = kx1 + sc.t * kDxW, wy = ky1 + sc.t * kDyW
                var vx = wx * cv.zoom + cv.worldX
                var vy = wy * cv.zoom + cv.worldY

                var _bres  = cv.netzberechnung._aderNrFuerKreuzung(aderZuordnung, sc, sci, gepoolt2)
                var aderNr = _bres.aderNr
                var istLeer = _bres.istLeer
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
        var elemente = cv.elementeModel.snapshot()
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
                        aderKey:      cv.netzberechnung._lokalerAderSchluessel(seg, net, elemente),
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
    // OPT-VERBRENDER-CACHE-01: gecacht in cv._cachedKreuzungsLuecken, invalidiert
    // zusammen mit _cachedNetze bei elementeModel.geaendert (nicht bei jedem
    // Repaint neu — die O(h×v)-Doppelschleife unten kostet sonst auch beim
    // reinen Schwenken/Zoomen ohne Modelländerung).
    function _kreuzungsLuecken(netze) {
        if (cv._cachedKreuzungsLuecken !== null) return cv._cachedKreuzungsLuecken
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
        cv._cachedKreuzungsLuecken = result
        return result
    }

    function kabelSchnittNetzeBerechnenCached(el, netze) {
        var elId = el ? (el.id || 0) : 0
        if (elId > 0 && cv._cachedKabelSchnitte[elId] !== undefined)
            return cv._cachedKabelSchnitte[elId]
        var result = kabelSchnittNetzeBerechnen(el, netze)
        if (elId > 0) cv._cachedKabelSchnitte[elId] = result
        return result
    }

    // KABEL-ADERFARBE-PROPAGATION-04: gecachte Sicht auf kabel_ader für EIN
    // Kabel (verbindungId → {aderNr, farbe, farbe2, bezeichnung}) — die
    // Tabelle wird bei jedem Speichern seitenübergreifend gepoolt
    // (Database::kabelAderProjektweitSynchronisieren()) und ist damit die
    // AUTORITATIVE, konfliktfreie Nummerierung. Als Vorrang vor dem rein
    // lokalen Positions-Fallback (si+1) genutzt, damit Canvas-Farbe/
    // Ader-Label/EP-Anzeige nach dem Speichern konsistent bleiben, statt
    // dass jede Kabellinie unabhängig wieder bei 1 zu zählen anfängt (genau
    // das war der Bugreport: zwei Linien mit gleichem BMK, Adern doppelt
    // vergeben). Für eine brandneue, noch nie gespeicherte Kreuzung liefert
    // die Tabelle naturgemäß noch nichts — dafür bleibt si+1 als vorläufige
    // Vorschau bis zum nächsten Speichern.
    // KABEL-UEBERARBEITUNG-01/PROPAGATION-07: gecachte Sicht auf kabel_ader,
    // geschlüsselt über den LOKALEN NETZ-02-Ader-Schlüssel (aderKey), NICHT
    // mehr über verbindung_id. Ein Kontakt leitet das Potenzial durch
    // (Netzberechnung bleibt unverändert), aber auf jeder Kontaktseite liegt
    // physisch eine ANDERE Ader — mit verbindung_id als Schlüssel hätten
    // zwei unterschiedliche Adern, die zufällig dieselbe verbindung_id
    // teilen, sich im JS-Objekt gegenseitig überschrieben (nur die zuletzt
    // verarbeitete Zeile hätte gewonnen). s. Nutzer-Klarstellung: "auf jeder
    // Kontakt Seite ist eine andere physische Ader".
    function kabelAderProKabelCached(kabelId) {
        if (kabelId <= 0) return {}
        if (cv._cachedKabelAderProKabel[kabelId] !== undefined)
            return cv._cachedKabelAderProKabel[kabelId]
        var map = {}
        var rows = db.kabelAlleAderLaden(kabelId)
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i]
            if (!r.aderKey) continue   // freie Ader (keiner Kreuzung zugeordnet) oder Alt-Zeile ohne aderKey
            map[r.aderKey] = { aderNr: r.aderNr, farbe: r.farbe || "", farbe2: r.farbe2 || "", bezeichnung: r.bezeichnung || "" }
        }
        cv._cachedKabelAderProKabel[kabelId] = map
        return map
    }

    // KABEL-ADERFARBE-PROPAGATION-02/03: Liefert für eine Kabellinie die
    // Adern, die AKTUELL an einer echten Kreuzung hängen (nicht die
    // statische Roster-Liste aus extra_daten.adern, die auch ohne jede
    // Kreuzung unverändert bleibt). Pro Kreuzung wird die Ader über
    // aderZuordnung (aderKey > netKey > legacyNetKey) aufgelöst; ohne
    // explizite Zuordnung zunächst über die seitenübergreifend gepoolte
    // kabel_ader-Tabelle (PROPAGATION-04), erst danach über den rein
    // lokalen Positions-Fallback (si+1). "0" (explizit keine Ader)
    // übersprungen, Duplikate (mehrere Kreuzungen → gleiche Ader)
    // zusammengefasst. Gibt [{aderNr, farbe, farbe2, bezeichnung,
    // verbindungId}, ...] zurück, sortiert nach aderNr. Gemeinsam genutzt
    // von EpKabelAdernBlock.qml (Anzeige, mit gecachten Netzen/Schnitten)
    // und CanvasCacheHandler.qml (Speichern) — bewusst nicht dupliziert,
    // s. Lehre aus KABEL-ADERFARBE-PROPAGATION-01 (Renderer-Eigenart
    // mehrfach kopiert).
    function kabelAktiveAderZuordnungen(el, netze, verwendeCache) {
        if (!el || el.typ !== "kabellinie") return []
        var ed = el.extraDaten || {}
        var roster = ed.adern || []
        if (roster.length === 0) return []

        var rosterMap = {}
        for (var ri = 0; ri < roster.length; ri++) {
            var nr = roster[ri].aderNr !== undefined ? roster[ri].aderNr : (ri + 1)
            rosterMap[nr] = roster[ri]
        }

        var schnitte = verwendeCache ? kabelSchnittNetzeBerechnenCached(el, netze)
                                      : kabelSchnittNetzeBerechnen(el, netze)
        var aderZuordnung = ed.aderZuordnung || null
        var kabelId = ed.kabelId || 0
        var gepoolt = kabelAderProKabelCached(kabelId)

        var gesehen = {}, out = []
        for (var si = 0; si < schnitte.length; si++) {
            var sc = schnitte[si]
            var res = cv.netzberechnung._aderNrFuerKreuzung(aderZuordnung, sc, si, gepoolt)
            if (res.istLeer) continue
            var aderNr = res.aderNr
            if (gesehen[aderNr]) continue
            gesehen[aderNr] = true
            var roAder = rosterMap[aderNr] || {}
            out.push({
                aderNr:       aderNr,
                farbe:        roAder.farbe || "",
                farbe2:       roAder.farbe2 || "",
                bezeichnung:  roAder.bezeichnung || "",
                verbindungId: sc.verbindungId || 0
            })
        }
        out.sort(function(a, b) { return a.aderNr - b.aderNr })
        return out
    }
}
