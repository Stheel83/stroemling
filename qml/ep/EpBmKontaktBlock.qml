import QtQuick
import "../components"

// KONTAKT-Block: Anschlusskennzeichnung + Erweiterungen (Kontaktsymbole).
// Nur sichtbar wenn das Element ein Kontaktsymbol ist.
Item {
    id: root

    required property var panel
    required property var theme

    width: parent ? parent.width : 0

    readonly property var _KONTAKT_SYMS: [
        "schliesser", "oeffner", "wechsler",
        "taster_no", "taster_nc", "not_halt", "bimetall_nc"
    ]
    readonly property bool _istKontakt: {
        if (!panel.el || panel.el.typ !== "symbol") return false
        var sid = panel.el.symbolId || ""
        for (var k = 0; k < _KONTAKT_SYMS.length; k++)
            if (sid === _KONTAKT_SYMS[k]) return true
        return false
    }
    readonly property var _erw: {
        var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
        return Array.isArray(ed.erweiterungen) ? ed.erweiterungen : []
    }

    height:  _istKontakt ? kontaktCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function hatErw(key) {
        return root._erw.indexOf(key) >= 0
    }
    function toggleErw(key) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        var arr = Array.isArray(ed.erweiterungen) ? ed.erweiterungen.slice() : []
        var idx = arr.indexOf(key)
        if (idx >= 0) arr.splice(idx, 1)
        else          arr.push(key)
        ed.erweiterungen = arr
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }
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
    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    Column {
        id: kontaktCol
        width: parent.width
        spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("KONTAKT") }

        InputField {
            label: qsTr("Anschlusskennzeichnung")
            value: (panel.el && panel.el.extraDaten)
                   ? (panel.el.extraDaten.anschlusskennzeichnung || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("anschlusskennzeichnung", t.trim()) }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Erweiterungen") }
        Repeater {
            model: [
                { key: "zeit_an",    label: qsTr("Anzugsverzögert") },
                { key: "zeit_ab",    label: qsTr("Abfallverzögert") },
                { key: "voreilung",  label: qsTr("Voreilung")       },
                { key: "nacheilung", label: qsTr("Nacheilung")      }
            ]
            Row {
                width: kontaktCol.width
                leftPadding: 12; height: 28; spacing: 8
                Rectangle {
                    width: 18; height: 18; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.hatErw(modelData.key) ? root.theme.accent : root.theme.inputBg
                    border.color: root.theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "✓"; color: "#ffffff"; font.pixelSize: 11
                        visible: root.hatErw(modelData.key)
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleErw(modelData.key)
                    }
                }
                Text {
                    text: modelData.label
                    color: root.theme.textMuted; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        Item { height: 4 }
    }
}
