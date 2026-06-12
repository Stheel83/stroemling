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

    // Breite je Steg-Spalte in px
    readonly property int _stegSlotBreite: 10
    // Gesamtbreite Steg-Block (mindestens 0, wächst mit Steg-Anzahl)
    readonly property int _stegBreite: panel._klaMaxStegSpalten * _stegSlotBreite

    // ── Hilfsfunktionen ─────────────────────────────────────────
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
                   font.pixelSize: 11; font.weight: Font.Medium
                   color: root.theme.textSubtle }
            Text { width: panel.klaCols[1].w; text: panel.klaCols[1].header
                   font.pixelSize: 11; font.weight: Font.Medium
                   color: root.theme.textSubtle }
            Rectangle { width: 1; height: 22; color: root.theme.border
                        anchors.verticalCenter: parent.verticalCenter }
            Text { width: panel.klaCols[2].w; text: panel.klaCols[2].header
                   leftPadding: 8; font.pixelSize: 11; font.weight: Font.Medium
                   color: root.theme.textSubtle }
            // Steg-Block (keine Beschriftung, Breite dynamisch)
            Item { width: root._stegBreite; height: 22 }
            Text { width: panel.klaCols[3].w; text: panel.klaCols[3].header
                   font.pixelSize: 11; font.weight: Font.Medium
                   color: root.theme.textSubtle }
            Rectangle { width: 1; height: 22; color: root.theme.border
                        anchors.verticalCenter: parent.verticalCenter }
            Text { width: panel.klaCols[4].w; text: panel.klaCols[4].header
                   leftPadding: 8; font.pixelSize: 11; font.weight: Font.Medium
                   color: root.theme.textSubtle }
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

                // ── Felder die Steg-Slots benötigen ──────────
                property int _ks: model.typ === "anschluss" ? (model.klemmeSort    || 0) : 0
                property int _eb: model.typ === "anschluss" ? (model.ebene        || 0) : 0
                property int _ri: model.typ === "anschluss" ? (model.klemmeReiheIdx  || 0) : 0
                property int _rn: model.typ === "anschluss" ? (model.klemmeReihenAnz || 1) : 1
                property var _ls: {
                    if (model.typ !== "anschluss") return []
                    try { return JSON.parse(model.leisteStegJson || "[]") } catch(e) { return [] }
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

                    // Daten-Row: Nr | A | sep | Qs | [Steg-Spalten] | Farbe | sep | B
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
                                    color: root._verbFarbe(model.vonPlatziert, model.vonVerbBez)
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

                        // ── Steg-Spalten (eine je Leisten-Steg) ───────────────
                        Item {
                            id: stegBlock
                            width: root._stegBreite; height: klaDelegate.height

                            Row {
                                anchors.left: parent.left
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                spacing: 0

                                Repeater {
                                    model: klaDelegate._ls.length

                                    Item {
                                        id: stegSlot
                                        width: root._stegSlotBreite
                                        height: stegBlock.height

                                        property var   sd: klaDelegate._ls[index]
                                        property int   ks: klaDelegate._ks
                                        property int   re: klaDelegate._eb

                                        // Status dieser Zeile für diesen Steg
                                        readonly property bool _inRange:
                                            sd != null && ks >= sd.vs && ks <= sd.bs
                                        readonly property bool _active:
                                            _inRange && re === sd.eb
                                        // Durchlauf: Klemme ist in Range, aber falsche Ebene,
                                        // jedoch noch zwischen erster und letzter aktiven Zeile
                                        readonly property bool _through: {
                                            if (!_inRange || _active) return false
                                            if (ks === sd.vs && re < sd.eb) return false
                                            if (ks === sd.bs && re > sd.eb) return false
                                            return true
                                        }
                                        // Querstrich nur an allererster / allerletzter Zeile der Klemme
                                        readonly property bool _er: _active && ks === sd.vs && klaDelegate._ri === 0
                                        readonly property bool _la: _active && ks === sd.bs && klaDelegate._ri === (klaDelegate._rn - 1)

                                        // Vertikaler Balken
                                        Rectangle {
                                            visible: (stegSlot._active || stegSlot._through) &&
                                                     !(stegSlot._er && stegSlot._la)
                                            width: 3
                                            color: root.stegFarbe(stegSlot.sd ? stegSlot.sd.st || "" : "")
                                            opacity: stegSlot._through ? 0.28 : 1.0
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: stegSlot._er ? parent.height * 0.5 : 0
                                            height: (stegSlot._er || stegSlot._la)
                                                    ? parent.height * 0.5 : parent.height
                                        }
                                        // Querstrich (Gruppenanfang/-ende, nur aktive Ebene)
                                        Rectangle {
                                            visible: stegSlot._er || stegSlot._la
                                            width: parent.width; height: 2
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: parent.height * 0.5 - 1
                                            color: root.stegFarbe(stegSlot.sd ? stegSlot.sd.st || "" : "")
                                        }

                                        MouseArea {
                                            id: ssMa; anchors.fill: parent; hoverEnabled: true
                                        }
                                        ToolTip.visible: ssMa.containsMouse &&
                                                         (stegSlot._active || stegSlot._through)
                                        ToolTip.delay: 300
                                        ToolTip.text: {
                                            if (!stegSlot.sd) return ""
                                            var t = qsTr("Steg Eb.%1  %2–%3")
                                                    .arg(stegSlot.sd.eb || 1)
                                                    .arg(stegSlot.sd.vn || "?")
                                                    .arg(stegSlot.sd.bn || "?")
                                            if (stegSlot.sd.pot) t += "\n" + stegSlot.sd.pot
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
                                    color: root._verbFarbe(model.nachPlatziert, model.nachVerbBez)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Durchgehende Trennlinien (volle Zeilenhöhe)
                    Rectangle {
                        x: 8 + panel.klaCols[0].w + panel.klaCols[1].w
                        width: 1; height: parent.height
                        color: root.theme.border; opacity: 0.5
                    }
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
