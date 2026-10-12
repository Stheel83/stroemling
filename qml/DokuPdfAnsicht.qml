import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtCore
import "components"
import "la"

// DOKU-PDF-04/-05: Dokumentations-PDF als eigene Ansicht (gleiche Zweispalten-Gestaltung wie der
// SPS/PLS-Export-Tab). Das PDF wird aus Abschnitten zusammengesetzt (Deckblatt, Inhaltsverzeichnis,
// Schaltplan, SPS/PLS-I/O-Liste); Reihenfolge und Auswahl sind einstellbar, Zusammenstellungen
// lassen sich als Vorlage speichern (global, QML-Settings). Der eigentliche Aufbau passiert in
// Database::dokuPdfExportieren() (konzept/features/51_dokumentations_pdf.md).
Item {
    id: root

    required property var theme
    required property int projektId
    required property int seiteId
    property bool         debug: false

    // ── Persistenz: globale Vorlagen + zuletzt benutzte Zusammenstellung ──
    Settings {
        id: einst
        category: "doku_pdf"
        property string vorlagen: "[]"   // JSON: [{name, zustand}]
        property string zuletzt:  ""     // JSON des zuletzt benutzten Zustands
    }

    // SPS-Export-Vorlagen des Export-Tabs. Der Loader erzeugt die Settings bei jedem Öffnen
    // neu, damit zwischenzeitlich im Tab gespeicherte Vorlagen sichtbar sind.
    Loader {
        id: spsEinstLader
        active: root.visible
        sourceComponent: Settings {
            category: "sps_export"
            property string vorlagen: "[]"
            property string zuletzt:  ""
        }
        onLoaded: root._spsVorlagenLaden()
    }

    ListModel { id: abschnittModel }   // typ, titel, aktiv
    ListModel { id: seitenModel }      // sid, label, gewaehlt

    property var    _vorlagen: []
    property var    _spsEintraege: []        // [{name, konfig}]
    property int    _spsAuswahl: 0
    property bool   _spsVorhanden: false
    property string titelzusatz: ""
    property bool   logoAn: true
    property bool   normblattAn: true
    property bool   infostreifenAn: false
    property bool   vollCanvasAn: false
    property int    gewaehlteSeiten: 0
    property int    abschnittVersion: 0   // Zähler: ListModel.get() löst in Bindings keine Neuberechnung aus
    property string spsVorlageName: ""
    // Deckblatt: Blattvorlage (Art "deckblatt") per Name, projektübergreifend wie spsVorlageName
    property string deckblattVorlageName: ""
    property var    _deckblattVorlagen: []

    readonly property var _abschnittTitel: ({
        "deckblatt":          qsTr("Deckblatt"),
        "inhaltsverzeichnis": qsTr("Inhaltsverzeichnis"),
        "schaltplan":         qsTr("Schaltplan"),
        "sps_io":             qsTr("SPS/PLS – I/O-Liste")
    })

    // Listen (DOKU-PDF-05): Katalog aus C++ ([{id, titel}]), Zeilenzahl je Liste (leere Listen sind gesperrt)
    property var  _listenKatalog: []
    property var  _listenAnzahl: ({})
    property bool adersummeJeAnlageOrt: false

    function _titelFuer(typ) {
        if (root._abschnittTitel[typ] !== undefined) return root._abschnittTitel[typ]
        for (var i = 0; i < _listenKatalog.length; i++)
            if ("liste_" + _listenKatalog[i].id === typ) return _listenKatalog[i].titel
        return typ
    }

    function _istListe(typ) { return typ.indexOf("liste_") === 0 }
    function _listenId(typ) { return typ.substring(6) }

    // Listen ohne Einträge können nicht gewählt werden
    function _listeLeer(typ) {
        return _istListe(typ) && _listenAnzahl[_listenId(typ)] === 0
    }

    function _listenAnzahlLaden() {
        var m = {}
        for (var i = 0; i < _listenKatalog.length; i++) {
            var id = _listenKatalog[i].id
            m[id] = db.listenPdfStandard(root.projektId, id).zeilen.length
        }
        _listenAnzahl = m
        abschnittVersion++
    }

    // ── Hilfsfunktionen ──────────────────────────────────────────
    function _abschnittAktiv(typ) {
        var abhaengigkeit = abschnittVersion   // registriert die Abhängigkeit in aufrufenden Bindings
        if (abhaengigkeit < 0) return false
        for (var i = 0; i < abschnittModel.count; i++)
            if (abschnittModel.get(i).typ === typ) return abschnittModel.get(i).aktiv
        return false
    }

    function _standardAbschnitte() {
        var a = [ { typ: "deckblatt", aktiv: true }, { typ: "inhaltsverzeichnis", aktiv: true },
                  { typ: "schaltplan", aktiv: true }, { typ: "sps_io", aktiv: false } ]
        for (var i = 0; i < _listenKatalog.length; i++)
            a.push({ typ: "liste_" + _listenKatalog[i].id, aktiv: false })
        return a
    }

    function _abschnitteSetzen(liste) {
        var typen = ["deckblatt", "inhaltsverzeichnis", "schaltplan", "sps_io"]
        for (var t = 0; t < _listenKatalog.length; t++) typen.push("liste_" + _listenKatalog[t].id)
        var gesehen = {}
        var ergebnis = []
        for (var i = 0; i < liste.length; i++) {
            if (typen.indexOf(liste[i].typ) < 0 || gesehen[liste[i].typ]) continue
            gesehen[liste[i].typ] = true
            ergebnis.push({ typ: liste[i].typ, aktiv: !!liste[i].aktiv })
        }
        // fehlende Typen hinten anhängen (z. B. nach einem Update)
        var std = _standardAbschnitte()
        for (var k = 0; k < std.length; k++)
            if (!gesehen[std[k].typ]) ergebnis.push(std[k])
        abschnittModel.clear()
        for (var j = 0; j < ergebnis.length; j++)
            abschnittModel.append({ typ: ergebnis[j].typ, titel: root._titelFuer(ergebnis[j].typ),
                                    aktiv: ergebnis[j].aktiv })
        abschnittVersion++
    }

    function _zustand() {
        var abs = []
        for (var i = 0; i < abschnittModel.count; i++)
            abs.push({ typ: abschnittModel.get(i).typ, aktiv: abschnittModel.get(i).aktiv })
        var seiten = []
        for (var j = 0; j < seitenModel.count; j++)
            if (seitenModel.get(j).gewaehlt) seiten.push(seitenModel.get(j).schluessel)
        return { abschnitte: abs, seiten: seiten, titelzusatz: root.titelzusatz, logo: root.logoAn,
                 normblatt: root.normblattAn, infostreifen: root.infostreifenAn,
                 vollCanvas: root.vollCanvasAn, adersummeJeAnlageOrt: root.adersummeJeAnlageOrt,
                 spsVorlage: root.spsVorlageName, deckblattVorlage: root.deckblattVorlageName }
    }

    // mitSeiten=true: auch die gespeicherte Seitenauswahl anwenden (Vorlagen). Für "zuletzt benutzt" nein -
    // dort gilt die dauerhafte Seiten-Voreinstellung (Flag). Seiten werden über Anlage|Ort|Blatt zugeordnet,
    // da Vorlagen projektübergreifend sind; passt keine Seite, bleibt die Voreinstellung.
    function _zustandLaden(z, mitSeiten) {
        if (!z) z = {}
        _abschnitteSetzen(z.abschnitte || _standardAbschnitte())
        root.titelzusatz     = z.titelzusatz || ""
        root.logoAn          = z.logo === undefined ? true : !!z.logo
        root.normblattAn     = z.normblatt === undefined ? true : !!z.normblatt
        root.infostreifenAn  = !!z.infostreifen
        root.vollCanvasAn    = !!z.vollCanvas
        root.adersummeJeAnlageOrt = !!z.adersummeJeAnlageOrt
        root.spsVorlageName = z.spsVorlage || ""
        root.deckblattVorlageName = z.deckblattVorlage || ""
        _spsAuswahlSetzen()
        if (mitSeiten && z.seiten) _seitenAuswahlAnwenden(z.seiten)
    }

    function _seitenAuswahlAnwenden(schluessel) {
        var treffer = 0
        for (var i = 0; i < seitenModel.count; i++)
            if (schluessel.indexOf(seitenModel.get(i).schluessel) >= 0) treffer++
        if (treffer === 0 && schluessel.length > 0) {
            meldungManager.zeigen(qsTr("Die Seitenauswahl der Vorlage passt nicht zu den Seiten dieses Projekts – "
                                       + "es gilt die Seiten-Voreinstellung."), false)
            return
        }
        for (var j = 0; j < seitenModel.count; j++)
            seitenModel.setProperty(j, "gewaehlt", schluessel.indexOf(seitenModel.get(j).schluessel) >= 0)
        _seitenZaehlen()
    }

    // Wählt den SPS-Eintrag passend zu spsVorlageName (die Liste wird erst beim Öffnen per Loader gefüllt).
    function _spsAuswahlSetzen() {
        _spsAuswahl = 0
        for (var i = 0; i < _spsEintraege.length; i++)
            if (_spsEintraege[i].name === root.spsVorlageName) _spsAuswahl = i
    }

    function _spsVorlagenLaden() {
        var eintraege = [ { name: qsTr("(Standard)"), konfig: JSON.parse(db.spsExportStandardKonfig()) } ]
        var einstSps = spsEinstLader.item
        if (einstSps) {
            try {
                var z = einstSps.zuletzt ? JSON.parse(einstSps.zuletzt) : null
                if (z && z.spalten && z.spalten.length > 0)
                    eintraege.push({ name: qsTr("(Zuletzt im Export-Tab)"), konfig: z })
            } catch (e) { }
            try {
                var v = JSON.parse(einstSps.vorlagen) || []
                for (var i = 0; i < v.length; i++) eintraege.push({ name: v[i].name, konfig: v[i].konfig })
            } catch (e2) { }
        }
        _spsEintraege = eintraege
        _spsAuswahlSetzen()
    }

    function _seitenNeuLaden() {
        seitenModel.clear()
        var liste = db.dokuPdfSeitenListe(root.projektId)
        for (var i = 0; i < liste.length; i++) {
            var s = liste[i]
            var t = "=" + s.anlage + " +" + s.ort + "   " + qsTr("Blatt %1").arg(s.blatt)
            if (s.bezeichnung) t += "  –  " + s.bezeichnung
            seitenModel.append({ sid: s.id, label: t, gewaehlt: s.inDokuPdf,
                                 schluessel: s.anlage + "|" + s.ort + "|" + s.blatt })
        }
        _seitenZaehlen()
    }

    function _seitenZaehlen() {
        var n = 0
        for (var i = 0; i < seitenModel.count; i++) if (seitenModel.get(i).gewaehlt) n++
        root.gewaehlteSeiten = n
    }

    function _alleSeiten(wert) {
        for (var i = 0; i < seitenModel.count; i++) seitenModel.setProperty(i, "gewaehlt", wert)
        _seitenZaehlen()
    }

    function _nurAktuelleSeite() {
        for (var i = 0; i < seitenModel.count; i++)
            seitenModel.setProperty(i, "gewaehlt", seitenModel.get(i).sid === root.seiteId)
        _seitenZaehlen()
    }

    function _alsFlagUebernehmen() {
        for (var i = 0; i < seitenModel.count; i++)
            db.seiteInDokuPdfSetzen(seitenModel.get(i).sid, seitenModel.get(i).gewaehlt)
        meldungManager.zeigen(qsTr("Auswahl als Seiten-Voreinstellung gespeichert."), true)
    }

    function _optionenJson() {
        var abs = []
        for (var i = 0; i < abschnittModel.count; i++) {
            var a = abschnittModel.get(i)
            if (!a.aktiv) continue
            if (a.typ === "deckblatt")
                abs.push({ typ: "deckblatt", titelzusatz: root.titelzusatz, logo: root.logoAn,
                           vorlageId: _deckblattVorlageId() })
            else if (a.typ === "sps_io")
                abs.push({ typ: "sps_io", konfig: _spsEintraege[_spsAuswahl].konfig })
            else if (root._istListe(a.typ)) {
                if (root._listeLeer(a.typ)) continue   // leere Listen entfallen (auch im C++-Export)
                var lid = root._listenId(a.typ)
                abs.push({ typ: "liste", liste: lid,
                           jeAnlageOrt: lid === "adersummenliste" ? root.adersummeJeAnlageOrt : false })
            }
            else
                abs.push({ typ: a.typ })
        }
        var ids = []
        for (var j = 0; j < seitenModel.count; j++)
            if (seitenModel.get(j).gewaehlt) ids.push(seitenModel.get(j).sid)
        return JSON.stringify({
            mitNormblatt:    root.normblattAn && !root.vollCanvasAn,
            vollCanvas:      root.vollCanvasAn,
            mitInfostreifen: root.infostreifenAn,
            seiteIds:        ids,
            abschnitte:      abs
        })
    }

    readonly property bool exportMoeglich: {
        var version = abschnittVersion
        var irgendeinAktiv = version < 0
        for (var i = 0; i < abschnittModel.count; i++)
            if (abschnittModel.get(i).aktiv && !_listeLeer(abschnittModel.get(i).typ)) irgendeinAktiv = true
        if (!irgendeinAktiv) return false
        if (_abschnittAktiv("schaltplan") && gewaehlteSeiten === 0) return false
        if (_abschnittAktiv("sps_io") && !_spsVorhanden) return false
        return true
    }

    // Vorlagen
    function _vorlagenSpeichern() { einst.vorlagen = JSON.stringify(_vorlagen) }

    function _vorlageSpeichern(name) {
        var neu = _vorlagen.slice()
        var gefunden = -1
        for (var i = 0; i < neu.length; i++) if (neu[i].name === name) gefunden = i
        if (gefunden >= 0) neu[gefunden] = { name: name, zustand: _zustand() }
        else neu.push({ name: name, zustand: _zustand() })
        _vorlagen = neu
        _vorlagenSpeichern()
        vorlageCombo.currentIndex = _idxVorlage(name)
        meldungManager.zeigen(qsTr("Vorlage \"%1\" gespeichert").arg(name), true)
    }

    function _idxVorlage(name) {
        for (var i = 0; i < _vorlagen.length; i++) if (_vorlagen[i].name === name) return i + 1
        return 0
    }

    function _vorlageLoeschen() {
        var i = vorlageCombo.currentIndex - 1
        if (i < 0 || i >= _vorlagen.length) return
        var neu = _vorlagen.slice()
        neu.splice(i, 1)
        _vorlagen = neu
        _vorlagenSpeichern()
        vorlageCombo.currentIndex = 0
    }

    function _deckblattVorlagenLaden() {
        _deckblattVorlagen = db.normblattVorlagenListe().filter(function(v) { return v.art === "deckblatt" })
    }
    // Id der gewählten Vorlage; 0 = die erste Deckblattvorlage (C++ wählt)
    function _deckblattVorlageId() {
        for (var i = 0; i < _deckblattVorlagen.length; i++)
            if (_deckblattVorlagen[i].name === root.deckblattVorlageName) return _deckblattVorlagen[i].id
        return 0
    }

    // Beim Einblenden den Zustand frisch laden (zuletzt benutzte Zusammenstellung, Seiten-Flags, SPS-Vorlagen)
    function oeffnen() {
        if (root.projektId < 0) return
        try { _vorlagen = JSON.parse(einst.vorlagen) || [] } catch (e) { _vorlagen = [] }
        var z = null
        if (einst.zuletzt) { try { z = JSON.parse(einst.zuletzt) } catch (e2) { z = null } }
        _spsVorhanden = db.spsRackListe(root.projektId).length > 0
        _deckblattVorlagenLaden()
        _listenKatalog = db.listenPdfKatalog()
        _listenAnzahlLaden()
        _seitenNeuLaden()
        _zustandLaden(z, false)
        vorlageCombo.currentIndex = 0
    }

    onVisibleChanged: if (visible) oeffnen()
    onProjektIdChanged: if (visible) oeffnen()
    Component.onCompleted: if (visible) oeffnen()

    // ── Wiederverwendbare Bedienelemente ─────────────────────────
    // wert = anzuzeigender Zustand (Bindung bleibt auch nach einem Klick erhalten, sonst würde
    // ein später geladener Zustand nicht mehr angezeigt); umgeschaltet(neu) meldet die Benutzeraktion.
    component Kaestchen: CheckBox {
        id: kb
        property string beschriftung: ""
        property bool   wert: false
        signal umgeschaltet(bool neu)
        checked: wert
        onToggled: {
            var n = kb.checked
            kb.checked = Qt.binding(function() { return kb.wert })
            kb.umgeschaltet(n)
        }
        implicitHeight: 26
        indicator: Item {
            implicitWidth: 14; implicitHeight: 14
            x: kb.leftPadding; y: (kb.height - height) / 2
            Rectangle {
                anchors.fill: parent; radius: 3
                color: kb.checked ? root.theme.accent : "transparent"
                border.color: kb.checked ? root.theme.accent : root.theme.border
                border.width: 1.5
                opacity: kb.enabled ? 1 : 0.5
            }
            Text {
                anchors.centerIn: parent
                text: "✓"; font.pixelSize: 10; font.bold: true
                color: root.theme.sidebar; visible: kb.checked
            }
        }
        contentItem: Text {
            text: kb.beschriftung
            color: kb.enabled ? root.theme.textPrimary : root.theme.textMuted
            font.pixelSize: 12
            leftPadding: 22
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    // Auswahlliste im Stil des SPS-Export-Tabs (Hintergrund/Text aus dem Theme)
    component Auswahl: ComboBox {
        id: ab
        implicitHeight: 28
        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
        contentItem: Text {
            text: ab.displayText; color: root.theme.textPrimary; font.pixelSize: 12
            leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
    }

    component KleinerButton: Button {
        id: kbtn
        implicitHeight: 26
        implicitWidth: Math.max(26, kt.implicitWidth + 16)
        contentItem: Text {
            id: kt
            text: kbtn.text
            color: kbtn.enabled ? root.theme.textSecondary : root.theme.textMuted
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: kbtn.hovered && kbtn.enabled ? root.theme.hover : root.theme.inputBg
            radius: 4; border.color: root.theme.border
        }
    }

    // ── Pfadwahl (eigener Picker, AppImage-tauglich) ─────────────
    LaPdfExportDialog {
        id: pfadDialog
        theme: root.theme
        dateiname: "dokumentation.pdf"
        titelText: qsTr("Dokumentations-PDF speichern")
        erfolgText: qsTr("Dokumentations-PDF gespeichert.")
        onExportAngefordert: function(pfad) {
            var ok = db.dokuPdfExportieren(root.projektId, pfad, root._optionenJson())
            pfadDialog.erfolgReagieren(ok)
            if (ok) {
                einst.zuletzt = JSON.stringify(root._zustand())
                achievementManager.ereignis("pdf_exportiert", { "seitenAnzahl": root.gewaehlteSeiten })
            }
        }
    }

    // ── Vorlage speichern ────────────────────────────────────────
    Dialog {
        id: nameDialog
        title: qsTr("Vorlage speichern")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }
        onOpened: { nameFeld.text = vorlageCombo.currentIndex > 0 ? root._vorlagen[vorlageCombo.currentIndex - 1].name : ""
                    nameFeld.forceActiveFocus() }
        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Name der Vorlage"); color: root.theme.textMuted; font.pixelSize: 11 }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Die Vorlage enthält Abschnitte, Optionen und die aktuelle Seitenauswahl.")
                color: root.theme.textMuted; font.pixelSize: 11
            }
            TextField {
                id: nameFeld
                Layout.fillWidth: true
                color: root.theme.textPrimary; font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onAccepted: if (text.trim().length > 0) { root._vorlageSpeichern(text.trim()); nameDialog.accept() }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Button {
                    text: qsTr("Abbrechen"); Layout.fillWidth: true; implicitHeight: 32
                    onClicked: nameDialog.reject()
                    contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                }
                Button {
                    text: qsTr("Speichern"); Layout.fillWidth: true; implicitHeight: 32
                    enabled: nameFeld.text.trim().length > 0
                    onClicked: { root._vorlageSpeichern(nameFeld.text.trim()); nameDialog.accept() }
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                }
            }
        }
    }

    // ── Oberfläche ───────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Kopfleiste
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: root.theme.surfaceDeep
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 14
                text: qsTr("Dokumentations-PDF")
                color: root.theme.textPrimary; font.pixelSize: 15; font.bold: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right; anchors.rightMargin: 14
                text: qsTr("Deckblatt, Verzeichnis, Schaltplan und SPS/PLS in einem PDF")
                color: root.theme.textMuted; font.pixelSize: 12
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.border }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            spacing: 14

            // ── Links: Zusammenstellung + Abschnitte ─────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 8

                Text { text: qsTr("Zusammenstellung"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13 }

                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Auswahl {
                        id: vorlageCombo
                        Layout.fillWidth: true
                        model: [qsTr("(zuletzt benutzt)")].concat(root._vorlagen.map(function(v) { return v.name }))
                        onActivated: function(i) {
                            if (i === 0) {
                                var z = null
                                try { z = einst.zuletzt ? JSON.parse(einst.zuletzt) : null } catch (e) { z = null }
                                root._zustandLaden(z, false)
                            } else {
                                root._zustandLaden(root._vorlagen[i - 1].zustand, true)
                            }
                        }
                    }
                    KleinerButton { text: qsTr("Speichern unter …"); onClicked: nameDialog.open() }
                    KleinerButton {
                        text: qsTr("Löschen"); enabled: vorlageCombo.currentIndex > 0
                        onClicked: root._vorlageLoeschen()
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.border }

                Text {
                    text: qsTr("Abschnitte")
                    color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13
                }
                Text {
                    text: qsTr("Die Reihenfolge der Liste ist die Reihenfolge im PDF.")
                    color: root.theme.textMuted; font.pixelSize: 11
                }

                ScrollView {
                    id: abschnittScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth

                ColumnLayout {
                    width: abschnittScroll.availableWidth
                    spacing: 6

                Repeater {
                    model: abschnittModel
                    delegate: ColumnLayout {
                        id: zeile
                        required property int index
                        required property string typ
                        required property string titel
                        required property bool aktiv
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Kaestchen {
                                Layout.fillWidth: true
                                beschriftung: zeile.titel
                                wert: zeile.aktiv
                                enabled: (zeile.typ !== "sps_io" || root._spsVorhanden) && !root._listeLeer(zeile.typ)
                                onUmgeschaltet: function(neu) {
                                    abschnittModel.setProperty(zeile.index, "aktiv", neu)
                                    root.abschnittVersion++
                                }
                            }
                            Text {
                                visible: zeile.typ === "sps_io" && !root._spsVorhanden
                                text: qsTr("keine SPS/PLS-Daten im Projekt")
                                color: root.theme.textMuted; font.pixelSize: 11
                            }
                            Text {
                                visible: root._istListe(zeile.typ)
                                text: root._listeLeer(zeile.typ) ? qsTr("keine Einträge")
                                      : qsTr("%1 Zeilen").arg(root._listenAnzahl[root._listenId(zeile.typ)])
                                color: root.theme.textMuted; font.pixelSize: 11
                            }
                            KleinerButton {
                                text: "▲"; enabled: zeile.index > 0
                                onClicked: { abschnittModel.move(zeile.index, zeile.index - 1, 1); root.abschnittVersion++ }
                            }
                            KleinerButton {
                                text: "▼"; enabled: zeile.index < abschnittModel.count - 1
                                onClicked: { abschnittModel.move(zeile.index, zeile.index + 1, 1); root.abschnittVersion++ }
                            }
                        }

                        // Optionen des Abschnitts, eingerückt direkt darunter
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 24
                            spacing: 8
                            visible: zeile.aktiv && zeile.typ === "deckblatt"
                            Text { text: qsTr("Vorlage"); color: root.theme.textMuted; font.pixelSize: 11 }
                            Auswahl {
                                Layout.preferredWidth: 200
                                model: root._deckblattVorlagen.map(function(v) { return v.name })
                                currentIndex: Math.max(0, root._deckblattVorlagen.map(function(v) { return v.name })
                                                          .indexOf(root.deckblattVorlageName))
                                onActivated: function(i) { root.deckblattVorlageName = root._deckblattVorlagen[i].name }
                            }
                            Text { text: qsTr("Titelzusatz"); color: root.theme.textMuted; font.pixelSize: 11 }
                            TextField {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                placeholderText: qsTr("z. B. Schaltplan Steuerung Anlage 2 (optional)")
                                text: root.titelzusatz
                                onTextEdited: root.titelzusatz = text
                                color: root.theme.textPrimary; font.pixelSize: 12
                                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                            }
                            Kaestchen {
                                beschriftung: qsTr("Logo")
                                wert: root.logoAn
                                onUmgeschaltet: function(neu) { root.logoAn = neu }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 24
                            spacing: 8
                            visible: zeile.aktiv && zeile.typ === "sps_io" && root._spsVorhanden
                            Text { text: qsTr("Spalten und Filter wie"); color: root.theme.textMuted; font.pixelSize: 11 }
                            Auswahl {
                                Layout.fillWidth: true
                                model: root._spsEintraege.map(function(e) { return e.name })
                                currentIndex: root._spsAuswahl
                                onActivated: function(i) { root._spsAuswahl = i; root.spsVorlageName = root._spsEintraege[i].name }
                            }
                        }

                        Kaestchen {
                            Layout.leftMargin: 24
                            visible: zeile.aktiv && zeile.typ === "liste_adersummenliste"
                            beschriftung: qsTr("je Anlage/Ort gruppieren")
                            wert: root.adersummeJeAnlageOrt
                            onUmgeschaltet: function(neu) { root.adersummeJeAnlageOrt = neu }
                        }

                        Text {
                            Layout.leftMargin: 24
                            visible: zeile.aktiv && zeile.typ === "schaltplan"
                            text: qsTr("%1 von %2 Seiten ausgewählt (rechts ändern)").arg(root.gewaehlteSeiten).arg(seitenModel.count)
                            color: root.theme.textMuted; font.pixelSize: 11
                        }
                    }
                }
                }   // ColumnLayout
                }   // ScrollView
            }

            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: root.theme.border }

            // ── Rechts: Schaltplan-Seiten + Optionen ─────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 8
                enabled: root._abschnittAktiv("schaltplan")
                opacity: enabled ? 1.0 : 0.45

                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text {
                        text: qsTr("Schaltplan-Seiten (%1 von %2)").arg(root.gewaehlteSeiten).arg(seitenModel.count)
                        color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                    KleinerButton { text: qsTr("Alle");  onClicked: root._alleSeiten(true) }
                    KleinerButton { text: qsTr("Keine"); onClicked: root._alleSeiten(false) }
                    KleinerButton {
                        text: qsTr("Nur aktuelle"); enabled: root.seiteId > 0
                        onClicked: root._nurAktuelleSeite()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.theme.inputBg
                    radius: 4; border.color: root.theme.border
                    clip: true

                    ListView {
                        id: seitenListe
                        anchors.fill: parent
                        anchors.margins: 4
                        model: seitenModel
                        clip: true
                        ScrollBar.vertical: ScrollBar { }
                        delegate: Kaestchen {
                            required property int index
                            required property string label
                            required property bool gewaehlt
                            width: seitenListe.width - 10
                            implicitHeight: 26
                            beschriftung: label
                            wert: gewaehlt
                            onUmgeschaltet: function(neu) { seitenModel.setProperty(index, "gewaehlt", neu); root._seitenZaehlen() }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: seitenModel.count === 0
                            text: qsTr("Das Projekt hat noch keine Seiten.")
                            color: root.theme.textMuted; font.pixelSize: 12
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    KleinerButton {
                        text: qsTr("Auswahl als Voreinstellung der Seiten speichern")
                        onClicked: root._alsFlagUebernehmen()
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Schreibt die Auswahl dauerhaft in die Seiten (Option „In Dokumentations-PDF aufnehmen“ im Seite-bearbeiten-Dialog).")
                    }
                    Item { Layout.fillWidth: true }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.border }

                Kaestchen {
                    Layout.fillWidth: true
                    beschriftung: qsTr("Normblatt einschließen")
                    wert: root.normblattAn && !root.vollCanvasAn
                    enabled: !root.vollCanvasAn
                    onUmgeschaltet: function(neu) { root.normblattAn = neu }
                }
                Kaestchen {
                    Layout.fillWidth: true
                    beschriftung: qsTr("Infostreifen für Seiten ohne Schriftfeld")
                    wert: root.infostreifenAn
                    onUmgeschaltet: function(neu) { root.infostreifenAn = neu }
                }
                Kaestchen {
                    Layout.fillWidth: true
                    beschriftung: qsTr("Ganzes Canvas (ohne Normblatt)")
                    wert: root.vollCanvasAn
                    onUmgeschaltet: function(neu) { root.vollCanvasAn = neu }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.border }

        // ── Fußleiste: Hinweis + Export ──────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            color: root.theme.surfaceDeep

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: root.exportMoeglich ? root.theme.textMuted : root.theme.accent
                    font.pixelSize: 12
                    text: {
                        var aktiv = root.abschnittVersion < 0
                        var n = 0
                        for (var i = 0; i < abschnittModel.count; i++)
                            if (abschnittModel.get(i).aktiv) { aktiv = true; n++ }
                        if (!aktiv) return qsTr("Mindestens ein Abschnitt muss ausgewählt sein.")
                        if (root._abschnittAktiv("schaltplan") && root.gewaehlteSeiten === 0)
                            return qsTr("Für den Schaltplan ist keine Seite ausgewählt.")
                        if (root._abschnittAktiv("sps_io") && !root._spsVorhanden)
                            return qsTr("Der SPS/PLS-Abschnitt braucht SPS/PLS-Daten im Projekt.")
                        return qsTr("%1 Abschnitte, %2 Schaltplan-Seiten").arg(n).arg(
                            root._abschnittAktiv("schaltplan") ? root.gewaehlteSeiten : 0)
                    }
                }

                Button {
                    text: qsTr("Exportieren …")
                    implicitWidth: 200; implicitHeight: 32
                    enabled: root.exportMoeglich
                    onClicked: pfadDialog.open()
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Dokumentations-PDF-Ansicht"); visible: root.debug && root.visible }
}
