import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// COPY-CROSS-01: Sanfte Verhaltenslenkung statt hartem Verbot beim Einfügen
// aus einem anderen Projekt – siehe konzept/features/15_makros.md §2c.
// Aufruf via canvas.crossProjektEinfuegenDialogOeffnen() (CanvasDialogLayer.qml).
Dialog {
    id: root
    required property var theme

    modal: true; parent: Overlay.overlay; anchors.centerIn: parent
    width: 360; padding: 20

    signal alsMakroBehalten()
    signal nurEingefuegt()

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 8
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: qsTr("Elemente aus anderem Projekt eingefügt")
            font.pixelSize: 14; font.weight: Font.Medium; color: root.theme.textPrimary
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Diese Auswahl stammt aus einem anderen Projekt. Als benanntes Makro in der Bibliothek behalten – für erneute Verwendung an anderer Stelle?")
            font.pixelSize: 11; color: root.theme.textMuted; wrapMode: Text.WordWrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Nein danke"); implicitHeight: 30; implicitWidth: 110
                background: Rectangle {
                    color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border
                }
                contentItem: Text {
                    text: parent.text; color: root.theme.textPrimary; font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: { root.close(); root.nurEingefuegt() }
            }

            Button {
                text: qsTr("Als Makro behalten"); implicitHeight: 30; implicitWidth: 150
                background: Rectangle {
                    color: parent.hovered ? root.theme.accent : root.theme.inputBg
                    radius: 4; border.color: root.theme.accent
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.hovered ? "white" : root.theme.accent
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: { root.close(); root.alsMakroBehalten() }
            }
        }
    }
}
