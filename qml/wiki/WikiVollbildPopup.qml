import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Vollbild-Popup für Wiki-Bilder — ausgelagert aus WikiAnsicht.qml
// (REFACTOR-QML-04). Echtes Vollbild über das gesamte Fenster
// (Overlay.overlay statt begrenztem Karten-Popup) + Zoom/Pan, damit auch
// dichte Infografiken (z.B. Charakter-Übersichtsblätter) auf kleinen
// Bildschirmen lesbar bleiben. Mausrad zoomt, gezogen wird mit der Maus,
// Doppelklick wechselt zwischen "einpassen" und 2,5×-Zoom.
Popup {
    id: root
    required property var panel   // WikiAnsicht-Referenz (_vollbildPfad, _vollbildBeschr)

    parent:       Overlay.overlay
    x:            0
    y:            0
    width:        parent ? parent.width  : 0
    height:       parent ? parent.height : 0
    modal:        true
    closePolicy:  Popup.CloseOnEscape
    padding:      0

    property real _zoom: 1.0

    onOpened: root._zoom = 1.0

    background: Rectangle { color: "#000000" }

    Flickable {
        id:    vollbildFlick
        anchors.fill: parent
        anchors.bottomMargin: 40
        clip:  true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth:  vollbildImg.width  * root._zoom
        contentHeight: vollbildImg.height * root._zoom

        Image {
            id:               vollbildImg
            transformOrigin:  Item.TopLeft
            width:            vollbildFlick.width
            height:           vollbildFlick.height
            scale:            root._zoom
            source:           panel._vollbildPfad
            fillMode:         Image.PreserveAspectFit
            smooth:           true
            asynchronous:     true

            TapHandler {
                onDoubleTapped: root._zoom = (root._zoom > 1.0 ? 1.0 : 2.5)
            }
        }

        WheelHandler {
            onWheel: (event) => {
                const faktor = event.angleDelta.y > 0 ? 1.2 : (1 / 1.2)
                root._zoom = Math.max(1.0, Math.min(6.0, root._zoom * faktor))
            }
        }
    }

    // Unterleiste: Beschriftung + Zoom-Hinweis + Schließen-Button
    RowLayout {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
        spacing: 8
        Text {
            Layout.fillWidth: true
            text:           panel._vollbildBeschr + qsTr("  ·  Mausrad: Zoom · Ziehen: Verschieben · Doppelklick: Zoom an/aus")
            font.pixelSize: 11
            color:          "#cccccc"
            elide:          Text.ElideRight
        }
        Rectangle {
            width: 70; height: 24; radius: 3
            color: closeHover.hovered ? "#33ffffff" : "transparent"
            border.color: "#666666"
            Text {
                anchors.centerIn: parent
                text:           qsTr("✕ Schließen")
                font.pixelSize: 10
                color:          "#eeeeee"
            }
            HoverHandler { id: closeHover }
            TapHandler   { onTapped: root.close() }
        }
    }
}
