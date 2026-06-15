import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var theme

    property int projektId: -1
    property int seiteId:   -1

    // Referenz auf den rechts platzierten SchaltplanCanvas
    property var canvas: null

    // Gültig sobald canvas eine Verbindung hat
    readonly property int    pfadAnzahl:        canvas ? Object.keys(canvas.fehlersuchPfadIds).length : 0
    readonly property var    querverweise:       canvas ? canvas.fehlersuchQuerverweise : []
    readonly property var    unterbrechungen:    canvas ? canvas.fehlersuchUnterbrechungen : {}
    readonly property var    unterbrechungsIds:  canvas ? Object.keys(canvas.fehlersuchUnterbrechungen) : []

    // Elemente im Pfad gruppiert nach Rolle (reine QML-Logik, kein DB-Zugriff)
    property bool elementeAusgeklappt: true
    readonly property var pfadElemente: {
        if (!canvas || pfadAnzahl === 0)
            return { quellen: [], schalter: [], verbraucher: [] }
        var alle     = canvas.elementeModel.snapshot()
        var pfadSet  = canvas.fehlersuchPfadIds
        var quellen  = [], schalter = [], verbraucher = []
        for (var i = 0; i < alle.length; i++) {
            var el  = alle[i]
            if (!pfadSet[el.id || -1]) continue
            if (el.typ !== "symbol")   continue
            var bmk = (el.extraDaten || {}).bmk || ""
            if (!bmk) continue
            var rolle = symbolDefinitionModel.rolleForSymbol(el.symbolId || "")
            if      (rolle === "quelle")     quellen.push(bmk)
            else if (rolle === "trenner")    schalter.push(bmk)
            else if (rolle === "verbraucher") verbraucher.push(bmk)
        }
        return { quellen: quellen, schalter: schalter, verbraucher: verbraucher }
    }

    signal querverweisNavigieren(int seiteId, real x, real y, int partnerId)
    signal fehlersuchNavigieren(int seiteId, real cx, real cy, int elementId)
    signal geschlossen()

    property bool autoWeiterverfolgen: false

    // ── Strg+F Suche ─────────────────────────────────────────────
    property bool   suchfeldAktiv: false
    property var    _fsEintraege:  []
    property string _fsSuchText:   ""

    readonly property var _fsGefiltert: {
        var q = root._fsSuchText.trim().toLowerCase()
        if (q.length < 1) return []
        return root._fsEintraege.filter(function(e) {
            return e.label.toLowerCase().indexOf(q) >= 0
        }).slice(0, 8)
    }

    function suchfeldOeffnen() {
        if (root.projektId >= 0)
            root._fsEintraege = db.spotlightEintraege(root.projektId).filter(
                function(e) { return e.kategorie === "BMK" })
        root._fsSuchText   = ""
        root.suchfeldAktiv = true
        fsTextInput.forceActiveFocus()
    }

    function _navigiereZuEintrag(eintrag) {
        root.suchfeldAktiv = false
        root.fehlersuchNavigieren(eintrag.seiteId || -1, eintrag.cx || 0,
                                   eintrag.cy || 0, eintrag.elementId || -1)
    }

    // ── Escape: Pfad aufheben ─────────────────────────────────
    Keys.onEscapePressed: { if (canvas) canvas.fehlersuchPfadZuruecksetzen() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: theme.surfaceDeep

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                spacing: 6

                Text {
                    text: qsTr("Fehlersuchmodus")
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: theme.textPrimary
                    Layout.fillWidth: true
                }

                // Toggle: Auto-Weiterverfolgen auf Zielseite
                Rectangle {
                    implicitWidth: autoToggleRow.implicitWidth + 12
                    implicitHeight: 24
                    radius: 4
                    color: root.autoWeiterverfolgen ? theme.accent : "transparent"
                    border.color: root.autoWeiterverfolgen ? theme.accent : theme.border
                    ToolTip.visible: autoToggleMaus.containsMouse
                    ToolTip.text: qsTr("Auto-Weiterverfolgen: BFS nach Querverweis-Sprung automatisch starten")
                    ToolTip.delay: 600

                    RowLayout {
                        id: autoToggleRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "⇒"
                            font.pixelSize: 11
                            color: root.autoWeiterverfolgen ? "white" : theme.textMuted
                        }
                        Text {
                            text: qsTr("Auto")
                            font.pixelSize: 10
                            color: root.autoWeiterverfolgen ? "white" : theme.textMuted
                        }
                    }

                    MouseArea {
                        id: autoToggleMaus
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.autoWeiterverfolgen = !root.autoWeiterverfolgen
                    }
                }

                Button {
                    flat: true; implicitWidth: 28; implicitHeight: 28
                    contentItem: Text { text: "✕"; color: theme.textMuted; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                    ToolTip.visible: hovered; ToolTip.text: qsTr("Fehlersuchmodus schliessen (Esc)")
                    ToolTip.delay: 600
                    onClicked: root.geschlossen()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Strg+F Suchbereich ────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.suchfeldAktiv
            implicitHeight: fsCol.implicitHeight
            color: theme.surfaceDeep
            clip: true

            Column {
                id: fsCol
                width: parent.width
                spacing: 0

                // Suchfeld
                Rectangle {
                    width: parent.width
                    height: 36
                    color: "transparent"

                    Rectangle {
                        anchors { fill: parent; margins: 6 }
                        color: theme.inputBg
                        radius: 4
                        border.color: fsTextInput.activeFocus ? theme.accent : theme.border
                        border.width: 1

                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                            spacing: 4

                            Text {
                                text: "🔍"
                                font.pixelSize: 11
                                color: theme.textMuted
                            }

                            TextInput {
                                id: fsTextInput
                                Layout.fillWidth: true
                                font.pixelSize: 12
                                color: theme.textPrimary
                                selectedTextColor: "white"
                                selectionColor: theme.accent
                                clip: true
                                onTextChanged:     root._fsSuchText = text
                                Keys.onEscapePressed: {
                                    root.suchfeldAktiv = false
                                    root._fsSuchText   = ""
                                }
                                Keys.onReturnPressed: {
                                    if (root._fsGefiltert.length > 0)
                                        root._navigiereZuEintrag(root._fsGefiltert[0])
                                }
                                Keys.onDownPressed: {
                                    if (root._fsGefiltert.length > 0)
                                        root._navigiereZuEintrag(root._fsGefiltert[0])
                                }
                            }

                            Text {
                                text: "Esc"
                                font.pixelSize: 9
                                color: theme.borderLight
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { root.suchfeldAktiv = false; root._fsSuchText = "" }
                                }
                            }
                        }
                    }
                }

                // Ergebnisliste
                Repeater {
                    model: root._fsGefiltert

                    Rectangle {
                        width: fsCol.width
                        height: 32
                        color: fsMaus.containsMouse ? theme.hover : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 6

                            Text {
                                text: modelData.label || ""
                                font.pixelSize: 12; font.weight: Font.Medium
                                color: theme.textPrimary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: (modelData.blattnummer || "")
                                font.pixelSize: 10
                                color: theme.textMuted
                            }
                        }

                        MouseArea {
                            id: fsMaus
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._navigiereZuEintrag(modelData)
                        }
                    }
                }

                // Hinweis wenn keine Ergebnisse und Suchtext vorhanden
                Item {
                    width: fsCol.width
                    height: 28
                    visible: root._fsSuchText.length > 0 && root._fsGefiltert.length === 0

                    Text {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: qsTr("Kein BMK gefunden")
                        font.pixelSize: 11
                        color: theme.borderLight
                    }
                }

                Rectangle { width: parent.width; height: 1; color: theme.border }
            }
        }

        // ── Pfad-Status ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: theme.surface

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                spacing: 8

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.pfadAnzahl > 0 ? theme.accent : theme.borderLight
                }

                Text {
                    text: root.pfadAnzahl > 0
                        ? qsTr("%1 Elemente im Pfad").arg(root.pfadAnzahl)
                        : qsTr("Kein Pfad aktiv")
                    font.pixelSize: 12
                    color: root.pfadAnzahl > 0 ? theme.textPrimary : theme.textMuted
                    Layout.fillWidth: true
                }

                Button {
                    visible: root.pfadAnzahl > 0
                    flat: true; implicitWidth: 24; implicitHeight: 24
                    contentItem: Text { text: "×"; color: theme.textMuted; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                    ToolTip.visible: hovered; ToolTip.text: qsTr("Hervorhebung aufheben (Esc)")
                    ToolTip.delay: 600
                    onClicked: if (root.canvas) root.canvas.fehlersuchPfadZuruecksetzen()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        // ── Querverweis-Liste ─────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: qvCol.implicitHeight
            clip: true

            ColumnLayout {
                id: qvCol
                width: parent.width
                spacing: 0

                // Anleitung wenn kein Pfad
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 32
                    implicitHeight: anleitungCol.implicitHeight
                    visible: root.pfadAnzahl === 0

                    Column {
                        id: anleitungCol
                        anchors { left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 20 }
                        spacing: 10

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: qsTr("Element oder Leitung anklicken, um den Strompfad von diesem Punkt bis zur nächsten Unterbrechung zu markieren.")
                            font.pixelSize: 12
                            color: theme.textMuted
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: qsTr("Leere Stelle klicken → Markierung aufheben.")
                            font.pixelSize: 11
                            color: theme.borderLight
                        }
                    }
                }

                // Querverweise wenn Pfad aktiv und Querverweis vorhanden
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.leftMargin: 14
                    implicitHeight: qvHeaderText.implicitHeight
                    visible: root.pfadAnzahl > 0 && root.querverweise.length > 0

                    Text {
                        id: qvHeaderText
                        text: qsTr("Pfad führt weiter auf:")
                        font.pixelSize: 11; font.weight: Font.Medium
                        color: theme.textMuted
                    }
                }

                Repeater {
                    model: root.querverweise

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: qvMaus.containsMouse ? theme.hover : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 6

                            Text {
                                text: "⚡"
                                font.pixelSize: 14
                                color: theme.accent
                            }
                            Text {
                                text: modelData.bezeichnung || qsTr("(Querverweis)")
                                font.pixelSize: 12
                                color: theme.textPrimary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: qsTr("Springen →")
                                font.pixelSize: 11
                                color: theme.accent
                                visible: qvMaus.containsMouse && (modelData.nachSeiteId || -1) >= 0
                            }
                        }

                        MouseArea {
                            id: qvMaus
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (modelData.nachSeiteId || -1) >= 0
                                         ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                var nachId = modelData.nachSeiteId || -1
                                if (nachId >= 0)
                                    root.querverweisNavigieren(
                                        nachId,
                                        modelData.zielX || 0,
                                        modelData.zielY || 0,
                                        root.autoWeiterverfolgen ? (modelData.partnerId || -1) : -1)
                            }
                        }
                    }
                }

                // Hinweis wenn Querverweis-Zielseite nicht aufgelöst werden konnte
                Repeater {
                    model: root.querverweise.filter(function(q) {
                        return (q.nachSeiteId || -1) < 0
                    })
                    Item {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        implicitHeight: qvWarnText.implicitHeight + 4

                        Text {
                            id: qvWarnText
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: qsTr("Zielseite für \"%1\" nicht gefunden – Netz neu synchronisieren?")
                                  .arg(modelData.bezeichnung || "?")
                            font.pixelSize: 10
                            color: theme.borderLight
                        }
                    }
                }

                // ── Unterbrechungen (Trenner) ─────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.leftMargin: 14
                    implicitHeight: ubrHeaderText.implicitHeight
                    visible: root.pfadAnzahl > 0 && root.unterbrechungsIds.length > 0

                    Text {
                        id: ubrHeaderText
                        text: qsTr("Pfad unterbrochen bei:")
                        font.pixelSize: 11; font.weight: Font.Medium
                        color: "#e04040"
                    }
                }

                Repeater {
                    model: root.unterbrechungsIds

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 8

                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: "transparent"
                                border.color: "#e04040"
                                border.width: 2
                            }

                            Text {
                                text: root.unterbrechungen[modelData] || qsTr("(Trenner)")
                                font.pixelSize: 12
                                color: "#e04040"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // ── Elemente im Pfad (aufklappbar) ───────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.divider
                    visible: root.pfadAnzahl > 0
                    Layout.topMargin: 8
                }

                // Sektion-Kopfzeile
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    color: elKopfMaus.containsMouse ? theme.hover : "transparent"
                    visible: root.pfadAnzahl > 0

                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                        spacing: 6

                        Text {
                            text: root.elementeAusgeklappt ? "▾" : "▸"
                            font.pixelSize: 10
                            color: theme.textMuted
                        }
                        Text {
                            text: qsTr("Elemente im Pfad")
                            font.pixelSize: 11; font.weight: Font.Medium
                            color: theme.textMuted
                            Layout.fillWidth: true
                        }
                        // Anzahl-Badge
                        Rectangle {
                            visible: (root.pfadElemente.quellen.length +
                                      root.pfadElemente.schalter.length +
                                      root.pfadElemente.verbraucher.length) > 0
                            implicitWidth: badgeText.implicitWidth + 10
                            height: 16; radius: 8
                            color: theme.accent
                            opacity: 0.75
                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: root.pfadElemente.quellen.length +
                                      root.pfadElemente.schalter.length +
                                      root.pfadElemente.verbraucher.length
                                font.pixelSize: 9; font.weight: Font.Bold
                                color: "white"
                            }
                        }
                    }

                    MouseArea {
                        id: elKopfMaus
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.elementeAusgeklappt = !root.elementeAusgeklappt
                    }
                }

                // Gruppen (nur sichtbar wenn ausgeklappt)
                Repeater {
                    model: root.elementeAusgeklappt && root.pfadAnzahl > 0 ? [
                        { icon: "⚡", label: qsTr("Quellen"),      bmks: root.pfadElemente.quellen },
                        { icon: "◻",  label: qsTr("Schaltelemente"), bmks: root.pfadElemente.schalter },
                        { icon: "◉",  label: qsTr("Verbraucher"),  bmks: root.pfadElemente.verbraucher }
                    ].filter(function(g) { return g.bmks.length > 0 }) : []

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        // Gruppen-Header
                        Item {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.topMargin: 6
                            implicitHeight: grpHeaderText.implicitHeight

                            Text {
                                id: grpHeaderText
                                text: modelData.icon + "  " + modelData.label
                                font.pixelSize: 10; font.weight: Font.Medium
                                color: theme.textMuted
                            }
                        }

                        // BMK-Einträge
                        Repeater {
                            model: modelData.bmks

                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                color: "transparent"

                                Text {
                                    anchors { left: parent.left; leftMargin: 28;
                                              verticalCenter: parent.verticalCenter }
                                    text: modelData
                                    font.pixelSize: 11
                                    color: theme.textPrimary
                                }
                            }
                        }
                    }
                }

                // Hinweis wenn keine BMK-Elemente im Pfad
                Item {
                    Layout.fillWidth: true
                    Layout.leftMargin: 28
                    implicitHeight: keineElText.implicitHeight + 4
                    visible: root.elementeAusgeklappt && root.pfadAnzahl > 0 &&
                             root.pfadElemente.quellen.length === 0 &&
                             root.pfadElemente.schalter.length === 0 &&
                             root.pfadElemente.verbraucher.length === 0

                    Text {
                        id: keineElText
                        text: qsTr("Keine BMK-tragenden Elemente")
                        font.pixelSize: 10
                        color: theme.borderLight
                    }
                }

                Item { Layout.fillWidth: true; implicitHeight: 8 }
            }
        }

        // ── Statusleiste ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: theme.surfaceDeep

            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("Klick auf Element → Pfad markieren  ·  Esc → löschen")
                font.pixelSize: 10
                color: theme.borderLight
            }
        }
    }
}
