import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

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
            theme: theme
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
            theme: theme
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
            theme: theme
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
                text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.makroId > 0)
                      ? qsTr("Makro aktualisieren ▸")
                      : qsTr("Als Makro speichern ▸")
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
                    canvas.grafikSpeichernJetzt()
                    canvas.elementeModel.laden(canvas.seiteId)
                    // Element per Position wiederfinden (Index nach Reload nicht mehr gültig)
                    var reloaded = canvas.elementeModel.snapshot()
                    var freshEl = null
                    for (var i = 0; i < reloaded.length; i++) {
                        var r = reloaded[i]
                        if (r.typ === "makrokasten"
                                && Math.abs(r.x1 - savedX1) < 0.01
                                && Math.abs(r.y1 - savedY1) < 0.01) {
                            freshEl = r; break
                        }
                    }
                    if (!freshEl || !(freshEl.id > 0)) return
                    var newId = db.makroSpeichern(freshEl.id, canvas.seiteId)
                    if (newId > 0) {
                        canvas.elementeModel.laden(canvas.seiteId)
                        canvas.makroListeGeaendert()
                        canvas.neuZeichnen()
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
    }
}
