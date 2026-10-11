import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// SPS-IMPORT-01: CSV-Import von SPS/PLS-Adresslisten (Bestandsanlagen).
// Ablauf: Datei wählen → Spalten den Feldern zuordnen (Auto-Erkennung über die
// Spaltentitel) → Optionen → Live-Prüfung (Trockenlauf, schreibt nichts) →
// Importieren. Fehlerhafte Zeilen werden gemeldet und übersprungen, der Rest
// wird in einer Transaktion übernommen.
Dialog {
    id: root

    required property var theme
    property int projektId: -1

    signal importiert()

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  Math.min(820, parent ? parent.width - 40 : 820)
    height: Math.min(640, parent ? parent.height - 40 : 640)
    padding: 16
    title: qsTr("SPS/PLS-Daten aus CSV importieren")

    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

    // ── Zustand ──
    property string _pfad: ""
    property string _lesefehler: ""
    property var    _kopf: []
    property var    _beispiel: []
    property int    _datenzeilen: 0
    property var    _bericht: ({})
    property var    _feldOptionen: []   // [{feld, text}] importierbare Felder

    ListModel { id: zuordnung }         // spalte (Titel), beispiel, feld

    readonly property var _modusOptionen: [
        { text: qsTr("Nur leere Felder auffüllen (Standard)"), wert: "auffuellen" },
        { text: qsTr("Vorhandene Kanäle überspringen"),         wert: "ueberspringen" },
        { text: qsTr("Felder aus der CSV überschreiben"),       wert: "ueberschreiben" }
    ]
    readonly property var _systemOptionen: [
        { text: qsTr("PLS (Rack / Slot / Kanal)"), wert: "PLS" },
        { text: qsTr("SPS (Byte / Bit-Adressen)"), wert: "SPS" }
    ]

    function _pfadBereinigen(s) {
        s = String(s)
        if (s.startsWith("file:///")) return s.substring(7)
        if (s.startsWith("file://"))  return s.substring(7)
        return s
    }

    function oeffnen() {
        _pfad = ""; _lesefehler = ""; _kopf = []; _beispiel = []; _datenzeilen = 0; _bericht = ({})
        zuordnung.clear()
        pfadFeld.text = ""
        // importierbare Felder = Export-Katalog ohne reine Schaltplan-/Textfelder
        var kat = db.spsExportFeldKatalog()
        var o = [{ feld: "", text: qsTr("— ignorieren —") }]
        for (var i = 0; i < kat.length; i++) {
            var f = kat[i].feld
            if (f === "bmk" || f === "seite_blatt" || f === "seite_name" || f === "fest") continue
            o.push({ feld: f, text: kat[i].titel })
        }
        _feldOptionen = o
        open()
    }

    function _datei(pfad) {
        _pfad = _pfadBereinigen(pfad)
        pfadFeld.text = _pfad
        var r = db.spsImportLesen(_pfad)
        _lesefehler = r.fehler || ""
        zuordnung.clear()
        _kopf = []; _beispiel = []; _datenzeilen = 0; _bericht = ({})
        if (_lesefehler !== "") return
        _kopf = r.kopf
        _beispiel = r.beispiel
        _datenzeilen = r.zeilen
        var bsp = r.beispiel.length > 0 ? r.beispiel[0] : []
        for (var i = 0; i < r.kopf.length; i++)
            zuordnung.append({ spalte: r.kopf[i], beispiel: i < bsp.length ? bsp[i] : "",
                               feld: r.vorschlag[i] || "" })
        _pruefenPlanen()
    }

    function _konfigJson() {
        var sp = []
        for (var i = 0; i < zuordnung.count; i++) sp.push(zuordnung.get(i).feld)
        return JSON.stringify({
            spalten: sp,
            kopfzeile: true,
            dezimal: dezimalCombo.currentIndex === 0 ? "," : ".",
            systemStandard: _systemOptionen[systemCombo.currentIndex].wert,
            vorhandene: _modusOptionen[modusCombo.currentIndex].wert,
            hardwareAnlegen: hwCheck.checked
        })
    }

    function _pruefenPlanen() { pruefTimer.restart() }

    function _pruefen() {
        if (_pfad === "" || zuordnung.count === 0) { _bericht = ({}); return }
        _bericht = db.spsImportPruefen(root.projektId, _pfad, _konfigJson())
    }

    readonly property bool _kannImportieren:
        _pfad !== "" && _lesefehler === "" && (_bericht.fehler === undefined || _bericht.fehler === "")
        && ((_bericht.neueKanaele || 0) + (_bericht.aktualisiert || 0)) > 0

    Timer { id: pruefTimer; interval: 200; onTriggered: root._pruefen() }

    FileDialog {
        id: dateiDialog
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("CSV-Dateien (*.csv *.txt)"), qsTr("Alle Dateien (*)")]
        onAccepted: root._datei(selectedFile)
    }

    component KnopfText: Text {
        required property var thm
        color: thm.textMuted; font.pixelSize: 11
    }

    contentItem: ColumnLayout {
        spacing: 8

        // ── 1. Datei ──
        Text { text: qsTr("1. CSV-Datei"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            TextField {
                id: pfadFeld
                Layout.fillWidth: true
                placeholderText: qsTr("/pfad/zur/datei.csv")
                color: root.theme.textPrimary
                font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onAccepted: if (text.trim() !== "") root._datei(text.trim())
            }
            Button {
                text: qsTr("Durchsuchen …"); implicitHeight: 30
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border }
                onClicked: dateiDialog.open()
            }
            Button {
                text: qsTr("Laden"); implicitHeight: 30
                enabled: pfadFeld.text.trim() !== ""
                contentItem: Text { text: parent.text; font.pixelSize: 12
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.enabled && parent.hovered ? root.theme.accent : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                onClicked: root._datei(pfadFeld.text.trim())
            }
        }
        Text {
            visible: root._lesefehler !== "" || root._kopf.length > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            color: root._lesefehler !== "" ? "#cc6666" : root.theme.textMuted
            text: root._lesefehler !== "" ? root._lesefehler
                  : qsTr("%1 Datenzeile(n), %2 Spalte(n). Spaltentitel wurden – soweit erkennbar – automatisch zugeordnet.")
                        .arg(root._datenzeilen).arg(root._kopf.length)
        }

        // ── 2. Zuordnung ──
        Text { text: qsTr("2. Spaltenzuordnung"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13
               visible: zuordnung.count > 0 }

        Rectangle {
            visible: zuordnung.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            color: root.theme.surface
            border.color: root.theme.border
            radius: 4

            ListView {
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                model: zuordnung
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    id: zeile
                    required property int index
                    required property string spalte
                    required property string beispiel
                    required property string feld
                    width: ListView.view.width
                    height: 32
                    color: index % 2 ? root.theme.surface : root.theme.surfaceDeep

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            text: zeile.spalte
                            color: root.theme.textPrimary; font.pixelSize: 12; font.bold: true
                            elide: Text.ElideRight
                            Layout.preferredWidth: 200
                        }
                        Text {
                            text: zeile.beispiel
                            color: root.theme.textMuted; font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        ComboBox {
                            Layout.preferredWidth: 230
                            implicitHeight: 26
                            model: root._feldOptionen.map(function(o) { return o.text })
                            currentIndex: {
                                for (var i = 0; i < root._feldOptionen.length; i++)
                                    if (root._feldOptionen[i].feld === zeile.feld) return i
                                return 0
                            }
                            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                            contentItem: Text {
                                text: parent.displayText; font.pixelSize: 12
                                color: zeile.feld === "" ? root.theme.textMuted : root.theme.textPrimary
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                            }
                            onActivated: function(i) {
                                zuordnung.setProperty(zeile.index, "feld", root._feldOptionen[i].feld)
                                root._pruefenPlanen()
                            }
                        }
                    }
                }
            }
        }

        // ── 3. Optionen ──
        Text { text: qsTr("3. Optionen"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13
               visible: zuordnung.count > 0 }

        GridLayout {
            visible: zuordnung.count > 0
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 10
            rowSpacing: 6

            KnopfText { thm: root.theme; text: qsTr("System, wenn nicht erkennbar") }
            ComboBox {
                id: systemCombo
                Layout.fillWidth: true; implicitHeight: 28
                model: root._systemOptionen.map(function(o) { return o.text })
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                onActivated: root._pruefenPlanen()
            }
            KnopfText { thm: root.theme; text: qsTr("Vorhandene Kanäle") }
            ComboBox {
                id: modusCombo
                Layout.fillWidth: true; implicitHeight: 28
                model: root._modusOptionen.map(function(o) { return o.text })
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                onActivated: root._pruefenPlanen()
            }

            KnopfText { thm: root.theme; text: qsTr("Dezimalzeichen in der CSV") }
            ComboBox {
                id: dezimalCombo
                Layout.fillWidth: true; implicitHeight: 28
                model: [qsTr("Komma ( 12,5 )"), qsTr("Punkt ( 12.5 )")]
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                onActivated: root._pruefenPlanen()
            }
            Item { Layout.preferredWidth: 1 }
            CheckBox {
                id: hwCheck
                text: qsTr("Fehlende Racks/Baugruppen anlegen")
                checked: true
                onToggled: root._pruefenPlanen()
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                    leftPadding: parent.indicator.width + 6; verticalAlignment: Text.AlignVCenter }
            }
        }

        // ── 4. Ergebnis der Prüfung ──
        Text { text: qsTr("4. Prüfung"); color: root.theme.textPrimary; font.bold: true; font.pixelSize: 13
               visible: zuordnung.count > 0 }

        Text {
            visible: zuordnung.count > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 12
            color: (root._bericht.fehler || "") !== "" ? "#cc6666" : root.theme.textPrimary
            text: {
                var b = root._bericht
                if ((b.fehler || "") !== "") return b.fehler
                if (b.neueKanaele === undefined) return ""
                var t = qsTr("%1 neue Kanäle · %2 aktualisiert · %3 unverändert/übersprungen")
                            .arg(b.neueKanaele).arg(b.aktualisiert).arg(b.uebersprungen)
                if (b.neueRacks > 0 || b.neueBaugruppen > 0)
                    t += qsTr(" · neu angelegt: %1 Rack(s), %2 Baugruppe(n)").arg(b.neueRacks).arg(b.neueBaugruppen)
                if (b.fehlerhaft > 0)
                    t += "\n" + qsTr("%1 fehlerhafte Zeile(n) werden NICHT importiert (siehe Liste).").arg(b.fehlerhaft)
                return t
            }
        }

        Rectangle {
            visible: zuordnung.count > 0 && (root._bericht.meldungen || []).length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            color: root.theme.inputBg
            border.color: root.theme.border
            radius: 4
            ListView {
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                model: root._bericht.meldungen || []
                ScrollBar.vertical: ScrollBar {}
                delegate: Text {
                    required property var modelData
                    width: ListView.view.width
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    color: modelData.fehler ? "#cc6666" : "#e0a800"
                    text: (modelData.zeile > 0 ? qsTr("Zeile %1: ").arg(modelData.zeile) : "") + modelData.text
                }
            }
        }

        // ── Buttons ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); implicitHeight: 32; implicitWidth: 110
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }
            Button {
                text: qsTr("Importieren"); implicitHeight: 32; implicitWidth: 130
                enabled: root._kannImportieren
                contentItem: Text { text: parent.text; font.pixelSize: 12
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                onClicked: {
                    var b = db.spsImportAusfuehren(root.projektId, root._pfad, root._konfigJson())
                    if (b.ausgefuehrt) {
                        meldungManager.zeigen(qsTr("Import abgeschlossen: %1 neue Kanäle, %2 aktualisiert")
                                              .arg(b.neueKanaele).arg(b.aktualisiert), true)
                        root.importiert()
                        root.close()
                    } else {
                        root._bericht = b
                    }
                }
            }
        }
    }
}
