import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var    panel
    required property var    theme
    required property string colsProp
    property int leftMargin:  12
    property int minColWidth: 40

    // Klick-Sortierung (LISTEN-IDEEN-01): nur Spalten mit cols[i].field sind
    // klickbar. sortFeld/sortAsc kommen von der Tab-Seite (Panel-Sortierstate),
    // spalteKlick meldet den geklickten field-Namen zurück.
    property string sortFeld: ""
    property bool   sortAsc:  true
    signal spalteKlick(string feld)

    readonly property var cols: panel[colsProp]

    Layout.fillWidth: true
    height: 30
    color: theme.tableHeader

    Row {
        anchors { left: parent.left; leftMargin: root.leftMargin; verticalCenter: parent.verticalCenter }

        Repeater {
            // Wichtig: über die Anzahl (Zahl), NICHT über das Array selbst iterieren.
            // Bei model:root.cols würde jede Breitenänderung (Neuzuweisung des Arrays)
            // den Repeater dazu bringen, ALLE Delegates neu zu erstellen — inklusive
            // der gerade aktiven Drag-MouseArea, wodurch der Drag nach jedem Pixel
            // abbricht. Mit einer reinen Zahl als Model bleibt die Spaltenanzahl beim
            // Resizen unverändert, die Delegates bleiben bestehen und nur die
            // Bindungen auf root.cols[index] werten neu aus.
            model: root.cols.length
            delegate: Item {
                width: root.cols[index].w; height: 20

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (index < root.cols.length - 1 ? 6 : 0)
                    text: root.cols[index].header
                          + (root.cols[index].field && root.cols[index].field === root.sortFeld
                             ? (root.sortAsc ? " ▲" : " ▼") : "")
                    font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle
                    elide: Text.ElideRight
                }

                // Klickfläche für Sortierung – lässt rechts Platz für den
                // Resize-Griff (dessen Trefferbereich per margins:-3 übersteht).
                MouseArea {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: Math.max(0, parent.width - 8)
                    visible: !!root.cols[index].field
                    enabled: !!root.cols[index].field
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.spalteKlick(root.cols[index].field)
                }

                // Drag-Griff zum Verändern der Spaltenbreite (verschiebt Breite
                // zwischen dieser und der nächsten Spalte, Gesamtbreite bleibt konstant)
                Rectangle {
                    visible: index < root.cols.length - 1
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: spDragMa.containsMouse || spDragMa.pressed ? root.theme.accent : root.theme.border

                    MouseArea {
                        id: spDragMa
                        anchors { fill: parent; margins: -3 }
                        cursorShape: Qt.SizeHorCursor
                        hoverEnabled: true
                        property real _startX:  0
                        property real _startW0: 0
                        property real _startW1: 0

                        onPressed: (mouse) => {
                            _startX  = mapToItem(null, mouse.x, mouse.y).x
                            _startW0 = root.cols[index].w
                            _startW1 = root.cols[index + 1].w
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed) return
                            var dx    = mapToItem(null, mouse.x, mouse.y).x - _startX
                            var gesamt = _startW0 + _startW1
                            var w0 = Math.max(root.minColWidth,
                                       Math.min(gesamt - root.minColWidth, _startW0 + dx))
                            var w1 = gesamt - w0
                            var arr = root.cols.slice()
                            arr[index]     = Object.assign({}, arr[index],     { w: w0 })
                            arr[index + 1] = Object.assign({}, arr[index + 1], { w: w1 })
                            root.panel[root.colsProp] = arr
                        }
                        onReleased: root.panel.spaltenSpeichern(root.colsProp)
                    }
                }
            }
        }
    }
}
