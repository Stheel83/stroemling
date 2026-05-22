import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root

    required property var theme

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

    property string _importPfad: ""
    property string _statusText: ""
    property bool   _statusOk:   true

    function _zeigeStatus(text, ok) {
        _statusText = text
        _statusOk   = (ok !== false)
        statusTimer.restart()
    }

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

    function _editStarten() {
        _editTitel  = _aktArtikel.titel  || ""
        _editInhalt = _aktArtikel.inhalt || ""
        _editTags   = _aktArtikel.tags   || ""
        _editModus  = true
    }

    // ── Toolbar-Hilfsfunktionen ───────────────────────────────
    function _fmtWrap(vor, nach) {
        var sel = inhaltEdit.selectedText
        if (sel.length > 0) {
            var start = inhaltEdit.selectionStart
            var end   = inhaltEdit.selectionEnd
            inhaltEdit.remove(start, end)
            inhaltEdit.insert(start, vor + sel + nach)
            inhaltEdit.select(start + vor.length, start + vor.length + sel.length)
        } else {
            var pos = inhaltEdit.cursorPosition
            inhaltEdit.insert(pos, vor + nach)
            inhaltEdit.cursorPosition = pos + vor.length
        }
        inhaltEdit.forceActiveFocus()
    }

    function _fmtZeile(praefix) {
        var pos   = inhaltEdit.cursorPosition
        var txt   = inhaltEdit.text
        var start = pos
        while (start > 0 && txt[start - 1] !== '\n') start--
        if (txt.substring(start, start + praefix.length) === praefix)
            inhaltEdit.remove(start, start + praefix.length)
        else {
            inhaltEdit.insert(start, praefix)
            inhaltEdit.cursorPosition = pos + praefix.length
        }
        inhaltEdit.forceActiveFocus()
    }

    function _fmtEinfuegen(text) {
        inhaltEdit.insert(inhaltEdit.cursorPosition, text)
        inhaltEdit.forceActiveFocus()
    }

    function _fmtLink() {
        var sel   = inhaltEdit.selectedText
        var ltext = sel.length > 0 ? sel : "Linktext"
        var start = sel.length > 0 ? inhaltEdit.selectionStart : inhaltEdit.cursorPosition
        if (sel.length > 0)
            inhaltEdit.remove(inhaltEdit.selectionStart, inhaltEdit.selectionEnd)
        inhaltEdit.insert(start, "[" + ltext + "](https://)")
        // Cursor direkt hinter "https://" positionieren
        inhaltEdit.cursorPosition = start + ltext.length + 11
        inhaltEdit.forceActiveFocus()
    }

    // Ersetzt wiki://bild/ID durch den aktuellen Temp-Pfad des jeweiligen Bildes
    function _preprocessMarkdown(md) {
        var result = md
        for (var i = 0; i < root._bilder.length; i++) {
            var b = root._bilder[i]
            if (b.tempPfad && b.id)
                result = result.split("wiki://bild/" + b.id).join("file://" + b.tempPfad)
        }
        return result
    }

    function _speichern() {
        if (_aktArtId < 0) return
        db.wikiArtikelSpeichern(_aktArtId, _editTitel.trim(), _editInhalt, _editTags.trim())
        _aktArtikel = db.wikiArtikelLaden(_aktArtId)
        _artikel    = db.wikiArtikelFuerKategorie(_aktKatId)
        _editModus  = false
    }

    function _neueKategorieBestaetigen() {
        const name = _neuKatName.trim()
        if (name === "") { _neuKatModus = false; return }
        const newId = db.wikiKategorieAnlegen(name, "")
        _neuKatModus = false
        _neuKatName  = ""
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
    RowLayout {
        anchors.fill: parent
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
                            color: exportBtnHover.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "↑"
                                font.pixelSize: 12
                                color: root.theme.textMuted
                            }
                            HoverHandler { id: exportBtnHover }
                            TapHandler { onTapped: wikiExportDialog.open() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: importBtnHover.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "↓"
                                font.pixelSize: 12
                                color: root.theme.textMuted
                            }
                            HoverHandler { id: importBtnHover }
                            TapHandler { onTapped: wikiImportDialog.open() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: katAddHover.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            visible: !root._neuKatModus
                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 14
                                color: root.theme.textPrimary
                            }
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
                            color: katOkHover.containsMouse ? root.theme.accent : root.theme.border
                            Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 11; color: root.theme.textPrimary }
                            HoverHandler { id: katOkHover }
                            TapHandler { onTapped: root._neueKategorieBestaetigen() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: katXHover.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: root.theme.textMuted }
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
                                 : (katDelegHover.containsMouse ? root.theme.hover : "transparent")

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
                            color: artAddHover.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            visible: root._hatKategorie && !root._neuArtModus
                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 14
                                color: root.theme.textPrimary
                            }
                            HoverHandler { id: artAddHover }
                            TapHandler { onTapped: { root._neuArtTitel = ""; root._neuArtModus = true } }
                        }
                    }
                }

                // Suchfeld
                Rectangle {
                    Layout.fillWidth: true
                    height:           36
                    color:            root.theme.surface
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.divider
                    }
                    TextField {
                        id: suchFeld
                        anchors { fill: parent; margins: 6 }
                        font.pixelSize: 11
                        color:          root.theme.textPrimary
                        leftPadding:    28
                        background: Rectangle {
                            radius: 3
                            color:  root.theme.inputBg
                            border.color: suchFeld.activeFocus ? root.theme.accent : root.theme.borderLight
                        }
                        placeholderText: qsTr("Suchen …")
                        Text {
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            text:           "🔍"
                            font.pixelSize: 11
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
                            color: artOkHover.containsMouse ? root.theme.accent : root.theme.border
                            Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 11; color: root.theme.textPrimary }
                            HoverHandler { id: artOkHover }
                            TapHandler { onTapped: root._neuerArtikelBestaetigen() }
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: artXHover.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: root.theme.textMuted }
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
                                : (artDelegHover.containsMouse ? root.theme.hover : "transparent")
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

                    Text {
                        anchors.centerIn: parent
                        visible:   artListe.count === 0 && root._hatKategorie
                        text:      qsTr("Noch keine Artikel.\nAuf + klicken um einen anzulegen.")
                        color:     root.theme.textMuted
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
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
                            color:    editBtnHover.containsMouse ? root.theme.accent : root.theme.border
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
                            color:    saveBtnHover.containsMouse ? root.theme.accent : Qt.darker(root.theme.accent, 1.15)
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
                            color:    cancelBtnHover.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
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
                            color:    delBtnHover.containsMouse ? "#c0392b33" : "transparent"
                            border.color: root.theme.border
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

                // Tags-Eingabe (Edit)
                Rectangle {
                    Layout.fillWidth: true
                    height:           visible ? 34 : 0
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
                            height:           26
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
                Rectangle {
                    Layout.fillWidth: true
                    height:           visible ? 36 : 0
                    visible:          root._editModus
                    color:            root.theme.surfaceDeep

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1; color: root.theme.border
                    }

                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 3

                        // ── Inline-Formatierung ───────────────
                        Rectangle {
                            width: 26; height: 24; radius: 3
                            color: tbBMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbBMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Fett (Ctrl+B)"
                            Text { anchors.centerIn: parent; text: "B"; font.bold: true; font.pixelSize: 12; color: root.theme.textPrimary }
                            MouseArea { id: tbBMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtWrap("**", "**") }
                        }
                        Rectangle {
                            width: 26; height: 24; radius: 3
                            color: tbIMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbIMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Kursiv (Ctrl+I)"
                            Text { anchors.centerIn: parent; text: "I"; font.italic: true; font.pixelSize: 12; color: root.theme.textPrimary }
                            MouseArea { id: tbIMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtWrap("*", "*") }
                        }
                        Rectangle {
                            width: 26; height: 24; radius: 3
                            color: tbSMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbSMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Durchgestrichen"
                            Text { anchors.centerIn: parent; text: "S"; font.strikeout: true; font.pixelSize: 12; color: root.theme.textPrimary }
                            MouseArea { id: tbSMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtWrap("~~", "~~") }
                        }
                        Rectangle {
                            width: 26; height: 24; radius: 3
                            color: tbCodeMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbCodeMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Code (inline)"
                            Text { anchors.centerIn: parent; text: "`"; font.family: "monospace"; font.pixelSize: 13; color: root.theme.textPrimary }
                            MouseArea { id: tbCodeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtWrap("`", "`") }
                        }
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbLinkMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbLinkMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Link einfügen"
                            Text { anchors.centerIn: parent; text: "🔗"; font.pixelSize: 11 }
                            MouseArea { id: tbLinkMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtLink() }
                        }

                        // Separator
                        Rectangle { width: 1; height: 20; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }

                        // ── Überschriften ─────────────────────
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbH1Mouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbH1Mouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Überschrift 1"
                            Text { anchors.centerIn: parent; text: "H1"; font.bold: true; font.pixelSize: 10; color: root.theme.textPrimary }
                            MouseArea { id: tbH1Mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("# ") }
                        }
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbH2Mouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbH2Mouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Überschrift 2"
                            Text { anchors.centerIn: parent; text: "H2"; font.bold: true; font.pixelSize: 10; color: root.theme.textPrimary }
                            MouseArea { id: tbH2Mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("## ") }
                        }
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbH3Mouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbH3Mouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Überschrift 3"
                            Text { anchors.centerIn: parent; text: "H3"; font.bold: true; font.pixelSize: 10; color: root.theme.textPrimary }
                            MouseArea { id: tbH3Mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("### ") }
                        }

                        // Separator
                        Rectangle { width: 1; height: 20; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }

                        // ── Listen & Struktur ─────────────────
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbUlMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbUlMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Aufzählungsliste"
                            Text { anchors.centerIn: parent; text: "• —"; font.pixelSize: 10; color: root.theme.textPrimary }
                            MouseArea { id: tbUlMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("- ") }
                        }
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbOlMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbOlMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Nummerierte Liste"
                            Text { anchors.centerIn: parent; text: "1."; font.pixelSize: 10; color: root.theme.textPrimary }
                            MouseArea { id: tbOlMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("1. ") }
                        }
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbQMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbQMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Zitat"
                            Text { anchors.centerIn: parent; text: "❝"; font.pixelSize: 12; color: root.theme.textPrimary }
                            MouseArea { id: tbQMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtZeile("> ") }
                        }

                        // Separator
                        Rectangle { width: 1; height: 20; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }

                        // ── Trennlinie ────────────────────────
                        Rectangle {
                            width: 36; height: 24; radius: 3
                            color: tbHrMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbHrMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Trennlinie"
                            Text { anchors.centerIn: parent; text: "───"; font.pixelSize: 10; color: root.theme.textPrimary }
                            MouseArea { id: tbHrMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtEinfuegen("\n\n---\n\n") }
                        }
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbBrMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbBrMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Zeilenumbruch (innerhalb Absatz)"
                            Text { anchors.centerIn: parent; text: "↵"; font.pixelSize: 13; color: root.theme.textPrimary }
                            MouseArea { id: tbBrMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root._fmtEinfuegen("\\\n") }
                        }

                        // Separator
                        Rectangle { width: 1; height: 20; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }

                        // ── Bild einfügen ─────────────────────
                        Rectangle {
                            width: 28; height: 24; radius: 3
                            color: tbImgMouse.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            ToolTip.visible: tbImgMouse.containsMouse; ToolTip.delay: 700; ToolTip.text: "Bild in Text einfügen"
                            Text { anchors.centerIn: parent; text: "🖼"; font.pixelSize: 12 }
                            MouseArea { id: tbImgMouse; anchors.fill: parent; hoverEnabled: true; onClicked: bildEinfuegenPopup.open() }
                        }
                    }
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
                                else if (e.key === Qt.Key_B) { root._fmtWrap("**", "**");       e.accepted = true }
                                else if (e.key === Qt.Key_I) { root._fmtWrap("*", "*");         e.accepted = true }
                            }
                        }
                    }
                }

                // ── Bildgalerie ───────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height:           visible ? 116 : 0
                    visible:          root._hatArtikel
                    color:            root.theme.surfaceDeep
                    clip:             true

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width; height: 1; color: root.theme.border
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Galerie-Header
                        RowLayout {
                            Layout.fillWidth: true
                            height: 28
                            Layout.leftMargin:  16
                            Layout.rightMargin: 8

                            Text {
                                text: root._bilder.length > 0
                                      ? "📷 " + qsTr("Bilder (%1)").arg(root._bilder.length)
                                      : "📷 " + qsTr("Bilder")
                                font.pixelSize: 10
                                color:          root.theme.textMuted
                                Layout.fillWidth: true
                            }
                            Rectangle {
                                width: 110; height: 20; radius: 3
                                color: addBildHover.containsMouse ? root.theme.accent : root.theme.border
                                Text {
                                    anchors.centerIn: parent
                                    text:           qsTr("+ Bild hinzufügen")
                                    font.pixelSize: 10
                                    color:          root.theme.textPrimary
                                }
                                HoverHandler { id: addBildHover }
                                TapHandler   { onTapped: bildFileDialog.open() }
                            }
                        }

                        // Thumbnail-Reihe
                        ListView {
                            id:               thumbListe
                            Layout.fillWidth: true
                            height:           84
                            Layout.leftMargin: 8
                            orientation:      ListView.Horizontal
                            spacing:          6
                            clip:             true
                            model:            root._bilder

                            delegate: Rectangle {
                                width:  80
                                height: 80
                                radius: 4
                                color:  root.theme.border
                                clip:   true

                                Image {
                                    anchors.fill: parent
                                    source:       modelData.tempPfad ? "file://" + modelData.tempPfad : ""
                                    fillMode:     Image.PreserveAspectCrop
                                    smooth:       true
                                    asynchronous: true
                                }

                                // Löschen-Button oben rechts (bei Hover)
                                Rectangle {
                                    anchors { top: parent.top; right: parent.right; margins: 3 }
                                    width: 18; height: 18; radius: 9
                                    color:   thumbHover.containsMouse ? "#cc000000" : "#88000000"
                                    visible: thumbHover.containsMouse || delThumbHover.containsMouse
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        font.pixelSize: 9
                                        color: "white"
                                    }
                                    HoverHandler { id: delThumbHover }
                                    TapHandler {
                                        onTapped: {
                                            db.wikiBildLoeschen(modelData.id)
                                            root._bilderLaden(root._aktArtId)
                                        }
                                    }
                                }

                                // Vollbild per Klick (nur wenn kein Löschen-Hover)
                                HoverHandler { id: thumbHover }
                                TapHandler {
                                    onTapped: {
                                        root._vollbildPfad   = modelData.tempPfad ? "file://" + modelData.tempPfad : ""
                                        root._vollbildBeschr = modelData.beschreibung || modelData.dateiname
                                        vollbildPopup.open()
                                    }
                                }
                            }

                            // Platzhalter wenn noch keine Bilder
                            Text {
                                anchors.centerIn: parent
                                visible:   thumbListe.count === 0
                                text:      qsTr("Noch keine Bilder")
                                color:     root.theme.textMuted
                                font.pixelSize: 10
                            }
                        }
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
                            color:         pickHover.containsMouse ? root.theme.accent + "44" : "transparent"
                            border.color:  pickHover.containsMouse ? root.theme.accent : "transparent"
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
                            root._fmtEinfuegen("![" + descr + "](wiki://bild/" + modelData.id + ")")
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
            root._zeigeStatus(ok ? qsTr("Wiki erfolgreich exportiert") : qsTr("Export fehlgeschlagen"), ok)
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
                    color: mergeHover.containsMouse ? root.theme.accent : root.theme.border
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
                            root._zeigeStatus(ok ? qsTr("Import erfolgreich") : qsTr("Import fehlgeschlagen"), ok)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 3
                    color: replaceHover.containsMouse ? "#c0392b" : root.theme.border
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
                            root._zeigeStatus(ok ? qsTr("Import erfolgreich") : qsTr("Import fehlgeschlagen"), ok)
                        }
                    }
                }

                Rectangle {
                    width: 70; height: 32; radius: 3
                    color: abbrImportHover.containsMouse ? root.theme.hover : "transparent"
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

    // ── Status-Toast ──────────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 20 }
        width:   statusToastLabel.implicitWidth + 32
        height:  36
        radius:  6
        color:   root._statusOk ? "#27ae60" : "#c0392b"
        visible: root._statusText !== ""

        Text {
            id:             statusToastLabel
            anchors.centerIn: parent
            text:           root._statusText
            font.pixelSize: 13
            color:          "white"
        }
    }

    Timer {
        id:       statusTimer
        interval: 3000
        onTriggered: root._statusText = ""
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
    Popup {
        id:           vollbildPopup
        anchors.centerIn: parent
        width:        Math.min(root.width  * 0.88, 1200)
        height:       Math.min(root.height * 0.88, 900)
        modal:        true
        closePolicy:  Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding:      0

        background: Rectangle {
            color:        root.theme.surface
            radius:       6
            border.color: root.theme.border
            border.width: 1
        }

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 12
            spacing:         8

            // Bild
            Image {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                source:            root._vollbildPfad
                fillMode:          Image.PreserveAspectFit
                smooth:            true
                asynchronous:      true
            }

            // Beschriftung + Schließen-Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text:           root._vollbildBeschr
                    font.pixelSize: 11
                    color:          root.theme.textMuted
                    elide:          Text.ElideRight
                }
                Rectangle {
                    width: 70; height: 24; radius: 3
                    color: closeHover.containsMouse ? root.theme.hover : "transparent"
                    border.color: root.theme.border
                    Text {
                        anchors.centerIn: parent
                        text:           qsTr("✕ Schließen")
                        font.pixelSize: 10
                        color:          root.theme.textMuted
                    }
                    HoverHandler { id: closeHover }
                    TapHandler   { onTapped: vollbildPopup.close() }
                }
            }
        }
    }
}
