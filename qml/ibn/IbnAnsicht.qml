import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    property int    projektId:   -1
    property int    seiteId:     -1
    property var    theme
    property bool   debug:       false

    // "projekt" = alle Seiten, "seite" = nur aktuelle Seite
    property string ansichtModus: "projekt"

    // "bm" = Betriebsmittel, "kabel" = Kabel+Adern
    property string _kategorie: "bm"

    property int    ausgewaehlterIndex:       -1
    property int    kabelAusgewaehlterIndex: -1
    property var    _kabelAdern:              []

    // Dynamische Messfelder für das ausgewählte BM
    property var _dynFelder: []   // [{feldname, label, feldtyp, optionen, einheit, pflichtfeld}]
    property var _dynWerte:  ({}) // feldname → wert (String)

    function _dynWerteAlsListe() {
        var result = []
        var feldMap = {}
        for (var fi = 0; fi < root._dynFelder.length; fi++)
            feldMap[root._dynFelder[fi].feldname] = root._dynFelder[fi].feldtyp
        for (var fn in root._dynWerte) {
            var wert = root._dynWerte[fn]
            if (feldMap[fn] === "zahl") wert = wert.replace(",", ".")
            result.push({ "feldname": fn, "wert": wert })
        }
        return result
    }

    signal bmkGewaehlt(int seiteId, int elementId, real x1, real y1)
    signal geschlossen()

    // ── BM-Liste ──────────────────────────────────────────────
    property var    _liste:  []
    property string _suche:  ""
    property string _filter: "alle"

    // Canvas-Overlay: bmk → status
    property var statusMap: ({})

    function _statusMapAktualisieren() {
        var m = {}
        for (var i = 0; i < root._liste.length; i++) {
            var e = root._liste[i]
            if (e.bmk) m[e.bmk] = e.status || "offen"
        }
        root.statusMap = m
    }

    // ── Kabel-Liste ───────────────────────────────────────────
    property var _kabelListe: []

    function kabelLaden() {
        root._kabelListe = (root.projektId >= 0)
                           ? db.ibnKabelListeLaden(root.projektId) : []
        root.kabelAusgewaehlterIndex = -1
        root._kabelAdern = []
    }

    function _gefilterteKabelListe() {
        var s = root._suche.trim().toLowerCase()
        return root._kabelListe.filter(function(k) {
            var textOk = s === ""
                || (k.bezeichnung || "").toLowerCase().indexOf(s) >= 0
                || (k.kabeltyp    || "").toLowerCase().indexOf(s) >= 0
                || (k.vonOrt      || "").toLowerCase().indexOf(s) >= 0
                || (k.nachOrt     || "").toLowerCase().indexOf(s) >= 0
            var statusOk = root._filter === "alle" || k.status === root._filter
            return textOk && statusOk
        })
    }

    // ── Gemeinsame Hilfsfunktionen ────────────────────────────
    function laden() {
        var sid = (root.ansichtModus === "seite" && root.seiteId >= 0)
                  ? root.seiteId : -1
        root._liste = db.ibnListeLaden(root.projektId, sid)
        root.ausgewaehlterIndex = -1
        root._statusMapAktualisieren()
        kabelLaden()
    }

    function _gefilterteListe() {
        var s = root._suche.trim().toLowerCase()
        return root._liste.filter(function(e) {
            var textOk = s === ""
                || e.bmk.toLowerCase().indexOf(s) >= 0
                || e.blattnummer.toLowerCase().indexOf(s) >= 0
                || (e.seitenbezeichnung || "").toLowerCase().indexOf(s) >= 0
            var statusOk = root._filter === "alle" || e.status === root._filter
            return textOk && statusOk
        })
    }

    function _statusFarbe(status) {
        switch (status) {
            case "in_arbeit":     return "#e0b040"
            case "abgeschlossen": return "#44aa66"
            default:              return "#666688"
        }
    }

    function _statusLabel(status) {
        switch (status) {
            case "in_arbeit":     return qsTr("In Arbeit")
            case "abgeschlossen": return qsTr("✓ Fertig")
            default:              return qsTr("Offen")
        }
    }

    onAnsichtModusChanged: laden()
    onSeiteIdChanged:      { if (ansichtModus === "seite") laden() }
    onProjektIdChanged:    { if (projektId >= 0) laden() }

    // ── Layout ────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: titelZeile.height + steuerZeile.height
            color: theme.surfaceDeep

            Column {
                anchors.fill: parent

                // Zeile 1: Titel + Schließen
                RowLayout {
                    id: titelZeile
                    width: parent.width
                    height: 36
                    spacing: 6

                    Item { width: 12 }

                    Text {
                        text: qsTr("⚡ Inbetriebnahme")
                        font.pixelSize: 13; font.weight: Font.Medium
                        color: theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Button {
                        flat: true; implicitWidth: 28; implicitHeight: 28
                        contentItem: Text { text: "✕"; color: theme.textMuted; font.pixelSize: 14;
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                        onClicked: root.geschlossen()
                    }

                    Item { width: 4 }
                }

                // Zeile 2: Toggles + PDF
                RowLayout {
                    id: steuerZeile
                    width: parent.width
                    height: 32
                    spacing: 6

                    Item { width: 6 }

                    // BM / Kabel / Felder Toggle
                    RowLayout {
                        spacing: 2
                        Repeater {
                            model: [
                                { key: "bm",     label: qsTr("BM")     },
                                { key: "kabel",  label: qsTr("Kabel")  },
                                { key: "felder", label: qsTr("Felder") }
                            ]
                            delegate: Rectangle {
                                implicitWidth: 46; implicitHeight: 24; radius: 4
                                color: root._kategorie === modelData.key
                                       ? theme.accent : theme.activeItem
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label; font.pixelSize: 11
                                    color: root._kategorie === modelData.key
                                           ? "white" : theme.textSecondary
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root._kategorie = modelData.key
                                }
                            }
                        }
                    }

                    // Projekt / Seite Toggle (nur bei BM/Kabel)
                    RowLayout {
                        visible: root._kategorie !== "felder"
                        spacing: 2
                        Repeater {
                            model: [
                                { key: "projekt", label: qsTr("Projekt") },
                                { key: "seite",   label: qsTr("Seite")   }
                            ]
                            delegate: Rectangle {
                                implicitWidth: 50; implicitHeight: 24; radius: 4
                                color: root.ansichtModus === modelData.key
                                       ? theme.accent : theme.activeItem
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label; font.pixelSize: 11
                                    color: root.ansichtModus === modelData.key
                                           ? "white" : theme.textSecondary
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.ansichtModus = modelData.key
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        flat: true; implicitWidth: 86; implicitHeight: 24
                        contentItem: Text { text: qsTr("⬇ PDF"); color: theme.textPrimary; font.pixelSize: 11;
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4;
                            border.color: theme.accent }
                        onClicked: pdfSaveDialog.open()
                        ToolTip.visible: hovered; ToolTip.text: qsTr("Prüfprotokoll als PDF exportieren")
                        ToolTip.delay: 600
                    }

                    Item { width: 4 }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Suche + Filter (nur BM/Kabel) ─────────────────────
        RowLayout {
            visible: root._kategorie !== "felder"
            Layout.fillWidth: true; Layout.margins: 8; spacing: 6

            TextField {
                id: tfSuche
                Layout.fillWidth: true; implicitHeight: 30
                placeholderText: root._kategorie === "kabel"
                                 ? qsTr("Kabel / Typ / Ort suchen …")
                                 : qsTr("BMK / Blatt suchen …")
                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                color: theme.textPrimary; font.pixelSize: 12
                onTextChanged: root._suche = text
            }

            ComboBox {
                id: cmbFilter
                implicitWidth: 110; implicitHeight: 30
                model: [
                    { key: "alle",           label: qsTr("Alle")       },
                    { key: "offen",          label: qsTr("Offen")      },
                    { key: "in_arbeit",      label: qsTr("In Arbeit")  },
                    { key: "abgeschlossen",  label: qsTr("Fertig")     }
                ]
                textRole: "label"
                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                contentItem: Text {
                    leftPadding: 8; text: cmbFilter.displayText
                    color: theme.textPrimary; font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    width: cmbFilter.width; implicitHeight: 28
                    highlighted: cmbFilter.highlightedIndex === index
                    contentItem: Text {
                        leftPadding: 8; text: modelData.label
                        color: theme.textPrimary; font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                }
                onActivated: root._filter = model[index].key
            }
        }

        Rectangle {
            visible: root._kategorie !== "felder"
            Layout.fillWidth: true; height: 1; color: theme.divider
        }

        IbnBmSplit {
            id: bmSplit
            panel: root
            theme: root.theme
            debug: root.debug
            visible:           root._kategorie === "bm"
            Layout.fillWidth:  true
            Layout.fillHeight: root._kategorie === "bm"
            onBmkGewaehlt: function(sId, eId, x, y) { root.bmkGewaehlt(sId, eId, x, y) }
        }

        IbnKabelSplit {
            panel: root
            theme: root.theme
            debug: root.debug
            visible:           root._kategorie === "kabel"
            Layout.fillWidth:  true
            Layout.fillHeight: root._kategorie === "kabel"
            onKabelGewaehlt: function(sId, eId, x, y) { root.bmkGewaehlt(sId, eId, x, y) }
        }

        IbnFeldPanel {
            id: feldPanel
            theme: root.theme
            debug: root.debug
            visible:           root._kategorie === "felder"
            Layout.fillWidth:  true
            Layout.fillHeight: root._kategorie === "felder"
            onFelderGeaendert: {
                // Dynamische Felder des aktuell gewählten BM neu laden
                var fl = root._gefilterteListe()
                if (root.ausgewaehlterIndex >= 0 && root.ausgewaehlterIndex < fl.length) {
                    var e = fl[root.ausgewaehlterIndex]
                    var kat = e.symbolKategorie || ""
                    root._dynFelder = kat !== "" ? db.ibnFeldvorlagenLaden(kat) : []
                }
            }
        }

        // ── Statusleiste ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 28; color: theme.surfaceDeep
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                Text {
                    text: {
                        if (root._kategorie === "felder") {
                            var sys  = feldPanel._vorlagen.filter(function(v){ return v.erstelltVon === "system" }).length
                            var user = feldPanel._vorlagen.filter(function(v){ return v.erstelltVon === "user"   }).length
                            return qsTr("%1 Systemfelder  ·  %2 eigene Felder").arg(sys).arg(user)
                        }
                        var fl = root._kategorie === "kabel"
                                 ? root._gefilterteKabelListe()
                                 : root._gefilterteListe()
                        var offen  = fl.filter(function(e){ return e.status === "offen"         }).length
                        var fertig = fl.filter(function(e){ return e.status === "abgeschlossen" }).length
                        return qsTr("%1 gesamt  ·  %2 offen  ·  %3 fertig")
                               .arg(fl.length).arg(offen).arg(fertig)
                    }
                    font.pixelSize: 10; color: theme.textMuted
                }
                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("⟳"); flat: true; implicitHeight: 24; implicitWidth: 28
                    contentItem: Text { text: parent.text; color: theme.accent; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 3 }
                    onClicked: root.laden()
                }
            }
        }
    }

    // ── PDF-Export ────────────────────────────────────────
    FileDialog {
        id: pdfSaveDialog
        title: qsTr("Prüfprotokoll speichern")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("PDF-Datei (*.pdf)"), qsTr("Alle Dateien (*)")]
        defaultSuffix: "pdf"
        onAccepted: {
            var sid = root.ansichtModus === "seite" ? root.seiteId : -1
            var ok  = db.ibnProtokollPdfSpeichern(root.projektId, sid,
                                                   selectedFile.toString())
            if (ok) achievementManager.ereignis("ibn_protokoll")
            meldungManager.zeigen(ok ? qsTr("PDF gespeichert.") : qsTr("PDF konnte nicht gespeichert werden."), ok)
        }
    }

    DebugLabel { panelName: qsTr("IBN-Ansicht"); visible: root.debug }
}
