import QtQuick

Canvas {
    id: root
    width: 52; height: 52
    onPaint: {
        var ctx = getContext("2d")
        var w = width, h = height, cx = w/2, cy = h/2
        ctx.clearRect(0, 0, w, h)

        ctx.fillStyle = "#0f1923"; ctx.fillRect(0, 0, w, h)

        function orbit(angle) {
            ctx.save()
            ctx.translate(cx, cy)
            ctx.rotate(angle * Math.PI / 180)
            ctx.globalAlpha = 0.6; ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.2
            ctx.beginPath()
            ctx.ellipse(0, 0, 24, 7, 0, 0, Math.PI*2)
            ctx.stroke()
            ctx.restore()
        }
        orbit(-15); orbit(45); orbit(-75)

        // Kern
        ctx.save()
        ctx.globalAlpha = 0.5
        ctx.beginPath(); ctx.arc(cx, cy, 6, 0, Math.PI*2)
        ctx.fillStyle = "#3ecfcf"; ctx.fill()
        ctx.globalAlpha = 1
        ctx.beginPath(); ctx.arc(cx, cy, 4, 0, Math.PI*2)
        ctx.fillStyle = "#3ecfcf"; ctx.fill()
        // Kreuz im Kern
        ctx.strokeStyle = "#0f1923"; ctx.lineWidth = 1.5; ctx.lineCap = "round"
        ctx.beginPath(); ctx.moveTo(cx-2.5, cy); ctx.lineTo(cx+2.5, cy); ctx.stroke()
        ctx.beginPath(); ctx.moveTo(cx, cy-2.5); ctx.lineTo(cx, cy+2.5); ctx.stroke()
        ctx.restore()

        function elektron(ex, ey) {
            ctx.save()
            ctx.globalAlpha = 1
            ctx.beginPath(); ctx.arc(ex, ey, 4, 0, Math.PI*2)
            ctx.fillStyle = "#3ecfcf"; ctx.fill()
            ctx.globalAlpha = 0.85
            ctx.beginPath(); ctx.arc(ex+1.5, ey-1.5, 1.5, 0, Math.PI*2)
            ctx.fillStyle = "#ffffff"; ctx.fill()
            ctx.restore()
        }
        elektron(46, 20); elektron(10, 38); elektron(14, 7)
    }
}
