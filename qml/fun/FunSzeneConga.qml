import QtQuick

// Conga-Schlange: erstes Element führt, alle anderen folgen mit Zeitversatz.
Item {
    id: root
    required property var  sprites
    required property real canvasW
    required property real canvasH

    signal fertig()

    // Ringpuffer: pro Sprite einen Versatz von _versatz Frames
    property int _versatz:  34
    property var _history:  []   // [{x,y}] Positionen des Anführers
    property real _hx:      0
    property real _hy:      0
    property real _dx:      90
    property real _dy:      30

    function starten() {
        if (sprites.count === 0) return

        _hx = canvasW / 2
        _hy = canvasH / 2
        var angle = Math.random() * 2 * Math.PI
        _dx = Math.cos(angle) * 90
        _dy = Math.sin(angle) * 90

        // Puffer vorbelegen damit alle sofort eine Position haben
        var needed = sprites.count * _versatz + 10
        _history = []
        for (var i = 0; i < needed; i++)
            _history.push({ x: _hx, y: _hy })

        congaAnim.running = true
    }

    function stoppen() {
        congaAnim.running = false
    }

    FrameAnimation {
        id:      congaAnim
        running: false
        onTriggered: {
            var dt = Math.min(frameTime, 0.05)

            root._hx += root._dx * dt
            root._hy += root._dy * dt

            // Rand: abprallen + leichte Kursänderung
            var sw0 = sprites.count > 0 ? sprites.get(0).sw : 40
            var sh0 = sprites.count > 0 ? sprites.get(0).sh : 20
            if (root._hx < 0)              { root._hx = 0;              root._dx =  Math.abs(root._dx); _knicken() }
            if (root._hx + sw0 > canvasW) { root._hx = canvasW - sw0;  root._dx = -Math.abs(root._dx); _knicken() }
            if (root._hy < 0)              { root._hy = 0;              root._dy =  Math.abs(root._dy) }
            if (root._hy + sh0 > canvasH) { root._hy = canvasH - sh0;  root._dy = -Math.abs(root._dy) }

            // Sanfte Kurvenbewegung
            root._dy += (Math.random() - 0.5) * 8
            root._dy = Math.max(-110, Math.min(110, root._dy))

            root._history.push({ x: root._hx, y: root._hy })
            var maxLen = sprites.count * root._versatz + 20
            while (root._history.length > maxLen) root._history.shift()

            // Alle Sprites auf ihre jeweilige Historien-Position setzen
            for (var i = 0; i < sprites.count; i++) {
                var hIdx = Math.max(0, root._history.length - 1 - i * root._versatz)
                sprites.setProperty(i, "sx", root._history[hIdx].x)
                sprites.setProperty(i, "sy", root._history[hIdx].y)
            }
        }
    }

    function _knicken() {
        root._dy += (Math.random() - 0.5) * 60
    }
}
