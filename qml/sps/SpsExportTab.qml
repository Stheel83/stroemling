import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "../la"

// SPS-EXPORT-02: frei konfigurierbarer CSV-Export der SPS/PLS-Adressliste.
// Der Anwender stellt Spalten (Auswahl, Reihenfolge, Titel, feste Textspalten),
// Format und Filter selbst zusammen und kann das als Vorlage speichern.
// Vorlagen sind global (App-Einstellungen, nicht in der Projektdatei) – so lässt
// sich ein Zielformat (Leitsystem-Import, Excel-Vorlage) einmal bauen und in
// jedem Projekt wiederverwenden. Die Datenaufbereitung selbst liegt in C++
// (Database_SpsExport.cpp); diese Datei ist nur Konfigurations-Oberfläche.
Item {
    id: root

    required property var theme
    property int   projektId: -1
    property var   racks: []         // db.spsRackListe(...) – für den Rack-Filter
    property int   kanalAnzahl: 0
    property string projektName: ""

    // ── Globale Ablage (Vorlagen + zuletzt bearbeiteter Stand) ───
    Settings {
        id: einst
        category: "sps_export"
        property string vorlagen: "[]"   // JSON: [{name, konfig}]
        property string zuletzt:  ""     // JSON der zuletzt bearbeiteten Konfiguration
    }

    ListModel { id: spaltenModel }       // feld, titel, standardTitel, gruppe, aktiv, wert

    property var  _vorlagen: []
    property bool _laedt: false
    property string _vorschauText: ""
    property string _vorschauFehler: ""
    property int    _vorschauZeilen: 0
    property int    _aktiveSpalten: 0

    readonly property var _trennOptionen: [
        { text: qsTr("Semikolon ( ; )"),   wert: ";" },
        { text: qsTr("Komma ( , )"),       wert: "," },
        { text: qsTr("Tabulator"),         wert: "\t" },
        { text: qsTr("Senkrechter Strich ( | )"), wert: "|" }
    ]
    readonly property var _dezimalOptionen: [
        { text: qsTr("Komma ( 12,5 )"),  wert: "," },
        { text: qsTr("Punkt ( 12.5 )"),  wert: "." }
    ]
    readonly property var _anfuehrungOptionen: [
        { text: qsTr("Immer"),            wert: "immer" },
        { text: qsTr("Nur bei Bedarf"),   wert: "bei_bedarf" }
    ]
    readonly property var _signalOptionen: [
        { text: qsTr("alle Signale"), wert: "" },
        { text: "DI", wert: "DI" }, { text: "DO", wert: "DO" },
        { text: "AI", wert: "AI" }, { text: "AO", wert: "AO" }
    ]
    readonly property var _systemOptionen: [
        { text: qsTr("SPS und PLS"), wert: "" },
        { text: "SPS", wert: "SPS" }, { text: "PLS", wert: "PLS" }
    ]
    readonly property var _belegungOptionen: [
        { text: qsTr("alle Kanäle"),            wert: "alle" },
        { text: qsTr("nur mit Element"),        wert: "mit_element" },
        { text: qsTr("nur ohne Element"),       wert: "ohne_element" }
    ]
    readonly property var _rackOptionen: {
        var o = [{ text: qsTr("alle Racks"), wert: "" }]
        for (var i = 0; i < racks.length; i++)
            o.push({ text: "R" + racks[i].rack_nr + " – " + (racks[i].bezeichnung || "") + " [" + racks[i].system_typ + "]",
                     wert: String(racks[i].rack_nr) })
        return o
    }

    function _idx(optionen, wert) {
        for (var i = 0; i < optionen.length; i++) if (optionen[i].wert === wert) return i
        return 0
    }

    // ── Konfiguration ⇄ Oberfläche ───────────────────────────────
    function _konfigObjekt() {
        var sp = []
        for (var i = 0; i < spaltenModel.count; i++) {
            var m = spaltenModel.get(i)
            if (!m.aktiv) continue
            var o = { feld: m.feld, titel: m.titel }
            if (m.feld === "fest") o.wert = m.wert
            sp.push(o)
        }
        return {
            spalten:      sp,
            trennzeichen: _trennOptionen[trennCombo.currentIndex].wert,
            dezimal:      _dezimalOptionen[dezimalCombo.currentIndex].wert,
            kopfzeile:    kopfCheck.checked,
            bom:          bomCheck.checked,
            anfuehrung:   _anfuehrungOptionen[anfuehrungCombo.currentIndex].wert,
            filter: {
                system:   _systemOptionen[systemCombo.currentIndex].wert,
                rack:     _rackOptionen[rackCombo.currentIndex].wert,
                signal:   _signalOptionen[signalCombo.currentIndex].wert,
                belegung: _belegungOptionen[belegungCombo.currentIndex].wert
            }
        }
    }

    function _konfigLaden(k) {
        _laedt = true
        var kat = db.spsExportFeldKatalog()
        var katMap = {}
        for (var c = 0; c < kat.length; c++) katMap[kat[c].feld] = kat[c]

        spaltenModel.clear()
        var benutzt = {}
        var festVorhanden = false
        var sp = k.spalten || []
        for (var i = 0; i < sp.length; i++) {
            var d = katMap[sp[i].feld]
            if (!d) continue
            spaltenModel.append({ feld: d.feld,
                                  titel: sp[i].titel !== undefined ? sp[i].titel : d.titel,
                                  standardTitel: d.titel, gruppe: d.gruppe, aktiv: true,
                                  wert: sp[i].wert || "" })
            if (d.feld === "fest") festVorhanden = true
            else benutzt[d.feld] = true
        }
        for (var j = 0; j < kat.length; j++) {
            var e = kat[j]
            if (benutzt[e.feld]) continue
            if (e.feld === "fest" && festVorhanden) continue
            spaltenModel.append({ feld: e.feld, titel: e.titel, standardTitel: e.titel,
                                  gruppe: e.gruppe, aktiv: false, wert: "" })
        }

        trennCombo.currentIndex     = _idx(_trennOptionen, k.trennzeichen !== undefined ? k.trennzeichen : ";")
        dezimalCombo.currentIndex   = _idx(_dezimalOptionen, k.dezimal !== undefined ? k.dezimal : ",")
        kopfCheck.checked           = k.kopfzeile !== false
        bomCheck.checked            = k.bom !== false
        anfuehrungCombo.currentIndex = _idx(_anfuehrungOptionen, k.anfuehrung || "immer")
        var f = k.filter || {}
        systemCombo.currentIndex    = _idx(_systemOptionen, f.system || "")
        rackCombo.currentIndex      = _idx(_rackOptionen, f.rack || "")
        signalCombo.currentIndex    = _idx(_signalOptionen, f.signal || "")
        belegungCombo.currentIndex  = _idx(_belegungOptionen, f.belegung || "alle")
        _laedt = false
        _geaendert()
    }

    function _standardLaden() {
        _konfigLaden(JSON.parse(db.spsExportStandardKonfig()))
    }

    function _geaendert() {
        if (_laedt) return
        aktualisierTimer.restart()
    }

    function _vorschauAktualisieren() {
        if (root.projektId < 0) { _vorschauText = ""; _vorschauFehler = ""; _vorschauZeilen = 0; return }
        var json = JSON.stringify(_konfigObjekt())
        var v = db.spsExportVorschau(root.projektId, json, 8)
        _vorschauText   = v.text || ""
        _vorschauFehler = v.fehler || ""
        _vorschauZeilen = v.zeilen || 0
        _aktiveSpalten  = _konfigObjekt().spalten.length
        einst.zuletzt = json
    }

    function _vorlagenSpeichern() { einst.vorlagen = JSON.stringify(_vorlagen) }

    function _vorlageSpeichern(name) {
        var konfig = _konfigObjekt()
        var neu = _vorlagen.slice()
        var gefunden = -1
        for (var i = 0; i < neu.length; i++) if (neu[i].name === name) gefunden = i
        if (gefunden >= 0) neu[gefunden] = { name: name, konfig: konfig }
        else neu.push({ name: name, konfig: konfig })
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

    Timer {
        id: aktualisierTimer
        interval: 150
        onTriggered: root._vorschauAktualisieren()
    }

    onProjektIdChanged: _geaendert()
    onKanalAnzahlChanged: _geaendert()

    Component.onCompleted: {
        try { _vorlagen = JSON.parse(einst.vorlagen) || [] } catch (e) { _vorlagen = [] }
        var start = null
        if (einst.zuletzt) { try { start = JSON.parse(einst.zuletzt) } catch (e2) { start = null } }
        if (start && start.spalten && start.spalten.length > 0) _konfigLaden(start)
        else _standardLaden()
    }

    // ── Hilfskomponente: einheitlich gestaltete ComboBox ─────────
    // Theme wird explizit durchgereicht (Inline-Komponenten sehen die ids der
    // umgebenden Datei nicht zuverlässig).
    component KonfigCombo: ComboBox {
        required property var thm
        property var optionen: []
        signal geaendert()
        model: optionen.map(function(o) { return o.text })
        Layout.fillWidth: true
        implicitHeight: 30
        background: Rectangle { color: thm.inputBg; border.color: thm.border; radius: 4 }
        contentItem: Text {
            text: parent.displayText; color: thm.textPrimary; font.pixelSize: 12
            leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
        }
        onActivated: geaendert()
    }

    component KnopfLabel: Text {
        required property var thm
        color: thm.textMuted; font.pixelSize: 11
    }

    // ── Dialoge ──────────────────────────────────────────────────
    LaPdfExportDialog {
        id: exportDialog
        theme: root.theme
        dateiname: "io_liste.csv"
        dateiEndung: ".csv"
        titelText: qsTr("I/O-Liste als CSV exportieren")
        speichernTitel: qsTr("CSV speichern unter")
        erfolgText: qsTr("I/O-Liste exportiert.")
        onExportAngefordert: function(pfad) {
            var ok = db.spsExportCsvSpeichern(root.projektId, pfad, JSON.stringify(root._konfigObjekt()))
            exportDialog.erfolgReagieren(ok)
        }
    }

    LaPdfExportDialog {
        id: pdfDialog
        theme: root.theme
        dateiname: "io_liste.pdf"
        titelText: qsTr("I/O-Liste als PDF exportieren")
        onExportAngefordert: function(pfad) {
            var ok = db.spsExportPdfSpeichern(root.projektId, root.projektName, pfad,
                                              JSON.stringify(root._konfigObjekt()))
            pdfDialog.erfolgReagieren(ok)
        }
    }

    Dialog {
        id: nameDialog
        title: qsTr("Vorlage speichern")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }
        onOpened: {
            var i = vorlageCombo.currentIndex - 1
            nameFeld.text = (i >= 0 && i < root._vorlagen.length) ? root._vorlagen[i].name : ""
            nameFeld.forceActiveFocus()
        }
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                text: qsTr("Name der Vorlage (vorhandener Name wird überschrieben):")
                color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            TextField {
                id: nameFeld
                Layout.fillWidth: true
                color: root.theme.textPrimary
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onAccepted: okKnopf.clicked()
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Button {
                    text: qsTr("Abbrechen"); Layout.fillWidth: true; implicitHeight: 32
                    contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                    onClicked: nameDialog.close()
                }
                Button {
                    id: okKnopf
                    text: qsTr("Speichern"); Layout.fillWidth: true; implicitHeight: 32
                    enabled: nameFeld.text.trim().length > 0
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                    onClicked: {
                        if (!enabled) return
                        root._vorlageSpeichern(nameFeld.text.trim())
                        nameDialog.close()
                    }
                }
            }
        }
    }

    // ── Layout ───────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14

        // ── Links: Vorlage + Spalten ─────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 8

            Text { text: qsTr("Vorlage"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                ComboBox {
                    id: vorlageCombo
                    Layout.fillWidth: true
                    implicitHeight: 30
                    model: [qsTr("(Standard)")].concat(root._vorlagen.map(function(v) { return v.name }))
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text {
                        text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                        leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                    }
                    onActivated: function(i) {
                        if (i === 0) root._standardLaden()
                        else root._konfigLaden(root._vorlagen[i - 1].konfig)
                    }
                }
                Button {
                    text: qsTr("Speichern unter …"); implicitHeight: 30
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius: 4; border.color: root.theme.accent }
                    onClicked: nameDialog.open()
                }
                Button {
                    text: qsTr("Löschen"); implicitHeight: 30
                    enabled: vorlageCombo.currentIndex > 0
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textSecondary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered && parent.enabled ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                    onClicked: root._vorlageLoeschen()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Text { text: qsTr("Spalten"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                Text {
                    text: qsTr("Haken = exportieren · ▲▼ = Reihenfolge · Titel frei änderbar")
                    color: root.theme.textMuted; font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.theme.surface
                border.color: root.theme.border
                radius: 4

                ListView {
                    id: spaltenListe
                    anchors.fill: parent
                    anchors.margins: 1
                    model: spaltenModel
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        id: zeile
                        required property int index
                        required property string feld
                        required property string titel
                        required property string standardTitel
                        required property string gruppe
                        required property bool aktiv
                        required property string wert

                        width: ListView.view.width
                        height: 34
                        color: index % 2 ? root.theme.surface : root.theme.surfaceDeep
                        opacity: aktiv ? 1.0 : 0.6

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 4

                            CheckBox {
                                checked: zeile.aktiv
                                onToggled: {
                                    spaltenModel.setProperty(zeile.index, "aktiv", checked)
                                    root._geaendert()
                                }
                            }
                            ToolButton {
                                text: "▲"
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                enabled: zeile.index > 0
                                onClicked: { spaltenModel.move(zeile.index, zeile.index - 1, 1); root._geaendert() }
                            }
                            ToolButton {
                                text: "▼"
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                enabled: zeile.index < spaltenModel.count - 1
                                onClicked: { spaltenModel.move(zeile.index, zeile.index + 1, 1); root._geaendert() }
                            }
                            Text {
                                text: zeile.feld === "fest" ? qsTr("Fester Text") : zeile.standardTitel
                                color: root.theme.textPrimary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.preferredWidth: 130
                                ToolTip.visible: _lblMa.containsMouse
                                ToolTip.text: zeile.gruppe
                                ToolTip.delay: 400
                                MouseArea { id: _lblMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            }
                            TextField {
                                Layout.fillWidth: true
                                implicitHeight: 26
                                text: zeile.titel
                                placeholderText: qsTr("Spaltentitel")
                                color: root.theme.textPrimary
                                font.pixelSize: 12
                                background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                onTextEdited: { spaltenModel.setProperty(zeile.index, "titel", text); root._geaendert() }
                            }
                            TextField {
                                visible: zeile.feld === "fest"
                                Layout.preferredWidth: 110
                                implicitHeight: 26
                                text: zeile.wert
                                placeholderText: qsTr("Wert")
                                color: root.theme.textPrimary
                                font.pixelSize: 12
                                background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.accent }
                                onTextEdited: { spaltenModel.setProperty(zeile.index, "wert", text); root._geaendert() }
                            }
                            ToolButton {
                                visible: zeile.feld === "fest"
                                text: "✕"
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                onClicked: { spaltenModel.remove(zeile.index); root._geaendert() }
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Textspalte entfernen")
                            }
                        }
                    }
                }
            }

            Button {
                text: qsTr("＋ Feste Textspalte")
                implicitHeight: 28
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border }
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Spalte mit immer gleichem Inhalt (z.B. Stationsname) – für Import-Vorlagen")
                onClicked: {
                    spaltenModel.append({ feld: "fest", titel: qsTr("Text"), standardTitel: qsTr("Fester Text"),
                                          gruppe: "Sonstiges", aktiv: true, wert: "" })
                    root._geaendert()
                }
            }
        }

        // ── Rechts: Format, Filter, Vorschau, Export ─────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 8

            Text { text: qsTr("Format"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13 }

            GridLayout {
                columns: 2
                columnSpacing: 10
                rowSpacing: 6
                Layout.fillWidth: true

                KnopfLabel { thm: root.theme; text: qsTr("Trennzeichen") }
                KonfigCombo { id: trennCombo; thm: root.theme; optionen: root._trennOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Dezimalzeichen") }
                KonfigCombo { id: dezimalCombo; thm: root.theme; optionen: root._dezimalOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Anführungszeichen") }
                KonfigCombo { id: anfuehrungCombo; thm: root.theme; optionen: root._anfuehrungOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: "" }
                CheckBox {
                    id: kopfCheck
                    text: qsTr("Kopfzeile (Spaltentitel) ausgeben")
                    checked: true
                    onToggled: root._geaendert()
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
                }
                KnopfLabel { thm: root.theme; text: "" }
                CheckBox {
                    id: bomCheck
                    text: qsTr("UTF-8-BOM (für Excel)")
                    checked: true
                    onToggled: root._geaendert()
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
                }
            }

            Text { text: qsTr("Filter"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.topMargin: 6 }

            GridLayout {
                columns: 2
                columnSpacing: 10
                rowSpacing: 6
                Layout.fillWidth: true

                KnopfLabel { thm: root.theme; text: qsTr("System") }
                KonfigCombo { id: systemCombo; thm: root.theme; optionen: root._systemOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Rack") }
                KonfigCombo { id: rackCombo; thm: root.theme; optionen: root._rackOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Signal") }
                KonfigCombo { id: signalCombo; thm: root.theme; optionen: root._signalOptionen; onGeaendert: root._geaendert() }

                KnopfLabel { thm: root.theme; text: qsTr("Belegung") }
                KonfigCombo { id: belegungCombo; thm: root.theme; optionen: root._belegungOptionen; onGeaendert: root._geaendert() }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Text { text: qsTr("Vorschau"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13; Layout.fillWidth: true }
                Text {
                    text: root._vorschauFehler !== "" ? root._vorschauFehler
                          : qsTr("%1 Zeile(n) – Vorschau zeigt die ersten 8").arg(root._vorschauZeilen)
                    color: root._vorschauFehler !== "" ? "#cc6666" : root.theme.textMuted
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.theme.inputBg
                border.color: root.theme.border
                radius: 4

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    TextArea {
                        readOnly: true
                        text: root._vorschauText
                        wrapMode: TextArea.NoWrap
                        font.family: "monospace"
                        font.pixelSize: 11
                        color: root.theme.textPrimary
                        background: null
                        selectByMouse: true
                    }
                }
            }

            Text {
                visible: root._aktiveSpalten > 10
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#e0a800"
                font.pixelSize: 11
                text: qsTr("%1 Spalten ausgewählt – im PDF (A4 quer) wird es eng. Für das PDF besser eine Vorlage mit wenigen Spalten verwenden.").arg(root._aktiveSpalten)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Als PDF exportieren …")
                implicitHeight: 34
                implicitWidth: 200
                enabled: root.projektId >= 0 && root._vorschauFehler === "" && root._vorschauZeilen > 0
                contentItem: Text { text: parent.text; font.pixelSize: 13
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                onClicked: pdfDialog.open()
            }
            Button {
                text: qsTr("Als CSV exportieren …")
                implicitHeight: 34
                implicitWidth: 200
                enabled: root.projektId >= 0 && root._vorschauFehler === "" && root._vorschauZeilen > 0
                contentItem: Text { text: parent.text; font.pixelSize: 13
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                onClicked: exportDialog.open()
            }
            }
        }
    }
}
