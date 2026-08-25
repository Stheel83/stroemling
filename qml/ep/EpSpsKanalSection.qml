import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:  parent ? parent.width : 0
    height: _istSpsRelevant ? spsCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    readonly property bool _istSpsRelevant: {
        if (!panel.el || (panel.el.typ || "") !== "symbol") return false
        var sid = panel.el.symbolId || ""
        return sid.indexOf("sps_") === 0 || sid.indexOf("pls_") === 0
    }

    property int _refresh: 0

    property var kanalInfo: {
        _refresh
        if (!_istSpsRelevant || (panel.el.id || 0) <= 0) return ({})
        var info = db.spsKanalFuerElement(panel.el.id)
        return (info && info.id) ? info : ({})
    }

    readonly property bool hatKanal: (kanalInfo.id || 0) > 0
    readonly property bool istPls:   hatKanal && (kanalInfo.system_typ || "SPS") === "PLS"

    // SPS-KANAL-ZUWEISEN-LEER-01: als "model:"-Bindung ausgewertet wurde diese
    // Liste nur einmal beim Erzeugen der Komponente berechnet und danach nie
    // wieder aktualisiert (kein QML-Property hängt von den DB-Zeilen ab) - neu
    // angelegte Kanäle aus einer ganz anderen Ansicht (SpsAnsicht.qml) blieben
    // im Zuweisen-Popup dauerhaft unsichtbar. Wird jetzt zusätzlich in
    // Dialog.onOpened frisch neu berechnet.
    // SPS-KANAL-TYP-FILTER-01: erwarteten I/O-Typ (DI/DO/AI/AO) aus der
    // Symbol-ID ableiten - zweites "_"-getrenntes Segment
    // ("sps_do_einpolig" -> "DO", "sps_ai_4" -> "AI", "pls_ao_4" -> "AO").
    function _erwarteterKanalTyp(symbolId) {
        var teile = (symbolId || "").split("_")
        return (teile[1] || "").toUpperCase()
    }

    // Tatsächlicher I/O-Typ eines Kanals aus dem Baugruppen-Typ - bei
    // gemischten DIO/AIO-Baugruppen zusätzlich nach Richtung (adress_typ
    // 'E'=Eingang/'A'=Ausgang) aufgeschlüsselt, da eine einzelne Kanalzeile
    // dort nur eine Richtung vertritt.
    function _kanalTyp(kanal) {
        var bgTyp = (kanal.baugruppe_typ || "").toUpperCase()
        if (bgTyp === "DIO") return kanal.adress_typ === "A" ? "DO" : "DI"
        if (bgTyp === "AIO") return kanal.adress_typ === "A" ? "AO" : "AI"
        return bgTyp
    }

    function _freieKanaeleErmitteln() {
        if (!panel.canvas || (panel.canvas.projektId || -1) < 0) return []
        var alle      = db.spsKanalListe(panel.canvas.projektId)
        var aktElemId = panel.el ? (panel.el.id || 0) : 0
        // Nur bei eindeutig typisierten Symbolen (DI/DO/AI/AO) einschränken -
        // Nutzerwunsch: ein AO-Symbol darf sich keinen DI-Kanal zuweisen lassen.
        var erwarteterTyp = _erwarteterKanalTyp(panel.el ? panel.el.symbolId : "")
        var typEingrenzen = ["DI", "DO", "AI", "AO"].indexOf(erwarteterTyp) >= 0
        var ergebnis  = []
        for (var i = 0; i < alle.length; i++) {
            var eid = alle[i].grafik_element_id
            if (typEingrenzen && _kanalTyp(alle[i]) !== erwarteterTyp) continue
            if (!eid || eid === aktElemId) ergebnis.push(alle[i])
        }
        return ergebnis
    }

    function richtungText(typ) {
        if (typ === "E") return "Eingang"
        if (typ === "A") return "Ausgang"
        if (typ === "M") return "Merker"
        if (typ === "T") return "Timer"
        if (typ === "Z") return "Zaehler"
        return typ
    }

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    component InfoZeile: Item {
        id: izRoot
        property string label: ""
        property string wert:  ""
        property bool   fett:  false
        width: root.width; height: 20
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 0
            Text {
                text: izRoot.label + ":"
                font.pixelSize: 10; color: root.theme.panelMid
                width: 72
            }
            Text {
                text: izRoot.wert; font.pixelSize: 10; font.bold: izRoot.fett
                color: root.theme.textSecondary
                width: root.width - 12 - 72 - 8; elide: Text.ElideRight
            }
        }
    }

    Column {
        id: spsCol
        width: parent.width
        spacing: 0

        Trennlinie {}
        AbschnittTitel { text: "SPS/PLS-KANAL" }

        // ── kein Kanal zugewiesen ─────────────────────────────
        Item {
            visible: !root.hatKanal
            width: parent.width; height: 34
            Rectangle {
                anchors {
                    left: parent.left; right: parent.right
                    margins: 12; verticalCenter: parent.verticalCenter
                }
                height: 26; radius: 3
                color: zuweiseMa.containsMouse ? root.theme.border : root.theme.inputBg
                border.color: root.theme.border
                Text {
                    anchors.centerIn: parent
                    text: "Kanal zuweisen ..."
                    font.pixelSize: 10; color: root.theme.accent
                }
                MouseArea {
                    id: zuweiseMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: dlgKanalWaehlen.open()
                }
            }
        }

        // ── SPS-Kanal zugewiesen ──────────────────────────────
        Column {
            visible: root.hatKanal && !root.istPls
            width: parent.width; spacing: 1

            InfoZeile {
                label: "Adresse"
                wert: (root.kanalInfo.adresse || "?") + "  (SPS – " +
                      root.richtungText(root.kanalInfo.adress_typ || "") +
                      " " + (root.kanalInfo.datentyp || "") + ")"
                fett: true
            }
            InfoZeile {
                label: "Variable"
                wert:  root.kanalInfo.variablenname || "–"
            }
            InfoZeile {
                visible: (root.kanalInfo.kommentar || "") !== ""
                label:   "Kommentar"
                wert:    root.kanalInfo.kommentar || ""
            }
        }

        // ── PLS-Kanal zugewiesen ──────────────────────────────
        Column {
            visible: root.hatKanal && root.istPls
            width: parent.width; spacing: 1

            InfoZeile {
                label: "Adresse"
                wert: (root.kanalInfo.adresse || "?") + "  (PLS – " +
                      root.richtungText(root.kanalInfo.adress_typ || "") + ")"
                fett: true
            }
            InfoZeile {
                label: "Tag"
                wert:  root.kanalInfo.variablenname || "–"
            }
            InfoZeile {
                visible: (root.kanalInfo.kommentar || "") !== ""
                label:   "Kommentar"
                wert:    root.kanalInfo.kommentar || ""
            }
            InfoZeile {
                visible: (root.kanalInfo.pls_einheit || "") !== ""
                         || root.kanalInfo.pls_bereich_min !== undefined
                label: "Einheit / Bereich"
                wert: {
                    var s   = root.kanalInfo.pls_einheit || ""
                    var min = root.kanalInfo.pls_bereich_min
                    var max = root.kanalInfo.pls_bereich_max
                    if (min !== undefined && max !== undefined)
                        s += (s ? "  " : "") + min + " – " + max
                    return s || "–"
                }
            }
            InfoZeile {
                id: alarmZeile
                property var k: root.kanalInfo
                visible: k.pls_alarm_ll !== undefined || k.pls_alarm_lo !== undefined
                         || k.pls_alarm_hi !== undefined || k.pls_alarm_hh !== undefined
                label: "Alarm"
                wert: {
                    var parts = []
                    if (alarmZeile.k.pls_alarm_ll !== undefined)
                        parts.push("LL " + alarmZeile.k.pls_alarm_ll)
                    if (alarmZeile.k.pls_alarm_lo !== undefined)
                        parts.push("LO " + alarmZeile.k.pls_alarm_lo)
                    if (alarmZeile.k.pls_alarm_hi !== undefined)
                        parts.push("HI " + alarmZeile.k.pls_alarm_hi)
                    if (alarmZeile.k.pls_alarm_hh !== undefined)
                        parts.push("HH " + alarmZeile.k.pls_alarm_hh)
                    return parts.join("  ·  ")
                }
            }
        }

        // ── Aktionsbuttons (Kanal zugewiesen) ────────────────
        Item {
            visible: root.hatKanal
            width: parent.width; height: 34
            Row {
                anchors {
                    left: parent.left; right: parent.right
                    margins: 12; verticalCenter: parent.verticalCenter
                }
                spacing: 6
                Rectangle {
                    width: Math.round((parent.width - 6) * 0.58)
                    height: 26; radius: 3
                    color: aendernMa.containsMouse ? root.theme.border : root.theme.inputBg
                    border.color: root.theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "Andern ..."
                        font.pixelSize: 10; color: root.theme.accent
                    }
                    MouseArea {
                        id: aendernMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: dlgKanalWaehlen.open()
                    }
                }
                Rectangle {
                    width: Math.round((parent.width - 6) * 0.42)
                    height: 26; radius: 3
                    color: entfernenMa.containsMouse ? root.theme.border : root.theme.inputBg
                    border.color: root.theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "Entfernen"
                        font.pixelSize: 10; color: root.theme.borderLight
                    }
                    MouseArea {
                        id: entfernenMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var kid = root.kanalInfo.id || 0
                            if (kid > 0) {
                                db.spsKanalElementEntfernen(kid)
                                root._refresh++
                                panel.canvas.spsKonfliktAktualisieren()
                            }
                        }
                    }
                }
            }
        }

        Item { height: 4 }
    }

    // ── Dialog: Kanal wählen ──────────────────────────────────────────────
    Dialog {
        id: dlgKanalWaehlen
        width: 400
        anchors.centerIn: Overlay.overlay
        modal: true

        property int gewaehltId: 0

        background: Rectangle {
            color: root.theme.sidebar
            border.color: root.theme.border
            border.width: 1; radius: 6
        }

        header: Item {
            height: 36
            Text {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                text: "SPS/PLS-Kanal zuweisen"
                color: root.theme.accent
                font.pixelSize: 13; font.weight: Font.Medium
            }
        }

        onOpened: {
            dlgKanalWaehlen.gewaehltId = root.kanalInfo.id || 0
            kanalListe.model = root._freieKanaeleErmitteln()
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: {
            if (!panel.el || dlgKanalWaehlen.gewaehltId <= 0) return

            // SPS-KANAL-ZUWEISEN-ID0-01: ein frisch platziertes, noch nicht
            // gespeichertes Element hat hier id=0 (DB vergibt die echte ID erst
            // beim Speichern) - die Zuweisung würde am Fremdschlüssel scheitern.
            // Etabliertes Muster (analog EpMakrokastenSection.qml): jetzt
            // speichern, neu laden, Element über Position wiederfinden (Index/
            // ID sind nach dem Reload nicht mehr verlässlich dieselben).
            var savedTyp      = panel.el.typ
            var savedSymbolId = panel.el.symbolId
            var savedX1       = panel.el.x1, savedY1 = panel.el.y1
            panel.canvas.grafikSpeichernJetzt()
            panel.canvas.elementeModel.laden(panel.canvas.seiteId)
            var reloaded = panel.canvas.elementeModel.snapshot()
            var freshEl  = null
            for (var i = 0; i < reloaded.length; i++) {
                var r = reloaded[i]
                if (r.typ === savedTyp && r.symbolId === savedSymbolId
                        && Math.abs(r.x1 - savedX1) < 0.01 && Math.abs(r.y1 - savedY1) < 0.01) {
                    freshEl = r; break
                }
            }
            if (!freshEl || (freshEl.id || 0) <= 0) return

            var aktId = root.kanalInfo.id || 0
            if (aktId > 0 && aktId !== dlgKanalWaehlen.gewaehltId)
                db.spsKanalElementEntfernen(aktId)
            db.spsKanalElementZuweisen(dlgKanalWaehlen.gewaehltId, freshEl.id)

            // Nutzerwunsch: BMK automatisch aus Rack/Slot/Kanal vorbelegen,
            // aber nur wenn noch keins gesetzt ist (nie einen vorhandenen
            // BMK überschreiben).
            var bisherigesBmk = (freshEl.extraDaten && freshEl.extraDaten.bmk) || ""
            if (bisherigesBmk.trim() === "") {
                var gewaehltesKanal = null
                var modellListe = kanalListe.model || []
                for (var k = 0; k < modellListe.length; k++) {
                    if (modellListe[k].id === dlgKanalWaehlen.gewaehltId) { gewaehltesKanal = modellListe[k]; break }
                }
                if (gewaehltesKanal) {
                    // PLS: Rack/Slot/Kanal (kein systemtyp-eigenes Adressformat
                    // mit Aussagekraft) - SPS: die tatsächliche SPS-Adresse
                    // (E0.0/A1.3/EW64 ...), die für SPS-Technik die relevante
                    // Kennung ist, nicht Rack/Slot/Kanal.
                    var bmkVorschlag = (gewaehltesKanal.system_typ || "SPS") === "PLS"
                        ? "-R" + (gewaehltesKanal.rack_nr || 0)
                          + "-S" + (gewaehltesKanal.slot || 0)
                          + "-K" + ((gewaehltesKanal.kanal_nr || 0) + 1)
                        : "-" + (gewaehltesKanal.adresse || "")
                    if (bmkVorschlag !== "-")
                        db.grafikElementExtraMergeSetzen(freshEl.id, { bmk: bmkVorschlag })
                }
            }

            panel.canvas.seiteNeuLaden()
            root._refresh++
            panel.canvas.spsKonfliktAktualisieren()
        }

        ColumnLayout {
            width: parent.width
            spacing: 8

            Text {
                text: "Freien Kanal auswählen:"
                color: root.theme.textBright; font.pixelSize: 11
            }

            ListView {
                id: kanalListe
                Layout.fillWidth: true
                // Fixe Höhe statt Math.min(contentHeight, 220) (SPS-KANAL-ZUWEISEN-LEER-01
                // Teil 2): das Popup berechnet seine Größe direkt beim Öffnen, bevor
                // onOpened das Modell neu befüllt - contentHeight war zu dem Zeitpunkt noch
                // 0 (letzter Stand vor dem Neu-Befüllen), das Popup blieb dauerhaft auf
                // Höhe 0 für die Liste hängen, obwohl das Modell danach korrekt gefüllt war.
                height: 220
                clip: true

                model: root._freieKanaeleErmitteln()

                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    width: kanalListe.width; height: 30; radius: 3
                    color: dlgKanalWaehlen.gewaehltId === modelData.id
                           ? root.theme.activeItemAlt
                           : (delegMa.containsMouse ? root.theme.hover : "transparent")
                    border.color: dlgKanalWaehlen.gewaehltId === modelData.id
                                  ? root.theme.accent : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text {
                            text: root._kanalTyp(modelData) || "–"
                            font.pixelSize: 10; font.bold: true
                            color: {
                                switch (root._kanalTyp(modelData)) {
                                case "DI": case "AI": return "#4caf50"
                                case "DO": case "AO": return "#f44336"
                                default: return root.theme.textMuted
                                }
                            }
                            width: 26; elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.adresse || "?"
                            font.pixelSize: 11; font.bold: true; color: root.theme.accent
                            width: 74; elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.variablenname || "–"
                            font.pixelSize: 11; color: root.theme.textSecondary
                            width: 100; elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.kommentar || ""
                            font.pixelSize: 10; color: root.theme.textMuted
                            elide: Text.ElideRight
                            width: kanalListe.width - 8 - 26 - 74 - 100 - 32
                        }
                    }
                    MouseArea {
                        id: delegMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dlgKanalWaehlen.gewaehltId = modelData.id
                        onDoubleClicked: {
                            dlgKanalWaehlen.gewaehltId = modelData.id
                            dlgKanalWaehlen.accept()
                        }
                    }
                }
            }

            Text {
                visible: kanalListe.count === 0
                text: "Keine freien Kanäle vorhanden.\nKanäle in der SPS/PLS-Ansicht anlegen."
                color: root.theme.textMuted; font.pixelSize: 10; font.italic: true
                wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
        }
    }
}
