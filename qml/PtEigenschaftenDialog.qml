import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: root
    required property var theme

    property int    projektId:      -1
    property string altName:        ""
    property string altNummer:      ""
    property string altAuftragg:    ""
    property string altAuftragnehm: ""
    property string altBearbeiter:  ""

    signal projektMetaGeaendert(int id)

    modal: true; parent: Overlay.overlay; anchors.centerIn: parent
    width: 380; padding: 20

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6
    }

    onOpened: {
        epName.text        = root.altName
        epNummer.text      = root.altNummer
        epAuftragg.text    = root.altAuftragg
        epAuftragnehm.text = root.altAuftragnehm
        epBearbeiter.text  = root.altBearbeiter
    }

    FileDialog {
        id: logoFileDialog
        title: qsTr("Logo-Datei auswählen")
        nameFilters: ["Bilder (*.png *.jpg *.jpeg *.bmp *.gif *.webp)"]
        onAccepted: {
            var ok = db.projektLogoSpeichern(root.projektId, selectedFile.toString())
            if (ok) root.projektMetaGeaendert(root.projektId)
        }
    }

    contentItem: ColumnLayout {
        spacing: 8

        Text {
            text: qsTr("Projekt-Eigenschaften")
            font.pixelSize: 15; font.weight: Font.Medium; color: root.theme.textPrimary
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        Text { text: qsTr("Projektname *");   color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: epName; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Projektnummer");   color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: epNummer; Layout.fillWidth: true; placeholderText: qsTr("z.B. 2024-001")
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Auftraggeber");    color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: epAuftragg; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Auftragnehmer");   color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: epAuftragnehm; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Bearbeiter");      color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: epBearbeiter; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }

        Text {
            text: qsTr("Logo (ersetzt Auftragnehmer im Schriftfeld)")
            color: root.theme.textMuted; font.pixelSize: 12
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Button {
                text: qsTr("Logo wählen …"); implicitHeight: 30; flat: true
                contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 12;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg;
                                        border.color: root.theme.border; radius: 4 }
                onClicked: logoFileDialog.open()
            }
            Button {
                text: qsTr("Entfernen"); implicitHeight: 30; flat: true
                contentItem: Text { text: parent.text; color: "#aa4444"; font.pixelSize: 12;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? "#3a1010" : root.theme.inputBg;
                                        border.color: root.theme.border; radius: 4 }
                onClicked: {
                    db.projektLogoLoeschen(root.projektId)
                    root.projektMetaGeaendert(root.projektId)
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 4 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg;
                                        radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }
            Button {
                text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                enabled: epName.text.trim().length > 0
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    db.projektMetaSpeichern(
                        root.projektId,
                        epName.text.trim(), epNummer.text.trim(),
                        epAuftragg.text.trim(), epAuftragnehm.text.trim(),
                        epBearbeiter.text.trim()
                    )
                    projektModel.laden()
                    root.projektMetaGeaendert(root.projektId)
                    root.close()
                }
            }
        }
    }
}
