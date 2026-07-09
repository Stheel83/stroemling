import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "nb"
import "components"

Item {
    id: root

    required property var theme
    property bool debug: false

    signal gespeichert(int vorlageId)

    // ── Interner State ────────────────────────────────────────
    property var  _vorlagen:   []
    property int  _vorlIdx:    -1
    property var  _felder:     []
    property int  _selIdx:     -1
    property bool _neuModus:   false
    property string _neuName:  ""

    readonly property var _vorlage: (_vorlIdx >= 0 && _vorlIdx < _vorlagen.length)
                                    ? _vorlagen[_vorlIdx] : null

    // ── Lifecycle ─────────────────────────────────────────────
    onVisibleChanged: if (visible) _laden()

    function _laden() {
        _neuModus = false
        _vorlagen = db.normblattVorlagenListe()
        _vorlIdx  = _vorlagen.length > 0 ? 0 : -1
        _felderLaden()
    }

    function _felderLaden() {
        _selIdx = -1
        _felder = _vorlage ? db.normblattFelderLaden(_vorlage.id) : []
    }

    // ── Feld-Operationen ──────────────────────────────────────
    function _feldHinzufuegen(feldtyp) {
        if (!_vorlage) return
        var f = {
            feldtyp:       feldtyp,
            xMm:           Math.round((_vorlage.breiteMm || 297) / 2 - 25),
            yMm:           Math.round((_vorlage.hoeheMm  || 210) / 2 - 6),
            breiteMm:      50, hoeheMm: 13,
            label:         _defaultLabel(feldtyp),
            inhalt:        "",
            quelleSpalte:  _defaultQuelle(feldtyp),
            schriftgroesse: 3.5, fett: 0, rahmen: 1,
            reihenfolge:   _felder.length
        }
        var neu = _felder.slice(); neu.push(f); _felder = neu
        _selIdx = neu.length - 1
    }

    function _feldVerschieben(idx, xMm, yMm) {
        var f = _feldKopie(idx); if (!f) return
        f.xMm = xMm; f.yMm = yMm
        var neu = _felder.slice(); neu[idx] = f; _felder = neu
    }

    function _feldGroesse(idx, bMm, hMm) {
        var f = _feldKopie(idx); if (!f) return
        f.breiteMm = bMm; f.hoeheMm = hMm
        var neu = _felder.slice(); neu[idx] = f; _felder = neu
    }

    function _feldAktualisieren(idx, feld) {
        if (idx < 0 || idx >= _felder.length) return
        var neu = _felder.slice(); neu[idx] = feld; _felder = neu
    }

    function _feldLoeschen(idx) {
        if (idx < 0 || idx >= _felder.length) return
        var neu = _felder.slice(); neu.splice(idx, 1); _felder = neu
        _selIdx = -1
    }

    function _feldKopie(idx) {
        if (idx < 0 || idx >= _felder.length) return null
        var f = _felder[idx]
        return {
            feldtyp: f.feldtyp, label: f.label, inhalt: f.inhalt,
            quelleSpalte: f.quelleSpalte, xMm: f.xMm, yMm: f.yMm,
            breiteMm: f.breiteMm, hoeheMm: f.hoeheMm,
            schriftgroesse: f.schriftgroesse, fett: f.fett,
            rahmen: f.rahmen, reihenfolge: f.reihenfolge
        }
    }

    function _defaultLabel(typ) {
        var m = { "fest":"TEXT","projekt":"PROJEKT","seite":"SEITE",
                  "datum":"DATUM","vollkennzeichen":"KENNZEICHEN","format":"FORMAT","logo":"LOGO" }
        return m[typ] || typ.toUpperCase()
    }
    function _defaultQuelle(typ) {
        if (typ === "projekt") return "name"
        if (typ === "seite")   return "blattnummer"
        return ""
    }

    // ── Vorlage-Verwaltung ────────────────────────────────────
    function _vorlageNeuErstellen() {
        var name = _neuName.trim()
        if (!name) return
        var id = db.normblattVorlageSpeichern({
            name: name, breiteMm: 297, hoeheMm: 210,
            randLinksMm: 20, randRechtsMm: 10,
            randObenMm: 10,  randUntenMm: 10
        })
        _neuModus = false
        _vorlagen = db.normblattVorlagenListe()
        for (var i = 0; i < _vorlagen.length; i++) {
            if (_vorlagen[i].id === id) { _vorlIdx = i; break }
        }
        _felderLaden()
    }

    // Dupliziert die aktuell angezeigte Vorlage inkl. aller Felder (auch
    // noch nicht gespeicherter lokaler Änderungen — "Kopieren" dupliziert
    // bewusst den Stand, den der Nutzer gerade vor sich hat, nicht den
    // zuletzt gespeicherten DB-Stand).
    function _vorlageKopieren() {
        if (!_vorlage) return
        var neuId = db.normblattVorlageSpeichern({
            name:         _vorlage.name + qsTr(" (Kopie)"),
            beschreibung: _vorlage.beschreibung,
            breiteMm:     _vorlage.breiteMm,     hoeheMm:      _vorlage.hoeheMm,
            randLinksMm:  _vorlage.randLinksMm,  randRechtsMm: _vorlage.randRechtsMm,
            randObenMm:   _vorlage.randObenMm,   randUntenMm:  _vorlage.randUntenMm
        })
        if (neuId > 0 && _felder.length > 0)
            db.normblattFelderSpeichern(neuId, _felder)
        _vorlagen = db.normblattVorlagenListe()
        for (var i = 0; i < _vorlagen.length; i++) {
            if (_vorlagen[i].id === neuId) { _vorlIdx = i; break }
        }
        _felderLaden()
    }

    function _vorlageLoeschen() {
        if (!_vorlage) return
        db.normblattVorlageLoeschen(_vorlage.id)
        _laden()
    }

    // ── Speichern ─────────────────────────────────────────────
    function _speichern() {
        if (!_vorlage) return
        db.normblattFelderSpeichern(_vorlage.id, _felder)
        root.gespeichert(_vorlage.id)
    }

    // ── Background ────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.theme ? root.theme.sidebar : "#0d1b2a"
    }

    // ── Header ────────────────────────────────────────────────
    Rectangle {
        id: headerBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        color: root.theme.sidebar; height: 54

        RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 8

            Text {
                text: qsTr("Titelblatt-Vorlagen")
                color: root.theme.textPrimary; font.pixelSize: 15; font.weight: Font.Medium
            }
            Item { width: 8 }

            // ── Neu-Modus ─────────────────────────────────────
            TextField {
                id: tfNeu
                visible: root._neuModus
                Layout.preferredWidth: 200; Layout.preferredHeight: 32
                text: root._neuName; onTextChanged: root._neuName = text
                placeholderText: qsTr("Vorlagenname …")
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.accent; radius: 4 }
                color: root.theme.textPrimary; font.pixelSize: 13
                Keys.onReturnPressed:  root._vorlageNeuErstellen()
                Keys.onEscapePressed:  root._neuModus = false
                onVisibleChanged: if (visible) { root._neuName = qsTr("Neue Vorlage"); forceActiveFocus() }
            }
            Rectangle {
                visible: root._neuModus; width: 80; height: 32; radius: 5
                color: erstellenMA.containsMouse ? root.theme.accent : Qt.darker(root.theme.accent, 1.3)
                opacity: root._neuName.trim() ? 1.0 : 0.5
                Text { anchors.centerIn: parent; text: qsTr("Erstellen"); color: "white"; font.pixelSize: 12; font.weight: Font.Medium }
                MouseArea { id: erstellenMA; anchors.fill: parent; hoverEnabled: true
                    enabled: root._neuName.trim() !== ""; onClicked: root._vorlageNeuErstellen() }
            }
            Rectangle {
                visible: root._neuModus; width: 80; height: 32; radius: 5
                color: neuAbbrMA.containsMouse ? root.theme.hover : root.theme.inputBg
                border.color: root.theme.border; border.width: 1
                Text { anchors.centerIn: parent; text: qsTr("Abbrechen"); color: root.theme.textPrimary; font.pixelSize: 12 }
                MouseArea { id: neuAbbrMA; anchors.fill: parent; hoverEnabled: true; onClicked: root._neuModus = false }
            }

            // ── Normal-Modus ──────────────────────────────────
            ComboBox {
                id: cmbVorlage
                visible: !root._neuModus
                Layout.preferredWidth: 220; Layout.preferredHeight: 32
                model: root._vorlagen.map(function(v) { return v.name })
                currentIndex: root._vorlIdx
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text {
                    leftPadding: 8; text: cmbVorlage.displayText
                    color: root.theme.textPrimary; font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                }
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: cmbVorlage.width; implicitHeight: 32
                    highlighted: cmbVorlage.highlightedIndex === index
                    contentItem: Text {
                        leftPadding: 8; text: modelData
                        color: root.theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                }
                onActivated: function(i) { root._vorlIdx = i; root._felderLaden() }
            }
            Rectangle {
                visible: !root._neuModus; width: 32; height: 32; radius: 5
                color: neuBtnMA.containsMouse ? root.theme.hover : root.theme.inputBg
                border.color: root.theme.border; border.width: 1
                Text { anchors.centerIn: parent; text: "+"; color: root.theme.textPrimary; font.pixelSize: 20; font.weight: Font.Light }
                MouseArea { id: neuBtnMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root._neuModus = true }
                ToolTip.visible: neuBtnMA.containsMouse; ToolTip.text: qsTr("Neue Vorlage anlegen"); ToolTip.delay: 600
            }
            Rectangle {
                visible: !root._neuModus && root._vorlage !== null; width: 32; height: 32; radius: 5
                color: kopBtnMA.containsMouse ? root.theme.hover : root.theme.inputBg
                border.color: root.theme.border; border.width: 1
                Text { anchors.centerIn: parent; text: "⧉"; color: root.theme.textPrimary; font.pixelSize: 15 }
                MouseArea { id: kopBtnMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root._vorlageKopieren() }
                ToolTip.visible: kopBtnMA.containsMouse; ToolTip.text: qsTr("Vorlage duplizieren"); ToolTip.delay: 600
            }
            Rectangle {
                visible: !root._neuModus && root._vorlage !== null; width: 32; height: 32; radius: 5
                color: delVorlMA.containsMouse ? "#602020" : root.theme.inputBg
                border.color: delVorlMA.containsMouse ? "#a03030" : root.theme.border; border.width: 1
                Text { anchors.centerIn: parent; text: "✕"
                    color: delVorlMA.containsMouse ? "#f0a0a0" : root.theme.textMuted; font.pixelSize: 13 }
                MouseArea { id: delVorlMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root._vorlageLoeschen() }
                ToolTip.visible: delVorlMA.containsMouse; ToolTip.text: qsTr("Vorlage löschen"); ToolTip.delay: 600
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: root._vorlage !== null
                text: qsTr("%1 × %2 mm")
                    .arg(root._vorlage ? Math.round(root._vorlage.breiteMm || 297) : 297)
                    .arg(root._vorlage ? Math.round(root._vorlage.hoeheMm  || 210) : 210)
                color: root.theme.textMuted; font.pixelSize: 11
            }
        }

        Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1; color: root.theme.divider }
    }

    // ── Hauptbereich (3 Spalten) ──────────────────────────────
    RowLayout {
        anchors { top: headerBar.bottom; bottom: footerBar.top; left: parent.left; right: parent.right }
        spacing: 0

        // Palette (links)
        Rectangle {
            Layout.preferredWidth: 165; Layout.fillHeight: true
            color: Qt.darker(root.theme.sidebar, 1.06); clip: true

            NormblattFeldPalette {
                anchors.fill: parent; theme: root.theme
                enabled: root._vorlage !== null
                opacity: enabled ? 1.0 : 0.4
                onFeldtypGewaehlt: function(typ) { root._feldHinzufuegen(typ) }
            }

            Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                        width: 1; color: root.theme.divider }
        }

        // Editor-Canvas (Mitte)
        NormblattEditorCanvas {
            id: editorCanvas
            Layout.fillWidth: true; Layout.fillHeight: true
            theme:        root.theme
            felder:       root._felder
            hatVorlage:   root._vorlage !== null
            selIdx:       root._selIdx
            breiteMm:     root._vorlage ? (root._vorlage.breiteMm || 297) : 297
            hoeheMm:      root._vorlage ? (root._vorlage.hoeheMm  || 210) : 210
            randLinksMm:  root._vorlage ? (root._vorlage.randLinksMm  || 20) : 20
            randRechtsMm: root._vorlage ? (root._vorlage.randRechtsMm || 10) : 10
            randObenMm:   root._vorlage ? (root._vorlage.randObenMm   || 10) : 10
            randUntenMm:  root._vorlage ? (root._vorlage.randUntenMm  || 10) : 10

            onFeldAngewaehlt:          function(idx)       { root._selIdx = idx }
            onHintergrundGeklickt:                         { root._selIdx = -1  }
            onFeldVerschoben:          function(idx, x, y) { root._feldVerschieben(idx, x, y) }
            onFeldGroesseGeaendert:    function(idx, b, h) { root._feldGroesse(idx, b, h) }
            onFeldLoeschenAngefordert: function(idx)       { root._feldLoeschen(idx) }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.divider }

        // Eigenschaften (rechts)
        NormblattFeldProperties {
            Layout.preferredWidth: 205; Layout.fillHeight: true
            theme:   root.theme
            feldIdx: root._selIdx
            feld:    (root._selIdx >= 0 && root._selIdx < root._felder.length)
                     ? root._felder[root._selIdx] : null
            onFeldGeaendert:  function(idx, f) { root._feldAktualisieren(idx, f) }
            onFeldLoeschen:   function(idx)    { root._feldLoeschen(idx) }
        }
    }

    // ── Footer ────────────────────────────────────────────────
    Rectangle {
        id: footerBar
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        color: root.theme.sidebar; height: 52

        Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 1; color: root.theme.divider }

        RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 8

            Text {
                visible: root._felder.length > 0
                text: qsTr("%1 Felder").arg(root._felder.length)
                color: root.theme.textMuted; font.pixelSize: 11
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 100; height: 36; radius: 6
                enabled: root._vorlage !== null; opacity: enabled ? 1.0 : 0.45
                color: speichernMA.containsMouse ? root.theme.accent : Qt.darker(root.theme.accent, 1.3)
                Text { anchors.centerIn: parent; text: qsTr("Speichern")
                    color: "white"; font.pixelSize: 13; font.weight: Font.Medium }
                MouseArea { id: speichernMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: root._speichern() }
                ToolTip.visible: speichernMA.containsMouse; ToolTip.delay: 600
                ToolTip.text: qsTr("Normblatt-Vorlage speichern")
            }
        }
    }

    DebugLabel { panelName: qsTr("Normblatt-Editor"); visible: root.debug }
}
