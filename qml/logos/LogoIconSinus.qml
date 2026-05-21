import QtQuick

Canvas {
    id: root
    width: 52; height: 52
    onPaint: {
        var ctx = getContext("2d")
        var w = width, h = height
        ctx.clearRect(0, 0, w, h)

        // Hintergrund
        ctx.fillStyle = "#0f1923"
        ctx.fillRect(0, 0, w, h)

        // Nulllinie gestrichelt
        ctx.save()
        ctx.setLineDash([1.5, 3])
        ctx.strokeStyle = "#3ecfcf"; ctx.globalAlpha = 0.2; ctx.lineWidth = 0.6
        ctx.beginPath(); ctx.moveTo(4, 26); ctx.lineTo(48, 26); ctx.stroke()
        ctx.restore()

        // Welle Glow
        ctx.save()
        ctx.strokeStyle = "#3ecfcf"; ctx.globalAlpha = 0.1; ctx.lineWidth = 7
        ctx.beginPath()
        ctx.moveTo(4, 26)
        ctx.bezierCurveTo(10, 26, 15, 7, 22, 7)
        ctx.bezierCurveTo(29, 7, 34, 26, 40, 26)
        ctx.lineTo(48, 26)
        ctx.stroke()
        ctx.restore()

        // Welle
        ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 2; ctx.globalAlpha = 1
        ctx.beginPath()
        ctx.moveTo(4, 26)
        ctx.bezierCurveTo(10, 26, 15, 7, 22, 7)
        ctx.bezierCurveTo(29, 7, 34, 26, 40, 26)
        ctx.lineTo(48, 26)
        ctx.stroke()

        // Hilfsfunktion Elektron
        function elektron(ex, ey) {
            ctx.save()
            ctx.globalAlpha = 0.15
            ctx.beginPath(); ctx.arc(ex, ey, 8, 0, Math.PI*2)
            ctx.fillStyle = "#3ecfcf"; ctx.fill()
            ctx.globalAlpha = 1
            ctx.beginPath(); ctx.arc(ex, ey, 5, 0, Math.PI*2)
            ctx.fillStyle = "#3ecfcf"; ctx.fill()
            ctx.globalAlpha = 0.4
            ctx.beginPath(); ctx.arc(ex, ey, 5, 0, Math.PI*2)
            ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 0.6; ctx.stroke()
            ctx.globalAlpha = 0.85
            ctx.beginPath(); ctx.arc(ex+2, ey-2, 1.8, 0, Math.PI*2)
            ctx.fillStyle = "#ffffff"; ctx.fill()
            ctx.restore()
        }

        elektron(22, 7)
        elektron(40, 26)
    }
}
