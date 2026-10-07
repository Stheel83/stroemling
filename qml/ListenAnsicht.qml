import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "components"
import "la"

Item {
    id: panel

    property int    projektId:   -1
    property string projektName: ""
    property var    theme
    property bool   debug:       false
    property var    canvas:      null

    onProjektIdChanged: laden()
    onVisibleChanged:   if (visible && projektId >= 0) laden()

    // LISTEN-IDEEN-01: Stückliste/Querverweise/Aderliste/Bestellliste/
    // Adersummenliste liegen als rohe JS-Arrays vor (statt ListModel), analog
    // zum schon vorhandenen Muster bei _kabelDaten/_svDaten/_bpDaten – nötig
    // für Klick-Sortierung + Freitext-Filter (siehe _listeGefiltertSortiert).
    // Klemmenplan/Klemmlistenauszug bleiben ListModel: hierarchische Gruppen-
    // Header (Leiste→Klemmen bzw. Leiste→Anschlüsse), Sortierung/Filter dort
    // bewusst nicht angeboten – würde die Gruppierung zerreißen.
    function laden() {
        if (projektId < 0) {
            panel._stuecklisteDaten     = []
            panel._querverweisDaten     = []
            panel._aderlisteDaten       = []
            panel._bestellisteDaten     = []
            panel._aderSummenlisteDaten = []
            klemmenplanModel.clear(); klaModel.clear()
            panel._kabelDaten = []; panel._svDaten = []; panel._bpDaten = []
            return
        }
        panel._stuecklisteDaten = db.stueckliste(projektId)
        panel._querverweisDaten = db.querverweisListe(projektId)
        panel._aderlisteDaten   = db.aderliste(projektId)
        aderSummenlisteNeuLaden()

        klemmenplanModel.clear()
        var kp = db.klemmenplan(projektId)
        for (var m = 0; m < kp.length; m++) klemmenplanModel.append(kp[m])

        klaModel.clear()
        var kla = db.klemmlistenauszug(projektId)
        for (var n = 0; n < kla.length; n++) klaModel.append(kla[n])

        panel._kabelDaten    = db.kabelListeAufgeschluesselt(projektId)
        panel._kabelExpanded = {}

        panel._svDaten = db.steckverbinderListe(projektId)
        panel._bpDaten = db.steckverbinderBelegungsplan(projektId)

        panel._bestellisteDaten = db.bestellliste(projektId)
    }

    // Adersummenliste separat neu ladbar (Umschalter "je Anlage/Ort", ohne
    // die restlichen Listen mitzuladen).
    property bool asJeAnlageOrt: false
    onAsJeAnlageOrtChanged: aderSummenlisteNeuLaden()
    function aderSummenlisteNeuLaden() {
        panel._aderSummenlisteDaten = projektId >= 0 ? db.aderSummenliste(projektId, asJeAnlageOrt) : []
    }

    ListModel { id: klemmenplanModel }
    ListModel { id: klaModel }

    property alias _klemmenplanModel: klemmenplanModel
    property alias _klaModel:         klaModel

    property var _stuecklisteDaten:     []
    property var _querverweisDaten:     []
    property var _aderlisteDaten:       []
    property var _bestellisteDaten:     []
    property var _aderSummenlisteDaten: []

    property var _kabelDaten:    []
    property var _kabelExpanded: ({})
    property var _svDaten:       []
    property var _bpDaten:       []

    // ── Sortier-/Filterzustand je flacher Liste (LISTEN-IDEEN-01) ─────
    property string slSortFeld: ""; property bool slSortAsc: true
    property string qvSortFeld: ""; property bool qvSortAsc: true
    property string alSortFeld: ""; property bool alSortAsc: true
    property string boSortFeld: ""; property bool boSortAsc: true
    property string asSortFeld: ""; property bool asSortAsc: true
    property string svSortFeld: ""; property bool svSortAsc: true

    property string slFilter: ""
    property string qvFilter: ""
    property string alFilter: ""
    property string boFilter: ""
    property string asFilter: ""
    property string svFilter: ""
    property string klFilter: ""

    // Klick auf Spaltenkopf: gleiches Feld erneut → Richtung umdrehen,
    // sonst neu aufsteigend sortieren.
    function sortSetzen(feldProp, ascProp, feld) {
        if (panel[feldProp] === feld) panel[ascProp] = !panel[ascProp]
        else { panel[feldProp] = feld; panel[ascProp] = true }
    }

    // Gemeinsame Filter+Sortier-Logik für alle flachen Listen. filterFelder:
    // Feldnamen, die textuell durchsucht werden. sortFeld leer → unsortiert
    // (Original-Reihenfolge aus der DB-Abfrage bleibt erhalten).
    function _listeGefiltertSortiert(daten, filterText, filterFelder, sortFeld, sortAsc) {
        var out = daten || []
        if (filterText) {
            var ft = filterText.toLowerCase()
            out = out.filter(function (row) {
                for (var i = 0; i < filterFelder.length; i++) {
                    var v = row[filterFelder[i]]
                    if (v !== undefined && v !== null && String(v).toLowerCase().indexOf(ft) !== -1) return true
                }
                return false
            })
        }
        if (sortFeld) {
            out = out.slice().sort(function (a, b) {
                var av = a[sortFeld], bv = b[sortFeld]
                if (typeof av === "number" && typeof bv === "number") return sortAsc ? av - bv : bv - av
                av = (av === undefined || av === null) ? "" : String(av).toLowerCase()
                bv = (bv === undefined || bv === null) ? "" : String(bv).toLowerCase()
                if (av < bv) return sortAsc ? -1 : 1
                if (av > bv) return sortAsc ? 1 : -1
                return 0
            })
        }
        return out
    }

    readonly property var slAnzeige: _listeGefiltertSortiert(_stuecklisteDaten, slFilter,
        ["bmk", "symbolId", "freitext1", "freitext2", "seite", "anlageUO", "ortUO", "anlageKz", "ortKz"],
        slSortFeld, slSortAsc)
    readonly property var qvAnzeige: _listeGefiltertSortiert(_querverweisDaten, qvFilter,
        ["signalname", "richtung", "seite", "zielSeite"], qvSortFeld, qvSortAsc)
    readonly property var alAnzeige: _listeGefiltertSortiert(_aderlisteDaten, alFilter,
        ["bezeichnung", "aderfarbe", "aderfarbe2", "seite", "anlageUO", "ortUO", "anlageKz", "ortKz"],
        alSortFeld, alSortAsc)
    readonly property var boAnzeige: _listeGefiltertSortiert(_bestellisteDaten, boFilter,
        ["bezeichnung", "hersteller", "artikelnummer", "bestellnummer", "lieferant"], boSortFeld, boSortAsc)
    // Je-Anlage/Ort-Modus: nur filtern, NICHT sortieren – die Gruppierung
    // nach Anlage/Ort/Farbe/Querschnitt aus der DB bleibt sonst zerrissen.
    readonly property var asAnzeige: asJeAnlageOrt
        ? _listeGefiltertSortiert(_aderSummenlisteDaten, asFilter, ["aderfarbe", "aderfarbe2", "anlageKz", "ortKz"], "", true)
        : _listeGefiltertSortiert(_aderSummenlisteDaten, asFilter, ["aderfarbe", "aderfarbe2"], asSortFeld, asSortAsc)
    readonly property var svAnzeige: _listeGefiltertSortiert(_svDaten, svFilter,
        ["bmk", "gkBezeichnung", "bauteilBez", "hersteller", "blattnr", "anlageUO", "ortUO", "anlageKz", "ortKz"],
        svSortFeld, svSortAsc)
    readonly property var klAnzeige: _listeGefiltertSortiert(_kabelDaten, klFilter,
        ["bezeichnung", "kabeltyp", "vonOrt", "nachOrt"], "", true)

    readonly property int _bpKontaktAnzahl: {
        var n = 0
        for (var i = 0; i < _bpDaten.length; i++)
            if (_bpDaten[i] && _bpDaten[i].typ === "kontakt") n++
        return n
    }

    function netzeNummerieren(praefix, start, schrittweite) {
        if (projektId < 0) return 0
        var sc   = Math.max(1, schrittweite)
        var alle = db.verbindungenProjektLaden(projektId)

        // Bereits vergebene Nummern sammeln (nur passend zum Schema)
        var verwendet = {}
        for (var i = 0; i < alle.length; i++) {
            var bez = alle[i].bezeichnung || ""
            if (!bez || !bez.startsWith(praefix)) continue
            var rest = bez.substring(praefix.length)
            var n = parseInt(rest, 10)
            if (!isNaN(n) && n.toString() === rest) verwendet[n] = true
        }

        // Unbenannte Netze (nicht pe/n, keine bestehende Bezeichnung) nummerieren
        var zuweisungen = []
        var n = start
        for (var j = 0; j < alle.length; j++) {
            var v = alle[j]
            if (v.bezeichnung) continue
            var st = v.signaltyp || ""
            if (st === "pe" || st === "n") continue
            while (verwendet[n]) n += sc
            zuweisungen.push({id: v.id, bezeichnung: praefix + n})
            verwendet[n] = true
            n += sc
        }

        if (zuweisungen.length > 0) {
            db.verbindungenBulkBezeichnungSetzen(projektId, zuweisungen)
            panel.laden()
            // Canvas-Annotationscache der aktuellen Seite aktualisieren
            if (panel.canvas) panel.canvas.verbindungAnnotationenNeuLaden()
        }
        return zuweisungen.length
    }

    readonly property int klemmenplanZaehler: {
        var n = 0
        for (var i = 0; i < klemmenplanModel.count; i++)
            if (klemmenplanModel.get(i).typ === "klemme") n++
        return n
    }

    readonly property int _klaAnschlussZaehler: {
        var n = 0
        for (var i = 0; i < klaModel.count; i++)
            if (klaModel.get(i).typ === "anschluss") n++
        return n
    }
    readonly property int _klaMaxStegSpalten: {
        var max = 0
        for (var i = 0; i < klaModel.count; i++) {
            var row = klaModel.get(i)
            if (row.typ === "leiste") { var n = row.stegAnzahl || 0; if (n > max) max = n }
        }
        return max
    }

    // field: Datenfeld für Klick-Sortierung (LISTEN-IDEEN-01) – fehlt field,
    // ist die Spalte nicht klickbar (z.B. "Canvas Pos."-Sprungpfeil-Spalte).
    property var slCols: [
        { header: "BMK",        w: 110, field: "bmk" },       { header: "Typ",        w: 110, field: "symbolId" },
        { header: "Freitext 1", w: 130, field: "freitext1" }, { header: "Freitext 2", w: 130, field: "freitext2" },
        { header: "Seite",      w: 65,  field: "seite" },     { header: "==Anlage",   w: 65,  field: "anlageUO" },
        { header: "++Ort",      w: 65,  field: "ortUO" },     { header: "=Anlage",    w: 55,  field: "anlageKz" },
        { header: "+Ort",       w: 55,  field: "ortKz" },     { header: "Canvas Pos.", w: 70  }
    ]
    property var qvCols: [
        { header: "Signalname", w: 160, field: "signalname" }, { header: "Richtung",    w: 100, field: "richtung" },
        { header: "Seite",      w: 90,  field: "seite" },      { header: "Zielseite",   w: 90,  field: "zielSeite" },
        { header: "Canvas Pos.", w: 70 }
    ]
    property var alCols: [
        { header: "Bezeichnung",  w: 80, field: "bezeichnung" },     { header: "Aderfarbe",   w: 70, field: "aderfarbe" },
        { header: "Querschnitt",  w: 80, field: "querschnittMm2" },  { header: "Länge (m)",   w: 70, field: "laengeM" },
        { header: "Seite",        w: 60, field: "seite" },           { header: "==Anlage",    w: 60, field: "anlageUO" },
        { header: "++Ort",        w: 60, field: "ortUO" },           { header: "=Anlage",     w: 55, field: "anlageKz" },
        { header: "+Ort",         w: 55, field: "ortKz" },           { header: "Canvas Pos.", w: 70 }
    ]
    property var kpCols: [
        { header: "Nr.",         w: 55  }, { header: "Bauteil",     w: 155 },
        { header: "Typ",         w: 90  }, { header: "Querschnitt", w: 110 },
        { header: "Farbe",       w: 100 }, { header: "Potenzial",   w: 100 },
        { header: "+Ort",        w: 80  }, { header: "Canvas Pos.", w: 70  }
    ]
    readonly property var klaCols: [
        { header: qsTr("Nr."),            w: 50  },
        { header: qsTr("Von (Seite A)"),  w: 210 },
        { header: qsTr("Qs"),             w: 80  },
        { header: qsTr("Farbe"),          w: 90  },
        { header: qsTr("Nach (Seite B)"), w: 210 }
    ]
    property var klCols: [
        { header: "Bezeichnung", w: 110 }, { header: "Kabeltyp",  w: 130 },
        { header: "Adern",       w: 50  }, { header: "mm²",       w: 55  },
        { header: "Länge (m)",   w: 70  }, { header: "Von-Ort",   w: 100 },
        { header: "Nach-Ort",    w: 100 }, { header: "Linien",    w: 50  }
    ]
    property var svCols: [
        { header: "BMK",         w: 80,  field: "bmk" },           { header: "Bezeichnung", w: 120, field: "gkBezeichnung" },
        { header: "Bauteil/Typ", w: 130, field: "bauteilBez" },    { header: "Hersteller",  w: 110, field: "hersteller" },
        { header: "Polzahl",     w: 60,  field: "polzahl" },       { header: "IP gesteckt", w: 75,  field: "ipGesteckt" },
        { header: "Kodierung",   w: 70,  field: "kodierung" },     { header: "Geschirmt",   w: 70,  field: "geschirmt" },
        { header: "Seite",       w: 55,  field: "blattnr" },       { header: "==Anlage",    w: 65,  field: "anlageUO" },
        { header: "++Ort",       w: 65,  field: "ortUO" },         { header: "=Anlage",     w: 55,  field: "anlageKz" },
        { header: "+Ort",        w: 55,  field: "ortKz" },         { header: "Canvas Pos.", w: 70 }
    ]
    property var bpCols: [
        { header: qsTr("Pin"),        w: 45  }, { header: qsTr("Typ"),       w: 90  },
        { header: qsTr("Symbol-BMK"), w: 100 }, { header: qsTr("Signal"),    w: 130 },
        { header: qsTr("Farbe"),      w: 80  }, { header: qsTr("mm²"),       w: 60  },
        { header: qsTr("Seite"),      w: 60  }
    ]
    readonly property var klAderCols: [
        { header: "Nr",          w: 40  }, { header: "Farbe",       w: 70  },
        { header: "Bezeichnung", w: 90  }, { header: "Seite",       w: 80  },
        { header: "Netz",        w: 130 }, { header: "Von",         w: 90  },
        { header: "Nach",        w: 90  }, { header: "",            w: 30  }
    ]
    property var boCols: [
        { header: "Bezeichnung",     w: 180, field: "bezeichnung" },   { header: "Hersteller",    w: 120, field: "hersteller" },
        { header: "Artikelnr.",      w: 110, field: "artikelnummer" }, { header: "Bestellnr.",    w: 110, field: "bestellnummer" },
        { header: "Lieferant",       w: 110, field: "lieferant" },     { header: "Menge",         w: 80,  field: "menge" },
        { header: "Einzelpreis EUR", w: 100, field: "preisEur" },      { header: "Summe EUR",     w: 100, field: "summeEur" }
    ]
    property var asCols: [
        { header: "Aderfarbe",  w: 100, field: "aderfarbe" },      { header: "Querschnitt", w: 90, field: "querschnittMm2" },
        { header: "Anzahl",     w: 70,  field: "anzahl" },         { header: "Gesamtlänge", w: 100, field: "laengeGesamtM" }
    ]

    // ── Spaltenbreiten: Nutzer-Resizing + Persistenz ──────────────────
    // (klaCols/klAderCols bewusst nicht resizebar: klaCols hat handgeschriebene
    // Trennlinien-Offsets statt Repeater-Header, klAderCols ist eine verschachtelte
    // Sub-Tabelle ohne eigene Kopfzeile)
    Settings {
        id: spaltenSettings
        category: "listenansicht_spalten"
        property string slCols: ""
        property string qvCols: ""
        property string alCols: ""
        property string kpCols: ""
        property string klCols: ""
        property string svCols: ""
        property string bpCols: ""
        property string boCols: ""
        property string asCols: ""
    }

    function _spaltenLaden(propName) {
        var json = spaltenSettings[propName]
        if (!json) return
        try {
            var breiten = JSON.parse(json)
            var cols    = panel[propName]
            if (!Array.isArray(breiten) || breiten.length !== cols.length) return
            var neu = cols.map(function (c, i) { return Object.assign({}, c, { w: breiten[i] }) })
            panel[propName] = neu
        } catch (e) { /* ungültiges/altes JSON ignorieren, Default bleibt */ }
    }

    function spaltenSpeichern(propName) {
        var breiten = panel[propName].map(function (c) { return c.w })
        spaltenSettings[propName] = JSON.stringify(breiten)
    }

    Component.onCompleted: {
        _spaltenLaden("slCols"); _spaltenLaden("qvCols")
        _spaltenLaden("alCols"); _spaltenLaden("kpCols")
        _spaltenLaden("klCols"); _spaltenLaden("svCols")
        _spaltenLaden("bpCols"); _spaltenLaden("boCols")
        _spaltenLaden("asCols")
    }

    Rectangle { anchors.fill: parent; color: theme.surface }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ── Titelleiste ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 48; color: theme.sidebar
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                spacing: 12
                Text { text: qsTr("Listen"); font.pixelSize: 16; font.weight: Font.Medium; color: theme.textSecondary }
                Text { text: projektName ? "– " + projektName : ""; font.pixelSize: 13; color: theme.borderLight;
                       Layout.fillWidth: true; elide: Text.ElideRight }
                // ── Netze nummerieren ───────────────────────────────────
                Rectangle {
                    id: numBtn
                    width: 32; height: 32; radius: 6
                    color: numMa.containsMouse ? theme.activeItemAlt : "transparent"
                    Text { anchors.centerIn: parent; text: "N"; font.pixelSize: 14; font.weight: Font.Medium; color: theme.accent }
                    MouseArea {
                        id: numMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: numPopup.open()
                    }
                    ToolTip.visible: numMa.containsMouse; ToolTip.text: qsTr("Verbindungen nummerieren – allen unbeschrifteten Leitungen automatisch fortlaufende Nummern zuweisen"); ToolTip.delay: 400

                    Popup {
                        id: numPopup
                        parent: Overlay.overlay
                        x: numBtn.mapToItem(parent, 0, 0).x - width + numBtn.width
                        y: numBtn.mapToItem(parent, 0, 0).y + numBtn.height + 4
                        width: 240; padding: 12
                        modal: false; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        background: Rectangle {
                            color: theme.surface; radius: 6
                            border.color: theme.border
                            layer.enabled: true
                        }

                        property string _praefix:      ""
                        property int    _start:        1
                        property int    _schrittweite: 1
                        property string _meldung:      ""

                        Column {
                            width: parent.width; spacing: 8

                            Text {
                                text: qsTr("Netze nummerieren")
                                font.pixelSize: 12; font.weight: Font.Medium
                                color: theme.textSecondary
                            }

                            // Präfix
                            Column {
                                width: parent.width; spacing: 3
                                Text { text: qsTr("Präfix"); font.pixelSize: 10; color: theme.panelMid }
                                Rectangle {
                                    width: parent.width; height: 28; radius: 3
                                    color: theme.inputBg; border.color: praefixTf.activeFocus ? theme.accent : theme.border
                                    TextInput {
                                        id: praefixTf
                                        anchors { fill: parent; margins: 5 }
                                        color: theme.textSecondary; font.pixelSize: 11
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: numPopup._praefix
                                        onTextChanged: numPopup._praefix = text
                                    }
                                }
                            }

                            // Startnummer + Schrittweite nebeneinander
                            Row {
                                width: parent.width; spacing: 8
                                Column {
                                    width: (parent.width - 8) / 2; spacing: 3
                                    Text { text: qsTr("Startnummer"); font.pixelSize: 10; color: theme.panelMid }
                                    Rectangle {
                                        width: parent.width; height: 28; radius: 3
                                        color: theme.inputBg; border.color: startTf.activeFocus ? theme.accent : theme.border
                                        TextInput {
                                            id: startTf
                                            anchors { fill: parent; margins: 5 }
                                            color: theme.textSecondary; font.pixelSize: 11
                                            verticalAlignment: TextInput.AlignVCenter
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            text: numPopup._start
                                            onTextChanged: { var n = parseInt(text, 10); if (!isNaN(n) && n >= 1) numPopup._start = n }
                                        }
                                    }
                                }
                                Column {
                                    width: (parent.width - 8) / 2; spacing: 3
                                    Text { text: qsTr("Schrittweite"); font.pixelSize: 10; color: theme.panelMid }
                                    Rectangle {
                                        width: parent.width; height: 28; radius: 3
                                        color: theme.inputBg; border.color: schrittTf.activeFocus ? theme.accent : theme.border
                                        TextInput {
                                            id: schrittTf
                                            anchors { fill: parent; margins: 5 }
                                            color: theme.textSecondary; font.pixelSize: 11
                                            verticalAlignment: TextInput.AlignVCenter
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            text: numPopup._schrittweite
                                            onTextChanged: { var n = parseInt(text, 10); if (!isNaN(n) && n >= 1) numPopup._schrittweite = n }
                                        }
                                    }
                                }
                            }

                            // Meldung nach Ausführung
                            Text {
                                visible: numPopup._meldung !== ""
                                text: numPopup._meldung
                                font.pixelSize: 10; color: theme.accent
                                wrapMode: Text.Wrap; width: parent.width
                            }

                            // Buttons
                            Row {
                                spacing: 8
                                Rectangle {
                                    width: 120; height: 30; radius: 5
                                    color: ausfuehrenMa.containsMouse ? theme.accent : theme.activeItemAlt
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Nummerieren")
                                        font.pixelSize: 11; color: theme.textSecondary
                                    }
                                    MouseArea {
                                        id: ausfuehrenMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var anz = panel.netzeNummerieren(numPopup._praefix,
                                                                              numPopup._start,
                                                                              numPopup._schrittweite)
                                            numPopup._meldung = anz > 0
                                                ? qsTr("%1 Netz(e) nummeriert").arg(anz)
                                                : qsTr("Keine unbeschrifteten Netze")
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 80; height: 30; radius: 5
                                    color: schliesseMa.containsMouse ? theme.hover : "transparent"
                                    border.color: theme.border
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Schließen")
                                        font.pixelSize: 11; color: theme.borderLight
                                    }
                                    MouseArea {
                                        id: schliesseMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { numPopup._meldung = ""; numPopup.close() }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 32; height: 32; radius: 6
                    color: refreshMa.containsMouse ? theme.activeItemAlt : "transparent"
                    Text { anchors.centerIn: parent; text: "↻"; font.pixelSize: 18; color: theme.accent }
                    MouseArea {
                        id: refreshMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Von/Nach per Canvas-Traversal (KABEL-VONNACH-BAUTEIL-01): rechnet
                            // die Adern, deren Kabellinie auf der aktuellen Seite liegt; andere
                            // Seiten behalten ihre gespeicherten Werte.
                            if (panel.projektId >= 0 && panel.canvas)
                                panel.canvas.verdrahtungswegeAktualisieren()
                            panel.laden()
                        }
                    }
                    ToolTip.visible: refreshMa.containsMouse; ToolTip.text: qsTr("Neu laden"); ToolTip.delay: 400
                }
            }
        }

        Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

        // ── Tab-Leiste ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36; color: theme.surface
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 2
                Repeater {
                    // Anzeigereihenfolge nach Themenblöcken (Material → Verdrahtung →
                    // Klemmen → Steckverbinder → Navigation), unabhängig von der
                    // StackLayout-Reihenfolge (tab: verweist weiter auf deren Index).
                    model: [
                        { label: qsTr("Stückliste  (")        + panel._stuecklisteDaten.length     + ")", tab: 0 },
                        { label: qsTr("Bestellliste  (")      + panel._bestellisteDaten.length     + ")", tab: 8 },
                        { label: qsTr("Kabelliste  (")        + panel._kabelDaten.length           + ")", tab: 5 },
                        { label: qsTr("Aderliste  (")         + panel._aderlisteDaten.length       + ")", tab: 2 },
                        { label: qsTr("Adersummenliste  (")   + panel._aderSummenlisteDaten.length + ")", tab: 9 },
                        { label: qsTr("Klemmenplan  (")       + klemmenplanZaehler                 + ")", tab: 3 },
                        { label: qsTr("Klemmlistenauszug  (") + panel._klaAnschlussZaehler         + ")", tab: 4 },
                        { label: qsTr("Steckverbinder  (")    + panel._svDaten.length              + ")", tab: 6 },
                        { label: qsTr("Belegungsplan  (")     + panel._bpKontaktAnzahl             + ")", tab: 7 },
                        { label: qsTr("Querverweise  (")      + panel._querverweisDaten.length     + ")", tab: 1 }
                    ]
                    delegate: Rectangle {
                        width: tabLabel.implicitWidth + 24; height: 28; radius: 5
                        color: tabStack.currentIndex === modelData.tab
                               ? theme.activeItemAlt : (tabMa.containsMouse ? theme.hover : "transparent")
                        border.color: tabStack.currentIndex === modelData.tab ? theme.accent : "transparent"
                        Text {
                            id: tabLabel; anchors.centerIn: parent
                            text: modelData.label; font.pixelSize: 12
                            color: tabStack.currentIndex === modelData.tab ? theme.textSecondary : theme.borderLight
                        }
                        MouseArea {
                            id: tabMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: tabStack.currentIndex = modelData.tab
                        }
                    }
                }
            }
        }

        Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

        // ── Tab-Inhalt ───────────────────────────────────────────
        StackLayout {
            id: tabStack
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: 0

            LaTabStueckliste       { panel: panel; theme: panel.theme }
            LaTabQuerverweise      { panel: panel; theme: panel.theme }
            LaTabAderliste         { panel: panel; theme: panel.theme }
            LaTabKlemmenplan       { panel: panel; theme: panel.theme }
            LaTabKlemmlistenauszug { panel: panel; theme: panel.theme }
            LaTabKabelliste        { panel: panel; theme: panel.theme }
            LaTabSteckverbinder    { panel: panel; theme: panel.theme }
            LaTabBelegungsplan     { panel: panel; theme: panel.theme }
            LaTabBestellliste      { panel: panel; theme: panel.theme }
            LaTabAderSummenliste   { panel: panel; theme: panel.theme }
        }
    }

    DebugLabel { panelName: qsTr("Listen-Ansicht"); visible: panel.debug }
}
