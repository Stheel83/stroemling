import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Bestätigungsdialog für Löschaktionen in der SPS/PLS-Ansicht (SPS-LOESCHEN-01):
// Rack, Baugruppe und Kanal. Der Aufrufer setzt Titel/Text (und optional eine
// Checkbox, z.B. „Kanäle ebenfalls löschen") und führt die Aktion im Handler aus.
// Optik: wie SbAnlageOrtLoeschenDialog (rote Löschen-Schaltfläche, Standard 37).
Dialog {
    id: root
    required property var theme

    property string titel:       ""
    property string text:        ""
    property bool   gefahr:      false   // true = Hinweis in Warnfarbe (Daten gehen verloren)
    property string optionText:  ""      // leer = keine Checkbox
    property bool   optionWert:  false

    signal bestaetigt(bool option)

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 400
    padding: 20

    onAboutToShow: optionBox.checked = root.optionWert

    background: Rectangle { color: root.theme.sidebar; border.color: "#5a2020"; border.width: 1; radius: 6 }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: root.titel
            font.pixelSize: 15; font.weight: Font.Medium; color: "#cc3300"
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3a1a1a" }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            color: root.gefahr ? "#dd6600" : root.theme.textSecondary
            text: root.text
        }

        CheckBox {
            id: optionBox
            visible: root.optionText !== ""
            Layout.fillWidth: true
            text: root.optionText
            contentItem: Text {
                text: optionBox.text
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                color: root.theme.textPrimary
                leftPadding: optionBox.indicator.width + 8
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#3a1a1a"; Layout.topMargin: 4 }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                                     horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }
            Button {
                text: qsTr("Löschen"); implicitWidth: 90; implicitHeight: 34
                contentItem: Text { text: parent.text; color: "#ffe0e0"; font.pixelSize: 13;
                                     horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? "#6a1a1a" : "#3a1010"; radius: 4 }
                onClicked: {
                    root.bestaetigt(optionBox.visible && optionBox.checked)
                    root.close()
                }
            }
        }
    }
}
