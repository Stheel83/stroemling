import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import "../components"

// Bild-Werkzeug: FileDialog + Drag-Drop-Bereich des SchaltplanCanvas.
// Anchoring (top/bottom/left/right) wird vom Aufrufer (SchaltplanCanvas) gesetzt.
// Kommuniziert ausschließlich über `canvas` (SchaltplanCanvas-Referenz).
Item {
    id: root

    required property var canvas

    function dialogOeffnen() { bildDialog.open() }

    // ── FileDialog: Bild aus Dateimanager wählen ──────────────────────────
    FileDialog {
        id:          bildDialog
        title:       qsTr("Bild auswählen (max. 5 MB)")
        nameFilters: ["Bilder (*.png *.jpg *.jpeg *.bmp *.gif *.webp)", "Alle Dateien (*)"]

        onAccepted: {
            var result = db.bildAlsDataUrl(selectedFile.toString())
            if (result.startsWith("error:")) {
                bildFehlerText.text = result.substring(6)
                bildFehlerDialog.open()
                canvas.aktivesWerkzeug = "zeiger"
            } else {
                canvas.paletteImageData = result
                canvas.bildLaden(result)
                canvas.aktivesWerkzeug = "bild"
            }
        }
        onRejected: {
            canvas.aktivesWerkzeug = "zeiger"
        }
    }

    // ── Fehlermeldung wenn Bild zu groß oder nicht lesbar ─────────────────
    Dialog {
        id:               bildFehlerDialog
        title:            qsTr("Bild konnte nicht geladen werden")
        modal:            true
        anchors.centerIn: parent
        standardButtons:  Dialog.Ok

        Label {
            id:       bildFehlerText
            color:    "#c05050"
            wrapMode: Text.Wrap
            width:    300
        }
    }

    // ── Drag & Drop: Bilder per Datei-Drag aus dem Dateimanager ──────────
    DropArea {
        anchors.fill: parent
        enabled:      canvas.seiteId >= 0
        keys:         ["text/uri-list"]

        Rectangle {
            anchors.fill:  parent
            color:         "transparent"
            border.color:  "#4a9eff"
            border.width:  3
            visible:       parent.containsDrag
            z:             9999

            Rectangle {
                anchors.centerIn: parent
                width:  hintText.implicitWidth + 32
                height: 44
                color:  "#cc0d1a2b"
                radius: 8

                Text {
                    id:              hintText
                    anchors.centerIn: parent
                    text:            qsTr("Bild hier ablegen")
                    color:           "#4a9eff"
                    font.pixelSize:  16
                    font.bold:       true
                }
            }
        }

        onDropped: function(drop) {
            if (!drop.hasUrls) return
            var urls = drop.urls
            for (var i = 0; i < urls.length; i++) {
                var url = urls[i].toString()
                if (!/\.(png|jpg|jpeg|bmp|gif|webp)$/i.test(url)) continue
                var result = db.bildAlsDataUrl(url)
                if (result.startsWith("error:")) {
                    bildFehlerText.text = result.substring(6)
                    bildFehlerDialog.open()
                    continue
                }
                var vp = root.mapToItem(canvas, drop.x, drop.y)
                var w  = canvas.viewportZuWelt(vp.x, vp.y)
                if (canvas.rastend) w = canvas.rasterPunkt(w.x, w.y)
                canvas.bildLaden(result)
                var hs = canvas.gridPx * 4
                var elBild = {
                    typ:             "bild",
                    x1: w.x - hs,   y1: w.y - hs,
                    x2: w.x + hs,   y2: w.y + hs,
                    bildDaten:       result,
                    strichFarbe:     canvas.stilVorlage.strichFarbe,
                    strichBreite:    canvas.stilVorlage.strichBreite,
                    strichArt:       canvas.stilVorlage.strichArt,
                    fuell:           false, fuellFarbe: "#000000", fuellOpazitaet: 0,
                    opazitaet:       1.0, eckenRadius: 0,
                    rotation: 0, spiegelX: false, spiegelY: false, proportional: false,
                    ausschnittLinks: 0, ausschnittRechts: 0, ausschnittOben: 0, ausschnittUnten: 0
                }
                canvas.aktionAusfuehren(elementeModel.snapshot().concat([elBild]))
                canvas.auswahl = [elementeModel.anzahl - 1]
                break
            }
            drop.accepted = true
        }
    }

    DebugLabel { panelName: qsTr("Canvas-Bild-Werkzeug"); visible: canvas.debug }
}
