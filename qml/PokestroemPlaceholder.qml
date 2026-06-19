import QtQuick

Item {
    id: root
    property var theme: null

    readonly property color _textPri: root.theme ? root.theme.textPrimary : "#e8f4f8"
    readonly property color _textMut: root.theme ? root.theme.textMuted   : "#8090a0"

    readonly property real _textTopMargin: Math.max(160, root.height * 0.56)

    // Auf-ab-Schaukeln
    property real bobOffset: 0
    SequentialAnimation on bobOffset {
        running: root.visible
        loops:   Animation.Infinite
        NumberAnimation { to:  8; duration: 950; easing.type: Easing.InOutSine }
        NumberAnimation { to: -8; duration: 950; easing.type: Easing.InOutSine }
    }

    // ── Grüner Fisch ────────────────────────────────────────────────────
    // Schwimmt von links nach rechts, bei jeder Runde neue Höhe + Tempo.
    // from/to/duration werden erst beim Start jeder Runde aus den aktuellen
    // root.width/height gelesen (nicht live gebunden) – sonst stockt die
    // erste Runde, weil root.width bei anchors.fill erst nach dem ersten
    // Layout-Durchlauf den echten Wert hat (Animation würde mittendrin neu
    // zum geänderten "to" springen).
    property real _swimY: 6

    Image {
        id: fishImage
        width: 140; height: 100
        y: root._swimY + root.bobOffset
        source: "qrc:/assets/stroemling_logo.png"
        fillMode: Image.PreserveAspectFit
        smooth: false
        mirror: true   // wird pro Runde in _naechsteRunde() passend zur Schwimmrichtung gesetzt
    }

    NumberAnimation {
        id: swimAnim
        target:   fishImage
        property: "x"
        easing.type: Easing.Linear
        onStopped: if (root.visible) root._naechsteRunde()
    }

    function _naechsteRunde() {
        if (root.width <= 0 || root.height <= 0) {
            Qt.callLater(root._naechsteRunde)
            return
        }
        var maxY = Math.max(6, root._textTopMargin - fishImage.height - 20)
        root._swimY = 6 + Math.random() * Math.max(0, maxY - 6)

        // Zufällige Richtung: Bild zeigt nativ nach links, daher mirror=true
        // wenn nach rechts geschwommen wird (und umgekehrt).
        var vonLinks = Math.random() < 0.5
        fishImage.mirror  = vonLinks
        swimAnim.from     = vonLinks ? -fishImage.width : root.width
        swimAnim.to       = vonLinks ? root.width        : -fishImage.width
        swimAnim.duration = 9000 + Math.random() * 4000   // 9–13 s, leichte Tempo-Variation
        swimAnim.start()
    }

    onVisibleChanged: if (root.visible) root._naechsteRunde(); else swimAnim.stop()
    Component.onCompleted: if (root.visible) Qt.callLater(root._naechsteRunde)

    // ── Willkommenstext ──────────────────────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top
        anchors.topMargin:        root._textTopMargin
        spacing: 7

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:            "Willkommen bei Strömling Design"
            font.pixelSize:  18
            font.weight:     Font.Light
            color:           root._textPri
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:            "Seite im linken Baum anklicken, um den Schaltplan zu öffnen."
            font.pixelSize:  12
            color:           root._textMut
        }
    }
}
