import QtQuick

// Kleines Farbquadrat für IEC 60757 Aderfarben. Bei gesetztem aderCode2
// (Bifarb-Ader, z.B. PE = GN+YE oder DIN-47100-Bifarben) werden diagonale
// Streifen in beiden Farben gezeichnet statt einer flächigen Farbe.
// stromlingsName ist für die 5 Netzleiter befüllt, sonst leer.
Item {
    id: root

    property string aderCode:  ""
    property string aderCode2: ""

    readonly property string stromlingsName: ({
        "BN": "Brauno – Außenleiter L1",
        "BK": "Schwärzchen – Außenleiter L2",
        "GY": "Grausel – Außenleiter L3",
        "BU": "Blaubertha – Neutralleiter N"
    })[aderCode] || (aderCode === "GN" && aderCode2 === "YE" ? "Erdikus – Schutzleiter PE" : "")

    // IEC 60757 Farbcodes → Hex
    readonly property var _farbMap: ({
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
    })
    readonly property string farbe:  _farbMap[aderCode]  || ""
    readonly property string farbe2: _farbMap[aderCode2] || ""

    visible: aderCode !== ""

    // CL (transparent / farblos): nur Rahmen
    Rectangle {
        visible: root.aderCode === "CL"
        anchors.fill: parent; radius: 2
        color: "transparent"
        border.color: "#888888"; border.width: 1
    }

    // Einfarbig (kein aderCode2, außer CL)
    Rectangle {
        visible: root.farbe !== "" && root.farbe2 === "" && root.aderCode !== "CL"
        anchors.fill: parent
        radius: 2
        color: root.farbe
        border.color: root.aderCode === "WH" ? "#888888"
                    : Qt.darker(root.farbe, 1.4)
        border.width: 1
    }

    // Bifarb-Ader: diagonale Streifen in farbe/farbe2 (wie zweifarbige Isolierung)
    Canvas {
        id: bifarbCanvas
        visible: root.farbe !== "" && root.farbe2 !== ""
        anchors.fill: parent

        Component.onCompleted: if (visible) requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged:  if (visible) requestPaint()
        onHeightChanged: if (visible) requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            ctx.save()
            ctx.beginPath()
            ctx.rect(0, 0, width, height)
            ctx.clip()

            ctx.fillStyle = root.farbe
            ctx.fillRect(0, 0, width, height)

            ctx.fillStyle = root.farbe2
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
