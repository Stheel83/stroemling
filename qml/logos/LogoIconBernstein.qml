import QtQuick

Canvas {
    id: root
    width: 52; height: 52
    onPaint: {
        var ctx = getContext("2d")
        var w = width, h = height, cx = w/2, cy = h/2
        ctx.clearRect(0, 0, w, h)

        ctx.fillStyle = "#0f1923"; ctx.fillRect(0, 0, w, h)

        // Bernstein-Körper (unregelmäßige Tropfenform)
        ctx.save()
        ctx.globalAlpha = 0.15
        ctx.beginPath(); ctx.arc(cx, cy, 22, 0, Math.PI*2)
        ctx.fillStyle = "#c06010"; ctx.fill()
        ctx.restore()

        ctx.beginPath()
        ctx.moveTo(cx, 4)
        ctx.bezierCurveTo(cx+14, 3, cx+22, 10, cx+22, cx)
        ctx.bezierCurveTo(cx+22, cy+16, cx+12, cy+22, cx, cy+22)
        ctx.bezierCurveTo(cx-14, cy+22, cx-22, cy+12, cx-22, cy)
        ctx.bezierCurveTo(cx-22, cy-14, cx-12, 3, cx, 4)
        var grad = ctx.createRadialGradient(cx-4, cy-6, 2, cx, cy, 22)
        grad.addColorStop(0, "#fff0a0")
        grad.addColorStop(0.3, "#f0b030")
        grad.addColorStop(0.7, "#c06010")
        grad.addColorStop(1, "#7a3000")
        ctx.fillStyle = grad; ctx.globalAlpha = 0.92; ctx.fill()
        ctx.globalAlpha = 0.4
        ctx.strokeStyle = "#f0b030"; ctx.lineWidth = 0.8; ctx.stroke()

        // Glanz
        ctx.save()
        ctx.globalAlpha = 0.4
        ctx.beginPath()
        ctx.moveTo(cx-5, 8); ctx.bezierCurveTo(cx+5, 5, cx+16, 12, cx+18, 20)
        ctx.bezierCurveTo(cx+8, 10, cx-2, 6, cx-8, 10)
        ctx.closePath()
        ctx.fillStyle = "#fff8c0"; ctx.fill()
        ctx.restore()

        // Orbits
        function orbit(angle) {
            ctx.save()
            ctx.translate(cx, cy); ctx.rotate(angle * Math.PI/180)
            ctx.globalAlpha = 0.4; ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 0.8
            ctx.setLineDash([3, 2])
            ctx.beginPath(); ctx.ellipse(0, 0, 26, 7, 0, 0, Math.PI*2); ctx.stroke()
            ctx.restore()
        }
        orbit(-15); orbit(55)

        // Elektronen
        function elektron(ex, ey) {
            ctx.save()
            ctx.beginPath(); ctx.arc(ex, ey, 4, 0, Math.PI*2)
            var eg = ctx.createRadialGradient(ex-1, ey-1, 0.5, ex, ey, 4)
            eg.addColorStop(0, "#ffffff"); eg.addColorStop(1, "#f0b030")
            ctx.fillStyle = eg; ctx.globalAlpha = 1; ctx.fill()
            ctx.globalAlpha = 0.8
            ctx.beginPath(); ctx.arc(ex+1.5, ey-1.5, 1.5, 0, Math.PI*2)
            ctx.fillStyle = "#ffffff"; ctx.fill()
            ctx.restore()
        }
        elektron(46, 18); elektron(4, 36)
    }
}
