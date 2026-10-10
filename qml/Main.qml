import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "components"
import "wiki"
import "einstellungen"
import "sps"
import "fun"
import "logos"
import "rosi"
import stroemling

// ProjektStartAnsicht ist direkt im qml/-Ordner, kein Unterordner-Import nötig

ApplicationWindow {
    id:         root
    visible:    true
    width:      1200
    height:     800
    visibility: Window.Maximized
    title:      qsTr("Strömling Design")
    color:      appTheme.surface
    flags:      Qt.Window | Qt.FramelessWindowHint

    // Globale Palette: sorgt dafür dass TextField-Hintergründe im Theme-Farbton erscheinen
    palette.base: appTheme.inputBg
    palette.text: appTheme.textPrimary

    property int    aktivProjektId:   -1
    property string aktivProjektName: ""
    property string aktiveAnsicht:    "projekte"

    // F1-Kontexthilfe: aktiveAnsicht -> Titel des passenden Wiki-Artikels.
    // Ansichten ohne Eintrag fallen auf die Shortcut-Übersicht zurück.
    readonly property var f1KontextArtikel: ({
        "projekte":            "Programmübersicht",
        "seiten":              "Schaltplan – Erste Schritte",
        "kabelrechner":        "Kabelrechner",
        "ibn":                 "IBN – Inbetriebnahme",
        "fehlersuche":         "Fehlersuchmodus",
        "achievements":        "Errungenschaften (Achievements)",
        "meldungen":           "Meldungen: Toast statt Dialog",
        "sps":                 "SPS/PLS-Integration",
        "steckverbinder_editor": "Steckverbinder und konfektionierte Kabel anlegen",
        "konfkabel_editor":    "Steckverbinder und konfektionierte Kabel anlegen",
        "kontakt_editor":      "Steckverbinder und konfektionierte Kabel anlegen",
        "symbol_editor":       "Symbole platzieren und bearbeiten",
        "bauteile":            "Bauteilbibliothek – Kategorien und Verwaltung",
        "klemmen_editor":      "Klemmen-Typ anlegen und bearbeiten",
        "kabel_editor":        "Kabel-Typ anlegen und bearbeiten",
        "normblatt":           "Normblatt-Vorlagen selbst gestalten",
        "einstellungen":       "Einstellungen",
        "stueckliste":         "Listen-Ansicht – Stückliste, Aderliste & Co."
    })

    property int    aktivSeiteId:   -1
    property string aktivSeiteName: ""

    // IBN-ZENTRIEREN-SCOPE-01: gehören logisch zum IBN-Sprung-Timer weiter
    // unten, müssen aber hier auf root liegen - Handler und Timer greifen
    // beide über "root._ibnZentriereX/Y" zu, nicht über die SplitView, in
    // der sie ursprünglich (falsch) deklariert waren.
    property real _ibnZentriereX: 0
    property real _ibnZentriereY: 0

    // gitVerfuegbar() ist ein blockierender Prozessaufruf – einmal cachen reicht
    readonly property bool gitVerfuegbar: db.gitVerfuegbar()

    // ── Tab / Split-Zustand ──────────────────────────────────────────────
    property int  fokussiertesPanel: 1     // 1 oder 2
    property bool splitAktiv:        false
    property bool splitHorizontal:   true

    // Zugriff auf den aktiven Canvas-Panel
    property var aktiverCanvas: fokussiertesPanel === 1 ? panel1.canvas : panel2.canvas

    property string aktivProjektHintergrund: "#fdf8e8"

    property bool   debugModeAktiv:         false
    property bool   drcPanelOffen:          false
    property bool   suchPanelOffen:         false

    property string symbolEditorId:         ""
    property string symbolEditorVorlageId:  ""
    property string symbolEditorVorher:     "projekte"

    // ── Klemmen-Queue: sequentielles Platzieren ───────────────────────────
    property var  _klemmeQueue:     []
    property bool _klemmeQueueAktiv: false

    function _klemmeQueueNaechste() {
        if (_klemmeQueue.length === 0) { _klemmeQueueAktiv = false; return }
        var q    = _klemmeQueue.slice()
        var item = q.shift()
        _klemmeQueue = q
        if (aktivSeiteId < 0) { _klemmeQueueAktiv = false; return }
        // bereits platziert → überspringen
        if (db.klemmeAnschlussIstPlatziert(item.klemmeId, item.anschlussBezeichnung)) {
            _klemmeQueueNaechste(); return
        }
        var p = fokussiertesPanel === 1 ? panel1 : panel2
        p.canvas.paletteSymbolId   = "klemme_anschluss"
        p.canvas.paletteExtraDaten = {
            "bauteilKlemmeId":      item.bauteilKlemmeId,
            "anschlussBezeichnung": item.anschlussBezeichnung,
            "platziermodus":        "verknuepft",
            "bmk":                  item.bmk,
            "klemmeId":             item.klemmeId
        }
        p.canvas.aktivesWerkzeug = "symbol"
        p.canvas.forceActiveFocus()
    }

    // ── Steckverbinder-Kontakt-Queue: sequentielles Platzieren ────────────
    property var  _kontaktQueue:     []
    property bool _kontaktQueueAktiv: false

    function _kontaktQueueNaechste() {
        if (_kontaktQueue.length === 0) { _kontaktQueueAktiv = false; return }
        var q    = _kontaktQueue.slice()
        var item = q.shift()
        _kontaktQueue = q
        if (aktivSeiteId < 0) { _kontaktQueueAktiv = false; return }
        // bereits platziert → überspringen
        if (db.steckverbinderPositionIstPlatziert(item.positionId)) {
            _kontaktQueueNaechste(); return
        }
        var p = fokussiertesPanel === 1 ? panel1 : panel2
        p.canvas.paletteSymbolId   = item.symbolId
        p.canvas.paletteExtraDaten = {
            "platziermodus":   "verknuepft",
            "geraetekastenId": item.geraetekastenId,
            "positionId":      item.positionId,
            "bmk":             item.bmk
        }
        p.canvas.aktivesWerkzeug = "symbol"
        p.canvas.forceActiveFocus()
    }

    // ── Theme-System ─────────────────────────────────────────────
    readonly property var themes: ({
        "dunkel": {
            name:          "Dunkel",
            surface:       "#0a1628",
            sidebar:       "#0d1b2a",
            surfaceDeep:   "#09121e",
            inputBg:       "#0a1628",
            border:        "#1e3a5f",
            borderLight:   "#4a6080",
            borderDark:    "#2a4060",
            divider:       "#111e2e",
            textPrimary:   "#e8f0fe",
            textSecondary: "#c0d8f0",
            textMuted:     "#8899aa",
            textBright:    "#c8d8e8",
            textSubtle:    "#7a9ab8",
            accent:        "#4a9eff",
            accentLight:   "#7aaddd",
            logoGruen:     "#55d400",
            akzentGold:    "#f0c040",
            panelMid:      "#5577aa",
            hover:         "#0f2540",
            hoverSidebar:  "#162d4a",
            hoverBtn:      "#0d1528",
            activeItem:    "#1e3a5f",
            activeItemAlt: "#1a3a6a",
            btnPrimary:    "#1a4a8a",
            btnDisabled:   "#1a2a3a",
            badge:         "#1a3050",
            tableEven:     "#070e1a",
            tableOdd:      "#0a1321",
            tableHeader:   "#0d1f33"
        },
        "hell": {
            name:          "Hell",
            surface:       "#f0f4f8",
            sidebar:       "#e2eaf4",
            surfaceDeep:   "#d8e4f0",
            inputBg:       "#f4f8fc",
            border:        "#7a9ab8",
            borderLight:   "#6080a0",
            borderDark:    "#405060",
            divider:       "#c8d8e8",
            textPrimary:   "#1a2a3a",
            textSecondary: "#2a4060",
            textMuted:     "#3a5878",
            textBright:    "#3a5070",
            textSubtle:    "#506070",
            accent:        "#1a6fd8",
            accentLight:   "#4a90c8",
            logoGruen:     "#000000",
            akzentGold:    "#3d7a00",
            panelMid:      "#3a6090",
            hover:         "#c8dced",
            hoverSidebar:  "#bccfe0",
            hoverBtn:      "#d4e5f2",
            activeItem:    "#b8d0e8",
            activeItemAlt: "#9bbcd8",
            btnPrimary:    "#1a6fd8",
            btnDisabled:   "#a0b8d0",
            badge:         "#c8dcea",
            tableEven:     "#f0f5f9",
            tableOdd:      "#e6eef4",
            tableHeader:   "#d8e4ee"
        },
        "blueprint": {
            name:          "Blueprint",
            surface:       "#0c1f50",
            sidebar:       "#081640",
            surfaceDeep:   "#050e28",
            inputBg:       "#081640",
            border:        "#1a3a80",
            borderLight:   "#2050a0",
            borderDark:    "#3060a0",
            divider:       "#0f2060",
            textPrimary:   "#ffffff",
            textSecondary: "#c0d8ff",
            textMuted:     "#7090cc",
            textBright:    "#e0f0ff",
            textSubtle:    "#6080c0",
            accent:        "#40d0ff",
            accentLight:   "#80e0ff",
            logoGruen:     "#55d400",
            akzentGold:    "#f0c040",
            panelMid:      "#4070c0",
            hover:         "#102570",
            hoverSidebar:  "#102060",
            hoverBtn:      "#0c1d60",
            activeItem:    "#1a3a80",
            activeItemAlt: "#1a4a90",
            btnPrimary:    "#1a5090",
            btnDisabled:   "#1a2a50",
            badge:         "#1a3070",
            tableEven:     "#060f28",
            tableOdd:      "#081540",
            tableHeader:   "#0a1845"
        }
    })

    property var appTheme: themes[AppTheme.activeName] || themes["dunkel"]

    Settings {
        id: langSettings
        category: "i18n"
        property string language: "system"
    }

    Settings {
        id: panelBreiten
        category: "panels"
        property int sidebarBreite:      200
        property int seitenBaumBreite:   280
        property int symbolPaletteBreite: 130
    }

    Settings {
        id:       funModusSettings
        category: "funmodus"
        property bool   aktiv:          false
        property int    wartezeitMin:   10
        property string gespraechTexte: "[]"
    }

    // Reaktiver Zwischenspeicher: wird initial aus Settings gelesen, dann per Signal aus
    // EinstellungenAnsicht aktualisiert (mehrere Settings-Objekte teilen keine Bindings).
    property string _funGesprTexte: funModusSettings.gespraechTexte

    property string aktivSprache: langSettings.language

    // ── Fun-Modus Idle-Detection ─────────────────────────────────
    // C++ Event-Filter erkennt Mausbewegung, Klicks, Tastatur und Scrollrad –
    // zuverlässiger als MouseArea (z=-999 bekommt keine Klicks von höheren Elementen).
    Connections {
        target: aktivitaetsMonitor
        function onAktivitaet() {
            if (funModusSettings.aktiv && root.aktivProjektId >= 0 && !funOverlay.visible)
                idleTimer.restart()
        }
    }

    Timer {
        id:       idleTimer
        interval: funModusSettings.wartezeitMin * 60 * 1000
        repeat:   false

        onTriggered: {
            var c = root.aktiverCanvas
            if (!c) return
            if (root.aktiveAnsicht !== "seiten") return
            if (root.aktivSeiteId < 0) return
            if (c.elementeModel.anzahl < 2) return
            if (c.auswahl && c.auswahl.length > 0) return

            funOverlay.canvas  = c
            funOverlay.visible = true
        }
    }

    // Wenn Fun-Modus in den Einstellungen aktiviert wird: Timer sofort starten
    Connections {
        target: funModusSettings
        function onAktivChanged() {
            if (funModusSettings.aktiv && root.aktivProjektId >= 0)
                idleTimer.restart()
            else
                idleTimer.stop()
        }
    }

    Shortcut {
        sequence:    "Ctrl+Shift+Alt+D"
        context:     Qt.ApplicationShortcut
        onActivated: root.debugModeAktiv = !root.debugModeAktiv
    }

    Shortcut {
        sequence:    "Ctrl+P"
        context:     Qt.ApplicationShortcut
        onActivated: root.suchPanelOffen = !root.suchPanelOffen
    }

    Shortcut {
        sequence:    "Ctrl+Shift+P"
        context:     Qt.ApplicationShortcut
        enabled:     root.aktivProjektId >= 0
        onActivated: pdfExportDialog.open()
    }

    PdfExportDialog {
        id:        pdfExportDialog
        theme:     appTheme
        projektId: root.aktivProjektId
        seiteId:   root.aktivSeiteId
        debug:     root.debugModeAktiv
    }

    onSuchPanelOffenChanged: {
        if (suchPanelOffen) suchPanel.oeffnen()
    }

    // ── Eigene Titelleiste ───────────────────────────────────────
    AppTitelleiste {
        id:          appTitelleiste
        anchors { top: parent.top; left: parent.left; right: parent.right }
        theme:       appTheme
        projektName: root.aktivProjektName
    }


    // ── Layout ───────────────────────────────────────────────────
    RowLayout {
        anchors { top: appTitelleiste.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing:      0

        // --------------------------------------------------------
        // Navigationsleiste (Linke Sidebar)
        // --------------------------------------------------------
        AppSidebar {
            id:                    sidebar
            Layout.preferredWidth: panelBreiten.sidebarBreite
            Layout.fillHeight:     true
            theme:                 appTheme
            debug:                 root.debugModeAktiv
            aktiveAnsicht:         root.aktiveAnsicht
            aktivProjektId:        root.aktivProjektId
            aktivProjektName:      root.aktivProjektName
            themes:                root.themes
            themeName:             AppTheme.activeName

            onWidthChanged: if (width >= 150) panelBreiten.sidebarBreite = width

            onAnsichtGewaehlt: function(ansicht) { root.aktiveAnsicht = ansicht }
            onPdfExportAngefordert: pdfExportDialog.open()
            onThemeGewaehlt: function(name) { AppTheme.setTheme(name) }
            onSymbolEditorAngefordert: {
                root.symbolEditorVorher    = root.aktiveAnsicht
                root.symbolEditorId        = ""
                root.symbolEditorVorlageId = ""
                root.aktiveAnsicht         = "symbol_editor"
            }
        }


        // Drag-Handle Sidebar ↔ Hauptbereich
        Rectangle {
            id:                sidebarGriff
            width:             4
            Layout.fillHeight: true
            color:             sidebarMa.pressed || sidebarMa.containsMouse
                               ? appTheme.accent : appTheme.border

            MouseArea {
                id:          sidebarMa
                anchors.fill: parent
                cursorShape: Qt.SizeHorCursor
                hoverEnabled: true

                property real _startSceneX: 0
                property real _startW:      0

                onPressed: (mouse) => {
                    _startSceneX = mapToItem(null, mouse.x, mouse.y).x
                    _startW      = sidebar.Layout.preferredWidth
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    var sceneX = mapToItem(null, mouse.x, mouse.y).x
                    var newW   = Math.max(150, Math.min(350, _startW + sceneX - _startSceneX))
                    sidebar.Layout.preferredWidth = newW
                    panelBreiten.sidebarBreite    = newW
                }
            }
        }

        // --------------------------------------------------------
        // Hauptbereich
        // --------------------------------------------------------
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // Projektverwaltung
            ProjektStartAnsicht {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "projekte"
                theme:        appTheme
                debug:        root.debugModeAktiv
                onZurueck: root.aktiveAnsicht = "seiten"
                onProjektMetaGeaendert: function(id) {
                    if (id === root.aktivProjektId) {
                        panel1.normblattNeuLaden()
                        panel2.normblattNeuLaden()
                    }
                }
            }

            // Seitenbaum + Canvas (Split-Layout)
            Item {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "seiten"

                RowLayout {
                    anchors {
                        left:   parent.left
                        right:  parent.right
                        top:    parent.top
                        bottom: suchPanel.top
                    }
                    spacing: 0

                    SeitenBaum {
                        id:                    seitenBaum
                        Layout.preferredWidth: panelBreiten.seitenBaumBreite
                        Layout.fillHeight:     true
                        theme:             appTheme
                        debug:                 root.debugModeAktiv
                        projektId:             root.aktivProjektId
                        projektName:           root.aktivProjektName
                        aktivSeiteId:          root.aktivSeiteId

                        onSeiteGewaehlt: function(id, blattnummer, bezeichnung) {
                            var p = root.fokussiertesPanel === 1 ? panel1 : panel2
                            p.seiteOeffnen(id, blattnummer, bezeichnung)
                        }
                        onSeiteAlsTabOeffnen: function(id, blattnummer, bezeichnung) {
                            var p = root.fokussiertesPanel === 1 ? panel1 : panel2
                            p.seiteOeffnen(id, blattnummer, bezeichnung)
                        }
                        onSeiteGeloescht: function(id) {
                            panel1.seiteEntfernen(id)
                            panel2.seiteEntfernen(id)
                            if (root.aktivSeiteId === id) {
                                root.aktivSeiteId   = -1
                                root.aktivSeiteName = ""
                            }
                        }
                        onSeiteFormatGeaendert: function(seiteId) {
                            panel1.normblattNeuLaden()
                            panel2.normblattNeuLaden()
                        }
                        onSprungAngefordert: function(seiteId, blattnr, seiteBez, wx, wy) {
                            if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                            var p = root.fokussiertesPanel === 1 ? panel1 : panel2
                            p.seiteOeffnenUndZentrieren(seiteId, blattnr, seiteBez, wx, wy)
                        }
                        onKlemmenAnschlussPlatzieren: function(klemmeId, bauteilKlemmeId, anschlussBezeichnung, bmk) {
                            if (root.aktivSeiteId < 0) { meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false); return }
                            if (db.klemmeAnschlussIstPlatziert(klemmeId, anschlussBezeichnung)) { meldungManager.zeigen(qsTr("Dieser Klemmenanschluss ist bereits platziert."), false); return }
                            root.aktiverCanvas.paletteSymbolId  = "klemme_anschluss"
                            root.aktiverCanvas.paletteExtraDaten = {
                                "bauteilKlemmeId":      bauteilKlemmeId,
                                "anschlussBezeichnung": anschlussBezeichnung,
                                "platziermodus":        "verknuepft",
                                "bmk":                  bmk,
                                "klemmeId":             klemmeId
                            }
                            root.aktiverCanvas.aktivesWerkzeug = "symbol"
                            root.aktiverCanvas.forceActiveFocus()
                        }
                        onKlemmenSequentiellStarten: function(queueJson) {
                            var queue = JSON.parse(queueJson)
                            if (!queue || queue.length === 0) return
                            if (root.aktivSeiteId < 0) { meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false); return }
                            if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                            root._klemmeQueue      = queue
                            root._klemmeQueueAktiv = true
                            root._klemmeQueueNaechste()
                        }
                        onBetriebsmittelKontaktPlatzieren: function(betriebsmittelId, symbolId, bmk, pinBez) {
                            if (root.aktivSeiteId < 0) { meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false); return }
                            if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                            root.aktiverCanvas.paletteBetriebsmittelId = betriebsmittelId
                            root.aktiverCanvas.paletteSymbolId         = symbolId
                            var ed = { "bmk": bmk }
                            var pbKeys = pinBez ? Object.keys(pinBez) : []
                            if (pbKeys.length > 0) ed["pinBez"] = pinBez
                            root.aktiverCanvas.paletteExtraDaten       = ed
                            root.aktiverCanvas.aktivesWerkzeug         = "symbol"
                            root.aktiverCanvas.forceActiveFocus()
                        }
                        onSteckverbinderKontaktPlatzieren: function(geraetekastenId, positionId, symbolId, bmk) {
                            if (root.aktivSeiteId < 0) { meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false); return }
                            if (db.steckverbinderPositionIstPlatziert(positionId)) { meldungManager.zeigen(qsTr("Diese Position ist bereits platziert."), false); return }
                            if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                            root.aktiverCanvas.paletteSymbolId  = symbolId
                            root.aktiverCanvas.paletteExtraDaten = {
                                "platziermodus":   "verknuepft",
                                "geraetekastenId": geraetekastenId,
                                "positionId":      positionId,
                                "bmk":             bmk
                            }
                            root.aktiverCanvas.aktivesWerkzeug  = "symbol"
                            root.aktiverCanvas.forceActiveFocus()
                        }
                        onSteckverbinderSequentiellStarten: function(queueJson) {
                            var queue = JSON.parse(queueJson)
                            if (!queue || queue.length === 0) return
                            if (root.aktivSeiteId < 0) { meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false); return }
                            if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                            root._kontaktQueue      = queue
                            root._kontaktQueueAktiv = true
                            root._kontaktQueueNaechste()
                        }
                        onBauteilPlatzieren: function(bauteilId, symbolId, bezeichnung) {
                            if (root.aktivSeiteId < 0) { meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false); return }
                            if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                            root.aktiverCanvas.paletteSymbolId   = symbolId
                            root.aktiverCanvas.paletteExtraDaten = { "bauteilId": bauteilId, "bezeichnung": bezeichnung }
                            root.aktiverCanvas.aktivesWerkzeug   = "symbol"
                            root.aktiverCanvas.forceActiveFocus()
                        }

                        onWidthChanged: if (width >= 180) panelBreiten.seitenBaumBreite = width
                    }

                    // Drag-Handle SeitenBaum ↔ SymbolPalette
                    Rectangle {
                        id:                seitenBaumGriff
                        width:             4
                        Layout.fillHeight: true
                        color:             seitenBaumMa.pressed || seitenBaumMa.containsMouse
                                           ? appTheme.accent : appTheme.border

                        MouseArea {
                            id:          seitenBaumMa
                            anchors.fill: parent
                            cursorShape: Qt.SizeHorCursor
                            hoverEnabled: true

                            property real _startSceneX: 0
                            property real _startW:      0

                            onPressed: (mouse) => {
                                _startSceneX = mapToItem(null, mouse.x, mouse.y).x
                                _startW      = seitenBaum.Layout.preferredWidth
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed) return
                                var sceneX = mapToItem(null, mouse.x, mouse.y).x
                                var newW   = Math.max(180, Math.min(500, _startW + sceneX - _startSceneX))
                                seitenBaum.Layout.preferredWidth = newW
                                panelBreiten.seitenBaumBreite    = newW
                            }
                        }
                    }

                    SymbolPalette {
                        id:                    symbolPalette
                        Layout.preferredWidth: panelBreiten.symbolPaletteBreite
                        Layout.fillHeight:     true
                        theme:                 appTheme
                        debug:                 root.debugModeAktiv
                        projektId:             root.aktivProjektId
                        onSymbolGewaehlt: function(symCode) {
                            root.aktiverCanvas.paletteSymbolId = symCode
                            root.aktiverCanvas.aktivesWerkzeug = "symbol"
                            root.aktiverCanvas.forceActiveFocus()
                        }
                        onMakroEinfuegenAngefordert: function(makroId, name) {
                            if (root.aktivSeiteId < 0) { meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false); return }
                            root.aktiveAnsicht = "seiten"
                            root.aktiverCanvas.makroEinfuegenId   = makroId
                            root.aktiverCanvas.makroEinfuegenName = name
                            root.aktiverCanvas.aktivesWerkzeug    = "makroEinfuegen"
                        }
                        onEditorOeffnen: function(symbolId) {
                            root.symbolEditorVorher    = root.aktiveAnsicht
                            root.symbolEditorId        = symbolId
                            root.symbolEditorVorlageId = ""
                            root.aktiveAnsicht         = "symbol_editor"
                        }
                        onVorlageFuerEditor: function(quellId) {
                            root.symbolEditorVorher    = root.aktiveAnsicht
                            root.symbolEditorId        = ""
                            root.symbolEditorVorlageId = quellId
                            root.aktiveAnsicht         = "symbol_editor"
                        }

                        onWidthChanged: if (width >= 90) panelBreiten.symbolPaletteBreite = width
                    }

                    // Drag-Handle SymbolPalette \u2194 Canvas
                    Rectangle {
                        id:                symbolPaletteGriff
                        width:             4
                        Layout.fillHeight: true
                        color:             symbolPaletteMa.pressed || symbolPaletteMa.containsMouse
                                           ? appTheme.accent : appTheme.border

                        MouseArea {
                            id:          symbolPaletteMa
                            anchors.fill: parent
                            cursorShape: Qt.SizeHorCursor
                            hoverEnabled: true

                            property real _startSceneX: 0
                            property real _startW:      0

                            onPressed: (mouse) => {
                                _startSceneX = mapToItem(null, mouse.x, mouse.y).x
                                _startW      = symbolPalette.Layout.preferredWidth
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed) return
                                var sceneX = mapToItem(null, mouse.x, mouse.y).x
                                var newW   = Math.max(90, Math.min(400, _startW + sceneX - _startSceneX))
                                symbolPalette.Layout.preferredWidth = newW
                                panelBreiten.symbolPaletteBreite    = newW
                            }
                        }
                    }

                    SplitView {
                        id:                arbeitsSplitView
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        orientation:       root.splitHorizontal ? Qt.Horizontal : Qt.Vertical

                        CanvasPanel {
                            id:                   panel1
                            SplitView.fillWidth:  true
                            SplitView.fillHeight: true
                            SplitView.minimumWidth:  200
                            SplitView.minimumHeight: 100
                            theme:            appTheme
                            debug:            root.debugModeAktiv
                            projektId:        root.aktivProjektId

                            hintergrundFarbe: root.aktivProjektHintergrund
                            fokussiert:       root.fokussiertesPanel === 1 && root.splitAktiv
                            splitSchliessbar: root.splitAktiv
                            elementeModel:    elementeModel1

                            onSplitSchliessen: {
                                root.splitAktiv        = false
                                root.fokussiertesPanel = 1
                                panel1.canvas.forceActiveFocus()
                            }
                            onPanelAngeklickt:        root.fokussiertesPanel = 1
                            onAktivSeiteIdChanged: {
                                if (root.fokussiertesPanel === 1) {
                                    root.aktivSeiteId   = panel1.aktivSeiteId
                                    root.aktivSeiteName = panel1.aktivSeiteName
                                }
                            }
                            onHintergrundGeaendert: function(farbe) {
                                root.aktivProjektHintergrund = farbe
                                db.projektHintergrundSpeichern(root.aktivProjektId, farbe)
                            }
                            onQuerverweisNavigieren: function(seiteId) {
                                if (root.fokussiertesPanel === 1) {
                                    root.aktivSeiteId   = seiteId
                                    root.aktivSeiteName = panel1.aktivSeiteName
                                }
                            }
                            onGkSprungAngefordert: function(seiteId, blattnr, seiteBez, wx, wy) {
                                if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                                panel1.seiteOeffnenUndZentrieren(seiteId, blattnr, seiteBez, wx, wy)
                            }
                            onKlemmeImSeitenBaumAnzeigen: function(klemmeId, anschlussBezeichnung) {
                                seitenBaum.navigiereZuKlemme(klemmeId, anschlussBezeichnung)
                            }
                            onKabelImSeitenBaumAnzeigen: function(kabelId) {
                                seitenBaum.navigiereZuKabel(kabelId)
                            }
                            onGeraetekastenImSeitenBaumAnzeigen: function(gkId, gkBmk) {
                                seitenBaum.navigiereZuGeraetekasten(gkId, gkBmk)
                            }
                            onMakroListeGeaendert: symbolPalette.makroListeAktualisieren()
                            onAktivesWerkzeugGeaendert: function(wkz) {
                                if (wkz !== "symbol") symbolPalette.abwaehlen()
                                if (wkz === "zeiger" && root._klemmeQueueAktiv)
                                    root._klemmeQueueNaechste()
                                if (wkz === "zeiger" && root._kontaktQueueAktiv)
                                    root._kontaktQueueNaechste()
                            }
                            onTeilenRechts: { root.splitHorizontal = true;  root.splitAktiv = true }
                            onTeilenUnten:  { root.splitHorizontal = false; root.splitAktiv = true }
                            onDrcKlick:     root.drcPanelOffen  = !root.drcPanelOffen
                            onSuchKlick:    root.suchPanelOffen = !root.suchPanelOffen
                            drcAktiv:       root.drcPanelOffen
                            suchAktiv:      root.suchPanelOffen
                        }

                        CanvasPanel {
                            id:                   panel2
                            SplitView.preferredWidth:  root.splitHorizontal ? 500 : undefined
                            SplitView.preferredHeight: root.splitHorizontal ? undefined : 400
                            SplitView.minimumWidth:  root.splitAktiv ? 200 : 0
                            SplitView.minimumHeight: root.splitAktiv ? 100 : 0
                            SplitView.maximumWidth:  root.splitAktiv ? Infinity : 0
                            SplitView.maximumHeight: root.splitAktiv ? Infinity : 0
                            visible: root.splitAktiv
                            theme:            appTheme
                            debug:            root.debugModeAktiv
                            projektId:        root.aktivProjektId

                            hintergrundFarbe: root.aktivProjektHintergrund
                            fokussiert:       root.fokussiertesPanel === 2
                            elementeModel:    elementeModel2
                            splitSchliessbar: root.splitAktiv

                            onSplitSchliessen: {
                                root.splitAktiv        = false
                                root.fokussiertesPanel = 1
                                panel1.canvas.forceActiveFocus()
                            }
                            onPanelAngeklickt:        root.fokussiertesPanel = 2
                            onAktivSeiteIdChanged: {
                                if (root.fokussiertesPanel === 2) {
                                    root.aktivSeiteId   = panel2.aktivSeiteId
                                    root.aktivSeiteName = panel2.aktivSeiteName
                                }
                            }
                            onHintergrundGeaendert: function(farbe) {
                                root.aktivProjektHintergrund = farbe
                                db.projektHintergrundSpeichern(root.aktivProjektId, farbe)
                            }
                            onQuerverweisNavigieren: function(seiteId) {
                                if (root.fokussiertesPanel === 2) {
                                    root.aktivSeiteId   = seiteId
                                    root.aktivSeiteName = panel2.aktivSeiteName
                                }
                            }
                            onGkSprungAngefordert: function(seiteId, blattnr, seiteBez, wx, wy) {
                                if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                                panel2.seiteOeffnenUndZentrieren(seiteId, blattnr, seiteBez, wx, wy)
                            }
                            onKlemmeImSeitenBaumAnzeigen: function(klemmeId, anschlussBezeichnung) {
                                seitenBaum.navigiereZuKlemme(klemmeId, anschlussBezeichnung)
                            }
                            onKabelImSeitenBaumAnzeigen: function(kabelId) {
                                seitenBaum.navigiereZuKabel(kabelId)
                            }
                            onGeraetekastenImSeitenBaumAnzeigen: function(gkId, gkBmk) {
                                seitenBaum.navigiereZuGeraetekasten(gkId, gkBmk)
                            }
                            onMakroListeGeaendert: symbolPalette.makroListeAktualisieren()
                            onAktivesWerkzeugGeaendert: function(wkz) {
                                if (wkz !== "symbol") symbolPalette.abwaehlen()
                                if (wkz === "zeiger" && root._klemmeQueueAktiv)
                                    root._klemmeQueueNaechste()
                                if (wkz === "zeiger" && root._kontaktQueueAktiv)
                                    root._kontaktQueueNaechste()
                            }
                            onDrcKlick:     root.drcPanelOffen  = !root.drcPanelOffen
                            onSuchKlick:    root.suchPanelOffen = !root.suchPanelOffen
                            drcAktiv:       root.drcPanelOffen
                            suchAktiv:      root.suchPanelOffen
                            onPanelLeer: {
                                root.splitAktiv      = false
                                root.fokussiertesPanel = 1
                            }
                            onTeilenRechts: { /* Verschachtelung nicht unterst\u00fctzt */ }
                            onTeilenUnten:  { /* Verschachtelung nicht unterst\u00fctzt */ }
                        }
                    }
                }

                // \u2500\u2500 DRC-Panel (unten, ausklappbar) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
                // ── Suchpanel (unten, ausklappbar) ───────────────────────
                KommandoPalette {
                    id:    suchPanel
                    anchors {
                        left:   parent.left
                        right:  parent.right
                        bottom: drcPanel.top
                    }
                    height:    root.suchPanelOffen ? 260 : 0
                    clip:      true
                    theme:     appTheme
                    projektId: root.aktivProjektId
                    debug:     root.debugModeAktiv

                    onSchliessen: root.suchPanelOffen = false
                    onWerkzeugAktiviert: function(werkzeug) {
                        if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                        root.aktiverCanvas.aktivesWerkzeug = werkzeug
                    }
                    onSeiteOeffnen: function(id, blattnummer, bezeichnung) {
                        if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                        var p = root.fokussiertesPanel === 1 ? panel1 : panel2
                        p.seiteOeffnen(id, blattnummer, bezeichnung)
                    }
                    onElementSprung: function(seiteId, blattnummer, seiteBez, cx, cy) {
                        if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                        var p = root.fokussiertesPanel === 1 ? panel1 : panel2
                        p.seiteOeffnenUndZentrieren(seiteId, blattnummer, seiteBez, cx, cy)
                    }

                    Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                }

                DrcPanel {
                    id:    drcPanel
                    anchors {
                        left:   parent.left
                        right:  parent.right
                        bottom: parent.bottom
                    }
                    height:    root.drcPanelOffen ? 200 : 0
                    clip:      true
                    theme:     appTheme
                    projektId: root.aktivProjektId
                    debug:     root.debugModeAktiv
                    onSchliessen: root.drcPanelOffen = false

                    Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                }
            }

            // Bauteil-Datenbank (inkl. Klemmenreihen als Sondereintrag)
            BauteilAnsicht {
                id:           bauteilAnsicht
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "bauteile"
                theme:        appTheme
                debug:        root.debugModeAktiv
                projektId:    root.aktivProjektId

                onKlemmenEditorAngefordert: function(id, bezeichnung) {
                    root.aktiveAnsicht = "klemmen_editor"
                }
                onKabelEditorAngefordert: function(id, bezeichnung) {
                    root.aktiveAnsicht = "kabel_editor"
                }
                onSteckverbinderEditorAngefordert: function(id, bezeichnung) {
                    root.aktiveAnsicht = "steckverbinder_editor"
                }
                onKonfkabelEditorAngefordert: function(id, bezeichnung) {
                    root.aktiveAnsicht = "konfkabel_editor"
                }
                onKontaktEditorAngefordert: function(id, bezeichnung) {
                    root.aktiveAnsicht = "kontakt_editor"
                }
                onGeraetekastenSprungAngefordert: function(seiteId, blattnr, seiteBez, wx, wy) {
                    if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
                    var p = root.fokussiertesPanel === 2 ? panel2 : panel1
                    p.seiteOeffnenUndZentrieren(seiteId, blattnr, seiteBez, wx, wy)
                }
                onMakroListeGeaendert: symbolPalette.makroListeAktualisieren()
                onLeisteKanvasAktualisiert: {
                    if (panel1.aktivSeiteId >= 0) elementeModel1.laden(panel1.aktivSeiteId)
                    if (panel2.aktivSeiteId >= 0) elementeModel2.laden(panel2.aktivSeiteId)
                }
                onKontaktenSequentiellPlatzierenAngefordert: function(queueJson) {
                    var queue = JSON.parse(queueJson)
                    if (!queue || queue.length === 0) return
                    if (root.aktivSeiteId < 0) {
                        meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false)
                        return
                    }
                    root.aktiveAnsicht = "seiten"
                    root._kontaktQueue      = queue
                    root._kontaktQueueAktiv = true
                    root._kontaktQueueNaechste()
                }
                onKontaktPlatzierenAngefordert: function(geraetekastenId, positionId, symbolId, bmk) {
                    if (root.aktivSeiteId < 0) {
                        meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false)
                        return
                    }
                    if (db.steckverbinderPositionIstPlatziert(positionId)) { meldungManager.zeigen(qsTr("Diese Position ist bereits platziert."), false); return }
                    root.aktiveAnsicht = "seiten"
                    root.aktiverCanvas.paletteSymbolId  = symbolId
                    root.aktiverCanvas.paletteExtraDaten = {
                        "platziermodus":   "verknuepft",
                        "geraetekastenId": geraetekastenId,
                        "positionId":      positionId,
                        "bmk":             bmk
                    }
                    root.aktiverCanvas.aktivesWerkzeug  = "symbol"
                    root.aktiverCanvas.forceActiveFocus()
                }
            }

            // Listen (Stückliste + Querverweise) – lazy per Loader (RESSOURCEN-MESSUNG-01):
            // ListenAnsicht.laden() ruft beim Erzeugen sofort alle 9 Listen-Queries über
            // das gesamte Projekt ab (bei großen Projekten mehrere Sekunden). Component
            // wird daher erst beim ersten Tab-Besuch instanziiert, bleibt danach aber
            // (active bleibt true) erhalten, damit Scroll-Position/Auswahl nicht bei
            // jedem Tab-Wechsel verloren geht.
            Loader {
                anchors.fill: parent
                active:  root.aktiveAnsicht === "stueckliste" || item !== null
                visible: root.aktiveAnsicht === "stueckliste"
                sourceComponent: ListenAnsicht {
                    theme:        appTheme
                    debug:        root.debugModeAktiv
                    projektId:    root.aktivProjektId
                    projektName:  root.aktivProjektName
                    canvas:       root.aktiverCanvas
                }
            }

            // Klemmen-Editor Vollbild
            BauteilEditorRahmen {
                anchors.fill:       parent
                visible:            root.aktiveAnsicht === "klemmen_editor"
                theme:              appTheme
                debug:              root.debugModeAktiv
                editorName:         qsTr("Klemmen-Editor")
                bauteilBezeichnung: bauteilAnsicht.selectedBauteilBezeichnung
                onZurueck:          root.aktiveAnsicht = "bauteile"

                KlemmenEditor {
                    Layout.fillWidth:     true
                    Layout.fillHeight:    true
                    theme:                appTheme
                    debug:                root.debugModeAktiv
                    bauteilId:            bauteilAnsicht.selectedBauteilId
                    bauteilBezeichnung:   bauteilAnsicht.selectedBauteilBezeichnung
                    bauteilHersteller:    bauteilAnsicht.selectedBauteilHersteller
                    bauteilArtikelnummer: bauteilAnsicht.selectedBauteilArtikelnummer

                    onBauteilGespeichert: function(id, bez) {
                        bauteilAnsicht.selectedBauteilBezeichnung = bez
                    }

                    onAnschlussPlatzieren: function(bkId, bez, modus) {
                        if (root.aktivSeiteId < 0) {
                            meldungManager.zeigen(qsTr("Bitte zuerst eine Seite auswählen."), false)
                            return
                        }
                        root.aktiveAnsicht = "seiten"
                        root.aktiverCanvas.paletteSymbolId  = "klemme_anschluss"
                        root.aktiverCanvas.paletteExtraDaten = {
                            "bauteilKlemmeId":      bkId,
                            "anschlussBezeichnung": bez,
                            "platziermodus":        modus
                        }
                        root.aktiverCanvas.aktivesWerkzeug  = "symbol"
                        root.aktiverCanvas.forceActiveFocus()
                    }
                }
            }

            // Kabel-Editor Vollbild
            BauteilEditorRahmen {
                anchors.fill:       parent
                visible:            root.aktiveAnsicht === "kabel_editor"
                theme:              appTheme
                debug:              root.debugModeAktiv
                editorName:         qsTr("Kabel-Editor")
                bauteilBezeichnung: bauteilAnsicht.selectedBauteilBezeichnung
                onZurueck:          root.aktiveAnsicht = "bauteile"

                KabelEditor {
                    Layout.fillWidth:     true
                    Layout.fillHeight:    true
                    theme:                appTheme
                    debug:                root.debugModeAktiv
                    bauteilId:            bauteilAnsicht.selectedBauteilId
                    bauteilBezeichnung:   bauteilAnsicht.selectedBauteilBezeichnung
                    bauteilHersteller:    bauteilAnsicht.selectedBauteilHersteller
                    bauteilArtikelnummer: bauteilAnsicht.selectedBauteilArtikelnummer

                    onBauteilGespeichert: function(id, bez) {
                        bauteilAnsicht.selectedBauteilBezeichnung = bez
                        bauteilModel.aktualisieren()
                    }
                }
            }

            // Steckverbinder-Editor Vollbild
            BauteilEditorRahmen {
                anchors.fill:       parent
                visible:            root.aktiveAnsicht === "steckverbinder_editor"
                theme:              appTheme
                debug:              root.debugModeAktiv
                editorName:         qsTr("Steckverbinder-Editor")
                bauteilBezeichnung: bauteilAnsicht.selectedBauteilBezeichnung
                onZurueck:          root.aktiveAnsicht = "bauteile"

                SteckverbinderEditor {
                    Layout.fillWidth:     true
                    Layout.fillHeight:    true
                    theme:                appTheme
                    debug:                root.debugModeAktiv
                    bauteilId:            bauteilAnsicht.selectedBauteilId
                    bauteilBezeichnung:   bauteilAnsicht.selectedBauteilBezeichnung
                    bauteilHersteller:    bauteilAnsicht.selectedBauteilHersteller
                    bauteilArtikelnummer: bauteilAnsicht.selectedBauteilArtikelnummer

                    onBauteilGespeichert: function(id, bez) {
                        bauteilAnsicht.selectedBauteilBezeichnung = bez
                        bauteilModel.aktualisieren()
                    }
                }
            }

            // Konfkabel-Editor Vollbild
            BauteilEditorRahmen {
                anchors.fill:       parent
                visible:            root.aktiveAnsicht === "konfkabel_editor"
                theme:              appTheme
                debug:              root.debugModeAktiv
                editorName:         qsTr("Konf. Kabel-Editor")
                bauteilBezeichnung: bauteilAnsicht.selectedBauteilBezeichnung
                onZurueck:          root.aktiveAnsicht = "bauteile"

                KonfkabelEditor {
                    Layout.fillWidth:     true
                    Layout.fillHeight:    true
                    theme:                appTheme
                    debug:                root.debugModeAktiv
                    bauteilId:            bauteilAnsicht.selectedBauteilId
                    bauteilBezeichnung:   bauteilAnsicht.selectedBauteilBezeichnung
                    bauteilHersteller:    bauteilAnsicht.selectedBauteilHersteller
                    bauteilArtikelnummer: bauteilAnsicht.selectedBauteilArtikelnummer

                    onBauteilGespeichert: function(id, bez) {
                        bauteilAnsicht.selectedBauteilBezeichnung = bez
                        bauteilModel.aktualisieren()
                    }
                }
            }

            // Kontakt-Editor Vollbild
            BauteilEditorRahmen {
                anchors.fill:       parent
                visible:            root.aktiveAnsicht === "kontakt_editor"
                theme:              appTheme
                debug:              root.debugModeAktiv
                editorName:         qsTr("Kontakt-Editor")
                bauteilBezeichnung: bauteilAnsicht.selectedBauteilBezeichnung
                onZurueck:          root.aktiveAnsicht = "bauteile"

                KontaktEditor {
                    Layout.fillWidth:     true
                    Layout.fillHeight:    true
                    theme:                appTheme
                    debug:                root.debugModeAktiv
                    bauteilId:            bauteilAnsicht.selectedBauteilId
                    bauteilBezeichnung:   bauteilAnsicht.selectedBauteilBezeichnung
                    bauteilHersteller:    bauteilAnsicht.selectedBauteilHersteller
                    bauteilArtikelnummer: bauteilAnsicht.selectedBauteilArtikelnummer

                    onBauteilGespeichert: function(id, bez) {
                        bauteilAnsicht.selectedBauteilBezeichnung = bez
                        bauteilModel.aktualisieren()
                    }
                }
            }

            // Kabelquerschnitt-Rechner
            KabelRechner {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "kabelrechner"
                theme:        appTheme
                debug:        root.debugModeAktiv
            }

            // Symbol-Editor
            SymbolEditorAnsicht {
                id:           symbolEditorAnsicht
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "symbol_editor"
                theme:        appTheme
                debug:        root.debugModeAktiv
                editSymbolId: root.symbolEditorId
                vorlageId:    root.symbolEditorVorlageId

                onGespeichert: function(symbolId) {
                    // Editor bleibt nach dem Speichern offen (Nutzerwunsch) – nur die
                    // Palette aktualisieren, damit Änderungen sofort sichtbar sind.
                    // Verlassen weiterhin über «Abbrechen» (schließt ohne Datenverlust,
                    // da bereits gespeichert wurde).
                    symbolPalette.laden()
                }
                onAbgebrochen: {
                    root.aktiveAnsicht = (root.symbolEditorVorher !== "symbol_editor")
                                          ? root.symbolEditorVorher : "seiten"
                }
            }

            // ── Inbetriebnahme-Ansicht ─────────────────────────────────
            Item {
                id:           ibnBereich
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "ibn"

                SplitView {
                    anchors.fill: parent
                    orientation:  Qt.Horizontal
                    handle: Rectangle {
                        implicitWidth: 5
                        color: SplitHandle.pressed ? appTheme.accent
                             : SplitHandle.hovered  ? appTheme.activeItem : appTheme.border
                    }

                    IbnAnsicht {
                        id:                       ibnAnsicht
                        SplitView.preferredWidth: 400
                        SplitView.minimumWidth:   200
                        theme:                    appTheme
                        debug:                    root.debugModeAktiv
                        projektId:                root.aktivProjektId
                        seiteId:                  root.aktivSeiteId

                        onGeschlossen: root.aktiveAnsicht = "seiten"

                        onBmkGewaehlt: function(sid, elementId, wx, wy, blattnr, seiteBez) {
                            if (sid !== root.aktivSeiteId) {
                                root._ibnZentriereX = wx
                                root._ibnZentriereY = wy
                                root.aktivSeiteId   = sid
                                // IBN-SEITENNAME-STALE-01: aktivSeiteId speist zwar
                                // ibnCanvas.seiteId (Canvas-Inhalt springt korrekt um),
                                // aktivSeiteName wird aber sonst nur von panel1/panel2
                                // (Schaltplan-Modus) gepflegt - im IBN-Modus blieb die
                                // Titelzeile über dem Canvas dadurch auf der vorherigen
                                // Seite stehen, obwohl der Sprung selbst funktionierte.
                                // Formel identisch zu CanvasPanel.aktivSeiteName.
                                if (blattnr !== "")
                                    root.aktivSeiteName = seiteBez.length > 0
                                                          ? seiteBez + "  –  " + blattnr : blattnr
                                ibnZentriereTimer.restart()
                            } else {
                                ibnCanvas._zoomZuWeltPosition(wx, wy)
                                ibnCanvas._zeigeMarker(wx, wy)
                            }
                        }
                    }

                    // Sprungziel-Markierung analog CanvasPanel.seiteOeffnenUndZentrieren:
                    // ibnCanvas hängt hier direkt (nicht über CanvasPanel), daher eigener
                    // kleiner Timer statt Wiederverwendung von dessen Funktion.
                    // IBN-ZENTRIEREN-SCOPE-01: _ibnZentriereX/Y liegen jetzt auf root
                    // (siehe oben) statt hier - Handler und Timer griffen beide über
                    // "root."  zu, hier deklariert waren sie für root unerreichbar.
                    Timer {
                        id:       ibnZentriereTimer
                        interval: 80
                        onTriggered: {
                            ibnCanvas._zoomZuWeltPosition(root._ibnZentriereX, root._ibnZentriereY)
                            ibnCanvas._zeigeMarker(root._ibnZentriereX, root._ibnZentriereY)
                        }
                    }

                    SchaltplanCanvas {
                        id:                      ibnCanvas
                        SplitView.fillWidth:     true
                        theme:                   appTheme
                        debug:                   root.debugModeAktiv
                        seiteId:                 root.aktivSeiteId
                        projektId:               root.aktivProjektId
                        seiteName:               root.aktivSeiteName
                        hintergrundFarbe:        root.aktivProjektHintergrund
                        elementeModel:           elementeModel3
                        ibnModus:                true
                        ibnStatusMap:            ibnAnsicht.statusMap

                        onHintergrundGeaendert: function(farbe) {
                            root.aktivProjektHintergrund = farbe
                            db.projektHintergrundSpeichern(root.aktivProjektId, farbe)
                        }
                        onQuerverweisNavigieren: function(sid) {
                            root.aktivSeiteId = sid
                        }
                    }
                }
            }

            // ── Normblatt-Vorlagen-Editor ──────────────────────────────
            NormblattEditorDialog {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "normblatt"
                theme:        appTheme
                debug:        root.debugModeAktiv
            }

            // ── Wiki ───────────────────────────────────────────────────
            WikiAnsicht {
                id:           wikiAnsicht
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "wiki"
                theme:        appTheme
                debug:        root.debugModeAktiv
            }

            // ── SPS/PLS ────────────────────────────────────────────────
            SpsAnsicht {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "sps"
                theme:        appTheme
                projektId:    root.aktivProjektId
                debug:        root.debugModeAktiv
            }

            // ── Fehlersuchmodus ────────────────────────────────────────
            Item {
                id:           fehlersuchBereich
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "fehlersuche"

                // Anzeige-Toggle (Signaltyp/Aderfarbe) bei jedem erneuten
                // Eintritt in den Fehlersuchmodus auf Kategorie-Default zurücksetzen
                onVisibleChanged: if (visible) fehlersuchCanvas.fehlersuchZeigeAderfarbe = false

                SplitView {
                    anchors.fill: parent
                    orientation:  Qt.Horizontal
                    handle: Rectangle {
                        implicitWidth: 5
                        color: SplitHandle.pressed ? appTheme.accent
                             : SplitHandle.hovered  ? appTheme.activeItem : appTheme.border
                    }

                    FehlersuchAnsicht {
                        id:                       fehlersuchAnsicht
                        SplitView.preferredWidth: 320
                        SplitView.minimumWidth:   200
                        theme:                    appTheme
                        projektId:                root.aktivProjektId
                        seiteId:                  root.aktivSeiteId
                        canvas:                   fehlersuchCanvas

                        onGeschlossen: root.aktiveAnsicht = "seiten"

                        onQuerverweisNavigieren: function(sid, x, y, partnerId) {
                            if (sid !== root.aktivSeiteId) {
                                fehlersuchCanvas._querverweisZielPos = { x: x, y: y }
                                if (partnerId > 0)
                                    fehlersuchCanvas._fehlersuchAutoStartId = partnerId
                                root.aktivSeiteId = sid
                            } else {
                                fehlersuchCanvas._zoomZuWeltPosition(x, y)
                                if (partnerId > 0)
                                    fehlersuchCanvas.fehlersuchPfadBerechnen(partnerId)
                            }
                        }

                        onFehlersuchNavigieren: function(sid, cx, cy, elementId) {
                            if (sid !== root.aktivSeiteId) {
                                fehlersuchCanvas._querverweisZielPos  = { x: cx, y: cy }
                                if (elementId > 0)
                                    fehlersuchCanvas._fehlersuchAutoStartId = elementId
                                root.aktivSeiteId = sid
                            } else {
                                fehlersuchCanvas._zoomZuWeltPosition(cx, cy)
                                if (elementId > 0)
                                    fehlersuchCanvas.fehlersuchPfadBerechnen(elementId)
                            }
                        }

                        onHistoriNavigieren: function(sid, startId) {
                            if (sid !== root.aktivSeiteId) {
                                fehlersuchCanvas._fehlersuchAutoStartId = startId
                                root.aktivSeiteId = sid
                            } else {
                                fehlersuchCanvas.fehlersuchPfadBerechnen(startId)
                            }
                        }
                    }

                    SchaltplanCanvas {
                        id:                      fehlersuchCanvas
                        SplitView.fillWidth:     true
                        theme:                   appTheme
                        debug:                   root.debugModeAktiv
                        seiteId:                 root.aktivSeiteId
                        projektId:               root.aktivProjektId
                        seiteName:               root.aktivSeiteName
                        hintergrundFarbe:        root.aktivProjektHintergrund
                        elementeModel:           elementeModel4
                        ibnModus:                true
                        fehlersuchModus:         true

                        onHintergrundGeaendert: function(farbe) {
                            root.aktivProjektHintergrund = farbe
                            db.projektHintergrundSpeichern(root.aktivProjektId, farbe)
                        }
                        onQuerverweisNavigieren: function(sid) {
                            root.aktivSeiteId = sid
                        }
                    }
                }
            }

            // ── Errungenschaften ───────────────────────────────────────
            AchievementsPanel {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "achievements"
                theme:        appTheme
                debug:        root.debugModeAktiv
            }

            // ── Meldungen ────────────────────────────────────────────
            MeldungenPanel {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "meldungen"
                theme:        appTheme
                debug:        root.debugModeAktiv
            }

            // ── Einstellungen ──────────────────────────────────────────
            EinstellungenAnsicht {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "einstellungen"
                theme:        appTheme
                seiteOffen:   root.aktivSeiteId >= 0
                debug:        root.debugModeAktiv
                onJetztTesten: {
                    if (root.aktivSeiteId < 0) return
                    var c = root.aktiverCanvas
                    if (!c) c = panel1.canvas
                    funOverlay.canvas  = c
                    funOverlay.visible = true
                    achievementManager.ereignis("fun_modus")
                }
                onGespraechTexteGeaendert: root._funGesprTexte = json
            }
        }
    }

    // ── Fun-Modus-Overlay ─────────────────────────────────────────
    FunModusOverlay {
        id:              funOverlay
        anchors.fill:    parent
        visible:         false
        z:               600
        theme:           appTheme
        gespraechTexte:  root._funGesprTexte
        onDeaktiviert:   idleTimer.restart()
    }

    // ── Achievement-Toast ─────────────────────────────────────────
    AchievementToast {
        id:     achievementToast
        z:      750
        theme:  appTheme
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
    }

    Connections {
        target: achievementManager
        function onAchievementFreigeschaltet(id, titel, beschreibung) {
            achievementToast.zeigen(titel, beschreibung)
        }
    }

    // ── Status-Toast (Erfolg/Info, z.B. "PDF gespeichert") ────────
    MeldungToast {
        id:     meldungToast
        z:      750
        theme:  appTheme
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20 + (achievementToast.visible ? achievementToast.height + 12 : 0)
    }

    Connections {
        target: meldungManager
        function onMeldungAnzuzeigen(text, erfolg) {
            meldungToast.zeigen(text, erfolg)
        }
    }

    // ── Rosi Röhrenaal ─────────────────────────────────────────────
    RosiSprechblase {
        id:     rosiSprechblase
        z:      750
        theme:  appTheme
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
    }

    RosiPostkarte {
        id:     rosiPostkarte
        z:      750
        theme:  appTheme
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.bottomMargin: 20
        anchors.leftMargin:   16
    }

    Connections {
        target: rosiManager
        function onAuftauchen(text) {
            rosiSprechblase.zeigen(text)
        }
        function onPostkarteAngekommen(text) {
            rosiPostkarte.zeigen(text)
        }
        function onVorwarnung(sekunden) {
            rosiSprechblase.vorwarnen(sekunden)
        }
        function onAbwesenheitAnzeigen(text, istUrlaub) {
            rosiSprechblase.abwesenheitAnzeigen(text, istUrlaub)
        }
        function onAbwesenheitVerstecken() {
            rosiSprechblase.abwesenheitVerstecken()
        }
    }

    // ── Shortcut-Übersicht ────────────────────────────────────────
    ShortcutUebersicht {
        id:           shortcutUebersicht
        anchors.fill: parent
        z:            700
        theme:        appTheme
        debug:        root.debugModeAktiv
    }

    // ── Äußerer Fensterrahmen + Resize-Griffe ─────────────────────
    // Nur aktiv wenn das Fenster nicht maximiert ist.
    readonly property int _rg: 5   // Griffbreite in Pixeln

    // Sichtbarer Rahmen (konsumiert keine Events)
    Rectangle {
        anchors.fill: parent
        color:        "transparent"
        border.color: appTheme.border
        border.width: 1
        enabled:      false
        visible:      root.visibility === Window.Windowed
        z:            900
    }

    // Ecke: oben links
    Item {
        x: 0; y: 0; width: root._rg * 2; height: root._rg * 2
        visible: root.visibility === Window.Windowed; z: 800
        DragHandler {
            target: null; cursorShape: Qt.SizeFDiagCursor
            onActiveChanged: if (active) root.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
        }
    }
    // Kante: oben
    Item {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.leftMargin: root._rg * 2; anchors.rightMargin: root._rg * 2
        height: root._rg
        visible: root.visibility === Window.Windowed; z: 800
        DragHandler {
            target: null; cursorShape: Qt.SizeVerCursor
            onActiveChanged: if (active) root.startSystemResize(Qt.TopEdge)
        }
    }
    // Ecke: oben rechts
    Item {
        anchors { top: parent.top; right: parent.right }
        width: root._rg * 2; height: root._rg * 2
        visible: root.visibility === Window.Windowed; z: 800
        DragHandler {
            target: null; cursorShape: Qt.SizeBDiagCursor
            onActiveChanged: if (active) root.startSystemResize(Qt.TopEdge | Qt.RightEdge)
        }
    }
    // Kante: links
    Item {
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        anchors.topMargin: root._rg * 2; anchors.bottomMargin: root._rg * 2
        width: root._rg
        visible: root.visibility === Window.Windowed; z: 800
        DragHandler {
            target: null; cursorShape: Qt.SizeHorCursor
            onActiveChanged: if (active) root.startSystemResize(Qt.LeftEdge)
        }
    }
    // Kante: rechts
    Item {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        anchors.topMargin: root._rg * 2; anchors.bottomMargin: root._rg * 2
        width: root._rg
        visible: root.visibility === Window.Windowed; z: 800
        DragHandler {
            target: null; cursorShape: Qt.SizeHorCursor
            onActiveChanged: if (active) root.startSystemResize(Qt.RightEdge)
        }
    }
    // Ecke: unten links
    Item {
        anchors { bottom: parent.bottom; left: parent.left }
        width: root._rg * 2; height: root._rg * 2
        visible: root.visibility === Window.Windowed; z: 800
        DragHandler {
            target: null; cursorShape: Qt.SizeBDiagCursor
            onActiveChanged: if (active) root.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
        }
    }
    // Kante: unten
    Item {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        anchors.leftMargin: root._rg * 2; anchors.rightMargin: root._rg * 2
        height: root._rg
        visible: root.visibility === Window.Windowed; z: 800
        DragHandler {
            target: null; cursorShape: Qt.SizeVerCursor
            onActiveChanged: if (active) root.startSystemResize(Qt.BottomEdge)
        }
    }
    // Ecke: unten rechts
    Item {
        anchors { bottom: parent.bottom; right: parent.right }
        width: root._rg * 2; height: root._rg * 2
        visible: root.visibility === Window.Windowed; z: 800
        DragHandler {
            target: null; cursorShape: Qt.SizeFDiagCursor
            onActiveChanged: if (active) root.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
        }
    }

    // ── Globale Canvas-Shortcuts ──────────────────────────────────
    // Eine einzige Instanz pro Taste – leitet über root.aktiverCanvas weiter.
    // Verhindert Ambiguität wenn panel1 + panel2 im Split-Modus beide sichtbar sind.
    // WindowShortcut feuert erst nachdem ein TextInput den Event selbst verarbeitet hat.

    // Löschen
    // enabled-Bindung ist Pflicht, nicht nur der Check in onActivated: ein
    // aktiver Shortcut greift sich die Taste bereits beim reinen Matching,
    // bevor Keys.onPressed anderer Ansichten (z.B. NormblattEditorDialog)
    // sie überhaupt sehen - der frühe return in onActivated kommt zu spät,
    // die Taste wäre trotzdem schon "verbraucht" (DELETE-SHORTCUT-KONFLIKT-01).
    Shortcut {
        sequence: "Delete"
        enabled:  root.aktiveAnsicht === "seiten"
        onActivated: {
            var c = root.aktiverCanvas
            if (!c || c.textEditAktiv) return
            if (c.aktivesWerkzeug === "symbol" && c.paletteSymbolId !== "") {
                c.abbruch(); c.paletteSymbolId = ""; c.aktivesWerkzeug = "zeiger"
            } else if (c.auswahl.length > 0) {
                c.loeschen()
            }
        }
    }
    Shortcut {
        sequence: "Backspace"
        enabled:  root.aktiveAnsicht === "seiten"
        onActivated: {
            var c = root.aktiverCanvas
            if (!c || c.textEditAktiv) return
            if (c.aktivesWerkzeug === "symbol" && c.paletteSymbolId !== "") {
                c.abbruch(); c.paletteSymbolId = ""; c.aktivesWerkzeug = "zeiger"
            } else if (c.auswahl.length > 0) {
                c.loeschen()
            }
        }
    }

    // Werkzeuge (nur wenn kein Text-Overlay aktiv)
    Shortcut { sequence: "V"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="zeiger"} } }
    Shortcut { sequence: "L"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="linie"} } }
    Shortcut { sequence: "P"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="polygonlinie"} } }
    Shortcut { sequence: "R"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="rechteck"} } }
    Shortcut { sequence: "K"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="kreis"} } }
    Shortcut { sequence: "T"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="text"} } }
    Shortcut { sequence: "G"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="geraetekasten"} } }
    Shortcut { sequence: "U"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="strukturkasten"} } }
    Shortcut { sequence: "M"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="makrokasten"} } }
    Shortcut { sequence: "O"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="schirm"} } }
    Shortcut { sequence: "C"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="kabellinie"} } }
    Shortcut { sequence: "N"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="notiz"} } }
    Shortcut { sequence: "S"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv&&c.paletteSymbolId!==""){c.abbruch();c.aktivesWerkzeug="symbol"} } }
    Shortcut { sequence: "F"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.querverweisZurGegenseiteNavigieren() } }
    Shortcut { sequence: "Ctrl+M"; context: Qt.ApplicationShortcut; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.minimapSichtbar=!c.minimapSichtbar } }
    Shortcut { sequence: "Ctrl+J"; context: Qt.ApplicationShortcut; enabled: root.aktivProjektId >= 0; onActivated: root.suchPanelOffen = !root.suchPanelOffen }
    Shortcut { sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; enabled: root.aktivProjektId >= 0 && root.aktiveAnsicht === "fehlersuche"; onActivated: fehlersuchAnsicht.suchfeldOeffnen() }
    // GIT-01: Explizites Speichern + Auto-Commit
    Shortcut {
        sequence: "Ctrl+S"
        context:  Qt.ApplicationShortcut
        enabled:  db.projektOffen
        onActivated: {
            var c = root.aktiverCanvas
            if (root.aktiveAnsicht === "seiten" && c) c.grafikSpeichernJetzt()
            db.gitAutoCommit(db.projektOrdner,
                             Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm"))
        }
    }
    Shortcut { sequence: "Escape"; onActivated: {
        var c = root.aktiverCanvas
        if (root.aktiveAnsicht === "seiten" && c) c.handleEscape()
        else if (root.aktiveAnsicht === "symbol_editor") { symbolEditorAnsicht.werkzeugPunkte = []; symbolEditorAnsicht.repaintAll() }
        else if (root.aktiveAnsicht === "fehlersuche") {
            if (fehlersuchAnsicht.suchfeldAktiv) fehlersuchAnsicht.suchfeldSchliessen()
            else fehlersuchCanvas.fehlersuchPfadZuruecksetzen()
        }
    } }

    // Undo / Redo
    Shortcut { sequence: "Ctrl+Z";       onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.undo() } }
    Shortcut { sequence: "Ctrl+Y";       onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.redo() } }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.redo() } }

    // Auswahl / Bearbeiten
    Shortcut { sequence: "Ctrl+A"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.alleAuswaehlen() } }
    Shortcut { sequence: "Ctrl+C"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.kopieren(0) } }
    Shortcut { sequence: "Ctrl+X"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.ausschneiden(0) } }
    Shortcut { sequence: "Ctrl+V"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.einfuegen(0) } }
    Shortcut { sequence: "Ctrl+D";       onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.duplizieren() } }
    Shortcut { sequence: "Ctrl+G";       onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.gruppeErstellen() } }
    Shortcut { sequence: "Ctrl+Shift+G"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.gruppeAufloesen() } }

    // Zwischenablage-Slots
    Shortcut { sequence: "Ctrl+Shift+1"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.kopieren(1) } }
    Shortcut { sequence: "Ctrl+Shift+2"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.kopieren(2) } }
    Shortcut { sequence: "Ctrl+Shift+3"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.kopieren(3) } }
    Shortcut { sequence: "Ctrl+Shift+4"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.kopieren(4) } }
    Shortcut { sequence: "Ctrl+1"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&root.aktivSeiteId>=0) c.einfuegen(1) } }
    Shortcut { sequence: "Ctrl+2"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&root.aktivSeiteId>=0) c.einfuegen(2) } }
    Shortcut { sequence: "Ctrl+3"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&root.aktivSeiteId>=0) c.einfuegen(3) } }
    Shortcut { sequence: "Ctrl+4"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&root.aktivSeiteId>=0) c.einfuegen(4) } }

    // Zoom
    Shortcut { sequence: "Ctrl+Shift+H"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&root.aktivSeiteId>=0) c.zoomAllesEinpassen() } }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&root.aktivSeiteId>=0&&c.normblattDaten!==null) c.zoomNormblattEinpassen() } }
    Shortcut { sequence: "Ctrl+Shift+F"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&root.aktivSeiteId>=0) c.zoomAuswahlEinpassen() } }

    // Seitennavigation
    Shortcut {
        sequence: "PgUp"
        context:  Qt.ApplicationShortcut
        onActivated: {
            if (root.aktiveAnsicht !== "seiten" || root.aktivProjektId < 0 || root.aktivSeiteId < 0) return
            var seiten = db.alleSeitenFlach(root.aktivProjektId)
            for (var i = 0; i < seiten.length; i++) {
                if (seiten[i].id === root.aktivSeiteId && i > 0) {
                    var s = seiten[i - 1]
                    var p = root.fokussiertesPanel === 1 ? panel1 : panel2
                    p.seiteOeffnen(s.id, s.blattnummer, s.bezeichnung)
                    break
                }
            }
        }
    }
    Shortcut {
        sequence: "PgDown"
        context:  Qt.ApplicationShortcut
        onActivated: {
            if (root.aktiveAnsicht !== "seiten" || root.aktivProjektId < 0 || root.aktivSeiteId < 0) return
            var seiten = db.alleSeitenFlach(root.aktivProjektId)
            for (var i = 0; i < seiten.length; i++) {
                if (seiten[i].id === root.aktivSeiteId && i < seiten.length - 1) {
                    var s = seiten[i + 1]
                    var p = root.fokussiertesPanel === 1 ? panel1 : panel2
                    p.seiteOeffnen(s.id, s.blattnummer, s.bezeichnung)
                    break
                }
            }
        }
    }

    // F1: Wiki-Artikel zur aktuellen Ansicht, sonst Shortcut-Übersicht
    Shortcut {
        sequence: "F1"; context: Qt.ApplicationShortcut
        onActivated: {
            var titel = root.f1KontextArtikel[root.aktiveAnsicht]
            if (titel && wikiAnsicht.oeffneArtikelNachTitel(titel))
                root.aktiveAnsicht = "wiki"
            else
                shortcutUebersicht.visible = !shortcutUebersicht.visible
        }
    }
    Shortcut { sequence: "Ctrl+P"; context: Qt.ApplicationShortcut; onActivated: root.aktiveAnsicht = "projekte" }

    // ── Datenbank-Fehler-Dialog ───────────────────────────────────
    Dialog {
        id:              dbFehlerDialog
        title:           "Datenbankfehler"
        modal:           true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        property string meldung: ""
        property string backupOrdner: ""   // gesetzt bei Migrationsfehlern (BACKUP-OEFFNEN-01)

        Label {
            width:     Math.min(500, dbFehlerDialog.availableWidth)
            text:      dbFehlerDialog.meldung
            wrapMode:  Text.WordWrap
            color:     appTheme.textPrimary
        }

        footer: DialogButtonBox {
            standardButtons: Dialog.Ok
            Button {
                visible: dbFehlerDialog.backupOrdner !== ""
                text: qsTr("Backup-Ordner öffnen")
                DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
                onClicked: Qt.openUrlExternally("file://" + dbFehlerDialog.backupOrdner)
            }
        }
    }

    Connections {
        target: db
        function onDbFehler(meldung) {
            dbFehlerDialog.meldung = meldung
            dbFehlerDialog.backupOrdner = ""
            dbFehlerDialog.open()
        }
        function onDbFehlerMitBackup(meldung) {
            dbFehlerDialog.meldung = meldung
            dbFehlerDialog.backupOrdner = db.letzterBackupOrdner()
            dbFehlerDialog.open()
        }
    }

    // ── Projekt öffnen/schließen reagieren ───────────────────────
    function _projektInitialisieren() {
        projektModel.laden()
        var info = db.ersteProjektInfo()
        if (info.id > 0) {
            root.aktivProjektId          = info.id
            root.aktivProjektName        = info.name
            root.aktivProjektHintergrund = db.projektHintergrundLaden(info.id)
            root.aktiveAnsicht           = "projekte"
            seitenModel.laden(info.id)
            klemmenleistenModel.laden(info.id)
            // Modelle neu laden die im C++-Konstruktor oder Component.onCompleted
            // ohne offene Projekt-DB initialisiert wurden:
            farbModel.laden()
            kategorieModel.laden()
            symbolDefinitionModel.cacheLeeren()
            symbolPalette.laden()
            symbolEditorAnsicht.ladeDaten()
            symbolEditorAnsicht.symbollisteAktualisieren()
        }
    }

    // Beim Start: openProjekt() feuert bevor QML läuft – Signal kommt nie an.
    // Component.onCompleted holt den Zustand nach.
    Component.onCompleted: {
        if (db.projektOffen) root._projektInitialisieren()
        achievementManager.ereignis("app_start")
    }

    Connections {
        target: db
        function onProjektOffenChanged() {
            if (!db.projektOffen) {
                root.aktivProjektId   = -1
                root.aktivProjektName = ""
                root.aktivSeiteId     = -1
                root.aktivSeiteName   = ""
                root.aktiveAnsicht    = "projekte"
                return
            }
            root._projektInitialisieren()
        }
    }

    component PlatzhalterAnsicht: Item {
        property string titel:        "Titel"
        property string beschreibung: "Beschreibung"

        Column {
            anchors.centerIn: parent
            spacing:          12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           titel
                font.pixelSize: 22
                font.weight:    Font.Light
                color:          appTheme.borderDark
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           beschreibung
                font.pixelSize: 14
                color:          appTheme.borderDark
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

}
