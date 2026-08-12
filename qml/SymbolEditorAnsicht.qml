import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "symboleditor"

// ============================================================
// SymbolEditorAnsicht – visueller Symboleditor (Phase D)
//
// Eigenschaften die vom Elternelement gesetzt werden müssen:
//   theme          – Theme-Objekt aus Main.qml
//   editSymbolId   – ID des zu bearbeitenden Symbols ("" = neues Symbol)
//
// Signals:
//   gespeichert(string symbolId) – nach erfolgreichem Speichern
//   abgebrochen()               – nach Abbrechen
// ============================================================

Item {
    id: root
    focus: true

    // ── Öffentliche Properties ─────────────────────────────────────
    property string editSymbolId: ""
    property var    theme
    property bool   debug: false

    signal gespeichert(string symbolId)
    signal abgebrochen()

    // ── Innerer Zustand ────────────────────────────────────────────
    property string nameText:      qsTr("Neues Symbol")
    property string kategorieText: ""
    property int    breiteMm:      32
    property int    hoeheMm:       16
    property string rolleText:     "durchleiter"
    // BMK-Label-Position (SYMBOL-BMKSEITE-EDITOR-01): "auto" (0°/180°→oben,
    // 90°/270°→seitlich) oder "vertikal" (umgekehrt — für Symbole deren
    // Grundausrichtung bei 0° bereits vertikal ist, z.B. Kontakte nach
    // SYMBOL-VERTIKAL-01). Siehe CanvasRenderHandler.qml maleElement().
    property string bmkSeiteText:  "auto"
    property bool   istBuiltin:    false
    property string vorlageId:     ""   // wenn gesetzt: Geometrie aus diesem Symbol als Vorlage laden
    property bool   _kopierModus:  false
    property real   _seZoom: 1.0
    property real   _sePanX: 0.0
    property real   _sePanY: 0.0

    property var    primitive:          []   // array of QVariantMap
    property var    pins:               []   // array of {name, x, y, offenX, offenY, signaltyp, kontext}
    property var    undoStack:          []   // array of {typ: "primitiv"|"pin"}

    property string aktivesWerkzeug:    "auswahl"
    property int    ausgewaehltPrimIdx: -1
    property int    ausgewaehltPinIdx:  -1
    property string aktLinienart:       "solid"
    property bool   aktGefuellt:        false

    // Zwischenpunkte für Mehrstufenwerkzeuge (Linie, Rechteck, Kreis, Bogen)
    property var    werkzeugPunkte: []
    property var    mausNormPos:    ({x: -1, y: -1})
    property bool   mausImCanvas:   false

    // ── Symbolliste: Zustand ────────────────────────────────────────
    property var    listenSymbole:     []
    property string aktiveListenId:    ""
    property string listeFilter:       ""
    property string loeschenSymbolId:  ""
    property string loeschenSymbolName: ""

    property var gefilterteSymbole: {
        var f = listeFilter.toLowerCase()
        var result = f ? listenSymbole.filter(function(s) {
            return s.name.toLowerCase().indexOf(f) >= 0 ||
                   (s.kategorie || "").toLowerCase().indexOf(f) >= 0
        }) : listenSymbole.slice()
        var ordnung = ["kontakte","schutz","antriebe","passive","signalgeraete",
                       "klemmen","sps_pls","kfz","arduino","sensoren"]
        result.sort(function(a, b) {
            var ia = ordnung.indexOf(a.kategorie || ""); if (ia < 0) ia = 999
            var ib = ordnung.indexOf(b.kategorie || ""); if (ib < 0) ib = 999
            if (ia !== ib) return ia - ib
            return (a.name || "").localeCompare(b.name || "")
        })
        return result
    }

    function normToMmX(v) { return v * root.breiteMm }
    function normToMmY(v) { return v * root.hoeheMm }
    function normToMmForField(name, v) {
        return (name === "y1" || name === "y2" || name === "y3") ? v * root.hoeheMm : v * root.breiteMm
    }
    function mmToNormForField(name, v) {
        return (name === "y1" || name === "y2" || name === "y3") ? v / root.hoeheMm : v / root.breiteMm
    }
    function istPositionsfeld(name) {
        return ["x1","y1","x2","y2","x3","y3","radius"].indexOf(name) >= 0
    }

    // ── Daten laden ────────────────────────────────────────────────
    Component.onCompleted: { ladeDaten(); symbollisteAktualisieren() }
    onEditSymbolIdChanged:  ladeDaten()
    onVorlageIdChanged:     ladeDaten()

    function ladeDaten() {
        if (_kopierModus) return
        undoStack          = []
        ausgewaehltPrimIdx = -1
        ausgewaehltPinIdx  = -1
        werkzeugPunkte     = []

        if (editSymbolId === "" && vorlageId !== "") {
            // Vorlage laden – Geometrie kopieren, Symbol-ID bleibt leer (wird beim Speichern neu vergeben)
            var vInfo = symbolDefinitionModel.symbolInfo(vorlageId)
            nameText      = qsTr("Kopie von ") + (vInfo.name || vorlageId)
            kategorieText = vInfo.kategorie || ""
            breiteMm      = vInfo.breiteMm  || 32
            hoeheMm       = vInfo.hoeheMm   || 16
            rolleText     = vInfo.rolle     || "durchleiter"
            bmkSeiteText  = vInfo.bmkSeite  || "auto"
            istBuiltin    = false

            var vPrims   = symbolDefinitionModel.primitiveFuerSymbol(vorlageId)
            var vPinList = symbolDefinitionModel.pinsForSymbol(vorlageId)
            var vPins    = []
            for (var vi = 0; vi < vPinList.length; vi++) {
                var vp = vPinList[vi]
                vPins.push({
                    name:      vp.name,
                    x:         vp.x,
                    y:         vp.y,
                    offenX:    vp.offenX !== undefined ? vp.offenX : (vp.offen ? vp.offen.x : -1),
                    offenY:    vp.offenY !== undefined ? vp.offenY : (vp.offen ? vp.offen.y : 0),
                    signaltyp: vp.signaltyp || "neutral",
                    kontext:   vp.kontext   || "",
                    knotenGruppe: vp.knotenGruppe !== undefined ? vp.knotenGruppe : 0
                })
            }
            primitive = vPrims.slice()
            pins      = vPins
        } else if (editSymbolId === "") {
            nameText      = qsTr("Neues Symbol")
            kategorieText = ""
            breiteMm      = 32
            hoeheMm       = 16
            rolleText     = "durchleiter"
            bmkSeiteText  = "auto"
            istBuiltin    = false
            primitive     = []
            pins          = []
        } else {
            var info = symbolDefinitionModel.symbolInfo(editSymbolId)
            nameText      = info.name      || editSymbolId
            kategorieText = info.kategorie || ""
            breiteMm      = info.breiteMm  || 32
            hoeheMm       = info.hoeheMm   || 16
            rolleText     = info.rolle     || "durchleiter"
            bmkSeiteText  = info.bmkSeite  || "auto"
            istBuiltin    = info.ist_builtin     || false

            var prims = symbolDefinitionModel.primitiveFuerSymbol(editSymbolId)
            var pinList = symbolDefinitionModel.pinsForSymbol(editSymbolId)

            // Pins mit offenX/offenY flach machen für interne Nutzung
            var flatPins = []
            for (var i = 0; i < pinList.length; i++) {
                var p = pinList[i]
                flatPins.push({
                    name:      p.name,
                    x:         p.x,
                    y:         p.y,
                    offenX:    p.offenX !== undefined ? p.offenX : (p.offen ? p.offen.x : -1),
                    offenY:    p.offenY !== undefined ? p.offenY : (p.offen ? p.offen.y : 0),
                    signaltyp: p.signaltyp || "neutral",
                    kontext:   p.kontext   || "",
                    knotenGruppe: p.knotenGruppe !== undefined ? p.knotenGruppe : 0
                })
            }
            primitive = prims.slice()
            pins      = flatPins
        }
        zeichneCanvas.requestPaint()
    }

    function symbollisteAktualisieren() {
        listenSymbole = symbolDefinitionModel.alleSymbole()
    }

    function neuesSymbol() {
        aktiveListenId = ""
        vorlageId      = ""
        if (editSymbolId !== "") { editSymbolId = "" } else { ladeDaten() }
    }

    function kopieErstellen() {
        _kopierModus   = true
        aktiveListenId = ""
        vorlageId      = ""
        editSymbolId   = ""
        istBuiltin     = false
        nameText       = qsTr("Kopie von ") + nameText
        _kopierModus   = false
    }

    function fmtN(v) {
        if (v === undefined || v === null) return "0"
        var n = parseFloat(v)
        return isNaN(n) ? "0" : n.toString()
    }

    function kopiereInZwischenablage(text) {
        klipboardHelper.text = text
        klipboardHelper.selectAll()
        klipboardHelper.copy()
    }

    function sqlAlsText(symbolId) {
        var info    = symbolDefinitionModel.symbolInfo(symbolId)
        var prims   = symbolDefinitionModel.primitiveFuerSymbol(symbolId)
        var pinList = symbolDefinitionModel.pinsForSymbol(symbolId)
        if (!info || !info.name) return ""
        function esc(s) { return (s || "").replace(/'/g, "''") }
        var lines = []
        lines.push("-- ── " + info.name + " ──")
        lines.push("INSERT INTO symbol_definition (id, name, kategorie, breite_mm, hoehe_mm, rolle, ist_builtin) VALUES")
        lines.push("('" + esc(symbolId) + "', '" + esc(info.name) + "', '" + esc(info.kategorie || "") + "', " +
                   (info.breiteMm || 32) + ", " + (info.hoeheMm || 16) + ", '" + esc(info.rolle || "durchleiter") + "', 0);")
        lines.push("")
        if (pinList.length > 0) {
            lines.push("INSERT INTO symbol_pin (symbol_id, name, x, y, offen_x, offen_y, signaltyp) VALUES")
            for (var pi = 0; pi < pinList.length; pi++) {
                var pin = pinList[pi]
                var ox  = pin.offenX !== undefined ? pin.offenX : (pin.offen ? pin.offen.x : -1)
                var oy  = pin.offenY !== undefined ? pin.offenY : (pin.offen ? pin.offen.y : 0)
                lines.push("('" + esc(symbolId) + "', '" + esc(pin.name) + "', " +
                            fmtN(pin.x) + ", " + fmtN(pin.y) + ", " + fmtN(ox) + ", " + fmtN(oy) +
                            ", '" + esc(pin.signaltyp || "neutral") + "')" +
                            (pi < pinList.length - 1 ? "," : ";"))
            }
            lines.push("")
        }
        if (prims.length > 0) {
            lines.push("INSERT INTO symbol_primitiv")
            lines.push("    (symbol_id, reihenfolge, typ, x1, y1, x2, y2, x3, y3,")
            lines.push("     radius, winkel_von, winkel_bis, bogen_gegen_uhrzeiger,")
            lines.push("     text_inhalt, schrift_relativ, schrift_fett, text_align, text_baseline, linienart)")
            lines.push("VALUES")
            for (var pri = 0; pri < prims.length; pri++) {
                var p  = prims[pri]
                var ti = (p.text_inhalt && p.text_inhalt.length > 0) ? "'" + esc(p.text_inhalt) + "'" : "NULL"
                lines.push("('" + esc(symbolId) + "', " + pri + ", '" + esc(p.typ) + "', " +
                            fmtN(p.x1) + ", " + fmtN(p.y1) + ", " + fmtN(p.x2) + ", " + fmtN(p.y2) + ", " +
                            fmtN(p.x3) + ", " + fmtN(p.y3) + ", " +
                            fmtN(p.radius) + ", " + fmtN(p.winkel_von) + ", " + fmtN(p.winkel_bis) + ", " +
                            (p.bogen_gegen_uhrzeiger ? 1 : 0) + ", " +
                            ti + ", " + fmtN(p.schrift_relativ || 0.5) + ", " + (p.schrift_fett ? 1 : 0) + ", " +
                            "'" + esc(p.text_align || "center") + "', '" + esc(p.text_baseline || "middle") + "', '" +
                            esc(p.linienart || "solid") + "')" +
                            (pri < prims.length - 1 ? "," : ";"))
            }
        }
        return lines.join("\n")
    }

    // ── Snap-to-Grid (0.5-mm-Raster) ──────────────────────────────
    // Snap auf 0.5mm: breiteMm * 2 Schritte in X, hoeheMm * 2 Schritte in Y
    function snapX(v) { return Math.round(v * root.breiteMm * 2) / (root.breiteMm * 2) }
    function snapY(v) { return Math.round(v * root.hoeheMm  * 2) / (root.hoeheMm  * 2) }

    // ── Primitiv hinzufügen ────────────────────────────────────────
    function addPrimitiv(p) {
        primitive = primitive.concat([p])
        undoStack = undoStack.concat([{typ: "primitiv"}])
        zeichneCanvas.requestPaint()
    }

    // ── Pin hinzufügen ─────────────────────────────────────────────
    function addPin(nx, ny) {
        var neu = {name: "P" + (pins.length + 1), x: nx, y: ny, offenX: -1, offenY: 0, signaltyp: "neutral", kontext: "", knotenGruppe: 0}
        pins = pins.concat([neu])
        undoStack = undoStack.concat([{typ: "pin"}])
        ausgewaehltPinIdx = pins.length - 1
        zeichneCanvas.requestPaint()
    }

    // ── Undo (Strg+Z) ──────────────────────────────────────────────
    function undo() {
        if (undoStack.length === 0) return
        var last = undoStack[undoStack.length - 1]
        undoStack = undoStack.slice(0, undoStack.length - 1)
        if (last.typ === "primitiv" && primitive.length > 0) {
            primitive = primitive.slice(0, primitive.length - 1)
            if (ausgewaehltPrimIdx >= primitive.length) ausgewaehltPrimIdx = -1
        } else if (last.typ === "pin" && pins.length > 0) {
            pins = pins.slice(0, pins.length - 1)
            if (ausgewaehltPinIdx >= pins.length) ausgewaehltPinIdx = -1
        }
        zeichneCanvas.requestPaint()
    }

    // ── Speichern ──────────────────────────────────────────────────
    function speichern() {
        if (istBuiltin) {
            meldungManager.zeigen(qsTr("Eingebaute Symbole können nicht verändert werden. Nutze «Als Vorlage kopieren»."), false)
            return
        }

        var sid = editSymbolId
        if (sid === "") {
            // ID aus Name generieren
            sid = nameText.toLowerCase()
                    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue").replace(/ß/g, "ss")
                    .replace(/[^a-z0-9]/g, "_").replace(/_+/g, "_").replace(/^_|_$/g, "")
            if (sid === "") sid = "symbol_" + Date.now()
        }

        if (editSymbolId === "") {
            if (!symbolDefinitionModel.symbolAnlegen(sid, nameText, kategorieText, breiteMm, hoeheMm, rolleText, bmkSeiteText)) {
                speichernFehlerText.text = qsTr("Symbol-ID bereits vergeben. Bitte anderen Namen wählen.")
                speichernFehlerDialog.open()
                return
            }
        } else {
            symbolDefinitionModel.symbolAktualisieren(sid, nameText, kategorieText, breiteMm, hoeheMm, rolleText, bmkSeiteText)
        }

        symbolDefinitionModel.primitivAlleLoeschen(sid)
        for (var i = 0; i < primitive.length; i++) {
            var p = Object.assign({}, primitive[i])
            p.reihenfolge = i
            symbolDefinitionModel.primitivHinzufuegen(sid, p)
        }

        symbolDefinitionModel.pinAlleLoeschen(sid)
        for (var j = 0; j < pins.length; j++) {
            symbolDefinitionModel.pinHinzufuegen(sid, pins[j])
        }

        symbollisteAktualisieren()
        aktiveListenId = sid
        editSymbolId   = sid
        root.gespeichert(sid)
    }

    // ── Tastenkürzel ───────────────────────────────────────────────
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            undo(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Escape) {
            werkzeugPunkte = []; zeichneCanvas.requestPaint()
            event.accepted = true; return
        }
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (ausgewaehltPrimIdx >= 0) {
                primitive = primitive.filter(function(_, idx) { return idx !== ausgewaehltPrimIdx })
                ausgewaehltPrimIdx = -1
                zeichneCanvas.requestPaint()
            }
            event.accepted = true; return
        }
        if (!event.isAutoRepeat) {
            if (event.key === Qt.Key_A) { aktivesWerkzeug = "auswahl";     werkzeugPunkte = [] }
            if (event.key === Qt.Key_L) { aktivesWerkzeug = "linie";       werkzeugPunkte = [] }
            if (event.key === Qt.Key_R) { aktivesWerkzeug = "rechteck";    werkzeugPunkte = [] }
            if (event.key === Qt.Key_K) { aktivesWerkzeug = "kreis_offen"; werkzeugPunkte = [] }
            if (event.key === Qt.Key_B) { aktivesWerkzeug = "bogen";       werkzeugPunkte = [] }
            if (event.key === Qt.Key_P) { aktivesWerkzeug = "punkt";       werkzeugPunkte = [] }
            if (event.key === Qt.Key_T) { aktivesWerkzeug = "text";        werkzeugPunkte = [] }
            if (event.key === Qt.Key_I) { aktivesWerkzeug = "pin";         werkzeugPunkte = [] }
        }
    }

    // ── Hit-Test Hilfsfunktionen ───────────────────────────────────
    function distPunktZuSegment(px, py, x1, y1, x2, y2) {
        var dx = x2 - x1, dy = y2 - y1
        var lenSq = dx * dx + dy * dy
        if (lenSq < 0.00001) return Math.sqrt((px-x1)*(px-x1)+(py-y1)*(py-y1))
        var t = Math.max(0, Math.min(1, ((px-x1)*dx+(py-y1)*dy)/lenSq))
        var cx = x1 + t*dx, cy = y1 + t*dy
        return Math.sqrt((px-cx)*(px-cx)+(py-cy)*(py-cy))
    }

    function distZuPrimitiv(p, nx, ny) {
        switch (p.typ) {
        case "linie":
            return distPunktZuSegment(nx, ny, p.x1, p.y1, p.x2, p.y2)
        case "rechteck":
            return Math.min(
                distPunktZuSegment(nx, ny, p.x1, p.y1, p.x2, p.y1),
                distPunktZuSegment(nx, ny, p.x2, p.y1, p.x2, p.y2),
                distPunktZuSegment(nx, ny, p.x1, p.y2, p.x2, p.y2),
                distPunktZuSegment(nx, ny, p.x1, p.y1, p.x1, p.y2))
        case "rechteck_gefuellt":
            if (nx >= Math.min(p.x1,p.x2) && nx <= Math.max(p.x1,p.x2) &&
                ny >= Math.min(p.y1,p.y2) && ny <= Math.max(p.y1,p.y2)) return 0
            return Math.min(
                distPunktZuSegment(nx, ny, p.x1, p.y1, p.x2, p.y1),
                distPunktZuSegment(nx, ny, p.x2, p.y1, p.x2, p.y2),
                distPunktZuSegment(nx, ny, p.x1, p.y2, p.x2, p.y2),
                distPunktZuSegment(nx, ny, p.x1, p.y1, p.x1, p.y2))
        case "kreis_offen":
            return Math.abs(Math.sqrt((nx-p.x1)*(nx-p.x1)+(ny-p.y1)*(ny-p.y1))-p.radius)
        case "kreis_gefuellt":
            return Math.sqrt((nx-p.x1)*(nx-p.x1)+(ny-p.y1)*(ny-p.y1))
        case "text":
        case "bogen":
        case "dreieck_gefuellt":
            return Math.sqrt((nx-p.x1)*(nx-p.x1)+(ny-p.y1)*(ny-p.y1))
        default:
            return 999
        }
    }

    function treffePrimitiv(nx, ny) {
        var bestIdx = -1, bestDist = 0.07
        for (var i = 0; i < primitive.length; i++) {
            var d = distZuPrimitiv(primitive[i], nx, ny)
            if (d < bestDist) { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }

    function treffePin(nx, ny) {
        var bestIdx = -1, bestDist = 0.07
        for (var i = 0; i < pins.length; i++) {
            var pin = pins[i]
            var d = Math.sqrt((nx-pin.x)*(nx-pin.x)+(ny-pin.y)*(ny-pin.y))
            if (d < bestDist) { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }


    function repaintAll() { zeichneCanvas.requestPaint() }
    // ── Dialoge ────────────────────────────────────────────────────

    property var textEingabePos: ({x: 0, y: 0})

    Dialog {
        id:      textEingabeDialog
        title:   qsTr("Text-Primitiv einfügen")
        modal:   true
        parent:  Overlay.overlay
        anchors.centerIn: parent
        width:   340
        padding: 16

        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }

        ColumnLayout { spacing: 8; width: parent.width
            Text { text: qsTr("Textinhalt:"); color: root.theme.textMuted; font.pixelSize: 11 }
            TextField {
                id: textFeld
                Layout.fillWidth: true
                placeholderText: "M, 3~, ..."
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                color: root.theme.textPrimary; font.pixelSize: 13
            }
            Row {
                spacing: 12
                Text { text: qsTr("Fett:"); color: root.theme.textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                CheckBox { id: textFettCheck }
            }
        }
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (textFeld.text.length > 0)
                root.addPrimitiv({typ: "text", x1: root.textEingabePos.x, y1: root.textEingabePos.y,
                    text_inhalt: textFeld.text, schrift_relativ: 0.15,
                    schrift_fett: textFettCheck.checked, text_align: "center", text_baseline: "middle",
                    linienart: "solid"})
            textFeld.text = ""
        }
    }

    Dialog {
        id: speichernFehlerDialog
        title: qsTr("Fehler beim Speichern")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 340; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            id: speichernFehlerText
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Ok
    }

    Dialog {
        id:    loeschenConfirmDialog
        title: qsTr("Symbol löschen")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 340; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            text: qsTr("Symbol «%1» wirklich löschen?\nDieser Vorgang kann nicht rückgängig gemacht werden.").arg(root.loeschenSymbolName)
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: {
            if (root.editSymbolId === root.loeschenSymbolId || root.aktiveListenId === root.loeschenSymbolId) {
                root.editSymbolId   = ""
                root.vorlageId      = ""
                root.aktiveListenId = ""
                root.ladeDaten()
            }
            symbolDefinitionModel.symbolLoeschen(root.loeschenSymbolId)
            root.symbollisteAktualisieren()
            root.loeschenSymbolId   = ""
            root.loeschenSymbolName = ""
        }
    }

    TextEdit { id: klipboardHelper; visible: false; width: 0; height: 0 }

    // ── Hauptlayout ────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Symbolliste (links) ──────────────────────────────────
        SeSymbolListe {
            id:                symbolListePanel
            editor:            root
            Layout.fillHeight: true
            onLoeschenAngefordert: function(sid, sname) {
                root.loeschenSymbolId   = sid
                root.loeschenSymbolName = sname
                loeschenConfirmDialog.open()
            }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.border }

        // ── Editor (rechts) ─────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            // ── Header-Leiste ────────────────────────────────────────
            SeEditorHeader {
                editor: root
                Layout.fillWidth: true
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // ── Mitte + Pins: vertikal ziehbar ───────────────────────
            SplitView {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                orientation: Qt.Vertical
                handle: Rectangle {
                    implicitHeight: 5
                    color: SplitHandle.pressed ? root.theme.accent
                         : SplitHandle.hovered  ? root.theme.activeItem : root.theme.border
                }

            // ── Mitte: Toolbar | Zeichenfläche | Eigenschaften ────────
            RowLayout {
                SplitView.fillHeight: true
                SplitView.minimumHeight: 120
                spacing: 0


                // ── Werkzeug-Toolbar ─────────────────────────────────
                SeWerkzeugToolbar {
                    editor: root
                    Layout.fillHeight: true
                }

                // ── Zeichenfläche ─────────────────────────────────────
                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    clip: true

                    // Hintergrund
                    Rectangle { anchors.fill: parent; color: root.theme.surfaceDeep }

                    Canvas {
                        id: zeichneCanvas
                        anchors.fill: parent
                        renderStrategy: Canvas.Threaded

                        // Rechteckiger Zeichenbereich – Seitenverhältnis = breiteMm : hoeheMm
                        readonly property real padding:  36
                        readonly property real baseSize: Math.min(width - 2*padding, height - 2*padding)
                        readonly property real drawW:    baseSize * root._seZoom * root.breiteMm / Math.max(root.breiteMm, root.hoeheMm)
                        readonly property real drawH:    baseSize * root._seZoom * root.hoeheMm  / Math.max(root.breiteMm, root.hoeheMm)
                        readonly property real drawX:    (width  - drawW) / 2 + root._sePanX
                        readonly property real drawY:    (height - drawH) / 2 + root._sePanY

                        function n2sx(n) { return drawX + n * drawW }
                        function n2sy(n) { return drawY + n * drawH }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var dw = drawW, dh = drawH, dx = drawX, dy = drawY

                            // ── Hintergrund der Zeichenfläche ──────────
                            ctx.fillStyle = "#fdf8e8"
                            ctx.fillRect(dx, dy, dw, dh)

                            // ── Punkt-Raster (0.5-mm-Schritte) ───────────────────
                            var stepsX = root.breiteMm * 2   // 0.5mm pro Schritt
                            var stepsY = root.hoeheMm  * 2
                            ctx.fillStyle = "#2a3a5a"
                            for (var gi = 0; gi <= stepsX; gi++) {
                                for (var gj = 0; gj <= stepsY; gj++) {
                                    ctx.beginPath()
                                    ctx.arc(dx + gi/stepsX*dw, dy + gj/stepsY*dh, 1.5, 0, 2*Math.PI)
                                    ctx.fill()
                                }
                            }
                            // 4-mm-Rasterpunkte größer hervorheben
                            var grid4X = Math.round(root.breiteMm / 4)
                            var grid4Y = Math.round(root.hoeheMm  / 4)
                            ctx.fillStyle = "#5577aa"
                            for (var gx4 = 0; gx4 <= grid4X; gx4++) {
                                for (var gy4 = 0; gy4 <= grid4Y; gy4++) {
                                    ctx.beginPath()
                                    ctx.arc(dx + gx4/grid4X*dw, dy + gy4/grid4Y*dh, 3.0, 0, 2*Math.PI)
                                    ctx.fill()
                                }
                            }

                            // ── mm-Lineal (oben und links) ────────────
                            var pxPerMmX = dw / root.breiteMm
                            var pxPerMmY = dh / root.hoeheMm
                            ctx.save()
                            ctx.lineWidth = 0.7
                            // X-Lineal oben
                            for (var mx = 0; mx <= root.breiteMm; mx++) {
                                var isLabeledX = (mx % 4 === 0)
                                var tickLenX   = isLabeledX ? 8 : 4
                                var xtx = dx + mx * pxPerMmX
                                ctx.strokeStyle = "#6688aa"
                                ctx.beginPath(); ctx.moveTo(xtx, dy - tickLenX); ctx.lineTo(xtx, dy); ctx.stroke()
                                if (isLabeledX) {
                                    ctx.fillStyle = "#6688aa"; ctx.font = "9px sans-serif"
                                    ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                                    ctx.fillText(mx, xtx, dy - tickLenX - 1)
                                }
                            }
                            // Y-Lineal links
                            for (var my = 0; my <= root.hoeheMm; my++) {
                                var isLabeledY = (my % 4 === 0)
                                var tickLenY   = isLabeledY ? 8 : 4
                                var yty = dy + my * pxPerMmY
                                ctx.strokeStyle = "#6688aa"
                                ctx.beginPath(); ctx.moveTo(dx - tickLenY, yty); ctx.lineTo(dx, yty); ctx.stroke()
                                if (isLabeledY) {
                                    ctx.fillStyle = "#6688aa"; ctx.font = "9px sans-serif"
                                    ctx.textAlign = "right"; ctx.textBaseline = "middle"
                                    ctx.fillText(my, dx - tickLenY - 3, yty)
                                }
                            }
                            // Einheit "mm" an der Ecke
                            ctx.fillStyle = "#445566"; ctx.font = "8px sans-serif"
                            ctx.textAlign = "right"; ctx.textBaseline = "bottom"
                            ctx.fillText("mm", dx - 2, dy - 2)
                            ctx.restore()

                            // ── Rand der Zeichenfläche ─────────────────
                            ctx.strokeStyle = "#3a4a6a"
                            ctx.lineWidth   = 1
                            ctx.setLineDash([4, 4])
                            ctx.strokeRect(dx + 0.5, dy + 0.5, dw - 1, dh - 1)
                            ctx.setLineDash([])

                            // ── Primitive ─────────────────────────────
                            ctx.lineCap  = "round"
                            ctx.lineJoin = "round"

                            for (var pi = 0; pi < root.primitive.length; pi++) {
                                var p = root.primitive[pi]
                                var isSel = (pi === root.ausgewaehltPrimIdx)
                                ctx.strokeStyle = isSel ? "#00e5a0" : "#0b5394"
                                ctx.lineWidth   = isSel ? 3.0 : 2.0

                                var la = p.linienart || "durchgehend"
                                if      (la === "gestrichelt")    ctx.setLineDash([8, 4])
                                else if (la === "gepunktet")     ctx.setLineDash([2, 4])
                                else if (la === "Strich-Punkt") ctx.setLineDash([8, 4, 2, 4])
                                else                       ctx.setLineDash([])

                                zeichneCanvas.zeichnePrimitiv(ctx, p, dx, dy, dw, dh)
                                ctx.setLineDash([])

                                // Griffe + Koordinaten-Label bei Auswahl (Nutzerwunsch:
                                // X1/Y1/X2/Y2 direkt am Primitiv statt nur im Eigenschaften-Panel)
                                if (isSel) {
                                    ctx.strokeStyle = "#00e5a0"
                                    zeichneCanvas.zeichneGriff(ctx, n2sx(p.x1 || 0), n2sy(p.y1 || 0))
                                    zeichneCanvas.zeichneKoordLabel(ctx, n2sx(p.x1 || 0), n2sy(p.y1 || 0),
                                        "X1", "Y1", root.normToMmX(p.x1 || 0), root.normToMmY(p.y1 || 0))
                                    if (p.typ === "linie" || p.typ === "rechteck" || p.typ === "rechteck_gefuellt") {
                                        zeichneCanvas.zeichneGriff(ctx, n2sx(p.x2 || 0), n2sy(p.y2 || 0))
                                        zeichneCanvas.zeichneKoordLabel(ctx, n2sx(p.x2 || 0), n2sy(p.y2 || 0),
                                            "X2", "Y2", root.normToMmX(p.x2 || 0), root.normToMmY(p.y2 || 0))
                                    }
                                }
                            }

                            // ── Vorschau-Linie (aktuelles Werkzeug) ───
                            if (root.mausImCanvas && root.werkzeugPunkte.length > 0) {
                                ctx.strokeStyle = "#ffcc00"
                                ctx.lineWidth   = 1.5
                                ctx.setLineDash([4, 4])
                                var pts = root.werkzeugPunkte
                                var mx  = root.mausNormPos.x, my = root.mausNormPos.y

                                if (root.aktivesWerkzeug === "linie") {
                                    ctx.beginPath()
                                    ctx.moveTo(n2sx(pts[0].x), n2sy(pts[0].y))
                                    ctx.lineTo(n2sx(mx), n2sy(my))
                                    ctx.stroke()
                                } else if (root.aktivesWerkzeug === "rechteck") {
                                    ctx.strokeRect(n2sx(pts[0].x), n2sy(pts[0].y), (mx-pts[0].x)*dw, (my-pts[0].y)*dh)
                                } else if (root.aktivesWerkzeug === "kreis_offen") {
                                    var kd = Math.sqrt(Math.pow((mx-pts[0].x)*dw, 2) + Math.pow((my-pts[0].y)*dh, 2))
                                    ctx.beginPath()
                                    ctx.arc(n2sx(pts[0].x), n2sy(pts[0].y), kd, 0, 2*Math.PI)
                                    ctx.stroke()
                                } else if (root.aktivesWerkzeug === "bogen") {
                                    if (pts.length === 1) {
                                        ctx.beginPath()
                                        ctx.moveTo(n2sx(pts[0].x), n2sy(pts[0].y))
                                        ctx.lineTo(n2sx(mx), n2sy(my))
                                        ctx.stroke()
                                    } else if (pts.length === 2) {
                                        var bRad = Math.sqrt(Math.pow((pts[1].x-pts[0].x)*dw, 2) + Math.pow((pts[1].y-pts[0].y)*dh, 2))
                                        var bW1  = Math.atan2((pts[1].y-pts[0].y)*dh, (pts[1].x-pts[0].x)*dw)
                                        var bW2  = Math.atan2((my-pts[0].y)*dh, (mx-pts[0].x)*dw)
                                        ctx.beginPath()
                                        ctx.arc(n2sx(pts[0].x), n2sy(pts[0].y), bRad, bW1, bW2, false)
                                        ctx.stroke()
                                    }
                                }
                                ctx.setLineDash([])
                            }

                            // ── Pins ──────────────────────────────────
                            for (var pii = 0; pii < root.pins.length; pii++) {
                                var pin = root.pins[pii]
                                var isSelP = (pii === root.ausgewaehltPinIdx)
                                ctx.beginPath()
                                ctx.arc(n2sx(pin.x), n2sy(pin.y), isSelP ? 6 : 4, 0, 2*Math.PI)
                                ctx.fillStyle   = isSelP ? "#ff8800" : "#4a9eff"
                                ctx.strokeStyle = isSelP ? "#7f4400" : "#0a2040"
                                ctx.lineWidth   = 1; ctx.fill(); ctx.stroke()
                                // Pin-Bezeichnung
                                ctx.save()
                                ctx.fillStyle = isSelP ? "#ff8800" : "#7aaddd"
                                ctx.font = "10px sans-serif"
                                ctx.textAlign = "left"; ctx.textBaseline = "bottom"
                                ctx.fillText(pin.name || "", n2sx(pin.x)+8, n2sy(pin.y)-1)
                                ctx.restore()
                                // Richtungspfeil (offen-Vektor)
                                ctx.strokeStyle = isSelP ? "#ff8800" : "#4a9eff"
                                ctx.lineWidth   = 1.5
                                ctx.beginPath()
                                ctx.moveTo(n2sx(pin.x), n2sy(pin.y))
                                ctx.lineTo(n2sx(pin.x) + (pin.offenX||0)*12, n2sy(pin.y) + (pin.offenY||0)*12)
                                ctx.stroke()
                            }

                            // ── Fadenkreuz ────────────────────────────
                            if (root.mausImCanvas && root.aktivesWerkzeug !== "auswahl") {
                                var scx2 = n2sx(root.mausNormPos.x), scy2 = n2sy(root.mausNormPos.y)
                                ctx.strokeStyle = "#ffcc0066"; ctx.lineWidth = 1
                                ctx.setLineDash([2, 2])
                                ctx.beginPath(); ctx.moveTo(dx, scy2); ctx.lineTo(dx+ds, scy2); ctx.stroke()
                                ctx.beginPath(); ctx.moveTo(scx2, dy); ctx.lineTo(scx2, dy+ds); ctx.stroke()
                                ctx.setLineDash([])
                                ctx.beginPath()
                                ctx.arc(scx2, scy2, 4, 0, 2*Math.PI)
                                ctx.strokeStyle = "#ffcc00"; ctx.lineWidth = 1.5; ctx.stroke()
                            }
                        }

                        function zeichneGriff(ctx, px, py) {
                            ctx.save()
                            ctx.fillStyle = "#00e5a0"; ctx.strokeStyle = "#004d35"; ctx.lineWidth = 1.5
                            ctx.beginPath(); ctx.arc(px, py, 5, 0, 2*Math.PI); ctx.fill(); ctx.stroke()
                            ctx.restore()
                        }

                        // Koordinaten-Label neben einem Griff (mm, aus Normkoordinaten
                        // umgerechnet) — Nutzerwunsch: Orientierung direkt am Primitiv.
                        function zeichneKoordLabel(ctx, px, py, labelX, labelY, mmX, mmY) {
                            ctx.save()
                            ctx.font = "10px sans-serif"
                            ctx.textAlign    = "left"
                            ctx.textBaseline = "top"
                            var text = labelX + ": " + mmX.toFixed(2) + "mm   " + labelY + ": " + mmY.toFixed(2) + "mm"
                            var boxX = px + 8, boxY = py + 8
                            var tw   = ctx.measureText(text).width
                            ctx.fillStyle = "rgba(10, 20, 15, 0.78)"
                            ctx.fillRect(boxX - 3, boxY - 2, tw + 6, 15)
                            ctx.fillStyle = "#00e5a0"
                            ctx.fillText(text, boxX, boxY)
                            ctx.restore()
                        }

                        function zeichnePrimitiv(ctx, p, dx, dy, dw, dh) {
                            switch (p.typ) {
                            case "linie":
                                ctx.beginPath()
                                ctx.moveTo(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
                                ctx.lineTo(dx+(p.x2||0)*dw, dy+(p.y2||0)*dh)
                                ctx.stroke()
                                break
                            case "rechteck":
                                ctx.strokeRect(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh,
                                               ((p.x2||0)-(p.x1||0))*dw, ((p.y2||0)-(p.y1||0))*dh)
                                break
                            case "rechteck_gefuellt":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.fillRect(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh,
                                             ((p.x2||0)-(p.x1||0))*dw, ((p.y2||0)-(p.y1||0))*dh)
                                ctx.restore()
                                break
                            case "kreis_offen":
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.1)*dw, 0, 2*Math.PI)
                                ctx.stroke()
                                break
                            case "kreis_gefuellt":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.04)*dw, 0, 2*Math.PI)
                                ctx.fill(); ctx.restore()
                                break
                            case "bogen": {
                                var ra = (p.winkel_von||0) * Math.PI/180
                                var re = (p.winkel_bis||90) * Math.PI/180
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh, (p.radius||0.1)*dw,
                                        ra, re, p.bogen_gegen_uhrzeiger ? true : false)
                                ctx.stroke()
                                break
                            }
                            case "text":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.font = ((p.schrift_fett ? "bold " : "") +
                                            Math.round((p.schrift_relativ||0.15)*dw) + "px sans-serif")
                                ctx.textAlign    = p.text_align    || "center"
                                ctx.textBaseline = p.text_baseline || "middle"
                                ctx.fillText(p.text_inhalt||"?", dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
                                ctx.restore()
                                break
                            case "dreieck_gefuellt":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.beginPath()
                                ctx.moveTo(dx+(p.x1||0)*dw, dy+(p.y1||0)*dh)
                                ctx.lineTo(dx+(p.x2||0)*dw, dy+(p.y2||0)*dh)
                                ctx.lineTo(dx+((p.x3||p.x1)||0)*dw, dy+((p.y3||p.y1)||0)*dh)
                                ctx.closePath(); ctx.fill(); ctx.restore()
                                break
                            }
                        }

                        // ── Maus-Interaktion ──────────────────────────
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            // Drag-Zustand (Auswahl-Werkzeug)
                            property bool dragAktiv:       false
                            property bool dragIstPin:      false
                            property bool dragBewegteSich: false
                            property var  dragStartNorm:   ({x: 0, y: 0})
                            property var  dragObjStart:    null

                            // Pan-Zustand (mittlere Maustaste)
                            property bool _panAktiv:  false
                            property var  _panStart:  ({x: 0, y: 0})
                            property real _panStartX: 0
                            property real _panStartY: 0

                            function mausZuNorm(mx, my) {
                                var nx = (mx - zeichneCanvas.drawX) / zeichneCanvas.drawW
                                var ny = (my - zeichneCanvas.drawY) / zeichneCanvas.drawH
                                nx = Math.max(0, Math.min(1, root.snapX(nx)))
                                ny = Math.max(0, Math.min(1, root.snapY(ny)))
                                return {x: nx, y: ny}
                            }

                            onPressed: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) {
                                    _panAktiv  = true
                                    _panStart  = {x: mouse.x, y: mouse.y}
                                    _panStartX = root._sePanX
                                    _panStartY = root._sePanY
                                    return
                                }
                                if (root.aktivesWerkzeug !== "auswahl") return
                                var nm = mausZuNorm(mouse.x, mouse.y)
                                var pi = root.treffePin(nm.x, nm.y)
                                if (pi >= 0) {
                                    root.ausgewaehltPinIdx  = pi
                                    root.ausgewaehltPrimIdx = -1
                                    dragAktiv     = true
                                    dragIstPin    = true
                                    dragStartNorm = {x: nm.x, y: nm.y}
                                    dragObjStart  = {x: root.pins[pi].x, y: root.pins[pi].y}
                                    zeichneCanvas.requestPaint()
                                    return
                                }
                                var priIdx = root.treffePrimitiv(nm.x, nm.y)
                                if (priIdx >= 0) {
                                    root.ausgewaehltPrimIdx = priIdx
                                    root.ausgewaehltPinIdx  = -1
                                    dragAktiv     = true
                                    dragIstPin    = false
                                    dragStartNorm = {x: nm.x, y: nm.y}
                                    dragObjStart  = Object.assign({}, root.primitive[priIdx])
                                    zeichneCanvas.requestPaint()
                                }
                            }

                            onReleased: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) {
                                    _panAktiv = false
                                    return
                                }
                                dragAktiv    = false
                                dragObjStart = null
                            }

                            onPositionChanged: function(mouse) {
                                if (_panAktiv) {
                                    root._sePanX = _panStartX + (mouse.x - _panStart.x)
                                    root._sePanY = _panStartY + (mouse.y - _panStart.y)
                                    zeichneCanvas.requestPaint()
                                    return
                                }
                                var nm = mausZuNorm(mouse.x, mouse.y)
                                root.mausNormPos  = nm
                                root.mausImCanvas = true

                                if (dragAktiv && dragObjStart !== null) {
                                    var ddx = nm.x - dragStartNorm.x
                                    var ddy = nm.y - dragStartNorm.y
                                    if (dragIstPin && root.ausgewaehltPinIdx >= 0) {
                                        var arrP = root.pins.slice()
                                        var pp   = Object.assign({}, arrP[root.ausgewaehltPinIdx])
                                        pp.x = Math.max(0, Math.min(1, root.snapX(dragObjStart.x + ddx)))
                                        pp.y = Math.max(0, Math.min(1, root.snapY(dragObjStart.y + ddy)))
                                        arrP[root.ausgewaehltPinIdx] = pp
                                        root.pins = arrP
                                        dragBewegteSich = true
                                    } else if (!dragIstPin && root.ausgewaehltPrimIdx >= 0) {
                                        var idx = root.ausgewaehltPrimIdx
                                        var arr = root.primitive.slice()
                                        var p   = Object.assign({}, arr[idx])
                                        var o   = dragObjStart
                                        p.x1 = Math.max(0, Math.min(1, root.snapX((o.x1 || 0) + ddx)))
                                        p.y1 = Math.max(0, Math.min(1, root.snapY((o.y1 || 0) + ddy)))
                                        if (p.typ === "linie" || p.typ === "rechteck" || p.typ === "rechteck_gefuellt") {
                                            p.x2 = Math.max(0, Math.min(1, root.snapX((o.x2 || 0) + ddx)))
                                            p.y2 = Math.max(0, Math.min(1, root.snapY((o.y2 || 0) + ddy)))
                                        }
                                        if (p.typ === "dreieck_gefuellt") {
                                            p.x2 = Math.max(0, Math.min(1, root.snapX((o.x2 || 0) + ddx)))
                                            p.y2 = Math.max(0, Math.min(1, root.snapY((o.y2 || 0) + ddy)))
                                            p.x3 = Math.max(0, Math.min(1, root.snapX((o.x3 || 0) + ddx)))
                                            p.y3 = Math.max(0, Math.min(1, root.snapY((o.y3 || 0) + ddy)))
                                        }
                                        arr[idx] = p
                                        root.primitive = arr
                                        dragBewegteSich = true
                                    }
                                }

                                zeichneCanvas.requestPaint()
                            }

                            onExited: {
                                root.mausImCanvas = false
                                zeichneCanvas.requestPaint()
                            }

                            onClicked: function(mouse) {
                                if (mouse.button === Qt.MiddleButton) return
                                if (dragBewegteSich) { dragBewegteSich = false; return }
                                root.forceActiveFocus()
                                var nm = mausZuNorm(mouse.x, mouse.y)
                                var nx = nm.x, ny = nm.y

                                if (mouse.button === Qt.RightButton) {
                                    root.werkzeugPunkte = []
                                    zeichneCanvas.requestPaint()
                                    return
                                }

                                switch (root.aktivesWerkzeug) {
                                case "auswahl":
                                    var pi2 = root.treffePin(nx, ny)
                                    if (pi2 >= 0) {
                                        root.ausgewaehltPinIdx  = pi2
                                        root.ausgewaehltPrimIdx = -1
                                    } else {
                                        root.ausgewaehltPrimIdx = root.treffePrimitiv(nx, ny)
                                        root.ausgewaehltPinIdx  = -1
                                    }
                                    zeichneCanvas.requestPaint()
                                    break

                                case "linie":
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else {
                                        root.addPrimitiv({typ:"linie",x1:root.werkzeugPunkte[0].x,y1:root.werkzeugPunkte[0].y,x2:nx,y2:ny,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break

                                case "rechteck":
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else {
                                        var rx1=Math.min(root.werkzeugPunkte[0].x,nx), ry1=Math.min(root.werkzeugPunkte[0].y,ny)
                                        var rx2=Math.max(root.werkzeugPunkte[0].x,nx), ry2=Math.max(root.werkzeugPunkte[0].y,ny)
                                        root.addPrimitiv({typ:(root.aktGefuellt?"rechteck_gefuellt":"rechteck"),x1:rx1,y1:ry1,x2:rx2,y2:ry2,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break

                                case "kreis_offen": {
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else {
                                        var kdw = zeichneCanvas.drawW, kdh = zeichneCanvas.drawH
                                        var krad = Math.sqrt(Math.pow((nx-root.werkzeugPunkte[0].x)*kdw, 2) + Math.pow((ny-root.werkzeugPunkte[0].y)*kdh, 2)) / kdw
                                        root.addPrimitiv({typ:(root.aktGefuellt?"kreis_gefuellt":"kreis_offen"),x1:root.werkzeugPunkte[0].x,y1:root.werkzeugPunkte[0].y,radius:krad,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break
                                }

                                case "bogen":
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else if (root.werkzeugPunkte.length === 1) {
                                        root.werkzeugPunkte = root.werkzeugPunkte.concat([{x:nx,y:ny}])
                                    } else {
                                        var bdw = zeichneCanvas.drawW, bdh = zeichneCanvas.drawH
                                        var bcx = root.werkzeugPunkte[0].x, bcy = root.werkzeugPunkte[0].y
                                        var bRad2 = Math.sqrt(Math.pow((root.werkzeugPunkte[1].x-bcx)*bdw, 2) + Math.pow((root.werkzeugPunkte[1].y-bcy)*bdh, 2)) / bdw
                                        var bWv = Math.atan2((root.werkzeugPunkte[1].y-bcy)*bdh,(root.werkzeugPunkte[1].x-bcx)*bdw)*180/Math.PI
                                        var bWb = Math.atan2((ny-bcy)*bdh,(nx-bcx)*bdw)*180/Math.PI
                                        if (bWv < 0) bWv += 360; if (bWb < 0) bWb += 360
                                        root.addPrimitiv({typ:"bogen",x1:bcx,y1:bcy,radius:bRad2,winkel_von:bWv,winkel_bis:bWb,bogen_gegen_uhrzeiger:false,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break

                                case "punkt":
                                    root.addPrimitiv({typ:"kreis_gefuellt",x1:nx,y1:ny,radius:0.04,linienart:"solid"})
                                    break

                                case "text":
                                    root.textEingabePos = {x:nx,y:ny}
                                    textEingabeDialog.open()
                                    break

                                case "pin":
                                    root.addPin(nx, ny)
                                    break
                                }
                            }
                        }
                    } // Canvas

                    // Scroll-Zoom (Mausrad zoomt auf Cursor-Position)
                    WheelHandler {
                        onWheel: function(event) {
                            var dy = event.angleDelta.y !== 0 ? event.angleDelta.y
                                                              : event.pixelDelta.y * 4
                            if (Math.abs(dy) < 1) { event.accepted = false; return }
                            var factor   = Math.pow(1.001, dy)
                            var newZoom  = Math.max(0.15, Math.min(8.0, root._seZoom * factor))
                            var scale    = newZoom / root._seZoom
                            var newDrawW = zeichneCanvas.drawW * scale
                            var newDrawH = zeichneCanvas.drawH * scale
                            var newDrawX = event.x - (event.x - zeichneCanvas.drawX) * scale
                            var newDrawY = event.y - (event.y - zeichneCanvas.drawY) * scale
                            root._sePanX = newDrawX - (zeichneCanvas.width  - newDrawW) / 2
                            root._sePanY = newDrawY - (zeichneCanvas.height - newDrawH) / 2
                            root._seZoom = newZoom
                            zeichneCanvas.requestPaint()
                            event.accepted = true
                        }
                    }

                    // Zoom-Steuerung (oben rechts, analog zu CanvasHeaderBar)
                    Row {
                        anchors { top: parent.top; right: parent.right; topMargin: 4; rightMargin: 6 }
                        spacing: 0

                        Button {
                            text: qsTr("−"); flat: true; implicitWidth: 26; implicitHeight: 26
                            contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 18
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4 }
                            onClicked: {
                                var s = Math.max(0.15, root._seZoom / 1.25) / root._seZoom
                                root._sePanX = root._sePanX * s; root._sePanY = root._sePanY * s
                                root._seZoom = Math.max(0.15, root._seZoom / 1.25)
                                zeichneCanvas.requestPaint()
                            }
                        }
                        Text {
                            text: Math.round(root._seZoom * 100) + "%"
                            color: root.theme.accent; font.pixelSize: 12; font.weight: Font.Medium
                            leftPadding: 2; rightPadding: 2
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root._seZoom = 1.0; root._sePanX = 0.0; root._sePanY = 0.0
                                    zeichneCanvas.requestPaint()
                                }
                            }
                        }
                        Button {
                            text: "+"; flat: true; implicitWidth: 26; implicitHeight: 26
                            contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4 }
                            onClicked: {
                                var s = Math.min(8.0, root._seZoom * 1.25) / root._seZoom
                                root._sePanX = root._sePanX * s; root._sePanY = root._sePanY * s
                                root._seZoom = Math.min(8.0, root._seZoom * 1.25)
                                zeichneCanvas.requestPaint()
                            }
                        }
                    }

                    // Koordinaten-Anzeige
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                        color: "#80000018"; radius: 3
                        width: koordinatenLbl.implicitWidth + 22; height: 30
                        Text {
                            id: koordinatenLbl
                            anchors.centerIn: parent
                            text: root.mausImCanvas
                                  ? "x: " + root.normToMmX(root.mausNormPos.x).toFixed(1) + " mm   y: " + root.normToMmY(root.mausNormPos.y).toFixed(1) + " mm"
                                  : ""
                            font.pixelSize: 13; color: "#aabbcc"
                        }
                    }

                    // Werkzeug-Status
                    Rectangle {
                        anchors { bottom: parent.bottom; right: parent.right; margins: 6 }
                        color: "#80000018"; radius: 3
                        width: werkzeugStatusLbl.implicitWidth + 12; height: 20
                        visible: root.werkzeugPunkte.length > 0
                        Text {
                            id: werkzeugStatusLbl
                            anchors.centerIn: parent
                            text: {
                                switch (root.aktivesWerkzeug) {
                                case "linie":
                                case "rechteck":
                                case "kreis_offen": return qsTr("Endpunkt klicken")
                                case "bogen":
                                    if (root.werkzeugPunkte.length === 1) return qsTr("Startwinkel klicken")
                                    return qsTr("Endwinkel klicken")
                                default: return ""
                                }
                            }
                            font.pixelSize: 11; color: "#ffcc66"
                        }
                    }
                } // Zeichenfläche

                Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.sidebar }


                // ── Eigenschaften-Panel ───────────────────────────────
                SeEigenschaftenPanel {
                    editor: root
                    Layout.fillHeight: true
                }
            } // inner RowLayout

            // ── Pin-Liste ──────────────────────────────────────────────
            SePinListe {
                editor: root
                SplitView.preferredHeight: 190
                SplitView.minimumHeight:   80
            }
            } // SplitView
        } // ColumnLayout
    } // outer RowLayout

    DebugLabel { panelName: qsTr("Symbol-Editor"); visible: root.debug }
}
