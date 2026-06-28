import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

// BAUTEILE-Aufklapp-Bereich im Seitenbaum:
// Trennlinie + Header + Klemmenleisten + Kabel-Platzhalter.
ColumnLayout {
    id: root

    required property var theme
    required property int aktivSeiteId
    property int  projektId: -1
    property bool debug: false

    property bool _bauteilBereichOffen: false
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

    property var  _gkAufgeklappt:     ({})    // bmk → bool
    property int    _highlightKlemmeId: -1
    property int    _highlightKabelId:  -1
    property int    _highlightGkId:     -1
    property string _aktiveTab:         "alles"   // "alles" | "klemmen" | "kabel" | "sonstiges"

    readonly property bool offen: _bauteilBereichOffen

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

        // Bauteilbereich öffnen falls geschlossen
        if (!root._bauteilBereichOffen) {
            root._klemmenCache       = {}
            root._anschluesseCache   = {}
            root._leistenAufgeklappt = {}
            root._klemmenAufgeklappt = {}
            root._bauteilBereichOffen = true
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
        root._bauteilBereichOffen = true
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
        root._bauteilBereichOffen = true
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
        root._klemmenCache        = {}
        root._anschluesseCache    = {}
        root._leistenAufgeklappt  = {}
        root._klemmenAufgeklappt  = {}
        root._bauteilBereichOffen = false
        root._platziert           = {}
        root._geraeteAufgeklappt  = {}
        root._mitgliederCache     = {}
        root._kabelAufgeklappt    = {}
        root._kabellinienCache    = {}
        root._gkAufgeklappt       = {}
    }

    function _onElementeGeaendert() {
        if (root._bauteilBereichOffen) {
            root.aktualisiereStatus()
            root._mitgliederCache = {}
            root._geraeteVersion++
        }
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
        color: bauteilHeaderArea.containsMouse ? root.theme.hover : "transparent"

        // bauteilHeaderArea zuerst → liegt im Z-Stack unter dem RowLayout,
        // damit der ↻-Button seine Klicks selbst abfangen kann.
        MouseArea {
            id: bauteilHeaderArea; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root._bauteilBereichOffen) {
                    root._klemmenCache        = {}
                    root._anschluesseCache    = {}
                    root._leistenAufgeklappt  = {}
                    root._klemmenAufgeklappt  = {}
                    root.aktualisiereStatus()
                }
                root._bauteilBereichOffen = !root._bauteilBereichOffen
            }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 6
            Text {
                text: qsTr("BAUTEILE"); font.pixelSize: 10; font.weight: Font.Medium
                color: root.theme.textMuted; Layout.fillWidth: true
            }
            Rectangle {
                width: 22; height: 22; radius: 3
                visible: root._bauteilBereichOffen
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
            Text { text: root._bauteilBereichOffen ? "▲" : "▼"; font.pixelSize: 9; color: root.theme.textMuted }
        }
        DebugLabel { panelName: qsTr("BAUTEILE-Bereich (Seitenbaum)"); visible: root.debug }
    }

    // ── Tab-Filter ───────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true; height: 26
        visible: root._bauteilBereichOffen
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
        visible: root._bauteilBereichOffen && root.aktivSeiteId < 0
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
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: root._bauteilBereichOffen; clip: true
        Column {
            id: inhaltSpalte
            width: parent.width

            // ─── Klemmenleisten ───────────────────────────────
            Column {
            visible: root._aktiveTab === "alles" || root._aktiveTab === "klemmen"
            width: parent.width
            Repeater {
                model: klemmenleistenModel
                delegate: Column {
                    id: leisteItem
                    width: parent.width
                    property int    leisteId:    model.leisteId
                    property string bmkKurz:     model.bmkKurz
                    property string bezeichnung: model.bezeichnung
                    property bool   offen:       root._leistenAufgeklappt[leisteId] === true

                    // Leisten-Zeile
                    Rectangle {
                        width: parent.width; height: 32
                        color: leisteMA.containsMouse ? root.theme.hover : "transparent"

                        // leisteMA zuerst → liegt im Z-Stack unter dem RowLayout
                        MouseArea {
                            id: leisteMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var lid = leisteItem.leisteId
                                var auf = Object.assign({}, root._leistenAufgeklappt)
                                auf[lid] = !auf[lid]
                                if (auf[lid] && root._klemmenCache[lid] === undefined) {
                                    var c = Object.assign({}, root._klemmenCache)
                                    c[lid] = db.klemmenFuerLeiste(lid)
                                    root._klemmenCache = c
                                }
                                root._leistenAufgeklappt = auf
                            }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                            spacing: 5
                            Text { text: leisteItem.offen ? "▾" : "▸"; font.pixelSize: 9; color: root.theme.textMuted }
                            Text { text: "🔌"; font.pixelSize: 12 }
                            Text {
                                text: leisteItem.bmkKurz + "  " + leisteItem.bezeichnung
                                font.pixelSize: 12; color: root.theme.textPrimary
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            // Sequentiell-Platzieren-Button
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                visible: leisteItem.offen
                                color: seqMa.containsMouse ? root.theme.activeItemAlt : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "⇥"; font.pixelSize: 13
                                    color: root.theme.accent
                                }
                                ToolTip.visible: seqMa.containsMouse
                                ToolTip.text:    qsTr("Anschlüsse sequentiell platzieren")
                                ToolTip.delay:   400
                                MouseArea {
                                    id: seqMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var klemmen = db.klemmenFuerLeiste(leisteItem.leisteId)
                                        var queue = []
                                        for (var i = 0; i < klemmen.length; i++) {
                                            var kl = klemmen[i]
                                            if (!kl.bauteilId || kl.bauteilId <= 0) continue
                                            var anschluesse = db.anschluesseFuerKlemme(kl.bauteilId)
                                            for (var j = 0; j < anschluesse.length; j++) {
                                                var ans = anschluesse[j]
                                                if (!root.istPlatziert(kl.id, ans.bezeichnung)) {
                                                    queue.push({
                                                        klemmeId:             kl.id,
                                                        bauteilKlemmeId:      kl.bauteilKlemmeId,
                                                        anschlussBezeichnung: ans.bezeichnung,
                                                        bmk: kl.leisteBmk + ":" + kl.nummer + ":" + ans.bezeichnung
                                                    })
                                                    break  // nur erster freier Anschluss je Klemme
                                                }
                                            }
                                        }
                                        if (queue.length > 0)
                                            root.klemmenSequentiellStarten(JSON.stringify(queue))
                                    }
                                }
                            }
                        }
                    }

                    // Klemmen-Liste (lazy geladen)
                    Column {
                        width: parent.width
                        visible: leisteItem.offen
                        property var klemmen: root._klemmenCache[leisteItem.leisteId] || []

                        Repeater {
                            model: parent.klemmen
                            delegate: Column {
                                id: klemmeItem
                                width: parent.width
                                property var  kl:          modelData
                                property int  kId:         modelData ? (modelData.id        || -1) : -1
                                property int  bauteilId:   modelData ? (modelData.bauteilId || -1) : -1
                                property bool hatBauteil:  bauteilId > 0
                                property bool klemmeOffen: root._klemmenAufgeklappt[kId] === true

                                // Klemmen-Zeile
                                Rectangle {
                                    id: klemmeZeile
                                    width: parent.width; height: 30
                                    color: root._highlightKlemmeId === klemmeItem.kId
                                        ? root.theme.activeItem
                                        : (klemmeMA.containsMouse && klemmeItem.hatBauteil ? root.theme.hover : "transparent")
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                                        spacing: 4
                                        Text {
                                            text: klemmeItem.hatBauteil ? (klemmeItem.klemmeOffen ? "▾" : "▸") : " "
                                            font.pixelSize: 9; color: root.theme.textMuted
                                        }
                                        Text {
                                            text: klemmeItem.kl
                                                ? (klemmeItem.kl.nummer + (klemmeItem.kl.bezeichnung ? "  " + klemmeItem.kl.bezeichnung : ""))
                                                : ""
                                            font.pixelSize: 12
                                            color: klemmeItem.hatBauteil ? root.theme.textSecondary : root.theme.borderDark
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
                                            var auf = Object.assign({}, root._klemmenAufgeklappt)
                                            auf[kid] = !auf[kid]
                                            if (auf[kid] && root._anschluesseCache[bid] === undefined) {
                                                var c = Object.assign({}, root._anschluesseCache)
                                                c[bid] = db.anschluesseFuerKlemme(bid)
                                                root._anschluesseCache = c
                                            }
                                            root._klemmenAufgeklappt = auf
                                        }
                                    }
                                }

                                // Anschluesse (lazy geladen)
                                Column {
                                    width: parent.width
                                    visible: klemmeItem.hatBauteil && klemmeItem.klemmeOffen
                                    property var anschluesse: klemmeItem.bauteilId > 0
                                        ? (root._anschluesseCache[klemmeItem.bauteilId] || [])
                                        : []
                                    property var klemmenDaten: klemmeItem.kl

                                    Repeater {
                                        model: parent.anschluesse
                                        delegate: Rectangle {
                                            width: parent.width; height: 28
                                            property var  ans:       modelData
                                            property var  kd:        parent.klemmenDaten
                                            property bool platziert: kd && ans
                                                ? root.istPlatziert(kd.id, ans.bezeichnung)
                                                : false
                                            color: platziert
                                                ? "transparent"
                                                : (anschlussMA.containsMouse ? root.theme.activeItem : "transparent")

                                            RowLayout {
                                                anchors { fill: parent; leftMargin: 34; rightMargin: 6 }
                                                spacing: 4
                                                Text {
                                                    text: "[" + (ans ? ans.bezeichnung : "") + "]"
                                                    font.pixelSize: 11
                                                    color: platziert ? root.theme.textMuted : root.theme.accent
                                                    opacity: platziert ? 0.6 : 1.0
                                                }
                                                Text {
                                                    text: ans ? (qsTr("Seite ") + ans.seite + "  Eb." + ans.ebene) : ""
                                                    font.pixelSize: 11; color: root.theme.textMuted
                                                    opacity: platziert ? 0.5 : 1.0
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    visible: platziert
                                                    text: "✓"
                                                    font.pixelSize: 11; color: "#60b060"
                                                }
                                                // Sprung-Button: nur wenn platziert
                                                Rectangle {
                                                    visible: platziert
                                                    implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                                    color: sprungMA.containsMouse ? root.theme.accent : "transparent"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "→"
                                                        font.pixelSize: 11
                                                        color: sprungMA.containsMouse ? "#ffffff" : root.theme.accent
                                                    }
                                                    MouseArea {
                                                        id: sprungMA; anchors.fill: parent; hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (!parent.parent.parent.kd || !parent.parent.parent.ans) return
                                                            var _kd  = parent.parent.parent.kd
                                                            var _ans = parent.parent.parent.ans
                                                            var pos  = db.klemmeAnschlussPosition(_kd.id, _ans.bezeichnung)
                                                            if (pos && pos.seiteId > 0)
                                                                root.sprungAngefordert(pos.seiteId, pos.blattnr,
                                                                                       pos.seiteBez, pos.weltX, pos.weltY)
                                                        }
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                id: anschlussMA; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: parent.platziert ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                enabled: !parent.platziert
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

            } // end klemmen Column

            // ── GERÄTE ───────────────────────────────────
            Column {
            visible: root._aktiveTab === "alles" || root._aktiveTab === "sonstiges"
            width: parent.width
            property var _geraeteListe: {
                var _v = root._geraeteVersion;
                return root._bauteilBereichOffen && root.projektId >= 0
                    ? db.betriebsmittelListe(root.projektId).filter(function(b) { return b.anzahl > 0 })
                    : [];
            }

            Rectangle {
                width: parent.width; height: 1; color: root.theme.divider
                visible: parent._geraeteListe.length > 0
            }

            Repeater {
                model: parent._geraeteListe
                delegate: Column {
                    id: geraetItem
                    width: parent.width
                    property int    bmId:        modelData.id
                    property string bmKz:        modelData.kz
                    property string bmBez:       modelData.bezeichnung || ""
                    property bool   aufgeklappt: root._geraeteAufgeklappt[bmId] === true

                    // Betriebsmittel-Zeile
                    Rectangle {
                        id: geraetZeile
                        width: parent.width; height: 32
                        color: geraetMA.containsMouse ? root.theme.hover : "transparent"

                        // Picker-Popup: Anschlussbelegung (wenn vorhanden) oder generische Symbolliste
                        Popup {
                            id: kontaktPicker
                            x: 10; y: geraetZeile.height
                            width: 220
                            padding: 4
                            background: Rectangle {
                                color: root.theme.surface; radius: 4
                                border.color: root.theme.border
                            }

                            property var _anschluesse: []
                            property bool _hatAnschluesse: _anschluesse.length > 0

                            onOpened: {
                                var bid = db.betriebsmittelBauteilId(geraetItem.bmId)
                                _anschluesse = bid > 0 ? db.bauteilKontaktListe(bid) : []
                            }

                            Column {
                                width: parent.width
                                spacing: 1

                                // ── Kontaktbelegung aus DB ───────────────────
                                Repeater {
                                    model: kontaktPicker._hatAnschluesse ? kontaktPicker._anschluesse : []
                                    delegate: Rectangle {
                                        width: parent.width; height: 28; radius: 3
                                        color: aMA.containsMouse ? root.theme.activeItem : "transparent"
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            Text {
                                                text: modelData.bezeichnung || modelData.symbolId
                                                font.pixelSize: 11; font.weight: Font.Medium
                                                color: root.theme.accent
                                                Layout.preferredWidth: 60
                                            }
                                            Text {
                                                text: modelData.symbolId
                                                font.pixelSize: 10; color: root.theme.textMuted
                                                Layout.fillWidth: true; elide: Text.ElideRight
                                            }
                                        }
                                        MouseArea {
                                            id: aMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                kontaktPicker.close()
                                                var pb = {}
                                                try { pb = JSON.parse(modelData.pinBez || "{}") } catch(e) {}
                                                root.betriebsmittelKontaktPlatzieren(
                                                    geraetItem.bmId,
                                                    modelData.symbolId,
                                                    geraetItem.bmKz,
                                                    pb
                                                )
                                            }
                                        }
                                    }
                                }

                                // Trennlinie zwischen Anschlussbelegung und generischer Liste
                                Rectangle {
                                    width: parent.width - 8; height: 1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: root.theme.border
                                    visible: kontaktPicker._hatAnschluesse
                                }

                                // ── Generische Symbolliste (immer sichtbar) ───
                                Repeater {
                                    model: [
                                        { id: "schliesser",  name: qsTr("Schließer (NO)") },
                                        { id: "oeffner",     name: qsTr("Öffner (NC)") },
                                        { id: "wechsler",    name: qsTr("Wechsler") },
                                        { id: "taster_no",   name: qsTr("Taster (NO)") },
                                        { id: "taster_nc",   name: qsTr("Taster (NC)") },
                                        { id: "bimetall_nc", name: qsTr("Bimetall-Kontakt (NC)") }
                                    ]
                                    delegate: Rectangle {
                                        width: parent.width; height: 28; radius: 3
                                        color: pickerMA.containsMouse ? root.theme.activeItem : "transparent"
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            Text {
                                                text: modelData.name
                                                font.pixelSize: 11; color: root.theme.textPrimary
                                                Layout.fillWidth: true
                                            }
                                        }
                                        MouseArea {
                                            id: pickerMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                kontaktPicker.close()
                                                root.betriebsmittelKontaktPlatzieren(
                                                    geraetItem.bmId,
                                                    modelData.id,
                                                    geraetItem.bmKz,
                                                    {}
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Hover-MA zuerst → RowLayout-Kinder liegen darüber
                        MouseArea {
                            id: geraetMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var bid = geraetItem.bmId
                                var auf = Object.assign({}, root._geraeteAufgeklappt)
                                auf[bid] = !auf[bid]
                                if (auf[bid] && root._mitgliederCache[bid] === undefined) {
                                    var c = Object.assign({}, root._mitgliederCache)
                                    c[bid] = db.betriebsmittelMitgliederMitPos(bid)
                                    root._mitgliederCache = c
                                }
                                root._geraeteAufgeklappt = auf
                            }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                            spacing: 5
                            Text { text: geraetItem.aufgeklappt ? "▾" : "▸"; font.pixelSize: 9; color: root.theme.textMuted }
                            Text { text: "⚙"; font.pixelSize: 12; color: root.theme.textMuted }
                            Text {
                                text: "-" + geraetItem.bmKz + (geraetItem.bmBez ? "  " + geraetItem.bmBez : "")
                                font.pixelSize: 12; color: root.theme.textPrimary
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.anzahl
                                font.pixelSize: 10; color: root.theme.textMuted
                            }
                            // Kontakt-hinzufügen-Button
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                color: plusMA.containsMouse ? root.theme.activeItemAlt : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"; font.pixelSize: 14; font.bold: true
                                    color: root.theme.accent
                                }
                                ToolTip.visible: plusMA.containsMouse
                                ToolTip.text:    qsTr("Kontakt platzieren")
                                ToolTip.delay:   400
                                MouseArea {
                                    id: plusMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { mouse.accepted = true; kontaktPicker.open() }
                                }
                            }
                        }
                    }

                    // Mitglieder-Liste
                    Column {
                        width: parent.width
                        visible: geraetItem.aufgeklappt
                        property var mitglieder: root._mitgliederCache[geraetItem.bmId] || []

                        Repeater {
                            model: parent.mitglieder
                            delegate: Rectangle {
                                width: parent.width; height: 26
                                color: mitgliedMA.containsMouse ? root.theme.hover : "transparent"
                                property var md: modelData

                                // Hover-MA zuerst → Sprung-Button liegt darüber
                                MouseArea {
                                    id: mitgliedMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.ArrowCursor
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                                    spacing: 4
                                    Text {
                                        text: md.istHauptfunktion ? "★" : "◇"
                                        font.pixelSize: 9
                                        color: md.istHauptfunktion ? root.theme.accent : root.theme.textMuted
                                    }
                                    Text {
                                        text: md.symbolId || ""
                                        font.pixelSize: 11; color: root.theme.textSecondary
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Text {
                                        text: md.blattnr || ""
                                        font.pixelSize: 10; color: root.theme.textMuted
                                        elide: Text.ElideRight; Layout.minimumWidth: 0
                                    }
                                    Rectangle {
                                        implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                        color: sprungGMA.containsMouse ? root.theme.accent : "transparent"
                                        Text {
                                            anchors.centerIn: parent; text: "→"; font.pixelSize: 11
                                            color: sprungGMA.containsMouse ? "#ffffff" : root.theme.accent
                                        }
                                        MouseArea {
                                            id: sprungGMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var d = md
                                                if (d && d.seiteId > 0)
                                                    root.sprungAngefordert(d.seiteId, d.blattnr,
                                                                           d.seiteBez, d.weltX, d.weltY)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            } // end geraete Column

            // ── KABEL ────────────────────────────────────
            Column {
            visible: root._aktiveTab === "alles" || root._aktiveTab === "kabel"
            width: parent.width
            property var _kabelListe: root._bauteilBereichOffen && root.projektId >= 0
                ? db.kabelListeMitPos(root.projektId)
                : []

            Rectangle {
                width: parent.width; height: 1; color: root.theme.divider
                visible: root._bauteilBereichOffen
            }

            Rectangle {
                width: parent.width; height: 28; color: "transparent"
                visible: root._bauteilBereichOffen && parent._kabelListe.length === 0
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 6
                    Text { text: "⚡"; font.pixelSize: 11; opacity: 0.35; color: root.theme.textMuted }
                    Text {
                        text: qsTr("Kabel – mit C zeichnen")
                        font.pixelSize: 11; color: root.theme.textMuted; opacity: 0.6
                        Layout.fillWidth: true
                    }
                }
            }

            Repeater {
                model: parent._kabelListe
                delegate: Column {
                    id: kabelItem
                    width: parent.width
                    property int    kId:          modelData.id
                    property string kBez:         modelData.bezeichnung || "–"
                    property string kTyp:         modelData.kabeltyp || ""
                    property bool   aufgeklappt:  root._kabelAufgeklappt[kId] === true

                    // Kabel-Kopfzeile
                    Rectangle {
                        width: parent.width; height: 32
                        color: root._highlightKabelId === kabelItem.kId
                            ? root.theme.activeItem
                            : (kabelKopfMA.containsMouse ? root.theme.hover : "transparent")

                        // kabelKopfMA zuerst → RowLayout-Kinder liegen darüber
                        MouseArea {
                            id: kabelKopfMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var kid = kabelItem.kId
                                var auf = Object.assign({}, root._kabelAufgeklappt)
                                auf[kid] = !auf[kid]
                                if (auf[kid] && root._kabellinienCache[kid] === undefined) {
                                    var c = Object.assign({}, root._kabellinienCache)
                                    c[kid] = db.kabellinienMitPos(kid)
                                    root._kabellinienCache = c
                                }
                                root._kabelAufgeklappt = auf
                            }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                            spacing: 5
                            Text { text: kabelItem.aufgeklappt ? "▾" : "▸"; font.pixelSize: 9; color: root.theme.textMuted }
                            Text { text: "⚡"; font.pixelSize: 11; color: root.theme.textMuted }
                            Text {
                                text: kabelItem.kBez
                                font.pixelSize: 12; color: root.theme.textPrimary
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: kabelItem.kTyp
                                font.pixelSize: 10; color: root.theme.textMuted
                                elide: Text.ElideRight
                                Layout.maximumWidth: 90; Layout.minimumWidth: 0
                            }
                        }
                    }

                    // Kabellinie-Liste (lazy geladen)
                    Column {
                        width: parent.width
                        visible: kabelItem.aufgeklappt
                        property var linien: root._kabellinienCache[kabelItem.kId] || []

                        Repeater {
                            model: parent.linien
                            delegate: Rectangle {
                                width: parent.width; height: 26
                                color: kabelLinieMA.containsMouse ? root.theme.hover : "transparent"
                                property var ld: modelData

                                // Hover-MA zuerst → Sprung-Button liegt darüber
                                MouseArea {
                                    id: kabelLinieMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.ArrowCursor
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                                    spacing: 4
                                    Text {
                                        text: ld.blattnr || ""
                                        font.pixelSize: 11; color: root.theme.textSecondary
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Text {
                                        text: ld.seiteBez || ""
                                        font.pixelSize: 10; color: root.theme.textMuted
                                        Layout.minimumWidth: 0
                                        elide: Text.ElideRight; Layout.maximumWidth: 80
                                    }
                                    Rectangle {
                                        implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                        color: kabelSprungMA.containsMouse ? root.theme.accent : "transparent"
                                        Text {
                                            anchors.centerIn: parent; text: "→"; font.pixelSize: 11
                                            color: kabelSprungMA.containsMouse ? "#ffffff" : root.theme.accent
                                        }
                                        MouseArea {
                                            id: kabelSprungMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var d = ld
                                                root.sprungAngefordert(d.seiteId, d.blattnr,
                                                                       d.seiteBez, d.weltX, d.weltY)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            } // end kabel Column

            // ── GERÄTEKÄSTEN ─────────────────────────────────────
            Column {
            id: gkWrapper
            visible: root._aktiveTab === "alles" || root._aktiveTab === "sonstiges"
            width: parent.width
            property var _gkFlachListe: root._bauteilBereichOffen && root.projektId >= 0
                ? db.geraetekastenListeMitPos(root.projektId)
                : []

            property var _gkGruppiert: {
                var gruppen = {}
                var reihenfolge = []
                var liste = gkWrapper._gkFlachListe
                for (var i = 0; i < liste.length; i++) {
                    var gk = liste[i]
                    var bmk = gk.bmk || ""
                    if (!gruppen[bmk]) {
                        gruppen[bmk] = { bmk: bmk, bezeichnung: gk.bezeichnung || "", instanzen: [] }
                        reihenfolge.push(bmk)
                    }
                    gruppen[bmk].instanzen.push(gk)
                }
                return reihenfolge.map(function(b) { return gruppen[b] })
            }

            Rectangle {
                width: parent.width; height: 1; color: root.theme.divider
                visible: root._bauteilBereichOffen
            }

            Rectangle {
                width: parent.width; height: 28; color: "transparent"
                visible: root._bauteilBereichOffen && parent._gkGruppiert.length === 0
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 6
                    Text { text: "📐"; font.pixelSize: 11; opacity: 0.35; color: root.theme.textMuted }
                    Text {
                        text: qsTr("Geraetekaesten – mit G zeichnen")
                        font.pixelSize: 11; color: root.theme.textMuted; opacity: 0.6
                        Layout.fillWidth: true
                    }
                }
            }

            Repeater {
                model: parent._gkGruppiert
                delegate: Column {
                    id: gkGruppeItem
                    width: parent.width
                    property string gkBmk:  modelData.bmk
                    property string gkBez:  modelData.bezeichnung
                    property var    gkInst: modelData.instanzen
                    property bool   auf:    root._gkAufgeklappt[gkBmk] === true

                    // Gruppen-Kopfzeile (BMK)
                    Rectangle {
                        width: parent.width; height: 32
                        color: gkKopfMA.containsMouse ? root.theme.hover : "transparent"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                            spacing: 5
                            Text { text: gkGruppeItem.auf ? "▾" : "▸"; font.pixelSize: 9; color: root.theme.textMuted }
                            Text { text: "📐"; font.pixelSize: 12; color: root.theme.textMuted }
                            Text {
                                text: gkGruppeItem.gkBmk
                                      + (gkGruppeItem.gkBez ? "  " + gkGruppeItem.gkBez : "")
                                font.pixelSize: 12; color: root.theme.textPrimary
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                visible: gkGruppeItem.gkInst.length > 1
                                text: gkGruppeItem.gkInst.length
                                font.pixelSize: 10; color: root.theme.textMuted
                            }
                        }
                        MouseArea {
                            id: gkKopfMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var b = gkGruppeItem.gkBmk
                                var auf = Object.assign({}, root._gkAufgeklappt)
                                auf[b] = !auf[b]
                                root._gkAufgeklappt = auf
                            }
                        }
                    }

                    // Instanzen-Liste
                    Column {
                        width: parent.width
                        visible: gkGruppeItem.auf

                        Repeater {
                            model: gkGruppeItem.gkInst
                            delegate: Rectangle {
                                width: parent.width; height: 26
                                color: root._highlightGkId === gkd.id
                                    ? root.theme.activeItem
                                    : (gkInstMA.containsMouse ? root.theme.hover : "transparent")
                                property var gkd: modelData

                                MouseArea {
                                    id: gkInstMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.ArrowCursor
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                                    spacing: 4
                                    Text {
                                        text: gkd.blattnr || ""
                                        font.pixelSize: 11; color: root.theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: gkd.seiteBez || ""
                                        font.pixelSize: 10; color: root.theme.textMuted
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                        Layout.maximumWidth: 80
                                    }
                                    Rectangle {
                                        implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                        color: gkSprungMA.containsMouse ? root.theme.accent : "transparent"
                                        Text {
                                            anchors.centerIn: parent; text: "→"; font.pixelSize: 11
                                            color: gkSprungMA.containsMouse ? "#ffffff" : root.theme.accent
                                        }
                                        MouseArea {
                                            id: gkSprungMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var d = gkd
                                                root.sprungAngefordert(d.seiteId, d.blattnr,
                                                                       d.seiteBez, d.weltX, d.weltY)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            } // end gk Column

            // ── BIBLIOTHEK: plain Bauteile mit Symbol ────────────
            Column {
            visible: root._aktiveTab === "alles" || root._aktiveTab === "sonstiges"
            width: parent.width
            property var _bibliothekListe: root._bauteilBereichOffen
                ? bauteilModel.bauteileWithSymbol()
                : []

            Rectangle {
                width: parent.width; height: 1; color: root.theme.divider
                visible: root._bauteilBereichOffen
            }

            Rectangle {
                width: parent.width; height: 28; color: "transparent"
                visible: root._bauteilBereichOffen && parent._bibliothekListe.length === 0
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 6
                    Text { text: "💡"; font.pixelSize: 11; opacity: 0.35; color: root.theme.textMuted }
                    Text {
                        text: qsTr("Bibliothek – Bauteile mit Symbol im Editor anlegen")
                        font.pixelSize: 11; color: root.theme.textMuted; opacity: 0.6
                        Layout.fillWidth: true
                    }
                }
            }

            Repeater {
                model: parent._bibliothekListe
                delegate: Rectangle {
                    width: parent.width; height: 32
                    color: bibMA.containsMouse ? root.theme.hover : "transparent"
                    property var bd: modelData

                    MouseArea { id: bibMA; anchors.fill: parent; hoverEnabled: true }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                        spacing: 5
                        Text { text: "💡"; font.pixelSize: 11; color: root.theme.textMuted }
                        Text {
                            text: bd.bezeichnung || ""
                            font.pixelSize: 12; color: root.theme.textPrimary
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Text {
                            text: bd.symbolId || ""
                            font.pixelSize: 10; color: root.theme.textMuted
                            elide: Text.ElideRight; Layout.maximumWidth: 70
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: bibPlusMA.containsMouse ? root.theme.activeItemAlt : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "+"; font.pixelSize: 14; font.bold: true
                                color: root.theme.accent
                            }
                            ToolTip.visible: bibPlusMA.containsMouse
                            ToolTip.text:    qsTr("Auf Canvas platzieren")
                            ToolTip.delay:   400
                            MouseArea {
                                id: bibPlusMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mouse.accepted = true
                                    root.bauteilPlatzieren(bd.bauteilId, bd.symbolId, bd.bezeichnung)
                                }
                            }
                        }
                    }
                }
            }
            } // end bibliothek Column
        }
    }
}
