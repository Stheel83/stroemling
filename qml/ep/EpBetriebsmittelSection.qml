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
                                when:    !bmkOxTf.activeFocus
                                value:   (bmkOxTf.weltWert / panel.canvas.mmToPx).toFixed(1)
                                delayed: true
                            }
                            onEditingFinished: {
                                var v = parseFloat(text.replace(",","."))
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
                                ? panel.el.extraDaten.bmkOffsetY
                                : SK.bmkOffsetYDefault(panel.el ? (panel.el.symbolId || "") : "")
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text {
                                when:    !bmkOyTf.activeFocus
                                value:   (bmkOyTf.weltWert / panel.canvas.mmToPx).toFixed(1)
                                delayed: true
                            }
                            onEditingFinished: {
                                var v = parseFloat(text.replace(",","."))
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

    EpBmVerknuepfenDialog {
        id:    dlgBmVerknuepfen
        panel: root.panel
        theme: root.theme
    }
}
