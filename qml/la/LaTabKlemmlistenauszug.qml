import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import stroemling

ColumnLayout {
    id: root
    required property var panel
    required property var theme
    spacing: 0

    // Breite des Steg-Indikatorbereichs zwischen Qs und Farbe
    readonly property int _stegBreite: 18

    // ── Hilfsfunktionen (root-Scope → AOT-sicher) ──────────────
    function stegFarbe(st) {
        if (st === "pe")    return "#3a8c3a"
        if (st === "n")     return "#2a62a0"
        if (st === "power") return "#b03030"
        return root.theme.accent
    }
    function _sigFarbe(st) {
        if (st === "pe")      return "#4caf50"
        if (st === "n")       return "#42a5f5"
        if (st === "power")   return "#ef5350"
        if (st === "digital") return "#ab47bc"
        if (st === "analog")  return "#ff9800"
        return "#888"
    }
    function _verbText(bez, platz, verbBez, bl) {
        if ((bez || "") === "") return ""
        if (!platz) return qsTr("(nicht platziert)")
        var t = verbBez || qsTr("(offen)")
        if (bl) t += " / S." + bl
        return t
    }
    function _verbFarbe(platz, verbBez) {
        if (!platz)   return root.theme.borderDark
        if (!verbBez) return root.theme.borderLight
        return root.theme.textSecondary
    }
    // Dezente Hintergrundfarbe für Steg-Gruppen-Zeilen
    function _stegBgFarbe(st) {
        return Qt.alpha(root.stegFarbe(st), 0.17)
    }

    FileDialog {
        id: csvDialog
        fileMode: FileDialog.SaveFile
        title: qsTr("Klemmlistenauszug als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.klemmlistenauszugCsvSpeichern(panel.projektId, selectedFile)
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Klemmlistenauszug")
        anzahl: panel._klaAnschlussZaehler
        onCsvKlick: csvDialog.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    // ── Spaltenheader ────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true; height: 30; color: theme.tableHeader

        Row {
            anchors { left: parent.left; leftMargin: 8
                      verticalCenter: parent.verticalCenter }
            spacing: 0

            Text { width: panel.klaCols[0].w; text: panel.klaCols[0].header
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
            Text { width: panel.klaCols[1].w; text: panel.klaCols[1].header
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
            Rectangle { width: 1; height: 22; color: root.theme.border
                        anchors.verticalCenter: parent.verticalCenter }
            Text { width: panel.klaCols[2].w; text: panel.klaCols[2].header; leftPadding: 8
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
            // Steg-Spalte (kein Spaltenheader-Text, wird visuell genutzt)
            Item { width: root._stegBreite; height: 22 }
            Text { width: panel.klaCols[3].w; text: panel.klaCols[3].header
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
            Rectangle { width: 1; height: 22; color: root.theme.border
                        anchors.verticalCenter: parent.verticalCenter }
            Text { width: panel.klaCols[4].w; text: panel.klaCols[4].header; leftPadding: 8
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true

        ListView {
            id: klaView
            model: panel._klaModel; clip: true

            // Leer-Zustand
            Column {
                visible: panel._klaAnschlussZaehler === 0
                anchors.centerIn: parent; spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId >= 0 ? qsTr("Keine Klemmenleisten im Projekt")
                                               : qsTr("Kein Projekt ausgewählt")
                    font.pixelSize: 14; color: root.theme.borderDark
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: panel.projektId >= 0
                    text: qsTr("Klemmenleisten unter Bauteile → Klemmenreihen anlegen.")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                }
            }

            delegate: Item {
                id: klaDelegate
                width: klaView.width
                height: model.typ === "leiste" ? 26 : 28

                // Nur die Stegs dieser Ebene (für Klammer-Indikator)
                property var _stegs: {
                    if (model.typ !== "anschluss") return []
                    try {
                        var all = JSON.parse(model.stegJson || "[]")
                        return all.filter(function(s) { return s.eb === model.ebene })
                    } catch(e) { return [] }
                }
                // Hintergrundfarbe: alle Ebenen-Zeilen einer Steg-Klemme einfärben.
                // Bevorzugt die Farbe des zur aktuellen Ebene passenden Stegs.
                property color _stegBg: {
                    if (model.typ !== "anschluss") return "transparent"
                    try {
                        var all = JSON.parse(model.stegJson || "[]")
                        if (all.length === 0) return "transparent"
                        for (var i = 0; i < all.length; i++) {
                            if (all[i].eb === model.ebene)
                                return root._stegBgFarbe(all[i].st || "")
                        }
                        // Andere Ebene dieser Klemme: gleiche Farbe, noch dezenter
                        return Qt.alpha(root.stegFarbe(all[0].st || ""), 0.09)
                    } catch(e) { return "transparent" }
                }

                // ── Leisten-Kopfzeile ─────────────────────────
                Rectangle {
                    visible: model.typ === "leiste"
                    anchors.fill: parent; color: root.theme.tableHeader
                    Row {
                        anchors { left: parent.left; leftMargin: 12
                                  verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: model.typ === "leiste" ? model.bmk : ""
                               font.pixelSize: 11; font.weight: Font.Bold
                               color: root.theme.accent }
                        Text { text: model.typ === "leiste" ? ("– " + model.bezeichnung) : ""
                               font.pixelSize: 11; color: root.theme.textSubtle }
                    }
                }

                // ── Anschluss-Paar-Zeile ──────────────────────
                Rectangle {
                    visible: model.typ === "anschluss"
                    anchors.fill: parent
                    color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd

                    // Steg-Gruppen-Einfärbung (halbtransparent über Zebramuster)
                    Rectangle {
                        anchors.fill: parent
                        color: klaDelegate._stegBg
                        visible: klaDelegate._stegBg !== Qt.rgba(0,0,0,0)
                    }

                    // Daten-Row: Nr | A | sep | Qs | [Steg] | Farbe | sep | B
                    Row {
                        anchors { left: parent.left; leftMargin: 8
                                  verticalCenter: parent.verticalCenter }
                        spacing: 0

                        // Nr.
                        Text {
                            width: panel.klaCols[0].w
                            text: model.typ === "anschluss" ? (model.klemmeNr || "") : ""
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: root.theme.textSecondary; elide: Text.ElideRight
                        }

                        // Von (Seite A)
                        Item {
                            width: panel.klaCols[1].w; height: 28
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                Text {
                                    visible: (model.anschlussVon || "") !== ""
                                    text: model.anschlussVon || ""
                                    font.pixelSize: 11; font.weight: Font.Medium
                                    color: root.theme.accent
                                }
                                Rectangle {
                                    visible: (model.vonPlatziert || false) &&
                                             (model.vonSignaltyp || "") !== ""
                                    width: 5; height: 5; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root._sigFarbe(model.vonSignaltyp || "")
                                }
                                Text {
                                    width: panel.klaCols[1].w - 50
                                    text: root._verbText(model.anschlussVon,
                                                         model.vonPlatziert,
                                                         model.vonVerbBez,
                                                         model.vonBlattnummer)
                                    font.pixelSize: 11
                                    color: root._verbFarbe(model.vonPlatziert,
                                                           model.vonVerbBez)
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Trennlinie A|Qs
                        Rectangle {
                            width: 1; height: 22; color: root.theme.border
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Querschnitt
                        Text {
                            width: panel.klaCols[2].w; leftPadding: 8
                            text: model.typ === "anschluss" ? (model.querschnitt || "–") : ""
                            font.pixelSize: 11; color: root.theme.borderLight
                            elide: Text.ElideRight
                        }

                        // ── Steg-Indikatoren (zentriert in _stegBreite px) ──
                        Item {
                            width: root._stegBreite; height: klaDelegate.height

                            Row {
                                anchors.centerIn: parent
                                spacing: 2

                                Repeater {
                                    model: klaDelegate._stegs

                                    Item {
                                        width: 4; height: klaDelegate.height

                                        // Verbindungsbalken (volle Höhe für mittlere Zeilen,
                                        // halbe Höhe für erste / letzte Zeile der Gruppe)
                                        Rectangle {
                                            width: 2
                                            color: root.stegFarbe(modelData.st || "")
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: !(modelData.er && modelData.la)
                                            y: modelData.er ? parent.height * 0.5 : 0
                                            height: (modelData.er || modelData.la)
                                                    ? parent.height * 0.5
                                                    : parent.height
                                        }
                                        // Querstrich in Zeilenmitte (Gruppenanfang/-ende)
                                        Rectangle {
                                            visible: modelData.er || modelData.la
                                            width: parent.width; height: 2
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: parent.height * 0.5 - 1
                                            color: root.stegFarbe(modelData.st || "")
                                        }

                                        MouseArea {
                                            id: stegMa; anchors.fill: parent
                                            hoverEnabled: true
                                        }
                                        ToolTip.visible: stegMa.containsMouse
                                        ToolTip.delay: 300
                                        ToolTip.text: {
                                            var t = qsTr("Steg Eb.%1  %2–%3")
                                                    .arg(modelData.eb || 1)
                                                    .arg(modelData.vn || "?")
                                                    .arg(modelData.bn || "?")
                                            if (modelData.pot) t += "\n" + modelData.pot
                                            return t
                                        }
                                    }
                                }
                            }
                        }

                        // Farbe
                        Row {
                            width: panel.klaCols[3].w; spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 10; height: 10; radius: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: model.typ === "anschluss" &&
                                         (model.farbeHex || "") !== ""
                                color: model.farbeHex || "transparent"
                                border.color: root.theme.border; border.width: 1
                            }
                            Text {
                                width: panel.klaCols[3].w - 18
                                text: model.typ === "anschluss" ? (model.farbeBez || "–") : ""
                                font.pixelSize: 11; color: root.theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }

                        // Trennlinie Farbe|B
                        Rectangle {
                            width: 1; height: 22; color: root.theme.border
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Nach (Seite B)
                        Item {
                            width: panel.klaCols[4].w; height: 28
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4; leftPadding: 8
                                Text {
                                    visible: (model.anschlussNach || "") !== ""
                                    text: model.anschlussNach || ""
                                    font.pixelSize: 11; font.weight: Font.Medium
                                    color: root.theme.borderLight
                                }
                                Rectangle {
                                    visible: (model.nachPlatziert || false) &&
                                             (model.nachSignaltyp || "") !== ""
                                    width: 5; height: 5; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root._sigFarbe(model.nachSignaltyp || "")
                                }
                                Text {
                                    width: panel.klaCols[4].w - 58
                                    text: root._verbText(model.anschlussNach,
                                                         model.nachPlatziert,
                                                         model.nachVerbBez,
                                                         model.nachBlattnummer)
                                    font.pixelSize: 11
                                    color: root._verbFarbe(model.nachPlatziert,
                                                           model.nachVerbBez)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Durchgehende Trennlinien (volle Zeilenhöhe)
                    // Position: leftMargin + Nr + Von
                    Rectangle {
                        x: 8 + panel.klaCols[0].w + panel.klaCols[1].w
                        width: 1; height: parent.height
                        color: root.theme.border; opacity: 0.5
                    }
                    // Position: leftMargin + Nr + Von + sep + Qs + Steg + Farbe
                    Rectangle {
                        x: 8 + panel.klaCols[0].w + panel.klaCols[1].w + 1
                            + panel.klaCols[2].w + root._stegBreite + panel.klaCols[3].w
                        width: 1; height: parent.height
                        color: root.theme.border; opacity: 0.5
                    }
                }
            }
        }
    }
}
