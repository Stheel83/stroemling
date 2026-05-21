import QtQuick
import "LogoFischBase.js" as Base

Canvas {
    width: 52; height: 52
    onPaint: {
        Base.drawFisch(getContext("2d"), width, height, function(ctx, cx) {
            // Spule (Induktivität): 3 Halbkreis-Bögen zwischen Flossen-Spitzen
            var y = 34, lx = cx-14, rx = cx+14
            ctx.lineWidth = 1.5; ctx.strokeStyle = "#3ecfcf"
            // Draht links
            ctx.beginPath(); ctx.moveTo(lx, y); ctx.lineTo(cx-10, y); ctx.stroke()
            // 3 Bögen: Radius 3.5, Mittelpunkte bei cx-6.5, cx, cx+6.5
            ctx.beginPath()
            ctx.arc(cx-7, y, 3.5, Math.PI, 0)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(cx, y, 3.5, Math.PI, 0)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(cx+7, y, 3.5, Math.PI, 0)
            ctx.stroke()
            // Draht rechts
            ctx.beginPath(); ctx.moveTo(cx+10, y); ctx.lineTo(rx, y); ctx.stroke()
        })
    }
}
