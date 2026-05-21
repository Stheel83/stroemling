// Hilfsfunktionen für alle Logo-Canvas-Icons

// Ellipse via parametrische Punkte (Qt Canvas unterstützt ctx.ellipse() nicht zuverlässig)
function ellipse(ctx, cx, cy, rx, ry, rotationRad) {
    ctx.save()
    ctx.translate(cx, cy)
    if (rotationRad) ctx.rotate(rotationRad)
    ctx.beginPath()
    var steps = 40
    for (var i = 0; i <= steps; i++) {
        var t = (i / steps) * Math.PI * 2
        var x = rx * Math.cos(t)
        var y = ry * Math.sin(t)
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
    }
    ctx.closePath()
    ctx.restore()
}

// Elektron-Kugel (teal mit weißem Glanzpunkt)
function elektron(ctx, ex, ey, r) {
    r = r || 5
    ctx.save()
    ctx.globalAlpha = 0.15
    ctx.beginPath(); ctx.arc(ex, ey, r + 3, 0, Math.PI*2)
    ctx.fillStyle = "#3ecfcf"; ctx.fill()
    ctx.globalAlpha = 1
    ctx.beginPath(); ctx.arc(ex, ey, r, 0, Math.PI*2)
    ctx.fillStyle = "#3ecfcf"; ctx.fill()
    ctx.globalAlpha = 0.4
    ctx.beginPath(); ctx.arc(ex, ey, r, 0, Math.PI*2)
    ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 0.6; ctx.stroke()
    ctx.globalAlpha = 0.85
    ctx.beginPath(); ctx.arc(ex + r*0.4, ey - r*0.4, r*0.35, 0, Math.PI*2)
    ctx.fillStyle = "#ffffff"; ctx.fill()
    ctx.restore()
}
