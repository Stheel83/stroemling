import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Bestätigungsdialog „Seite löschen" — ausgelagert aus SeitenBaum.qml (REFACTOR-QML-01).
Dialog {
    id: root
    required property var theme
    required property var sb   // SeitenBaum-Referenz, für seiteGeloescht-Signal

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 380
    padding: 20

    property int loeschSeiteId:       -1
    property int loeschElementeAnzahl: 0

    background: Rectangle { color: root.theme.sidebar; border.color: "#5a2020"; border.width: 1; radius: 6 }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: qsTr("Seite löschen")
            font.pixelSize: 15; font.weight: Font.Medium; color: "#cc3300"
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#3a1a1a" }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            color: root.loeschElementeAnzahl > 0 ? "#dd6600" : root.theme.textSecondary
            text: root.loeschElementeAnzahl > 0
                ? "Diese Seite enthält " + root.loeschElementeAnzahl
                  + " Element(e).\n\nSeite und alle Elemente werden unwiderruflich gelöscht."
                : "Diese leere Seite löschen?"
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
                    var id = root.loeschSeiteId
                    seitenModel.loeschen(2, id)
                    root.sb.seiteGeloescht(id)
                    root.close()
                }
            }
        }
    }
}
