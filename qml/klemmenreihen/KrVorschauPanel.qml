import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    required property var panel
    required property var theme

    DebugLabel { panelName: qsTr("Klemmenreihen-Vorschau"); visible: panel.debug }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Kopfzeile
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color:  theme.surfaceDeep
            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                Text {
                    text: klemmenreiheModel.hatLeiste
                          ? (klemmenreiheModel.leiste["bmkKurz"] || "-" + (klemmenreiheModel.leiste["bezeichnung"] || ""))
                          : ""
                    font.pixelSize: 14; font.weight: Font.Medium
                    color: theme.accent
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: klemmenreiheModel.hatLeiste && klemmenreiheModel.leiste["gesamtBreiteMm"] > 0
                    text: {
                        if (!klemmenreiheModel.hatLeiste) return ""
                        var kl = klemmenreiheModel.klemmen
                        var ohneAngabe = 0
                        for (var i = 0; i < kl.length; ++i)
                            if (kl[i].breiteMm === 0) ohneAngabe++
                        var total = 0
                        for (var j = 0; j < kl.length; ++j)
                            total += kl[j].breiteMm
                        var t = total.toFixed(1) + " mm"
                        if (ohneAngabe > 0) t += "  (" + ohneAngabe + qsTr(" ohne Angabe") + ")"
                        return t
                    }
                    font.pixelSize: 11
                    color: theme.textMuted
                }
            }
        }
        Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

        // Klemmen-Reihe mit Stegbrücken-Balken (scrollbar horizontal)
        ScrollView {
            id:                klemScrollView
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentWidth:      klemmenRow.x + klemmenRow.implicitWidth + 16
            clip:              true

            Item {
                width:  Math.max(klemScrollView.availableWidth,
                                 klemmenRow.x + klemmenRow.implicitWidth + 16)
                height: klemScrollView.availableHeight

                Row {
                    id:      klemmenRow
                    x:       16
                    y:       Math.max(8, (parent.height
                             - klemmenRow.implicitHeight
                             - (stegBars.visible ? stegBars.height + 8 : 0)) / 2)
                    spacing: 2
                    padding: 0

                    Repeater {
                        model: klemmenreiheModel.klemmen

                        delegate: Rectangle {
                            width:   Math.max(48, modelData.breiteMm > 0 ? modelData.breiteMm * 4 : 48)
                            height:  80
                            radius:  3
                            color:   panel.aktivKlemmeIdx === index
                                     ? theme.activeItemAlt
                                     : (klemmeMa.containsMouse ? theme.hover : theme.surface)
                            border.color: panel.aktivKlemmeIdx === index ? theme.accent : theme.border
                            border.width: panel.aktivKlemmeIdx === index ? 2 : 1

                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text:            modelData.nummer || String(index + 1)
                                    font.pixelSize:  12; font.weight: Font.Bold
                                    color:           panel.aktivKlemmeIdx === index ? theme.accent : theme.textPrimary
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: modelData.breiteMm > 0
                                    text:    modelData.breiteMm.toFixed(1)
                                    font.pixelSize: 9
                                    color:   theme.textMuted
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: modelData.bauteilName !== ""
                                    text:    modelData.bauteilName
                                    font.pixelSize: 8
                                    color:   theme.textSubtle
                                    width:   parent.parent.width - 8
                                    elide:   Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                id:           klemmeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    panel.aktivKlemmeIdx = (panel.aktivKlemmeIdx === index ? -1 : index)
                            }
                        }
                    }

                    // Leere-Ansicht falls keine Klemmen
                    Item {
                        visible: klemmenreiheModel.klemmen.length === 0
                        width:   300; height: 80
                        Text {
                            anchors.centerIn: parent
                            text:    qsTr("Noch keine Klemmen\n+ Klemme hinzufügen")
                            font.pixelSize: 12; color: theme.textMuted
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Stegbrücken-Balken
                Item {
                    id:      stegBars
                    x:       klemmenRow.x
                    y:       klemmenRow.y + klemmenRow.height + 8
                    width:   klemmenRow.implicitWidth
                    height:  klemmenreiheModel.stegbruecken.length * 22 + 4
                    visible: klemmenreiheModel.stegbruecken.length > 0

                    Repeater {
                        model: klemmenreiheModel.stegbruecken

                        delegate: Item {
                            x:      panel.klemmeX(modelData.vonIdx)
                            y:      index * 22
                            width:  panel.klemmeBarWidth(modelData.vonIdx, modelData.bisIdx)
                            height: 18

                            Rectangle {
                                anchors.fill: parent
                                color:   modelData.hatKonflikt ? "#7a2020" : panel.stegFarbe(index)
                                radius:  3
                                opacity: 0.85
                            }
                            Text {
                                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                                text: "Eb." + modelData.ebene + "  "
                                      + modelData.vonNummer + "–" + modelData.bisNummer
                                      + (modelData.potenzialText ? "  " + modelData.potenzialText : "")
                                      + (modelData.hatKonflikt ? "  ⚠" : "")
                                font.pixelSize: 9; color: "white"
                                elide: Text.ElideRight; width: parent.width - 8
                            }
                        }
                    }
                }
            }
        }

        Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

        // Toolbar
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color:  theme.surfaceDeep

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                Button {
                    text: qsTr("+ Klemme")
                    implicitHeight: 28
                    contentItem: Text {
                        text: parent.text; font.pixelSize: 12; color: theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent
                    }
                    onClicked: {
                        klemmenreiheModel.klemmeAnlegen(-1)
                        panel.aktivKlemmeIdx = klemmenreiheModel.klemmen.length - 1
                    }
                }

                // Pfeil hoch/runter (nur wenn Klemme ausgewählt)
                Button {
                    visible: panel.aktivKlemmeIdx > 0
                    text: "▲"
                    implicitWidth: 32; implicitHeight: 28
                    contentItem: Text {
                        text: parent.text; font.pixelSize: 12; color: theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 4
                    }
                    onClicked: {
                        var k = klemmenreiheModel.klemmen[panel.aktivKlemmeIdx]
                        if (k && klemmenreiheModel.klemmeSchieben(k.klemmeId, -1))
                            panel.aktivKlemmeIdx -= 1
                    }
                }
                Button {
                    visible: panel.aktivKlemmeIdx >= 0 && panel.aktivKlemmeIdx < klemmenreiheModel.klemmen.length - 1
                    text: "▼"
                    implicitWidth: 32; implicitHeight: 28
                    contentItem: Text {
                        text: parent.text; font.pixelSize: 12; color: theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 4
                    }
                    onClicked: {
                        var k = klemmenreiheModel.klemmen[panel.aktivKlemmeIdx]
                        if (k && klemmenreiheModel.klemmeSchieben(k.klemmeId, 1))
                            panel.aktivKlemmeIdx += 1
                    }
                }

                // Löschen-Button (nur wenn Klemme ausgewählt)
                Button {
                    visible: panel.aktivKlemmeIdx >= 0
                    text: qsTr("Löschen")
                    implicitHeight: 28
                    contentItem: Text {
                        text: parent.text; font.pixelSize: 12; color: "#e05050"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#3a1010" : "transparent"; border.color: "#7a3030"; border.width: 1; radius: 4
                    }
                    onClicked: {
                        var k = klemmenreiheModel.klemmen[panel.aktivKlemmeIdx]
                        if (k) {
                            klemmenreiheModel.klemmeLoeschen(k.klemmeId)
                            panel.aktivKlemmeIdx = -1
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: klemmenreiheModel.hatLeiste
                    text: {
                        var aus = klemmenreiheModel.leiste["ausrichtung"] || "senkrecht"
                        return aus === "senkrecht" ? qsTr("Senkrecht") : qsTr("Liegend")
                    }
                    font.pixelSize: 11; color: theme.textMuted
                }
            }
        }
    }
}
