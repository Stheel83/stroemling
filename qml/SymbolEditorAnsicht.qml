import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

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
    property int    groesse:       1
    property string rolleText:     "durchleiter"
    property bool   istBuiltin:    false
    property string vorlageId:     ""   // wenn gesetzt: Geometrie aus diesem Symbol als Vorlage laden

    property var    primitive:          []   // array of QVariantMap
    property var    pins:               []   // array of {name, x, y, offenX, offenY, signaltyp, kontext}
    property var    undoStack:          []   // array of {typ: "primitiv"|"pin"}

    property string aktivesWerkzeug:    "auswahl"
    property int    ausgewaehltPrimIdx: -1
    property int    ausgewaehltPinIdx:  -1
    property string aktLinienart:       "solid"

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
        if (!f) return listenSymbole
        return listenSymbole.filter(function(s) {
            return s.name.toLowerCase().indexOf(f) >= 0 ||
                   (s.kategorie || "").toLowerCase().indexOf(f) >= 0
        })
    }

    readonly property real refMm: 4.0   // 1 Rasterzelle = 4 mm (feste Referenz)
    function normToMm(v) { return v * root.groesse * root.refMm }
    function mmToNorm(v) { return v / (root.groesse * root.refMm) }
    function istPositionsfeld(name) {
        return ["x1","y1","x2","y2","x3","y3","radius"].indexOf(name) >= 0
    }

    // ── Daten laden ────────────────────────────────────────────────
    Component.onCompleted: { ladeDaten(); symbollisteAktualisieren() }
    onEditSymbolIdChanged:  ladeDaten()
    onVorlageIdChanged:     ladeDaten()

    function ladeDaten() {
        undoStack          = []
        ausgewaehltPrimIdx = -1
        ausgewaehltPinIdx  = -1
        werkzeugPunkte     = []

        if (editSymbolId === "" && vorlageId !== "") {
            // Vorlage laden – Geometrie kopieren, Symbol-ID bleibt leer (wird beim Speichern neu vergeben)
            var vInfo = symbolDefinitionModel.symbolInfo(vorlageId)
            nameText      = qsTr("Kopie von ") + (vInfo.name || vorlageId)
            kategorieText = vInfo.kategorie      || ""
            groesse       = vInfo.groesse_raster || 1
            rolleText     = vInfo.rolle          || "durchleiter"
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
                    kontext:   vp.kontext   || ""
                })
            }
            primitive = vPrims.slice()
            pins      = vPins
        } else if (editSymbolId === "") {
            nameText      = qsTr("Neues Symbol")
            kategorieText = ""
            groesse       = 1
            rolleText     = "durchleiter"
            istBuiltin    = false
            primitive     = []
            pins          = []
        } else {
            var info = symbolDefinitionModel.symbolInfo(editSymbolId)
            nameText      = info.name           || editSymbolId
            kategorieText = info.kategorie       || ""
            groesse       = info.groesse_raster  || 1
            rolleText     = info.rolle           || "durchleiter"
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
                    kontext:   p.kontext   || ""
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
        lines.push("INSERT INTO symbol_definition (id, name, kategorie, groesse_raster, rolle, ist_builtin) VALUES")
        lines.push("('" + esc(symbolId) + "', '" + esc(info.name) + "', '" + esc(info.kategorie || "") + "', " +
                   (info.groesse_raster || 1) + ", '" + esc(info.rolle || "durchleiter") + "', 0);")
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

    // ── Snap-to-Grid (20 Schritte) ─────────────────────────────────
    function snap(v) {
        // 0.5-mm-Snap: groesse * 4mm / 0.5mm = groesse * 8 Schritte
        var steps = root.groesse * 8
        return Math.round(v * steps) / steps
    }

    // ── Primitiv hinzufügen ────────────────────────────────────────
    function addPrimitiv(p) {
        primitive = primitive.concat([p])
        undoStack = undoStack.concat([{typ: "primitiv"}])
        zeichneCanvas.requestPaint()
    }

    // ── Pin hinzufügen ─────────────────────────────────────────────
    function addPin(nx, ny) {
        var neu = {name: "P" + (pins.length + 1), x: nx, y: ny, offenX: -1, offenY: 0, signaltyp: "neutral", kontext: ""}
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
            builtinHinweisDialog.open()
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
            if (!symbolDefinitionModel.symbolAnlegen(sid, nameText, kategorieText, groesse, rolleText)) {
                speichernFehlerText.text = qsTr("Symbol-ID bereits vergeben. Bitte anderen Namen wählen.")
                speichernFehlerDialog.open()
                return
            }
        } else {
            symbolDefinitionModel.symbolAktualisieren(sid, nameText, kategorieText, groesse, rolleText)
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
        id:    builtinHinweisDialog
        title: qsTr("Eingebautes Symbol")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent; width: 320; padding: 16
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Text {
            text: qsTr("Eingebaute Symbole können nicht verändert werden.\nNutze «Als Vorlage kopieren» um eine eigene Kopie zu erstellen.")
            color: root.theme.textSecondary; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        standardButtons: Dialog.Ok
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
        Rectangle {
            id:               symbolListePanel
            width:            256
            Layout.fillHeight: true
            color:            root.theme.sidebar
            clip:             true

            ColumnLayout {
                anchors.fill: parent
                spacing:      0

                // Kopfzeile: Filter + Neu-Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    color:  root.theme.sidebar

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6

                        TextField {
                            id: listeFilterFeld
                            Layout.fillWidth: true
                            implicitHeight:   28
                            placeholderText:  qsTr("Filter…")
                            font.pixelSize:   12
                            background: Rectangle {
                                color: root.theme.inputBg; radius: 4; border.color: root.theme.border
                            }
                            color: root.theme.textPrimary
                            onTextChanged: root.listeFilter = text
                        }

                        Button {
                            text:          qsTr("+ Neu")
                            implicitHeight: 28; implicitWidth: 62
                            onClicked:     root.neuesSymbol()
                            background: Rectangle {
                                color: parent.hovered ? Qt.lighter(root.theme.accent) : root.theme.accent
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.text; color: "white"; font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment:   Text.AlignVCenter
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

                // Scrollbare Symbolliste
                ScrollView {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ListView {
                        id:    symbolListeView
                        model: root.gefilterteSymbole
                        clip:  true

                        section.property:  "ist_builtin"
                        section.criteria:  ViewSection.FullString
                        section.delegate: Rectangle {
                            width:  ListView.view.width
                            height: 22
                            color:  root.theme.surfaceDeep

                            Text {
                                anchors {
                                    left: parent.left; leftMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                text:  section === "true" ? qsTr("EINGEBAUT") : qsTr("EIGENE")
                                font.pixelSize:    9
                                font.weight:       Font.Medium
                                font.letterSpacing: 1.5
                                color: root.theme.textMuted
                            }
                        }

                        delegate: Rectangle {
                            id:     listItem
                            width:  ListView.view.width
                            height: 50
                            color:  root.aktiveListenId === modelData.id
                                    ? root.theme.badge
                                    : (listeItemHover.hovered ? root.theme.surfaceDeep : "transparent")
                            radius: 2

                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 8; rightMargin: 6
                                    topMargin: 5; bottomMargin: 5
                                }
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text:  modelData.ist_builtin ? "🔒" : "✏"
                                        font.pixelSize: 10
                                        color: modelData.ist_builtin ? root.theme.textMuted : root.theme.accent
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text:  modelData.name
                                        font.pixelSize: 12; font.weight: Font.Medium
                                        color: root.theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        implicitWidth:  groesseLabel.implicitWidth + 8
                                        height: 16; radius: 3
                                        color:  root.theme.surfaceDeep

                                        Text {
                                            id: groesseLabel
                                            anchors.centerIn: parent
                                            text:  (modelData.groesse_raster || 1) + "×" + (modelData.groesse_raster || 1)
                                            font.pixelSize: 9; color: root.theme.textMuted
                                        }
                                    }

                                    // ── Als Vorlage kopieren ──────────────
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        visible: listeItemHover.hovered || root.aktiveListenId === modelData.id
                                        color:   listeKopHover.hovered ? root.theme.badge : "transparent"
                                        ToolTip.visible: listeKopHover.hovered
                                        ToolTip.delay:   600
                                        ToolTip.text:    qsTr("Als Vorlage kopieren")
                                        Text {
                                            anchors.centerIn: parent; text: "⧉"
                                            font.pixelSize: 13; color: root.theme.textSecondary
                                        }
                                        HoverHandler { id: listeKopHover }
                                        TapHandler {
                                            onTapped: {
                                                var src = modelData.id
                                                root.aktiveListenId = ""
                                                root.editSymbolId   = ""
                                                root.vorlageId      = ""
                                                Qt.callLater(function() { root.vorlageId = src })
                                            }
                                        }
                                    }

                                    // ── Löschen (nur eigene) ─────────────
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        visible: !modelData.ist_builtin &&
                                                 (listeItemHover.hovered || root.aktiveListenId === modelData.id)
                                        color: listeDelHover.hovered ? "#3a1a1a" : "transparent"
                                        ToolTip.visible: listeDelHover.hovered
                                        ToolTip.delay:   600
                                        ToolTip.text:    qsTr("Symbol löschen")
                                        Text {
                                            anchors.centerIn: parent; text: "✕"
                                            font.pixelSize: 13; color: "#ff4444"
                                        }
                                        HoverHandler { id: listeDelHover }
                                        TapHandler {
                                            onTapped: {
                                                root.loeschenSymbolId   = modelData.id
                                                root.loeschenSymbolName = modelData.name
                                                loeschenConfirmDialog.open()
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text:  modelData.kategorie || ""
                                    font.pixelSize: 10; color: root.theme.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler { id: listeItemHover }
                            TapHandler {
                                onTapped: {
                                    root.aktiveListenId = modelData.id
                                    root.vorlageId      = ""
                                    root.editSymbolId   = modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.border }

        // ── Editor (rechts) ─────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            // ── Header-Leiste ────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height:           44
                color:            root.theme.sidebar

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 8

                    TextField {
                        id: nameFeld
                        text:            root.nameText
                        onEditingFinished: root.nameText = text
                        placeholderText: qsTr("Symbolname")
                        implicitWidth: 170; implicitHeight: 28
                        font.pixelSize: 13
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary
                    }

                    TextField {
                        id: katFeld
                        text:            root.kategorieText
                        onEditingFinished: root.kategorieText = text
                        placeholderText: qsTr("Kategorie")
                        implicitWidth: 130; implicitHeight: 28
                        font.pixelSize: 13
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary
                    }

                    Text { text: qsTr("Größe:"); color: root.theme.textMuted; font.pixelSize: 11 }
                    ComboBox {
                        model: ["1×1 (4 mm)", "2×2 (8 mm)", "3×3 (12 mm)", "4×4 (16 mm)"]
                        currentIndex: root.groesse - 1
                        onCurrentIndexChanged: root.groesse = currentIndex + 1
                        implicitWidth: 110; implicitHeight: 28; font.pixelSize: 12
                    }

                    Text { text: qsTr("Rolle:"); color: root.theme.textMuted; font.pixelSize: 11 }
                    ComboBox {
                        id: rolleCombo
                        model: ["durchleiter", "verbraucher", "quelle", "trenner", "variabel"]
                        currentIndex: Math.max(0, model.indexOf(root.rolleText))
                        onCurrentIndexChanged: root.rolleText = model[currentIndex]
                        implicitWidth: 115; implicitHeight: 28; font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    // Builtin-Hinweis
                    Rectangle {
                        visible: root.istBuiltin
                        radius: 4; color: "#40331a"
                        border.color: "#cc8800"; border.width: 1
                        implicitWidth: eingebautLabel.implicitWidth + 16
                        implicitHeight: 28
                        Text {
                            id: eingebautLabel
                            anchors.centerIn: parent
                            text: qsTr("⚠ Eingebaut – nur als Vorlage kopierbar")
                            color: "#ffbb44"; font.pixelSize: 11
                        }
                    }

                    Button {
                        text: qsTr("Speichern")
                        enabled: !root.istBuiltin
                        implicitHeight: 28; implicitWidth: 90
                        onClicked: root.speichern()
                        background: Rectangle { color: parent.enabled ? (parent.hovered ? Qt.lighter(root.theme.accent) : root.theme.accent) : root.theme.btnDisabled; radius: 4 }
                        contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text:    qsTr("SQL")
                        visible: editSymbolId !== ""
                        enabled: true
                        implicitHeight: 28; implicitWidth: 58
                        onClicked: {
                            var sql = root.sqlAlsText(root.editSymbolId)
                            root.kopiereInZwischenablage(sql)
                            sqlKopiertTimer.restart()
                        }
                        background: Rectangle {
                            color: parent.hovered ? root.theme.badge : "transparent"
                            radius: 4; border.color: root.theme.accent; border.width: 1
                        }
                        contentItem: Text {
                            text: sqlKopiertTimer.running ? qsTr("✓ OK") : parent.text
                            color: root.theme.accent; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment:   Text.AlignVCenter
                        }
                        Timer {
                            id: sqlKopiertTimer
                            interval: 1500
                        }
                        ToolTip.visible: hovered; ToolTip.delay: 600
                        ToolTip.text: qsTr("SQL-INSERT für dieses Symbol in Zwischenablage kopieren")
                    }
                    Button {
                        text: qsTr("Abbrechen")
                        implicitHeight: 28; implicitWidth: 90
                        flat: true
                        onClicked: root.abgebrochen()
                        background: Rectangle { color: parent.hovered ? root.theme.badge : "transparent"; radius: 4 }
                        contentItem: Text { text: parent.text; color: root.theme.textMuted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // ── Mitte: Toolbar | Zeichenfläche | Eigenschaften ────────
            RowLayout {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                spacing: 0

                // ── Werkzeug-Toolbar ─────────────────────────────────
                Rectangle {
                    width: 72
                    Layout.fillHeight: true
                    color: root.theme.sidebar

                    Column {
                        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
                        spacing: 4

                        Repeater {
                            model: [
                                {id: "auswahl",     icon: "↖", shortcut: "A", tooltip: qsTr("Auswahl (A)")},
                                {id: "linie",       icon: "╱", shortcut: "L", tooltip: qsTr("Linie (L)")},
                                {id: "rechteck",    icon: "□", shortcut: "R", tooltip: qsTr("Rechteck (R)")},
                                {id: "kreis_offen", icon: "○", shortcut: "K", tooltip: qsTr("Kreis (K)")},
                                {id: "bogen",       icon: "⌒", shortcut: "B", tooltip: qsTr("Bogen (B)")},
                                {id: "punkt",       icon: "●", shortcut: "P", tooltip: qsTr("Punkt (P)")},
                                {id: "text",        icon: "A", shortcut: "T", tooltip: qsTr("Text (T)")},
                                {id: "pin",         icon: "⊕", shortcut: "I", tooltip: qsTr("Pin (I)")},
                            ]
                            delegate: Rectangle {
                                width: 38; height: 38; radius: 6
                                color: root.aktivesWerkzeug === modelData.id
                                       ? root.theme.accent
                                       : (btnHover.containsMouse ? root.theme.badge : "transparent")
                                ToolTip.visible: btnHover.containsMouse
                                ToolTip.delay: 600
                                ToolTip.text: modelData.tooltip
                                Text {
                                    anchors.centerIn: parent
                                    text:           modelData.icon
                                    font.pixelSize: 18
                                    color: root.aktivesWerkzeug === modelData.id ? "white" : root.theme.textPrimary
                                }
                                HoverHandler { id: btnHover }
                                TapHandler {
                                    onTapped: {
                                        root.aktivesWerkzeug = modelData.id
                                        root.werkzeugPunkte  = []
                                        root.forceActiveFocus()
                                    }
                                }
                            }
                        }

                        // Trennlinie
                        Rectangle { width: 36; height: 1; color: root.theme.border; anchors.horizontalCenter: parent.horizontalCenter }

                        // Linienart-Button (für neue Primitive)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Strich:")
                            font.pixelSize: 9; color: root.theme.textMuted
                        }
                        ComboBox {
                            width: 64
                            model: ["—", "- -", "···", "-·-"]
                            currentIndex: ["durchgehend","gestrichelt","gepunktet","Strich-Punkt"].indexOf(root.aktLinienart)
                            onCurrentIndexChanged: root.aktLinienart = ["durchgehend","gestrichelt","gepunktet","Strich-Punkt"][currentIndex]
                            font.pixelSize: 10; implicitHeight: 24
                        }

                        // Undo-Hinweis
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "⌘Z"
                            font.pixelSize: 9; color: root.theme.textMuted
                            topPadding: 4
                            ToolTip.visible: undoHover.containsMouse
                            ToolTip.delay: 600
                            ToolTip.text: qsTr("Strg+Z: Letztes rückgängig")
                            HoverHandler { id: undoHover }
                        }
                    }
                }
                Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.border }

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

                        // Quadratischer Zeichenbereich zentriert im Canvas
                        readonly property real padding:  36
                        readonly property real drawSize: Math.min(width, height) - 2 * padding
                        readonly property real drawX:    (width  - drawSize) / 2
                        readonly property real drawY:    (height - drawSize) / 2

                        function n2sx(n) { return drawX + n * drawSize }
                        function n2sy(n) { return drawY + n * drawSize }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var ds = drawSize, dx = drawX, dy = drawY

                            // ── Hintergrund der Zeichenfläche ──────────
                            ctx.fillStyle = "#fdf8e8"
                            ctx.fillRect(dx, dy, ds, ds)

                            // ── Punkt-Raster (0.5-mm-Schritte) ───────────────────
                            var snapSteps = root.groesse * 8   // Schritte bei 0.5mm
                            ctx.fillStyle = "#2a3a5a"
                            for (var gi = 0; gi <= snapSteps; gi++) {
                                for (var gj = 0; gj <= snapSteps; gj++) {
                                    ctx.beginPath()
                                    ctx.arc(dx + gi/snapSteps*ds, dy + gj/snapSteps*ds, 1.5, 0, 2*Math.PI)
                                    ctx.fill()
                                }
                            }
                            // 4-mm-Rasterpunkte (Kanal auf 4mm-Grid) größer hervorheben
                            ctx.fillStyle = "#5577aa"
                            for (var gx4 = 0; gx4 <= root.groesse; gx4++) {
                                for (var gy4 = 0; gy4 <= root.groesse; gy4++) {
                                    ctx.beginPath()
                                    ctx.arc(dx + gx4/root.groesse*ds, dy + gy4/root.groesse*ds, 3.0, 0, 2*Math.PI)
                                    ctx.fill()
                                }
                            }

                            // ── mm-Lineal (oben und links) ────────────
                            var totalMm  = root.groesse * 4.0
                            var pxPerMm  = ds / totalMm
                            var labelEvery = (totalMm <= 6) ? 1 : 2
                            ctx.save()
                            ctx.lineWidth = 0.7
                            for (var mi = 0; mi <= Math.round(totalMm); mi++) {
                                var isLabeled = (mi % labelEvery === 0)
                                var tickLen   = isLabeled ? 8 : 4
                                // X-Lineal oben
                                var xtx = dx + mi * pxPerMm
                                ctx.strokeStyle = "#6688aa"
                                ctx.beginPath(); ctx.moveTo(xtx, dy - tickLen); ctx.lineTo(xtx, dy); ctx.stroke()
                                if (isLabeled) {
                                    ctx.fillStyle = "#6688aa"; ctx.font = "9px sans-serif"
                                    ctx.textAlign = "center"; ctx.textBaseline = "bottom"
                                    ctx.fillText(mi, xtx, dy - tickLen - 1)
                                }
                                // Y-Lineal links
                                var yty = dy + mi * pxPerMm
                                ctx.beginPath(); ctx.moveTo(dx - tickLen, yty); ctx.lineTo(dx, yty); ctx.stroke()
                                if (isLabeled) {
                                    ctx.fillStyle = "#6688aa"; ctx.font = "9px sans-serif"
                                    ctx.textAlign = "right"; ctx.textBaseline = "middle"
                                    ctx.fillText(mi, dx - tickLen - 3, yty)
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
                            ctx.strokeRect(dx + 0.5, dy + 0.5, ds - 1, ds - 1)
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

                                zeichneCanvas.zeichnePrimitiv(ctx, p, dx, dy, ds)
                                ctx.setLineDash([])

                                // Griffe bei Auswahl
                                if (isSel) {
                                    ctx.strokeStyle = "#00e5a0"
                                    zeichneCanvas.zeichneGriff(ctx, n2sx(p.x1 || 0), n2sy(p.y1 || 0))
                                    if (p.typ === "linie" || p.typ === "rechteck")
                                        zeichneCanvas.zeichneGriff(ctx, n2sx(p.x2 || 0), n2sy(p.y2 || 0))
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
                                    ctx.strokeRect(n2sx(pts[0].x), n2sy(pts[0].y), (mx-pts[0].x)*ds, (my-pts[0].y)*ds)
                                } else if (root.aktivesWerkzeug === "kreis_offen") {
                                    var kd = Math.sqrt(((mx-pts[0].x)*ds)*((mx-pts[0].x)*ds)+((my-pts[0].y)*ds)*((my-pts[0].y)*ds))
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
                                        var bRad = Math.sqrt(((pts[1].x-pts[0].x)*ds)*((pts[1].x-pts[0].x)*ds)+((pts[1].y-pts[0].y)*ds)*((pts[1].y-pts[0].y)*ds))
                                        var bW1  = Math.atan2((pts[1].y-pts[0].y)*ds, (pts[1].x-pts[0].x)*ds)
                                        var bW2  = Math.atan2((my-pts[0].y)*ds, (mx-pts[0].x)*ds)
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

                        function zeichnePrimitiv(ctx, p, dx, dy, ds) {
                            switch (p.typ) {
                            case "linie":
                                ctx.beginPath()
                                ctx.moveTo(dx+(p.x1||0)*ds, dy+(p.y1||0)*ds)
                                ctx.lineTo(dx+(p.x2||0)*ds, dy+(p.y2||0)*ds)
                                ctx.stroke()
                                break
                            case "rechteck":
                                ctx.strokeRect(dx+(p.x1||0)*ds, dy+(p.y1||0)*ds,
                                               ((p.x2||0)-(p.x1||0))*ds, ((p.y2||0)-(p.y1||0))*ds)
                                break
                            case "kreis_offen":
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*ds, dy+(p.y1||0)*ds, (p.radius||0.1)*ds, 0, 2*Math.PI)
                                ctx.stroke()
                                break
                            case "kreis_gefuellt":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*ds, dy+(p.y1||0)*ds, (p.radius||0.04)*ds, 0, 2*Math.PI)
                                ctx.fill(); ctx.restore()
                                break
                            case "bogen": {
                                var ra = (p.winkel_von||0) * Math.PI/180
                                var re = (p.winkel_bis||90) * Math.PI/180
                                ctx.beginPath()
                                ctx.arc(dx+(p.x1||0)*ds, dy+(p.y1||0)*ds, (p.radius||0.1)*ds,
                                        ra, re, p.bogen_gegen_uhrzeiger ? true : false)
                                ctx.stroke()
                                break
                            }
                            case "text":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.font = ((p.schrift_fett ? "bold " : "") +
                                            Math.round((p.schrift_relativ||0.15)*ds) + "px sans-serif")
                                ctx.textAlign    = p.text_align    || "center"
                                ctx.textBaseline = p.text_baseline || "middle"
                                ctx.fillText(p.text_inhalt||"?", dx+(p.x1||0)*ds, dy+(p.y1||0)*ds)
                                ctx.restore()
                                break
                            case "dreieck_gefuellt":
                                ctx.save()
                                ctx.fillStyle = ctx.strokeStyle
                                ctx.beginPath()
                                ctx.moveTo(dx+(p.x1||0)*ds, dy+(p.y1||0)*ds)
                                ctx.lineTo(dx+(p.x2||0)*ds, dy+(p.y2||0)*ds)
                                ctx.lineTo(dx+((p.x3||p.x1)||0)*ds, dy+((p.y3||p.y1)||0)*ds)
                                ctx.closePath(); ctx.fill(); ctx.restore()
                                break
                            }
                        }

                        // ── Maus-Interaktion ──────────────────────────
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            // Drag-Zustand (Auswahl-Werkzeug)
                            property bool dragAktiv:       false
                            property bool dragIstPin:      false
                            property bool dragBewegteSich: false
                            property var  dragStartNorm:   ({x: 0, y: 0})
                            property var  dragObjStart:    null

                            function mausZuNorm(mx, my) {
                                var nx = (mx - zeichneCanvas.drawX) / zeichneCanvas.drawSize
                                var ny = (my - zeichneCanvas.drawY) / zeichneCanvas.drawSize
                                nx = Math.max(0, Math.min(1, root.snap(nx)))
                                ny = Math.max(0, Math.min(1, root.snap(ny)))
                                return {x: nx, y: ny}
                            }

                            onPressed: function(mouse) {
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

                            onReleased: {
                                dragAktiv    = false
                                dragObjStart = null
                            }

                            onPositionChanged: function(mouse) {
                                var nm = mausZuNorm(mouse.x, mouse.y)
                                root.mausNormPos  = nm
                                root.mausImCanvas = true

                                if (dragAktiv && dragObjStart !== null) {
                                    var ddx = nm.x - dragStartNorm.x
                                    var ddy = nm.y - dragStartNorm.y
                                    if (dragIstPin && root.ausgewaehltPinIdx >= 0) {
                                        var arrP = root.pins.slice()
                                        var pp   = Object.assign({}, arrP[root.ausgewaehltPinIdx])
                                        pp.x = Math.max(0, Math.min(1, root.snap(dragObjStart.x + ddx)))
                                        pp.y = Math.max(0, Math.min(1, root.snap(dragObjStart.y + ddy)))
                                        arrP[root.ausgewaehltPinIdx] = pp
                                        root.pins = arrP
                                        dragBewegteSich = true
                                    } else if (!dragIstPin && root.ausgewaehltPrimIdx >= 0) {
                                        var idx = root.ausgewaehltPrimIdx
                                        var arr = root.primitive.slice()
                                        var p   = Object.assign({}, arr[idx])
                                        var o   = dragObjStart
                                        p.x1 = Math.max(0, Math.min(1, root.snap((o.x1 || 0) + ddx)))
                                        p.y1 = Math.max(0, Math.min(1, root.snap((o.y1 || 0) + ddy)))
                                        if (p.typ === "linie" || p.typ === "rechteck") {
                                            p.x2 = Math.max(0, Math.min(1, root.snap((o.x2 || 0) + ddx)))
                                            p.y2 = Math.max(0, Math.min(1, root.snap((o.y2 || 0) + ddy)))
                                        }
                                        if (p.typ === "dreieck_gefuellt") {
                                            p.x2 = Math.max(0, Math.min(1, root.snap((o.x2 || 0) + ddx)))
                                            p.y2 = Math.max(0, Math.min(1, root.snap((o.y2 || 0) + ddy)))
                                            p.x3 = Math.max(0, Math.min(1, root.snap((o.x3 || 0) + ddx)))
                                            p.y3 = Math.max(0, Math.min(1, root.snap((o.y3 || 0) + ddy)))
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
                                        root.addPrimitiv({typ:"rechteck",x1:rx1,y1:ry1,x2:rx2,y2:ry2,linienart:root.aktLinienart})
                                        root.werkzeugPunkte = []
                                    }
                                    break

                                case "kreis_offen": {
                                    if (root.werkzeugPunkte.length === 0) {
                                        root.werkzeugPunkte = [{x:nx,y:ny}]
                                    } else {
                                        var ds = zeichneCanvas.drawSize
                                        var krad = Math.sqrt(((nx-root.werkzeugPunkte[0].x)*ds)*((nx-root.werkzeugPunkte[0].x)*ds)+((ny-root.werkzeugPunkte[0].y)*ds)*((ny-root.werkzeugPunkte[0].y)*ds)) / ds
                                        root.addPrimitiv({typ:"kreis_offen",x1:root.werkzeugPunkte[0].x,y1:root.werkzeugPunkte[0].y,radius:krad,linienart:root.aktLinienart})
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
                                        var bds = zeichneCanvas.drawSize
                                        var bcx = root.werkzeugPunkte[0].x, bcy = root.werkzeugPunkte[0].y
                                        var bRad2 = Math.sqrt(((root.werkzeugPunkte[1].x-bcx)*bds)*((root.werkzeugPunkte[1].x-bcx)*bds)+((root.werkzeugPunkte[1].y-bcy)*bds)*((root.werkzeugPunkte[1].y-bcy)*bds)) / bds
                                        var bWv = Math.atan2((root.werkzeugPunkte[1].y-bcy)*bds,(root.werkzeugPunkte[1].x-bcx)*bds)*180/Math.PI
                                        var bWb = Math.atan2((ny-bcy)*bds,(nx-bcx)*bds)*180/Math.PI
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

                    // Koordinaten-Anzeige
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
                        color: "#80000018"; radius: 3
                        width: koordinatenLbl.implicitWidth + 22; height: 30
                        Text {
                            id: koordinatenLbl
                            anchors.centerIn: parent
                            text: root.mausImCanvas
                                  ? "x: " + root.normToMm(root.mausNormPos.x).toFixed(1) + " mm   y: " + root.normToMm(root.mausNormPos.y).toFixed(1) + " mm"
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
                Rectangle {
                    width: 210
                    Layout.fillHeight: true
                    color: root.theme.sidebar
                    clip: true

                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 8

                        // Typ-Anzeige
                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (root.ausgewaehltPrimIdx >= 0) {
                                    var p = root.primitive[root.ausgewaehltPrimIdx]
                                    return p ? qsTr("Primitiv: ") + p.typ : qsTr("—")
                                }
                                if (root.ausgewaehltPinIdx >= 0) return qsTr("Pin ausgewählt")
                                return qsTr("Kein Element")
                            }
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: root.theme.textPrimary; wrapMode: Text.Wrap
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

                        // Koordinaten-Felder für ausgewähltes Primitiv
                        Repeater {
                            model: {
                                if (root.ausgewaehltPrimIdx < 0) return []
                                var p2 = root.primitive[root.ausgewaehltPrimIdx]
                                if (!p2) return []
                                switch (p2.typ) {
                                case "linie":      return ["x1","y1","x2","y2"]
                                case "rechteck":   return ["x1","y1","x2","y2"]
                                case "kreis_offen":
                                case "kreis_gefuellt": return ["x1","y1","radius"]
                                case "bogen":      return ["x1","y1","radius","winkel_von","winkel_bis"]
                                case "text":       return ["x1","y1","schrift_relativ"]
                                case "dreieck_gefuellt": return ["x1","y1","x2","y2","x3","y3"]
                                default: return []
                                }
                            }
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: {
                                        var angFelder = ["winkel_von","winkel_bis"]
                                        if (root.istPositionsfeld(modelData)) return modelData + " (mm):"
                                        if (angFelder.indexOf(modelData) >= 0) return modelData + " (°):"
                                        return modelData + ":"
                                    }
                                    font.pixelSize: 11; color: root.theme.textMuted
                                    width: 88
                                }
                                TextField {
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    font.pixelSize: 11
                                    text: {
                                        var idx2 = root.ausgewaehltPrimIdx
                                        if (idx2 < 0) return ""
                                        var pv = root.primitive[idx2]
                                        if (!pv) return ""
                                        var val = pv[modelData] !== undefined ? pv[modelData] : 0
                                        return root.istPositionsfeld(modelData)
                                            ? root.normToMm(val).toFixed(2)
                                            : val.toFixed(3)
                                    }
                                    background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                    color: root.theme.textPrimary
                                    onEditingFinished: {
                                        var idx3 = root.ausgewaehltPrimIdx
                                        if (idx3 < 0) return
                                        var arr = root.primitive.slice()
                                        var pm = Object.assign({}, arr[idx3])
                                        var parsed = parseFloat(text) || 0
                                        pm[modelData] = root.istPositionsfeld(modelData)
                                            ? root.mmToNorm(parsed)
                                            : parsed
                                        arr[idx3] = pm
                                        root.primitive = arr
                                        zeichneCanvas.requestPaint()
                                    }
                                }
                            }
                        }

                        // text_inhalt-Feld (nur bei Text-Primitiv)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: root.ausgewaehltPrimIdx >= 0 &&
                                     root.primitive[root.ausgewaehltPrimIdx] &&
                                     root.primitive[root.ausgewaehltPrimIdx].typ === "text"
                            Text { text: qsTr("Inhalt:"); font.pixelSize: 11; color: root.theme.textMuted }
                            TextField {
                                Layout.fillWidth: true; implicitHeight: 24; font.pixelSize: 11
                                text: {
                                    var idx4 = root.ausgewaehltPrimIdx
                                    if (idx4 < 0) return ""
                                    var px = root.primitive[idx4]
                                    return px ? (px.text_inhalt || "") : ""
                                }
                                background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                color: root.theme.textPrimary
                                onEditingFinished: {
                                    var idx5 = root.ausgewaehltPrimIdx; if (idx5 < 0) return
                                    var arr2 = root.primitive.slice()
                                    var pm2  = Object.assign({}, arr2[idx5])
                                    pm2.text_inhalt = text; arr2[idx5] = pm2; root.primitive = arr2
                                    zeichneCanvas.requestPaint()
                                }
                            }
                        }

                        // Linienart-Selektor (für ausgewähltes Primitiv)
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            visible: root.ausgewaehltPrimIdx >= 0
                            Text { text: qsTr("Linienart:"); font.pixelSize: 11; color: root.theme.textMuted }
                            ComboBox {
                                Layout.fillWidth: true; font.pixelSize: 11
                                model: ["durchgehend", "gestrichelt", "gepunktet", "Strich-Punkt"]
                                currentIndex: {
                                    var idx6 = root.ausgewaehltPrimIdx; if (idx6 < 0) return 0
                                    var pla = root.primitive[idx6]; if (!pla) return 0
                                    var i2 = model.indexOf(pla.linienart || "solid")
                                    return i2 >= 0 ? i2 : 0
                                }
                                onActivated: function(idx) {
                                    var idx7 = root.ausgewaehltPrimIdx; if (idx7 < 0) return
                                    var arr3 = root.primitive.slice()
                                    var pm3  = Object.assign({}, arr3[idx7])
                                    pm3.linienart = model[idx]; arr3[idx7] = pm3; root.primitive = arr3
                                    zeichneCanvas.requestPaint()
                                }
                            }
                        }

                        // Löschen-Button
                        Button {
                            Layout.fillWidth: true
                            visible: root.ausgewaehltPrimIdx >= 0
                            text: qsTr("Primitiv löschen")
                            implicitHeight: 28
                            onClicked: {
                                root.primitive = root.primitive.filter(function(_, idx) { return idx !== root.ausgewaehltPrimIdx })
                                root.ausgewaehltPrimIdx = -1
                                zeichneCanvas.requestPaint()
                            }
                            background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 4; border.color: "#ff4444"; border.width: 1 }
                            contentItem: Text { text: parent.text; color: "#ff4444"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }

                        Item { Layout.fillHeight: true }

                        // Anzahl-Info
                        Text {
                            Layout.fillWidth: true
                            text: root.primitive.length + qsTr(" Primitive · ") + root.pins.length + qsTr(" Pins")
                            font.pixelSize: 10; color: root.theme.textMuted
                        }
                    }
                } // Eigenschaften
            } // Hauptbereich-Row

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // ── Pin-Liste ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 190
                color:  root.theme.sidebar

                ColumnLayout {
                    anchors { fill: parent; margins: 8 }
                    spacing: 4

                    // Header
                    RowLayout {
                        Text { text: qsTr("Pins:"); font.pixelSize: 12; font.weight: Font.Medium; color: root.theme.textPrimary }
                        Text { text: "  " + qsTr("Name"); width: 56; font.pixelSize: 10; color: root.theme.textMuted }
                        Text { text: qsTr("x (mm)");      width: 62; font.pixelSize: 10; color: root.theme.textMuted }
                        Text { text: qsTr("y (mm)");      width: 62; font.pixelSize: 10; color: root.theme.textMuted }
                        Text { text: qsTr("Richtung");    width: 96; font.pixelSize: 10; color: root.theme.textMuted }
                        Text { text: qsTr("Signaltyp");   width: 95; font.pixelSize: 10; color: root.theme.textMuted }
                        Item { Layout.fillWidth: true }
                        // Standard-Vorlage: waagerecht (2 Pins links/rechts)
                        Button {
                            text: "↔ H"
                            implicitHeight: 24; implicitWidth: 40
                            ToolTip.visible: hovered; ToolTip.delay: 600
                            ToolTip.text: qsTr("Waagerecht: Pin 1 links (0 mm), Pin 2 rechts (%1 mm)").arg(root.groesse * 4.0)
                            onClicked: {
                                var yMid = 0.5
                                root.pins = [
                                    {name:"1", x:0.0,  y:yMid, offenX:-1, offenY:0, signaltyp:"neutral", kontext:""},
                                    {name:"2", x:1.0,  y:yMid, offenX:1,  offenY:0, signaltyp:"neutral", kontext:""}
                                ]
                                root.ausgewaehltPinIdx = -1
                                zeichneCanvas.requestPaint()
                            }
                            background: Rectangle { color: parent.hovered ? root.theme.badge : "transparent"; radius: 4; border.color: root.theme.accent; border.width: 1 }
                            contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        // Standard-Vorlage: senkrecht (2 Pins oben/unten)
                        Button {
                            text: "↕ V"
                            implicitHeight: 24; implicitWidth: 40
                            ToolTip.visible: hovered; ToolTip.delay: 600
                            ToolTip.text: qsTr("Senkrecht: Pin 1 oben (0 mm), Pin 2 unten (%1 mm)").arg(root.groesse * 4.0)
                            onClicked: {
                                var xMid = 0.5
                                root.pins = [
                                    {name:"1", x:xMid, y:0.0, offenX:0, offenY:-1, signaltyp:"neutral", kontext:""},
                                    {name:"2", x:xMid, y:1.0, offenX:0, offenY:1,  signaltyp:"neutral", kontext:""}
                                ]
                                root.ausgewaehltPinIdx = -1
                                zeichneCanvas.requestPaint()
                            }
                            background: Rectangle { color: parent.hovered ? root.theme.badge : "transparent"; radius: 4; border.color: root.theme.accent; border.width: 1 }
                            contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            text: qsTr("+ Pin")
                            implicitHeight: 24; implicitWidth: 58
                            onClicked: {
                                root.pins = root.pins.concat([{name:"P"+(root.pins.length+1),x:0.5,y:1,offenX:0,offenY:1,signaltyp:"neutral",kontext:""}])
                                root.ausgewaehltPinIdx = root.pins.length - 1
                                zeichneCanvas.requestPaint()
                            }
                            background: Rectangle { color: parent.hovered ? root.theme.badge : "transparent"; radius: 4; border.color: root.theme.accent; border.width: 1 }
                            contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }

                    // Pin-Einträge
                    ListView {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        model: root.pins
                        clip:  true

                        delegate: Rectangle {
                            width:  ListView.view.width
                            height: 30
                            color:  root.ausgewaehltPinIdx === index ? root.theme.badge : "transparent"
                            radius: 3

                            // Index für innere Repeater sichern
                            property int  myIdx: index
                            property var  myPin: root.pins[index] || {}

                            TapHandler { onTapped: { root.ausgewaehltPinIdx = myIdx; root.ausgewaehltPrimIdx = -1; zeichneCanvas.requestPaint() } }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4; leftPadding: 4

                                // Name
                                TextField {
                                    width: 54; height: 30; font.pixelSize: 11
                                    text: parent.parent.myPin.name || ""
                                    background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                    color: root.theme.textPrimary
                                    onEditingFinished: {
                                        var arr = root.pins.slice()
                                        var p = Object.assign({}, arr[parent.parent.myIdx])
                                        p.name = text; arr[parent.parent.myIdx] = p; root.pins = arr
                                    }
                                }
                                // x (mm)
                                TextField {
                                    width: 58; height: 30; font.pixelSize: 11
                                    text: root.normToMm(parent.parent.myPin.x !== undefined ? parent.parent.myPin.x : 0).toFixed(2)
                                    validator: DoubleValidator { bottom: 0; top: root.groesse * 4.0; decimals: 2 }
                                    background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                    color: root.theme.textPrimary
                                    onEditingFinished: {
                                        var arr = root.pins.slice()
                                        var p = Object.assign({}, arr[parent.parent.myIdx])
                                        p.x = root.mmToNorm(parseFloat(text)||0)
                                        arr[parent.parent.myIdx] = p; root.pins = arr
                                        zeichneCanvas.requestPaint()
                                    }
                                }
                                // y (mm)
                                TextField {
                                    width: 58; height: 30; font.pixelSize: 11
                                    text: root.normToMm(parent.parent.myPin.y !== undefined ? parent.parent.myPin.y : 0.5).toFixed(2)
                                    validator: DoubleValidator { bottom: 0; top: root.groesse * 4.0; decimals: 2 }
                                    background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                    color: root.theme.textPrimary
                                    onEditingFinished: {
                                        var arr = root.pins.slice()
                                        var p = Object.assign({}, arr[parent.parent.myIdx])
                                        p.y = root.mmToNorm(parseFloat(text)||0.5)
                                        arr[parent.parent.myIdx] = p; root.pins = arr
                                        zeichneCanvas.requestPaint()
                                    }
                                }
                                // Richtung (offen-Vektor)
                                Row {
                                    spacing: 2
                                    Repeater {
                                        model: [{l:"←",ox:-1,oy:0},{l:"→",ox:1,oy:0},{l:"↑",ox:0,oy:-1},{l:"↓",ox:0,oy:1}]
                                        delegate: Rectangle {
                                            width: 22; height: 30; radius: 3
                                            property var outerPin: parent.parent.parent.myPin
                                            property int outerIdx: parent.parent.parent.myIdx
                                            color: (outerPin.offenX===modelData.ox && outerPin.offenY===modelData.oy)
                                                   ? root.theme.accent
                                                   : (dirHover.containsMouse ? root.theme.badge : "transparent")
                                            Text { anchors.centerIn: parent; text: modelData.l; font.pixelSize: 13
                                                   color: (parent.outerPin.offenX===modelData.ox && parent.outerPin.offenY===modelData.oy) ? "white" : root.theme.textPrimary }
                                            HoverHandler { id: dirHover }
                                            TapHandler {
                                                onTapped: {
                                                    var arr = root.pins.slice()
                                                    var p = Object.assign({}, arr[parent.outerIdx])
                                                    p.offenX = modelData.ox; p.offenY = modelData.oy
                                                    arr[parent.outerIdx] = p; root.pins = arr
                                                    zeichneCanvas.requestPaint()
                                                }
                                            }
                                        }
                                    }
                                }
                                // Signaltyp
                                ComboBox {
                                    width: 140; height: 30
                                    model: ["neutral","power","pe","n","input_digital","output_digital","input_analog","output_analog"]
                                    font.pixelSize: 10
                                    currentIndex: {
                                        var st = parent.parent.myPin.signaltyp || "neutral"
                                        var i2 = model.indexOf(st); return i2 >= 0 ? i2 : 0
                                    }
                                    onActivated: function(idx) {
                                        var arr = root.pins.slice()
                                        var p = Object.assign({}, arr[parent.parent.myIdx])
                                        p.signaltyp = model[idx]; arr[parent.parent.myIdx] = p; root.pins = arr
                                    }
                                }
                                // Löschen
                                Rectangle {
                                    width: 22; height: 30; radius: 3
                                    color: delHover.containsMouse ? "#3a1a1a" : "transparent"
                                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: "#ff4444" }
                                    HoverHandler { id: delHover }
                                    TapHandler {
                                        onTapped: {
                                            var myI = parent.parent.parent.myIdx
                                            root.pins = root.pins.filter(function(_, i2) { return i2 !== myI })
                                            if (root.ausgewaehltPinIdx >= root.pins.length) root.ausgewaehltPinIdx = -1
                                            zeichneCanvas.requestPaint()
                                        }
                                    }
                                }
                            }
                        }
                    } // ListView
                }
            } // Pin-Liste
        } // ColumnLayout (Editor)
    } // RowLayout

    DebugLabel { panelName: qsTr("Symbol-Editor"); visible: root.debug }
}
