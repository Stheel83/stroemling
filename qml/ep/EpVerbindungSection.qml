import QtQuick
import QtQuick.Controls
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

        // Bezeichnung + Vorschlag-Button (nächste freie Nummer)
        Item {
            width: root.width
            height: 20 + 28   // Label + Eingabe

            Text {
                id: bezLabel
                anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 5 }
                text: qsTr("Bezeichnung"); font.pixelSize: 10; color: root.theme.panelMid
            }
            Rectangle {
                id: bezBox
                anchors { top: bezLabel.bottom; left: parent.left; leftMargin: 8 }
                width: parent.width - 16 - 30 - 4; height: 28; radius: 3
                color: root.theme.inputBg
                border.color: bezTf.activeFocus ? root.theme.accent : root.theme.border
                TextInput {
                    id: bezTf
                    anchors { fill: parent; margins: 5 }
                    color: root.theme.textSecondary; font.pixelSize: 11
                    verticalAlignment: TextInput.AlignVCenter
                    text: panel.verbindung ? (panel.verbindung.bezeichnung || "") : ""
                    Binding on text {
                        when: !bezTf.activeFocus
                        value: panel.verbindung ? (panel.verbindung.bezeichnung || "") : ""
                    }
                    onEditingFinished: canvas.verbindungAnnotationAktualisieren("bezeichnung", text)
                    Keys.onEscapePressed: { text = panel.verbindung ? (panel.verbindung.bezeichnung || "") : ""; focus = false }
                }
            }
            Rectangle {
                id: vorschlagBtn
                anchors { left: bezBox.right; leftMargin: 4; top: bezBox.top }
                width: 30; height: 28; radius: 3
                color: vorschlagMa.containsMouse ? root.theme.activeItemAlt : root.theme.inputBg
                border.color: root.theme.border
                Text {
                    anchors.centerIn: parent
                    text: "→N"; font.pixelSize: 10; color: root.theme.accent
                }
                MouseArea {
                    id: vorschlagMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (canvas.projektId < 0) return
                        var vorschlag = db.naechsteFreiePotenzialNummer(canvas.projektId, "", 1, 1)
                        bezTf.text = vorschlag
                        canvas.verbindungAnnotationAktualisieren("bezeichnung", vorschlag)
                    }
                }
                ToolTip.visible: vorschlagMa.containsMouse
                ToolTip.text: qsTr("Nächste freie Nummer vorschlagen")
                ToolTip.delay: 400
            }
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
