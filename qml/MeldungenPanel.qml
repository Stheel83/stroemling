import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Zeigt die zuletzt angezeigten Toast-Meldungen dieser Session – neueste zuerst.
// Reine RAM-Historie (kein DB-Persist), siehe MeldungManager.

Item {
    id: root

    required property var theme
    property bool debug: false

    onVisibleChanged: if (visible) liste.model = meldungManager.historie()

    Connections {
        target: meldungManager
        function onMeldungAnzuzeigen() {
            if (root.visible) liste.model = meldungManager.historie()
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
                    text:           qsTr("Meldungen")
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
                        text:              "🔔"
                        font.pixelSize:    40
                        Layout.alignment:  Qt.AlignHCenter
                    }
                    Text {
                        text:              qsTr("Noch keine Meldungen in dieser Session.")
                        font.pixelSize:    14
                        color:             root.theme.textMuted
                        Layout.alignment:  Qt.AlignHCenter
                    }
                }
            }

            // Meldungs-Liste
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
                                    text:           modelData.erfolg ? "✓" : "✗"
                                    font.pixelSize: 16
                                    color:          modelData.erfolg ? root.theme.accent : "#c0392b"
                                }
                                Text {
                                    text:           modelData.text || ""
                                    font.pixelSize: 13
                                    color:          root.theme.textPrimary
                                    Layout.fillWidth: true
                                    wrapMode:       Text.WordWrap
                                }
                            }
                            Text {
                                text:           modelData.datum || ""
                                font.pixelSize: 10
                                color:          root.theme.textMuted
                                opacity:        0.6
                                leftPadding:    26
                            }
                        }
                    }

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
