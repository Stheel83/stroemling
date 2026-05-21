import QtQuick
import "LogoFischBase.js" as Base

Canvas {
    width: 52; height: 52
    property color iconBg: "#0d1b2a"
    onIconBgChanged: requestPaint()
    onPaint: {
        Base.drawFisch(getContext("2d"), width, height, iconBg, function(ctx, sx, sy) {
            // Kondensator: sx≈38, Draht→Platte──Platte→Rand
            ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.5
            var p1 = sx+4, p2 = sx+7
            ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(p1, sy); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(p1, sy-5); ctx.lineTo(p1, sy+5); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(p2, sy-5); ctx.lineTo(p2, sy+5); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(p2, sy); ctx.lineTo(sx+11, sy); ctx.stroke()
        })
    }
}
