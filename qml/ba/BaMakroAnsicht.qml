import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var panel
    required property var theme

    signal makroEinfuegenAngefordert(int makroId, string name)

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        Rectangle {
            Layout.fillWidth: true; height: 40; color: theme.sidebar
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                Text {
                    text: qsTr("Makros"); font.pixelSize: 13; font.weight: Font.Medium
                    color: theme.textPrimary; Layout.fillWidth: true
                }
                Button {
                    text: "✕"; flat: true; implicitWidth: 24; implicitHeight: 24
                    contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 13;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                    onClicked: panel.aktiveSpezialAnsicht = ""
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        ListView {
            id: makroListView
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: panel.makroListe

            delegate: Rectangle {
                width: makroListView.width; height: 48
                color: mkRowHover.containsMouse ? theme.hover : "transparent"
                HoverHandler { id: mkRowHover }

                ColumnLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                    spacing: 1
                    Text {
                        text: modelData.name; font.pixelSize: 12; font.weight: Font.Medium
                        color: theme.textPrimary; Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: (modelData.kategorie ? modelData.kategorie + " · " : "")
                              + modelData.elementAnzahl + " " + qsTr("Elemente")
                        font.pixelSize: 10; color: theme.textMuted
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }

                Button {
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: qsTr("Einfügen"); implicitHeight: 26; implicitWidth: 70
                    visible: mkRowHover.hovered
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 11;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg;
                        radius: 4; border.color: theme.accent }
                    onClicked: root.makroEinfuegenAngefordert(modelData.id, modelData.name)
                }

                Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 1; color: theme.border; opacity: 0.4 }
            }

            Text {
                anchors.centerIn: parent
                visible: panel.makroListe.length === 0
                text: qsTr("Keine Makros gespeichert.\nMakrokasten zeichnen (M),\nbenennen – fertig.")
                color: theme.textMuted; font.pixelSize: 11; font.italic: true
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                width: parent.width - 24
            }
        }
    }
}
