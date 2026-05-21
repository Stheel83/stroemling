import QtQuick

// Formationstanz: Sprites wechseln zwischen Kreis → Linie → Stern → Welle.
Item {
    id: root
    required property var  sprites
    required property real canvasW
    required property real canvasH

    signal fertig()

    property int _formation:  0
    property var _ziele:      []
    property var _formNamen:  [qsTr("Kreis"), qsTr("Linie"), qsTr("Stern"), qsTr("Welle")]

    // Formationsname-Einblendung
    Text {
        id:                  formTitel
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 80 }
        text:                ""
        font.pixelSize:      22
        font.weight:         Font.Bold
        font.letterSpacing:  2
        color:               "#ffffff"
        opacity:             0
        style:               Text.Outline
        styleColor:          "#000000"

        SequentialAnimation {
            id: titelAnim
            NumberAnimation { target: formTitel; property: "opacity"; to: 1.0; duration: 350 }
            PauseAnimation  { duration: 1400 }
            NumberAnimation { target: formTitel; property: "opacity"; to: 0.0; duration: 500 }
        }
    }

    // ── Bewegungs-Timer (Lerp zu Zielen) ─────────────────────────
    Timer {
        id:       formTimer
        interval: 16
        repeat:   true
        onTriggered: {
            var n       = sprites.count
            var arrived = true
            for (var i = 0; i < n && i < root._ziele.length; i++) {
                var sx = sprites.get(i).sx
                var sy = sprites.get(i).sy
                var dx = root._ziele[i].x - sx
                var dy = root._ziele[i].y - sy
                if (Math.abs(dx) > 1.5 || Math.abs(dy) > 1.5) {
                    arrived = false
                    sprites.setProperty(i, "sx", sx + dx * 0.07)
                    sprites.setProperty(i, "sy", sy + dy * 0.07)
                } else {
                    sprites.setProperty(i, "sx", root._ziele[i].x)
                    sprites.setProperty(i, "sy", root._ziele[i].y)
                }
            }
            if (arrived) {
                formTimer.stop()
                pauseTimer.restart()
            }
        }
    }

    // ── Pause zwischen Formationen ────────────────────────────────
    Timer {
        id:       pauseTimer
        interval: 2200
        repeat:   false
        onTriggered: {
            root._formation = (root._formation + 1) % root._formNamen.length
            root._ziele     = root._berechnZiele(root._formation)
            formTitel.text  = root._formNamen[root._formation]
            titelAnim.restart()
            formTimer.restart()
        }
    }

    // ── API ───────────────────────────────────────────────────────
    function starten() {
        _formation = 0
        _ziele     = _berechnZiele(0)
        formTitel.text = _formNamen[0]
        titelAnim.restart()
        formTimer.restart()
    }

    function stoppen() {
        formTimer.stop()
        pauseTimer.stop()
        titelAnim.stop()
        formTitel.opacity = 0
    }

    function _berechnZiele(f) {
        var n   = sprites.count
        if (n === 0) return []
        var cx  = canvasW / 2
        var cy  = canvasH / 2
        var res = []

        if (f === 0) {
            // ── Kreis ──────────────────────────────────────────────
            var r = Math.min(canvasW, canvasH) * 0.33
            for (var i = 0; i < n; i++) {
                var ang = (i / n) * 2 * Math.PI - Math.PI / 2
                res.push({ x: cx + Math.cos(ang) * r - sprites.get(i).sw / 2,
                            y: cy + Math.sin(ang) * r - sprites.get(i).sh / 2 })
            }
        } else if (f === 1) {
            // ── Linie ──────────────────────────────────────────────
            var gap     = Math.min(120, (canvasW - 80) / Math.max(n - 1, 1))
            var totalW  = gap * (n - 1)
            for (var i = 0; i < n; i++) {
                res.push({ x: cx - totalW / 2 + i * gap - sprites.get(i).sw / 2,
                            y: cy - sprites.get(i).sh / 2 })
            }
        } else if (f === 2) {
            // ── Stern ──────────────────────────────────────────────
            var rO = Math.min(canvasW, canvasH) * 0.36
            var rI = rO * 0.42
            for (var i = 0; i < n; i++) {
                var rr  = (i % 2 === 0) ? rO : rI
                var ang = (i / n) * 2 * Math.PI - Math.PI / 2
                res.push({ x: cx + Math.cos(ang) * rr - sprites.get(i).sw / 2,
                            y: cy + Math.sin(ang) * rr - sprites.get(i).sh / 2 })
            }
        } else {
            // ── Welle ──────────────────────────────────────────────
            var gap    = Math.min(130, (canvasW - 80) / Math.max(n - 1, 1))
            var totalW = gap * (n - 1)
            var welleA = canvasH * 0.22
            for (var i = 0; i < n; i++) {
                var t = n > 1 ? i / (n - 1) : 0
                res.push({ x: cx - totalW / 2 + i * gap - sprites.get(i).sw / 2,
                            y: cy + Math.sin(t * 2 * Math.PI) * welleA - sprites.get(i).sh / 2 })
            }
        }
        return res
    }
}
