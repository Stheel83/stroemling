import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    required property var editor

    signal loeschenAngefordert(string symbolId, string symbolName)

    function kategorieName(k) {
        var n = { "kontakte": "Kontakte", "schutz": "Schutzgeräte", "antriebe": "Antriebe",
                  "passive": "Passive", "signalgeraete": "Signalgeräte", "klemmen": "Klemmen",
                  "sps_pls": "SPS / PLS", "kfz": "KFZ-Elektrik", "arduino": "Arduino",
                  "sensoren": "Sensoren" }
        return n[k] || (k || qsTr("Ohne Kategorie"))
    }

    width: 256
    color: editor.theme.sidebar
    clip:  true

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Kopfzeile: Filter + Neu-Button
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color:  root.editor.theme.sidebar

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 6

                TextField {
                    id: listeFilterFeld
                    Layout.fillWidth: true
                    implicitHeight:   28
                    placeholderText:  qsTr("Filter…")
                    font.pixelSize:   12
                    background: Rectangle { color: root.editor.theme.inputBg; radius: 4; border.color: root.editor.theme.border }
                    color: root.editor.theme.textPrimary
                    onTextChanged: root.editor.listeFilter = text
                }

                Button {
                    text:          qsTr("+ Neu")
                    implicitHeight: 28; implicitWidth: 62
                    onClicked:     root.editor.neuesSymbol()
                    background: Rectangle {
                        color: parent.hovered ? root.editor.theme.accent : root.editor.theme.inputBg
                        radius: 4; border.color: root.editor.theme.accent
                    }
                    contentItem: Text {
                        text: parent.text; color: root.editor.theme.textPrimary; font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.editor.theme.border }

        ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ListView {
                id:    symbolListeView
                model: root.editor.gefilterteSymbole
                clip:  true

                section.property:  "kategorie"
                section.criteria:  ViewSection.FullString
                section.delegate: Rectangle {
                    width:  ListView.view.width
                    height: 22
                    color:  root.editor.theme.surfaceDeep

                    Text {
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        text:  root.kategorieName(section).toUpperCase()
                        font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 1.5
                        color: root.editor.theme.textMuted
                    }
                }

                delegate: Rectangle {
                    id:     listItem
                    width:  ListView.view.width
                    height: 50
                    color:  root.editor.aktiveListenId === modelData.id
                            ? root.editor.theme.badge
                            : (listeItemHover.hovered ? root.editor.theme.surfaceDeep : "transparent")
                    radius: 2
                    border.width: modelData.markiertLoeschen ? 1 : 0
                    border.color: "#cc4444"

                    ColumnLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 6; topMargin: 5; bottomMargin: 5 }
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text:  modelData.ist_builtin ? "🔒" : "✏"
                                font.pixelSize: 10
                                color: modelData.ist_builtin ? root.editor.theme.textMuted : root.editor.theme.accent
                            }
                            Text {
                                Layout.fillWidth: true
                                text:  modelData.name
                                font.pixelSize: 12; font.weight: Font.Medium
                                color: root.editor.theme.textPrimary; elide: Text.ElideRight
                            }
                            Rectangle {
                                implicitWidth: groesseLabel.implicitWidth + 8; height: 16; radius: 3
                                color: root.editor.theme.surfaceDeep
                                Text {
                                    id: groesseLabel
                                    anchors.centerIn: parent
                                    text: (modelData.breiteMm || 16) + "×" + (modelData.hoeheMm || 16) + "mm"
                                    font.pixelSize: 9; color: root.editor.theme.textMuted
                                }
                            }

                            // Als Vorlage kopieren
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                visible: listeItemHover.hovered || root.editor.aktiveListenId === modelData.id
                                color:   listeKopHover.hovered ? root.editor.theme.badge : "transparent"
                                ToolTip.visible: listeKopHover.hovered; ToolTip.delay: 600
                                ToolTip.text: qsTr("Als Vorlage kopieren")
                                Text { anchors.centerIn: parent; text: "❐"; font.pixelSize: 13; color: root.editor.theme.textSecondary }
                                HoverHandler { id: listeKopHover }
                                TapHandler {
                                    onTapped: {
                                        var src = modelData.id
                                        root.editor.aktiveListenId = ""
                                        root.editor.editSymbolId   = ""
                                        root.editor.vorlageId      = ""
                                        Qt.callLater(function() { root.editor.vorlageId = src })
                                    }
                                }
                            }

                            // Zum Vergleichen markieren (SE-VERGLEICH-01) — sitzungsbasiert, keine DB
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                property bool markiert: root.editor.vergleichsListe.indexOf(modelData.id) >= 0
                                visible: listeItemHover.hovered || root.editor.aktiveListenId === modelData.id || markiert
                                color:   listeVglHover.hovered ? root.editor.theme.badge : "transparent"
                                ToolTip.visible: listeVglHover.hovered; ToolTip.delay: 600
                                ToolTip.text: markiert ? qsTr("Aus Vergleichsliste entfernen") : qsTr("Zum Vergleichen markieren")
                                Text {
                                    anchors.centerIn: parent; text: "📌"; font.pixelSize: 12
                                    color: parent.markiert ? root.editor.theme.accent : root.editor.theme.textSecondary
                                }
                                HoverHandler { id: listeVglHover }
                                TapHandler {
                                    onTapped: root.editor.vergleichToggle(modelData.id)
                                }
                            }

                            // Zum Löschen markieren (SYM-LOESCH-MARKIERUNG-01) — built-in + eigene
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                visible: listeItemHover.hovered || root.editor.aktiveListenId === modelData.id ||
                                         modelData.markiertLoeschen
                                color:   listeMarkHover.hovered ? root.editor.theme.badge : "transparent"
                                ToolTip.visible: listeMarkHover.hovered; ToolTip.delay: 600
                                ToolTip.text: modelData.markiertLoeschen ? qsTr("Löschmarkierung aufheben") : qsTr("Zum Löschen markieren")
                                Text {
                                    anchors.centerIn: parent; text: "🗑"; font.pixelSize: 12
                                    color: modelData.markiertLoeschen ? "#cc4444" : root.editor.theme.textSecondary
                                }
                                HoverHandler { id: listeMarkHover }
                                TapHandler {
                                    onTapped: root.editor.markierungLoeschenToggle(modelData.id)
                                }
                            }

                            // Löschen (nur eigene)
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                visible: !modelData.ist_builtin &&
                                         (listeItemHover.hovered || root.editor.aktiveListenId === modelData.id)
                                color: listeDelHover.hovered ? theme.activeItemAlt : "transparent"
                                ToolTip.visible: listeDelHover.hovered; ToolTip.delay: 600
                                ToolTip.text: qsTr("Symbol löschen")
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; color: "#ff4444" }
                                HoverHandler { id: listeDelHover }
                                TapHandler {
                                    onTapped: root.loeschenAngefordert(modelData.id, modelData.name)
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text:  modelData.kategorie || ""
                            font.pixelSize: 10; color: root.editor.theme.textMuted; elide: Text.ElideRight
                        }
                    }

                    HoverHandler { id: listeItemHover }
                    TapHandler {
                        onTapped: {
                            root.editor.aktiveListenId = modelData.id
                            root.editor.vorlageId      = ""
                            root.editor.editSymbolId   = modelData.id
                        }
                    }
                }
            }
        }
    }
    DebugLabel { panelName: qsTr("SE Symbol-Liste"); visible: editor.debug }
}
