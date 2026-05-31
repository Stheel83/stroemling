import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"

Item {
    id: root
    required property var theme
    property bool debug: false

    signal zurueck()
    signal projektMetaGeaendert(int projektId)

    readonly property bool _gitOk: root._gitOk

    property bool _geaendert:    false
    property bool _ladevorgang:  false
    property string _exportStatus: ""
    property bool   _exportOk:     true

    function _kurzPfad(pfad) {
        return pfad.replace(/^\/home\/[^/]+/, "~")
    }
    function _dateiName(pfad) {
        return pfad.split("/").pop()
    }
    function _verzeichnis(pfad) {
        var parts = pfad.split("/")
        parts.pop()
        return _kurzPfad(parts.join("/"))
    }
    // GIT-00: Ordner-pro-Projekt – zeigt Ordnername statt Dateiname für neue Struktur
    function _projektAnzeigeNameFuerOrdner(pfad) {
        var parts = pfad.split("/")
        return (parts[parts.length - 1] === "projekt.strl")
               ? parts[parts.length - 2]
               : parts[parts.length - 1]
    }
    function _projektElternPfad(pfad) {
        var parts = pfad.split("/")
        if (parts[parts.length - 1] === "projekt.strl") parts.splice(parts.length - 2, 2)
        else parts.pop()
        return _kurzPfad(parts.join("/"))
    }
    function _istNeuesFormat(pfad) { return pfad.split("/").pop() === "projekt.strl" }
    function _slug(name) {
        return name.trim()
                   .replace(/[\/\\:*?"<>|]/g, "_")
                   .replace(/\s+/g, "-")
                   .replace(/-+/g, "-")
                   .replace(/^-+|-+$/g, "")
                   .substring(0, 64)
               || "Neues-Projekt"
    }

    function _ladenMetaDaten() {
        _ladevorgang = true
        var info = db.ersteProjektInfo()
        nameField.text   = info.name          || ""
        nummerField.text = info.projektnummer  || ""
        agField.text     = info.auftraggeber   || ""
        anField.text     = info.auftragnehmer  || ""
        bearField.text   = info.bearbeiter     || ""
        _ladevorgang = false
        _geaendert   = false
    }

    Component.onCompleted: { if (db.projektOffen) _ladenMetaDaten() }
    onVisibleChanged:       { if (visible && db.projektOffen) _ladenMetaDaten() }

    Connections {
        target: db
        function onProjektOffenChanged() {
            if (db.projektOffen) root._ladenMetaDaten()
            else root._geaendert = false
        }
    }

    // ── Neues Projekt (GIT-00: Ordner-pro-Projekt) ────────────────────────────
    FolderDialog {
        id: projektOrtDialog
        title: qsTr("Speicherort wählen")
        onAccepted: {
            var p = selectedFolder.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            neuProjektPopup._ort = p
        }
    }

    Popup {
        id: neuProjektPopup
        modal: true
        padding: 0
        anchors.centerIn: Overlay.overlay

        property string _name: ""
        property string _ort:  ""

        onOpened: {
            if (_ort === "") _ort = db.standardProjektOrdner()
            _name = ""
            nameInputField.text = ""
            nameInputField.forceActiveFocus()
        }

        background: Rectangle {
            color:        root.theme.surface
            border.color: root.theme.border
            radius:       8
        }

        contentItem: ColumnLayout {
            width: 400
            spacing: 0

            // Header
            Item {
                Layout.fillWidth: true
                height: 48
                Text {
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    text:           qsTr("Neues Projekt anlegen")
                    font.pixelSize: 14; font.weight: Font.Medium
                    color:          root.theme.textPrimary
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 1
                    color: root.theme.border
                }
            }

            // Felder
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins:   24
                spacing:          20

                // Projektname
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: qsTr("Projektname"); font.pixelSize: 11; color: root.theme.textMuted }
                    TextField {
                        id:               nameInputField
                        Layout.fillWidth: true
                        placeholderText:  qsTr("z. B. Schaltschrank Halle 3")
                        color:            root.theme.textPrimary; font.pixelSize: 13
                        background: Rectangle {
                            color:        root.theme.inputBg
                            border.color: nameInputField.activeFocus ? root.theme.accent : root.theme.border
                            radius:       4
                        }
                        onTextChanged: neuProjektPopup._name = text
                        Keys.onReturnPressed: { if (neuProjektPopup._name.trim()) anlegenBtn.clicked() }
                        Keys.onEscapePressed: neuProjektPopup.close()
                    }
                }

                // Speicherort
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text { text: qsTr("Speicherort"); font.pixelSize: 11; color: root.theme.textMuted }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text {
                            Layout.fillWidth: true
                            text:           neuProjektPopup._ort.replace(/^\/home\/[^/]+/, "~")
                            font.pixelSize: 11; font.family: "monospace"
                            color:          root.theme.textPrimary; elide: Text.ElideLeft
                        }
                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color:        ortBtnMa.containsMouse ? root.theme.hover : root.theme.inputBg
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "📂"; font.pixelSize: 13 }
                            MouseArea {
                                id:           ortBtnMa; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: projektOrtDialog.open()
                            }
                        }
                    }
                }

                // Pfad-Vorschau
                Rectangle {
                    Layout.fillWidth: true
                    visible:          neuProjektPopup._name.trim() !== ""
                    implicitHeight:   vorschauCol.implicitHeight + 16
                    color:            root.theme.surfaceDeep
                    radius:           4
                    border.color:     root.theme.borderLight

                    Column {
                        id: vorschauCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 2
                        Text {
                            width: parent.width
                            text: neuProjektPopup._ort.replace(/^\/home\/[^/]+/, "~")
                                  + "/" + root._slug(neuProjektPopup._name) + "/"
                            font.pixelSize: 10; font.family: "monospace"
                            color: root.theme.textMuted; wrapMode: Text.WrapAnywhere
                        }
                        Text {
                            text:           "  projekt.strl"
                            font.pixelSize: 10; font.family: "monospace"
                            color:          root.theme.accent
                        }
                    }
                }
            }

            // Footer-Buttons
            Item {
                Layout.fillWidth: true; height: 52
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width; height: 1; color: root.theme.border
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    Button {
                        text: qsTr("Abbrechen"); implicitHeight: 32; implicitWidth: 95
                        contentItem: Text {
                            text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered ? root.theme.hover : root.theme.inputBg
                            radius: 4; border.color: root.theme.border
                        }
                        onClicked: neuProjektPopup.close()
                    }
                    Button {
                        id: anlegenBtn
                        text: qsTr("Anlegen ›"); implicitHeight: 32; implicitWidth: 95
                        enabled: neuProjektPopup._name.trim() !== ""
                        contentItem: Text {
                            text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            opacity: parent.enabled ? 1.0 : 0.45
                        }
                        background: Rectangle {
                            color:        parent.hovered && parent.enabled ? root.theme.accent : root.theme.inputBg
                            radius:       4
                            border.color: parent.enabled ? root.theme.accent : root.theme.border
                        }
                        onClicked: {
                            var slug    = root._slug(neuProjektPopup._name)
                            var ordner  = neuProjektPopup._ort + "/" + slug
                            var pfad    = ordner + "/projekt.strl"
                            var name    = neuProjektPopup._name
                            neuProjektPopup.close()
                            if (db.createProjekt(pfad, name))
                                db.gitProjektInit(ordner)  // GIT-01: init + erster Commit
                            else
                                fehlerPopup.open()
                        }
                    }
                }
            }
        }
    }

    FolderDialog {
        id: projektOeffnenDialog
        title: qsTr("Projektordner wählen")
        onAccepted: {
            var p = selectedFolder.toString()
            if (p.startsWith("file://")) p = p.substring(7)
            if (!db.openProjekt(p + "/projekt.strl"))
                fehlerPopup.open()
        }
    }

    FileDialog {
        id: exportDialog
        title:         qsTr("Projektkopie speichern")
        fileMode:      FileDialog.SaveFile
        nameFilters:   ["Strömling Projekte (*.strl)"]
        defaultSuffix: "strl"
        onAccepted: {
            var ok = db.projektExportieren(selectedFile.toString())
            root._exportOk    = ok
            root._exportStatus = ok
                ? qsTr("Exportiert: ") + selectedFile.toString().split("/").pop()
                : qsTr("Export fehlgeschlagen")
            exportStatusTimer.restart()
        }
    }

    Timer {
        id: exportStatusTimer; interval: 4000
        onTriggered: root._exportStatus = ""
    }

    // ── Fehler-Popup ──────────────────────────────────────────────────
    Popup {
        id: fehlerPopup
        modal: true; anchors.centerIn: parent; padding: 20
        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }
        contentItem: Column {
            spacing: 12
            Text { text: qsTr("Projekt konnte nicht geöffnet werden."); color: root.theme.textPrimary; font.pixelSize: 13 }
            Text { text: qsTr("Datei beschädigt oder falsches Format."); color: root.theme.textMuted; font.pixelSize: 11 }
            Button {
                text: qsTr("OK"); onClicked: fehlerPopup.close()
                background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg; radius: 4; border.color: root.theme.accent }
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }

    // ── Haupthintergrund ──────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: root.theme.surfaceDeep }

    // ── Zweispaltiges Layout ──────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── LINKE SPALTE: Projektliste ────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: root.theme.sidebar

            Rectangle {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 1; color: root.theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Header
                Rectangle {
                    Layout.fillWidth: true; height: 52; color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 10 }
                        spacing: 6
                        Text {
                            text: qsTr("PROJEKTE")
                            font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 1
                            color: root.theme.textMuted
                        }
                        Item { Layout.fillWidth: true }
                        // Öffnen-Button
                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: oeffBtnHov.containsMouse ? root.theme.hover : "transparent"
                            Text { anchors.centerIn: parent; text: "📂"; font.pixelSize: 14 }
                            MouseArea {
                                id: oeffBtnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: projektOeffnenDialog.open()
                                ToolTip.visible: containsMouse; ToolTip.delay: 600; ToolTip.text: qsTr("Projektordner wählen…")
                            }
                        }
                        // Neu-Button
                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: neuBtnHov.containsMouse ? root.theme.accent : root.theme.inputBg
                            border.color: root.theme.accent
                            Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 18; font.weight: Font.Bold; color: root.theme.textPrimary }
                            MouseArea {
                                id: neuBtnHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: neuProjektPopup.open()
                                ToolTip.visible: containsMouse; ToolTip.delay: 600; ToolTip.text: qsTr("Neues Projekt")
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

                // Projektliste
                ListView {
                    id: projektListe
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: db.bekannteProjecte

                    Text {
                        visible: projektListe.count === 0
                        anchors.centerIn: parent
                        text: qsTr("Keine Projekte\nin der Registry")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 12; color: root.theme.textMuted
                    }

                    delegate: Item {
                        id: projektItem
                        width: projektListe.width
                        height: 62

                        readonly property bool istOffen: db.projektOffen && db.projektPfad === modelData.dateiPfad
                        readonly property bool fehlt:    !modelData.dateiExistiert

                        Rectangle {
                            anchors.fill: parent
                            color: projektItem.istOffen
                                   ? (root.theme.accent + "28")
                                   : (itemMa.containsMouse ? root.theme.hover : "transparent")
                        }

                        // Akzent-Streifen links für offenes Projekt
                        Rectangle {
                            visible: projektItem.istOffen
                            width: 3; height: parent.height * 0.55
                            radius: 2; x: 0; anchors.verticalCenter: parent.verticalCenter
                            color: root.theme.accent
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: projektItem.istOffen ? 14 : 12; rightMargin: 12 }
                            spacing: 10

                            Text {
                                font.pixelSize: 18
                                text: projektItem.fehlt ? "⚠" : "📄"
                                color: projektItem.fehlt ? "#cc8800" : root.theme.textMuted
                            }

                            Column {
                                Layout.fillWidth: true; spacing: 3
                                Text {
                                    width: parent.width
                                    text: modelData.projektName || qsTr("(Unbenannt)")
                                    font.pixelSize: 13
                                    font.weight: projektItem.istOffen ? Font.Medium : Font.Normal
                                    color: projektItem.fehlt ? "#cc8800" : root.theme.textPrimary
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.dateiPfad
                                    font.pixelSize: 10; font.family: "monospace"
                                    color: root.theme.textMuted; elide: Text.ElideMiddle; opacity: 0.75
                                }
                            }
                        }

                        Rectangle {
                            visible: index < projektListe.count - 1
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                            height: 1; color: root.theme.divider
                        }

                        MouseArea {
                            id: itemMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: projektItem.fehlt ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (projektItem.fehlt || projektItem.istOffen) return
                                db.openProjekt(modelData.dateiPfad)
                            }
                        }

                        // "In neuer Instanz öffnen" – nach itemMa, liegt darüber
                        Rectangle {
                            visible: itemMa.containsMouse && !projektItem.fehlt
                            width: 24; height: 24; radius: 4
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            color: niMa.containsMouse ? root.theme.accent : root.theme.inputBg
                            border.color: root.theme.accent
                            Text {
                                anchors.centerIn: parent; text: "↗"; font.pixelSize: 13
                                color: niMa.containsMouse ? "#ffffff" : root.theme.accent
                            }
                            MouseArea {
                                id: niMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    appHelper.neueInstanzMitProjekt(modelData.dateiPfad)
                                    mouse.accepted = true
                                }
                                ToolTip.visible: containsMouse
                                ToolTip.text: qsTr("In neuer Instanz öffnen")
                                ToolTip.delay: 400
                            }
                        }
                    }
                }

                // Info-Hinweis: Mehrere Projekte / Makros
                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10; Layout.rightMargin: 10
                    Layout.topMargin: 8;   Layout.bottomMargin: 8
                    text: qsTr("Jedes Projekt läuft in einer eigenen Programminstanz (↗). "
                             + "Das Kopieren zwischen Projekten ist bewusst nicht vorgesehen — "
                             + "für wiederverwendbare Schaltungsteile bitte die Makro-Funktion nutzen.")
                    font.pixelSize: 9; color: root.theme.textMuted; wrapMode: Text.WordWrap
                }
            }
        }

        // ── RECHTE SPALTE: Metadaten-Panel ───────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.theme.surface

            // Platzhalter wenn kein Projekt offen
            Column {
                visible: !db.projektOffen
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📁"; font.pixelSize: 52; opacity: 0.2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Projekt auswählen oder neu anlegen")
                    font.pixelSize: 14; color: root.theme.textMuted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Klicke in der Liste auf ein Projekt\num es zu öffnen und zu bearbeiten.")
                    font.pixelSize: 11; color: root.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; opacity: 0.6
                }
            }

            // Metadaten-Formular wenn Projekt offen
            ColumnLayout {
                visible: db.projektOffen
                anchors { fill: parent; topMargin: 28; bottomMargin: 20; leftMargin: 40; rightMargin: 40 }
                spacing: 0

                Text {
                    text: qsTr("Projektdetails")
                    font.pixelSize: 20; font.weight: Font.Light
                    color: root.theme.textPrimary
                    Layout.bottomMargin: 20
                }

                // ── Stammdaten ────────────────────────────────────────────────
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2; rowSpacing: 12; columnSpacing: 20

                    Text { text: qsTr("Name"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: nameField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: nameField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }

                    Text { text: qsTr("Projektnummer"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: nummerField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: nummerField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }

                    Text { text: qsTr("Auftraggeber"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: agField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: agField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }

                    Text { text: qsTr("Auftragnehmer"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: anField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: anField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }

                    Text { text: qsTr("Bearbeiter"); font.pixelSize: 12; color: root.theme.textMuted }
                    TextField {
                        id: bearField; Layout.fillWidth: true; font.pixelSize: 13
                        color: root.theme.textPrimary
                        background: Rectangle { color: root.theme.inputBg; border.color: bearField.activeFocus ? root.theme.accent : root.theme.border; radius: 4 }
                        onTextChanged: if (!root._ladevorgang) root._geaendert = true
                    }
                }

                // ── Trennlinie ────────────────────────────────────────────────
                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 20; Layout.bottomMargin: 16 }

                // ── Datenpfade ────────────────────────────────────────────────
                Text { text: qsTr("DATENPFADE"); font.pixelSize: 10; font.letterSpacing: 1; color: root.theme.textMuted; Layout.bottomMargin: 12 }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3; rowSpacing: 10; columnSpacing: 12

                    // Projektordner/-datei (GIT-00: zeigt Ordner für neues Format)
                    Text {
                        text: root._istNeuesFormat(db.projektPfad)
                              ? qsTr("Projektordner") : qsTr("Projektdatei")
                        font.pixelSize: 11; color: root.theme.textMuted
                    }
                    Column {
                        Layout.fillWidth: true; spacing: 2
                        Text {
                            width: parent.width
                            text: root._projektAnzeigeNameFuerOrdner(db.projektPfad)
                            font.pixelSize: 12; color: root.theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root._projektElternPfad(db.projektPfad)
                            font.pixelSize: 10; font.family: "monospace"
                            color: root.theme.textMuted; elide: Text.ElideLeft; opacity: 0.7
                        }
                    }
                    Rectangle {
                        width: 24; height: 24; radius: 4
                        color: pfad1Ma.containsMouse ? root.theme.hover : "transparent"
                        Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 13 }
                        MouseArea {
                            id: pfad1Ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("file://" + db.projektPfad.substring(0, db.projektPfad.lastIndexOf("/")))
                            ToolTip.visible: containsMouse; ToolTip.delay: 600
                            ToolTip.text: qsTr("Verzeichnis öffnen")
                        }
                    }

                    // Makrobibliothek
                    Text { text: qsTr("Makrobibliothek"); font.pixelSize: 11; color: root.theme.textMuted }
                    Column {
                        Layout.fillWidth: true; spacing: 2
                        Text {
                            width: parent.width
                            text: root._dateiName(db.makroPfad)
                            font.pixelSize: 12; color: root.theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root._verzeichnis(db.makroPfad)
                            font.pixelSize: 10; font.family: "monospace"
                            color: root.theme.textMuted; elide: Text.ElideLeft; opacity: 0.7
                        }
                    }
                    Rectangle {
                        width: 24; height: 24; radius: 4
                        color: pfad2Ma.containsMouse ? root.theme.hover : "transparent"
                        Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 13 }
                        MouseArea {
                            id: pfad2Ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("file://" + db.makroPfad.substring(0, db.makroPfad.lastIndexOf("/")))
                            ToolTip.visible: containsMouse; ToolTip.delay: 600
                            ToolTip.text: qsTr("Verzeichnis öffnen")
                        }
                    }

                    // Wiki
                    Text { text: qsTr("Wiki"); font.pixelSize: 11; color: root.theme.textMuted }
                    Column {
                        Layout.fillWidth: true; spacing: 2
                        Text {
                            width: parent.width
                            text: root._dateiName(db.wikiPfad)
                            font.pixelSize: 12; color: root.theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root._verzeichnis(db.wikiPfad)
                            font.pixelSize: 10; font.family: "monospace"
                            color: root.theme.textMuted; elide: Text.ElideLeft; opacity: 0.7
                        }
                    }
                    Rectangle {
                        width: 24; height: 24; radius: 4
                        color: pfad3Ma.containsMouse ? root.theme.hover : "transparent"
                        Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 13 }
                        MouseArea {
                            id: pfad3Ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("file://" + db.wikiPfad.substring(0, db.wikiPfad.lastIndexOf("/")))
                            ToolTip.visible: containsMouse; ToolTip.delay: 600
                            ToolTip.text: qsTr("Verzeichnis öffnen")
                        }
                    }
                }

                // ── GIT-02: Remote / Cloud ────────────────────────────────────
                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 20; Layout.bottomMargin: 16 }
                Text { text: qsTr("VERSIONSVERWALTUNG"); font.pixelSize: 10; font.letterSpacing: 1; color: root.theme.textMuted; Layout.bottomMargin: 10 }

                RowLayout {
                    Layout.fillWidth: true; spacing: 8

                    property bool _gitRepo: db.projektOffen && db.projektOrdner !== ""
                                            && root._gitOk

                    Text {
                        text: qsTr("Remote-URL")
                        font.pixelSize: 11; color: root.theme.textMuted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextField {
                        id: remoteUrlField
                        Layout.fillWidth: true
                        placeholderText: parent._gitRepo
                            ? qsTr("git@codeberg.org:nutzer/projekt.git")
                            : qsTr("(kein Git-Repo)")
                        enabled: parent._gitRepo
                        font.pixelSize: 11; font.family: "monospace"
                        color: root.theme.textPrimary
                        background: Rectangle {
                            color:        root.theme.inputBg
                            border.color: remoteUrlField.activeFocus ? root.theme.accent : root.theme.border
                            radius: 4
                        }
                        Component.onCompleted: {
                            if (db.projektOffen) text = db.gitRemoteUrl(db.projektOrdner)
                        }
                        Connections {
                            target: db
                            function onProjektOffenChanged() {
                                remoteUrlField.text = db.projektOffen
                                    ? db.gitRemoteUrl(db.projektOrdner) : ""
                            }
                        }
                        Keys.onReturnPressed: remoteUebernehmenBtn.clicked()
                    }

                    Rectangle {
                        id: remoteUebernehmenBtn
                        width: 80; height: 28; radius: 4
                        enabled: parent._gitRepo && remoteUrlField.text.trim() !== ""
                        color:        remoteUeberMa.containsMouse && enabled ? root.theme.accent : root.theme.inputBg
                        border.color: enabled ? root.theme.accent : root.theme.border

                        function clicked() {
                            if (!enabled) return
                            db.gitRemoteSetzen(db.projektOrdner, remoteUrlField.text.trim())
                        }

                        Text {
                            anchors.centerIn: parent
                            text:           qsTr("Übernehmen")
                            font.pixelSize: 11
                            color:          parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        }
                        MouseArea {
                            id:           remoteUeberMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked:    parent.clicked()
                        }
                        ToolTip.visible: remoteUeberMa.containsMouse; ToolTip.delay: 500
                        ToolTip.text:    qsTr("Remote setzen + initialen Push starten.\n"
                                            + "Zugangsdaten (SSH-Key / HTTPS-Credential) bitte einmalig im System einrichten.")
                    }
                }

                Text {
                    Layout.fillWidth: true; Layout.topMargin: 4
                    text: qsTr("Push nach jeder Version automatisch – Fehler werden still geloggt, lokales Speichern bleibt primär.")
                    font.pixelSize: 10; color: root.theme.textMuted; wrapMode: Text.WordWrap
                }

                // ── Trennlinie ────────────────────────────────────────────────
                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 16; Layout.bottomMargin: 16 }

                // ── Aktionen ──────────────────────────────────────────────────
                Text { text: qsTr("AKTIONEN"); font.pixelSize: 10; font.letterSpacing: 1; color: root.theme.textMuted; Layout.bottomMargin: 12 }

                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    // Kopie exportieren
                    Rectangle {
                        implicitWidth: 190; height: 34; radius: 4
                        color: exportHov.containsMouse ? root.theme.inputBg : "transparent"
                        border.color: root.theme.border
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 6
                            Text { text: "⬆"; font.pixelSize: 13; color: root.theme.textMuted }
                            Text { text: qsTr("Kopie exportieren (.strl)"); font.pixelSize: 11; color: root.theme.textMuted }
                        }
                        MouseArea {
                            id: exportHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: exportDialog.open()
                            ToolTip.visible: containsMouse; ToolTip.delay: 700
                            ToolTip.text: qsTr("Kompakte Kopie der Projektdatei erstellen (alle Daten, kein Undo-Verlauf)")
                        }
                    }

                    // Aus Liste entfernen
                    Rectangle {
                        implicitWidth: 170; height: 34; radius: 4
                        color: entfHov.containsMouse ? root.theme.hover : "transparent"
                        border.color: root.theme.border
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 6
                            Text { text: "×"; font.pixelSize: 16; color: "#cc6600" }
                            Text { text: qsTr("Aus Liste entfernen"); font.pixelSize: 11; color: root.theme.textMuted }
                        }
                        MouseArea {
                            id: entfHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { db.projektAusRegistryEntfernen(db.projektPfad); db.closeProjekt() }
                            ToolTip.visible: containsMouse; ToolTip.delay: 800
                            ToolTip.text: qsTr("Aus Projektliste entfernen — Datei bleibt auf der Festplatte erhalten")
                        }
                    }


