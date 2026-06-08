import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Zeigt nur bereits freigeschaltete Achievements – neueste zuerst.
// Kein Hinweis auf Gesamtanzahl oder gesperrte Achievements.

Item {
    id: root

    required property var theme
    property bool debug: false

    onVisibleChanged: if (visible) liste.model = achievementManager.erreichte()

    // Refresh wenn ein neues Achievement freigeschaltet wird
    Connections {
        target: achievementManager
        function onAchievementFreigeschaltet() {
            if (root.visible) liste.model = achievementManager.erreichte()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.theme.surface

        ColumnLayout {
            anchors { fill: parent; margins: 0 }
            spacing: 0

            // Header
            Rectangle {
                Layout.fillWidth: true
                height: 48
                color: root.theme.surfaceDeep

                Text {
                    anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                    text:           "Errungenschaften"
                    font.pixelSize: 15
                    font.weight:    Font.Medium
                    color:          root.theme.textPrimary
                }
            }

            Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

            // Leer-Zustand
            Item {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                visible: liste.count === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text:              "🏆"
                        font.pixelSize:    40
                        Layout.alignment:  Qt.AlignHCenter
                    }
                    Text {
                        text:              "Noch nichts erreicht."
                        font.pixelSize:    14
                        color:             root.theme.textMuted
                        Layout.alignment:  Qt.AlignHCenter
                    }
                    Text {
                        text:              "Schau dich um."
                        font.pixelSize:    12
                        color:             root.theme.textMuted
                        opacity:           0.7
                        Layout.alignment:  Qt.AlignHCenter
                    }
                }
            }

            // Achievement-Liste
            ListView {
                id:               liste
                Layout.fillWidth:  true
                Layout.fillHeight: true
                visible:           count > 0
                clip:              true
                model:             []
                spacing:           0

                delegate: Item {
                    width:  liste.width
                    height: card.height + 1

                    Rectangle {
                        id:     card
                        width:  parent.width
                        height: cardLayout.implicitHeight + 20
                        color:  "transparent"

                        ColumnLayout {
                            id:       cardLayout
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                            spacing:  4

                            RowLayout {
                                spacing: 10
                                Text {
                                    text:           "🏆"
                                    font.pixelSize: 20
                                }
                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Text {
                                        text:           modelData.titel || ""
                                        font.pixelSize: 13
                                        font.weight:    Font.Medium
                                        color:          root.theme.accent
                                        Layout.fillWidth: true
                                        elide:          Text.ElideRight
                                    }
                                    Text {
                                        text:           modelData.beschreibung || ""
                                        font.pixelSize: 11
                                        color:          root.theme.textMuted
                                        Layout.fillWidth: true
                                        wrapMode:       Text.WordWrap
                                    }
                                }
                            }
                            Text {
                                text:           modelData.datum || ""
                                font.pixelSize: 10
                                color:          root.theme.textMuted
                                opacity:        0.6
                                leftPadding:    30
                            }
                        }
                    }

                    // Trennlinie
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width:  parent.width
                        height: 1
                        color:  root.theme.divider
                    }
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }
        }
    }
}
