import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling
import "../components"

Item {
    id: root
    required property int projektId
    required property var theme
    property bool debug: false

    signal sprungAngefordert(int seiteId, string blattnr, string seiteBez, real wx, real wy)

    property var _flachListe: []

    property var _gruppiert: {
        var gruppen = {}
        var reihenfolge = []
        for (var i = 0; i < root._flachListe.length; i++) {
            var gk = root._flachListe[i]
            var bmk = gk.bmk || ""
            if (!gruppen[bmk]) {
                gruppen[bmk] = { bmk: bmk, bezeichnung: gk.bezeichnung || "", instanzen: [] }
                reihenfolge.push(bmk)
            }
            gruppen[bmk].instanzen.push(gk)
        }
        return reihenfolge.map(function(b) { return gruppen[b] })
    }

    function laden() {
        root._flachListe = root.projektId >= 0
            ? db.geraetekastenListeMitPos(root.projektId)
            : []
    }

    onVisibleChanged:  { if (visible) laden() }
    onProjektIdChanged: laden()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 40
            color: root.theme.surfaceDeep
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1; color: root.theme.border
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                Text {
                    text: qsTr("Gerätekästen")
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: root.theme.textPrimary; Layout.fillWidth: true
                }
                Text {
                    visible: root._flachListe.length > 0
                    text: root._gruppiert.length + qsTr(" Geräte  ·  ") + root._flachListe.length + qsTr(" Kästen")
                    font.pixelSize: 10; color: root.theme.textMuted
                }
                Rectangle {
                    width: 22; height: 22; radius: 3
                    color: reloadHover.containsMouse ? root.theme.hover : "transparent"
                    HoverHandler { id: reloadHover }
                    Text { anchors.centerIn: parent; text: "⟳"; font.pixelSize: 14; color: root.theme.accent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.laden()
                    }
                }
            }
        }

        // ── Leerzustand ──────────────────────────────────────
        Item {
            visible: root._gruppiert.length === 0
            Layout.fillWidth: true; Layout.fillHeight: true
            Column {
                anchors.centerIn: parent; spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📐"
                    font.pixelSize: 32; opacity: 0.3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Noch keine Gerätekästen im Projekt.")
                    font.pixelSize: 12; color: root.theme.textMuted; font.italic: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Gerätekästen mit der Taste G auf dem Canvas zeichnen.")
                    font.pixelSize: 11; color: root.theme.borderLight
                }
            }
        }

        // ── Geräte-Liste ─────────────────────────────────────
        ScrollView {
            visible: root._gruppiert.length > 0
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true

            Column {
                width: parent.width

                Repeater {
                    model: root._gruppiert
                    delegate: Column {
                        width: parent.width

                        // BMK-Gruppenzeile
                        Rectangle {
                            width: parent.width; height: 38
                            color: root.theme.surface
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 1; color: root.theme.border
                            }
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: 3; color: root.theme.accent
                            }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                                spacing: 8
                                Text { text: "📐"; font.pixelSize: 13 }
                                Text {
                                    text: modelData.bmk
                                    font.pixelSize: 12; font.weight: Font.Medium
                                    color: root.theme.textPrimary
                                }
                                Text {
                                    text: modelData.bezeichnung
                                    font.pixelSize: 11; color: root.theme.textSecondary
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Text {
                                    visible: modelData.instanzen.length > 1
                                    text: modelData.instanzen.length + "×"
                                    font.pixelSize: 10; color: root.theme.textMuted
                                }
                            }
                        }

                        // Instanzen
                        Repeater {
                            model: modelData.instanzen
                            delegate: Rectangle {
                                width: parent.width; height: 30
                                color: instHover.containsMouse ? root.theme.hover : "transparent"
                                property var gkd: modelData

                                MouseArea {
                                    id: instHover; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.ArrowCursor
                                }

                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: 1; color: root.theme.divider
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 28; rightMargin: 10 }
                                    spacing: 6
                                    Text {
                                        text: "↳"; font.pixelSize: 11
                                        color: root.theme.borderLight
                                    }
                                    Text {
                                        text: qsTr("Blatt ") + (gkd.blattnr || "–")
                                        font.pixelSize: 11; color: root.theme.textSecondary
                                        Layout.preferredWidth: 60
                                    }
                                    Text {
                                        text: gkd.seiteBez || ""
                                        font.pixelSize: 11; color: root.theme.textMuted
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        color: sprungHover.containsMouse ? root.theme.accent : "transparent"
                                        border.color: sprungHover.containsMouse ? root.theme.accent : root.theme.border
                                        HoverHandler { id: sprungHover }
                                        Text {
                                            anchors.centerIn: parent; text: "→"
                                            font.pixelSize: 11
                                            color: sprungHover.containsMouse ? "white" : root.theme.accent
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var d = gkd
                                                root.sprungAngefordert(d.seiteId, d.blattnr,
                                                                       d.seiteBez, d.weltX, d.weltY)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Geraetekasten-Ansicht"); visible: root.debug }
}
