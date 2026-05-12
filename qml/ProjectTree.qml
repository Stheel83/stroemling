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

    // Wird nach oben gemeldet wenn ein Projekt ausgewählt wird
    signal projektGewaehlt(int id, string name)

    // Wird nach oben gemeldet wenn Projekt-Metadaten gespeichert wurden
    signal projektMetaGeaendert(int id)

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
                        onClicked: projektModel.loeschen(model.projektId)
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
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : theme.inputBg;
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
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgProjektEigenschaften.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: epName.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
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

    DebugLabel { panelName: qsTr("Projektliste"); visible: root.debug }
}
