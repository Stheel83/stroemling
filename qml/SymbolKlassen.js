.pragma library

// Symbole ohne BMK-Sektion im EP (reine Verbindungshelfer ohne eigenes Betriebsmittelkennzeichen)
var VERB_SYMS = [
    "winkel", "treffpunkt", "treffpunkt_l",
    "geraeteanschluss", "unterbrechung",
    "querverweis", "aderdefinition",
    "klemme_anschluss"
]

function istVerbHelper(sid) {
    return VERB_SYMS.indexOf(sid) >= 0
}

// Symbole mit eigenem Canvas-Beschriftungsblock → allgemeinen BMK-Renderblock überspringen
// (potenzial hat BMK im EP, aber eigene Renderlogik im Canvas)
function hatEigenenBeschriftungsBlock(sid) {
    return istVerbHelper(sid) || sid === "potenzial"
}

// Standard-bmkOffsetY-Default je nach Symboltyp (Pixel-Einheiten, unabhängig von zoom)
function bmkOffsetYDefault(sid) {
    return (sid === "potenzial" || sid === "geraeteanschluss" || sid === "klemme_anschluss") ? 0 : -14
}
