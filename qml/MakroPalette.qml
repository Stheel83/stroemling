import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    required property var theme

    signal makroEinfuegenAngefordert(int makroId, string name)

    property var _liste: []

    function aktualisieren() {
        root._liste = db.makroListe()
    }

    Component.onCompleted: aktualisieren()
    onVisibleChanged: if (visible) aktualisieren()

    // ── Kategorie-Farbe aus Name-Hash ─────────────────────────
    function katFarbe(kat) {
        if (!kat) return root.theme.textMuted
        var h = 0
        for (var i = 0; i < kat.length; i++)
            h = (Math.imul(h, 31) + kat.charCodeAt(i)) | 0
        h = ((h >>> 0) % 360)
        return Qt.hsla(h / 360.0, 0.55, 0.45, 1.0)
    }

    // ── Vorschau-Popup ────────────────────────────────────────
    property int  _hoverId:    -1
    property real _hoverGlobalX: 0
    property real _hoverGlobalY: 0
    property var  _hoverElems:  []
    property string _hoverName: ""
    property string _hoverKat:  ""
    property int    _hoverAnz:  0
    property real   _hoverKastenBreite: 100
    property real   _hoverKastenHoehe:  100

    // Verzögertes Schließen: verhindert Flackern beim Wechsel der Maus
    // von der Kachel über die schmale Lücke zum Popup
    Timer {
        id: vorschauSchliessTimer
        interval: 200
        onTriggered: root._hoverId = -1
    }

    Popup {
        id: vorschauPopup
        parent:      Overlay.overlay
        modal:       false
        closePolicy: Popup.NoAutoClose
        focus:       false
        width:       220
        padding:     10

        x: Math.max(8, Math.min(root._hoverGlobalX + 6,
                                (parent ? parent.width : 800) - width - 8))
        y: Math.max(8, Math.min(root._hoverGlobalY - height / 2,
                                (parent ? parent.height : 600) - height - 8))

        visible: root._hoverId >= 0

        background: Rectangle {
            color:        root.theme.sidebar
            border.color: root.theme.accent
            border.width: 1
            radius: 5

            MouseArea {
                anchors.fill: parent
                hoverEnabled:  true
                acceptedButtons: Qt.NoButton
                onEntered: vorschauSchliessTimer.stop()
                onExited:  vorschauSchliessTimer.restart()
            }
        }

        ColumnLayout {
            width: parent.width
            spacing: 6

            Text {
                Layout.fillWidth: true
                text:  root._hoverName
                font.pixelSize: 12; font.weight: Font.Medium
                color: root.theme.textPrimary
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            Canvas {
                id: vorschauCanvas
                Layout.fillWidth: true
                height: 120
                property var elems: root._hoverElems

                onElemsChanged: requestPaint()

                Connections {
                    target: vorschauPopup
                    function onVisibleChanged() { if (vorschauPopup.visible) vorschauCanvas.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var es = root._hoverElems
                    if (es.length === 0) return
                    var makroW = root._hoverKastenBreite
                    var makroH = root._hoverKastenHoehe
                    var pad    = 8
                    var scaleX = (width  - 2 * pad) / makroW
                    var scaleY = (height - 2 * pad) / makroH
                    var scale  = Math.min(scaleX, scaleY)
                    var offX   = pad + ((width  - 2 * pad) - makroW * scale) / 2
                    var offY   = pad + ((height - 2 * pad) - makroH * scale) / 2
                    ctx.strokeStyle = root.theme.textMuted || "#aaa"
                    ctx.lineWidth   = 1.0
                    for (var i = 0; i < es.length; i++) {
                        var e  = es[i]
                        var x1 = offX + e.x1 * scale
                        var y1 = offY + e.y1 * scale
                        var x2 = offX + e.x2 * scale
                        var y2 = offY + e.y2 * scale
                        var t  = e.typ
                        if (t === "linie" || t === "kabellinie" || t === "polygonlinie") {
                            ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke()
                        } else if (t === "rechteck" || t === "geraetekasten"
                                || t === "strukturkasten" || t === "makrokasten") {
                            ctx.strokeRect(x1, y1, x2 - x1, y2 - y1)
                        } else if (t === "symbol" || t === "querverweis"
                                || t === "potenzial" || t === "aderdefinition") {
                            var sw = Math.abs(x2 - x1), sh = Math.abs(y2 - y1)
                            var cx = (x1 + x2) / 2, cy = (y1 + y2) / 2
                            ctx.strokeRect(cx - sw / 2, cy - sh / 2, sw, sh)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: (root._hoverKat || qsTr("Allgemein")) + "  ·  "
                      + root._hoverAnz + " " + qsTr("Elemente")
                font.pixelSize: 10
                color: root.theme.textMuted
            }
        }
    }

    // ── Liste + Footer ────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentWidth: root.width
            clip: true

            Column {
                width: root.width

                Repeater {
                model: root._liste

                delegate: Rectangle {
                    id: kachel
                    width:  root.width
                    height: 48
                    color:  rowMa.containsMouse ? root.theme.hover : "transparent"

                    // Farbiger linker Akzentstreifen
                    Rectangle {
                        width: 3; height: parent.height
                        color: root.katFarbe(modelData.kategorie)
                    }

                    ColumnLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text:  modelData.name
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: root.theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (modelData.kategorie || qsTr("Allgemein"))
                                  + "  ·  " + modelData.elementAnzahl + " " + qsTr("Elemente")
                            font.pixelSize: 10
                            color: root.theme.textMuted
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 1; color: root.theme.divider; opacity: 0.5
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            vorschauSchliessTimer.stop()
                            root._hoverElems          = db.makroElementeVorschau(modelData.id)
                            root._hoverId             = modelData.id
                            root._hoverName           = modelData.name
                            root._hoverKat            = modelData.kategorie
                            root._hoverAnz            = modelData.elementAnzahl
                            root._hoverKastenBreite   = modelData.kastenBreite || 100
                            root._hoverKastenHoehe    = modelData.kastenHoehe  || 100
                            root._hoverGlobalX        = kachel.mapToItem(null, kachel.width, 0).x
                            root._hoverGlobalY        = kachel.mapToItem(null, 0, kachel.height / 2).y
                            vorschauCanvas.requestPaint()
                        }
                        onExited: vorschauSchliessTimer.restart()

                        onClicked: {
                            vorschauSchliessTimer.stop()
                            root._hoverId = -1
                            root.makroEinfuegenAngefordert(modelData.id, modelData.name)
                        }
                    }
                }
            }

            // Leer-Zustand
            Text {
                width: root.width
                visible: root._liste.length === 0
                text: qsTr("Keine Makros gespeichert.\nMakrokasten zeichnen (M),\nbenennen – fertig.")
                color: root.theme.textMuted
                font.pixelSize: 11; font.italic: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                topPadding: 20; leftPadding: 12; rightPadding: 12
            }
        }
    }

    } // ColumnLayout
}
