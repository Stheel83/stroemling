import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "ep"

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

    // Shortcut – aktuell ausgewähltes Element-Objekt (null wenn keins)
    readonly property var el: {
        var idx = canvas.ausgewaehlt
        return (idx >= 0 && idx < canvas.elemente.length) ? canvas.elemente[idx] : null
    }

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

    color:  theme ? theme.surfaceDeep : "#09121e"
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
        for (var i = 0; i < canvas.elemente.length; i++) {
            var sk = canvas.elemente[i]
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
        for (var i = 0; i < canvas.elemente.length; i++) {
            var gk = canvas.elemente[i]
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

        var VERB_SYMS = ["winkel","treffpunkt","treffpunkt_l","geraeteanschluss",
                         "unterbrechung","querverweis","aderdefinition","potenzial","klemme_anschluss"]

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
                anlageUO = skGA ? skGA.anlageUO || "" : ""
                anlage   = skGA && skGA.anlage ? skGA.anlage : (nd ? nd.anlageKuerzel || "" : "")
                ortUO    = skGA ? skGA.ortUO   || "" : ""
                ort      = skGA && skGA.ort    ? skGA.ort    : (nd ? nd.ortKuerzel    || "" : "")
            } else {
                for (var k = 0; k < VERB_SYMS.length; k++) if (sid === VERB_SYMS[k]) return ""
                bmk = (el.extraDaten || {}).bmk || ""
                if (!bmk) return ""
                var sk = strukturkastenFuer(el)
                anlageUO = sk ? sk.anlageUO || "" : ""
                anlage   = sk && sk.anlage ? sk.anlage : (nd ? nd.anlageKuerzel || "" : "")
                ortUO    = sk ? sk.ortUO   || "" : ""
                ort      = sk && sk.ort    ? sk.ort    : (nd ? nd.ortKuerzel    || "" : "")
            }
        } else if (el.typ === "geraetekasten") {
            bmk = (el.extraDaten || {}).bmk || ""
            if (!bmk) return ""
            var sk2 = strukturkastenFuer(el)
            anlageUO = sk2 ? sk2.anlageUO || "" : ""
            anlage   = sk2 && sk2.anlage ? sk2.anlage : (nd ? nd.anlageKuerzel || "" : "")
            ortUO    = sk2 ? sk2.ortUO   || "" : ""
            ort      = sk2 && sk2.ort    ? sk2.ort    : (nd ? nd.ortKuerzel    || "" : "")
        } else if (el.typ === "strukturkasten") {
            var ed = el.extraDaten || {}
            anlageUO = ed.anlageUO || ""
            anlage   = ed.anlage   || (nd ? nd.anlageKuerzel || "" : "")
            ortUO    = ed.ortUO    || ""
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
                    color: theme ? Qt.rgba(0.29, 0.60, 1.0, 0.12) : "#0d2040"
                    border.color: theme ? theme.accent : "#4a9eff"; border.width: 1
                    Text {
                        id: vkLabel
                        anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                        text: panel.vollkennzeichen
                        font.pixelSize: 11; font.family: "monospace"; font.weight: Font.Medium
                        color: theme ? theme.accent : "#4a9eff"
                    }
                }
            }

            Trennlinie {}

            // ================================================
            // ABSCHNITT: VERBINDUNG (nur wenn Auto-Verbindung selektiert)
            // ================================================
            Item {
                visible: panel.verbindung !== null && !panel.el
                width: panel.width
                height: visible ? verbindungCol.implicitHeight : 0
                clip: true

                Column {
                    id: verbindungCol
                    width: parent.width; spacing: 0

                    AbschnittTitel { text: qsTr("VERBINDUNG") }

                    // Signaltyp (Anzeige, nicht editierbar)
                    FeldLabel { text: qsTr("Signaltyp") }
                    Item {
                        width: panel.width; height: 28
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            width: 80; height: 20; radius: 3
                            color: {
                                var s = panel.verbindung ? panel.verbindung.signaltyp : "neutral"
                                if (s === "power")           return "#cc3300"
                                if (s === "pe")              return "#88cc00"
                                if (s === "n")               return "#4488ff"
                                if (s === "input_digital")   return "#44aaff"
                                if (s === "output_digital")  return "#44cc66"
                                if (s === "input_analog")    return "#88bbff"
                                if (s === "output_analog")   return "#66ddaa"
                                if (s === "kommunikation")   return "#aa44cc"
                                if (s === "konflikt")        return "#ff8800"
                                return theme.border
                            }
                            Text {
                                anchors.centerIn: parent
                                text: panel.verbindung ? (panel.verbindung.signaltyp || "neutral") : ""
                                font.pixelSize: 10; color: "#ffffff"
                            }
                        }
                    }

                    // Potenzialname / Bezeichnung
                    InputField {
                        label: qsTr("Bezeichnung")
                        value: panel.verbindung ? (panel.verbindung.bezeichnung || "") : ""
                        theme: theme
                        onCommit: function(t) { canvas.verbindungAnnotationAktualisieren("bezeichnung", t) }
                    }

                    // ADP-Daten (Nur-Lesen – Bearbeitung über Aderdefinitionspunkt-Symbol)
                    FeldLabel { text: qsTr("Aderdaten (vom Aderdefinitionspunkt)") }
                    Repeater {
                        model: {
                            var adps = panel.verbindung ? (panel.verbindung.adps || []) : []
                            return adps.length > 0 ? adps : [null]
                        }
                        Item {
                            width: panel.width; height: adpRow.implicitHeight + 6
                            Row {
                                id: adpRow
                                anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12
                                          verticalCenter: parent.verticalCenter }
                                spacing: 6
                                Rectangle {
                                    visible: modelData && modelData.ed && modelData.ed.aderfarbe
                                    width: 14; height: 14; radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: (modelData && modelData.ed && modelData.ed.aderfarbe)
                                           ? canvas.aderFarbeZuCanvas(modelData.ed.aderfarbe) : "transparent"
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: theme.textSecondary; font.pixelSize: 11
                                    text: {
                                        if (!modelData) return "– kein Aderdefinitionspunkt –"
                                        var ed = modelData.ed || {}
                                        var t = ""
                                        if (ed.bezeichnung) t += ed.bezeichnung + "  "
                                        if (ed.aderfarbe)   t += ed.aderfarbe + "  "
                                        if (ed.querschnitt_mm2 > 0) t += ed.querschnitt_mm2 + " mm²  "
                                        if (ed.laenge_m > 0)        t += "\u2192 " + ed.laenge_m + " m"
                                        return t.trim() || "–"
                                    }
                                }
                            }
                        }
                    }

                    Trennlinie {}
                }
            }

            // ================================================
            // ABSCHNITT: STIL (alle Typen)
            // ================================================
            AbschnittTitel { text: qsTr("STIL") }

            // Strichfarbe (nicht für Bilder)
            FeldLabel { text: qsTr("Farbe"); visible: !panel.el || panel.el.typ !== "bild" }
            ColorPalette {
                visible: !panel.el || panel.el.typ !== "bild"
                height:  visible ? implicitHeight : 0
                model:   panel.farbpalette
                value:   panel.s("strichFarbe", theme.accent)
                theme:   theme
                onColorSelected: function(c) { canvas.eigenschaftAktualisieren("strichFarbe", c) }
            }
            Item { height: 8; visible: !panel.el || panel.el.typ !== "bild" }

            // Strichstärke (alle Typen außer Text und Bild)
            Item {
                width: parent.width
                height: (panel.el && panel.el.typ !== "text" && panel.el.typ !== "bild") ? strichCol.implicitHeight : 0
                visible: height > 0; clip: true
                Column {
                    id: strichCol
                    width: parent.width; spacing: 0
                    FeldLabel { text: qsTr("Strichstärke") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Repeater {
                            model: [
                                { anzeige: "0.5", wert: 0.5 }, { anzeige: "1",   wert: 1.0 },
                                { anzeige: "1.5", wert: 1.5 }, { anzeige: "2",   wert: 2.0 },
                                { anzeige: "3",   wert: 3.0 }, { anzeige: "5",   wert: 5.0 }
                            ]
                            MiniButton { theme: theme;
                                label:   modelData.anzeige
                                tooltip: modelData.anzeige + " mm"
                                aktiv:   Math.abs(panel.s("strichBreite", 1.5) - modelData.wert) < 0.01
                                breite:  32
                                onKlick: canvas.eigenschaftAktualisieren("strichBreite", modelData.wert)
                            }
                        }
                    }
                    Item { height: 8 }
                }
            }

            // Schriftgröße (nur Text-Elemente)
            Item {
                width: parent.width
                height: (panel.el && panel.el.typ === "text") ? txtSchriftCol.implicitHeight : 0
                visible: height > 0; clip: true
                Column {
                    id: txtSchriftCol
                    width: parent.width; spacing: 0
                    FeldLabel { text: qsTr("Schriftgröße") }
                    SchriftgrosseSelektor {
                        wert: panel.s("strichBreite", 3.5)
                        onWertGeaendert: function(v) {
                            canvas.eigenschaftAktualisieren("strichBreite", v)
                        }
                    }
                    Item { height: 8 }
                }
            }
            Item { height: 0 }

            // Linienart (nicht für Bilder)
            FeldLabel { text: qsTr("Linienart"); visible: !panel.el || panel.el.typ !== "bild" }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                visible: !panel.el || panel.el.typ !== "bild"
                height: visible ? implicitHeight : 0
                Repeater {
                    model: [
                        { anzeige: "\u2014\u2014",    wert: "solid",       tip: qsTr("Durchgehend")  },
                        { anzeige: "- -  -",          wert: "gestrichelt", tip: qsTr("Gestrichelt")  },
                        { anzeige: "\u00B7\u00B7\u00B7\u00B7\u00B7", wert: "gepunktet", tip: qsTr("Gepunktet") }
                    ]
                    MiniButton { theme: theme;
                        label:   modelData.anzeige
                        tooltip: modelData.tip
                        aktiv:   panel.s("strichArt", "solid") === modelData.wert
                        breite:  58
                        mono:    true
                        onKlick: canvas.eigenschaftAktualisieren("strichArt", modelData.wert)
                    }
                }
            }
            Item { height: 8; visible: !panel.el || panel.el.typ !== "bild" }

            // Deckkraft mit Zahleneingabe
            Item {
                width: panel.width; height: 22
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("Deckkraft"); color: theme.panelMid; font.pixelSize: 10
                }
                Row {
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 3
                    Rectangle {
                        width: 36; height: 18; radius: 3; anchors.verticalCenter: parent.verticalCenter
                        color: theme.inputBg; border.color: opTf.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: opTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                            horizontalAlignment: TextInput.AlignRight
                            color: theme.textSecondary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter
                            validator: IntValidator { bottom: 5; top: 100 }
                            text: Math.round(panel.s("opazitaet", 1.0) * 100)
                            Binding on text {
                                when: !opTf.activeFocus
                                value: Math.round(panel.s("opazitaet", 1.0) * 100)
                            }
                            onEditingFinished: {
                                var v = parseInt(text)
                                if (!isNaN(v)) canvas.eigenschaftAktualisieren("opazitaet", Math.max(0.05, Math.min(1.0, v/100)))
                            }
                            Keys.onEscapePressed: { text = Math.round(panel.s("opazitaet", 1.0) * 100); focus = false }
                        }
                    }
                    Text { text: "%"; color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            StilSlider {
                width: panel.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                von: 0.05; bis: 1.0; schritt: 0.05
                wert: panel.s("opazitaet", 1.0)
                onGeaendert: function(v) { canvas.eigenschaftAktualisieren("opazitaet", v) }
            }

            // ================================================
            // ABSCHNITT: FÜLLUNG (nur Rechteck + Kreis)
            // ================================================
            Item {
                width: parent.width
                height: (panel.el && (panel.el.typ === "rechteck" || panel.el.typ === "kreis"))
                        ? fuellCol.implicitHeight : 0
                visible: height > 0; clip: true

                Column {
                    id: fuellCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("FÜLLUNG") }

                    // Toggle Füllung an/aus
                    Row {
                        leftPadding: 12; height: 32; spacing: 8
                        Rectangle {
                            width: 20; height: 20; radius: 4; anchors.verticalCenter: parent.verticalCenter
                            color: panel.s("fuell", false) ? theme.accent : theme.inputBg
                            border.color: theme.border
                            Text { anchors.centerIn: parent; text: qsTr("\u2713"); color: "#ffffff"; font.pixelSize: 12
                                   visible: panel.s("fuell", false) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: canvas.eigenschaftAktualisieren("fuell", !panel.s("fuell", false))
                                        ToolTip.visible: containsMouse
                                        ToolTip.text:    qsTr("Füllung ein-/ausschalten")
                                        ToolTip.delay:   500 }
                        }
                        Text { text: qsTr("Füllung aktivieren"); color: theme.textMuted; font.pixelSize: 11
                               anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Farbe + Opazität (nur wenn aktiv)
                    Item {
                        width: parent.width
                        height: panel.s("fuell", false) ? fuellDetailCol.implicitHeight : 0
                        visible: height > 0; clip: true

                        Column {
                            id: fuellDetailCol
                            width: parent.width; spacing: 0

                            FeldLabel { text: qsTr("Füllfarbe") }
                            ColorPalette {
                                model: panel.farbpalette
                                value: panel.s("fuellFarbe", theme.activeItemAlt)
                                theme: theme
                                onColorSelected: function(c) { canvas.eigenschaftAktualisieren("fuellFarbe", c) }
                            }
                            Item { height: 8 }

                            Item {
                                width: panel.width; height: 22
                                Text {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: qsTr("Füllopazität"); color: theme.panelMid; font.pixelSize: 10
                                }
                                Row {
                                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    spacing: 3
                                    Rectangle {
                                        width: 36; height: 18; radius: 3; anchors.verticalCenter: parent.verticalCenter
                                        color: theme.inputBg; border.color: fuOpTf.activeFocus ? theme.accent : theme.border
                                        TextInput {
                                            id: fuOpTf
                                            anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                                            horizontalAlignment: TextInput.AlignRight
                                            color: theme.textSecondary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter
                                            validator: IntValidator { bottom: 5; top: 100 }
                                            text: Math.round(panel.s("fuellOpazitaet", 0.3) * 100)
                                            Binding on text {
                                                when: !fuOpTf.activeFocus
                                                value: Math.round(panel.s("fuellOpazitaet", 0.3) * 100)
                                            }
                                            onEditingFinished: {
                                                var v = parseInt(text)
                                                if (!isNaN(v)) canvas.eigenschaftAktualisieren("fuellOpazitaet", Math.max(0.05, Math.min(1.0, v/100)))
                                            }
                                            Keys.onEscapePressed: { text = Math.round(panel.s("fuellOpazitaet", 0.3) * 100); focus = false }
                                        }
                                    }
                                    Text { text: "%"; color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            StilSlider {
                                width: panel.width - 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                von: 0.05; bis: 1.0; schritt: 0.05
                                wert: panel.s("fuellOpazitaet", 0.3)
                                onGeaendert: function(v) { canvas.eigenschaftAktualisieren("fuellOpazitaet", v) }
                            }
                        }
                    }
                }
            }

            // ================================================
            // ABSCHNITT: FORM (nur Rechteck)
            // ================================================
            Item {
                width: parent.width
                height: (panel.el && panel.el.typ === "rechteck") ? formCol.implicitHeight : 0
                visible: height > 0; clip: true

                Column {
                    id: formCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("FORM") }

                    FeldLabel { text: qsTr("Eckenradius\u2002") + Math.round(panel.s("eckenRadius", 0)) + "\u202Fmm" }
                    StilSlider {
                        height: 36
                        width: panel.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        von: 0; bis: 20; schritt: 1
                        wert: panel.s("eckenRadius", 0)
                        onGeaendert: function(v) { canvas.eigenschaftAktualisieren("eckenRadius", v) }
                    }
                }
            }

            // ================================================
            // ABSCHNITT: MEHRFACHAUSWAHL
            // ================================================
            Item {
                id: multiAuswahlItem
                width: parent.width

                readonly property bool hatSymbole: {
                    for (var i = 0; i < canvas.auswahl.length; i++) {
                        var idx = canvas.auswahl[i]
                        if (idx >= 0 && idx < canvas.elemente.length
                                && canvas.elemente[idx].typ === "symbol") return true
                    }
                    return false
                }

                height: (canvas.auswahl.length > 1 && hatSymbole) ? multiCol.implicitHeight : 0
                visible: height > 0; clip: true

                Column {
                    id: multiCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("ROTATION") }

                    FeldLabel { text: qsTr("Alle Symbole auf:") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Repeater {
                            model: [
                                { anzeige: "0°",   wert: 0   },
                                { anzeige: "90°",  wert: 90  },
                                { anzeige: "180°", wert: 180 },
                                { anzeige: "270°", wert: 270 }
                            ]
                            MiniButton { theme: theme;
                                label:   modelData.anzeige
                                breite:  40
                                onKlick: canvas.eigenschaftAktualisieren("rotation", modelData.wert)
                            }
                        }
                    }

                    Item { height: 4 }
                    FeldLabel { text: qsTr("Um Pivot drehen:") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        MiniButton { theme: theme; label: qsTr("↺ 90°");  breite: 56; tooltip: qsTr("90° gegen Uhrzeigersinn um linken Pin"); onKlick: canvas.multiRotationUmPivot(270) }
                        MiniButton { theme: theme; label: qsTr("180°");   breite: 40; tooltip: qsTr("180° um linken Pin");                    onKlick: canvas.multiRotationUmPivot(180) }
                        MiniButton { theme: theme; label: qsTr("90° ↻");  breite: 56; tooltip: qsTr("90° im Uhrzeigersinn um linken Pin");    onKlick: canvas.multiRotationUmPivot(90)  }
                    }
                    Item { height: 8 }
                }
            }

            // ================================================
            // ABSCHNITT: SYMBOL (nur Symbole)
            // ================================================
            Item {
                width: parent.width
                height: (panel.el && panel.el.typ === "symbol"
                         && panel.el.symbolId !== "aderdefinition") ? symbolCol.implicitHeight : 0
                visible: height > 0; clip: true

                Column {
                    id: symbolCol
                    width: parent.width; spacing: 0

                    // Spiegelung ist für Winkel und Treffpunkt sinnlos:
                    // alle Varianten sind durch die 4 Rotationen abgedeckt;
                    // spiegelX/Y würde nur die Grafik, nicht die Pinlogik betreffen
                    readonly property bool zeigeSpiegelung:
                        !(panel.el && (panel.el.symbolId === "querverweis"
                                    || panel.el.symbolId === "winkel"
                                    || panel.el.symbolId === "treffpunkt"
                                    || panel.el.symbolId === "klemme_anschluss"))
                    // treffpunkt_l: spiegelX ist sinnvoll (8 Varianten), daher in zeigeSpiegelung enthalten

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("SYMBOL") }

                    FeldLabel {
                        text: qsTr("Rotation")
                        visible: !(panel.el && panel.el.symbolId === "querverweis")
                    }
                    Row {
                        visible: !(panel.el && panel.el.symbolId === "querverweis")
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Repeater {
                            model: [
                                { anzeige: "0°",   wert: 0   },
                                { anzeige: "90°",  wert: 90  },
                                { anzeige: "180°", wert: 180 },
                                { anzeige: "270°", wert: 270 }
                            ]
                            MiniButton { theme: theme;
                                label:   modelData.anzeige
                                aktiv:   panel.s("rotation", 0) === modelData.wert
                                breite:  40
                                onKlick: canvas.eigenschaftAktualisieren("rotation", modelData.wert)
                            }
                        }
                    }
                    Item {
                        height: 8
                        visible: symbolCol.zeigeSpiegelung
                    }

                    FeldLabel {
                        text: qsTr("Spiegelung")
                        visible: symbolCol.zeigeSpiegelung
                    }
                    Row {
                        visible: symbolCol.zeigeSpiegelung
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        MiniButton { theme: theme;
                            label:   qsTr("\u2194 H")
                            tooltip: qsTr("Horizontal spiegeln (Taste X)")
                            aktiv:   panel.s("spiegelX", false)
                            breite:  56
                            onKlick: canvas.eigenschaftAktualisieren("spiegelX", !panel.s("spiegelX", false))
                        }
                        MiniButton { theme: theme;
                            label:   qsTr("\u2195 V")
                            tooltip: qsTr("Vertikal spiegeln (Taste Y)")
                            aktiv:   panel.s("spiegelY", false)
                            breite:  56
                            onKlick: canvas.eigenschaftAktualisieren("spiegelY", !panel.s("spiegelY", false))
                        }
                    }
                    Item {
                        height: 4
                        visible: symbolCol.zeigeSpiegelung
                    }

                }
            }

            // ================================================
            // ABSCHNITT: ADERDEFINITION
            // ================================================
            Item {
                id: adrSection
                width: parent.width
                height: (panel.el && panel.el.symbolId === "aderdefinition") ? adrCol.implicitHeight : 0
                visible: height > 0; clip: true

                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                Column {
                    id: adrCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("ADERDEFINITION") }

                    // Rotation: nur 0° (waagerecht) und 90° (senkrecht)
                    FeldLabel { text: qsTr("Rotation") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        MiniButton { theme: theme; label: "0°";  aktiv: panel.s("rotation", 0) === 0;  breite: 56
                            onKlick: canvas.eigenschaftAktualisieren("rotation", 0)  }
                        MiniButton { theme: theme; label: "90°"; aktiv: panel.s("rotation", 0) === 90; breite: 56
                            onKlick: canvas.eigenschaftAktualisieren("rotation", 90) }
                    }
                    Item { height: 8 }

                    InputField {
                        label: qsTr("Bezeichnung")
                        value: panel.el ? ((panel.el.extraDaten || {}).bezeichnung || "") : ""
                        theme: theme
                        onCommit: function(t) { adrSection.extraSetzen("bezeichnung", t) }
                    }

                    FeldLabel { text: qsTr("Aderfarbe (IEC 60757)") }
                    Flow {
                        width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4; bottomPadding: 4
                        Repeater {
                            model: ["BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK","GNYE"]
                            MiniButton { theme: theme;
                                label: modelData; breite: 38; hoehe: 24
                                aktiv: panel.el && (panel.el.extraDaten || {}).aderfarbe === modelData
                                onKlick: {
                                    var cur = panel.el ? ((panel.el.extraDaten || {}).aderfarbe || "") : ""
                                    parent.parent.parent.extraSetzen("aderfarbe",
                                        cur === modelData ? "" : modelData)
                                }
                            }
                        }
                    }

                    FeldLabel { text: qsTr("Querschnitt mm²") }
                    Flow {
                        width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4; bottomPadding: 4
                        Repeater {
                            model: [0.14, 0.25, 0.34, 0.5, 0.75, 1.0, 1.5, 2.5, 4.0, 6.0,
                                    10.0, 16.0, 25.0, 35.0, 50.0, 70.0, 95.0, 120.0, 150.0,
                                    185.0, 240.0, 300.0]
                            MiniButton { theme: theme;
                                label: modelData + ""; breite: 40; hoehe: 24
                                aktiv: {
                                    var q = panel.el ? ((panel.el.extraDaten || {}).querschnitt_mm2 || 0) : 0
                                    return Math.abs(q - modelData) < 0.01
                                }
                                onKlick: {
                                    var q = panel.el ? ((panel.el.extraDaten || {}).querschnitt_mm2 || 0) : 0
                                    parent.parent.parent.extraSetzen("querschnitt_mm2",
                                        Math.abs(q - modelData) < 0.01 ? 0 : modelData)
                                }
                            }
                        }
                    }

                    InputField {
                        label: qsTr("Länge (m)")
                        value: { var v = panel.el ? ((panel.el.extraDaten || {}).laenge_m || 0) : 0; return v > 0 ? (v + "").replace('.', ',') : "" }
                        theme: theme
                        onCommit: function(t) { var v = parseFloat(t.replace(',', '.')); adrSection.extraSetzen("laenge_m", isNaN(v) ? 0 : v) }
                    }
                    Item { height: 4 }
                }
            }

            // ABSCHNITT: KLEMMEN-ANSCHLUSS
            EpKlemmenAnschlussSection { canvas: canvas; panel: panel; theme: theme }

            // ================================================
            // ABSCHNITT: STECKVERBINDER (stecker / buchse)
            // ================================================
            Item {
                width: parent.width
                height: (panel.el && (panel.el.symbolId === "stecker" || panel.el.symbolId === "buchse"))
                        ? svCol.implicitHeight : 0
                visible: height > 0; clip: true

                Column {
                    id: svCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("STECKVERBINDER") }

                    // ── Anschlusstyp ─────────────────────────────
                    FeldLabel { text: qsTr("Anschlusstyp") }
                    ComboBox {
                        width: parent.width - 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        model: [
                            qsTr("Schraubanschluss"),
                            qsTr("Federklemmung"),
                            qsTr("Crimp"),
                            qsTr("Löt")
                        ]
                        property var _keys: ["schraub", "feder", "crimp", "loet"]
                        currentIndex: {
                            var t = (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.svAnschlusstyp || "schraub") : "schraub"
                            var idx = _keys.indexOf(t)
                            return idx >= 0 ? idx : 0
                        }
                        onActivated: {
                            if (!panel.el) return
                            var ed = panel.el.extraDaten || {}
                            ed.svAnschlusstyp = _keys[currentIndex]
                            canvas.eigenschaftAktualisieren("extraDaten", ed)
                        }
                    }

                    // ── Aderquerschnitt min / max ────────────────
                    FeldLabel { text: qsTr("Querschnitt (mm²)") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        TextField {
                            width: 72
                            placeholderText: "min"
                            text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svQsMin !== undefined)
                                  ? String(panel.el.extraDaten.svQsMin).replace(".", ",") : ""
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onEditingFinished: {
                                if (!panel.el) return
                                var v = parseFloat(text.replace(",", "."))
                                if (isNaN(v)) return
                                var ed = panel.el.extraDaten || {}
                                ed.svQsMin = v
                                canvas.eigenschaftAktualisieren("extraDaten", ed)
                            }
                        }
                        Text {
                            text: "–"
                            anchors.verticalCenter: parent.verticalCenter
                            color: theme.textSecondary; font.pixelSize: 12
                        }
                        TextField {
                            width: 72
                            placeholderText: "max"
                            text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svQsMax !== undefined)
                                  ? String(panel.el.extraDaten.svQsMax).replace(".", ",") : ""
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onEditingFinished: {
                                if (!panel.el) return
                                var v = parseFloat(text.replace(",", "."))
                                if (isNaN(v)) return
                                var ed = panel.el.extraDaten || {}
                                ed.svQsMax = v
                                canvas.eigenschaftAktualisieren("extraDaten", ed)
                            }
                        }
                    }

                    // ── Kabeldurchmesser max ─────────────────────
                    FeldLabel { text: qsTr("Kabeldurchmesser max (mm)") }
                    TextField {
                        width: parent.width - 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        placeholderText: "z. B. 8,5"
                        text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.svKabelDmMax !== undefined)
                              ? String(panel.el.extraDaten.svKabelDmMax).replace(".", ",") : ""
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        onEditingFinished: {
                            if (!panel.el) return
                            var v = parseFloat(text.replace(",", "."))
                            if (isNaN(v)) return
                            var ed = panel.el.extraDaten || {}
                            ed.svKabelDmMax = v
                            canvas.eigenschaftAktualisieren("extraDaten", ed)
                        }
                    }

                    Item { height: 4 }
                }
            }

            // ================================================
            // ABSCHNITT: BILD (nur Bild-Elemente)
            // ================================================
            Item {
                width: parent.width
                height: (panel.el && panel.el.typ === "bild") ? bildCol.implicitHeight : 0
                visible: height > 0; clip: true

                Column {
                    id: bildCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("BILD") }

                    // ── Rotation (freier Winkel) ──────────────
                    FeldLabel { text: qsTr("Rotation") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Repeater {
                            model: [
                                { anzeige: "0°",   wert: 0   },
                                { anzeige: "90°",  wert: 90  },
                                { anzeige: "180°", wert: 180 },
                                { anzeige: "270°", wert: 270 }
                            ]
                            MiniButton { theme: theme;
                                label:   modelData.anzeige
                                aktiv:   panel.s("rotation", 0) === modelData.wert
                                breite:  40
                                onKlick: canvas.eigenschaftAktualisieren("rotation", modelData.wert)
                            }
                        }
                    }
                    Item { height: 4 }

                    // Freier Winkel
                    Item {
                        width: panel.width; height: 28
                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: qsTr("Freier Winkel"); color: theme.panelMid; font.pixelSize: 10
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 3
                            Rectangle {
                                width: 48; height: 22; radius: 3
                                color: theme.inputBg; border.color: bildRotTf.activeFocus ? theme.accent : theme.border
                                TextInput {
                                    id: bildRotTf
                                    anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                                    horizontalAlignment: TextInput.AlignRight
                                    color: theme.textSecondary; font.pixelSize: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    validator: DoubleValidator {
                                        bottom: 0; top: 359.9; decimals: 1
                                        notation: DoubleValidator.StandardNotation
                                    }
                                    text: panel.s("rotation", 0).toFixed(1)
                                    Binding on text {
                                        when: !bildRotTf.activeFocus
                                        value: panel.s("rotation", 0).toFixed(1)
                                    }
                                    onEditingFinished: {
                                        var v = parseFloat(text)
                                        if (!isNaN(v)) canvas.eigenschaftAktualisieren("rotation", ((v % 360) + 360) % 360)
                                    }
                                    Keys.onEscapePressed: { text = panel.s("rotation", 0).toFixed(1); focus = false }
                                }
                            }
                            Text { text: "°"; color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Item { height: 6 }

                    // ── Spiegelung ────────────────────────────
                    FeldLabel { text: qsTr("Spiegelung") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        MiniButton { theme: theme;
                            label:   qsTr("\u2194 H")
                            tooltip: qsTr("Horizontal spiegeln (Taste X)")
                            aktiv:   panel.s("spiegelX", false)
                            breite:  56
                            onKlick: canvas.eigenschaftAktualisieren("spiegelX", !panel.s("spiegelX", false))
                        }
                        MiniButton { theme: theme;
                            label:   qsTr("\u2195 V")
                            tooltip: qsTr("Vertikal spiegeln (Taste Y)")
                            aktiv:   panel.s("spiegelY", false)
                            breite:  56
                            onKlick: canvas.eigenschaftAktualisieren("spiegelY", !panel.s("spiegelY", false))
                        }
                    }
                    Item { height: 8 }

                    // ── Seitenverhältnis ──────────────────────
                    Trennlinie {}
                    AbschnittTitel { text: qsTr("GRÖßENÄNDERUNG") }
                    Row {
                        leftPadding: 12; height: 32; spacing: 8
                        Rectangle {
                            width: 20; height: 20; radius: 4; anchors.verticalCenter: parent.verticalCenter
                            color: panel.s("proportional", false) ? theme.accent : theme.inputBg
                            border.color: theme.border
                            Text { anchors.centerIn: parent; text: qsTr("\u2713"); color: "#ffffff"
                                   font.pixelSize: 12; visible: panel.s("proportional", false) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: canvas.eigenschaftAktualisieren("proportional",
                                               !panel.s("proportional", false)) }
                        }
                        Text { text: qsTr("Seitenverhältnis beibehalten"); color: theme.textMuted
                               font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // ── Ausschnitt ────────────────────────────
                    Trennlinie {}
                    AbschnittTitel { text: qsTr("AUSSCHNITT") }

                    // Links
                    Item {
                        width: panel.width; height: 22
                        Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                               text: qsTr("Links\u2002") + Math.round(panel.s("ausschnittLinks", 0) * 100) + " %"
                               color: theme.panelMid; font.pixelSize: 10 }
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 22; height: 18; radius: 3; visible: panel.s("ausschnittLinks", 0) > 0
                            color: theme.inputBg; border.color: theme.border
                            Text { anchors.centerIn: parent; text: qsTr("\u2715"); font.pixelSize: 9; color: theme.accent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: canvas.eigenschaftAktualisieren("ausschnittLinks", 0) }
                        }
                    }
                    StilSlider { height: 36; width: panel.width-16; anchors.horizontalCenter: parent.horizontalCenter
                        von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittLinks", 0)
                        onGeaendert: function(v) { canvas.eigenschaftAktualisieren("ausschnittLinks", v) } }

                    // Rechts
                    Item {
                        width: panel.width; height: 22
                        Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                               text: qsTr("Rechts\u2002") + Math.round(panel.s("ausschnittRechts", 0) * 100) + " %"
                               color: theme.panelMid; font.pixelSize: 10 }
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 22; height: 18; radius: 3; visible: panel.s("ausschnittRechts", 0) > 0
                            color: theme.inputBg; border.color: theme.border
                            Text { anchors.centerIn: parent; text: qsTr("\u2715"); font.pixelSize: 9; color: theme.accent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: canvas.eigenschaftAktualisieren("ausschnittRechts", 0) }
                        }
                    }
                    StilSlider { height: 36; width: panel.width-16; anchors.horizontalCenter: parent.horizontalCenter
                        von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittRechts", 0)
                        onGeaendert: function(v) { canvas.eigenschaftAktualisieren("ausschnittRechts", v) } }

                    // Oben
                    Item {
                        width: panel.width; height: 22
                        Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                               text: qsTr("Oben\u2002") + Math.round(panel.s("ausschnittOben", 0) * 100) + " %"
                               color: theme.panelMid; font.pixelSize: 10 }
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 22; height: 18; radius: 3; visible: panel.s("ausschnittOben", 0) > 0
                            color: theme.inputBg; border.color: theme.border
                            Text { anchors.centerIn: parent; text: qsTr("\u2715"); font.pixelSize: 9; color: theme.accent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: canvas.eigenschaftAktualisieren("ausschnittOben", 0) }
                        }
                    }
                    StilSlider { height: 36; width: panel.width-16; anchors.horizontalCenter: parent.horizontalCenter
                        von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittOben", 0)
                        onGeaendert: function(v) { canvas.eigenschaftAktualisieren("ausschnittOben", v) } }

                    // Unten
                    Item {
                        width: panel.width; height: 22
                        Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                               text: qsTr("Unten\u2002") + Math.round(panel.s("ausschnittUnten", 0) * 100) + " %"
                               color: theme.panelMid; font.pixelSize: 10 }
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 22; height: 18; radius: 3; visible: panel.s("ausschnittUnten", 0) > 0
                            color: theme.inputBg; border.color: theme.border
                            Text { anchors.centerIn: parent; text: qsTr("\u2715"); font.pixelSize: 9; color: theme.accent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: canvas.eigenschaftAktualisieren("ausschnittUnten", 0) }
                        }
                    }
                    StilSlider { height: 36; width: panel.width-16; anchors.horizontalCenter: parent.horizontalCenter
                        von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittUnten", 0)
                        onGeaendert: function(v) { canvas.eigenschaftAktualisieren("ausschnittUnten", v) } }

                    Item { height: 4 }
                }
            }

            // ================================================
            // ABSCHNITT: TEXT-INHALT (nur Text-Elemente)
            // ================================================
            Item {
                width: parent.width
                height: (panel.el && panel.el.typ === "text") ? textCol.implicitHeight : 0
                visible: height > 0; clip: true

                Column {
                    id: textCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("TEXT") }

                    // ── Inhalt ──────────────────────────────
                    FeldLabel { text: qsTr("Inhalt (Shift + Enter = neue Zeile)") }
                    Rectangle {
                        width: panel.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: txtEdit.implicitHeight + 10
                        color: theme.inputBg; radius: 3
                        border.color: txtEdit.activeFocus ? theme.accent : theme.border

                        TextEdit {
                            id: txtEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            wrapMode: TextEdit.NoWrap
                            text: panel.s("textInhalt", "")
                            Binding on text {
                                when: !txtEdit.activeFocus
                                value: panel.s("textInhalt", "")
                            }
                            Keys.onReturnPressed: function(event) {
                                // Shift+Enter = neue Zeile, Enter allein = übernehmen
                                if (event.modifiers & Qt.ShiftModifier) {
                                    event.accepted = false
                                } else {
                                    var t = text.replace(/^\n+|\n+$/g, "").trim()
                                    if (t !== "") canvas.eigenschaftAktualisieren("textInhalt", t)
                                    focus = false
                                    event.accepted = true
                                }
                            }
                            Keys.onEscapePressed: { text = panel.s("textInhalt", ""); focus = false }
                            onEditingFinished: {
                                var t = text.replace(/^\n+|\n+$/g, "").trim()
                                if (t !== "") canvas.eigenschaftAktualisieren("textInhalt", t)
                            }
                        }
                    }
                    Item { height: 6 }

                    // ── Ausrichtung ──────────────────────────
                    FeldLabel { text: qsTr("Ausrichtung") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Repeater {
                            model: [
                                { anzeige: "\u25C4 Links",    wert: "links"  },
                                { anzeige: "\u25C4\u25BA Mitte",  wert: "mitte"  },
                                { anzeige: "Rechts \u25BA", wert: "rechts" }
                            ]
                            MiniButton { theme: theme;
                                label:   modelData.anzeige
                                aktiv:   panel.s("textAusrichtung", "links") === modelData.wert
                                breite:  52
                                onKlick: canvas.eigenschaftAktualisieren("textAusrichtung", modelData.wert)
                            }
                        }
                    }
                    Item { height: 6 }

                    // ── Einpassen ────────────────────────────
                    Row {
                        leftPadding: 12; height: 30; spacing: 8
                        Rectangle {
                            width: 20; height: 20; radius: 4; anchors.verticalCenter: parent.verticalCenter
                            color: panel.s("textEinpassen", false) ? theme.accent : theme.inputBg
                            border.color: theme.border
                            Text { anchors.centerIn: parent; text: qsTr("\u2713"); color: "#ffffff"
                                   font.pixelSize: 12; visible: panel.s("textEinpassen", false) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: canvas.eigenschaftAktualisieren("textEinpassen",
                                               !panel.s("textEinpassen", false)) }
                        }
                        Text { text: qsTr("Text in Rahmen einpassen"); color: theme.textMuted; font.pixelSize: 11
                               anchors.verticalCenter: parent.verticalCenter }
                    }
                    Item { height: 6 }

                    // ── Richtung (normgerecht: max. 90°, nie kopfstehend) ──
                    FeldLabel { text: qsTr("Richtung") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        // Waagrecht: 0° oder 180° → rendert als 0° (normal)
                        MiniButton { theme: theme;
                            label:   qsTr("\u2192 Waagrecht")
                            aktiv:   (panel.s("rotation", 0) % 180) === 0
                            breite:  86
                            onKlick: canvas.eigenschaftAktualisieren("rotation", 0)
                        }
                        // Senkrecht: 90° oder 270° → rendert als –90° (von rechts lesbar)
                        MiniButton { theme: theme;
                            label:   qsTr("\u2191 Senkrecht")
                            aktiv:   (panel.s("rotation", 0) % 180) !== 0
                            breite:  86
                            onKlick: canvas.eigenschaftAktualisieren("rotation", 90)
                        }
                    }
                    Item { height: 4 }
                }
            }

            // ================================================
            // ================================================
            // ABSCHNITT: NOTIZ
            // ================================================
            Item {
                width: parent.width
                height: (panel.el && panel.el.typ === "notiz") ? notizCol.implicitHeight : 0
                visible: height > 0; clip: true

                Column {
                    id: notizCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("NOTIZ") }

                    FeldLabel { text: qsTr("Inhalt") }
                    Rectangle {
                        width: panel.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: notizEdit.implicitHeight + 10
                        color: theme.inputBg; radius: 3
                        border.color: notizEdit.activeFocus ? theme.accent : theme.border
                        TextEdit {
                            id: notizEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            wrapMode: TextEdit.WordWrap
                            text: panel.s("textInhalt", "")
                            Binding on text {
                                when: !notizEdit.activeFocus
                                value: panel.s("textInhalt", "")
                            }
                            Keys.onReturnPressed: function(event) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    event.accepted = false
                                } else {
                                    var t = text.replace(/^\n+|\n+$/g, "").trim()
                                    if (t !== "") canvas.eigenschaftAktualisieren("textInhalt", t)
                                    focus = false; event.accepted = true
                                }
                            }
                            Keys.onEscapePressed: { text = panel.s("textInhalt", ""); focus = false }
                            onEditingFinished: {
                                var t = text.replace(/^\n+|\n+$/g, "").trim()
                                if (t !== "") canvas.eigenschaftAktualisieren("textInhalt", t)
                            }
                        }
                    }
                    Item { height: 6 }

                    FeldLabel { text: qsTr("Hintergrundfarbe") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Repeater {
                            model: ["#1a1a00","#001a00","#001a1a","#1a001a","#1a0a00","#0a0a18"]
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                color: modelData
                                border.color: (panel.s("fuellFarbe","#1a1a00") === modelData)
                                              ? theme.accent : theme.border
                                border.width: (panel.s("fuellFarbe","#1a1a00") === modelData) ? 2 : 1
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: canvas.eigenschaftAktualisieren("fuellFarbe", modelData)
                                }
                            }
                        }
                    }
                    Item { height: 8 }
                }
            }

            // ================================================
            // ABSCHNITT: MAßE
            // ================================================
            Trennlinie {}
            AbschnittTitel { text: qsTr("MA\u00dfe") }

            // Linie: X1/Y1, X2/Y2, Länge
            Column {
                width: parent.width; spacing: 0
                visible: panel.el && panel.el.typ === "linie"

                MassField {
                    label: "X1"; einheit: "mm"
                    wert: panel.el ? +(panel.el.x1 / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) { canvas.eigenschaftAktualisieren("x1", v * canvas.mmToPx) }
                }
                MassField {
                    label: "Y1"; einheit: "mm"
                    wert: panel.el ? +(panel.el.y1 / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) { canvas.eigenschaftAktualisieren("y1", v * canvas.mmToPx) }
                }
                MassField {
                    label: "X2"; einheit: "mm"
                    wert: panel.el ? +(panel.el.x2 / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) { canvas.eigenschaftAktualisieren("x2", v * canvas.mmToPx) }
                }
                MassField {
                    label: "Y2"; einheit: "mm"
                    wert: panel.el ? +(panel.el.y2 / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) { canvas.eigenschaftAktualisieren("y2", v * canvas.mmToPx) }
                }
                MassField {
                    label: qsTr("Länge"); einheit: "mm"
                    wert: {
                        if (!panel.el) return 0
                        var dx = panel.el.x2 - panel.el.x1
                        var dy = panel.el.y2 - panel.el.y1
                        return +((Math.sqrt(dx*dx + dy*dy) / canvas.mmToPx).toFixed(1))
                    }
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var dx = panel.el.x2 - panel.el.x1
                        var dy = panel.el.y2 - panel.el.y1
                        var len = Math.sqrt(dx*dx + dy*dy)
                        var newLen = v * canvas.mmToPx
                        if (len > 0.001)
                            canvas.eigenschaftenSetzen({ x2: panel.el.x1 + (dx/len)*newLen,
                                                         y2: panel.el.y1 + (dy/len)*newLen })
                        else
                            canvas.eigenschaftenSetzen({ x2: panel.el.x1 + newLen, y2: panel.el.y1 })
                    }
                }
            }

            // Rechteck: X/Y/Breite/Höhe
            Column {
                width: parent.width; spacing: 0
                visible: panel.el && panel.el.typ === "rechteck"

                MassField {
                    label: "X"; einheit: "mm"
                    wert: panel.el ? +(Math.min(panel.el.x1, panel.el.x2) / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var w = panel.el.x2 - panel.el.x1
                        canvas.eigenschaftenSetzen({ x1: v * canvas.mmToPx, x2: v * canvas.mmToPx + w })
                    }
                }
                MassField {
                    label: "Y"; einheit: "mm"
                    wert: panel.el ? +(Math.min(panel.el.y1, panel.el.y2) / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var h = panel.el.y2 - panel.el.y1
                        canvas.eigenschaftenSetzen({ y1: v * canvas.mmToPx, y2: v * canvas.mmToPx + h })
                    }
                }
                MassField {
                    label: qsTr("Breite"); einheit: "mm"
                    wert: panel.el ? +(Math.abs(panel.el.x2 - panel.el.x1) / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        canvas.eigenschaftAktualisieren("x2", panel.el.x1 + v * canvas.mmToPx)
                    }
                }
                MassField {
                    label: qsTr("Höhe"); einheit: "mm"
                    wert: panel.el ? +(Math.abs(panel.el.y2 - panel.el.y1) / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        canvas.eigenschaftAktualisieren("y2", panel.el.y1 + v * canvas.mmToPx)
                    }
                }
            }

            // Symbol: X/Y/Breite/Höhe (nicht für Querverweis)
            Column {
                width: parent.width; spacing: 0
                visible: panel.el && panel.el.typ === "symbol"
                         && panel.el.symbolId !== "querverweis"

                MassField {
                    label: "X"; einheit: "mm"
                    wert: panel.el ? +(Math.min(panel.el.x1, panel.el.x2) / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var w = panel.el.x2 - panel.el.x1
                        canvas.eigenschaftenSetzen({ x1: v * canvas.mmToPx, x2: v * canvas.mmToPx + w })
                    }
                }
                MassField {
                    label: "Y"; einheit: "mm"
                    wert: panel.el ? +(Math.min(panel.el.y1, panel.el.y2) / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var h = panel.el.y2 - panel.el.y1
                        canvas.eigenschaftenSetzen({ y1: v * canvas.mmToPx, y2: v * canvas.mmToPx + h })
                    }
                }
                MassField {
                    label: qsTr("Breite"); einheit: "mm"
                    wert: panel.el ? +(Math.abs(panel.el.x2 - panel.el.x1) / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        canvas.eigenschaftAktualisieren("x2", panel.el.x1 + v * canvas.mmToPx)
                    }
                }
                MassField {
                    label: qsTr("Höhe"); einheit: "mm"
                    wert: panel.el ? +(Math.abs(panel.el.y2 - panel.el.y1) / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        canvas.eigenschaftAktualisieren("y2", panel.el.y1 + v * canvas.mmToPx)
                    }
                }
            }

            // Text: X/Y Ankerposition
            Column {
                width: parent.width; spacing: 0
                visible: panel.el && panel.el.typ === "text"

                MassField {
                    label: "X"; einheit: "mm"
                    wert: panel.el ? +(panel.el.x1 / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var w = panel.el.x2 - panel.el.x1
                        canvas.eigenschaftenSetzen({ x1: v * canvas.mmToPx, x2: v * canvas.mmToPx + w })
                    }
                }
                MassField {
                    label: "Y"; einheit: "mm"
                    wert: panel.el ? +(panel.el.y1 / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var h = panel.el.y2 - panel.el.y1
                        canvas.eigenschaftenSetzen({ y1: v * canvas.mmToPx, y2: v * canvas.mmToPx + h })
                    }
                }
            }

            // Kreis: Mittelpunkt + Radius
            Column {
                width: parent.width; spacing: 0
                visible: panel.el && panel.el.typ === "kreis"

                MassField {
                    label: "X"; einheit: "mm"
                    wert: panel.el ? +(panel.el.x1 / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var dx = panel.el.x2 - panel.el.x1
                        var dy = panel.el.y2 - panel.el.y1
                        canvas.eigenschaftenSetzen({ x1: v * canvas.mmToPx, x2: v * canvas.mmToPx + dx, y2: panel.el.y1 + dy })
                    }
                }
                MassField {
                    label: "Y"; einheit: "mm"
                    wert: panel.el ? +(panel.el.y1 / canvas.mmToPx).toFixed(1) : 0
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        var dx = panel.el.x2 - panel.el.x1
                        var dy = panel.el.y2 - panel.el.y1
                        canvas.eigenschaftenSetzen({ y1: v * canvas.mmToPx, x2: panel.el.x1 + dx, y2: v * canvas.mmToPx + dy })
                    }
                }
                MassField {
                    label: qsTr("Radius"); einheit: "mm"
                    wert: {
                        if (!panel.el) return 0
                        var dx = panel.el.x2 - panel.el.x1
                        var dy = panel.el.y2 - panel.el.y1
                        return +((Math.sqrt(dx*dx + dy*dy) / canvas.mmToPx).toFixed(1))
                    }
                    onWertGeaendert: function(v) {
                        if (!panel.el) return
                        canvas.eigenschaftenSetzen({ x2: panel.el.x1 + v * canvas.mmToPx, y2: panel.el.y1 })
                    }
                }
            }

            // ================================================
            // ABSCHNITT: BETRIEBSMITTEL → EpBetriebsmittelSection.qml
            EpBetriebsmittelSection { canvas: canvas; panel: panel; theme: theme }

            // ABSCHNITT: QUERVERWEIS → EpQuerverweisSection.qml
            EpQuerverweisSection { canvas: canvas; panel: panel; theme: theme }

            // ================================================
            // ABSCHNITT: POTENZIAL (nur Potenzialpunkt)
            // ================================================
            Item {
                id: potItem
                width:   parent.width
                height:  (panel.el && panel.el.typ === "symbol"
                          && panel.el.symbolId === "potenzial")
                         ? potCol.implicitHeight : 0
                visible: height > 0
                clip:    true

                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                readonly property string aktuellSig: (panel.el && panel.el.extraDaten
                    && panel.el.extraDaten.signaltyp) ? panel.el.extraDaten.signaltyp : "neutral"

                Column {
                    id: potCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("SIGNALTYP") }

                    FeldLabel { text: qsTr("Potenzialklasse") }
                    Flow {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Repeater {
                            model: [
                                { key: "neutral",        label: qsTr("Neutral"),     farbe: "#4a9eff" },
                                { key: "power",          label: qsTr("Kraft"),       farbe: "#cc3300" },
                                { key: "pe",             label: "PE",          farbe: "#88cc00" },
                                { key: "n",              label: "N",           farbe: "#4488ff" },
                                { key: "input_digital",  label: "DI",          farbe: "#44aacc" },
                                { key: "output_digital", label: "DO",          farbe: "#aa44cc" },
                                { key: "input_analog",   label: "AI",          farbe: "#88bbff" },
                                { key: "output_analog",  label: "AO",          farbe: "#66ddaa" },
                                { key: "kommunikation",  label: qsTr("Komm."),       farbe: "#cc8800" }
                            ]
                            delegate: Rectangle {
                                width:  sigMa.implicitWidth + 16; height: 24; radius: 4
                                color:  potItem.aktuellSig === modelData.key
                                        ? Qt.rgba(
                                              parseInt(modelData.farbe.slice(1,3),16)/255,
                                              parseInt(modelData.farbe.slice(3,5),16)/255,
                                              parseInt(modelData.farbe.slice(5,7),16)/255,
                                              0.25)
                                        : theme.inputBg
                                border.color: potItem.aktuellSig === modelData.key
                                              ? modelData.farbe : theme.border
                                border.width: 1
                                Text {
                                    id: sigMa
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 10
                                    color: potItem.aktuellSig === modelData.key
                                           ? modelData.farbe : theme.panelMid
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: potItem.extraSetzen("signaltyp", modelData.key)
                                }
                            }
                        }
                    }
                    Item { height: 8 }
                }
            }

            // ================================================
            // ABSCHNITT: TREFFPUNKT
            // ================================================
            Item {
                id: treffItem
                width:   parent.width
                height:  (panel.el && panel.el.typ === "symbol"
                          && (panel.el.symbolId === "treffpunkt"
                           || panel.el.symbolId === "treffpunkt_l"))
                         ? treffCol.implicitHeight : 0
                visible: height > 0
                clip:    true

                readonly property string zielRichtung: {
                    var r = panel.s("rotation", 0)
                    if      (r === 0)   return "\u2193  Unten"
                    else if (r === 90)  return "\u2190  Links"
                    else if (r === 180) return "\u2191  Oben"
                    else                return "\u2192  Rechts"
                }

                Column {
                    id: treffCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel {
                        text: (panel.el && panel.el.symbolId === "treffpunkt_l")
                              ? "TREFFPUNKT L  (Quellen 90°)" : "TREFFPUNKT  (Quellen 180°)"
                    }

                    FeldLabel { text: qsTr("Ziel-Richtung") }
                    Rectangle {
                        width: parent.width - 16; height: 28; radius: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: theme.surface; border.color: theme.border; border.width: 1
                        Text {
                            anchors { fill: parent; leftMargin: 8 }
                            verticalAlignment: Text.AlignVCenter
                            text:           treffItem.zielRichtung
                            color:          theme.accent
                            font.pixelSize: 12
                        }
                    }
                    Item { height: 6 }
                }
            }

            // ABSCHNITT: GERÄTEANSCHLUSS → EpGeraeteanschlussSection.qml
            EpGeraeteanschlussSection { canvas: canvas; panel: panel; theme: theme }

            // ABSCHNITT: GERÄTEKASTEN
            EpGeraetekastenSection { canvas: canvas; panel: panel; theme: theme }

            // ABSCHNITT: STRUKTURKASTEN
            EpStrukturkastenSection { canvas: canvas; panel: panel; theme: theme }

            // ABSCHNITT: MAKROKASTEN
            EpMakrokastenSection { canvas: canvas; panel: panel; theme: theme }

            // ================================================
            // ABSCHNITT: KABELDEFINITIONSLINIE
            EpKabelDefinitionSection { canvas: canvas; panel: panel; theme: theme }

            // ABSCHNITT: REIHENFOLGE
            // ================================================
            Trennlinie {}
            AbschnittTitel { text: qsTr("REIHENFOLGE") }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 2; spacing: 4; bottomPadding: 4

                Repeater {
                    model: [
                        { anzeige: "\u2912 Ganz vorne",  richt: "ganzVorne",  tip: qsTr("In den Vordergrund (vor alle anderen)")  },
                        { anzeige: "\u2913 Ganz hinten", richt: "ganzHinten", tip: qsTr("In den Hintergrund (hinter alle anderen)") },
                        { anzeige: "\u2191 Eine vor",    richt: "vorne1",     tip: qsTr("Eine Ebene nach vorne")  },
                        { anzeige: "\u2193 Eine zurück", richt: "hinten1",    tip: qsTr("Eine Ebene nach hinten") }
                    ]
                    MiniButton { theme: theme;
                        label:   modelData.anzeige
                        tooltip: modelData.tip
                        breite:  90; hoehe: 26
                        onKlick: canvas.zReihenfolgeAendern(modelData.richt)
                    }
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

    // Einheitlicher Slider im App-Stil
    component StilSlider: Slider {
        id: ssRoot
        property real von:    0.0
        property real bis:    1.0
        property real schritt: 0.05
        property real wert:   0.5
        signal geaendert(real v)

        from: von; to: bis; stepSize: schritt; value: wert
        onMoved: ssRoot.geaendert(value)

        background: Rectangle {
            x: ssRoot.leftPadding; y: ssRoot.topPadding + ssRoot.availableHeight / 2 - 2
            width: ssRoot.availableWidth; height: 4; radius: 2; color: theme.border
            Rectangle {
                width: ssRoot.visualPosition * parent.width
                height: parent.height; radius: 2; color: theme.accent
            }
        }
        handle: Rectangle {
            x: ssRoot.leftPadding + ssRoot.visualPosition * ssRoot.availableWidth - 7
            y: ssRoot.topPadding  + ssRoot.availableHeight / 2 - 7
            width: 14; height: 14; radius: 7
            color: theme.accent; border.color: "#ffffff"; border.width: 1
        }
    }

    // Beschriftetes Eingabefeld für Maßangaben
    component MassField: Item {
        id: mfRoot
        property string label:   ""
        property string einheit: ""
        property real   wert:    0
        signal wertGeaendert(real wert)

        width: panel.width; height: 28

        Row {
            anchors { left: mfRoot.left; leftMargin: 12; verticalCenter: mfRoot.verticalCenter }
            spacing: 8

            Text {
                text: mfRoot.label; width: 56
                color: theme.borderLight; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
                width: 76; height: 22; radius: 4
                color: theme.inputBg; border.color: tf.activeFocus ? theme.accent : theme.border
                anchors.verticalCenter: parent.verticalCenter

                TextInput {
                    id: tf
                    anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                    color: theme.textSecondary; font.pixelSize: 11; verticalAlignment: TextInput.AlignVCenter
                    validator: DoubleValidator { bottom: -9999; top: 9999; decimals: 1; notation: DoubleValidator.StandardNotation }

                    text: mfRoot.wert.toFixed(1)

                    // Wert von außen aktualisieren wenn nicht im Fokus
                    Binding on text {
                        when: !tf.activeFocus
                        value: mfRoot.wert.toFixed(1)
                    }

                    onEditingFinished: {
                        var v = parseFloat(text)
                        if (!isNaN(v)) mfRoot.wertGeaendert(v)
                    }
                    Keys.onEscapePressed: { text = mfRoot.wert.toFixed(1); focus = false }
                }
            }
            Text {
                text: mfRoot.einheit
                color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Ausschnitt-Zeile: Label + Prozentanzeige + Reset + Slider
    component AusschnittZeile: Column {
        property string feldKey:   ""
        property string feldLabel: ""

        readonly property real wert: panel.s(feldKey, 0)

        width: panel.width; spacing: 0

        Item {
            width: panel.width; height: 22
            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: feldLabel + "\u2002" + Math.round(wert * 100) + " %"
                color: theme.panelMid; font.pixelSize: 10
            }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3
                visible: wert > 0
                color: azResetMa.containsMouse ? theme.border : theme.inputBg
                border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("\u2715"); font.pixelSize: 9; color: theme.accent }
                MouseArea {
                    id: azResetMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: canvas.eigenschaftAktualisieren(feldKey, 0)
                }
            }
        }
        StilSlider {
            width: panel.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01
            wert: parent.wert
            onGeaendert: function(v) { canvas.eigenschaftAktualisieren(feldKey, v) }
        }
        Item { height: 2 }
    }

    // Schrittweiser Schriftgrößen-Selektor (◄ 2.5 mm ►)
    // Verwendung: wert binden, onWertGeaendert auswerten.
    component SchriftgrosseSelektor: Item {
        id: sgRoot
        property real wert: 2.5
        signal wertGeaendert(real neuerWert)

        readonly property var  schritte: [1.5, 2.0, 2.5, 3.5, 5.0, 7.0, 10.0, 15.0, 20.0, 30.0, 40.0]
        readonly property int  aktIdx: {
            var best = 0, bestD = 9999
            for (var i = 0; i < schritte.length; i++) {
                var d = Math.abs(schritte[i] - wert)
                if (d < bestD) { bestD = d; best = i }
            }
            return best
        }

        width: parent.width; height: 32

        Row {
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgKlMa.containsMouse ? theme.border : theme.inputBg
                border.color: sgRoot.aktIdx > 0 ? theme.border : theme.divider
                Text { anchors.centerIn: parent; text: qsTr("\u25C4"); font.pixelSize: 11
                       color: sgRoot.aktIdx > 0 ? theme.accent : theme.borderDark }
                MouseArea {
                    id: sgKlMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; enabled: sgRoot.aktIdx > 0
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx - 1])
                }
            }
            Rectangle {
                width: 60; height: 28; radius: 4
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; color: theme.textSecondary; font.pixelSize: 11
                       text: sgRoot.wert.toFixed(1) + " mm" }
            }
            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgGrMa.containsMouse ? theme.border : theme.inputBg
                border.color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? theme.border : theme.divider
                Text { anchors.centerIn: parent; text: qsTr("\u25BA"); font.pixelSize: 11
                       color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? theme.accent : theme.borderDark }
                MouseArea {
                    id: sgGrMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: sgRoot.aktIdx < sgRoot.schritte.length - 1
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx + 1])
                }
            }
        }
    }


    DebugLabel { panelName: qsTr("Eigenschaften-Panel"); visible: panel.debug }
}
