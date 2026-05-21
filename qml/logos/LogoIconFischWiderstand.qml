import QtQuick
import "LogoFischBase.js" as Base

Canvas {
    width: 52; height: 52
    property color iconBg: "#0d1b2a"
    onIconBgChanged: requestPaint()
    onPaint: {
        Base.drawFisch(getContext("2d"), width, height, iconBg, function(ctx, sx, sy) {
            // Widerstand DIN: Rechteck sx+2 … sx+10, Drähte links/rechts
            ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.5
            ctx.beginPath(); ctx.moveTo(sx, sy);    ctx.lineTo(sx+2, sy); ctx.stroke()
            ctx.beginPath(); ctx.rect(sx+2, sy-3, 8, 6); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(sx+10, sy); ctx.lineTo(sx+12, sy); ctx.stroke()
        })
    }
}
