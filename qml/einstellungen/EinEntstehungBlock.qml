import QtQuick
import QtQuick.Layouts

// Sektion "Entstehung & KI-Werkzeuge": Projektinhaber, Entstehungsgeschichte, KI-Tools.
ColumnLayout {
    id: root

    required property var theme

    Layout.fillWidth: true
    spacing: 0

    Item { implicitHeight: 28 }
    Text {
        Layout.leftMargin:   20
        text:                qsTr("Entstehung & KI-Werkzeuge")
        font.pixelSize:      11
        font.weight:         Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing:  1
        color:               root.theme.textMuted
    }
    Item { implicitHeight: 8 }

    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border
        height:             entstehungCol.implicitHeight + 24

        ColumnLayout {
            id:      entstehungCol
            anchors {
                left:    parent.left
                right:   parent.right
                top:     parent.top
                margins: 12
            }
            spacing: 10

            Text {
                text:           "Stephan Theelke"
                font.pixelSize: 14; font.weight: Font.Medium
                color:          root.theme.textPrimary
            }
            Text {
                text:           qsTr("Projektinhaber")
                font.pixelSize: 11; color: root.theme.textMuted
            }
            Text {
                text:           "stroemling@stheelke.de"
                font.pixelSize: 11; color: root.theme.accent
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            Text {
                Layout.fillWidth: true
                text:           qsTr("Die Idee zu Strömling Design entstand am 08.04.2026 aus einem konkreten Bedürfnis: Im Berufsalltag arbeite ich täglich mit EPLAN P8 Electric — einem professionellen E-CAD-Tool, das keine Linux-Version hat und für den Privatgebrauch nicht in Frage kommt. Privat nutze ich ausschließlich Linux (openSUSE mit KDE), und ich wollte ein Tool, das unter Linux läuft und meinen persönlichen Anforderungen entspricht. QElectroTech kannte ich, aber auch das war nicht das, was ich mir vorgestellt hatte. Also habe ich angefangen, mir selbst eins zu bauen — mit KI-Unterstützung, obwohl ich kein Programmierer bin. Für mich war von Anfang an klar: die Datenbank sollte SQLite sein (damit habe ich Erfahrung), und die Oberfläche sollte Qt sein — denn ich als Linuxer nutze openSUSE mit KDE schon seit Jahren.")
                font.pixelSize: 12; color: root.theme.textPrimary; wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text:           qsTr("Kurz zu mir: Ich komme von Usedom, wurde in Pommern ausgebildet und lebe heute in Hamburg — mit einem Bein im Osten, einem im Westen.")
                font.pixelSize: 12; color: root.theme.textPrimary; wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text:           qsTr("Den Begriff \"Strömlinge\" kenne ich noch aus meiner Lehrzeit um die Jahrtausendwende — endlich konnte ich ihn mal verwenden.")
                font.pixelSize: 12; color: root.theme.textPrimary; wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            Text {
                Layout.fillWidth: true
                text:           qsTr("Dieses Projekt wurde mit Unterstützung von KI-Werkzeugen entwickelt:")
                font.pixelSize: 12; color: root.theme.textPrimary; wrapMode: Text.WordWrap
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [
                        qsTr("⚙  Claude Code (Anthropic) — Code & Konzepte"),
                        qsTr("🖼  ChatGPT / DALL-E (OpenAI) — Strömlinge-Bilder"),
                        qsTr("🖼  Gemini / (Google) — Strömlinge-Bilder")
                    ]
                    Text {
                        Layout.fillWidth: true
                        text:           modelData
                        font.pixelSize: 12; color: root.theme.textSecondary; wrapMode: Text.WordWrap
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text:           qsTr("Die Projektidee stammt von mir — Konzepte und Quellcode habe ich gemeinsam mit KI erarbeitet.")
                font.pixelSize: 11; color: root.theme.textMuted; wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text:           qsTr("Der Quellcode ist Open Source (GPL-3.0). Die Konzeptdateien sind meine persönlichen Arbeitsunterlagen und werden nicht veröffentlicht.")
                font.pixelSize: 11; color: root.theme.textMuted; wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            Text {
                Layout.fillWidth: true
                text:           qsTr("Verwendete Bibliotheken:")
                font.pixelSize: 12; color: root.theme.textPrimary; wrapMode: Text.WordWrap
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [
                        qsTr("Qt Framework (LGPL v3) — qt.io/licensing"),
                        qsTr("SQLite (Public Domain) — sqlite.org")
                    ]
                    Text {
                        Layout.fillWidth: true
                        text:           modelData
                        font.pixelSize: 11; color: root.theme.textSecondary; wrapMode: Text.WordWrap
                    }
                }
            }
            Item { implicitHeight: 2 }
        }
    }
}
