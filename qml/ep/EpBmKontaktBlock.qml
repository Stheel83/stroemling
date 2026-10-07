import QtQuick
import "../components"

// KONTAKT-Block: Anschlusskennzeichnung (Kontaktsymbole).
// Nur sichtbar wenn das Element ein Kontaktsymbol ist.
Item {
    id: root

    required property var panel
    required property var theme

    width: parent ? parent.width : 0

    // Sichtbarkeit (EP-KONTAKT-BLOCK-01/02): die Anschlusskennzeichnung wirkt nur bei
    // einer Nebenfunktion (Kontakt eines Betriebsmittels, erscheint im Kontaktspiegel
    // der Hauptfunktion). Daher:
    //  - mit Betriebsmittel verknüpft: sichtbar genau dann, wenn das Element NICHT die
    //    Hauptfunktion ist (egal welche Symbolkategorie, z.B. Schütz-Hilfskontakt),
    //  - noch nicht verknüpft: sichtbar bei Kontaktsymbolen (Kategorie "Kontakte",
    //    plus bimetall_nc), damit man sie vor dem Verknüpfen schon eintragen kann.
    readonly property bool _istKontakt: {
        if (!panel.el || panel.el.typ !== "symbol" || !(panel._refresh * 0 === 0)) return false
        if ((panel.el.betriebsmittelId || 0) > 0) {
            var mitglieder = db.betriebsmittelMitglieder(panel.el.betriebsmittelId)
            for (var i = 0; i < mitglieder.length; i++)
                if (mitglieder[i].id === panel.el.id) return !mitglieder[i].istHauptfunktion
            return false
        }
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
