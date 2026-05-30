import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "components"

// Projektliste – zeigt alle bekannten Projekte aus der Registry (bekannte_projekte)
// und erlaubt Anlegen / Öffnen / Entfernen.

Item {
    id: root

    property var  theme
    property bool debug: false

    property string _statusText: ""
    property bool   _statusOk:   true

    function _zeigeStatus(text, ok) {
        _statusText = text
        _statusOk   = (ok !== false)
        statusTimer.restart()
    }

    signal projektGewaehlt(int id, string name)
    signal projektMetaGeaendert(int id)
    signal projektGeloescht(int id)

    FileDialog {
        id: neuesProjektDialog
        fileMode:      FileDialog.SaveFile
        nameFilters:   ["Strömling Projekte (*.strl)"]
        defaultSuffix: "strl"
        onAccepted: {
            if (!db.createProjekt(selectedFile.toString(), ""))
                root._zeigeStatus(qsTr("Projekt konnte nicht angelegt werden."), false)
        }
    }

    PtEigenschaftenDialog {
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
        id:          projektOeffnenDialog
        title:       qsTr("Projekt öffnen (.strl)")
        fileMode:    FileDialog.OpenFile
        nameFilters: ["Strömling Projekte (*.strl)", qsTr("Alle Dateien (*)")]
        onAccepted: {
            if (!db.openProjekt(selectedFile.toString()))
                root._zeigeStatus(qsTr("Projekt konnte nicht geöffnet werden"), false)
        }
    }

    FileDialog {
        id:            projektExportDialog
        title:         qsTr("Projekt exportieren (Kopie erstellen)")
        fileMode:      FileDialog.SaveFile
        nameFilters:   ["Strömling Projekte (*.strl)", qsTr("Alle Dateien (*)")]
        defaultSuffix: "strl"
        onAccepted: {
            var ok = db.projektExportieren(selectedFile.toString())
            root._zeigeStatus(
                ok ? qsTr("Exportiert: ") + selectedFile.toString().split("/").pop()
                   : qsTr("Export fehlgeschlagen"),
                ok
            )
        }
    }

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: 12
        spacing: 8

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
                ToolTip.text:    qsTr("Projekt öffnen (.strl Datei)")
                onClicked: projektOeffnenDialog.open()
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
            model:            db.bekannteProjecte

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
                height: 56

                readonly property bool istAktiv: (modelData ? modelData.dateiPfad : "") === db.projektPfad

                HoverHandler { id: itemHover }

                Rectangle {
                    anchors.fill: parent; anchors.margins: 2
                    color:  delegateRoot.istAktiv
                            ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
                            : (itemHover.hovered ? theme.divider : "transparent")
                    radius: 6
                    Behavior on color { ColorAnimation { duration: 100 } }

                    // Aktiv-Indikator links
                    Rectangle {
                        width:  3; height: parent.height - 12; radius: 2
                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        color:   delegateRoot.istAktiv ? theme.accent : "transparent"
                    }

                    TapHandler {
                        onTapped: {
                            if (!modelData) return
                            if (!delegateRoot.istAktiv) {
                                if (db.openProjekt(modelData.dateiPfad)) {
                                    var info = db.ersteProjektInfo()
                                    root.projektGewaehlt(info.id || 0, info.name || modelData.projektName)
                                } else {
                                    root._zeigeStatus(qsTr("Projekt konnte nicht geöffnet werden"), false)
                                }
                            } else {
                                var info2 = db.ersteProjektInfo()
                                root.projektGewaehlt(info2.id || 0, info2.name || modelData.projektName)
                            }
                            projektListe.currentIndex = index
                        }
                    }

                    ColumnLayout {
                        anchors {
                            left: parent.left; leftMargin: 14
                            right: exportBtn.visible ? exportBtn.left : (editBtn.visible ? editBtn.left : neuInstanzBtn.left)
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 2

                        Text {
                            text: (modelData && modelData.projektName) || qsTr("(Ohne Namen)")
                            font.pixelSize: 13; font.weight: Font.Medium
                            color: (modelData && modelData.dateiExistiert) ? theme.textPrimary : theme.textMuted
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: {
                                if (!modelData || !modelData.dateiExistiert)
                                    return qsTr("Datei nicht gefunden")
                                return modelData.projektNummer
                                       ? modelData.projektNummer
                                       : (modelData.dateiPfad || "").split("/").pop()
                            }
                            font.pixelSize: 10
                            color: (modelData && modelData.dateiExistiert) ? theme.panelMid : "#cc4444"
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }

                    RoundButton {
                        id: exportBtn
                        text: "⬆"; width: 24; height: 24; font.pixelSize: 11
                        visible: itemHover.hovered && delegateRoot.istAktiv
                        palette.button: "transparent"; palette.buttonText: theme.textMuted
                        anchors { right: editBtn.left; rightMargin: 2; verticalCenter: parent.verticalCenter }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text: qsTr("Kopie exportieren (.strl)")
                        onClicked: projektExportDialog.open()
                    }

                    RoundButton {
                        id: neuInstanzBtn
                        text: "↗"; width: 24; height: 24; font.pixelSize: 13
                        visible: itemHover.hovered && !delegateRoot.istAktiv && (modelData ? modelData.dateiExistiert : false)
                        palette.button: "transparent"; palette.buttonText: theme.accent
                        anchors { right: deleteBtn.left; rightMargin: 2; verticalCenter: parent.verticalCenter }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text: qsTr("In neuer Instanz öffnen")
                        onClicked: appHelper.neueInstanzMitProjekt(modelData.dateiPfad)
                    }

                    RoundButton {
                        id: editBtn
                        text: "✎"; width: 24; height: 24; font.pixelSize: 13
                        visible: itemHover.hovered && delegateRoot.istAktiv
                        palette.button: "transparent"; palette.buttonText: theme.accent
                        anchors { right: neuInstanzBtn.visible ? neuInstanzBtn.left : deleteBtn.left; rightMargin: 2; verticalCenter: parent.verticalCenter }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text: qsTr("Projekt bearbeiten")
                        onClicked: {
                            if (!modelData) return
                            var info = db.ersteProjektInfo()
                            dlgProjektEigenschaften.projektId      = info.id || 0
                            dlgProjektEigenschaften.altName        = info.name        || modelData.projektName
                            dlgProjektEigenschaften.altNummer      = info.projektnummer || modelData.projektNummer || ""
                            dlgProjektEigenschaften.altAuftragg    = info.auftraggeber  || ""
                            dlgProjektEigenschaften.altAuftragnehm = info.auftragnehmer || ""
                            dlgProjektEigenschaften.altBearbeiter  = info.bearbeiter    || ""
                            dlgProjektEigenschaften.open()
                        }
                    }

                    RoundButton {
                        id: deleteBtn
                        text: "×"; width: 24; height: 24; font.pixelSize: 14
                        visible: itemHover.hovered
                        palette.button: "transparent"; palette.buttonText: "#cc6600"
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        ToolTip.visible: hovered; ToolTip.delay: 700
                        ToolTip.text: qsTr("Aus Projektliste entfernen")
                        onClicked: {
                            if (!modelData || !modelData.dateiPfad) return
                            var aktivId = delegateRoot.istAktiv
                                          ? (db.ersteProjektInfo().id || -1)
                                          : -1
                            dlgLoeschen.dateiPfad      = modelData.dateiPfad
                            dlgLoeschen.projektName    = modelData.projektName || modelData.dateiPfad.split("/").pop()
                            dlgLoeschen.aktivProjektId = aktivId
                            dlgLoeschen.open()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 16 }
        width:   statusLabel.implicitWidth + 28; height: 34; radius: 6
        color:   root._statusOk ? "#27ae60" : "#c0392b"
        visible: root._statusText !== ""

        Text {
            id: statusLabel
            anchors.centerIn: parent
            text: root._statusText; font.pixelSize: 12; color: "white"
            elide: Text.ElideRight; maximumLineCount: 1
        }
    }

    Timer {
        id:       statusTimer
        interval: 3500
        onTriggered: root._statusText = ""
    }

    DebugLabel { panelName: qsTr("Projektliste"); visible: root.debug }
}
