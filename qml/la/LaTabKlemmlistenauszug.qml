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
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Repeater {
                model: panel.klaCols
                delegate: Text {
                    width: modelData.w; text: modelData.header
                    font.pixelSize: 11; font.weight: Font.Medium
                    color: root.theme.textSubtle
                }
            }
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
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: panel.projektId >= 0
                          ? qsTr("Keine Klemmenleisten im Projekt")
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
                height: model.typ === "leiste" ? 26 : model.typ === "steg" ? 22 : 28

                // ── Leisten-Kopfzeile ──────────────────────────
                Rectangle {
                    visible: model.typ === "leiste"
                    anchors.fill: parent
                    color: root.theme.tableHeader
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text { text: model.typ === "leiste" ? model.bmk : ""
                               font.pixelSize: 11; font.weight: Font.Bold; color: root.theme.accent }
                        Text { text: model.typ === "leiste" ? ("– " + model.bezeichnung) : ""
                               font.pixelSize: 11; color: root.theme.textSubtle }
                    }
                }

                // ── Stegbrücken-Trennzeile ─────────────────────
                Rectangle {
                    visible: model.typ === "steg"
                    anchors.fill: parent
                    color: {
                        var st = model.signaltyp || ""
                        if (st === "pe")    return "#1a5c1a"
                        if (st === "n")     return "#1a3a5c"
                        if (st === "power") return "#5c1a1a"
                        return root.theme.activeItemAlt
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: {
                            if (model.typ !== "steg") return ""
                            var t = qsTr("Steg Eb.%1").arg(model.ebene || 1)
                            t += "  " + (model.vonNr || "?") + "–" + (model.bisNr || "?")
                            if (model.potenzial) t += "  •  " + model.potenzial
                            if (model.hatKonflikt) t += "  ⚠ Konflikt"
                            return t
                        }
                        font.pixelSize: 10; font.weight: Font.Medium
                        color: root.theme.textSecondary
                    }
                }

                // ── Anschluss-Paar-Zeile (A links, B rechts) ──
                Rectangle {
                    visible: model.typ === "anschluss"
                    anchors.fill: parent
                    color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
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
                            width: panel.klaCols[1].w; height: parent.height
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                                // Anschlussbezeichnung
                                Text {
                                    visible: (model.anschlussVon || "") !== ""
                                    text: model.anschlussVon || ""
                                    font.pixelSize: 11; font.weight: Font.Medium
                                    color: root.theme.accent
                                }
                                // Signaltyp-Punkt
                                Rectangle {
                                    visible: model.vonPlatziert && (model.vonSignaltyp || "") !== ""
                                    width: 5; height: 5; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: {
                                        var st = model.vonSignaltyp || ""
                                        if (st === "pe")      return "#4caf50"
                                        if (st === "n")       return "#42a5f5"
                                        if (st === "power")   return "#ef5350"
                                        if (st === "digital") return "#ab47bc"
                                        if (st === "analog")  return "#ff9800"
                                        return root.theme.borderLight
                                    }
                                }
                                // Verbindungstext
                                Text {
                                    width: panel.klaCols[1].w - 52
                                    text: {
                                        if (model.typ !== "anschluss") return ""
                                        if ((model.anschlussVon || "") === "") return ""
                                        if (!model.vonPlatziert) return qsTr("(nicht platziert)")
                                        var t = model.vonVerbBez || qsTr("(offen)")
                                        if (model.vonBlattnummer) t += " / S." + model.vonBlattnummer
                                        return t
                                    }
                                    font.pixelSize: 11
                                    color: {
                                        if (!model.vonPlatziert) return root.theme.borderDark
                                        if (!model.vonVerbBez)   return root.theme.borderLight
                                        return root.theme.textSecondary
                                    }
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // ── Nach (Seite B) ────────────────────
                        Item {
                            width: panel.klaCols[2].w; height: parent.height
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5
                                // Anschlussbezeichnung
                                Text {
                                    visible: (model.anschlussNach || "") !== ""
                                    text: model.anschlussNach || ""
                                    font.pixelSize: 11; font.weight: Font.Medium
                                    color: root.theme.borderLight
                                }
                                // Signaltyp-Punkt
                                Rectangle {
                                    visible: model.nachPlatziert && (model.nachSignaltyp || "") !== ""
                                    width: 5; height: 5; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: {
                                        var st = model.nachSignaltyp || ""
                                        if (st === "pe")      return "#4caf50"
                                        if (st === "n")       return "#42a5f5"
                                        if (st === "power")   return "#ef5350"
                                        if (st === "digital") return "#ab47bc"
                                        if (st === "analog")  return "#ff9800"
                                        return root.theme.borderLight
                                    }
                                }
                                // Verbindungstext
                                Text {
                                    width: panel.klaCols[2].w - 52
                                    text: {
                                        if (model.typ !== "anschluss") return ""
                                        if ((model.anschlussNach || "") === "") return ""
                                        if (!model.nachPlatziert) return qsTr("(nicht platziert)")
                                        var t = model.nachVerbBez || qsTr("(offen)")
                                        if (model.nachBlattnummer) t += " / S." + model.nachBlattnummer
                                        return t
                                    }
                                    font.pixelSize: 11
                                    color: {
                                        if (!model.nachPlatziert) return root.theme.borderDark
                                        if (!model.nachVerbBez)   return root.theme.borderLight
                                        return root.theme.textSecondary
                                    }
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // ── Querschnitt ───────────────────────
                        Text {
                            width: panel.klaCols[3].w
                            text: model.typ === "anschluss" ? (model.querschnitt || "–") : ""
                            font.pixelSize: 11; color: root.theme.borderLight; elide: Text.ElideRight
                        }

                        // ── Farbe ─────────────────────────────
                        Row {
                            width: panel.klaCols[4].w; spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 10; height: 10; radius: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: model.typ === "anschluss" && (model.farbeHex || "") !== ""
                                color: model.farbeHex || "transparent"
                                border.color: root.theme.border; border.width: 1
                            }
                            Text {
                                width: panel.klaCols[4].w - 18
                                text: model.typ === "anschluss" ? (model.farbeBez || "–") : ""
                                font.pixelSize: 11; color: root.theme.textSecondary; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
