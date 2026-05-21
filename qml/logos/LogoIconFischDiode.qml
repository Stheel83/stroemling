import QtQuick
import "LogoFischBase.js" as Base

Canvas {
    width: 52; height: 52
    property color iconBg: "#0d1b2a"
    onIconBgChanged: requestPaint()
    onPaint: {
        Base.drawFisch(getContext("2d"), width, height, iconBg, function(ctx, sx, sy) {
            // Diode DIN: Dreieck Spitze rechts + Sperrschicht; sx≈38
            ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.5
            ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(sx+2, sy); ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(sx+2, sy-5)
            ctx.lineTo(sx+9, sy)
            ctx.lineTo(sx+2, sy+5)
            ctx.closePath()
            ctx.stroke()
            ctx.beginPath(); ctx.moveTo(sx+9, sy-5); ctx.lineTo(sx+9, sy+5); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(sx+9, sy); ctx.lineTo(sx+12, sy); ctx.stroke()
        })
    }
}
