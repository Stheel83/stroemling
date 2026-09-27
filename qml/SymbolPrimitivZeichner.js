.pragma library

// Gemeinsamer Primitiv-Zeichner für Symbol-VORSCHAUEN (Palette-Zeile/Hover,
// Bauteil-Symbol-Picker, Fun-Modus-Sprite). Der "echte" Canvas-Renderer
// (CanvasRenderHandler.qml) bleibt bewusst getrennt - der macht zusätzlich
// Rotation/Spiegelung/Farbüberschreibung des ganzen platzierten Symbols und
// ist strukturell nicht vergleichbar.
//
// SE-LINIENART-SPRACHE-01-Nachtrag/QML-REFACTOR-06: vorher hatte
// SymbolPalette.qml/BaSymbolPickerDialog.qml/FunSprite.qml denselben
// Primitiv-Zeichen-Switch dreifach eigenständig kopiert - die
// linienart-Sprachkorrektur musste dadurch einzeln in allen drei Dateien
// nachgezogen werden. BaSymbolPickerDialog.qml/FunSprite.qml skalierten
// Kreise zusätzlich mit `radius*w` statt `radius*Math.min(w,h)` wie
// SymbolPalette.qml - bei einer nicht-quadratischen Vorschau-Box wurden
// Kreise dort zu Ellipsen verzerrt. Ein Aufruf dieser Funktion behebt beides
// einheitlich.

// Zeichnet eine Primitiv-Liste (aus symbolDefinitionModel.primitiveFuerSymbol())
// normiert auf die übergebene Box (w×h) in den 2D-Context ctx.
function zeichnePrimitive(ctx, prims, w, h) {
    // Einheitlicher Skalierungsfaktor statt getrennt w/h, damit Kreise/Bögen
    // nicht zu Ellipsen verzerrt werden, wenn die Vorschau-Box ein anderes
    // Seitenverhältnis hat als die Symbolgröße (z.B. 16x16mm).
    var scale = Math.min(w, h)
    var offX  = (w - scale) / 2
    var offY  = (h - scale) / 2
    function sx(nx) { return nx * scale + offX }
    function sy(ny) { return ny * scale + offY }

    for (var i = 0; i < prims.length; i++) {
        var p = prims[i]
        switch (p.linienart) {
            case "dash":    ctx.setLineDash([4, 2]); break
            case "dot":     ctx.setLineDash([1, 2]); break
            case "dashdot": ctx.setLineDash([4, 2, 1, 2]); break
            default:        ctx.setLineDash([]);     break
        }
        switch (p.typ) {
            case "linie":
                ctx.beginPath()
                ctx.moveTo(sx(p.x1), sy(p.y1))
                ctx.lineTo(sx(p.x2), sy(p.y2))
                ctx.stroke()
                break
            case "rechteck": {
                var rrw = (p.x2 - p.x1) * scale, rrh = (p.y2 - p.y1) * scale
                if (p.rotation) {
                    ctx.save()
                    ctx.translate(sx((p.x1+p.x2)/2), sy((p.y1+p.y2)/2))
                    ctx.rotate(p.rotation * Math.PI / 180)
                    ctx.strokeRect(-rrw / 2, -rrh / 2, rrw, rrh)
                    ctx.restore()
                } else {
                    ctx.strokeRect(sx(p.x1), sy(p.y1), rrw, rrh)
                }
                break
            }
            case "rechteck_gefuellt": {
                var rgw = (p.x2 - p.x1) * scale, rgh = (p.y2 - p.y1) * scale
                ctx.save()
                ctx.fillStyle = ctx.strokeStyle
                if (p.rotation) {
                    ctx.translate(sx((p.x1+p.x2)/2), sy((p.y1+p.y2)/2))
                    ctx.rotate(p.rotation * Math.PI / 180)
                    ctx.fillRect(-rgw / 2, -rgh / 2, rgw, rgh)
                } else {
                    ctx.fillRect(sx(p.x1), sy(p.y1), rgw, rgh)
                }
                ctx.restore()
                break
            }
            case "kreis_offen":
                ctx.beginPath()
                ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale, 0, 2 * Math.PI)
                ctx.stroke()
                break
            case "kreis_gefuellt":
                ctx.save()
                ctx.fillStyle = ctx.strokeStyle
                ctx.beginPath()
                ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale, 0, 2 * Math.PI)
                ctx.fill()
                ctx.restore()
                break
            case "bogen":
                ctx.beginPath()
                ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale,
                        p.winkel_von * Math.PI / 180,
                        p.winkel_bis * Math.PI / 180,
                        p.bogen_gegen_uhrzeiger)
                ctx.stroke()
                break
            case "text":
                ctx.save()
                ctx.fillStyle    = ctx.strokeStyle
                ctx.font         = (p.schrift_fett ? "bold " : "") +
                                   Math.round(p.schrift_relativ * scale) + "px sans-serif"
                ctx.textAlign    = p.text_align    || "center"
                ctx.textBaseline = p.text_baseline || "middle"
                if (p.rotation) {
                    ctx.translate(sx(p.x1), sy(p.y1))
                    ctx.rotate(p.rotation * Math.PI / 180)
                    ctx.fillText(p.text_inhalt, 0, 0)
                } else {
                    ctx.fillText(p.text_inhalt, sx(p.x1), sy(p.y1))
                }
                ctx.restore()
                break
            case "dreieck_gefuellt":
                ctx.save()
                ctx.fillStyle = ctx.strokeStyle
                ctx.beginPath()
                ctx.moveTo(sx(p.x1), sy(p.y1))
                ctx.lineTo(sx(p.x2), sy(p.y2))
                ctx.lineTo(sx(p.x3), sy(p.y3))
                ctx.closePath()
                ctx.fill()
                ctx.restore()
                break
        }
    }
    ctx.setLineDash([])
}
