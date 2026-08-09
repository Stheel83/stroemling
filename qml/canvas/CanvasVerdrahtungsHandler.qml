import QtQuick

// M11: Verdrahtungsweg-Algorithmus + Verbindungsannotationen.
// Hält keinen eigenen Zustand – schreibt Ergebnisse direkt auf cv.*.
QtObject {
    required property var cv

    // ── M11: Verdrahtungsweg-Algorithmus (Stufe 2) ──────────────
    // Berechnet Von/Nach-Gerät:Pin für alle kabel_adern dieses Projekts,
    // deren Kabellinie auf der aktuellen Seite liegt.
    // Stufe 2: per-Ader-Traversal mit Treffpunkt-Routing.
    function verdrahtungswegeAktualisieren() {
        if (cv.projektId < 0 || cv.seiteId < 0) return
        var adern = db.kabelAderListeMitVerbindung(cv.projektId)
        if (!adern || adern.length === 0) return

        var netze = cv.netzberechnung.autoNetzeBerechnen()
        // verbindungId → net
        var verbNetMap = {}
        for (var ni = 0; ni < netze.length; ni++) {
            var n = netze[ni]
            if ((n.verbindungId || 0) > 0) verbNetMap[n.verbindungId] = n
        }

        // grafik_element.id → Elementindex in elementeModel
        var _verEls = cv.elementeModel.snapshot()
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
            db.kabelAderEndpunkteBulkSetzen(cv.projektId, ergebnisse)
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
        var crossed = _netSegmentKreuzungBerechnen(cv.elementeModel.element(kabellinieElIdx), net)
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
            var el = cv.elementeModel.element(parseInt(idxStr))
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
        var el = cv.elementeModel.element(startElIdx)
        if (!el || !el.typ) return "⚠ Kein Endpunkt"
        var sid = el.symbolId || ""

        // Endpunkt-Symbole: Traversal hält hier
        if (sid === "geraeteanschluss" || sid === "potenzial" ||
            sid === "klemme_anschluss" || sid === "isoliert_gelegte_ader")
            return _formatEndpunkt(el, net)

        // Querverweis: Cross-page traversal (Partnerseite laden und dort weitersuchen)
        if (sid === "querverweis") {
            var partnerInfo = cv._querverweisPartnerMap[startElIdx]
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
            var wp = cv.pinWeltPos(el, pins[pi].x, pins[pi].y)
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
            if (pins[pi].name === armName) { armPos = cv.pinWeltPos(el, pins[pi].x, pins[pi].y); break }
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
            var _fmtEls = cv.elementeModel.snapshot()
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
        // KLEMME-KONFLIKT-01-Folgefix (Aug 2026): nicht mehr beim ersten
        // Treffer zurückkehren — kommen in derselben Union-Find-Gruppe
        // mehrere UNTERSCHIEDLICHE nicht-neutrale Signaltypen vor (z.B. durch
        // die Zwei-Hop-Fremdseiten-Injektion in CanvasNetzberechnung.qml),
        // ist das ein echter Konflikt, kein "erster Treffer gewinnt". Sonst
        // hängt das Ergebnis zufällig von der Array-Reihenfolge ab.
        var _erg = "neutral"
        for (var _sj = 0; _sj < verbindungen.length; _sj++) {
            var _sv = verbindungen[_sj]
            if (_sf(_sv.elIdxA) === _ziel || _sf(_sv.elIdxB) === _ziel) {
                var _ssig = _sv.signaltyp || "neutral"
                if (_ssig === "konflikt") return "konflikt"
                if (_ssig === "neutral" || _ssig === "unversorgt") continue
                if (_erg === "neutral") _erg = _ssig
                else if (_erg !== _ssig) _erg = "konflikt"
            }
        }
        return _erg
    }

    // Baut pin-basierten Adj-Graph aus einem db.grafikLaden()-Ergebnis.
    function _adjFuerElemente(elemente) {
        var posMap = {}
        for (var i = 0; i < elemente.length; i++) {
            var el = elemente[i]
            if (!el || el.typ !== "symbol" || !(el.symbolId || "")) continue
            var pins = symbolDefinitionModel.pinsForSymbol(el.symbolId)
            for (var pi = 0; pi < pins.length; pi++) {
                var wp  = cv.pinWeltPos(el, pins[pi].x, pins[pi].y)
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
            var alle = db.querverweiseLadenProjekt(cv.projektId)
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
        var annListe = db.verbindungAnnotationenLaden(cv.seiteId)
        var cache = {}
        for (var i = 0; i < annListe.length; i++) cache[annListe[i].netKey] = annListe[i]
        cv.verbindungAnnotationenCache = cache
        // Ausgewählte Verbindung im Cache aktualisieren
        if (cv.ausgewaehltVerbindung) {
            var ann = cache[cv.ausgewaehltVerbindung.netKey]
            if (ann) {
                var upd = {}; for (var k in cv.ausgewaehltVerbindung) upd[k] = cv.ausgewaehltVerbindung[k]
                upd.verbindungId = ann.verbindungId
                upd.bezeichnung  = ann.bezeichnung  || upd.bezeichnung
                upd.farbe        = ann.farbe        || upd.farbe
                upd.querschnitt  = ann.querschnitt_mm2 || upd.querschnitt
                cv.ausgewaehltVerbindung = upd
            }
        }
    }

    function verbindungAnnotationAktualisieren(key, value) {
        if (!cv.ausgewaehltVerbindung) return
        var vb = {}; for (var k in cv.ausgewaehltVerbindung) vb[k] = cv.ausgewaehltVerbindung[k]
        vb[key] = value
        cv.ausgewaehltVerbindung = vb
        // Cache aktualisieren
        var cache = {}; for (var ck in cv.verbindungAnnotationenCache) cache[ck] = cv.verbindungAnnotationenCache[ck]
        var entry = {}; if (cache[vb.netKey]) { for (var ek in cache[vb.netKey]) entry[ek] = cache[vb.netKey][ek] }
        entry[key] = value
        cache[vb.netKey] = entry
        cv.verbindungAnnotationenCache = cache
        // In DB persistieren
        if (vb.verbindungId > 0)
            db.verbindungAktualisieren(vb.verbindungId, vb.bezeichnung || "", vb.farbe || "", vb.querschnitt || 0)
        cv._drawCanvas.requestPaint()
    }
}
