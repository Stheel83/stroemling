import QtQuick 2.15
import "../components"

Canvas {
    id: root

    required property var theme

    property var    klemme:               ({})
    property var    anschluesse:          []
    property var    bruecken:             []
    property bool   debug:                false

    // Aktuell ausgewählter Anschluss (z.B. "1.1", "1.2", "PE") – wird farblich markiert
    property string markierteBezeichnung: ""
    // Bezeichnungen neben den Kreisen einblenden (für EigenschaftenPanel)
    property bool   zeigeBezeichnungen:   false
    // Akzentfarbe für markierten Anschluss
    property string akzentFarbe:          theme.accent

    onMarkierteBezeichnungChanged: requestPaint()
    onZeigeBezeichnungenChanged:   requestPaint()
    onThemeChanged:                requestPaint()

    // Layout-Konstanten (spiegeln sich in implicitHeight)
    readonly property int _kreisR:   7
    readonly property int _circGap:  6
    readonly property int _bodyH:   28
    readonly property int _margin:  16

    // Höhe passt sich dynamisch an pA / pB an
    implicitHeight: {
        var pA = (klemme && klemme.punkteSeitenA) ? klemme.punkteSeitenA : 1
        var pB = (klemme && klemme.punkteSeitenB) ? klemme.punkteSeitenB : 1
        var pe = (klemme && klemme.fussKontaktPe) ? 38 : 0
        var topH = pA * 2 * _kreisR + (pA - 1) * _circGap
        var botH = pB * 2 * _kreisR + (pB - 1) * _circGap
        return Math.max(100, 2 * _margin + topH + _bodyH + botH + pe)
    }

    onKlemmeChanged:      requestPaint()
    onAnschluesseChanged: requestPaint()
    onBrueckenChanged:    requestPaint()
    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        if (!klemme || !klemme.ebenenAnzahl) return

        var ebenen  = klemme.ebenenAnzahl  || 1
        var pA      = klemme.punkteSeitenA || 1
        var pB      = klemme.punkteSeitenB || 1
        var hatPe   = klemme.fussKontaktPe || false
        var hatSteg = klemme.stegbrueckeFaehig || false

        var kreisR  = _kreisR
        var circGap = _circGap
        var bodyH   = _bodyH
        var margin  = _margin

        // ── Vertikale Positionen (absolut, nicht skaliert) ───────────────
        // Seite-A-Kreise von oben gestapelt
        var aStartY = margin + kreisR
        var aEndY   = aStartY + (pA - 1) * (2 * kreisR + circGap)

        // Seite-B-Kreise direkt nach dem Körper-Abschnitt
        var bStartY = aEndY + kreisR + bodyH + kreisR
        var bEndY   = bStartY + (pB - 1) * (2 * kreisR + circGap)

        // Mittelpunkt des Körpers (für Brücken-Verbindung und Steg-Indikator)
        var busY = aEndY + kreisR + bodyH / 2

        // ── Horizontales Layout und Skalierung ───────────────────────────
        var colW  = 28    // Breite pro Ebene
        var ebGap = 20    // Lücke zwischen Ebenen (Brückenbalken)
        var logW  = ebenen * colW + (ebenen - 1) * ebGap
        var scale = Math.min(1.0, (width - 2 * margin) / Math.max(logW, 1))
        var totalW = logW * scale
        var startX = (width - totalW) / 2

        var marked = root.markierteBezeichnung || ""
        var showLbl = root.zeigeBezeichnungen
        var akzent  = root.akzentFarbe

        // Hilfsfunktion: Bezeichnung für einen Kreis berechnen
        function bezFuer(ebene1, pA2, seiteA, kreisIdx) {
            var idx = seiteA ? (1 + kreisIdx) : (pA2 + 1 + kreisIdx)
            return ebene1 + "." + idx
        }

        for (var e = 0; e < ebenen; ++e) {
            var cx = startX + (e * (colW + ebGap) + colW / 2) * scale

            // ── Durchgehende senkrechte Linie A→B ───────────────────────
            ctx.beginPath()
            ctx.moveTo(cx, aStartY)
            ctx.lineTo(cx, bEndY)
            ctx.strokeStyle = "#cccccc"
            ctx.lineWidth   = 1.5
            ctx.stroke()

            // ── Kleiner waagerechter Tick in der Mitte (Klemmen-Körper) ─
            var tickW = 5 * scale
            ctx.beginPath()
            ctx.moveTo(cx - tickW, busY)
            ctx.lineTo(cx + tickW, busY)
            ctx.strokeStyle = "#888888"
            ctx.lineWidth   = 2
            ctx.stroke()

            // ── Seite-A-Kreise (übereinander) ───────────────────────────
            for (var a = 0; a < pA; ++a) {
                var ay      = aStartY + a * (2 * kreisR + circGap)
                var bezA    = bezFuer(e + 1, pA, true, a)
                var markA   = (bezA === marked)

                ctx.beginPath()
                ctx.arc(cx, ay, kreisR, 0, 2 * Math.PI)
                if (markA) {
                    ctx.fillStyle   = akzent
                    ctx.fill()
                    ctx.strokeStyle = akzent
                } else {
                    ctx.strokeStyle = "#cccccc"
                }
                ctx.lineWidth = markA ? 2 : 1.5
                ctx.stroke()

                if (showLbl) {
                    ctx.font          = "8px sans-serif"
                    ctx.textAlign     = "left"
                    ctx.textBaseline  = "middle"
                    ctx.fillStyle     = markA ? akzent : "#999999"
                    ctx.fillText(bezA, cx + kreisR + 3, ay)
                }
            }

            // ── Seite-B-Kreise (übereinander) ───────────────────────────
            for (var b = 0; b < pB; ++b) {
                var by      = bStartY + b * (2 * kreisR + circGap)
                var bezB    = bezFuer(e + 1, pA, false, b)
                var markB   = (bezB === marked)

                ctx.beginPath()
                ctx.arc(cx, by, kreisR, 0, 2 * Math.PI)
                if (markB) {
                    ctx.fillStyle   = akzent
                    ctx.fill()
                    ctx.strokeStyle = akzent
                } else {
                    ctx.strokeStyle = "#cccccc"
                }
                ctx.lineWidth = markB ? 2 : 1.5
                ctx.stroke()

                if (showLbl) {
                    ctx.font          = "8px sans-serif"
                    ctx.textAlign     = "left"
                    ctx.textBaseline  = "middle"
                    ctx.fillStyle     = markB ? akzent : "#999999"
                    ctx.fillText(bezB, cx + kreisR + 3, by)
                }
            }

            // ── Steg-Kontakt-Indikator (gefüllter Punkt auf busY) ───────
            if (hatSteg) {
                ctx.beginPath()
                ctx.arc(cx, busY, 3.5, 0, 2 * Math.PI)
                ctx.fillStyle = akzentFarbe
                ctx.fill()
            }

            // ── Brücke zur nächsten Ebene ────────────────────────────────
            for (var br = 0; br < bruecken.length; ++br) {
                var von  = bruecken[br].vonEbene  - 1
                var nach = bruecken[br].nachEbene - 1
                if (von === e && nach === e + 1) {
                    var brkX1 = startX + (e * (colW + ebGap) + colW) * scale
                    var brkX2 = startX + (e * (colW + ebGap) + colW + ebGap) * scale
                    ctx.beginPath()
                    ctx.moveTo(brkX1, busY)
                    ctx.lineTo(brkX2, busY)
                    ctx.strokeStyle = "#5dba7d"
                    ctx.lineWidth   = 3
                    ctx.stroke()
                }
            }
        }

        // ── PE-Fusskontakt ───────────────────────────────────────────────
        if (hatPe) {
            var peMarkiert = (marked === "PE")
            var peX  = startX + totalW / 2
            var peY1 = bEndY + kreisR + 4
            var peY2 = peY1 + 18
            var peFarbe = peMarkiert ? akzent : "#4caf50"
            ctx.beginPath()
            ctx.moveTo(peX, peY1)
            ctx.lineTo(peX, peY2)
            ctx.strokeStyle = peFarbe
            ctx.lineWidth   = 2
            ctx.stroke()
            for (var pl = 0; pl < 3; ++pl) {
                var pw = 9 - pl * 3
                ctx.beginPath()
                ctx.moveTo(peX - pw, peY2 + pl * 5)
                ctx.lineTo(peX + pw, peY2 + pl * 5)
                ctx.strokeStyle = peFarbe
                ctx.lineWidth   = 1.5
                ctx.stroke()
            }
            if (showLbl) {
                ctx.font         = "8px sans-serif"
                ctx.textAlign    = "left"
                ctx.textBaseline = "middle"
                ctx.fillStyle    = peFarbe
                ctx.fillText("PE", peX + 12, peY1 + (peY2 - peY1) / 2)
            }
        }
    }

    DebugLabel { panelName: qsTr("Klemmen-Vorschau"); visible: root.debug }
}
