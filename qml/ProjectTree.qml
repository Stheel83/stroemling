import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "components"

// Projektliste – zeigt alle Projekte aus der DB
// und erlaubt Anlegen / Löschen

Item {
    id: root

    property var  theme
    property bool debug: false

    property string _exportStatus: ""
    property bool   _exportStatusOk: true

    property int    _loeschenProjektId:   -1
    property string _loeschenProjektName: ""

    function _zeigeExportStatus(text, ok) {
        _exportStatus   = text
        _exportStatusOk = (ok !== false)
        exportStatusTimer.restart()
    }

    // Wird nach oben gemeldet wenn ein Projekt ausgewählt wird
    signal projektGewaehlt(int id, string name)

    // Wird nach oben gemeldet wenn Projekt-Metadaten gespeichert wurden
    signal projektMetaGeaendert(int id)

    // Wird nach oben gemeldet wenn ein Projekt gelöscht wurde
    signal projektGeloescht(int id)

    ColumnLayout {
        anchors.fill:   parent
        anchors.margins: 12
        spacing: 8

        // Überschrift + Neu-Button
        RowLayout {
            Layout.fillWidth: true

            Text {
                text:           qsTr("Projekte")
                font.pixelSize: 14
                font.weight:    Font.Medium
                color:          theme.textBright
                Layout.fillWidth: true
            }

            // Projekt importieren (bestehende .stroemling-Datei öffnen)
            RoundButton {
                text:   "📂"
                width:  28
                height: 28
                font.pixelSize: 14
                palette.button:     theme.border
                palette.buttonText: theme.textPrimary

                ToolTip.visible: hovered
                ToolTip.text:    qsTr("Projekt importieren (.stroemling öffnen)")

                onClicked: projektImportDialog.open()
            }

            // Neues Projekt anlegen
            RoundButton {
                text:   "+"
                width:  28
                height: 28
                font.pixelSize: 18
                palette.button:     theme.border
                palette.buttonText: theme.accent

                ToolTip.visible: hovered
                ToolTip.text:    qsTr("Neues Projekt anlegen")

                onClicked: neuesProjektDialog.open()
            }
        }

        // Trennlinie
        Rectangle { height: 1; color: theme.border; Layout.fillWidth: true }

        // Projektliste
        ListView {
            id:               projektListe
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip:             true
            model:            projektModel  // aus main.cpp als Kontext-Property

            // Kein Projekt vorhanden
            Text {
                anchors.centerIn: parent
                visible:    projektListe.count === 0
                text:       qsTr("Noch keine Projekte.\nKlicke + um eines anzulegen.")
                color:      theme.borderLight
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }

            delegate: Item {
                id: delegateRoot
                width:  ListView.view.width
                height: 52

                HoverHandler { id: itemHover }

                Rectangle {
                    anchors.fill:   parent
                    anchors.margins: 2
                    color:  ListView.isCurrentItem ? theme.activeItem : (itemHover.hovered ? theme.divider : "transparent")
                    radius: 6

                    Behavior on color { ColorAnimation { duration: 100 } }

                    TapHandler {
                        onTapped: {
                            projektListe.currentIndex = index
                            root.projektGewaehlt(model.projektId, model.name)
                        }
                    }

                    ColumnLayout {
                        anchors {
                            left:           parent.left
                            leftMargin:     10
                            right:          deleteBtn.left
                            rightMargin:    4
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2

                        Text {
                            text:           model.name
                            font.pixelSize: 13
                            font.weight:    Font.Medium
                            color:          theme.textPrimary
                            elide:          Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text:           model.projektnummer || model.erstelltAm.substring(0, 10)
                            font.pixelSize: 11
                            color:          theme.panelMid
                        }
                    }

                    // Export-Button (nur beim Hover sichtbar)
                    RoundButton {
                        id:      exportBtn
                        text:    "⬆"
                        width:   24
                        height:  24
                        visible: itemHover.hovered
                        font.pixelSize: 11
                        palette.button:     "transparent"
                        palette.buttonText: theme.textMuted
                        anchors {
                            right:          editBtn.left
                            rightMargin:    2
                            verticalCenter: parent.verticalCenter
                        }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text:    qsTr("Kopie exportieren (.stroemling)")
                        onClicked: projektExportDialog.open()
                    }

                    // Bearbeiten-Button (nur beim Hover sichtbar)
                    RoundButton {
                        id:      editBtn
                        text:    "✎"
                        width:   24
                        height:  24
                        visible: itemHover.hovered
                        font.pixelSize: 13
                        palette.button:     "transparent"
                        palette.buttonText: theme.accent
                        anchors {
                            right:          deleteBtn.left
                            rightMargin:    2
                            verticalCenter: parent.verticalCenter
                        }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text:    qsTr("Projekt bearbeiten")
                        onClicked: {
                            dlgProjektEigenschaften.projektId      = model.projektId
                            dlgProjektEigenschaften.altName        = model.name
                            dlgProjektEigenschaften.altNummer      = model.projektnummer || ""
                            dlgProjektEigenschaften.altAuftragg    = model.auftraggeber  || ""
                            dlgProjektEigenschaften.altAuftragnehm = model.auftragnehmer || ""
                            dlgProjektEigenschaften.altBearbeiter  = model.bearbeiter    || ""
                            dlgProjektEigenschaften.open()
                        }
                    }

                    // Löschen-Button (nur beim Hover sichtbar)
                    RoundButton {
                        id:      deleteBtn
                        text:    "×"
                        width:   24
                        height:  24
                        visible: itemHover.hovered
                        font.pixelSize: 14
                        palette.button:     "transparent"
                        palette.buttonText: "#cc4444"
                        anchors {
                            right:          parent.right
                            rightMargin:    6
                            verticalCenter: parent.verticalCenter
                        }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text:    qsTr("Projekt löschen")
                        onClicked: {
                            root._loeschenProjektId   = model.projektId
                            root._loeschenProjektName = model.name
                            dlgLoeschen.open()
                        }
                    }
                }
            }
        }
    }

    // Dialog: Neues Projekt
    Dialog {
        id:     neuesProjektDialog
        title:  qsTr("Neues Projekt anlegen")
        width:  320
        anchors.centerIn: parent

        standardButtons: Dialog.Ok | Dialog.Cancel

        ColumnLayout {
            width: parent.width
            spacing: 10

            Label { text: qsTr("Projektname *"); color: theme.textBright }
            TextField {
                id:               nameField
                placeholderText:  qsTr("z.B. Hausinstallation EFH")
                Layout.fillWidth: true
                background: Rectangle { color: theme.sidebar; radius: 4; border.color: theme.border }
                color: theme.textPrimary
            }

            Label { text: qsTr("Projektnummer"); color: theme.textBright }
            TextField {
                id:               nummerField
                placeholderText:  qsTr("z.B. 2024-001")
                Layout.fillWidth: true
                background: Rectangle { color: theme.sidebar; radius: 4; border.color: theme.border }
                color: theme.textPrimary
            }
        }

        onAccepted: {
            if (nameField.text.trim() !== "") {
                projektModel.anlegen(
                    nameField.text.trim(),
                    nummerField.text.trim()
                )
                nameField.text   = ""
                nummerField.text = ""
            }
        }
    }

    // Dialog: Projekt-Eigenschaften bearbeiten
    Dialog {
        id: dlgProjektEigenschaften
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 380
        padding: 20

        property int    projektId:      -1
        property string altName:        ""
        property string altNummer:      ""
        property string altAuftragg:    ""
        property string altAuftragnehm: ""
        property string altBearbeiter:  ""

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        onOpened: {
            epName.text        = dlgProjektEigenschaften.altName
            epNummer.text      = dlgProjektEigenschaften.altNummer
            epAuftragg.text    = dlgProjektEigenschaften.altAuftragg
            epAuftragnehm.text = dlgProjektEigenschaften.altAuftragnehm
            epBearbeiter.text  = dlgProjektEigenschaften.altBearbeiter
        }

        contentItem: ColumnLayout {
            spacing: 8

            Text {
                text: qsTr("Projekt-Eigenschaften")
                font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            Text { text: qsTr("Projektname *"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: epName; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Projektnummer"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: epNummer; Layout.fillWidth: true; placeholderText: qsTr("z.B. 2024-001")
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Auftraggeber"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: epAuftragg; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Auftragnehmer"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: epAuftragnehm; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Text { text: qsTr("Bearbeiter"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: epBearbeiter; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }

            Text { text: qsTr("Logo (ersetzt Auftragnehmer im Schriftfeld)"); color: theme.textMuted; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Button {
                    text: qsTr("Logo wählen …"); implicitHeight: 30; flat: true
                    contentItem: Text { text: parent.text; color: theme.accent; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg;
                                            border.color: theme.border; radius: 4 }
                    onClicked: logoFileDialog.open()
                }
                Button {
                    text: qsTr("Entfernen"); implicitHeight: 30; flat: true
                    contentItem: Text { text: parent.text; color: "#aa4444"; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? "#3a1010" : theme.inputBg;
                                            border.color: theme.border; radius: 4 }
                    onClicked: {
                        db.projektLogoLoeschen(dlgProjektEigenschaften.projektId)
                        root.projektMetaGeaendert(dlgProjektEigenschaften.projektId)
                    }
                }
            }

            FileDialog {
                id: logoFileDialog
                title: qsTr("Logo-Datei auswählen")
                nameFilters: ["Bilder (*.png *.jpg *.jpeg *.bmp *.gif *.webp)"]
                onAccepted: {
                    var ok = db.projektLogoSpeichern(dlgProjektEigenschaften.projektId,
                                                     selectedFile.toString())
                    if (ok) root.projektMetaGeaendert(dlgProjektEigenschaften.projektId)
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgProjektEigenschaften.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: epName.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: parent.enabled ? theme.textPrimary : theme.textMuted; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        db.projektMetaSpeichern(
                            dlgProjektEigenschaften.projektId,
                            epName.text.trim(),
                            epNummer.text.trim(),
                            epAuftragg.text.trim(),
                            epAuftragnehm.text.trim(),
                            epBearbeiter.text.trim()
                        )
                        projektModel.laden()
                        root.projektMetaGeaendert(dlgProjektEigenschaften.projektId)
                        dlgProjektEigenschaften.close()
                    }
                }
            }
        }
    }

    // ── Bestätigungs-Dialog: Projekt löschen ─────────────────────
    Dialog {
        id:               dlgLoeschen
        modal:            true
        parent:           Overlay.overlay
        anchors.centerIn: parent
        width:            340
        padding:          20

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 8 }

        contentItem: ColumnLayout {
            spacing: 12

            Text {
                text: qsTr("Projekt löschen?")
                font.pixelSize: 14; font.weight: Font.Medium
                color: theme.textPrimary
            }

            Text {
                Layout.fillWidth: true
                text: root._loeschenProjektName
                font.pixelSize: 13; color: theme.accent
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Alle Seiten, Elemente und Leitungen dieses Projekts werden unwiederbringlich gelöscht.")
                font.pixelSize: 11; color: "#ff8888"
                wrapMode: Text.WordWrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Abbrechen"); implicitHeight: 30; implicitWidth: 100
                    onClicked: dlgLoeschen.close()
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 11;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: qsTr("Löschen"); implicitHeight: 30; implicitWidth: 100
                    onClicked: {
                        var pid = root._loeschenProjektId
                        projektModel.loeschen(pid)
                        root._loeschenProjektId   = -1
                        root._loeschenProjektName = ""
                        dlgLoeschen.close()
                        root.projektGeloescht(pid)
                    }
                    background: Rectangle { color: parent.hovered ? "#cc2222" : theme.inputBg; radius: 4; border.color: "#ff4444" }
                    contentItem: Text { text: parent.text; color: parent.hovered ? "white" : "#ff4444"; font.pixelSize: 11;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }

    // ── Projekt-Import FileDialog ─────────────────────────────
    FileDialog {
        id:           projektImportDialog
        title:        qsTr("Projekt importieren")
        fileMode:     FileDialog.OpenFile
        nameFilters:  ["Strömling Projekte (*.stroemling)", qsTr("Alle Dateien (*)")]
        onAccepted: {
            var pfad = selectedFile.toString().replace(/^file:\/\//, "")
            if (!db.openProjekt(pfad))
                root._zeigeExportStatus(qsTr("Projekt konnte nicht geöffnet werden"), false)
        }
    }

    // ── Projekt-Export FileDialog ─────────────────────────────
    FileDialog {
        id:           projektExportDialog
        title:        qsTr("Projekt exportieren (Kopie erstellen)")
        fileMode:     FileDialog.SaveFile
        nameFilters:  ["Strömling Projekte (*.stroemling)", qsTr("Alle Dateien (*)")]
        defaultSuffix: "stroemling"
        onAccepted: {
            var pfad = selectedFile.toString().replace(/^file:\/\//, "")
            const ok = db.projektExportieren(pfad)
            root._zeigeExportStatus(
                ok ? qsTr("Exportiert: ") + pfad.split("/").pop()
                   : qsTr("Export fehlgeschlagen"),
                ok
            )
        }
    }

    // ── Status-Toast ──────────────────────────────────────────
    Rectangle {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 16 }
        width:   exportStatusLabel.implicitWidth + 28
        height:  34
        radius:  6
        color:   root._exportStatusOk ? "#27ae60" : "#c0392b"
        visible: root._exportStatus !== ""

        Text {
            id:             exportStatusLabel
            anchors.centerIn: parent
            text:           root._exportStatus
            font.pixelSize: 12
            color:          "white"
            elide:          Text.ElideRight
            maximumLineCount: 1
        }
    }

    Timer {
        id:       exportStatusTimer
        interval: 3500
        onTriggered: root._exportStatus = ""
    }

    DebugLabel { panelName: qsTr("Projektliste"); visible: root.debug }
}
