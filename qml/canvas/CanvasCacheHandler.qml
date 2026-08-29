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
    //
    // Nachtrag: label zeigt bewusst nur die Anschlussbezeichnung der
    // Gegenstelle (+ Blattnummer bei Fremdseite), NICHT die volle Leiste:Nr.
    // — die ist innerhalb einer Ebenen-Gruppe immer identisch mit der schon
    // angezeigten eigenen BMK (dieselbe Klemme) und sprengte im PDF-Pendant
    // (pdfKlemmenAnschlussPartner) die feste Textbox (Nutzer-Screenshot).
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
                var bezP  = p2.anschlussBezeichnung || ""
                var label = bezP || "?"
                if (p2.seiteId !== cv.seiteId) label += " Bl." + p2.blattnummer
                partner.push({
                    label:   label,
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

    // KABEL-ADERFARBE-PROPAGATION-03/04: hält kabel_ader (seitenübergreifende
    // Tabelle, genutzt von EpKabelLinienBlock.qml für "N Adr." pro Linie +
    // "Freie Adern") bei jedem Speichern (grafikSpeichernJetzt()) aktuell.
    //
    // PROPAGATION-04 (Aug 2026): NICHT mehr seiten-lokal berechnet und
    // direkt persistiert — ein Kabel kann über mehrere Seiten verteilt
    // gezeichnet sein (dieselbe kabelId, mehrere Kabellinien), und eine rein
    // seiten-lokale Poolung hätte pro Linie unabhängig bei Ader 1 neu
    // gezählt und dieselbe Adernummer an mehreren Stellen vergeben (Nutzer-
    // Bugreport: zwei Kabellinien mit gleichem BMK, Adern doppelt vergeben).
    // Stattdessen nur die auf DIESER Seite vorkommenden kabelId sammeln und
    // je einmal db.kabelAderProjektweitSynchronisieren() aufrufen — die
    // sammelt selbst ALLE Kabellinien dieser kabelId über alle Seiten
    // (per SQL, nicht auf das Live-Elementmodell angewiesen) und poolt die
    // Adernummern seitenübergreifend. netze wird hierfür nicht mehr
    // gebraucht (die C++-Seite berechnet ihre Kreuzungen selbst aus den
    // bereits persistierten verbindung/verbindung_segment-Tabellen).
    function kabelAderSynchronisieren() {
        var els = cv.elementeModel.snapshot()
        var kabelIds = {}
        for (var i = 0; i < els.length; i++) {
            var el = els[i]
            if (!el || el.typ !== "kabellinie") continue
            var kabelId = (el.extraDaten && el.extraDaten.kabelId) || 0
            if (kabelId > 0) kabelIds[kabelId] = true
        }
        for (var kid in kabelIds) {
            db.kabelAderProjektweitSynchronisieren(parseInt(kid))
            // KABEL-UEBERARBEITUNG-01/PROPAGATION-05: kabelAderProKabelCached()
            // (CanvasGeometrie.qml) cached pro kabelId und wird sonst nur bei
            // elementeModel.geaendert invalidiert — die Poolung oben schreibt
            // aber per direktem SQL an dieser Signalkette vorbei. Ohne diese
            // gezielte Invalidierung hätte das Kreuzungs-Popup direkt nach
            // dem Speichern weiterhin den alten (Vor-Sync-)Stand gezeigt.
            delete cv._cachedKabelAderProKabel[kid]
        }
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
        var freshEd   = currentEl.extraDaten || {}

        var netze    = cv.netzberechnung.autoNetzeBerechnen()
        var schnitte = cv.geometrie.kabelSchnittNetzeBerechnen(currentEl, netze)

        // KABEL-ADERFARBE-PROPAGATION-02: Aderliste kommt aus extra_daten.
        // adern der Kabellinie selbst, NICHT mehr aus db.kabelLinieDetails()
        // (liest die kabel_ader-Tabelle, die beim normalen "Bauteil-Kabel
        // wählen"-Workflow leer bleibt bzw. veraltete Reste zeigt — dieselbe
        // Erkenntnis wie bei KABEL-ADERFARBE-01 für die Canvas-Farbe).
        var aderzahl = freshEd.aderzahl || 0
        var rawAdern = freshEd.adern || []
        var aderMap  = {}
        for (var ai = 0; ai < rawAdern.length; ai++)
            aderMap[rawAdern[ai].aderNr] = rawAdern[ai]
        var fullAdern = []
        for (var nr = 1; nr <= aderzahl; nr++)
            fullAdern.push(aderMap[nr] || { aderNr: nr, farbe: "", bezeichnung: "", verbindungId: 0, kabellinieGrafikElementId: 0 })

        cv._dialogLayer.aderzuordnungOeffnen(kabelId, freshEd.bezeichnung || "", freshEd.kabeltyp || "",
            aderzahl, fullAdern, schnitte, freshEd.aderZuordnung || {},
            freshGeid, _pinNummernFuerNetze(netze))
    }

    // Liefert die Ader-Nummern 1..aderzahl, die NICHT bereits an einer
    // ANDEREN Kreuzung vergeben sind (eigenerAderKey wird ausgenommen,
    // damit die aktuell zugeordnete Ader selbst nicht fälschlich als
    // "belegt" gilt).
    //
    // KABEL-ADERFARBE-PROPAGATION-02: eine Kreuzung ohne expliziten
    // aderZuordnung-Eintrag gilt NICHT als frei — sie hat implizit den
    // Positions-Fallback (i-te Kreuzung → Ader i, wie überall sonst beim
    // Rendern/den Ader-Labels, s. _sammleKabelAderFarben()/
    // kabelKreuzungBeiPosition()). Ohne diesen Fallback hier hätte das
    // Popup direkt nach einer frischen Bauteil-Kabel-Zuweisung (aderZuordnung
    // noch komplett leer) fälschlich alle Adern als frei angeboten.
    //
    // KABEL-UEBERARBEITUNG-01/PROPAGATION-05/-07 (Aug 2026): zusätzlich zu
    // den Kreuzungen DERSELBEN Kabellinie (lokal, s.o.) auch die seiten-
    // übergreifend gepoolte kabel_ader-Tabelle (gepoolt, aus
    // CanvasGeometrie.qml::kabelAderProKabelCached(), seit PROPAGATION-07
    // über den lokalen aderKey statt verbindungId geschlüsselt) berück-
    // sichtigen — sonst bot das Popup weiterhin Adern an, die bereits einer
    // ANDEREN Kabellinie desselben Kabels (ggf. auf einer anderen Seite)
    // zugeordnet sind. Damit nutzt das Popup dieselbe Datengrundlage wie
    // die Poolung beim Speichern, statt zwei divergierende Quellen zu haben
    // (Bestandsaufnahme §6.5.5, Punkt 1).
    //
    // AKP-FREIE-ADERN-LOKAL-01 (Aug 2026): der lokale Kreuzungs-Loop rechnete
    // für Kreuzungen ohne eigenen aderZuordnung-Eintrag bislang direkt mit
    // dem reinen Positions-Fallback (i+1) — bei einer Linie, deren Adern
    // kabelweit NICHT bei 1 beginnen (z.B. die vierte Linie eines Kabels,
    // Adern 10/11), markierte das die falsche Nummer als belegt (hier: "1"
    // statt "10") und ließ echte, weiter hinten liegende freie Adern
    // dadurch potenziell unentdeckt, je nachdem wie sich die falschen
    // Markierungen mit echten überschneiden. Nutzt jetzt denselben
    // 3-stufigen Resolver wie überall sonst (explizit > gepoolt > lokaler
    // Fallback, `_aderNrFuerKreuzung()`) statt einer eigenen, unvollständigen
    // Kopie davon.
    function _freieAdernFuerKreuzung(aderzahl, aderZuordnung, schnitte, eigenerAderKey, gepoolt) {
        var belegt = {}
        for (var i = 0; i < schnitte.length; i++) {
            var sc  = schnitte[i]
            var key = sc.aderKey || sc.netKey || sc.legacyNetKey || ""
            if (key === eigenerAderKey) continue
            var res = cv.netzberechnung._aderNrFuerKreuzung(aderZuordnung, sc, i, gepoolt)
            if (!res.istLeer) belegt[res.aderNr] = true
        }
        if (gepoolt) {
            for (var ak in gepoolt) {
                if (ak === eigenerAderKey) continue
                belegt[gepoolt[ak].aderNr] = true
            }
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

        // KABEL-ADERFARBE-PROPAGATION-02: s. aderzuordnungDialogOeffnen()
        // oben — Aderliste aus extra_daten.adern statt der leeren/veralteten
        // kabel_ader-Tabelle.
        var aderzahl = freshEd.aderzahl || 0
        var rawAdern = freshEd.adern || []
        var aderMap  = {}
        for (var ai = 0; ai < rawAdern.length; ai++) aderMap[rawAdern[ai].aderNr] = rawAdern[ai]

        var netze    = cv.netzberechnung.autoNetzeBerechnen()
        var schnitte = cv.geometrie.kabelSchnittNetzeBerechnen(currentEl, netze)
        // AKP-FREIE-ADERN-CACHE-01 (Aug 2026): Cache gezielt verwerfen statt
        // wie sonst üblich zu vertrauen — dieses Popup ist der einzige Ort,
        // an dem der Nutzer eine gerade eben (z.B. durch Bauteil-Tausch)
        // freigewordene Ader sofort als wählbar sehen muss. Die üblichen
        // Invalidierungspunkte (grafikSpeichernJetzt→kabelAderSynchronisieren,
        // netzCacheInvalidieren) laufen zeitlich nicht zuverlässig VOR
        // diesem Öffnen-Handler, ein veralteter Eintrag hätte sonst schon
        // freie Adern fälschlich als belegt gezeigt (Nutzerbericht).
        delete cv._cachedKabelAderProKabel[kabelId]
        var gepoolt  = cv.geometrie.kabelAderProKabelCached(kabelId)
        var freieNrn = _freieAdernFuerKreuzung(aderzahl, freshEd.aderZuordnung || {}, schnitte, treffer.aderKey, gepoolt)

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
