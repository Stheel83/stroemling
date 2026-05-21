import QtQuick

Item {
    id: root
    property var theme: null

    readonly property color _textPri: root.theme ? root.theme.textPrimary : "#e8f4f8"
    readonly property color _textMut: root.theme ? root.theme.textMuted   : "#8090a0"

    // Wangen-Pulsieren → Canvas neu zeichnen
    property real wangenGlow: 0.7
    onWangenGlowChanged: fishCanvas.requestPaint()

    SequentialAnimation on wangenGlow {
        running: root.visible
        loops:   Animation.Infinite
        NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
    }

    // Auf-ab-Schaukeln (ändert nur y – kein requestPaint nötig)
    property real bobOffset: 0
    SequentialAnimation on bobOffset {
        running: root.visible
        loops:   Animation.Infinite
        NumberAnimation { to:  8; duration: 950; easing.type: Easing.InOutSine }
        NumberAnimation { to: -8; duration: 950; easing.type: Easing.InOutSine }
    }

    // ── Pokeström-Fisch ──────────────────────────────────────────────────
    Canvas {
        id: fishCanvas
        width: 120; height: 120
        y: Math.max(6, root.height * 0.28 - 60) + root.bobOffset

        // Schwimmt von links nach rechts (endlos)
        NumberAnimation on x {
            running: root.visible
            from:    -fishCanvas.width
            to:      root.width
            duration: 11000
            loops:   Animation.Infinite
            easing.type: Easing.Linear
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = 58, cy = 62, br = 28   // Körper-Mittelpunkt und -Radius
            var wg = root.wangenGlow

            // Körper-Glühen
            var gl = ctx.createRadialGradient(cx, cy, 2, cx, cy, br+20)
            gl.addColorStop(0, "rgba(62,207,207,0.13)")
            gl.addColorStop(1, "rgba(62,207,207,0)")
            ctx.fillStyle = gl; ctx.fillRect(0, 0, width, height)

            // Schwanzflosse – oberer Lappen
            ctx.beginPath()
            ctx.moveTo(cx-br, cy)
            ctx.bezierCurveTo(cx-br-10, cy-16, cx-br-22, cy-34, cx-br-16, cy-46)
            ctx.bezierCurveTo(cx-br-8,  cy-28, cx-br-4,  cy-13, cx-br, cy)
            ctx.fillStyle = "#2aafaf"; ctx.fill()

            // Schwanzflosse – unterer Lappen
            ctx.beginPath()
            ctx.moveTo(cx-br, cy)
            ctx.bezierCurveTo(cx-br-10, cy+16, cx-br-22, cy+34, cx-br-16, cy+46)
            ctx.bezierCurveTo(cx-br-8,  cy+28, cx-br-4,  cy+13, cx-br, cy)
            ctx.fillStyle = "#2aafaf"; ctx.fill()

            // Körper
            ctx.beginPath()
            ctx.arc(cx, cy, br, 0, Math.PI*2)
            var bg = ctx.createRadialGradient(cx-6, cy-9, 3, cx, cy, br)
            bg.addColorStop(0,   "#afffff")
            bg.addColorStop(0.5, "#3ecfcf")
            bg.addColorStop(1,   "#1a8f8f")
            ctx.fillStyle = bg; ctx.fill()
            ctx.strokeStyle = "#1a7f7f"; ctx.lineWidth = 1.5; ctx.stroke()

            // Rückenflosse
            ctx.beginPath()
            ctx.moveTo(cx-8, cy-br)
            ctx.bezierCurveTo(cx-6, cy-br-18, cx+12, cy-br-18, cx+12, cy-br)
            ctx.closePath()
            ctx.fillStyle = "#2aafaf"; ctx.fill()
            ctx.strokeStyle = "#1a7f7f"; ctx.lineWidth = 1; ctx.stroke()

            // Bauchflosse
            ctx.beginPath()
            ctx.moveTo(cx+5, cy+br)
            ctx.bezierCurveTo(cx+8, cy+br+10, cx+20, cy+br+11, cx+22, cy+br+2)
            ctx.bezierCurveTo(cx+22, cy+br-2, cx+15, cy+br-3, cx+8, cy+br-1)
            ctx.closePath()
            ctx.fillStyle = "#2aafaf"; ctx.fill()

            // Wangen-Glühen (Pikachu-Stil, pink)
            ctx.save()
            ctx.globalAlpha = wg
            var wGr = ctx.createRadialGradient(cx+18, cy+9, 0, cx+18, cy+9, 11)
            wGr.addColorStop(0, "rgba(255,110,110,0.9)")
            wGr.addColorStop(1, "rgba(255,70,70,0)")
            ctx.fillStyle = wGr
            ctx.beginPath(); ctx.arc(cx+18, cy+9, 11, 0, Math.PI*2); ctx.fill()
            ctx.restore()

            // Auge – weißes Augapfel
            ctx.beginPath()
            ctx.arc(cx+19, cy-8, 12, 0, Math.PI*2)
            ctx.fillStyle = "white"; ctx.fill()
            ctx.strokeStyle = "#1a7f7f"; ctx.lineWidth = 1; ctx.stroke()
            // Pupille
            ctx.beginPath()
            ctx.arc(cx+21, cy-7, 7.5, 0, Math.PI*2)
            ctx.fillStyle = "#0d1b2a"; ctx.fill()
            // Glanzpunkt groß
            ctx.beginPath()
            ctx.arc(cx+24, cy-10, 3, 0, Math.PI*2)
            ctx.fillStyle = "white"; ctx.fill()
            // Glanzpunkt klein
            ctx.beginPath()
            ctx.arc(cx+18, cy-3, 1.5, 0, Math.PI*2)
            ctx.fillStyle = "rgba(255,255,255,0.6)"; ctx.fill()

            // Mund (kleiner Bogen)
            ctx.beginPath()
            ctx.arc(cx+br-3, cy+5, 3.5, 0.25, Math.PI-0.25)
            ctx.strokeStyle = "#1a7f7f"; ctx.lineWidth = 1.5; ctx.lineCap = "round"
            ctx.stroke()
        }
    }

    // ── Willkommenstext ──────────────────────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top
        anchors.topMargin:        Math.max(160, parent.height * 0.56)
        spacing: 7

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:            "Willkommen bei Strömling Design"
            font.pixelSize:  18
            font.weight:     Font.Light
            color:           root._textPri
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:            "Seite im linken Baum anklicken, um den Schaltplan zu öffnen."
            font.pixelSize:  12
            color:           root._textMut
        }
    }
}
