.pragma library

// Mehrfachauswahl im Symboleditor (SE-MEHRFACHAUSWAHL-01): reine Geometrie in
// normierten 0..1-Koordinaten, ohne Zugriff auf Editor-Zustand (testbar).

// Welche Koordinatenpaare ein Primitiv beim Verschieben mitnimmt – identisch zum
// bisherigen Einzel-Verschieben: Kreis/Bogen/Text nur x1/y1.
function _hatXY2(typ) { return typ === "linie" || typ === "rechteck" || typ === "rechteck_gefuellt" || typ === "dreieck_gefuellt" }
function _hatXY3(typ) { return typ === "dreieck_gefuellt" }

// Bounding-Box {x1,y1,x2,y2} (x1<=x2, y1<=y2). radius ist relativ zur Breite
// normiert (Renderer: radius*dw) → in Y × breite/hoehe.
function bboxPrimitiv(p, breiteMm, hoeheMm) {
    var xs = [p.x1 || 0], ys = [p.y1 || 0]
    if (_hatXY2(p.typ)) { xs.push(p.x2 || 0); ys.push(p.y2 || 0) }
    if (_hatXY3(p.typ)) { xs.push((p.x3 || p.x1) || 0); ys.push((p.y3 || p.y1) || 0) }
    var x1 = Math.min.apply(null, xs), x2 = Math.max.apply(null, xs)
    var y1 = Math.min.apply(null, ys), y2 = Math.max.apply(null, ys)
    if (p.typ === "kreis_offen" || p.typ === "kreis_gefuellt" || p.typ === "bogen") {
        var rx = p.radius || 0
        var ry = rx * breiteMm / hoeheMm
        x1 -= rx; x2 += rx; y1 -= ry; y2 += ry
    }
    return { x1: x1, y1: y1, x2: x2, y2: y2 }
}

// Auswahlrahmen r = {x1,y1,x2,y2} (beliebige Ecken-Reihenfolge).
// fenster=true: Box muss komplett im Rahmen liegen; false (Schneiden): Überlappung genügt.
function trifftRahmen(bb, r, fenster) {
    var rx1 = Math.min(r.x1, r.x2), rx2 = Math.max(r.x1, r.x2)
    var ry1 = Math.min(r.y1, r.y2), ry2 = Math.max(r.y1, r.y2)
    if (fenster) return bb.x1 >= rx1 && bb.x2 <= rx2 && bb.y1 >= ry1 && bb.y2 <= ry2
    return bb.x1 <= rx2 && bb.x2 >= rx1 && bb.y1 <= ry2 && bb.y2 >= ry1
}

// Kopie des Primitivs um (dx,dy) verschoben.
function verschiebePrimitiv(p, dx, dy) {
    var q = Object.assign({}, p)
    q.x1 = (q.x1 || 0) + dx; q.y1 = (q.y1 || 0) + dy
    if (_hatXY2(q.typ)) { q.x2 = (q.x2 || 0) + dx; q.y2 = (q.y2 || 0) + dy }
    if (_hatXY3(q.typ)) { q.x3 = (q.x3 || 0) + dx; q.y3 = (q.y3 || 0) + dy }
    return q
}

// Begrenzt den Versatz so, dass keine Ankerkoordinate der Auswahl aus 0..1 läuft
// (sonst würde am Rand gestaucht statt verschoben). primList/pinList: Indizes.
function gruppenDelta(prims, pins, primList, pinList, dx, dy) {
    var minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity
    function nimm(x, y) {
        if (x < minX) minX = x; if (x > maxX) maxX = x
        if (y < minY) minY = y; if (y > maxY) maxY = y
    }
    primList.forEach(function(i) {
        var p = prims[i]
        nimm(p.x1 || 0, p.y1 || 0)
        if (_hatXY2(p.typ)) nimm(p.x2 || 0, p.y2 || 0)
        if (_hatXY3(p.typ)) nimm(p.x3 || 0, p.y3 || 0)
    })
    pinList.forEach(function(i) { nimm(pins[i].x, pins[i].y) })
    if (minX === Infinity) return { dx: 0, dy: 0 }
    return {
        dx: Math.max(-minX, Math.min(1 - maxX, dx)),
        dy: Math.max(-minY, Math.min(1 - maxY, dy))
    }
}
