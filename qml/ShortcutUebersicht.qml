import QtQuick
import "components"

Item {
    id: root

    required property var theme
    property bool debug: false

    visible: false

    // Dunkel-Overlay
    Rectangle {
        anchors.fill: parent
        color:        "#000000"
        opacity:      0.55
        MouseArea {
            anchors.fill: parent
            onClicked:    root.visible = false
        }
    }

    // Karte
    Rectangle {
        id:               karte
        anchors.centerIn: parent
        width:            Math.min(parent.width  - 40, 720)
        height:           Math.min(parent.height - 40, karteCol.implicitHeight + 32)
        color:            root.theme.surface
        border.color:     root.theme.border
        border.width:     1
        radius:           6

        MouseArea { anchors.fill: parent }   // Klicks nicht ans Overlay durchreichen

        Column {
            id:            karteCol
            width:         parent.width
            topPadding:    20
            bottomPadding: 16
            spacing:       0

            // Kopfzeile
            Row {
                width:          parent.width
                leftPadding:    24
                rightPadding:   16
                bottomPadding:  12
                spacing:        0
                Text {
                    text:            "Tastaturkuerzel"
                    font.pixelSize:  15
                    font.weight:     Font.DemiBold
                    color:           root.theme.textPrimary
                    width:           parent.width - parent.leftPadding - parent.rightPadding - 32
                }
                Rectangle {
                    width: 28; height: 28; radius: 4
                    color: closeArea.containsMouse ? root.theme.hover : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text:             "x"
                        font.pixelSize:   13
                        color:            root.theme.textMuted
                    }
                    MouseArea {
                        id:            closeArea
                        anchors.fill:  parent
                        hoverEnabled:  true
                        onClicked:     root.visible = false
                    }
                }
            }

            // Trennlinie
            Rectangle { width: parent.width; height: 1; color: root.theme.divider }
            Item { width: 1; height: 12 }

            // Zweispaltig
            Row {
                width:       parent.width
                leftPadding: 24
                spacing:     32

                Column {
                    width:   (parent.width - parent.leftPadding - parent.spacing) / 2
                    spacing: 0

                    // ── Werkzeuge ────────────────────────────────
                    ShortcutSectionHeader { text: "Werkzeuge (nur im Schaltplan)" }
                    ShortcutZeile { kuerzel: "V";  aktion: "Zeiger / Auswahl" }
                    ShortcutZeile { kuerzel: "L";  aktion: "Linie zeichnen" }
                    ShortcutZeile { kuerzel: "P";  aktion: "Polygonlinie zeichnen" }
                    ShortcutZeile { kuerzel: "R";  aktion: "Rechteck zeichnen" }
                    ShortcutZeile { kuerzel: "K";  aktion: "Kreis zeichnen" }
                    ShortcutZeile { kuerzel: "T";  aktion: "Text einfuegen" }
                    ShortcutZeile { kuerzel: "N";  aktion: "Notiz einfuegen" }
                    ShortcutZeile { kuerzel: "C";  aktion: "Kabellinie zeichnen" }
                    ShortcutZeile { kuerzel: "G";  aktion: "Geraetekasten platzieren" }
                    ShortcutZeile { kuerzel: "U";  aktion: "Strukturkasten platzieren" }
                    ShortcutZeile { kuerzel: "M";  aktion: "Makrokasten platzieren" }
                    ShortcutZeile { kuerzel: "S";  aktion: "Symbol platzieren (aktives)" }

                    Item { width: 1; height: 8 }

                    // ── Navigation ───────────────────────────────
                    ShortcutSectionHeader { text: "Navigation" }
                    ShortcutZeile { kuerzel: "F";        aktion: "Querverweis Gegenseite anspringen" }
                    ShortcutZeile { kuerzel: "Escape";   aktion: "Werkzeug abbrechen / Auswahl aufheben" }
                }

                Column {
                    width:   (parent.width - parent.leftPadding - parent.spacing) / 2
                    spacing: 0

                    // ── Bearbeiten ───────────────────────────────
                    ShortcutSectionHeader { text: "Bearbeiten" }
                    ShortcutZeile { kuerzel: "Ctrl+Z";         aktion: "Rueckgaengig" }
                    ShortcutZeile { kuerzel: "Ctrl+Y";         aktion: "Wiederholen" }
                    ShortcutZeile { kuerzel: "Ctrl+Shift+Z";   aktion: "Wiederholen (alternativ)" }
                    ShortcutZeile { kuerzel: "Ctrl+A";         aktion: "Alles auswaehlen" }
                    ShortcutZeile { kuerzel: "Del / Backspace"; aktion: "Auswahl loeschen" }
                    ShortcutZeile { kuerzel: "Ctrl+C";         aktion: "Kopieren" }
                    ShortcutZeile { kuerzel: "Ctrl+X";         aktion: "Ausschneiden" }
                    ShortcutZeile { kuerzel: "Ctrl+V";         aktion: "Einfuegen" }
                    ShortcutZeile { kuerzel: "Ctrl+D";         aktion: "Duplizieren" }

                    Item { width: 1; height: 8 }

                    // ── Ablagen 1–4 ──────────────────────────────
                    ShortcutSectionHeader { text: "Ablagen 1-4" }
                    ShortcutZeile { kuerzel: "Ctrl+Shift+1..4"; aktion: "Auswahl in Ablage kopieren" }
                    ShortcutZeile { kuerzel: "Ctrl+1..4";       aktion: "Aus Ablage einfuegen" }

                    Item { width: 1; height: 8 }

                    // ── Ansicht ──────────────────────────────────
                    ShortcutSectionHeader { text: "Ansicht" }
                    ShortcutZeile { kuerzel: "Ctrl+Shift+H"; aktion: "Gesamte Seite einpassen" }
                    ShortcutZeile { kuerzel: "Ctrl+Shift+N"; aktion: "Normblatt einpassen" }
                    ShortcutZeile { kuerzel: "Bild-auf";     aktion: "Vorherige Seite" }
                    ShortcutZeile { kuerzel: "Bild-ab";      aktion: "Naechste Seite" }
                    ShortcutZeile { kuerzel: "Ctrl+J";       aktion: "Seite schnell anspringen" }

                    Item { width: 1; height: 8 }

                    // ── Allgemein ────────────────────────────────
                    ShortcutSectionHeader { text: "Allgemein" }
                    ShortcutZeile { kuerzel: "Ctrl+P";       aktion: "Kommandopalette oeffnen" }
                    ShortcutZeile { kuerzel: "Ctrl+Shift+P"; aktion: "PDF-Export" }
                    ShortcutZeile { kuerzel: "F1";           aktion: "Diese Uebersicht" }
                    ShortcutZeile { kuerzel: "Ctrl+Shift+Alt+D"; aktion: "Debug-Modus umschalten" }
                }
            }

            Item { width: 1; height: 4 }
        }
    }

    // Inline-Hilfskomponenten
    component ShortcutSectionHeader: Item {
        property string text: ""
        width:  parent ? parent.width : 0
        height: 24
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text:            parent.text
            font.pixelSize:  9
            font.weight:     Font.Bold
            font.letterSpacing: 1.2
            color:           root.theme.borderLight
        }
    }

    component ShortcutZeile: Item {
        property string kuerzel: ""
        property string aktion:  ""
        width:  parent ? parent.width : 0
        height: 22
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Rectangle {
                width:  120
                height: 18
                radius: 3
                color:  root.theme.surfaceDeep
                Text {
                    anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                    text:           parent.parent.parent.kuerzel
                    font.pixelSize: 10
                    font.family:    "monospace"
                    color:          root.theme.textPrimary
                }
            }
            Text {
                text:           parent.parent.aktion
                font.pixelSize: 11
                color:          root.theme.textMuted
            }
        }
    }

    DebugLabel { panelName: qsTr("Shortcut-Uebersicht"); visible: root.debug && root.visible }
}
