import QtQuick
import QtQuick.Layouts
import QtCore

// Sektion "Rosi Röhrenaal": einziger Schalter, der Rest (Timing, Sprüche,
// Urlaub) läuft vollständig intern im RosiManager – siehe
// konzept/features/48_rosi_roehrenaal.md. Bewusst kein Mehrstufen-UI,
// Nerv-nicht-Knopf in der Sprechblase reicht für den Alltag.
ColumnLayout {
    id: root

    required property var theme

    Layout.fillWidth: true
    spacing: 0

    Settings {
        id:       rosiSettings
        category: "rosi"
        property bool aktiviert: true
    }

    Item { implicitHeight: 28 }
    Text {
        Layout.leftMargin:   20
        text:                qsTr("Rosi Röhrenaal")
        font.pixelSize:      11
        font.weight:         Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing:  1
        color:               root.theme.textMuted
    }
    Item { implicitHeight: 8 }

    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        implicitHeight:     rosiCol.implicitHeight + 20
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        ColumnLayout {
            id: rosiCol
            anchors {
                left:  parent.left;  leftMargin:  12
                right: parent.right; rightMargin: 12
                top:   parent.top;   topMargin:   12
            }
            spacing: 12

            Text {
                Layout.fillWidth: true
                text:    qsTr("Taucht hin und wieder aus einer Rohröffnung auf und lässt einen lockeren Spruch da. Mit dem „Nerv nicht“-Knopf bleibt sie bis morgen weg.")
                font.pixelSize: 11
                color:          root.theme.textMuted
                wrapMode:       Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text:             qsTr("Aktiviert")
                    font.pixelSize:   12
                    color:            root.theme.textPrimary
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 44; height: 24; radius: 12
                    color: rosiSettings.aktiviert ? root.theme.accent : root.theme.inputBg
                    border.color: root.theme.border

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        x: rosiSettings.aktiviert ? parent.width - width - 3 : 3
                        y: 3; width: 18; height: 18; radius: 9
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    rosiSettings.aktiviert = !rosiSettings.aktiviert
                    }
                }
            }

            Item { implicitHeight: 2 }
        }
    }
}
