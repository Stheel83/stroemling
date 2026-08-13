import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

// ============================================================
// SymbolPalette
// Kategorie-Navigation mit Drill-Down, Favoriten und Makro-Schnellzugriff.
//
// Eigenschaften die vom Elternelement gesetzt werden müssen:
//   theme       – Theme-Objekt aus Main.qml
//   projektId   – aktive Projekt-ID (-1 wenn keines)
//
// Signals:
//   symbolGewaehlt(string symbolCode)
//   makroEinfuegenAngefordert(int makroId, string name)
// ============================================================

Rectangle {
    id: root

    color: theme.sidebar

    // ── Öffentliche Properties ────────────────────────────────
    property var    theme
    property bool   debug:      false
    property int    projektId:  -1

    // "symbole" | "makros"
    property string paletteModus: "symbole"

    // Aktuell ausgewählter Symbol-Code (leer = keiner)
    property string aktivesSymbol: ""

    signal symbolGewaehlt(string symbolCode)
    signal makroEinfuegenAngefordert(int makroId, string name)
    signal editorOeffnen(string symbolId)
    signal vorlageFuerEditor(string quellId)

    function makroListeAktualisieren() { makroPalette.aktualisieren() }

    // ── Interner State ────────────────────────────────────────
    // "kategorien" | "symbole" | "favoriten" | "zuletzt"
    property string ansicht: "kategorien"
    property string aktiveKategorie: ""

    // Symbolliste aus der DB (für aktive Norm)
    property var alleSymbole: []
    // Eigene (nicht-eingebaute) Symbole aus symbol_definition
    property var eigeneSymboleList: []

    // Zum Löschen markierte Symbol-IDs (SYM-LOESCH-MARKIERUNG-01,
    // Entwicklungsphase-Werkzeug — reine Merkliste für spätere manuelle
    // Bereinigung, kein automatisches Löschen).
    property var markierteLoeschen: []

    // ── Hilfsfunktionen ───────────────────────────────────────
    function laden() {
        alleSymbole = db.symboleNachNorm("IEC")
        var alle = symbolDefinitionModel.alleSymbole()
        var eigene = []
        for (var i = 0; i < alle.length; i++) {
            if (!alle[i].ist_builtin) {
                eigene.push({
                    id:           alle[i].id,
                    code:         alle[i].id,
                    name:         alle[i].name,
                    kategoriePfad: "eigene",
                    favorit:      false,
                    tooltip:      "",
                    ist_builtin:  false
                })
            }
        }
        eigeneSymboleList = eigene
        markierteLoeschenLaden()
    }

    function markierteLoeschenLaden() {
        markierteLoeschen = symbolDefinitionModel.symboleMarkiertLoeschen()
    }

    function istMarkiertLoeschen(code) {
        return code !== undefined && markierteLoeschen.indexOf(code) !== -1
    }

    function markierungLoeschenToggle(sym) {
        if (!sym || sym.code === undefined) return
        var neu = !root.istMarkiertLoeschen(sym.code)
        symbolDefinitionModel.markierungLoeschenSetzen(sym.code, neu)
        root.markierteLoeschenLaden()
    }

    function abwaehlen() {
        aktivesSymbol = ""
    }

    function kategorienListe() {
        var seen = {}, result = []
        for (var i = 0; i < alleSymbole.length; i++) {
            var k = alleSymbole[i].kategoriePfad
            if (!seen[k]) { seen[k] = true; result.push(k) }
        }
        return result
    }

    function symboleInKategorie(kat) {
        if (kat === "eigene") return root.eigeneSymboleList
        if (kat === "verbindungen") return [
            { id: undefined, code: "winkel",           name: "Winkelelement",      kategoriePfad: "verbindungen", favorit: false, tooltip: "Winkel oder auch diagonal geschnittenes Quadrat, Abk. DGQ, gesprochen Digge Kuh" },
            { id: undefined, code: "treffpunkt",       name: "Treffpunkt T",       kategoriePfad: "verbindungen", favorit: false, tooltip: "Hier treffen sich zwei und gehen in die selbe Richtung" },
            { id: undefined, code: "treffpunkt_l",     name: "Treffpunkt L",       kategoriePfad: "verbindungen", favorit: false, tooltip: "Hier sind zwei andere die auch in die selbe Richtung wollen" },
            { id: undefined, code: "geraeteanschluss", name: "Geräteanschluss",    kategoriePfad: "verbindungen", favorit: false, tooltip: "Dieser Anschluss fühlt sich im Gerätekasten am wohlsten" },
            { id: undefined, code: "potenzial",        name: "Potenzialpunkt",     kategoriePfad: "verbindungen", favorit: false, tooltip: "Hier beginnt es" },
            { id: undefined, code: "unterbrechung",    name: "Unterbrechung (U)",  kategoriePfad: "verbindungen", favorit: false, tooltip: "Sie unterbricht alles, Grafik, Potenzial und deinen Workflow" },
            { id: undefined, code: "querverweis",      name: "Querverweis \u2192", kategoriePfad: "verbindungen", favorit: false, tooltip: "Schafft Verbindung, über Grenzen hinweg" },
            { id: undefined, code: "aderdefinition",        name: "Aderdefinition",        kategoriePfad: "verbindungen", favorit: false, tooltip: "sagt dir was für ne Ader da ist" },
            { id: undefined, code: "isoliert_gelegte_ader", name: "Isol. gelegte Ader",    kategoriePfad: "verbindungen", favorit: false, tooltip: "Ader ist an einem Ende isoliert abgeschlossen – kein Anschluss auf dieser Seite" }
        ]
        var r = []
        for (var i = 0; i < alleSymbole.length; i++)
            if (alleSymbole[i].kategoriePfad === kat) r.push(alleSymbole[i])
        return r
    }

    function favoritenListe() {
        var r = []
        for (var i = 0; i < alleSymbole.length; i++)
            if (alleSymbole[i].favorit) r.push(alleSymbole[i])
        return r
    }

    function hatFavoriten() {
        for (var i = 0; i < alleSymbole.length; i++)
            if (alleSymbole[i].favorit) return true
        return false
    }

    // ── Zuletzt verwendet (session-only, max. 8 Einträge) ────────
    property var zuletzt: []

    function zuletztHinzufuegen(code) {
        var neu = [code]
        for (var i = 0; i < zuletzt.length && neu.length < 8; i++) {
            if (zuletzt[i] !== code) neu.push(zuletzt[i])
        }
        zuletzt = neu
    }

    function symbolFinden(code) {
        var i
        for (i = 0; i < alleSymbole.length; i++)
            if (alleSymbole[i].code === code) return alleSymbole[i]
        for (i = 0; i < eigeneSymboleList.length; i++)
            if (eigeneSymboleList[i].code === code) return eigeneSymboleList[i]
        var verb = symboleInKategorie("verbindungen")
        for (i = 0; i < verb.length; i++)
            if (verb[i].code === code) return verb[i]
        return null
    }

    function zuletztListe() {
        var r = []
        for (var i = 0; i < zuletzt.length; i++) {
            var sym = symbolFinden(zuletzt[i])
            if (sym) r.push(sym)
        }
        return r
    }

    function kategorieName(id) {
        var namen = {
            "kontakte":      "Kontakte",
            "schutz":        "Schutzgeräte",
            "antriebe":      "Antriebe",
            "passive":       "Passive",
            "signalgeraete": "Signalgeräte",
            "klemmen":       "Klemmen",
            "verbindungen":  "Verbindungen",
            "sps_pls":       "SPS / PLS",
            "kfz":           "KFZ-Elektrik",
            "arduino":       "Arduino",
            "sensoren":      "Sensoren",
            "eigene":        qsTr("Eigene Symbole")
        }
        return namen[id] || id
    }

    function favoritToggle(sym) {
        if (sym.id === undefined) return   // Verbindungselemente haben keine DB-Favoriten
        var neuFav = !sym.favorit
        db.symbolFavoritSetzen(sym.id, neuFav)
        // Liste lokal aktualisieren (ohne reload)
        var neu = []
        for (var i = 0; i < alleSymbole.length; i++) {
            if (alleSymbole[i].id === sym.id) {
                var kopie = {}
                for (var k in alleSymbole[i]) kopie[k] = alleSymbole[i][k]
                kopie.favorit = neuFav
                neu.push(kopie)
            } else {
                neu.push(alleSymbole[i])
            }
        }
        alleSymbole = neu
    }

    Component.onCompleted: laden()

    // ── Gesamt-Layout ─────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Symbole / Makros Toggle ───────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: theme.surfaceDeep

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                spacing: 3

                Repeater {
                    model: ["symbole", "makros"]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 22; radius: 3
                        color:        root.paletteModus === modelData ? theme.activeItemAlt : theme.surface
                        border.color: root.paletteModus === modelData ? theme.accent : theme.border

                        Text {
                            anchors.centerIn: parent
                            text: modelData === "symbole" ? qsTr("Symbole") : qsTr("Makros")
                            font.pixelSize: 10; font.weight: Font.Medium
                            color: root.paletteModus === modelData ? theme.accent : theme.borderLight
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.paletteModus !== modelData
                            onClicked: root.paletteModus = modelData
                        }
                    }
                }
            }
        }

        Rectangle { height: 1; color: theme.border; Layout.fillWidth: true }

        // ── Makro-Palette ─────────────────────────────────────
        MakroPalette {
            id: makroPalette
            Layout.fillWidth: true
            Layout.fillHeight: true
            theme: root.theme
            visible: root.paletteModus === "makros"
            onMakroEinfuegenAngefordert: function(id, name) {
                root.makroEinfuegenAngefordert(id, name)
            }
        }

        // ── Navigationszeile (Zurück / Titel) ─────────────────
        Rectangle {
            Layout.fillWidth: true
            height: visible ? 28 : 0
            visible: root.paletteModus === "symbole" && root.ansicht !== "kategorien"
            color: "transparent"

            RowLayout {
                anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                spacing: 2

                Rectangle {
                    width: 22; height: 22; radius: 3
                    color: backMa.containsMouse ? theme.hover : "transparent"
                    Text {
                        anchors.centerIn: parent; text: qsTr("\u2190")
                        font.pixelSize: 14; color: theme.accent
                    }
                    MouseArea {
                        id: backMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.ansicht = "kategorien"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.ansicht === "favoriten" ? "\u2605 Favoriten"
                        : root.ansicht === "zuletzt"   ? "\u23f3 Zuletzt verwendet"
                        : root.kategorieName(root.aktiveKategorie)
                    font.pixelSize: 10; font.weight: Font.Medium
                    color: theme.textSecondary; elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            height: (root.paletteModus === "symbole" && root.ansicht !== "kategorien") ? 1 : 0
            color: theme.border; Layout.fillWidth: true
        }

        // ── Scroll-Inhalt (nur Symbole-Modus) ────────────────
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.paletteModus === "symbole"
            contentWidth: root.width
            clip: true

            Column {
                width: root.width

                // ------------------------------------------------
                // KATEGORIE-ANSICHT
                // ------------------------------------------------
                Column {
                    width: parent.width
                    visible: root.ansicht === "kategorien"

                    // Zuletzt verwendet (nur wenn vorhanden, ganz oben)
                    KategorieZeile {
                        visible: root.zuletzt.length > 0
                        label: qsTr("\u23f3  Zuletzt verwendet")
                        onKlick: root.ansicht = "zuletzt"
                    }

                    // Favoriten-Zeile (nur wenn vorhanden)
                    KategorieZeile {
                        visible: root.hatFavoriten()
                        label: qsTr("\u2605  Favoriten")
                        highlight: true
                        onKlick: root.ansicht = "favoriten"
                    }

                    // Kategorie-Zeilen
                    Repeater {
                        model: root.alleSymbole.length > 0 ? root.kategorienListe() : []
                        delegate: KategorieZeile {
                            label: root.kategorieName(modelData)
                            onKlick: {
                                root.aktiveKategorie = modelData
                                root.ansicht = "symbole"
                            }
                        }
                    }

                    // Feste Verbindungselemente-Kategorie
                    KategorieZeile {
                        label: qsTr("\u21AA  Verbindungen")
                        onKlick: { root.aktiveKategorie = "verbindungen"; root.ansicht = "symbole" }
                    }

                    // Eigene Symbole (nur sichtbar wenn vorhanden)
                    KategorieZeile {
                        visible:   root.eigeneSymboleList.length > 0
                        height:    visible ? 34 : 0
                        label:     qsTr("\u2B50  Eigene Symbole")
                        highlight: true
                        onKlick:   { root.aktiveKategorie = "eigene"; root.ansicht = "symbole" }
                    }

                    KategorieZeile {
                        label:     qsTr("+  Neues Symbol")
                        highlight: true
                        onKlick:   root.editorOeffnen("")
                    }
                }

                // ------------------------------------------------
                // SYMBOL-ANSICHT (Kategorie, Favoriten oder Zuletzt)
                // ------------------------------------------------
                Column {
                    width: parent.width
                    visible: root.ansicht === "symbole" || root.ansicht === "favoriten" || root.ansicht === "zuletzt"

                    Repeater {
                        model: {
                            if (root.ansicht === "favoriten") return root.favoritenListe()
                            if (root.ansicht === "zuletzt")   return root.zuletztListe()
                            if (root.ansicht === "symbole")   return root.symboleInKategorie(root.aktiveKategorie)
                            return []
                        }

                        delegate: SymbolZeile {
                            sym:    modelData
                            aktiv:  root.aktivesSymbol === modelData.code
                            onSymbolKlick: {
                                root.aktivesSymbol = (root.aktivesSymbol === modelData.code) ? "" : modelData.code
                                if (root.aktivesSymbol !== "") {
                                    root.symbolGewaehlt(root.aktivesSymbol)
                                    root.zuletztHinzufuegen(root.aktivesSymbol)
                                }
                            }
                            markiertLoeschen: root.istMarkiertLoeschen(modelData.code)
                            onFavKlick:       root.favoritToggle(modelData)
                            onVorlageKopieren: root.vorlageFuerEditor(modelData.code)
                            onBearbeiten:      root.editorOeffnen(modelData.code)
                            onMarkierenToggle: root.markierungLoeschenToggle(modelData)
                            onLoeschen: {
                                symbolDefinitionModel.symbolLoeschen(modelData.code)
                                root.laden()
                                if (root.eigeneSymboleList.length === 0)
                                    root.ansicht = "kategorien"
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // Inline-Komponenten
    // ============================================================

    component KategorieZeile: Rectangle {
        property string label:     ""
        property bool   highlight: false
        signal klick()

        width: root.width; height: 34
        color: kzMa.containsMouse ? theme.hover : "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: label; font.pixelSize: 11
                color: highlight ? theme.akzentGold : theme.textSecondary
                elide: Text.ElideRight
            }
            Text {
                text: qsTr("\u203a"); font.pixelSize: 14; color: theme.borderLight
            }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width - 12; height: 1; color: theme.divider; anchors.horizontalCenter: parent.horizontalCenter }

        MouseArea {
            id: kzMa; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: klick()
        }
    }

    component SymbolZeile: Item {
        property var  sym:              null
        property bool aktiv:            false
        property bool markiertLoeschen: false
        signal symbolKlick()
        signal favKlick()
        signal vorlageKopieren()
        signal bearbeiten()
        signal markierenToggle()
        signal loeschen()

        width: root.width; height: 52

        Rectangle {
            anchors { fill: parent; margins: 2 }
            radius: 4
            color:        aktiv ? theme.activeItemAlt : "transparent"
            border.color: aktiv ? theme.accent : "transparent"
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                spacing: 4

                // Canvas-Vorschau
                Canvas {
                    id: vorschau
                    Layout.preferredWidth:  56
                    Layout.preferredHeight: 32
                    property string symCode: sym ? sym.code : ""

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = aktiv ? theme.accent : theme.textSubtle
                        ctx.lineWidth   = 1.5
                        drawByPrimitivPalette(ctx, symCode, width, height)
                    }

                    function drawByPrimitivPalette(ctx, symbolId, w, h) {
                        var prims = symbolDefinitionModel.primitiveFuerSymbol(symbolId)
                        // Einheitlicher Skalierungsfaktor statt getrennt w/h, damit Kreise/Bögen
                        // nicht zu Ellipsen verzerrt werden, wenn die Vorschau-Box (56x32) ein
                        // anderes Seitenverhältnis hat als die Symbolgröße (z.B. 16x16mm).
                        var scale = Math.min(w, h)
                        var offX  = (w - scale) / 2
                        var offY  = (h - scale) / 2
                        function sx(nx) { return nx * scale + offX }
                        function sy(ny) { return ny * scale + offY }
                        for (var i = 0; i < prims.length; i++) {
                            var p = prims[i]
                            ctx.setLineDash([])
                            switch (p.typ) {
                                case "linie":
                                    ctx.beginPath()
                                    ctx.moveTo(sx(p.x1), sy(p.y1))
                                    ctx.lineTo(sx(p.x2), sy(p.y2))
                                    ctx.stroke()
                                    break
                                case "rechteck":
                                    ctx.strokeRect(sx(p.x1), sy(p.y1),
                                                   (p.x2 - p.x1) * scale, (p.y2 - p.y1) * scale)
                                    break
                                case "rechteck_gefuellt":
                                    ctx.save()
                                    ctx.fillStyle = ctx.strokeStyle
                                    ctx.fillRect(sx(p.x1), sy(p.y1),
                                                 (p.x2 - p.x1) * scale, (p.y2 - p.y1) * scale)
                                    ctx.restore()
                                    break
                                case "kreis_offen":
                                    ctx.beginPath()
                                    ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale, 0, 2 * Math.PI)
                                    ctx.stroke()
                                    break
                                case "kreis_gefuellt":
                                    ctx.save()
                                    ctx.fillStyle = ctx.strokeStyle
                                    ctx.beginPath()
                                    ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale, 0, 2 * Math.PI)
                                    ctx.fill()
                                    ctx.restore()
                                    break
                                case "bogen":
                                    ctx.beginPath()
                                    ctx.arc(sx(p.x1), sy(p.y1), p.radius * scale,
                                            p.winkel_von * Math.PI / 180,
                                            p.winkel_bis * Math.PI / 180,
                                            p.bogen_gegen_uhrzeiger)
                                    ctx.stroke()
                                    break
                                case "text":
                                    ctx.save()
                                    ctx.fillStyle    = ctx.strokeStyle
                                    ctx.font         = (p.schrift_fett ? "bold " : "") +
                                                       Math.round(p.schrift_relativ * scale) + "px sans-serif"
                                    ctx.textAlign    = p.text_align    || "center"
                                    ctx.textBaseline = p.text_baseline || "middle"
                                    ctx.fillText(p.text_inhalt, sx(p.x1), sy(p.y1))
                                    ctx.restore()
                                    break
                                case "dreieck_gefuellt":
                                    ctx.save()
                                    ctx.fillStyle = ctx.strokeStyle
                                    ctx.beginPath()
                                    ctx.moveTo(sx(p.x1), sy(p.y1))
                                    ctx.lineTo(sx(p.x2), sy(p.y2))
                                    ctx.lineTo(sx(p.x3), sy(p.y3))
                                    ctx.closePath()
                                    ctx.fill()
                                    ctx.restore()
                                    break
                            }
                        }
                    }

                    Connections {
                        target: root
                        function onAktivesSymbolChanged() { vorschau.requestPaint() }
                        function onAlleSymboleChanged()   { vorschau.requestPaint() }
                        function onThemeChanged()         { vorschau.requestPaint() }
                    }

                    // Löschmarkierung-Badge (SYM-LOESCH-MARKIERUNG-01)
                    Text {
                        anchors { top: parent.top; right: parent.right; margins: -2 }
                        visible: markiertLoeschen
                        text: "🗑"
                        font.pixelSize: 12
                        ToolTip.visible: markierBadgeMa.containsMouse
                        ToolTip.text: qsTr("Zum Löschen markiert")
                        ToolTip.delay: 400
                        MouseArea { id: markierBadgeMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                }

                // Name + Favorit-Knopf
                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: sym ? sym.name : ""
                        font.pixelSize: 9; color: aktiv ? theme.accent : theme.textMuted
                        width: parent.width; elide: Text.ElideRight
                    }
                }

                // Favorit-Stern
                Text {
                    text: (sym && sym.favorit) ? "\u2605" : "\u2606"
                    font.pixelSize: 13
                    color: (sym && sym.favorit) ? theme.akzentGold : theme.borderDark
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: favKlick()
                    }
                }
            }

            MouseArea {
                anchors { fill: parent; rightMargin: 22 }
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        if (sym && sym.id !== undefined) kontextMenu.popup()
                    } else {
                        symbolKlick()
                    }
                }
            }

            Menu {
                id: kontextMenu
                MenuItem {
                    text: qsTr("Als Vorlage kopieren")
                    onTriggered: vorlageKopieren()
                }
                MenuSeparator { visible: sym && sym.ist_builtin === false }
                MenuItem {
                    visible: sym && sym.ist_builtin === false
                    height:  visible ? implicitHeight : 0
                    text:    qsTr("Bearbeiten")
                    onTriggered: bearbeiten()
                }
                MenuItem {
                    visible: sym && sym.ist_builtin === false
                    height:  visible ? implicitHeight : 0
                    text:    qsTr("Löschen")
                    onTriggered: loeschen()
                }
                MenuSeparator {}
                MenuItem {
                    text: markiertLoeschen ? qsTr("Löschmarkierung aufheben") : qsTr("Zum Löschen markieren")
                    onTriggered: markierenToggle()
                }
            }

            ToolTip.visible: szHover.containsMouse && sym !== null && sym.tooltip !== undefined && sym.tooltip !== ""
            ToolTip.text:    (sym && sym.tooltip) ? sym.tooltip : ""
            ToolTip.delay:   600
            MouseArea { id: szHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        }

        Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width - 8; height: 1; color: theme.divider }
    }

    DebugLabel { panelName: qsTr("Symbolpalette"); visible: root.debug }
}
