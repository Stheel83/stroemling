import QtQuick
import "LogoFischBase.js" as Base

Canvas {
    width: 52; height: 52
    property color iconBg: "#0d1b2a"
    onIconBgChanged: requestPaint()
    onPaint: {
        Base.drawFisch(getContext("2d"), width, height, iconBg, function(ctx, sx, sy) {
            // Spule: sx≈38, 2 Halbkreis-Bögen r=3 → sx bis sx+12
            ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.5
            ctx.beginPath(); ctx.arc(sx+3,  sy, 3, Math.PI, 0); ctx.stroke()
            ctx.beginPath(); ctx.arc(sx+9,  sy, 3, Math.PI, 0); ctx.stroke()
        })
    }
}
