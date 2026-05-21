import QtQuick

// DVD-Bounce: alle Sprites bewegen sich frei durch den Canvas und prallen an Rändern ab.
Item {
    id: root
    required property var  sprites   // ListModel mit sx, sy, sw, sh
    required property real canvasW
    required property real canvasH

    signal fertig()

    property var _vel: []   // [{dx, dy}] parallel zu sprites

    function starten() {
        _vel = []
        for (var i = 0; i < sprites.count; i++) {
            var speed = 60 + Math.random() * 90
            var angle = Math.random() * 2 * Math.PI
            _vel.push({ dx: Math.cos(angle) * speed, dy: Math.sin(angle) * speed })
        }
        dvdTimer.restart()
    }

    function stoppen() {
        dvdTimer.stop()
    }

    Timer {
        id:       dvdTimer
        interval: 16
        repeat:   true
        onTriggered: {
            var dt = 0.016
            var n  = Math.min(sprites.count, root._vel.length)
            for (var i = 0; i < n; i++) {
                var sx = sprites.get(i).sx
                var sy = sprites.get(i).sy
                var sw = sprites.get(i).sw
                var sh = sprites.get(i).sh
                var v  = root._vel[i]

                sx += v.dx * dt
                sy += v.dy * dt

                if (sx < 0)                    { sx = 0;                  v.dx =  Math.abs(v.dx) }
                if (sy < 0)                    { sy = 0;                  v.dy =  Math.abs(v.dy) }
                if (sx + sw > root.canvasW)    { sx = root.canvasW - sw;  v.dx = -Math.abs(v.dx) }
                if (sy + sh > root.canvasH)    { sy = root.canvasH - sh;  v.dy = -Math.abs(v.dy) }

                root._vel[i] = v
                sprites.setProperty(i, "sx", sx)
                sprites.setProperty(i, "sy", sy)
            }
        }
    }
}
