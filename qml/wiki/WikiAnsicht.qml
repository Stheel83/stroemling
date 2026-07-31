import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    required property var theme
    property bool debug: false

    // ── State ─────────────────────────────────────────────────
    property var  _kategorien: []
    property int  _katIdx:     -1
    property var  _artikel:    []
    property int  _artIdx:     -1
    property var  _aktArtikel: ({})
    property bool _editModus:  false

    property string _editTitel:  ""
    property string _editInhalt: ""
    property string _editTags:   ""

    property bool _neuKatModus: false
    property bool _neuArtModus: false
    property string _neuKatName: ""
    property string _neuArtTitel: ""

    property string _importPfad:       ""
    property string _bundleExportPfad: ""
    property string _bundleKennung:    ""
    property string _bundleTitel:      ""
    property int    _bundleVersion:    1
    property var    _bundleKatIds:     []

    // Bilder des aktuellen Artikels — [{id, dateiname, mimeTyp, beschreibung, sortierung, tempPfad}]
    property var    _bilder:          []
    property string _vollbildPfad:    ""
    property string _vollbildBeschr:  ""

    readonly property bool _hatKategorie: _katIdx >= 0 && _katIdx < _kategorien.length
    readonly property bool _hatArtikel:   _artIdx >= 0 && _artIdx < _artikel.length
    readonly property int  _aktKatId:     _hatKategorie ? _kategorien[_katIdx].id : -1
    readonly property int  _aktArtId:     _hatArtikel   ? _artikel[_artIdx].id   : -1

    // ── Lifecycle ─────────────────────────────────────────────
    Component.onCompleted: _kategorienLaden()
    onVisibleChanged: if (visible) _kategorienLaden()

    // ── Datenzugriff ──────────────────────────────────────────
    function _kategorienLaden() {
        _kategorien = db.wikiAlleKategorien()
        if (_katIdx >= _kategorien.length) _katIdx = _kategorien.length - 1
    }

    function _artikelLaden(katId) {
        _artikel = db.wikiArtikelFuerKategorie(katId)
        _artIdx = -1
        _aktArtikel = ({})
        _editModus = false
    }

    function _artikelInhaltLaden(artId) {
        _aktArtikel = db.wikiArtikelLaden(artId)
        _bilderLaden(artId)
        _editModus = false
    }

    // Für F1-Kontexthilfe: öffnet den Artikel mit exaktem Titel-Match,
    // unabhängig von dessen Kategorie. Liefert false wenn nicht gefunden.
    function oeffneArtikelNachTitel(titel) {
        _kategorienLaden()
        for (var i = 0; i < _kategorien.length; i++) {
            var arts = db.wikiArtikelFuerKategorie(_kategorien[i].id)
            for (var j = 0; j < arts.length; j++) {
                if (arts[j].titel === titel) {
                    _katIdx = i
                    _artikel = arts
                    _artIdx = j
                    _artikelInhaltLaden(arts[j].id)
                    return true
                }
            }
        }
        return false
    }

    function _bilderLaden(artId) {
        var liste = db.wikiBilderFuerArtikel(artId)
        var result = []
        for (var i = 0; i < liste.length; i++) {
            var item = liste[i]
            item.tempPfad = db.wikiBildAlsTempDatei(item.id)
            result.push(item)
        }
        _bilder = result
    }

    function _preprocessMarkdown(md) {
        var result = md
        for (var i = 0; i < root._bilder.length; i++) {
            var b = root._bilder[i]
            if (b.tempPfad && b.id)
                result = result.split("wiki://bild/" + b.id).join("file://" + b.tempPfad)
        }
        return result
    }

    function _editStarten() {
        _editTitel  = _aktArtikel.titel  || ""
        _editInhalt = _aktArtikel.inhalt || ""
        _editTags   = _aktArtikel.tags   || ""
        _editModus  = true
    }


    function _speichern() {
        if (_aktArtId < 0) return
        db.wikiArtikelSpeichern(_aktArtId, _editTitel.trim(), _editInhalt, _editTags.trim())
        _aktArtikel = db.wikiArtikelLaden(_aktArtId)
        _artikel    = db.wikiArtikelFuerKategorie(_aktKatId)
        _editModus  = false
        achievementManager.ereignis("wiki_artikel_bearbeitet")
    }

    function _neueKategorieBestaetigen() {
        const name = _neuKatName.trim()
        if (name === "") { _neuKatModus = false; return }
        const newId = db.wikiKategorieAnlegen(name, "")
        _neuKatModus = false
        _neuKatName  = ""
        achievementManager.ereignis("wiki_kategorie_erstellt")
        _kategorienLaden()
        // neu angelegte Kategorie selektieren
        for (var i = 0; i < _kategorien.length; i++) {
            if (_kategorien[i].id === newId) { _katIdx = i; break }
        }
        _artikelLaden(_aktKatId)
    }

    function _neuerArtikelBestaetigen() {
        const titel = _neuArtTitel.trim()
        if (titel === "" || _aktKatId < 0) { _neuArtModus = false; return }
        const newId = db.wikiArtikelAnlegen(_aktKatId, titel)
        achievementManager.ereignis("wiki_artikel_erstellt")
        _neuArtModus  = false
        _neuArtTitel  = ""
        _artikel = db.wikiArtikelFuerKategorie(_aktKatId)
        for (var i = 0; i < _artikel.length; i++) {
            if (_artikel[i].id === newId) { _artIdx = i; break }
        }
        _artikelInhaltLaden(_aktArtId)
        _editStarten()
    }

    // ── Layout ────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        // Persistenter Hinweis: Wiki-Inhalte entstehen u. a. mit KI-Unterstützung
        Rectangle {
            Layout.fillWidth: true
            height:           26
            color:            root.theme.surfaceDeep
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1; color: root.theme.border
            }
            Text {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text:           qsTr("🤖 Wiki-Inhalte entstehen u. a. mit Unterstützung von KI (Claude Code) — redaktionell geprüft.")
                font.pixelSize: 10
                color:          root.theme.textMuted
            }
        }

    RowLayout {
        Layout.fillWidth:  true
        Layout.fillHeight: true
        spacing:      0

        // ── Spalte 1: Kategorien ──────────────────────────────
        Rectangle {
            Layout.preferredWidth: 180
            Layout.fillHeight:     true
            color:                 root.theme.surfaceDeep

            ColumnLayout {
                anchors.fill: parent
                spacing:      0

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    height:           36
                    color:            root.theme.surfaceDeep
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: root.theme.border
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                        Text {
                            text:           qsTr("Kategorien")
                            font.pixelSize: 11
                            font.weight:    Font.Medium
                            color:          root.theme.textMuted
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: exportBtnHover.hovered ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "↑"
                                font.pixelSize: 12
                                color: root.theme.textMuted
                            }
                            ToolTip.visible: exportBtnHover.hovered
                            ToolTip.text:    qsTr("Wiki exportieren")
                            ToolTip.delay:   700
                            HoverHandler { id: exportBtnHover }
                            TapHandler { onTapped: wikiExportDialog.open() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: importBtnHover.hovered ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "↓"
                                font.pixelSize: 12
                                color: root.theme.textMuted
                            }
                            ToolTip.visible: importBtnHover.hovered
                            ToolTip.text:    qsTr("Wiki importieren")
                            ToolTip.delay:   700
                            HoverHandler { id: importBtnHover }
                            TapHandler { onTapped: wikiImportDialog.open() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: bundleBtnHover.hovered ? "#5b8dd9" + "33" : "transparent"
                            border.color: (bundleBtnHover.hovered) ? "#5b8dd9" : root.theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "🗂"
                                font.pixelSize: 11
                            }
                            ToolTip.visible: bundleBtnHover.hovered
                            ToolTip.text:    qsTr("Bundle-Menü – vorgefertigte Artikel-Sammlungen laden oder installieren")
                            ToolTip.delay:   700
                            HoverHandler { id: bundleBtnHover }
                            TapHandler { onTapped: wikiBundle.open() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: katAddHover.hovered ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            visible: !root._neuKatModus
                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 14
                                color: root.theme.textPrimary
                            }
                            ToolTip.visible: katAddHover.hovered
                            ToolTip.text:    qsTr("Neue Kategorie")
                            ToolTip.delay:   700
                            HoverHandler { id: katAddHover }
                            TapHandler { onTapped: { root._neuKatName = ""; root._neuKatModus = true } }
                        }
                    }
                }

                // Neue-Kategorie-Eingabe
                Rectangle {
                    Layout.fillWidth: true
                    height:           visible ? 38 : 0
                    visible:          root._neuKatModus
                    color:            root.theme.surface
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.border
                    }
                    RowLayout {
                        anchors { fill: parent; margins: 4 }
                        spacing: 4
                        TextField {
                            id:               neuKatField
                            Layout.fillWidth: true
                            height:           28
                            font.pixelSize:   11
                            color:            root.theme.textPrimary
                            background: Rectangle {
                                radius: 3
                                color:  root.theme.inputBg
                                border.color: neuKatField.activeFocus ? root.theme.accent : root.theme.border
                            }
                            placeholderText: qsTr("Name …")
                            text: root._neuKatName
                            onTextChanged:    root._neuKatName = text
                            onAccepted:       root._neueKategorieBestaetigen()
                            Keys.onEscapePressed: { root._neuKatModus = false }
                            Component.onCompleted: forceActiveFocus()
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: katOkHover.hovered ? root.theme.accent : root.theme.border
                            Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 11; color: root.theme.textPrimary }
                            ToolTip.visible: katOkHover.hovered
                            ToolTip.text:    qsTr("Kategorie anlegen")
                            ToolTip.delay:   700
                            HoverHandler { id: katOkHover }
                            TapHandler { onTapped: root._neueKategorieBestaetigen() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: katXHover.hovered ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: root.theme.textMuted }
                            ToolTip.visible: katXHover.hovered
                            ToolTip.text:    qsTr("Abbrechen")
                            ToolTip.delay:   700
                            HoverHandler { id: katXHover }
                            TapHandler { onTapped: root._neuKatModus = false }
                        }
                    }
                }

                // Kategorienliste
                ListView {
                    id:               katListe
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip:             true
                    model:            root._kategorien

                    delegate: Rectangle {
                        id:      katDeleg
                        width:   katListe.width
                        height:  34
                        color:   root._katIdx === index
                                 ? root.theme.accent + "33"
                                 : (katDelegHover.hovered ? root.theme.hover : "transparent")

                        property bool _editModus: false

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 1; color: root.theme.divider
                        }

                        // Linker Akzentbalken für aktive Kategorie
                        Rectangle {
                            width:   3
                            height:  parent.height
                            color:   root.theme.accent
                            visible: root._katIdx === index
                        }

                        Text {
                            id: katNameText
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 8 }
                            text:           modelData.name
                            font.pixelSize: 12
                            color:          root._katIdx === index ? root.theme.accent : root.theme.textPrimary
                            elide:          Text.ElideRight
                            visible:        !katDeleg._editModus
                        }

                        TextField {
                            id: katUmbenennFeld
                            anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            visible:        katDeleg._editModus
                            font.pixelSize: 12
                            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.accent; radius: 3 }
                            color:          root.theme.textPrimary
                            onVisibleChanged: if (visible) { text = modelData.name; selectAll(); forceActiveFocus() }
                            Keys.onReturnPressed: {
                                var n = text.trim()
                                if (n.length > 0) db.wikiKategorieUmbenennen(modelData.id, n, modelData.beschreibung)
                                katDeleg._editModus = false
                                root._kategorienLaden()
                            }
                            Keys.onEscapePressed: katDeleg._editModus = false
                        }

                        HoverHandler { id: katDelegHover }
                        TapHandler {
                            onTapped: {
                                root._katIdx = index
                                root._artikelLaden(modelData.id)
                            }
                            onDoubleTapped: {
                                root._katIdx = index
                                katDeleg._editModus = true
                            }
                        }
                    }
                }
            }
        }

        // Trennlinie
        Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.border }

        // ── Spalte 2: Artikel ─────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 240
            Layout.fillHeight:     true
            color:                 root.theme.surface

            ColumnLayout {
                anchors.fill: parent
                spacing:      0

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    height:           36
                    color:            root.theme.surface
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.border
                    }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                        Text {
                            text: root._hatKategorie
                                  ? root._kategorien[root._katIdx].name
                                  : qsTr("Artikel")
                            font.pixelSize: 11
                            font.weight:    Font.Medium
                            color:          root.theme.textMuted
                            Layout.fillWidth: true
                            elide:          Text.ElideRight
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: artAddHover.hovered ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            visible: root._hatKategorie && !root._neuArtModus
                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 14
                                color: root.theme.textPrimary
                            }
                            ToolTip.visible: artAddHover.hovered
                            ToolTip.text:    qsTr("Neuer Artikel")
                            ToolTip.delay:   700
                            HoverHandler { id: artAddHover }
                            TapHandler { onTapped: { root._neuArtTitel = ""; root._neuArtModus = true } }
                        }
                    }
                }

                // Suchfeld
                Rectangle {
                    Layout.fillWidth: true
                    height:           44
                    color:            root.theme.surface
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.divider
                    }
                    TextField {
                        id: suchFeld
                        anchors { fill: parent; margins: 6 }
                        font.pixelSize: 13
                        color:          root.theme.textPrimary
                        leftPadding:    30
                        background: Rectangle {
                            radius: 4
                            color:  root.theme.inputBg
                            border.color: suchFeld.activeFocus ? root.theme.accent : root.theme.borderLight
                        }
                        placeholderText: qsTr("Suchen …")
                        Text {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text:           "🔍"
                            font.pixelSize: 13
                        }
                        onTextChanged: {
                            if (text.trim() !== "") {
                                root._artikel = db.wikiSuchen(text.trim())
                                root._artIdx  = -1
                            } else if (root._hatKategorie) {
                                root._artikel = db.wikiArtikelFuerKategorie(root._aktKatId)
                            }
                        }
                    }
                }

                // Neuer-Artikel-Eingabe
                Rectangle {
                    Layout.fillWidth: true
                    height:           visible ? 38 : 0
                    visible:          root._neuArtModus
                    color:            root.theme.surface
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.border
                    }
                    RowLayout {
                        anchors { fill: parent; margins: 4 }
                        spacing: 4
                        TextField {
                            id:               neuArtField
                            Layout.fillWidth: true
                            height:           28
                            font.pixelSize:   11
                            color:            root.theme.textPrimary
                            background: Rectangle {
                                radius: 3
                                color:  root.theme.inputBg
                                border.color: neuArtField.activeFocus ? root.theme.accent : root.theme.border
                            }
                            placeholderText: qsTr("Titel …")
                            text: root._neuArtTitel
                            onTextChanged:   root._neuArtTitel = text
                            onAccepted:      root._neuerArtikelBestaetigen()
                            Keys.onEscapePressed: root._neuArtModus = false
                            Component.onCompleted: if (root._neuArtModus) forceActiveFocus()
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: artOkHover.hovered ? root.theme.accent : root.theme.border
                            Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 11; color: root.theme.textPrimary }
                            ToolTip.visible: artOkHover.hovered
                            ToolTip.text:    qsTr("Artikel anlegen")
                            ToolTip.delay:   700
                            HoverHandler { id: artOkHover }
                            TapHandler { onTapped: root._neuerArtikelBestaetigen() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: artXHover.hovered ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: root.theme.textMuted }
                            ToolTip.visible: artXHover.hovered
                            ToolTip.text:    qsTr("Abbrechen")
                            ToolTip.delay:   700
                            HoverHandler { id: artXHover }
                            TapHandler { onTapped: root._neuArtModus = false }
                        }
                    }
                }

                // Artikelliste
                ListView {
                    id:               artListe
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip:             true
                    model:            root._artikel

                    delegate: Rectangle {
                        width:  artListe.width
                        height: 40
                        color:  root._artIdx === index
                                ? root.theme.accent + "33"
                                : (artDelegHover.hovered ? root.theme.hover : "transparent")
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 1; color: root.theme.divider
                        }
                        Rectangle {
                            width: 3; height: parent.height
                            color: root.theme.accent
                            visible: root._artIdx === index
                        }

                        Column {
                            anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Row {
                                spacing: 4
                                width: parent.width
                                Text {
                                    width:          modelData.istSystem ? parent.width - artSysText.implicitWidth - 10 : parent.width
                                    text:           modelData.titel
                                    font.pixelSize: 12
                                    color:          root._artIdx === index ? root.theme.accent : root.theme.textPrimary
                                    elide:          Text.ElideRight
                                }
                                Rectangle {
                                    visible: modelData.istSystem == 1
                                    width:  artSysText.implicitWidth + 6
                                    height: 13
                                    radius: 3
                                    color:  root.theme.accent + "44"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        id: artSysText
                                        anchors.centerIn: parent
                                        text:           "SYS"
                                        font.pixelSize: 8
                                        color:          root.theme.accent
                                    }
                                }
                                Rectangle {
                                    visible: (modelData.bundleKennung || "") !== ""
                                    width:  artBundleText.implicitWidth + 6
                                    height: 13
                                    radius: 3
                                    color:  "#5b8dd9" + "44"
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        id: artBundleText
                                        anchors.centerIn: parent
                                        text:           "BND"
                                        font.pixelSize: 8
                                        color:          "#5b8dd9"
                                    }
                                }
                            }
                            Text {
                                width:          parent.width
                                text:           modelData.tags || ""
                                font.pixelSize: 9
                                color:          root.theme.textMuted
                                elide:          Text.ElideRight
                                visible:        text !== ""
                            }
                        }

                        HoverHandler { id: artDelegHover }
                        TapHandler {
                            onTapped: {
                                root._artIdx = index
                                root._artikelInhaltLaden(modelData.id)
                                root._neuArtModus = false
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: artListe.count === 0 && root._hatKategorie
                        spacing: 12

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source:   "qrc:/assets/isolus.png"
                            width:    180; height: 180
                            fillMode: Image.PreserveAspectFit
                            smooth:   true; mipmap: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:           qsTr("Noch keine Artikel.\nAuf + klicken um einen anzulegen.")
                            color:          root.theme.textMuted
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        // Trennlinie
        Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.border }

        // ── Spalte 3: Inhalt ─────────────────────────────────
        Rectangle {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            color:             root.theme.surface

            ColumnLayout {
                anchors.fill: parent
                spacing:      0

                // Header: Titel + Buttons
                Rectangle {
                    Layout.fillWidth: true
                    height:           44
                    color:            root.theme.surfaceDeep
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.border
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 10 }
                        spacing: 8

                        // Titel — Leseansicht oder Eingabefeld
                        Text {
                            Layout.fillWidth: true
                            visible:   !root._editModus
                            text:      root._aktArtikel.titel || ""
                            font.pixelSize: 15
                            font.weight:    Font.Medium
                            color:          root.theme.textPrimary
                            elide:          Text.ElideRight
                        }

                        TextField {
                            id:               titelFeld
                            Layout.fillWidth: true
                            visible:          root._editModus
                            height:           30
                            font.pixelSize:   14
                            font.weight:      Font.Medium
                            color:            root.theme.textPrimary
                            background: Rectangle {
                                radius: 3
                                color: root.theme.inputBg
                                border.color: titelFeld.activeFocus ? root.theme.accent : root.theme.border
                            }
                            text: root._editTitel
                            onTextChanged: root._editTitel = text

                            Binding on text {
                                when: !titelFeld.activeFocus
                                value: root._editTitel
                            }
                        }

                        // Buttons: Bearbeiten (Leseansicht) / Speichern + Abbrechen (Edit)
                        Rectangle {
                            visible:  !root._editModus && root._hatArtikel
                            width:    80; height: 26; radius: 3
                            color:    editBtnHover.hovered ? root.theme.accent : root.theme.border
                            ToolTip.visible: editBtnHover.hovered; ToolTip.delay: 600
                            ToolTip.text: qsTr("Artikel bearbeiten")
                            Text {
                                anchors.centerIn: parent
                                text:           qsTr("✏ Bearbeiten")
                                font.pixelSize: 10
                                color:          root.theme.textPrimary
                            }
                            HoverHandler { id: editBtnHover }
                            TapHandler   { onTapped: root._editStarten() }
                        }
                        Rectangle {
                            visible:  root._editModus
                            width:    70; height: 26; radius: 3
                            color:    saveBtnHover.hovered ? root.theme.accent : Qt.darker(root.theme.accent, 1.15)
                            ToolTip.visible: saveBtnHover.hovered; ToolTip.delay: 600
                            ToolTip.text: qsTr("Änderungen speichern")
                            Text {
                                anchors.centerIn: parent
                                text:           qsTr("✔ Speichern")
                                font.pixelSize: 10
                                color:          "white"
                            }
                            HoverHandler { id: saveBtnHover }
                            TapHandler   { onTapped: root._speichern() }
                        }
                        Rectangle {
                            visible:  root._editModus
                            width:    62; height: 26; radius: 3
                            color:    cancelBtnHover.hovered ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: cancelBtnHover.hovered; ToolTip.delay: 600
                            ToolTip.text: qsTr("Bearbeitung abbrechen ohne zu speichern")
                            Text {
                                anchors.centerIn: parent
                                text:           qsTr("✕ Abbrechen")
                                font.pixelSize: 10
                                color:          root.theme.textMuted
                            }
                            HoverHandler { id: cancelBtnHover }
                            TapHandler   { onTapped: root._editModus = false }
                        }

                        // Löschen-Button (Leseansicht, nur für Nutzer-Artikel)
                        Rectangle {
                            visible:  !root._editModus && root._hatArtikel && !(root._aktArtikel.istSystem == 1)
                            width:    22; height: 22; radius: 3
                            color:    delBtnHover.hovered ? "#c0392b33" : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: delBtnHover.hovered; ToolTip.delay: 600
                            ToolTip.text: qsTr("Artikel unwiderruflich löschen")
                            Text {
                                anchors.centerIn: parent
                                text: "🗑"
                                font.pixelSize: 11
                            }
                            HoverHandler { id: delBtnHover }
                            TapHandler {
                                onTapped: {
                                    db.wikiArtikelLoeschen(root._aktArtId)
                                    root._artikel = db.wikiArtikelFuerKategorie(root._aktKatId)
                                    root._artIdx  = -1
                                    root._aktArtikel = ({})
                                    root._bilder = []
                                }
                            }
                        }
                    }
                }

                // Tags-Zeile (Leseansicht)
                Rectangle {
                    Layout.fillWidth: true
                    height:           visible ? 30 : 0
                    visible:          !root._editModus && (root._aktArtikel.tags || "") !== ""
                    color:            root.theme.surface
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.divider
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        text:           "🏷 " + (root._aktArtikel.tags || "")
                        font.pixelSize: 10
                        color:          root.theme.textMuted
                    }
                }

                // Bundle-Indikator (Leseansicht)
                Rectangle {
                    Layout.fillWidth: true
                    height:           visible ? 30 : 0
                    visible:          !root._editModus && (root._aktArtikel.bundleKennung || "") !== ""
                    color:            "#5b8dd9" + "18"
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.divider
                    }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                        spacing: 6
                        Text {
                            text:           "🗂 Bundle: " + (root._aktArtikel.bundleKennung || "")
                                            + ((root._aktArtikel.vonNutzerGeaendert == 1) ? "  • bearbeitet" : "")
                            font.pixelSize: 10
                            color:          "#5b8dd9"
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible:  root._aktArtikel.vonNutzerGeaendert == 1
                            width:    resetBndHover.hovered ? resetBndText.implicitWidth + 12 : 16
                            implicitHeight: 18; radius: 3
                            color:    resetBndHover.hovered ? "#5b8dd9" + "33" : "transparent"
                            border.color: "#5b8dd9" + "66"
                            Behavior on width { NumberAnimation { duration: 100 } }
                            Text {
                                id:             resetBndText
                                anchors.centerIn: parent
                                text:           resetBndHover.hovered ? qsTr("Zurücksetzen") : "↺"
                                font.pixelSize: 9
                                color:          "#5b8dd9"
                            }
                            HoverHandler { id: resetBndHover }
                            TapHandler {
                                onTapped: {
                                    db.wikiBundleArtikelZuruecksetzen(root._aktArtId)
                                    root._aktArtikel = db.wikiArtikelLaden(root._aktArtId)
                                    root._artikel    = db.wikiArtikelFuerKategorie(root._aktKatId)
                                }
                            }
                        }
                    }
                }

                // Tags-Eingabe (Edit)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight:    visible ? 34 : 0
                    visible:          root._editModus
                    color:            root.theme.surface
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.divider
                    }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 8
                        Text {
                            text:           "🏷 " + qsTr("Tags:")
                            font.pixelSize: 10
                            color:          root.theme.textMuted
                        }
                        TextField {
                            id:               tagsFeld
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26
                            font.pixelSize:   11
                            color:            root.theme.textPrimary
                            background: Rectangle {
                                radius: 3
                                color: root.theme.inputBg
                                border.color: tagsFeld.activeFocus ? root.theme.accent : root.theme.border
                            }
                            placeholderText: qsTr("kommagetrennt, z.B. TN-C, Altbestand")
                            text: root._editTags
                            onTextChanged: root._editTags = text

                            Binding on text {
                                when: !tagsFeld.activeFocus
                                value: root._editTags
                            }
                        }
                    }
                }

                // ── Formatierungs-Toolbar (Edit-Modus) ───────────────
                WikiFormatierungsToolbar {
                    id: formatierungsToolbar
                    theme: root.theme
                    textArea: inhaltEdit
                    visible: root._editModus
                    onBildEinfuegenAngefordert: bildEinfuegenPopup.open()
                }

                // ── Textbereich ───────────────────────────────
                // Leseansicht (Markdown gerendert)
                ScrollView {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    visible:           !root._editModus && root._hatArtikel
                    clip:              true
                    contentWidth:      availableWidth

                    TextArea {
                        leftPadding:    24
                        rightPadding:   24
                        topPadding:     20
                        bottomPadding:  20
                        readOnly:       true
                        wrapMode:       TextEdit.Wrap
                        textFormat:     TextEdit.MarkdownText
                        font.pixelSize: 13
                        color:          root.theme.textPrimary
                        background:     null
                        selectByMouse:  true
                        onLinkActivated: function(link) { Qt.openUrlExternally(link) }
                        text:           (root._aktArtikel.inhalt || "") !== ""
                                        ? root._preprocessMarkdown(root._aktArtikel.inhalt)
                                        : qsTr("*(Noch kein Inhalt – auf Bearbeiten klicken)*")
                    }
                }

                // Bearbeitungsansicht
                ScrollView {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    visible:           root._editModus
                    clip:              true
                    contentWidth:      availableWidth

                    TextArea {
                        id:             inhaltEdit
                        leftPadding:    24
                        rightPadding:   24
                        topPadding:     16
                        wrapMode:       TextArea.Wrap
                        font.pixelSize: 13
                        color:          root.theme.textPrimary
                        background:     null
                        placeholderText: qsTr("Text eingeben – Toolbar nutzen oder Markdown schreiben")

                        text: root._editInhalt

                        Binding on text {
                            when: !inhaltEdit.activeFocus
                            value: root._editInhalt
                        }
                        onTextChanged: root._editInhalt = text

                        Keys.onPressed: function(e) {
                            if (e.modifiers & Qt.ControlModifier) {
                                if      (e.key === Qt.Key_S) { root._speichern();               e.accepted = true }
                                else if (e.key === Qt.Key_B) { formatierungsToolbar._fmtWrap("**", "**"); e.accepted = true }
                                else if (e.key === Qt.Key_I) { formatierungsToolbar._fmtWrap("*", "*");  e.accepted = true }
                            }
                        }
                    }
                }

                // ── Bildgalerie ───────────────────────────────
                WikiBildGalerie {
                    bilder:  root._bilder
                    theme:   root.theme
                    visible: root._hatArtikel
                    onBildHinzufuegenAngefordert: bildFileDialog.open()
                    onVollbildAnzeigen: function(pfad, beschr) {
                        root._vollbildPfad   = pfad
                        root._vollbildBeschr = beschr
                        vollbildPopup.open()
                    }
                    onBildLoeschen: function(bildId) {
                        db.wikiBildLoeschen(bildId)
                        root._bilderLaden(root._aktArtId)
                    }
                }

                // Leerstate: Kein Artikel ausgewählt
                Item {
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    visible:           !root._hatArtikel
                    Text {
                        anchors.centerIn: parent
                        text:     root._hatKategorie
                                  ? qsTr("Artikel in der Liste links auswählen\noder auf + klicken um einen neuen anzulegen.")
                                  : qsTr("Kategorie links auswählen.")
                        color:    root.theme.textMuted
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
    }

    // ── Bild-Einfügen-Popup ───────────────────────────────────
    Popup {
        id:           bildEinfuegenPopup
        anchors.centerIn: parent
        width:        Math.min(root.width * 0.6, 620)
        height:       160
        modal:        true
        padding:      12
        closePolicy:  Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color:        root.theme.surface
            radius:       6
            border.color: root.theme.border
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing:      8

            Text {
                text:           qsTr("Bild wählen – wird an Cursorposition eingefügt:")
                font.pixelSize: 11
                color:          root.theme.textMuted
            }

            Text {
                visible:          root._bilder.length === 0
                Layout.fillWidth: true
                text:             qsTr("Noch keine Bilder – erst in der Galerie unten zum Artikel hinzufügen.")
                font.pixelSize:   11
                color:            root.theme.textMuted
                wrapMode:         Text.Wrap
            }

            ListView {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                orientation:       ListView.Horizontal
                spacing:           8
                clip:              true
                model:             root._bilder
                visible:           root._bilder.length > 0

                delegate: Item {
                    width:  96
                    height: ListView.view.height

                    Rectangle {
                        id:     thumbPickRect
                        width:  88; height: 88; radius: 4
                        color:  root.theme.border
                        clip:   true
                        anchors.horizontalCenter: parent.horizontalCenter

                        Image {
                            anchors.fill: parent
                            source:       modelData.tempPfad ? "file://" + modelData.tempPfad : ""
                            fillMode:     Image.PreserveAspectCrop
                            smooth:       true
                            asynchronous: true
                        }

                        Rectangle {
                            anchors.fill:  parent
                            radius:        4
                            color:         pickHover.hovered ? root.theme.accent + "44" : "transparent"
                            border.color:  pickHover.hovered ? root.theme.accent : "transparent"
                            border.width:  2
                        }
                    }

                    Text {
                        anchors { top: thumbPickRect.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                        width:          88
                        text:           modelData.beschreibung || modelData.dateiname || ""
                        font.pixelSize: 9
                        color:          root.theme.textMuted
                        elide:          Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    HoverHandler { id: pickHover }
                    TapHandler {
                        onTapped: {
                            var descr = modelData.beschreibung || modelData.dateiname || ""
                            formatierungsToolbar._fmtEinfuegen("![" + descr + "](wiki://bild/" + modelData.id + ")")
                            bildEinfuegenPopup.close()
                        }
                    }
                }
            }
        }
    }

    // ── Wiki Export FileDialog ────────────────────────────────
    FileDialog {
        id:           wikiExportDialog
        title:        qsTr("Wiki exportieren")
        fileMode:     FileDialog.SaveFile
        nameFilters:  [qsTr("JSON-Dateien (*.json)"), qsTr("Alle Dateien (*)")]
        onAccepted: {
            const ok = db.wikiExportJson(selectedFile.toString())
            meldungManager.zeigen(ok ? qsTr("Wiki erfolgreich exportiert") : qsTr("Export fehlgeschlagen"), ok)
        }
    }

    // ── Wiki Import FileDialog ────────────────────────────────
    FileDialog {
        id:           wikiImportDialog
        title:        qsTr("Wiki importieren")
        fileMode:     FileDialog.OpenFile
        nameFilters:  [qsTr("JSON-Dateien (*.json)"), qsTr("Alle Dateien (*)")]
        onAccepted: {
            root._importPfad = selectedFile.toString()
            importModePopup.open()
        }
    }

    // ── Import-Modus-Popup ────────────────────────────────────
    Popup {
        id:           importModePopup
        anchors.centerIn: parent
        width:        340
        height:       160
        modal:        true
        padding:      0
        closePolicy:  Popup.CloseOnEscape

        background: Rectangle {
            color:        root.theme.surface
            radius:       6
            border.color: root.theme.border
            border.width: 1
        }

        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 16

            Text {
                Layout.fillWidth: true
                text:           qsTr("Wie soll importiert werden?")
                font.pixelSize: 14
                font.weight:    Font.Medium
                color:          root.theme.textPrimary
                wrapMode:       Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 3
                    color: mergeHover.hovered ? root.theme.accent : root.theme.border
                    Text {
                        anchors.centerIn: parent
                        text:           qsTr("Zusammenführen")
                        font.pixelSize: 11
                        color:          root.theme.textPrimary
                    }
                    HoverHandler { id: mergeHover }
                    TapHandler {
                        onTapped: {
                            importModePopup.close()
                            const ok = db.wikiImportJson(root._importPfad, true)
                            root._kategorienLaden()
                            meldungManager.zeigen(ok ? qsTr("Import erfolgreich") : qsTr("Import fehlgeschlagen"), ok)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 3
                    color: replaceHover.hovered ? "#c0392b" : root.theme.border
                    Text {
                        anchors.centerIn: parent
                        text:           qsTr("Ersetzen")
                        font.pixelSize: 11
                        color:          root.theme.textPrimary
                    }
                    HoverHandler { id: replaceHover }
                    TapHandler {
                        onTapped: {
                            importModePopup.close()
                            const ok = db.wikiImportJson(root._importPfad, false)
                            root._kategorienLaden()
                            root._artIdx     = -1
                            root._aktArtikel = ({})
                            root._bilder     = []
                            meldungManager.zeigen(ok ? qsTr("Import erfolgreich") : qsTr("Import fehlgeschlagen"), ok)
                        }
                    }
                }

                Rectangle {
                    width: 70; height: 32; radius: 3
                    color: abbrImportHover.hovered ? root.theme.hover : "transparent"
                    border.color: root.theme.border
                    Text {
                        anchors.centerIn: parent
                        text:           qsTr("Abbrechen")
                        font.pixelSize: 11
                        color:          root.theme.textMuted
                    }
                    HoverHandler { id: abbrImportHover }
                    TapHandler { onTapped: importModePopup.close() }
                }
            }
        }
    }

    // ── Bild-Import FileDialog ────────────────────────────────
    FileDialog {
        id:          bildFileDialog
        title:       qsTr("Bild auswählen")
        nameFilters: ["Bilder (*.png *.jpg *.jpeg *.bmp *.webp)"]
        onAccepted: {
            var newId = db.wikiBildHinzufuegen(root._aktArtId, selectedFile.toString())
            if (newId > 0) root._bilderLaden(root._aktArtId)
        }
    }

    // ── Vollbild-Popup ────────────────────────────────────────
    // Echtes Vollbild über das gesamte Fenster (Overlay.overlay statt
    // begrenztem Karten-Popup) + Zoom/Pan, damit auch dichte Infografiken
    // (z.B. Charakter-Übersichtsblätter) auf kleinen Bildschirmen lesbar
    // bleiben. Mausrad zoomt, gezogen wird mit der Maus, Doppelklick wechselt
    // zwischen "einpassen" und 2,5×-Zoom.
    Popup {
        id:           vollbildPopup
        parent:       Overlay.overlay
        x:            0
        y:            0
        width:        parent ? parent.width  : 0
        height:       parent ? parent.height : 0
        modal:        true
        closePolicy:  Popup.CloseOnEscape
        padding:      0

        property real _zoom: 1.0

        onOpened: vollbildPopup._zoom = 1.0

        background: Rectangle { color: "#000000" }

        Flickable {
            id:    vollbildFlick
            anchors.fill: parent
            anchors.bottomMargin: 40
            clip:  true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth:  vollbildImg.width  * vollbildPopup._zoom
            contentHeight: vollbildImg.height * vollbildPopup._zoom

            Image {
                id:               vollbildImg
                transformOrigin:  Item.TopLeft
                width:            vollbildFlick.width
                height:           vollbildFlick.height
                scale:            vollbildPopup._zoom
                source:           root._vollbildPfad
                fillMode:         Image.PreserveAspectFit
                smooth:           true
                asynchronous:     true

                TapHandler {
                    onDoubleTapped: vollbildPopup._zoom = (vollbildPopup._zoom > 1.0 ? 1.0 : 2.5)
                }
            }

            WheelHandler {
                onWheel: (event) => {
                    const faktor = event.angleDelta.y > 0 ? 1.2 : (1 / 1.2)
                    vollbildPopup._zoom = Math.max(1.0, Math.min(6.0, vollbildPopup._zoom * faktor))
                }
            }
        }

        // Unterleiste: Beschriftung + Zoom-Hinweis + Schließen-Button
        RowLayout {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
            spacing: 8
            Text {
                Layout.fillWidth: true
                text:           root._vollbildBeschr + qsTr("  ·  Mausrad: Zoom · Ziehen: Verschieben · Doppelklick: Zoom an/aus")
                font.pixelSize: 11
                color:          "#cccccc"
                elide:          Text.ElideRight
            }
            Rectangle {
                width: 70; height: 24; radius: 3
                color: closeHover.hovered ? "#33ffffff" : "transparent"
                border.color: "#666666"
                Text {
                    anchors.centerIn: parent
                    text:           qsTr("✕ Schließen")
                    font.pixelSize: 10
                    color:          "#eeeeee"
                }
                HoverHandler { id: closeHover }
                TapHandler   { onTapped: vollbildPopup.close() }
            }
        }
    }

    DebugLabel { panelName: qsTr("Wiki-Ansicht"); visible: root.debug }

    // ── Bundle-Menü, Import & Export ─────────────────────────
    WikiBundleDialog {
        id: wikiBundle
        theme: root.theme
        kategorien: root._kategorien
        onBundleImportiert: {
            root._kategorienLaden()
            root._artIdx = -1
            root._aktArtikel = ({})
            root._bilder = []
        }
    }
}
