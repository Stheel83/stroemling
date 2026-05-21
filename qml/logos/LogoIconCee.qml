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

        // Montagering
        ctx.globalAlpha = 0.2; ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 0.8
        ctx.beginPath(); ctx.arc(cx, cy, 24, 0, Math.PI*2); ctx.stroke()

        // Montageschrauben
        var screwPos = [0, 72, 144, 216, 288]
        ctx.globalAlpha = 0.35
        screwPos.forEach(function(deg) {
            var a = (deg-90) * Math.PI/180
            ctx.beginPath(); ctx.arc(cx+24*Math.cos(a), cy+24*Math.sin(a), 2, 0, Math.PI*2); ctx.stroke()
        })

        // Gehäuse (Füllung)
        var hg = ctx.createRadialGradient(cx-4, cy-4, 2, cx, cy, 20)
        hg.addColorStop(0, "#2a3a4a"); hg.addColorStop(1, "#161e28")
        ctx.beginPath(); ctx.arc(cx, cy, 20, 0, Math.PI*2)
        ctx.fillStyle = hg; ctx.globalAlpha = 0.95; ctx.fill()
        ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.2; ctx.globalAlpha = 0.55; ctx.stroke()

        // Führungsring
        ctx.globalAlpha = 0.25; ctx.lineWidth = 0.6
        ctx.beginPath(); ctx.arc(cx, cy, 13, 0, Math.PI*2); ctx.stroke()

        // Codierungsnut oben
        ctx.globalAlpha = 0.65; ctx.lineWidth = 2; ctx.lineCap = "round"
        ctx.beginPath()
        ctx.moveTo(cx-4, cy-19); ctx.quadraticCurveTo(cx, cy-22, cx+4, cy-19); ctx.stroke()

        // 5 Pins gleichmäßig r=9, je 72°
        var labels = ["L1","L2","N","PE","L3"]
        ctx.globalAlpha = 1; ctx.lineWidth = 1
        labels.forEach(function(lbl, i) {
            var a = (-90 + i * 72) * Math.PI / 180
            var px = cx + 9 * Math.cos(a), py = cy + 9 * Math.sin(a)
            ctx.beginPath(); ctx.arc(px, py, 3.5, 0, Math.PI*2)
            ctx.fillStyle = "#1a2a3a"; ctx.fill()
            ctx.strokeStyle = "#d0d8e0"; ctx.stroke()
            ctx.fillStyle = "#8090a0"; ctx.font = "3.5px monospace"
            ctx.textAlign = "center"; ctx.textBaseline = "middle"
            ctx.fillText(lbl, px, py)
        })

        // Mitte-Label
        ctx.globalAlpha = 0.4; ctx.fillStyle = "#3ecfcf"
        ctx.font = "5px 'Courier New'"; ctx.textAlign = "center"; ctx.textBaseline = "middle"
        ctx.fillText("CEE", cx, cy-1)
        ctx.globalAlpha = 0.25; ctx.font = "3.5px 'Courier New'"
        ctx.fillText("400V", cx, cy+5)
    }
}
