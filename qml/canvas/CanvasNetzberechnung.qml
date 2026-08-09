import QtQuick

// Elektrische Netzberechnung des SchaltplanCanvas: gruppiert Auto-
// Verbindungssegmente (aus SymbolDefinitionModel::autoVerbindungenBerechnen)
// zu Netzen (Union-Find über Pin-Knotengruppen, NETZ-MEHRPOL-01), inkl.
// Klemmen-Durchleitung/Stegbrücken (KLEMME-NET-01) und stabilen NetKeys
// (NETZ-01/NETZ-02). Reine Berechnung, kein ctx/Rendering.
// cv: Referenz auf SchaltplanCanvas (root). REFACTOR-01 Stufe 2.
QtObject {
    id: handler
    required property var cv

    // Reine Routing-Elemente ohne eigene Identität (NETZ-02): dürfen bei
    // der lokalen Ader-Suche transparent übersprungen werden. Gewöhnliche
    // (auch unbeschriftete) Bauteile gehören NICHT dazu.
    property var _routingSymbolTypen: ({
        "winkel": true, "treffpunkt": true, "treffpunkt_l": true,
        "aderdefinition": true
    })

    // Delegiert an SymbolDefinitionModel::autoVerbindungenBerechnen() (C++).
    function autoVerbindungenBerechnen() {
        return symbolDefinitionModel.autoVerbindungenBerechnen(
            cv.elementeModel.snapshot(),
            cv.gridPx,
            cv.normblattDaten || {}
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
        if (!handler._routingSymbolTypen[el.symbolId || ""]) return ""
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
        var elemente = cv.elementeModel.snapshot()

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
        if (cv.projektId >= 0) {
            var _stege = db.klemmenStegbrueckenGruppen(cv.projektId)
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
        if (cv.projektId >= 0) {
            var _iBruecken = db.klemmenInterneBruecken(cv.projektId)
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

        // Union-Find auf (Elementindex, Knotengruppe) — NETZ-MEHRPOL-01:
        // Pins mit unterschiedlicher knotenGruppe auf demselben Element
        // (z.B. Motor U/V/W, Trafo Primär-/Sekundärwicklung) sind KEIN
        // gemeinsamer elektrischer Knoten und dürfen nicht mitverschmolzen
        // werden, nur weil sie zum selben Symbol gehören. Default-Gruppe 0
        // deckt alle anderen Symbole unverändert ab (ein Element = ein Knoten).
        function _ufKey(elIdx, grp) { return elIdx + ":" + (grp || 0) }
        var parent = {}
        function find(x) {
            if (parent[x] === undefined) parent[x] = x
            while (parent[x] !== x) { parent[x] = parent[parent[x]]; x = parent[x] }
            return x
        }
        function union(a, b) { var ra = find(a), rb = find(b); if (ra !== rb) parent[ra] = rb }

        for (var i = 0; i < vbs.length; i++)
            union(_ufKey(vbs[i].elIdxA, vbs[i].knotenGruppeA), _ufKey(vbs[i].elIdxB, vbs[i].knotenGruppeB))

        // Segmente nach Netz gruppieren
        var netMap = {}
        for (var i = 0; i < vbs.length; i++) {
            var v = vbs[i]
            var rid = "" + find(_ufKey(v.elIdxA, v.knotenGruppeA))
            if (!netMap[rid]) netMap[rid] = { signaltyp: "neutral", bezeichnung: "", segmente: [], pinSet: {} }
            var net = netMap[rid]
            net.segmente.push({ x1: v.x1, y1: v.y1, x2: v.x2, y2: v.y2,
                                elIdxA: v.elIdxA, elIdxB: v.elIdxB,
                                pinNameA: v.pinNameA || "", pinNameB: v.pinNameB || "",
                                logisch: v.logisch || false })
            if (!v.logisch) {
                var g = cv.gridPx > 0 ? cv.gridPx : 1
                var k1 = Math.round(v.x1/g) + "," + Math.round(v.y1/g)
                var k2 = Math.round(v.x2/g) + "," + Math.round(v.y2/g)
                net.pinSet[k1] = true; net.pinSet[k2] = true
            }
            // KLEMME-KONFLIKT-01: Klemmen-Stegbrücken/-interne Brücken (_addLog
            // oben) hängen Kanten mit signaltyp:"neutral" NACH der C++-BFS-
            // Konfliktprüfung an, verschmelzen im Union-Find aber trotzdem
            // zuvor unabhängige Netze (z.B. Ebene 1 = L, Ebene 2 = N derselben
            // Klemme). Ohne den else-if-Zweig unten würde die erste nicht-
            // neutrale Kante (z.B. "power") stehen bleiben und eine spätere,
            // abweichende Kante (z.B. "n") stillschweigend ignoriert – kein
            // Konflikt sichtbar, obwohl zwei unterschiedliche Potenziale im
            // selben Netz liegen.
            if (v.signaltyp === "konflikt") {
                net.signaltyp = "konflikt"
            } else if (v.signaltyp === "unversorgt") {
                if (net.signaltyp !== "konflikt") net.signaltyp = "unversorgt"
            } else if (v.signaltyp !== "neutral") {
                if (net.signaltyp === "neutral" || net.signaltyp === "unversorgt") net.signaltyp = v.signaltyp
                else if (net.signaltyp !== "konflikt" && net.signaltyp !== v.signaltyp) net.signaltyp = "konflikt"
            }
        }

        // Querverweis-Symbole: Bezeichnung + Querverweise
        var result = []
        for (var ei = 0; ei < elemente.length; ei++) {
            var el = elemente[ei]
            if (el.typ !== "symbol" || el.symbolId !== "querverweis") continue
            if (parent[_ufKey(ei, 0)] === undefined) continue
            var rid2 = "" + find(_ufKey(ei, 0))
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

            var ann = _netLookup(cv.verbindungAnnotationenCache, [net.netKey, net.legacyNetKey]) || {}
            if (ann.bezeichnung && !net.bezeichnung) net.bezeichnung = ann.bezeichnung
            net.verbindungId  = ann.verbindungId  || 0
            net.farbe         = ann.farbe         || ""
            net.querschnitt   = ann.querschnitt_mm2 || 0

            // Querverweise aus Querverweis-Symbolen
            net.querverweise = []
            for (var ei2 = 0; ei2 < elemente.length; ei2++) {
                var eel = elemente[ei2]
                if (eel.typ !== "symbol" || eel.symbolId !== "querverweis") continue
                if (parent[_ufKey(ei2, 0)] === undefined || ("" + find(_ufKey(ei2, 0))) !== rid) continue
                var eed = eel.extraDaten || {}
                if (eed.zielSeiteId && eed.signalname) {
                    var richtung = eed.richtung || "ausgang"
                    net.querverweise.push({
                        vonSeiteId:      richtung === "ausgang" ? cv.seiteId : eed.zielSeiteId,
                        nachSeiteId:     richtung === "ausgang" ? eed.zielSeiteId : cv.seiteId,
                        vonBezeichnung:  eed.signalname,
                        nachBezeichnung: eed.signalname
                    })
                }
            }
            result.push(net)
        }

        // ── Cross-page klemmen + querverweis signaltyp import (KLEMME-NET-01) ─
        // Für Netze auf dieser Seite die noch kein Potenzial haben:
        // Partner-Anschlüsse gleicher klemmeId+Ebene ODER Querverweise mit
        // gleichem signalname auf anderen Seiten laden. Die Partnerseite
        // bekommt dieselbe A↔B- und Stegbrücken-Injektion wie die aktuelle
        // Seite, damit Potenziale die nur über Stegbrücken ankommen ebenfalls
        // erkannt werden. Querverweis-Cross-Page-Import (KLEMME-KONFLIKT-01-
        // Folgefix, Aug 2026): nur suchmodus "signal" (Default) unterstützt —
        // "bmk"-Modus bräuchte den Strukturkasten-Anlage/Ort-Lookup aus
        // SymbolDefinitionModel.cpp §4, der in QML nicht verfügbar ist; für
        // solche Querverweise findet einfach kein Cross-Page-Import statt
        // (kein Rückschritt ggü. vorher, nur unausgebaute Erweiterung).
        if (cv.projektId >= 0) {
            var _cpAlleKa = db.klemmenAnschlussAlleSeiten(cv.projektId)
            var _cpStege  = db.klemmenStegbrueckenGruppen(cv.projektId)
            var _cpAlleQv = db.querverweiseLadenProjekt(cv.projektId)
            // Fremdseiten: "klemmeId:ebene" → [seiteId, ...]
            var _cpFremd = {}
            for (var _cpI = 0; _cpI < _cpAlleKa.length; _cpI++) {
                var _cpKa  = _cpAlleKa[_cpI]
                if (_cpKa.seiteId === cv.seiteId) continue
                var _cpBez = _cpKa.anschlussBezeichnung || ""
                var _cpEb  = (_cpBez === "PE" || _cpBez.indexOf(".") < 0) ? _cpBez : _cpBez.split(".")[0]
                if (!_cpEb) continue
                var _cpKey = _cpKa.klemmeId + ":" + _cpEb
                if (!_cpFremd[_cpKey]) _cpFremd[_cpKey] = []
                if (_cpFremd[_cpKey].indexOf(_cpKa.seiteId) < 0)
                    _cpFremd[_cpKey].push(_cpKa.seiteId)
            }
            // Fremdseiten: signalname → [seiteId, ...] (nur suchmodus "signal")
            var _qvFremd = {}
            for (var _qvI = 0; _qvI < _cpAlleQv.length; _qvI++) {
                var _qvKa = _cpAlleQv[_qvI]
                if (_qvKa.seiteId === cv.seiteId) continue
                if ((_qvKa.suchmodus || "signal") === "bmk") continue
                if (!_qvKa.signalname) continue
                if (!_qvFremd[_qvKa.signalname]) _qvFremd[_qvKa.signalname] = []
                if (_qvFremd[_qvKa.signalname].indexOf(_qvKa.seiteId) < 0)
                    _qvFremd[_qvKa.signalname].push(_qvKa.seiteId)
            }
            var _cpCache = {}  // seiteId → {els, vbs}
            for (var _cpRi = 0; _cpRi < result.length; _cpRi++) {
                var _cpNet = result[_cpRi]
                // KLEMME-KONFLIKT-01-Folgefix (Aug 2026, "Seite 01 zeigt nix"):
                // vorher wurde ein bereits lokal aufgelöstes Netz (z.B. "power"
                // durch eine eigene Quelle auf DIESER Seite) komplett
                // übersprungen — ein widersprechender Fremdseiten-Kandidat
                // (Klemme/Querverweis derselben klemmeId+Ebene bzw. desselben
                // signalname, aber mit anderem tatsächlichem Signaltyp auf der
                // Fremdseite) wurde dadurch nie erkannt. Bereits als "konflikt"
                // markierte Netze werden weiterhin übersprungen (kann nicht
                // mehr "weniger" Konflikt werden).
                if (_cpNet.signaltyp === "konflikt") continue
                var _cpLokalSig = (_cpNet.signaltyp === "neutral" || _cpNet.signaltyp === "unversorgt")
                                   ? "neutral" : _cpNet.signaltyp
                // Über ALLE Segmente, beide Seiten und ALLE Fremdseiten hinweg
                // sammeln statt beim ersten Treffer abzubrechen (früheres
                // _cpDone) — ein abweichender Kandidat auf einer ANDEREN
                // Fremdseite ist ebenso ein echter Konflikt wie einer auf
                // derselben.
                var _cpNetSig = _cpLokalSig
                var _cpMerge = function(cand) {
                    if (cand === "neutral" || cand === "unversorgt") return
                    if (_cpNetSig === "neutral") _cpNetSig = cand
                    else if (_cpNetSig !== cand) _cpNetSig = "konflikt"
                }
                for (var _cpSi = 0; _cpSi < _cpNet.segmente.length; _cpSi++) {
                    var _cpSeg = _cpNet.segmente[_cpSi]
                    for (var _cpSide = 0; _cpSide < 2; _cpSide++) {
                        var _cpEIdx = _cpSide === 0 ? _cpSeg.elIdxA : _cpSeg.elIdxB
                        if (_cpEIdx === undefined) continue
                        var _cpEl = elemente[_cpEIdx]
                        if (!_cpEl) continue
                        var _cpIsKlemme = _cpEl.symbolId === "klemme_anschluss"
                        var _cpIsQv     = _cpEl.symbolId === "querverweis"
                        if (!_cpIsKlemme && !_cpIsQv) continue

                        var _cpFPs, _cpKId, _cpEEb, _cpQvSn
                        if (_cpIsKlemme) {
                            var _cpEd  = _cpEl.extraDaten || {}
                            _cpKId = _cpEd.klemmeId || 0
                            if (_cpKId <= 0) continue
                            var _cpEBez = _cpEd.anschlussBezeichnung || ""
                            _cpEEb = (_cpEBez === "PE" || _cpEBez.indexOf(".") < 0) ? _cpEBez : _cpEBez.split(".")[0]
                            _cpFPs = _cpFremd[_cpKId + ":" + _cpEEb]
                        } else {
                            var _cpQed = _cpEl.extraDaten || {}
                            if ((_cpQed.suchmodus || "signal") === "bmk") continue
                            _cpQvSn = _cpQed.signalname || ""
                            if (!_cpQvSn) continue
                            _cpFPs = _qvFremd[_cpQvSn]
                        }
                        if (!_cpFPs || !_cpFPs.length) continue
                        for (var _cpFPi = 0; _cpFPi < _cpFPs.length; _cpFPi++) {
                            var _cpSId = _cpFPs[_cpFPi]
                            if (!_cpCache[_cpSId]) {
                                var _cpPEls = db.grafikLaden(_cpSId)
                                var _cpPVbs = symbolDefinitionModel.autoVerbindungenBerechnen(_cpPEls, cv.gridPx, {})
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
                            // Kandidaten fließen über _cpMerge() in den netweiten
                            // Akkumulator _cpNetSig ein statt direkt zu schreiben —
                            // ein abweichender Kandidat, egal ob auf derselben oder
                            // einer anderen Fremdseite gefunden, ist ein echter
                            // Konflikt (KLEMME-KONFLIKT-01).
                            if (_cpIsKlemme) {
                                for (var _cpPEi = 0; _cpPEi < _cpPC.els.length; _cpPEi++) {
                                    var _cpPEl = _cpPC.els[_cpPEi]
                                    if (!_cpPEl || _cpPEl.symbolId !== "klemme_anschluss") continue
                                    var _cpPEd = _cpPEl.extraDaten || {}
                                    if ((_cpPEd.klemmeId || 0) !== _cpKId) continue
                                    var _cpPBez = _cpPEd.anschlussBezeichnung || ""
                                    var _cpPEb  = (_cpPBez === "PE" || _cpPBez.indexOf(".") < 0) ? _cpPBez : _cpPBez.split(".")[0]
                                    if (_cpPEb !== _cpEEb) continue
                                    _cpMerge(cv._signaltypInVerbindungen(_cpPEi, _cpPC.vbs))
                                }
                            } else {
                                // Querverweis-Cross-Page-Import (KLEMME-KONFLIKT-01-
                                // Folgefix): dieselbe Fremdseiten-vbs (inkl. Klemmen-
                                // Injektion) wird wiederverwendet — ein Querverweis
                                // bekommt seinen Signaltyp genauso über die normale
                                // Kantenauflösung wie ein klemme_anschluss.
                                for (var _cpQPEi = 0; _cpQPEi < _cpPC.els.length; _cpQPEi++) {
                                    var _cpQPEl = _cpPC.els[_cpQPEi]
                                    if (!_cpQPEl || _cpQPEl.symbolId !== "querverweis") continue
                                    var _cpQPEd = _cpQPEl.extraDaten || {}
                                    if ((_cpQPEd.suchmodus || "signal") === "bmk") continue
                                    if ((_cpQPEd.signalname || "") !== _cpQvSn) continue
                                    _cpMerge(cv._signaltypInVerbindungen(_cpQPEi, _cpPC.vbs))
                                }
                            }
                        }
                    }
                }
                if (_cpNetSig !== "neutral") _cpNet.signaltyp = _cpNetSig
            }
        }
        // ─────────────────────────────────────────────────────────────────────
        return result
    }

    function autoNetzeBerechnenCached() {
        if (cv._cachedNetze !== null) return cv._cachedNetze
        cv._cachedNetze = autoNetzeBerechnen()
        return cv._cachedNetze
    }
}
