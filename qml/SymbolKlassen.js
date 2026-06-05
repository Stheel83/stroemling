.pragma library

// Symbole die eigene Beschriftungsblöcke haben und den allgemeinen BMK-Renderblock überspringen
var VERB_SYMS = [
    "winkel", "treffpunkt", "treffpunkt_l",
    "geraeteanschluss", "unterbrechung",
    "querverweis", "aderdefinition",
    "klemme_anschluss", "potenzial"
]

function istVerbHelper(sid) {
    return VERB_SYMS.indexOf(sid) >= 0
}

// Standard-bmkOffsetY-Default je nach Symboltyp (Pixel-Einheiten, unabhängig von zoom)
function bmkOffsetYDefault(sid) {
    return (sid === "potenzial" || sid === "geraeteanschluss" || sid === "klemme_anschluss") ? 0 : -14
}
