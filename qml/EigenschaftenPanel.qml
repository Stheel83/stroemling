import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

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
                    FeldLabel { text: qsTr("Bezeichnung") }
                    Item {
                        width: panel.width; height: 30
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12
                                      verticalCenter: parent.verticalCenter }
                            height: 24; radius: 4
                            color: theme.inputBg; border.color: vbBezTf.activeFocus ? theme.accent : theme.border
                            TextInput {
                                id: vbBezTf
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                color: theme.textSecondary; font.pixelSize: 11; verticalAlignment: TextInput.AlignVCenter
                                text: panel.verbindung ? (panel.verbindung.bezeichnung || "") : ""
                                Binding on text { when: !vbBezTf.activeFocus
                                    value: panel.verbindung ? (panel.verbindung.bezeichnung || "") : "" }
                                onEditingFinished: canvas.verbindungAnnotationAktualisieren("bezeichnung", text)
                                Keys.onEscapePressed: { focus = false }
                            }
                        }
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
            Flow {
                width: panel.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                visible: !panel.el || panel.el.typ !== "bild"
                height: visible ? implicitHeight : 0

                Repeater {
                    model: panel.farbpalette
                    Rectangle {
                        width: 20; height: 20; radius: 10; color: modelData
                        border.color: panel.s("strichFarbe", theme.accent) === modelData ? "#ffffff" : theme.borderDark
                        border.width: panel.s("strichFarbe", theme.accent) === modelData ? 2 : 1
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: canvas.eigenschaftAktualisieren("strichFarbe", modelData)
                            ToolTip.visible: containsMouse
                            ToolTip.text:    modelData
                            ToolTip.delay:   400
                        }
                    }
                }
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
                            MiniButton {
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
                    MiniButton {
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
                            Flow {
                                width: panel.width - 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 5
                                Repeater {
                                    model: panel.farbpalette
                                    Rectangle {
                                        width: 20; height: 20; radius: 10; color: modelData
                                        border.color: panel.s("fuellFarbe", theme.activeItemAlt) === modelData ? "#ffffff" : theme.borderDark
                                        border.width: panel.s("fuellFarbe", theme.activeItemAlt) === modelData ? 2 : 1
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: canvas.eigenschaftAktualisieren("fuellFarbe", modelData)
                                        }
                                    }
                                }
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
                            MiniButton {
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
                        MiniButton { label: qsTr("↺ 90°");  breite: 56; tooltip: qsTr("90° gegen Uhrzeigersinn um linken Pin"); onKlick: canvas.multiRotationUmPivot(270) }
                        MiniButton { label: qsTr("180°");   breite: 40; tooltip: qsTr("180° um linken Pin");                    onKlick: canvas.multiRotationUmPivot(180) }
                        MiniButton { label: qsTr("90° ↻");  breite: 56; tooltip: qsTr("90° im Uhrzeigersinn um linken Pin");    onKlick: canvas.multiRotationUmPivot(90)  }
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
                            MiniButton {
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
                        MiniButton {
                            label:   qsTr("\u2194 H")
                            tooltip: qsTr("Horizontal spiegeln (Taste X)")
                            aktiv:   panel.s("spiegelX", false)
                            breite:  56
                            onKlick: canvas.eigenschaftAktualisieren("spiegelX", !panel.s("spiegelX", false))
                        }
                        MiniButton {
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
                        MiniButton { label: "0°";  aktiv: panel.s("rotation", 0) === 0;  breite: 56
                            onKlick: canvas.eigenschaftAktualisieren("rotation", 0)  }
                        MiniButton { label: "90°"; aktiv: panel.s("rotation", 0) === 90; breite: 56
                            onKlick: canvas.eigenschaftAktualisieren("rotation", 90) }
                    }
                    Item { height: 8 }

                    FeldLabel { text: qsTr("Bezeichnung") }
                    Item {
                        width: parent.width; height: 30
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12
                                      verticalCenter: parent.verticalCenter }
                            height: 24; radius: 4
                            color: theme.inputBg; border.color: adrBezTf.activeFocus ? theme.accent : theme.border
                            TextInput {
                                id: adrBezTf
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                color: theme.textSecondary; font.pixelSize: 11; verticalAlignment: TextInput.AlignVCenter
                                text: panel.el ? ((panel.el.extraDaten || {}).bezeichnung || "") : ""
                                Binding on text { when: !adrBezTf.activeFocus
                                    value: panel.el ? ((panel.el.extraDaten || {}).bezeichnung || "") : "" }
                                onEditingFinished: parent.parent.parent.parent.extraSetzen("bezeichnung", text)
                                Keys.onEscapePressed: { focus = false }
                            }
                        }
                    }

                    FeldLabel { text: qsTr("Aderfarbe (IEC 60757)") }
                    Flow {
                        width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4; bottomPadding: 4
                        Repeater {
                            model: ["BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK","GNYE"]
                            MiniButton {
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
                            MiniButton {
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

                    FeldLabel { text: qsTr("Länge (m)") }
                    Item {
                        width: parent.width; height: 30
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12
                                      verticalCenter: parent.verticalCenter }
                            height: 24; radius: 4
                            color: theme.inputBg; border.color: adrLaengeTf.activeFocus ? theme.accent : theme.border
                            TextInput {
                                id: adrLaengeTf
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                color: theme.textSecondary; font.pixelSize: 11; verticalAlignment: TextInput.AlignVCenter
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                text: {
                                    var v = panel.el ? ((panel.el.extraDaten || {}).laenge_m || 0) : 0
                                    return v > 0 ? (v + "").replace('.', ',') : ""
                                }
                                Binding on text { when: !adrLaengeTf.activeFocus
                                    value: {
                                        var v = panel.el ? ((panel.el.extraDaten || {}).laenge_m || 0) : 0
                                        return v > 0 ? (v + "").replace('.', ',') : ""
                                    }
                                }
                                onEditingFinished: {
                                    var v = parseFloat(text.replace(',', '.'))
                                    parent.parent.parent.parent.extraSetzen("laenge_m", isNaN(v) ? 0 : v)
                                }
                                Keys.onEscapePressed: { focus = false }
                            }
                        }
                    }
                    Item { height: 4 }
                }
            }

            // ================================================
            // ABSCHNITT: KLEMMEN-ANSCHLUSS
            // ================================================
            Item {
                width: parent.width
                height: (panel.el && panel.el.symbolId === "klemme_anschluss") ? kaCol.implicitHeight : 0
                visible: height > 0; clip: true

                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                Column {
                    id: kaCol
                    width: parent.width; spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("KLEMMEN-ANSCHLUSS") }

                    // ── Anschluss ───────────────────────────────
                    // Große Bezeichnung
                    Item {
                        width: parent.width; height: 36
                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            Text {
                                text: panel.el ? ((panel.el.extraDaten || {}).anschlussBezeichnung || "–") : "–"
                                font.pixelSize: 18; font.weight: Font.Bold; color: theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Rectangle {
                                visible: (panel.kaDetails && panel.kaDetails.anschlussSeite !== "")
                                width: 28; height: 18; radius: 3
                                color: theme.badge
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: panel.kaDetails ? (panel.kaDetails.anschlussSeite || "") : ""
                                    font.pixelSize: 10; color: theme.accent
                                }
                            }
                            Text {
                                visible: panel.kaDetails && panel.kaDetails.anschlussEbene !== undefined
                                         && panel.kaDetails.anschlussEbene !== null
                                text: panel.kaDetails ? qsTr("Eb. %1").arg(panel.kaDetails.anschlussEbene) : ""
                                font.pixelSize: 10; color: theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Platziermodus
                    Item {
                        width: parent.width; height: 20
                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: {
                                var m = panel.el ? ((panel.el.extraDaten || {}).platziermodus || "") : ""
                                if (m === "skizze")      return qsTr("Modus: Skizze")
                                if (m === "verknuepft") return qsTr("Modus: Verknüpft")
                                return m || ""
                            }
                            font.pixelSize: 10; color: theme.textSubtle
                        }
                    }

                    // BMK – editierbar, bei Modus "verknuepft" schreibgeschützt
                    FeldLabel { text: qsTr("BMK / Bezeichner") }
                    Item {
                        width: parent.width; height: 30
                        readonly property bool bmkReadOnly:
                            panel.el ? ((panel.el.extraDaten || {}).platziermodus === "verknuepft") : false
                        Rectangle {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12
                                      verticalCenter: parent.verticalCenter }
                            height: 24; radius: 4
                            color: theme.inputBg
                            border.color: parent.bmkReadOnly ? theme.border
                                          : (kaBmkTf.activeFocus ? theme.accent : theme.border)
                            opacity: parent.bmkReadOnly ? 0.6 : 1.0
                            TextInput {
                                id: kaBmkTf
                                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                readOnly: parent.parent.bmkReadOnly
                                color: parent.parent.bmkReadOnly ? theme.textMuted : theme.textSecondary
                                font.pixelSize: 11
                                verticalAlignment: TextInput.AlignVCenter
                                text: panel.el ? ((panel.el.extraDaten || {}).bmk || "") : ""
                                Binding on text {
                                    when:  !kaBmkTf.activeFocus
                                    value: panel.el ? ((panel.el.extraDaten || {}).bmk || "") : ""
                                }
                                onEditingFinished: if (!readOnly) parent.parent.parent.parent.extraSetzen("bmk", kaBmkTf.text)
                                Keys.onEscapePressed: { focus = false }
                            }
                        }
                    }

                    // ── Klemme (aus Bauteil-DB) ──────────────────
                    Item {
                        width: parent.width
                        height: (panel.kaDetails && panel.kaDetails.ok) ? klemmeInfoRow.implicitHeight : 0
                        clip: true

                        Column {
                            id: klemmeInfoRow
                            width: parent.width; spacing: 0

                            Trennlinie {}
                            AbschnittTitel { text: qsTr("KLEMME") }

                            // Typ
                            FeldLabel { text: qsTr("Typ") }
                            Item {
                                width: parent.width; height: 24
                                Text {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: {
                                        var t = panel.kaDetails ? (panel.kaDetails.anschlussTyp || "") : ""
                                        if (t === "schraube")     return qsTr("Schraubklemme")
                                        if (t === "federklemme")  return qsTr("Federklemme")
                                        if (t === "kaefigklemme") return qsTr("Käfigklemme")
                                        if (t === "stecker")      return qsTr("Stecker")
                                        return t || "–"
                                    }
                                    font.pixelSize: 12; color: theme.textSecondary
                                }
                            }

                            // Norm
                            FeldLabel { text: qsTr("Norm") }
                            Item {
                                width: parent.width; height: 24
                                Text {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: (panel.kaDetails && panel.kaDetails.norm) ? panel.kaDetails.norm : "–"
                                    font.pixelSize: 12; color: theme.textSecondary
                                }
                            }

                            // Breite (nur anzeigen wenn angegeben)
                            Item {
                                width: parent.width
                                height: (panel.kaDetails && panel.kaDetails.breiteMm > 0) ? 22 : 0
                                clip: true
                                Row {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    spacing: 6
                                    Text {
                                        text: qsTr("Breite:")
                                        font.pixelSize: 11; color: theme.textMuted
                                    }
                                    Text {
                                        text: panel.kaDetails ? (panel.kaDetails.breiteMm.toFixed(1) + " mm") : ""
                                        font.pixelSize: 11; color: theme.textSecondary
                                    }
                                }
                            }

                            // Querschnitte
                            Item {
                                width: parent.width
                                height: (panel.kaDetails && panel.kaDetails.querschnitte && panel.kaDetails.querschnitte.length > 0) ? querschnittCol.implicitHeight : 0
                                clip: true

                                Column {
                                    id: querschnittCol
                                    width: parent.width; spacing: 0

                                    FeldLabel { text: qsTr("Querschnitte") }

                                    Repeater {
                                        model: panel.kaDetails ? (panel.kaDetails.querschnitte || []) : []
                                        delegate: Item {
                                            width: parent.width; height: 22
                                            Row {
                                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                                spacing: 6
                                                Text {
                                                    width: 90
                                                    text: {
                                                        var t = modelData.adertyp || ""
                                                        if (t === "starr")         return qsTr("Starr")
                                                        if (t === "flexibel")      return qsTr("Flexibel")
                                                        if (t === "aenh_blank")    return qsTr("AEH blank")
                                                        if (t === "aenh_isoliert") return qsTr("AEH isoliert")
                                                        return t
                                                    }
                                                    font.pixelSize: 11; color: theme.textMuted
                                                }
                                                Text {
                                                    text: (modelData.minMm2 + "").replace('.', ',') + " – " +
                                                          (modelData.maxMm2 + "").replace('.', ',') + " mm²"
                                                    font.pixelSize: 11; color: theme.textSecondary
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Klemmen-Ebenenansicht (L7) ───────────────────────
                    Item {
                        width: parent.width
                        height: (panel.kaDetails && panel.kaDetails.ok
                                 && panel.kaDetails.ebenenAnzahl > 0)
                                ? vorschauBlock.implicitHeight : 0
                        clip: true

                        Column {
                            id: vorschauBlock
                            width: parent.width; spacing: 0

                            Trennlinie {}
                            AbschnittTitel { text: qsTr("KLEMMENAUFBAU") }

                            Item { width: 1; height: 8 }
                            KlemmenVorschau {
                                width: parent.width - 24
                                anchors.horizontalCenter: parent.horizontalCenter

                                klemme: panel.kaDetails ? {
                                    "ebenenAnzahl":    panel.kaDetails.ebenenAnzahl    || 1,
                                    "punkteSeitenA":   panel.kaDetails.punkteSeitenA   || 1,
                                    "punkteSeitenB":   panel.kaDetails.punkteSeitenB   || 1,
                                    "fussKontaktPe":   panel.kaDetails.fussKontaktPe   || false,
                                    "stegbrueckeFaehig": panel.kaDetails.stegbrueckeFaehig || false
                                } : ({})
                                bruecken:              (panel.kaDetails && panel.kaDetails.bruecken) ? panel.kaDetails.bruecken : []
                                markierteBezeichnung:  panel.el ? ((panel.el.extraDaten || {}).anschlussBezeichnung || "") : ""
                                zeigeBezeichnungen:    true
                                akzentFarbe:           theme.accent
                            }
                            Item { width: 1; height: 8 }
                        }
                    }

                    Item { height: 4 }
                }
            }

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
                            MiniButton {
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
                        MiniButton {
                            label:   qsTr("\u2194 H")
                            tooltip: qsTr("Horizontal spiegeln (Taste X)")
                            aktiv:   panel.s("spiegelX", false)
                            breite:  56
                            onKlick: canvas.eigenschaftAktualisieren("spiegelX", !panel.s("spiegelX", false))
                        }
                        MiniButton {
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
                            MiniButton {
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
                        MiniButton {
                            label:   qsTr("\u2192 Waagrecht")
                            aktiv:   (panel.s("rotation", 0) % 180) === 0
                            breite:  86
                            onKlick: canvas.eigenschaftAktualisieren("rotation", 0)
                        }
                        // Senkrecht: 90° oder 270° → rendert als –90° (von rechts lesbar)
                        MiniButton {
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

                    FeldLabel { text: qsTr("Inhalt (Shift+Enter = neue Zeile)") }
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
                            wrapMode: TextEdit.NoWrap
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
            // ABSCHNITT: BETRIEBSMITTEL (alle Symbole außer
            //            Verbindungshelfer und Querverweis)
            // ================================================
            Item {
                id: bmkItem
                width: parent.width
                height: {
                    if (!panel.el || panel.el.typ !== "symbol") return 0
                    var sid = panel.el.symbolId || ""
                    var verbEl = ["winkel","treffpunkt","treffpunkt_l","geraeteanschluss","unterbrechung","querverweis","aderdefinition"]
                    for (var k = 0; k < verbEl.length; k++) if (sid === verbEl[k]) return 0
                    return bmkCol.implicitHeight
                }
                visible: height > 0
                clip:    true

                // Hilfsfunktion: extraDaten-Kopie mit geändertem Schlüssel speichern
                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                Column {
                    id: bmkCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("BETRIEBSMITTEL") }

                    // ── BMK ──────────────────────────────────
                    FeldLabel { text: qsTr("Betriebsmittelkennzeichen (BMK)") }
                    Row {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Rectangle {
                            width: parent.width - 36
                            height: 28; color: theme.inputBg; radius: 3
                            border.color: bmkEdit.activeFocus ? theme.accent : theme.border

                            TextInput {
                                id: bmkEdit
                                anchors { fill: parent; margins: 5 }
                                color: theme.textSecondary; font.pixelSize: 11
                                verticalAlignment: TextInput.AlignVCenter

                                text: (panel.el && panel.el.extraDaten)
                                      ? (panel.el.extraDaten.bmk || "") : ""
                                Binding on text {
                                    when: !bmkEdit.activeFocus
                                    value: (panel.el && panel.el.extraDaten)
                                           ? (panel.el.extraDaten.bmk || "") : ""
                                }
                                onEditingFinished: bmkItem.extraSetzen("bmk", text.trim())
                                Keys.onEscapePressed: focus = false
                            }
                        }

                        // # = nächste freie Nummer vorschlagen
                        Rectangle {
                            width: 28; height: 28; radius: 3
                            color: autoMa.containsMouse ? theme.border : theme.inputBg
                            border.color: theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "#"; color: theme.accent; font.pixelSize: 13; font.bold: true
                            }
                            ToolTip.visible: autoMa.containsMouse
                            ToolTip.text: qsTr("Nächste freie Nummer vorschlagen")
                            ToolTip.delay: 400
                            MouseArea {
                                id: autoMa
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (canvas.projektId < 0) return
                                    var bmk = (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmk)
                                              ? panel.el.extraDaten.bmk : ""
                                    // Präfix = alles außer abschließende Ziffern
                                    var praefix = bmk.replace(/\d+$/, "")
                                    if (!praefix) praefix = "-?"
                                    var vorschlag = db.naechsteBmkNummer(canvas.projektId, praefix)
                                    bmkItem.extraSetzen("bmk", vorschlag)
                                }
                            }
                        }
                    }
                    Item { height: 6 }

                    // ── Verknüpfung (Haupt-/Nebenfunktion) ───────
                    FeldLabel { text: qsTr("Geräteverknüpfung") }
                    Item {
                        id: verknuepfungItem
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: verknuepfungCol.implicitHeight

                        property int bmId: (panel.el && panel.el.betriebsmittelId > 0)
                                           ? panel.el.betriebsmittelId : 0

                        // Cache-Buster: wird nach DB-schreibenden Aktionen inkrementiert
                        property int _refresh: 0

                        // Betriebsmittel-Info (kz, bezeichnung, hauptElementId)
                        property var bmInfo: {
                            _refresh
                            return bmId > 0 ? db.betriebsmittelInfo(bmId) : ({})
                        }

                        // Rolle dieses Elements im verknüpften Betriebsmittel
                        property bool istHauptfunktion: bmId > 0
                                                        && bmInfo.hauptElementId > 0
                                                        && bmInfo.hauptElementId === (panel.el ? panel.el.id : -1)
                        property bool hauptfunktionFehlt: bmId > 0 && (bmInfo.hauptElementId || 0) === 0

                        Column {
                            id: verknuepfungCol
                            width: parent.width
                            spacing: 4

                            // ── Status-Zeile ──────────────────────────
                            Rectangle {
                                width: parent.width; height: 28
                                color: theme.inputBg; radius: 3
                                border.color: {
                                    if (verknuepfungItem.istHauptfunktion) return theme.accent
                                    if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                                    return theme.border
                                }
                                Row {
                                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                    spacing: 6
                                    // Indikator-Punkt / Stern
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (!verknuepfungItem.bmId)          return "○"
                                            if (verknuepfungItem.istHauptfunktion) return "★"
                                            if (verknuepfungItem.hauptfunktionFehlt) return "⚠"
                                            return "◆"
                                        }
                                        font.pixelSize: 11
                                        color: {
                                            if (verknuepfungItem.istHauptfunktion)   return theme.accent
                                            if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                                            if (verknuepfungItem.bmId > 0)          return theme.textSecondary
                                            return theme.borderLight
                                        }
                                    }
                                    // BMK
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: verknuepfungItem.bmId > 0
                                              ? (verknuepfungItem.bmInfo.kz || "–") : ""
                                        font.pixelSize: 11; font.bold: verknuepfungItem.istHauptfunktion
                                        color: theme.accent
                                        visible: verknuepfungItem.bmId > 0
                                    }
                                    // Rollen-Label
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            if (!verknuepfungItem.bmId)              return qsTr("nicht verknüpft")
                                            if (verknuepfungItem.istHauptfunktion)   return qsTr("Hauptfunktion")
                                            if (verknuepfungItem.hauptfunktionFehlt) return qsTr("HF nicht platziert")
                                            return qsTr("Nebenfunktion")
                                        }
                                        font.pixelSize: 10
                                        color: {
                                            if (verknuepfungItem.istHauptfunktion)   return theme.accent
                                            if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                                            if (verknuepfungItem.bmId > 0)          return theme.textMuted
                                            return theme.borderLight
                                        }
                                    }
                                }
                            }

                            // ── Aktions-Buttons Zeile 1: Verknüpfen / Trennen ──
                            Row {
                                spacing: 4
                                Rectangle {
                                    width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                                    color: verknLinkMa.containsMouse ? theme.border : theme.inputBg
                                    border.color: theme.border
                                    Text { anchors.centerIn: parent; text: qsTr("Verknüpfen …")
                                           font.pixelSize: 10; color: theme.accent }
                                    MouseArea {
                                        id: verknLinkMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: dlgVerknuepfen.open()
                                    }
                                }
                                Rectangle {
                                    width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                                    color: verknTrennenMa.containsMouse ? theme.border : theme.inputBg
                                    border.color: theme.border
                                    opacity: verknuepfungItem.bmId > 0 ? 1.0 : 0.4
                                    Text { anchors.centerIn: parent; text: qsTr("Trennen")
                                           font.pixelSize: 10; color: theme.borderLight }
                                    MouseArea {
                                        id: verknTrennenMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        enabled: verknuepfungItem.bmId > 0
                                        onClicked: {
                                            db.grafikElementEntknuepfen(panel.el.id)
                                            canvas.eigenschaftAktualisieren("betriebsmittelId", 0)
                                        }
                                    }
                                }
                            }

                            // ── Aktions-Buttons Zeile 2: Hauptfunktion / BMK-Sync ──
                            Row {
                                visible: verknuepfungItem.bmId > 0
                                spacing: 4
                                Rectangle {
                                    width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                                    color: hfMa.containsMouse && !verknuepfungItem.istHauptfunktion
                                           ? theme.border : theme.inputBg
                                    border.color: verknuepfungItem.istHauptfunktion ? theme.accent : theme.border
                                    opacity: verknuepfungItem.istHauptfunktion ? 0.5 : 1.0
                                    Text {
                                        anchors.centerIn: parent
                                        text: "★ " + qsTr("Als HF festlegen")
                                        font.pixelSize: 10
                                        color: verknuepfungItem.istHauptfunktion ? theme.accent : theme.textMuted
                                    }
                                    MouseArea {
                                        id: hfMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        enabled: !verknuepfungItem.istHauptfunktion
                                        onClicked: {
                                            db.betriebsmittelHauptfunktionSetzen(
                                                verknuepfungItem.bmId, panel.el.id)
                                            verknuepfungItem._refresh++
                                            canvas.hfKarteAktualisieren()
                                        }
                                    }
                                }
                                Rectangle {
                                    width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                                    color: syncMa.containsMouse ? theme.border : theme.inputBg
                                    border.color: theme.border
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("BMK sync.")
                                        font.pixelSize: 10; color: theme.textMuted
                                    }
                                    ToolTip.visible: syncMa.containsMouse
                                    ToolTip.text:    qsTr("BMK aller verknüpften Elemente auf\n\"%1\" setzen").arg(
                                                         verknuepfungItem.bmInfo.kz || "")
                                    ToolTip.delay:   500
                                    MouseArea {
                                        id: syncMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            db.betriebsmittelBmkSynchronisieren(verknuepfungItem.bmId)
                                            canvas.seiteNeuLaden()
                                            verknuepfungItem._refresh++
                                        }
                                    }
                                }
                            }

                            // ── Mitglieder-Liste ──────────────────────
                            Column {
                                visible: verknuepfungItem.bmId > 0
                                width: parent.width
                                spacing: 1
                                Repeater {
                                    model: verknuepfungItem.bmId > 0
                                           ? db.betriebsmittelMitglieder(verknuepfungItem.bmId) : []
                                    delegate: Rectangle {
                                        width: verknuepfungItem.width; height: 22
                                        color: modelData.id === (panel.el ? panel.el.id : -1)
                                               ? theme.activeItemAlt : "transparent"
                                        radius: 2
                                        Row {
                                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                            spacing: 5
                                            // Aktuelles Element: Balken; Hauptfunktion: ★
                                            Rectangle {
                                                width: 3; height: 14; radius: 1
                                                color: modelData.id === (panel.el ? panel.el.id : -1)
                                                       ? theme.accent : "transparent"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: modelData.istHauptfunktion ? "★" : "◆"
                                                font.pixelSize: 9
                                                color: modelData.istHauptfunktion ? theme.accent : theme.borderLight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: modelData.symbolId || modelData.typ || "–"
                                                font.pixelSize: 9; color: theme.borderLight
                                                width: 52; elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: modelData.blattnummer || "–"
                                                font.pixelSize: 9; color: theme.textMuted
                                                width: 26; elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item { height: 4 }

                    // ── Kontakt: Anschlusskennzeichnung + Modifier ──────
                    Item {
                        id: kontaktItem
                        width: parent.width
                        readonly property var _KONTAKT_SYMS: [
                            "schliesser","oeffner","wechsler",
                            "taster_no","taster_nc","not_halt","bimetall_nc"
                        ]
                        readonly property bool _istKontakt: {
                            if (!panel.el || panel.el.typ !== "symbol") return false
                            var sid = panel.el.symbolId || ""
                            for (var k = 0; k < _KONTAKT_SYMS.length; k++)
                                if (sid === _KONTAKT_SYMS[k]) return true
                            return false
                        }
                        readonly property var _erw: {
                            var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                            return Array.isArray(ed.erweiterungen) ? ed.erweiterungen : []
                        }
                        height: _istKontakt ? kontaktCol.implicitHeight : 0
                        visible: height > 0; clip: true

                        function hatErw(key) {
                            return kontaktItem._erw.indexOf(key) >= 0
                        }
                        function toggleErw(key) {
                            var ed = panel.el && panel.el.extraDaten
                                     ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                            var arr = Array.isArray(ed.erweiterungen) ? ed.erweiterungen.slice() : []
                            var idx = arr.indexOf(key)
                            if (idx >= 0) arr.splice(idx, 1)
                            else          arr.push(key)
                            ed.erweiterungen = arr
                            canvas.eigenschaftAktualisieren("extraDaten", ed)
                        }

                        Column {
                            id: kontaktCol
                            width: parent.width
                            spacing: 0

                            Trennlinie {}
                            AbschnittTitel { text: qsTr("KONTAKT") }

                            // Anschlusskennzeichnung (z.B. 13/14, 21/22)
                            FeldLabel { text: qsTr("Anschlusskennzeichnung") }
                            Rectangle {
                                width: parent.width - 16; height: 28
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: theme.inputBg; radius: 3
                                border.color: ankEdit.activeFocus ? theme.accent : theme.border
                                TextInput {
                                    id: ankEdit
                                    anchors { fill: parent; margins: 5 }
                                    color: theme.textSecondary; font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: (panel.el && panel.el.extraDaten)
                                          ? (panel.el.extraDaten.anschlusskennzeichnung || "") : ""
                                    Binding on text {
                                        when: !ankEdit.activeFocus
                                        value: (panel.el && panel.el.extraDaten)
                                               ? (panel.el.extraDaten.anschlusskennzeichnung || "") : ""
                                    }
                                    onEditingFinished: bmkItem.extraSetzen("anschlusskennzeichnung", text.trim())
                                    Keys.onEscapePressed: focus = false
                                }
                            }
                            Item { height: 6 }

                            // Modifier-Checkboxen
                            FeldLabel { text: qsTr("Erweiterungen") }
                            Repeater {
                                model: [
                                    { key: "zeit_an",    label: qsTr("Anzugsverzögert")  },
                                    { key: "zeit_ab",    label: qsTr("Abfallverzögert")  },
                                    { key: "voreilung",  label: qsTr("Voreilung")         },
                                    { key: "nacheilung", label: qsTr("Nacheilung")        }
                                ]
                                Row {
                                    width: kontaktCol.width
                                    leftPadding: 12; height: 28; spacing: 8
                                    Rectangle {
                                        width: 18; height: 18; radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: kontaktItem.hatErw(modelData.key) ? theme.accent : theme.inputBg
                                        border.color: theme.border
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"; color: "#ffffff"; font.pixelSize: 11
                                            visible: kontaktItem.hatErw(modelData.key)
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: kontaktItem.toggleErw(modelData.key)
                                        }
                                    }
                                    Text {
                                        text: modelData.label
                                        color: theme.textMuted; font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                            Item { height: 4 }
                        }
                    }

                    // ── Beschriftungszeilen (Reihenfolge + Sichtbarkeit) ──
                    Trennlinie {}
                    AbschnittTitel { text: qsTr("BESCHRIFTUNGSZEILEN") }

                    // BMK-Hinweis (fest, nicht verschiebbar)
                    Item {
                        width: parent.width; height: 18
                        Text {
                            anchors { left: parent.left; leftMargin: 12
                                      verticalCenter: parent.verticalCenter }
                            text: qsTr("BMK  –  erste Zeile (fest)")
                            color: theme.borderLight; font.pixelSize: 10; font.italic: true
                        }
                    }

                    // Reorderable Freitext-Zeilen
                    Repeater {
                        id: ftRepeater
                        model: {
                            var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                            return ed.textReihenfolge || ["freitext1", "freitext2"]
                        }

                        Item {
                            id: ftZeileRoot
                            width:  bmkCol.width
                            height: ftZeileCol.implicitHeight

                            readonly property string ftKey:      modelData
                            readonly property int    ftPos:      index
                            readonly property bool   ftSichtbar: {
                                var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                                return ed[ftKey + "Sichtbar"] !== false
                            }
                            readonly property string ftLabel:    ftKey === "freitext1" ? "Typ / Bezeichnung" : "Bemerkung"
                            readonly property string ftWert: {
                                var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                                return ed[ftKey] || ""
                            }

                            function setWert(v) {
                                var ed = panel.el && panel.el.extraDaten
                                         ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                                ed[ftKey] = v
                                canvas.eigenschaftAktualisieren("extraDaten", ed)
                            }
                            function toggleSichtbar() {
                                var ed = panel.el && panel.el.extraDaten
                                         ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                                ed[ftKey + "Sichtbar"] = !ftSichtbar
                                canvas.eigenschaftAktualisieren("extraDaten", ed)
                            }
                            function verschiebeUm(delta) {
                                var ed  = panel.el && panel.el.extraDaten
                                          ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                                var arr = (ed.textReihenfolge || ["freitext1", "freitext2"]).slice()
                                var ziel = ftPos + delta
                                if (ziel < 0 || ziel >= arr.length) return
                                var tmp = arr[ziel]; arr[ziel] = arr[ftPos]; arr[ftPos] = tmp
                                ed.textReihenfolge = arr
                                canvas.eigenschaftAktualisieren("extraDaten", ed)
                            }

                            Column {
                                id: ftZeileCol
                                width: parent.width
                                spacing: 2

                                FeldLabel { text: ftZeileRoot.ftLabel }

                                Row {
                                    anchors { left: parent.left; leftMargin: 8
                                              right: parent.right; rightMargin: 8 }
                                    spacing: 4

                                    // Sichtbarkeit-Toggle
                                    Rectangle {
                                        width: 26; height: 26; radius: 3
                                        color: visMa.containsMouse ? theme.border : theme.inputBg
                                        border.color: theme.border
                                        ToolTip.visible: visMa.containsMouse
                                        ToolTip.text:    ftZeileRoot.ftSichtbar ? "Zeile ausblenden" : "Zeile einblenden"
                                        ToolTip.delay:   400
                                        Text {
                                            anchors.centerIn: parent
                                            text:  ftZeileRoot.ftSichtbar ? "\uD83D\uDC41" : "\u20E0"
                                            color: ftZeileRoot.ftSichtbar ? theme.accent : theme.borderDark
                                            font.pixelSize: 14
                                        }
                                        MouseArea {
                                            id: visMa; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: ftZeileRoot.toggleSichtbar()
                                        }
                                    }

                                    // Texteingabe
                                    Rectangle {
                                        width: parent.width - 26 - 22 - 22 - 3 * 4
                                        height: 26; radius: 3
                                        color: theme.inputBg
                                        border.color: ftEdit.activeFocus ? theme.accent : theme.border
                                        opacity: ftZeileRoot.ftSichtbar ? 1.0 : 0.45
                                        TextInput {
                                            id: ftEdit
                                            anchors { fill: parent; margins: 5 }
                                            color: theme.textSecondary; font.pixelSize: 11
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: ftZeileRoot.ftWert
                                            Binding on text {
                                                when: !ftEdit.activeFocus
                                                value: ftZeileRoot.ftWert
                                            }
                                            onEditingFinished: ftZeileRoot.setWert(text.trim())
                                            Keys.onEscapePressed: focus = false
                                        }
                                    }

                                    // Nach oben
                                    Rectangle {
                                        width: 22; height: 26; radius: 3
                                        color: upMa.containsMouse && ftZeileRoot.ftPos > 0
                                               ? theme.border : theme.inputBg
                                        border.color: ftZeileRoot.ftPos > 0 ? theme.border : theme.divider
                                        Text {
                                            anchors.centerIn: parent; text: qsTr("\u25B2"); font.pixelSize: 9
                                            color: ftZeileRoot.ftPos > 0 ? theme.accent : theme.borderDark
                                        }
                                        MouseArea {
                                            id: upMa; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: ftZeileRoot.ftPos > 0
                                            onClicked: ftZeileRoot.verschiebeUm(-1)
                                        }
                                    }

                                    // Nach unten
                                    Rectangle {
                                        width: 22; height: 26; radius: 3
                                        color: downMa.containsMouse
                                               && ftZeileRoot.ftPos < ftRepeater.count - 1
                                               ? theme.border : theme.inputBg
                                        border.color: ftZeileRoot.ftPos < ftRepeater.count - 1
                                                      ? theme.border : theme.divider
                                        Text {
                                            anchors.centerIn: parent; text: qsTr("\u25BC"); font.pixelSize: 9
                                            color: ftZeileRoot.ftPos < ftRepeater.count - 1
                                                   ? theme.accent : theme.borderDark
                                        }
                                        MouseArea {
                                            id: downMa; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: ftZeileRoot.ftPos < ftRepeater.count - 1
                                            onClicked: ftZeileRoot.verschiebeUm(1)
                                        }
                                    }
                                }
                                Item { height: 4 }
                            }
                        }
                    }
                    Item { height: 2 }

                    // ── Schriftgröße ──────────────────────────
                    Trennlinie {}
                    AbschnittTitel { text: qsTr("SCHRIFTGRÖSSE") }
                    SchriftgrosseSelektor {
                        wert: (panel.el && panel.el.extraDaten
                               && panel.el.extraDaten.schriftgroesse !== undefined)
                              ? panel.el.extraDaten.schriftgroesse : 2.5
                        onWertGeaendert: function(v) {
                            bmkItem.extraSetzen("schriftgroesse", v)
                        }
                    }

                    AbschnittTitel { text: qsTr("BESCHRIFTUNGSPOSITION") }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Column {
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Versatz X"); color: theme.panelMid; font.pixelSize: 10
                            }
                            Row {
                                spacing: 2
                                Rectangle {
                                    width: 52; height: 22; radius: 3
                                    color: theme.inputBg
                                    border.color: bmkOxTf.activeFocus ? theme.accent : theme.border
                                    TextInput {
                                        id: bmkOxTf
                                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                        horizontalAlignment: TextInput.AlignRight
                                        color: theme.textSecondary; font.pixelSize: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        validator: DoubleValidator {
                                            bottom: -999; top: 999; decimals: 1
                                            notation: DoubleValidator.StandardNotation
                                        }
                                        property real weltWert: (panel.el && panel.el.extraDaten
                                            && panel.el.extraDaten.bmkOffsetX !== undefined)
                                            ? panel.el.extraDaten.bmkOffsetX : 0
                                        text: (weltWert / canvas.mmToPx).toFixed(1)
                                        Binding on text {
                                            when: !bmkOxTf.activeFocus
                                            value: (bmkOxTf.weltWert / canvas.mmToPx).toFixed(1)
                                        }
                                        onEditingFinished: {
                                            var v = parseFloat(text)
                                            if (!isNaN(v))
                                                bmkItem.extraSetzen("bmkOffsetX", v * canvas.mmToPx)
                                        }
                                        Keys.onEscapePressed: focus = false
                                    }
                                }
                                Text { text: "mm"; color: theme.borderLight; font.pixelSize: 10
                                       anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        Column {
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Versatz Y"); color: theme.panelMid; font.pixelSize: 10
                            }
                            Row {
                                spacing: 2
                                Rectangle {
                                    width: 52; height: 22; radius: 3
                                    color: theme.inputBg
                                    border.color: bmkOyTf.activeFocus ? theme.accent : theme.border
                                    TextInput {
                                        id: bmkOyTf
                                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                        horizontalAlignment: TextInput.AlignRight
                                        color: theme.textSecondary; font.pixelSize: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        validator: DoubleValidator {
                                            bottom: -999; top: 999; decimals: 1
                                            notation: DoubleValidator.StandardNotation
                                        }
                                        property real weltWert: (panel.el && panel.el.extraDaten
                                            && panel.el.extraDaten.bmkOffsetY !== undefined)
                                            ? panel.el.extraDaten.bmkOffsetY : -14
                                        text: (weltWert / canvas.mmToPx).toFixed(1)
                                        Binding on text {
                                            when: !bmkOyTf.activeFocus
                                            value: (bmkOyTf.weltWert / canvas.mmToPx).toFixed(1)
                                        }
                                        onEditingFinished: {
                                            var v = parseFloat(text)
                                            if (!isNaN(v))
                                                bmkItem.extraSetzen("bmkOffsetY", v * canvas.mmToPx)
                                        }
                                        Keys.onEscapePressed: focus = false
                                    }
                                }
                                Text { text: "mm"; color: theme.borderLight; font.pixelSize: 10
                                       anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                    Item { height: 4 }
                }
            }

            // ================================================
            // ABSCHNITT: QUERVERWEIS (nur Querverweis-Symbol)
            // ================================================
            Item {
                width:   parent.width
                height:  (panel.el && panel.el.typ === "symbol"
                          && panel.el.symbolId === "querverweis")
                         ? qvCol.implicitHeight : 0
                visible: height > 0
                clip:    true

                // Hilfsfunktion: extraDaten-Kopie holen und geänderten Key setzen
                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                id: qvItem

                // Gibt die Gegenstelle im Projekt zurück (null wenn nicht gefunden)
                property var qvPartner: {
                    if (!panel.el || panel.el.typ !== "symbol" || panel.el.symbolId !== "querverweis") return null
                    var sn = (panel.el.extraDaten && panel.el.extraDaten.signalname) || ""
                    if (!sn || canvas.projektId < 0) return null
                    var alle = db.querverweiseLadenProjekt(canvas.projektId)
                    for (var k = 0; k < alle.length; k++) {
                        var qv = alle[k]
                        if (qv.signalname !== sn) continue
                        if (qv.seiteId === canvas.seiteId && panel.el
                            && Math.abs(qv.x1 - panel.el.x1) < 0.5
                            && Math.abs(qv.y1 - panel.el.y1) < 0.5) continue
                        return qv
                    }
                    return null
                }

                Column {
                    id: qvCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("QUERVERWEIS") }

                    // ── Signalname ────────────────────────────
                    FeldLabel { text: qsTr("Signalname") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: snEdit.activeFocus ? theme.accent : theme.border

                        TextInput {
                            id: snEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter

                            text: (panel.el && panel.el.extraDaten)
                                  ? (panel.el.extraDaten.signalname || "") : ""
                            Binding on text {
                                when: !snEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten)
                                       ? (panel.el.extraDaten.signalname || "") : ""
                            }
                            onEditingFinished: qvItem.extraSetzen("signalname", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    // ── Suchmodus ────────────────────────────
                    FeldLabel { text: qsTr("Suchmodus") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        MiniButton {
                            label: qsTr("Signalname")
                            aktiv: !panel.el || !panel.el.extraDaten
                                   || !panel.el.extraDaten.suchmodus
                                   || panel.el.extraDaten.suchmodus === "signal"
                            breite: 84
                            onKlick: qvItem.extraSetzen("suchmodus", "signal")
                        }
                        MiniButton {
                            label: qsTr("mit BMK")
                            aktiv: panel.el && panel.el.extraDaten
                                   && panel.el.extraDaten.suchmodus === "bmk"
                            breite: 84
                            onKlick: qvItem.extraSetzen("suchmodus", "bmk")
                        }
                    }
                    Item { height: 6 }

                    // ── Rolle (Ausgang / Eingang) ──────────────
                    FeldLabel { text: qsTr("Rolle") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        MiniButton {
                            label: qsTr("\u2192 Ausgang")
                            aktiv:  !panel.el || !panel.el.extraDaten
                                    || (panel.el.extraDaten.richtung || "ausgang") === "ausgang"
                            breite: 84
                            onKlick: parent.parent.parent.extraSetzen("richtung", "ausgang")
                        }
                        MiniButton {
                            label: qsTr("Eingang \u2190")
                            aktiv:  panel.el && panel.el.extraDaten
                                    && panel.el.extraDaten.richtung === "eingang"
                            breite: 84
                            onKlick: parent.parent.parent.extraSetzen("richtung", "eingang")
                        }
                    }
                    Item { height: 6 }

                    // ── Pfeilrichtung (Rotation) ──────────────
                    FeldLabel { text: qsTr("Pfeilrichtung") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3
                        Repeater {
                            model: [
                                { label: qsTr("\u2192"), rot: 0   },
                                { label: qsTr("\u2193"), rot: 90  },
                                { label: qsTr("\u2190"), rot: 180 },
                                { label: qsTr("\u2191"), rot: 270 }
                            ]
                            delegate: MiniButton {
                                label:  modelData.label
                                aktiv:  panel.s("rotation", 0) === modelData.rot
                                breite: 36
                                onKlick: canvas.eigenschaftAktualisieren("rotation", modelData.rot)
                            }
                        }
                    }
                    Item { height: 6 }

                    // ── Gegenseite (read-only, mit Navigation) ────────────
                    FeldLabel { text: qsTr("Gegenseite") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        Text {
                            width: 128
                            text: qvItem.qvPartner
                                  ? (qvItem.qvPartner.blattnummer
                                     + (qvItem.qvPartner.seitenBezeichnung
                                        ? " " + qvItem.qvPartner.seitenBezeichnung : ""))
                                  : qsTr("– keine Gegenstelle –")
                            color: qvItem.qvPartner ? theme.accent : theme.textSecondary
                            font.pixelSize: 11
                            font.bold: qvItem.qvPartner !== null
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            height: 22
                        }
                        MiniButton {
                            visible: qvItem.qvPartner !== null
                            label: qsTr("→ (F)")
                            breite: 48
                            onKlick: canvas.querverweisZurGegenseiteNavigieren()
                        }
                    }
                    Item { height: 6 }

                    // ── Verbinden mit (Querverweise projektübergreifend) ───
                    FeldLabel { text: qsTr("Verbinden mit") }
                    Item {
                        id: qvDropItem
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28

                        // Alle Querverweise des Projekts (seitenübergreifend, ohne aktuelles Element)
                        // Im BMK-Modus wird nach Anlage+Ort des aktuellen Elements gefiltert.
                        property var offeneQv: {
                            var liste   = [{ label: qsTr("– auswählen –"), sn: "" }]
                            var curEl   = panel.el
                            var curSid  = canvas.seiteId
                            var curMode = (curEl && curEl.extraDaten && curEl.extraDaten.suchmodus)
                                          || "signal"
                            var alle    = canvas.projektId >= 0
                                          ? db.querverweiseLadenProjekt(canvas.projektId)
                                          : []

                            // Anlage+Ort des aktuellen Elements für BMK-Filter
                            var filterAnlage = "", filterOrt = ""
                            if (curMode === "bmk" && curEl) {
                                var nd   = canvas.normblattDaten
                                var sk   = panel.strukturkastenFuer(curEl)
                                filterAnlage = sk && sk.anlage ? sk.anlage
                                              : (nd ? nd.anlageKuerzel || "" : "")
                                filterOrt    = sk && sk.ort    ? sk.ort
                                              : (nd ? nd.ortKuerzel    || "" : "")
                            }

                            for (var k = 0; k < alle.length; k++) {
                                var qv = alle[k]
                                // Aktuelles Element anhand Seite + Position ausschließen
                                if (qv.seiteId === curSid && curEl
                                        && Math.abs(qv.x1 - curEl.x1) < 0.5
                                        && Math.abs(qv.y1 - curEl.y1) < 0.5) continue
                                // BMK-Filter: nur gleiche Anlage+Ort (Seiten-Ebene)
                                if (curMode === "bmk") {
                                    if ((qv.anlageKuerzel || "") !== filterAnlage) continue
                                    if ((qv.ortKuerzel    || "") !== filterOrt)    continue
                                }
                                var rich  = qv.richtung || "ausgang"
                                var sn    = qv.signalname || ""
                                var pfeil = (rich === "ausgang") ? "\u2192" : "\u2190"
                                var seite = qv.blattnummer
                                            + (qv.seitenBezeichnung ? " " + qv.seitenBezeichnung : "")
                                var bez   = pfeil + " " + (sn !== "" ? sn : "(kein Name)")
                                            + "  \u2014  " + seite
                                liste.push({ label: bez, sn: sn })
                            }
                            return liste
                        }

                        ComboBox {
                            id: qvVerbindenBox
                            anchors.fill: parent
                            model: parent.offeneQv.map(function(e) { return e.label })
                            currentIndex: 0

                            Connections {
                                target: panel
                                function onElChanged() { qvVerbindenBox.currentIndex = 0 }
                            }

                            onActivated: function(idx) {
                                if (idx <= 0) return
                                var sn = qvDropItem.offeneQv[idx].sn
                                if (sn !== "") qvItem.extraSetzen("signalname", sn)
                                currentIndex = 0
                            }

                            background: Rectangle {
                                color: theme.inputBg; radius: 3
                                border.color: qvVerbindenBox.pressed ? theme.accent : theme.border
                            }
                            contentItem: Text {
                                leftPadding: 6
                                text: qvVerbindenBox.displayText
                                color: theme.textSecondary; font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            delegate: Rectangle {
                                width: qvVerbindenBox.width
                                height: 24
                                color: qvVerbindenBox.highlightedIndex === index
                                       ? theme.activeItemAlt : theme.inputBg
                                Text {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                                    text: modelData
                                    color: theme.textSecondary
                                    font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: qvVerbindenBox.highlightedIndex = index
                                    onExited:  qvVerbindenBox.highlightedIndex = -1
                                    onClicked: {
                                        qvVerbindenBox.currentIndex = index
                                        qvVerbindenBox.activated(index)
                                        qvVerbindenBox.popup.close()
                                    }
                                }
                            }
                            popup: Popup {
                                y: qvVerbindenBox.height
                                width: qvVerbindenBox.width
                                padding: 0
                                contentItem: ListView {
                                    implicitHeight: Math.min(contentHeight, 200)
                                    model: qvVerbindenBox.delegateModel
                                    clip: true
                                    ScrollBar.vertical: ScrollBar {}
                                }
                                background: Rectangle {
                                    color: theme.inputBg
                                    border.color: theme.border; radius: 3
                                }
                            }
                        }
                    }
                    Item { height: 6 }
                }
            }

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

            // ================================================
            // ABSCHNITT: GERÄTEANSCHLUSS
            // ================================================
            Item {
                id: gaItem
                width:   parent.width
                height:  (panel.el && panel.el.typ === "symbol"
                          && panel.el.symbolId === "geraeteanschluss")
                         ? gaCol.implicitHeight : 0
                visible: height > 0
                clip:    true

                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                readonly property string aktuellRolle: (panel.el && panel.el.extraDaten
                    && panel.el.extraDaten.rolle) ? panel.el.extraDaten.rolle : "ziel"
                readonly property string aktuellSig: (panel.el && panel.el.extraDaten
                    && panel.el.extraDaten.signaltyp) ? panel.el.extraDaten.signaltyp : "neutral"

                Column {
                    id: gaCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("GERÄTEANSCHLUSS") }

                    FeldLabel { text: qsTr("Rolle") }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        MiniButton {
                            label:   qsTr("\u25C4 Ziel")
                            aktiv:   gaItem.aktuellRolle === "ziel"
                            breite:  80
                            onKlick: gaItem.extraSetzen("rolle", "ziel")
                        }
                        MiniButton {
                            label:   qsTr("Quelle \u25BA")
                            aktiv:   gaItem.aktuellRolle === "quelle"
                            breite:  80
                            onKlick: gaItem.extraSetzen("rolle", "quelle")
                        }
                    }
                    Item { height: 6 }

                    // Anschlusskennzeichnung
                    FeldLabel { text: qsTr("Anschlusskennzeichnung") }
                    Rectangle {
                        width: parent.width - 16; height: 28; radius: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: theme.surface; border.color: theme.border; border.width: 1
                        TextInput {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.textSecondary; font.pixelSize: 11
                            text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.anschlusskennzeichnung)
                                  ? panel.el.extraDaten.anschlusskennzeichnung : ""
                            onEditingFinished: gaItem.extraSetzen("anschlusskennzeichnung", text)
                        }
                    }
                    Item { height: 6 }

                    // Signaltyp – nur wenn Quelle
                    Item {
                        width:   parent.width
                        height:  gaItem.aktuellRolle === "quelle" ? gaSigCol.implicitHeight : 0
                        visible: height > 0; clip: true

                        Column {
                            id: gaSigCol
                            width: parent.width
                            spacing: 0

                            FeldLabel { text: qsTr("Signaltyp") }
                            Flow {
                                width: parent.width - 16
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4

                                Repeater {
                                    model: [
                                        { key: "neutral",        label: qsTr("Neutral"), farbe: "#4a9eff" },
                                        { key: "power",          label: qsTr("Kraft"),   farbe: "#cc3300" },
                                        { key: "pe",             label: "PE",      farbe: "#88cc00" },
                                        { key: "n",              label: "N",       farbe: "#4488ff" },
                                        { key: "input_digital",  label: "DI",      farbe: "#44aacc" },
                                        { key: "output_digital", label: "DO",      farbe: "#aa44cc" },
                                        { key: "input_analog",   label: "AI",      farbe: "#88bbff" },
                                        { key: "output_analog",  label: "AO",      farbe: "#66ddaa" },
                                        { key: "kommunikation",  label: qsTr("Komm."),   farbe: "#cc8800" }
                                    ]
                                    delegate: Rectangle {
                                        width:  gaSigLbl.implicitWidth + 16; height: 24; radius: 4
                                        color:  gaItem.aktuellSig === modelData.key
                                                ? Qt.rgba(
                                                      parseInt(modelData.farbe.slice(1,3),16)/255,
                                                      parseInt(modelData.farbe.slice(3,5),16)/255,
                                                      parseInt(modelData.farbe.slice(5,7),16)/255,
                                                      0.25)
                                                : theme.inputBg
                                        border.color: gaItem.aktuellSig === modelData.key
                                                      ? modelData.farbe : theme.border
                                        border.width: 1
                                        Text {
                                            id: gaSigLbl
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            font.pixelSize: 10
                                            color: gaItem.aktuellSig === modelData.key
                                                   ? modelData.farbe : theme.panelMid
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: gaItem.extraSetzen("signaltyp", modelData.key)
                                        }
                                    }
                                }
                            }
                            Item { height: 6 }
                        }
                    }
                }
            }

            // ================================================
            // ABSCHNITT: GERÄTEKASTEN
            // ================================================
            Item {
                id: gkItem
                width:   parent.width
                height:  (panel.el && panel.el.typ === "geraetekasten") ? gkCol.implicitHeight : 0
                visible: height > 0
                clip:    true

                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                Column {
                    id: gkCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("GERÄTEKASTEN") }

                    FeldLabel { text: qsTr("BMK (Einbauort)") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: gkBmkEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: gkBmkEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "") : ""
                            Binding on text {
                                when: !gkBmkEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "") : ""
                            }
                            onEditingFinished: gkItem.extraSetzen("bmk", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    FeldLabel { text: qsTr("Bezeichnung") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: gkBezEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: gkBezEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                            Binding on text {
                                when: !gkBezEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                            }
                            onEditingFinished: gkItem.extraSetzen("bezeichnung", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    // ── Schriftgröße ──────────────────────────
                    Trennlinie {}
                    AbschnittTitel { text: qsTr("SCHRIFTGRÖSSE") }
                    SchriftgrosseSelektor {
                        wert: (panel.el && panel.el.extraDaten
                               && panel.el.extraDaten.schriftgroesse !== undefined)
                              ? panel.el.extraDaten.schriftgroesse : 2.5
                        onWertGeaendert: function(v) { gkItem.extraSetzen("schriftgroesse", v) }
                    }
                    Item { height: 4 }
                }
            }

            // ================================================
            // ABSCHNITT: STRUKTURKASTEN
            // ================================================
            Item {
                id: skItem
                width:   parent.width
                height:  (panel.el && panel.el.typ === "strukturkasten") ? skCol.implicitHeight : 0
                visible: height > 0
                clip:    true

                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                Column {
                    id: skCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("STRUKTURKASTEN") }

                    FeldLabel { text: qsTr("Bezeichnung") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: skBezEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: skBezEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                            Binding on text {
                                when: !skBezEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                            }
                            onEditingFinished: skItem.extraSetzen("bezeichnung", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    FeldLabel { text: qsTr("Übergeordnete Anlage (==)") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: skAnlUOEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: skAnlUOEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.anlageUO || "") : ""
                            Binding on text {
                                when: !skAnlUOEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.anlageUO || "") : ""
                            }
                            onEditingFinished: skItem.extraSetzen("anlageUO", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    FeldLabel { text: qsTr("Übergeordneter Ort (++)") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: skOrtUOEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: skOrtUOEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.ortUO || "") : ""
                            Binding on text {
                                when: !skOrtUOEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.ortUO || "") : ""
                            }
                            onEditingFinished: skItem.extraSetzen("ortUO", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    FeldLabel { text: qsTr("Anlage (=)") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: skAnlEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: skAnlEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.anlage || "") : ""
                            Binding on text {
                                when: !skAnlEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.anlage || "") : ""
                            }
                            onEditingFinished: skItem.extraSetzen("anlage", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    FeldLabel { text: qsTr("Ort (+)") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: skOrtEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: skOrtEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.ort || "") : ""
                            Binding on text {
                                when: !skOrtEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.ort || "") : ""
                            }
                            onEditingFinished: skItem.extraSetzen("ort", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    // ── Schriftgröße ──────────────────────────
                    Trennlinie {}
                    AbschnittTitel { text: qsTr("SCHRIFTGRÖSSE") }
                    SchriftgrosseSelektor {
                        wert: (panel.el && panel.el.extraDaten
                               && panel.el.extraDaten.schriftgroesse !== undefined)
                              ? panel.el.extraDaten.schriftgroesse : 2.5
                        onWertGeaendert: function(v) { skItem.extraSetzen("schriftgroesse", v) }
                    }
                    Item { height: 4 }
                }
            }

            // ================================================
            // ABSCHNITT: MAKROKASTEN
            // ================================================
            Item {
                id: mkItem
                width:   parent.width
                height:  (panel.el && panel.el.typ === "makrokasten") ? mkCol.implicitHeight : 0
                visible: height > 0
                clip:    true

                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                Column {
                    id: mkCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("MAKRO") }

                    FeldLabel { text: qsTr("Name") }
                    Rectangle {
                        width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: mkNameEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: mkNameEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.name || "") : ""
                            Binding on text {
                                when: !mkNameEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.name || "") : ""
                            }
                            onEditingFinished: {
                                mkItem.extraSetzen("name", text.trim())
                                var mkId = panel.el && panel.el.extraDaten ? (panel.el.extraDaten.makroId || 0) : 0
                                if (mkId > 0) db.makroMetaAktualisieren(mkId, text.trim(),
                                    panel.el.extraDaten.beschreibung || "",
                                    panel.el.extraDaten.kategorie || "")
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 4 }

                    FeldLabel { text: qsTr("Beschreibung") }
                    Rectangle {
                        width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: mkBeschEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: mkBeschEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.beschreibung || "") : ""
                            Binding on text {
                                when: !mkBeschEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.beschreibung || "") : ""
                            }
                            onEditingFinished: {
                                mkItem.extraSetzen("beschreibung", text.trim())
                                var mkId = panel.el && panel.el.extraDaten ? (panel.el.extraDaten.makroId || 0) : 0
                                if (mkId > 0) db.makroMetaAktualisieren(mkId,
                                    panel.el.extraDaten.name || "",
                                    text.trim(),
                                    panel.el.extraDaten.kategorie || "")
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 4 }

                    FeldLabel { text: qsTr("Kategorie") }
                    Rectangle {
                        width: parent.width - 16; anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: mkKatEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: mkKatEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.kategorie || "") : ""
                            Binding on text {
                                when: !mkKatEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.kategorie || "") : ""
                            }
                            onEditingFinished: {
                                mkItem.extraSetzen("kategorie", text.trim())
                                var mkId = panel.el && panel.el.extraDaten ? (panel.el.extraDaten.makroId || 0) : 0
                                if (mkId > 0) db.makroMetaAktualisieren(mkId,
                                    panel.el.extraDaten.name || "",
                                    panel.el.extraDaten.beschreibung || "",
                                    text.trim())
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    // Elementanzahl
                    Text {
                        visible: panel.el && panel.el.typ === "makrokasten"
                        leftPadding: 12
                        text: {
                            var el = panel.el
                            if (!el || el.typ !== "makrokasten") return ""
                            var minX = Math.min(el.x1, el.x2), minY = Math.min(el.y1, el.y2)
                            var maxX = Math.max(el.x1, el.x2), maxY = Math.max(el.y1, el.y2)
                            var cnt = 0
                            var alle = canvas.elemente
                            for (var i = 0; i < alle.length; i++) {
                                var e = alle[i]
                                if (e === el || e.typ === "makrokasten") continue
                                var mx = (e.x1 + e.x2) / 2, my = (e.y1 + e.y2) / 2
                                if (mx >= minX && mx <= maxX && my >= minY && my <= maxY) cnt++
                            }
                            return cnt + " " + qsTr("Elemente im Kasten")
                        }
                        color: theme.textMuted; font.pixelSize: 11; font.italic: true
                        width: parent.width - 16
                        wrapMode: Text.WordWrap
                    }
                    Item { height: 6 }

                    // Buttons: Speichern + Löschen
                    RowLayout {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Button {
                            text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.makroId > 0)
                                  ? qsTr("Makro aktualisieren ▸")
                                  : qsTr("Als Makro speichern ▸")
                            Layout.fillWidth: true
                            implicitHeight: 28
                            contentItem: Text {
                                text: parent.text; color: theme.textPrimary; font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? theme.accent : theme.inputBg
                                radius: 4; border.color: theme.accent
                            }
                            onClicked: {
                                var el = panel.el
                                if (!el || !(el.id > 0)) return
                                var newId = db.makroSpeichern(el.id, canvas.seiteId)
                                if (newId > 0) {
                                    mkItem.extraSetzen("makroId", newId)
                                    canvas.makroListeGeaendert()
                                }
                            }
                        }

                        Button {
                            visible: panel.el && panel.el.extraDaten && panel.el.extraDaten.makroId > 0
                            text: "×"
                            implicitWidth: 28; implicitHeight: 28
                            contentItem: Text {
                                text: parent.text; color: theme.textPrimary; font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? "#cc3300" : theme.inputBg
                                radius: 4; border.color: theme.border
                            }
                            onClicked: {
                                var mkId = panel.el && panel.el.extraDaten ? (panel.el.extraDaten.makroId || 0) : 0
                                if (mkId > 0) {
                                    db.makroLoeschen(mkId)
                                    mkItem.extraSetzen("makroId", 0)
                                    canvas.makroListeGeaendert()
                                }
                            }
                        }
                    }
                    Item { height: 6 }
                }
            }

            // ================================================
            // ABSCHNITT: KABELDEFINITIONSLINIE
            // ================================================
            Item {
                id: klItem
                width:   parent.width
                height:  (panel.el && panel.el.typ === "kabellinie") ? klCol.implicitHeight : 0
                visible: height > 0
                clip:    true

                function extraSetzen(key, val) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[key] = val
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
                function extraSetzenMehrfach(felder) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    for (var k in felder) ed[k] = felder[k]
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                // Picker-Dialog für Bauteil-Kabel-Zuweisung
                BauteilKabelPickerDialog {
                    id: epKabelPicker
                    theme: panel.theme
                    onAccepted: {
                        var bkId = epKabelPicker.ausgewaehltId
                        var felder = { bauteilKabelId: bkId }

                        if (bkId > 0) {
                            // Felder aus der bereits geladenen Liste befüllen – kein panel.db nötig
                            var liste = epKabelPicker.kabelListe
                            for (var i = 0; i < liste.length; i++) {
                                if (liste[i].id === bkId) {
                                    var k = liste[i]
                                    if (k.kabeltyp)                   felder.kabeltyp       = k.kabeltyp
                                    if ((k.aderzahl || 0) > 0)        felder.aderzahl       = k.aderzahl
                                    if ((k.querschnittMm2 || 0) > 0)  felder.querschnittMm2 = k.querschnittMm2
                                    if (k.adern)                      felder.adern          = k.adern
                                    break
                                }
                            }
                        } else {
                            felder.adern = []
                        }

                        // DB-Verknüpfung persistieren
                        var ed0 = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                        var kabelId = ed0.kabelId || 0
                        if (kabelId > 0) db.kabelBauteilKabelSetzen(kabelId, bkId)

                        klItem.extraSetzenMehrfach(felder)
                    }
                }

                Column {
                    id: klCol
                    width: parent.width
                    spacing: 0

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("KABEL") }

                    FeldLabel { text: qsTr("Bezeichnung (BMK)") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: klBezEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: klBezEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                            Binding on text {
                                when: !klBezEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                            }
                            onEditingFinished: klItem.extraSetzen("bezeichnung", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    FeldLabel { text: qsTr("Kabeltyp") }
                    Rectangle {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 28; color: theme.inputBg; radius: 3
                        border.color: klTypEdit.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: klTypEdit
                            anchors { fill: parent; margins: 5 }
                            color: theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.kabeltyp || "") : ""
                            Binding on text {
                                when: !klTypEdit.activeFocus
                                value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.kabeltyp || "") : ""
                            }
                            onEditingFinished: klItem.extraSetzen("kabeltyp", text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Item { height: 6 }

                    Row {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        Column {
                            width: (parent.width - 8) / 2; spacing: 4
                            FeldLabel { text: qsTr("Aderzahl") }
                            Rectangle {
                                width: parent.width; height: 28
                                color: theme.inputBg; radius: 3
                                border.color: klAderEdit.activeFocus ? theme.accent : theme.border
                                TextInput {
                                    id: klAderEdit
                                    anchors { fill: parent; margins: 5 }
                                    color: theme.textSecondary; font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter
                                    inputMethodHints: Qt.ImhDigitsOnly
                                    validator: IntValidator { bottom: 0; top: 999 }
                                    text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.aderzahl)
                                          ? panel.el.extraDaten.aderzahl.toString() : ""
                                    Binding on text {
                                        when: !klAderEdit.activeFocus
                                        value: (panel.el && panel.el.extraDaten && panel.el.extraDaten.aderzahl)
                                               ? panel.el.extraDaten.aderzahl.toString() : ""
                                    }
                                    onEditingFinished: klItem.extraSetzen("aderzahl", parseInt(text) || 0)
                                    Keys.onEscapePressed: focus = false
                                }
                            }
                        }
                        Column {
                            width: (parent.width - 8) / 2; spacing: 4
                            FeldLabel { text: qsTr("Querschnitt mm²") }
                            Rectangle {
                                width: parent.width; height: 28
                                color: theme.inputBg; radius: 3
                                border.color: klQsEdit.activeFocus ? theme.accent : theme.border
                                TextInput {
                                    id: klQsEdit
                                    anchors { fill: parent; margins: 5 }
                                    color: theme.textSecondary; font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.querschnittMm2)
                                          ? panel.el.extraDaten.querschnittMm2.toString() : ""
                                    Binding on text {
                                        when: !klQsEdit.activeFocus
                                        value: (panel.el && panel.el.extraDaten && panel.el.extraDaten.querschnittMm2)
                                               ? panel.el.extraDaten.querschnittMm2.toString() : ""
                                    }
                                    onEditingFinished: klItem.extraSetzen("querschnittMm2",
                                                           parseFloat(text.replace(",", ".")) || 0.0)
                                    Keys.onEscapePressed: focus = false
                                }
                            }
                        }
                    }
                    Item { height: 6 }

                    FeldLabel { text: qsTr("Bauteil-Kabel") }
                    Row {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Text {
                            width: parent.width - klBkWaehlenBtn.implicitWidth
                                   - (klBkLoeschenBtn.visible ? klBkLoeschenBtn.implicitWidth + 6 : 0) - 6
                            height: 24
                            verticalAlignment: Text.AlignVCenter
                            text: {
                                var ed   = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                                var bkId = ed.bauteilKabelId || 0
                                if (bkId > 0) {
                                    var liste = db.bauteilKabelListe()
                                    for (var i = 0; i < liste.length; i++) {
                                        if (liste[i].id === bkId)
                                            return (liste[i].bezeichnung || "") + (liste[i].kabeltyp ? "  " + liste[i].kabeltyp : "")
                                    }
                                    return qsTr("ID") + " " + bkId
                                }
                                return qsTr("–")
                            }
                            color: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) > 0
                                   ? theme.accent : theme.textMuted
                            font.pixelSize: 11
                            font.italic: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) <= 0
                            elide: Text.ElideRight
                        }
                        Button {
                            id: klBkWaehlenBtn
                            text: qsTr("Wählen …"); flat: true; implicitHeight: 24; implicitWidth: 72
                            contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 10;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 3; border.color: theme.border }
                            onClicked: {
                                epKabelPicker.kabelListe = db.bauteilKabelListe()
                                epKabelPicker.open()
                            }
                        }
                        Button {
                            id: klBkLoeschenBtn
                            text: "×"; flat: true; implicitHeight: 24; implicitWidth: 24
                            visible: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) > 0
                            contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 13;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 3 }
                            onClicked: {
                                var ed1 = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                                var klId1 = ed1.kabelId || 0
                                if (klId1 > 0) db.kabelBauteilKabelSetzen(klId1, 0)
                                klItem.extraSetzenMehrfach({ bauteilKabelId: 0, adern: [] })
                            }
                        }
                    }
                    Item { height: 4 }

                    // Von / Nach
                    Row {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        Column {
                            width: (parent.width - 8) / 2; spacing: 4
                            FeldLabel { text: qsTr("Von") }
                            Rectangle {
                                width: parent.width; height: 28
                                color: theme.inputBg; radius: 3
                                border.color: klVonEdit.activeFocus ? theme.accent : theme.border
                                TextInput {
                                    id: klVonEdit
                                    anchors { fill: parent; margins: 5 }
                                    color: theme.textSecondary; font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.vonOrt || "") : ""
                                    Binding on text {
                                        when: !klVonEdit.activeFocus
                                        value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.vonOrt || "") : ""
                                    }
                                    onEditingFinished: {
                                        klItem.extraSetzen("vonOrt", text.trim())
                                        var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                                        var kabelId = ed.kabelId || 0
                                        if (kabelId > 0) db.kabelMetaAktualisieren(kabelId,
                                            ed.bezeichnung || "", ed.kabeltyp || "",
                                            ed.aderzahl || 0, ed.querschnittMm2 || 0,
                                            text.trim(), ed.nachOrt || "")
                                    }
                                    Keys.onEscapePressed: focus = false
                                }
                            }
                        }
                        Column {
                            width: (parent.width - 8) / 2; spacing: 4
                            FeldLabel { text: qsTr("Nach") }
                            Rectangle {
                                width: parent.width; height: 28
                                color: theme.inputBg; radius: 3
                                border.color: klNachEdit.activeFocus ? theme.accent : theme.border
                                TextInput {
                                    id: klNachEdit
                                    anchors { fill: parent; margins: 5 }
                                    color: theme.textSecondary; font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter
                                    text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.nachOrt || "") : ""
                                    Binding on text {
                                        when: !klNachEdit.activeFocus
                                        value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.nachOrt || "") : ""
                                    }
                                    onEditingFinished: {
                                        klItem.extraSetzen("nachOrt", text.trim())
                                        var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                                        var kabelId = ed.kabelId || 0
                                        if (kabelId > 0) db.kabelMetaAktualisieren(kabelId,
                                            ed.bezeichnung || "", ed.kabeltyp || "",
                                            ed.aderzahl || 0, ed.querschnittMm2 || 0,
                                            ed.vonOrt || "", text.trim())
                                    }
                                    Keys.onEscapePressed: focus = false
                                }
                            }
                        }
                    }
                    Item { height: 4 }

                    // Aderzuordnung-Button (öffnet AderzuordnungDialog)
                    Button {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Aderzuordnung …")
                        implicitHeight: 28
                        enabled: (panel.el && panel.el.extraDaten && (panel.el.extraDaten.kabelId || 0) > 0)
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? (theme ? theme.textPrimary : "#c0d8f0") : (theme ? theme.textMuted : "#7090b0")
                            font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered && parent.enabled ? (theme ? theme.hover : "#0f2540") : (theme ? theme.inputBg : "#0f1c2e")
                            radius: 3; border.color: theme ? theme.border : "#2a4060"
                        }
                        onClicked: canvas.aderzuordnungDialogOeffnen(panel.el)
                    }
                    Item { height: 4 }

                    // ─── KABEL-LINIEN ────────────────────────────────────
                    AbschnittTitel { text: qsTr("KABEL-LINIEN") }

                    // Liste aller Kabellinie-Grafikelemente dieses Kabels
                    Repeater {
                        model: {
                            var kabelId = panel.el && panel.el.extraDaten
                                          ? (panel.el.extraDaten.kabelId || 0) : 0
                            return kabelId > 0
                                   ? db.kabelAlleLinienLaden(kabelId + (panel._refresh * 0))
                                   : []
                        }

                        delegate: Rectangle {
                            width: parent ? parent.width - 16 : 0
                            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                            height: 32; radius: 3
                            color: (panel.el && modelData.grafikElementId === (panel.el.id || -1))
                                   ? (theme ? theme.activeItemAlt : "#0f2540")
                                   : (theme ? theme.inputBg       : "#0f1c2e")
                            border.color: theme ? theme.border : "#2a4060"

                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                spacing: 6
                                Text {
                                    text: modelData.seiteBezeichnung || ("Seite " + modelData.seiteId)
                                    color: theme ? theme.textSecondary : "#88aacc"
                                    font.pixelSize: 10; elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.aderAnzahl + " " + qsTr("Adr.")
                                    color: modelData.aderAnzahl > 0
                                           ? (theme ? theme.accent   : "#e07000")
                                           : (theme ? theme.textMuted : "#7090b0")
                                    font.pixelSize: 10
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    canvas.querverweisNavigieren(modelData.seiteId)
                                    panel._refresh++
                                }
                            }
                        }
                    }

                    // Freie Adern (keiner Linie zugewiesen) anzeigen
                    Item {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: {
                            var kabelId = panel.el && panel.el.extraDaten
                                          ? (panel.el.extraDaten.kabelId || 0) : 0
                            var freie = kabelId > 0
                                        ? db.kabelFreieAderLaden(kabelId + (panel._refresh * 0))
                                        : []
                            return freie.length > 0 ? freiAderCol.implicitHeight : 0
                        }
                        clip: true
                        Column {
                            id: freiAderCol
                            width: parent.width; spacing: 2
                            Text {
                                width: parent.width
                                text: qsTr("Freie Adern (nicht zugeordnet):")
                                color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10; font.italic: true
                            }
                            Repeater {
                                model: {
                                    var kabelId = panel.el && panel.el.extraDaten
                                                  ? (panel.el.extraDaten.kabelId || 0) : 0
                                    return kabelId > 0
                                           ? db.kabelFreieAderLaden(kabelId + (panel._refresh * 0))
                                           : []
                                }
                                delegate: Text {
                                    width: parent ? parent.width : 0
                                    text: {
                                        var t = "Ader " + (modelData.aderNr || "?")
                                        if (modelData.farbe) t += "  " + modelData.farbe
                                        if (modelData.bezeichnung) t += "  " + modelData.bezeichnung
                                        return t
                                    }
                                    color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                    Item { height: 4 }

                    // ─── KABEL-ADERN ────────────────────────────────────
                    AbschnittTitel { text: qsTr("KABEL-ADERN") }
                    Text {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Dieser Linie zugeordnet:")
                        color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10; font.italic: true
                    }
                    Repeater {
                        model: {
                            var geid = panel.el ? (panel.el.id || 0) : 0
                            return geid > 0
                                   ? db.kabelAderFuerLinieLaden(geid + (panel._refresh * 0))
                                   : []
                        }
                        delegate: Rectangle {
                            width: parent ? parent.width - 16 : 0
                            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                            height: 24; radius: 3
                            color: theme ? theme.inputBg : "#0f1c2e"
                            border.color: theme ? theme.border : "#2a4060"
                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                spacing: 6
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    visible: (modelData.farbe || "") !== ""
                                    color: canvas ? canvas.iecFarbe(modelData.farbe || "") : "#888888"
                                    border.color: "#00000055"; border.width: 1
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Text {
                                    text: {
                                        var t = "Ader " + (modelData.aderNr || "?")
                                        if (modelData.farbe) t += "  " + modelData.farbe
                                        if (modelData.bezeichnung) t += "  " + modelData.bezeichnung
                                        return t
                                    }
                                    color: theme ? theme.textSecondary : "#88aacc"
                                    font.pixelSize: 10; elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                    Text {
                        width: parent.width - 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: {
                            var geid = panel.el ? (panel.el.id || 0) : 0
                            return geid > 0 && db.kabelAderFuerLinieLaden(geid).length === 0
                        }
                        text: qsTr("Keine Adern zugeordnet.")
                        color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10; font.italic: true
                    }
                    Item { height: 8 }
                }
            }

            // ================================================
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
                    MiniButton {
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

    // Kleiner Toggle-/Auswahl-Button
    component MiniButton: Rectangle {
        id: mbRoot
        property string label:   ""
        property string tooltip: ""
        property bool   aktiv:   false
        property real   breite:  40
        property real   hoehe:   28
        property bool   mono:    false
        signal klick()

        width: breite; height: hoehe; radius: 4
        color:        aktiv ? theme.activeItemAlt : (mbMaus.containsMouse ? theme.hover : theme.inputBg)
        border.color: aktiv ? theme.accent : theme.border

        Text {
            anchors.centerIn: parent
            text:           mbRoot.label
            font.pixelSize: 10
            font.family:    mbRoot.mono ? "monospace" : ""
            color:          mbRoot.aktiv ? theme.accent : theme.textMuted
        }
        MouseArea {
            id: mbMaus; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked:   mbRoot.klick()
        }
        ToolTip.visible: mbRoot.tooltip !== "" && mbMaus.containsMouse
        ToolTip.text:    mbRoot.tooltip
        ToolTip.delay:   500
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

    // ── Dialog: Betriebsmittel verknüpfen ────────────────────
    Dialog {
        id:    dlgVerknuepfen
        title: qsTr("Geräteverknüpfung")
        width: 340
        anchors.centerIn: parent
        modal: true

        property int gewaehltId: 0

        background: Rectangle {
            color:  theme ? theme.sidebar : "#1a2332"
            border.color: theme ? theme.border : "#2a4060"
            border.width: 1; radius: 6
        }

        header: Item {
            height: 36
            Text {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                text: qsTr("Geräteverknüpfung")
                color: theme ? theme.accent : "#e07000"
                font.pixelSize: 13; font.weight: Font.Medium
            }
        }

        onOpened: {
            dlgVerknuepfen.gewaehltId = panel.el ? (panel.el.betriebsmittelId || 0) : 0
            neuKzField.text = (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "") : ""
            neuBezField.text = ""
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: {
            if (!panel.el) return
            var zielId  = dlgVerknuepfen.gewaehltId
            var zielKz  = ""
            if (zielId <= 0 && neuKzField.text.trim() !== "") {
                zielKz = neuKzField.text.trim()
                zielId = db.betriebsmittelAnlegen(canvas.projektId, zielKz, neuBezField.text.trim())
            } else if (zielId > 0) {
                zielKz = db.betriebsmittelKz(zielId)
            }
            if (zielId > 0) {
                db.grafikElementVerknuepfen(panel.el.id, zielId)
                canvas.eigenschaftAktualisieren("betriebsmittelId", zielId)
                // BMK vom Betriebsmittel übernehmen
                if (zielKz !== "") {
                    var ed = panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed["bmk"] = zielKz
                    canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: 8

            // ── Vorhandene Betriebsmittel ───────────────────
            Text {
                text: qsTr("Vorhandenes Betriebsmittel wählen:")
                color: theme ? theme.textBright : "#c0d8f0"; font.pixelSize: 11
            }

            ListView {
                id: bmListe
                Layout.fillWidth: true
                height: Math.min(contentHeight, 160)
                clip: true
                model: canvas.projektId >= 0 ? db.betriebsmittelListe(canvas.projektId) : []

                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    width: bmListe.width; height: 28; radius: 3
                    color: dlgVerknuepfen.gewaehltId === modelData.id
                           ? (theme ? theme.activeItemAlt : "#1e3a5a")
                           : (bmDelegMa.containsMouse ? (theme ? theme.hover : "#1a2a3a") : "transparent")
                    border.color: dlgVerknuepfen.gewaehltId === modelData.id
                                  ? (theme ? theme.accent : "#4a9eff") : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: modelData.kz;          font.pixelSize: 12; color: theme ? theme.accent : "#4a9eff"; width: 80; elide: Text.ElideRight }
                        Text { text: modelData.bezeichnung || ""; font.pixelSize: 11; color: theme ? theme.textMuted : "#7090b0" }
                        Text { text: modelData.anzahl > 0 ? "(" + modelData.anzahl + ")" : ""; font.pixelSize: 10; color: theme ? theme.borderLight : "#506070" }
                    }
                    MouseArea {
                        id: bmDelegMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { dlgVerknuepfen.gewaehltId = modelData.id; neuKzField.text = "" }
                    }
                }
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: theme ? theme.border : "#2a4060" }

            // ── Neues Betriebsmittel anlegen ────────────────
            Text {
                text: qsTr("… oder neues Betriebsmittel anlegen:")
                color: theme ? theme.textBright : "#c0d8f0"; font.pixelSize: 11
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                TextField {
                    id: neuKzField
                    placeholderText: qsTr("BMK z.B. -K1")
                    Layout.preferredWidth: 100
                    background: Rectangle { color: theme ? theme.inputBg : "#0d1a28"; radius: 4; border.color: theme ? theme.border : "#2a4060" }
                    color: theme ? theme.textPrimary : "#c0d8f0"; font.pixelSize: 11
                    onTextChanged: if (text.trim() !== "") dlgVerknuepfen.gewaehltId = 0
                }
                TextField {
                    id: neuBezField
                    placeholderText: qsTr("Bezeichnung (optional)")
                    Layout.fillWidth: true
                    background: Rectangle { color: theme ? theme.inputBg : "#0d1a28"; radius: 4; border.color: theme ? theme.border : "#2a4060" }
                    color: theme ? theme.textPrimary : "#c0d8f0"; font.pixelSize: 11
                }
            }

            // Hinweis: BMK wird vom Betriebsmittel übernommen
            Text {
                visible: dlgVerknuepfen.gewaehltId > 0
                text: qsTr("Das BMK wird vom gewählten Betriebsmittel übernommen.")
                color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10; font.italic: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    DebugLabel { panelName: qsTr("Eigenschaften-Panel"); visible: panel.debug }
}
