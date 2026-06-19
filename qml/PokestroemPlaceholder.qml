import QtQuick

Item {
    id: root
    property var theme: null

    readonly property color _textPri: root.theme ? root.theme.textPrimary : "#e8f4f8"
    readonly property color _textMut: root.theme ? root.theme.textMuted   : "#8090a0"

    // Auf-ab-Schaukeln
    property real bobOffset: 0
    SequentialAnimation on bobOffset {
        running: root.visible
        loops:   Animation.Infinite
        NumberAnimation { to:  8; duration: 950; easing.type: Easing.InOutSine }
        NumberAnimation { to: -8; duration: 950; easing.type: Easing.InOutSine }
    }

    // ── Grüner Fisch ────────────────────────────────────────────────────
    Image {
        id: fishImage
        width: 140; height: 100
        y: Math.max(6, root.height * 0.28 - 50) + root.bobOffset
        source: "qrc:/assets/stroemling_logo.png"
        fillMode: Image.PreserveAspectFit
        smooth: false
        mirror: true

        // Schwimmt von links nach rechts (endlos)
        NumberAnimation on x {
            running: root.visible
            from:    -fishImage.width
            to:      root.width
            duration: 11000
            loops:   Animation.Infinite
            easing.type: Easing.Linear
        }
    }

    // ── Willkommenstext ──────────────────────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top
        anchors.topMargin:        Math.max(160, parent.height * 0.56)
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
