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
                id: delRoot
                width: klaView.width
                height: {
                    if (model.typ === "leiste")    return 26
                    if (model.typ === "steg")      return 22
                    return 28
                }

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
                        if (st === "pe")      return "#1a5c1a"
                        if (st === "n")       return "#1a3a5c"
                        if (st === "power")   return "#5c1a1a"
                        return root.theme.activeItemAlt
                    }
                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Text {
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
                }

                // ── Anschluss-Datenzeile ───────────────────────
                Rectangle {
                    visible: model.typ === "anschluss"
                    anchors.fill: parent
                    color: index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0

                        // Nr.
                        Text {
                            width: panel.klaCols[0].w
                            text: model.typ === "anschluss" ? (model.klemmeNr || "") : ""
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: root.theme.textSecondary; elide: Text.ElideRight
                        }

                        // Anschluss
                        Text {
                            width: panel.klaCols[1].w
                            text: model.typ === "anschluss" ? (model.anschlussBez || "") : ""
                            font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                        }

                        // Seite (A/B/PE)
                        Rectangle {
                            width: panel.klaCols[2].w
                            height: parent.height
                            color: "transparent"
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.typ === "anschluss" ? (model.seite || "") : ""
                                font.pixelSize: 11
                                color: {
                                    var s = model.seite || ""
                                    if (s === "A")  return root.theme.accent
                                    if (s === "PE") return "#4caf50"
                                    return root.theme.borderLight
                                }
                            }
                        }

                        // Verbindung (Netz + Seite)
                        Item {
                            width: panel.klaCols[3].w
                            height: parent.height
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                // Signaltyp-Punkt
                                Rectangle {
                                    visible: model.typ === "anschluss" && model.platziert && model.signaltyp !== ""
                                    width: 6; height: 6; radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: {
                                        var st = model.signaltyp || ""
                                        if (st === "pe")      return "#4caf50"
                                        if (st === "n")       return "#42a5f5"
                                        if (st === "power")   return "#ef5350"
                                        if (st === "digital") return "#ab47bc"
                                        if (st === "analog")  return "#ff9800"
                                        return root.theme.borderLight
                                    }
                                }
                                Text {
                                    width: panel.klaCols[3].w - 14
                                    text: {
                                        if (model.typ !== "anschluss") return ""
                                        if (!model.platziert) return qsTr("(nicht platziert)")
                                        var t = model.verbBez || qsTr("(offen)")
                                        if (model.blattnummer) t += " / S." + model.blattnummer
                                        return t
                                    }
                                    font.pixelSize: 11
                                    color: {
                                        if (model.typ !== "anschluss") return root.theme.textSubtle
                                        if (!model.platziert) return root.theme.borderDark
                                        if (!model.verbBez)   return root.theme.borderLight
                                        return root.theme.textSecondary
                                    }
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Querschnitt
                        Text {
                            width: panel.klaCols[4].w
                            text: model.typ === "anschluss" ? (model.querschnitt || "–") : ""
                            font.pixelSize: 11; color: root.theme.borderLight; elide: Text.ElideRight
                        }

                        // Farbe
                        Row {
                            width: panel.klaCols[5].w
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 10; height: 10; radius: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: model.typ === "anschluss" && (model.farbeHex || "") !== ""
                                color: (model.farbeHex || "transparent")
                                border.color: root.theme.border; border.width: 1
                            }
                            Text {
                                width: panel.klaCols[5].w - 18
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
