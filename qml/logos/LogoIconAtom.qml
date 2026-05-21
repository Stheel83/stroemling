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

        // 3 Orbits (Ellipsen via parametrische Punkte)
        var orbits = [-15, 45, -75]
        orbits.forEach(function(deg) {
            ctx.save()
            Base.ellipse(ctx, cx, cy, 23, 7, deg * Math.PI / 180)
            ctx.globalAlpha = 0.6
            ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.3
            ctx.stroke()
            ctx.restore()
        })

        // Kern (teal Kreis mit Kreuz)
        ctx.save()
        ctx.beginPath(); ctx.arc(cx, cy, 5, 0, Math.PI*2)
        ctx.fillStyle = "#3ecfcf"; ctx.globalAlpha = 0.9; ctx.fill()
        ctx.strokeStyle = "#0d1b2a"; ctx.lineWidth = 1.8; ctx.lineCap = "round"
        ctx.globalAlpha = 1
        ctx.beginPath(); ctx.moveTo(cx-2.5, cy); ctx.lineTo(cx+2.5, cy); ctx.stroke()
        ctx.beginPath(); ctx.moveTo(cx, cy-2.5); ctx.lineTo(cx, cy+2.5); ctx.stroke()
        ctx.restore()

        // 3 Elektronen an den Orbit-Enden
        Base.elektron(ctx, 46, 21, 4)
        Base.elektron(ctx, 9,  38, 4)
        Base.elektron(ctx, 15,  7, 4)
    }
}
