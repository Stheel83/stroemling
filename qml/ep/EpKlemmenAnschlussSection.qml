import QtQuick
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
        canvas.eigenschaftAktualisieren("extraDaten", ed)
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
            width: parent.width; height: 20
            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: {
                    var m = panel.el ? ((panel.el.extraDaten || {}).platziermodus || "") : ""
                    if (m === "skizze")      return qsTr("Modus: Skizze")
                    if (m === "verknuepft") return qsTr("Modus: Verknüpft")
                    return m || ""
                }
                font.pixelSize: 10; color: theme.textSubtle
            }
        }

        InputField {
            label: qsTr("BMK / Bezeichner")
            value: panel.el ? ((panel.el.extraDaten || {}).bmk || "") : ""
            theme: theme
            readOnly: panel.el ? ((panel.el.extraDaten || {}).platziermodus === "verknuepft") : false
            onCommit: function(t) { root.extraSetzen("bmk", t) }
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
                            if (t === "schraube")     return qsTr("Schraubklemme")
                            if (t === "federklemme")  return qsTr("Federklemme")
                            if (t === "kaefigklemme") return qsTr("Käfigklemme")
                            if (t === "stecker")      return qsTr("Stecker")
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
                    theme: theme

                    klemme: panel.kaDetails ? {
                        "ebenenAnzahl":      panel.kaDetails.ebenenAnzahl    || 1,
                        "punkteSeitenA":     panel.kaDetails.punkteSeitenA   || 1,
                        "punkteSeitenB":     panel.kaDetails.punkteSeitenB   || 1,
                        "fussKontaktPe":     panel.kaDetails.fussKontaktPe   || false,
                        "stegbrueckeFaehig": panel.kaDetails.stegbrueckeFaehig || false
                    } : ({})
                    bruecken:             (panel.kaDetails && panel.kaDetails.bruecken) ? panel.kaDetails.bruecken : []
                    markierteBezeichnung: panel.el ? ((panel.el.extraDaten || {}).anschlussBezeichnung || "") : ""
                    zeigeBezeichnungen:   true
                    akzentFarbe:          theme.accent
                }
                Item { width: 1; height: 8 }
            }
        }

        Item { height: 4 }
    }
}
