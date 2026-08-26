import QtQuick

// Cache-Refresh-Funktionen (HF-Referenz, SPS-Konflikt, Querverweis-Partner,
// Kabellinien-Anzahl) sowie die Ader-Dialog-Orchestrierung (Aderzuordnung/
// Ader-Kreuzung öffnen — bereitet Daten auf und delegiert ans Öffnen des
// jeweiligen Dialogs in CanvasDialogLayer).
// cv: Referenz auf SchaltplanCanvas (root). REFACTOR-01 Stufe 4.
QtObject {
    id: handler
    required property var cv

    // --------------------------------------------------------
    // Cache-Refresh
    // --------------------------------------------------------

    // Baut den Partner-Cache: elementIdx → Blattnummer der Gegenseite.
    // Wird beim Laden einer Seite einmal aufgerufen.
    function hfReferenzMapAktualisieren() {
        if (cv.projektId < 0) { cv._hfReferenzMap = {}; return }
        var liste = db.betriebsmittelHfListe(cv.projektId)
        var map = {}
        for (var i = 0; i < liste.length; i++) {
            var e = liste[i]
            map[e.betriebsmittelId] = {
                hauptElementId: e.hauptElementId,
                blattnummer:    e.blattnummer,
                seiteId:        e.seiteId
            }
        }
        cv._hfReferenzMap = map
    }

    function spsKonfliktAktualisieren() {
        if (cv.projektId < 0) { cv._spsKonfliktSet = {}; return }
        var ids = db.spsKonfliktElementIds(cv.projektId)
        var s = {}
        for (var i = 0; i < ids.length; i++) s[ids[i]] = true
        cv._spsKonfliktSet = s
        cv.repaintAll()
    }

    function hfKarteAktualisieren() {
        hfReferenzMapAktualisieren()
        cv.repaintAll()
    }

    function querverweisPartnerCacheAktualisieren() {
        if (cv.seiteId < 0 || cv.projektId < 0) { cv._querverweisPartnerMap = {}; return }
        var alle = db.querverweiseLadenProjekt(cv.projektId)
        var map = {}
        var _qvEls = cv.elementeModel.snapshot()
        for (var i = 0; i < _qvEls.length; i++) {
            var el = _qvEls[i]
            if (el.typ !== "symbol" || el.symbolId !== "querverweis") continue
            var sn = (el.extraDaten && el.extraDaten.signalname) || ""
            if (!sn) continue
            for (var k = 0; k < alle.length; k++) {
                var qv = alle[k]
                if (qv.signalname !== sn) continue
                if (qv.seiteId === cv.seiteId && Math.abs(qv.x1 - el.x1) < 0.5 && Math.abs(qv.y1 - el.y1) < 0.5) continue
                map[i] = {
                    label:   qv.blattnummer + (qv.seitenBezeichnung ? " " + qv.seitenBezeichnung : ""),
                    seiteId: qv.seiteId,
                    x1:      qv.x1,
                    y1:      qv.y1
                }
                break
            }
        }
        cv._querverweisPartnerMap = map
    }

    // Baut den Partner-Cache für den Klemmenanschluss-Hover-Tooltip
    // (KLEMMENANSCHLUSS-PARTNER-01): elementIdx (aktuelle Seite) → Liste der
    // anderen Platzierungen derselben Klemme+Ebene (elektrisch verbunden,
    // KLEMME-NET-01-Gruppierung — Ebene = Anschlussbezeichnung-Präfix vor dem
    // ".", z.B. "1" für "1.1"/"1.2", oder "PE"). Wird analog zum
    // Querverweis-Partner-Cache beim Seitenwechsel aufgebaut.
    function klemmeAnschlussPartnerCacheAktualisieren() {
        if (cv.seiteId < 0 || cv.projektId < 0) { cv._klemmeAnschlussPartnerMap = {}; return }
        var alle = db.klemmenAnschlussAlleSeiten(cv.projektId)
        var ebeneVon = function(bez) {
            return (bez === "PE" || bez.indexOf(".") < 0) ? bez : bez.split(".")[0]
        }
        var gruppen = {}
        for (var i = 0; i < alle.length; i++) {
            var p = alle[i]
            var eb = ebeneVon(p.anschlussBezeichnung || "")
            if (!eb) continue
            var key = p.klemmeId + ":" + eb
            if (!gruppen[key]) gruppen[key] = []
            gruppen[key].push(p)
        }
        var map = {}
        var els = cv.elementeModel.snapshot()
        for (var ei = 0; ei < els.length; ei++) {
            var el = els[ei]
            if (el.typ !== "symbol" || el.symbolId !== "klemme_anschluss") continue
            var ed = el.extraDaten || {}
            var kId = ed.klemmeId
            if (kId === undefined || kId === null) continue
            var eEb = ebeneVon(ed.anschlussBezeichnung || "")
            if (!eEb) continue
            var grp = gruppen[kId + ":" + eEb] || []
            var partner = []
            for (var gi = 0; gi < grp.length; gi++) {
                var p2 = grp[gi]
                if (p2.seiteId === cv.seiteId && Math.abs(p2.x1 - el.x1) < 0.5
                        && Math.abs(p2.y1 - el.y1) < 0.5) continue // sich selbst
                var rawBmk = p2.bmk || ""
                var bezP   = p2.anschlussBezeichnung || ""
                var baseBmk = (bezP !== "" && rawBmk.endsWith(":" + bezP))
                              ? rawBmk.slice(0, rawBmk.length - bezP.length - 1) : rawBmk
                var colIdx = baseBmk.lastIndexOf(":")
                var leiste = colIdx >= 0 ? baseBmk.slice(0, colIdx) : baseBmk
                var nr     = colIdx >= 0 ? baseBmk.slice(colIdx + 1) : ""
                var kennung = leiste ? (nr ? leiste + ":" + nr : leiste) : bezP
                var seiteLabel = p2.seiteId === cv.seiteId
                                  ? "dieser Seite"
                                  : ("Seite " + p2.blattnummer + (p2.seitenBezeichnung ? " " + p2.seitenBezeichnung : ""))
                partner.push({
                    label:   kennung + " auf " + seiteLabel,
                    seiteId: p2.seiteId, x1: p2.x1, y1: p2.y1
                })
            }
            if (partner.length > 0) map[ei] = partner
        }
        cv._klemmeAnschlussPartnerMap = map
    }

    function kabelLinienCacheAktualisieren() {
        var map = {}
        var _klEls = cv.elementeModel.snapshot()
        for (var i = 0; i < _klEls.length; i++) {
            var el = _klEls[i]
            if (el.typ !== "kabellinie") continue
            var kId = (el.extraDaten && el.extraDaten.kabelId) || 0
            if (kId <= 0 || kId in map) continue
            var linien = db.kabelAlleLinienLaden(kId)
            map[kId] = linien.length
        }
        cv._kabelLinienCache = map
    }

    // --------------------------------------------------------
    // Ader-Dialog-Orchestrierung
    // --------------------------------------------------------

    // Baut eine Map netKey → anschlusskennzeichnung des Geräte-Pins am Netzende.
    // Wird für den Aderzuordnungsmodus „Pin-Nummer" (M10) benötigt.
    function _pinNummernFuerNetze(netze) {
        var els = cv.elementeModel.snapshot()
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

        var savedAuswahl = cv.auswahl.slice()
        cv.elementeModel.laden(cv.seiteId)
        cv.auswahl = savedAuswahl
        var reloaded = cv.elementeModel.snapshot()

        var elId = el.id || 0
        var freshEl = null
        for (var i = 0; i < reloaded.length; i++) {
            if (reloaded[i].id === elId) { freshEl = reloaded[i]; break }
        }
        var currentEl = freshEl || el
        var freshGeid = currentEl.id || 0

        var details  = db.kabelLinieDetails(freshGeid)
        var netze    = cv.netzberechnung.autoNetzeBerechnen()
        var schnitte = cv.geometrie.kabelSchnittNetzeBerechnen(currentEl, netze)

        // Vollständige Aderliste aufbauen: DB-Einträge + fehlende aderNr als freie Platzhalter
        var aderzahl = details.aderzahl || ed.aderzahl || 0
        var rawAdern = details.adern || []
        var aderMap  = {}
        for (var ai = 0; ai < rawAdern.length; ai++)
            aderMap[rawAdern[ai].aderNr] = rawAdern[ai]
        var fullAdern = []
        for (var nr = 1; nr <= aderzahl; nr++)
            fullAdern.push(aderMap[nr] || { aderNr: nr, farbe: "", bezeichnung: "", verbindungId: 0, kabellinieGrafikElementId: 0 })

        cv._dialogLayer.aderzuordnungOeffnen(kabelId, ed.bezeichnung || "", ed.kabeltyp || "",
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
            var zugeordnet = cv.netzberechnung._netLookup(aderZuordnung, [sc.aderKey, sc.netKey, sc.legacyNetKey])
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

        var savedAuswahl = cv.auswahl.slice()
        cv.elementeModel.laden(cv.seiteId)
        cv.auswahl = savedAuswahl
        var reloaded = cv.elementeModel.snapshot()

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

        var netze    = cv.netzberechnung.autoNetzeBerechnen()
        var schnitte = cv.geometrie.kabelSchnittNetzeBerechnen(currentEl, netze)
        var freieNrn = _freieAdernFuerKreuzung(aderzahl, freshEd.aderZuordnung || {}, schnitte, treffer.aderKey)

        var freieAdern = []
        for (var fi = 0; fi < freieNrn.length; fi++) {
            var nr = freieNrn[fi]
            freieAdern.push(aderMap[nr] || { aderNr: nr, farbe: "", farbe2: "", bezeichnung: "" })
        }
        var alteAder = aderMap[treffer.aktuelleAderNr] || { aderNr: treffer.aktuelleAderNr, farbe: "", farbe2: "", bezeichnung: "" }

        cv._dialogLayer.aderKreuzungPickerOeffnen(kabelId, freshGeid, treffer.aderKey,
            treffer.verbindungId, treffer.aktuelleAderNr, treffer.istLeer,
            alteAder, freieAdern, treffer.vpX, treffer.vpY)
    }
}
