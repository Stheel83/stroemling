// Gemeinsame Zeichenroutine Fisch-Icon (52×52)
// ctx: Canvas 2D-Kontext, w/h: Breite/Höhe
// drawSymbol(ctx): Callback der das gehaltene Symbol zeichnet

function drawFisch(ctx, w, h, drawSymbol) {
    var cx = w / 2  // 26
    ctx.clearRect(0, 0, w, h)

    // Hintergrund
    ctx.fillStyle = "#0f1923"; ctx.fillRect(0, 0, w, h)

    ctx.strokeStyle = "#3ecfcf"
    ctx.lineWidth   = 1.5
    ctx.lineCap     = "round"
    ctx.lineJoin    = "round"

    // Körper (aufrechtes Oval)
    ctx.beginPath()
    ctx.ellipse(cx, 27, 9, 14, 0, 0, Math.PI*2)
    ctx.stroke()

    // Kopf (Kreis, überlappt Körper oben)
    ctx.beginPath()
    ctx.arc(cx, 12, 8, 0, Math.PI*2)
    ctx.stroke()

    // Rückenflosse (oben rechts, kleine Dreieckform)
    ctx.beginPath()
    ctx.moveTo(cx+7, 16)
    ctx.bezierCurveTo(cx+13, 10, cx+11, 5, cx+8, 8)
    ctx.stroke()

    // Schwanzflosse (V unten)
    ctx.beginPath()
    ctx.moveTo(cx, 41)
    ctx.lineTo(cx-11, 51)
    ctx.moveTo(cx, 41)
    ctx.lineTo(cx+11, 51)
    ctx.stroke()

    // Linke Brustflosse (Arm)
    ctx.beginPath()
    ctx.moveTo(cx-9, 26)
    ctx.bezierCurveTo(cx-17, 22, cx-20, 29, cx-14, 34)
    ctx.stroke()

    // Rechte Brustflosse (Arm)
    ctx.beginPath()
    ctx.moveTo(cx+9, 26)
    ctx.bezierCurveTo(cx+17, 22, cx+20, 29, cx+14, 34)
    ctx.stroke()

    // Auge (gefüllt)
    ctx.beginPath()
    ctx.arc(cx+3, 10, 2.5, 0, Math.PI*2)
    ctx.fillStyle = "#3ecfcf"; ctx.fill()
    ctx.globalAlpha = 0.8
    ctx.beginPath(); ctx.arc(cx+4, 9, 1, 0, Math.PI*2)
    ctx.fillStyle = "#ffffff"; ctx.fill()
    ctx.globalAlpha = 1

    // Mund (kleiner Bogen)
    ctx.beginPath()
    ctx.arc(cx+6, 14, 2, 0.1, 1.1)
    ctx.stroke()

    // Gehaltenes Symbol zeichnen
    drawSymbol(ctx, cx)
}
