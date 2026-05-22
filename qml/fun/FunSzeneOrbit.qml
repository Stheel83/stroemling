import QtQuick

// Orbit: 1 Zentralgestirn bleibt in der Mitte, alle anderen kreisen auf Ellipsen darum.
Item {
    id: root
    required property var  sprites
    required property real canvasW
    required property real canvasH

    signal fertig()

    property var _orbits: []   // [{angle, rx, ry, speed}] für jeden Nicht-Zentrum-Sprite

    function starten() {
        if (sprites.count === 0) return

        // Zentralgestirn (Index 0) in die Mitte setzen
        var cx  = canvasW / 2
        var cy  = canvasH / 2
        var sw0 = sprites.get(0).sw
        var sh0 = sprites.get(0).sh
        sprites.setProperty(0, "sx", cx - sw0 / 2)
        sprites.setProperty(0, "sy", cy - sh0 / 2)

        _orbits = []
        var layer = 0
        for (var i = 1; i < sprites.count; i++) {
            if ((i - 1) % 3 === 0 && i > 1) layer++
            var baseRx = 150 + layer * 110
            var baseRy = 90  + layer * 70
            var dir    = (i % 2 === 0) ? 1 : -1
            _orbits.push({
                angle: (i / sprites.count) * 2 * Math.PI,
                rx:    baseRx + Math.random() * 30,
                ry:    baseRy + Math.random() * 20,
                speed: dir * (0.4 + Math.random() * 0.5)
            })
        }
        orbitAnim.running = true
    }

    function stoppen() {
        orbitAnim.running = false
    }

    FrameAnimation {
        id:      orbitAnim
        running: false
        onTriggered: {
            var cx = canvasW / 2
            var cy = canvasH / 2
            var dt = Math.min(frameTime, 0.05)

            for (var i = 1; i < sprites.count && i - 1 < root._orbits.length; i++) {
                var o  = root._orbits[i - 1]
                o.angle += o.speed * dt
                root._orbits[i - 1] = o

                var sw = sprites.get(i).sw
                var sh = sprites.get(i).sh
                sprites.setProperty(i, "sx", cx + Math.cos(o.angle) * o.rx - sw / 2)
                sprites.setProperty(i, "sy", cy + Math.sin(o.angle) * o.ry - sh / 2)
            }
        }
    }
}
