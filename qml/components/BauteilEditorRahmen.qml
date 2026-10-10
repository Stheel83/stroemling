import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Vollbild-Rahmen für die Bauteil-Editoren (Klemmen, Kabel, Steckverbinder …):
// Breadcrumb-Leiste „← Bauteile / <Bezeichnung> / <Editorname>" + Trennlinie,
// darunter der als Kind übergebene Editor (Layout.fillWidth/fillHeight setzen).
Item {
    id: root

    property var    theme
    property bool   debug:      false
    property string editorName: ""   // z.B. qsTr("Klemmen-Editor")
    property string bauteilBezeichnung: ""

    signal zurueck()

    default property alias inhalt: spalte.data

    DebugLabel { panelName: qsTr("%1 Ansicht").arg(root.editorName); visible: root.debug }

    ColumnLayout {
        id: spalte
        anchors.fill: parent
        spacing:      0

        Rectangle {
            Layout.fillWidth: true
            height:           44
            color:            root.theme.sidebar

            DebugLabel { panelName: qsTr("Breadcrumb-Leiste"); visible: root.debug }

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 16 }
                spacing: 6

                Button {
                    text: "← " + qsTr("Bauteile"); flat: true; implicitHeight: 28
                    contentItem: Text {
                        text: parent.text; color: root.theme.accent; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: parent.hovered ? root.theme.badge : "transparent"; radius: 4 }
                    onClicked: root.zurueck()
                }
                Text { text: "/"; color: root.theme.textMuted; font.pixelSize: 12 }
                Text {
                    text:           root.bauteilBezeichnung
                    font.pixelSize: 13; font.weight: Font.Medium
                    color:          root.theme.textPrimary
                }
                Text { text: "/"; color: root.theme.textMuted; font.pixelSize: 12 }
                Text {
                    text:           root.editorName
                    font.pixelSize: 12
                    color:          root.theme.textMuted
                }
                Item { Layout.fillWidth: true }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }
    }
}
