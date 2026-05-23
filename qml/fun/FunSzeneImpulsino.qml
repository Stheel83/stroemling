import QtQuick

// Impulsino läuft als Bonus-Charakter parallel zu allen anderen Szenarien.
// Startet/stoppt automatisch mit root.visible des FunModusOverlay.
Item {
    id: root
    required property real canvasW
    required property real canvasH
    property bool running: false

    onRunningChanged: running ? _start() : _stop()

    readonly property real _iw: 220
    readonly property real _ih: 145
    property real _px: 40
    property real _py: 40
    property real _dx: 0
    property real _dy: 0

    function _start() {
        _px = 40 + Math.random() * Math.max(0, canvasW - _iw - 80)
        _py = 40 + Math.random() * Math.max(0, canvasH - _ih - 80)
        var speed = 100 + Math.random() * 60
        var angle = Math.random() * 2 * Math.PI
        _dx = Math.cos(angle) * speed
        _dy = Math.sin(angle) * speed
        bounceAnim.running = true
        pulseTimer.interval = 600 + Math.floor(Math.random() * 800)
        pulseTimer.start()
    }

    function _stop() {
        bounceAnim.running = false
        pulseTimer.stop()
        pulseAnim.stop()
    }

    Image {
        id: img
        x:        root._px
        y:        root._py
        width:    root._iw
        height:   root._ih
        source:   "qrc:/assets/impulsino_sheet.png"
        fillMode: Image.PreserveAspectFit
        smooth:   true
        mipmap:   true

        SequentialAnimation {
            id: pulseAnim
            NumberAnimation { target: img; property: "scale"; to: 1.14; duration: 70;  easing.type: Easing.OutQuad }
            NumberAnimation { target: img; property: "scale"; to: 1.0;  duration: 130; easing.type: Easing.InQuad }
        }
    }

    FrameAnimation {
        id: bounceAnim
        running: false
        onTriggered: {
            var dt = Math.min(frameTime, 0.05)
            root._px += root._dx * dt
            root._py += root._dy * dt

            if (root._px < 0)                        { root._px = 0;                         root._dx =  Math.abs(root._dx) }
            if (root._py < 0)                        { root._py = 0;                         root._dy =  Math.abs(root._dy) }
            if (root._px + root._iw > root.canvasW)  { root._px = root.canvasW - root._iw;  root._dx = -Math.abs(root._dx) }
            if (root._py + root._ih > root.canvasH)  { root._py = root.canvasH - root._ih;  root._dy = -Math.abs(root._dy) }
        }
    }

    Timer {
        id: pulseTimer
        repeat: true
        onTriggered: {
            interval = 500 + Math.floor(Math.random() * 1200)
            pulseAnim.restart()
        }
    }
}
