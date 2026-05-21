import QtQuick
import "LogoFischBase.js" as Base

Canvas {
    width: 52; height: 52
    onPaint: {
        Base.drawFisch(getContext("2d"), width, height, function(ctx, cx) {
            // Kondensator: zwei senkrechte Platten, gehalten zwischen den Flossen-Spitzen
            // Arme enden ca. bei (cx-14, 34) und (cx+14, 34)
            var y = 34, lx = cx-14, rx = cx+14
            var pl = cx-4, pr = cx+4  // Platten-X
            ctx.lineWidth = 1.5; ctx.strokeStyle = "#3ecfcf"
            // Draht links → linke Platte
            ctx.beginPath(); ctx.moveTo(lx, y); ctx.lineTo(pl, y); ctx.stroke()
            // Linke Platte (senkrecht)
            ctx.beginPath(); ctx.moveTo(pl, y-5); ctx.lineTo(pl, y+5); ctx.stroke()
            // Rechte Platte
            ctx.beginPath(); ctx.moveTo(pr, y-5); ctx.lineTo(pr, y+5); ctx.stroke()
            // Draht rechte Platte → rechter Arm
            ctx.beginPath(); ctx.moveTo(pr, y); ctx.lineTo(rx, y); ctx.stroke()
        })
    }
}
