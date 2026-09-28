import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

// LISTEN-PDF-DIALOG-01: eigener Pfad-Picker statt nativem FileDialog (der im
// AppImage nicht zuverlässig funktioniert) – 1:1 dasselbe Muster wie
// PdfExportDialog.qml (Schaltplan) und IbnPdfExportDialog.qml (Prüfprotokoll),
// aber datenunabhängig: der eigentliche PDF-Aufbau (Spalten/Zeilen) bleibt
// beim Aufrufer, dieser Dialog kümmert sich nur um Pfadauswahl,
// Überschreiben-Bestätigung und Status/Erfolgsmeldung.
Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  440
    padding: 20

    required property var    theme
    property string          dateiname: "liste.pdf"   // Vorschlag für Dateiname
    property string          titelText: qsTr("Als PDF exportieren")

    // Aufrufer verbindet sich hierauf, führt db.listePdfSpeichern() aus und
    // ruft anschließend erfolgReagieren(ok) auf.
    signal exportAngefordert(string pfad)

    function erfolgReagieren(ok) {
        if (ok) {
            meldungManager.zeigen(qsTr("PDF gespeichert."), true)
            root.accept()
        } else {
            statusText.text = qsTr("Export fehlgeschlagen. Pfad prüfen.")
        }
    }

    title: root.titelText

    background: Rectangle {
        color:        root.theme.sidebar
        border.color: root.theme.border
        border.width: 1; radius: 6
    }

    onOpened: statusText.text = ""

    // Eigener Pfad-Picker – identisch zu PdfExportDialog.qml/IbnPdfExportDialog.qml
    Dialog {
        id: speicherDialog
        title:  qsTr("PDF speichern unter")
        modal:  true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width:  440
        padding: 16

        property string selectedFile: ""

        background: Rectangle {
            color: root.theme.sidebar; border.color: root.theme.border
            border.width: 1; radius: 6
        }

        onOpened: {
            var aktuell = _stripUrl(tfPfad.text.trim())
            _pfadFeld.text = aktuell.length > 0
                ? aktuell
                : _stripUrl(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)) + "/" + root.dateiname
        }

        function _stripUrl(s) {
            s = String(s)
            if (s.startsWith("file:///")) return s.substring(7)
            if (s.startsWith("file://"))  return s.substring(7)
            return s
        }

        contentItem: ColumnLayout {
            spacing: 8

            Text { text: qsTr("Schnellzugriff"); color: root.theme.textMuted; font.pixelSize: 11 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [
                        { label: "Home",      path: StandardPaths.writableLocation(StandardPaths.HomeLocation) },
                        { label: qsTr("Dokumente"), path: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) },
                        { label: qsTr("Downloads"), path: StandardPaths.writableLocation(StandardPaths.DownloadLocation) },
                        { label: qsTr("Desktop"),   path: StandardPaths.writableLocation(StandardPaths.DesktopLocation) }
                    ]
                    Button {
                        text: modelData.label
                        Layout.fillWidth: true
                        implicitHeight: 28
                        onClicked: {
                            var dir = ("" + modelData.path)
                            if (dir.startsWith("file:///")) dir = dir.substring(7)
                            else if (dir.startsWith("file://")) dir = dir.substring(7)
                            var cur = ("" + _pfadFeld.text)
                            if (cur.startsWith("file:///")) cur = cur.substring(7)
                            else if (cur.startsWith("file://")) cur = cur.substring(7)
                            var parts = cur.split("/")
                            var name = parts[parts.length - 1]
                            if (!name || !name.includes(".")) name = root.dateiname
                            _pfadFeld.text = dir + "/" + name
                        }
                        contentItem: Text {
                            text: parent.text; font.pixelSize: 11
                            color: root.theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered ? root.theme.hover : root.theme.inputBg
                            radius: 4; border.color: root.theme.border
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            Text { text: qsTr("Dateipfad"); color: root.theme.textMuted; font.pixelSize: 11 }

            TextField {
                id: _pfadFeld
                Layout.fillWidth: true
                placeholderText: qsTr("/home/user/") + root.dateiname
                color:           root.theme.textPrimary
                font.pixelSize:  12
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Button {
                    text: qsTr("Abbrechen"); Layout.fillWidth: true; implicitHeight: 32
                    onClicked: speicherDialog.reject()
                    contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                }
                Button {
                    text: qsTr("OK"); Layout.fillWidth: true; implicitHeight: 32
                    enabled: _pfadFeld.text.trim().length > 0
                    onClicked: {
                        var p = ("" + _pfadFeld.text).trim()
                        if (p.startsWith("file:///")) p = p.substring(7)
                        else if (p.startsWith("file://")) p = p.substring(7)
                        if (!p.endsWith(".pdf")) p = p + ".pdf"
                        speicherDialog.selectedFile = "file:///" + p.replace(/^\/+/, "")
                        speicherDialog.accept()
                    }
                    contentItem: Text { text: parent.text; font.pixelSize: 12
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                }
            }
        }

        onAccepted: tfPfad.text = selectedFile
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text:           qsTr("Speichern als")
            color:          root.theme.textMuted
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: tfPfad
                Layout.fillWidth: true
                placeholderText:  qsTr("Dateipfad …")
                color:            root.theme.textPrimary
                font.pixelSize:   12
                background: Rectangle {
                    color:        root.theme.inputBg
                    radius:       4
                    border.color: root.theme.border
                }
            }

            Button {
                text:          "📁"
                implicitWidth: 32
                implicitHeight: 32
                contentItem: Text {
                    text:  parent.text
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius:       4
                    border.color: root.theme.border
                }
                onClicked: speicherDialog.open()
            }
        }

        Text {
            id: statusText
            Layout.fillWidth: true
            text:           ""
            color:          "#cc6666"
            font.pixelSize: 11
            wrapMode:       Text.WordWrap
            visible:        text.length > 0
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text:           qsTr("Abbrechen")
                Layout.fillWidth: true
                implicitHeight: 32
                contentItem: Text {
                    text:  parent.text
                    color: root.theme.textSecondary
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius:       4
                    border.color: root.theme.border
                }
                onClicked: root.reject()
            }

            Button {
                text:           qsTr("Exportieren")
                Layout.fillWidth: true
                implicitHeight: 32
                enabled:        tfPfad.text.trim().length > 0
                contentItem: Text {
                    text:  parent.text
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.enabled
                           ? (parent.hovered ? root.theme.accent : root.theme.inputBg)
                           : root.theme.inputBg
                    radius:       4
                    border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    statusText.text = ""
                    var pfad = tfPfad.text.trim()
                    if (db.dateiExistiert(pfad)) {
                        ueberschreibenDialog.pfad = pfad
                        ueberschreibenDialog.open()
                    } else {
                        root.exportAngefordert(pfad)
                    }
                }
            }
        }

        // ── Überschreiben-Bestätigung ──────────────────────────────
        Dialog {
            id:      ueberschreibenDialog
            title:   qsTr("Datei existiert bereits")
            modal:   true
            parent:  Overlay.overlay
            anchors.centerIn: parent
            width:   360
            padding: 20

            property string pfad: ""

            background: Rectangle {
                color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6
            }
            contentItem: ColumnLayout {
                spacing: 10
                Text {
                    text: qsTr("Diese Datei existiert bereits und wird beim Exportieren überschrieben:")
                    color: root.theme.textSecondary; font.pixelSize: 13
                    wrapMode: Text.Wrap; Layout.fillWidth: true
                }
                Text {
                    text: ueberschreibenDialog.pfad
                    color: root.theme.textMuted; font.pixelSize: 11
                    wrapMode: Text.Wrap; Layout.fillWidth: true
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Button {
                        text: qsTr("Abbrechen"); Layout.fillWidth: true; implicitHeight: 32
                        contentItem: Text {
                            text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                            radius: 4; border.color: root.theme.border }
                        onClicked: ueberschreibenDialog.close()
                    }
                    Button {
                        text: qsTr("Überschreiben"); Layout.fillWidth: true; implicitHeight: 32
                        contentItem: Text {
                            text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg
                            radius: 4; border.color: root.theme.accent }
                        onClicked: {
                            var p = ueberschreibenDialog.pfad
                            ueberschreibenDialog.close()
                            root.exportAngefordert(p)
                        }
                    }
                }
            }
        }
    }
}
