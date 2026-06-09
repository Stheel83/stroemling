import QtQuick

// Fun-Modus-Overlay: liegt über dem gesamten Fenster (z: 600).
// Wird von Main.qml gesteuert; schreibt NICHT in elementeModel oder DB.
Item {
    id: root

    property var    canvas: null   // aktiver SchaltplanCanvas – muss vor visible=true gesetzt werden
    required property var theme
    property string gespraechTexte: "[]"

    signal deaktiviert()

    // ── Sprite-Datenmodell ────────────────────────────────────────
    ListModel { id: spriteModel }   // roles: sx, sy, sw, sh, typ, label

    // ── Abgedunkelter Hintergrund ─────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        "#000000"
        opacity:      0.68
    }

    // ── Sprites ───────────────────────────────────────────────────
    // Qt 6: required-Properties mit Rollennamen werden automatisch gebunden.
    Repeater {
        model: spriteModel
        FunSprite { theme: root.theme }
    }

    // ── Szenarien ─────────────────────────────────────────────────
    FunSzeneDvd {
        id:      dvdSzene
        sprites: spriteModel
        canvasW: root.width
        canvasH: root.height
    }
    FunSzeneOrbit {
        id:      orbitSzene
        sprites: spriteModel
        canvasW: root.width
        canvasH: root.height
    }
    FunSzeneConga {
        id:      congaSzene
        sprites: spriteModel
        canvasW: root.width
        canvasH: root.height
    }
    FunSzeneFangen {
        id:      fangenSzene
        sprites: spriteModel
        canvasW: root.width
        canvasH: root.height
    }
    FunSzeneSpringeil {
        id:           springeilSzene
        anchors.fill: parent          // Canvas-Kind braucht Größe des Overlays
        sprites:      spriteModel
        canvasW:      root.width
        canvasH:      root.height
    }
    FunSzeneFormation {
        id:           formationSzene
        anchors.fill: parent          // Text-Anker brauchen parent-Größe
        sprites:      spriteModel
        canvasW:      root.width
        canvasH:      root.height
    }
    FunSzeneGespraech {
        id:             gespraechSzene
        anchors.fill:   parent          // Sprechblasen-Rechtecke brauchen Kontext
        sprites:        spriteModel
        canvasW:        root.width
        canvasH:        root.height
        gespraechTexte: root.gespraechTexte
    }
    FunSzeneFall {
        id:           fallSzene
        anchors.fill: parent
        sprites:      spriteModel
        canvasW:      root.width
        canvasH:      root.height
    }

    FunSzeneImpulsino {
        id:      impulsinoSzene
        canvasW: root.width
        canvasH: root.height
        running: root.visible
    }

    property var  _szenen:        [dvdSzene, orbitSzene, congaSzene, fangenSzene,
                                   springeilSzene, formationSzene, gespraechSzene, fallSzene]
    property var  _aktiveSzene:   null
    property var  _shuffleQueue:  []   // gemischte Reihenfolge, nachfüllen wenn leer

    // ── Szenario-Titel (kurz eingeblendet) ────────────────────────
    property var _szenenNamen: [
        qsTr("DVD-Bounce"), qsTr("Orbit"), qsTr("Conga-Schlange"), qsTr("Fangen"),
        qsTr("Springseil"),  qsTr("Formationstanz"), qsTr("Gespräch"), qsTr("Schwerkraft")
    ]

    Rectangle {
        id:      titelBox
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 40 }
        width:   titelText.implicitWidth + 32
        height:  36
        radius:  8
        color:   "#cc000000"
        opacity: 0
        z:       5

        Text {
            id:                  titelText
            anchors.centerIn:    parent
            text:                ""
            font.pixelSize:      15
            font.weight:         Font.Medium
            color:               "white"
            font.letterSpacing:  1
        }

        SequentialAnimation {
            id: titelAnim
            NumberAnimation { target: titelBox; property: "opacity"; to: 1.0; duration: 400 }
            PauseAnimation  { duration: 1800 }
            NumberAnimation { target: titelBox; property: "opacity"; to: 0.0; duration: 600 }
        }
    }

    // ── "Schluss jetzt"-Button ────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.bottom; right: parent.right; margins: 28 }
        width:  170
        height: 50
        radius: 8
        color:  schlussMaus.containsMouse ? "#991111" : "#cc2222"
        z:      10

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.72; duration: 1100; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 1100; easing.type: Easing.InOutSine }
        }

        Text {
            anchors.centerIn: parent
            text:             qsTr("Schluss jetzt")
            font.pixelSize:   16
            font.weight:      Font.Bold
            color:            "white"
        }

        MouseArea {
            id:           schlussMaus
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.deaktivieren()
        }
    }

    // ── Aktivierung / Deaktivierung ───────────────────────────────
    onVisibleChanged: {
        if (visible) _aktivieren()
        else         _allesStoppen()
    }

    function deaktivieren() {
        root.visible = false
        root.deaktiviert()
    }

    function _allesStoppen() {
        for (var i = 0; i < _szenen.length; i++)
            _szenen[i].stoppen()
        _aktiveSzene = null
    }

    function _shuffleAuffuellen() {
        // Fisher-Yates Shuffle über alle Szenarien-Indizes
        var arr = []
        for (var i = 0; i < _szenen.length; i++) arr.push(i)
        for (var j = arr.length - 1; j > 0; j--) {
            var k = Math.floor(Math.random() * (j + 1))
            var t = arr[j]; arr[j] = arr[k]; arr[k] = t
        }
        // Letztes der alten Queue == Erstes der neuen? → tauschen um Repeat zu vermeiden
        var lastPlayed = _shuffleQueue.length > 0 ? -1
            : (_aktiveSzene ? _szenen.indexOf(_aktiveSzene) : -1)
        if (lastPlayed >= 0 && arr[0] === lastPlayed && arr.length > 1) {
            var tmp = arr[0]; arr[0] = arr[1]; arr[1] = tmp
        }
        _shuffleQueue = arr
    }

    function _aktivieren() {
        if (!root.canvas) { root.visible = false; return }

        // Sprites aus Canvas-Snapshot aufbauen
        spriteModel.clear()
        var snap   = root.canvas.elementeModel.snapshot()
        var zoom   = root.canvas.zoom
        var wX     = root.canvas.worldX
        var wY     = root.canvas.worldY

        for (var i = 0; i < snap.length; i++) {
            var el   = snap[i]
            var p1   = root.canvas.mapToItem(root, el.x1 * zoom + wX, el.y1 * zoom + wY)
            var p2   = root.canvas.mapToItem(root, el.x2 * zoom + wX, el.y2 * zoom + wY)
            var sw   = Math.min(200, Math.max(32, Math.abs(p2.x - p1.x)))
            var sh   = Math.min(100, Math.max(18, Math.abs(p2.y - p1.y)))
            if (el.typ === "linie" || el.typ === "kabellinie") { sw = Math.max(sw, 44); sh = Math.max(sh, 18) }
            spriteModel.append({ sx: p1.x, sy: p1.y, sw: sw, sh: sh,
                                  typ: el.typ, label: el.textInhalt || el.symbolId || el.typ,
                                  symbolId: el.symbolId || "" })
        }

        if (spriteModel.count === 0) { root.visible = false; return }

        // Nächstes Szenario aus gemischter Queue – nie zwei gleiche hintereinander
        if (_shuffleQueue.length === 0) _shuffleAuffuellen()
        var idx     = _shuffleQueue.shift()
        _aktiveSzene = _szenen[idx]
        _aktiveSzene.starten()

        // Kurzen Titel einblenden
        titelText.text = _szenenNamen[idx]
        titelAnim.restart()
    }
}
