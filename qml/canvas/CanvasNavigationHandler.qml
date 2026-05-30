import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
                canvas.auswahl = canvas.auswahlFuerElement(hitIdx)
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
        MenuItem {
            text: "BMKs nummerieren..."
            enabled: {
                var cnt = 0
                for (var i = 0; i < canvas.auswahl.length; i++)
                    if (canvas.elementeModel.element(canvas.auswahl[i]).typ === "symbol") cnt++
                return cnt >= 2
            }
            onTriggered: {
                var praefix = "-"
                for (var i = 0; i < canvas.auswahl.length; i++) {
                    var el = canvas.elementeModel.element(canvas.auswahl[i])
                    if (el && el.typ === "symbol" && el.extraDaten && el.extraDaten.bmk) {
                        praefix = el.extraDaten.bmk.replace(/\d+$/, "")
                        break
                    }
                }
                var nextFull = db.naechsteBmkNummer(canvas.projektId, praefix)
                bmkNummerierungDialog.praefixFeld = praefix
                bmkNummerierungDialog.startNrFeld = parseInt(nextFull.substring(praefix.length)) || 1
                bmkNummerierungDialog.open()
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
            text:    "Gruppieren\t(Strg+G)"
            enabled: canvas.auswahl.length >= 2
            onTriggered: canvas.gruppeErstellen()
        }
        MenuItem {
            text:    "Gruppe aufloesen\t(Strg+Umsch+G)"
            enabled: canvas.auswahl.length > 0 &&
                     canvas.elementeModel.gruppeVonElement(canvas.auswahl[0]) >= 0
            onTriggered: canvas.gruppeAufloesen()
        }
        MenuSeparator {}
        Menu {
            title: "Ausrichten"
            enabled: canvas.auswahl.length >= 2
            MenuItem { text: "Linksbuendig";          onTriggered: canvas.elementeAusrichten("links")      }
            MenuItem { text: "Rechtsbuendig";         onTriggered: canvas.elementeAusrichten("rechts")     }
            MenuItem { text: "Oben ausrichten";       onTriggered: canvas.elementeAusrichten("oben")       }
            MenuItem { text: "Unten ausrichten";      onTriggered: canvas.elementeAusrichten("unten")      }
            MenuSeparator {}
            MenuItem { text: "Horizontal zentrieren"; onTriggered: canvas.elementeAusrichten("mitte_h")   }
            MenuItem { text: "Vertikal zentrieren";   onTriggered: canvas.elementeAusrichten("mitte_v")   }
            MenuSeparator {}
            MenuItem {
                text:    "Horizontal verteilen"
                enabled: canvas.auswahl.length >= 3
                onTriggered: canvas.elementeAusrichten("verteilen_h")
            }
            MenuItem {
                text:    "Vertikal verteilen"
                enabled: canvas.auswahl.length >= 3
                onTriggered: canvas.elementeAusrichten("verteilen_v")
            }
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
    // CE-11: Batch-BMK-Nummerierungsdialog
    // --------------------------------------------------------
    Dialog {
        id: bmkNummerierungDialog
        title: "BMKs nummerieren"
        modal: true
        anchors.centerIn: Overlay.overlay
        standardButtons: Dialog.Ok | Dialog.Cancel

        property string praefixFeld: "-"
        property int    startNrFeld: 1

        onAboutToShow: {
            praefixInput.text  = praefixFeld
            startNrInput.value = startNrFeld
        }

        ColumnLayout {
            spacing: 8
            width: 260

            RowLayout {
                spacing: 8
                Label { text: "Praefix:"; Layout.preferredWidth: 90 }
                TextField {
                    id: praefixInput
                    Layout.fillWidth: true
                    placeholderText: "-K"
                }
            }
            RowLayout {
                spacing: 8
                Label { text: "Startnummer:"; Layout.preferredWidth: 90 }
                SpinBox {
                    id: startNrInput
                    from: 1; to: 9999
                    editable: true
                    Layout.fillWidth: true
                }
            }
        }

        onAccepted: canvas.batchBmkNummerieren(praefixInput.text.trim(), startNrInput.value)
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
