.pragma library

// Größenänderung im Symboleditor (SE-GROESSE-01): Primitive und Pins sind in
// 0..1 relativ zur Symbolgröße gespeichert. Ändert man Breite/Höhe, bleiben die
// absoluten mm-Maße des Inhalts erhalten (kein Verzerren) – das Symbol wächst
// nach rechts/unten bzw. schrumpft von dort. Dafür werden die normierten Werte
// mit alt/neu umgerechnet:
//   x1/x2/x3, Pin-x          → × altBreite/neuBreite
//   y1/y2/y3, Pin-y          → × altHoehe/neuHoehe
//   radius (relativ zur Breite, s. Renderer: radius*dw) → × altBreite/neuBreite
//   schrift_relativ (relativ zur Höhe: schrift*dh, nur Text) → × altHoehe/neuHoehe
function skaliere(primitive, pins, altB, altH, neuB, neuH) {
    var fx = altB / neuB
    var fy = altH / neuH
    function mul(o, k, f) { if (typeof o[k] === "number") o[k] = o[k] * f }
    var np = primitive.map(function(p) {
        var q = Object.assign({}, p)
        mul(q, "x1", fx); mul(q, "x2", fx); mul(q, "x3", fx)
        mul(q, "y1", fy); mul(q, "y2", fy); mul(q, "y3", fy)
        mul(q, "radius", fx)
        if (q.typ === "text") mul(q, "schrift_relativ", fy)
        return q
    })
    var npin = pins.map(function(p) {
        var q = Object.assign({}, p)
        mul(q, "x", fx); mul(q, "y", fy)
        return q
    })
    return { primitive: np, pins: npin }
}
