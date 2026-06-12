import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Item {
    id: root

    // ── Konfiguration ──────────────────────────────────────────────────────
    property int     projektId:        -1
    property string  hintergrundFarbe: "#080f1c"
    required property var theme
    required property var elementeModel
    property bool    debug:            false
    property bool    fokussiert:       false

    // ── Tab-Modell ─────────────────────────────────────────────────────────
    // Jedes Element: { seiteId, blattnummer, bezeichnung }
    property var tabs:        []
    property int aktivTabIdx: -1

    readonly property int aktivSeiteId: (aktivTabIdx >= 0 && aktivTabIdx < tabs.length)
                                        ? tabs[aktivTabIdx].seiteId : -1
    readonly property string aktivSeiteName: {
        if (aktivTabIdx < 0 || aktivTabIdx >= tabs.length) return ""
        var t = tabs[aktivTabIdx]
        return t.bezeichnung.length > 0
               ? t.bezeichnung + "  –  " + t.blattnummer
               : t.blattnummer
    }

    // Direktzugriff auf den inneren SchaltplanCanvas (für Main.qml)
    property alias canvas: innerCanvas

    // ── Signale ────────────────────────────────────────────────────────────
    signal panelAngeklickt()
    signal querverweisNavigieren(int seiteId)
    signal gkSprungAngefordert(int seiteId, string blattnr, string seiteBez, real wx, real wy)
    signal hintergrundGeaendert(string farbe)
    signal makroListeGeaendert()
    signal aktivesWerkzeugGeaendert(string werkzeug)
    signal teilenRechts()
    signal teilenUnten()
    signal panelLeer()
    signal splitSchliessen()
    signal drcKlick()
    signal suchKlick()

    property bool drcAktiv:  false
    property bool suchAktiv: false

    // Wenn true → Split-Schließen-Button erscheint in der Tab-Leiste
    property bool splitSchliessbar: false

    // ── Öffentliche Funktionen ─────────────────────────────────────────────

    // Seite öffnen: falls schon als Tab vorhanden → wechseln; sonst neuer Tab
    function seiteOeffnen(seiteId, blattnummer, bezeichnung) {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].seiteId === seiteId) { aktivTabIdx = i; return }
        }
        _tabHinzufuegen(seiteId, blattnummer, bezeichnung)
    }

    // Seite per ID öffnen (Querverweis): holt Metadaten aus DB
    function seiteOeffnenNachId(seiteId) {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].seiteId === seiteId) { aktivTabIdx = i; return }
        }
        var info = db.seiteBasisDaten(seiteId)
        _tabHinzufuegen(seiteId, info ? (info.blattnummer || "") : "", info ? (info.bezeichnung || "") : "")
    }

    function tabSchliessen(idx) {
        if (tabs.length <= 1) return
        var tmp = tabs.slice()
        tmp.splice(idx, 1)
        tabs = tmp
        if (aktivTabIdx >= tabs.length)  aktivTabIdx = tabs.length - 1
        else if (aktivTabIdx > idx)      aktivTabIdx = aktivTabIdx - 1
        if (tabs.length === 0) root.panelLeer()
    }

    function seiteEntfernen(seiteId) {
        for (var i = tabs.length - 1; i >= 0; i--) {
            if (tabs[i].seiteId === seiteId) { tabSchliessen(i); return }
        }
    }

    function alleTabsSchliessen() {
        tabs = []; aktivTabIdx = -1
    }

    onProjektIdChanged: alleTabsSchliessen()

    function normblattNeuLaden() { innerCanvas.normblattNeuLaden() }

    // Seite öffnen und Canvas auf Weltkoordinaten (wx, wy) zentrieren.
    property real _zentriereX: 0
    property real _zentriereY: 0
    Timer {
        id: zentriereTimer
        interval: 80
        onTriggered: innerCanvas._zoomZuWeltPosition(root._zentriereX, root._zentriereY)
    }
    function seiteOeffnenUndZentrieren(seiteId, blattnummer, bezeichnung, wx, wy) {
        seiteOeffnen(seiteId, blattnummer, bezeichnung)
        root._zentriereX = wx
        root._zentriereY = wy
        zentriereTimer.restart()
    }

    function _tabHinzufuegen(seiteId, blattnummer, bezeichnung) {
        var tmp = tabs.slice()
        tmp.push({ seiteId: seiteId, blattnummer: blattnummer, bezeichnung: bezeichnung })
        tabs = tmp
        aktivTabIdx = tabs.length - 1
    }

    // ── Layout ─────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Tab-Leiste ─────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 32
            color: theme.surfaceDeep

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Tabs (scrollbar bei vielen Tabs)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Row {
                        id: tabRow
                        height: parent.height
                        spacing: 0

                        Repeater {
                            model: tabs
                            delegate: Item {
                                id: tabItem
                                height: tabRow.height
                                property bool aktiv: index === root.aktivTabIdx
                                // Breite: gleichmäßig aufteilen, min 60, max 200
                                width: Math.min(200, Math.max(60,
                                       tabRow.parent.parent.width / Math.max(1, tabs.length)))

                                Rectangle {
                                    anchors.fill: parent
                                    color:        tabItem.aktiv ? theme.surface : "transparent"
                                    border.color: tabItem.aktiv ? theme.accent  : "transparent"
                                    border.width: tabItem.aktiv ? 1 : 0

                                    // Unterstrich für aktiven Tab
                                    Rectangle {
                                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: 2
                                        color:   tabItem.aktiv ? theme.accent : "transparent"
                                    }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                                        spacing: 4

                                        Text {
                                            Layout.fillWidth: true
                                            text: {
                                                var t = modelData
                                                return t.bezeichnung.length > 0
                                                       ? t.bezeichnung + " – " + t.blattnummer
                                                       : t.blattnummer
                                            }
                                            font.pixelSize: 12
                                            color: tabItem.aktiv ? theme.textPrimary : theme.textMuted
                                            elide: Text.ElideRight
                                        }

                                        // × Schließen – nur sichtbar wenn mehr als ein Tab
                                        Rectangle {
                                            width: 16; height: 16; radius: 3
                                            visible: tabs.length > 1
                                            color:   closeHover.hovered ? theme.hover : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"; font.pixelSize: 13
                                                color: theme.textMuted
                                            }
                                            HoverHandler { id: closeHover }
                                            TapHandler { onTapped: root.tabSchliessen(index) }
                                        }
                                    }

                                    TapHandler {
                                        onTapped: {
                                            root.aktivTabIdx = index
                                            root.panelAngeklickt()
                                            innerCanvas.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Teilen-Buttons ──────────────────────────────────────────
                Rectangle {
                    width: 1; Layout.fillHeight: true
                    color: theme.border
                    visible: tabs.length > 0
                }

                RowLayout {
                    spacing: 2
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    visible: tabs.length > 0

                    Button {
                        flat: true; width: 24; height: 24
                        contentItem: Text {
                            text: "□│"; font.pixelSize: 11
                            color: parent.hovered ? theme.textPrimary : theme.textMuted
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment:   Text.AlignVCenter
                        }
                        background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 3 }
                        ToolTip.visible: hovered; ToolTip.delay: 600
                        ToolTip.text: qsTr("Arbeitsbereich rechts teilen – beide Panels sind unabhängig (eigene Tabs, eigene Seite)")
                        onClicked: root.teilenRechts()
                    }

                    Button {
                        flat: true; width: 24; height: 24
                        contentItem: Text {
                            text: "□─"; font.pixelSize: 11
                            color: parent.hovered ? theme.textPrimary : theme.textMuted
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment:   Text.AlignVCenter
                        }
                        background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 3 }
                        ToolTip.visible: hovered; ToolTip.delay: 600
                        ToolTip.text: qsTr("Arbeitsbereich unten teilen – beide Panels sind unabhängig (eigene Tabs, eigene Seite)")
                        onClicked: root.teilenUnten()
                    }

                    // Split-Ansicht schließen
                    Button {
                        flat: true; width: 24; height: 24
                        visible: root.splitSchliessbar
                        contentItem: Text {
                            text: "✕"; font.pixelSize: 11
                            color: parent.hovered ? theme.textPrimary : theme.textMuted
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment:   Text.AlignVCenter
                        }
                        background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 3 }
                        ToolTip.visible: hovered; ToolTip.delay: 600
                        ToolTip.text: qsTr("Geteilte Ansicht schließen")
                        onClicked: root.splitSchliessen()
                    }
                }
            }
        }

        // Trennlinie
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── SchaltplanCanvas ───────────────────────────────────────────────
        SchaltplanCanvas {
            id: innerCanvas
            Layout.fillWidth:  true
            Layout.fillHeight: true
            theme:            root.theme
            debug:            root.debug
            seiteId:          root.aktivSeiteId
            projektId:        root.projektId
            seiteName:        root.aktivSeiteName
            hintergrundFarbe: root.hintergrundFarbe
            elementeModel:    root.elementeModel

            onAktivesWerkzeugChanged:
                root.aktivesWerkzeugGeaendert(innerCanvas.aktivesWerkzeug)
            onHintergrundGeaendert: function(farbe) {
                root.hintergrundGeaendert(farbe)
            }
            onQuerverweisNavigieren: function(seiteId) {
                root.seiteOeffnenNachId(seiteId)
                root.querverweisNavigieren(seiteId)
            }
            onGkSprungAngefordert: function(seiteId, blattnr, seiteBez, wx, wy) {
                root.gkSprungAngefordert(seiteId, blattnr, seiteBez, wx, wy)
            }
            onMakroListeGeaendert: root.makroListeGeaendert()
            onDrcKlick:  root.drcKlick()
            onSuchKlick: root.suchKlick()
            drcAktiv:  root.drcAktiv
            suchAktiv: root.suchAktiv
        }
    }

    // ── Fokus-Rahmen ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        "transparent"
        border.color: root.fokussiert ? root.theme.accent : "transparent"
        border.width: 2
        z: 10
        visible: root.fokussiert
        // transparent Rectangle ohne MouseArea – blockiert keine Events
    }

    // Klick irgendwo → Panel fokussieren
    MouseArea {
        anchors.fill: parent; z: -1
        onPressed: function(mouse) {
            root.panelAngeklickt()
            mouse.accepted = false
        }
    }

    DebugLabel { panelName: "Canvas-Panel"; visible: root.debug }
}
