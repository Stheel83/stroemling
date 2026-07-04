import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    readonly property bool _verknuepft: panel.svPositionDetails !== null && panel.svPositionDetails !== undefined

    width:   parent ? parent.width : 0
    height:  (panel.el && (panel.el.symbolId === "stecker" || panel.el.symbolId === "buchse"))
             ? svCol.implicitHeight : 0
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
        id: svCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("STECKVERBINDER") }

        // ── Verknüpfte Position (read-only, Neukonzeption Jul 2026) ─────────
        Item {
            visible: root._verknuepft
            width: parent.width; height: visible ? posCol.implicitHeight : 0

            Column {
                id: posCol
                width: parent.width; spacing: 4
                topPadding: 4; bottomPadding: 8

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Text {
                        text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "–") : "–"
                        font.pixelSize: 16; font.weight: Font.Bold; color: root.theme.accent
                    }
                    Text {
                        text: panel.svPositionDetails ? qsTr("Pos. %1").arg(panel.svPositionDetails.positionNr) : ""
                        font.pixelSize: 11; color: root.theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!panel.svPositionDetails) return ""
                        var d = panel.svPositionDetails
                        return d.bezeichnung + " (" + (d.geschlecht === "stift" ? qsTr("Stift") : qsTr("Buchse")) + ")"
                    }
                    font.pixelSize: 12; color: root.theme.textSecondary
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Text {
                        visible: panel.svPositionDetails && panel.svPositionDetails.kontaktgroesse > 0
                        text: panel.svPositionDetails ? (panel.svPositionDetails.kontaktgroesse + " mm²") : ""
                        font.pixelSize: 11; color: root.theme.textMuted
                    }
                    Text {
                        visible: panel.svPositionDetails && (panel.svPositionDetails.verbindungstechnik || "") !== ""
                        text: panel.svPositionDetails ? panel.svPositionDetails.verbindungstechnik : ""
                        font.pixelSize: 11; color: root.theme.textMuted
                    }
                    Text {
                        visible: panel.svPositionDetails && panel.svPositionDetails.istSchirmkontakt
                        text: qsTr("Schirmkontakt")
                        font.pixelSize: 11; color: root.theme.accent
                    }
                }
            }
        }

        Trennlinie { visible: root._verknuepft }

        FeldLabel { visible: !root._verknuepft; text: qsTr("Anschlusstyp") }
        ComboBox {
            visible: !root._verknuepft
            width: parent.width - 24
            anchors.horizontalCenter: parent.horizontalCenter
            model: [
                qsTr("Schraubanschluss"),
                qsTr("Federklemmung"),
                qsTr("Crimp"),
                qsTr("Löt")
            ]
            property var _keys: ["schraub", "feder", "crimp", "loet"]
            currentIndex: {
                var t = (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.svAnschlusstyp || "schraub") : "schraub"
                var idx = _keys.indexOf(t)
                return idx >= 0 ? idx : 0
            }
            onActivated: {
                if (!panel.el) return
                var ed = panel.el.extraDaten ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                ed.svAnschlusstyp = _keys[currentIndex]
                panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
            }
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }

        FeldLabel { visible: !root._verknuepft; text: qsTr("Querschnitt (mm²)") }
        Row {
            visible: !root._verknuepft
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            TextField {
                width: 72
                placeholderText: "min"
                text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svQsMin !== undefined)
                      ? String(panel.el.extraDaten.svQsMin).replace(".", ",") : ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                color: root.theme.textPrimary
                onEditingFinished: {
                    if (!panel.el) return
                    var v = parseFloat(text.replace(",", "."))
                    if (isNaN(v)) return
                    var ed = panel.el.extraDaten ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed.svQsMin = v
                    panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
            }
            Text {
                text: "–"
                anchors.verticalCenter: parent.verticalCenter
                color: theme.textSecondary; font.pixelSize: 12
            }
            TextField {
                width: 72
                placeholderText: "max"
                text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svQsMax !== undefined)
                      ? String(panel.el.extraDaten.svQsMax).replace(".", ",") : ""
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                color: root.theme.textPrimary
                onEditingFinished: {
                    if (!panel.el) return
                    var v = parseFloat(text.replace(",", "."))
                    if (isNaN(v)) return
                    var ed = panel.el.extraDaten ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed.svQsMax = v
                    panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
            }
        }

        FeldLabel { visible: !root._verknuepft; text: qsTr("Kabeldurchmesser max (mm)") }
        TextField {
            visible: !root._verknuepft
            width: parent.width - 24
            anchors.horizontalCenter: parent.horizontalCenter
            placeholderText: "z. B. 8,5"
            text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svKabelDmMax !== undefined)
                  ? String(panel.el.extraDaten.svKabelDmMax).replace(".", ",") : ""
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary
            onEditingFinished: {
                if (!panel.el) return
                var v = parseFloat(text.replace(",", "."))
                if (isNaN(v)) return
                var ed = panel.el.extraDaten ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                ed.svKabelDmMax = v
                panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
            }
        }

        Item { height: 4 }
    }
}
