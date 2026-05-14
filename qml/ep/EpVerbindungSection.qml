import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.verbindung !== null && !panel.el) ? vCol.implicitHeight : 0
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

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    Column {
        id: vCol
        width: parent.width; spacing: 0

        AbschnittTitel { text: qsTr("VERBINDUNG") }

        FeldLabel { text: qsTr("Signaltyp") }
        Item {
            width: root.width; height: 28
            Rectangle {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 80; height: 20; radius: 3
                color: {
                    var s = panel.verbindung ? panel.verbindung.signaltyp : "neutral"
                    if (s === "power")           return "#cc3300"
                    if (s === "pe")              return "#88cc00"
                    if (s === "n")               return "#4488ff"
                    if (s === "input_digital")   return "#44aaff"
                    if (s === "output_digital")  return "#44cc66"
                    if (s === "input_analog")    return "#88bbff"
                    if (s === "output_analog")   return "#66ddaa"
                    if (s === "kommunikation")   return "#aa44cc"
                    if (s === "konflikt")        return "#ff8800"
                    return theme.border
                }
                Text {
                    anchors.centerIn: parent
                    text: panel.verbindung ? (panel.verbindung.signaltyp || "neutral") : ""
                    font.pixelSize: 10; color: "#ffffff"
                }
            }
        }

        InputField {
            label: qsTr("Bezeichnung")
            value: panel.verbindung ? (panel.verbindung.bezeichnung || "") : ""
            theme: theme
            onCommit: function(t) { canvas.verbindungAnnotationAktualisieren("bezeichnung", t) }
        }

        FeldLabel { text: qsTr("Aderdaten (vom Aderdefinitionspunkt)") }
        Repeater {
            model: {
                var adps = panel.verbindung ? (panel.verbindung.adps || []) : []
                return adps.length > 0 ? adps : [null]
            }
            Item {
                width: root.width; height: adpRow.implicitHeight + 6
                Row {
                    id: adpRow
                    anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12
                              verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Rectangle {
                        visible: modelData && modelData.ed && modelData.ed.aderfarbe
                        width: 14; height: 14; radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: (modelData && modelData.ed && modelData.ed.aderfarbe)
                               ? canvas.aderFarbeZuCanvas(modelData.ed.aderfarbe) : "transparent"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: theme.textSecondary; font.pixelSize: 11
                        text: {
                            if (!modelData) return "– kein Aderdefinitionspunkt –"
                            var ed = modelData.ed || {}
                            var t = ""
                            if (ed.bezeichnung)         t += ed.bezeichnung + "  "
                            if (ed.aderfarbe)           t += ed.aderfarbe + "  "
                            if (ed.querschnitt_mm2 > 0) t += ed.querschnitt_mm2 + " mm²  "
                            if (ed.laenge_m > 0)        t += "→ " + ed.laenge_m + " m"
                            return t.trim() || "–"
                        }
                    }
                }
            }
        }

        Trennlinie {}
    }
}
