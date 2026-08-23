import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "components"
import "sb"

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
    property string _aktiveTab:     "seitenstruktur"   // "seitenstruktur" | "bauteile"
    property bool _nurSeitenFilter: true   // an: Anlage/Ort ohne Seiten ausgeblendet (SEITENSTRUKTUR-01)

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
    signal steckverbinderKontaktPlatzieren(int geraetekastenId, int positionId, string symbolId, string bmk)
    signal steckverbinderSequentiellStarten(string queueJson)
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
    // Dialoge (REFACTOR-QML-01: ausgelagert nach qml/sb/)
    // --------------------------------------------------------
    SbSeiteLoeschenDialog       { id: dlgSeiteLoeschen;       theme: root.theme; sb: root }
    SbAnlageOrtLoeschenDialog   { id: dlgAnlageOrtLoeschen;   theme: root.theme }
    SbAnlageDialog              { id: dlgAnlage;              theme: root.theme; sb: root }
    SbOrtDialog                 { id: dlgOrt;                 theme: root.theme; sb: root }
    SbSeiteDialog                { id: dlgSeite;               theme: root.theme; sb: root }
    SbAnlageBearbeitenDialog    { id: dlgAnlageBearbeiten;    theme: root.theme }
    SbOrtBearbeitenDialog       { id: dlgOrtBearbeiten;       theme: root.theme }
    SbSeiteBearbeitenDialog     { id: dlgSeiteBearbeiten;     theme: root.theme; sb: root }
    SbSeiteVerschiebenDialog    { id: dlgSeiteVerschieben;    theme: root.theme }
    SbOrtVerschiebenDialog      { id: dlgOrtVerschieben;      theme: root.theme }

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

        // ── Seitenstruktur / Bauteile – Tabs ─────────────────
        Rectangle {
            Layout.fillWidth: true; height: 26
            color: theme.surfaceDeep

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { tab: "seitenstruktur", label: qsTr("Seitenstruktur"), tooltip: qsTr("Anlagen, Orte und Seiten anlegen, bearbeiten und sortieren") },
                        { tab: "bauteile",       label: qsTr("Bauteile"),       tooltip: qsTr("Im Schaltplan verwendete Bauteile") }
                    ]
                    delegate: Item {
                        id: seitenStrukturTab
                        width: parent.width / 2; height: 26
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
                            hoverEnabled: true
                            onClicked: root._aktiveTab = modelData.tab
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 600
                            ToolTip.text: modelData.tooltip
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Filter: Nur Seiten anzeigen (SEITENSTRUKTUR-01) ──
        Rectangle {
            Layout.fillWidth: true; height: 26
            visible: root._aktiveTab === "seitenstruktur"
            color: theme.sidebar

            Row {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 6

                Rectangle {
                    width: 14; height: 14; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: root._nurSeitenFilter ? theme.accent : theme.inputBg
                    border.color: theme.border
                    Text {
                        anchors.centerIn: parent; text: "✓"; color: "#fff"
                        font.pixelSize: 9; visible: root._nurSeitenFilter
                    }
                }
                Text {
                    text: qsTr("Nur Seiten anzeigen")
                    font.pixelSize: 10; color: theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root._nurSeitenFilter = !root._nurSeitenFilter
                    // Qt 6 TreeView cached row heights (s. rowHeightProvider-Kommentar
                    // oben): ein reiner Property-Wechsel ohne Modell-Reset reicht nicht,
                    // um bereits gemessene Zeilenhöhen zu verwerfen -> Lücke im Baum.
                    Qt.callLater(function() { treeView.forceLayout() })
                }
                ToolTip.visible: containsMouse
                ToolTip.delay: 600
                ToolTip.text: qsTr("Aus: zeigt auch Anlagen/Orte ohne Seiten (z. B. für Strukturkästen)")
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root._aktiveTab === "seitenstruktur"
            clip: true

            TreeView {
                id: treeView
                model: seitenModel
                clip: true

                // Qt 6 cached row heights: rowHeightProvider zwingt frische Auswertung
                // KnotenTypRole = Qt.UserRole+5, HatSeitenRole = Qt.UserRole+17
                rowHeightProvider: function(row) {
                    var idx = treeView.index(row, 0)
                    var knotenTyp = seitenModel.data(idx, Qt.UserRole + 5)
                    var hatSeiten = seitenModel.data(idx, Qt.UserRole + 17)
                    if (knotenTyp === 2 || hatSeiten === true || !root._nurSeitenFilter) return 36
                    return 0
                }

                Component.onCompleted: expandRecursively()
                Connections {
                    target: seitenModel
                    function onModelReset() {
                        Qt.callLater(function() {
                            treeView.expandRecursively()
                            treeView.forceLayout()
                        })
                    }
                }

                delegate: TreeViewDelegate {
                    id: delegateItem
                    // Anlage/Ort ohne Seiten werden ausgeblendet, solange der
                    // "Nur Seiten anzeigen"-Filter aktiv ist (SEITENSTRUKTUR-01)
                    property bool _zeigeZeile: model.knotenTyp === 2 || (model.hatSeiten ?? true) || !root._nurSeitenFilter
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
                                        dlgAnlageOrtLoeschen.loeschKnotenTyp    = model.knotenTyp
                                        dlgAnlageOrtLoeschen.loeschId           = model.itemId
                                        dlgAnlageOrtLoeschen.loeschName         = model.bezeichnung
                                        dlgAnlageOrtLoeschen.loeschSeitenAnzahl = model.seitenAnzahl ?? 0
                                        dlgAnlageOrtLoeschen.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hinweis am unteren Rand des Seitenstruktur-Tabs
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: hinweisText.implicitHeight + 16
            visible: root._aktiveTab === "seitenstruktur"
            color: theme.surfaceDeep

            Text {
                id: hinweisText
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Leere Anlagen/Orte? → Filter ausschalten")
                color: theme.textMuted
                font.pixelSize: 10
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
            onSteckverbinderKontaktPlatzieren: function(gkId, posId, symId, bmk) {
                root.steckverbinderKontaktPlatzieren(gkId, posId, symId, bmk)
            }
            onSteckverbinderSequentiellStarten: function(json) {
                root.steckverbinderSequentiellStarten(json)
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
