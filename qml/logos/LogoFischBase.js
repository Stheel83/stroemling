// Fisch-Icon: Körper links (fx=13), rechter Arm zeigt nach rechts, Symbol an Arm-Spitze (~x=38)
// drawSymbol(ctx, sx, sy): Callback mit Arm-Spitzen-Koordinate

function drawFisch(ctx, w, h, bg, drawSymbol) {
    var fx = 13

    ctx.clearRect(0, 0, w, h)
    ctx.fillStyle = bg || "#0f1923"
    ctx.fillRect(0, 0, w, h)

    ctx.strokeStyle = "#3ecfcf"
    ctx.lineWidth = 1.5
    ctx.lineCap = "round"
    ctx.lineJoin = "round"

    // Körper (aufrechtes Oval: Breite 9, Höhe 14 via scale+arc)
    ctx.save()
    ctx.translate(fx, 27)
    ctx.scale(1, 14/9)
    ctx.beginPath()
    ctx.arc(0, 0, 9, 0, Math.PI*2)
    ctx.restore()
    ctx.stroke()

    // Kopf
    ctx.beginPath()
    ctx.arc(fx, 12, 8, 0, Math.PI*2)
    ctx.stroke()

    // Rückenflosse
    ctx.beginPath()
    ctx.moveTo(fx+7, 16)
    ctx.bezierCurveTo(fx+13, 10, fx+11, 5, fx+8, 8)
    ctx.stroke()

    // Schwanzflosse (V unten)
    ctx.beginPath()
    ctx.moveTo(fx, 41)
    ctx.lineTo(fx-9, 51)
    ctx.moveTo(fx, 41)
    ctx.lineTo(fx+9, 51)
    ctx.stroke()

    // Linke Brustflosse (dekorativ)
    ctx.beginPath()
    ctx.moveTo(fx-9, 28)
    ctx.bezierCurveTo(fx-14, 25, fx-15, 31, fx-11, 34)
    ctx.stroke()

    // Rechte Brustflosse / Arm → nach rechts zum Symbol
    ctx.beginPath()
    ctx.moveTo(fx+9, 26)
    ctx.bezierCurveTo(fx+16, 22, fx+26, 24, fx+25, 27)
    ctx.stroke()

    // Auge
    ctx.beginPath()
    ctx.arc(fx+3, 10, 2.5, 0, Math.PI*2)
    ctx.fillStyle = "#3ecfcf"; ctx.fill()
    ctx.globalAlpha = 0.8
    ctx.beginPath(); ctx.arc(fx+4, 9, 1, 0, Math.PI*2)
    ctx.fillStyle = "#ffffff"; ctx.fill()
    ctx.globalAlpha = 1

    // Mund (kleiner Bogen)
    ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.5
    ctx.beginPath()
    ctx.arc(fx+6, 14, 2, 0.1, 1.1)
    ctx.stroke()

    // Symbol zeichnen an Arm-Spitze
    drawSymbol(ctx, fx+25, 27)
}
