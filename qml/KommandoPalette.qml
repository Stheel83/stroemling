import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Popup {
    id: root

    property int    projektId:  -1
    required property var theme
    property bool   debug: false

    signal werkzeugAktiviert(string werkzeug)
    signal seiteOeffnen(int id, string blattnummer, string bezeichnung)
    signal elementSprung(int seiteId, string blattnummer, string seiteBez, real cx, real cy)

    modal:  false
    focus:  true
    width:  500
    height: Math.min(480, contentItem.implicitHeight + 2)
    padding: 0

    parent:  Overlay.overlay
    x:       (parent.width  - width)  / 2
    y:       Math.max(60, (parent.height - height) / 4)

    background: Rectangle {
        color:        root.theme.sidebar
        border.color: root.theme.accent
        border.width: 1
        radius: 6
    }

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
        for (var i = 0; i < _werkzeuge.length; i++) {
            var w = _werkzeuge[i]
            liste.push({ kategorie: "Werkzeug", label: w.label,
                         info: "[" + w.kuerzel + "]", werkzeug: w.werkzeug,
                         seiteId: -1, blattnummer: "", bezeichnung: "", cx: 0, cy: 0 })
        }
        if (root.projektId >= 0) {
            var seiten = db.alleSeitenFlach(root.projektId)
            for (var j = 0; j < seiten.length; j++) {
                var s = seiten[j]
                var bez = s.bezeichnung ? s.bezeichnung + " – " + s.blattnummer : s.blattnummer
                liste.push({ kategorie: "Seite", label: bez, info: s.blattnummer,
                             seiteId: s.id, blattnummer: s.blattnummer,
                             bezeichnung: s.bezeichnung || "", werkzeug: "", cx: 0, cy: 0 })
            }
            var elems = db.spotlightEintraege(root.projektId)
            for (var k = 0; k < elems.length; k++) {
                var e = elems[k]
                liste.push({ kategorie: e.kategorie, label: e.label,
                             info: e.blattnummer, seiteId: e.seiteId,
                             blattnummer: e.blattnummer, bezeichnung: e.seiteBez,
                             werkzeug: "", cx: e.cx, cy: e.cy })
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
        if (e.kategorie === "Werkzeug") {
            root.werkzeugAktiviert(e.werkzeug)
        } else if (e.kategorie === "Seite") {
            root.seiteOeffnen(e.seiteId, e.blattnummer, e.bezeichnung)
        } else {
            root.elementSprung(e.seiteId, e.blattnummer, e.bezeichnung, e.cx, e.cy)
        }
    }

    contentItem: ColumnLayout {
        spacing: 0
        implicitHeight: suchZeile.height + trenn.height + listView.contentHeight + 8

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
                    color: root.theme.textMuted
                }

                TextField {
                    id: suchfeld
                    Layout.fillWidth: true
                    placeholderText: qsTr("Werkzeug, Seite, BMK oder Kabel suchen …")
                    font.pixelSize: 14
                    color:               root.theme.textPrimary
                    background:          Rectangle { color: "transparent" }
                    placeholderTextColor: root.theme.textMuted

                    onTextChanged: root._auswahl = root._gefiltert.length > 0 ? 0 : -1

                    Keys.onUpPressed:     { if (root._auswahl > 0) root._auswahl-- }
                    Keys.onDownPressed:   { if (root._auswahl < root._gefiltert.length - 1) root._auswahl++ }
                    Keys.onReturnPressed: root._aktivieren(root._auswahl)
                    Keys.onEscapePressed: root.close()
                }

                Text {
                    text: root._gefiltert.length + " " + qsTr("Treffer")
                    font.pixelSize: 10
                    color: root.theme.textMuted
                    visible: suchfeld.text.length > 0
                }
            }
        }

        Rectangle {
            id: trenn
            Layout.fillWidth: true
            height: 1
            color: root.theme.border
        }

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
                color:  (index === root._auswahl) ? root.theme.activeItem : "transparent"

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Rectangle {
                        width: 54; height: 16; radius: 3
                        color: modelData.kategorie === "Werkzeug" ? root.theme.badge
                             : modelData.kategorie === "Seite"    ? Qt.rgba(0.1, 0.5, 0.3, 0.3)
                             : modelData.kategorie === "BMK"      ? Qt.rgba(0.1, 0.3, 0.7, 0.3)
                             :                                      Qt.rgba(0.5, 0.3, 0.1, 0.3)
                        Text {
                            anchors.centerIn: parent
                            text:  modelData.kategorie
                            font.pixelSize: 9
                            color: root.theme.textMuted
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text:  modelData.label
                        font.pixelSize: 13
                        color: root.theme.textPrimary
                        elide: Text.ElideRight
                    }

                    Text {
                        text:  modelData.info || ""
                        font.pixelSize: 11
                        color: root.theme.textMuted
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked:              { root._auswahl = index; root._aktivieren(index) }
                    onContainsMouseChanged: if (containsMouse) root._auswahl = index
                    hoverEnabled: true
                }
            }
        }
    }

    Overlay.modal: Rectangle { color: "transparent" }

    DebugLabel { parent: root.contentItem; panelName: qsTr("Kommando-Palette"); visible: root.debug && root.visible }
}
