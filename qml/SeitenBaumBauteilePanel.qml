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

    readonly property bool offen: _bauteilBereichOffen

    signal klemmenAnschlussPlatzieren(int klemmeId, int bauteilKlemmeId,
                                      string anschlussBezeichnung, string bmk)

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

    function reset() {
        root._klemmenCache        = {}
        root._anschluesseCache    = {}
        root._leistenAufgeklappt  = {}
        root._klemmenAufgeklappt  = {}
        root._bauteilBereichOffen = false
        root._platziert           = {}
    }

    Layout.fillWidth: true
    spacing: 0

    // ── Trennlinie ──────────────────────────────────────────
    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.borderDark }

    // ── BAUTEILE Header (immer sichtbar) ────────────────────
    Rectangle {
        Layout.fillWidth: true; height: 36
        color: bauteilHeaderArea.containsMouse ? root.theme.hover : "transparent"
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 6
            Text {
                text: qsTr("BAUTEILE"); font.pixelSize: 10; font.weight: Font.Medium
                color: root.theme.textMuted; Layout.fillWidth: true
            }
            Text { text: root._bauteilBereichOffen ? "▲" : "▼"; font.pixelSize: 9; color: root.theme.textMuted }
        }
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
        DebugLabel { panelName: qsTr("BAUTEILE-Bereich (Seitenbaum)"); visible: root.debug }
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
        Layout.fillWidth: true; Layout.preferredHeight: 220
        visible: root._bauteilBereichOffen; clip: true
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
                    property bool   offen:       root._leistenAufgeklappt[leisteId] === true

                    // Leisten-Zeile
                    Rectangle {
                        width: parent.width; height: 32
                        color: leisteMA.containsMouse ? root.theme.hover : "transparent"
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
                        }
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
                                    width: parent.width; height: 30
                                    color: klemmeMA.containsMouse && klemmeItem.hatBauteil ? root.theme.hover : "transparent"
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
                                            }
                                            MouseArea {
                                                id: anschlussMA; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: parent.platziert ? Qt.ForbiddenCursor : Qt.PointingHandCursor
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

            // ── Kabel-Platzhalter ──────────────────────────
            Rectangle {
                width: parent.width; height: 32; color: "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 6
                    Text { text: "🔗"; font.pixelSize: 12; opacity: 0.4 }
                    Text {
                        text: qsTr("Kabel  (noch nicht verfügbar)")
                        font.pixelSize: 12; color: root.theme.borderDark; Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
