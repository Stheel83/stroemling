import QtQuick

Canvas {
    width: 52; height: 52
    property color iconBg: "#0d1e2e"
    onIconBgChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = iconBg; ctx.fillRect(0, 0, width, height)

        // Wasser
        var wg = ctx.createLinearGradient(0, 36, 0, 52)
        wg.addColorStop(0, "#1a6a7a"); wg.addColorStop(1, "#0a2a3a")
        ctx.fillStyle = wg; ctx.globalAlpha = 0.8
        ctx.fillRect(0, 36, 52, 16)

        // Horizont-Leuchten
        ctx.save(); ctx.globalAlpha = 0.25
        ctx.beginPath(); ctx.arc(26, 36, 18, Math.PI, 0)
        ctx.fillStyle = "#1a5a6a"; ctx.fill()
        ctx.restore()

        // Wellen
        function welle(y, alpha, lw) {
            ctx.save(); ctx.globalAlpha = alpha; ctx.lineWidth = lw
            ctx.strokeStyle = "#3ecfcf"; ctx.lineCap = "round"
            ctx.beginPath()
            ctx.moveTo(4, y)
            ctx.bezierCurveTo(10, y-3, 16, y+2, 22, y)
            ctx.bezierCurveTo(28, y-2, 34, y+3, 40, y)
            ctx.bezierCurveTo(44, y-1, 48, y, 50, y)
            ctx.stroke(); ctx.restore()
        }
        welle(40, 0.9, 1.4); welle(44, 0.6, 1.0); welle(48, 0.3, 0.7)

        // Blitz Glow
        ctx.save(); ctx.globalAlpha = 0.2
        ctx.beginPath()
        ctx.moveTo(28, 5); ctx.lineTo(21, 23); ctx.lineTo(27, 23)
        ctx.lineTo(19, 35); ctx.lineTo(34, 17); ctx.lineTo(28, 17); ctx.lineTo(33, 5)
        ctx.closePath()
        ctx.fillStyle = "#3ecfcf"; ctx.fill(); ctx.restore()

        // Blitz
        ctx.save()
        var bg = ctx.createLinearGradient(26, 5, 26, 35)
        bg.addColorStop(0, "#ffffff"); bg.addColorStop(1, "#3ecfcf")
        ctx.beginPath()
        ctx.moveTo(28, 5); ctx.lineTo(21, 23); ctx.lineTo(27, 23)
        ctx.lineTo(19, 35); ctx.lineTo(34, 17); ctx.lineTo(28, 17); ctx.lineTo(33, 5)
        ctx.closePath()
        ctx.fillStyle = bg; ctx.globalAlpha = 0.95; ctx.fill()
        ctx.globalAlpha = 0.5; ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 1; ctx.lineCap = "round"
        ctx.beginPath(); ctx.moveTo(30, 8); ctx.lineTo(25, 19); ctx.stroke()
        ctx.restore()
    }
}
