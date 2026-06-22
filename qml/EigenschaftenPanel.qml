import QtQuick
import QtQuick.Controls
import "components"
import "ep"
import "SymbolKlassen.js" as SK

// ============================================================
// EigenschaftenPanel.qml
// Rechtes Seitenpanel – zeigt und bearbeitet Eigenschaften des
// ausgewählten Canvas-Elements.
//
// Verwendung:
//   EigenschaftenPanel { canvas: root }
//
// canvas muss SchaltplanCanvas sein und folgende Funktionen bieten:
//   eigenschaftAktualisieren(key, value)
//   eigenschaftenSetzen(updates)
//   zReihenfolgeAendern(richtung)
// ============================================================

Rectangle {
    id: panel

    // Referenz auf den Canvas (für Callbacks und Datenzugriff)
    required property var canvas
    property var  theme
    property bool debug: false

    // Refresh-Zähler: hochzählen erzwingt Binding-Neuauswertung von el + EpKabelDefinitionSection.
    // Wird bei jedem elementeModel.geaendert inkrementiert, damit in-place-Änderungen
    // (z.B. extraDaten per eigenschaftAktualisieren) sofort im Panel sichtbar werden.
    property int _refresh: 0

    Connections {
        target: canvas ? canvas.elementeModel : null
        function onGeaendert() { panel._refresh++ }
    }
    Connections {
        target: canvas
        function onAuswahlChanged() { panel._refresh++ }
    }

    // Shortcut – aktuell ausgewähltes Element-Objekt (null wenn keins).
    // _refresh * 0 in den idx-Ausdruck damit der AOT-Compiler die Abhängigkeit nicht wegoptimiert.
    readonly property var el: {
        var idx = canvas.ausgewaehlt + _refresh * 0
        return (idx >= 0 && idx < canvas.elementeModel.anzahl) ? canvas.elementeModel.element(idx) : null
    }

    // Anzahl selektierter Elemente – als getypte int-Property hier in EigenschaftenPanel
    // definiert, damit EpMehrfachauswahlSection über panel.auswahlLaenge binden kann.
    // canvas.auswahlLaenge direkt aus der Section zu binden funktioniert im AOT-Modus
    // nicht zuverlässig (required property var canvas als Holder).
    readonly property int auswahlLaenge:       canvas ? canvas.auswahlLaenge       : 0
    readonly property int symbolAuswahlAnzahl: canvas ? canvas.symbolAuswahlAnzahl : 0
    readonly property int seiteId:             canvas ? canvas.seiteId             : -1

    // Format-Pinsel-Zähler: hochzählen in formatKopieren() → reaktiver Proxy für Sections
    readonly property int formatZaehler: canvas ? canvas.formatZaehler : 0

    // Ausgewählte Auto-Verbindung (null wenn keine)
    readonly property var verbindung: canvas.ausgewaehltVerbindung

    // Klemmen-Details – wird automatisch neu abgefragt wenn el wechselt
    readonly property var kaDetails: {
        if (!panel.el || panel.el.symbolId !== "klemme_anschluss") return null
        var ed  = panel.el.extraDaten || {}
        var kid = ed.bauteilKlemmeId
        if (kid === undefined || kid < 0) return null
        return klemmeModel.klemmeDetailsHolen(kid, ed.anschlussBezeichnung || "")
    }

    // Verfügbare Farben in der Palette
    readonly property var farbpalette: [
        "#4a9eff", "#0055cc", "#00ccff", "#44cc44",
        "#ff4444", "#ff8800", "#ffee00", "#cc44cc",
        "#ffffff", "#aaaaaa", "#555555", "#000000"
    ]

    color:  theme.surfaceDeep
    clip:   true

    // Sichere Eigenschaftsabfrage mit Fallback
    function s(key, fallback) {
        return (panel.el && panel.el[key] !== undefined) ? panel.el[key] : fallback
    }

    // Findet den kleinsten Strukturkasten der den Mittelpunkt von el enthält.
    // Gibt das extraDaten-Objekt des Kastens zurück, oder null.
    function strukturkastenFuer(el) {
        var cx = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
        var best = null, bestArea = Infinity
        var _skSnap = canvas.elementeModel.snapshot()
        for (var i = 0; i < _skSnap.length; i++) {
            var sk = _skSnap[i]
            if (sk.typ !== "strukturkasten") continue
            var sx1 = Math.min(sk.x1, sk.x2), sx2 = Math.max(sk.x1, sk.x2)
            var sy1 = Math.min(sk.y1, sk.y2), sy2 = Math.max(sk.y1, sk.y2)
            if (cx >= sx1 && cx <= sx2 && cy >= sy1 && cy <= sy2) {
                var area = (sx2 - sx1) * (sy2 - sy1)
                if (area < bestArea) { bestArea = area; best = sk.extraDaten || {} }
            }
        }
        return best
    }

    // Findet den kleinsten Gerätekasten der den Mittelpunkt von el enthält.
    // Gibt das Element-Objekt zurück, oder null.
    function geraetekastenFuer(el) {
        var cx = (el.x1 + el.x2) / 2, cy = (el.y1 + el.y2) / 2
        var best = null, bestArea = Infinity
        var _gkSnap = canvas.elementeModel.snapshot()
        for (var i = 0; i < _gkSnap.length; i++) {
            var gk = _gkSnap[i]
            if (gk.typ !== "geraetekasten") continue
            var gx1 = Math.min(gk.x1, gk.x2), gx2 = Math.max(gk.x1, gk.x2)
            var gy1 = Math.min(gk.y1, gk.y2), gy2 = Math.max(gk.y1, gk.y2)
            if (cx >= gx1 && cx <= gx2 && cy >= gy1 && cy <= gy2) {
                var area = (gx2 - gx1) * (gy2 - gy1)
                if (area < bestArea) { bestArea = area; best = gk }
            }
        }
        return best
    }

    // Vollkennzeichen des ausgewählten Elements nach DIN EN 81346.
    // Leer für reine Grafikelemente (Linie, Rechteck, Kreis, Polygonlinie, Text, Bild).
    readonly property string vollkennzeichen: {
        var el = panel.el
        if (!el) return ""

        var bmk = "", anlageUO = "", anlage = "", ortUO = "", ort = ""
        var nd  = canvas.normblattDaten   // {anlageKuerzel, ortKuerzel, ...} oder null

        if (el.typ === "symbol") {
            var sid = el.symbolId || ""

            if (sid === "geraeteanschluss") {
                // BMK nur wenn im Gerätekasten; Anschlusskennzeichnung ist der :-Teil
                var ank = (el.extraDaten || {}).anschlusskennzeichnung || ""
                if (!ank) return ""
                var gk = geraetekastenFuer(el)
                if (!gk) return ""
                var gkBmkGA = (gk.extraDaten || {}).bmk || ""
                bmk = (gkBmkGA ? gkBmkGA + ":" : ":") + ank
                var skGA = strukturkastenFuer(gk)
                anlageUO = (skGA && skGA.anlageUO) ? skGA.anlageUO : (nd ? nd.anlageUO || "" : "")
                anlage   = skGA && skGA.anlage ? skGA.anlage : (nd ? nd.anlageKuerzel || "" : "")
                ortUO    = (skGA && skGA.ortUO) ? skGA.ortUO : (nd ? nd.ortUO || "" : "")
                ort      = skGA && skGA.ort    ? skGA.ort    : (nd ? nd.ortKuerzel    || "" : "")
            } else {
                if (SK.istVerbHelper(sid)) return ""
                bmk = (el.extraDaten || {}).bmk || ""
                if (!bmk) return ""
                var sk = strukturkastenFuer(el)
                anlageUO = (sk && sk.anlageUO) ? sk.anlageUO : (nd ? nd.anlageUO || "" : "")
                anlage   = sk && sk.anlage ? sk.anlage : (nd ? nd.anlageKuerzel || "" : "")
                ortUO    = (sk && sk.ortUO) ? sk.ortUO : (nd ? nd.ortUO || "" : "")
                ort      = sk && sk.ort    ? sk.ort    : (nd ? nd.ortKuerzel    || "" : "")
            }
        } else if (el.typ === "geraetekasten") {
            bmk = (el.extraDaten || {}).bmk || ""
            if (!bmk) return ""
            var sk2 = strukturkastenFuer(el)
            anlageUO = (sk2 && sk2.anlageUO) ? sk2.anlageUO : (nd ? nd.anlageUO || "" : "")
            anlage   = sk2 && sk2.anlage ? sk2.anlage : (nd ? nd.anlageKuerzel || "" : "")
            ortUO    = (sk2 && sk2.ortUO) ? sk2.ortUO : (nd ? nd.ortUO || "" : "")
            ort      = sk2 && sk2.ort    ? sk2.ort    : (nd ? nd.ortKuerzel    || "" : "")
        } else if (el.typ === "strukturkasten") {
            var ed = el.extraDaten || {}
            anlageUO = ed.anlageUO || (nd ? nd.anlageUO || "" : "")
            anlage   = ed.anlage   || (nd ? nd.anlageKuerzel || "" : "")
            ortUO    = ed.ortUO    || (nd ? nd.ortUO || "" : "")
            ort      = ed.ort      || (nd ? nd.ortKuerzel    || "" : "")
        } else {
            return ""
        }

        var result = ""
        if (anlageUO) result += "==" + anlageUO
        if (anlage)   result += "="  + anlage
        if (ortUO)    result += "++" + ortUO
        if (ort)      result += "+"  + ort
        if (bmk)      result += bmk
        return result
    }

    // --------------------------------------------------------
    // ScrollView – kompletter Panel-Inhalt
    // --------------------------------------------------------
    ScrollView {
        anchors.fill: parent
        contentWidth: panel.width
        clip: true
        focus: false          // Flickable darf keinen Tastaturfokus stehlen;
        activeFocusOnTab: false  // Maus-Scroll funktioniert fokusunabhängig

        Column {
            id: inhalt
            width: panel.width
            topPadding:    8
            bottomPadding: 12
            spacing:       0

            // ------------------------------------------------
            // Typ-Header
            // ------------------------------------------------
            Row {
                leftPadding: 12; height: 36; spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (panel.verbindung !== null && !panel.el)
                            return "\u26A1  Verbindung" + (panel.verbindung.bezeichnung ? " \u2013 " + panel.verbindung.bezeichnung : "")
                        if (!panel.el && canvas.auswahl.length > 1)
                            return canvas.auswahl.length + qsTr(" Elemente ausgewählt")
                        if (!panel.el) return "–"
                        if (panel.el.typ === "linie")          return "\u2572  Linie"
                        if (panel.el.typ === "polygonlinie")   return "\u2F09  Polygonlinie"
                        if (panel.el.typ === "rechteck")       return "\u25A1  Rechteck"
                        if (panel.el.typ === "kreis")          return "\u25CB  Kreis"
                        if (panel.el.typ === "symbol")         return "\u26A1  Symbol \u2013 " + (panel.el.symbolId || "")
                        if (panel.el.typ === "text")           return "T  Text"
                        if (panel.el.typ === "notiz")          return "\u270E  Notiz"
                        if (panel.el.typ === "geraetekasten")  return "\u25A3  Gerätekasten"
                        if (panel.el.typ === "strukturkasten") return "\u2610  Strukturkasten"
                        if (panel.el.typ === "kabellinie")     return "\u2504  Kabeldefinitionslinie"
                        return panel.el.typ
                    }
                    font.pixelSize: 13; font.weight: Font.Medium; color: theme.textSecondary
                }
            }

            // Vollkennzeichen-Badge
            Item {
                width: parent.width
                height: panel.vollkennzeichen !== "" ? 26 : 0
                visible: height > 0
                Rectangle {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    height: 20; radius: 3; width: vkLabel.implicitWidth + 14
                    color: Qt.rgba(0.29, 0.60, 1.0, 0.12)
                    border.color: theme.accent; border.width: 1
                    Text {
                        id: vkLabel
                        anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                        text: panel.vollkennzeichen
                        font.pixelSize: 11; font.family: "monospace"; font.weight: Font.Medium
                        color: theme.accent
                    }
                }
            }

            Trennlinie {}

            // ABSCHNITT: VERBINDUNG → EpVerbindungSection.qml
            EpVerbindungSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: STIL → EpStilSection.qml
            EpStilSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: FÜLLUNG → EpFuellungSection.qml
            EpFuellungSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: FORM → EpFormSection.qml
            EpFormSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: FORMAT-PINSEL → EpFormatPinselSection.qml
            EpFormatPinselSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: MEHRFACHAUSWAHL → EpMehrfachauswahlSection.qml
            EpMehrfachauswahlSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: SYMBOL → EpSymbolSection.qml
            EpSymbolSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: ADERDEFINITION → EpAderdefinitionSection.qml
            EpAderdefinitionSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: KLEMMEN-ANSCHLUSS
            EpKlemmenAnschlussSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: STECKVERBINDER → EpSteckverbinderSection.qml
            EpSteckverbinderSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: BILD → EpBildSection.qml
            EpBildSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: TEXT-INHALT → EpTextInhaltSection.qml
            EpTextInhaltSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: NOTIZ → EpNotizSection.qml
            EpNotizSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: MAßE → EpMasseSection.qml
            EpMasseSection { canvas: canvas; panel: panel; theme: panel.theme }
            // ABSCHNITT: SPS/PLS-KANAL → EpSpsKanalSection.qml
            EpSpsKanalSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: BETRIEBSMITTEL → EpBetriebsmittelSection.qml
            EpBetriebsmittelSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: INBETRIEBNAHME-STATUS (read-only) → EpIbnStatusSection.qml
            EpIbnStatusSection { panel: panel; theme: panel.theme }

            // ABSCHNITT: QUERVERWEIS → EpQuerverweisSection.qml
            EpQuerverweisSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: POTENZIAL → EpPotenzialSection.qml
            EpPotenzialSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: TREFFPUNKT → EpTreffpunktSection.qml
            EpTreffpunktSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: GERÄTEANSCHLUSS → EpGeraeteanschlussSection.qml
            EpGeraeteanschlussSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: GERÄTEKASTEN
            EpGeraetekastenSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: STRUKTURKASTEN
            EpStrukturkastenSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: MAKROKASTEN
            EpMakrokastenSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: SCHIRM
            EpSchirmSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ================================================
            // ABSCHNITT: KABELDEFINITIONSLINIE
            EpKabelDefinitionSection { canvas: canvas; panel: panel; theme: panel.theme }

            // ABSCHNITT: REIHENFOLGE
            // ================================================
            Trennlinie     { visible: panel.el !== null && canvas.auswahl.length === 1 }
            AbschnittTitel { text: qsTr("REIHENFOLGE")
                             visible: panel.el !== null && canvas.auswahl.length === 1 }

            Grid {
                visible: panel.el !== null && canvas.auswahl.length === 1
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 2; spacing: 4; bottomPadding: 4

                Repeater {
                    model: [
                        { anzeige: "\u2912 Ganz vorne",  richt: "ganzVorne",  tip: qsTr("In den Vordergrund (vor alle anderen)")  },
                        { anzeige: "\u2913 Ganz hinten", richt: "ganzHinten", tip: qsTr("In den Hintergrund (hinter alle anderen)") },
                        { anzeige: "\u2191 Eine vor",    richt: "vorne1",     tip: qsTr("Eine Ebene nach vorne")  },
                        { anzeige: "\u2193 Eine zurück", richt: "hinten1",    tip: qsTr("Eine Ebene nach hinten") }
                    ]
                    MiniButton { theme: panel.theme;
                        label:   modelData.anzeige
                        tooltip: modelData.tip
                        breite:  90; hoehe: 26
                        onKlick: canvas.zReihenfolgeAendern(modelData.richt)
                    }
                }
            }

            // ── LÖSCHEN ──────────────────────────────────────────────────
            Trennlinie { visible: canvas.auswahl.length > 0 }

            Item {
                visible: canvas.auswahl.length > 0
                width:   panel.width
                height:  46

                Rectangle {
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 12; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    height: 30; radius: 4
                    color:        loeschMaus.containsMouse ? "#3a0a0a" : "#200808"
                    border.color: "#993333"

                    Text {
                        anchors.centerIn: parent
                        text: canvas.auswahl.length > 1
                              ? "✕  " + canvas.auswahl.length + qsTr(" Elemente löschen")
                              : "✕  " + qsTr("Element löschen")
                        font.pixelSize: 11
                        color: "#ff5555"
                    }

                    MouseArea {
                        id: loeschMaus
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    canvas.loeschen()
                    }

                    ToolTip.visible: loeschMaus.containsMouse
                    ToolTip.text:    qsTr("Ausgewähltes löschen (Entf)")
                    ToolTip.delay:   500
                }
            }
        }
    }

    // ============================================================
    // Inline-Komponenten
    // ============================================================

    component Trennlinie: Rectangle {
        width: panel.width - 16; height: 1; color: theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: panel.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text:            parent.text
            font.pixelSize:  9
            font.weight:     Font.Bold
            font.letterSpacing: 1.5
            color:           theme.borderLight
        }
    }

    component FeldLabel: Item {
        property string text: ""
        width: panel.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: theme.panelMid
        }
    }


    DebugLabel { panelName: qsTr("Eigenschaften-Panel"); visible: panel.debug }
}
