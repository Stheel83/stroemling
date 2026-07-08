import QtQuick
import QtQuick.Controls
import stroemling
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.symbolId === "klemme_anschluss") ? kaCol.implicitHeight : 0
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
        id: kaCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("KLEMMEN-ANSCHLUSS") }

        // Große Bezeichnung
        Item {
            width: parent.width; height: 36
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 8
                Text {
                    text: panel.el ? ((panel.el.extraDaten || {}).anschlussBezeichnung || "–") : "–"
                    font.pixelSize: 18; font.weight: Font.Bold; color: theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    visible: (panel.kaDetails && panel.kaDetails.anschlussSeite !== "")
                    width: 28; height: 18; radius: 3
                    color: theme.badge
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: panel.kaDetails ? (panel.kaDetails.anschlussSeite || "") : ""
                        font.pixelSize: 10; color: theme.accent
                    }
                }
                Text {
                    visible: panel.kaDetails && panel.kaDetails.anschlussEbene !== undefined
                             && panel.kaDetails.anschlussEbene !== null
                    text: panel.kaDetails ? qsTr("Eb. %1").arg(panel.kaDetails.anschlussEbene) : ""
                    font.pixelSize: 10; color: theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Platziermodus
        Item {
            width: parent.width
            height: modusText.implicitHeight + 8
            Text {
                id: modusText
                anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                wrapMode: Text.WordWrap
                property bool istGeist: panel.el ? ((panel.el.extraDaten || {}).geist === true) : false
                text: {
                    if (istGeist) return qsTr("⚠ Platzhalter – echten Anschluss aus dem Klemmenreihen-Editor direkt auf diesen setzen; der Platzhalter wird automatisch ersetzt. Kein Löschen nötig.")
                    var m = panel.el ? ((panel.el.extraDaten || {}).platziermodus || "") : ""
                    if (m === "skizze")      return qsTr("Modus: Skizze")
                    if (m === "verknuepft") return qsTr("Modus: Verknüpft")
                    return m || ""
                }
                font.pixelSize: 10; color: istGeist ? "#e0a030" : theme.textSubtle
            }
        }

        // VERKNÜPFT: strukturierte Kennung (Leiste / Klemme / Anschluss)
        Item {
            width: parent.width
            height: (panel.el && (panel.el.extraDaten || {}).platziermodus === "verknuepft")
                    ? kennungSpalte.implicitHeight : 0
            clip: true
            Column {
                id: kennungSpalte
                width: parent.width; spacing: 0
                property var kp: {
                    var ed  = panel.el ? (panel.el.extraDaten || {}) : {}
                    var bez = ed.anschlussBezeichnung || ""
                    var raw = ed.bmk || ""
                    var base = (bez !== "" && raw.endsWith(":" + bez))
                               ? raw.slice(0, raw.length - bez.length - 1) : raw
                    var c = base.lastIndexOf(":")
                    return { leiste: c >= 0 ? base.slice(0, c) : base,
                             nr:     c >= 0 ? base.slice(c + 1) : "" }
                }
                AbschnittTitel { text: qsTr("KENNUNG") }
                Item {
                    width: parent.width; height: 22
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { text: qsTr("Leiste"); width: 70; font.pixelSize: 10; color: theme.textMuted }
                        Text { text: kennungSpalte.kp.leiste || "–"
                               font.pixelSize: 11; font.weight: Font.Medium; color: theme.textSecondary }
                    }
                }
                Item {
                    width: parent.width; height: 22
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { text: qsTr("Klemme"); width: 70; font.pixelSize: 10; color: theme.textMuted }
                        Text { text: kennungSpalte.kp.nr ? qsTr("Nr. %1").arg(kennungSpalte.kp.nr) : "–"
                               font.pixelSize: 11; color: theme.textSecondary }
                    }
                }
                Item {
                    width: parent.width; height: 22
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0
                        Text { text: qsTr("Anschluss"); width: 70; font.pixelSize: 10; color: theme.textMuted }
                        Text { text: panel.el ? ((panel.el.extraDaten || {}).anschlussBezeichnung || "–") : "–"
                               font.pixelSize: 11; font.weight: Font.Medium; color: theme.accent }
                    }
                }
            }
        }

        // SKIZZE: editierbares Bezeichner-Feld
        InputField {
            visible: !panel.el || (panel.el.extraDaten || {}).platziermodus !== "verknuepft"
            label: qsTr("Bezeichner")
            value: panel.el ? ((panel.el.extraDaten || {}).bmk || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("bmk", t) }
        }

        // BMK-Einblend-Checkboxen: Leiste | Anlage | Ort | Gerät (nur für verknüpfte Klemmen)
        Row {
            leftPadding: 12; height: 32; spacing: 10
            visible: panel.el ? ((panel.el.extraDaten || {}).platziermodus === "verknuepft") : false

            Repeater {
                model: ListModel {
                    ListElement { bmkKey: "bmkSichtbar";    bmkLabel: "Leiste";
                                  bmkTip: "Leitenbezeichner (-X1:Nr.) ein-/ausblenden. Klemmen-Nummer bleibt sichtbar." }
                    ListElement { bmkKey: "anlageAnzeigen"; bmkLabel: "Anlage";
                                  bmkTip: "Anlagekürzel (z. B. =ST) ein-/ausblenden." }
                    ListElement { bmkKey: "ortAnzeigen";    bmkLabel: "Ort";
                                  bmkTip: "Ortkürzel (z. B. +ST1) ein-/ausblenden." }
                    ListElement { bmkKey: "geraetAnzeigen"; bmkLabel: "Gerät";
                                  bmkTip: "Gerätepräfix (z. B. -AZD01) ein-/ausblenden.\nNur relevant wenn Gerät-Picker im KR-Editor gesetzt." }
                }
                Row {
                    required property string bmkKey
                    required property string bmkLabel
                    required property string bmkTip
                    spacing: 4; height: parent.height
                    property bool an: panel.el ? ((panel.el.extraDaten || {})[bmkKey] !== false) : true
                    Rectangle {
                        width: 16; height: 16; radius: 3; anchors.verticalCenter: parent.verticalCenter
                        color: parent.an ? theme.accent : theme.inputBg; border.color: theme.border
                        Text { anchors.centerIn: parent; text: "✓"; color: "#fff"
                               font.pixelSize: 10; visible: parent.parent.an }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                            onClicked: root.extraSetzen(parent.parent.bmkKey, !parent.parent.an)
                            ToolTip.visible: containsMouse; ToolTip.delay: 500
                            ToolTip.text: parent.parent.bmkTip
                        }
                    }
                    Text {
                        text: parent.bmkLabel; color: theme.textMuted; font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Klemme (aus Bauteil-DB)
        Item {
            width: parent.width
            height: (panel.kaDetails && panel.kaDetails.ok) ? klemmeInfoRow.implicitHeight : 0
            clip: true

            Column {
                id: klemmeInfoRow
                width: parent.width; spacing: 0

                Trennlinie {}
                AbschnittTitel { text: qsTr("KLEMME") }

                FeldLabel { text: qsTr("Typ") }
                Item {
                    width: parent.width; height: 24
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: {
                            var t = panel.kaDetails ? (panel.kaDetails.anschlussTyp || "") : ""
                            if (t === "schraube") return qsTr("Schraubanschluss")
                            if (t === "feder")    return qsTr("Federkraft")
                            if (t === "kaefig")   return qsTr("Käfigzugfeder")
                            if (t === "push_in")  return qsTr("Steckanschluss")
                            return t || "–"
                        }
                        font.pixelSize: 12; color: theme.textSecondary
                    }
                }

                FeldLabel { text: qsTr("Norm") }
                Item {
                    width: parent.width; height: 24
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: (panel.kaDetails && panel.kaDetails.norm) ? panel.kaDetails.norm : "–"
                        font.pixelSize: 12; color: theme.textSecondary
                    }
                }

                Item {
                    width: parent.width
                    height: (panel.kaDetails && panel.kaDetails.breiteMm > 0) ? 22 : 0
                    clip: true
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Text { text: qsTr("Breite:"); font.pixelSize: 11; color: theme.textMuted }
                        Text {
                            text: panel.kaDetails ? (panel.kaDetails.breiteMm.toFixed(1) + " mm") : ""
                            font.pixelSize: 11; color: theme.textSecondary
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: (panel.kaDetails && panel.kaDetails.querschnitte && panel.kaDetails.querschnitte.length > 0) ? querschnittCol.implicitHeight : 0
                    clip: true

                    Column {
                        id: querschnittCol
                        width: parent.width; spacing: 0

                        FeldLabel { text: qsTr("Querschnitte") }

                        Repeater {
                            model: panel.kaDetails ? (panel.kaDetails.querschnitte || []) : []
                            delegate: Item {
                                width: parent.width; height: 22
                                Row {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    spacing: 6
                                    Text {
                                        width: 90
                                        text: {
                                            var t = modelData.adertyp || ""
                                            if (t === "starr")         return qsTr("Starr")
                                            if (t === "flexibel")      return qsTr("Flexibel")
                                            if (t === "aenh_blank")    return qsTr("AEH blank")
                                            if (t === "aenh_isoliert") return qsTr("AEH isoliert")
                                            return t
                                        }
                                        font.pixelSize: 11; color: theme.textMuted
                                    }
                                    Text {
                                        text: (modelData.minMm2 + "").replace('.', ',') + " – " +
                                              (modelData.maxMm2 + "").replace('.', ',') + " mm²"
                                        font.pixelSize: 11; color: theme.textSecondary
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Klemmen-Ebenenansicht
        Item {
            width: parent.width
            height: (panel.kaDetails && panel.kaDetails.ok
                     && panel.kaDetails.ebenenAnzahl > 0)
                    ? vorschauBlock.implicitHeight : 0
            clip: true

            Column {
                id: vorschauBlock
                width: parent.width; spacing: 0

                Trennlinie {}
                AbschnittTitel { text: qsTr("KLEMMENAUFBAU") }

                Item { width: 1; height: 8 }
                KlemmenVorschau {
                    width: parent.width - 24
                    anchors.horizontalCenter: parent.horizontalCenter
                    theme: root.theme

                    klemme: panel.kaDetails ? {
                        "ebenenAnzahl":      panel.kaDetails.ebenenAnzahl    !== undefined ? panel.kaDetails.ebenenAnzahl    : 1,
                        "punkteSeitenA":     panel.kaDetails.punkteSeitenA   !== undefined ? panel.kaDetails.punkteSeitenA   : 1,
                        "punkteSeitenB":     panel.kaDetails.punkteSeitenB   !== undefined ? panel.kaDetails.punkteSeitenB   : 1,
                        "fussKontaktPe":     panel.kaDetails.fussKontaktPe   || false,
                        "stegbrueckeFaehig": panel.kaDetails.stegbrueckeFaehig || false
                    } : ({})
                    bruecken:             (panel.kaDetails && panel.kaDetails.bruecken) ? panel.kaDetails.bruecken : []
                    markierteBezeichnung: panel.el ? ((panel.el.extraDaten || {}).anschlussBezeichnung || "") : ""
                    zeigeBezeichnungen:   true
                    zeigeSeiten:          true
                    akzentFarbe:          theme.accent
                }
                Item { width: 1; height: 8 }
            }
        }

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
                        color: root.theme.inputBg; border.color: kaOxTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: kaOxTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetX !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetX : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !kaOxTf.activeFocus; value: (kaOxTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
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
                        color: root.theme.inputBg; border.color: kaOyTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: kaOyTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetY !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetY : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !kaOyTf.activeFocus; value: (kaOyTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
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
                color: kaResetMa.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 12; color: root.theme.textMuted }
                MouseArea {
                    id: kaResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.textpositionZuruecksetzen()
                }
                ToolTip { visible: kaResetMa.containsMouse; text: qsTr("Textposition zurücksetzen"); delay: 500 }
            }
        }
        Item { height: 4 }
    }
}
