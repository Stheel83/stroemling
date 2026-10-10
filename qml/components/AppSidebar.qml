import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Navigationsleiste (linke Sidebar): Ansichts-Schaltflächen, Theme-Picker, aktives Projekt.
// Zustandslos – Navigation und Seiteneffekte laufen über die Signale.
Rectangle {
    id:    root
    color: root.theme.sidebar

    required property var theme
    property string aktiveAnsicht:   ""
    property int    aktivProjektId:  -1
    property string aktivProjektName: ""
    property bool   debug:           false
    // Darstellung (Theme-Picker): Namen/Objekte kommen vom Aufrufer
    property var    themes:          ({})
    property string themeName:       ""

    signal ansichtGewaehlt(string ansicht)
    signal symbolEditorAngefordert()
    signal pdfExportAngefordert()
    signal themeGewaehlt(string name)

    DebugLabel { panelName: qsTr("Navigationsleiste"); visible: root.debug }

    ColumnLayout {
        anchors {
            fill:    parent
            margins: 8
        }
        spacing: 2

        Item { height: 4 }
        LogoHeader {
            theme: root.theme
            Layout.fillWidth: true
        }

        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }
        Item { height: 4 }

        SidebarButton {
            theme:   root.theme
            icon:    "📁"
            label:   qsTr("Projekte")
            active:  root.aktiveAnsicht === "projekte"
            tooltip: qsTr("Neues Projekt anlegen oder vorhandenes öffnen")
            onClicked: root.ansichtGewaehlt("projekte")
        }
        SidebarButton {
            theme:           root.theme
            icon:            "📄"
            label:           qsTr("Seiten")
            active:          root.aktiveAnsicht === "seiten"
            enabled:         root.aktivProjektId >= 0
            opacity:         enabled ? 1.0 : 0.4
            tooltip:         qsTr("Seitenbaum: Seiten, Anlagen und Orte verwalten")
            tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
            onClicked: root.ansichtGewaehlt("seiten")
        }
        SidebarButton {
            theme:           root.theme
            icon:            "📋"
            label:           qsTr("Listen")
            active:          root.aktiveAnsicht === "stueckliste"
            enabled:         root.aktivProjektId >= 0
            opacity:         enabled ? 1.0 : 0.4
            tooltip:         qsTr("Stückliste, Kabelliste, Klemmenplan und Querverweise")
            tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
            onClicked: root.ansichtGewaehlt("stueckliste")
        }
        SidebarButton {
            theme:           root.theme
            icon:            "🖥"
            label:           qsTr("SPS/PLS")
            active:          root.aktiveAnsicht === "sps"
            enabled:         root.aktivProjektId >= 0
            opacity:         enabled ? 1.0 : 0.4
            tooltip:         qsTr("SPS/PLS-Konfiguration: Hardware, Baugruppen und I/O-Kanäle verwalten")
            tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
            onClicked: root.ansichtGewaehlt("sps")
        }
        SidebarButton {
            theme:   root.theme
            icon:    "🔧"
            label:   qsTr("Bauteile")
            active:  root.aktiveAnsicht === "bauteile"
            tooltip: qsTr("Bauteilkatalog: Klemmen, Kabel und Geräte verwalten")
            onClicked: root.ansichtGewaehlt("bauteile")
        }
        SidebarButton {
            theme:           root.theme
            icon:            "✔"
            label:           qsTr("IBN")
            active:          root.aktiveAnsicht === "ibn"
            enabled:         root.aktivProjektId >= 0
            opacity:         enabled ? 1.0 : 0.4
            tooltip:         qsTr("Inbetriebnahme: Betriebsmittel prüfen und Messwerte erfassen")
            tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
            onClicked: {
                root.ansichtGewaehlt("ibn")
                achievementManager.ereignis("ibn_geoeffnet")
            }
        }
        SidebarButton {
            theme:           root.theme
            icon:            "🔍"
            label:           qsTr("Fehlersuche")
            active:          root.aktiveAnsicht === "fehlersuche"
            enabled:         root.aktivProjektId >= 0
            opacity:         enabled ? 1.0 : 0.4
            tooltip:         qsTr("Fehlersuchmodus: Strompfad durch den Schaltplan nachverfolgen")
            tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
            onClicked: root.ansichtGewaehlt("fehlersuche")
        }
        SidebarButton {
            theme:   root.theme
            icon:    "⚡"
            label:   qsTr("Kabelrechner")
            active:  root.aktiveAnsicht === "kabelrechner"
            tooltip: qsTr("Leitungsquerschnitt nach VDE 0298 / IEC 60364 berechnen")
            onClicked: {
                root.ansichtGewaehlt("kabelrechner")
                achievementManager.ereignis("kabelrechner_geoeffnet")
            }
        }
        SidebarButton {
            theme:           root.theme
            icon:            "🖨"
            label:           qsTr("PDF-Export")
            enabled:         root.aktivProjektId >= 0
            opacity:         enabled ? 1.0 : 0.4
            tooltip:         qsTr("Alle Seiten des Projekts als PDF exportieren")
            tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
            onClicked: root.pdfExportAngefordert()
        }
        SidebarButton {
            theme:           root.theme
            icon:            "📐"
            label:           qsTr("Normblatt")
            active:          root.aktiveAnsicht === "normblatt"
            enabled:         root.aktivProjektId >= 0
            opacity:         enabled ? 1.0 : 0.4
            tooltip:         qsTr("Schriftfeld nach DIN 6771 gestalten und Normblatt-Vorlage wählen")
            tooltipDisabled: qsTr("Zuerst ein Projekt öffnen")
            onClicked: root.ansichtGewaehlt("normblatt")
        }
        SidebarButton {
            theme:   root.theme
            icon:    "✏"
            label:   qsTr("Symbole")
            active:  root.aktiveAnsicht === "symbol_editor"
            tooltip: qsTr("Symboleditor: Eigene Schaltsymbole zeichnen und bearbeiten")
            onClicked: {
                root.symbolEditorVorher    = root.aktiveAnsicht
                root.symbolEditorId        = ""
                root.symbolEditorVorlageId = ""
                root.aktiveAnsicht         = "symbol_editor"
                achievementManager.ereignis("symbol_editor_geoeffnet")
            }
        }
        SidebarButton {
            theme:   root.theme
            icon:    "📚"
            label:   qsTr("Wiki")
            active:  root.aktiveAnsicht === "wiki"
            tooltip: qsTr("Erfahrungs-Wiki: Fachwissen nachschlagen und eigene Artikel erfassen")
            onClicked: {
                root.ansichtGewaehlt("wiki")
                achievementManager.ereignis("wiki_geoeffnet")
            }
        }
        SidebarButton {
            theme:   root.theme
            icon:    "🏆"
            label:   qsTr("Errungenschaften")
            active:  root.aktiveAnsicht === "achievements"
            tooltip: qsTr("Deine freigeschalteten Errungenschaften")
            onClicked: root.ansichtGewaehlt("achievements")
        }
        SidebarButton {
            theme:   root.theme
            icon:    "🔔"
            label:   qsTr("Meldungen")
            active:  root.aktiveAnsicht === "meldungen"
            tooltip: qsTr("Zuletzt angezeigte Meldungen dieser Session")
            onClicked: root.ansichtGewaehlt("meldungen")
        }
        SidebarButton {
            theme:   root.theme
            icon:    "⚙"
            label:   qsTr("Einstellungen")
            active:  root.aktiveAnsicht === "einstellungen"
            tooltip: qsTr("Theme, Darstellung und App-Einstellungen")
            onClicked: root.ansichtGewaehlt("einstellungen")
        }

        Item { Layout.fillHeight: true }

        // ── Theme-Picker ──────────────────────────────────
        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }
        Item { height: 4 }
        Text {
            text:        qsTr("Darstellung")
            font.pixelSize: 9
            color:       root.theme.textMuted
            leftPadding: 4
        }
        Item { height: 3 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: ["dunkel", "hell", "blueprint"]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    height:       22
                    radius:       3
                    color:        root.themeName === modelData ? root.theme.activeItemAlt : "transparent"
                    border.color: root.themeName === modelData ? root.theme.accent : root.theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text:           root.themes[modelData].name
                        font.pixelSize: 9
                        color:          root.themeName === modelData ? root.theme.accent : root.theme.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.themeGewaehlt(modelData)
                    }
                }
            }
        }
        Item { height: 4 }

        // ── Sprach-Picker ─────────────────────────────────
        // Ausgeblendet bis L20 (GUI-Übersetzungen) umgesetzt ist:
        // i18n/stroemling_en.ts enthält aktuell 0 echte Übersetzungen
        // (205 Einträge, alle "unfinished"/leer). "Auto" würde bei
        // englischem System-Locale denselben leeren EN-Übersetzer
        // laden und für diese 205 Strings leeren Text statt des
        // deutschen Quelltexts zeigen – daher der ganze Block
        // ausgeblendet, nicht nur "EN". root.aktivSprache/
        // langSettings bleiben unverändert (Settings-Wert "system"
        // wirkt sich bei fehlendem Übersetzer nicht aus).
        // konzept/projekt/08_roadmap.md L20

        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

        Item {
            height:             48
            Layout.fillWidth:   true
            visible:            root.aktivProjektId >= 0

            Column {
                anchors {
                    left:           parent.left
                    leftMargin:     8
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2
                Text {
                    text:           qsTr("Aktives Projekt")
                    font.pixelSize: 10
                    color:          root.theme.borderLight
                }
                Text {
                    text:           root.aktivProjektName
                    font.pixelSize: 12
                    font.weight:    Font.Medium
                    color:          root.theme.accent
                    width:          180
                    elide:          Text.ElideRight
                }
            }
        }
    }
}
