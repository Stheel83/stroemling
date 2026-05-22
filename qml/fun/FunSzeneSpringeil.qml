import QtQuick

// Springseil: 2 Halter links/rechts, 1 Springer springt über das Seil.
// Alle übrigen Sprites warten am unteren Rand.
Item {
    id: root
    required property var  sprites
    required property real canvasW
    required property real canvasH

    signal fertig()

    property real _phase:     0.0   // Seil-Phase (steigt kontinuierlich)
    property real _amplitude: 70    // max. Seilauslenkung in der Mitte

    // Indizes der drei Hauptakteure
    property int _idxL:    0
    property int _idxR:    1
    property int _idxSpringer: 2

    // Feste Bühnenpositionen der Halter (Mittelpunkte)
    property real _hLX: canvasW * 0.18
    property real _hLY: canvasH * 0.52
    property real _hRX: canvasW * 0.82
    property real _hRY: canvasH * 0.52

    // ── Seil-Canvas ───────────────────────────────────────────────
    Canvas {
        id: seilCanvas
        anchors.fill: parent
        visible: false

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (sprites.count < 2) return

            var sw0 = sprites.get(root._idxL).sw
            var sw1 = sprites.get(root._idxR).sw
            var x1  = root._hLX + sw0 / 2
            var x2  = root._hRX - sw1 / 2
            var y1  = root._hLY
            var y2  = root._hRY
            if (x2 <= x1) return

            var len  = x2 - x1
            var midY = (y1 + y2) / 2

            ctx.beginPath()
            ctx.strokeStyle = "#99aaff"
            ctx.lineWidth   = 2.5
            ctx.lineCap     = "round"
            var first = true
            for (var x = x1; x <= x2; x += 3) {
                var t = (x - x1) / len
                var y = midY + root._amplitude * Math.sin(t * Math.PI) * Math.cos(root._phase)
                if (first) { ctx.moveTo(x, y); first = false }
                else         ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }

    // ── Logik-Animation ───────────────────────────────────────────
    FrameAnimation {
        id:      seilAnim
        running: false
        onTriggered: {
            root._phase += 2.8 * Math.min(frameTime, 0.05)   // Seilgeschwindigkeit rad/s

            seilCanvas.requestPaint()

            if (sprites.count < 3) return

            // Springer springt einmal pro halber Seil-Umdrehung (|sin| Profil)
            var midX = (root._hLX + root._hRX) / 2
            var midY = (root._hLY + root._hRY) / 2
            var sh2  = sprites.get(root._idxSpringer).sh
            var sw2  = sprites.get(root._idxSpringer).sw
            // Springer ist oben wenn Seil durch Mitte pfeift (sin(phase)→0)
            var sprungHoehe = 70 + root._amplitude * Math.abs(Math.cos(root._phase))
            sprites.setProperty(root._idxSpringer, "sx", midX - sw2 / 2)
            sprites.setProperty(root._idxSpringer, "sy", midY - sh2 / 2 - Math.abs(Math.sin(root._phase)) * sprungHoehe)
        }
    }

    // ── API ───────────────────────────────────────────────────────
    function starten() {
        if (sprites.count === 0) return

        _phase = 0.0

        var n = sprites.count
        _idxL       = 0
        _idxR       = Math.min(1, n - 1)
        _idxSpringer = Math.min(2, n - 1)

        // Halter Links positionieren
        var sw0 = sprites.get(_idxL).sw, sh0 = sprites.get(_idxL).sh
        sprites.setProperty(_idxL, "sx", _hLX - sw0 / 2)
        sprites.setProperty(_idxL, "sy", _hLY - sh0 / 2)

        // Halter Rechts positionieren
        if (_idxR !== _idxL) {
            var sw1 = sprites.get(_idxR).sw, sh1 = sprites.get(_idxR).sh
            sprites.setProperty(_idxR, "sx", _hRX - sw1 / 2)
            sprites.setProperty(_idxR, "sy", _hRY - sh1 / 2)
        }

        // Übrige Sprites am unteren Rand parken
        var parkX = 30
        for (var i = 0; i < n; i++) {
            if (i === _idxL || i === _idxR || i === _idxSpringer) continue
            var sw = sprites.get(i).sw, sh = sprites.get(i).sh
            sprites.setProperty(i, "sx", parkX)
            sprites.setProperty(i, "sy", canvasH - sh - 12)
            parkX += sw + 10
        }

        seilCanvas.visible = true
        seilAnim.running = true
    }

    function stoppen() {
        seilAnim.running = false
        seilCanvas.visible = false
    }
}
