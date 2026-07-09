import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property var theme

    property var  felder:        []
    property int  selIdx:        -1
    property bool hatVorlage:    false
    property real breiteMm:      297
    property real hoeheMm:       210
    property real randLinksMm:   20
    property real randRechtsMm:  10
    property real randObenMm:    10
    property real randUntenMm:   10

    signal feldAngewaehlt(int idx)
    signal hintergrundGeklickt()
    signal feldVerschoben(int idx, real xMm, real yMm)
    signal feldGroesseGeaendert(int idx, real breiteMm, real hoeheMm)

    // ── Skalierung: Einpassen (fit-to-window) × Nutzer-Zoom ────
    readonly property real _fitScale: {
        if (breiteMm <= 0 || hoeheMm <= 0 || width <= 40 || height <= 40) return 1
        return Math.min((width - 40) / breiteMm, (height - 40) / hoeheMm)
    }
    property real zoomFactor: 1.0
    property real panX:       0
    property real panY:       0
    readonly property real _scale: _fitScale * zoomFactor
    readonly property real _pageX: (width  - breiteMm * _scale) / 2 + panX
    readonly property real _pageY: (height - hoeheMm  * _scale) / 2 + panY

    function _s(mm)  { return mm * _scale }

    // Zoomt um `factor`, wobei der Weltpunkt unter (mx, my) fix bleibt
    // (analog CanvasNavigationHandler._pendingWx/_pendingWy im Hauptcanvas).
    function _zoomAt(mx, my, factor) {
        var wx = (mx - _pageX) / _scale
        var wy = (my - _pageY) / _scale
        zoomFactor = Math.max(0.25, Math.min(8, zoomFactor * factor))
        var neueScale = _fitScale * zoomFactor
        panX = mx - wx * neueScale - (width  - breiteMm * neueScale) / 2
        panY = my - wy * neueScale - (height - hoeheMm  * neueScale) / 2
    }

    function _zoomZuruecksetzen() { zoomFactor = 1.0; panX = 0; panY = 0 }

    // Bei Vorlagenwechsel (andere Seitenmaße) wieder einpassen statt
    // mit dem alten Zoom/Pan-Stand auf die neue Seite zu schauen.
    onBreiteMmChanged: _zoomZuruecksetzen()
    onHoeheMmChanged:  _zoomZuruecksetzen()

    function _feldFarbe(typ) {
        switch (typ) {
        case "fest":            return "#3d6080"
        case "projekt":         return "#2a5580"
        case "seite":           return "#2a6a48"
        case "datum":           return "#7a5820"
        case "vollkennzeichen": return "#5c2a80"
        case "format":          return "#1e6a78"
        case "logo":            return "#783820"
        default:                return "#3a3a58"
        }
    }
    function _feldBadge(typ) {
        switch (typ) {
        case "fest":            return "T"
        case "projekt":         return "P"
        case "seite":           return "S"
        case "datum":           return "D"
        case "vollkennzeichen": return "K"
        case "format":          return "F"
        case "logo":            return "L"
        default:                return "?"
        }
    }

    // ── Hintergrund ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.theme.surfaceDeep
        MouseArea {
            anchors.fill: parent
            onClicked: root.hintergrundGeklickt()
        }
    }

    // Zoom: Mausrad, zentriert auf Cursor (analog CanvasNavigationHandler)
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 3
            if (delta === 0) return
            root._zoomAt(event.x, event.y, delta > 0 ? 1.12 : (1 / 1.12))
        }
    }

    // Pan: Rechts-/Mittelklick ziehen (analog CanvasNavigationHandler)
    DragHandler {
        target: null
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        property real startX: 0; property real startY: 0
        onActiveChanged: if (active) { startX = root.panX; startY = root.panY }
        onTranslationChanged: {
            root.panX = startX + translation.x
            root.panY = startY + translation.y
        }
    }

    // ── Seite ─────────────────────────────────────────────────
    Rectangle {
        x: root._pageX; y: root._pageY
        width:  root.breiteMm * root._scale
        height: root.hoeheMm  * root._scale
        color:  "#e8eff6"
        border.color: "#5070a0"; border.width: 1
    }

    // ── Raster (10mm, ab genug Zoom zusätzlich 1mm-Feinraster) ──
    Canvas {
        id: gridCanvas
        x: root._pageX; y: root._pageY
        width:  root.breiteMm * root._scale
        height: root.hoeheMm  * root._scale

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var scale = root._scale
            if (scale <= 0 || width <= 0 || height <= 0) return

            var stepFine = 1 * scale
            if (stepFine >= 6) {
                ctx.strokeStyle = "#dbe6f2"
                ctx.lineWidth   = 0.5
                ctx.beginPath()
                for (var fx = stepFine; fx < width;  fx += stepFine) { ctx.moveTo(fx, 0); ctx.lineTo(fx, height) }
                for (var fy = stepFine; fy < height; fy += stepFine) { ctx.moveTo(0, fy); ctx.lineTo(width, fy) }
                ctx.stroke()
            }

            var stepCoarse = 10 * scale
            ctx.strokeStyle = "#a8c0dc"
            ctx.lineWidth   = 0.6
            ctx.beginPath()
            for (var x = stepCoarse; x < width;  x += stepCoarse) { ctx.moveTo(x, 0); ctx.lineTo(x, height) }
            for (var y = stepCoarse; y < height; y += stepCoarse) { ctx.moveTo(0, y); ctx.lineTo(width, y) }
            ctx.stroke()
        }
    }

    // ── Randlinien (gestrichelt) ───────────────────────────────
    Canvas {
        id: randCanvas
        x: root._pageX; y: root._pageY
        width:  root.breiteMm * root._scale
        height: root.hoeheMm  * root._scale

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = "#7090b8"
            ctx.lineWidth   = 0.8
            ctx.setLineDash([5, 4])
            var rl = root.randLinksMm  * root._scale
            var rr = root.randRechtsMm * root._scale
            var ro = root.randObenMm   * root._scale
            var ru = root.randUntenMm  * root._scale
            ctx.strokeRect(rl, ro, width - rl - rr, height - ro - ru)
        }
    }

    // ── Felder ────────────────────────────────────────────────
    Repeater {
        model: root.felder

        delegate: Item {
            id: del
            required property var modelData
            required property int index

            property real _dxMm: 0   // Drag-Offset X (visuell, nicht committed)
            property real _dyMm: 0   // Drag-Offset Y
            property real _dbMm: 0   // Resize-Delta Breite
            property real _dhMm: 0   // Resize-Delta Höhe

            x:      root._pageX + (modelData.xMm + _dxMm) * root._scale
            y:      root._pageY + (modelData.yMm + _dyMm) * root._scale
            width:  (modelData.breiteMm + _dbMm) * root._scale
            height: (modelData.hoeheMm  + _dhMm) * root._scale

            // ── Feld-Rechteck ──────────────────────────────────
            Rectangle {
                anchors.fill: parent
                color:        root._feldFarbe(del.modelData.feldtyp)
                opacity:      del.index === root.selIdx ? 0.88 : 0.60
                border.color: del.index === root.selIdx ? root.theme.accent : root.theme.borderLight
                border.width: del.index === root.selIdx ? 2 : 1
                radius: 2
                clip: true

                Text {
                    anchors { left: parent.left; top: parent.top
                              margins: Math.max(2, parent.height * 0.08) }
                    text:           del.modelData.label || ""
                    color:          "#c4dcf4"
                    font.pixelSize: Math.max(7, Math.min(10, parent.height * 0.28))
                    font.weight:    Font.Medium
                    elide:          Text.ElideRight
                    width:          parent.width - 18
                }

                Rectangle {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
                    width: 14; height: 14; radius: 3
                    color:   Qt.rgba(0, 0, 0, 0.35)
                    visible: parent.width > 22 && parent.height > 18
                    Text {
                        anchors.centerIn: parent
                        text:           root._feldBadge(del.modelData.feldtyp)
                        color:          "white"
                        font.pixelSize: 8
                        font.weight:    Font.Bold
                    }
                }
            }

            // ── Drag-MouseArea ─────────────────────────────────
            MouseArea {
                anchors { fill: parent; rightMargin: 10; bottomMargin: 10 }
                cursorShape: Qt.SizeAllCursor
                preventStealing: true
                property real _sx: 0
                property real _sy: 0
                onPressed: function(mouse) {
                    var gp = mapToItem(null, mouse.x, mouse.y)
                    _sx = gp.x; _sy = gp.y
                    root.feldAngewaehlt(del.index)
                }
                onPositionChanged: function(mouse) {
                    if (!pressed) return
                    var gp = mapToItem(null, mouse.x, mouse.y)
                    del._dxMm = (gp.x - _sx) / root._scale
                    del._dyMm = (gp.y - _sy) / root._scale
                }
                onReleased: function(mouse) {
                    var gp = mapToItem(null, mouse.x, mouse.y)
                    var nx = Math.round(del.modelData.xMm + (gp.x - _sx) / root._scale)
                    var ny = Math.round(del.modelData.yMm + (gp.y - _sy) / root._scale)
                    nx = Math.max(0, Math.min(root.breiteMm - del.modelData.breiteMm, nx))
                    ny = Math.max(0, Math.min(root.hoeheMm  - del.modelData.hoeheMm,  ny))
                    del._dxMm = 0; del._dyMm = 0
                    root.feldVerschoben(del.index, nx, ny)
                }
            }

            // ── Resize-Handle (rechts-unten) ───────────────────
            Rectangle {
                visible:      del.index === root.selIdx
                width: 10; height: 10
                anchors { right: parent.right; bottom: parent.bottom }
                color:        root.theme.accent
                border.color: "white"; border.width: 1
                radius: 2; z: 10

                MouseArea {
                    anchors.fill:    parent
                    cursorShape:     Qt.SizeFDiagCursor
                    preventStealing: true
                    property real _sx: 0; property real _sy: 0
                    property real _b0: 0; property real _h0: 0
                    onPressed: function(mouse) {
                        var gp = mapToItem(null, mouse.x, mouse.y)
                        _sx = gp.x; _sy = gp.y
                        _b0 = del.modelData.breiteMm
                        _h0 = del.modelData.hoeheMm
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed) return
                        var gp  = mapToItem(null, mouse.x, mouse.y)
                        del._dbMm = Math.max(10, Math.round(_b0 + (gp.x - _sx) / root._scale)) - _b0
                        del._dhMm = Math.max(5,  Math.round(_h0 + (gp.y - _sy) / root._scale)) - _h0
                    }
                    onReleased: function(mouse) {
                        root.feldGroesseGeaendert(del.index,
                            del.modelData.breiteMm + del._dbMm,
                            del.modelData.hoeheMm  + del._dhMm)
                        del._dbMm = 0; del._dhMm = 0
                    }
                }
            }
        }
    }

    // ── Leerzustand ───────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: root.felder.length === 0
        text: root.hatVorlage
              ? qsTr("Palette links nutzen um\nFelder hinzuzufügen")
              : qsTr("Zuerst eine Vorlage anlegen (oben links),\ndann können Felder aus der Palette hinzugefügt werden")
        color: root.theme.panelMid; font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Zoom-Anzeige / Einpassen-Button ────────────────────────
    Rectangle {
        anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
        visible: root.hatVorlage
        width: 68; height: 26; radius: 5
        color: zoomMa.containsMouse ? root.theme.hover : Qt.rgba(0, 0, 0, 0.35)
        border.color: root.theme.border; border.width: 1

        Text {
            anchors.centerIn: parent
            text: Math.round(root.zoomFactor * 100) + " %"
            color: "white"; font.pixelSize: 11
        }
        MouseArea {
            id: zoomMa
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root._zoomZuruecksetzen()
        }
        ToolTip.visible: zoomMa.containsMouse
        ToolTip.text: qsTr("Auf Fenster einpassen (Mausrad = Zoom, rechte/mittlere Maustaste ziehen = Verschieben)")
        ToolTip.delay: 500
    }
}
