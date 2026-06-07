import QtQuick 2.15
import "../components"

Canvas {
    id: root

    required property var theme

    property var    klemme:               ({})
    property var    anschluesse:          []
    property var    bruecken:             []
    property bool   debug:                false

    // Aktuell ausgewählter Anschluss – wird farblich markiert
    property string markierteBezeichnung: ""
    // Bezeichnungen neben den Kreisen einblenden (für EigenschaftenPanel)
    property bool   zeigeBezeichnungen:   false
    // Akzentfarbe für markierten Anschluss
    property string akzentFarbe:          theme.accent

    onMarkierteBezeichnungChanged: requestPaint()
    onZeigeBezeichnungenChanged:   requestPaint()
    onThemeChanged:                requestPaint()

    // Layout-Konstanten
    readonly property int _kreisR:   7
    readonly property int _circGap:  6
    readonly property int _bodyW:   28   // Breite des Klemmen-Körpers (horizontal)
    readonly property int _rowH:    26   // Höhe pro Ebene-Reihe
    readonly property int _rowGap:  10   // Abstand zwischen Reihen (für Brücken)
    readonly property int _margin:  16

    // Höhe wächst mit der Ebenenanzahl (Klemmen wachsen nach oben)
    implicitHeight: {
        var ebenen = (klemme && klemme.ebenenAnzahl) ? klemme.ebenenAnzahl : 1
        var pe     = (klemme && klemme.fussKontaktPe) ? 28 : 0
        return Math.max(60, 2 * _margin + ebenen * _rowH
                            + Math.max(0, ebenen - 1) * _rowGap + pe)
    }

    // Breite richtet sich nach Anschluss-Punkten (wird für Hints genutzt)
    implicitWidth: {
        var pA   = (klemme && klemme.punkteSeitenA !== undefined) ? klemme.punkteSeitenA : 1
        var pB   = (klemme && klemme.punkteSeitenB !== undefined) ? klemme.punkteSeitenB : 1
        var aW   = pA > 0 ? pA * 2 * _kreisR + (pA - 1) * _circGap : 0
        var bW   = pB > 0 ? pB * 2 * _kreisR + (pB - 1) * _circGap : 0
        var lblA = (pA > 0 && root.zeigeBezeichnungen) ? 24 : 0
        var lblB = (pB > 0 && root.zeigeBezeichnungen) ? 24 : 0
        return 2 * _margin + lblA + aW + _bodyW + bW + lblB
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
        var pA      = (klemme.punkteSeitenA !== undefined) ? klemme.punkteSeitenA : 1
        var pB      = (klemme.punkteSeitenB !== undefined) ? klemme.punkteSeitenB : 1
        var hatPe   = klemme.fussKontaktPe     || false
        var hatSteg = klemme.stegbrueckeFaehig || false

        var kreisR  = _kreisR
        var circGap = _circGap
        var bodyW   = _bodyW
        var rowH    = _rowH
        var rowGap  = _rowGap
        var margin  = _margin

        var showLbl = root.zeigeBezeichnungen
        var marked  = root.markierteBezeichnung || ""
        var akzent  = root.akzentFarbe

        // Bezeichnung eines Anschluss-Kreises (unverändert gegenüber Original)
        function bezFuer(ebene1, pA2, seiteA, kreisIdx) {
            var idx = seiteA ? (1 + kreisIdx) : (pA2 + 1 + kreisIdx)
            return ebene1 + "." + idx
        }

        // ── Horizontale Positionen ────────────────────────────────────────
        // Seite-A-Kreise links, Seite-B-Kreise rechts vom Körper.
        // a=0 ist der äußerste linke Kreis (war oben), a=pA-1 körpernächster.
        // b=0 ist der körpernächste rechte Kreis, b=pB-1 äußerster rechts.
        var aWidth   = pA > 0 ? pA * (2 * kreisR) + (pA - 1) * circGap : 0
        var bWidth   = pB > 0 ? pB * (2 * kreisR) + (pB - 1) * circGap : 0
        var lblExtraA = (showLbl && pA > 0) ? 24 : 0
        var lblExtraB = (showLbl && pB > 0) ? 24 : 0

        // Zeichnung horizontal zentrieren
        var totalLogW = lblExtraA + aWidth + bodyW + bWidth + lblExtraB
        var startX    = (width - totalLogW) / 2

        var bodyLeftX  = startX + lblExtraA + aWidth
        var bodyRightX = bodyLeftX + bodyW
        var busX       = (bodyLeftX + bodyRightX) / 2

        // Kreis-X für Seite A (a=0 = linkster = äußerster)
        function axFuer(a) {
            return bodyLeftX - aWidth + kreisR + a * (2 * kreisR + circGap)
        }
        // Kreis-X für Seite B (b=0 = körpernächster)
        function bxFuer(b) {
            return bodyRightX + kreisR + b * (2 * kreisR + circGap)
        }

        // ── Vertikale Positionen (Ebene 1 unten, Ebene N oben) ───────────
        var peH    = hatPe ? 28 : 0
        var startY = height - margin - peH - rowH / 2   // Mitte der untersten Reihe

        function cyFuer(e) {   // e = 0-basierter Ebenen-Index
            return startY - e * (rowH + rowGap)
        }

        // Linke / rechte Endpunkte der waagerechten Durchgangslinie
        var lineLeftX  = pA > 0 ? axFuer(0)      : bodyLeftX
        var lineRightX = pB > 0 ? bxFuer(pB - 1) : bodyRightX

        // ── Jede Ebene zeichnen ───────────────────────────────────────────
        for (var e = 0; e < ebenen; ++e) {
            var cy = cyFuer(e)

            // Waagerechte Durchgangslinie A → Körper → B
            ctx.beginPath()
            ctx.moveTo(lineLeftX, cy)
            ctx.lineTo(lineRightX, cy)
            ctx.strokeStyle = "#cccccc"
            ctx.lineWidth   = 1.5
            ctx.stroke()

            // Kleiner senkrechter Tick = Klemmen-Körper
            var tickH = 5
            ctx.beginPath()
            ctx.moveTo(busX, cy - tickH)
            ctx.lineTo(busX, cy + tickH)
            ctx.strokeStyle = "#888888"
            ctx.lineWidth   = 2
            ctx.stroke()

            // ── Seite-A-Kreise (links vom Körper) ────────────────────────
            for (var a = 0; a < pA; ++a) {
                var ax   = axFuer(a)
                var bezA = bezFuer(e + 1, pA, true, a)
                var markA = (bezA === marked)

                ctx.beginPath()
                ctx.arc(ax, cy, kreisR, 0, 2 * Math.PI)
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
                    ctx.font         = "8px sans-serif"
                    ctx.textAlign    = "right"
                    ctx.textBaseline = "middle"
                    ctx.fillStyle    = markA ? akzent : "#999999"
                    ctx.fillText(bezA, ax - kreisR - 2, cy)
                }
            }

            // ── Seite-B-Kreise (rechts vom Körper) ───────────────────────
            for (var b = 0; b < pB; ++b) {
                var bx   = bxFuer(b)
                var bezB = bezFuer(e + 1, pA, false, b)
                var markB = (bezB === marked)

                ctx.beginPath()
                ctx.arc(bx, cy, kreisR, 0, 2 * Math.PI)
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
                    ctx.font         = "8px sans-serif"
                    ctx.textAlign    = "left"
                    ctx.textBaseline = "middle"
                    ctx.fillStyle    = markB ? akzent : "#999999"
                    ctx.fillText(bezB, bx + kreisR + 2, cy)
                }
            }

            // ── Steg-Kontakt-Indikator ────────────────────────────────────
            if (hatSteg) {
                ctx.beginPath()
                ctx.arc(busX, cy, 3.5, 0, 2 * Math.PI)
                ctx.fillStyle = akzent
                ctx.fill()
            }

            // ── Brücke zur nächsten Ebene (senkrechte Linie zwischen Reihen)
            for (var br = 0; br < bruecken.length; ++br) {
                var von  = bruecken[br].vonEbene  - 1
                var nach = bruecken[br].nachEbene - 1
                if (von === e && nach === e + 1) {
                    var brkY1 = cy - rowH / 2              // Oberkante dieser Reihe
                    var brkY2 = cyFuer(e + 1) + rowH / 2  // Unterkante der nächsten
                    ctx.beginPath()
                    ctx.moveTo(busX, brkY1)
                    ctx.lineTo(busX, brkY2)
                    ctx.strokeStyle = "#5dba7d"
                    ctx.lineWidth   = 3
                    ctx.stroke()
                }
            }
        }

        // ── PE-Fusskontakt (unterhalb von Ebene 1) ────────────────────────
        if (hatPe) {
            var peMarkiert = (marked === "PE")
            var peX  = busX
            var peY0 = startY + rowH / 2   // Unterkante der Ebene-1-Reihe
            var peY1 = peY0 + 4
            var peY2 = peY1 + 14
            var peFarbe = peMarkiert ? akzent : "#4caf50"

            ctx.beginPath()
            ctx.moveTo(peX, peY0)
            ctx.lineTo(peX, peY1)
            ctx.strokeStyle = peFarbe
            ctx.lineWidth   = 1.5
            ctx.stroke()

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

    DebugLabel { panelName: qsTr("Klemmen-Vorschau"); corner: "tr"; visible: root.debug }
}
