import QtQuick
import "LogoFischBase.js" as Base

Canvas {
    width: 52; height: 52
    onPaint: {
        Base.drawFisch(getContext("2d"), width, height, function(ctx, cx) {
            // Diode DIN: Dreieck (Spitze rechts) + Sperrschicht-Strich
            var y = 34, lx = cx-14, rx = cx+14
            var tx = cx-6   // Dreieck linke Kante
            var tip = cx+4  // Dreieck Spitze (rechts)
            ctx.lineWidth = 1.5; ctx.strokeStyle = "#3ecfcf"
            // Draht links
            ctx.beginPath(); ctx.moveTo(lx, y); ctx.lineTo(tx, y); ctx.stroke()
            // Dreieck (Anode-Kathode-Symbol, DIN)
            ctx.beginPath()
            ctx.moveTo(tx, y-6)
            ctx.lineTo(tip, y)
            ctx.lineTo(tx, y+6)
            ctx.closePath()
            ctx.stroke()
            // Sperrschicht (senkrechter Strich an Spitze)
            ctx.beginPath(); ctx.moveTo(tip, y-6); ctx.lineTo(tip, y+6); ctx.stroke()
            // Draht rechts
            ctx.beginPath(); ctx.moveTo(tip, y); ctx.lineTo(rx, y); ctx.stroke()
        })
    }
}
