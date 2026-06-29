import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "components"

// ============================================================
// SeitenBaum.qml
// Zeigt den Seitenbaum für das aktive Projekt:
//   Anlage (=EG) → Ort (+A1) → Seite (001 Stromversorgung)
// ============================================================

Item {
    id: root

    property var    theme
    property bool   debug:       false
    property int    projektId:   -1
    property string projektName: ""
    property int    aktivSeiteId: -1   // von außen gesetzt; -1 = keine Seite aktiv

    property int  _dragSeiteId:   -1
    property string _aktiveTab:     "seiten"   // "seiten" | "struktur" | "bauteile"

    Settings {
        id: seitenBaumSettings
        category: "seitenbaum"
    }

    // Wird ausgelöst wenn der Benutzer eine Seite anklickt
    signal seiteGewaehlt(int id, string blattnummer, string bezeichnung)

    // Rechtsklick → „Als Tab öffnen" (zusätzlicher Tab)
    signal seiteAlsTabOeffnen(int id, string blattnummer, string bezeichnung)

    // Wird ausgelöst nachdem eine Seite erfolgreich gelöscht wurde
    signal seiteGeloescht(int id)

    // Wird ausgelöst wenn das Seitenformat geändert wurde (Normblatt-Refresh)
    signal seiteFormatGeaendert(int seiteId)

    // Wird ausgelöst wenn ein Klemmen-Anschluss zum Platzieren gewählt wurde (Modus A)
    signal klemmenAnschlussPlatzieren(int klemmeId, int bauteilKlemmeId,
                                      string anschlussBezeichnung, string bmk)
    signal klemmenSequentiellStarten(string queueJson)
    signal betriebsmittelKontaktPlatzieren(int betriebsmittelId, string symbolId, string bmk, var pinBez)
    signal bauteilPlatzieren(int bauteilId, string symbolId, string bezeichnung)
    // Sprungfunktion: navigiere zu einem Element auf einer Seite
    signal sprungAngefordert(int seiteId, string blattnr, string seiteBez,
                             real weltX, real weltY)

    // Vom Canvas-Kontextmenü: Sprung zum Klemmenanschluss im Bauteilbereich.
    function navigiereZuKlemme(klemmeId, anschlussBezeichnung) {
        _aktiveTab = "bauteile"
        Qt.callLater(function() { bauteilePanel.navigiereZuKlemme(klemmeId, anschlussBezeichnung) })
    }

    function navigiereZuKabel(kabelId) {
        _aktiveTab = "bauteile"
        Qt.callLater(function() { bauteilePanel.navigiereZuKabel(kabelId) })
    }

    function navigiereZuGeraetekasten(gkId, gkBmk) {
        _aktiveTab = "bauteile"
        Qt.callLater(function() { bauteilePanel.navigiereZuGeraetekasten(gkId, gkBmk) })
    }

    // Hilfsfunktion: Listenindex für bekannte DIN-Formate ermitteln
    function formatIndex(b, h) {
        var fmts = [
            {breite:297, hoehe:210}, {breite:210, hoehe:297},
            {breite:420, hoehe:297}, {breite:297, hoehe:420},
            {breite:594, hoehe:420}, {breite:420, hoehe:594}
        ]
        for (var i = 0; i < fmts.length; i++)
            if (Math.abs(fmts[i].breite - b) < 1 && Math.abs(fmts[i].hoehe - h) < 1) return i
        return 0
    }

    onProjektIdChanged: {
        if (projektId >= 0)
            seitenModel.laden(projektId)
        bauteilePanel.reset()
    }

    // --------------------------------------------------------
    // Wiederverwendbare Button-Leiste (unten im Dialog)
    // --------------------------------------------------------
    component DialogButtons: RowLayout {
        property string confirmText:    "OK"
        property bool   confirmEnabled: true
        property var    onConfirm:      null
        property var    onCancel:       null

        Layout.fillWidth: true
        spacing: 8

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.columnSpan: 1 }

        // Abbrechen
        Button {
            text: qsTr("Abbrechen")
            flat: true
            implicitHeight: 32
            contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                 horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
            onClicked: if (onCancel) onCancel()
        }
        // Bestätigen
        Button {
            text: confirmText
            enabled: confirmEnabled
            implicitWidth: 90
            implicitHeight: 32
            contentItem: Text { text: parent.text; color: parent.enabled ? theme.textPrimary : theme.textMuted; font.pixelSize: 13;
                                 horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle {
                color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                radius: 4
                border.color: parent.enabled ? theme.accent : theme.border
            }
            onClicked: if (onConfirm) onConfirm()
        }
    }

    // --------------------------------------------------------
    // Dialog – Seite löschen (mit Bestätigung)
    // --------------------------------------------------------
    Dialog {
        id: dlgSeiteLoeschen
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 380
        padding: 20

        property int loeschSeiteId:       -1
        property int loeschElementeAnzahl: 0

        background: Rectangle { color: theme.sidebar; border.color: "#5a2020"; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 12

            Text {
                text: qsTr("Seite löschen")
                font.pixelSize: 15; font.weight: Font.Medium; color: "#ffcccc"
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: "#3a1a1a" }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 13
                color: dlgSeiteLoeschen.loeschElementeAnzahl > 0 ? "#ffaa44" : theme.textSecondary
                text: dlgSeiteLoeschen.loeschElementeAnzahl > 0
                    ? "Diese Seite enthält " + dlgSeiteLoeschen.loeschElementeAnzahl
                      + " Element(e).\n\nSeite und alle Elemente werden unwiderruflich gelöscht."
                    : "Diese leere Seite löschen?"
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#3a1a1a"; Layout.topMargin: 4 }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                         horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgSeiteLoeschen.close()
                }
                Button {
                    text: qsTr("Löschen"); implicitWidth: 90; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: "#ffe0e0"; font.pixelSize: 13;
                                         horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? "#6a1a1a" : "#3a1010"; radius: 4 }
                    onClicked: {
                        var id = dlgSeiteLoeschen.loeschSeiteId
                        seitenModel.loeschen(2, id)
                        root.seiteGeloescht(id)
                        dlgSeiteLoeschen.close()
                    }
                }
            }
        }
    }

    // --------------------------------------------------------
    // Dialoge – Anlegen
    // --------------------------------------------------------

    Dialog {
        id: dlgAnlage
        title: qsTr("Neue Anlage")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 20

        property int  fuerProjektId:    -1
        property var  _cache:           []   // [{kuerzel, bezeichnung}] aller vorhandenen Anlagen
        property bool _duplikat:        false

        onOpened: {
            inpAnlageKuerzel.text = ""; inpAnlageBez.text = ""; inpAnlageUO.text = ""
            anlageVorschlaegeModel.clear(); _duplikat = false
            var list = seitenModel.strukturListe()
            _cache = []
            for (var i = 0; i < list.length; i++)
                _cache.push({ kuerzel: list[i].anlageKuerzel, bezeichnung: list[i].anlageBez })
        }

        ListModel { id: anlageVorschlaegeModel }

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Kürzel (z.B. EG, OG, KG)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpAnlageKuerzel; Layout.fillWidth: true; placeholderText: "EG"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
                onTextChanged: {
                    var t = text.trim().toUpperCase()
                    anlageVorschlaegeModel.clear(); dlgAnlage._duplikat = false
                    if (t.length === 0) return
                    for (var i = 0; i < dlgAnlage._cache.length; i++) {
                        var kz = dlgAnlage._cache[i].kuerzel.toUpperCase()
                        if (kz.startsWith(t)) {
                            anlageVorschlaegeModel.append(dlgAnlage._cache[i])
                            if (kz === t) dlgAnlage._duplikat = true
                        }
                    }
                }
                onActiveFocusChanged: {
                    if (!activeFocus) Qt.callLater(() => { anlageVorschlaegeModel.clear() })
                }
            }
            // Vorschlagsliste
            Rectangle {
                Layout.fillWidth: true; Layout.topMargin: -6
                height: Math.min(anlageVorschlaegeModel.count * 30, 90)
                visible: anlageVorschlaegeModel.count > 0
                color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4; clip: true; z: 10
                ListView {
                    anchors.fill: parent; clip: true
                    model: anlageVorschlaegeModel
                    delegate: ItemDelegate {
                        width: parent.width; height: 30
                        background: Rectangle { color: parent.hovered ? theme.hover : "transparent" }
                        contentItem: Text {
                            text: model.kuerzel + "   " + model.bezeichnung
                            color: theme.textPrimary; font.pixelSize: 12; font.family: "monospace"
                            verticalAlignment: Text.AlignVCenter; leftPadding: 6
                        }
                        onClicked: {
                            inpAnlageKuerzel.text = model.kuerzel
                            inpAnlageBez.text = model.bezeichnung
                            anlageVorschlaegeModel.clear()
                        }
                    }
                }
            }
            // Duplikat-Warnung
            Text {
                visible: dlgAnlage._duplikat
                text: "⚠ " + qsTr("Kürzel bereits vorhanden")
                color: "#cc6600"; font.pixelSize: 11; Layout.topMargin: -4
            }
            Text { text: qsTr("Bezeichnung (z.B. Erdgeschoss)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpAnlageBez; Layout.fillWidth: true; placeholderText: qsTr("Erdgeschoss")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Übergeordnete Anlage == (optional, z.B. Werk1)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpAnlageUO; Layout.fillWidth: true; placeholderText: qsTr("Werk1")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgAnlage.close()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                    enabled: inpAnlageKuerzel.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        seitenModel.anlageAnlegen(dlgAnlage.fuerProjektId,
                            inpAnlageKuerzel.text.trim(), inpAnlageBez.text.trim(), inpAnlageUO.text.trim())
                        inpAnlageKuerzel.text = ""; inpAnlageBez.text = ""; inpAnlageUO.text = ""
                        dlgAnlage.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: dlgOrt
        title: qsTr("Neuer Ort")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 20

        property int  fuerAnlageId: -1
        property var  _cache:       []   // [{kuerzel, bezeichnung}] aller vorhandenen Orte
        property bool _duplikat:    false

        onOpened: {
            inpOrtKuerzel.text = ""; inpOrtBez.text = ""; inpOrtUO.text = ""
            ortVorschlaegeModel.clear(); _duplikat = false
            var list = seitenModel.strukturListe()
            _cache = []
            for (var i = 0; i < list.length; i++) {
                var orte = list[i].orte
                for (var j = 0; j < orte.length; j++)
                    _cache.push({ kuerzel: orte[j].ortKuerzel, bezeichnung: orte[j].ortBez,
                                  anlageId: list[i].anlageId })
            }
        }

        ListModel { id: ortVorschlaegeModel }

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Kürzel (z.B. A1, B2)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpOrtKuerzel; Layout.fillWidth: true; placeholderText: "A1"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
                onTextChanged: {
                    var t = text.trim().toUpperCase()
                    ortVorschlaegeModel.clear(); dlgOrt._duplikat = false
                    if (t.length === 0) return
                    for (var i = 0; i < dlgOrt._cache.length; i++) {
                        var kz = dlgOrt._cache[i].kuerzel.toUpperCase()
                        if (kz.startsWith(t)) {
                            ortVorschlaegeModel.append(dlgOrt._cache[i])
                            if (kz === t && dlgOrt._cache[i].anlageId === dlgOrt.fuerAnlageId)
                                dlgOrt._duplikat = true
                        }
                    }
                }
                onActiveFocusChanged: {
                    if (!activeFocus) Qt.callLater(() => { ortVorschlaegeModel.clear() })
                }
            }
            // Vorschlagsliste
            Rectangle {
                Layout.fillWidth: true; Layout.topMargin: -6
                height: Math.min(ortVorschlaegeModel.count * 30, 90)
                visible: ortVorschlaegeModel.count > 0
                color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4; clip: true; z: 10
                ListView {
                    anchors.fill: parent; clip: true
                    model: ortVorschlaegeModel
                    delegate: ItemDelegate {
                        width: parent.width; height: 30
                        background: Rectangle { color: parent.hovered ? theme.hover : "transparent" }
                        contentItem: Text {
                            text: model.kuerzel + "   " + model.bezeichnung
                            color: theme.textPrimary; font.pixelSize: 12; font.family: "monospace"
                            verticalAlignment: Text.AlignVCenter; leftPadding: 6
                        }
                        onClicked: {
                            inpOrtKuerzel.text = model.kuerzel
                            inpOrtBez.text = model.bezeichnung
                            ortVorschlaegeModel.clear()
                        }
                    }
                }
            }
            // Duplikat-Warnung (nur wenn Kürzel in dieser Anlage schon existiert)
            Text {
                visible: dlgOrt._duplikat
                text: "⚠ " + qsTr("Kürzel in dieser Anlage bereits vorhanden")
                color: "#cc6600"; font.pixelSize: 11; Layout.topMargin: -4
            }
            Text { text: qsTr("Bezeichnung (z.B. Hauptverteiler)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpOrtBez; Layout.fillWidth: true; placeholderText: qsTr("Hauptverteiler")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Übergeordneter Ort ++ (optional, z.B. Halle2)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpOrtUO; Layout.fillWidth: true; placeholderText: qsTr("Halle2")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgOrt.close()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                    enabled: inpOrtKuerzel.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        seitenModel.ortAnlegen(dlgOrt.fuerAnlageId,
                            inpOrtKuerzel.text.trim(), inpOrtBez.text.trim(), inpOrtUO.text.trim())
                        inpOrtKuerzel.text = ""; inpOrtBez.text = ""; inpOrtUO.text = ""
                        dlgOrt.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: dlgSeite
        title: qsTr("Neue Seite")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 20

        property int fuerOrtId: -1

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Blattnummer (z.B. 001)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpBlatt; Layout.fillWidth: true; placeholderText: "001"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Bezeichnung (optional)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpSeiteBez; Layout.fillWidth: true; placeholderText: qsTr("Stromversorgung 24VDC")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Seitentyp"); color: theme.textMuted; font.pixelSize: 12 }
            ComboBox {
                id: cmbTyp; Layout.fillWidth: true
                model: ["schaltplan", "klemmenplan", "kabelplan", "titelblatt", "inhaltsverzeichnis", "layout"]
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text { leftPadding: 8; text: cmbTyp.displayText; color: theme.textPrimary;
                                    font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
            }
            Text { text: qsTr("Format"); color: theme.textMuted; font.pixelSize: 12 }
            ComboBox {
                id: cmbFormat; Layout.fillWidth: true
                model: ListModel {
                    ListElement { text: "A4 Querformat  (297 × 210 mm)"; breite: 297; hoehe: 210 }
                    ListElement { text: "A4 Hochformat  (210 × 297 mm)"; breite: 210; hoehe: 297 }
                    ListElement { text: "A3 Querformat  (420 × 297 mm)"; breite: 420; hoehe: 297 }
                    ListElement { text: "A3 Hochformat  (297 × 420 mm)"; breite: 297; hoehe: 420 }
                    ListElement { text: "A2 Querformat  (594 × 420 mm)"; breite: 594; hoehe: 420 }
                    ListElement { text: "A2 Hochformat  (420 × 594 mm)"; breite: 420; hoehe: 594 }
                }
                textRole: "text"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text { leftPadding: 8; text: cmbFormat.displayText; color: theme.textPrimary;
                                    font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgSeite.close()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                    enabled: inpBlatt.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        var fmt = cmbFormat.model.get(cmbFormat.currentIndex)
                        seitenModel.seiteAnlegen(dlgSeite.fuerOrtId,
                            inpBlatt.text.trim(), inpSeiteBez.text.trim(), cmbTyp.currentText,
                            fmt.breite, fmt.hoehe)
                        inpBlatt.text = ""; inpSeiteBez.text = ""; cmbTyp.currentIndex = 0; cmbFormat.currentIndex = 0
                        dlgSeite.close()
                    }
                }
            }
        }
    }

    // --------------------------------------------------------
    // Dialoge – Bearbeiten
    // --------------------------------------------------------

    Dialog {
        id: dlgAnlageBearbeiten
        title: qsTr("Anlage bearbeiten")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 20

        property int    itemId:             -1
        property string altKuerzel:         ""
        property string altBezeichnung:     ""
        property string altUebergeordnet:   ""

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        onOpened: {
            editAnlageKuerzel.text = dlgAnlageBearbeiten.altKuerzel
            editAnlageBez.text     = dlgAnlageBearbeiten.altBezeichnung
            editAnlageUO.text      = dlgAnlageBearbeiten.altUebergeordnet
        }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Kürzel"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editAnlageKuerzel; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Bezeichnung"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editAnlageBez; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Übergeordnete Anlage == (optional)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editAnlageUO; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgAnlageBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editAnlageKuerzel.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        seitenModel.anlageBearbeiten(dlgAnlageBearbeiten.itemId,
                            editAnlageKuerzel.text.trim(), editAnlageBez.text.trim(), editAnlageUO.text.trim())
                        dlgAnlageBearbeiten.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: dlgOrtBearbeiten
        title: qsTr("Ort bearbeiten")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 360
        padding: 20

        property int    itemId:             -1
        property string altKuerzel:         ""
        property string altBezeichnung:     ""
        property string altUebergeordnet:   ""

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        onOpened: {
            editOrtKuerzel.text = dlgOrtBearbeiten.altKuerzel
            editOrtBez.text     = dlgOrtBearbeiten.altBezeichnung
            editOrtUO.text      = dlgOrtBearbeiten.altUebergeordnet
        }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Kürzel"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editOrtKuerzel; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Bezeichnung"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editOrtBez; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Übergeordneter Ort ++ (optional)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editOrtUO; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgOrtBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editOrtKuerzel.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        seitenModel.ortBearbeiten(dlgOrtBearbeiten.itemId,
                            editOrtKuerzel.text.trim(), editOrtBez.text.trim(), editOrtUO.text.trim())
                        dlgOrtBearbeiten.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: dlgSeiteBearbeiten
        title: qsTr("Seite bearbeiten")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 460
        padding: 20

        property int    itemId:               -1
        property string altBlattnummer:      ""
        property string altBezeichnung:      ""
        property string altSeitentyp:        ""
        property real   altBreiteMm:         297
        property real   altHoeheMm:          210
        property real   altRandLinks:        20
        property real   altRandRechts:       10
        property real   altRandOben:         10
        property real   altRandUnten:        10

        height: Math.min(implicitHeight, 680)
        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }
        DebugLabel { panelName: "Seite-ID: " + dlgSeiteBearbeiten.itemId; visible: root.debug && dlgSeiteBearbeiten.visible; parent: dlgSeiteBearbeiten.background }

        onOpened: {
            editBlatt.text      = dlgSeiteBearbeiten.altBlattnummer
            editSeiteBez.text   = dlgSeiteBearbeiten.altBezeichnung
            var idx = editCmbTyp.model.indexOf(dlgSeiteBearbeiten.altSeitentyp)
            editCmbTyp.currentIndex    = idx >= 0 ? idx : 0
            editCmbFormat.currentIndex = root.formatIndex(dlgSeiteBearbeiten.altBreiteMm, dlgSeiteBearbeiten.altHoeheMm)
            editRandLinks.value  = dlgSeiteBearbeiten.altRandLinks
            editRandRechts.value = dlgSeiteBearbeiten.altRandRechts
            editRandOben.value   = dlgSeiteBearbeiten.altRandOben
            editRandUnten.value  = dlgSeiteBearbeiten.altRandUnten
            normblattPanel.laden(dlgSeiteBearbeiten.itemId)
        }

        contentItem: ColumnLayout {
            spacing: 0

            ScrollView {
                id: dlgSeiteBearbeitenScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: dlgSeiteBearbeitenScroll.width
                spacing: 10
            Text { text: qsTr("Blattnummer"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editBlatt; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Bezeichnung"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editSeiteBez; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Seitentyp"); color: theme.textMuted; font.pixelSize: 12 }
            ComboBox {
                id: editCmbTyp; Layout.fillWidth: true
                model: ["schaltplan", "klemmenplan", "kabelplan", "titelblatt", "inhaltsverzeichnis", "layout"]
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text { leftPadding: 8; text: editCmbTyp.displayText; color: theme.textPrimary;
                                    font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
            }
            Text { text: qsTr("Format"); color: theme.textMuted; font.pixelSize: 12 }
            ComboBox {
                id: editCmbFormat; Layout.fillWidth: true
                model: ListModel {
                    ListElement { text: "A4 Querformat  (297 × 210 mm)"; breite: 297; hoehe: 210 }
                    ListElement { text: "A4 Hochformat  (210 × 297 mm)"; breite: 210; hoehe: 297 }
                    ListElement { text: "A3 Querformat  (420 × 297 mm)"; breite: 420; hoehe: 297 }
                    ListElement { text: "A3 Hochformat  (297 × 420 mm)"; breite: 297; hoehe: 420 }
                    ListElement { text: "A2 Querformat  (594 × 420 mm)"; breite: 594; hoehe: 420 }
                    ListElement { text: "A2 Hochformat  (420 × 594 mm)"; breite: 420; hoehe: 594 }
                }
                textRole: "text"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text { leftPadding: 8; text: editCmbFormat.displayText; color: theme.textPrimary;
                                    font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
            }

            Text { text: qsTr("Ränder (mm)"); color: theme.textMuted; font.pixelSize: 12 }
            GridLayout {
                columns: 4; columnSpacing: 6; rowSpacing: 4; Layout.fillWidth: true
                Text { text: qsTr("Links");  color: theme.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                Text { text: qsTr("Rechts"); color: theme.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                Text { text: qsTr("Oben");   color: theme.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                Text { text: qsTr("Unten");  color: theme.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                SpinBox { id: editRandLinks;  from: 5; to: 50; value: 20; implicitWidth: 88
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    contentItem: Text { text: editRandLinks.value; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                SpinBox { id: editRandRechts; from: 5; to: 30; value: 10; implicitWidth: 88
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    contentItem: Text { text: editRandRechts.value; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                SpinBox { id: editRandOben;   from: 5; to: 30; value: 10; implicitWidth: 88
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    contentItem: Text { text: editRandOben.value; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                SpinBox { id: editRandUnten;  from: 5; to: 30; value: 10; implicitWidth: 88
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    contentItem: Text { text: editRandUnten.value; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            }

            SeitenBaumNormblattPanel {
                id: normblattPanel
                theme: root.theme
            }
            } // ColumnLayout (ScrollView content)
            } // ScrollView

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgSeiteBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editBlatt.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        var fmt = editCmbFormat.model.get(editCmbFormat.currentIndex)
                        seitenModel.seiteBearbeiten(dlgSeiteBearbeiten.itemId,
                            editBlatt.text.trim(), editSeiteBez.text.trim(), editCmbTyp.currentText,
                            fmt.breite, fmt.hoehe,
                            editRandLinks.value, editRandRechts.value,
                            editRandOben.value,  editRandUnten.value)
                        normblattPanel.speichern(dlgSeiteBearbeiten.itemId)
                        root.seiteFormatGeaendert(dlgSeiteBearbeiten.itemId)
                        dlgSeiteBearbeiten.close()
                    }
                }
            }
        }
    }

    // --------------------------------------------------------
    // Dialoge – Verschieben
    // --------------------------------------------------------

    Dialog {
        id: dlgSeiteVerschieben
        title: qsTr("Seite verschieben")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 380
        padding: 20

        property int seiteId: -1

        ListModel { id: anlageModelVers }
        ListModel { id: ortModelVers }

        onOpened: {
            anlageModelVers.clear()
            var anlagen = seitenModel.anlagenListe()
            for (var i = 0; i < anlagen.length; i++)
                anlageModelVers.append(anlagen[i])
            cmbVersAnlage.currentIndex = 0
        }

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Anlage"); color: theme.textMuted; font.pixelSize: 12 }
            ComboBox {
                id: cmbVersAnlage
                Layout.fillWidth: true
                model: anlageModelVers
                textRole: "label"
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && anlageModelVers.count > 0) {
                        var anlId = anlageModelVers.get(currentIndex).itemId
                        ortModelVers.clear()
                        var orte = seitenModel.orteListe(anlId)
                        for (var i = 0; i < orte.length; i++)
                            ortModelVers.append(orte[i])
                        cmbVersOrt.currentIndex = 0
                    }
                }
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text { leftPadding: 8; text: cmbVersAnlage.displayText; color: theme.textPrimary;
                                    font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
            }
            Text { text: qsTr("Ort"); color: theme.textMuted; font.pixelSize: 12 }
            ComboBox {
                id: cmbVersOrt
                Layout.fillWidth: true
                model: ortModelVers
                textRole: "label"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text { leftPadding: 8; text: cmbVersOrt.displayText; color: theme.textPrimary;
                                    font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgSeiteVerschieben.close()
                }
                Button {
                    text: qsTr("Verschieben"); implicitWidth: 100; implicitHeight: 34
                    enabled: cmbVersOrt.currentIndex >= 0 && ortModelVers.count > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        var ortId = ortModelVers.get(cmbVersOrt.currentIndex).itemId
                        seitenModel.seiteVerschieben(dlgSeiteVerschieben.seiteId, ortId)
                        dlgSeiteVerschieben.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: dlgOrtVerschieben
        title: qsTr("Ort verschieben")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 380
        padding: 20

        property int ortId: -1

        ListModel { id: anlageModelOrtVers }

        onOpened: {
            anlageModelOrtVers.clear()
            var anlagen = seitenModel.anlagenListe()
            for (var i = 0; i < anlagen.length; i++)
                anlageModelOrtVers.append(anlagen[i])
            cmbVersOrtAnlage.currentIndex = 0
        }

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: qsTr("Anlage"); color: theme.textMuted; font.pixelSize: 12 }
            ComboBox {
                id: cmbVersOrtAnlage
                Layout.fillWidth: true
                model: anlageModelOrtVers
                textRole: "label"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text { leftPadding: 8; text: cmbVersOrtAnlage.displayText; color: theme.textPrimary;
                                    font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgOrtVerschieben.close()
                }
                Button {
                    text: qsTr("Verschieben"); implicitWidth: 100; implicitHeight: 34
                    enabled: cmbVersOrtAnlage.currentIndex >= 0 && anlageModelOrtVers.count > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        var anlId = anlageModelOrtVers.get(cmbVersOrtAnlage.currentIndex).itemId
                        seitenModel.ortVerschieben(dlgOrtVerschieben.ortId, anlId)
                        dlgOrtVerschieben.close()
                    }
                }
            }
        }
    }

    // --------------------------------------------------------
    // Kein Projekt gewählt
    // --------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: root.projektId < 0

        Column {
            anchors.centerIn: parent
            spacing: 12
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Seitenbaum"); font.pixelSize: 22; font.weight: Font.Light; color: theme.borderDark
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Bitte zuerst ein Projekt auswählen."); font.pixelSize: 14; color: theme.borderDark
            }
        }
    }

    // --------------------------------------------------------
    // Hauptlayout wenn Projekt aktiv
    // --------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: root.projektId >= 0

        Rectangle {
            Layout.fillWidth: true; height: 52; color: theme.sidebar
            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: qsTr("Seitenbaum")
                        font.pixelSize: 9; color: theme.textMuted
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.projektName
                        font.pixelSize: 14; font.weight: Font.Medium; color: theme.textPrimary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
                Button {
                    text: qsTr("+ Anlage"); flat: true
                    contentItem: Text { text: parent.text; color: theme.accent; font.pixelSize: 13 }
                    background: Rectangle { color: parent.hovered ? theme.badge : "transparent"; radius: 4 }
                    onClicked: { dlgAnlage.fuerProjektId = root.projektId; dlgAnlage.open() }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Seiten / Struktur – Tabs ─────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 26
            color: theme.surfaceDeep

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { tab: "seiten",   label: qsTr("Seiten") },
                        { tab: "struktur", label: qsTr("Struktur") },
                        { tab: "bauteile", label: qsTr("Bauteile") }
                    ]
                    delegate: Item {
                        id: seitenStrukturTab
                        width: parent.width / 3; height: 26
                        property bool aktiv: root._aktiveTab === modelData.tab

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.pixelSize: 10
                            color: seitenStrukturTab.aktiv ? theme.accent : theme.textMuted
                            font.weight: seitenStrukturTab.aktiv ? Font.Medium : Font.Normal
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 2; radius: 1
                            color: theme.accent
                            visible: seitenStrukturTab.aktiv
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root._aktiveTab = modelData.tab
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root._aktiveTab === "seiten"
            clip: true

            TreeView {
                id: treeView
                model: seitenModel
                clip: true

                Component.onCompleted: expandRecursively()
                Connections {
                    target: seitenModel
                    function onModelReset() { Qt.callLater(treeView.expandRecursively) }
                }

                delegate: TreeViewDelegate {
                    id: delegateItem
                    // Anlage/Ort ohne Seiten werden im Hauptbaum ausgeblendet (→ STRUKTUR-Panel)
                    property bool _zeigeZeile: model.knotenTyp === 2 || (model.hatSeiten ?? true)
                    implicitHeight: _zeigeZeile ? 36 : 0
                    implicitWidth: treeView.width
                    visible: _zeigeZeile

                    property real _savedY: 0
                    z: dragHandle.drag.active ? 10 : 0
                    opacity: dragHandle.drag.active ? 0.75 : 1.0

                    onClicked: {
                        if (model.knotenTyp === 2)
                            root.seiteGewaehlt(model.itemId,
                                               model.blattnummer  ?? "",
                                               model.rohBezeichnung ?? "")
                    }

                    // Rechtsklick-Menü (nur für Seiten)
                    Menu {
                        id: seiteKontextMenu
                        property int _seiteId:       -1
                        property string _blattnummer: ""
                        property string _bezeichnung: ""

                        MenuItem {
                            text: qsTr("Als Tab öffnen")
                            onTriggered: root.seiteAlsTabOeffnen(
                                             seiteKontextMenu._seiteId,
                                             seiteKontextMenu._blattnummer,
                                             seiteKontextMenu._bezeichnung)
                        }
                        MenuItem {
                            text: qsTr("Öffnen")
                            onTriggered: root.seiteGewaehlt(
                                             seiteKontextMenu._seiteId,
                                             seiteKontextMenu._blattnummer,
                                             seiteKontextMenu._bezeichnung)
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: qsTr("Duplizieren")
                            onTriggered: {
                                var neueId = db.seiteDuplizieren(seiteKontextMenu._seiteId)
                                if (neueId > 0) seitenModel.laden(root.projektId)
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: function(eventPoint) {
                            if (model.knotenTyp !== 2) return
                            seiteKontextMenu._seiteId       = model.itemId
                            seiteKontextMenu._blattnummer   = model.blattnummer  ?? ""
                            seiteKontextMenu._bezeichnung   = model.rohBezeichnung ?? ""
                            seiteKontextMenu.popup()
                        }
                    }

                    background: Rectangle {
                        color: delegateItem.selected ? theme.hover : (delegateItem.hovered ? theme.hover : "transparent")
                    }

                    contentItem: RowLayout {
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        // Drag-Handle für Seiten (ersetzt ▲/▼ Buttons)
                        Item {
                            width:   model.knotenTyp === 2 ? 18 : 0
                            height:  parent.height
                            visible: model.knotenTyp === 2

                            Text {
                                anchors.centerIn: parent
                                text:           "☰"
                                font.pixelSize: 12
                                color:          dragHandle.drag.active ? theme.accent : theme.textMuted
                                opacity:        delegateItem.hovered || dragHandle.drag.active ? 1.0 : 0.25
                            }

                            MouseArea {
                                id:           dragHandle
                                anchors.fill: parent
                                drag.target:  delegateItem
                                drag.axis:    Drag.YAxis
                                drag.minimumY: -9999
                                drag.maximumY:  9999
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                ToolTip.visible: containsMouse && !drag.active
                                ToolTip.text:    qsTr("Seite innerhalb dieses Orts per Ziehen umsortieren")
                                ToolTip.delay:   700

                                onPressed: {
                                    delegateItem._savedY = delegateItem.y
                                    root._dragSeiteId    = model.itemId
                                }
                                onReleased: {
                                    if (drag.active) {
                                        var delta      = delegateItem.y - delegateItem._savedY
                                        var neuerIndex = Math.max(0, model.sortierung + Math.round(delta / 36))
                                        seitenModel.seiteUmordnen(model.itemId, neuerIndex)
                                    }
                                    root._dragSeiteId = -1
                                }
                            }
                        }

                        Text {
                            text: { var t = model.knotenTyp; if (t===0) return "\u2699"; if (t===1) return "\uD83C\uDFE0"; return "\uD83D\uDCC4" }
                            font.pixelSize: 14
                            color: { var t = model.knotenTyp; if (t===0) return theme.accent; if (t===1) return theme.accentLight; return theme.textSecondary }
                        }
                        Text {
                            text: model.bezeichnung ?? ""
                            font.pixelSize: 13
                            color: { var t = model.knotenTyp; if (t===0) return theme.textPrimary; if (t===1) return theme.textSecondary; return theme.textSecondary }
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Rectangle {
                            visible: model.knotenTyp === 2
                            color: theme.badge; radius: 3
                            width: typText.width + 10; height: 18
                            Text { id: typText; anchors.centerIn: parent; text: model.seitentyp ?? ""; font.pixelSize: 10; color: theme.accent }
                        }
                        Row {
                            spacing: 4; visible: delegateItem.hovered && !dragHandle.drag.active
                            Button {
                                visible: model.knotenTyp === 0 || model.knotenTyp === 1
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "+"; color: theme.accent; font.pixelSize: 16;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered
                                ToolTip.text:    model.knotenTyp === 0 ? qsTr("Ort anlegen") : qsTr("Seite anlegen")
                                ToolTip.delay:   700
                                onClicked: {
                                    if (model.knotenTyp === 0) { dlgOrt.fuerAnlageId = model.itemId; dlgOrt.open() }
                                    else { dlgSeite.fuerOrtId = model.itemId; dlgSeite.open() }
                                }
                            }
                            Button {
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: qsTr("\u270E"); color: theme.accent; font.pixelSize: 14;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Bearbeiten"); ToolTip.delay: 700
                                onClicked: {
                                    if (model.knotenTyp === 0) {
                                        dlgAnlageBearbeiten.itemId = model.itemId
                                        dlgAnlageBearbeiten.altKuerzel = model.kuerzel
                                        dlgAnlageBearbeiten.altBezeichnung = model.rohBezeichnung
                                        dlgAnlageBearbeiten.altUebergeordnet = model.uebergeordnet ?? ""
                                        dlgAnlageBearbeiten.open()
                                    } else if (model.knotenTyp === 1) {
                                        dlgOrtBearbeiten.itemId = model.itemId
                                        dlgOrtBearbeiten.altKuerzel = model.kuerzel
                                        dlgOrtBearbeiten.altBezeichnung = model.rohBezeichnung
                                        dlgOrtBearbeiten.altUebergeordnet = model.uebergeordnet ?? ""
                                        dlgOrtBearbeiten.open()
                                    } else {
                                        dlgSeiteBearbeiten.itemId          = model.itemId
                                        dlgSeiteBearbeiten.altBlattnummer  = model.blattnummer
                                        dlgSeiteBearbeiten.altBezeichnung  = model.rohBezeichnung
                                        dlgSeiteBearbeiten.altSeitentyp    = model.seitentyp
                                        dlgSeiteBearbeiten.altBreiteMm     = model.breiteMm
                                        dlgSeiteBearbeiten.altHoeheMm      = model.hoeheMm
                                        dlgSeiteBearbeiten.altRandLinks     = model.randLinksMm
                                        dlgSeiteBearbeiten.altRandRechts    = model.randRechtsMm
                                        dlgSeiteBearbeiten.altRandOben      = model.randObenMm
                                        dlgSeiteBearbeiten.altRandUnten     = model.randUntenMm
                                        dlgSeiteBearbeiten.open()
                                    }
                                }
                            }
                            Button {
                                visible: model.knotenTyp === 1 || model.knotenTyp === 2
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: qsTr("\u2192"); color: "#44aa66"; font.pixelSize: 14;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered
                                ToolTip.text:    model.knotenTyp === 1
                                    ? qsTr("Ort in eine andere Anlage verschieben – öffnet Auswahl-Dialog")
                                    : qsTr("Seite in einen anderen Ort oder eine andere Anlage verschieben – öffnet Auswahl-Dialog")
                                ToolTip.delay:   700
                                onClicked: {
                                    if (model.knotenTyp === 1) {
                                        dlgOrtVerschieben.ortId = model.itemId
                                        dlgOrtVerschieben.open()
                                    } else {
                                        dlgSeiteVerschieben.seiteId = model.itemId
                                        dlgSeiteVerschieben.open()
                                    }
                                }
                            }
                            Button {
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: qsTr("\u00D7"); color: "#aa4444"; font.pixelSize: 16;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Löschen"); ToolTip.delay: 700
                                onClicked: {
                                    if (model.knotenTyp === 2) {
                                        dlgSeiteLoeschen.loeschSeiteId        = model.itemId
                                        dlgSeiteLoeschen.loeschElementeAnzahl = db.grafikLaden(model.itemId).length
                                        dlgSeiteLoeschen.open()
                                    } else {
                                        seitenModel.loeschen(model.knotenTyp, model.itemId)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Struktur-Tab ─────────────────────────────────────────
        SeitenBaumStrukturPanel {
            id: strukturPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root._aktiveTab === "struktur"
            theme: root.theme
            projektId: root.projektId

            onAnlageAnlegenAngefordert: {
                dlgAnlage.fuerProjektId = root.projektId
                dlgAnlage.open()
            }
            onAnlageBearbeitenAngefordert: function(id, kuerzel, bez, uo) {
                dlgAnlageBearbeiten.itemId           = id
                dlgAnlageBearbeiten.altKuerzel       = kuerzel
                dlgAnlageBearbeiten.altBezeichnung   = bez
                dlgAnlageBearbeiten.altUebergeordnet = uo
                dlgAnlageBearbeiten.open()
            }
            onOrtAnlegenAngefordert: function(anlageId) {
                dlgOrt.fuerAnlageId = anlageId
                dlgOrt.open()
            }
            onOrtSeiteAnlegenAngefordert: function(ortId) {
                dlgSeite.fuerOrtId = ortId
                dlgSeite.open()
            }
            onOrtBearbeitenAngefordert: function(id, kuerzel, bez, uo) {
                dlgOrtBearbeiten.itemId           = id
                dlgOrtBearbeiten.altKuerzel       = kuerzel
                dlgOrtBearbeiten.altBezeichnung   = bez
                dlgOrtBearbeiten.altUebergeordnet = uo
                dlgOrtBearbeiten.open()
            }
        }

        SeitenBaumBauteilePanel {
            id: bauteilePanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root._aktiveTab === "bauteile"
            theme: root.theme
            aktivSeiteId: root.aktivSeiteId
            projektId: root.projektId
            debug: root.debug
            onKlemmenAnschlussPlatzieren: function(kId, bkId, bez, bmk) {
                root.klemmenAnschlussPlatzieren(kId, bkId, bez, bmk)
            }
            onKlemmenSequentiellStarten: function(json) {
                root.klemmenSequentiellStarten(json)
            }
            onBetriebsmittelKontaktPlatzieren: function(bid, sid, bmk, pb) {
                root.betriebsmittelKontaktPlatzieren(bid, sid, bmk, pb)
            }
            onBauteilPlatzieren: function(bId, symId, bez) {
                root.bauteilPlatzieren(bId, symId, bez)
            }
            onSprungAngefordert: function(sid, bnr, sbez, wx, wy) {
                root.sprungAngefordert(sid, bnr, sbez, wx, wy)
            }
        }
    }

    DebugLabel { panelName: qsTr("Seitenbaum"); visible: root.debug }

}
