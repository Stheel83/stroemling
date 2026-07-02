import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

// DRC-Ergebnis-Panel – erscheint am unteren Rand des Canvas-Bereichs.
// Auslösung: manuell per Prüfen-Button. Ergebnisse bleiben bis zum nächsten
// Prüflauf oder bis das Panel geschlossen wird.
Item {
    id: root

    required property var    theme
    required property int    projektId
    property bool            debug: false

    signal schliessen()

    readonly property int  fehlerAnzahl: ergebnisModel.count
    readonly property bool hatFehler:    ergebnisModel.count > 0

    property bool hatGeprueft: false

    readonly property string isolusZustand: {
        if (!hatGeprueft)       return "idle"
        if (fehlerAnzahl === 0) return "intakt"
        if (fehlerAnzahl <= 3)  return "beansprucht"
        if (fehlerAnzahl <= 9)  return "beschaedigt"
        return "gefallen"
    }

    height: 200
    clip: true

    ListModel { id: ergebnisModel }

    function pruefen() {
        ergebnisModel.clear()

        var d01 = db.drcDoppelteBmk(root.projektId)
        for (var i = 0; i < d01.length; i++) {
            var f = d01[i]
            ergebnisModel.append({
                "typ":       "doppelter_bmk",
                "meldung":   qsTr("Doppelter BMK: %1  (%2×)").arg(f.bmk).arg(f.anzahl),
                "detail":    qsTr("IDs: %1").arg(f.ids.join(", ")),
                "seiteId":   -1,
                "elementId": -1
            })
        }

        var d02 = db.drcSymboleOhneBmk(root.projektId)
        for (var j = 0; j < d02.length; j++) {
            var g = d02[j]
            ergebnisModel.append({
                "typ":       "symbol_ohne_bmk",
                "meldung":   qsTr("Symbol ohne BMK: %1").arg(g.symbolId),
                "detail":    qsTr("Seite: %1").arg(g.seiteName),
                "seiteId":   g.seiteId,
                "elementId": g.elementId
            })
        }

        var d03 = db.drcSeitenOhneBezeichnung(root.projektId)
        for (var k = 0; k < d03.length; k++) {
            var h = d03[k]
            ergebnisModel.append({
                "typ":       "seite_ohne_bezeichnung",
                "meldung":   qsTr("Seite ohne Bezeichnung: Blatt %1").arg(h.blattnummer),
                "detail":    qsTr("Seiten-ID: %1").arg(h.seiteId),
                "seiteId":   h.seiteId,
                "elementId": -1
            })
        }

        var d04 = db.drcKabeladernOhneAnschluss(root.projektId)
        for (var l = 0; l < d04.length; l++) {
            var a = d04[l]
            var aderLabel = a.aderBez !== "" ? a.aderBez : qsTr("Ader %1").arg(a.aderNr)
            ergebnisModel.append({
                "typ":       "kabelader_ohne_anschluss",
                "meldung":   qsTr("Kabelader ohne Anschluss: %1 / %2").arg(a.kabelName).arg(aderLabel),
                "detail":    a.wasFehlt,
                "seiteId":   -1,
                "elementId": -1
            })
        }

        var d05 = db.drcUnverbundenePins(root.projektId)
        for (var m = 0; m < d05.length; m++) {
            var p = d05[m]
            ergebnisModel.append({
                "typ":       "unverbundener_pin",
                "meldung":   qsTr("Unverbundener Pin: %1  Pin %2").arg(p.symbolId).arg(p.pinName),
                "detail":    qsTr("Seite: %1").arg(p.seiteName),
                "seiteId":   p.seiteId,
                "elementId": p.elementId
            })
        }

        var d06 = db.drcLeitungsenden(root.projektId)
        for (var n = 0; n < d06.length; n++) {
            var w = d06[n]
            ergebnisModel.append({
                "typ":       "leitungsende_luft",
                "meldung":   qsTr("Leitungsende in der Luft"),
                "detail":    qsTr("Seite: %1  %2").arg(w.seiteName).arg(w.endpunkt),
                "seiteId":   w.seiteId,
                "elementId": w.elementId
            })
        }

        var d07 = db.drcPotenzialkonflikte(root.projektId)
        for (var o = 0; o < d07.length; o++) {
            var pk = d07[o]
            ergebnisModel.append({
                "typ":       "potenzialkonflikt",
                "meldung":   qsTr("Potenzialkonflikt: %1").arg(pk.name),
                "detail":    qsTr("Verbindung-ID: %1").arg(pk.verbindungId),
                "seiteId":   -1,
                "elementId": -1
            })
        }

        var d08 = db.drcParallelQuellen(root.projektId)
        for (var q2 = 0; q2 < d08.length; q2++) {
            var pq = d08[q2]
            ergebnisModel.append({
                "typ":       "parallel_quellen",
                "meldung":   qsTr("Zwei Ausgänge direkt verbunden: %1  (%2×)").arg(pq.name).arg(pq.quellenAnzahl),
                "detail":    pq.seiteNamen,
                "seiteId":   -1,
                "elementId": -1
            })
        }
        var d09 = db.drcKlemmeGeister(root.projektId)
        for (var r = 0; r < d09.length; r++) {
            var kg = d09[r]
            ergebnisModel.append({
                "typ":       "klemme_geist",
                "meldung":   qsTr("Klemmenanschluss-Platzhalter: %1").arg(kg.anschlussBezeichnung || kg.bmk || "?"),
                "detail":    qsTr("Seite: %1 – noch keine echte Klemme zugewiesen").arg(kg.seiteName),
                "seiteId":   kg.seiteId,
                "elementId": kg.elementId
            })
        }

        var d11 = db.drcSchirmOhneAnschluss(root.projektId)
        for (var s2 = 0; s2 < d11.length; s2++) {
            var sh = d11[s2]
            ergebnisModel.append({
                "typ":       "schirm_ohne_anschluss",
                "meldung":   qsTr("Schirm ohne Anschluss: %1").arg(sh.bezeichnung),
                "detail":    qsTr("Seite: %1 – Anschlusspunkt berührt keine Leitung").arg(sh.seiteName),
                "seiteId":   sh.seiteId,
                "elementId": sh.elementId
            })
        }

        root.hatGeprueft = true
        achievementManager.ereignis("drc_ausgefuehrt", { "fehlerAnzahl": ergebnisModel.count })
    }

    // Hintergrund
    Rectangle {
        anchors.fill: parent
        color: root.theme.surface
        border.color: root.theme.border
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 34
            color: root.theme.surfaceHover || root.theme.border

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 8

                // Mini-Isolus als Zustandsindikator
                Item {
                    width: 22; height: 22

                    Image {
                        anchors.fill: parent
                        source:      "qrc:/assets/isolus.png"
                        fillMode:    Image.PreserveAspectFit
                        opacity:     root.hatGeprueft ? 1.0 : 0.45
                        rotation:    root.isolusZustand === "gefallen" ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 500; easing.type: Easing.InOutCubic } }
                    }

                    Rectangle {
                        anchors.fill: parent; radius: 11
                        visible: root.hatGeprueft && root.isolusZustand !== "intakt" && root.isolusZustand !== "idle"
                        color:   root.isolusZustand === "beansprucht" ? "#FFD700"
                               : root.isolusZustand === "beschaedigt" ? "#FF7700"
                               : "#FF2200"
                        opacity: root.isolusZustand === "beansprucht" ? 0.30
                               : root.isolusZustand === "beschaedigt" ? 0.42
                               : 0.58
                    }

                    Rectangle {
                        visible: root.isolusZustand === "intakt"
                        anchors { right: parent.right; bottom: parent.bottom }
                        width: 8; height: 8; radius: 4
                        color: "#44BB55"
                    }
                }
                Text {
                    text:           qsTr("DRC — Designprüfung")
                    font.pixelSize: 12
                    font.weight:    Font.Medium
                    color:          root.theme.textPrimary
                }
                Text {
                    visible:        ergebnisModel.count > 0
                    text:           qsTr("%1 Befund(e)").arg(ergebnisModel.count)
                    font.pixelSize: 11
                    color:          "#E06000"
                }
                Item { Layout.fillWidth: true }

                // Prüfen-Button
                Rectangle {
                    width: pruefenText.implicitWidth + 20
                    height: 22
                    radius: 4
                    color: pruefenMa.pressed   ? root.theme.accent
                         : pruefenMa.containsMouse ? root.theme.surfaceHover || Qt.lighter(root.theme.border)
                         : root.theme.border

                    Text {
                        id: pruefenText
                        anchors.centerIn: parent
                        text: qsTr("Prüfen")
                        font.pixelSize: 11
                        color: root.theme.textPrimary
                    }
                    MouseArea {
                        id: pruefenMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.pruefen()
                    }
                }

                // Schließen-Button
                Rectangle {
                    width: 22; height: 22
                    radius: 4
                    color: schliesseMa.pressed   ? root.theme.accent
                         : schliesseMa.containsMouse ? root.theme.surfaceHover || Qt.lighter(root.theme.border)
                         : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 11
                        color: root.theme.textMuted
                    }
                    MouseArea {
                        id: schliesseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.schliessen()
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // ── Ergebnisliste ────────────────────────────────────────
        ListView {
            id: liste
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true
            model: ergebnisModel

            ScrollBar.vertical: ScrollBar {}

            // Leer-Zustand — Isolus als Wächter
            Item {
                anchors.fill: parent
                visible: ergebnisModel.count === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Item {
                        width: 56; height: 56
                        anchors.horizontalCenter: parent.horizontalCenter

                        Image {
                            anchors.fill: parent
                            source:      "qrc:/assets/isolus.png"
                            fillMode:    Image.PreserveAspectFit
                            opacity:     root.hatGeprueft ? 1.0 : 0.45
                        }

                        Rectangle {
                            visible: root.isolusZustand === "intakt"
                            anchors { right: parent.right; bottom: parent.bottom }
                            width: 14; height: 14; radius: 7
                            color: "#44BB55"
                            Text {
                                anchors.centerIn: parent
                                text: "✓"; font.pixelSize: 9; font.weight: Font.Bold; color: "white"
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.isolusZustand === "intakt"
                              ? qsTr("Kein Befund — Isolus hält die Stellung.")
                              : qsTr("Prüfen starten")
                        font.pixelSize: 11
                        color: root.isolusZustand === "intakt" ? root.theme.textSecondary : root.theme.textMuted
                    }
                }
            }

            delegate: Rectangle {
                width: liste.width
                height: 38
                color: index % 2 === 0 ? "transparent" : (root.theme.surfaceHover || Qt.lighter(root.theme.surface))

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "⚠"
                        font.pixelSize: 12
                        color: "#E06000"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: model.meldung
                        font.pixelSize: 11
                        color: root.theme.textPrimary
                    }
                    Text {
                        text: model.detail
                        font.pixelSize: 10
                        font.family: "monospace"
                        color: root.theme.textMuted
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("DRC-Panel"); visible: root.debug }
}
