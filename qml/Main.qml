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
import stroemling

// ProjektStartAnsicht ist direkt im qml/-Ordner, kein Unterordner-Import nötig

ApplicationWindow {
    id:         root
    visible:    true
    width:      1200
    height:     800
    title:      qsTr("Strömling Design")
    color:      appTheme.surface

    // Globale Palette: sorgt dafür dass TextField-Hintergründe im Theme-Farbton erscheinen
    palette.base: appTheme.inputBg
    palette.text: appTheme.textPrimary

    property int    aktivProjektId:   -1
    property string aktivProjektName: ""
    property string aktiveAnsicht:    "projekte"

    property int    aktivSeiteId:   -1
    property string aktivSeiteName: ""

    // ── Tab / Split-Zustand ──────────────────────────────────────────────
    property int  fokussiertesPanel: 1     // 1 oder 2
    property bool splitAktiv:        false
    property bool splitHorizontal:   true

    // Zugriff auf den aktiven Canvas-Panel
    property var aktiverCanvas: fokussiertesPanel === 1 ? panel1.canvas : panel2.canvas

    property string aktivProjektNorm:        "IEC"
    property string aktivProjektHintergrund: "#080f1c"

    property bool   debugModeAktiv:         false
    property bool   drcPanelOffen:          false

    property string symbolEditorId:         ""
    property string symbolEditorVorlageId:  ""
    property string symbolEditorVorher:     "projekte"

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
        property int sidebarBreite:    200
        property int seitenBaumBreite: 280
    }

    Settings {
        id:       funModusSettings
        category: "funmodus"
        property bool   aktiv:          false
        property int    wartezeitMin:   10
        property string gespraechTexte: "[]"
    }

    Settings {
        id:       logoSettings
        category: "logo"
        property int index: 0
    }

    // Zyklischer Logo-Index: bei jedem Start um 1 weiter (mod 9 Icons)
    property int _logoIndex: 0

    // Reaktiver Zwischenspeicher: wird initial aus Settings gelesen, dann per Signal aus
    // EinstellungenAnsicht aktualisiert (mehrere Settings-Objekte teilen keine Bindings).
    property string _funGesprTexte: funModusSettings.gespraechTexte

    property string aktivSprache: langSettings.language

    // ── Fun-Modus Idle-Detection ─────────────────────────────────
    // Beobachtet Mausbewegungen im gesamten Fenster; stört andere Elemente nicht.
    // WICHTIG: running-Binding auf idleTimer vermeiden – restart() bricht Bindings.
    MouseArea {
        id:                      idleMouseWatcher
        anchors.fill:            parent
        z:                       -999
        hoverEnabled:            true
        propagateComposedEvents: true
        acceptedButtons:         Qt.NoButton
        onPositionChanged: {
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

    // Logo-Index beim Start zyklisch weiterschalten (9 Icons)
    Timer {
        interval: 0; running: true; repeat: false
        onTriggered: {
            root._logoIndex = logoSettings.index % 9
            logoSettings.index = (logoSettings.index + 1) % 9
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
        context:     Shortcut.ApplicationShortcut
        onActivated: root.debugModeAktiv = !root.debugModeAktiv
    }

    Shortcut {
        sequence:    "Ctrl+P"
        context:     Shortcut.ApplicationShortcut
        onActivated: kommandoPalette.open()
    }

    Shortcut {
        sequence:    "Ctrl+Shift+P"
        context:     Shortcut.ApplicationShortcut
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

    KommandoPalette {
        id:        kommandoPalette
        theme:     appTheme
        projektId: root.aktivProjektId
        debug:     root.debugModeAktiv

        onWerkzeugAktiviert: function(werkzeug) {
            if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
            root.aktiverCanvas.aktivesWerkzeug = werkzeug
        }
        onSeiteOeffnen: function(id, blattnummer, bezeichnung) {
            if (root.aktiveAnsicht !== "seiten") root.aktiveAnsicht = "seiten"
            var p = root.fokussiertesPanel === 1 ? panel1 : panel2
            p.seiteOeffnen(id, blattnummer, bezeichnung)
        }
    }

    // ── Hilfsdialog: keine Seite aktiv ──────────────────────────
    Dialog {
        id:      keineSeiteMeldung
        title:   qsTr("Keine Seite ausgewählt")
        modal:   true
        parent:  Overlay.overlay
        anchors.centerIn: parent
        width:   340
        padding: 20
        background: Rectangle {
            color: appTheme.sidebar; border.color: appTheme.border; border.width: 1; radius: 6
        }
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                text:           qsTr("Bitte zuerst eine Seite auswählen.")
                color:          appTheme.textSecondary; font.pixelSize: 13
                wrapMode:       Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                text:           qsTr("Klicke im Seitenbaum auf eine Seite (z.B. '001 Hauptstromkreis'), dann klappt die Platzierung auf dem Canvas auf.")
                color:          appTheme.textMuted; font.pixelSize: 11
                wrapMode:       Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("OK"); implicitWidth: 80; implicitHeight: 32
                    contentItem: Text {
                        text: parent.text; color: appTheme.textPrimary; font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: parent.hovered ? appTheme.accent : appTheme.inputBg; radius: 4; border.color: appTheme.accent }
                    onClicked: keineSeiteMeldung.close()
                }
            }
        }
    }

    // ── Layout ───────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing:      0

        // --------------------------------------------------------
        // Navigationsleiste (Linke Sidebar)
        // --------------------------------------------------------
        Rectangle {
            id:                    sidebar
            Layout.preferredWidth: panelBreiten.sidebarBreite
            Layout.fillHeight:     true
            color:                 appTheme.sidebar

            onWidthChanged: if (width >= 150) panelBreiten.sidebarBreite = width

            DebugLabel { panelName: qsTr("Navigationsleiste"); visible: root.debugModeAktiv }

            ColumnLayout {
                anchors {
                    fill:    parent
                    margins: 8
                }
                spacing: 2

                Item { height: 4 }
                LogoHeader {
                    logoIndex: root._logoIndex
                    theme:     appTheme
                    Layout.fillWidth: true
                }

                Rectangle { height: 1; color: appTheme.border; Layout.fillWidth: true }
                Item { height: 4 }

                SidebarButton {
                    theme:   appTheme
                    icon:    "📁"
                    label:   qsTr("Projekte")
                    active:  root.aktiveAnsicht === "projekte"
                    tooltip: qsTr("Neues Projekt anlegen oder vorhandenes öffnen")
                    onClicked: root.aktiveAnsicht = "projekte"
                }
                SidebarButton {
                    theme:           appTheme
                    icon:            "📄"
                    label:           qsTr("Seiten")
                    active:          root.aktiveAnsicht === "seiten"
                    enabled:         root.aktivProjektId >= 0
                    opacity:         enabled ? 1.0 : 0.4
                    tooltip:         qsTr("Seitenbaum: Seiten, Anlagen und Orte verwalten")
                    tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
                    onClicked: root.aktiveAnsicht = "seiten"
                }
                SidebarButton {
                    theme:   appTheme
                    icon:    "🔧"
                    label:   qsTr("Bauteile")
                    active:  root.aktiveAnsicht === "bauteile"
                    tooltip: qsTr("Bauteilkatalog: Klemmen, Kabel und Geräte verwalten")
                    onClicked: root.aktiveAnsicht = "bauteile"
                }
                SidebarButton {
                    theme:           appTheme
                    icon:            "📋"
                    label:           qsTr("Listen")
                    active:          root.aktiveAnsicht === "stueckliste"
                    enabled:         root.aktivProjektId >= 0
                    opacity:         enabled ? 1.0 : 0.4
                    tooltip:         qsTr("Stückliste, Kabelliste, Klemmenplan und Querverweise")
                    tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
                    onClicked: root.aktiveAnsicht = "stueckliste"
                }
                SidebarButton {
                    theme:   appTheme
                    icon:    "✏"
                    label:   qsTr("Symbole")
                    active:  root.aktiveAnsicht === "symbol_editor"
                    tooltip: qsTr("Symboleditor: Eigene Schaltsymbole zeichnen und bearbeiten")
                    onClicked: {
                        root.symbolEditorVorher    = root.aktiveAnsicht
                        root.symbolEditorId        = ""
                        root.symbolEditorVorlageId = ""
                        root.aktiveAnsicht         = "symbol_editor"
                    }
                }
                SidebarButton {
                    theme:   appTheme
                    icon:    "⚡"
                    label:   qsTr("Kabelrechner")
                    active:  root.aktiveAnsicht === "kabelrechner"
                    tooltip: qsTr("Leitungsquerschnitt nach VDE 0298 / IEC 60364 berechnen")
                    onClicked: root.aktiveAnsicht = "kabelrechner"
                }
                SidebarButton {
                    theme:           appTheme
                    icon:            "✔"
                    label:           qsTr("IBN")
                    active:          root.aktiveAnsicht === "ibn"
                    enabled:         root.aktivProjektId >= 0
                    opacity:         enabled ? 1.0 : 0.4
                    tooltip:         qsTr("Inbetriebnahme: Betriebsmittel prüfen und Messwerte erfassen")
                    tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
                    onClicked: root.aktiveAnsicht = "ibn"
                }
                SidebarButton {
                    theme:           appTheme
                    icon:            "📐"
                    label:           qsTr("Normblatt")
                    active:          root.aktiveAnsicht === "normblatt"
                    enabled:         root.aktivProjektId >= 0
                    opacity:         enabled ? 1.0 : 0.4
                    tooltip:         qsTr("Schriftfeld nach DIN 6771 gestalten und Normblatt-Vorlage wählen")
                    tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
                    onClicked: root.aktiveAnsicht = "normblatt"
                }
                SidebarButton {
                    theme:           appTheme
                    icon:            "🖨"
                    label:           qsTr("PDF-Export")
                    enabled:         root.aktivProjektId >= 0
                    opacity:         enabled ? 1.0 : 0.4
                    tooltip:         qsTr("Alle Seiten des Projekts als PDF exportieren")
                    tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
                    onClicked: pdfExportDialog.open()
                }
                SidebarButton {
                    theme:   appTheme
                    icon:    "📚"
                    label:   qsTr("Wiki")
                    active:  root.aktiveAnsicht === "wiki"
                    tooltip: qsTr("Erfahrungs-Wiki: Fachwissen nachschlagen und eigene Artikel erfassen")
                    onClicked: root.aktiveAnsicht = "wiki"
                }
                SidebarButton {
                    theme:           appTheme
                    icon:            "⚡"
                    label:           qsTr("SPS/PLS")
                    active:          root.aktiveAnsicht === "sps"
                    enabled:         root.aktivProjektId >= 0
                    opacity:         enabled ? 1.0 : 0.4
                    tooltip:         qsTr("SPS/PLS-Konfiguration: Hardware, Baugruppen und I/O-Kanäle verwalten")
                    tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
                    onClicked: root.aktiveAnsicht = "sps"
                }
                SidebarButton {
                    theme:           appTheme
                    icon:            "⚠"
                    label:           qsTr("DRC")
                    active:          root.drcPanelOffen
                    enabled:         root.aktivProjektId >= 0
                    opacity:         enabled ? 1.0 : 0.4
                    tooltip:         qsTr("Design Rule Check: Schaltplan auf häufige Fehler und Inkonsistenzen prüfen")
                    tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
                    onClicked: root.drcPanelOffen = !root.drcPanelOffen
                }
                SidebarButton {
                    theme:   appTheme
                    icon:    "⚙"
                    label:   qsTr("Einstellungen")
                    active:  root.aktiveAnsicht === "einstellungen"
                    tooltip: qsTr("Theme, Darstellung und App-Einstellungen")
                    onClicked: root.aktiveAnsicht = "einstellungen"
                }

                Item { Layout.fillHeight: true }

                // ── Theme-Picker ──────────────────────────────────
                Rectangle { height: 1; color: appTheme.border; Layout.fillWidth: true }
                Item { height: 4 }
                Text {
                    text:        qsTr("Darstellung")
                    font.pixelSize: 9
                    color:       appTheme.textMuted
                    leftPadding: 4
                }
                Item { height: 3 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: ["dunkel", "hell", "blueprint"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height:       22
                            radius:       3
                            color:        AppTheme.activeName === modelData ? appTheme.activeItemAlt : "transparent"
                            border.color: AppTheme.activeName === modelData ? appTheme.accent : appTheme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text:           root.themes[modelData].name
                                font.pixelSize: 9
                                color:          AppTheme.activeName === modelData ? appTheme.accent : appTheme.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AppTheme.setTheme(modelData)
                            }
                        }
                    }
                }
                Item { height: 4 }

                // ── Sprach-Picker ─────────────────────────────────
                Rectangle { height: 1; color: appTheme.border; Layout.fillWidth: true }
                Item { height: 4 }
                Text {
                    text:        qsTr("Sprache")
                    font.pixelSize: 9
                    color:       appTheme.textMuted
                    leftPadding: 4
                }
                Item { height: 3 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: [
                            { key: "system", label: "Auto" },
                            { key: "de",     label: "DE"   },
                            { key: "en",     label: "EN"   }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height:       22
                            radius:       3
                            color:        root.aktivSprache === modelData.key ? appTheme.activeItemAlt : "transparent"
                            border.color: root.aktivSprache === modelData.key ? appTheme.accent : appTheme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text:           modelData.label
                                font.pixelSize: 9
                                color:          root.aktivSprache === modelData.key ? appTheme.accent : appTheme.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.aktivSprache !== modelData.key) {
                                        root.aktivSprache        = modelData.key
                                        langSettings.language    = modelData.key
                                        appHelper.restart()
                                    }
                                }
                            }
                        }
                    }
                }
                Item { height: 4 }
                // ─────────────────────────────────────────────────

                Rectangle { height: 1; color: appTheme.border; Layout.fillWidth: true }

                Item {
                    height:             48
                    Layout.fillWidth:   true
                    visible:            root.aktivProjektId >= 0

                    Column {
                        anchors {
                            left:           parent.left
                            leftMargin:     8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2
                        Text {
                            text:           qsTr("Aktives Projekt")
                            font.pixelSize: 10
                            color:          appTheme.borderLight
                        }
                        Text {
                            text:           root.aktivProjektName
                            font.pixelSize: 12
                            font.weight:    Font.Medium
                            color:          appTheme.accent
                            width:          180
                            elide:          Text.ElideRight
                        }
                    }
                }
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

            // Projektliste
            ProjectTree {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "projekte"
                theme:        appTheme
                debug:        root.debugModeAktiv

                onProjektGewaehlt: function(id, name) {
                    root.aktivProjektId          = id
                    root.aktivProjektName        = name
                    root.aktivProjektNorm        = db.projektNormLaden(id)
                    root.aktivProjektHintergrund = db.projektHintergrundLaden(id)
                    root.aktivSeiteId            = -1
                    root.aktivSeiteName          = ""
                    seitenModel.laden(id)
                    klemmenleistenModel.laden(id)
                }
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
                        bottom: drcPanel.top
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
                        onKlemmenAnschlussPlatzieren: function(klemmeId, bauteilKlemmeId, anschlussBezeichnung, bmk) {
                            if (root.aktivSeiteId < 0) { keineSeiteMeldung.open(); return }
                            root.aktiverCanvas.paletteExtraDaten = {
                                "bauteilKlemmeId":      bauteilKlemmeId,
                                "anschlussBezeichnung": anschlussBezeichnung,
                                "platziermodus":        "verknuepft",
                                "bmk":                  bmk,
                                "klemmeId":             klemmeId
                            }
                            root.aktiverCanvas.paletteSymbolId = "klemme_anschluss"
                            root.aktiverCanvas.aktivesWerkzeug = "symbol"
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
                        Layout.preferredWidth: 130
                        Layout.fillHeight:     true
                        theme:                 appTheme
                        debug:                 root.debugModeAktiv
                        projektId:             root.aktivProjektId
                        aktiveNorm:            root.aktivProjektNorm

                        onSymbolGewaehlt: function(symCode) {
                            root.aktiverCanvas.paletteSymbolId = symCode
                            root.aktiverCanvas.aktivesWerkzeug = "symbol"
                            root.aktiverCanvas.forceActiveFocus()
                        }
                        onNormGeaendert: function(neuNorm) {
                            root.aktivProjektNorm = neuNorm
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
                    }

                    //\u2500\u2500 Arbeitsbereich: ein oder zwei CanvasPanels \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
                    Rectangle {
                        width:             1
                        Layout.fillHeight: true
                        color:             appTheme.border
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
                            aktiveNorm:       root.aktivProjektNorm
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
                            onMakroListeGeaendert:     bauteilAnsicht.makroListeAktualisieren()
                            onAktivesWerkzeugGeaendert: function(wkz) {
                                if (wkz !== "symbol") symbolPalette.abwaehlen()
                            }
                            onTeilenRechts: { root.splitHorizontal = true;  root.splitAktiv = true }
                            onTeilenUnten:  { root.splitHorizontal = false; root.splitAktiv = true }
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
                            aktiveNorm:       root.aktivProjektNorm
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
                            onMakroListeGeaendert:     bauteilAnsicht.makroListeAktualisieren()
                            onAktivesWerkzeugGeaendert: function(wkz) {
                                if (wkz !== "symbol") symbolPalette.abwaehlen()
                            }
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
                DrcPanel {
                    id:    drcPanel
                    anchors {
                        left:   parent.left
                        right:  parent.right
                        bottom: parent.bottom
                    }
                    height:    root.drcPanelOffen ? 200 : 0
                    visible:   root.drcPanelOffen
                    theme:     appTheme
                    projektId: root.aktivProjektId
                    debug:     root.debugModeAktiv
                    onSchliessen: root.drcPanelOffen = false

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
                onMakroEinfuegenAngefordert: function(makroId, name) {
                    if (root.aktivSeiteId < 0) {
                        keineSeiteMeldung.open()
                        return
                    }
                    root.aktiveAnsicht = "seiten"
                    root.aktiverCanvas.makroEinfuegenId   = makroId
                    root.aktiverCanvas.makroEinfuegenName = name
                    root.aktiverCanvas.aktivesWerkzeug    = "makroEinfuegen"
                }

                onKlemmeAnschlussModusAPlatzieren: function(bauteilKlemmeId, anschlussBezeichnung, bmk, klemmeId) {
                    if (root.aktivSeiteId < 0) {
                        keineSeiteMeldung.open()
                        return
                    }
                    root.aktiveAnsicht = "seiten"
                    root.aktiverCanvas.paletteExtraDaten = {
                        "bauteilKlemmeId":      bauteilKlemmeId,
                        "anschlussBezeichnung": anschlussBezeichnung,
                        "platziermodus":        "verknuepft",
                        "bmk":                  bmk,
                        "klemmeId":             klemmeId
                    }
                    root.aktiverCanvas.paletteSymbolId  = "klemme_anschluss"
                    root.aktiverCanvas.aktivesWerkzeug  = "symbol"
                    root.aktiverCanvas.forceActiveFocus()
                }
            }

            // Listen (Stückliste + Querverweise)
            ListenAnsicht {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "stueckliste"
                theme:        appTheme
                debug:        root.debugModeAktiv
                projektId:    root.aktivProjektId
                projektName:  root.aktivProjektName
                canvas:       root.aktiverCanvas
            }

            // Klemmen-Editor Vollbild
            Item {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "klemmen_editor"

                DebugLabel { panelName: qsTr("Klemmen-Editor Ansicht"); visible: root.debugModeAktiv }

                ColumnLayout {
                    anchors.fill: parent
                    spacing:      0

                    // Breadcrumb-Leiste
                    Rectangle {
                        Layout.fillWidth: true
                        height:           44
                        color:            appTheme.sidebar

                        DebugLabel { panelName: qsTr("Breadcrumb-Leiste"); visible: root.debugModeAktiv }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 16 }
                            spacing: 6

                            Button {
                                text: "← " + qsTr("Bauteile"); flat: true; implicitHeight: 28
                                contentItem: Text {
                                    text: parent.text; color: appTheme.accent; font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle { color: parent.hovered ? appTheme.badge : "transparent"; radius: 4 }
                                onClicked: root.aktiveAnsicht = "bauteile"
                            }
                            Text { text: "/"; color: appTheme.textMuted; font.pixelSize: 12 }
                            Text {
                                text:           bauteilAnsicht.selectedBauteilBezeichnung
                                font.pixelSize: 13; font.weight: Font.Medium
                                color:          appTheme.textPrimary
                            }
                            Text { text: "/"; color: appTheme.textMuted; font.pixelSize: 12 }
                            Text {
                                text:           qsTr("Klemmen-Editor")
                                font.pixelSize: 12
                                color:          appTheme.textMuted
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: appTheme.border }

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
                                keineSeiteMeldung.open()
                                return
                            }
                            root.aktiveAnsicht = "seiten"
                            root.aktiverCanvas.paletteExtraDaten = {
                                "bauteilKlemmeId":      bkId,
                                "anschlussBezeichnung": bez,
                                "platziermodus":        modus
                            }
                            root.aktiverCanvas.paletteSymbolId  = "klemme_anschluss"
                            root.aktiverCanvas.aktivesWerkzeug  = "symbol"
                            root.aktiverCanvas.forceActiveFocus()
                        }
                    }
                }
            }

            // Kabel-Editor Vollbild
            Item {
                anchors.fill: parent
                visible:      root.aktiveAnsicht === "kabel_editor"

                DebugLabel { panelName: qsTr("Kabel-Editor Ansicht"); visible: root.debugModeAktiv }

                ColumnLayout {
                    anchors.fill: parent
                    spacing:      0

                    Rectangle {
                        Layout.fillWidth: true
                        height:           44
                        color:            appTheme.sidebar

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 16 }
                            spacing: 6

                            Button {
                                text: "← " + qsTr("Bauteile"); flat: true; implicitHeight: 28
                                contentItem: Text {
                                    text: parent.text; color: appTheme.accent; font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle { color: parent.hovered ? appTheme.badge : "transparent"; radius: 4 }
                                onClicked: root.aktiveAnsicht = "bauteile"
                            }
                            Text { text: "/"; color: appTheme.textMuted; font.pixelSize: 12 }
                            Text {
                                text:           bauteilAnsicht.selectedBauteilBezeichnung
                                font.pixelSize: 13; font.weight: Font.Medium
                                color:          appTheme.textPrimary
                            }
                            Text { text: "/"; color: appTheme.textMuted; font.pixelSize: 12 }
                            Text {
                                text:           qsTr("Kabel-Editor")
                                font.pixelSize: 12
                                color:          appTheme.textMuted
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: appTheme.border }

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
                editSymbolId: root.symbolEditorId
                vorlageId:    root.symbolEditorVorlageId

                onGespeichert: function(symbolId) {
                    symbolPalette.laden()
                    root.aktiveAnsicht = (root.symbolEditorVorher !== "symbol_editor")
                                          ? root.symbolEditorVorher : "seiten"
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

                        onBmkGewaehlt: function(sid, elementId, wx, wy) {
                            if (sid !== root.aktivSeiteId) {
                                ibnCanvas._querverweisZielPos = { x: wx, y: wy }
                                root.aktivSeiteId = sid
                            } else {
                                ibnCanvas._zoomZuWeltPosition(wx, wy)
                            }
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
                }
                onGespraechTexteGeaendert: root._funGesprTexte = json
            }
        }
    }

    // ── Projekt-Start-Overlay (kein Projekt geöffnet) ────────────
    ProjektStartAnsicht {
        anchors.fill: parent
        visible:      !db.projektOffen
        theme:        appTheme
        z:            200
        debug:        root.debugModeAktiv
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

    // ── Shortcut-Übersicht ────────────────────────────────────────
    ShortcutUebersicht {
        id:           shortcutUebersicht
        anchors.fill: parent
        z:            700
        theme:        appTheme
        debug:        root.debugModeAktiv
    }

    // ── Globale Canvas-Shortcuts ──────────────────────────────────
    // Eine einzige Instanz pro Taste – leitet über root.aktiverCanvas weiter.
    // Verhindert Ambiguität wenn panel1 + panel2 im Split-Modus beide sichtbar sind.
    // WindowShortcut feuert erst nachdem ein TextInput den Event selbst verarbeitet hat.

    // Löschen
    Shortcut {
        sequence: "Delete"
        onActivated: {
            if (root.aktiveAnsicht !== "seiten") return
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
        onActivated: {
            if (root.aktiveAnsicht !== "seiten") return
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
    Shortcut { sequence: "C"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="kabellinie"} } }
    Shortcut { sequence: "N"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.abbruch();c.aktivesWerkzeug="notiz"} } }
    Shortcut { sequence: "S"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv&&c.paletteSymbolId!==""){c.abbruch();c.aktivesWerkzeug="symbol"} } }
    Shortcut { sequence: "F"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.querverweisZurGegenseiteNavigieren() } }
    Shortcut { sequence: "Escape"; onActivated: {
        var c = root.aktiverCanvas
        if (root.aktiveAnsicht === "seiten" && c) c.handleEscape()
        else if (root.aktiveAnsicht === "symbol_editor") { symbolEditorAnsicht.werkzeugPunkte = []; symbolEditorAnsicht.repaintAll() }
    } }

    // Undo / Redo
    Shortcut { sequence: "Ctrl+Z";       onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.undo() } }
    Shortcut { sequence: "Ctrl+Y";       onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.redo() } }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c) c.redo() } }

    // Auswahl / Bearbeiten
    Shortcut { sequence: "Ctrl+A"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.alleAuswaehlen() } }
    Shortcut { sequence: "Ctrl+C"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.kopieren(0) } }
    Shortcut { sequence: "Ctrl+X"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv){c.kopieren(0);c.loeschen()} } }
    Shortcut { sequence: "Ctrl+V"; onActivated: { var c=root.aktiverCanvas; if(root.aktiveAnsicht==="seiten"&&c&&!c.textEditAktiv) c.einfuegen(0) } }

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

    // Seitennavigation
    Shortcut {
        sequence: "PgUp"
        context:  Shortcut.ApplicationShortcut
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
        context:  Shortcut.ApplicationShortcut
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

    // Shortcut-Übersicht
    Shortcut { sequence: "F1"; context: Shortcut.ApplicationShortcut; onActivated: shortcutUebersicht.visible = !shortcutUebersicht.visible }

    // ── Datenbank-Fehler-Dialog ───────────────────────────────────
    Dialog {
        id:              dbFehlerDialog
        title:           "Datenbankfehler"
        modal:           true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok
        property string meldung: ""

        Label {
            width:     Math.min(500, dbFehlerDialog.availableWidth)
            text:      dbFehlerDialog.meldung
            wrapMode:  Text.WordWrap
            color:     appTheme.textPrimary
        }
    }

    Connections {
        target: db
        function onDbFehler(meldung) {
            dbFehlerDialog.meldung = meldung
            dbFehlerDialog.open()
        }
    }

    // ── Projekt öffnen/schließen reagieren ───────────────────────
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
            // Projekt-Modelle neu laden
            projektModel.laden()
            // Erstes (einziges) Projekt automatisch auswählen
            var info = db.ersteProjektInfo()
            if (info.id > 0) {
                root.aktivProjektId          = info.id
                root.aktivProjektName        = info.name
                root.aktivProjektNorm        = db.projektNormLaden(info.id)
                root.aktivProjektHintergrund = db.projektHintergrundLaden(info.id)
                root.aktiveAnsicht           = "projekte"
                seitenModel.laden(info.id)
                klemmenleistenModel.laden(info.id)
            }
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
