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

    // Stegbalken-Farbe je Signaltyp
    function stegFarbe(signaltyp) {
        if (signaltyp === "pe")    return "#3a8c3a"
        if (signaltyp === "n")     return "#2a62a0"
        if (signaltyp === "power") return "#b03030"
        return root.theme.accent
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

    // ── Spaltenheader ──────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true; height: 30; color: theme.tableHeader

        Row {
            anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 0

            Text { width: panel.klaCols[0].w; text: panel.klaCols[0].header
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
            Text { width: panel.klaCols[1].w; text: panel.klaCols[1].header
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
            // Separator
            Rectangle { width: 1; height: 22; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }
            Text { width: panel.klaCols[2].w; text: panel.klaCols[2].header; leftPadding: 8
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
            Text { width: panel.klaCols[3].w; text: panel.klaCols[3].header
                   font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle }
            // Separator
            Rectangle { width: 1; height: 22; color: root.theme.border; anchors.verticalCenter: parent.verticalCenter }
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
                width: klaView.width
                height: model.typ === "leiste" ? 26 : 28

                // ── Leisten-Kopfzeile ──────────────────────────
                Rectangle {
                    visible: model.typ === "leiste"
                    anchors.fill: parent; color: root.theme.tableHeader
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: model.typ === "leiste" ? model.bmk : ""
                               font.pixelSize: 11; font.weight: Font.Bold; color: root.theme.accent }
                        Text { text: model.typ === "leiste" ? ("– " + model.bezeichnung) : ""
                               font.pixelSize: 11; color: root.theme.textSubtle }
                    }
                }

                // ── Anschluss-Paar-Zeile ───────────────────────
                Rectangle {
                    visible: model.typ === "anschluss"
                    anchors.fill: parent
                    color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd

                    // Steg-Vertikalbalken (4 px am linken Rand)
                    Rectangle {
                        id: stegBar
                        visible: model.typ === "anschluss" && (model.stegAktiv || false)
                        x: 0; width: 4; height: parent.height
                        // Abgerundete Ecken oben (erste Zeile) / unten (letzte Zeile)
                        topLeftRadius:    (model.stegIstErste  || false) ? 2 : 0
                        topRightRadius:   (model.stegIstErste  || false) ? 2 : 0
                        bottomLeftRadius: (model.stegIstLetzte || false) ? 2 : 0
                        bottomRightRadius:(model.stegIstLetzte || false) ? 2 : 0
                        color: root.stegFarbe(model.stegSignaltyp || "")

                        MouseArea {
                            id: stegMa; anchors.fill: parent; hoverEnabled: true
                        }
                        ToolTip.visible: stegMa.containsMouse && stegBar.visible
                        ToolTip.delay: 300
                        ToolTip.text: {
                            if (model.typ !== "anschluss") return ""
                            var t = qsTr("Steg Eb.%1  %2–%3")
                                    .arg(model.stegEbene || 1)
                                    .arg(model.stegVonNr || "?")
                                    .arg(model.stegBisNr || "?")
                            if (model.stegPotenzial) t += "\n" + model.stegPotenzial
                            return t
                        }
                    }

                    // Daten-Row (links nach rechts: Nr | A | sep | Qs | Farbe | sep | B)
                    Row {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        spacing: 0

                        // ── Nr. ───────────────────────────────
                        Text {
                            width: panel.klaCols[0].w
                            text: model.typ === "anschluss" ? (model.klemmeNr || "") : ""
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: root.theme.textSecondary; elide: Text.ElideRight
                        }

                        // ── Von (Seite A) ─────────────────────
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
                                    visible: (model.vonPlatziert || false) && (model.vonSignaltyp || "") !== ""
                                    width: 5; height: 5; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: _sigFarbe(model.vonSignaltyp || "")
                                }
                                Text {
                                    width: panel.klaCols[1].w - 50
                                    text: _verbText(model.anschlussVon, model.vonPlatziert,
                                                    model.vonVerbBez, model.vonBlattnummer)
                                    font.pixelSize: 11
                                    color: _verbFarbe(model.vonPlatziert, model.vonVerbBez)
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // ── Trennlinie A|Qs ───────────────────
                        Rectangle {
                            width: 1; height: 22; color: root.theme.border
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // ── Querschnitt ───────────────────────
                        Text {
                            width: panel.klaCols[2].w
                            leftPadding: 8
                            text: model.typ === "anschluss" ? (model.querschnitt || "–") : ""
                            font.pixelSize: 11; color: root.theme.borderLight; elide: Text.ElideRight
                        }

                        // ── Farbe ─────────────────────────────
                        Row {
                            width: panel.klaCols[3].w; spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 10; height: 10; radius: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: model.typ === "anschluss" && (model.farbeHex || "") !== ""
                                color: model.farbeHex || "transparent"
                                border.color: root.theme.border; border.width: 1
                            }
                            Text {
                                width: panel.klaCols[3].w - 18
                                text: model.typ === "anschluss" ? (model.farbeBez || "–") : ""
                                font.pixelSize: 11; color: root.theme.textSecondary; elide: Text.ElideRight
                            }
                        }

                        // ── Trennlinie Farbe|B ────────────────
                        Rectangle {
                            width: 1; height: 22; color: root.theme.border
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // ── Nach (Seite B) ────────────────────
                        Item {
                            width: panel.klaCols[4].w; height: 28
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                leftPadding: 8
                                Text {
                                    visible: (model.anschlussNach || "") !== ""
                                    text: model.anschlussNach || ""
                                    font.pixelSize: 11; font.weight: Font.Medium
                                    color: root.theme.borderLight
                                }
                                Rectangle {
                                    visible: (model.nachPlatziert || false) && (model.nachSignaltyp || "") !== ""
                                    width: 5; height: 5; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: _sigFarbe(model.nachSignaltyp || "")
                                }
                                Text {
                                    width: panel.klaCols[4].w - 58
                                    text: _verbText(model.anschlussNach, model.nachPlatziert,
                                                    model.nachVerbBez, model.nachBlattnummer)
                                    font.pixelSize: 11
                                    color: _verbFarbe(model.nachPlatziert, model.nachVerbBez)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Vertikale Trennlinien als durchgehende Linien über die ganze Zeilenhöhe
                    Rectangle {
                        x: 20 + panel.klaCols[0].w + panel.klaCols[1].w
                        width: 1; height: parent.height
                        color: root.theme.border; opacity: 0.5
                    }
                    Rectangle {
                        x: 20 + panel.klaCols[0].w + panel.klaCols[1].w + 1
                            + panel.klaCols[2].w + panel.klaCols[3].w
                        width: 1; height: parent.height
                        color: root.theme.border; opacity: 0.5
                    }
                }
            }

            // Hilfsfunktionen (außerhalb delegate, im ListView-Scope)
            function _sigFarbe(st) {
                if (st === "pe")      return "#4caf50"
                if (st === "n")       return "#42a5f5"
                if (st === "power")   return "#ef5350"
                if (st === "digital") return "#ab47bc"
                if (st === "analog")  return "#ff9800"
                return klaView.model ? "#888" : "#888"
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
        }
    }
}
