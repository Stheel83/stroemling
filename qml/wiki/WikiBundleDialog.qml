import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root

    required property var theme
    property var          kategorien: []

    signal statusMeldung(string text, bool ok)
    signal bundleImportiert()

    function open() { bundleMenuPopup.open() }

    // ── Interner State ────────────────────────────────────────
    property string _kennung:  ""
    property string _titel:    ""
    property int    _version:  1
    property var    _katIds:   []

    // ── Bundle-Menü-Popup ─────────────────────────────────────
    Popup {
        id:           bundleMenuPopup
        anchors.centerIn: parent
        width:        280
        height:       contentCol.implicitHeight + 32
        modal:        true
        padding:      0
        closePolicy:  Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.theme.surface; radius: 6; border.color: root.theme.border
        }

        Column {
            id:      contentCol
            anchors { fill: parent; margins: 16 }
            spacing: 10

            Text {
                text:           qsTr("Bundle-Aktionen")
                font.pixelSize: 13; font.weight: Font.Medium
                color:          root.theme.textPrimary
            }
            Rectangle { width: parent.width; height: 1; color: root.theme.divider }

            Rectangle {
                width: parent.width; height: 32; radius: 3
                color: bndImportHover.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: qsTr("↓  Bundle importieren (.json)")
                    font.pixelSize: 11; color: root.theme.textPrimary
                }
                HoverHandler { id: bndImportHover }
                TapHandler {
                    onTapped: { bundleMenuPopup.close(); bundleImportDialog.open() }
                }
            }
            Rectangle {
                width: parent.width; height: 32; radius: 3
                color: bndExportHover.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: qsTr("↑  Bundle exportieren …")
                    font.pixelSize: 11; color: root.theme.textPrimary
                }
                HoverHandler { id: bndExportHover }
                TapHandler {
                    onTapped: {
                        bundleMenuPopup.close()
                        root._version = 1
                        root._kennung = ""
                        root._titel   = ""
                        root._katIds  = []
                        bundleExportPopup.open()
                    }
                }
            }
        }
    }

    // ── Bundle-Import FileDialog ──────────────────────────────
    FileDialog {
        id:          bundleImportDialog
        title:       qsTr("Bundle importieren")
        fileMode:    FileDialog.OpenFile
        nameFilters: [qsTr("Bundle-JSON (*.json)"), qsTr("Alle Dateien (*)")]
        onAccepted: {
            const res = db.wikiBundleAnwenden(selectedFile.toString())
            root.statusMeldung(
                res.erfolg
                    ? qsTr("Bundle eingespielt: %1").arg(res.meldung)
                    : qsTr("Bundle-Fehler: %1").arg(res.meldung),
                res.erfolg
            )
            root.bundleImportiert()
        }
    }

    // ── Bundle-Export-Popup ───────────────────────────────────
    Popup {
        id:           bundleExportPopup
        anchors.centerIn: parent
        width:        420
        modal:        true
        padding:      0
        closePolicy:  Popup.CloseOnEscape

        background: Rectangle {
            color: root.theme.surface; radius: 6; border.color: root.theme.border
        }

        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 12

            Text {
                text: qsTr("Bundle exportieren")
                font.pixelSize: 14; font.weight: Font.Medium
                color: root.theme.textPrimary
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }

            // Kennung
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: qsTr("Kennung:"); font.pixelSize: 11; color: root.theme.textMuted
                    width: 70
                }
                TextField {
                    id: bndKennungFeld
                    Layout.fillWidth: true; height: 28; font.pixelSize: 11
                    placeholderText: "z.B. meine_tutorials"
                    color: root.theme.textPrimary
                    text: root._kennung
                    onTextChanged: root._kennung = text
                    background: Rectangle {
                        radius: 3; color: root.theme.inputBg
                        border.color: bndKennungFeld.activeFocus ? root.theme.accent : root.theme.border
                    }
                }
            }

            // Titel
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: qsTr("Titel:"); font.pixelSize: 11; color: root.theme.textMuted
                    width: 70
                }
                TextField {
                    id: bndTitelFeld
                    Layout.fillWidth: true; height: 28; font.pixelSize: 11
                    placeholderText: qsTr("Lesbarer Name")
                    color: root.theme.textPrimary
                    text: root._titel
                    onTextChanged: root._titel = text
                    background: Rectangle {
                        radius: 3; color: root.theme.inputBg
                        border.color: bndTitelFeld.activeFocus ? root.theme.accent : root.theme.border
                    }
                }
            }

            // Version
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: qsTr("Version:"); font.pixelSize: 11; color: root.theme.textMuted
                    width: 70
                }
                SpinBox {
                    id: bndVersionSpin
                    from: 1; to: 9999; value: root._version
                    onValueChanged: root._version = value
                    font.pixelSize: 11
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 11;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            // Kategorien
            Text {
                text: qsTr("Kategorien:"); font.pixelSize: 11; color: root.theme.textMuted
            }
            Rectangle {
                Layout.fillWidth: true
                height: Math.min(bndKatCol.implicitHeight + 8, 160)
                color: root.theme.inputBg; radius: 3; border.color: root.theme.border
                clip: true
                Flickable {
                    anchors { fill: parent; margins: 4 }
                    contentHeight: bndKatCol.implicitHeight
                    Column {
                        id: bndKatCol
                        width: parent.width; spacing: 2
                        Repeater {
                            model: root.kategorien
                            delegate: RowLayout {
                                width: parent.width; spacing: 6; height: 24
                                CheckBox {
                                    id: bndKatChk
                                    checked: root._katIds.indexOf(modelData.id) >= 0
                                    onCheckedChanged: {
                                        var ids = root._katIds.slice()
                                        if (checked) { if (ids.indexOf(modelData.id) < 0) ids.push(modelData.id) }
                                        else { ids = ids.filter(function(i) { return i !== modelData.id }) }
                                        root._katIds = ids
                                    }
                                }
                                Text {
                                    text: modelData.name; font.pixelSize: 11
                                    color: root.theme.textPrimary
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 80; height: 30; radius: 3
                    color: bndExpSaveHover.containsMouse ? root.theme.accent : Qt.darker(root.theme.accent, 1.15)
                    enabled: root._kennung.trim() !== "" && root._katIds.length > 0
                    opacity: enabled ? 1.0 : 0.5
                    Text { anchors.centerIn: parent; text: qsTr("Speichern"); font.pixelSize: 11; color: "white" }
                    HoverHandler { id: bndExpSaveHover }
                    TapHandler {
                        onTapped: {
                            bundleExportPopup.close()
                            bundleExportSaveDialog.open()
                        }
                    }
                }
                Rectangle {
                    width: 70; height: 30; radius: 3
                    color: bndExpAbbrHover.containsMouse ? root.theme.hover : "transparent"
                    border.color: root.theme.border
                    Text { anchors.centerIn: parent; text: qsTr("Abbrechen"); font.pixelSize: 11; color: root.theme.textMuted }
                    HoverHandler { id: bndExpAbbrHover }
                    TapHandler { onTapped: bundleExportPopup.close() }
                }
            }
        }
    }

    // ── Bundle-Export SaveFileDialog ──────────────────────────
    FileDialog {
        id:          bundleExportSaveDialog
        title:       qsTr("Bundle speichern")
        fileMode:    FileDialog.SaveFile
        nameFilters: [qsTr("Bundle-JSON (*.json)"), qsTr("Alle Dateien (*)")]
        onAccepted: {
            const ok = db.wikiBundleExportieren(
                selectedFile.toString(),
                root._kennung.trim(),
                root._titel.trim(),
                root._version,
                root._katIds
            )
            if (ok) achievementManager.ereignis("wiki_bundle_exportiert")
            root.statusMeldung(
                ok ? qsTr("Bundle exportiert") : qsTr("Bundle-Export fehlgeschlagen"), ok
            )
        }
    }
}
