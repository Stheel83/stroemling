import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "symbol"
              && panel.el.symbolId !== "aderdefinition") ? symbolCol.implicitHeight : 0
    visible: height > 0
    clip:    true

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
        width: root.width; height: visible ? 20 : 0
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    // Symbole ohne Pin-Beschriftungsblock (haben eigene Logik oder keine sinnvollen Pins)
    readonly property var _pinBezSkip: ({
        "querverweis": true, "winkel": true, "treffpunkt": true, "treffpunkt_l": true,
        "klemme_anschluss": true, "geraeteanschluss": true, "potenzial": true,
        "aderdefinition": true, "isoliert_gelegte_ader": true
    })

    // Nur für freistehende Symbole ohne Bauteil-Zuordnung – ist ein Bauteil
    // verknüpft, kommen die Pin-Labels aus dessen Kontakt-Editor
    // (bauteil_kontakt.pin_bez, einmalig beim Platzieren nach extraDaten.pinBez
    // kopiert); eine zusätzliche manuelle Bearbeitung hier würde diese Vorgabe
    // unkontrolliert überschreiben.
    readonly property bool zeigtPinBez:
        panel.el && panel.el.typ === "symbol"
        && !_pinBezSkip[panel.el.symbolId || ""]
        && !(panel.el.betriebsmittelId > 0)

    readonly property bool istSteckerOderBuchse:
        panel.el && (panel.el.symbolId === "stecker" || panel.el.symbolId === "buchse")

    // Symbole mit eigenem, generischem BMK-Textlabel – Klemme/Geräteanschluss/
    // Potenzial haben ihre eigene Textposition-Logik in ihren jeweiligen
    // EP-Sektionen (eigene Default-Werte, eigene Basisberechnung der Position).
    readonly property bool zeigtTextposition:
        panel.el && panel.el.typ === "symbol"
        && !_pinBezSkip[panel.el.symbolId || ""]

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    // Löscht die Offset-Schlüssel statt sie auf 0 zu setzen: der Code-Default
    // für normale Symbole ist -14 (Text sitzt automatisch über dem Symbol),
    // nicht 0 – nur so kehrt "Zurücksetzen" wirklich zur Ruheposition zurück.
    function textpositionZuruecksetzen() {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        delete ed.bmkOffsetX
        delete ed.bmkOffsetY
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    // Pin 2 von Stecker/Buchse ist die fiktive Steckverbindung – keine eigene
    // Beschriftung, Status stattdessen als "Gesteckt"/"Nicht gesteckt" (s.u.).
    function _pinsFuerBeschriftung(symbolId) {
        var pins = symbolDefinitionModel.pinsForSymbol(symbolId)
        if (symbolId !== "stecker" && symbolId !== "buchse") return pins
        var r = []
        for (var i = 0; i < pins.length; i++)
            if (pins[i].name !== "2") r.push(pins[i])
        return r
    }

    readonly property var _aktuellerPinBez:
        (panel.el && panel.el.extraDaten && panel.el.extraDaten.pinBez)
        ? panel.el.extraDaten.pinBez : ({})

    function _pinBezSpeichern(pinName, label) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        if (!ed.pinBez) ed.pinBez = {}
        if (label === "") {
            delete ed.pinBez[pinName]
            if (Object.keys(ed.pinBez).length === 0) delete ed.pinBez
        } else {
            ed.pinBez[pinName] = label
        }
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    Column {
        id: symbolCol
        width: parent.width; spacing: 0

        readonly property bool zeigeSpiegelung:
            !(panel.el && (panel.el.symbolId === "querverweis"
                        || panel.el.symbolId === "winkel"
                        || panel.el.symbolId === "treffpunkt"
                        || panel.el.symbolId === "klemme_anschluss"))

        Trennlinie {}
        AbschnittTitel { text: qsTr("SYMBOL") }

        FeldLabel {
            text: qsTr("Rotation")
            visible: !(panel.el && panel.el.symbolId === "querverweis")
        }
        Row {
            visible: !(panel.el && panel.el.symbolId === "querverweis")
            height: visible ? implicitHeight : 0
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: [
                    { anzeige: "0°",   wert: 0   },
                    { anzeige: "90°",  wert: 90  },
                    { anzeige: "180°", wert: 180 },
                    { anzeige: "270°", wert: 270 }
                ]
                MiniButton { theme: root.theme;
                    label:   modelData.anzeige
                    aktiv:   panel.s("rotation", 0) === modelData.wert
                    breite:  40
                    onKlick: panel.canvas.eigenschaftAktualisieren("rotation", modelData.wert)
                }
            }
        }
        Item {
            height: symbolCol.zeigeSpiegelung ? 8 : 0
            visible: symbolCol.zeigeSpiegelung
        }

        FeldLabel {
            text: qsTr("Spiegelung")
            visible: symbolCol.zeigeSpiegelung
        }
        Row {
            visible: symbolCol.zeigeSpiegelung
            height: visible ? implicitHeight : 0
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: root.theme;
                label:   qsTr("↔ H")
                tooltip: qsTr("Horizontal spiegeln (Taste X)")
                aktiv:   panel.s("spiegelX", false)
                breite:  56
                onKlick: panel.canvas.eigenschaftAktualisieren("spiegelX", !panel.s("spiegelX", false))
            }
            MiniButton { theme: root.theme;
                label:   qsTr("↕ V")
                tooltip: qsTr("Vertikal spiegeln (Taste Y)")
                aktiv:   panel.s("spiegelY", false)
                breite:  56
                onKlick: panel.canvas.eigenschaftAktualisieren("spiegelY", !panel.s("spiegelY", false))
            }
        }
        Item {
            height: symbolCol.zeigeSpiegelung ? 4 : 0
            visible: symbolCol.zeigeSpiegelung
        }

        // ── Textposition ─────────────────────────────────────────────────────
        Loader {
            active: root.zeigtTextposition
            width: parent.width

            sourceComponent: Component {
                Column {
                    width: parent ? parent.width : 0; spacing: 0

                    Rectangle {
                        width: parent.width - 16; height: 1; color: root.theme.border
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Item {
                        width: parent.width; height: 26
                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: qsTr("TEXTPOSITION"); font.pixelSize: 9; font.weight: Font.Bold
                            font.letterSpacing: 1.5; color: root.theme.borderLight
                        }
                    }

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
                                    color: root.theme.inputBg; border.color: symOxTf.activeFocus ? root.theme.accent : root.theme.border
                                    TextInput {
                                        id: symOxTf
                                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                        horizontalAlignment: TextInput.AlignRight
                                        color: root.theme.textSecondary; font.pixelSize: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                                        property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetX !== undefined)
                                                                ? panel.el.extraDaten.bmkOffsetX : 0
                                        text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                                        Binding on text { when: !symOxTf.activeFocus; value: (symOxTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
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
                                    color: root.theme.inputBg; border.color: symOyTf.activeFocus ? root.theme.accent : root.theme.border
                                    TextInput {
                                        id: symOyTf
                                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                        horizontalAlignment: TextInput.AlignRight
                                        color: root.theme.textSecondary; font.pixelSize: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                                        property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetY !== undefined)
                                                                ? panel.el.extraDaten.bmkOffsetY : -14
                                        text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                                        Binding on text { when: !symOyTf.activeFocus; value: (symOyTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
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
                            color: symResetMa.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 12; color: root.theme.textMuted }
                            MouseArea {
                                id: symResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.textpositionZuruecksetzen()
                            }
                            ToolTip { visible: symResetMa.containsMouse; text: qsTr("Textposition zurücksetzen"); delay: 500 }
                        }
                    }
                    Item { height: 4; width: parent.width }
                }
            }
        }

        // ── Pin-Bezeichnungen ────────────────────────────────────────────────
        // Sichtbar für freistehende Symbol-Typen ohne Bauteil-Zuordnung, die
        // eigene Pin-Beschriftung unterstützen. Vorausgefüllt mit dem Pin-Namen
        // aus der Pinbelegung (symbol_pin.name) – wird in dieser Form auch
        // automatisch auf dem Canvas angezeigt. Feld bearbeiten überschreibt
        // das Label je Instanz in extraDaten.pinBez.
        Loader {
            active: root.zeigtPinBez
            width: parent.width

            sourceComponent: Component {
                Column {
                    width: parent ? parent.width : 0; spacing: 0

                    Rectangle {
                        width: parent.width - 16; height: 1; color: root.theme.border
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Item {
                        width: parent.width; height: 26
                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: qsTr("PIN-BEZEICHNUNGEN"); font.pixelSize: 9; font.weight: Font.Bold
                            font.letterSpacing: 1.5; color: root.theme.borderLight
                        }
                    }

                    // Steckverbindungsstatus – nur Stecker/Buchse (Pin 2 ist die fiktive
                    // Steckverbindung, keine eigene Pin-Zeile, s. _pinsFuerBeschriftung).
                    // _refresh referenziert für AOT-Reaktivität (Muster wie panel.el).
                    Item {
                        id: steBuStatus
                        visible: root.istSteckerOderBuchse
                        width: parent.width; height: visible ? 28 : 0

                        readonly property bool verbunden:
                            root.istSteckerOderBuchse && (panel._refresh * 0 === 0) && panel.canvas
                            ? panel.canvas.hatLogischeVerbindung(panel.canvas.ausgewaehlt) : false

                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: steBuStatus.verbunden ? qsTr("● Gesteckt") : qsTr("● Nicht gesteckt")
                            font.pixelSize: 11
                            color: steBuStatus.verbunden ? "#00e5a0" : "#f0a030"
                        }
                    }

                    Repeater {
                        model: panel.el ? root._pinsFuerBeschriftung(panel.el.symbolId || "") : []
                        delegate: RowLayout {
                            width: parent.width; height: 28
                            spacing: 0

                            // Pin-Name (grau, links)
                            Item {
                                Layout.preferredWidth: 44; height: parent.height
                                Text {
                                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    text: modelData.name; font.pixelSize: 10
                                    color: root.theme.textMuted
                                }
                            }

                            // Editierbares Label
                            Rectangle {
                                Layout.fillWidth: true; height: 24; radius: 3
                                Layout.rightMargin: 12
                                color: pinLabelTf.activeFocus ? root.theme.inputBgActive : root.theme.inputBg
                                border.color: pinLabelTf.activeFocus ? root.theme.accent : root.theme.border

                                TextInput {
                                    id: pinLabelTf
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    text: root._aktuellerPinBez[modelData.name] || modelData.name
                                    color: root.theme.accent; font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                    onEditingFinished: root._pinBezSpeichern(modelData.name, text.trim())
                                    Keys.onEscapePressed: { text = root._aktuellerPinBez[modelData.name] || modelData.name; focus = false }
                                }
                            }
                        }
                    }
                    Item { height: 4; width: parent.width }
                }
            }
        }
    }
}
