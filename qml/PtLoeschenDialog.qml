import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    required property var theme

    property string dateiPfad:       ""
    property string projektName:     ""
    property int    aktivProjektId:  -1

    signal projektGeloescht(int id)

    modal: true; parent: Overlay.overlay; anchors.centerIn: parent
    width: 360; padding: 20

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 8
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: qsTr("Aus Projektliste entfernen?")
            font.pixelSize: 14; font.weight: Font.Medium; color: root.theme.textPrimary
        }
        Text {
            Layout.fillWidth: true
            text: root.projektName
            font.pixelSize: 13; color: root.theme.accent; elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Der Eintrag wird aus der Projektliste entfernt. Die Datei auf dem Datentrager bleibt unverandert erhalten.")
            font.pixelSize: 11; color: root.theme.textMuted; wrapMode: Text.WordWrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Abbrechen"); implicitHeight: 30; implicitWidth: 100
                background: Rectangle {
                    color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border
                }
                contentItem: Text {
                    text: parent.text; color: root.theme.textPrimary; font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.close()
            }

            Button {
                text: qsTr("Entfernen"); implicitHeight: 30; implicitWidth: 100
                background: Rectangle {
                    color: parent.hovered ? "#cc6600" : root.theme.inputBg
                    radius: 4; border.color: "#ff8800"
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.hovered ? "white" : "#ff8800"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var id   = root.aktivProjektId
                    var pfad = root.dateiPfad
                    if (id !== -1)
                        db.closeProjekt()
                    db.projektAusRegistryEntfernen(pfad)
                    root.dateiPfad      = ""
                    root.projektName    = ""
                    root.aktivProjektId = -1
                    root.close()
                    root.projektGeloescht(id)
                }
            }
        }
    }
}
