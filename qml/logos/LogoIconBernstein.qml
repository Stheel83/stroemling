import QtQuick
import "LogoBase.js" as Base

Canvas {
    width: 52; height: 52
    property color iconBg: "#0d1b2a"
    onIconBgChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        var cx = width/2, cy = height/2
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = iconBg; ctx.fillRect(0, 0, width, height)

        // Bernstein-Körper: kleines, kantiges unregelmäßiges Polygon (Fossil-Stein)
        var pts = [
            [cx,    cy-16], // oben
            [cx+10, cy-11], // oben rechts
            [cx+13, cy-2],  // rechts oben
            [cx+11, cy+8],  // rechts
            [cx+5,  cy+14], // unten rechts
            [cx-4,  cy+15], // unten
            [cx-11, cy+9],  // unten links
            [cx-13, cy+1],  // links
            [cx-10, cy-10]  // oben links
        ]

        // Hinterleuchten
        ctx.save()
        ctx.globalAlpha = 0.12
        ctx.beginPath(); ctx.arc(cx, cy, 20, 0, Math.PI*2)
        ctx.fillStyle = "#c06010"; ctx.fill()
        ctx.restore()

        // Körper (gefüllt)
        ctx.beginPath()
        ctx.moveTo(pts[0][0], pts[0][1])
        for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1])
        ctx.closePath()
        var grad = ctx.createRadialGradient(cx-3, cy-5, 1, cx, cy, 16)
        grad.addColorStop(0, "#fff0a0")
        grad.addColorStop(0.35, "#f0b030")
        grad.addColorStop(0.7, "#c06010")
        grad.addColorStop(1, "#7a3000")
        ctx.fillStyle = grad; ctx.globalAlpha = 0.92; ctx.fill()
        ctx.globalAlpha = 0.45
        ctx.strokeStyle = "#f0b030"; ctx.lineWidth = 0.8; ctx.stroke()

        // Glanz-Facette
        ctx.save()
        ctx.globalAlpha = 0.35
        ctx.beginPath()
        ctx.moveTo(pts[0][0], pts[0][1])
        ctx.lineTo(pts[1][0], pts[1][1])
        ctx.lineTo(cx+2, cy-4)
        ctx.closePath()
        ctx.fillStyle = "#fff8c0"; ctx.fill()
        ctx.restore()

        // 2 Orbits (gestrichelt)
        ctx.save()
        ctx.setLineDash([2.5, 2])
        Base.ellipse(ctx, cx, cy, 24, 6, -15 * Math.PI/180)
        ctx.globalAlpha = 0.35; ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 0.8; ctx.stroke()
        Base.ellipse(ctx, cx, cy, 24, 6, 55 * Math.PI/180)
        ctx.stroke()
        ctx.restore()

        Base.elektron(ctx, 47, 19, 4)
        Base.elektron(ctx, 5,  36, 4)
    }
}
