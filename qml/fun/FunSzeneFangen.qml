import QtQuick

// Fangen: 1 Fänger jagt die anderen. Bei Berührung wechselt die Rolle.
Item {
    id: root
    required property var  sprites
    required property real canvasW
    required property real canvasH

    signal fertig()

    property int _faengerIdx:   0
    property int _cooldown:     0     // Frames nach dem Fangen, in denen kein neues Fangen möglich
    property var _vel:          []

    // Fänger-Markierung: blinkendes Label
    property string _faengerLabel: ""

    function starten() {
        if (sprites.count < 2) return

        _faengerIdx = Math.floor(Math.random() * sprites.count)
        _cooldown   = 90
        _vel        = []

        for (var i = 0; i < sprites.count; i++) {
            var speed = 50 + Math.random() * 40
            var angle = Math.random() * 2 * Math.PI
            _vel.push({ dx: Math.cos(angle) * speed, dy: Math.sin(angle) * speed })
        }

        fangenAnim.running = true
    }

    function stoppen() {
        fangenAnim.running = false
    }

    FrameAnimation {
        id:      fangenAnim
        running: false
        onTriggered: {
            if (sprites.count < 2) return
            var dt = Math.min(frameTime, 0.05)
            if (root._cooldown > 0) root._cooldown--

            // Fänger: Ziel = nächster Flüchtling
            var fsx  = sprites.get(root._faengerIdx).sx
            var fsy  = sprites.get(root._faengerIdx).sy
            var fsw  = sprites.get(root._faengerIdx).sw
            var fsh  = sprites.get(root._faengerIdx).sh
            var fcx  = fsx + fsw / 2
            var fcy  = fsy + fsh / 2

            var nearestIdx  = -1
            var nearestDist = 1e9
            for (var j = 0; j < sprites.count; j++) {
                if (j === root._faengerIdx) continue
                var jcx = sprites.get(j).sx + sprites.get(j).sw / 2
                var jcy = sprites.get(j).sy + sprites.get(j).sh / 2
                var d   = Math.sqrt((jcx - fcx) * (jcx - fcx) + (jcy - fcy) * (jcy - fcy))
                if (d < nearestDist) { nearestDist = d; nearestIdx = j }
            }

            // Fänger-Geschwindigkeit auf Ziel ausrichten (120 px/s)
            if (nearestIdx >= 0) {
                var tcx = sprites.get(nearestIdx).sx + sprites.get(nearestIdx).sw / 2
                var tcy = sprites.get(nearestIdx).sy + sprites.get(nearestIdx).sh / 2
                var ang = Math.atan2(tcy - fcy, tcx - fcx)
                root._vel[root._faengerIdx] = { dx: Math.cos(ang) * 120, dy: Math.sin(ang) * 120 }
            }

            // Bewegung aller Sprites
            for (var i = 0; i < sprites.count; i++) {
                var sx = sprites.get(i).sx
                var sy = sprites.get(i).sy
                var sw = sprites.get(i).sw
                var sh = sprites.get(i).sh
                var v  = root._vel[i]

                if (i !== root._faengerIdx) {
                    // Flüchtling: vom Fänger wegbewegen
                    var dax  = (sx + sw / 2) - fcx
                    var day  = (sy + sh / 2) - fcy
                    var dist = Math.sqrt(dax * dax + day * day) + 0.001
                    var flee = Math.min(6000 / (dist * dist + 1), 300)
                    v.dx += dax / dist * flee * dt
                    v.dy += day / dist * flee * dt
                    v.dx += (Math.random() - 0.5) * 15
                    v.dy += (Math.random() - 0.5) * 15
                    var spd = Math.sqrt(v.dx * v.dx + v.dy * v.dy)
                    if (spd > 90) { v.dx = v.dx / spd * 90; v.dy = v.dy / spd * 90 }
                }

                sx += v.dx * dt
                sy += v.dy * dt

                if (sx < 0)          { sx = 0;          v.dx =  Math.abs(v.dx) }
                if (sy < 0)          { sy = 0;          v.dy =  Math.abs(v.dy) }
                if (sx + sw > canvasW) { sx = canvasW - sw; v.dx = -Math.abs(v.dx) }
                if (sy + sh > canvasH) { sy = canvasH - sh; v.dy = -Math.abs(v.dy) }

                root._vel[i] = v
                sprites.setProperty(i, "sx", sx)
                sprites.setProperty(i, "sy", sy)
            }

            // Fangen prüfen
            if (root._cooldown === 0 && nearestIdx >= 0) {
                var tsw  = sprites.get(nearestIdx).sw
                var tsh  = sprites.get(nearestIdx).sh
                var touch = (fsw + tsw) / 2 + 6
                if (nearestDist < touch) {
                    root._faengerIdx = nearestIdx
                    root._cooldown   = 80
                    // Flüchtling jetzt etwas beschleunigen (Schrecksekunde)
                    root._vel[nearestIdx].dx *= -1.4
                    root._vel[nearestIdx].dy *= -1.4
                }
            }
        }
    }
}
