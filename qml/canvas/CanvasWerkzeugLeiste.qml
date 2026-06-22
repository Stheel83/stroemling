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

    Column {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
        spacing: 4
        WerkzeugButton { canvas: root.canvas; werkzeug: "zeiger";        symbol: "↖"; tooltip: qsTr("Zeiger – Auswählen & Verschieben  [V]") }
        Rectangle { width: 32; height: 1; color: AppTheme.border; anchors.horizontalCenter: parent.horizontalCenter }
        Rectangle { width: 32; height: 1; color: AppTheme.border; anchors.horizontalCenter: parent.horizontalCenter }
        WerkzeugButton { canvas: root.canvas; werkzeug: "linie";          symbol: "╲"; tooltip: qsTr("Linie zeichnen  [L]") }
        WerkzeugButton { canvas: root.canvas; werkzeug: "polygonlinie";   symbol: "∿"; tooltip: qsTr("Polygonlinie  [P]  (Doppelklick zum Abschließen)") }
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

    DebugLabel { panelName: qsTr("Canvas-Werkzeuge"); visible: canvas.debug }
}
