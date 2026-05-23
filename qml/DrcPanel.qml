import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// DRC-Ergebnis-Panel – erscheint am unteren Rand des Canvas-Bereichs.
// Auslösung: manuell per Prüfen-Button. Ergebnisse bleiben bis zum nächsten
// Prüflauf oder bis das Panel geschlossen wird.
Item {
    id: root

    required property var    theme
    required property int    projektId

    signal schliessen()

    readonly property int  fehlerAnzahl: ergebnisModel.count
    readonly property bool hatFehler:    ergebnisModel.count > 0

    height: 200
    clip: true

    ListModel { id: ergebnisModel }

    function pruefen() {
        ergebnisModel.clear()

        var d01 = db.drcDoppelteBmk(root.projektId)
        for (var i = 0; i < d01.length; i++) {
            var f = d01[i]
            ergebnisModel.append({
                "typ":       "doppelter_bmk",
                "meldung":   qsTr("Doppelter BMK: %1  (%2×)").arg(f.bmk).arg(f.anzahl),
                "detail":    qsTr("IDs: %1").arg(f.ids.join(", ")),
                "seiteId":   -1,
                "elementId": -1
            })
        }

        var d02 = db.drcSymboleOhneBmk(root.projektId)
        for (var j = 0; j < d02.length; j++) {
            var g = d02[j]
            ergebnisModel.append({
                "typ":       "symbol_ohne_bmk",
                "meldung":   qsTr("Symbol ohne BMK: %1").arg(g.symbolId),
                "detail":    qsTr("Seite: %1").arg(g.seiteName),
                "seiteId":   g.seiteId,
                "elementId": g.elementId
            })
        }
    }

    // Hintergrund
    Rectangle {
        anchors.fill: parent
        color: root.theme.surface
        border.color: root.theme.border
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 34
            color: root.theme.surfaceHover || root.theme.border

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 8

                Text {
                    text:           "⚠"
                    font.pixelSize: 14
                    color:          ergebnisModel.count > 0
                                    ? "#E06000"
                                    : root.theme.textMuted
                }
                Text {
                    text:           qsTr("DRC — Designprüfung")
                    font.pixelSize: 12
                    font.weight:    Font.Medium
                    color:          root.theme.textPrimary
                }
                Text {
                    visible:        ergebnisModel.count > 0
                    text:           qsTr("%1 Befund(e)").arg(ergebnisModel.count)
                    font.pixelSize: 11
                    color:          "#E06000"
                }
                Item { Layout.fillWidth: true }

                // Prüfen-Button
                Rectangle {
                    width: pruefenText.implicitWidth + 20
                    height: 22
                    radius: 4
                    color: pruefenMa.pressed   ? root.theme.accent
                         : pruefenMa.containsMouse ? root.theme.surfaceHover || Qt.lighter(root.theme.border)
                         : root.theme.border

                    Text {
                        id: pruefenText
                        anchors.centerIn: parent
                        text: qsTr("Prüfen")
                        font.pixelSize: 11
                        color: root.theme.textPrimary
                    }
                    MouseArea {
                        id: pruefenMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.pruefen()
                    }
                }

                // Schließen-Button
                Rectangle {
                    width: 22; height: 22
                    radius: 4
                    color: schliesseMa.pressed   ? root.theme.accent
                         : schliesseMa.containsMouse ? root.theme.surfaceHover || Qt.lighter(root.theme.border)
                         : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 11
                        color: root.theme.textMuted
                    }
                    MouseArea {
                        id: schliesseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.schliessen()
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // ── Ergebnisliste ────────────────────────────────────────
        ListView {
            id: liste
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true
            model: ergebnisModel

            ScrollBar.vertical: ScrollBar {}

            // Leer-Zustand
            Item {
                anchors.centerIn: parent
                visible: ergebnisModel.count === 0
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "✓"
                        font.pixelSize: 20
                        color: root.theme.textMuted
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Keine Befunde — Prüfen starten")
                        font.pixelSize: 11
                        color: root.theme.textMuted
                    }
                }
            }

            delegate: Rectangle {
                width: liste.width
                height: 38
                color: index % 2 === 0 ? "transparent" : (root.theme.surfaceHover || Qt.lighter(root.theme.surface))

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "⚠"
                        font.pixelSize: 12
                        color: "#E06000"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: model.meldung
                        font.pixelSize: 11
                        color: root.theme.textPrimary
                    }
                    Text {
                        text: model.detail
                        font.pixelSize: 10
                        font.family: "monospace"
                        color: root.theme.textMuted
                    }
                }
            }
        }
    }
}
