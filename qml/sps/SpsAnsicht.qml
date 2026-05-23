import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    property int projektId: -1
    property var theme
    property bool debug: false

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

    // ── Toast ────────────────────────────────────────────────────
    property string _statusText: ""
    property bool   _statusOk:   true

    function _zeigeStatus(text, ok) {
        _statusText = text
        _statusOk   = ok
        statusTimer.restart()
    }

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
                _zeigeStatus(qsTr("%1-Baugruppen haben keine I/O-Kanäle").arg(bg.typ), false)
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
            root._zeigeStatus(count + " " + qsTr("Kanäle angelegt"), true)
        else
            root._zeigeStatus(qsTr("Keine neuen Kanäle – Adresskonflikte oder bereits vorhanden"), false)
    }

    onProjektIdChanged: _ladeRacks()

    Component.onCompleted: _ladeRacks()

    // ── Rack-Dialog ───────────────────────────────────────────────
    Dialog {
        id: rackDialog
        property bool  istNeu: true
        property int   editId: -1

        title: istNeu ? qsTr("Rack anlegen") : qsTr("Rack bearbeiten")
        modal: true
        anchors.centerIn: parent
        width: 380

        standardButtons: Dialog.Ok | Dialog.Cancel

        ColumnLayout {
            width: parent.width
            spacing: 8

            Label { text: qsTr("Rack-Nummer"); color: root.theme.textPrimary }
            SpinBox {
                id: rackNrSpin
                from: 0; to: 99
                Layout.fillWidth: true
            }
            Label { text: qsTr("System-Typ"); color: root.theme.textPrimary }
            ComboBox {
                id: systemTypCombo
                model: ["SPS", "PLS"]
                Layout.fillWidth: true
            }
            Label { text: qsTr("Bezeichnung"); color: root.theme.textPrimary }
            TextField {
                id: rackBezField
                placeholderText: "Rack 0"
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                color: root.theme.textPrimary
            }
            Label { text: qsTr("Hersteller"); color: root.theme.textPrimary }
            TextField {
                id: rackHerstellerField
                placeholderText: "Siemens"
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                color: root.theme.textPrimary
            }
        }

        function oeffnenNeu() {
            istNeu = true; editId = -1
            rackNrSpin.value = 0
            systemTypCombo.currentIndex = 0
            rackBezField.text = ""
            rackHerstellerField.text = ""
            open()
        }
        function oeffnenEdit(rack) {
            istNeu = false; editId = rack.id
            rackNrSpin.value = rack.rack_nr
            systemTypCombo.currentIndex = rack.system_typ === "PLS" ? 1 : 0
            rackBezField.text = rack.bezeichnung
            rackHerstellerField.text = rack.hersteller
            open()
        }

        onAccepted: {
            var bez = rackBezField.text.trim() || ("Rack " + rackNrSpin.value)
            if (istNeu) {
                var newId = db.spsRackAnlegen(root.projektId,
                                               rackNrSpin.value,
                                               systemTypCombo.currentText,
                                               bez,
                                               rackHerstellerField.text.trim())
                if (newId > 0) {
                    _ladeRacks()
                    // Neu erstelltes Rack auswählen
                    for (var i = 0; i < _racks.length; i++)
                        if (_racks[i].id === newId) { _waehleRack(_racks[i]); break }
                } else {
                    _zeigeStatus(qsTr("Rack konnte nicht angelegt werden (Rack-Nr. bereits vergeben?)"), false)
                }
            } else {
                var ok = db.spsRackAktualisieren(editId, rackNrSpin.value,
                                                  systemTypCombo.currentText,
                                                  bez, "", rackHerstellerField.text.trim())
                if (ok) { _ladeRacks() } else { _zeigeStatus(qsTr("Rack konnte nicht gespeichert werden"), false) }
            }
        }
    }

    // ── Baugruppe-Dialog ──────────────────────────────────────────
    Dialog {
        id: bgDialog
        property bool istNeu: true
        property int  editId: -1

        title: istNeu ? qsTr("Baugruppe anlegen") : qsTr("Baugruppe bearbeiten")
        modal: true
        anchors.centerIn: parent
        width: 400

        standardButtons: Dialog.Ok | Dialog.Cancel

        ColumnLayout {
            width: parent.width
            spacing: 8

            Label { text: qsTr("Slot"); color: root.theme.textPrimary }
            SpinBox { id: bgSlotSpin; from: 0; to: 31; Layout.fillWidth: true }

            Label { text: qsTr("Typ"); color: root.theme.textPrimary }
            ComboBox {
                id: bgTypCombo
                model: ["CPU","PS","DI","DO","DIO","AI","AO","AIO","CP","FM","andere"]
                Layout.fillWidth: true
            }
            Label { text: qsTr("Bezeichnung"); color: root.theme.textPrimary }
            TextField {
                id: bgBezField; placeholderText: "SM 321"
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                color: root.theme.textPrimary
            }
            Label { text: qsTr("Artikel-Nr."); color: root.theme.textPrimary }
            TextField {
                id: bgArtNrField; placeholderText: "6ES7 321-..."
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                color: root.theme.textPrimary
            }
            Label { text: qsTr("Kanäle"); color: root.theme.textPrimary }
            SpinBox { id: bgKanaeleSpin; from: 1; to: 128; value: 8; Layout.fillWidth: true }

            Label { text: qsTr("Startbyte (SPS)"); color: root.theme.textPrimary }
            SpinBox { id: bgStartbyteSpin; from: 0; to: 9999; value: 0; Layout.fillWidth: true }
        }

        function oeffnenNeu() {
            istNeu = true; editId = -1
            bgSlotSpin.value = 0; bgTypCombo.currentIndex = 2
            bgBezField.text = ""; bgArtNrField.text = ""
            bgKanaeleSpin.value = 8; bgStartbyteSpin.value = 0
            open()
        }
        function oeffnenEdit(bg) {
            istNeu = false; editId = bg.id
            bgSlotSpin.value = bg.slot
            bgTypCombo.currentIndex = Math.max(0, bgTypCombo.model.indexOf(bg.typ))
            bgBezField.text = bg.bezeichnung
            bgArtNrField.text = bg.artikel_nr
            bgKanaeleSpin.value = bg.kanaele
            bgStartbyteSpin.value = bg.adress_byte_start
            open()
        }

        onAccepted: {
            if (istNeu) {
                var newId = db.spsBaugruppeAnlegen(root._ausgewaehlterRackId,
                                                    bgSlotSpin.value,
                                                    bgTypCombo.currentText,
                                                    bgBezField.text.trim(),
                                                    bgKanaeleSpin.value,
                                                    bgStartbyteSpin.value)
                if (newId < 0) _zeigeStatus(qsTr("Baugruppe konnte nicht angelegt werden (Slot bereits belegt?)"), false)
                else { _ausgewaehlterBaugruppeId = newId; _ladeBaugruppen() }
            } else {
                var ok = db.spsBaugruppeAktualisieren(editId,
                                                       bgSlotSpin.value, bgTypCombo.currentText,
                                                       bgBezField.text.trim(), bgArtNrField.text.trim(),
                                                       bgKanaeleSpin.value, "BOOL",
                                                       bgStartbyteSpin.value, "")
                if (!ok) _zeigeStatus(qsTr("Baugruppe konnte nicht gespeichert werden"), false)
                else _ladeBaugruppen()
            }
        }
    }

    // ── Auto-Anlegen Bestätigung ──────────────────────────────────
    Dialog {
        id: autoAnlegenDialog
        title: qsTr("Kanäle automatisch anlegen")
        modal: true
        anchors.centerIn: parent
        width: 360
        standardButtons: Dialog.Ok | Dialog.Cancel

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            color: root.theme.textPrimary
            text: {
                var bg = root._pendingAutoAnlegenBg
                if (!bg) return ""
                var vorh = db.spsKanalListeFuerBaugruppe(bg.id).length
                return qsTr("Die Baugruppe \"%1\" hat bereits %2 Kanal(e).\nNeu anlegen überspringt Adresskonflikte.\nFortfahren?").arg(bg.bezeichnung || bg.typ).arg(vorh)
            }
        }

        onAccepted: root._kanaeleAutoAnlegen(root._pendingAutoAnlegenBg)
    }

    // ── Kanal-Dialog ──────────────────────────────────────────────
    Dialog {
        id: kanalDialog
        property bool istNeu: true
        property int  editId: -1
        property bool istPls: root._ausgewaehlterSystemTyp === "PLS"

        title: istNeu ? qsTr("Kanal anlegen") : qsTr("Kanal bearbeiten")
        modal: true
        anchors.centerIn: parent
        width: 440

        standardButtons: Dialog.Ok | Dialog.Cancel

        ScrollView {
            width: parent.width
            height: Math.min(500, contentHeight + 20)
            clip: true

            ColumnLayout {
                width: kanalDialog.width - 40
                spacing: 8

                // SPS-Felder
                Label { text: qsTr("Adress-Typ (SPS)"); visible: !kanalDialog.istPls; color: root.theme.textPrimary }
                ComboBox {
                    id: kanalAdressTypCombo
                    visible: !kanalDialog.istPls
                    model: ["E","A","M","T","Z"]
                    Layout.fillWidth: true
                }
                Label { text: qsTr("Byte-Nr."); visible: !kanalDialog.istPls; color: root.theme.textPrimary }
                SpinBox { id: kanalByteNrSpin; visible: !kanalDialog.istPls; from: 0; to: 99999; Layout.fillWidth: true }
                Label { text: qsTr("Bit-Nr. (−1 für WORD/BYTE/DWORD)"); visible: !kanalDialog.istPls; color: root.theme.textPrimary }
                SpinBox { id: kanalBitNrSpin; visible: !kanalDialog.istPls; from: 0; to: 7; Layout.fillWidth: true }
                Label { text: qsTr("Datentyp"); visible: !kanalDialog.istPls; color: root.theme.textPrimary }
                ComboBox {
                    id: kanalDatentypCombo
                    visible: !kanalDialog.istPls
                    model: ["BOOL","BYTE","WORD","DWORD","REAL","INT","DINT"]
                    Layout.fillWidth: true
                }

                // PLS-Felder
                Label { text: qsTr("Kanal-Nr. (innerhalb Baugruppe, 0-basiert)"); visible: kanalDialog.istPls; color: root.theme.textPrimary }
                SpinBox { id: kanalNrSpin; visible: kanalDialog.istPls; from: 0; to: 127; Layout.fillWidth: true }

                // Gemeinsam
                Label { text: qsTr("Variable / Tag (ISA: TIC-001)"); color: root.theme.textPrimary }
                TextField {
                    id: kanalVarField; placeholderText: kanalDialog.istPls ? "TIC-001" : "Motor_Start"
                    Layout.fillWidth: true
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                    color: root.theme.textPrimary
                }
                Label { text: qsTr("Kommentar"); color: root.theme.textPrimary }
                TextField {
                    id: kanalKomField; placeholderText: kanalDialog.istPls ? "Reaktor Temp. Eingang" : "Taster grün S7"
                    Layout.fillWidth: true
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                    color: root.theme.textPrimary
                }
                Label { text: qsTr("Baugruppe"); color: root.theme.textPrimary }
                ComboBox {
                    id: kanalBaugruppeCombo
                    Layout.fillWidth: true
                    model: root._baugruppen.map(function(b) {
                        return "Slot " + b.slot + " – " + b.typ + " " + b.bezeichnung
                    })
                    property int ausgewaehlteId: root._baugruppen.length > 0
                                                  ? root._baugruppen[currentIndex].id : -1
                }

                // PLS-Metadaten
                Label { text: qsTr("Einheit"); visible: kanalDialog.istPls; color: root.theme.textPrimary }
                TextField {
                    id: plsEinheitField; visible: kanalDialog.istPls
                    placeholderText: "°C / bar / m³/h / %"
                    Layout.fillWidth: true
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                    color: root.theme.textPrimary
                }
                Label { text: qsTr("Bereich Min / Max"); visible: kanalDialog.istPls; color: root.theme.textPrimary }
                RowLayout {
                    visible: kanalDialog.istPls
                    Layout.fillWidth: true
                    TextField {
                        id: plsMinField; placeholderText: "0.0"; Layout.fillWidth: true
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                        color: root.theme.textPrimary
                    }
                    Label { text: "–"; color: root.theme.textMuted }
                    TextField {
                        id: plsMaxField; placeholderText: "100.0"; Layout.fillWidth: true
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                        color: root.theme.textPrimary
                    }
                }
                Label { text: qsTr("Alarme LL / LO / HI / HH"); visible: kanalDialog.istPls; color: root.theme.textPrimary }
                GridLayout {
                    visible: kanalDialog.istPls
                    Layout.fillWidth: true
                    columns: 4; columnSpacing: 6
                    TextField { id: plsAlllField; placeholderText: "LL"; Layout.fillWidth: true
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                        color: root.theme.textPrimary }
                    TextField { id: plsAlloField; placeholderText: "LO"; Layout.fillWidth: true
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                        color: root.theme.textPrimary }
                    TextField { id: plsAlhiField; placeholderText: "HI"; Layout.fillWidth: true
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                        color: root.theme.textPrimary }
                    TextField { id: plsAlhhField; placeholderText: "HH"; Layout.fillWidth: true
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                        color: root.theme.textPrimary }
                }
                Label { text: qsTr("Protokoll"); visible: kanalDialog.istPls; color: root.theme.textPrimary }
                ComboBox {
                    id: plsProtokollCombo
                    visible: kanalDialog.istPls
                    model: ["analog","HART","PROFIBUS_PA","FOUNDATION_FF"]
                    Layout.fillWidth: true
                }
            }
        }

        function oeffnenNeu() {
            istNeu = true; editId = -1
            kanalAdressTypCombo.currentIndex = 0
            kanalByteNrSpin.value = 0; kanalBitNrSpin.value = 0
            kanalDatentypCombo.currentIndex = 0
            kanalNrSpin.value = 0
            kanalVarField.text = ""; kanalKomField.text = ""
            plsEinheitField.text = ""; plsMinField.text = ""; plsMaxField.text = ""
            plsAlllField.text = ""; plsAlloField.text = ""
            plsAlhiField.text = ""; plsAlhhField.text = ""
            plsProtokollCombo.currentIndex = 0
            // Aktive Baugruppe vorauswählen
            if (root._ausgewaehlterBaugruppeId > 0) {
                for (var i = 0; i < root._baugruppen.length; i++)
                    if (root._baugruppen[i].id === root._ausgewaehlterBaugruppeId) {
                        kanalBaugruppeCombo.currentIndex = i; break
                    }
            }
            open()
        }
        function oeffnenEdit(k) {
            istNeu = false; editId = k.id
            kanalAdressTypCombo.currentIndex = Math.max(0, kanalAdressTypCombo.model.indexOf(k.adress_typ))
            kanalByteNrSpin.value = k.byte_nr || 0
            kanalBitNrSpin.value  = k.bit_nr  || 0
            kanalDatentypCombo.currentIndex = Math.max(0, kanalDatentypCombo.model.indexOf(k.datentyp))
            kanalNrSpin.value     = k.kanal_nr != null ? k.kanal_nr : 0
            kanalVarField.text    = k.variablenname || ""
            kanalKomField.text    = k.kommentar    || ""
            plsEinheitField.text  = k.pls_einheit  || ""
            plsMinField.text      = k.pls_bereich_min != null ? String(k.pls_bereich_min) : ""
            plsMaxField.text      = k.pls_bereich_max != null ? String(k.pls_bereich_max) : ""
            plsAlllField.text     = k.pls_alarm_ll != null ? String(k.pls_alarm_ll) : ""
            plsAlloField.text     = k.pls_alarm_lo != null ? String(k.pls_alarm_lo) : ""
            plsAlhiField.text     = k.pls_alarm_hi != null ? String(k.pls_alarm_hi) : ""
            plsAlhhField.text     = k.pls_alarm_hh != null ? String(k.pls_alarm_hh) : ""
            var pidx = plsProtokollCombo.model.indexOf(k.pls_protokoll)
            plsProtokollCombo.currentIndex = pidx >= 0 ? pidx : 0
            for (var i = 0; i < root._baugruppen.length; i++)
                if (root._baugruppen[i].id === k.baugruppe_id) { kanalBaugruppeCombo.currentIndex = i; break }
            open()
        }

        onAccepted: {
            var bgId = kanalBaugruppeCombo.ausgewaehlteId
            var isPls = kanalDialog.istPls
            var byteNr = isPls ? 0 : kanalByteNrSpin.value
            var bitNr  = isPls ? 0 : kanalBitNrSpin.value
            var kNr    = isPls ? kanalNrSpin.value : -1
            var typ    = isPls ? "E" : kanalAdressTypCombo.currentText
            var dtype  = isPls ? "REAL" : kanalDatentypCombo.currentText

            if (istNeu) {
                var newId = db.spsKanalAnlegen(root.projektId, bgId, kNr,
                                                typ, byteNr, bitNr, dtype,
                                                kanalVarField.text.trim(),
                                                kanalKomField.text.trim())
                if (newId < 0) { _zeigeStatus(qsTr("Kanal konnte nicht angelegt werden (Adresse bereits vergeben?)"), false); return }
                root._ausgewaehlterKanalId = newId
            } else {
                var felder = {
                    "adress_typ":    typ,
                    "byte_nr":       byteNr,
                    "bit_nr":        bitNr,
                    "datentyp":      dtype,
                    "variablenname": kanalVarField.text.trim(),
                    "kommentar":     kanalKomField.text.trim()
                }
                if (isPls) {
                    felder["kanal_nr"]       = kNr
                    felder["pls_einheit"]    = plsEinheitField.text.trim() || null
                    felder["pls_protokoll"]  = plsProtokollCombo.currentText
                    if (plsMinField.text.trim()) felder["pls_bereich_min"] = parseFloat(plsMinField.text)
                    if (plsMaxField.text.trim()) felder["pls_bereich_max"] = parseFloat(plsMaxField.text)
                    if (plsAlllField.text.trim()) felder["pls_alarm_ll"] = parseFloat(plsAlllField.text)
                    if (plsAlloField.text.trim()) felder["pls_alarm_lo"] = parseFloat(plsAlloField.text)
                    if (plsAlhiField.text.trim()) felder["pls_alarm_hi"] = parseFloat(plsAlhiField.text)
                    if (plsAlhhField.text.trim()) felder["pls_alarm_hh"] = parseFloat(plsAlhhField.text)
                }
                if (!db.spsKanalAktualisieren(editId, felder)) {
                    _zeigeStatus(qsTr("Kanal konnte nicht gespeichert werden"), false)
                    return
                }
            }
            _ladeKanaele()
        }
    }

    // ── Export-Dialoge ────────────────────────────────────────────
    FileDialog {
        id: exportDialog
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: {
            var ok = db.spsIOListeCsvSpeichern(root.projektId, selectedFile)
            _zeigeStatus(ok ? qsTr("I/O-Liste exportiert") : qsTr("Export fehlgeschlagen"), ok)
        }
    }

    // ── Haupt-Layout ──────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

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
                                       : (rackHover.containsMouse ? root.theme.hover : root.theme.surface)

                                HoverHandler { id: rackHover }

                                ColumnLayout {
                                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 4 }
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
                                    anchors.fill: parent
                                    onClicked: root._waehleRack(rackDelegate.modelData)
                                    onDoubleClicked: rackDialog.oeffnenEdit(rackDelegate.modelData)
                                }

                                RoundButton {
                                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                    text: "✕"
                                    width: 22; height: 22
                                    font.pixelSize: 11
                                    visible: rackHover.containsMouse
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Rack löschen (alle Baugruppen + Kanäle)")
                                    onClicked: {
                                        if (db.spsRackLoeschen(rackDelegate.modelData.id)) {
                                            root._ausgewaehlterRackId = -1
                                            root._ladeRacks()
                                        }
                                    }
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
                                Label { text: qsTr("Startbyte"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                                Item { Layout.preferredWidth: 54 }
                            }
                        }

                        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

                        ListView {
                            id: bgListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
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
                                       : (bgHover.containsMouse ? root.theme.hover : (index % 2 ? root.theme.surface : root.theme.surfaceDeep))

                                HoverHandler { id: bgHover }

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
                                        text: (root._ausgewaehlterSystemTyp === "SPS") ? modelData.adress_byte_start : "–"
                                        color: root.theme.textMuted
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    RoundButton {
                                        text: "⚡"
                                        width: 22; height: 22
                                        font.pixelSize: 11
                                        visible: bgHover.containsMouse
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
                                        width: 22; height: 22
                                        font.pixelSize: 11
                                        visible: bgHover.containsMouse
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Baugruppe löschen")
                                        onClicked: {
                                            if (db.spsBaugruppeLoeschen(bgDelegate.modelData.id)) {
                                                if (root._ausgewaehlterBaugruppeId === bgDelegate.modelData.id)
                                                    root._ausgewaehlterBaugruppeId = -1
                                                root._ladeBaugruppen()
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root._ausgewaehlterBaugruppeId = bgDelegate.modelData.id
                                    onDoubleClicked: bgDialog.oeffnenEdit(bgDelegate.modelData)
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
                    }
                }
            }

            // ── Tab 1: Kanäle / Adressen ──────────────────────────
            Item {
                ColumnLayout {
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
                                model: ["alle","E (Eingang)","A (Ausgang)","M (Merker)","PLS-AI","PLS-AO"]
                                Layout.preferredWidth: 140
                                onActivated: root._kanalFilter = model[currentIndex]
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: _gefiltert.length + " " + qsTr("Kanäle")
                                color: root.theme.textMuted
                                font.pixelSize: 11
                            }
                            RoundButton {
                                text: "+"
                                width: 26; height: 26
                                font.pixelSize: 14
                                enabled: root.projektId >= 0
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
                            Label { text: qsTr("Element"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 120 }
                            Item { Layout.preferredWidth: 28 }
                        }
                    }

                    Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

                    property var _gefiltert: {
                        var f = root._kanalFilter
                        if (f === "alle") return root._kanaele
                        if (f === "E (Eingang)") return root._kanaele.filter(function(k) { return k.adress_typ === "E" })
                        if (f === "A (Ausgang)")  return root._kanaele.filter(function(k) { return k.adress_typ === "A" })
                        if (f === "M (Merker)")   return root._kanaele.filter(function(k) { return k.adress_typ === "M" })
                        if (f === "PLS-AI")       return root._kanaele.filter(function(k) { return k.system_typ === "PLS" && k.adress_typ === "E" })
                        if (f === "PLS-AO")       return root._kanaele.filter(function(k) { return k.system_typ === "PLS" && k.adress_typ === "A" })
                        return root._kanaele
                    }

                    ListView {
                        id: kanalListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: parent._gefiltert
                        clip: true

                        delegate: Rectangle {
                            id: kanalDelegate
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 38
                            color: modelData.id === root._ausgewaehlterKanalId
                                   ? Qt.rgba(0.2, 0.6, 1.0, 0.12)
                                   : (kanalHover.containsMouse ? root.theme.hover : (index % 2 ? root.theme.surface : root.theme.surfaceDeep))

                            HoverHandler { id: kanalHover }

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
                                    Layout.preferredWidth: 120
                                    ToolTip.visible: _bmk && elemLabelMa.containsMouse
                                    ToolTip.text: _bmk + (modelData.seite_name ? "  (" + modelData.seite_name + ")" : "")
                                    ToolTip.delay: 400
                                    MouseArea { id: elemLabelMa; anchors.fill: parent; hoverEnabled: true }
                                }
                                RoundButton {
                                    text: "✕"
                                    width: 22; height: 22
                                    font.pixelSize: 11
                                    visible: kanalHover.containsMouse
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Kanal löschen")
                                    onClicked: {
                                        if (db.spsKanalLoeschen(kanalDelegate.modelData.id)) {
                                            if (root._ausgewaehlterKanalId === kanalDelegate.modelData.id)
                                                root._ausgewaehlterKanalId = -1
                                            root._ladeKanaele()
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root._ausgewaehlterKanalId = kanalDelegate.modelData.id
                                onDoubleClicked: kanalDialog.oeffnenEdit(kanalDelegate.modelData)
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

            // ── Tab 2: Export ─────────────────────────────────────
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20
                    width: Math.min(parent.width - 80, 500)

                    Label {
                        text: qsTr("Export")
                        font.pixelSize: 18
                        font.bold: true
                        color: root.theme.textPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Label {
                        text: qsTr("Alle %1 Kanäle des Projekts als I/O-Liste exportieren.").arg(root._kanaele.length)
                        color: root.theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Button {
                        text: qsTr("I/O-Liste als CSV exportieren")
                        Layout.alignment: Qt.AlignHCenter
                        enabled: root._kanaele.length > 0
                        onClicked: exportDialog.open()
                    }

                    Label {
                        text: qsTr("CSV-Format: Adresse, System, Typ, Variable/Tag, Kommentar,\nEinheit, Bereich, Alarme (LL/LO/HI/HH), Protokoll, Element-ID\n\nKompatibel mit Excel (UTF-8 BOM, Semikolon-getrennt).")
                        color: root.theme.textMuted
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // ── Status-Toast ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: root._statusOk ? "#1b5e20" : "#7f0000"
            visible: _statusText.length > 0

            Label {
                anchors.centerIn: parent
                text: root._statusText
                color: "white"
                font.pixelSize: 12
            }

            Timer {
                id: statusTimer
                interval: 3500
                onTriggered: root._statusText = ""
            }
        }
    }

    DebugLabel { panelName: qsTr("SPS-Ansicht"); visible: root.debug }
}
