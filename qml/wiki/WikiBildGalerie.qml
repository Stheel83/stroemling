import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var theme
    property var          bilder: []

    signal bildHinzufuegenAngefordert()
    signal vollbildAnzeigen(string pfad, string beschreibung)
    signal bildLoeschen(int bildId)

    Layout.fillWidth: true
    height: visible ? 116 : 0
    color: root.theme.surfaceDeep
    clip: true

    Rectangle {
        anchors.top: parent.top
        width: parent.width; height: 1; color: root.theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Galerie-Header
        RowLayout {
            Layout.fillWidth: true
            height: 28
            Layout.leftMargin:  16
            Layout.rightMargin: 8

            Text {
                text: root.bilder.length > 0
                      ? "📷 " + qsTr("Bilder (%1)").arg(root.bilder.length)
                      : "📷 " + qsTr("Bilder")
                font.pixelSize: 10
                color:          root.theme.textMuted
                Layout.fillWidth: true
            }
            Rectangle {
                width: 110; height: 20; radius: 3
                color: addBildHover.containsMouse ? root.theme.accent : root.theme.border
                Text {
                    anchors.centerIn: parent
                    text:           qsTr("+ Bild hinzufügen")
                    font.pixelSize: 10
                    color:          root.theme.textPrimary
                }
                HoverHandler { id: addBildHover }
                TapHandler   { onTapped: root.bildHinzufuegenAngefordert() }
            }
        }

        // Thumbnail-Reihe
        ListView {
            id:               thumbListe
            Layout.fillWidth: true
            height:           84
            Layout.leftMargin: 8
            orientation:      ListView.Horizontal
            spacing:          6
            clip:             true
            model:            root.bilder

            delegate: Rectangle {
                width:  80
                height: 80
                radius: 4
                color:  root.theme.border
                clip:   true

                Image {
                    anchors.fill: parent
                    source:       modelData.tempPfad ? "file://" + modelData.tempPfad : ""
                    fillMode:     Image.PreserveAspectCrop
                    smooth:       true
                    asynchronous: true
                }

                // Löschen-Button oben rechts (bei Hover)
                Rectangle {
                    anchors { top: parent.top; right: parent.right; margins: 3 }
                    width: 18; height: 18; radius: 9
                    color:   thumbHover.containsMouse ? "#cc000000" : "#88000000"
                    visible: thumbHover.containsMouse || delThumbHover.containsMouse
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 9
                        color: "white"
                    }
                    HoverHandler { id: delThumbHover }
                    TapHandler {
                        onTapped: root.bildLoeschen(modelData.id)
                    }
                }

                // Vollbild per Klick
                HoverHandler { id: thumbHover }
                TapHandler {
                    onTapped: {
                        root.vollbildAnzeigen(
                            modelData.tempPfad ? "file://" + modelData.tempPfad : "",
                            modelData.beschreibung || modelData.dateiname
                        )
                    }
                }
            }

            // Platzhalter wenn noch keine Bilder
            Text {
                anchors.centerIn: parent
                visible:   thumbListe.count === 0
                text:      qsTr("Noch keine Bilder")
                color:     root.theme.textMuted
                font.pixelSize: 10
            }
        }
    }
}
