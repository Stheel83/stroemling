import QtQuick
import QtQuick.Controls

// Pan / Zoom / Pinch und Rechtsklick-Kontextmenü des SchaltplanCanvas.
// Kommuniziert ausschließlich über `canvas` (SchaltplanCanvas-Referenz).
Item {
    id: root

    required property var canvas

    // --------------------------------------------------------
    // Pan – Rechts-/Mittelklick
    // --------------------------------------------------------
    DragHandler {
        id: panHandler
        target: null
        enabled: canvas.seiteId >= 0
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        property real startX: 0; property real startY: 0
        onActiveChanged: { if (active) { startX = canvas.worldX; startY = canvas.worldY } }
        onTranslationChanged: {
            canvas.worldX = startX + translation.x
            canvas.worldY = startY + translation.y
            canvas.repaintAll()
        }
    }

    // --------------------------------------------------------
    // Rechtsklick-Kontextmenü
    // TapHandler koexistiert mit DragHandler für denselben Button:
    // Drag beyond threshold → Pan; sauberer Klick → Menü
    // --------------------------------------------------------
    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled:         canvas.seiteId >= 0
        onTapped: function(eventPoint) {
            if (canvas.aktivesWerkzeug !== "zeiger") return
            var vpX = eventPoint.position.x
            var vpY = eventPoint.position.y
            var hitIdx = canvas.elementBeiPosition(vpX, vpY)
            if (hitIdx >= 0 && canvas.auswahl.indexOf(hitIdx) < 0)
                canvas.auswahl = [hitIdx]
            kontextMenu.popup(vpX, vpY)
        }
    }

    Menu {
        id: kontextMenu

        MenuItem {
            text:    "Kopieren\t(Strg+C)"
            enabled: canvas.auswahl.length > 0
            onTriggered: canvas.kopieren(0)
        }
        MenuItem {
            text:    "Ausschneiden\t(Strg+X)"
            enabled: canvas.auswahl.length > 0
            onTriggered: { canvas.kopieren(0); canvas.loeschen() }
        }
        MenuItem {
            text:    "Einfuegen\t(Strg+V)"
            enabled: canvas.zwischenablage.length > 0 && canvas.seiteId >= 0
            onTriggered: canvas.einfuegen(0)
        }
        MenuItem {
            text:    "Duplizieren\t(Strg+D)"
            enabled: canvas.auswahl.length > 0 && canvas.seiteId >= 0
            onTriggered: canvas.duplizieren()
        }
        MenuSeparator {}
        MenuItem {
            text: "Drehen 90 Grad"
            enabled: {
                if (canvas.auswahl.length === 0) return false
                for (var i = 0; i < canvas.auswahl.length; i++)
                    if (canvas.elementeModel.element(canvas.auswahl[i]).typ === "symbol") return true
                return false
            }
            onTriggered: {
                if (canvas.auswahl.length === 1) {
                    var el = canvas.elementeModel.element(canvas.ausgewaehlt)
                    canvas.eigenschaftAktualisieren("rotation", ((el.rotation || 0) + 90) % 360)
                } else {
                    canvas.multiRotationUmPivot(90)
                }
            }
        }
        MenuSeparator {}
        MenuItem {
            text:    "Loeschen\t(Entf)"
            enabled: canvas.auswahl.length > 0
            onTriggered: canvas.loeschen()
        }
        MenuSeparator {}
        MenuItem {
            text:      "Alles auswaehlen\t(Strg+A)"
            onTriggered: canvas.alleAuswaehlen()
        }
        MenuItem {
            text:    "Auswahl aufheben\t(Esc)"
            enabled: canvas.auswahl.length > 0
            onTriggered: { canvas.auswahl = []; canvas.neuZeichnen() }
        }
    }

    // --------------------------------------------------------
    // Zoom – Mausrad + Touchpad-Scroll
    // --------------------------------------------------------
    WheelHandler {
        enabled: canvas.seiteId >= 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y
                                                 : event.pixelDelta.y * 3
            if (delta === 0) return
            var factor  = delta > 0 ? 1.12 : (1 / 1.12)
            var newZoom = Math.max(canvas.minZoom, Math.min(canvas.maxZoom, canvas.zoom * factor))
            canvas.worldX = event.x - (event.x - canvas.worldX) * (newZoom / canvas.zoom)
            canvas.worldY = event.y - (event.y - canvas.worldY) * (newZoom / canvas.zoom)
            canvas.zoom   = newZoom; canvas.repaintAll()
        }
    }

    // --------------------------------------------------------
    // Zoom – Touchpad-Pinch (zwei Finger aufziehen / zusammenziehen)
    // --------------------------------------------------------
    PinchHandler {
        id: pinchHandler
        target: null
        enabled: canvas.seiteId >= 0
        property real startZoom: 1.0
        onActiveChanged: { if (active) startZoom = canvas.zoom }
        onActiveScaleChanged: {
            var newZoom = Math.max(canvas.minZoom, Math.min(canvas.maxZoom, startZoom * activeScale))
            var cx = centroid.position.x
            var cy = centroid.position.y
            canvas.worldX = cx - (cx - canvas.worldX) * (newZoom / canvas.zoom)
            canvas.worldY = cy - (cy - canvas.worldY) * (newZoom / canvas.zoom)
            canvas.zoom   = newZoom; canvas.repaintAll()
        }
    }
}
