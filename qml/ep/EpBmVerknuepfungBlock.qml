import QtQuick
import QtQuick.Controls

// Geräteverknüpfung-Block: Status, Verknüpfen/Trennen, HF-Festlegen, Mitglieder.
// Kommuniziert über `panel` und Signal `verknuepfenAngefordert()`.
Column {
    id: root

    required property var panel
    required property var theme
    signal verknuepfenAngefordert()

    width:   parent ? parent.width : 0
    spacing: 0

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    FeldLabel { text: qsTr("Geräteverknüpfung") }

    Item {
        id: verknuepfungItem
        width: parent.width - 16
        anchors.horizontalCenter: parent.horizontalCenter
        height: verknuepfungCol.implicitHeight

        property int  bmId: (panel.el && panel.el.betriebsmittelId > 0)
                            ? panel.el.betriebsmittelId : 0
        property int  _refresh: 0
        property var  bmInfo: {
            _refresh
            return bmId > 0 ? db.betriebsmittelInfo(bmId) : ({})
        }
        property bool istHauptfunktion:   bmId > 0
                                          && bmInfo.hauptElementId > 0
                                          && bmInfo.hauptElementId === (panel.el ? panel.el.id : -1)
        property bool hauptfunktionFehlt: bmId > 0 && (bmInfo.hauptElementId || 0) === 0
        property bool _hasBmk: {
            var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
            return (ed.bmk || "").trim() !== ""
        }

        Column {
            id: verknuepfungCol
            width: parent.width
            spacing: 4

            // ── Status-Zeile ──────────────────────────
            Rectangle {
                id: statusZeile
                width: parent.width; height: 28
                color: theme.inputBg; radius: 3
                border.color: {
                    if (verknuepfungItem.istHauptfunktion)   return theme.accent
                    if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                    return theme.border
                }

                readonly property string statusTip: {
                    if (!verknuepfungItem.bmId)
                        return qsTr("○ Nicht verknüpft – dieses Symbol gehört noch zu keinem Betriebsmittel")
                    if (verknuepfungItem.istHauptfunktion)
                        return qsTr("★ Hauptfunktion – das steuernde Symbol (z. B. Spule), von dem alle Kontakte die BMK erben")
                    if (verknuepfungItem.hauptfunktionFehlt)
                        return qsTr("⚠ Hauptfunktion fehlt – dem Betriebsmittel ist noch kein Symbol als Hauptfunktion zugewiesen")
                    return qsTr("◆ Nebenfunktion – ein Kontakt dieses Betriebsmittels, BMK wird von der Hauptfunktion übernommen")
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    ToolTip.visible: containsMouse
                    ToolTip.text:    statusZeile.statusTip
                    ToolTip.delay:   500
                }

                Row {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!verknuepfungItem.bmId)              return "○"
                            if (verknuepfungItem.istHauptfunktion)   return "★"
                            if (verknuepfungItem.hauptfunktionFehlt) return "⚠"
                            return "◆"
                        }
                        font.pixelSize: 11
                        color: {
                            if (verknuepfungItem.istHauptfunktion)   return theme.accent
                            if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                            if (verknuepfungItem.bmId > 0)           return theme.textSecondary
                            return theme.borderLight
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: verknuepfungItem.bmId > 0
                              ? (verknuepfungItem.bmInfo.kz || "–") : ""
                        font.pixelSize: 11; font.bold: verknuepfungItem.istHauptfunktion
                        color: theme.accent
                        visible: verknuepfungItem.bmId > 0
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!verknuepfungItem.bmId)              return qsTr("nicht verknüpft")
                            if (verknuepfungItem.istHauptfunktion)   return qsTr("Hauptfunktion")
                            if (verknuepfungItem.hauptfunktionFehlt) return qsTr("HF nicht platziert")
                            return qsTr("Nebenfunktion")
                        }
                        font.pixelSize: 10
                        color: {
                            if (verknuepfungItem.istHauptfunktion)   return theme.accent
                            if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                            if (verknuepfungItem.bmId > 0)           return theme.textMuted
                            return theme.borderLight
                        }
                    }
                }
            }

            // ── Aktions-Buttons Zeile 1: Verknüpfen / Trennen ──
            Row {
                spacing: 4
                Rectangle {
                    width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                    color: verknLinkMa.containsMouse ? theme.border : theme.inputBg
                    border.color: theme.border
                    Text { anchors.centerIn: parent; text: qsTr("Verknüpfen …")
                           font.pixelSize: 10; color: theme.accent }
                    MouseArea {
                        id: verknLinkMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.verknuepfenAngefordert()
                    }
                }
                Rectangle {
                    width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                    color: verknTrennenMa.containsMouse ? theme.border : theme.inputBg
                    border.color: theme.border
                    opacity: verknuepfungItem.bmId > 0 ? 1.0 : 0.4
                    Text { anchors.centerIn: parent; text: qsTr("Trennen")
                           font.pixelSize: 10; color: theme.borderLight }
                    MouseArea {
                        id: verknTrennenMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: verknuepfungItem.bmId > 0
                        onClicked: {
                            db.grafikElementEntknuepfen(panel.el.id)
                            panel.canvas.eigenschaftAktualisieren("betriebsmittelId", 0)
                        }
                    }
                }
            }

            // ── Aktions-Buttons Zeile 2: Hauptfunktion / BMK-Sync ──
            // HF-Button erscheint auch ohne BM wenn ein BMK eingetragen ist.
            Row {
                visible: !verknuepfungItem.istHauptfunktion
                         && (verknuepfungItem.bmId > 0 || verknuepfungItem._hasBmk)
                spacing: 4
                Rectangle {
                    width: verknuepfungItem.bmId > 0
                           ? (verknuepfungItem.width - 4) / 2 : verknuepfungItem.width
                    height: 24; radius: 3
                    color: hfMa.containsMouse ? theme.border : theme.inputBg
                    border.color: theme.border
                    Text {
                        anchors.centerIn: parent
                        text: "★ " + qsTr("Als HF festlegen")
                        font.pixelSize: 10; color: theme.textMuted
                    }
                    MouseArea {
                        id: hfMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var bmId = verknuepfungItem.bmId
                            if (bmId <= 0) {
                                var kz = (panel.el && panel.el.extraDaten
                                          && panel.el.extraDaten.bmk)
                                         ? panel.el.extraDaten.bmk.trim() : ""
                                if (kz === "") return
                                bmId = db.betriebsmittelAnlegen(
                                    panel.canvas.projektId, kz, "")
                                if (bmId <= 0) return
                                // Nur gezielte UPDATEs – kein eigenschaftAktualisieren,
                                // das würde DELETE+INSERT triggern und alle Element-IDs
                                // invalidieren (FK setzt haupt_element_id auf NULL).
                                db.grafikElementVerknuepfen(panel.el.id, bmId)
                                db.betriebsmittelBmkSynchronisieren(bmId)
                            }
                            db.betriebsmittelHauptfunktionSetzen(bmId, panel.el.id)
                            // seiteNeuLaden() liest per SELECT aus DB – keine ID-Änderung.
                            // In-Memory-Modell bekommt betriebsmittelId aus der DB zurück.
                            panel.canvas.seiteNeuLaden()
                            verknuepfungItem._refresh++
                            panel.canvas.hfKarteAktualisieren()
                        }
                    }
                }
                Rectangle {
                    visible: verknuepfungItem.bmId > 0
                    width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                    color: syncMa.containsMouse ? theme.border : theme.inputBg
                    border.color: theme.border
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("BMK sync.")
                        font.pixelSize: 10; color: theme.textMuted
                    }
                    ToolTip.visible: syncMa.containsMouse
                    ToolTip.text:    qsTr("BMK aller verknüpften Elemente auf\n\"%1\" setzen").arg(
                                         verknuepfungItem.bmInfo.kz || "")
                    ToolTip.delay:   500
                    MouseArea {
                        id: syncMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            db.betriebsmittelBmkSynchronisieren(verknuepfungItem.bmId)
                            panel.canvas.seiteNeuLaden()
                            verknuepfungItem._refresh++
                        }
                    }
                }
            }

            // ── Kontaktspiegel ────────────────────────
            Column {
                visible: verknuepfungItem.bmId > 0
                width: parent.width
                spacing: 0

                // Header
                Rectangle {
                    width: parent.width; height: 20
                    color: theme.surfaceDeep; radius: 2
                    Row {
                        anchors { fill: parent; leftMargin: 7; rightMargin: 4 }
                        spacing: 0
                        Text {
                            width: 56; height: parent.height
                            text: qsTr("Anschluss")
                            font.pixelSize: 9; font.weight: Font.Medium
                            color: theme.borderLight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 52; height: parent.height
                            text: qsTr("Typ")
                            font.pixelSize: 9; font.weight: Font.Medium
                            color: theme.borderLight
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            width: 36; height: parent.height
                            text: qsTr("Blatt")
                            font.pixelSize: 9; font.weight: Font.Medium
                            color: theme.borderLight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Repeater {
                    model: verknuepfungItem.bmId > 0
                           ? db.betriebsmittelMitglieder(verknuepfungItem.bmId) : []
                    delegate: Rectangle {
                        id: ksZeile
                        width: verknuepfungItem.width; height: 24
                        color: modelData.id === (panel.el ? panel.el.id : -1)
                               ? theme.activeItemAlt : (zeileMa.containsMouse ? theme.hover : "transparent")
                        radius: 2

                        MouseArea { id: zeileMa; anchors.fill: parent; hoverEnabled: true }

                        Row {
                            anchors { left: parent.left; right: parent.right
                                      leftMargin: 4; rightMargin: 4
                                      verticalCenter: parent.verticalCenter }
                            spacing: 0

                            Rectangle {
                                width: 3; height: 14; radius: 1
                                anchors.verticalCenter: parent.verticalCenter
                                color: modelData.id === (panel.el ? panel.el.id : -1)
                                       ? theme.accent : "transparent"
                            }

                            Text {
                                width: 56; height: ksZeile.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.istHauptfunktion
                                      ? "★ HF"
                                      : (modelData.anschlusskennzeichnung || "–")
                                font.pixelSize: 10; font.bold: modelData.istHauptfunktion
                                color: modelData.istHauptfunktion ? theme.accent : theme.textMuted
                                elide: Text.ElideRight
                            }

                            Text {
                                width: 52; height: ksZeile.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.symbolId || modelData.typ || "–"
                                font.pixelSize: 9; color: theme.borderLight
                                elide: Text.ElideRight
                            }

                            Text {
                                width: 28; height: ksZeile.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.blattnummer || "–"
                                font.pixelSize: 9; color: theme.textMuted
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: 20; height: 18; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: sprungMa.containsMouse ? theme.accent : "transparent"
                                border.color: sprungMa.containsMouse ? theme.accent : theme.border
                                Text {
                                    anchors.centerIn: parent
                                    text: "→"; font.pixelSize: 10
                                    color: sprungMa.containsMouse ? "#ffffff" : theme.accent
                                }
                                MouseArea {
                                    id: sprungMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.canvas.bmElementSprungAnfordern(
                                        modelData.seiteId,
                                        modelData.blattnummer,
                                        modelData.seiteBezeichnung,
                                        modelData.weltX,
                                        modelData.weltY)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Item { height: 4 }
}
