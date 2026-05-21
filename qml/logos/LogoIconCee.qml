import QtQuick

Canvas {
    id: root
    width: 52; height: 52
    onPaint: {
        var ctx = getContext("2d")
        var w = width, h = height, cx = w/2, cy = h/2
        ctx.clearRect(0, 0, w, h)

        ctx.fillStyle = "#0f1923"; ctx.fillRect(0, 0, w, h)

        // Montagering
        ctx.globalAlpha = 0.2; ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 0.8
        ctx.beginPath(); ctx.arc(cx, cy, 24, 0, Math.PI*2); ctx.stroke()

        // Montageschrauben (5 Stück)
        var screws = [
            [cx, cy-24], [cx+20, cy-12], [cx+20, cy+12],
            [cx, cy+24], [cx-20, cy]
        ]
        ctx.globalAlpha = 0.35
        screws.forEach(function(s) {
            ctx.beginPath(); ctx.arc(s[0], s[1], 2, 0, Math.PI*2); ctx.stroke()
        })

        // Gehäuse
        ctx.globalAlpha = 0.95
        var hg = ctx.createRadialGradient(cx-4, cy-4, 2, cx, cy, 22)
        hg.addColorStop(0, "#2a3a4a"); hg.addColorStop(1, "#161e28")
        ctx.beginPath(); ctx.arc(cx, cy, 20, 0, Math.PI*2)
        ctx.fillStyle = hg; ctx.fill()
        ctx.strokeStyle = "#3ecfcf"; ctx.lineWidth = 1.2; ctx.globalAlpha = 0.55; ctx.stroke()

        // Führungsring
        ctx.globalAlpha = 0.25; ctx.lineWidth = 0.6
        ctx.beginPath(); ctx.arc(cx, cy, 13, 0, Math.PI*2); ctx.stroke()

        // Codierungsnut oben
        ctx.globalAlpha = 0.65; ctx.lineWidth = 2; ctx.lineCap = "round"
        ctx.beginPath()
        ctx.moveTo(cx-4, cy-19); ctx.quadraticCurveTo(cx, cy-22, cx+4, cy-19); ctx.stroke()

        // 5 Pins gleichmäßig auf r=9, je 72°, Start -90°
        var pins = ["L1","L2","N","PE","L3"]
        var r = 9
        ctx.globalAlpha = 1; ctx.lineWidth = 1
        pins.forEach(function(label, i) {
            var angle = (-90 + i * 72) * Math.PI / 180
            var px = cx + r * Math.cos(angle)
            var py = cy + r * Math.sin(angle)
            ctx.beginPath(); ctx.ellipse(px, py, 3.5, 3.5, 0, 0, Math.PI*2)
            ctx.fillStyle = "#1a2a3a"; ctx.fill()
            ctx.strokeStyle = "#d0d8e0"; ctx.stroke()
            ctx.fillStyle = "#8090a0"; ctx.font = "3.5px monospace"
            ctx.textAlign = "center"; ctx.textBaseline = "middle"
            ctx.fillText(label, px, py)
        })

        // Mitte-Label
        ctx.globalAlpha = 0.4; ctx.fillStyle = "#3ecfcf"
        ctx.font = "5px 'Courier New'"
        ctx.textAlign = "center"; ctx.textBaseline = "middle"
        ctx.fillText("CEE", cx, cy-1)
        ctx.globalAlpha = 0.25; ctx.font = "3.5px 'Courier New'"
        ctx.fillText("400V", cx, cy+5)
    }
}
