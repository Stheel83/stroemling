import QtQuick 2.15

Item {
    id: root

    required property var  theme
    required property real zoom
    required property real worldX
    required property real worldY
    required property real canvasWidth
    required property real canvasHeight
    required property var  normblattDaten
    required property real mmToPx

    signal panRequest(real newWorldX, real newWorldY)

    readonly property real pagePxW: normblattDaten ? (normblattDaten.breiteMm || 297) * mmToPx : 297 * mmToPx
    readonly property real pagePxH: normblattDaten ? (normblattDaten.hoeheMm  || 210) * mmToPx : 210 * mmToPx
    readonly property real mapW:    180
    readonly property real scale:   mapW / pagePxW
    readonly property real mapH:    pagePxH * scale

    // Viewport-Rechteck in Minimap-Koordinaten (geclipt auf Seitengrenzen)
    readonly property real vpRaw:  (-worldX / zoom) * scale
    readonly property real vpTop:  (-worldY / zoom) * scale
    readonly property real vpWRaw: (canvasWidth  / zoom) * scale
    readonly property real vpHRaw: (canvasHeight / zoom) * scale

    readonly property real vpX: Math.max(0, vpRaw)
    readonly property real vpY: Math.max(0, vpTop)
    readonly property real vpW: Math.min(vpWRaw + Math.min(0, vpRaw), mapW - Math.max(0, vpRaw))
    readonly property real vpH: Math.min(vpHRaw + Math.min(0, vpTop), mapH - Math.max(0, vpTop))

    width:  mapW + 2
    height: mapH + 2

    Rectangle {
        anchors.fill: parent
        color:        Qt.rgba(0.04, 0.07, 0.14, 0.88)
        border.color: root.theme.border
        border.width: 1
        radius:       4

        // Seitenrahmen
        Rectangle {
            x: 1; y: 1
            width:  root.mapW
            height: root.mapH
            color:        "transparent"
            border.color: root.theme.textMuted
            border.width: 1
        }

        // Viewport-Indikator
        Rectangle {
            x: 1 + root.vpX
            y: 1 + root.vpY
            width:  Math.max(2, root.vpW)
            height: Math.max(2, root.vpH)
            color:        Qt.rgba(0.2, 0.6, 1.0, 0.20)
            border.color: root.theme.accent
            border.width: 1
        }

        // Klick → Canvas zentrieren auf geklickten Punkt
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                var cx = mouse.x - 1
                var cy = mouse.y - 1
                var cpx = cx / root.scale
                var cpy = cy / root.scale
                root.panRequest(
                    -(cpx * root.zoom) + root.canvasWidth  / 2,
                    -(cpy * root.zoom) + root.canvasHeight / 2
                )
            }
        }
    }
}
