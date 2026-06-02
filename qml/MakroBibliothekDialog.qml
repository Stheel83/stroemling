import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ============================================================
// MakroBibliothekDialog – Zentraler Makro-Editor (projektübergreifend)
// Umbenennen, Kategorie/Beschreibung bearbeiten, Löschen,
// Vorschau-Canvas. Kein Canvas-Zugang nötig.
// ============================================================

Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:   700
    height:  520
    padding: 0

    required property var theme

    signal makroListeGeaendert()

    // ── Interner Zustand ──────────────────────────────────────
    property var    _liste:           []
    property string _suchText:        ""
    property int    _selId:           -1
    property string _selName:         ""
    property string _selKat:          ""
    property string _selBeschr:       ""
    property var    _selElems:        []
    property real   _selKastenBreite: 100
    property real   _selKastenHoehe:  100
    property bool   _geaendert:       false
    property bool   _loeschenModus:   false

    property var _gefilterteListe: {
        var s = _suchText.trim().toLowerCase()
        if (s === "") return _liste
        return _liste.filter(function(m) {
            return m.name.toLowerCase().indexOf(s) >= 0
                || (m.kategorie || "").toLowerCase().indexOf(s) >= 0
        })
    }

    function laden() {
        root._liste = db.makroListe()
    }

    function waehleAus(m) {
        root._selId           = m.id
        root._selName         = m.name
        root._selKat          = m.kategorie
        root._selBeschr       = m.beschreibung
        root._selElems        = db.makroElementeVorschau(m.id)
        root._selKastenBreite = m.kastenBreite || 100
        root._selKastenHoehe  = m.kastenHoehe  || 100
        root._geaendert       = false
        root._loeschenModus   = false
        tfName.text   = m.name
        tfKat.text    = m.kategorie
        tfBeschr.text = m.beschreibung
        vorschauCanvas.requestPaint()
    }

    onOpened: {
        root._suchText       = ""
        root._selId          = -1
        root._geaendert      = false
        root._loeschenModus  = false
        suchfeld.text        = ""
        root.laden()
    }

    // ── Hintergrund ───────────────────────────────────────────
    background: Rectangle {
        color:        root.theme.sidebar
        border.color: root.theme.border
        border.width: 1
        radius:       6
    }

    // ── Inhalt ────────────────────────────────────────────────
    contentItem: ColumnLayout {
        spacing: 0

        // Titelzeile
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color:  "transparent"

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                spacing: 8

                Text {
                    text: qsTr("Makro-Bibliothek")
                    font.pixelSize: 15; font.weight: Font.Medium
                    color: root.theme.textPrimary
                    Layout.fillWidth: true
                }
                Button {
                    text: "×"
                    flat: true; implicitWidth: 28; implicitHeight: 28
                    contentItem: Text {
                        text: parent.text; color: root.theme.textMuted
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? root.theme.hover : "transparent"; radius: 4
                    }
                    onClicked: root.reject()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // Zweispaltige Hauptfläche
        RowLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            // ── Linke Spalte: Suche + Liste ───────────────────
            Rectangle {
                Layout.preferredWidth: 240
                Layout.fillHeight:     true
                color: root.theme.surfaceDeep

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Suchfeld
                    TextField {
                        id: suchfeld
                        Layout.fillWidth: true
                        Layout.topMargin: 8; Layout.leftMargin: 8
                        Layout.rightMargin: 8; Layout.bottomMargin: 4
                        placeholderText: qsTr("Suche...")
                        font.pixelSize:  12
                        color:           root.theme.textPrimary
                        background: Rectangle {
                            color: root.theme.inputBg; radius: 4
                            border.color: root.theme.border
                        }
                        onTextChanged: root._suchText = text
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

                    // Makro-Liste
                    ListView {
                        id: listeView
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        clip:  true
                        model: root._gefilterteListe

                        delegate: Column {
                            width: listeView.width

                            // Kategorie-Trenner (nur wenn neue Kategorie)
                            Rectangle {
                                width:  parent.width
                                height: 22
                                color:  root.theme.sidebar
                                visible: index === 0
                                      || root._gefilterteListe[index - 1].kategorie !== modelData.kategorie

                                Text {
                                    anchors {
                                        left: parent.left; leftMargin: 10
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: modelData.kategorie || qsTr("Allgemein")
                                    font.pixelSize: 10; font.weight: Font.DemiBold
                                    color: root.theme.textMuted
                                }
                            }

                            // Listeneintrag
                            Rectangle {
                                width:  parent.width
                                height: 40
                                color:  root._selId === modelData.id
                                        ? (root.theme.accent + "30")
                                        : (eintragMa.containsMouse ? root.theme.hover : "transparent")

                                // Auswahl-Akzentstreifen links
                                Rectangle {
                                    width: 3; height: parent.height
                                    visible: root._selId === modelData.id
                                    color:   root.theme.accent
                                }

                                ColumnLayout {
                                    anchors { fill: parent; leftMargin: 14; rightMargin: 6 }
                                    spacing: 1

                                    Text {
                                        text:            modelData.name
                                        font.pixelSize:  12; font.weight: Font.Medium
                                        color:           root.theme.textPrimary
                                        Layout.fillWidth: true
                                        elide:           Text.ElideRight
                                    }
                                    Text {
                                        text:           modelData.elementAnzahl + " " + qsTr("Elemente")
                                        font.pixelSize: 10; color: root.theme.textMuted
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: eintragMa; anchors.fill: parent
                                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.waehleAus(modelData)
                                }
                            }
                        }

                        // Leer-Zustand
                        Text {
                            anchors.centerIn: parent
                            visible: root._gefilterteListe.length === 0
                            text: root._liste.length === 0
                                  ? qsTr("Noch keine Makros.\nMakrokasten auf dem\nCanvas zeichnen (M).")
                                  : qsTr("Keine Treffer.")
                            color:      root.theme.textMuted
                            font.pixelSize: 11; font.italic: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            width: parent.width - 24
                        }
                    }
                }
            }

            // Trennlinie
            Rectangle { width: 1; Layout.fillHeight: true; color: root.theme.border }

            // ── Rechte Spalte: Vorschau + Editor / Platzhalter ─
            Item {
                Layout.fillWidth:  true
                Layout.fillHeight: true

                // Platzhalter (kein Makro ausgewählt)
                Text {
                    anchors.centerIn: parent
                    visible: root._selId < 0
                    text:    qsTr("Makro aus der Liste\nauswählen zum Bearbeiten.")
                    color:   root.theme.textMuted
                    font.pixelSize: 12; font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    width: parent.width - 32
                }

                // Editor-Bereich
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    visible: root._selId >= 0

                    // Vorschau-Canvas
                    Canvas {
                        id: vorschauCanvas
                        Layout.fillWidth:     true
                        Layout.preferredHeight: 160

                        onWidthChanged:  requestPaint()
                        onHeightChanged: requestPaint()

                        Connections {
                            target: root
                            function onSelElemsChanged() { vorschauCanvas.requestPaint() }
                        }

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var es = root._selElems
                            if (!es || es.length === 0) return
                            var makroW = root._selKastenBreite || 100
                            var makroH = root._selKastenHoehe  || 100
                            var pad    = 14
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
                                    var sw = Math.abs(x2 - x1); var sh = Math.abs(y2 - y1)
                                    var cx = (x1 + x2) / 2;     var cy = (y1 + y2) / 2
                                    ctx.strokeRect(cx - sw / 2, cy - sh / 2, sw, sh)
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

                    // Formular
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 16
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: qsTr("Name"); font.pixelSize: 11; color: root.theme.textMuted }
                            TextField {
                                id: tfName
                                Layout.fillWidth: true; font.pixelSize: 13
                                color: root.theme.textPrimary
                                background: Rectangle {
                                    color: root.theme.inputBg; radius: 4
                                    border.color: root.theme.border
                                }
                                onTextEdited: root._geaendert = true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: qsTr("Kategorie"); font.pixelSize: 11; color: root.theme.textMuted }
                            TextField {
                                id: tfKat
                                Layout.fillWidth: true; font.pixelSize: 13
                                placeholderText: qsTr("z. B. Antriebe")
                                color: root.theme.textPrimary
                                background: Rectangle {
                                    color: root.theme.inputBg; radius: 4
                                    border.color: root.theme.border
                                }
                                onTextEdited: root._geaendert = true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: qsTr("Beschreibung"); font.pixelSize: 11; color: root.theme.textMuted }
                            TextField {
                                id: tfBeschr
                                Layout.fillWidth: true; font.pixelSize: 13
                                placeholderText: qsTr("optional")
                                color: root.theme.textPrimary
                                background: Rectangle {
                                    color: root.theme.inputBg; radius: 4
                                    border.color: root.theme.border
                                }
                                onTextEdited: root._geaendert = true
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }

                    // Buttonzeile
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.margins:   12
                        spacing: 8

                        // Löschen / Bestätigung
                        Item {
                            Layout.fillWidth: true
                            height: 32

                            Button {
                                id: btnLoeschen
                                visible:       !root._loeschenModus
                                text:          qsTr("Löschen")
                                implicitHeight: 32; implicitWidth: 90
                                contentItem: Text {
                                    text: parent.text; color: root.theme.textMuted
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color:        parent.hovered ? "#40cc3333" : root.theme.inputBg
                                    radius:       4
                                    border.color: parent.hovered ? "#cc3333" : root.theme.border
                                }
                                onClicked: root._loeschenModus = true
                            }

                            RowLayout {
                                visible: root._loeschenModus
                                spacing: 6
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text:           qsTr("Wirklich löschen?")
                                    font.pixelSize: 11; color: "#cc3333"
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Button {
                                    text:           qsTr("Ja")
                                    implicitHeight: 28; implicitWidth: 52
                                    contentItem: Text {
                                        text: parent.text; color: "#cc3333"
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment:   Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color:        parent.hovered ? "#30cc3333" : root.theme.inputBg
                                        radius:       4
                                        border.color: "#cc3333"
                                    }
                                    onClicked: {
                                        db.makroLoeschen(root._selId)
                                        root._selId         = -1
                                        root._loeschenModus = false
                                        root.laden()
                                        root.makroListeGeaendert()
                                    }
                                }
                                Button {
                                    text:           qsTr("Abbruch")
                                    implicitHeight: 28; implicitWidth: 62
                                    contentItem: Text {
                                        text: parent.text; color: root.theme.textMuted
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment:   Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                                        radius:       4
                                        border.color: root.theme.border
                                    }
                                    onClicked: root._loeschenModus = false
                                }
                            }
                        }

                        Button {
                            id: btnSpeichern
                            text:           qsTr("Speichern")
                            implicitHeight: 32; implicitWidth: 100
                            enabled:        tfName.text.trim().length > 0 && root._geaendert
                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment:   Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.enabled
                                       ? (parent.hovered ? root.theme.accent : root.theme.inputBg)
                                       : root.theme.inputBg
                                radius:       4
                                border.color: parent.enabled ? root.theme.accent : root.theme.border
                            }
                            onClicked: {
                                var n = tfName.text.trim()
                                var b = tfBeschr.text.trim()
                                var k = tfKat.text.trim()
                                db.makroMetaAktualisieren(root._selId, n, b, k)
                                root._geaendert = false
                                root.laden()
                                root.makroListeGeaendert()
                            }
                        }
                    }
                }
            }
        }
    }
}
