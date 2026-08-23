import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Bibliothek-Abschnitt (Bauteile mit Symbol) im BAUTEILE-Bereich des
// Seitenbaums — ausgelagert aus SeitenBaumBauteilePanel.qml (REFACTOR-QML-03).
Column {
    id: root
    required property var panel
    required property var theme

    visible: panel._aktiveTab === "alles" || panel._aktiveTab === "sonstiges"
    width: parent.width
    property var _bibliothekListe: panel.visible
        ? bauteilModel.bauteileWithSymbol()
        : []

    Rectangle {
        width: parent.width; height: 1; color: root.theme.divider
    }

    Rectangle {
        width: parent.width; height: 28; color: "transparent"
        visible: parent._bibliothekListe.length === 0
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
            spacing: 6
            Text { text: "💡"; font.pixelSize: 11; opacity: 0.35; color: root.theme.textMuted }
            Text {
                text: qsTr("Bibliothek – Bauteile mit Symbol im Editor anlegen")
                font.pixelSize: 11; color: root.theme.textMuted; opacity: 0.6
                Layout.fillWidth: true
            }
        }
    }

    Repeater {
        model: parent._bibliothekListe
        delegate: Rectangle {
            width: parent.width; height: 32
            color: bibMA.containsMouse ? root.theme.hover : "transparent"
            property var bd: modelData

            MouseArea { id: bibMA; anchors.fill: parent; hoverEnabled: true }

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                spacing: 5
                Text { text: "💡"; font.pixelSize: 11; color: root.theme.textMuted }
                Text {
                    text: bd.bezeichnung || ""
                    font.pixelSize: 12; color: root.theme.textPrimary
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Text {
                    text: bd.symbolId || ""
                    font.pixelSize: 10; color: root.theme.textMuted
                    elide: Text.ElideRight; Layout.maximumWidth: 70
                }
                Rectangle {
                    width: 22; height: 22; radius: 3
                    color: bibPlusMA.containsMouse ? root.theme.activeItemAlt : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "+"; font.pixelSize: 14; font.bold: true
                        color: root.theme.accent
                    }
                    ToolTip.visible: bibPlusMA.containsMouse
                    ToolTip.text:    qsTr("Auf Canvas platzieren")
                    ToolTip.delay:   400
                    MouseArea {
                        id: bibPlusMA; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            mouse.accepted = true
                            panel.bauteilPlatzieren(bd.bauteilId, bd.symbolId, bd.bezeichnung)
                        }
                    }
                }
            }
        }
    }
}
