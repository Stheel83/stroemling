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

    function _zeigeExportStatus(text, ok) {
        _exportStatus   = text
        _exportStatusOk = (ok !== false)
        exportStatusTimer.restart()
    }

    signal projektGewaehlt(int id, string name)
    signal projektMetaGeaendert(int id)
    signal projektGeloescht(int id)

    PtNeuesProjektDialog    { id: neuesProjektDialog;     theme: root.theme }
    PtEigenschaftenDialog   {
        id: dlgProjektEigenschaften
        theme: root.theme
        onProjektMetaGeaendert: function(id) { root.projektMetaGeaendert(id) }
    }
    PtLoeschenDialog {
        id: dlgLoeschen
        theme: root.theme
        onProjektGeloescht: function(id) { root.projektGeloescht(id) }
    }

    FileDialog {
        id:          projektImportDialog
        title:       qsTr("Projekt importieren")
        fileMode:    FileDialog.OpenFile
        nameFilters: ["Strömling Projekte (*.strl)", qsTr("Alle Dateien (*)")]
        onAccepted: {
            var pfad = selectedFile.toString().replace(/^file:\/\//, "")
            if (!db.openProjekt(pfad))
                root._zeigeExportStatus(qsTr("Projekt konnte nicht geöffnet werden"), false)
        }
    }

    FileDialog {
        id:            projektExportDialog
        title:         qsTr("Projekt exportieren (Kopie erstellen)")
        fileMode:      FileDialog.SaveFile
        nameFilters:   ["Strömling Projekte (*.strl)", qsTr("Alle Dateien (*)")]
        defaultSuffix: "strl"
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

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: 12
        spacing: 8

        // Überschrift + Neu-Button
        RowLayout {
            Layout.fillWidth: true

            Text {
                text:           qsTr("Projekte")
                font.pixelSize: 14; font.weight: Font.Medium
                color:          theme.textBright; Layout.fillWidth: true
            }

            RoundButton {
                text: "📂"; width: 28; height: 28; font.pixelSize: 14
                palette.button: theme.border; palette.buttonText: theme.textPrimary
                ToolTip.visible: hovered
                ToolTip.text:    qsTr("Projekt importieren (.strl öffnen)")
                onClicked: projektImportDialog.open()
            }

            RoundButton {
                text: "+"; width: 28; height: 28; font.pixelSize: 18
                palette.button: theme.border; palette.buttonText: theme.accent
                ToolTip.visible: hovered
                ToolTip.text:    qsTr("Neues Projekt anlegen")
                onClicked: neuesProjektDialog.open()
            }
        }

        Rectangle { height: 1; color: theme.border; Layout.fillWidth: true }

        ListView {
            id:               projektListe
            Layout.fillWidth: true; Layout.fillHeight: true
            clip:             true
            model:            projektModel

            Text {
                anchors.centerIn: parent
                visible:    projektListe.count === 0
                text:       qsTr("Noch keine Projekte.\nKlicke + um eines anzulegen.")
                color:      theme.borderLight; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }

            delegate: Item {
                id: delegateRoot
                width:  ListView.view.width
                height: 52

                HoverHandler { id: itemHover }

                Rectangle {
                    anchors.fill: parent; anchors.margins: 2
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
                            left: parent.left; leftMargin: 10
                            right: deleteBtn.left; rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2
                        Text {
                            text: model.name; font.pixelSize: 13; font.weight: Font.Medium
                            color: theme.textPrimary; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: model.projektnummer || model.erstelltAm.substring(0, 10)
                            font.pixelSize: 11; color: theme.panelMid
                        }
                    }

                    RoundButton {
                        id: exportBtn; text: "⬆"; width: 24; height: 24
                        visible: itemHover.hovered; font.pixelSize: 11
                        palette.button: "transparent"; palette.buttonText: theme.textMuted
                        anchors { right: editBtn.left; rightMargin: 2; verticalCenter: parent.verticalCenter }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text: qsTr("Kopie exportieren (.strl)")
                        onClicked: projektExportDialog.open()
                    }

                    RoundButton {
                        id: editBtn; text: "✎"; width: 24; height: 24
                        visible: itemHover.hovered; font.pixelSize: 13
                        palette.button: "transparent"; palette.buttonText: theme.accent
                        anchors { right: deleteBtn.left; rightMargin: 2; verticalCenter: parent.verticalCenter }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text: qsTr("Projekt bearbeiten")
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

                    RoundButton {
                        id: deleteBtn; text: "×"; width: 24; height: 24
                        visible: itemHover.hovered; font.pixelSize: 14
                        palette.button: "transparent"; palette.buttonText: "#cc4444"
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text: qsTr("Projekt löschen")
                        onClicked: {
                            dlgLoeschen.projektId   = model.projektId
                            dlgLoeschen.projektName = model.name
                            dlgLoeschen.open()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 16 }
        width:   exportStatusLabel.implicitWidth + 28; height: 34; radius: 6
        color:   root._exportStatusOk ? "#27ae60" : "#c0392b"
        visible: root._exportStatus !== ""

        Text {
            id: exportStatusLabel
            anchors.centerIn: parent
            text: root._exportStatus; font.pixelSize: 12; color: "white"
            elide: Text.ElideRight; maximumLineCount: 1
        }
    }

    Timer {
        id:       exportStatusTimer
        interval: 3500
        onTriggered: root._exportStatus = ""
    }

    DebugLabel { panelName: qsTr("Projektliste"); visible: root.debug }
}
