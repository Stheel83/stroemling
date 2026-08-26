import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtCore
import "components"

Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  500
    padding: 20

    required property var theme
    required property int projektId
    required property int seiteId
    property bool         debug: false

    title: qsTr("PDF-Export")

    background: Rectangle {
        color:        root.theme.sidebar
        border.color: root.theme.border
        border.width: 1; radius: 6
    }

    // Eigener Pfad-Picker – kein nativer FileDialog (funktioniert in AppImage)
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
                : _stripUrl(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)) + "/export.pdf"
        }

        // StandardPaths gibt in Qt6/QML URLs zurück (file:///…) – immer strippen
        function _stripUrl(s) {
            if (s.startsWith("file:///")) return s.substring(7)
            if (s.startsWith("file://"))  return s.substring(7)
            return s
        }
        function _dateiname(pfad) {
            var parts = _stripUrl(pfad).split("/")
            var n = parts[parts.length - 1]
            return (n.length > 0 && n.includes(".")) ? n : "export.pdf"
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
                            if (!name || !name.includes(".")) name = "export.pdf"
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
                placeholderText: qsTr("/home/user/projekt.pdf")
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
                        speicherDialog.selectedFile = "file://" + p
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

    contentItem: Item {
        implicitWidth:  innerLayout.implicitWidth
        implicitHeight: innerLayout.implicitHeight

        ColumnLayout {
            id: innerLayout
            anchors.fill: parent
            spacing: 12

            // Seiten-Auswahl
            Text {
                text:           qsTr("Seiten")
                color:          root.theme.textMuted
                font.pixelSize: 11
            }

            ColumnLayout {
                spacing: 6

                RadioButton {
                    id: rbAlle
                    checked: true
                    indicator: _radioInd.createObject(rbAlle, {ctrl: rbAlle})
                    contentItem: Text {
                        text:           qsTr("Alle Seiten")
                        color:          root.theme.textPrimary
                        font.pixelSize: 12
                        leftPadding:    22
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                RadioButton {
                    id: rbAktuell
                    enabled: root.seiteId > 0
                    indicator: _radioInd.createObject(rbAktuell, {ctrl: rbAktuell})
                    contentItem: Text {
                        text:           qsTr("Aktuelle Seite")
                        color:          rbAktuell.enabled ? root.theme.textPrimary : root.theme.textMuted
                        font.pixelSize: 12
                        leftPadding:    22
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                RadioButton {
                    id: rbVoll
                    enabled: root.seiteId > 0
                    onCheckedChanged: if (checked) cbNormblatt.checked = false
                    indicator: _radioInd.createObject(rbVoll, {ctrl: rbVoll})
                    contentItem: Text {
                        text:           qsTr("Ganzes Canvas (aktuelle Seite)")
                        color:          rbVoll.enabled ? root.theme.textPrimary : root.theme.textMuted
                        font.pixelSize: 12
                        leftPadding:    22
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                RadioButton {
                    id: rbAlleVoll
                    onCheckedChanged: if (checked) cbNormblatt.checked = false
                    indicator: _radioInd.createObject(rbAlleVoll, {ctrl: rbAlleVoll})
                    contentItem: Text {
                        text:           qsTr("Alle Seiten (ganzes Canvas, ohne Normblatt)")
                        color:          root.theme.textPrimary
                        font.pixelSize: 12
                        leftPadding:    22
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Normblatt-Option (im Ganzes-Canvas-Modus nicht sinnvoll)
            CheckBox {
                id: cbNormblatt
                checked: true
                enabled: !rbVoll.checked && !rbAlleVoll.checked
                Layout.fillWidth: true
                indicator: _checkInd.createObject(cbNormblatt, {ctrl: cbNormblatt})
                contentItem: Text {
                    text:           qsTr("Normblatt einschließen")
                    color:          cbNormblatt.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    leftPadding:    22
                    verticalAlignment: Text.AlignVCenter
                }
            }

            CheckBox {
                id: cbInfostreifen
                checked: false
                Layout.fillWidth: true
                indicator: _checkInd.createObject(cbInfostreifen, {ctrl: cbInfostreifen})
                contentItem: Text {
                    text:           qsTr("Infostreifen für Seiten ohne Schriftfeld")
                    color:          root.theme.textPrimary
                    font.pixelSize: 12
                    leftPadding:    22
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Indicator-Templates (style-unabhängig)
            Component {
                id: _radioInd
                Item {
                    property var ctrl
                    implicitWidth: 14; implicitHeight: 14
                    x: ctrl.leftPadding; y: (ctrl.height - height) / 2
                    Rectangle {
                        anchors.fill: parent; radius: 7
                        color: "transparent"
                        border.color: ctrl.checked ? root.theme.accent : root.theme.border
                        border.width: 1.5
                    }
                    Rectangle {
                        width: 7; height: 7; radius: 4
                        anchors.centerIn: parent
                        color: root.theme.accent
                        visible: ctrl.checked
                    }
                }
            }
            Component {
                id: _checkInd
                Item {
                    property var ctrl
                    implicitWidth: 14; implicitHeight: 14
                    x: ctrl.leftPadding; y: (ctrl.height - height) / 2
                    Rectangle {
                        anchors.fill: parent; radius: 3
                        color: ctrl.checked ? root.theme.accent : "transparent"
                        border.color: ctrl.checked ? root.theme.accent : root.theme.border
                        border.width: 1.5
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✓"; font.pixelSize: 10; font.bold: true
                        color: root.theme.sidebar
                        visible: ctrl.checked
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // Dateipfad
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

            // Status-/Fehlermeldung
            Text {
                id: statusText
                Layout.fillWidth: true
                text:           ""
                color:          root.theme.accent
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
                    id:             btnExport
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
                            root._pdfSchreiben(pfad)
                        }
                    }
                }
            }
        }

        // Eigentlicher Export-Aufruf, ausgelagert damit die Überschreiben-
        // Bestätigung dazwischengeschaltet werden kann.
        function _pdfSchreiben(pfad) {
            var nb   = cbNormblatt.checked
            var info = cbInfostreifen.checked
            var ok = false
            if (rbAlleVoll.checked)
                ok = db.canvasPdfExportieren(root.projektId, pfad, false, true, info)
            else if (rbVoll.checked)
                ok = db.canvasSeiteExportieren(root.seiteId, pfad, false, true, info)
            else if (rbAlle.checked)
                ok = db.canvasPdfExportieren(root.projektId, pfad, nb, false, info)
            else
                ok = db.canvasSeiteExportieren(root.seiteId, pfad, nb, false, info)

            if (ok) {
                var seiten = (rbAlle.checked || rbAlleVoll.checked)
                    ? seitenModel.rowCount() : 1
                achievementManager.ereignis("pdf_exportiert", { "seitenAnzahl": seiten })
                meldungManager.zeigen(qsTr("PDF gespeichert."), true)
                root.accept()
            } else {
                statusText.text = qsTr("Export fehlgeschlagen. Pfad prüfen.")
            }
        }

        // ── Überschreiben-Bestätigung ──────────────────────────────────
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
                            root._pdfSchreiben(p)
                        }
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("PDF-Export-Dialog"); visible: root.debug && root.visible }
}
