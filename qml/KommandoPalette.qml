import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Popup {
    id: root

    property int    projektId:  -1
    property var    theme

    // Werkzeug-Aktivierung
    signal werkzeugAktiviert(string werkzeug)
    // Seite öffnen
    signal seiteOeffnen(int id, string blattnummer, string bezeichnung)

    modal:  false
    focus:  true
    width:  500
    height: Math.min(480, contentItem.implicitHeight + 2)
    padding: 0

    parent:  Overlay.overlay
    x:       (parent.width  - width)  / 2
    y:       Math.max(60, (parent.height - height) / 4)

    background: Rectangle {
        color:        root.theme ? root.theme.sidebar      : "#0d1b2a"
        border.color: root.theme ? root.theme.accent       : "#4a9eff"
        border.width: 1
        radius: 6
    }

    // Beim Öffnen: Feld leeren, Ergebnisse aufbauen
    onOpened: {
        suchfeld.text = ""
        suchfeld.forceActiveFocus()
        _eintraegeLaden()
    }

    property var _alleEintraege: []

    readonly property var _werkzeuge: [
        { label: "Zeiger",           werkzeug: "zeiger",          kuerzel: "V" },
        { label: "Linie",            werkzeug: "linie",           kuerzel: "L" },
        { label: "Polygonlinie",     werkzeug: "polygonlinie",    kuerzel: "P" },
        { label: "Kabellinie",       werkzeug: "kabellinie",      kuerzel: "C" },
        { label: "Rechteck",         werkzeug: "rechteck",        kuerzel: "R" },
        { label: "Kreis",            werkzeug: "kreis",           kuerzel: "K" },
        { label: "Gerätekasten",     werkzeug: "geraetekasten",   kuerzel: "G" },
        { label: "Strukturkasten",   werkzeug: "strukturkasten",  kuerzel: "U" },
        { label: "Makrokasten",      werkzeug: "makrokasten",     kuerzel: "M" },
        { label: "Text",             werkzeug: "text",            kuerzel: "T" },
        { label: "Notiz",            werkzeug: "notiz",           kuerzel: "N" }
    ]

    function _eintraegeLaden() {
        var liste = []
        // Werkzeuge
        for (var i = 0; i < _werkzeuge.length; i++) {
            var w = _werkzeuge[i]
            liste.push({ kategorie: "Werkzeug", label: w.label,
                         info: "[" + w.kuerzel + "]", werkzeug: w.werkzeug, seiteId: -1 })
        }
        // Seiten
        if (root.projektId >= 0) {
            var seiten = db.alleSeitenFlach(root.projektId)
            for (var j = 0; j < seiten.length; j++) {
                var s = seiten[j]
                var bez = s.bezeichnung ? s.bezeichnung + " – " + s.blattnummer : s.blattnummer
                liste.push({ kategorie: "Seite", label: bez,
                             info: s.blattnummer, seiteId: s.id,
                             blattnummer: s.blattnummer, bezeichnung: s.bezeichnung || "",
                             werkzeug: "" })
            }
        }
        root._alleEintraege = liste
        _auswahl = liste.length > 0 ? 0 : -1
    }

    property int _auswahl: -1

    readonly property var _gefiltert: {
        var q = suchfeld.text.trim().toLowerCase()
        if (q === "") return root._alleEintraege
        return root._alleEintraege.filter(function(e) {
            return e.label.toLowerCase().indexOf(q) >= 0
        })
    }

    function _aktivieren(idx) {
        if (idx < 0 || idx >= _gefiltert.length) return
        var e = _gefiltert[idx]
        root.close()
        if (e.werkzeug !== "") {
            root.werkzeugAktiviert(e.werkzeug)
        } else if (e.seiteId >= 0) {
            root.seiteOeffnen(e.seiteId, e.blattnummer, e.bezeichnung)
        }
    }

    contentItem: ColumnLayout {
        spacing: 0
        implicitHeight: suchZeile.height + trenn.height + listView.contentHeight + 8

        // Suchzeile
        Rectangle {
            id: suchZeile
            Layout.fillWidth: true
            height: 44
            color: "transparent"
            radius: 6

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                Text {
                    text: "⌕"; font.pixelSize: 16
                    color: root.theme ? root.theme.textMuted : "#8899aa"
                }

                TextField {
                    id: suchfeld
                    Layout.fillWidth: true
                    placeholderText: qsTr("Werkzeug oder Seite suchen …")
                    font.pixelSize: 14
                    color:       root.theme ? root.theme.textPrimary    : "#e8f0fe"
                    background:  Rectangle { color: "transparent" }
                    placeholderTextColor: root.theme ? root.theme.textMuted : "#8899aa"

                    onTextChanged: root._auswahl = root._gefiltert.length > 0 ? 0 : -1

                    Keys.onUpPressed:   { if (root._auswahl > 0) root._auswahl-- }
                    Keys.onDownPressed: { if (root._auswahl < root._gefiltert.length - 1) root._auswahl++ }
                    Keys.onReturnPressed: root._aktivieren(root._auswahl)
                    Keys.onEscapePressed: root.close()
                }

                Text {
                    text: root._gefiltert.length + " " + qsTr("Treffer")
                    font.pixelSize: 10
                    color: root.theme ? root.theme.textMuted : "#8899aa"
                    visible: suchfeld.text.length > 0
                }
            }
        }

        Rectangle {
            id: trenn
            Layout.fillWidth: true
            height: 1
            color: root.theme ? root.theme.border : "#1e3a5f"
        }

        // Ergebnisliste
        ListView {
            id: listView
            Layout.fillWidth:  true
            height: Math.min(380, contentHeight)
            clip:   true
            model:  root._gefiltert

            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                width:  listView.width
                height: 38
                color:  (index === root._auswahl)
                        ? (root.theme ? root.theme.activeItem : "#1e3a5f") : "transparent"

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    // Kategorie-Badge
                    Rectangle {
                        width: 48; height: 16; radius: 3
                        color: modelData.kategorie === "Werkzeug"
                               ? (root.theme ? root.theme.badge : "#1a3050")
                               : Qt.rgba(0.1, 0.5, 0.3, 0.3)
                        Text {
                            anchors.centerIn: parent
                            text:  modelData.kategorie
                            font.pixelSize: 9
                            color: root.theme ? root.theme.textMuted : "#8899aa"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text:  modelData.label
                        font.pixelSize: 13
                        color: root.theme ? root.theme.textPrimary : "#e8f0fe"
                        elide: Text.ElideRight
                    }

                    Text {
                        text:  modelData.info || ""
                        font.pixelSize: 11
                        color: root.theme ? root.theme.textMuted : "#8899aa"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked:        { root._auswahl = index; root._aktivieren(index) }
                    onContainsMouseChanged: if (containsMouse) root._auswahl = index
                    hoverEnabled: true
                }
            }
        }
    }

    // Klick außerhalb schließt
    Overlay.modal: Rectangle { color: "transparent" }
}
