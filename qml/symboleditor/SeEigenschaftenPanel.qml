import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    required property var editor

    width: 210
    color: editor.theme.sidebar
    clip:  true

    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: {
                if (editor.ausgewaehltPrimIdx >= 0) {
                    var p = editor.primitive[editor.ausgewaehltPrimIdx]
                    return p ? qsTr("Primitiv: ") + p.typ : qsTr("—")
                }
                if (editor.ausgewaehltPinIdx >= 0) return qsTr("Pin ausgewählt")
                return qsTr("Kein Element")
            }
            font.pixelSize: 12; font.weight: Font.Medium
            color: editor.theme.textPrimary; wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: editor.theme.border }

        // Koordinaten-Felder für ausgewähltes Primitiv
        Repeater {
            model: {
                if (editor.ausgewaehltPrimIdx < 0) return []
                var p2 = editor.primitive[editor.ausgewaehltPrimIdx]
                if (!p2) return []
                switch (p2.typ) {
                case "linie":             return ["x1","y1","x2","y2"]
                case "rechteck":          return ["x1","y1","x2","y2"]
                case "kreis_offen":
                case "kreis_gefuellt":    return ["x1","y1","radius"]
                case "bogen":             return ["x1","y1","radius","winkel_von","winkel_bis"]
                case "text":              return ["x1","y1","schrift_relativ"]
                case "dreieck_gefuellt":  return ["x1","y1","x2","y2","x3","y3"]
                default: return []
                }
            }
            delegate: RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text {
                    text: {
                        var angFelder = ["winkel_von","winkel_bis"]
                        if (editor.istPositionsfeld(modelData)) return modelData + " (mm):"
                        if (angFelder.indexOf(modelData) >= 0)  return modelData + " (°):"
                        return modelData + ":"
                    }
                    font.pixelSize: 11; color: editor.theme.textMuted; width: 88
                }
                TextField {
                    Layout.fillWidth: true; implicitHeight: 30; font.pixelSize: 11
                    text: {
                        var idx2 = editor.ausgewaehltPrimIdx
                        if (idx2 < 0) return ""
                        var pv = editor.primitive[idx2]
                        if (!pv) return ""
                        var val = pv[modelData] !== undefined ? pv[modelData] : 0
                        return editor.istPositionsfeld(modelData)
                            ? editor.normToMmForField(modelData, val).toFixed(2)
                            : val.toFixed(3)
                    }
                    background: Rectangle { color: editor.theme.inputBg; radius: 3; border.color: editor.theme.border }
                    color: editor.theme.textPrimary
                    onEditingFinished: {
                        var idx3 = editor.ausgewaehltPrimIdx
                        if (idx3 < 0) return
                        var arr = editor.primitive.slice()
                        var pm  = Object.assign({}, arr[idx3])
                        var parsed = parseFloat(text) || 0
                        pm[modelData] = editor.istPositionsfeld(modelData)
                            ? editor.mmToNormForField(modelData, parsed)
                            : parsed
                        arr[idx3] = pm
                        editor.primitive = arr
                        editor.repaintAll()
                    }
                }
            }
        }

        // text_inhalt (nur bei Text-Primitiv)
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            visible: editor.ausgewaehltPrimIdx >= 0 &&
                     editor.primitive[editor.ausgewaehltPrimIdx] &&
                     editor.primitive[editor.ausgewaehltPrimIdx].typ === "text"
            Text { text: qsTr("Inhalt:"); font.pixelSize: 11; color: editor.theme.textMuted }
            TextField {
                Layout.fillWidth: true; implicitHeight: 24; font.pixelSize: 11
                text: {
                    var idx4 = editor.ausgewaehltPrimIdx; if (idx4 < 0) return ""
                    var px = editor.primitive[idx4]; return px ? (px.text_inhalt || "") : ""
                }
                background: Rectangle { color: editor.theme.inputBg; radius: 3; border.color: editor.theme.border }
                color: editor.theme.textPrimary
                onEditingFinished: {
                    var idx5 = editor.ausgewaehltPrimIdx; if (idx5 < 0) return
                    var arr2 = editor.primitive.slice()
                    var pm2  = Object.assign({}, arr2[idx5])
                    pm2.text_inhalt = text; arr2[idx5] = pm2; editor.primitive = arr2
                    editor.repaintAll()
                }
            }
        }

        // Linienart
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            visible: editor.ausgewaehltPrimIdx >= 0
            Text { text: qsTr("Linienart:"); font.pixelSize: 11; color: editor.theme.textMuted }
            ComboBox {
                Layout.fillWidth: true; font.pixelSize: 11
                model: ["durchgehend", "gestrichelt", "gepunktet", "Strich-Punkt"]
                currentIndex: {
                    var idx6 = editor.ausgewaehltPrimIdx; if (idx6 < 0) return 0
                    var pla = editor.primitive[idx6]; if (!pla) return 0
                    var i2 = model.indexOf(pla.linienart || "solid")
                    return i2 >= 0 ? i2 : 0
                }
                onActivated: function(idx) {
                    var idx7 = editor.ausgewaehltPrimIdx; if (idx7 < 0) return
                    var arr3 = editor.primitive.slice()
                    var pm3  = Object.assign({}, arr3[idx7])
                    pm3.linienart = model[idx]; arr3[idx7] = pm3; editor.primitive = arr3
                    editor.repaintAll()
                }
                background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: editor.theme.textPrimary; font.pixelSize: 11;
                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            }
        }

        Button {
            Layout.fillWidth: true
            visible: editor.ausgewaehltPrimIdx >= 0
            text: qsTr("Primitiv löschen"); implicitHeight: 28
            onClicked: {
                editor.primitive = editor.primitive.filter(function(_, idx) { return idx !== editor.ausgewaehltPrimIdx })
                editor.ausgewaehltPrimIdx = -1
                editor.repaintAll()
            }
            background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 4; border.color: "#ff4444"; border.width: 1 }
            contentItem: Text { text: parent.text; color: "#ff4444"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            text: editor.primitive.length + qsTr(" Primitive · ") + editor.pins.length + qsTr(" Pins")
            font.pixelSize: 10; color: editor.theme.textMuted
        }
    }
    DebugLabel { panelName: qsTr("SE Eigenschaften"); visible: editor.debug }
}
