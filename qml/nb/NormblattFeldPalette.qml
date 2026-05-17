import QtQuick
import QtQuick.Controls

Item {
    id: root
    required property var theme

    signal feldtypGewaehlt(string typ)

    readonly property var _typen: [
        { typ: "fest",            label: qsTr("Fester Text"),    badge: "T", farbe: "#3d6080" },
        { typ: "projekt",         label: qsTr("Projektfeld"),    badge: "P", farbe: "#2a5580" },
        { typ: "seite",           label: qsTr("Seitenfeld"),     badge: "S", farbe: "#2a6a48" },
        { typ: "datum",           label: qsTr("Datum"),          badge: "D", farbe: "#7a5820" },
        { typ: "vollkennzeichen", label: qsTr("Vollkennzeichen"),badge: "K", farbe: "#5c2a80" },
        { typ: "format",          label: qsTr("Format"),         badge: "F", farbe: "#1e6a78" },
        { typ: "logo",            label: qsTr("Logo"),           badge: "L", farbe: "#783820" }
    ]

    Column {
        anchors { fill: parent; topMargin: 8; leftMargin: 8; rightMargin: 8 }
        spacing: 4

        Text {
            text: qsTr("FELDER")
            color: root.theme.borderLight
            font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
            height: 26; verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: root._typen

            delegate: Rectangle {
                required property var modelData
                width: parent.width; height: 34; radius: 5
                color: ma.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                border.color: root.theme.divider; border.width: 1

                Row {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 8

                    Rectangle {
                        width: 20; height: 20; radius: 4
                        color: modelData.farbe
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: modelData.badge
                            color: "white"; font.pixelSize: 10; font.weight: Font.Bold
                        }
                    }
                    Text {
                        text: modelData.label
                        color: root.theme.textPrimary; font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        width: parent.width - 36
                    }
                }

                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.feldtypGewaehlt(modelData.typ)
                }

                ToolTip.visible: ma.containsMouse
                ToolTip.text: qsTr("Klicken um Feld hinzuzufügen")
                ToolTip.delay: 600
            }
        }

        Item { height: 8 }

        Text {
            text: qsTr("Klick = Feld in die\nMitte der Seite")
            color: root.theme.textMuted; font.pixelSize: 10
            width: parent.width; wrapMode: Text.WordWrap
        }
    }
}
