import QtQuick
import QtQuick.Controls
import "../components"

// Ausrichten/Verteilen-Werkzeuge für die Mehrfachauswahl im Normblatt-
// Editor. Ersetzt NormblattFeldProperties im rechten Panel, sobald
// mehrfachAuswahl.length >= 2 ist (siehe NormblattEditorDialog.qml).
Item {
    id: root
    required property var theme
    property int anzahl: 0

    signal ausrichtenAngefordert(string modus)

    component AbsTitel: Text {
        height: 22; verticalAlignment: Text.AlignBottom
        color: root.theme.borderLight
        font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
    }

    Column {
        id: col
        width: parent.width; padding: 8; spacing: 8

        Text {
            text: qsTr("%1 Felder ausgewählt").arg(root.anzahl)
            color: root.theme.textPrimary; font.pixelSize: 12; font.weight: Font.Medium
        }

        AbsTitel { text: qsTr("AUSRICHTEN") }

        Row {
            spacing: 4
            MiniButton { theme: root.theme; label: qsTr("Links");  breite: (col.width - col.padding * 2 - 8) / 3
                tooltip: qsTr("Linke Kanten aneinander ausrichten")
                onKlick: root.ausrichtenAngefordert("links") }
            MiniButton { theme: root.theme; label: qsTr("Mitte");  breite: (col.width - col.padding * 2 - 8) / 3
                tooltip: qsTr("Horizontal zentrieren")
                onKlick: root.ausrichtenAngefordert("hZentrieren") }
            MiniButton { theme: root.theme; label: qsTr("Rechts"); breite: (col.width - col.padding * 2 - 8) / 3
                tooltip: qsTr("Rechte Kanten aneinander ausrichten")
                onKlick: root.ausrichtenAngefordert("rechts") }
        }
        Row {
            spacing: 4
            MiniButton { theme: root.theme; label: qsTr("Oben");   breite: (col.width - col.padding * 2 - 8) / 3
                tooltip: qsTr("Obere Kanten aneinander ausrichten")
                onKlick: root.ausrichtenAngefordert("oben") }
            MiniButton { theme: root.theme; label: qsTr("Mitte");  breite: (col.width - col.padding * 2 - 8) / 3
                tooltip: qsTr("Vertikal zentrieren")
                onKlick: root.ausrichtenAngefordert("vZentrieren") }
            MiniButton { theme: root.theme; label: qsTr("Unten");  breite: (col.width - col.padding * 2 - 8) / 3
                tooltip: qsTr("Untere Kanten aneinander ausrichten")
                onKlick: root.ausrichtenAngefordert("unten") }
        }

        AbsTitel { text: qsTr("VERTEILEN"); visible: root.anzahl >= 3 }

        Column {
            visible: root.anzahl >= 3
            width: parent.width; spacing: 4
            MiniButton { theme: root.theme; label: qsTr("Horizontal verteilen")
                breite: col.width - col.padding * 2
                tooltip: qsTr("Gleicher Abstand zwischen den Feldern (waagrecht)")
                onKlick: root.ausrichtenAngefordert("hVerteilen") }
            MiniButton { theme: root.theme; label: qsTr("Vertikal verteilen")
                breite: col.width - col.padding * 2
                tooltip: qsTr("Gleicher Abstand zwischen den Feldern (senkrecht)")
                onKlick: root.ausrichtenAngefordert("vVerteilen") }
        }

        Text {
            visible: root.anzahl < 3
            text: qsTr("Verteilen braucht mindestens\n3 ausgewählte Felder")
            color: root.theme.textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap
            width: parent.width - 16
        }

        Item { height: 4 }

        Rectangle { width: col.width - col.padding * 2; height: 1; color: root.theme.divider }

        Text {
            text: qsTr("Strg+Klick auf ein Feld fügt es zur\nAuswahl hinzu oder entfernt es")
            color: root.theme.textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap
            width: parent.width - 16
        }
    }
}
