import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Pan / Zoom / Pinch und Rechtsklick-Kontextmenü des SchaltplanCanvas.
// Kommuniziert ausschließlich über `canvas` (SchaltplanCanvas-Referenz).
Item {
    id: root

    required property var canvas

    // Settle-Timer: 200 ms nach dem letzten Bewegungsevent → voller Repaint mit Text
    Timer {
        id: settleTimer
        interval: 200
        repeat:   false
        onTriggered: {
            canvas.bewegungAktiv = false
            canvas.repaintAll()
        }
    }

    // --------------------------------------------------------
    // Pan – Rechts-/Mittelklick
    // --------------------------------------------------------
    DragHandler {
        id: panHandler
        target: null
        enabled: canvas.seiteId >= 0
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        property real startX: 0; property real startY: 0
        onActiveChanged: {
            if (active) { startX = canvas.worldX; startY = canvas.worldY }
            else settleTimer.restart()
        }
        onTranslationChanged: {
            canvas.bewegungAktiv = true
            settleTimer.restart()
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
                for (var i = 0; i < canvas.auswahl.length; i++) {
                    var elT = canvas.elementeModel.element(canvas.auswahl[i]).typ
                    if (elT === "symbol" || elT === "schirm") return true
                }
                return false
            }
            onTriggered: {
                if (canvas.auswahl.length === 1) {
                    var el = canvas.elementeModel.element(canvas.ausgewaehlt)
                    if (el.typ === "schirm") canvas.schirmDrehen()
                    else canvas.eigenschaftAktualisieren("rotation", ((el.rotation || 0) + 90) % 360)
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
            enabled: canvas.auswahl.length >= 1
            MenuItem {
                text:    "Am Raster ausrichten"
                enabled: canvas.auswahl.length >= 1
                onTriggered: canvas.elementeAufRasterSnappen()
            }
            MenuSeparator {}
            MenuItem { text: "Linksbuendig";          enabled: canvas.auswahl.length >= 2; onTriggered: canvas.elementeAusrichten("links")    }
            MenuItem { text: "Rechtsbuendig";         enabled: canvas.auswahl.length >= 2; onTriggered: canvas.elementeAusrichten("rechts")   }
            MenuItem { text: "Oben ausrichten";       enabled: canvas.auswahl.length >= 2; onTriggered: canvas.elementeAusrichten("oben")     }
            MenuItem { text: "Unten ausrichten";      enabled: canvas.auswahl.length >= 2; onTriggered: canvas.elementeAusrichten("unten")    }
            MenuSeparator {}
            MenuItem { text: "Horizontal zentrieren"; enabled: canvas.auswahl.length >= 2; onTriggered: canvas.elementeAusrichten("mitte_h") }
            MenuItem { text: "Vertikal zentrieren";   enabled: canvas.auswahl.length >= 2; onTriggered: canvas.elementeAusrichten("mitte_v") }
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
            text: "Im Bauteilbereich anzeigen"
            enabled: {
                if (canvas.auswahl.length !== 1) return false
                var el = canvas.elementeModel.element(canvas.auswahl[0])
                return el && el.symbolId === "klemme_anschluss"
                    && el.extraDaten && el.extraDaten.klemmeId > 0
                    && el.extraDaten.platziermodus === "verknuepft"
            }
            onTriggered: {
                var el = canvas.elementeModel.element(canvas.auswahl[0])
                canvas.klemmeImSeitenBaumAnzeigen(
                    el.extraDaten.klemmeId,
                    el.extraDaten.anschlussBezeichnung || ""
                )
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

    // CE-17: EigenschaftenPanel-Button löst BMK-Dialog aus
    Connections {
        target: canvas
        function onBatchBmkDialogOeffnen() {
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
    // Pending-Zustand für akkumulierte Zoom-Schritte zwischen zwei Frames.
    // Bei schnellen Touchpad-Gesten kommen viele Events pro Frame; wir
    // akkumulieren den Zoom-Faktor und rendern erst beim Timer-Auslöser.
    property real _pendingZoom: -1
    property real _pendingWx:    0
    property real _pendingWy:    0

    Timer {
        id: zoomFlushTimer
        interval: 16   // ~1 Frame bei 60 fps
        repeat:   false
        onTriggered: {
            canvas.worldX = root._pendingWx
            canvas.worldY = root._pendingWy
            canvas.zoom   = root._pendingZoom
            canvas.repaintAll()
            root._pendingZoom = -1
        }
    }

    WheelHandler {
        enabled: canvas.seiteId >= 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y
                                                 : event.pixelDelta.y * 3
            if (delta === 0) return
            canvas.bewegungAktiv = true
            settleTimer.restart()
            var factor   = delta > 0 ? 1.12 : (1 / 1.12)
            var baseZoom = root._pendingZoom > 0 ? root._pendingZoom : canvas.zoom
            var baseWx   = root._pendingZoom > 0 ? root._pendingWx   : canvas.worldX
            var baseWy   = root._pendingZoom > 0 ? root._pendingWy   : canvas.worldY
            var newZoom  = Math.max(canvas.minZoom, Math.min(canvas.maxZoom, baseZoom * factor))
            root._pendingWx   = event.x - (event.x - baseWx) * (newZoom / baseZoom)
            root._pendingWy   = event.y - (event.y - baseWy) * (newZoom / baseZoom)
            root._pendingZoom = newZoom
            if (!zoomFlushTimer.running) zoomFlushTimer.start()
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
        onActiveChanged: {
            if (active) startZoom = canvas.zoom
            else settleTimer.restart()
        }
        onActiveScaleChanged: {
            canvas.bewegungAktiv = true
            settleTimer.restart()
            var newZoom = Math.max(canvas.minZoom, Math.min(canvas.maxZoom, startZoom * activeScale))
            var cx = centroid.position.x
            var cy = centroid.position.y
            canvas.worldX = cx - (cx - canvas.worldX) * (newZoom / canvas.zoom)
            canvas.worldY = cy - (cy - canvas.worldY) * (newZoom / canvas.zoom)
            canvas.zoom   = newZoom; canvas.repaintAll()
        }
    }
}
