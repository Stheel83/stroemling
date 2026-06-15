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
    readonly property int    pfadAnzahl:        canvas ? Object.keys(canvas.fehlersuchPfadIds).length : 0
    readonly property var    querverweise:       canvas ? canvas.fehlersuchQuerverweise : []
    readonly property var    unterbrechungen:    canvas ? canvas.fehlersuchUnterbrechungen : {}
    readonly property var    unterbrechungsIds:  canvas ? Object.keys(canvas.fehlersuchUnterbrechungen) : []

    signal querverweisNavigieren(int seiteId, real x, real y, int partnerId)
    signal geschlossen()

    property bool autoWeiterverfolgen: false

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

                // Toggle: Auto-Weiterverfolgen auf Zielseite
                Rectangle {
                    implicitWidth: autoToggleRow.implicitWidth + 12
                    implicitHeight: 24
                    radius: 4
                    color: root.autoWeiterverfolgen ? theme.accent : "transparent"
                    border.color: root.autoWeiterverfolgen ? theme.accent : theme.border
                    ToolTip.visible: autoToggleMaus.containsMouse
                    ToolTip.text: qsTr("Auto-Weiterverfolgen: BFS nach Querverweis-Sprung automatisch starten")
                    ToolTip.delay: 600

                    RowLayout {
                        id: autoToggleRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "⇒"
                            font.pixelSize: 11
                            color: root.autoWeiterverfolgen ? "white" : theme.textMuted
                        }
                        Text {
                            text: qsTr("Auto")
                            font.pixelSize: 10
                            color: root.autoWeiterverfolgen ? "white" : theme.textMuted
                        }
                    }

                    MouseArea {
                        id: autoToggleMaus
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.autoWeiterverfolgen = !root.autoWeiterverfolgen
                    }
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
                                visible: qvMaus.containsMouse && (modelData.nachSeiteId || -1) >= 0
                            }
                        }

                        MouseArea {
                            id: qvMaus
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (modelData.nachSeiteId || -1) >= 0
                                         ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                var nachId = modelData.nachSeiteId || -1
                                if (nachId >= 0)
                                    root.querverweisNavigieren(
                                        nachId,
                                        modelData.zielX || 0,
                                        modelData.zielY || 0,
                                        root.autoWeiterverfolgen ? (modelData.partnerId || -1) : -1)
                            }
                        }
                    }
                }

                // Hinweis wenn Querverweis-Zielseite nicht aufgelöst werden konnte
                Repeater {
                    model: root.querverweise.filter(function(q) {
                        return (q.nachSeiteId || -1) < 0
                    })
                    Item {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        implicitHeight: qvWarnText.implicitHeight + 4

                        Text {
                            id: qvWarnText
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: qsTr("Zielseite für \"%1\" nicht gefunden – Netz neu synchronisieren?")
                                  .arg(modelData.bezeichnung || "?")
                            font.pixelSize: 10
                            color: theme.borderLight
                        }
                    }
                }

                // ── Unterbrechungen (Trenner) ─────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.leftMargin: 14
                    implicitHeight: ubrHeaderText.implicitHeight
                    visible: root.pfadAnzahl > 0 && root.unterbrechungsIds.length > 0

                    Text {
                        id: ubrHeaderText
                        text: qsTr("Pfad unterbrochen bei:")
                        font.pixelSize: 11; font.weight: Font.Medium
                        color: "#e04040"
                    }
                }

                Repeater {
                    model: root.unterbrechungsIds

                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                            spacing: 8

                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: "transparent"
                                border.color: "#e04040"
                                border.width: 2
                            }

                            Text {
                                text: root.unterbrechungen[modelData] || qsTr("(Trenner)")
                                font.pixelSize: 12
                                color: "#e04040"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
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
