import QtQuick

// SQL-Export-Textgenerierung für den Symboleditor — ausgelagert aus
// SymbolEditorAnsicht.qml (REFACTOR-QML-05). Reine Funktion ohne
// Root-Canvas-Kopplung: nimmt nur eine symbolId entgegen, liest über das
// globale symbolDefinitionModel und gibt fertigen SQL-/Migrationstext
// zurück.
QtObject {
    id: root

    function fmtN(v) {
        if (v === undefined || v === null) return "0"
        var n = parseFloat(v)
        return isNaN(n) ? "0" : n.toString()
    }

    // Zwei Modi je nach kopie_von_id des Symbols:
    //  - Zielt die Kopie auf ein bestehendes (i.d.R. built-in) Symbol, wird
    //    ein fertiger Migrationsblock erzeugt, der dessen Geometrie ersetzt
    //    (UPDATE + DELETE/INSERT, exakt das Format aus Database_Schema.cpp).
    //  - Sonst ein Seed-Block (INSERT OR IGNORE, inkl. Legacy-symbol-Tabelle)
    //    für ein komplett neues Symbol.
    function sqlAlsText(symbolId) {
        var info    = symbolDefinitionModel.symbolInfo(symbolId)
        var prims   = symbolDefinitionModel.primitiveFuerSymbol(symbolId)
        var pinList = symbolDefinitionModel.pinsForSymbol(symbolId)
        if (!info || !info.name) return ""
        function esc(s) { return (s || "").replace(/'/g, "''") }

        function pinWerte(zielId) {
            var t = []
            for (var i = 0; i < pinList.length; i++) {
                var p  = pinList[i]
                var ox = p.offenX !== undefined ? p.offenX : (p.offen ? p.offen.x : -1)
                var oy = p.offenY !== undefined ? p.offenY : (p.offen ? p.offen.y : 0)
                t.push("('" + esc(zielId) + "', '" + esc(p.name) + "', " +
                       root.fmtN(p.x) + ", " + root.fmtN(p.y) + ", " + root.fmtN(ox) + ", " + root.fmtN(oy) +
                       ", '" + esc(p.signaltyp || "neutral") + "')")
            }
            return t.join(", ")
        }

        function primWerte(zielId) {
            var t = []
            for (var i = 0; i < prims.length; i++) {
                var p  = prims[i]
                var ti = (p.text_inhalt && p.text_inhalt.length > 0) ? "'" + esc(p.text_inhalt) + "'" : "NULL"
                t.push("('" + esc(zielId) + "', " + i + ", '" + esc(p.typ) + "', " +
                       root.fmtN(p.x1) + ", " + root.fmtN(p.y1) + ", " + root.fmtN(p.x2) + ", " + root.fmtN(p.y2) + ", " +
                       root.fmtN(p.x3) + ", " + root.fmtN(p.y3) + ", " +
                       root.fmtN(p.radius) + ", " + root.fmtN(p.winkel_von) + ", " + root.fmtN(p.winkel_bis) + ", " +
                       (p.bogen_gegen_uhrzeiger ? 1 : 0) + ", " +
                       ti + ", " + root.fmtN(p.schrift_relativ || 0.5) + ", " + (p.schrift_fett ? 1 : 0) + ", " +
                       "'" + esc(p.text_align || "center") + "', '" + esc(p.text_baseline || "middle") + "', '" +
                       esc(p.linienart || "solid") + "', " + root.fmtN(p.rotation || 0) + ")")
            }
            return t.join(", ")
        }

        var zielId       = symbolId
        var zielName     = info.name
        var replaceModus = false
        if (info.kopieVonId && info.kopieVonId !== "") {
            var orig = symbolDefinitionModel.symbolInfo(info.kopieVonId)
            if (orig && orig.name) {
                replaceModus = true
                zielId   = info.kopieVonId
                zielName = orig.name
            }
        }
        // Ohne eigene Umbenennung trägt die Kopie noch "Kopie von <Original>"
        // (s. ladeDaten()) — dann den Original-Namen beibehalten statt ihn
        // mit dem Kopie-Titel zu überschreiben.
        var neuerName = (info.name.indexOf(qsTr("Kopie von ")) === 0) ? zielName : info.name

        var lines = []
        if (replaceModus) {
            lines.push("-- Fertiger Migrationsblock für Database_Schema.cpp (alleMigrationen()).")
            lines.push("-- <VERSION> auf die nächste freie Nummer setzen, Beschreibung ergänzen.")
            lines.push("-- Ersetzt die Geometrie von '" + zielId + "' durch diese überarbeitete Kopie ('" + symbolId + "').")
            lines.push('{ <VERSION>, "<BESCHREIBUNG>: \'' + zielId + '\' ueberarbeitet (aus Nutzer-Kopie \'' + symbolId + '\').", {')
            lines.push('    R"(UPDATE symbol_definition SET name=' + "'" + esc(neuerName) + "'" +
                        ', kategorie=' + "'" + esc(info.kategorie || "") + "'" +
                        ', breite_mm=' + (info.breiteMm || 32) + ', hoehe_mm=' + (info.hoeheMm || 16) +
                        ', rolle=' + "'" + esc(info.rolle || "durchleiter") + "'" +
                        ', bmk_seite=' + "'" + esc(info.bmkSeite || "auto") + "'" +
                        ', pin_schrift_mm=' + root.fmtN(info.pinSchriftMm || 2.0) +
                        ' WHERE id=' + "'" + esc(zielId) + "'" + ')",')
            lines.push('    R"(DELETE FROM symbol_pin WHERE symbol_id = ' + "'" + esc(zielId) + "'" + ')",')
            if (pinList.length > 0)
                lines.push('    R"(INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES ' + pinWerte(zielId) + ')",')
            lines.push('    R"(DELETE FROM symbol_primitiv WHERE symbol_id = ' + "'" + esc(zielId) + "'" + ')",')
            if (prims.length > 0)
                lines.push('    R"(INSERT INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES ' + primWerte(zielId) + ')",')
            lines.push("}},")
            if (neuerName !== zielName) {
                lines.push("")
                lines.push("-- Name in der Legacy-symbol-Tabelle mitpflegen (steuert SymbolPalette.qml-Kategorieliste):")
                lines.push('-- UPDATE symbol SET name = ' + "'" + esc(neuerName) + "'" + ' WHERE code = ' + "'" + esc(zielId) + "'" + ';')
            }
        } else {
            lines.push("-- Neues Symbol (kopie_von_id leer oder Original nicht mehr vorhanden).")
            lines.push("-- Ziel: symbole.sql (Basis-Seed) ODER neue Migration in Database_Schema.cpp,")
            lines.push("-- je nachdem wo verwandte Symbole bereits geseedet werden.")
            lines.push("-- kategorie_pfad/norm in der Legacy-symbol-Tabelle prüfen (Platzhalter unten).")
            lines.push("")
            lines.push("INSERT OR IGNORE INTO symbol (code, name, kategorie_pfad, norm, anschluesse) VALUES")
            lines.push("('" + esc(symbolId) + "', '" + esc(info.name) + "', '" + esc((info.kategorie || "").toLowerCase()) + "', 'IEC,ANSI', " + pinList.length + ");")
            lines.push("")
            lines.push("INSERT OR IGNORE INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin, bmk_seite, pin_schrift_mm) VALUES")
            lines.push("('" + esc(symbolId) + "', '" + esc(info.name) + "', '" + esc(info.kategorie || "") + "', " +
                       (info.breiteMm || 32) + ", " + (info.hoeheMm || 16) + ", '" + esc(info.rolle || "durchleiter") + "', 1, '" +
                       esc(info.bmkSeite || "auto") + "', " + root.fmtN(info.pinSchriftMm || 2.0) + ");")
            if (pinList.length > 0) {
                lines.push("")
                lines.push("INSERT OR IGNORE INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES")
                lines.push(pinWerte(symbolId) + ";")
            }
            if (prims.length > 0) {
                lines.push("")
                lines.push("INSERT OR IGNORE INTO symbol_primitiv (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3, radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger, text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart, rotation) VALUES")
                lines.push(primWerte(symbolId) + ";")
            }
        }
        return lines.join("\n")
    }
}
