import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    property string _updateStatus: ""   // "" | "ok" | "fehler"

    Timer {
        id: _updateFeedbackTimer
        interval: 1200
        onTriggered: root._updateStatus = ""
    }

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "makrokasten") ? mkCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

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
        id: mkCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("MAKRO") }

        InputField {
            label: qsTr("Name")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.name || "") : ""
            theme: root.theme
            onCommit: function(t) {
                root.extraSetzen("name", t.trim())
                var mkId = panel.el && panel.el.extraDaten ? (panel.el.extraDaten.makroId || 0) : 0
                if (mkId > 0) db.makroMetaAktualisieren(mkId, t.trim(),
                    panel.el.extraDaten.beschreibung || "",
                    panel.el.extraDaten.kategorie || "")
            }
        }
        Item { height: 4 }

        InputField {
            label: qsTr("Beschreibung")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.beschreibung || "") : ""
            theme: root.theme
            onCommit: function(t) {
                root.extraSetzen("beschreibung", t.trim())
                var mkId = panel.el && panel.el.extraDaten ? (panel.el.extraDaten.makroId || 0) : 0
                if (mkId > 0) db.makroMetaAktualisieren(mkId,
                    panel.el.extraDaten.name || "", t.trim(),
                    panel.el.extraDaten.kategorie || "")
            }
        }
        Item { height: 4 }

        InputField {
            label: qsTr("Kategorie")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.kategorie || "") : ""
            theme: root.theme
            onCommit: function(t) {
                root.extraSetzen("kategorie", t.trim())
                var mkId = panel.el && panel.el.extraDaten ? (panel.el.extraDaten.makroId || 0) : 0
                if (mkId > 0) db.makroMetaAktualisieren(mkId,
                    panel.el.extraDaten.name || "",
                    panel.el.extraDaten.beschreibung || "", t.trim())
            }
        }
        Item { height: 6 }

        Text {
            visible: panel.el && panel.el.typ === "makrokasten"
            leftPadding: 12
            text: {
                var el = panel.el
                if (!el || el.typ !== "makrokasten") return ""
                var minX = Math.min(el.x1, el.x2), minY = Math.min(el.y1, el.y2)
                var maxX = Math.max(el.x1, el.x2), maxY = Math.max(el.y1, el.y2)
                var cnt = 0
                var alle = canvas.elementeModel.snapshot()
                for (var i = 0; i < alle.length; i++) {
                    var e = alle[i]
                    if (e === el || e.typ === "makrokasten") continue
                    var mx = (e.x1 + e.x2) / 2, my = (e.y1 + e.y2) / 2
                    if (mx >= minX && mx <= maxX && my >= minY && my <= maxY) cnt++
                }
                return cnt + " " + qsTr("Elemente im Kasten")
            }
            color: theme.textMuted; font.pixelSize: 11; font.italic: true
            width: parent.width - 16
            wrapMode: Text.WordWrap
        }
        Item { height: 6 }

        RowLayout {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Button {
                text: {
                    if (root._updateStatus === "ok") return qsTr("✓ Gespeichert")
                    return (panel.el && panel.el.extraDaten && panel.el.extraDaten.makroId > 0)
                           ? qsTr("Makro aktualisieren ▸")
                           : qsTr("Als Makro speichern ▸")
                }
                Layout.fillWidth: true
                implicitHeight: 28
                contentItem: Text {
                    text: parent.text; color: root.theme.textPrimary; font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? root.theme.accent : root.theme.inputBg
                    radius: 4; border.color: root.theme.accent
                }
                onClicked: {
                    var el = panel.el
                    if (!el || el.typ !== "makrokasten") return
                    // Position vor Flush sichern; nach DELETE+INSERT ändert sich die DB-ID
                    var savedX1 = el.x1, savedY1 = el.y1
                    panel.canvas.grafikSpeichernJetzt()
                    panel.canvas.elementeModel.laden(panel.canvas.seiteId)
                    // Element per Position wiederfinden (Index nach Reload nicht mehr gültig)
                    var reloaded = panel.canvas.elementeModel.snapshot()
                    var freshEl = null
                    for (var i = 0; i < reloaded.length; i++) {
                        var r = reloaded[i]
                        if (r.typ === "makrokasten"
                                && Math.abs(r.x1 - savedX1) < 0.01
                                && Math.abs(r.y1 - savedY1) < 0.01) {
                            freshEl = r; break
                        }
                    }
                    if (!freshEl || !(freshEl.id > 0)) {
                        root._updateStatus = "fehler"
                        _updateFeedbackTimer.restart()
                        return
                    }
                    var newId = db.makroSpeichern(freshEl.id, panel.canvas.seiteId)
                    if (newId > 0) {
                        root._updateStatus = "ok"
                        _updateFeedbackTimer.restart()
                        panel.canvas.elementeModel.laden(panel.canvas.seiteId)
                        panel.canvas.makroListeGeaendert()
                        panel.canvas.neuZeichnen()
                    } else {
                        root._updateStatus = "fehler"
                        _updateFeedbackTimer.restart()
                    }
                }
            }

            Button {
                visible: panel.el && panel.el.extraDaten && panel.el.extraDaten.makroId > 0
                text: "×"
                implicitWidth: 28; implicitHeight: 28
                contentItem: Text {
                    text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? "#cc3300" : root.theme.inputBg
                    radius: 4; border.color: root.theme.border
                }
                onClicked: {
                    var mkId = panel.el && panel.el.extraDaten ? (panel.el.extraDaten.makroId || 0) : 0
                    if (mkId > 0) {
                        db.makroLoeschen(mkId)
                        root.extraSetzen("makroId", 0)
                        panel.canvas.makroListeGeaendert()
                    }
                }
            }
        }
        Item { height: 6 }

        // ── Textposition ──────────────────────────────────────────
        Trennlinie {}
        AbschnittTitel { text: qsTr("TEXTPOSITION") }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Column {
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Versatz X"); color: root.theme.panelMid; font.pixelSize: 10 }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: root.theme.inputBg; border.color: mkOxTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: mkOxTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetX !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetX : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !mkOxTf.activeFocus; value: (mkOxTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetX", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Column {
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Versatz Y"); color: root.theme.panelMid; font.pixelSize: 10 }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: root.theme.inputBg; border.color: mkOyTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: mkOyTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetY !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetY : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !mkOyTf.activeFocus; value: (mkOyTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetY", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: 32; height: 22; radius: 3
                color: mkResetMa.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 12; color: root.theme.textMuted }
                MouseArea {
                    id: mkResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.extraSetzen("bmkOffsetX", 0); root.extraSetzen("bmkOffsetY", 0) }
                }
                ToolTip { visible: mkResetMa.containsMouse; text: qsTr("Textposition zurücksetzen"); delay: 500 }
            }
        }
        Item { height: 4 }
    }
}
