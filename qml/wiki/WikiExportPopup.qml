import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// Wiki exportieren (WIKI-EXP-01, Konzept 25 §12): ein Dialog für Sicherung (ganzes Wiki) und Bundle (für andere).
Item {
    id: root

    required property var theme
    property var          kategorien: []

    function open() {
        _bundle  = false
        _version = 1
        _kennung = ""
        _titel   = ""
        _katIds  = []
        _zahlen  = db.wikiEigeneArtikelProKategorie()
        exportPopup.open()
    }

    // ── Interner State ────────────────────────────────────────
    property bool   _bundle:   false
    property string _kennung:  ""
    property string _titel:    ""
    property int    _version:  1
    property var    _katIds:   []
    property var    _zahlen:   ({})   // {kategorie_id: Anzahl eigener Artikel} – ohne mitgelieferte, unveränderte

    // Artikel installierter Bundles gehören zu deren Bundle und werden nicht umetikettiert
    readonly property int _fremdArtikel: _bundle ? db.wikiBundleFremdArtikelAnzahl(_katIds) : 0

    Popup {
        id:           exportPopup
        anchors.centerIn: Overlay.overlay
        width:        440
        // nie höher als das Fenster; reicht der Platz nicht, scrollt der Inhalt
        height:       Math.min(inhalt.implicitHeight + 40, (Overlay.overlay ? Overlay.overlay.height : 600) - 40)
        modal:        true
        padding:      0
        closePolicy:  Popup.CloseOnEscape

        background: Rectangle {
            color: root.theme.surface; radius: 6; border.color: root.theme.border
        }

        Flickable {
          anchors.fill: parent
          clip: true
          contentWidth: width
          contentHeight: inhalt.implicitHeight + 40
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { }

        ColumnLayout {
            id: inhalt
            x: 20; y: 20
            width: parent.width - 40
            spacing: 12

            Text {
                text: qsTr("Wiki exportieren")
                font.pixelSize: 14; font.weight: Font.Medium
                color: root.theme.textPrimary
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.theme.divider }

            // Wofür? (Sicherung | Bundle)
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [
                        { bundle: false, titel: qsTr("Sicherung (ganzes Wiki)") },
                        { bundle: true,  titel: qsTr("Bundle für andere") }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 30; radius: 3
                        color: root._bundle === modelData.bundle ? root.theme.accent
                                                                  : (modeHover.hovered ? root.theme.hover : "transparent")
                        border.color: root._bundle === modelData.bundle ? root.theme.accent : root.theme.border
                        Text {
                            anchors.centerIn: parent
                            text: modelData.titel; font.pixelSize: 11
                            color: root._bundle === modelData.bundle ? "white" : root.theme.textPrimary
                        }
                        HoverHandler { id: modeHover }
                        TapHandler { onTapped: root._bundle = modelData.bundle }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 11; color: root.theme.textMuted
                text: root._bundle
                      ? qsTr("Ein Bundle verteilt ausgewählte Kategorien an andere (z. B. über den Teamordner im Strömling Manager). "
                             + "Es hat eine Kennung und eine Version; beim Import werden eigene Anmerkungen an Artikeln nicht überschrieben.")
                      : qsTr("Sichert deine eigenen und geänderten Artikel samt Bildern in einer Datei. Unveränderte mitgelieferte Artikel kommen mit dem Programm "
                             + "und sind nicht enthalten; Herkunft und Stand installierter Bundles bleiben erhalten.")
            }

            // ── nur Bundle ────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: root._bundle
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text {
                        text: qsTr("Kennung:"); font.pixelSize: 11; color: root.theme.textMuted
                        Layout.preferredWidth: 70
                    }
                    TextField {
                        id: kennungFeld
                        Layout.fillWidth: true; Layout.preferredHeight: 28; font.pixelSize: 11
                        placeholderText: qsTr("z. B. firma_wiki")
                        color: root.theme.textPrimary
                        text: root._kennung
                        onTextChanged: root._kennung = text
                        background: Rectangle {
                            radius: 3; color: root.theme.inputBg
                            border.color: kennungFeld.activeFocus ? root.theme.accent : root.theme.border
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text {
                        text: qsTr("Titel:"); font.pixelSize: 11; color: root.theme.textMuted
                        Layout.preferredWidth: 70
                    }
                    TextField {
                        id: titelFeld
                        Layout.fillWidth: true; Layout.preferredHeight: 28; font.pixelSize: 11
                        placeholderText: qsTr("Lesbarer Name")
                        color: root.theme.textPrimary
                        text: root._titel
                        onTextChanged: root._titel = text
                        background: Rectangle {
                            radius: 3; color: root.theme.inputBg
                            border.color: titelFeld.activeFocus ? root.theme.accent : root.theme.border
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text {
                        text: qsTr("Version:"); font.pixelSize: 11; color: root.theme.textMuted
                        Layout.preferredWidth: 70
                    }
                    SpinBox {
                        from: 1; to: 9999; value: root._version
                        onValueChanged: root._version = value
                        font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                        contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 11;
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11; color: root.theme.textMuted
                    text: qsTr("Kategorien (Zahl = eigene oder geänderte Artikel; unveränderte mitgelieferte Artikel kommen mit dem Programm und sind nicht enthalten):")
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(katCol.implicitHeight + 8, 160)
                    color: root.theme.inputBg; radius: 3; border.color: root.theme.border
                    clip: true
                    Flickable {
                        anchors { fill: parent; margins: 4 }
                        contentHeight: katCol.implicitHeight
                        Column {
                            id: katCol
                            width: parent.width; spacing: 2
                            Repeater {
                                model: root.kategorien
                                delegate: RowLayout {
                                    width: parent.width; spacing: 6; height: 24
                                    CheckBox {
                                        enabled: (root._zahlen[modelData.id] || 0) > 0
                                        checked: root._katIds.indexOf(modelData.id) >= 0
                                        onCheckedChanged: {
                                            var ids = root._katIds.slice()
                                            if (checked) { if (ids.indexOf(modelData.id) < 0) ids.push(modelData.id) }
                                            else { ids = ids.filter(function(i) { return i !== modelData.id }) }
                                            root._katIds = ids
                                        }
                                    }
                                    Text {
                                        text: modelData.name + "  (" + (root._zahlen[modelData.id] || 0) + ")"
                                        font.pixelSize: 11
                                        color: (root._zahlen[modelData.id] || 0) > 0 ? root.theme.textPrimary : root.theme.textMuted
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: root._fremdArtikel > 0
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11; color: root.theme.textMuted
                    text: qsTr("%n Artikel aus installierten Bundles sind nicht enthalten (sie gehören zu ihrem eigenen Bundle).", "", root._fremdArtikel)
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 80; implicitHeight: 30; radius: 3
                    color: saveHover.hovered ? root.theme.accent : Qt.darker(root.theme.accent, 1.15)
                    enabled: !root._bundle || (root._kennung.trim() !== "" && root._katIds.length > 0)
                    opacity: enabled ? 1.0 : 0.5
                    Text { anchors.centerIn: parent; text: qsTr("Speichern"); font.pixelSize: 11; color: "white" }
                    HoverHandler { id: saveHover }
                    TapHandler {
                        onTapped: {
                            exportPopup.close()
                            saveDialog.open()
                        }
                    }
                }
                Rectangle {
                    implicitWidth: 70; implicitHeight: 30; radius: 3
                    color: abbrHover.hovered ? root.theme.hover : "transparent"
                    border.color: root.theme.border
                    Text { anchors.centerIn: parent; text: qsTr("Abbrechen"); font.pixelSize: 11; color: root.theme.textMuted }
                    HoverHandler { id: abbrHover }
                    TapHandler { onTapped: exportPopup.close() }
                }
            }
        }
        }
    }

    FileDialog {
        id:          saveDialog
        title:       root._bundle ? qsTr("Bundle speichern") : qsTr("Wiki-Sicherung speichern")
        fileMode:    FileDialog.SaveFile
        nameFilters: [qsTr("JSON-Dateien (*.json)"), qsTr("Alle Dateien (*)")]
        onAccepted: {
            const res = db.wikiExportieren(selectedFile.toString(), {
                bundle:       root._bundle,
                kennung:      root._kennung.trim(),
                titel:        root._titel.trim(),
                version:      root._version,
                kategorieIds: root._katIds
            })
            if (res.erfolg && root._bundle) achievementManager.ereignis("wiki_bundle_exportiert")
            meldungManager.zeigen(
                res.erfolg
                    ? (root._bundle ? qsTr("Bundle exportiert (%1 Artikel)").arg(res.artikel)
                                    : qsTr("Wiki erfolgreich exportiert"))
                    : qsTr("Export fehlgeschlagen: %1").arg(res.meldung),
                res.erfolg
            )
        }
    }
}
