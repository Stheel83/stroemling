import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "sb"

// BAUTEILE-Aufklapp-Bereich im Seitenbaum:
// Trennlinie + Header + Klemmenleisten + Kabel-Platzhalter.
ColumnLayout {
    id: root

    required property var theme
    required property int aktivSeiteId
    property int  projektId: -1
    property bool debug: false

    property bool _klemmenInitialisiert: false

    property var  _leistenAufgeklappt:  ({})
    property var  _klemmenAufgeklappt:  ({})
    property var  _klemmenCache:        ({})
    property var  _anschluesseCache:    ({})
    property var  _platziert:           ({})   // "klemmeId_bez" → true

    property var  _geraeteAufgeklappt:  ({})
    property var  _mitgliederCache:     ({})   // betriebsmittelId → [{...}]
    property int  _geraeteVersion:      0       // Zähler: Increment zwingt _geraeteListe zur Neuauswertung

    property var  _kabelAufgeklappt:   ({})
    property var  _kabellinienCache:   ({})    // kabelId → [{grafikElementId, seiteId, blattnr, …}]
    property int  _kabelVersion:       0       // Zähler: Increment zwingt _kabelListe zur Neuauswertung (KABEL-VERWAIST-01)

    property var  _gkAufgeklappt:     ({})    // bmk → bool
    property int  _gkVersion:         0       // Zähler: Increment zwingt _gkFlachListe zur Neuauswertung
    property int    _highlightKlemmeId: -1
    property int    _highlightKabelId:  -1
    property int    _highlightGkId:     -1
    property string _aktiveTab:         "alles"   // "alles" | "klemmen" | "kabel" | "sonstiges"

    Timer {
        id: highlightTimer
        interval: 2000
        onTriggered: root._highlightKlemmeId = -1
    }
    Timer {
        id: highlightKabelTimer
        interval: 2000
        onTriggered: root._highlightKabelId = -1
    }
    Timer {
        id: highlightGkTimer
        interval: 2000
        onTriggered: root._highlightGkId = -1
    }

    function navigiereZuKlemme(klemmeId, anschlussBezeichnung) {
        var info = db.leisteInfoFuerKlemme(klemmeId)
        if (!info || !info.leisteId) return
        var leisteId = info.leisteId

        // Caches beim ersten Sprung frisch aufbauen
        if (!root._klemmenInitialisiert) {
            root._klemmenCache         = {}
            root._anschluesseCache     = {}
            root._leistenAufgeklappt   = {}
            root._klemmenAufgeklappt   = {}
            root._klemmenInitialisiert = true
            root.aktualisiereStatus()
        }

        // Leiste aufklappen + Klemmen laden
        var auf = Object.assign({}, root._leistenAufgeklappt)
        auf[leisteId] = true
        if (root._klemmenCache[leisteId] === undefined) {
            var kc = Object.assign({}, root._klemmenCache)
            kc[leisteId] = db.klemmenFuerLeiste(leisteId)
            root._klemmenCache = kc
        }
        root._leistenAufgeklappt = auf

        // Klemme aufklappen + Anschlüsse laden
        var kauf = Object.assign({}, root._klemmenAufgeklappt)
        kauf[klemmeId] = true
        root._klemmenAufgeklappt = kauf
        var klemmenListe = root._klemmenCache[leisteId] || []
        for (var i = 0; i < klemmenListe.length; i++) {
            var kl = klemmenListe[i]
            if (kl.id === klemmeId && kl.bauteilId > 0) {
                if (root._anschluesseCache[kl.bauteilId] === undefined) {
                    var ac = Object.assign({}, root._anschluesseCache)
                    ac[kl.bauteilId] = db.anschluesseFuerKlemme(kl.bauteilId)
                    root._anschluesseCache = ac
                }
                break
            }
        }

        // Klemme-Zeile hervorheben
        root._highlightKlemmeId = klemmeId
        highlightTimer.restart()
    }

    function navigiereZuKabel(kabelId) {
        if (root._aktiveTab !== "alles" && root._aktiveTab !== "kabel")
            root._aktiveTab = "kabel"
        var auf = Object.assign({}, root._kabelAufgeklappt)
        auf[kabelId] = true
        if (root._kabellinienCache[kabelId] === undefined) {
            var c = Object.assign({}, root._kabellinienCache)
            c[kabelId] = db.kabellinienMitPos(kabelId)
            root._kabellinienCache = c
        }
        root._kabelAufgeklappt = auf
        root._highlightKabelId = kabelId
        highlightKabelTimer.restart()
    }

    function navigiereZuGeraetekasten(gkId, gkBmk) {
        if (root._aktiveTab !== "alles" && root._aktiveTab !== "sonstiges")
            root._aktiveTab = "sonstiges"
        var auf = Object.assign({}, root._gkAufgeklappt)
        auf[gkBmk] = true
        root._gkAufgeklappt = auf
        root._highlightGkId = gkId
        highlightGkTimer.restart()
    }

    signal klemmenAnschlussPlatzieren(int klemmeId, int bauteilKlemmeId,
                                      string anschlussBezeichnung, string bmk)
    signal klemmenSequentiellStarten(string queueJson)
    signal betriebsmittelKontaktPlatzieren(int betriebsmittelId, string symbolId, string bmk, var pinBez)
    signal steckverbinderKontaktPlatzieren(int geraetekastenId, int positionId, string symbolId, string bmk)
    signal steckverbinderSequentiellStarten(string queueJson)
    signal bauteilPlatzieren(int bauteilId, string symbolId, string bezeichnung)
    signal sprungAngefordert(int seiteId, string blattnr, string seiteBez,
                             real weltX, real weltY)

    function aktualisiereStatus() {
        var liste = db.platzierteKlemmenAnschluesse()
        var map = {}
        for (var i = 0; i < liste.length; i++) {
            var e = liste[i]
            map[e.klemmeId + "_" + e.anschlussBezeichnung] = true
        }
        root._platziert = map
    }

    function istPlatziert(klemmeId, bezeichnung) {
        return !!root._platziert[klemmeId + "_" + bezeichnung]
    }

    // Lädt alle aktuell aufgeklappten Knoten neu, ohne den Baum einzuklappen
    // (anders als der Öffnen-Handler, der *Aufgeklappt-Maps zurücksetzt).
    function neuLaden() {
        var klemmenCache = {}
        for (var lid in root._leistenAufgeklappt) {
            if (root._leistenAufgeklappt[lid])
                klemmenCache[lid] = db.klemmenFuerLeiste(parseInt(lid))
        }
        root._klemmenCache = klemmenCache

        var bauteilIdByKId = {}
        for (var lid2 in klemmenCache) {
            var liste = klemmenCache[lid2]
            for (var i = 0; i < liste.length; i++)
                bauteilIdByKId[liste[i].id] = liste[i].bauteilId
        }
        var anschluesseCache = {}
        for (var kid in root._klemmenAufgeklappt) {
            if (!root._klemmenAufgeklappt[kid]) continue
            var bid = bauteilIdByKId[kid]
            if (bid > 0) anschluesseCache[bid] = db.anschluesseFuerKlemme(bid)
        }
        root._anschluesseCache = anschluesseCache

        var mitgliederCache = {}
        for (var gbid in root._geraeteAufgeklappt) {
            if (root._geraeteAufgeklappt[gbid])
                mitgliederCache[gbid] = db.betriebsmittelMitgliederMitPos(parseInt(gbid))
        }
        root._mitgliederCache = mitgliederCache
        root._geraeteVersion++

        var kabellinienCache = {}
        for (var kkid in root._kabelAufgeklappt) {
            if (root._kabelAufgeklappt[kkid])
                kabellinienCache[kkid] = db.kabellinienMitPos(parseInt(kkid))
        }
        root._kabellinienCache = kabellinienCache

        root.aktualisiereStatus()
    }

    function reset() {
        root._klemmenCache         = {}
        root._anschluesseCache     = {}
        root._leistenAufgeklappt   = {}
        root._klemmenAufgeklappt   = {}
        root._klemmenInitialisiert = false
        root._platziert            = {}
        root._geraeteAufgeklappt  = {}
        root._mitgliederCache     = {}
        root._kabelAufgeklappt    = {}
        root._kabellinienCache    = {}
        root._gkAufgeklappt       = {}
    }

    function _onElementeGeaendert() {
        if (root.visible) {
            root.aktualisiereStatus()
            root._mitgliederCache = {}
            root._geraeteVersion++
            root._gkVersion++
            root._kabelVersion++

            // KABEL-VERWAIST-01-NACHTRAG: _kabellinienCache sonst nur beim
            // ersten Aufklappen befüllt — eine danach neu gezeichnete/gelöschte
            // Kabellinie würde sich hier sonst nie zeigen (stale), und der
            // "Keine Kabellinie"-Hinweis inkl. Löschen-Button könnte fälschlich
            // auf einem längst platzierten Kabel stehen bleiben.
            var kabellinienCache = Object.assign({}, root._kabellinienCache)
            for (var kkid in root._kabelAufgeklappt) {
                if (root._kabelAufgeklappt[kkid])
                    kabellinienCache[kkid] = db.kabellinienMitPos(parseInt(kkid))
            }
            root._kabellinienCache = kabellinienCache
        }
    }

    // KABEL-VERWAIST-01: Kabel ohne jede Kabellinie löschen (Datenleiche,
    // z.B. wenn die gezeichnete Linie gelöscht, aber nie neu platziert wurde).
    // Live-Nachprüfung statt Blindvertrauen auf den Cache — verhindert, dass
    // ein zwischenzeitlich stale gewordener Anzeigezustand ein tatsächlich
    // platziertes Kabel löscht (KABEL-VERWAIST-01-NACHTRAG).
    function kabelOhneLinieLoeschen(kabelId) {
        var aktuelleLinien = db.kabellinienMitPos(kabelId)
        if (aktuelleLinien.length > 0) {
            var c = Object.assign({}, root._kabellinienCache)
            c[kabelId] = aktuelleLinien
            root._kabellinienCache = c
            return
        }
        db.kabelLoeschen(kabelId)
        root._kabelVersion++
    }
    Connections { target: elementeModel1; function onGeaendert() { root._onElementeGeaendert() } }
    Connections { target: elementeModel2; function onGeaendert() { root._onElementeGeaendert() } }

    Layout.fillWidth: true
    spacing: 0

    // ── Trennlinie ──────────────────────────────────────────
    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.borderDark }

    // ── BAUTEILE Header (immer sichtbar) ────────────────────
    Rectangle {
        Layout.fillWidth: true; height: 36
        color: "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 6
            Text {
                text: qsTr("BAUTEILE"); font.pixelSize: 10; font.weight: Font.Medium
                color: root.theme.textMuted; Layout.fillWidth: true
            }
            Rectangle {
                width: 22; height: 22; radius: 3
                color: refreshBauteilBtn.containsMouse ? root.theme.activeItemAlt : "transparent"
                Text { anchors.centerIn: parent; text: "↻"; font.pixelSize: 13; color: root.theme.accent }
                ToolTip.visible: refreshBauteilBtn.containsMouse
                ToolTip.text:    qsTr("Neu laden")
                ToolTip.delay:   400
                MouseArea {
                    id: refreshBauteilBtn; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.neuLaden()
                }
            }
        }
        DebugLabel { panelName: qsTr("BAUTEILE-Bereich (Seitenbaum)"); visible: root.debug }
    }

    // ── Tab-Filter ───────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true; height: 26
        color: root.theme.surfaceDeep

        Row {
            anchors.fill: parent

            Repeater {
                model: [
                    { tab: "alles",     label: qsTr("Alles") },
                    { tab: "klemmen",   label: qsTr("Klemmen") },
                    { tab: "kabel",     label: qsTr("Kabel") },
                    { tab: "sonstiges", label: qsTr("Sonstiges") }
                ]
                delegate: Item {
                    id: tabDelegate
                    width: parent.width / 4; height: 26
                    clip: true
                    property bool aktiv: root._aktiveTab === modelData.tab

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        color: tabDelegate.aktiv ? root.theme.accent : root.theme.textMuted
                        font.weight: tabDelegate.aktiv ? Font.Medium : Font.Normal
                    }

                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 2; radius: 1
                        color: root.theme.accent
                        visible: tabDelegate.aktiv
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._aktiveTab = modelData.tab
                    }
                }
            }
        }
    }

    // ── BAUTEILE: Warnung wenn keine Seite aktiv ────────────
    Rectangle {
        Layout.fillWidth: true
        height: 30
        color: "#1a1a0a"
        visible: root.aktivSeiteId < 0
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

    // ── BAUTEILE Inhalt ──────────────────────────────────────
    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true
        Column {
            id: inhaltSpalte
            width: parent.width

            // ── BAUTEILE-Kategorien (REFACTOR-QML-03: ausgelagert nach qml/sb/) ──
            SbBauteileKlemmenleisten  { panel: root; theme: root.theme }
            SbBauteileGeraete         { panel: root; theme: root.theme }
            SbBauteileKabel           { panel: root; theme: root.theme }
            SbBauteileGeraetekaesten  { panel: root; theme: root.theme }
            SbBauteileBibliothek      { panel: root; theme: root.theme }
        }
    }
}
