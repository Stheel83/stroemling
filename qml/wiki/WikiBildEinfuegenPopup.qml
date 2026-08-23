import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Bild-Einfügen-Popup — ausgelagert aus WikiAnsicht.qml (REFACTOR-QML-04).
Popup {
    id: root
    required property var panel     // WikiAnsicht-Referenz (_bilder, width)
    required property var theme
    required property var toolbar   // WikiFormatierungsToolbar-Referenz (_fmtEinfuegen)

    anchors.centerIn: parent
    width:        Math.min(panel.width * 0.6, 620)
    height:       160
    modal:        true
    padding:      12
    closePolicy:  Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color:        theme.surface
        radius:       6
        border.color: theme.border
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing:      8

        Text {
            text:           qsTr("Bild wählen – wird an Cursorposition eingefügt:")
            font.pixelSize: 11
            color:          theme.textMuted
        }

        Text {
            visible:          panel._bilder.length === 0
            Layout.fillWidth: true
            text:             qsTr("Noch keine Bilder – erst in der Galerie unten zum Artikel hinzufügen.")
            font.pixelSize:   11
            color:            theme.textMuted
            wrapMode:         Text.Wrap
        }

        ListView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            orientation:       ListView.Horizontal
            spacing:           8
            clip:              true
            model:             panel._bilder
            visible:           panel._bilder.length > 0

            delegate: Item {
                width:  96
                height: ListView.view.height

                Rectangle {
                    id:     thumbPickRect
                    width:  88; height: 88; radius: 4
                    color:  theme.border
                    clip:   true
                    anchors.horizontalCenter: parent.horizontalCenter

                    Image {
                        anchors.fill: parent
                        source:       modelData.tempPfad ? "file://" + modelData.tempPfad : ""
                        fillMode:     Image.PreserveAspectCrop
                        smooth:       true
                        asynchronous: true
                    }

                    Rectangle {
                        anchors.fill:  parent
                        radius:        4
                        color:         pickHover.hovered ? theme.accent + "44" : "transparent"
                        border.color:  pickHover.hovered ? theme.accent : "transparent"
                        border.width:  2
                    }
                }

                Text {
                    anchors { top: thumbPickRect.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
                    width:          88
                    text:           modelData.beschreibung || modelData.dateiname || ""
                    font.pixelSize: 9
                    color:          theme.textMuted
                    elide:          Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                HoverHandler { id: pickHover }
                TapHandler {
                    onTapped: {
                        var descr = modelData.beschreibung || modelData.dateiname || ""
                        toolbar._fmtEinfuegen("![" + descr + "](wiki://bild/" + modelData.id + ")")
                        root.close()
                    }
                }
            }
        }
    }
}
