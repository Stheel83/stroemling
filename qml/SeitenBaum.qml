import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    // ── BAUTEILE-Bereich: Zustand + Caches ──────────────────
    property bool bauteilBereichOffen:   false
    property var  leistenAufgeklappt:    ({})   // {leisteId: bool}
    property var  klemmenAufgeklappt:    ({})   // {klemmeId: bool}
    property var  klemmenCache:          ({})   // {leisteId: [{id,nummer,bauteilId,bauteilKlemmeId,bezeichnung,leisteBmk}]}
    property var  anschluesseCache:      ({})   // {bauteilId: [{bezeichnung,seite,ebene}]}

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
        root.leistenAufgeklappt  = {}
        root.klemmenAufgeklappt  = {}
        root.klemmenCache        = {}
        root.anschluesseCache    = {}
        root.bauteilBereichOffen = false
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
            contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                 horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
            onClicked: if (onCancel) onCancel()
        }
        // Bestätigen
        Button {
            text: confirmText
            enabled: confirmEnabled
            implicitWidth: 90
            implicitHeight: 34
            contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                 horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
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
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                         horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
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

        property int fuerProjektId: -1

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: dlgAnlage.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
            Text { text: qsTr("Kürzel (z.B. EG, OG, KG)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpAnlageKuerzel; Layout.fillWidth: true; placeholderText: "EG"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Bezeichnung (z.B. Erdgeschoss)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpAnlageBez; Layout.fillWidth: true; placeholderText: qsTr("Erdgeschoss")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgAnlage.close()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                    enabled: inpAnlageKuerzel.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
                    onClicked: {
                        seitenModel.anlageAnlegen(dlgAnlage.fuerProjektId,
                            inpAnlageKuerzel.text.trim(), inpAnlageBez.text.trim())
                        inpAnlageKuerzel.text = ""; inpAnlageBez.text = ""
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

        property int fuerAnlageId: -1

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: dlgOrt.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
            Text { text: qsTr("Kürzel (z.B. A1, B2)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpOrtKuerzel; Layout.fillWidth: true; placeholderText: "A1"
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Bezeichnung (z.B. Hauptverteiler)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpOrtBez; Layout.fillWidth: true; placeholderText: qsTr("Hauptverteiler")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgOrt.close()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                    enabled: inpOrtKuerzel.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
                    onClicked: {
                        seitenModel.ortAnlegen(dlgOrt.fuerAnlageId,
                            inpOrtKuerzel.text.trim(), inpOrtBez.text.trim())
                        inpOrtKuerzel.text = ""; inpOrtBez.text = ""
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
            Text { text: dlgSeite.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
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
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgSeite.close()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                    enabled: inpBlatt.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
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

        property int    itemId:         -1
        property string altKuerzel:     ""
        property string altBezeichnung: ""

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        onOpened: {
            editAnlageKuerzel.text = dlgAnlageBearbeiten.altKuerzel
            editAnlageBez.text     = dlgAnlageBearbeiten.altBezeichnung
        }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: dlgAnlageBearbeiten.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
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
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgAnlageBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editAnlageKuerzel.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
                    onClicked: {
                        seitenModel.anlageBearbeiten(dlgAnlageBearbeiten.itemId,
                            editAnlageKuerzel.text.trim(), editAnlageBez.text.trim())
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

        property int    itemId:         -1
        property string altKuerzel:     ""
        property string altBezeichnung: ""

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        onOpened: {
            editOrtKuerzel.text = dlgOrtBearbeiten.altKuerzel
            editOrtBez.text     = dlgOrtBearbeiten.altBezeichnung
        }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: dlgOrtBearbeiten.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
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
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgOrtBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editOrtKuerzel.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
                    onClicked: {
                        seitenModel.ortBearbeiten(dlgOrtBearbeiten.itemId,
                            editOrtKuerzel.text.trim(), editOrtBez.text.trim())
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
        width: 360
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
        property string altHintergrundFarbe: ""
        property bool   altAussenOverlay:    false
        property string altTitelblattVorlage: "din6771"
        property var    _normblattVorlagen:   []
        property string altRevisionStatus:   ""
        property string altRevisionKennung:  ""

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

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
            dlgSeiteBearbeiten._normblattVorlagen = db.normblattVorlagenListe()
            var nd = db.normblattDatenLaden(dlgSeiteBearbeiten.itemId)
            if (nd) {
                chkNormblatt.checked       = nd.normblattAnzeigen !== false
                tfHintergrundFarbe.text    = nd.hintergrundFarbe  || ""
                chkAussenOverlay.checked   = nd.aussenOverlay === 1 || nd.aussenOverlay === true
                if (nd.normblattVorlageId) {
                    cmbVorlage.currentIndex = 3  // "benutzerdefiniert"
                    for (var j = 0; j < dlgSeiteBearbeiten._normblattVorlagen.length; j++) {
                        if (dlgSeiteBearbeiten._normblattVorlagen[j].id === nd.normblattVorlageId) {
                            cmbVorlageAuswahl.currentIndex = j; break
                        }
                    }
                } else {
                    var vi = cmbVorlage.model.indexOf(nd.titelblattVorlage || "din6771")
                    cmbVorlage.currentIndex = vi >= 0 ? vi : 0
                }
                var ri = cmbRevisionStatus.model.indexOf(nd.revisionStatus || "")
                cmbRevisionStatus.currentIndex = ri >= 0 ? ri : 0
                tfRevisionKennung.text = nd.revisionKennung || ""
            }
        }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: dlgSeiteBearbeiten.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
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
                SpinBox { id: editRandLinks;  from: 5; to: 50; value: 20; implicitWidth: 72
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    contentItem: Text { text: editRandLinks.value; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                SpinBox { id: editRandRechts; from: 5; to: 30; value: 10; implicitWidth: 72
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    contentItem: Text { text: editRandRechts.value; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                SpinBox { id: editRandOben;   from: 5; to: 30; value: 10; implicitWidth: 72
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    contentItem: Text { text: editRandOben.value; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
                SpinBox { id: editRandUnten;  from: 5; to: 30; value: 10; implicitWidth: 72
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    contentItem: Text { text: editRandUnten.value; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            }

            // ── Normblatt-Einstellungen ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 2
                CheckBox {
                    id: chkNormblatt
                    checked: true
                    indicator: Rectangle {
                        width: 16; height: 16; radius: 3
                        border.color: chkNormblatt.checked ? theme.accent : theme.border
                        color: chkNormblatt.checked ? theme.accent : theme.inputBg
                        Text {
                            anchors.centerIn: parent
                            text: "✓"; color: theme.textPrimary
                            font.pixelSize: 11; visible: chkNormblatt.checked
                        }
                    }
                    contentItem: Text {
                        text: qsTr("Normblatt anzeigen")
                        color: theme.textPrimary; font.pixelSize: 13
                        leftPadding: chkNormblatt.indicator.width + chkNormblatt.spacing
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Titelblatt-Vorlage (nur wenn Normblatt aktiv)
            Text {
                text: qsTr("Titelblatt-Vorlage")
                color: theme.textMuted; font.pixelSize: 12
                visible: chkNormblatt.checked
            }
            ComboBox {
                id: cmbVorlage
                Layout.fillWidth: true
                visible: chkNormblatt.checked
                model: ["din6771", "kompakt", "rahmen", "benutzerdefiniert"]
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text {
                    leftPadding: 8; text: {
                        switch(cmbVorlage.currentText) {
                            case "din6771":  return qsTr("DIN 6771 (vollständiges Schriftfeld)")
                            case "kompakt":  return qsTr("Kompakt (2-zeiliges Schriftfeld)")
                            case "rahmen":          return qsTr("Nur Rahmen (kein Schriftfeld)")
                            case "benutzerdefiniert": return qsTr("Benutzerdefiniert …")
                            default:                  return cmbVorlage.currentText
                        }
                    }
                    color: theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    width: cmbVorlage.width; implicitHeight: 32
                    highlighted: cmbVorlage.highlightedIndex === index
                    contentItem: Text {
                        leftPadding: 8
                        text: {
                            switch(modelData) {
                                case "din6771": return qsTr("DIN 6771 (vollständiges Schriftfeld)")
                                case "kompakt": return qsTr("Kompakt (2-zeiliges Schriftfeld)")
                                case "rahmen":          return qsTr("Nur Rahmen (kein Schriftfeld)")
                                case "benutzerdefiniert": return qsTr("Benutzerdefiniert …")
                                default:                  return modelData
                            }
                        }
                        color: theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                }
            }

            // Benutzerdefinierte Vorlage auswählen
            Text {
                text: qsTr("Vorlage auswählen")
                color: theme.textMuted; font.pixelSize: 12
                visible: chkNormblatt.checked && cmbVorlage.currentText === "benutzerdefiniert"
                height: visible ? implicitHeight : 0
            }
            ComboBox {
                id: cmbVorlageAuswahl
                Layout.fillWidth: true
                visible: chkNormblatt.checked && cmbVorlage.currentText === "benutzerdefiniert"
                         && dlgSeiteBearbeiten._normblattVorlagen.length > 0
                model: dlgSeiteBearbeiten._normblattVorlagen.map(function(v) { return v.name })
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text {
                    leftPadding: 8; text: cmbVorlageAuswahl.displayText
                    color: theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: cmbVorlageAuswahl.width; implicitHeight: 32
                    highlighted: cmbVorlageAuswahl.highlightedIndex === index
                    contentItem: Text {
                        leftPadding: 8; text: modelData
                        color: theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                }
            }
            Text {
                text: qsTr("Keine Vorlagen vorhanden. Über 'Normblatt' in der Seitenleiste anlegen.")
                visible: chkNormblatt.checked && cmbVorlage.currentText === "benutzerdefiniert"
                         && dlgSeiteBearbeiten._normblattVorlagen.length === 0
                color: theme.textMuted; font.pixelSize: 11; wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            // Außen-Overlay Checkbox (nur wenn Normblatt aktiv)
            RowLayout {
                Layout.fillWidth: true
                visible: chkNormblatt.checked
                CheckBox {
                    id: chkAussenOverlay
                    checked: false
                    indicator: Rectangle {
                        width: 16; height: 16; radius: 3
                        border.color: chkAussenOverlay.checked ? theme.accent : theme.border
                        color: chkAussenOverlay.checked ? theme.accent : theme.inputBg
                        Text {
                            anchors.centerIn: parent
                            text: "✓"; color: theme.textPrimary
                            font.pixelSize: 11; visible: chkAussenOverlay.checked
                        }
                    }
                    contentItem: Text {
                        text: qsTr("Bereich außerhalb abdunkeln")
                        color: theme.textPrimary; font.pixelSize: 13
                        leftPadding: chkAussenOverlay.indicator.width + chkAussenOverlay.spacing
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Seitenhintergrundfarbe
            Text { text: qsTr("Seitenhintergrund (Farbe)"); color: theme.textMuted; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                TextField {
                    id: tfHintergrundFarbe
                    Layout.fillWidth: true
                    placeholderText: qsTr("leer = transparent, z.B. #ffffff")
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    color: theme.textPrimary; font.pixelSize: 13
                }
                Rectangle {
                    width: 28; height: 28; radius: 4
                    color: tfHintergrundFarbe.text.trim() || "transparent"
                    border.color: theme.border
                }
            }

            // ── Revisionsstatus ──────────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 2 }
            Text { text: qsTr("Revisionsstatus"); color: theme.textMuted; font.pixelSize: 12 }
            ComboBox {
                id: cmbRevisionStatus
                Layout.fillWidth: true
                model: ["", "entwurf", "freigegeben", "veraltet"]
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                contentItem: Text {
                    leftPadding: 8
                    text: {
                        switch(cmbRevisionStatus.currentText) {
                            case "entwurf":     return qsTr("Entwurf")
                            case "freigegeben": return qsTr("Freigegeben")
                            case "veraltet":    return qsTr("Veraltet")
                            default:            return qsTr("Kein Status")
                        }
                    }
                    color: {
                        switch(cmbRevisionStatus.currentText) {
                            case "entwurf":     return "#d97706"
                            case "freigegeben": return "#16a34a"
                            case "veraltet":    return "#dc2626"
                            default:            return theme.textMuted
                        }
                    }
                    font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: cmbRevisionStatus.width; implicitHeight: 32
                    highlighted: cmbRevisionStatus.highlightedIndex === index
                    contentItem: Text {
                        leftPadding: 8
                        text: {
                            switch(modelData) {
                                case "entwurf":     return qsTr("Entwurf")
                                case "freigegeben": return qsTr("Freigegeben")
                                case "veraltet":    return qsTr("Veraltet")
                                default:            return qsTr("Kein Status")
                            }
                        }
                        color: {
                            switch(modelData) {
                                case "entwurf":     return "#d97706"
                                case "freigegeben": return "#16a34a"
                                case "veraltet":    return "#dc2626"
                                default:            return theme.textMuted
                            }
                        }
                        font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                }
            }
            Text {
                text: qsTr("Revisionskennzeichen (z. B. A, B, 1.0)")
                color: theme.textMuted; font.pixelSize: 12
                visible: cmbRevisionStatus.currentText !== ""
                height: visible ? implicitHeight : 0
            }
            TextField {
                id: tfRevisionKennung
                Layout.fillWidth: true
                visible: cmbRevisionStatus.currentText !== ""
                height: visible ? implicitHeight : 0
                placeholderText: qsTr("leer lassen wenn nicht relevant")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 13
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgSeiteBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editBlatt.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
                    onClicked: {
                        var fmt = editCmbFormat.model.get(editCmbFormat.currentIndex)
                        seitenModel.seiteBearbeiten(dlgSeiteBearbeiten.itemId,
                            editBlatt.text.trim(), editSeiteBez.text.trim(), editCmbTyp.currentText,
                            fmt.breite, fmt.hoehe,
                            editRandLinks.value, editRandRechts.value,
                            editRandOben.value,  editRandUnten.value)
                        db.normblattEinstellungenSetzen(
                            dlgSeiteBearbeiten.itemId,
                            chkNormblatt.checked,
                            tfHintergrundFarbe.text.trim(),
                            chkAussenOverlay.checked,
                            cmbVorlage.currentText,
                            (cmbVorlage.currentText === "benutzerdefiniert"
                             && cmbVorlageAuswahl.currentIndex >= 0
                             && dlgSeiteBearbeiten._normblattVorlagen.length > 0)
                                ? dlgSeiteBearbeiten._normblattVorlagen[cmbVorlageAuswahl.currentIndex].id : -1)
                        db.seiteRevisionSetzen(
                            dlgSeiteBearbeiten.itemId,
                            cmbRevisionStatus.currentText,
                            tfRevisionKennung.text.trim())
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
            Text { text: dlgSeiteVerschieben.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
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
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgSeiteVerschieben.close()
                }
                Button {
                    text: qsTr("Verschieben"); implicitWidth: 100; implicitHeight: 34
                    enabled: cmbVersOrt.currentIndex >= 0 && ortModelVers.count > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
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
            Text { text: dlgOrtVerschieben.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
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
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgOrtVerschieben.close()
                }
                Button {
                    text: qsTr("Verschieben"); implicitWidth: 100; implicitHeight: 34
                    enabled: cmbVersOrtAnlage.currentIndex >= 0 && anlageModelOrtVers.count > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
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

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: root.bauteilBereichOffen ? undefined : -1
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
                    implicitHeight: 36
                    implicitWidth: treeView.width

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
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

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
                            spacing: 4; visible: delegateItem.hovered
                            Button {
                                visible: model.knotenTyp === 2
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "▲"; color: theme.textMuted; font.pixelSize: 11;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Seite nach oben"); ToolTip.delay: 700
                                onClicked: seitenModel.seiteHoch(model.itemId)
                            }
                            Button {
                                visible: model.knotenTyp === 2
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "▼"; color: theme.textMuted; font.pixelSize: 11;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Seite nach unten"); ToolTip.delay: 700
                                onClicked: seitenModel.seiteRunter(model.itemId)
                            }
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
                                        dlgAnlageBearbeiten.open()
                                    } else if (model.knotenTyp === 1) {
                                        dlgOrtBearbeiten.itemId = model.itemId
                                        dlgOrtBearbeiten.altKuerzel = model.kuerzel
                                        dlgOrtBearbeiten.altBezeichnung = model.rohBezeichnung
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
                                background: Rectangle { color: parent.hovered ? "#1a3a2a" : "transparent"; radius: 4 }
                                ToolTip.visible: hovered
                                ToolTip.text:    model.knotenTyp === 1 ? qsTr("Ort verschieben") : qsTr("Seite verschieben")
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
                                background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 4 }
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

        // ── Trennlinie ──────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.borderDark }

        // ── BAUTEILE Header (immer sichtbar) ────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: bauteilHeaderArea.containsMouse ? theme.hover : "transparent"
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 6
                Text {
                    text: qsTr("BAUTEILE"); font.pixelSize: 10; font.weight: Font.Medium
                    color: theme.textMuted; Layout.fillWidth: true
                }
                Text { text: root.bauteilBereichOffen ? "▲" : "▼"; font.pixelSize: 9; color: theme.textMuted }
            }
            MouseArea {
                id: bauteilHeaderArea; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.bauteilBereichOffen) {
                        // Caches leeren damit beim nächsten Aufklappen frische Daten geladen werden
                        root.klemmenCache      = {}
                        root.anschluesseCache  = {}
                        root.leistenAufgeklappt = {}
                        root.klemmenAufgeklappt = {}
                    }
                    root.bauteilBereichOffen = !root.bauteilBereichOffen
                }
            }
            DebugLabel { panelName: qsTr("BAUTEILE-Bereich (Seitenbaum)"); visible: root.debug }
        }

        // ── BAUTEILE: Warnung wenn keine Seite aktiv ────────────
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: "#1a1a0a"
            visible: root.bauteilBereichOffen && root.aktivSeiteId < 0
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                spacing: 6
                Text { text: "⚠"; font.pixelSize: 12; color: "#aaaa44" }
                Text {
                    text: qsTr("Zuerst eine Seite im Baum auswählen ↑")
                    font.pixelSize: 11; color: "#aaaa44"
                    Layout.fillWidth: true
                }
            }
        }

        // ── BAUTEILE Inhalt (aufklappbar) ────────────────────────
        ScrollView {
            Layout.fillWidth: true; Layout.preferredHeight: 220
            visible: root.bauteilBereichOffen; clip: true
            Column {
                width: parent.width

                // ─── Klemmenleisten ───────────────────────────────
                Repeater {
                    model: klemmenleistenModel
                    delegate: Column {
                        id: leisteItem
                        width: parent.width
                        property int    leisteId:    model.leisteId
                        property string bmkKurz:     model.bmkKurz
                        property string bezeichnung: model.bezeichnung
                        property bool   offen:       root.leistenAufgeklappt[leisteId] === true

                        // Leisten-Zeile
                        Rectangle {
                            width: parent.width; height: 32
                            color: leisteMA.containsMouse ? theme.hover : "transparent"
                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                                spacing: 5
                                Text { text: leisteItem.offen ? "▾" : "▸"; font.pixelSize: 9; color: theme.textMuted }
                                Text { text: "🔌"; font.pixelSize: 12 }
                                Text {
                                    text: leisteItem.bmkKurz + "  " + leisteItem.bezeichnung
                                    font.pixelSize: 12; color: theme.textPrimary
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: leisteMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var lid = leisteItem.leisteId
                                    var auf = Object.assign({}, root.leistenAufgeklappt)
                                    auf[lid] = !auf[lid]
                                    if (auf[lid] && root.klemmenCache[lid] === undefined) {
                                        var c = Object.assign({}, root.klemmenCache)
                                        c[lid] = db.klemmenFuerLeiste(lid)
                                        root.klemmenCache = c
                                    }
                                    root.leistenAufgeklappt = auf
                                }
                            }
                        }

                        // Klemmen-Liste (lazy geladen)
                        Column {
                            width: parent.width
                            visible: leisteItem.offen
                            property var klemmen: root.klemmenCache[leisteItem.leisteId] || []

                            Repeater {
                                model: parent.klemmen
                                delegate: Column {
                                    id: klemmeItem
                                    width: parent.width
                                    property var  kl:          modelData
                                    property int  kId:         modelData ? (modelData.id        || -1) : -1
                                    property int  bauteilId:   modelData ? (modelData.bauteilId || -1) : -1
                                    property bool hatBauteil:  bauteilId > 0
                                    property bool klemmeOffen: root.klemmenAufgeklappt[kId] === true

                                    // Klemmen-Zeile
                                    Rectangle {
                                        width: parent.width; height: 30
                                        color: klemmeMA.containsMouse && klemmeItem.hatBauteil ? theme.hover : "transparent"
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                                            spacing: 4
                                            Text {
                                                text: klemmeItem.hatBauteil ? (klemmeItem.klemmeOffen ? "▾" : "▸") : " "
                                                font.pixelSize: 9; color: theme.textMuted
                                            }
                                            Text {
                                                text: klemmeItem.kl
                                                    ? (klemmeItem.kl.nummer + (klemmeItem.kl.bezeichnung ? "  " + klemmeItem.kl.bezeichnung : ""))
                                                    : ""
                                                font.pixelSize: 12
                                                color: klemmeItem.hatBauteil ? theme.textSecondary : theme.borderDark
                                                Layout.fillWidth: true; elide: Text.ElideRight
                                            }
                                        }
                                        MouseArea {
                                            id: klemmeMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: klemmeItem.hatBauteil ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: klemmeItem.hatBauteil
                                            onClicked: {
                                                var kid = klemmeItem.kId
                                                var bid = klemmeItem.bauteilId
                                                var auf = Object.assign({}, root.klemmenAufgeklappt)
                                                auf[kid] = !auf[kid]
                                                if (auf[kid] && root.anschluesseCache[bid] === undefined) {
                                                    var c = Object.assign({}, root.anschluesseCache)
                                                    c[bid] = db.anschluesseFuerKlemme(bid)
                                                    root.anschluesseCache = c
                                                }
                                                root.klemmenAufgeklappt = auf
                                            }
                                        }
                                    }

                                    // Anschlüsse (lazy geladen)
                                    Column {
                                        width: parent.width
                                        visible: klemmeItem.hatBauteil && klemmeItem.klemmeOffen
                                        property var anschluesse: klemmeItem.bauteilId > 0
                                            ? (root.anschluesseCache[klemmeItem.bauteilId] || [])
                                            : []
                                        property var klemmenDaten: klemmeItem.kl

                                        Repeater {
                                            model: parent.anschluesse
                                            delegate: Rectangle {
                                                width: parent.width; height: 28
                                                color: anschlussMA.containsMouse ? theme.activeItem : "transparent"
                                                property var ans: modelData
                                                property var kd:  parent.klemmenDaten

                                                RowLayout {
                                                    anchors { fill: parent; leftMargin: 34; rightMargin: 6 }
                                                    spacing: 4
                                                    Text {
                                                        text: "[" + (ans ? ans.bezeichnung : "") + "]"
                                                        font.pixelSize: 11; color: theme.accent
                                                    }
                                                    Text {
                                                        text: ans ? (qsTr("Seite ") + ans.seite + "  Eb." + ans.ebene) : ""
                                                        font.pixelSize: 11; color: theme.textMuted
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                                MouseArea {
                                                    id: anschlussMA; anchors.fill: parent; hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (!parent.kd || !parent.ans) return
                                                        var bmk = parent.kd.leisteBmk + ":"
                                                                  + parent.kd.nummer   + ":"
                                                                  + parent.ans.bezeichnung
                                                        root.klemmenAnschlussPlatzieren(
                                                            parent.kd.id,
                                                            parent.kd.bauteilKlemmeId,
                                                            parent.ans.bezeichnung,
                                                            bmk
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Kabel-Platzhalter ──────────────────────────
                Rectangle {
                    width: parent.width; height: 32; color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                        spacing: 6
                        Text { text: "🔗"; font.pixelSize: 12; opacity: 0.4 }
                        Text {
                            text: qsTr("Kabel  (noch nicht verfügbar)")
                            font.pixelSize: 12; color: theme.borderDark; Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Seitenbaum"); visible: root.debug }

}
