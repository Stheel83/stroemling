import QtQuick

// Schwerkraft: Sprites fallen nach unten, prallen ab, stapeln sich, springen dann hoch.
Item {
    id: root
    required property var  sprites
    required property real canvasW
    required property real canvasH

    signal fertig()

    property var _vel:      []      // [{dy}]
    property var _settled:  []      // true wenn Sprite auf dem Boden/aufgestapelt
    property int _phase:    0       // 0=fallen 1=pause 2=abgesprungen

    // ── Fallen-Animation ──────────────────────────────────────────
    FrameAnimation {
        id:      fallAnim
        running: false
        onTriggered: {
            var dt      = Math.min(frameTime, 0.05)
            var gravity = 520.0
            var n       = sprites.count
            var allDown = true

            for (var i = 0; i < n; i++) {
                if (root._settled[i]) continue
                allDown = false

                var sx = sprites.get(i).sx
                var sy = sprites.get(i).sy
                var sw = sprites.get(i).sw
                var sh = sprites.get(i).sh

                root._vel[i].dy += gravity * dt
                sy += root._vel[i].dy * dt

                // Boden (Unterseite des Sprites berührt canvasH)
                var boden = canvasH - sh - 4
                if (sy >= boden) {
                    sy = boden
                    root._vel[i].dy *= -0.38   // Prall + Dämpfung
                    if (Math.abs(root._vel[i].dy) < 18) {
                        root._vel[i].dy = 0
                        root._settled[i] = true
                    }
                }

                sprites.setProperty(i, "sy", sy)
            }

            if (allDown && root._phase === 0) {
                root._phase = 1
                fallAnim.running = false
                pauseTimer.start()
            }
        }
    }

    // ── Pause (Sprites liegen unten) ──────────────────────────────
    Timer {
        id:       pauseTimer
        interval: 1400
        repeat:   false
        onTriggered: {
            // Alle gleichzeitig hochspringen
            for (var i = 0; i < sprites.count; i++) {
                root._vel[i]     = { dy: -(380 + Math.random() * 100) }
                root._settled[i] = false
            }
            root._phase = 0
            fallAnim.running = true
        }
    }

    // ── API ───────────────────────────────────────────────────────
    function starten() {
        var n = sprites.count
        if (n === 0) return

        _vel     = []
        _settled = []
        _phase   = 0

        // Sprites oben horizontal verteilen und leicht versetzt starten
        var breite  = canvasW - 60
        var abstand = Math.min(breite / Math.max(n, 1), 160)
        for (var i = 0; i < n; i++) {
            var sw = sprites.get(i).sw
            var startX = 30 + i * abstand + (Math.random() - 0.5) * 20
            sprites.setProperty(i, "sx", Math.max(4, Math.min(canvasW - sw - 4, startX)))
            sprites.setProperty(i, "sy", -(30 + Math.random() * canvasH * 0.4))   // oben außerhalb
            _vel.push({ dy: Math.random() * 30 })
            _settled.push(false)
        }

        fallAnim.running = true
    }

    function stoppen() {
        fallAnim.running = false
        pauseTimer.stop()
    }
}
