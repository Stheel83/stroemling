import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

Item {
    id: root

    property int projektId: -1
    property var theme
    property bool debug: false
    property string projektName: ""

    // SPS-SPRUNG-01: Sprung vom Kanal zum Schaltplan-Element (Signatur wie die
    // übrigen Sprungsignale, Main.qml leitet an seiteOeffnenUndZentrieren weiter)
    signal sprungAngefordert(int seiteId, string blattnr, string seiteBez, real wx, real wy)

    function _kannSpringen(k) {
        return !!k && !!k.grafik_element_id && k.seite_id != null && k.welt_x != null
    }

    function _springeZuKanal(k) {
        if (!_kannSpringen(k)) return
        root.sprungAngefordert(k.seite_id, k.seite_blatt || "", k.seite_name || "", k.welt_x, k.welt_y)
    }

    // ── Auswahl-State ────────────────────────────────────────────
    property int _ausgewaehlterRackId:      -1
    property int _ausgewaehlterRackNr:       0
    property string _ausgewaehlterSystemTyp: "SPS"
    property int _ausgewaehlterBaugruppeId: -1
    property int _ausgewaehlterKanalId:     -1

    // ── Daten ────────────────────────────────────────────────────
    property var _racks:       []
    property var _baugruppen:  []
    property var _kanaele:     []
    property string _kanalFilter: "alle"
    property var _pendingAutoAnlegenBg: null

    // SPS-KANAL-FILTER-ERWEITERT-01: 1:1 aus EpSpsKanalSection.qml::_kanalTyp()
    // übernommen - löst DIO/AIO-Baugruppen anhand der Adress-Richtung in
    // DI/DO bzw. AI/AO auf, statt sie unter ihrem Baugruppen-Rohtyp zu verstecken.
    function _kanalTyp(kanal) {
        var bgTyp = (kanal.baugruppe_typ || "").toUpperCase()
        if (bgTyp === "DIO") return kanal.adress_typ === "A" ? "DO" : "DI"
        if (bgTyp === "AIO") return kanal.adress_typ === "A" ? "AO" : "AI"
        return bgTyp
    }

    // SPS-BELEGUNG-01: Belegung je Baugruppe. Als Property-Bindings mit Argumenten
    // geschrieben, damit sie sich bei Änderung von Kanälen/Baugruppen/Auswahl neu
    // auswerten (reine Funktionsaufrufe ohne Property-Argumente würden nur einmal laufen).
    readonly property var _keinIoTypen: ["CPU", "PS", "CP", "FM", "andere"]

    function _belegungBerechnen(kanaele) {
        var m = {}
        for (var i = 0; i < kanaele.length; i++) {
            var k = kanaele[i]
            if (k.baugruppe_id == null) continue
            var b = m[k.baugruppe_id] || (m[k.baugruppe_id] = { element: 0, beschriftet: 0, frei: 0, angelegt: 0 })
            b.angelegt++
            if (k.grafik_element_id) b.element++
            else if ((k.variablenname || "") !== "" || (k.kommentar || "") !== "") b.beschriftet++
            else b.frei++
        }
        return m
    }

    // Eine Zeile je Kanal-Nr. 0..kanaele-1 der Baugruppe; nicht angelegte Nummern
    // erscheinen als leere Platzhalter (leer: true), Kanäle außerhalb des Bereichs
    // werden hinten angehängt (ausserhalb: true). Baugruppen ohne I/O (CPU, PS, ...)
    // bekommen keine Platzhalter.
    function _bgKanalZeilenBerechnen(bgId, kanaele, baugruppen) {
        if (bgId < 0) return []
        var bg = null
        for (var i = 0; i < baugruppen.length; i++)
            if (baugruppen[i].id === bgId) { bg = baugruppen[i]; break }
        if (!bg) return []
        var n = _keinIoTypen.indexOf(bg.typ) >= 0 ? 0 : bg.kanaele
        var jeNr = {}, rest = []
        for (var j = 0; j < kanaele.length; j++) {
            var k = kanaele[j]
            if (k.baugruppe_id !== bgId) continue
            if (k.kanal_nr != null && k.kanal_nr >= 0 && k.kanal_nr < n)
                (jeNr[k.kanal_nr] = jeNr[k.kanal_nr] || []).push(k)
            else
                rest.push(k)
        }
        var out = []
        for (var nr = 0; nr < n; nr++) {
            if (jeNr[nr]) {
                for (var q = 0; q < jeNr[nr].length; q++)
                    out.push({ kanal: jeNr[nr][q], nr: nr, leer: false, ausserhalb: false })
            } else {
                out.push({ kanal: null, nr: nr, leer: true, ausserhalb: false })
            }
        }
        for (var r = 0; r < rest.length; r++)
            out.push({ kanal: rest[r], nr: rest[r].kanal_nr, leer: false, ausserhalb: true })
        return out
    }

    property var _belegungMap: _belegungBerechnen(_kanaele)
    property var _bgKanalZeilen: _bgKanalZeilenBerechnen(_ausgewaehlterBaugruppeId, _kanaele, _baugruppen)

    function _ladeRacks() {
        if (root.projektId < 0) { _racks = []; return }
        _racks = db.spsRackListe(root.projektId)
        if (_ausgewaehlterRackId < 0 && _racks.length > 0) {
            _waehleRack(_racks[0])
        } else {
            _ladeBaugruppen()
        }
    }

    function _waehleRack(rack) {
        _ausgewaehlterRackId      = rack.id
        _ausgewaehlterRackNr      = rack.rack_nr
        _ausgewaehlterSystemTyp   = rack.system_typ
        _ausgewaehlterBaugruppeId = -1
        _ladeBaugruppen()
    }

    function _ladeBaugruppen() {
        if (_ausgewaehlterRackId < 0) { _baugruppen = []; return }
        _baugruppen = db.spsBaugruppeListe(_ausgewaehlterRackId)
        _ladeKanaele()
    }

    function _ladeKanaele() {
        if (root.projektId < 0) { _kanaele = []; return }
        _kanaele = db.spsKanalListe(root.projektId)
    }

    // ── Löschen mit Rückfrage (SPS-LOESCHEN-01) ───────────────────
    // _loeschAktion: { typ: "rack"|"baugruppe"|"kanal", id: int }
    property var _loeschAktion: null

    function _kanaeleDerBaugruppen(bgIds) {
        var r = []
        for (var i = 0; i < _kanaele.length; i++)
            if (bgIds.indexOf(_kanaele[i].baugruppe_id) >= 0) r.push(_kanaele[i])
        return r
    }

    function _kanalHatInhalt(k) {
        return !!k.grafik_element_id || (k.variablenname || "") !== "" || (k.kommentar || "") !== ""
    }

    function _kanalLoeschenFragen(k) {
        // Leere, unverknüpfte Kanäle (z.B. frisch per ⚡ angelegt) ohne Rückfrage löschen
        if (!_kanalHatInhalt(k)) { _loeschenAusfuehren("kanal", k.id, false); return }
        _loeschAktion = { typ: "kanal", id: k.id }
        var t = qsTr("Kanal %1 wirklich löschen?").arg(k.adresse || "?")
        if (k.variablenname) t += "\n" + qsTr("Variable / Tag: %1").arg(k.variablenname)
        if (k.grafik_element_id)
            t += "\n\n" + qsTr("Die Verknüpfung mit dem Schaltplan-Element wird aufgelöst.")
        loeschDialog.titel = qsTr("Kanal löschen")
        loeschDialog.text = t
        loeschDialog.gefahr = !!k.grafik_element_id
        loeschDialog.optionText = ""
        loeschDialog.open()
    }

    function _baugruppeLoeschenFragen(bg) {
        var kanaele = _kanaeleDerBaugruppen([bg.id])
        _loeschAktion = { typ: "baugruppe", id: bg.id }
        loeschDialog.titel = qsTr("Baugruppe löschen")
        loeschDialog.text = _loeschText(qsTr("Baugruppe \"%1\" (Slot %2)").arg(bg.bezeichnung || bg.typ).arg(bg.slot),
                                         0, kanaele)
        loeschDialog.gefahr = kanaele.length > 0
        loeschDialog.optionText = kanaele.length > 0 ? qsTr("Kanäle ebenfalls löschen") : ""
        loeschDialog.optionWert = false
        loeschDialog.open()
    }

    function _rackLoeschenFragen(rack) {
        var bgs = db.spsBaugruppeListe(rack.id)
        var ids = bgs.map(function(b) { return b.id })
        var kanaele = _kanaeleDerBaugruppen(ids)
        _loeschAktion = { typ: "rack", id: rack.id }
        loeschDialog.titel = qsTr("Rack löschen")
        loeschDialog.text = _loeschText(qsTr("Rack \"%1\" (%2, R%3)").arg(rack.bezeichnung || ("Rack " + rack.rack_nr))
                                         .arg(rack.system_typ).arg(rack.rack_nr), bgs.length, kanaele)
        loeschDialog.gefahr = bgs.length > 0 || kanaele.length > 0
        loeschDialog.optionText = kanaele.length > 0 ? qsTr("Kanäle ebenfalls löschen") : ""
        loeschDialog.optionWert = false
        loeschDialog.open()
    }

    // Gemeinsamer Hinweistext. Wichtig: ohne Haken bleiben die Kanäle ERHALTEN
    // (sps_kanal.baugruppe_id ist ON DELETE SET NULL) - sie verlieren nur die Baugruppe.
    function _loeschText(was, anzahlBaugruppen, kanaele) {
        var mitElement = 0
        for (var i = 0; i < kanaele.length; i++) if (kanaele[i].grafik_element_id) mitElement++
        var t = qsTr("%1 wirklich löschen?").arg(was)
        if (anzahlBaugruppen > 0)
            t += "\n\n" + qsTr("%1 Baugruppe(n) werden mitgelöscht.").arg(anzahlBaugruppen)
        if (kanaele.length > 0) {
            t += "\n\n" + qsTr("%1 Kanal/Kanäle gehören dazu, davon %2 mit Schaltplan-Element.").arg(kanaele.length).arg(mitElement)
            t += "\n" + qsTr("Ohne Haken bleiben sie erhalten, haben dann aber keine Baugruppe mehr (DRC meldet sie).")
        }
        return t
    }

    function _loeschenAusfuehren(typ, id, kanaeleMitLoeschen) {
        if (typ === "kanal") {
            if (db.spsKanalLoeschen(id)) {
                if (_ausgewaehlterKanalId === id) _ausgewaehlterKanalId = -1
                _ladeKanaele()
            }
            return
        }
        var bgIds = [id]
        if (typ === "rack")
            bgIds = db.spsBaugruppeListe(id).map(function(b) { return b.id })
        if (kanaeleMitLoeschen) {
            var ks = _kanaeleDerBaugruppen(bgIds)
            for (var i = 0; i < ks.length; i++) db.spsKanalLoeschen(ks[i].id)
        }
        if (typ === "rack") {
            if (db.spsRackLoeschen(id)) { _ausgewaehlterRackId = -1; _ausgewaehlterBaugruppeId = -1; _ladeRacks() }
        } else {
            if (db.spsBaugruppeLoeschen(id)) {
                if (_ausgewaehlterBaugruppeId === id) _ausgewaehlterBaugruppeId = -1
                _ladeBaugruppen()
            }
        }
    }

    function _ausgewaehlteBaugruppeInfo() {
        for (var i = 0; i < _baugruppen.length; i++)
            if (_baugruppen[i].id === _ausgewaehlterBaugruppeId) return _baugruppen[i]
        return null
    }

    function _ausgewaehlterRackInfo() {
        for (var i = 0; i < _racks.length; i++)
            if (_racks[i].id === _ausgewaehlterRackId) return _racks[i]
        return null
    }

    function _kanaeleAutoAnlegen(bg) {
        if (!bg) return
        var keinIO = ["CPU", "PS", "CP", "FM", "andere"]
        for (var ki = 0; ki < keinIO.length; ki++) {
            if (bg.typ === keinIO[ki]) {
                meldungManager.zeigen(qsTr("%1-Baugruppen haben keine I/O-Kanäle").arg(bg.typ), false)
                return
            }
        }
        var isPls  = root._ausgewaehlterSystemTyp === "PLS"
        var n      = bg.kanaele
        var count  = 0
        var i, newId, byteNr, bitNr

        if (isPls) {
            var adressTypPls = (bg.typ === "AO" || bg.typ === "DO") ? "A" : "E"
            for (i = 0; i < n; i++) {
                newId = db.spsKanalAnlegen(root.projektId, bg.id, i,
                                           adressTypPls, 0, 0, "REAL", "", "")
                if (newId > 0) count++
            }
        } else {
            var isAnalog = (bg.typ === "AI" || bg.typ === "AO" || bg.typ === "AIO")
            var isDual   = (bg.typ === "DIO" || bg.typ === "AIO")
            var datentyp = isAnalog ? "WORD" : "BOOL"
            var byteStep = isAnalog ? 2 : 1
            var nE = isDual ? Math.ceil(n / 2) : n
            var nA = isDual ? Math.floor(n / 2) : n
            var machE = (bg.typ === "DI" || bg.typ === "AI" || bg.typ === "DIO" || bg.typ === "AIO")
            var machA = (bg.typ === "DO" || bg.typ === "AO" || bg.typ === "DIO" || bg.typ === "AIO")

            if (machE) {
                for (i = 0; i < nE; i++) {
                    if (isAnalog) { byteNr = bg.adress_byte_start + i * byteStep; bitNr = -1 }
                    else          { byteNr = bg.adress_byte_start + Math.floor(i / 8); bitNr = i % 8 }
                    newId = db.spsKanalAnlegen(root.projektId, bg.id, i,
                                               "E", byteNr, bitNr, datentyp, "", "")
                    if (newId > 0) count++
                }
            }
            if (machA) {
                for (i = 0; i < nA; i++) {
                    if (isAnalog) { byteNr = bg.adress_byte_start + i * byteStep; bitNr = -1 }
                    else          { byteNr = bg.adress_byte_start + Math.floor(i / 8); bitNr = i % 8 }
                    newId = db.spsKanalAnlegen(root.projektId, bg.id, i,
                                               "A", byteNr, bitNr, datentyp, "", "")
                    if (newId > 0) count++
                }
            }
        }

        root._ladeKanaele()
        if (count > 0)
            meldungManager.zeigen(count + " " + qsTr("Kanäle angelegt"), true)
        else
            meldungManager.zeigen(qsTr("Keine neuen Kanäle – Adresskonflikte oder bereits vorhanden"), false)
    }

    onProjektIdChanged: _ladeRacks()

    Component.onCompleted: _ladeRacks()

    // ── Rack-Dialog ───────────────────────────────────────────────
    SpsRackDialog {
        id: rackDialog
        theme: root.theme
        projektId: root.projektId
        onGespeichert: function(newId) {
            _ladeRacks()
            if (newId > 0) {
                for (var i = 0; i < _racks.length; i++)
                    if (_racks[i].id === newId) { _waehleRack(_racks[i]); break }
            }
        }
        onFehler: function(meldung) { meldungManager.zeigen(meldung, false) }
    }

    // ── Baugruppe-Dialog ──────────────────────────────────────────
    SpsBaugruppeDialog {
        id: bgDialog
        theme: root.theme
        rackId: root._ausgewaehlterRackId
        projektId: root.projektId
        onGespeichert: function(newId) {
            if (newId > 0) root._ausgewaehlterBaugruppeId = newId
            _ladeBaugruppen()
        }
        onFehler: function(meldung) { meldungManager.zeigen(meldung, false) }
    }

    // ── Auto-Anlegen Bestätigung ──────────────────────────────────
    SpsAutoAnlegenDialog {
        id: autoAnlegenDialog
        theme: root.theme
        bg: root._pendingAutoAnlegenBg
        onBestaetigt: root._kanaeleAutoAnlegen(root._pendingAutoAnlegenBg)
    }

    // ── CSV-Import (SPS-IMPORT-01) ────────────────────────────────
    SpsImportDialog {
        id: importDialog
        theme: root.theme
        projektId: root.projektId
        onImportiert: {
            root._ausgewaehlterBaugruppeId = -1
            root._ladeRacks()
        }
    }

    // ── Löschen-Rückfrage ─────────────────────────────────────────
    SpsLoeschenDialog {
        id: loeschDialog
        theme: root.theme
        onBestaetigt: function(option) {
            if (root._loeschAktion)
                root._loeschenAusfuehren(root._loeschAktion.typ, root._loeschAktion.id, option)
            root._loeschAktion = null
        }
    }

    // ── Kanal-Dialog ──────────────────────────────────────────────
    SpsKanalDialog {
        id: kanalDialog
        theme: root.theme
        projektId: root.projektId
        systemTyp: root._ausgewaehlterSystemTyp
        baugruppen: root._baugruppen
        aktBaugruppeId: root._ausgewaehlterBaugruppeId
        onGespeichert: function(newId) {
            if (newId > 0) root._ausgewaehlterKanalId = newId
            _ladeKanaele()
        }
        onFehler: function(meldung) { meldungManager.zeigen(meldung, false) }
    }

    // ── Haupt-Layout ──────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Hinweis: SPS/PLS noch nicht vollständig getestet
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: warnLabel.implicitHeight + 14
            color: "#7a4400"
            Label {
                id: warnLabel
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                text: qsTr("🚧  SPS/PLS – Diese Ansicht befindet sich noch in der Testphase und ist möglicherweise unvollständig.")
                color: "#ffd080"
                wrapMode: Text.Wrap
                font.pixelSize: 12
            }
        }

        // Tab-Bar
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.surface }

            TabButton {
                text: qsTr("Hardware")
                background: Rectangle {
                    color: tabBar.currentIndex === 0 ? root.theme.accent : root.theme.surface
                    opacity: tabBar.currentIndex === 0 ? 0.12 : 0
                }
                contentItem: Label {
                    text: parent.text
                    color: tabBar.currentIndex === 0 ? root.theme.accent : root.theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            TabButton {
                text: qsTr("Kanäle / Adressen")
                background: Rectangle {
                    color: root.theme.accent
                    opacity: tabBar.currentIndex === 1 ? 0.12 : 0
                }
                contentItem: Label {
                    text: parent.text
                    color: tabBar.currentIndex === 1 ? root.theme.accent : root.theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            TabButton {
                text: qsTr("Export")
                background: Rectangle {
                    color: root.theme.accent
                    opacity: tabBar.currentIndex === 2 ? 0.12 : 0
                }
                contentItem: Label {
                    text: parent.text
                    color: tabBar.currentIndex === 2 ? root.theme.accent : root.theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

        // Tab-Inhalt
        StackLayout {
            currentIndex: tabBar.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Tab 0: Hardware ───────────────────────────────────
            Item {
                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ── Rack-Liste (links) ────────────────────────
                    ColumnLayout {
                        Layout.preferredWidth: 200
                        Layout.maximumWidth: 200
                        Layout.fillHeight: true
                        spacing: 0

                        // Header
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: root.theme.surfaceDeep

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 2

                                Label {
                                    text: qsTr("Racks")
                                    color: root.theme.textPrimary
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                RoundButton {
                                    text: "+"
                                    width: 26; height: 26
                                    font.pixelSize: 14
                                    palette.button:     root.theme.border
                                    palette.buttonText: root.theme.accent
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Rack anlegen")
                                    onClicked: rackDialog.oeffnenNeu()
                                }
                            }
                        }

                        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

                        ListView {
                            id: rackListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: root._racks
                            clip: true

                            Label {
                                anchors.centerIn: parent
                                visible: rackListView.count === 0
                                text: root.projektId < 0
                                      ? qsTr("Kein Projekt geöffnet")
                                      : qsTr("Noch keine Racks –\n[+] zum Anlegen")
                                horizontalAlignment: Text.AlignHCenter
                                color: root.theme.textMuted
                                font.pixelSize: 12
                            }

                            delegate: Rectangle {
                                id: rackDelegate
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 52
                                color: modelData.id === root._ausgewaehlterRackId
                                       ? Qt.rgba(root.theme.accent.r ?? 0.2,
                                                  root.theme.accent.g ?? 0.6,
                                                  root.theme.accent.b ?? 1.0, 0.15)
                                       : (rackMa.containsMouse ? root.theme.hover : root.theme.surface)

                                ColumnLayout {
                                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 60 }
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Label {
                                        text: modelData.bezeichnung || ("Rack " + modelData.rack_nr)
                                        color: root.theme.textPrimary
                                        font.bold: modelData.id === root._ausgewaehlterRackId
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        text: "[" + modelData.system_typ + "] R" + modelData.rack_nr
                                            + (modelData.hersteller ? " · " + modelData.hersteller : "")
                                        color: root.theme.textMuted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: rackMa
                                    anchors.fill: parent; hoverEnabled: true
                                    onClicked: root._waehleRack(rackDelegate.modelData)
                                    onDoubleClicked: rackDialog.oeffnenEdit(rackDelegate.modelData)
                                }

                                // SPS-BEARBEITEN-01: Aktionen dauerhaft sichtbar (nicht nur bei Hover) -
                                // Bearbeiten war vorher nur per Doppelklick erreichbar und nicht auffindbar.
                                RoundButton {
                                    anchors { right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter }
                                    text: "✎"
                                    width: 24; height: 24
                                    font.pixelSize: 12
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Rack bearbeiten")
                                    onClicked: rackDialog.oeffnenEdit(rackDelegate.modelData)
                                }
                                RoundButton {
                                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                    text: "✕"
                                    width: 24; height: 24
                                    font.pixelSize: 11
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Rack löschen (mit Rückfrage)")
                                    onClicked: root._rackLoeschenFragen(rackDelegate.modelData)
                                }
                            }
                        }
                    }

                    Rectangle { width: 1; color: root.theme.border; Layout.fillHeight: true }

                    // ── Baugruppen-Liste (rechts) ─────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        // Header
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: root.theme.surfaceDeep

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 4

                                Label {
                                    text: {
                                        var r = root._ausgewaehlterRackInfo()
                                        if (!r) return qsTr("Baugruppen")
                                        return qsTr("Baugruppen in \"%1\" (%2)").arg(r.bezeichnung).arg(r.system_typ)
                                    }
                                    color: root.theme.textPrimary
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                RoundButton {
                                    text: "+"
                                    width: 26; height: 26
                                    font.pixelSize: 14
                                    enabled: root._ausgewaehlterRackId >= 0
                                    palette.button:     root.theme.border
                                    palette.buttonText: root.theme.accent
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Baugruppe anlegen")
                                    onClicked: bgDialog.oeffnenNeu()
                                }
                            }
                        }

                        // Spaltenköpfe
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            color: root.theme.surfaceDeep

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                spacing: 0

                                Label { text: "Slot"; color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 40 }
                                Label { text: "Typ";  color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 50 }
                                Label { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                                Label { text: qsTr("Kanäle"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 55 }
                                Label { text: qsTr("Belegt"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 70 }
                                Label { text: qsTr("Startbyte"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                                Label { text: qsTr("Platziert"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 60 }
                                Item { Layout.preferredWidth: 76 }
                            }
                        }

                        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

                        ListView {
                            id: bgListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 100
                            Layout.minimumHeight: 90
                            model: root._baugruppen
                            clip: true

                            delegate: Rectangle {
                                id: bgDelegate
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 40
                                color: modelData.id === root._ausgewaehlterBaugruppeId
                                       ? Qt.rgba(0.2, 0.6, 1.0, 0.10)
                                       : (bgMa.containsMouse ? root.theme.hover : (index % 2 ? root.theme.surface : root.theme.surfaceDeep))

                                // Muss vor dem RowLayout stehen (SPS-KANAL-LOESCHEN-01):
                                // eine MouseArea NACH den Buttons läge im Stapel obendrauf
                                // und würde deren Klicks abfangen, bevor der Button sie sieht.
                                MouseArea {
                                    id: bgMa
                                    anchors.fill: parent; hoverEnabled: true
                                    onClicked: root._ausgewaehlterBaugruppeId = bgDelegate.modelData.id
                                    onDoubleClicked: bgDialog.oeffnenEdit(bgDelegate.modelData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 4
                                    spacing: 0

                                    Label { text: modelData.slot;        color: root.theme.textPrimary; Layout.preferredWidth: 40 }
                                    Label {
                                        text: modelData.typ
                                        color: {
                                            switch(modelData.typ) {
                                            case "DI": case "AI": return "#4caf50"
                                            case "DO": case "AO": return "#f44336"
                                            case "CPU": return "#2196f3"
                                            default: return root.theme.textMuted
                                            }
                                        }
                                        font.bold: true
                                        Layout.preferredWidth: 50
                                    }
                                    Label { text: modelData.bezeichnung; color: root.theme.textPrimary; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Label { text: modelData.kanaele;     color: root.theme.textMuted; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignHCenter }
                                    Label {
                                        // Belegt = Kanäle mit zugewiesenem Schaltplan-Element / Kanäle der Baugruppe
                                        readonly property var _b: root._belegungMap[bgDelegate.modelData.id]
                                        readonly property bool _io: root._keinIoTypen.indexOf(bgDelegate.modelData.typ) < 0
                                        text: !_io ? "–" : ((_b ? _b.element : 0) + " / " + bgDelegate.modelData.kanaele)
                                        color: !_io ? root.theme.textMuted
                                               : ((_b ? _b.element : 0) >= bgDelegate.modelData.kanaele && bgDelegate.modelData.kanaele > 0
                                                  ? "#4caf50" : root.theme.textPrimary)
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignHCenter
                                        ToolTip.visible: _belegMa.containsMouse && _io
                                        ToolTip.delay: 300
                                        ToolTip.text: {
                                            var b = _b || { element: 0, beschriftet: 0, frei: 0, angelegt: 0 }
                                            var offen = Math.max(0, bgDelegate.modelData.kanaele - b.angelegt)
                                            return qsTr("%1 mit Element · %2 beschriftet · %3 frei · %4 nicht angelegt")
                                                .arg(b.element).arg(b.beschriftet).arg(b.frei).arg(offen)
                                        }
                                        MouseArea { id: _belegMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                    }
                                    Label {
                                        text: (root._ausgewaehlterSystemTyp === "SPS") ? modelData.adress_byte_start : "–"
                                        color: root.theme.textMuted
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    Label {
                                        text: modelData.betriebsmittel_id > 0 ? modelData.betriebsmittel_kz : "–"
                                        color: modelData.betriebsmittel_id > 0 ? root.theme.textPrimary : root.theme.textMuted
                                        Layout.preferredWidth: 60
                                        elide: Text.ElideRight
                                    }
                                    RoundButton {
                                        text: "✎"
                                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                        font.pixelSize: 12
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Baugruppe bearbeiten")
                                        onClicked: bgDialog.oeffnenEdit(bgDelegate.modelData)
                                    }
                                    RoundButton {
                                        text: "⚡"
                                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                        font.pixelSize: 11
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Kanäle automatisch anlegen")
                                        onClicked: {
                                            var bg = bgDelegate.modelData
                                            var vorh = db.spsKanalListeFuerBaugruppe(bg.id)
                                            if (vorh.length > 0) {
                                                root._pendingAutoAnlegenBg = bg
                                                autoAnlegenDialog.open()
                                            } else {
                                                root._kanaeleAutoAnlegen(bg)
                                            }
                                        }
                                    }
                                    RoundButton {
                                        text: "✕"
                                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                        font.pixelSize: 11
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Baugruppe löschen")
                                        onClicked: root._baugruppeLoeschenFragen(bgDelegate.modelData)
                                    }
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: root._ausgewaehlterRackId < 0
                                      ? qsTr("Rack auswählen")
                                      : qsTr("Keine Baugruppen – [+] zum Anlegen")
                                color: root.theme.textMuted
                                visible: root._baugruppen.length === 0
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; visible: kanalPanel.visible }

                        // ── Kanäle der ausgewählten Baugruppe (SPS-BELEGUNG-01) ──
                        ColumnLayout {
                            id: kanalPanel
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 100
                            Layout.minimumHeight: 120
                            visible: root._ausgewaehlteBaugruppeInfo() !== null
                            spacing: 0

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                color: root.theme.surfaceDeep

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Label {
                                        text: {
                                            var b = root._ausgewaehlteBaugruppeInfo()
                                            return b ? qsTr("Kanäle von Slot %1 – %2").arg(b.slot).arg(b.bezeichnung || b.typ) : ""
                                        }
                                        color: root.theme.textPrimary
                                        font.bold: true
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Repeater {
                                        model: {
                                            var z = root._bgKanalZeilen
                                            var el = 0, be = 0, fr = 0, le = 0
                                            for (var i = 0; i < z.length; i++) {
                                                var k = z[i].kanal
                                                if (z[i].leer) le++
                                                else if (k.grafik_element_id) el++
                                                else if ((k.variablenname || "") !== "" || (k.kommentar || "") !== "") be++
                                                else fr++
                                            }
                                            return [
                                                { farbe: "#4caf50", text: qsTr("%1 mit Element").arg(el) },
                                                { farbe: "#e0a800", text: qsTr("%1 beschriftet").arg(be) },
                                                { farbe: "#8a8a8a", text: qsTr("%1 frei").arg(fr) },
                                                { farbe: "transparent", text: qsTr("%1 nicht angelegt").arg(le) }
                                            ]
                                        }
                                        delegate: Row {
                                            required property var modelData
                                            spacing: 4
                                            Rectangle {
                                                width: 9; height: 9; radius: 5
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: modelData.farbe
                                                border.color: modelData.farbe === "transparent" ? root.theme.textMuted : modelData.farbe
                                            }
                                            Label { text: modelData.text; color: root.theme.textMuted; font.pixelSize: 11 }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 24
                                color: root.theme.surfaceDeep

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    spacing: 0
                                    Item { Layout.preferredWidth: 22 }
                                    Label { text: qsTr("Kanal"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 50 }
                                    Label { text: qsTr("Adresse"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 100 }
                                    Label { text: qsTr("Signal"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 50 }
                                    Label { text: qsTr("Variable / Tag"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 130 }
                                    Label { text: qsTr("Kommentar"); color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                                    Label { text: qsTr("Element"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 108 }
                                    Item { Layout.preferredWidth: 52 }
                                }
                            }

                            ListView {
                                id: bgKanalListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: root._bgKanalZeilen
                                clip: true
                                ScrollBar.vertical: ScrollBar {}

                                delegate: Rectangle {
                                    id: bkDelegate
                                    required property var modelData
                                    required property int index
                                    readonly property var kanal: modelData.kanal
                                    readonly property string status: modelData.leer ? "leer"
                                        : (kanal.grafik_element_id ? "element"
                                           : (((kanal.variablenname || "") !== "" || (kanal.kommentar || "") !== "") ? "beschriftet" : "frei"))
                                    width: ListView.view.width
                                    height: 28
                                    color: bkMa.containsMouse ? root.theme.hover
                                           : (index % 2 ? root.theme.surface : root.theme.surfaceDeep)

                                    MouseArea {
                                        id: bkMa
                                        anchors.fill: parent; hoverEnabled: true
                                        onDoubleClicked: {
                                            if (bkDelegate.kanal) kanalDialog.oeffnenEdit(bkDelegate.kanal)
                                            else                  kanalDialog.oeffnenNeu(bkDelegate.modelData.nr)
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        spacing: 0

                                        Item {
                                            Layout.preferredWidth: 22
                                            Layout.fillHeight: true
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 10; height: 10; radius: 5
                                                color: bkDelegate.status === "element" ? "#4caf50"
                                                     : bkDelegate.status === "beschriftet" ? "#e0a800"
                                                     : bkDelegate.status === "frei" ? "#8a8a8a" : "transparent"
                                                border.color: bkDelegate.status === "leer" ? root.theme.textMuted : color
                                            }
                                        }
                                        Label {
                                            text: "K" + (bkDelegate.modelData.nr + 1)
                                            color: bkDelegate.modelData.ausserhalb ? "#f44336" : root.theme.textMuted
                                            font.family: "monospace"
                                            Layout.preferredWidth: 50
                                        }
                                        Label {
                                            text: bkDelegate.kanal ? (bkDelegate.kanal.adresse || "?") : "–"
                                            color: bkDelegate.kanal ? root.theme.accent : root.theme.textMuted
                                            font.family: "monospace"
                                            font.bold: !!bkDelegate.kanal
                                            Layout.preferredWidth: 100
                                        }
                                        Label {
                                            text: bkDelegate.kanal ? root._kanalTyp(bkDelegate.kanal) : ""
                                            color: root.theme.textMuted
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 50
                                        }
                                        Label {
                                            text: bkDelegate.kanal ? (bkDelegate.kanal.variablenname || "")
                                                                   : qsTr("nicht angelegt – [+] zum Anlegen")
                                            color: bkDelegate.kanal ? root.theme.textPrimary : root.theme.textMuted
                                            font.italic: !bkDelegate.kanal
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: 130
                                        }
                                        Label {
                                            text: bkDelegate.kanal ? (bkDelegate.kanal.kommentar || "") : ""
                                            color: root.theme.textMuted
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Label {
                                            property string _bmk: {
                                                if (!bkDelegate.kanal) return ""
                                                var ed = bkDelegate.kanal.element_extra_daten
                                                if (!ed) return ""
                                                try { return JSON.parse(ed).bmk || "" } catch(e) { return "" }
                                            }
                                            text: !bkDelegate.kanal || !bkDelegate.kanal.grafik_element_id ? ""
                                                  : ((_bmk || "–") + (bkDelegate.kanal.seite_name ? " · " + bkDelegate.kanal.seite_name : ""))
                                            color: root.theme.accent
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: 108
                                        }
                                        RoundButton {
                                            text: "→"
                                            Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                            font.pixelSize: 11
                                            enabled: root._kannSpringen(bkDelegate.kanal)
                                            opacity: bkDelegate.kanal && bkDelegate.kanal.grafik_element_id ? 1.0 : 0.0
                                            ToolTip.visible: hovered && enabled
                                            ToolTip.text: qsTr("Zum Element im Schaltplan springen")
                                            onClicked: root._springeZuKanal(bkDelegate.kanal)
                                        }
                                        RoundButton {
                                            text: bkDelegate.kanal ? "✎" : "+"
                                            Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                            font.pixelSize: 12
                                            ToolTip.visible: hovered
                                            ToolTip.text: bkDelegate.kanal ? qsTr("Kanal bearbeiten") : qsTr("Kanal anlegen")
                                            onClicked: {
                                                if (bkDelegate.kanal) kanalDialog.oeffnenEdit(bkDelegate.kanal)
                                                else                  kanalDialog.oeffnenNeu(bkDelegate.modelData.nr)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Tab 1: Kanäle / Adressen ──────────────────────────
            Item {
                ColumnLayout {
                    id: kanaeleSpalte
                    anchors.fill: parent
                    spacing: 0

                    // Filter + Toolbar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: root.theme.surfaceDeep

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Label { text: qsTr("Filter:"); color: root.theme.textMuted }
                            ComboBox {
                                model: ["alle","E (Eingang)","A (Ausgang)","M (Merker)","T (Zeitglied)","Z (Zähler)",
                                        "DI","DO","AI","AO","PLS (Eingang)","PLS (Ausgang)"]
                                Layout.preferredWidth: 140
                                onActivated: root._kanalFilter = model[currentIndex]
                                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: kanaeleSpalte._gefiltert.length + " " + qsTr("Kanäle")
                                color: root.theme.textMuted
                                font.pixelSize: 11
                            }
                            Button {
                                text: qsTr("CSV importieren …")
                                implicitHeight: 26
                                enabled: root.projektId >= 0
                                contentItem: Text { text: parent.text; font.pixelSize: 11
                                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                                    radius: 4; border.color: root.theme.border }
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Kanäle (und fehlende Racks/Baugruppen) aus einer CSV-Datei übernehmen")
                                onClicked: importDialog.oeffnen()
                            }
                            RoundButton {
                                text: "+"
                                width: 26; height: 26
                                font.pixelSize: 14
                                enabled: root.projektId >= 0
                                palette.button:     root.theme.border
                                palette.buttonText: root.theme.accent
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Kanal anlegen")
                                onClicked: kanalDialog.oeffnenNeu()
                            }
                        }
                    }

                    // Spaltenkopf
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        color: root.theme.surfaceDeep

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 0
                            Label { text: qsTr("Adresse"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 100 }
                            Label { text: qsTr("Typ"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 50 }
                            Label { text: qsTr("Variable / Tag"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 130 }
                            Label { text: qsTr("Kommentar"); color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                            Label { text: qsTr("Einheit"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 55 }
                            Label { text: qsTr("Bereich"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 90 }
                            Label { text: qsTr("Element"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 96 }
                            Item { Layout.preferredWidth: 76 }
                        }
                    }

                    Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

                    property var _gefiltert: {
                        var f = root._kanalFilter
                        if (f === "alle") return root._kanaele
                        if (f === "E (Eingang)") return root._kanaele.filter(function(k) { return k.adress_typ === "E" })
                        if (f === "A (Ausgang)")  return root._kanaele.filter(function(k) { return k.adress_typ === "A" })
                        if (f === "M (Merker)")   return root._kanaele.filter(function(k) { return k.adress_typ === "M" })
                        if (f === "T (Zeitglied)") return root._kanaele.filter(function(k) { return k.adress_typ === "T" })
                        if (f === "Z (Zähler)")    return root._kanaele.filter(function(k) { return k.adress_typ === "Z" })
                        if (f === "DI" || f === "DO" || f === "AI" || f === "AO")
                            return root._kanaele.filter(function(k) { return root._kanalTyp(k) === f })
                        if (f === "PLS (Eingang)") return root._kanaele.filter(function(k) { return k.system_typ === "PLS" && k.adress_typ === "E" })
                        if (f === "PLS (Ausgang)") return root._kanaele.filter(function(k) { return k.system_typ === "PLS" && k.adress_typ === "A" })
                        return root._kanaele
                    }

                    ListView {
                        id: kanalListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: kanaeleSpalte._gefiltert
                        clip: true

                        delegate: Rectangle {
                            id: kanalDelegate
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 38
                            color: modelData.id === root._ausgewaehlterKanalId
                                   ? Qt.rgba(0.2, 0.6, 1.0, 0.12)
                                   : (kanalMa.containsMouse ? root.theme.hover : (index % 2 ? root.theme.surface : root.theme.surfaceDeep))

                            // Muss vor dem RowLayout stehen (SPS-KANAL-LOESCHEN-01):
                            // eine MouseArea NACH den Buttons läge im Stapel obendrauf
                            // und würde deren Klicks abfangen, bevor der Button sie sieht.
                            MouseArea {
                                id: kanalMa
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: root._ausgewaehlterKanalId = kanalDelegate.modelData.id
                                onDoubleClicked: kanalDialog.oeffnenEdit(kanalDelegate.modelData)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 0

                                Label {
                                    text: modelData.adresse || "?"
                                    color: root.theme.accent
                                    font.family: "monospace"
                                    font.bold: true
                                    Layout.preferredWidth: 100
                                }
                                Label {
                                    text: (modelData.system_typ === "PLS" ? "PLS " : "") + modelData.datentyp
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 50
                                }
                                Label {
                                    text: modelData.variablenname || ""
                                    color: root.theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.preferredWidth: 130
                                }
                                Label {
                                    text: modelData.kommentar || ""
                                    color: root.theme.textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: modelData.pls_einheit || ""
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 55
                                }
                                Label {
                                    text: {
                                        if (modelData.pls_bereich_min == null) return ""
                                        return modelData.pls_bereich_min + " – " + modelData.pls_bereich_max
                                    }
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 90
                                }
                                Label {
                                    id: elementLabel
                                    property string _bmk: {
                                        var ed = modelData.element_extra_daten
                                        if (!ed) return ""
                                        try { return JSON.parse(ed).bmk || "" } catch(e) { return "" }
                                    }
                                    text: _bmk
                                          ? _bmk + (modelData.seite_name ? " · " + modelData.seite_name : "")
                                          : (modelData.grafik_element_id ? "–" : "")
                                    color: _bmk ? root.theme.accent : root.theme.borderLight
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.preferredWidth: 96
                                    ToolTip.visible: _bmk && elemLabelMa.containsMouse
                                    ToolTip.text: _bmk + (modelData.seite_name ? "  (" + modelData.seite_name + ")" : "")
                                    ToolTip.delay: 400
                                    MouseArea { id: elemLabelMa; anchors.fill: parent; hoverEnabled: true }
                                }
                                RoundButton {
                                    text: "→"
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                    font.pixelSize: 11
                                    enabled: root._kannSpringen(kanalDelegate.modelData)
                                    opacity: kanalDelegate.modelData.grafik_element_id ? 1.0 : 0.0
                                    ToolTip.visible: hovered && enabled
                                    ToolTip.text: qsTr("Zum Element im Schaltplan springen")
                                    onClicked: root._springeZuKanal(kanalDelegate.modelData)
                                }
                                RoundButton {
                                    text: "✎"
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                    font.pixelSize: 12
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Kanal bearbeiten")
                                    onClicked: kanalDialog.oeffnenEdit(kanalDelegate.modelData)
                                }
                                RoundButton {
                                    text: "✕"
                                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                                    font.pixelSize: 11
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Kanal löschen")
                                    onClicked: root._kanalLoeschenFragen(kanalDelegate.modelData)
                                }
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            text: root._kanaele.length === 0
                                  ? qsTr("Keine Kanäle – [+] zum Anlegen")
                                  : qsTr("Alle Kanäle gefiltert")
                            color: root.theme.textMuted
                            visible: kanalListView.count === 0
                        }
                    }
                }
            }

            // ── Tab 2: Export (SPS-EXPORT-02, konfigurierbar) ─────
            SpsExportTab {
                theme: root.theme
                projektId: root.projektId
                racks: root._racks
                projektName: root.projektName
                kanalAnzahl: root._kanaele.length
            }
        }

    }

    DebugLabel { panelName: qsTr("SPS-Ansicht"); visible: root.debug }
}
