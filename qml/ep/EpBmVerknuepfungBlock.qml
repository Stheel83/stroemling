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

        Column {
            id: verknuepfungCol
            width: parent.width
            spacing: 4

            // ── Status-Zeile ──────────────────────────
            Rectangle {
                width: parent.width; height: 28
                color: theme.inputBg; radius: 3
                border.color: {
                    if (verknuepfungItem.istHauptfunktion)   return theme.accent
                    if (verknuepfungItem.hauptfunktionFehlt) return "#cc7700"
                    return theme.border
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
            Row {
                visible: verknuepfungItem.bmId > 0
                spacing: 4
                Rectangle {
                    width: (verknuepfungItem.width - 4) / 2; height: 24; radius: 3
                    color: hfMa.containsMouse && !verknuepfungItem.istHauptfunktion
                           ? theme.border : theme.inputBg
                    border.color: verknuepfungItem.istHauptfunktion ? theme.accent : theme.border
                    opacity: verknuepfungItem.istHauptfunktion ? 0.5 : 1.0
                    Text {
                        anchors.centerIn: parent
                        text: "★ " + qsTr("Als HF festlegen")
                        font.pixelSize: 10
                        color: verknuepfungItem.istHauptfunktion ? theme.accent : theme.textMuted
                    }
                    MouseArea {
                        id: hfMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: !verknuepfungItem.istHauptfunktion
                        onClicked: {
                            db.betriebsmittelHauptfunktionSetzen(
                                verknuepfungItem.bmId, panel.el.id)
                            verknuepfungItem._refresh++
                            panel.canvas.hfKarteAktualisieren()
                        }
                    }
                }
                Rectangle {
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

            // ── Mitglieder-Liste ──────────────────────
            Column {
                visible: verknuepfungItem.bmId > 0
                width: parent.width
                spacing: 1
                Repeater {
                    model: verknuepfungItem.bmId > 0
                           ? db.betriebsmittelMitglieder(verknuepfungItem.bmId) : []
                    delegate: Rectangle {
                        width: verknuepfungItem.width; height: 22
                        color: modelData.id === (panel.el ? panel.el.id : -1)
                               ? theme.activeItemAlt : "transparent"
                        radius: 2
                        Row {
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            spacing: 5
                            Rectangle {
                                width: 3; height: 14; radius: 1
                                color: modelData.id === (panel.el ? panel.el.id : -1)
                                       ? theme.accent : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.istHauptfunktion ? "★" : "◆"
                                font.pixelSize: 9
                                color: modelData.istHauptfunktion ? theme.accent : theme.borderLight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.symbolId || modelData.typ || "–"
                                font.pixelSize: 9; color: theme.borderLight
                                width: 52; elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.blattnummer || "–"
                                font.pixelSize: 9; color: theme.textMuted
                                width: 26; elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }
    }
    Item { height: 4 }
}
