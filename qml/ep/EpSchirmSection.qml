import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "schirm") ? shCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    readonly property string aktuelleSeite: (panel.el && panel.el.extraDaten
        && panel.el.extraDaten.anschlussSeite) ? panel.el.extraDaten.anschlussSeite : "links"

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
        id: shCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("SCHIRM") }

        InputField {
            label: qsTr("Bezeichnung")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("bezeichnung", t.trim()) }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Anschluss-Seite") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: [
                    { key: "links",  label: qsTr("Links")  },
                    { key: "rechts", label: qsTr("Rechts")  },
                    { key: "oben",   label: qsTr("Oben")    },
                    { key: "unten",  label: qsTr("Unten")   }
                ]
                delegate: MiniButton {
                    theme:   root.theme
                    label:   modelData.label
                    breite:  56
                    aktiv:   root.aktuelleSeite === modelData.key
                    onKlick: root.extraSetzen("anschlussSeite", modelData.key)
                }
            }
        }
        Item { height: 6 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton {
                theme:   root.theme
                label:   qsTr("↻ 90° drehen")
                breite:  110
                tooltip: qsTr("Kapselform um 90° im Uhrzeigersinn drehen (Breite/Höhe tauschen + Anschluss-Seite weiterschalten)")
                onKlick: panel.canvas.schirmDrehen()
            }
        }
        Item { height: 6 }

        // SCH-01: Schirmtyp (Geflecht/Folie/kombiniert) – reines Freitextfeld genügt fürs Erste
        InputField {
            label: qsTr("Schirmtyp (frei, z.B. Geflecht, Folie)")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.schirmtyp || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("schirmtyp", t.trim()) }
        }
        Item { height: 4 }
    }
}
