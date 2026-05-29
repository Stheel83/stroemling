import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sektion "Mitwirkende": Dankliste nach Kategorien.
ColumnLayout {
    id: root

    required property var theme

    Layout.fillWidth: true
    spacing: 0

    Item { implicitHeight: 28 }
    Text {
        Layout.leftMargin:   20
        text:                qsTr("Mitwirkende")
        font.pixelSize:      11
        font.weight:         Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing:  1
        color:               root.theme.textMuted
    }
    Item { implicitHeight: 8 }

    Rectangle {
        id:                 mitwCard
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        implicitHeight:     mitwCol.implicitHeight + 24
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        // ── Namen hier eintragen ──────────────────────
        property var _fehlersuche: []
        property var _tests:       ["Big B. hat fleißig das Programm missbraucht", "P.S. war sehr gründlich"]
        property var _design:      ["S.Z. hat des Strömling Design grundlegend definiert", "H.C. hat den **Schluss Jetzt** Button entwickelt", "S.Z., M.M., J.T., M.T., A.R., K.K., Big B., K.M., A.K., P.S. haben mich grundlegend bei der rotierenden Logo Auswahl beeinflusst"]
        property var _sonstiges:   []
        // Beispiel: property var _fehlersuche: ["Max Muster", "Anna Beispiel"]

        ColumnLayout {
            id: mitwCol
            anchors {
                left:  parent.left;  leftMargin:  16
                right: parent.right; rightMargin: 16
                top:   parent.top;   topMargin:   16
            }
            spacing: 0

            Text {
                Layout.fillWidth:    true
                Layout.bottomMargin: 16
                text:     qsTr("Herzlichen Dank an alle, die durch Fehlermeldungen, Tests, Designfeedback und andere Beiträge zu diesem Projekt beitragen.")
                font.pixelSize: 11
                color:    root.theme.textMuted
                wrapMode: Text.WordWrap
            }

            // ── Fehlersuche ───────────────────────────
            Text {
                Layout.bottomMargin: 6
                text:                qsTr("Fehlersuche")
                font.pixelSize:      9; font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing:  1.2; color: root.theme.textMuted
            }
            Repeater {
                id:    fehlerRep
                model: mitwCard._fehlersuche
                delegate: Text {
                    Layout.fillWidth: true; Layout.bottomMargin: 4
                    text: modelData; font.pixelSize: 12; color: root.theme.textPrimary
                }
            }
            Text {
                Layout.bottomMargin: 4
                visible:        fehlerRep.count === 0
                text:           qsTr("(noch keine Einträge)")
                font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
            }

            // ── Tests ────────────────────────────────
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 10; height: 1; color: root.theme.divider }
            Text {
                Layout.bottomMargin: 6
                text:                qsTr("Tests")
                font.pixelSize:      9; font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing:  1.2; color: root.theme.textMuted
            }
            Repeater {
                id:    testsRep
                model: mitwCard._tests
                delegate: Text {
                    Layout.fillWidth: true; Layout.bottomMargin: 4
                    text: modelData; font.pixelSize: 12; color: root.theme.textPrimary
                }
            }
            Text {
                Layout.bottomMargin: 4
                visible:        testsRep.count === 0
                text:           qsTr("(noch keine Einträge)")
                font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
            }

            // ── Design ───────────────────────────────
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 10; height: 1; color: root.theme.divider }
            Text {
                Layout.bottomMargin: 6
                text:                qsTr("Design")
                font.pixelSize:      9; font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing:  1.2; color: root.theme.textMuted
            }
            Repeater {
                id:    designRep
                model: mitwCard._design
                delegate: Text {
                    Layout.fillWidth: true; Layout.bottomMargin: 4
                    text: modelData; font.pixelSize: 12; color: root.theme.textPrimary
                }
            }
            Text {
                Layout.bottomMargin: 4
                visible:        designRep.count === 0
                text:           qsTr("(noch keine Einträge)")
                font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
            }

            // ── Sonstiges ────────────────────────────
            Rectangle { Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 10; height: 1; color: root.theme.divider }
            Text {
                Layout.bottomMargin: 6
                text:                qsTr("Sonstiges")
                font.pixelSize:      9; font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing:  1.2; color: root.theme.textMuted
            }
            Repeater {
                id:    sonstigesRep
                model: mitwCard._sonstiges
                delegate: Text {
                    Layout.fillWidth: true; Layout.bottomMargin: 4
                    text: modelData; font.pixelSize: 12; color: root.theme.textPrimary
                }
            }
            Text {
                Layout.bottomMargin: 4
                visible:        sonstigesRep.count === 0
                text:           qsTr("(noch keine Einträge)")
                font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
            }

            Item { implicitHeight: 8 }
        }
    }
}
