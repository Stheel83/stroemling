import QtQuick
import QtQuick.Controls
import "../components"
import "../SymbolKlassen.js" as SK

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height: {
        if (!panel.el || panel.el.typ !== "symbol") return 0
        var sid = panel.el.symbolId || ""
        if (SK.istVerbHelper(sid)) return 0
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

    // Rolle des aktuellen Elements im Betriebsmittel
    readonly property int  _bmId: (panel.el && (panel.el.betriebsmittelId || 0) > 0)
                                  ? panel.el.betriebsmittelId : 0
    readonly property bool _istHf: {
        if (_bmId === 0) return false
        var info = db.betriebsmittelInfo(_bmId)
        return (info.hauptElementId || 0) === (panel.el ? panel.el.id : -1)
    }
    readonly property bool _istNf: _bmId > 0 && !_istHf

    // ── Einbauort-Picker ─────────────────────────
    ListModel { id: bmAnlageModel }
    ListModel { id: bmOrteModel }

    property var bmElRef: panel.el
    onBmElRefChanged: {
        var oid = _bmId > 0 ? (db.betriebsmittelInfo(_bmId).ortId || -1) : -1
        bmSetFromOrtId(oid)
    }

    Component.onCompleted: bmRefreshAnlagen()

    function bmRefreshAnlagen() {
        bmAnlageModel.clear()
        bmAnlageModel.append({ itemId: -1, label: qsTr("(keine)") })
        var al = seitenModel.anlagenListe()
        for (var i = 0; i < al.length; i++) bmAnlageModel.append(al[i])
    }
    function bmRefreshOrte() {
        bmOrteModel.clear()
        bmOrteModel.append({ itemId: -1, label: qsTr("(kein)") })
        if (bmAnlageCombo.currentIndex <= 0 || bmAnlageModel.count <= 1) return
        var aId = bmAnlageModel.get(bmAnlageCombo.currentIndex).itemId
        if (aId < 0) return
        var ol = seitenModel.orteListe(aId)
        for (var i = 0; i < ol.length; i++) bmOrteModel.append(ol[i])
    }
    function bmApplyOrt() {
        if (root._bmId <= 0) return
        var newOrtId = bmOrteCombo.currentIndex > 0
                       ? bmOrteModel.get(bmOrteCombo.currentIndex).itemId : -1
        db.betriebsmittelOrtSetzen(root._bmId, newOrtId)
        panel.canvas.seiteNeuLaden()
    }
    function bmSetFromOrtId(oid) {
        bmRefreshAnlagen()
        if (oid > 0) {
            for (var ai = 1; ai < bmAnlageModel.count; ai++) {
                var aId = bmAnlageModel.get(ai).itemId
                var ol = seitenModel.orteListe(aId)
                for (var oi = 0; oi < ol.length; oi++) {
                    if (ol[oi].itemId === oid) {
                        bmAnlageCombo.currentIndex = ai
                        bmRefreshOrte()
                        for (var ri = 1; ri < bmOrteModel.count; ri++) {
                            if (bmOrteModel.get(ri).itemId === oid) {
                                bmOrteCombo.currentIndex = ri
                                return
                            }
                        }
                        return
                    }
                }
            }
        }
        bmAnlageCombo.currentIndex = 0
        bmRefreshOrte()
        bmOrteCombo.currentIndex = 0
    }

    Connections {
        target: seitenModel
        function onModelReset() { root.bmRefreshAnlagen(); root.bmRefreshOrte() }
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
                height: 28
                color:  root._istNf ? theme.surfaceDeep : theme.inputBg
                radius: 3
                border.color: bmkEdit.activeFocus ? theme.accent
                              : (root._istNf ? theme.divider : theme.border)

                TextInput {
                    id: bmkEdit
                    anchors { fill: parent; margins: 5 }
                    color: root._istNf ? theme.borderLight : theme.textSecondary
                    font.pixelSize: 11
                    verticalAlignment: TextInput.AlignVCenter
                    readOnly: root._istNf

                    text: (panel.el && panel.el.extraDaten)
                          ? (panel.el.extraDaten.bmk || "") : ""
                    Binding on text {
                        when:    !bmkEdit.activeFocus
                        value:   (panel.el && panel.el.extraDaten)
                                 ? (panel.el.extraDaten.bmk || "") : ""
                        delayed: true
                    }
                    onEditingFinished: {
                        var kz = text.trim()
                        if (kz !== "" && !kz.startsWith("-")) kz = "-" + kz
                        root.extraSetzen("bmk", kz)
                        if (root._istHf && root._bmId > 0 && kz !== "") {
                            db.betriebsmittelKzSetzen(root._bmId, kz)
                            panel.canvas.seiteNeuLaden()
                        }
                    }
                    Keys.onEscapePressed: focus = false
                }

                // Schloss-Icon wenn NF (read-only)
                Text {
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: "🔒"; font.pixelSize: 9; opacity: 0.5
                    visible: root._istNf
                }
            }

            Rectangle {
                width: 28; height: 28; radius: 3
                color: autoMa.containsMouse ? theme.border : theme.inputBg
                border.color: root._istNf ? theme.divider : theme.border
                opacity: root._istNf ? 0.4 : 1.0
                Text {
                    anchors.centerIn: parent
                    text: "#"; color: theme.accent; font.pixelSize: 13; font.bold: true
                }
                ToolTip.visible: autoMa.containsMouse && !root._istNf
                ToolTip.text: qsTr("Nächste freie Nummer vorschlagen")
                ToolTip.delay: 400
                MouseArea {
                    id: autoMa
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: root._istNf ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !root._istNf
                    onClicked: {
                        if (panel.canvas.projektId < 0) return
                        var bmk = (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmk)
                                  ? panel.el.extraDaten.bmk : ""
                        var praefix = bmk.replace(/\d+$/, "")
                        if (!praefix) praefix = "-?"
                        var vorschlag = db.naechsteBmkNummer(panel.canvas.projektId, praefix)
                        root.extraSetzen("bmk", vorschlag)
                        if (root._istHf && root._bmId > 0)
                            db.betriebsmittelKzSetzen(root._bmId, vorschlag)
                    }
                }
            }
        }
        Item { height: 6 }

        // ── Einbauort ─────────────────────────────
        Trennlinie {}
        AbschnittTitel { text: qsTr("EINBAUORT") }

        FeldLabel { text: qsTr("Anlage (=)") }
        ComboBox {
            id: bmAnlageCombo
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28
            model: bmAnlageModel
            textRole: "label"
            ToolTip.visible: hovered; ToolTip.delay: 600
            ToolTip.text: qsTr("Neue Anlagen und Orte werden im Seitenbaum angelegt (+ Anlage / + Ort)")
            onCurrentIndexChanged: root.bmRefreshOrte()
            onActivated: { bmOrteCombo.currentIndex = 0; root.bmApplyOrt() }
            delegate: ItemDelegate {
                required property var model
                text: model.label
                width: parent ? parent.width : 80
                font.pixelSize: 11
            }
            contentItem: Text {
                leftPadding: 8
                text: bmAnlageCombo.displayText
                font.pixelSize: 11
                color: root.theme.textSecondary
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: root.theme.inputBg
                border.color: bmAnlageCombo.activeFocus ? root.theme.accent : root.theme.border
                radius: 3
            }
        }

        Item { height: 4 }
        FeldLabel { text: qsTr("Ort (+)") }
        ComboBox {
            id: bmOrteCombo
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28
            model: bmOrteModel
            textRole: "label"
            enabled: bmAnlageCombo.currentIndex > 0
            opacity: enabled ? 1.0 : 0.4
            ToolTip.visible: hovered; ToolTip.delay: 600
            ToolTip.text: qsTr("Neue Anlagen und Orte werden im Seitenbaum angelegt (+ Anlage / + Ort)")
            onActivated: root.bmApplyOrt()
            delegate: ItemDelegate {
                required property var model
                text: model.label
                width: parent ? parent.width : 80
                font.pixelSize: 11
            }
            contentItem: Text {
                leftPadding: 8
                text: bmOrteCombo.displayText
                font.pixelSize: 11
                color: root.theme.textSecondary
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: root.theme.inputBg
                border.color: bmOrteCombo.activeFocus ? root.theme.accent : root.theme.border
                radius: 3
            }
        }
        Item { height: 6 }

        EpBmVerknuepfungBlock {
            panel: root.panel
            theme: root.theme
            onVerknuepfenAngefordert: dlgBmVerknuepfen.open()
        }

        EpBmKontaktBlock {
            panel: root.panel
            theme: root.theme
        }

        EpBmBeschriftungBlock {
            panel: root.panel
            theme: root.theme
        }

        // ── Schriftgröße ──────────────────────────
        Trennlinie {}
        AbschnittTitel { text: qsTr("SCHRIFTGRÖSSE") }
        SchriftgrosseSelektor {
            wert: (panel.el && panel.el.extraDaten
                   && panel.el.extraDaten.schriftgroesse !== undefined)
                  ? panel.el.extraDaten.schriftgroesse : 2.5
            onWertGeaendert: function(v) { root.extraSetzen("schriftgroesse", v) }
        }

    }

    EpBmVerknuepfenDialog {
        id:    dlgBmVerknuepfen
        panel: root.panel
        theme: root.theme
    }
}
