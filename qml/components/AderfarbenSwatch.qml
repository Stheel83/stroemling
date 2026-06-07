import QtQuick

// Kleines Farbquadrat für IEC 60757 Aderfarben.
// GNYE (Erdikus/PE) wird mit diagonal-gelben Streifen auf Grün gezeichnet.
// stromlingsName ist für die 5 Netzleiter befüllt, sonst leer.
Item {
    id: root

    property string aderCode: ""

    readonly property string stromlingsName: ({
        "BN": "Brauno – Außenleiter L1",
        "BK": "Schwärzchen – Außenleiter L2",
        "GY": "Grausel – Außenleiter L3",
        "BU": "Blaubertha – Neutralleiter N",
        "GNYE": "Erdikus – Schutzleiter PE"
    })[aderCode] || ""

    // IEC 60757 Farbcodes → Hex
    readonly property string farbe: ({
        "BK": "#222222",
        "BN": "#7B4020",
        "RD": "#CC2000",
        "OG": "#E06000",
        "YE": "#E8C800",
        "GN": "#3BAA35",
        "BU": "#0057A8",
        "VT": "#7B2FBE",
        "GY": "#888888",
        "WH": "#E8E8E8",
        "PK": "#E06090"
    })[aderCode] || ""

    visible: aderCode !== ""

    // CL (transparent / farblos): nur Rahmen
    Rectangle {
        visible: root.aderCode === "CL"
        anchors.fill: parent; radius: 2
        color: "transparent"
        border.color: "#888888"; border.width: 1
    }

    // Einfarbig (alle außer GNYE und CL)
    Rectangle {
        visible: root.farbe !== "" && root.aderCode !== "CL"
        anchors.fill: parent
        radius: 2
        color: root.farbe
        border.color: root.aderCode === "WH" ? "#888888"
                    : Qt.darker(root.farbe, 1.4)
        border.width: 1
    }

    // GNYE: grüner Grund + diagonale gelbe Streifen (wie PE-Isolierung)
    Canvas {
        id: gnyeCanvas
        visible: root.aderCode === "GNYE"
        anchors.fill: parent

        Component.onCompleted: if (visible) requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            ctx.save()
            ctx.beginPath()
            ctx.rect(0, 0, width, height)
            ctx.clip()

            ctx.fillStyle = "#4CAF50"
            ctx.fillRect(0, 0, width, height)

            ctx.fillStyle = "#FFD700"
            var s = Math.max(3, Math.floor(height / 3.5))
            for (var x = -height; x < width + height; x += s * 2) {
                ctx.beginPath()
                ctx.moveTo(x,         height)
                ctx.lineTo(x + height, 0)
                ctx.lineTo(x + height + s, 0)
                ctx.lineTo(x + s,     height)
                ctx.closePath()
                ctx.fill()
            }

            ctx.restore()
            ctx.strokeStyle = "rgba(0,0,0,0.35)"
            ctx.lineWidth   = 1
            ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
        }
    }
}
