import QtQuick

// Zeichenfläche des Symboleditors: Raster, Primitive, Pins, Auswahl-/Gummiband-Darstellung
// (onPaint) und die Maus-Interaktion aller Werkzeuge. Zustand und Aktionen liegen im Editor
// (`editor` = SymbolEditorAnsicht); diese Komponente zeichnet und leitet Eingaben weiter.
Canvas {
    id: cv
    required property var editor
    anchors.fill: parent
    renderStrategy: Canvas.Threaded

    // Rechteckiger Zeichenbereich – Seitenverhältnis = breiteMm : hoeheMm
    readonly property real padding:  36
    readonly property real baseSize: Math.min(width - 2*padding, height - 2*padding)
    readonly property real drawW:    baseSize * editor._seZoom * editor.breiteMm / Math.max(editor.breiteMm, editor.hoeheMm)
    readonly property real drawH:    baseSize * editor._seZoom * editor.hoeheMm  / Math.max(editor.breiteMm, editor.hoeheMm)
    readonly property real drawX:    (width  - drawW) / 2 + editor._sePanX
    readonly property real drawY:    (height - drawH) / 2 + editor._sePanY

    function n2sx(n) { return drawX + n * drawW }
    function n2sy(n) { return drawY + n * drawH }

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var dw = drawW, dh = drawH, dx = drawX, dy = drawY

        // ── Hintergrund der Zeichenfläche ──────────
        ctx.fillStyle = "#fdf8e8"
        ctx.fillRect(dx, dy, dw, dh)

        // ── Punkt-Raster (0.5-mm-Schritte) ───────────────────
        var stepsX = editor.breiteMm * 2   // 0.5mm pro Schritt
        var stepsY = editor.hoeheMm  * 2
        ctx.fillStyle = "#2a3a5a"
        for (var gi = 0; gi <= stepsX; gi++) {
            for (var gj = 0; gj <= stepsY; gj++) {
                ctx.beginPath()
                ctx.arc(dx + gi/stepsX*dw, dy + gj/stepsY*dh, 1.5, 0, 2*Math.PI)
                ctx.fill()
            }
        }
        // 4-mm-Rasterpunkte größer hervorheben
        var grid4X = Math.round(editor.breiteMm / 4)
        var grid4Y = Math.round(editor.hoeheMm  / 4)
        ctx.fillStyle = "#5577aa"
        for (var gx4 = 0; gx4 <= grid4X; gx4++) {
            for (var gy4 = 0; gy4 <= grid4Y; gy4++) {
                ctx.beginPath()
                ctx.arc(dx + gx4/grid4X*dw, dy + gy4/grid4Y*dh, 3.0, 0, 2*Math.PI)
                ctx.fill()
            }
        }

        // ── mm-Lineal (oben und links) ────────────
        var pxPerMmX = dw / editor.breiteMm
        var pxPerMmY = dh / editor.hoeheMm
        ctx.save()
        ctx.lineWidth = 0.7
        // X-Lineal oben
        for (var mx = 0; mx <= editor.breiteMm; mx++) {
            var isLabeledX = (mx % 4 === 0)
            var tickLenX   = isLabeledX ? 8 : 4
            var xtx = dx + mx * pxPerMmX
            ctx.strokeStyle = "#6688aa"
            ctx.beginPath(); ctx.moveTo(xtx, dy - tickLenX); ctx.lineTo(xtx, dy); ctx.stroke()
            if (isLabeledX) {
                ctx.fillStyle = "#6688aa"; ctx.font = "9px sans-serif"
                ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                ctx.fillText(mx, xtx, dy - tickLenX - 1)
            }
        }
        // Y-Lineal links
        for (var my = 0; my <= editor.hoeheMm; my++) {
            var isLabeledY = (my % 4 === 0)
            var tickLenY   = isLabeledY ? 8 : 4
            var yty = dy + my * pxPerMmY
            ctx.strokeStyle = "#6688aa"
            ctx.beginPath(); ctx.moveTo(dx - tickLenY, yty); ctx.lineTo(dx, yty); ctx.stroke()
            if (isLabeledY) {
                ctx.fillStyle = "#6688aa"; ctx.font = "9px sans-serif"
                ctx.textAlign = "right"; ctx.textBaseline = "middle"
                ctx.fillText(my, dx - tickLenY - 3, yty)
            }
        }
        // Einheit "mm" an der Ecke
        ctx.fillStyle = "#445566"; ctx.font = "8px sans-serif"
        ctx.textAlign = "right"; ctx.textBaseline = "bottom"
        ctx.fillText("mm", dx - 2, dy - 2)
        ctx.restore()

        // ── Rand der Zeichenfläche ─────────────────
        ctx.strokeStyle = "#3a4a6a"
        ctx.lineWidth   = 1
        ctx.setLineDash([4, 4])
        ctx.strokeRect(dx + 0.5, dy + 0.5, dw - 1, dh - 1)
        ctx.setLineDash([])

        // ── Primitive ─────────────────────────────
        // Vorschau-Drehung (SYMBOL-TEXT-LESBAR-01-Folge): translate/rotate/
        // scale/translate(-dw/2,-dh/2), identisch zum Muster in
        // CanvasRenderHandler.qml::_renderSymbol() - kollabiert bei
        // Rotation 0°/keine Spiegelung zur Identität (translate(dx,dy)),
        // daher hier immer angewendet statt bedingt verzweigt.
        ctx.lineCap  = "round"
        ctx.lineJoin = "round"
        var _pvRad = editor._sePreviewRotation * Math.PI / 180
        var _pvAktiv = editor._sePreviewRotation !== 0 ||
                       editor._sePreviewSpiegelX || editor._sePreviewSpiegelY

        ctx.save()
        ctx.translate(dx + dw/2, dy + dh/2)
        if (_pvRad !== 0) ctx.rotate(_pvRad)
        if (editor._sePreviewSpiegelX) ctx.scale(-1, 1)
        if (editor._sePreviewSpiegelY) ctx.scale(1, -1)
        ctx.translate(-dw/2, -dh/2)

        for (var pi = 0; pi < editor.primitive.length; pi++) {
            var p = editor.primitive[pi]
            var isSel = (pi === editor.ausgewaehltPrimIdx) || editor.multiPrim.indexOf(pi) >= 0
            ctx.strokeStyle = isSel ? "#00e5a0" : "#0b5394"
            ctx.lineWidth   = isSel ? 3.0 : 2.0

            var la = p.linienart || "solid"
            if      (la === "dash")    ctx.setLineDash([8, 4])
            else if (la === "dot")     ctx.setLineDash([2, 4])
            else if (la === "dashdot") ctx.setLineDash([8, 4, 2, 4])
            else                       ctx.setLineDash([])

            // dx/dy=0: Ursprung liegt bereits durch obiges translate() an
            // der (ggf. gedrehten/gespiegelten) Box-Ecke.
            cv.zeichnePrimitiv(ctx, p, 0, 0, dw, dh)
            ctx.setLineDash([])

            // Immer sichtbarer Anfasspunkt-Hinweis (Nutzerwunsch): Linien/
            // Rechtecke lassen sich überall auf der gezeichneten Kontur
            // treffen, Text/Kreis/Bogen aber nur über ihren einzelnen
            // Ankerpunkt (x1,y1) - der ist ohne Markierung schwer zu finden,
            // v.a. bei Text (Anker je nach text_align/-baseline nicht immer
            // unter dem sichtbaren Zeichen). Nur wenn NICHT ausgewählt
            // gezeichnet, sonst überdeckt vom größeren Auswahl-Griff unten.
            if (!isSel && (p.typ === "text" || p.typ === "kreis_offen" ||
                           p.typ === "kreis_gefuellt" || p.typ === "bogen")) {
                ctx.save()
                ctx.fillStyle   = "#ff8800"
                ctx.strokeStyle = "#3a1f00"
                ctx.lineWidth   = 1.2
                ctx.beginPath()
                ctx.arc((p.x1||0)*dw, (p.y1||0)*dh, 5, 0, 2*Math.PI)
                ctx.fill()
                ctx.stroke()
                ctx.restore()
            }
        }
        ctx.restore()

        // Griffe + Koordinaten-Label bei Auswahl nur in Basis-Orientierung
        // (Nutzerwunsch: X1/Y1/X2/Y2 direkt am Primitiv) - bei aktiver
        // Vorschau-Drehung würde die unrotierte n2sx/n2sy-Position nicht
        // mehr zur gezeichneten (gedrehten) Primitiv-Position passen.
        if (!_pvAktiv && editor.ausgewaehltPrimIdx >= 0) {
            var pSel = editor.primitive[editor.ausgewaehltPrimIdx]
            if (pSel) {
                ctx.strokeStyle = "#00e5a0"
                // Bei rotierten Rechtecken zeigen die Griffe die tatsächliche
                // (gedrehte) Bildschirmposition der Ecken, sonst würden sie
                // sichtbar neben dem gezeichneten Rechteck schweben.
                var g1x = n2sx(pSel.x1 || 0), g1y = n2sy(pSel.y1 || 0)
                var g2x = n2sx(pSel.x2 || 0), g2y = n2sy(pSel.y2 || 0)
                if (pSel.rotation && (pSel.typ === "rechteck" || pSel.typ === "rechteck_gefuellt")) {
                    var gcx = n2sx(((pSel.x1||0)+(pSel.x2||0))/2), gcy = n2sy(((pSel.y1||0)+(pSel.y2||0))/2)
                    var grad = pSel.rotation * Math.PI / 180
                    var gcos = Math.cos(grad), gsin = Math.sin(grad)
                    var d1x = g1x - gcx, d1y = g1y - gcy
                    var d2x = g2x - gcx, d2y = g2y - gcy
                    g1x = gcx + d1x*gcos - d1y*gsin; g1y = gcy + d1x*gsin + d1y*gcos
                    g2x = gcx + d2x*gcos - d2y*gsin; g2y = gcy + d2x*gsin + d2y*gcos
                }
                cv.zeichneGriff(ctx, g1x, g1y)
                cv.zeichneKoordLabel(ctx, g1x, g1y,
                    "X1", "Y1", editor.normToMmX(pSel.x1 || 0), editor.normToMmY(pSel.y1 || 0))
                if (pSel.typ === "linie" || pSel.typ === "rechteck" || pSel.typ === "rechteck_gefuellt") {
                    cv.zeichneGriff(ctx, g2x, g2y)
                    cv.zeichneKoordLabel(ctx, g2x, g2y,
                        "X2", "Y2", editor.normToMmX(pSel.x2 || 0), editor.normToMmY(pSel.y2 || 0))
                }
            }
        }

        // ── "Lesbar halten"-Text-Primitive (SYMBOL-TEXT-LESBAR-01) ──
        // Werden in zeichnePrimitiv() übersprungen (s.dort) und hier separat
        // aufrecht an der transformierten Ankerposition gezeichnet - exakt
        // dieselbe Formel wie in CanvasRenderHandler.qml::_renderSymbol().
        for (var lti = 0; lti < editor.primitive.length; lti++) {
            var ltp = editor.primitive[lti]
            if (ltp.typ !== "text" || !ltp.lesbar_halten) continue
            var ox = (ltp.x1||0)*dw - dw/2
            var oy = (ltp.y1||0)*dh - dh/2
            if (editor._sePreviewSpiegelX) ox = -ox
            if (editor._sePreviewSpiegelY) oy = -oy
            var tx = ox*Math.cos(_pvRad) - oy*Math.sin(_pvRad)
            var ty = ox*Math.sin(_pvRad) + oy*Math.cos(_pvRad)
            ctx.save()
            ctx.fillStyle = (lti === editor.ausgewaehltPrimIdx || editor.multiPrim.indexOf(lti) >= 0) ? "#00e5a0" : "#0b5394"
            ctx.font = ((ltp.schrift_fett ? "bold " : "") +
                        Math.round((ltp.schrift_relativ||0.15)*dh) + "px sans-serif")
            ctx.textAlign    = ltp.text_align    || "center"
            ctx.textBaseline = ltp.text_baseline || "middle"
            ctx.fillText(ltp.text_inhalt||"?", dx+dw/2+tx, dy+dh/2+ty)
            ctx.restore()
        }

        // ── Vorschau-Linie (aktuelles Werkzeug) ───
        if (editor.mausImCanvas && editor.werkzeugPunkte.length > 0) {
            ctx.strokeStyle = "#ffcc00"
            ctx.lineWidth   = 1.5
            ctx.setLineDash([4, 4])
            var pts = editor.werkzeugPunkte
            var mx  = editor.mausNormPos.x, my = editor.mausNormPos.y

            if (editor.aktivesWerkzeug === "linie") {
                ctx.beginPath()
                ctx.moveTo(n2sx(pts[0].x), n2sy(pts[0].y))
                ctx.lineTo(n2sx(mx), n2sy(my))
                ctx.stroke()
            } else if (editor.aktivesWerkzeug === "rechteck") {
                ctx.strokeRect(n2sx(pts[0].x), n2sy(pts[0].y), (mx-pts[0].x)*dw, (my-pts[0].y)*dh)
            } else if (editor.aktivesWerkzeug === "kreis_offen") {
                var kd = Math.sqrt(Math.pow((mx-pts[0].x)*dw, 2) + Math.pow((my-pts[0].y)*dh, 2))
                ctx.beginPath()
                ctx.arc(n2sx(pts[0].x), n2sy(pts[0].y), kd, 0, 2*Math.PI)
                ctx.stroke()
            } else if (editor.aktivesWerkzeug === "bogen") {
                if (pts.length === 1) {
                    ctx.beginPath()
                    ctx.moveTo(n2sx(pts[0].x), n2sy(pts[0].y))
                    ctx.lineTo(n2sx(mx), n2sy(my))
                    ctx.stroke()
                } else if (pts.length === 2) {
                    var bRad = Math.sqrt(Math.pow((pts[1].x-pts[0].x)*dw, 2) + Math.pow((pts[1].y-pts[0].y)*dh, 2))
                    var bW1  = Math.atan2((pts[1].y-pts[0].y)*dh, (pts[1].x-pts[0].x)*dw)
                    var bW2  = Math.atan2((my-pts[0].y)*dh, (mx-pts[0].x)*dw)
                    ctx.beginPath()
                    ctx.arc(n2sx(pts[0].x), n2sy(pts[0].y), bRad, bW1, bW2, false)
                    ctx.stroke()
                }
            }
            ctx.setLineDash([])
        }

        // ── Pins ──────────────────────────────────
        // SE-KNOTEN-VISUALISIERUNG-01: Pin-Farbe zeigt die Knoten-Gruppe,
        // damit sichtbar wird, welche Pins intern verbunden sind, statt die
        // Zahlenfelder in der Liste einzeln vergleichen zu müssen. Die
        // Gruppennummer wird nur an die Beschriftung angehängt, wenn das
        // Symbol tatsächlich mehr als eine Gruppe hat.
        var _knotenSet = {}
        for (var _kpi = 0; _kpi < editor.pins.length; _kpi++)
            _knotenSet[editor.pins[_kpi].knotenGruppe || 0] = true
        var _mehrereKnoten = Object.keys(_knotenSet).length > 1
        for (var pii = 0; pii < editor.pins.length; pii++) {
            var pin = editor.pins[pii]
            var isSelP  = (pii === editor.ausgewaehltPinIdx) || editor.multiPins.indexOf(pii) >= 0
            var kFarbe  = editor.knotenFarbe(pin.knotenGruppe || 0)
            ctx.beginPath()
            ctx.arc(n2sx(pin.x), n2sy(pin.y), isSelP ? 6 : 4, 0, 2*Math.PI)
            ctx.fillStyle   = isSelP ? "#ff8800" : kFarbe
            ctx.strokeStyle = isSelP ? "#7f4400" : "#0a2040"
            ctx.lineWidth   = 1; ctx.fill(); ctx.stroke()
            // Pin-Bezeichnung
            ctx.save()
            ctx.fillStyle = isSelP ? "#ff8800" : kFarbe
            ctx.font = "10px sans-serif"
            ctx.textAlign = "left"; ctx.textBaseline = "bottom"
            var pinLabel = (pin.name || "") + (_mehrereKnoten ? " ·" + (pin.knotenGruppe || 0) : "")
            ctx.fillText(pinLabel, n2sx(pin.x)+8, n2sy(pin.y)-1)
            ctx.restore()
            // Richtungspfeil (offen-Vektor)
            ctx.strokeStyle = isSelP ? "#ff8800" : kFarbe
            ctx.lineWidth   = 1.5
            ctx.beginPath()
            ctx.moveTo(n2sx(pin.x), n2sy(pin.y))
            ctx.lineTo(n2sx(pin.x) + (pin.offenX||0)*12, n2sy(pin.y) + (pin.offenY||0)*12)
            ctx.stroke()
        }

        // ── Auswahlrahmen (SE-MEHRFACHAUSWAHL-01) ──
        if (editor._rbAktiv) {
            var rbFenster = editor._rbB.x >= editor._rbA.x
            var rx = n2sx(Math.min(editor._rbA.x, editor._rbB.x)), ry = n2sy(Math.min(editor._rbA.y, editor._rbB.y))
            var rw = Math.abs(n2sx(editor._rbB.x) - n2sx(editor._rbA.x)), rh = Math.abs(n2sy(editor._rbB.y) - n2sy(editor._rbA.y))
            ctx.save()
            ctx.fillStyle   = rbFenster ? "#4a9eff22" : "#4ec94e22"
            ctx.strokeStyle = rbFenster ? "#4a9eff"   : "#4ec94e"
            ctx.lineWidth   = 1.5
            ctx.setLineDash(rbFenster ? [] : [6, 4])
            ctx.fillRect(rx, ry, rw, rh)
            ctx.strokeRect(rx, ry, rw, rh)
            ctx.restore()
        }

        // ── Fadenkreuz ────────────────────────────
        if (editor.mausImCanvas && editor.aktivesWerkzeug !== "auswahl") {
            var scx2 = n2sx(editor.mausNormPos.x), scy2 = n2sy(editor.mausNormPos.y)
            ctx.strokeStyle = "#ffcc0066"; ctx.lineWidth = 1
            ctx.setLineDash([2, 2])
            ctx.beginPath(); ctx.moveTo(dx, scy2); ctx.lineTo(dx+ds, scy2); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(scx2, dy); ctx.lineTo(scx2, dy+ds); ctx.stroke()
            ctx.setLineDash([])
            ctx.beginPath()
            ctx.arc(scx2, scy2, 4, 0, 2*Math.PI)
            ctx.strokeStyle = "#ffcc00"; ctx.lineWidth = 1.5; ctx.stroke()
        }
    }

    function zeichneGriff(ctx, px, py) {
        ctx.save()
        ctx.fillStyle = "#00e5a0"; ctx.strokeStyle = "#004d35"; ctx.lineWidth = 1.5
        ctx.beginPath(); ctx.arc(px, py, 5, 0, 2*Math.PI); ctx.fill(); ctx.stroke()
        ctx.restore()
    }

    // Koordinaten-Label neben einem Griff (mm, aus Normkoordinaten
    // umgerechnet) — Nutzerwunsch: Orientierung direkt am Primitiv.
    function zeichneKoordLabel(ctx, px, py, labelX, labelY, mmX, mmY) {
        ctx.save()
        ctx.font = "10px sans-serif"
        ctx.textAlign    = "left"
        ctx.textBaseline = "top"
        var text = labelX + ": " + mmX.toFixed(2) + "mm   " + labelY + ": " + mmY.toFixed(2) + "mm"
        var boxX = px + 8, boxY = py + 8
        var tw   = ctx.measureText(text).width
        ctx.fillStyle = "rgba(10, 20, 15, 0.78)"
        ctx.fillRect(boxX - 3, boxY - 2, tw + 6, 15)
        ctx.fillStyle = "#00e5a0"
        ctx.fillText(text, boxX, boxY)
        ctx.restore()
    }

    function zeichnePrimitiv(ctx, p, dx, dy, dw, dh) {
        switch (p.typ) {
        case "linie":
            ctx.beginPath()
            ctx.moveTo(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
            ctx.lineTo(dx+(p.x2||0)*dw, dy+(p.y2||0)*dh)
            ctx.stroke()
            break
        case "rechteck": {
            var rrw = ((p.x2||0)-(p.x1||0))*dw, rrh = ((p.y2||0)-(p.y1||0))*dh
            if (p.rotation) {
                ctx.save()
                ctx.translate(dx+((p.x1||0)+(p.x2||0))/2*dw, dy+((p.y1||0)+(p.y2||0))/2*dh)
                ctx.rotate(p.rotation * Math.PI / 180)
                ctx.strokeRect(-rrw/2, -rrh/2, rrw, rrh)
                ctx.restore()
            } else {
                ctx.strokeRect(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, rrw, rrh)
            }
            break
        }
        case "rechteck_gefuellt": {
            var rgw = ((p.x2||0)-(p.x1||0))*dw, rgh = ((p.y2||0)-(p.y1||0))*dh
            ctx.save()
            ctx.fillStyle = ctx.strokeStyle
            if (p.rotation) {
                ctx.translate(dx+((p.x1||0)+(p.x2||0))/2*dw, dy+((p.y1||0)+(p.y2||0))/2*dh)
                ctx.rotate(p.rotation * Math.PI / 180)
                ctx.fillRect(-rgw/2, -rgh/2, rgw, rgh)
            } else {
                ctx.fillRect(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, rgw, rgh)
            }
            ctx.restore()
            break
        }
        case "kreis_offen":
            ctx.beginPath()
            ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.1)*dw, 0, 2*Math.PI)
            ctx.stroke()
            break
        case "kreis_gefuellt":
            ctx.save()
            ctx.fillStyle = ctx.strokeStyle
            ctx.beginPath()
            ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.04)*dw, 0, 2*Math.PI)
            ctx.fill(); ctx.restore()
            break
        case "bogen": {
            var ra = (p.winkel_von||0) * Math.PI/180
            var re = (p.winkel_bis !== undefined && p.winkel_bis !== null ? p.winkel_bis : 90) * Math.PI/180
            ctx.beginPath()
            ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.1)*dw,
                    ra, re, p.bogen_gegen_uhrzeiger ? true : false)
            ctx.stroke()
            break
        }
        case "text":
            // SYMBOL-TEXT-LESBAR-01: wird stattdessen in einem separaten
            // aufrechten Pass gezeichnet, s. onPaint.
            if (p.lesbar_halten) break
            ctx.save()
            ctx.fillStyle = ctx.strokeStyle
            ctx.font = ((p.schrift_fett ? "bold " : "") +
                        Math.round((p.schrift_relativ||0.15)*dh) + "px sans-serif")
            ctx.textAlign    = p.text_align    || "center"
            ctx.textBaseline = p.text_baseline || "middle"
            if (p.rotation) {
                ctx.translate(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
                ctx.rotate(p.rotation * Math.PI / 180)
                ctx.fillText(p.text_inhalt||"?", 0, 0)
            } else {
                ctx.fillText(p.text_inhalt||"?", dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
            }
            ctx.restore()
            break
        case "dreieck_gefuellt":
            ctx.save()
            ctx.fillStyle = ctx.strokeStyle
            ctx.beginPath()
            ctx.moveTo(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
            ctx.lineTo(dx+(p.x2||0)*dw, dy+(p.y2||0)*dh)
            ctx.lineTo(dx+((p.x3||p.x1)||0)*dw, dy+((p.y3||p.y1)||0)*dh)
            ctx.closePath(); ctx.fill(); ctx.restore()
            break
        }
    }

    // ── Maus-Interaktion ──────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        // Drag-Zustand (Auswahl-Werkzeug)
        property bool dragAktiv:       false
        property bool dragIstPin:      false
        property bool dragBewegteSich: false
        property var  dragStartNorm:   ({x: 0, y: 0})
        property var  dragObjStart:    null
        // Gruppen-Drag (Mehrfachauswahl, SE-MEHRFACHAUSWAHL-01)
        property bool _gruppeAktiv:      false
        property var  _gruppeBasisPrim:  []
        property var  _gruppeBasisPins:  []
        property var  _gruppePl:         []
        property var  _gruppeNl:         []
        property bool _rbBewegt:         false

        // Pan-Zustand (mittlere Maustaste)
        property bool _panAktiv:  false
        property var  _panStart:  ({x: 0, y: 0})
        property real _panStartX: 0
        property real _panStartY: 0

        function mausZuNorm(mx, my) {
            var nx = (mx - cv.drawX) / cv.drawW
            var ny = (my - cv.drawY) / cv.drawH
            nx = Math.max(0, Math.min(1, editor.snapX(nx)))
            ny = Math.max(0, Math.min(1, editor.snapY(ny)))
            return {x: nx, y: ny}
        }

        // Wie mausZuNorm, aber ohne Raster/Begrenzung (Auswahlrahmen darf
        // außerhalb des Symbols beginnen/enden, z. B. für „Schneiden")
        function mausZuNormFrei(mx, my) {
            return {x: (mx - cv.drawX) / cv.drawW,
                    y: (my - cv.drawY) / cv.drawH}
        }

        onPressed: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                _panAktiv  = true
                _panStart  = {x: mouse.x, y: mouse.y}
                _panStartX = editor._sePanX
                _panStartY = editor._sePanY
                return
            }
            _rbBewegt = false
            if (editor.aktivesWerkzeug !== "auswahl") return
            if (mouse.button !== Qt.LeftButton) return
            var nm = mausZuNorm(mouse.x, mouse.y)
            var additiv = (mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier)) !== 0
            var pi = editor.treffePin(nm.x, nm.y)
            var priIdx = pi >= 0 ? -1 : editor.treffePrimitiv(nm.x, nm.y)

            if (pi < 0 && priIdx < 0) {
                // Leere Fläche → Auswahlrahmen aufziehen
                editor._rbBasisPrim = additiv ? editor.auswahlPrimListe().slice() : []
                editor._rbBasisPins = additiv ? editor.auswahlPinListe().slice()  : []
                if (!additiv) editor.setzeAuswahl([], [])
                editor._rbA = mausZuNormFrei(mouse.x, mouse.y)
                editor._rbB = editor._rbA
                editor._rbAktiv = true
                cv.requestPaint()
                return
            }

            // Treffer: Auswahl anpassen (Shift/Strg = umschalten, sonst ersetzen
            // – außer das Element gehört schon zur Auswahl, dann bleibt sie bestehen)
            var pl = editor.auswahlPrimListe().slice(), nl = editor.auswahlPinListe().slice()
            var istSel = (pi >= 0) ? nl.indexOf(pi) >= 0 : pl.indexOf(priIdx) >= 0
            if (additiv) {
                if (pi >= 0) nl = istSel ? nl.filter(function(v) { return v !== pi })     : nl.concat([pi])
                else         pl = istSel ? pl.filter(function(v) { return v !== priIdx }) : pl.concat([priIdx])
                editor.setzeAuswahl(pl, nl)
                if (istSel) return          // gerade abgewählt → nicht ziehen
            } else if (!istSel) {
                editor.setzeAuswahl(priIdx >= 0 ? [priIdx] : [], pi >= 0 ? [pi] : [])
            }
            dragStartNorm = {x: nm.x, y: nm.y}
            dragAktiv     = true
            if (editor.auswahlAnzahl >= 2) {
                // Gruppen-Drag: Stand bei Gestenbeginn merken
                _gruppeAktiv     = true
                _gruppeBasisPrim = editor.primitive.slice()
                _gruppeBasisPins = editor.pins.slice()
                _gruppePl        = editor.auswahlPrimListe().slice()
                _gruppeNl        = editor.auswahlPinListe().slice()
            } else if (pi >= 0) {
                dragIstPin   = true
                dragObjStart = {x: editor.pins[pi].x, y: editor.pins[pi].y}
            } else {
                dragIstPin   = false
                dragObjStart = Object.assign({}, editor.primitive[priIdx])
            }
            cv.requestPaint()
        }

        onReleased: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                _panAktiv = false
                return
            }
            if (editor._rbAktiv) {
                editor._rbAktiv = false
                if (_rbBewegt)
                    editor.rahmenAuswahlAnwenden(editor._rbA, editor._rbB, editor._rbBasisPrim, editor._rbBasisPins)
                else
                    editor.setzeAuswahl(editor._rbBasisPrim, editor._rbBasisPins)
                cv.requestPaint()
            }
            dragAktiv     = false
            dragObjStart  = null
            _gruppeAktiv  = false
        }

        onPositionChanged: function(mouse) {
            if (_panAktiv) {
                editor._sePanX = _panStartX + (mouse.x - _panStart.x)
                editor._sePanY = _panStartY + (mouse.y - _panStart.y)
                cv.requestPaint()
                return
            }
            var nm = mausZuNorm(mouse.x, mouse.y)
            editor.mausNormPos  = nm
            editor.mausImCanvas = true

            if (editor._rbAktiv) {
                editor._rbB = mausZuNormFrei(mouse.x, mouse.y)
                // erst ab ~4 px als Rahmen werten (sonst ist es ein einfacher Klick)
                var rbPx = Math.max(Math.abs(editor._rbB.x - editor._rbA.x) * cv.drawW,
                                    Math.abs(editor._rbB.y - editor._rbA.y) * cv.drawH)
                if (rbPx > 4) _rbBewegt = true
                cv.requestPaint()
                return
            }

            if (dragAktiv && _gruppeAktiv) {
                // Versatz auf 0,5-mm-Raster runden (relative Geometrie der Auswahl bleibt erhalten)
                var gdx = Math.round((nm.x - dragStartNorm.x) * editor.breiteMm * 2) / 2 / editor.breiteMm
                var gdy = Math.round((nm.y - dragStartNorm.y) * editor.hoeheMm  * 2) / 2 / editor.hoeheMm
                if (!dragBewegteSich && (gdx !== 0 || gdy !== 0)) {
                    editor.pushUndoSnapshot()
                    dragBewegteSich = true
                }
                if (dragBewegteSich)
                    editor.verschiebeAuswahlUm(_gruppeBasisPrim, _gruppeBasisPins, _gruppePl, _gruppeNl, gdx, gdy)
                return
            }

            if (dragAktiv && dragObjStart !== null) {
                // Snapshot einmalig beim ersten tatsächlichen Verschieben dieser
                // Drag-Geste (nicht bei jedem Mausereignis, sonst würde Strg+Z nur
                // einen winzigen Teilschritt zurücknehmen statt der ganzen Bewegung).
                if (!dragBewegteSich) editor.pushUndoSnapshot()
                var ddx = nm.x - dragStartNorm.x
                var ddy = nm.y - dragStartNorm.y
                if (dragIstPin && editor.ausgewaehltPinIdx >= 0) {
                    var arrP = editor.pins.slice()
                    var pp   = Object.assign({}, arrP[editor.ausgewaehltPinIdx])
                    pp.x = Math.max(0, Math.min(1, editor.snapX(dragObjStart.x + ddx)))
                    pp.y = Math.max(0, Math.min(1, editor.snapY(dragObjStart.y + ddy)))
                    arrP[editor.ausgewaehltPinIdx] = pp
                    editor.pins = arrP
                    dragBewegteSich = true
                } else if (!dragIstPin && editor.ausgewaehltPrimIdx >= 0) {
                    var idx = editor.ausgewaehltPrimIdx
                    var arr = editor.primitive.slice()
                    var p   = Object.assign({}, arr[idx])
                    var o   = dragObjStart
                    p.x1 = Math.max(0, Math.min(1, editor.snapX((o.x1 || 0) + ddx)))
                    p.y1 = Math.max(0, Math.min(1, editor.snapY((o.y1 || 0) + ddy)))
                    if (p.typ === "linie" || p.typ === "rechteck" || p.typ === "rechteck_gefuellt") {
                        p.x2 = Math.max(0, Math.min(1, editor.snapX((o.x2 || 0) + ddx)))
                        p.y2 = Math.max(0, Math.min(1, editor.snapY((o.y2 || 0) + ddy)))
                    }
                    if (p.typ === "dreieck_gefuellt") {
                        p.x2 = Math.max(0, Math.min(1, editor.snapX((o.x2 || 0) + ddx)))
                        p.y2 = Math.max(0, Math.min(1, editor.snapY((o.y2 || 0) + ddy)))
                        p.x3 = Math.max(0, Math.min(1, editor.snapX((o.x3 || 0) + ddx)))
                        p.y3 = Math.max(0, Math.min(1, editor.snapY((o.y3 || 0) + ddy)))
                    }
                    arr[idx] = p
                    editor.primitive = arr
                    dragBewegteSich = true
                }
            }

            cv.requestPaint()
        }

        onExited: {
            editor.mausImCanvas = false
            cv.requestPaint()
        }

        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) return
            if (dragBewegteSich) { dragBewegteSich = false; return }
            if (_rbBewegt) { _rbBewegt = false; editor.forceActiveFocus(); return }
            editor.forceActiveFocus()
            var nm = mausZuNorm(mouse.x, mouse.y)
            var nx = nm.x, ny = nm.y

            if (mouse.button === Qt.RightButton) {
                editor.werkzeugPunkte = []
                cv.requestPaint()
                return
            }

            switch (editor.aktivesWerkzeug) {
            case "auswahl":
                // Auswahl wird seit SE-MEHRFACHAUSWAHL-01 vollständig in onPressed/onReleased gesetzt
                break

            case "linie":
                if (editor.werkzeugPunkte.length === 0) {
                    editor.werkzeugPunkte = [{x:nx,y:ny}]
                } else {
                    editor.addPrimitiv({typ:"linie",x1:editor.werkzeugPunkte[0].x,y1:editor.werkzeugPunkte[0].y,x2:nx,y2:ny,linienart:editor.aktLinienart})
                    editor.werkzeugPunkte = []
                }
                break

            case "rechteck":
                if (editor.werkzeugPunkte.length === 0) {
                    editor.werkzeugPunkte = [{x:nx,y:ny}]
                } else {
                    var rx1=Math.min(editor.werkzeugPunkte[0].x,nx), ry1=Math.min(editor.werkzeugPunkte[0].y,ny)
                    var rx2=Math.max(editor.werkzeugPunkte[0].x,nx), ry2=Math.max(editor.werkzeugPunkte[0].y,ny)
                    editor.addPrimitiv({typ:(editor.aktGefuellt?"rechteck_gefuellt":"rechteck"),x1:rx1,y1:ry1,x2:rx2,y2:ry2,linienart:editor.aktLinienart})
                    editor.werkzeugPunkte = []
                }
                break

            case "kreis_offen": {
                if (editor.werkzeugPunkte.length === 0) {
                    editor.werkzeugPunkte = [{x:nx,y:ny}]
                } else {
                    var kdw = cv.drawW, kdh = cv.drawH
                    var krad = Math.sqrt(Math.pow((nx-editor.werkzeugPunkte[0].x)*kdw, 2) + Math.pow((ny-editor.werkzeugPunkte[0].y)*kdh, 2)) / kdw
                    editor.addPrimitiv({typ:(editor.aktGefuellt?"kreis_gefuellt":"kreis_offen"),x1:editor.werkzeugPunkte[0].x,y1:editor.werkzeugPunkte[0].y,radius:krad,linienart:editor.aktLinienart})
                    editor.werkzeugPunkte = []
                }
                break
            }

            case "bogen":
                if (editor.werkzeugPunkte.length === 0) {
                    editor.werkzeugPunkte = [{x:nx,y:ny}]
                } else if (editor.werkzeugPunkte.length === 1) {
                    editor.werkzeugPunkte = editor.werkzeugPunkte.concat([{x:nx,y:ny}])
                } else {
                    var bdw = cv.drawW, bdh = cv.drawH
                    var bcx = editor.werkzeugPunkte[0].x, bcy = editor.werkzeugPunkte[0].y
                    var bRad2 = Math.sqrt(Math.pow((editor.werkzeugPunkte[1].x-bcx)*bdw, 2) + Math.pow((editor.werkzeugPunkte[1].y-bcy)*bdh, 2)) / bdw
                    var bWv = Math.atan2((editor.werkzeugPunkte[1].y-bcy)*bdh,(editor.werkzeugPunkte[1].x-bcx)*bdw)*180/Math.PI
                    var bWb = Math.atan2((ny-bcy)*bdh,(nx-bcx)*bdw)*180/Math.PI
                    if (bWv < 0) bWv += 360; if (bWb < 0) bWb += 360
                    editor.addPrimitiv({typ:"bogen",x1:bcx,y1:bcy,radius:bRad2,winkel_von:bWv,winkel_bis:bWb,bogen_gegen_uhrzeiger:false,linienart:editor.aktLinienart})
                    editor.werkzeugPunkte = []
                }
                break

            case "punkt":
                // Feste absolute Größe statt relativ zu breiteMm (vorher 0.04
                // normiert -> 0,64mm bei 16mm-Symbol, aber 4,16mm bei einem
                // 104mm-Symbol wie Arduino Mega) - radius bleibt im Schema
                // relativ zu breite_mm gespeichert (Konvention aller Renderer),
                // daher hier umgekehrt aus der gewünschten mm-Größe berechnet.
                editor.addPrimitiv({typ:"kreis_gefuellt",x1:nx,y1:ny,radius:editor._punktRadiusMm/editor.breiteMm,linienart:"solid"})
                break

            case "text":
                editor.textEingabeOeffnen(nx, ny)
                break

            case "pin":
                editor.addPin(nx, ny)
                break
            }
        }
    }
}
