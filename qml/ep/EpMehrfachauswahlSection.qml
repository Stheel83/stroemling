import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    // panel.auswahlLaenge ist readonly property int → ändert sich bei JEDER
    // Auswahländerung, auch wenn ausgewaehlt konstant -1 bleibt (z.B. Keine→Mehrfach).
    // canvas.auswahl (property var) ist in AOT nicht direkt trackbar.
    // panel.symbolAuswahlAnzahl ist bereits ein getypter int in EigenschaftenPanel
    // und funktioniert zuverlässig (wird auch für den BMK-Button verwendet).
    // canvas ist in AOT-Bindings als required property var nicht auflösbar.
    readonly property bool _hatSymbole: panel.symbolAuswahlAnzahl >= 1

    width:   parent ? parent.width : 0
    height:  panel.auswahlLaenge >= 2 ? multiCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    Column {
        id: multiCol
        width: parent.width; spacing: 0

        Trennlinie {}

        // ── Rotation (nur wenn mind. ein Symbol ausgewählt) ──────────────
        Item {
            width: parent.width
            height: root._hatSymbole ? rotCol.implicitHeight : 0
            visible: root._hatSymbole
            clip: true

            Column {
                id: rotCol
                width: parent.width; spacing: 0

                AbschnittTitel { text: qsTr("ROTATION") }

                FeldLabel { text: qsTr("Alle Symbole auf:") }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    Repeater {
                        model: [
                            { anzeige: "0°",   wert: 0   },
                            { anzeige: "90°",  wert: 90  },
                            { anzeige: "180°", wert: 180 },
                            { anzeige: "270°", wert: 270 }
                        ]
                        MiniButton { theme: root.theme;
                            label:   modelData.anzeige
                            breite:  40
                            onKlick: panel.canvas.eigenschaftAktualisieren("rotation", modelData.wert)
                        }
                    }
                }

                Item { height: 4 }
                FeldLabel { text: qsTr("Um Pivot drehen:") }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    MiniButton { theme: root.theme; label: qsTr("↺ 90°");  breite: 56; tooltip: qsTr("90° gegen Uhrzeigersinn um linken Pin"); onKlick: panel.canvas.multiRotationUmPivot(270) }
                    MiniButton { theme: root.theme; label: qsTr("180°");   breite: 40; tooltip: qsTr("180° um linken Pin");                    onKlick: panel.canvas.multiRotationUmPivot(180) }
                    MiniButton { theme: root.theme; label: qsTr("90° ↻");  breite: 56; tooltip: qsTr("90° im Uhrzeigersinn um linken Pin");    onKlick: panel.canvas.multiRotationUmPivot(90)  }
                }
                Item { height: 6 }
            }
        }

        // ── Aktionen (alle Elementtypen) ─────────────────────────────────
        AbschnittTitel { text: qsTr("AKTIONEN") }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            MiniButton { theme: root.theme; label: qsTr("Duplizieren");  breite: 176
                tooltip: qsTr("Auswahl duplizieren – Kopie an Mauszeiger platzieren (Strg+D)")
                onKlick: panel.canvas.duplizieren() }
        }

        Item { height: 4 }

        Item {
            width: parent.width
            height: panel.symbolAuswahlAnzahl >= 2 ? bmkRow.implicitHeight + 4 : 0
            visible: height > 0; clip: true
            Row {
                id: bmkRow
                anchors.horizontalCenter: parent.horizontalCenter
                MiniButton { theme: root.theme; label: qsTr("BMK nummerieren...");  breite: 176
                    tooltip: qsTr("Automatische BMK-Vergabe fuer selektierte Symbole")
                    onKlick: panel.canvas.batchBmkDialogOeffnen() }
            }
        }

        Item { height: 4 }

        // ── Ausrichten & Verteilen (alle Elementtypen) ───────────────────
        AbschnittTitel { text: qsTr("AUSRICHTEN") }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            MiniButton { theme: root.theme; label: qsTr("Am Raster ausrichten"); breite: 176
                tooltip: qsTr("Alle selektierten Elemente auf das aktuelle Raster snappen")
                onKlick: panel.canvas.elementeAufRasterSnappen() }
        }

        Item { height: 4 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: root.theme; label: qsTr("← L"); breite: 44
                tooltip: qsTr("Linksbündig ausrichten")
                onKlick: panel.canvas.elementeAusrichten("links") }
            MiniButton { theme: root.theme; label: qsTr("R →"); breite: 44
                tooltip: qsTr("Rechtsbündig ausrichten")
                onKlick: panel.canvas.elementeAusrichten("rechts") }
            MiniButton { theme: root.theme; label: qsTr("↑ O"); breite: 44
                tooltip: qsTr("Oben ausrichten")
                onKlick: panel.canvas.elementeAusrichten("oben") }
            MiniButton { theme: root.theme; label: qsTr("U ↓"); breite: 44
                tooltip: qsTr("Unten ausrichten")
                onKlick: panel.canvas.elementeAusrichten("unten") }
        }

        Item { height: 4 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: root.theme; label: qsTr("⊙ H"); breite: 44
                tooltip: qsTr("Horizontal zentrieren")
                onKlick: panel.canvas.elementeAusrichten("mitte_h") }
            MiniButton { theme: root.theme; label: qsTr("⊙ V"); breite: 44
                tooltip: qsTr("Vertikal zentrieren")
                onKlick: panel.canvas.elementeAusrichten("mitte_v") }
            MiniButton { theme: root.theme; label: qsTr("↔ V."); breite: 44
                tooltip: qsTr("Horizontal verteilen (mind. 3 Elemente)")
                opacity: panel.auswahlLaenge >= 3 ? 1.0 : 0.4
                onKlick: panel.canvas.elementeAusrichten("verteilen_h") }
            MiniButton { theme: root.theme; label: qsTr("↕ V."); breite: 44
                tooltip: qsTr("Vertikal verteilen (mind. 3 Elemente)")
                opacity: panel.auswahlLaenge >= 3 ? 1.0 : 0.4
                onKlick: panel.canvas.elementeAusrichten("verteilen_v") }
        }

        Item { height: 8 }
    }
}