// Export-Status
                    Text {
                        visible: root._exportStatus !== ""
                        text: root._exportStatus
                        font.pixelSize: 11
                        color: root._exportOk ? root.theme.accent : "#cc4444"
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }

                // ── Versionshistorie (GIT-01) ─────────────────────────────────
                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 20; Layout.bottomMargin: 16 }

                RowLayout {
                    Layout.fillWidth: true; Layout.bottomMargin: 10
                    Text { text: qsTr("VERSIONSHISTORIE"); font.pixelSize: 10; font.letterSpacing: 1; color: root.theme.textMuted; Layout.fillWidth: true }
                    Rectangle {
                        width: 22; height: 22; radius: 4
                        color: reloadHov.containsMouse ? root.theme.hover : "transparent"
                        Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 14; color: root.theme.textMuted }
                        MouseArea {
                            id: reloadHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: verlaufListe.model = db.gitLog(db.projektOrdner)
                            ToolTip.visible: containsMouse; ToolTip.text: qsTr("Aktualisieren"); ToolTip.delay: 500
                        }
                    }
                }

                // Hinweis wenn Git fehlt oder kein Repo
                Rectangle {
                    Layout.fillWidth: true
                    visible:          verlaufListe.count === 0 && db.projektOffen
                    implicitHeight:   gitHinweisCol.implicitHeight + 16
                    color:            root.theme.surfaceDeep
                    radius:           4
                    border.color:     root.theme.borderLight

                    Column {
                        id: gitHinweisCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 6

                        Text {
                            width: parent.width
                            text: !root._gitOk
                                ? qsTr("Git ist nicht installiert – keine automatische Versionierung.")
                                : qsTr("Noch keine Versionshistorie – erste Version mit \"Version anlegen\" (Ctrl+S) erstellen.")
                            font.pixelSize: 11; font.weight: Font.Medium
                            color: root.theme.textPrimary; wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            visible: !root._gitOk
                            text: qsTr("Der Schaltplan wird weiterhin automatisch gespeichert. "
                                     + "Ohne Git gibt es jedoch keinen Versionsverlauf und keine "
                                     + "Möglichkeit, zu einem früheren Stand zurückzukehren.\n\n"
                                     + "Alternativen: Git installieren (empfohlen) · "
                                     + "Manuelle Kopien per \"Kopie exportieren\" · "
                                     + "Vollsicherung unter Einstellungen → Datensicherung.\n\n"
                                     + "Details und Installationsanleitung: Wiki → \"Versionierung mit Git\"")
                            font.pixelSize: 11; color: root.theme.textMuted; wrapMode: Text.WordWrap
                        }
                    }
                }

                // Commit-Liste (max. 200px, scrollbar wenn nötig)
                ListView {
                    id: verlaufListe
                    Layout.fillWidth: true
                    implicitHeight: Math.min(contentHeight, 220)
                    clip: true
                    visible: count > 0
                    model: []

                    // Laden wenn Projekt geöffnet / Ansicht sichtbar
                    Connections {
                        target: db
                        function onProjektOffenChanged() {
                            if (db.projektOffen)
                                verlaufListe.model = db.gitLog(db.projektOrdner)
                            else
                                verlaufListe.model = []
                        }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Item {
                        id: verlaufItem
                        width: verlaufListe.width
                        height: 44

                        property bool hov: verlaufMa.containsMouse
                        property bool istErster: index === 0

                        Rectangle {
                            anchors.fill: parent
                            color: verlaufItem.hov ? root.theme.hover : "transparent"
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 4; rightMargin: 8 }
                            spacing: 8

                            // Aktuell-Indikator
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: verlaufItem.istErster ? root.theme.accent : root.theme.border
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Column {
                                Layout.fillWidth: true; spacing: 2
                                Text {
                                    width: parent.width
                                    text: modelData.nachricht || "(kein Kommentar)"
                                    font.pixelSize: 12; font.weight: verlaufItem.istErster ? Font.Medium : Font.Normal
                                    color: root.theme.textPrimary; elide: Text.ElideRight
                                }
                                Text {
                                    text: {
                                        var d = new Date(modelData.datum)
                                        return isNaN(d.getTime())
                                            ? modelData.datum
                                            : Qt.formatDateTime(d, "dd.MM.yyyy HH:mm")
                                              + "  #" + modelData.hash
                                    }
                                    font.pixelSize: 10; font.family: "monospace"
                                    color: root.theme.textMuted
                                }
                            }

                            // Wiederherstellen-Button (sichtbar bei Hover, nicht beim aktuellen)
                            Rectangle {
                                visible:       verlaufItem.hov && !verlaufItem.istErster
                                width: 100; height: 26; radius: 4
                                color:        wiederHov.containsMouse ? root.theme.accent : root.theme.inputBg
                                border.color: root.theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Wiederherstellen")
                                    font.pixelSize: 10; color: root.theme.textPrimary
                                }
                                MouseArea {
                                    id:           wiederHov; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (db.gitCheckout(db.projektOrdner, modelData.hashFull))
                                            verlaufListe.model = db.gitLog(db.projektOrdner)
                                        else
                                            fehlerPopup.open()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: index < verlaufListe.count - 1
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 18 }
                            height: 1; color: root.theme.divider
                        }

                        MouseArea { id: verlaufMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                }

                Item { Layout.fillHeight: true }

                // ── Footer: Speichern + Zum Schaltplan ───────────────────────
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: 110; height: 34; radius: 4
                        color: root._geaendert && speichernHov.containsMouse
                               ? root.theme.accent : root.theme.inputBg
                        border.color: root._geaendert ? root.theme.accent : root.theme.border
                        Text {
                            anchors.centerIn: parent; text: qsTr("Speichern"); font.pixelSize: 12
                            color: root._geaendert ? root.theme.textPrimary : root.theme.textMuted
                        }
                        MouseArea {
                            id: speichernHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root._geaendert) return
                                var info = db.ersteProjektInfo()
                                if (db.projektMetaDatenSpeichern(nameField.text, nummerField.text,
                                                                  agField.text, anField.text, bearField.text)) {
                                    root._geaendert = false
                                    root.projektMetaGeaendert(info.id || 0)
                                }
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 150; height: 34; radius: 4
                        color: schaltplanHov.containsMouse ? root.theme.accent : root.theme.inputBg
                        border.color: root.theme.accent
                        Text { anchors.centerIn: parent; text: qsTr("Zum Schaltplan ›"); font.pixelSize: 12; color: root.theme.textPrimary }
                        MouseArea {
                            id: schaltplanHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.zurueck()
                        }
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Projekt-Start-Ansicht"); visible: root.debug }
}
