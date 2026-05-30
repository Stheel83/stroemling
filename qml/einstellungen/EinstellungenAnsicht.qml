import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    required property var theme
    property bool debug: false

    signal jetztTesten()
    signal gespraechTexteGeaendert(string json)

    property bool seiteOffen: true   // von Main.qml: root.aktivSeiteId >= 0

    property var _infos: ({})

    Component.onCompleted: { _infos = db.datenbankInfos(); funBlock.laden() }
    onVisibleChanged: if (visible) { _infos = db.datenbankInfos(); funBlock.laden() }

    Rectangle { anchors.fill: parent; color: root.theme.surfaceDeep }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:           48
            color:            root.theme.surface
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.theme.border }
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text:           qsTr("Einstellungen")
                font.pixelSize: 15; font.weight: Font.Medium
                color:          root.theme.textPrimary
            }
        }

        // ── Scrollbarer Inhalt ────────────────────────────────────
        ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentWidth:      availableWidth
            clip:              true

            ColumnLayout {
                width:   parent.width
                spacing: 0

                EinDatenbankpfadeBlock {
                    theme: root.theme
                    infos: root._infos
                }

                // ── Sektion: Versionen ────────────────────────────
                Item { implicitHeight: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Versionen")
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
                    height:             3 * 44
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    Column {
                        anchors.fill: parent

                        Repeater {
                            model: [
                                { label: qsTr("Haupt-DB Schema"),   wert: root._infos["schemaVersion"]     || "–" },
                                { label: qsTr("Wiki-DB Schema"),    wert: root._infos["wikiSchemaVersion"] || "–" },
                                { label: qsTr("Backups vorhanden"), wert: root._infos["backupAnzahl"] !== undefined
                                                                          ? (root._infos["backupAnzahl"] + qsTr(" Datei(en)"))
                                                                          : "–" }
                            ]

                            delegate: Item {
                                width:  parent.width; height: 44

                                Rectangle {
                                    visible:        index < 2
                                    anchors.bottom: parent.bottom
                                    width:          parent.width; height: 1
                                    color:          root.theme.divider
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    Text {
                                        text:             modelData.label
                                        font.pixelSize:   12; color: root.theme.textPrimary
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text:           modelData.wert.toString()
                                        font.pixelSize: 12; font.family: "monospace"
                                        color:          root.theme.accent
                                    }
                                }
                            }
                        }
                    }
                }

                EinFunModusBlock {
                    id:          funBlock
                    theme:       root.theme
                    seiteOffen:  root.seiteOffen
                    onJetztTesten:              root.jetztTesten()
                    onGespraechTexteGeaendert:  function(json) { root.gespraechTexteGeaendert(json) }
                }

                // ── Sektion: Version ─────────────────────────────
                Item { implicitHeight: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Version")
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
                    height:             88
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    ColumnLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredHeight: 44
                            Text { text: qsTr("Version"); font.pixelSize: 12; color: root.theme.textPrimary; Layout.fillWidth: true }
                            Text { text: appVersion;      font.pixelSize: 12; font.family: "monospace"; color: root.theme.accent }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }

                        RowLayout {
                            Layout.fillWidth: true; Layout.preferredHeight: 44
                            Text { text: qsTr("Build-Datum"); font.pixelSize: 12; color: root.theme.textPrimary; Layout.fillWidth: true }
                            Text { text: buildDatum;          font.pixelSize: 12; font.family: "monospace"; color: root.theme.accent }
                        }
                    }
                }

                // ── Sektion: Strömlinge ──────────────────────────
                Item { implicitHeight: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Strömlinge")
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
                    implicitHeight:     schwCol.implicitHeight + 24
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border
                    clip:               true

                    Column {
                        id:    schwCol
                        width: parent.width
                        anchors.top: parent.top
                        anchors.topMargin: 16

                        Image {
                            width:    parent.width - 32
                            anchors.horizontalCenter: parent.horizontalCenter
                            source:   "qrc:/assets/schwaerzchen_sheet.png"
                            fillMode: Image.PreserveAspectFit
                            smooth:   true; mipmap: true
                        }
                        Item { height: 10 }
                        Text {
                            width:   parent.width - 32
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:           qsTr("Die Strömlinge sind das lebendige Maskottchen-System von Strömling Design. Jeder Strömling repräsentiert einen elektrischen Leitertyp, ein Signal oder einen Systemzustand.")
                            font.pixelSize: 11; color: root.theme.textMuted; wrapMode: Text.WordWrap
                        }
                        Item { height: 8 }
                    }
                }

                EinMitwirkendeBlock { theme: root.theme }

                EinEntstehungBlock  { theme: root.theme }

                // ── Sektion: Lizenz & Open Source ────────────────
                Item { implicitHeight: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Lizenz & Open Source")
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
                    height:             lizenzCol.implicitHeight + 24

                    ColumnLayout {
                        id:      lizenzCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text:           qsTr("Strömling Design ist freie Software, lizenziert unter der GNU General Public License v3.")
                            font.pixelSize: 12; color: root.theme.textPrimary; wrapMode: Text.WordWrap
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: [
                                    qsTr("✓  Privat nutzbar – kostenlos"),
                                    qsTr("✓  Bildungseinrichtungen – kostenlos"),
                                    qsTr("✓  Quellcode öffentlich einsehbar"),
                                    qsTr("✓  Zukünftige Versionen bleiben Open Source"),
                                    qsTr("✓  Fehlermeldungen und Verbesserungsvorschläge willkommen")
                                ]
                                delegate: Text {
                                    Layout.fillWidth: true
                                    text: modelData; font.pixelSize: 12; color: root.theme.textPrimary; wrapMode: Text.WordWrap
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text:           qsTr("Wenn dir das Programm nützt, freue ich mich über eine Spende – das hilft, das Projekt weiterzuentwickeln.")
                            font.pixelSize: 11; font.italic: true; color: root.theme.textMuted; wrapMode: Text.WordWrap
                            topPadding: 4
                        }
                        Text {
                            Layout.fillWidth: true
                            text:           "GPL-3.0-or-later · https://www.gnu.org/licenses/gpl-3.0.txt"
                            font.pixelSize: 10; font.family: "monospace"; color: root.theme.textMuted; wrapMode: Text.WordWrap
                        }
                    }
                }

                Item { implicitHeight: 32 }
            }
        }
    }

    DebugLabel { panelName: qsTr("Einstellungen-Ansicht"); visible: root.debug }
}
