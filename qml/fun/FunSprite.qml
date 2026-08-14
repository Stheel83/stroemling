import QtQuick

// Qt 6: required-Properties mit Rollennamen werden vom Repeater automatisch gebunden.
Item {
    id: root

    // Modell-Rollen — automatisch per Namensgleichheit befüllt
    required property real   sx
    required property real   sy
    required property real   sw
    required property real   sh
    required property string typ
    required property string label
    required property string symbolId   // leer für Nicht-Symbol-Elemente

    // Muss explizit gesetzt werden (kein Modell-Pendant)
    required property var theme

    x:      sx
    y:      sy
    width:  sw
    height: sh

    // ── Hintergrund ───────────────────────────────────────────────
    Rectangle {
        anchors.fill:  parent
        radius:        4
        color:         _hintergrund()
        border.color:  Qt.lighter(color, 1.5)
        border.width:  1.5
        // Symbole: nur leichter Hintergrundton – Canvas zeigt das echte Symbol
        opacity:       (root.typ === "symbol" && root.symbolId !== "") ? 0.22 : 1.0
    }

    // ── Symbol-Canvas (nur für Symbol-Elemente mit Primitiven) ────
    // symbolDefinitionModel ist globale Context-Property (main.cpp rootContext)
    Canvas {
        id:      symCanvas
        anchors.fill: parent
        visible: root.typ === "symbol" && root.symbolId !== ""

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var prims = symbolDefinitionModel.primitiveFuerSymbol(root.symbolId)
            if (!prims || prims.length === 0) return

            // 12% Innenabstand damit Linien nicht am Rand abgeschnitten werden
            var pad = 0.12
            var pw  = width  * (1.0 - 2 * pad)
            var ph  = height * (1.0 - 2 * pad)
            ctx.save()
            ctx.translate(width * pad, height * pad)

            ctx.strokeStyle = "#cce0ff"
            ctx.lineWidth   = Math.max(1.2, Math.min(pw, ph) * 0.055)

            for (var i = 0; i < prims.length; i++) {
                var p = prims[i]

                switch (p.linienart) {
                    case "dash":    ctx.setLineDash([5, 3]); break
                    case "dot":     ctx.setLineDash([2, 3]); break
                    case "dashdot": ctx.setLineDash([5,3,2,3]); break
                    default:        ctx.setLineDash([]);     break
                }

                switch (p.typ) {
                    case "linie":
                        ctx.beginPath()
                        ctx.moveTo(p.x1 * pw, p.y1 * ph)
                        ctx.lineTo(p.x2 * pw, p.y2 * ph)
                        ctx.stroke()
                        break
                    case "rechteck": {
                        var rrw = (p.x2-p.x1)*pw, rrh = (p.y2-p.y1)*ph
                        if (p.rotation) {
                            ctx.save()
                            ctx.translate((p.x1+p.x2)/2*pw, (p.y1+p.y2)/2*ph)
                            ctx.rotate(p.rotation * Math.PI / 180)
                            ctx.strokeRect(-rrw/2, -rrh/2, rrw, rrh)
                            ctx.restore()
                        } else {
                            ctx.strokeRect(p.x1*pw, p.y1*ph, rrw, rrh)
                        }
                        break
                    }
                    case "rechteck_gefuellt": {
                        var rgw = (p.x2-p.x1)*pw, rgh = (p.y2-p.y1)*ph
                        ctx.save()
                        ctx.fillStyle = ctx.strokeStyle
                        if (p.rotation) {
                            ctx.translate((p.x1+p.x2)/2*pw, (p.y1+p.y2)/2*ph)
                            ctx.rotate(p.rotation * Math.PI / 180)
                            ctx.fillRect(-rgw/2, -rgh/2, rgw, rgh)
                        } else {
                            ctx.fillRect(p.x1*pw, p.y1*ph, rgw, rgh)
                        }
                        ctx.restore()
                        break
                    }
                    case "kreis_offen":
                        ctx.beginPath()
                        ctx.arc(p.x1*pw, p.y1*ph, p.radius*pw, 0, 2*Math.PI)
                        ctx.stroke()
                        break
                    case "kreis_gefuellt":
                        ctx.save()
                        ctx.fillStyle = ctx.strokeStyle
                        ctx.beginPath()
                        ctx.arc(p.x1*pw, p.y1*ph, p.radius*pw, 0, 2*Math.PI)
                        ctx.fill()
                        ctx.restore()
                        break
                    case "bogen":
                        ctx.beginPath()
                        ctx.arc(p.x1*pw, p.y1*ph, p.radius*pw,
                                p.winkel_von * Math.PI / 180,
                                p.winkel_bis * Math.PI / 180,
                                p.bogen_gegen_uhrzeiger)
                        ctx.stroke()
                        break
                    case "text":
                        ctx.save()
                        ctx.fillStyle    = ctx.strokeStyle
                        ctx.font         = (p.schrift_fett ? "bold " : "")
                                           + Math.round(p.schrift_relativ * ph) + "px sans-serif"
                        ctx.textAlign    = p.text_align    || "center"
                        ctx.textBaseline = p.text_baseline || "middle"
                        if (p.rotation) {
                            ctx.translate(p.x1*pw, p.y1*ph)
                            ctx.rotate(p.rotation * Math.PI / 180)
                            ctx.fillText(p.text_inhalt, 0, 0)
                        } else {
                            ctx.fillText(p.text_inhalt, p.x1*pw, p.y1*ph)
                        }
                        ctx.restore()
                        break
                    case "dreieck_gefuellt":
                        ctx.save()
                        ctx.fillStyle = ctx.strokeStyle
                        ctx.beginPath()
                        ctx.moveTo(p.x1*pw, p.y1*ph)
                        ctx.lineTo(p.x2*pw, p.y2*ph)
                        ctx.lineTo(p.x3*pw, p.y3*ph)
                        ctx.closePath()
                        ctx.fill()
                        ctx.restore()
                        break
                }
            }
            ctx.setLineDash([])
            ctx.restore()
        }

        // Einmalig beim Erstellen zeichnen (Position ändert sich danach per x/y des parent Item)
        Component.onCompleted: Qt.callLater(requestPaint)
    }

    // ── Beschriftung (für Nicht-Symbol-Elemente) ──────────────────
    Text {
        anchors {
            left: parent.left; leftMargin: 4
            right: parent.right; rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        visible:             !(root.typ === "symbol" && root.symbolId !== "")
        text:                root.label
        font.pixelSize:      Math.max(8, Math.min(11, root.sh * 0.38))
        color:               "#e8e8e8"
        elide:               Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    function _hintergrund() {
        switch (root.typ) {
            case "symbol":         return "#0d2a44"
            case "text":           return "#6b5a0a"
            case "notiz":          return "#7a6a00"
            case "rechteck":       return "#1a4a2a"
            case "linie":          return "#4a1060"
            case "kabellinie":     return "#3a1855"
            case "geraetekasten":  return "#1e3a5a"
            case "strukturkasten": return "#2a2a5a"
            default:               return "#2c3e50"
        }
    }
}
