import QtQuick

Canvas {
    id: root
    width: 52; height: 52
    onPaint: {
        var ctx = getContext("2d")
        var w = width, h = height
        ctx.clearRect(0, 0, w, h)

        // Himmel
        ctx.fillStyle = "#0d1e2e"; ctx.fillRect(0, 0, w, h)

        // Wasser
        var wg = ctx.createLinearGradient(0, 38, 0, h)
        wg.addColorStop(0, "#1a6a7a"); wg.addColorStop(1, "#0a2a3a")
        ctx.fillStyle = wg; ctx.globalAlpha = 0.8
        ctx.fillRect(0, 38, w, h-38)

        // Horizont-Leuchten
        ctx.save()
        ctx.globalAlpha = 0.3
        ctx.beginPath(); ctx.ellipse(26, 38, 22, 5, 0, 0, Math.PI*2)
        ctx.fillStyle = "#1a5a6a"; ctx.fill()
        ctx.restore()

        // Wellen
        function welle(y, alpha, lw) {
            ctx.save(); ctx.globalAlpha = alpha; ctx.lineWidth = lw
            ctx.strokeStyle = "#3ecfcf"; ctx.lineCap = "round"
            ctx.beginPath()
            ctx.moveTo(4, y)
            ctx.bezierCurveTo(10, y-3, 16, y+3, 22, y)
            ctx.bezierCurveTo(28, y-3, 34, y+3, 40, y)
            ctx.bezierCurveTo(44, y-2, 48, y, 50, y)
            ctx.stroke()
            ctx.restore()
        }
        welle(42, 0.9, 1.5); welle(46, 0.6, 1.1); welle(49, 0.3, 0.8)

        // Blitz Glow
        ctx.save(); ctx.globalAlpha = 0.2
        ctx.beginPath()
        ctx.moveTo(28, 6); ctx.lineTo(22, 24); ctx.lineTo(27, 24)
        ctx.lineTo(20, 36); ctx.lineTo(34, 18); ctx.lineTo(29, 18); ctx.lineTo(34, 6)
        ctx.closePath()
        ctx.fillStyle = "#3ecfcf"; ctx.fill()
        ctx.restore()

        // Blitz Hauptform
        ctx.save()
        var bg = ctx.createLinearGradient(26, 6, 26, 36)
        bg.addColorStop(0, "#ffffff"); bg.addColorStop(1, "#3ecfcf")
        ctx.beginPath()
        ctx.moveTo(28, 6); ctx.lineTo(22, 24); ctx.lineTo(27, 24)
        ctx.lineTo(20, 36); ctx.lineTo(34, 18); ctx.lineTo(29, 18); ctx.lineTo(34, 6)
        ctx.closePath()
        ctx.fillStyle = bg; ctx.globalAlpha = 0.95; ctx.fill()

        // Glanzlinie
        ctx.globalAlpha = 0.5; ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1
        ctx.lineCap = "round"
        ctx.beginPath(); ctx.moveTo(31, 9); ctx.lineTo(26, 20); ctx.stroke()
        ctx.restore()
    }
}
