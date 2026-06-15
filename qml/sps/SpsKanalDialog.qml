import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root

    property var    theme
    property int    projektId:      -1
    property string systemTyp:      "SPS"
    property var    baugruppen:     []
    property int    aktBaugruppeId: -1

    readonly property bool istPls: root.systemTyp === "PLS"

    property bool _istNeu: true
    property int  _editId: -1

    signal gespeichert(int newId)
    signal fehler(string meldung)

    title: _istNeu ? qsTr("Kanal anlegen") : qsTr("Kanal bearbeiten")
    modal: true
    anchors.centerIn: parent
    width: 440
    standardButtons: Dialog.Ok | Dialog.Cancel

    ScrollView {
        width: parent.width
        height: Math.min(500, contentHeight + 20)
        clip: true

        ColumnLayout {
            width: root.width - 40
            spacing: 8

            // SPS-Felder
            Label { text: qsTr("Adress-Typ (SPS)"); visible: !root.istPls; color: root.theme.textPrimary }
            ComboBox {
                id: kanalAdressTypCombo
                visible: !root.istPls
                model: ["E","A","M","T","Z"]
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            }
            Label { text: qsTr("Byte-Nr."); visible: !root.istPls; color: root.theme.textPrimary }
            SpinBox {
                id: kanalByteNrSpin; visible: !root.istPls; from: 0; to: 99999; Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Label { text: qsTr("Bit-Nr. (-1 fuer WORD/BYTE/DWORD)"); visible: !root.istPls; color: root.theme.textPrimary }
            SpinBox {
                id: kanalBitNrSpin; visible: !root.istPls; from: 0; to: 7; Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Label { text: qsTr("Datentyp"); visible: !root.istPls; color: root.theme.textPrimary }
            ComboBox {
                id: kanalDatentypCombo
                visible: !root.istPls
                model: ["BOOL","BYTE","WORD","DWORD","REAL","INT","DINT"]
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            }

            // PLS-Felder
            Label { text: qsTr("Kanal-Nr. (innerhalb Baugruppe, 0-basiert)"); visible: root.istPls; color: root.theme.textPrimary }
            SpinBox {
                id: kanalNrSpin; visible: root.istPls; from: 0; to: 127; Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            // Gemeinsam
            Label { text: qsTr("Variable / Tag (ISA: TIC-001)"); color: root.theme.textPrimary }
            TextField {
                id: kanalVarField; placeholderText: root.istPls ? "TIC-001" : "Motor_Start"
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                color: root.theme.textPrimary
            }
            Label { text: qsTr("Kommentar"); color: root.theme.textPrimary }
            TextField {
                id: kanalKomField; placeholderText: root.istPls ? "Reaktor Temp. Eingang" : "Taster gruen S7"
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                color: root.theme.textPrimary
            }
            Label { text: qsTr("Baugruppe"); color: root.theme.textPrimary }
            ComboBox {
                id: kanalBaugruppeCombo
                Layout.fillWidth: true
                model: root.baugruppen.map(function(b) {
                    return "Slot " + b.slot + " - " + b.typ + " " + b.bezeichnung
                })
                property int ausgewaehlteId: root.baugruppen.length > 0
                                              ? root.baugruppen[currentIndex].id : -1
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            }

            // PLS-Metadaten
            Label { text: qsTr("Einheit"); visible: root.istPls; color: root.theme.textPrimary }
            TextField {
                id: plsEinheitField; visible: root.istPls
                placeholderText: "°C / bar / m³/h / %"
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                color: root.theme.textPrimary
            }
            Label { text: qsTr("Bereich Min / Max"); visible: root.istPls; color: root.theme.textPrimary }
            RowLayout {
                visible: root.istPls
                Layout.fillWidth: true
                TextField {
                    id: plsMinField; placeholderText: "0.0"; Layout.fillWidth: true
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                    color: root.theme.textPrimary
                }
                Label { text: "-"; color: root.theme.textMuted }
                TextField {
                    id: plsMaxField; placeholderText: "100.0"; Layout.fillWidth: true
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                    color: root.theme.textPrimary
                }
            }
            Label { text: qsTr("Alarme LL / LO / HI / HH"); visible: root.istPls; color: root.theme.textPrimary }
            GridLayout {
                visible: root.istPls
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
            Label { text: qsTr("Protokoll"); visible: root.istPls; color: root.theme.textPrimary }
            ComboBox {
                id: plsProtokollCombo
                visible: root.istPls
                model: ["analog","HART","PROFIBUS_PA","FOUNDATION_FF"]
                Layout.fillWidth: true
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            }
        }
    }

    function oeffnenNeu() {
        _istNeu = true; _editId = -1
        kanalAdressTypCombo.currentIndex = 0
        kanalByteNrSpin.value = 0; kanalBitNrSpin.value = 0
        kanalDatentypCombo.currentIndex = 0
        kanalNrSpin.value = 0
        kanalVarField.text = ""; kanalKomField.text = ""
        plsEinheitField.text = ""; plsMinField.text = ""; plsMaxField.text = ""
        plsAlllField.text = ""; plsAlloField.text = ""
        plsAlhiField.text = ""; plsAlhhField.text = ""
        plsProtokollCombo.currentIndex = 0
        if (root.aktBaugruppeId > 0) {
            for (var i = 0; i < root.baugruppen.length; i++)
                if (root.baugruppen[i].id === root.aktBaugruppeId) {
                    kanalBaugruppeCombo.currentIndex = i; break
                }
        }
        open()
    }

    function oeffnenEdit(k) {
        _istNeu = false; _editId = k.id
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
        for (var i = 0; i < root.baugruppen.length; i++)
            if (root.baugruppen[i].id === k.baugruppe_id) { kanalBaugruppeCombo.currentIndex = i; break }
        open()
    }

    onAccepted: {
        var bgId   = kanalBaugruppeCombo.ausgewaehlteId
        var byteNr = root.istPls ? 0 : kanalByteNrSpin.value
        var bitNr  = root.istPls ? 0 : kanalBitNrSpin.value
        var kNr    = root.istPls ? kanalNrSpin.value : -1
        var typ    = root.istPls ? "E" : kanalAdressTypCombo.currentText
        var dtype  = root.istPls ? "REAL" : kanalDatentypCombo.currentText

        if (_istNeu) {
            var newId = db.spsKanalAnlegen(root.projektId, bgId, kNr,
                                            typ, byteNr, bitNr, dtype,
                                            kanalVarField.text.trim(),
                                            kanalKomField.text.trim())
            if (newId < 0) { root.fehler(qsTr("Kanal konnte nicht angelegt werden (Adresse bereits vergeben?)")); return }
            root.gespeichert(newId)
        } else {
            var felder = {
                "adress_typ":    typ,
                "byte_nr":       byteNr,
                "bit_nr":        bitNr,
                "datentyp":      dtype,
                "variablenname": kanalVarField.text.trim(),
                "kommentar":     kanalKomField.text.trim()
            }
            if (root.istPls) {
                felder["kanal_nr"]       = kNr
                felder["pls_einheit"]    = plsEinheitField.text.trim() || null
                felder["pls_protokoll"]  = plsProtokollCombo.currentText
                if (plsMinField.text.trim()) felder["pls_bereich_min"] = parseFloat(plsMinField.text.replace(",","."))
                if (plsMaxField.text.trim()) felder["pls_bereich_max"] = parseFloat(plsMaxField.text.replace(",","."))
                if (plsAlllField.text.trim()) felder["pls_alarm_ll"] = parseFloat(plsAlllField.text.replace(",","."))
                if (plsAlloField.text.trim()) felder["pls_alarm_lo"] = parseFloat(plsAlloField.text.replace(",","."))
                if (plsAlhiField.text.trim()) felder["pls_alarm_hi"] = parseFloat(plsAlhiField.text.replace(",","."))
                if (plsAlhhField.text.trim()) felder["pls_alarm_hh"] = parseFloat(plsAlhhField.text.replace(",","."))
            }
            if (!db.spsKanalAktualisieren(_editId, felder)) {
                root.fehler(qsTr("Kanal konnte nicht gespeichert werden"))
                return
            }
            root.gespeichert(-1)
        }
    }
}
