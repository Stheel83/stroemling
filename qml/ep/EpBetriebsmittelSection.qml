import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height: {
        if (!panel.el || panel.el.typ !== "symbol") return 0
        var sid = panel.el.symbolId || ""
        var verbEl = ["winkel","treffpunkt","treffpunkt_l","geraeteanschluss","unterbrechung","querverweis","aderdefinition"]
        for (var k = 0; k < verbEl.length; k++) if (sid === verbEl[k]) return 0
        return bmkCol.implicitHeight
    }
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    component SchriftgrosseSelektor: Item {
        id: sgRoot
        property real wert: 2.5
        signal wertGeaendert(real neuerWert)

        readonly property var  schritte: [1.5, 2.0, 2.5, 3.5, 5.0, 7.0, 10.0, 15.0, 20.0, 30.0, 40.0]
        readonly property int  aktIdx: {
            var best = 0, bestD = 9999
            for (var i = 0; i < schritte.length; i++) {
                var d = Math.abs(schritte[i] - wert)
                if (d < bestD) { bestD = d; best = i }
            }
            return best
        }

        width: parent.width; height: 32

        Row {
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgKlMa.containsMouse ? theme.border : theme.inputBg
                border.color: sgRoot.aktIdx > 0 ? theme.border : theme.divider
                Text { anchors.centerIn: parent; text: qsTr("◄"); font.pixelSize: 11
                       color: sgRoot.aktIdx > 0 ? theme.accent : theme.borderDark }
                MouseArea {
                    id: sgKlMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; enabled: sgRoot.aktIdx > 0
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx - 1])
                }
            }
            Rectangle {
                width: 60; height: 28; radius: 4
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; color: theme.textSecondary; font.pixelSize: 11
                       text: sgRoot.wert.toFixed(1) + " mm" }
            }
            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgGrMa.containsMouse ? theme.border : theme.inputBg
                border.color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? theme.border : theme.divider
                Text { anchors.centerIn: parent; text: qsTr("►"); font.pixelSize: 11
                       color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? theme.accent : theme.borderDark }
                MouseArea {
                    id: sgGrMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: sgRoot.aktIdx < sgRoot.schritte.length - 1
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx + 1])
                }
            }
        }
    }

    Column {
        id: bmkCol
        width: parent.width
        spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("BETRIEBSMITTEL") }

        // ── BMK ──────────────────────────────────
        FeldLabel { text: qsTr("Betriebsmittelkennzeichen (BMK)") }
        Row {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            Rectangle {
                width: parent.width - 36
                height: 28; color: theme.inputBg; radius: 3
                border.color: bmkEdit.activeFocus ? theme.accent : theme.border

                TextInput {
                    id: bmkEdit
                    anchors { fill: parent; margins: 5 }
                    color: theme.textSecondary; font.pixelSize: 11
                    verticalAlignment: TextInput.AlignVCenter

                    text: (panel.el && panel.el.extraDaten)
                          ? (panel.el.extraDaten.bmk || "") : ""
                    Binding on text {
                        when: !bmkEdit.activeFocus
                        value: (panel.el && panel.el.extraDaten)
                               ? (panel.el.extraDaten.bmk || "") : ""
                    }
                    onEditingFinished: root.extraSetzen("bmk", text.trim())
                    Keys.onEscapePressed: focus = false
                }
            }

            // # = nächste freie Nummer vorschlagen
            Rectangle {
                width: 28; height: 28; radius: 3
                color: autoMa.containsMouse ? theme.border : theme.inputBg
                border.color: theme.border
                Text {
                    anchors.centerIn: parent
                    text: "#"; color: theme.accent; font.pixelSize: 13; font.bold: true
                }
                ToolTip.visible: autoMa.containsMouse
                ToolTip.text: qsTr("Nächste freie Nummer vorschlagen")
                ToolTip.delay: 400
                MouseArea {
                    id: autoMa
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (panel.canvas.projektId < 0) return
                        var bmk = (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmk)
                                  ? panel.el.extraDaten.bmk : ""
                        var praefix = bmk.replace(/\d+$/, "")
                        if (!praefix) praefix = "-?"
                        var vorschlag = db.naechsteBmkNummer(panel.canvas.projektId, praefix)
                        root.extraSetzen("bmk", vorschlag)
                    }
                }
            }
        }
        Item { height: 6 }

        // ── Verknüpfung (Haupt-/Nebenfunktion) ───────
        FeldLabel { text: qsTr("Geräteverknüpfung") }
        Item {
            id: verknuepfungItem
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: verknuepfungCol.implicitHeight

            property int bmId: (panel.el && panel.el.betriebsmittelId > 0)
                               ? panel.el.betriebsmittelId : 0

            property int _refresh: 0

            property var bmInfo: {
                _refresh
                return bmId > 0 ? db.betriebsmittelInfo(bmId) : ({})
            }

            property bool istHauptfunktion: bmId > 0
                                            && bmInfo.hauptElementId > 0
                                            && bmInfo.hauptElementId === (panel.el ? panel.el.id : -1)
            property bool hauptfunktionFehlt: bmId > 0 && (bmInfo.hauptElementId || 0) === 0

            Column {
                id: verknuepfungCol
                width: parent.width
                spacing: 4

                // ── Status-Zeile ──────────────────────────
                Rectangle {
                    width: parent.width; height: 28
                    color: theme.inputBg; radius: 3
                    border.color: {
                        if (verknuepfungItem.istHauptfunktion) return theme.accent
                        if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                        return theme.border
                    }
                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!verknuepfungItem.bmId)             return "○"
                                if (verknuepfungItem.istHauptfunktion)  return "★"
                                if (verknuepfungItem.hauptfunktionFehlt) return "⚠"
                                return "◆"
                            }
                            font.pixelSize: 11
                            color: {
                                if (verknuepfungItem.istHauptfunktion)   return theme.accent
                                if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                                if (verknuepfungItem.bmId > 0)           return theme.textSecondary
                                return theme.borderLight
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: verknuepfungItem.bmId > 0
                                  ? (verknuepfungItem.bmInfo.kz || "–") : ""
                            font.pixelSize: 11; font.bold: verknuepfungItem.istHauptfunktion
                            color: theme.accent
                            visible: verknuepfungItem.bmId > 0
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!verknuepfungItem.bmId)               return qsTr("nicht verknüpft")
                                if (verknuepfungItem.istHauptfunktion)    return qsTr("Hauptfunktion")
                                if (verknuepfungItem.hauptfunktionFehlt)  return qsTr("HF nicht platziert")
                                return qsTr("Nebenfunktion")
                            }
                            font.pixelSize: 10
                            color: {
                                if (verknuepfungItem.istHauptfunktion)   return theme.accent
                                if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                                if (verknuepfungItem.bmId > 0)           return theme.textMuted
                                return theme.borderLight
                            }
                        }
                    }
                }

                // ── Aktions-Buttons Zeile 1: Verknüpfen / Trennen ──
                Row {
                    spacing: 4
                    Rectangle {
                        width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                        color: verknLinkMa.containsMouse ? theme.border : theme.inputBg
                        border.color: theme.border
                        Text { anchors.centerIn: parent; text: qsTr("Verknüpfen …")
                               font.pixelSize: 10; color: theme.accent }
                        MouseArea {
                            id: verknLinkMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: dlgVerknuepfen.open()
                        }
                    }
                    Rectangle {
                        width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                        color: verknTrennenMa.containsMouse ? theme.border : theme.inputBg
                        border.color: theme.border
                        opacity: verknuepfungItem.bmId > 0 ? 1.0 : 0.4
                        Text { anchors.centerIn: parent; text: qsTr("Trennen")
                               font.pixelSize: 10; color: theme.borderLight }
                        MouseArea {
                            id: verknTrennenMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: verknuepfungItem.bmId > 0
                            onClicked: {
                                db.grafikElementEntknuepfen(panel.el.id)
                                panel.canvas.eigenschaftAktualisieren("betriebsmittelId", 0)
                            }
                        }
                    }
                }

                // ── Aktions-Buttons Zeile 2: Hauptfunktion / BMK-Sync ──
                Row {
                    visible: verknuepfungItem.bmId > 0
                    spacing: 4
                    Rectangle {
                        width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                        color: hfMa.containsMouse && !verknuepfungItem.istHauptfunktion
                               ? theme.border : theme.inputBg
                        border.color: verknuepfungItem.istHauptfunktion ? theme.accent : theme.border
                        opacity: verknuepfungItem.istHauptfunktion ? 0.5 : 1.0
                        Text {
                            anchors.centerIn: parent
                            text: "★ " + qsTr("Als HF festlegen")
                            font.pixelSize: 10
                            color: verknuepfungItem.istHauptfunktion ? theme.accent : theme.textMuted
                        }
                        MouseArea {
                            id: hfMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: !verknuepfungItem.istHauptfunktion
                            onClicked: {
                                db.betriebsmittelHauptfunktionSetzen(
                                    verknuepfungItem.bmId, panel.el.id)
                                verknuepfungItem._refresh++
                                panel.canvas.hfKarteAktualisieren()
                            }
                        }
                    }
                    Rectangle {
                        width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                        color: syncMa.containsMouse ? theme.border : theme.inputBg
                        border.color: theme.border
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("BMK sync.")
                            font.pixelSize: 10; color: theme.textMuted
                        }
                        ToolTip.visible: syncMa.containsMouse
                        ToolTip.text:    qsTr("BMK aller verknüpften Elemente auf\n\"%1\" setzen").arg(
                                             verknuepfungItem.bmInfo.kz || "")
                        ToolTip.delay:   500
                        MouseArea {
                            id: syncMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                db.betriebsmittelBmkSynchronisieren(verknuepfungItem.bmId)
                                panel.canvas.seiteNeuLaden()
                                verknuepfungItem._refresh++
                            }
                        }
                    }
                }

                // ── Mitglieder-Liste ──────────────────────
                Column {
                    visible: verknuepfungItem.bmId > 0
                    width: parent.width
                    spacing: 1
                    Repeater {
                        model: verknuepfungItem.bmId > 0
                               ? db.betriebsmittelMitglieder(verknuepfungItem.bmId) : []
                        delegate: Rectangle {
                            width: verknuepfungItem.width; height: 22
                            color: modelData.id === (panel.el ? panel.el.id : -1)
                                   ? theme.activeItemAlt : "transparent"
                            radius: 2
                            Row {
                                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                spacing: 5
                                Rectangle {
                                    width: 3; height: 14; radius: 1
                                    color: modelData.id === (panel.el ? panel.el.id : -1)
                                           ? theme.accent : "transparent"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.istHauptfunktion ? "★" : "◆"
                                    font.pixelSize: 9
                                    color: modelData.istHauptfunktion ? theme.accent : theme.borderLight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.symbolId || modelData.typ || "–"
                                    font.pixelSize: 9; color: theme.borderLight
                                    width: 52; elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.blattnummer || "–"
                                    font.pixelSize: 9; color: theme.textMuted
                                    width: 26; elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
        Item { height: 4 }

        // ── Kontakt: Anschlusskennzeichnung + Modifier ──────
        Item {
            id: kontaktItem
            width: parent.width
            readonly property var _KONTAKT_SYMS: [
                "schliesser","oeffner","wechsler",
                "taster_no","taster_nc","not_halt","bimetall_nc"
            ]
            readonly property bool _istKontakt: {
                if (!panel.el || panel.el.typ !== "symbol") return false
                var sid = panel.el.symbolId || ""
                for (var k = 0; k < _KONTAKT_SYMS.length; k++)
                    if (sid === _KONTAKT_SYMS[k]) return true
                return false
            }
            readonly property var _erw: {
                var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                return Array.isArray(ed.erweiterungen) ? ed.erweiterungen : []
            }
            height: _istKontakt ? kontaktCol.implicitHeight : 0
            visible: height > 0; clip: true

            function hatErw(key) {
                return kontaktItem._erw.indexOf(key) >= 0
            }
            function toggleErw(key) {
                var ed = panel.el && panel.el.extraDaten
                         ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                var arr = Array.isArray(ed.erweiterungen) ? ed.erweiterungen.slice() : []
                var idx = arr.indexOf(key)
                if (idx >= 0) arr.splice(idx, 1)
                else          arr.push(key)
                ed.erweiterungen = arr
                panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
            }

            Column {
                id: kontaktCol
                width: parent.width
                spacing: 0

                Trennlinie {}
                AbschnittTitel { text: qsTr("KONTAKT") }

                InputField {
                    label: qsTr("Anschlusskennzeichnung")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.anschlusskennzeichnung || "") : ""
                    theme: theme
                    onCommit: function(t) { root.extraSetzen("anschlusskennzeichnung", t.trim()) }
                }
                Item { height: 6 }

                FeldLabel { text: qsTr("Erweiterungen") }
                Repeater {
                    model: [
                        { key: "zeit_an",    label: qsTr("Anzugsverzögert")  },
                        { key: "zeit_ab",    label: qsTr("Abfallverzögert")  },
                        { key: "voreilung",  label: qsTr("Voreilung")         },
                        { key: "nacheilung", label: qsTr("Nacheilung")        }
                    ]
                    Row {
                        width: kontaktCol.width
                        leftPadding: 12; height: 28; spacing: 8
                        Rectangle {
                            width: 18; height: 18; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: kontaktItem.hatErw(modelData.key) ? theme.accent : theme.inputBg
                            border.color: theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "✓"; color: "#ffffff"; font.pixelSize: 11
                                visible: kontaktItem.hatErw(modelData.key)
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: kontaktItem.toggleErw(modelData.key)
                            }
                        }
                        Text {
                            text: modelData.label
                            color: theme.textMuted; font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                Item { height: 4 }
            }
        }

        // ── Beschriftungszeilen (Reihenfolge + Sichtbarkeit) ──
        Trennlinie {}
        AbschnittTitel { text: qsTr("BESCHRIFTUNGSZEILEN") }

        Item {
            width: parent.width; height: 18
            Text {
                anchors { left: parent.left; leftMargin: 12
                          verticalCenter: parent.verticalCenter }
                text: qsTr("BMK  –  erste Zeile (fest)")
                color: theme.borderLight; font.pixelSize: 10; font.italic: true
            }
        }

        Repeater {
            id: ftRepeater
            model: {
                var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                return ed.textReihenfolge || ["freitext1", "freitext2"]
            }

            Item {
                id: ftZeileRoot
                width:  bmkCol.width
                height: ftZeileCol.implicitHeight

                readonly property string ftKey:      modelData
                readonly property int    ftPos:      index
                readonly property bool   ftSichtbar: {
                    var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                    return ed[ftKey + "Sichtbar"] !== false
                }
                readonly property string ftLabel:    ftKey === "freitext1" ? "Typ / Bezeichnung" : "Bemerkung"
                readonly property string ftWert: {
                    var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                    return ed[ftKey] || ""
                }

                function setWert(v) {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[ftKey] = v
                    panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
                function toggleSichtbar() {
                    var ed = panel.el && panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed[ftKey + "Sichtbar"] = !ftSichtbar
                    panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
                function verschiebeUm(delta) {
                    var ed  = panel.el && panel.el.extraDaten
                              ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    var arr = (ed.textReihenfolge || ["freitext1", "freitext2"]).slice()
                    var ziel = ftPos + delta
                    if (ziel < 0 || ziel >= arr.length) return
                    var tmp = arr[ziel]; arr[ziel] = arr[ftPos]; arr[ftPos] = tmp
                    ed.textReihenfolge = arr
                    panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
                }

                Column {
                    id: ftZeileCol
                    width: parent.width
                    spacing: 2

                    FeldLabel { text: ftZeileRoot.ftLabel }

                    Row {
                        anchors { left: parent.left; leftMargin: 8
                                  right: parent.right; rightMargin: 8 }
                        spacing: 4

                        Rectangle {
                            width: 26; height: 26; radius: 3
                            color: visMa.containsMouse ? theme.border : theme.inputBg
                            border.color: theme.border
                            ToolTip.visible: visMa.containsMouse
                            ToolTip.text:    ftZeileRoot.ftSichtbar ? "Zeile ausblenden" : "Zeile einblenden"
                            ToolTip.delay:   400
                            Text {
                                anchors.centerIn: parent
                                text:  ftZeileRoot.ftSichtbar ? "👁" : "⃠"
                                color: ftZeileRoot.ftSichtbar ? theme.accent : theme.borderDark
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: visMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ftZeileRoot.toggleSichtbar()
                            }
                        }

                        Rectangle {
                            width: parent.width - 26 - 22 - 22 - 3 * 4
                            height: 26; radius: 3
                            color: theme.inputBg
                            border.color: ftEdit.activeFocus ? theme.accent : theme.border
                            opacity: ftZeileRoot.ftSichtbar ? 1.0 : 0.45
                            TextInput {
                                id: ftEdit
                                anchors { fill: parent; margins: 5 }
                                color: theme.textSecondary; font.pixelSize: 11
                                verticalAlignment: TextInput.AlignVCenter
                                text: ftZeileRoot.ftWert
                                Binding on text {
                                    when: !ftEdit.activeFocus
                                    value: ftZeileRoot.ftWert
                                }
                                onEditingFinished: ftZeileRoot.setWert(text.trim())
                                Keys.onEscapePressed: focus = false
                            }
                        }

                        Rectangle {
                            width: 22; height: 26; radius: 3
                            color: upMa.containsMouse && ftZeileRoot.ftPos > 0
                                   ? theme.border : theme.inputBg
                            border.color: ftZeileRoot.ftPos > 0 ? theme.border : theme.divider
                            Text {
                                anchors.centerIn: parent; text: qsTr("▲"); font.pixelSize: 9
                                color: ftZeileRoot.ftPos > 0 ? theme.accent : theme.borderDark
                            }
                            MouseArea {
                                id: upMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: ftZeileRoot.ftPos > 0
                                onClicked: ftZeileRoot.verschiebeUm(-1)
                            }
                        }

                        Rectangle {
                            width: 22; height: 26; radius: 3
                            color: downMa.containsMouse
                                   && ftZeileRoot.ftPos < ftRepeater.count - 1
                                   ? theme.border : theme.inputBg
                            border.color: ftZeileRoot.ftPos < ftRepeater.count - 1
                                          ? theme.border : theme.divider
                            Text {
                                anchors.centerIn: parent; text: qsTr("▼"); font.pixelSize: 9
                                color: ftZeileRoot.ftPos < ftRepeater.count - 1
                                       ? theme.accent : theme.borderDark
                            }
                            MouseArea {
                                id: downMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: ftZeileRoot.ftPos < ftRepeater.count - 1
                                onClicked: ftZeileRoot.verschiebeUm(1)
                            }
                        }
                    }
                    Item { height: 4 }
                }
            }
        }
        Item { height: 2 }

        // ── Schriftgröße ──────────────────────────
        Trennlinie {}
        AbschnittTitel { text: qsTr("SCHRIFTGRÖSSE") }
        SchriftgrosseSelektor {
            wert: (panel.el && panel.el.extraDaten
                   && panel.el.extraDaten.schriftgroesse !== undefined)
                  ? panel.el.extraDaten.schriftgroesse : 2.5
            onWertGeaendert: function(v) { root.extraSetzen("schriftgroesse", v) }
        }

        AbschnittTitel { text: qsTr("BESCHRIFTUNGSPOSITION") }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Column {
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Versatz X"); color: theme.panelMid; font.pixelSize: 10
                }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: theme.inputBg
                        border.color: bmkOxTf.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: bmkOxTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator {
                                bottom: -999; top: 999; decimals: 1
                                notation: DoubleValidator.StandardNotation
                            }
                            property real weltWert: (panel.el && panel.el.extraDaten
                                && panel.el.extraDaten.bmkOffsetX !== undefined)
                                ? panel.el.extraDaten.bmkOffsetX : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text {
                                when: !bmkOxTf.activeFocus
                                value: (bmkOxTf.weltWert / panel.canvas.mmToPx).toFixed(1)
                            }
                            onEditingFinished: {
                                var v = parseFloat(text)
                                if (!isNaN(v)) root.extraSetzen("bmkOffsetX", v * panel.canvas.mmToPx)
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: theme.borderLight; font.pixelSize: 10
                           anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Column {
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Versatz Y"); color: theme.panelMid; font.pixelSize: 10
                }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: theme.inputBg
                        border.color: bmkOyTf.activeFocus ? theme.accent : theme.border
                        TextInput {
                            id: bmkOyTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator {
                                bottom: -999; top: 999; decimals: 1
                                notation: DoubleValidator.StandardNotation
                            }
                            property real weltWert: (panel.el && panel.el.extraDaten
                                && panel.el.extraDaten.bmkOffsetY !== undefined)
                                ? panel.el.extraDaten.bmkOffsetY : -14
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text {
                                when: !bmkOyTf.activeFocus
                                value: (bmkOyTf.weltWert / panel.canvas.mmToPx).toFixed(1)
                            }
                            onEditingFinished: {
                                var v = parseFloat(text)
                                if (!isNaN(v)) root.extraSetzen("bmkOffsetY", v * panel.canvas.mmToPx)
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: theme.borderLight; font.pixelSize: 10
                           anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Item { height: 4 }
    }

    // ── Dialog: Betriebsmittel verknüpfen ────────────────────
    Dialog {
        id:    dlgVerknuepfen
        title: qsTr("Geräteverknüpfung")
        width: 340
        anchors.centerIn: Overlay.overlay
        modal: true

        property int gewaehltId: 0

        background: Rectangle {
            color:  theme.sidebar
            border.color: theme.border
            border.width: 1; radius: 6
        }

        header: Item {
            height: 36
            Text {
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                text: qsTr("Geräteverknüpfung")
                color: theme.accent
                font.pixelSize: 13; font.weight: Font.Medium
            }
        }

        onOpened: {
            dlgVerknuepfen.gewaehltId = panel.el ? (panel.el.betriebsmittelId || 0) : 0
            neuKzField.text = (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "") : ""
            neuBezField.text = ""
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: {
            if (!panel.el) return
            var zielId = dlgVerknuepfen.gewaehltId
            var zielKz = ""
            if (zielId <= 0 && neuKzField.text.trim() !== "") {
                zielKz = neuKzField.text.trim()
                zielId = db.betriebsmittelAnlegen(panel.canvas.projektId, zielKz, neuBezField.text.trim())
            } else if (zielId > 0) {
                zielKz = db.betriebsmittelKz(zielId)
            }
            if (zielId > 0) {
                db.grafikElementVerknuepfen(panel.el.id, zielId)
                panel.canvas.eigenschaftAktualisieren("betriebsmittelId", zielId)
                if (zielKz !== "") {
                    var ed = panel.el.extraDaten
                             ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                    ed["bmk"] = zielKz
                    panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
                }
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: 8

            Text {
                text: qsTr("Vorhandenes Betriebsmittel wählen:")
                color: theme.textBright; font.pixelSize: 11
            }

            ListView {
                id: bmListe
                Layout.fillWidth: true
                height: Math.min(contentHeight, 160)
                clip: true
                model: panel.canvas.projektId >= 0 ? db.betriebsmittelListe(panel.canvas.projektId) : []

                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    width: bmListe.width; height: 28; radius: 3
                    color: dlgVerknuepfen.gewaehltId === modelData.id
                           ? theme.activeItemAlt
                           : (bmDelegMa.containsMouse ? theme.hover : "transparent")
                    border.color: dlgVerknuepfen.gewaehltId === modelData.id
                                  ? theme.accent : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: modelData.kz; font.pixelSize: 12; color: theme.accent; width: 80; elide: Text.ElideRight }
                        Text { text: modelData.bezeichnung || ""; font.pixelSize: 11; color: theme.textMuted }
                        Text { text: modelData.anzahl > 0 ? "(" + modelData.anzahl + ")" : ""; font.pixelSize: 10; color: theme.borderLight }
                    }
                    MouseArea {
                        id: bmDelegMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { dlgVerknuepfen.gewaehltId = modelData.id; neuKzField.text = "" }
                    }
                }
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

            Text {
                text: qsTr("… oder neues Betriebsmittel anlegen:")
                color: theme.textBright; font.pixelSize: 11
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                TextField {
                    id: neuKzField
                    placeholderText: qsTr("BMK z.B. -K1")
                    Layout.preferredWidth: 100
                    background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                    color: theme.textPrimary; font.pixelSize: 11
                    onTextChanged: if (text.trim() !== "") dlgVerknuepfen.gewaehltId = 0
                }
                TextField {
                    id: neuBezField
                    placeholderText: qsTr("Bezeichnung (optional)")
                    Layout.fillWidth: true
                    background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                    color: theme.textPrimary; font.pixelSize: 11
                }
            }

            Text {
                visible: dlgVerknuepfen.gewaehltId > 0
                text: qsTr("Das BMK wird vom gewählten Betriebsmittel übernommen.")
                color: theme.textMuted; font.pixelSize: 10; font.italic: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
