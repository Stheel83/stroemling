import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var theme

    property int projektId: -1
    property int seiteId:   -1

    // Referenz auf den rechts platzierten SchaltplanCanvas
    property var canvas: null

    // Gültig sobald canvas eine Verbindung hat
    readonly property int    pfadAnzahl:     canvas ? Object.keys(canvas.fehlersuchPfadIds).length : 0
    readonly property var    querverweise:   canvas ? canvas.fehlersuchQuerverweise : []

    signal querverweisNavigieren(int seiteId, real x, real y)
    signal geschlossen()

    // ── Escape: Pfad aufheben ─────────────────────────────────
    Keys.onEscapePressed: { if (canvas) canvas.fehlersuchPfadZuruecksetzen() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: theme.surfaceDeep

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                spacing: 6

                Text {
                    text: qsTr("Fehlersuchmodus")
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: theme.textPrimary
                    Layout.fillWidth: true
                }

                Button {
                    flat: true; implicitWidth: 28; implicitHeight: 28
                    contentItem: Text { text: "✕"; color: theme.textMuted; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                    ToolTip.visible: hovered; ToolTip.text: qsTr("Fehlersuchmodus schliessen (Esc)")
                    ToolTip.delay: 600
                    onClicked: root.geschlossen()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Pfad-Status ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: theme.surface

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                spacing: 8

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: root.pfadAnzahl > 0 ? theme.accent : theme.borderLight
                }

                Text {
                    text: root.pfadAnzahl > 0
                        ? qsTr("%1 Elemente im Pfad").arg(root.pfadAnzahl)
                        : qsTr("Kein Pfad aktiv")
                    font.pixelSize: 12
                    color: root.pfadAnzahl > 0 ? theme.textPrimary : theme.textMuted
                    Layout.fillWidth: true
                }

                Button {
                    visible: root.pfadAnzahl > 0
                    flat: true; implicitWidth: 24; implicitHeight: 24
                    contentItem: Text { text: "×"; color: theme.textMuted; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                    ToolTip.visible: hovered; ToolTip.text: qsTr("Hervorhebung aufheben (Esc)")
                    ToolTip.delay: 600
                    onClicked: if (root.canvas) root.canvas.fehlersuchPfadZuruecksetzen()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        // ── Querverweis-Liste ─────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: qvCol.implicitHeight
            clip: true

            ColumnLayout {
                id: qvCol
                width: parent.width
                spacing: 0

                // Anleitung wenn kein Pfad
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 32
                    implicitHeight: anleitungCol.implicitHeight
                    visible: root.pfadAnzahl === 0

                    Column {
                        id: anleitungCol
                        anchors { left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 20 }
                        spacing: 10

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: qsTr("Element oder Leitung anklicken, um den Strompfad von diesem Punkt bis zur nächsten Unterbrechung zu markieren.")
                            font.pixelSize: 12
                            color: theme.textMuted
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: qsTr("Leere Stelle klicken → Markierung aufheben.")
                            font.pixelSize: 11
                            color: theme.borderLight
                        }
                    }
                }

                // Querverweise wenn Pfad aktiv und Querverweis vorhanden
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.leftMargin: 14
                    implicitHeight: qvHeaderText.implicitHeight
                    visible: root.pfadAnzahl > 0 && root.querverweise.length > 0

                    Text {
                        id: qvHeaderText
                        text: qsTr("Pfad führt weiter auf:")
                        font.pixelSize: 11; font.weight: Font.Medium
                        color: theme.textMuted
                    }
                }

                Repeater {
                    model: root.querverweise

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: qvMaus.containsMouse ? theme.hover : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 6

                            Text {
                                text: "⚡"
                                font.pixelSize: 14
                                color: theme.accent
                            }
                            Text {
                                text: modelData.bezeichnung || qsTr("(Querverweis)")
                                font.pixelSize: 12
                                color: theme.textPrimary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: qsTr("Springen →")
                                font.pixelSize: 11
                                color: theme.accent
                                visible: qvMaus.containsMouse
                            }
                        }

                        MouseArea {
                            id: qvMaus
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.querverweisNavigieren(
                                           root.seiteId, modelData.x, modelData.y)
                        }
                    }
                }

                // Hinweis Querverweis ohne bekannte Seite
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    implicitHeight: qvHinweisText.implicitHeight
                    visible: root.pfadAnzahl > 0 && root.querverweise.length > 0

                    Text {
                        id: qvHinweisText
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: qsTr("Seitenwechsel noch nicht implementiert – Querverweis in einer späteren Version.")
                        font.pixelSize: 10
                        color: theme.borderLight
                    }
                }
            }
        }

        // ── Statusleiste ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 28
            color: theme.surfaceDeep

            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("Klick auf Element → Pfad markieren  ·  Esc → löschen")
                font.pixelSize: 10
                color: theme.borderLight
            }
        }
    }
}
