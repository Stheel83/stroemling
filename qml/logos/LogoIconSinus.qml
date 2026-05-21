import QtQuick
import "LogoBase.js" as Base

Canvas {
    width: 52; height: 52
    property color iconBg: "#0d1b2a"
    onIconBgChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = iconBg; ctx.fillRect(0, 0, width, height)

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

        Base.elektron(ctx, 22, 7, 5)
        Base.elektron(ctx, 40, 26, 5)
    }
}
