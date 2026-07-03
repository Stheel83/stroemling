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
        title: qsTr("Belegungsplan als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.steckverbinderBelegungsplanCsvSpeichern(panel.projektId, selectedFile)
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Belegungsplan")
        anzahl: panel._bpKontaktAnzahl
        onCsvKlick: csvDialog.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    Rectangle {
        Layout.fillWidth: true; height: 30; color: root.theme.tableHeader
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            Repeater {
                model: panel.bpCols
                delegate: Text {
                    width: modelData.w; text: modelData.header
                    font.pixelSize: 11; font.weight: Font.Medium; color: root.theme.textSubtle
                }
            }
        }
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true

        Column {
            width: parent.width

            Text {
                visible: panel._bpDaten.length === 0
                width: parent.width; padding: 24
                text: panel.projektId >= 0
                    ? qsTr("Keine Steckverbinder-Gerätekästen im Projekt.\nGerätekasten zeichnen (G), dann im BAUTEILE-Panel ein Steckverbinder-Bauteil verknüpfen.")
                    : qsTr("Kein Projekt ausgewählt")
                font.pixelSize: 12; color: root.theme.textMuted
                font.italic: true; wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: panel._bpDaten

                delegate: Rectangle {
                    id: delegateRect
                    width: parent.width
                    height: modelData.typ === "gehaeuse" ? 26 : 28

                    readonly property bool istGehaeuse: modelData.typ === "gehaeuse"

                    color: istGehaeuse
                        ? Qt.rgba(0, 0.53, 0.67, 0.15)
                        : (index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd)

                    Rectangle {
                        visible: istGehaeuse
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: 4; color: "#006688"
                    }
                    Rectangle {
                        visible: !istGehaeuse
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: 3; color: "#0088aa"
                    }

                    // ── Gehäuse-Kopfzeile ──────────────────────────────────────
                    Row {
                        visible: istGehaeuse
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: gkBmkTxt.implicitWidth + 8; height: 16; radius: 3
                            color: "#0d2030"; border.color: "#0088aa"; border.width: 1
                            Text {
                                id: gkBmkTxt; anchors.centerIn: parent
                                text: (modelData.anlageUO ? ("==" + modelData.anlageUO) : "")
                                      + (modelData.ortUO    ? ("++" + modelData.ortUO)    : "")
                                      + (modelData.anlageKz ? ("=" + modelData.anlageKz)  : "")
                                      + (modelData.ortKz    ? ("+" + modelData.ortKz)      : "")
                                      + (modelData.bmk || "")
                                font.pixelSize: 10; color: "#44bbdd"
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: (modelData.gkBez || "") !== ""
                            text: modelData.gkBez || ""
                            font.pixelSize: 11; color: root.theme.textSecondary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "·"; font.pixelSize: 11; color: root.theme.borderLight
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.bauteilBez || ""
                            font.pixelSize: 11; color: root.theme.textPrimary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.polzahl > 0
                            text: modelData.polzahl + qsTr("-pol")
                            font.pixelSize: 10; color: root.theme.textMuted
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "· " + qsTr("Seite") + " " + (modelData.blattnr || "")
                            font.pixelSize: 10; color: root.theme.accentLight
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20; height: 18
                            Rectangle {
                                anchors.fill: parent; radius: 3
                                color: bpSprungMa.containsMouse ? root.theme.accent : "transparent"
                                border.color: bpSprungMa.containsMouse ? root.theme.accent : root.theme.border
                                Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 10;
                                       color: bpSprungMa.containsMouse ? "#ffffff" : root.theme.accent }
                                MouseArea {
                                    id: bpSprungMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    enabled: panel.canvas !== null && (modelData.seiteId || 0) > 0
                                    onClicked: panel.canvas.bmElementSprungAnfordern(
                                        modelData.seiteId, modelData.blattnr, "", 0, 0)
                                }
                            }
                        }
                    }

                    // ── Kontakt-Zeile ──────────────────────────────────────────
                    Row {
                        visible: !istGehaeuse
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 0

                        Text {
                            width: panel.bpCols[0].w
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.kontaktBez || ""
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: root.theme.textPrimary; elide: Text.ElideRight
                        }
                        Text {
                            width: panel.bpCols[1].w
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (modelData.kontaktTyp === "stecker")          return qsTr("Stecker")
                                if (modelData.kontaktTyp === "buchse")           return qsTr("Buchse")
                                if (modelData.kontaktTyp === "geraeteanschluss") return qsTr("Ger.-Anschl.")
                                return modelData.kontaktTyp || ""
                            }
                            font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight
                        }
                        Text {
                            width: panel.bpCols[2].w
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.kontaktBmk || ""
                            font.pixelSize: 12; color: root.theme.accent; elide: Text.ElideRight
                        }
                        Text {
                            width: panel.bpCols[3].w
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.signalBez || "–"
                            font.pixelSize: 12
                            color: (modelData.signalBez || "") !== "" ? root.theme.textPrimary : root.theme.borderDark
                            elide: Text.ElideRight
                        }
                        // Aderfarbe: Farbmuster + Name
                        Item {
                            width: panel.bpCols[4].w; height: 28
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                Rectangle {
                                    visible: (modelData.signalFarbe || "") !== ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 12; height: 12; radius: 2
                                    color: modelData.signalFarbe || "transparent"
                                    border.color: Qt.rgba(1, 1, 1, 0.2); border.width: 1
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.signalFarbe || "–"
                                    font.pixelSize: 11
                                    color: (modelData.signalFarbe || "") !== "" ? root.theme.textSecondary : root.theme.borderDark
                                    elide: Text.ElideRight
                                    width: panel.bpCols[4].w - 20
                                }
                            }
                        }
                        Text {
                            width: panel.bpCols[5].w
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.querschnitt > 0 ? modelData.querschnitt + " mm²" : "–"
                            font.pixelSize: 12
                            color: modelData.querschnitt > 0 ? root.theme.textSecondary : root.theme.borderDark
                            elide: Text.ElideRight
                        }
                        Text {
                            width: panel.bpCols[6].w
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.blattnr || ""
                            font.pixelSize: 12; color: root.theme.accentLight; elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
