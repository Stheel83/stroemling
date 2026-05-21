import QtQuick
import "LogoFischBase.js" as Base

Canvas {
    width: 52; height: 52
    onPaint: {
        Base.drawFisch(getContext("2d"), width, height, function(ctx, cx) {
            // Widerstand DIN: Rechteck zwischen Flossen-Spitzen
            var y = 34, lx = cx-14, rx = cx+14
            var bx = cx-7, bw = 14, bh = 7
            ctx.lineWidth = 1.5; ctx.strokeStyle = "#3ecfcf"
            // Draht links
            ctx.beginPath(); ctx.moveTo(lx, y); ctx.lineTo(bx, y); ctx.stroke()
            // Rechteck (DIN-Widerstand)
            ctx.beginPath()
            ctx.rect(bx, y - bh/2, bw, bh)
            ctx.stroke()
            // Draht rechts
            ctx.beginPath(); ctx.moveTo(bx+bw, y); ctx.lineTo(rx, y); ctx.stroke()
        })
    }
}
