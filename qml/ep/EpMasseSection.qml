import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  panel.el ? masseCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    Column {
        id: masseCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("MAße") }

        // Linie: X1/Y1, X2/Y2, Länge
        Column {
            width: parent.width; spacing: 0
            visible: panel.el && panel.el.typ === "linie"

            MassField { theme: theme;
                label: "X1"; einheit: "mm"
                wert: panel.el ? +(panel.el.x1 / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) { canvas.eigenschaftAktualisieren("x1", v * canvas.mmToPx) }
            }
            MassField { theme: theme;
                label: "Y1"; einheit: "mm"
                wert: panel.el ? +(panel.el.y1 / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) { canvas.eigenschaftAktualisieren("y1", v * canvas.mmToPx) }
            }
            MassField { theme: theme;
                label: "X2"; einheit: "mm"
                wert: panel.el ? +(panel.el.x2 / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) { canvas.eigenschaftAktualisieren("x2", v * canvas.mmToPx) }
            }
            MassField { theme: theme;
                label: "Y2"; einheit: "mm"
                wert: panel.el ? +(panel.el.y2 / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) { canvas.eigenschaftAktualisieren("y2", v * canvas.mmToPx) }
            }
            MassField { theme: theme;
                label: qsTr("Länge"); einheit: "mm"
                wert: {
                    if (!panel.el) return 0
                    var dx = panel.el.x2 - panel.el.x1
                    var dy = panel.el.y2 - panel.el.y1
                    return +((Math.sqrt(dx*dx + dy*dy) / canvas.mmToPx).toFixed(1))
                }
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var dx = panel.el.x2 - panel.el.x1
                    var dy = panel.el.y2 - panel.el.y1
                    var len = Math.sqrt(dx*dx + dy*dy)
                    var newLen = v * canvas.mmToPx
                    if (len > 0.001)
                        canvas.eigenschaftenSetzen({ x2: panel.el.x1 + (dx/len)*newLen,
                                                     y2: panel.el.y1 + (dy/len)*newLen })
                    else
                        canvas.eigenschaftenSetzen({ x2: panel.el.x1 + newLen, y2: panel.el.y1 })
                }
            }
        }

        // Rechteck: X/Y/Breite/Höhe
        Column {
            width: parent.width; spacing: 0
            visible: panel.el && panel.el.typ === "rechteck"

            MassField { theme: theme;
                label: "X"; einheit: "mm"
                wert: panel.el ? +(Math.min(panel.el.x1, panel.el.x2) / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var w = panel.el.x2 - panel.el.x1
                    canvas.eigenschaftenSetzen({ x1: v * canvas.mmToPx, x2: v * canvas.mmToPx + w })
                }
            }
            MassField { theme: theme;
                label: "Y"; einheit: "mm"
                wert: panel.el ? +(Math.min(panel.el.y1, panel.el.y2) / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var h = panel.el.y2 - panel.el.y1
                    canvas.eigenschaftenSetzen({ y1: v * canvas.mmToPx, y2: v * canvas.mmToPx + h })
                }
            }
            MassField { theme: theme;
                label: qsTr("Breite"); einheit: "mm"
                wert: panel.el ? +(Math.abs(panel.el.x2 - panel.el.x1) / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    canvas.eigenschaftAktualisieren("x2", panel.el.x1 + v * canvas.mmToPx)
                }
            }
            MassField { theme: theme;
                label: qsTr("Höhe"); einheit: "mm"
                wert: panel.el ? +(Math.abs(panel.el.y2 - panel.el.y1) / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    canvas.eigenschaftAktualisieren("y2", panel.el.y1 + v * canvas.mmToPx)
                }
            }
        }

        // Symbol: X/Y/Breite/Höhe (nicht für Querverweis)
        Column {
            width: parent.width; spacing: 0
            visible: panel.el && panel.el.typ === "symbol"
                     && panel.el.symbolId !== "querverweis"

            MassField { theme: theme;
                label: "X"; einheit: "mm"
                wert: panel.el ? +(Math.min(panel.el.x1, panel.el.x2) / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var w = panel.el.x2 - panel.el.x1
                    canvas.eigenschaftenSetzen({ x1: v * canvas.mmToPx, x2: v * canvas.mmToPx + w })
                }
            }
            MassField { theme: theme;
                label: "Y"; einheit: "mm"
                wert: panel.el ? +(Math.min(panel.el.y1, panel.el.y2) / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var h = panel.el.y2 - panel.el.y1
                    canvas.eigenschaftenSetzen({ y1: v * canvas.mmToPx, y2: v * canvas.mmToPx + h })
                }
            }
            MassField { theme: theme;
                label: qsTr("Breite"); einheit: "mm"
                wert: panel.el ? +(Math.abs(panel.el.x2 - panel.el.x1) / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    canvas.eigenschaftAktualisieren("x2", panel.el.x1 + v * canvas.mmToPx)
                }
            }
            MassField { theme: theme;
                label: qsTr("Höhe"); einheit: "mm"
                wert: panel.el ? +(Math.abs(panel.el.y2 - panel.el.y1) / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    canvas.eigenschaftAktualisieren("y2", panel.el.y1 + v * canvas.mmToPx)
                }
            }
        }

        // Text: X/Y Ankerposition
        Column {
            width: parent.width; spacing: 0
            visible: panel.el && panel.el.typ === "text"

            MassField { theme: theme;
                label: "X"; einheit: "mm"
                wert: panel.el ? +(panel.el.x1 / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var w = panel.el.x2 - panel.el.x1
                    canvas.eigenschaftenSetzen({ x1: v * canvas.mmToPx, x2: v * canvas.mmToPx + w })
                }
            }
            MassField { theme: theme;
                label: "Y"; einheit: "mm"
                wert: panel.el ? +(panel.el.y1 / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var h = panel.el.y2 - panel.el.y1
                    canvas.eigenschaftenSetzen({ y1: v * canvas.mmToPx, y2: v * canvas.mmToPx + h })
                }
            }
        }

        // Kreis: Mittelpunkt + Radius
        Column {
            width: parent.width; spacing: 0
            visible: panel.el && panel.el.typ === "kreis"

            MassField { theme: theme;
                label: "X"; einheit: "mm"
                wert: panel.el ? +(panel.el.x1 / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var dx = panel.el.x2 - panel.el.x1
                    var dy = panel.el.y2 - panel.el.y1
                    canvas.eigenschaftenSetzen({ x1: v * canvas.mmToPx, x2: v * canvas.mmToPx + dx, y2: panel.el.y1 + dy })
                }
            }
            MassField { theme: theme;
                label: "Y"; einheit: "mm"
                wert: panel.el ? +(panel.el.y1 / canvas.mmToPx).toFixed(1) : 0
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    var dx = panel.el.x2 - panel.el.x1
                    var dy = panel.el.y2 - panel.el.y1
                    canvas.eigenschaftenSetzen({ y1: v * canvas.mmToPx, x2: panel.el.x1 + dx, y2: v * canvas.mmToPx + dy })
                }
            }
            MassField { theme: theme;
                label: qsTr("Radius"); einheit: "mm"
                wert: {
                    if (!panel.el) return 0
                    var dx = panel.el.x2 - panel.el.x1
                    var dy = panel.el.y2 - panel.el.y1
                    return +((Math.sqrt(dx*dx + dy*dy) / canvas.mmToPx).toFixed(1))
                }
                onWertGeaendert: function(v) {
                    if (!panel.el) return
                    canvas.eigenschaftenSetzen({ x2: panel.el.x1 + v * canvas.mmToPx, y2: panel.el.y1 })
                }
            }
        }
    }
}
