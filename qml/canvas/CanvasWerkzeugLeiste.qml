import QtQuick
import QtQuick.Controls
import stroemling
import "../components"

Rectangle {
    id: root
    required property var canvas

    signal bildWerkzeugAngefordert()

    width: 48
    color: AppTheme.surfaceDeep
    Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: AppTheme.border }

    // Direktzugriff auf die drei meistgenutzten "Verbindungen"-Symbole aus der
    // Symbolpalette (SYM-WKZLEISTE-VERBINDUNGEN-01) – erspart bei Winkel/Treffpunkt
    // den Kategorie-Drill-Down für die erste Platzierung pro Sitzung. Zeichnet die
    // echte Symbolform (wie SymbolPalette.qml SymbolZeile-Vorschau), keine geratene
    // Unicode-Glyphe. Aktivierung repliziert exakt Main.qml onSymbolGewaehlt.
    component VerbindungWerkzeugButton: Rectangle {
        id: vwRoot
        required property var canvas
        property string symbolId: ""
        property string tooltip: ""
        readonly property bool aktiv: canvas.aktivesWerkzeug === "symbol" && canvas.paletteSymbolId === symbolId

        width: 36; height: 36; radius: 6
        color:        aktiv ? AppTheme.activeItemAlt : vwMa.containsMouse ? AppTheme.hover : "transparent"
        border.color: aktiv ? AppTheme.accent : "transparent"

        Canvas {
            id: vwVorschau
            anchors.centerIn: parent
            width: 26; height: 26
            property string c: vwRoot.aktiv ? AppTheme.accent : vwMa.containsMouse ? AppTheme.accentLight : AppTheme.panelMid
            onCChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = c
                ctx.lineWidth   = 1.5
                var prims = symbolDefinitionModel.primitiveFuerSymbol(vwRoot.symbolId)
                // Einheitlicher Skalierungsfaktor (nicht getrennt w/h) wie in
                // SymbolPalette.qml SymbolZeile – verzerrt Kreise/Bögen nicht.
                var scale = Math.min(width, height) * 0.8
                var offX  = (width - scale) / 2
                var offY  = (height - scale) / 2
                function sx(nx) { return nx * scale + offX }
                function sy(ny) { return ny * scale + offY }
                for (var i = 0; i < prims.length; i++) {
                    var p = prims[i]
                    switch (p.typ) {
                        case "linie":
                            ctx.beginPath(); ctx.moveTo(sx(p.x1), sy(p.y1)); ctx.lineTo(sx(p.x2), sy(p.y2)); ctx.stroke()
                            break
                        case "bogen":
                            ctx.beginPath()
                            ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale,
                                    p.winkel_von * Math.PI / 180, p.winkel_bis * Math.PI / 180,
                                    p.bogen_gegen_uhrzeiger)
                            ctx.stroke()
                            break
                        case "kreis_offen":
                            ctx.beginPath(); ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale, 0, 2 * Math.PI); ctx.stroke()
                            break
                        case "kreis_gefuellt":
                            ctx.save(); ctx.fillStyle = ctx.strokeStyle
                            ctx.beginPath(); ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale, 0, 2 * Math.PI); ctx.fill()
                            ctx.restore()
                            break
                    }
                }
            }
        }
        MouseArea {
            id: vwMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                vwRoot.canvas.paletteSymbolId = vwRoot.symbolId
                vwRoot.canvas.aktivesWerkzeug = "symbol"
                vwRoot.canvas.forceActiveFocus()
            }
        }
        ToolTip.visible: vwMa.containsMouse
        ToolTip.text:    vwRoot.tooltip
        ToolTip.delay:   500
    }

    Column {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
        spacing: 4
        WerkzeugButton { canvas: root.canvas; werkzeug: "zeiger";        symbol: "↖"; tooltip: qsTr("Zeiger – Auswählen & Verschieben  [V]") }
        Rectangle { width: 32; height: 1; color: AppTheme.border; anchors.horizontalCenter: parent.horizontalCenter }
        Rectangle { width: 32; height: 1; color: AppTheme.border; anchors.horizontalCenter: parent.horizontalCenter }
        WerkzeugButton { canvas: root.canvas; werkzeug: "linie";          symbol: "╲"; tooltip: qsTr("Linie zeichnen  [L]") }
        WerkzeugButton { canvas: root.canvas; werkzeug: "polygonlinie";   symbol: "∿"; tooltip: qsTr("Polygonlinie  [P]  (Doppelklick zum Abschließen)") }
        VerbindungWerkzeugButton { canvas: root.canvas; symbolId: "winkel";       tooltip: qsTr("Winkel (Verbindungsecke)") }
        VerbindungWerkzeugButton { canvas: root.canvas; symbolId: "treffpunkt";   tooltip: qsTr("Treffpunkt T (Verbindungspunkt)") }
        VerbindungWerkzeugButton { canvas: root.canvas; symbolId: "treffpunkt_l"; tooltip: qsTr("Treffpunkt L (Verbindungspunkt)") }
        // Kabeldefinitionslinie – Mini-Canvas statt Unicode-Zeichen
        Rectangle {
            id: kbBtn
            width: 36; height: 36; radius: 6
            color: root.canvas.aktivesWerkzeug === "kabellinie" ? AppTheme.activeItemAlt
                 : kbMa.containsMouse ? AppTheme.hover : "transparent"
            border.color: root.canvas.aktivesWerkzeug === "kabellinie" ? AppTheme.accent : "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            Canvas {
                anchors.centerIn: parent; width: 22; height: 10
                property string c: root.canvas.aktivesWerkzeug === "kabellinie" ? AppTheme.accent
                                 : kbMa.containsMouse ? AppTheme.accentLight : AppTheme.panelMid
                onCChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = c; ctx.lineWidth = 2
                    ctx.setLineDash([3, 3])
                    ctx.beginPath(); ctx.moveTo(3, 5); ctx.lineTo(19, 5); ctx.stroke()
                    ctx.setLineDash([])
                    ctx.fillStyle = c
                    ctx.beginPath(); ctx.arc(3, 5, 2.5, 0, 2 * Math.PI); ctx.fill()
                    ctx.beginPath(); ctx.arc(19, 5, 2.5, 0, 2 * Math.PI); ctx.fill()
                }
            }
            MouseArea {
                id: kbMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.canvas.aktivesWerkzeug = "kabellinie"
            }
            ToolTip.visible: kbMa.containsMouse
            ToolTip.text:    qsTr("Kabeldefinitionslinie  [C]")
            ToolTip.delay:   500
        }
        WerkzeugButton { canvas: root.canvas; werkzeug: "rechteck";       symbol: "□"; tooltip: qsTr("Rechteck zeichnen  [R]") }
        WerkzeugButton { canvas: root.canvas; werkzeug: "kreis";          symbol: "○"; tooltip: qsTr("Kreis zeichnen  [K]") }
        WerkzeugButton { canvas: root.canvas; werkzeug: "geraetekasten";  symbol: "⊡"; tooltip: qsTr("Gerätekasten  [G]") }
        WerkzeugButton { canvas: root.canvas; werkzeug: "strukturkasten"; symbol: "☐"; tooltip: qsTr("Strukturkasten  [U]") }
        WerkzeugButton { canvas: root.canvas; werkzeug: "makrokasten";    symbol: "⬜"; tooltip: qsTr("Makrokasten  [M]") }
        WerkzeugButton { canvas: root.canvas; werkzeug: "schirm";        symbol: "⬭"; tooltip: qsTr("Schirm-Oval  [O]") }
        Rectangle { width: 32; height: 1; color: AppTheme.border; anchors.horizontalCenter: parent.horizontalCenter }
        WerkzeugButton { canvas: root.canvas; werkzeug: "text";  symbol: "T"; tooltip: qsTr("Text platzieren  [T]") }
        WerkzeugButton { canvas: root.canvas; werkzeug: "notiz"; symbol: "✎"; tooltip: qsTr("Notiz / Annotation  [N]") }

        Rectangle {
            id: bildWerkzeugBtn
            width: 36; height: 36; radius: 6
            color: root.canvas.aktivesWerkzeug === "bild" ? AppTheme.activeItemAlt
                 : bildWbMaus.containsMouse               ? AppTheme.hover : "transparent"
            border.color: root.canvas.aktivesWerkzeug === "bild" ? AppTheme.accent : "transparent"
            Text {
                anchors.centerIn: parent; text: "🖼"; font.pixelSize: 17
                color: root.canvas.aktivesWerkzeug === "bild" ? AppTheme.accent
                     : bildWbMaus.containsMouse               ? AppTheme.accentLight
                     : AppTheme.panelMid
            }
            MouseArea {
                id: bildWbMaus; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.canvas.abbruch()
                    root.canvas.paletteImageData = ""
                    root.bildWerkzeugAngefordert()
                }
            }
            ToolTip.visible: bildWbMaus.containsMouse
            ToolTip.text:    qsTr("Bild einfügen")
            ToolTip.delay:   500
        }
    }

    DebugLabel { panelName: qsTr("Canvas-Werkzeuge"); corner: "bl"; visible: canvas.debug }
}
