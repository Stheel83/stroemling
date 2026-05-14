import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    required property var canvas
    required property var theme

    signal bildWerkzeugAngefordert()

    width: 48
    color: theme ? theme.surfaceDeep : "#09121e"
    Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: theme ? theme.border : "#1e3a5f" }

    Column {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
        spacing: 4
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "zeiger";       symbol: "↖"; tooltip: qsTr("Zeiger – Auswählen & Verschieben  [V]") }
        Rectangle { width: 32; height: 1; color: root.theme ? root.theme.border : "#1e3a5f"; anchors.horizontalCenter: parent.horizontalCenter }
        Rectangle { width: 32; height: 1; color: root.theme ? root.theme.border : "#1e3a5f"; anchors.horizontalCenter: parent.horizontalCenter }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "linie";         symbol: "╲"; tooltip: qsTr("Linie zeichnen  [L]") }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "polygonlinie";  symbol: "∿"; tooltip: qsTr("Polygonlinie  [P]  (Doppelklick zum Abschließen)") }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "kabellinie";    symbol: "┄"; tooltip: qsTr("Kabeldefinitionslinie  [C]") }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "rechteck";      symbol: "□"; tooltip: qsTr("Rechteck zeichnen  [R]") }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "kreis";         symbol: "○"; tooltip: qsTr("Kreis zeichnen  [K]") }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "geraetekasten"; symbol: "▢"; tooltip: qsTr("Gerätekasten  [G]") }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "strukturkasten";symbol: "☐"; tooltip: qsTr("Strukturkasten  [U]") }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "makrokasten";   symbol: "⬜"; tooltip: qsTr("Makrokasten  [M]") }
        Rectangle { width: 32; height: 1; color: root.theme ? root.theme.border : "#1e3a5f"; anchors.horizontalCenter: parent.horizontalCenter }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "text";  symbol: "T"; tooltip: qsTr("Text platzieren  [T]") }
        WerkzeugButton { canvas: root.canvas; theme: root.theme; werkzeug: "notiz"; symbol: "✎"; tooltip: qsTr("Notiz / Annotation  [N]") }

        Rectangle {
            id: bildWerkzeugBtn
            width: 36; height: 36; radius: 6
            color: root.canvas.aktivesWerkzeug === "bild" ? (root.theme ? root.theme.activeItemAlt : "#1a3a6a")
                 : bildWbMaus.containsMouse               ? (root.theme ? root.theme.hover : "#0f2540") : "transparent"
            border.color: root.canvas.aktivesWerkzeug === "bild" ? (root.theme ? root.theme.accent : "#4a9eff") : "transparent"
            Text {
                anchors.centerIn: parent; text: "🖼"; font.pixelSize: 17
                color: root.canvas.aktivesWerkzeug === "bild" ? (root.theme ? root.theme.accent : "#4a9eff")
                     : bildWbMaus.containsMouse               ? (root.theme ? root.theme.accentLight : "#7aaddd")
                     : (root.theme ? root.theme.panelMid : "#5577aa")
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
}
