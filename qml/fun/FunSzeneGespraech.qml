import QtQuick

// Gespräch: 2 Symbole nähern sich, Sprechblasen mit Elektrotechnik-Witzen erscheinen.
Item {
    id: root
    required property var  sprites
    required property real canvasW
    required property real canvasH

    // Eigene Texte werden reaktiv von FunModusOverlay → Main.qml → Einstellungen durchgereicht.
    property string gespraechTexte: "[]"

    signal fertig()

    property var _activeDialog: []

    readonly property var _builtinDialog: [
        [ qsTr("Nenn deinen Widerstand!"),     qsTr("Meine Impedanz ist geheim.") ],
        [ qsTr("Hast du geerdet?"),             qsTr("Ich bin kurzschlussfreudig.") ],
        [ qsTr("230V? Kenn ich nicht."),        qsTr("Dein Potenzial ist hoch.") ],
        [ qsTr("Wir haben Verbindung!"),        qsTr("Phase? Welche Phase?") ],
        [ qsTr("Berühr mich nicht!"),           qsTr("Ich steh unter Spannung.") ],
        [ qsTr("Mein Schutzleiter ist weg."),   qsTr("Dann erd dich woanders!") ],
        [ qsTr("Null und Phase getrennt?"),     qsTr("Nur bei mir zu Hause.") ],
        [ qsTr("Ich brauche mehr Strom."),      qsTr("Hast du R verkleinert?") ],
    ]

    property int  _paar:     0    // aktuelles Dialogpaar-Index
    property int  _phase:    0    // 0=annähern 1=A redet 2=B redet 3=zurück
    property int  _idxA:     0
    property int  _idxB:     1
    property real _zielAX:   0
    property real _zielAY:   0
    property real _zielBX:   0
    property real _zielBY:   0
    property real _startAX:  0
    property real _startAY:  0
    property real _startBX:  0
    property real _startBY:  0

    // Positionen für Sprechblasen (werden im Timer gesetzt)
    property real _bAX:  0;  property real _bAY:  0;  property real _bAOp: 0
    property real _bBX:  0;  property real _bBY:  0;  property real _bBOp: 0

    // ── Sprechblase A ─────────────────────────────────────────────
    Rectangle {
        x:            root._bAX
        y:            root._bAY
        width:        blaText_A.implicitWidth + 18
        height:       34
        radius:       8
        color:        "#f5eec8"
        border.color: "#c8b850"
        border.width: 1
        opacity:      root._bAOp
        z:            20
        visible:      opacity > 0.01
        Text {
            id:              blaText_A
            anchors.centerIn: parent
            text:            root._activeDialog.length > 0 ? root._activeDialog[root._paar][0] : ""
            font.pixelSize:  11
            color:           "#3a3000"
        }
    }

    // ── Sprechblase B ─────────────────────────────────────────────
    Rectangle {
        x:            root._bBX
        y:            root._bBY
        width:        blaText_B.implicitWidth + 18
        height:       34
        radius:       8
        color:        "#c8ecf5"
        border.color: "#50a0c8"
        border.width: 1
        opacity:      root._bBOp
        z:            20
        visible:      opacity > 0.01
        Text {
            id:              blaText_B
            anchors.centerIn: parent
            text:            root._activeDialog.length > 0 ? root._activeDialog[root._paar][1] : ""
            font.pixelSize:  11
            color:           "#003040"
        }
    }

    // ── Bewegungs- und Dialog-Timer ───────────────────────────────
    property int _phaseTick: 0

    Timer {
        id:       gespTimer
        interval: 16
        repeat:   true
        onTriggered: {
            root._phaseTick++

            if (root._phase === 0) {
                // Annähern: A nach links-Mitte, B nach rechts-Mitte
                var fertigA = _lerp(root._idxA, root._zielAX, root._zielAY)
                var fertigB = _lerp(root._idxB, root._zielBX, root._zielBY)
                if (fertigA && fertigB) { root._phase = 1; root._phaseTick = 0 }

            } else if (root._phase === 1) {
                // A redet
                var sx = sprites.get(root._idxA).sx
                var sy = sprites.get(root._idxA).sy
                root._bAX  = sx + sprites.get(root._idxA).sw / 2 - 60
                root._bAY  = sy - 44
                root._bAOp = Math.min(1.0, root._phaseTick / 15.0)
                root._bBOp = 0
                if (root._phaseTick > 130) { root._phase = 2; root._phaseTick = 0 }

            } else if (root._phase === 2) {
                // B redet
                var sx = sprites.get(root._idxB).sx
                var sy = sprites.get(root._idxB).sy
                root._bBX  = sx + sprites.get(root._idxB).sw / 2 - 60
                root._bBY  = sy - 44
                root._bAOp = Math.max(0, root._bAOp - 0.05)
                root._bBOp = Math.min(1.0, root._phaseTick / 15.0)
                if (root._phaseTick > 130) { root._phase = 3; root._phaseTick = 0 }

            } else if (root._phase === 3) {
                // Zurückbewegen + Blasen ausblenden
                root._bAOp = Math.max(0, root._bAOp - 0.05)
                root._bBOp = Math.max(0, root._bBOp - 0.05)
                var fA = _lerp(root._idxA, root._startAX, root._startAY)
                var fB = _lerp(root._idxB, root._startBX, root._startBY)
                if (fA && fB && root._bAOp <= 0 && root._bBOp <= 0) {
                    // Nächstes Paar
                    root._paar = (root._paar + 1) % root._activeDialog.length
                    _naechstesPaar()
                }
            }
        }
    }

    // ── API ───────────────────────────────────────────────────────
    function starten() {
        if (sprites.count < 2) return

        // Eingebaute + eigene Texte zusammenführen
        var combined = []
        for (var i = 0; i < _builtinDialog.length; i++)
            combined.push(_builtinDialog[i])
        try {
            var custom = JSON.parse(root.gespraechTexte || "[]")
            for (var j = 0; j < custom.length; j++)
                if (custom[j].a && custom[j].b)
                    combined.push([custom[j].a, custom[j].b])
        } catch(e) {}
        _activeDialog = combined

        _paar = Math.floor(Math.random() * _activeDialog.length)
        _naechstesPaar()
        gespTimer.restart()
    }

    function stoppen() {
        gespTimer.stop()
        _bAOp = 0; _bBOp = 0
    }

    function _naechstesPaar() {
        _idxA = Math.floor(Math.random() * sprites.count)
        do { _idxB = Math.floor(Math.random() * sprites.count) } while (_idxB === _idxA)

        _startAX = sprites.get(_idxA).sx;  _startAY = sprites.get(_idxA).sy
        _startBX = sprites.get(_idxB).sx;  _startBY = sprites.get(_idxB).sy

        var sw = sprites.get(_idxA).sw + sprites.get(_idxB).sw
        _zielAX = canvasW / 2 - sw / 2 - 20;  _zielAY = canvasH / 2 - sprites.get(_idxA).sh / 2
        _zielBX = canvasW / 2 + 20;             _zielBY = canvasH / 2 - sprites.get(_idxB).sh / 2

        _bAOp = 0;  _bBOp = 0
        _phase = 0;  _phaseTick = 0
    }

    function _lerp(idx, tx, ty) {
        var sx = sprites.get(idx).sx
        var sy = sprites.get(idx).sy
        var dx = tx - sx, dy = ty - sy
        if (Math.abs(dx) < 1.5 && Math.abs(dy) < 1.5) {
            sprites.setProperty(idx, "sx", tx)
            sprites.setProperty(idx, "sy", ty)
            return true
        }
        sprites.setProperty(idx, "sx", sx + dx * 0.07)
        sprites.setProperty(idx, "sy", sy + dy * 0.07)
        return false
    }
}
