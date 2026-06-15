import QtQuick

// Fehlersuchmodus-Logik: BFS-Pfadberechnung über den Verbindungsgraphen.
// Hält keinen eigenen Zustand – schreibt Ergebnisse direkt auf cv.fehlersuch*.
QtObject {
    required property var cv

    function fehlersuchPfadZuruecksetzen() {
        cv.fehlersuchPfadIds      = {}
        cv.fehlersuchStartId      = -1
        cv.fehlersuchQuerverweise = []
        cv.fehlersuchPfadGefunden([])
        cv._drawCanvas.requestPaint()
    }

    function fehlersuchPfadBerechnen(startElementId) {
        var elems = cv.elementeModel.snapshot()

        var startIdx = -1
        for (var _ii = 0; _ii < elems.length; _ii++) {
            if ((elems[_ii].id || 0) === startElementId) { startIdx = _ii; break }
        }
        if (startIdx < 0) { fehlersuchPfadZuruecksetzen(); return }

        // Verbindungsgraph – dieselbe Quelle wie autoNetzeBerechnen
        var vbs = symbolDefinitionModel.autoVerbindungenBerechnen(
            elems, cv.gridPx, cv.normblattDaten || {}
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
        if (cv.projektId >= 0) {
            var _stege = db.klemmenStegbrueckenGruppen(cv.projektId)
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
                        var _z  = db.fehlersuchQuerverweisZiel(cv.seiteId, nb.id || -1)
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

        cv.fehlersuchPfadIds      = pfadIds
        cv.fehlersuchStartId      = startElementId
        cv.fehlersuchQuerverweise = querv
        cv.fehlersuchPfadGefunden(querv)
        cv._drawCanvas.requestPaint()
    }
}
