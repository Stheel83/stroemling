import QtQuick
import "../components"

// KONTAKT-Block: Anschlusskennzeichnung (Kontaktsymbole).
// Nur sichtbar wenn das Element ein Kontaktsymbol ist.
Item {
    id: root

    required property var panel
    required property var theme

    width: parent ? parent.width : 0

    // Kontaktsymbole: alle Symbole der Kategorie "Kontakte" (neue Kontakt-Symbole
    // erscheinen damit automatisch, keine feste ID-Liste mehr) + bimetall_nc
    // (Kategorie "Schutz", aber Hilfskontakt mit Anschlusskennzeichnung).
    readonly property bool _istKontakt: {
        if (!panel.el || panel.el.typ !== "symbol") return false
        var sid = panel.el.symbolId || ""
        if (sid === "bimetall_nc") return true
        var info = symbolDefinitionModel.symbolInfo(sid)
        return !!info && info.kategorie === "Kontakte"
    }
    height:  _istKontakt ? kontaktCol.implicitHeight : 0
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
        Item { height: 4 }
    }
}
