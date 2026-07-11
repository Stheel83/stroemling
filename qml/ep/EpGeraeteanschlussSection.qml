import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "symbol"
              && panel.el.symbolId === "geraeteanschluss")
             ? gaCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    function textpositionZuruecksetzen() {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        delete ed.bmkOffsetX
        delete ed.bmkOffsetY
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    readonly property string aktuellRolle: (panel.el && panel.el.extraDaten
        && panel.el.extraDaten.rolle) ? panel.el.extraDaten.rolle : "ziel"
    readonly property string aktuellSig: (panel.el && panel.el.extraDaten
        && panel.el.extraDaten.signaltyp) ? panel.el.extraDaten.signaltyp : "neutral"

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

    Column {
        id: gaCol
        width: parent.width
        spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("GERÄTEANSCHLUSS") }

        FeldLabel { text: qsTr("Rolle") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: root.theme;
                label:   qsTr("◄ Ziel")
                aktiv:   root.aktuellRolle === "ziel"
                breite:  80
                onKlick: root.extraSetzen("rolle", "ziel")
            }
            MiniButton { theme: root.theme;
                label:   qsTr("Quelle ►")
                aktiv:   root.aktuellRolle === "quelle"
                breite:  80
                onKlick: root.extraSetzen("rolle", "quelle")
            }
        }
        Item { height: 6 }

        InputField {
            label: qsTr("Anschlusskennzeichnung")
            value: (panel.el && panel.el.extraDaten && panel.el.extraDaten.anschlusskennzeichnung)
                   ? panel.el.extraDaten.anschlusskennzeichnung : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("anschlusskennzeichnung", t) }
        }
        Item { height: 6 }

        Trennlinie {}
        AbschnittTitel { text: qsTr("ANSCHLUSSTECHNIK") }

        FeldLabel { text: qsTr("Typ") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: [
                    { key: "schraube", label: qsTr("Schraube")  },
                    { key: "feder",    label: qsTr("Feder")     },
                    { key: "push_in",  label: "Push-in"         },
                    { key: "kaefig",   label: qsTr("Käfig")     }
                ]
                delegate: MiniButton {
                    theme:   root.theme
                    label:   modelData.label
                    breite:  64
                    aktiv:   (panel.el && panel.el.extraDaten && panel.el.extraDaten.anschlussTyp)
                             === modelData.key
                    onKlick: root.extraSetzen("anschlussTyp", modelData.key)
                }
            }
        }
        Item { height: 6 }

        // min/max mm² nebeneinander – inline statt InputField-Wrapper (height-Fix)
        Row {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: [
                    { key: "minMm2", lbl: qsTr("min. mm²") },
                    { key: "maxMm2", lbl: qsTr("max. mm²") }
                ]
                delegate: Column {
                    width: (parent.width - parent.spacing) / 2
                    spacing: 0
                    Item {
                        width: parent.width; height: 20
                        Text {
                            anchors { left: parent.left; leftMargin: 0; verticalCenter: parent.verticalCenter }
                            text: modelData.lbl; font.pixelSize: 10; color: root.theme.panelMid
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 28; radius: 3
                        color: root.theme.inputBg
                        border.color: mm2Tf.activeFocus ? root.theme.accent : root.theme.border
                        border.width: 1
                        TextInput {
                            id: mm2Tf
                            anchors { fill: parent; margins: 5 }
                            color: root.theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: {
                                var v = panel.el && panel.el.extraDaten
                                        ? panel.el.extraDaten[modelData.key] : undefined
                                return v !== undefined ? String(v) : ""
                            }
                            Binding on text {
                                when:    !mm2Tf.activeFocus
                                value: {
                                    var v = panel.el && panel.el.extraDaten
                                            ? panel.el.extraDaten[modelData.key] : undefined
                                    return v !== undefined ? String(v) : ""
                                }
                                delayed: true
                            }
                            onEditingFinished: {
                                var n = parseFloat(text.replace(",", "."))
                                root.extraSetzen(modelData.key, isNaN(n) ? 0 : n)
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                }
            }
        }
        Item { height: 4 }

        // Doppelbelegung + AEH als Checkboxen nebeneinander
        Row {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: 28; radius: 4
                color: doppelAktiv ? Qt.alpha(root.theme.accent, 0.15) : root.theme.inputBg
                border.color: doppelAktiv ? root.theme.accent : root.theme.border
                border.width: 1

                readonly property bool doppelAktiv: panel.el && panel.el.extraDaten
                                                    && panel.el.extraDaten.doppelbelegung === true

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Rectangle {
                        width: 13; height: 13; radius: 2
                        color: parent.parent.doppelAktiv ? root.theme.accent : "transparent"
                        border.color: parent.parent.doppelAktiv ? root.theme.accent : root.theme.borderLight
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "✓"; font.pixelSize: 9
                            color: root.theme.textPrimary
                            visible: parent.parent.parent.doppelAktiv
                        }
                    }
                    Text {
                        text: qsTr("Doppelbelegung")
                        font.pixelSize: 10; color: root.theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.extraSetzen("doppelbelegung", !parent.doppelAktiv)
                }
            }

            Rectangle {
                width: (parent.width - parent.spacing) / 2
                height: 28; radius: 4
                color: aehnAktiv ? Qt.alpha(root.theme.accent, 0.15) : root.theme.inputBg
                border.color: aehnAktiv ? root.theme.accent : root.theme.border
                border.width: 1

                readonly property bool aehnAktiv: !(panel.el && panel.el.extraDaten
                                                   && panel.el.extraDaten.aehnErlaubt === false)

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Rectangle {
                        width: 13; height: 13; radius: 2
                        color: parent.parent.aehnAktiv ? root.theme.accent : "transparent"
                        border.color: parent.parent.aehnAktiv ? root.theme.accent : root.theme.borderLight
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "✓"; font.pixelSize: 9
                            color: root.theme.textPrimary
                            visible: parent.parent.parent.aehnAktiv
                        }
                    }
                    Text {
                        text: "AEH"
                        font.pixelSize: 10; color: root.theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.extraSetzen("aehnErlaubt", !parent.aehnAktiv)
                }
            }
        }
        Item { height: 8 }

        Trennlinie {}
        FeldLabel { text: qsTr("Signaltyp") }
        Flow {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4

            // Rollenabhängige Signaltypen: quelle/ziel/beide
            property var _alle: [
                { key: "neutral",        label: qsTr("Neutral"), farbe: "#4a9eff", rollen: ["quelle","ziel"] },
                { key: "power",          label: "L",             farbe: "#cc3300", rollen: ["quelle","ziel"] },
                { key: "pe",             label: "PE",            farbe: "#88cc00", rollen: ["quelle","ziel"] },
                { key: "n",              label: "N",             farbe: "#4488ff", rollen: ["quelle","ziel"] },
                { key: "dc_plus",        label: "DC+",           farbe: "#dd5500", rollen: ["quelle","ziel"] },
                { key: "dc_minus",       label: "DC−",      farbe: "#334488", rollen: ["quelle","ziel"] },
                { key: "output_digital", label: "DO",            farbe: "#aa44cc", rollen: ["quelle"]        },
                { key: "input_digital",  label: "DI",            farbe: "#44aacc", rollen: ["ziel"]          },
                { key: "output_analog",  label: "AO",            farbe: "#66ddaa", rollen: ["quelle"]        },
                { key: "input_analog",   label: "AI",            farbe: "#88bbff", rollen: ["ziel"]          },
                { key: "kommunikation",  label: qsTr("Komm."),   farbe: "#cc8800", rollen: ["quelle","ziel"] },
                { key: "temp",           label: qsTr("Temp"),    farbe: "#e07030", rollen: ["quelle","ziel"] },
                { key: "stepper",        label: "Stepper",       farbe: "#20a890", rollen: ["quelle","ziel"] },
                { key: "sicherheit",     label: qsTr("Sicherheit"), farbe: "#d4a017", rollen: ["quelle","ziel"] },
                { key: "fe",             label: "FE",            farbe: "#4caf7d", rollen: ["quelle","ziel"] }
            ]

            Repeater {
                model: parent._alle.filter(function(s) {
                    return s.rollen.indexOf(root.aktuellRolle) >= 0
                })
                delegate: Rectangle {
                    width:  gaSigLbl.implicitWidth + 16; height: 24; radius: 4
                    color:  root.aktuellSig === modelData.key
                            ? Qt.rgba(
                                  parseInt(modelData.farbe.slice(1,3),16)/255,
                                  parseInt(modelData.farbe.slice(3,5),16)/255,
                                  parseInt(modelData.farbe.slice(5,7),16)/255,
                                  0.25)
                            : (root.theme ? root.theme.inputBg : "transparent")
                    border.color: root.aktuellSig === modelData.key
                                  ? modelData.farbe : (root.theme ? root.theme.border : "transparent")
                    border.width: 1
                    Text {
                        id: gaSigLbl
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: 10
                        color: root.aktuellSig === modelData.key
                               ? modelData.farbe : (root.theme ? root.theme.panelMid : "gray")
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.extraSetzen("signaltyp",
                            root.aktuellSig === modelData.key ? "neutral" : modelData.key)
                    }
                }
            }
        }
        Item { height: 8 }

        // ── Textposition ──────────────────────────────────────────
        Trennlinie {}
        AbschnittTitel { text: qsTr("TEXTPOSITION") }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Column {
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Versatz X"); color: root.theme.panelMid; font.pixelSize: 10 }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: root.theme.inputBg; border.color: gaOxTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: gaOxTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetX !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetX : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !gaOxTf.activeFocus; value: (gaOxTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetX", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Column {
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Versatz Y"); color: root.theme.panelMid; font.pixelSize: 10 }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: root.theme.inputBg; border.color: gaOyTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: gaOyTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetY !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetY : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !gaOyTf.activeFocus; value: (gaOyTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetY", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: 32; height: 22; radius: 3
                color: gaResetMa.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 12; color: root.theme.textMuted }
                MouseArea {
                    id: gaResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.textpositionZuruecksetzen()
                }
                ToolTip { visible: gaResetMa.containsMouse; text: qsTr("Textposition zurücksetzen"); delay: 500 }
            }
        }
        Item { height: 8 }
    }
}
