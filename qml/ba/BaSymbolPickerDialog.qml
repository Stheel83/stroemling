import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ============================================================
// BaSymbolPickerDialog – Symbol für ein Bauteil auswählen
// Suchfeld + kategorisierte Liste mit Canvas-Vorschau.
// Nutzung:
//   dlg.aktuelleSymbolId = "lampe"
//   dlg.open()
//   dlg.onAccepted: bauteilModel.symbolSpeichern(id, dlg.ausgewaehltId)
// ============================================================

Dialog {
    id: root

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 500; height: 560
    padding: 0

    required property var theme

    property string aktuelleSymbolId: ""   // vor open() setzen
    property string ausgewaehltId:    ""   // Ergebnis nach accept()

    property var    _alleSymbole:     []
    property string _selSymbolId:     ""

    title: qsTr("Symbol wählen")

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6
    }

    // ── Hilfsfunktion: Primitiv-Rendering (analog SymbolPalette) ──
    function drawSymbol(ctx, symbolId, w, h) {
        var prims = symbolDefinitionModel.primitiveFuerSymbol(symbolId)
        for (var i = 0; i < prims.length; i++) {
            var p = prims[i]
            ctx.setLineDash([])
            switch (p.typ) {
                case "linie":
                    ctx.beginPath()
                    ctx.moveTo(p.x1 * w, p.y1 * h)
                    ctx.lineTo(p.x2 * w, p.y2 * h)
                    ctx.stroke()
                    break
                case "rechteck":
                    ctx.strokeRect(p.x1 * w, p.y1 * h, (p.x2 - p.x1) * w, (p.y2 - p.y1) * h)
                    break
                case "kreis_offen":
                    ctx.beginPath()
                    ctx.arc(p.x1 * w, p.y1 * h, p.radius * w, 0, 2 * Math.PI)
                    ctx.stroke()
                    break
                case "kreis_gefuellt":
                    ctx.save(); ctx.fillStyle = ctx.strokeStyle
                    ctx.beginPath()
                    ctx.arc(p.x1 * w, p.y1 * h, p.radius * w, 0, 2 * Math.PI)
                    ctx.fill(); ctx.restore()
                    break
                case "bogen":
                    ctx.beginPath()
                    ctx.arc(p.x1 * w, p.y1 * h, p.radius * w,
                            p.winkel_von * Math.PI / 180,
                            p.winkel_bis * Math.PI / 180,
                            p.bogen_gegen_uhrzeiger)
                    ctx.stroke()
                    break
                case "text":
                    ctx.save(); ctx.fillStyle = ctx.strokeStyle
                    ctx.font         = (p.schrift_fett ? "bold " : "") +
                                       Math.round(p.schrift_relativ * h) + "px sans-serif"
                    ctx.textAlign    = p.text_align    || "center"
                    ctx.textBaseline = p.text_baseline || "middle"
                    ctx.fillText(p.text_inhalt, p.x1 * w, p.y1 * h)
                    ctx.restore()
                    break
                case "dreieck_gefuellt":
                    ctx.save(); ctx.fillStyle = ctx.strokeStyle
                    ctx.beginPath()
                    ctx.moveTo(p.x1 * w, p.y1 * h)
                    ctx.lineTo(p.x2 * w, p.y2 * h)
                    ctx.lineTo(p.x3 * w, p.y3 * h)
                    ctx.closePath(); ctx.fill(); ctx.restore()
                    break
            }
        }
    }

    function _filtern(text) {
        symbolModel.clear()
        var t = text.toLowerCase().trim()
        for (var i = 0; i < root._alleSymbole.length; i++) {
            var s = root._alleSymbole[i]
            if (!t || s.name.toLowerCase().indexOf(t) >= 0
                   || s.id.toLowerCase().indexOf(t) >= 0
                   || (s.kategorie || "").toLowerCase().indexOf(t) >= 0) {
                symbolModel.append({
                    symbolId:  s.id,
                    symName:   s.name,
                    kategorie: s.kategorie || qsTr("Sonstige")
                })
            }
        }
        // Selektion beibehalten wenn noch sichtbar
        if (root._selSymbolId !== "") {
            for (var j = 0; j < symbolModel.count; j++) {
                if (symbolModel.get(j).symbolId === root._selSymbolId) return
            }
            root._selSymbolId = ""
        }
    }

    onOpened: {
        root._alleSymbole  = symbolDefinitionModel.alleSymbole()
        root._selSymbolId  = root.aktuelleSymbolId
        suchfeld.text      = ""
        root._filtern("")
        // ListView zum selektierten Element scrollen
        for (var i = 0; i < symbolModel.count; i++) {
            if (symbolModel.get(i).symbolId === root._selSymbolId) {
                liste.positionViewAtIndex(i, ListView.Center)
                break
            }
        }
    }

    // ── Internes Datenmodell ──────────────────────────────────
    ListModel { id: symbolModel }

    contentItem: ColumnLayout {
        spacing: 0

        // Titelzeile
        Rectangle {
            Layout.fillWidth: true; height: 48; color: root.theme.surface
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                Text {
                    text: root.title; font.pixelSize: 15; font.weight: Font.Medium
                    color: root.theme.textPrimary; Layout.fillWidth: true
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // Suchfeld
        Rectangle {
            Layout.fillWidth: true; height: 44; color: root.theme.surface
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8
                Text { text: "\u{1F50D}"; font.pixelSize: 14; color: root.theme.textMuted }
                TextField {
                    id: suchfeld
                    Layout.fillWidth: true
                    placeholderText: qsTr("Name, Kategorie oder ID …")
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    color: root.theme.textPrimary; font.pixelSize: 13
                    onTextChanged: root._filtern(text)
                    Component.onCompleted: forceActiveFocus()
                }
                Button {
                    visible: suchfeld.text.length > 0; text: "×"
                    flat: true; implicitWidth: 28; implicitHeight: 28
                    contentItem: Text { text: parent.text; color: root.theme.textMuted; font.pixelSize: 16;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4 }
                    onClicked: suchfeld.text = ""
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }

        // Eintrag "kein Symbol"
        Rectangle {
            Layout.fillWidth: true; height: 40
            color: root._selSymbolId === ""
                   ? root.theme.activeItem
                   : (keinHover.hovered ? root.theme.hover : "transparent")
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                Rectangle { width: 40; height: 32; color: "transparent" }
                Text {
                    text: qsTr("(kein Symbol)")
                    color: root.theme.textMuted; font.pixelSize: 12; font.italic: true
                    Layout.fillWidth: true
                }
            }
            HoverHandler { id: keinHover }
            TapHandler { onTapped: root._selSymbolId = "" }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }

        // Symbolliste mit Kategorie-Trennern
        ListView {
            id: liste
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: symbolModel
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            section.property: "kategorie"
            section.delegate: Rectangle {
                width: liste.width; height: 26
                color: root.theme.sidebar
                Text {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
                    text: section
                    font.pixelSize: 11; font.weight: Font.Medium
                    color: root.theme.accent
                }
            }

            Text {
                anchors.centerIn: parent
                visible: liste.count === 0
                text: qsTr("Keine Symbole gefunden.")
                color: root.theme.textMuted; font.pixelSize: 12; font.italic: true
            }

            delegate: Rectangle {
                width: liste.width; height: 44
                color: root._selSymbolId === model.symbolId
                       ? root.theme.activeItem
                       : (rowHover.hovered ? root.theme.hover : "transparent")

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    // Symbol-Vorschau
                    Canvas {
                        id: vorschau
                        Layout.preferredWidth: 40; Layout.preferredHeight: 32
                        property string symId: model.symbolId
                        property string selId: root._selSymbolId

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = (symId === root._selSymbolId)
                                ? root.theme.accent : root.theme.textSubtle
                            ctx.lineWidth = 1.5
                            root.drawSymbol(ctx, symId, width, height)
                        }
                        onSymIdChanged: requestPaint()
                        onSelIdChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                    }

                    // Name + ID
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: model.symName
                            color: root.theme.textPrimary; font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        Text {
                            text: model.symbolId
                            color: root.theme.textMuted; font.pixelSize: 10
                        }
                    }
                }

                HoverHandler { id: rowHover }
                TapHandler {
                    onTapped: root._selSymbolId = model.symbolId
                    onDoubleTapped: {
                        root._selSymbolId  = model.symbolId
                        root.ausgewaehltId = model.symbolId
                        root.accept()
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // Buttons
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Layout.topMargin: 10; Layout.bottomMargin: 10
            Layout.leftMargin: 16; Layout.rightMargin: 16
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg;
                    radius: 4; border.color: root.theme.border }
                onClicked: root.reject()
            }
            Button {
                text: qsTr("Uebernehmen"); implicitWidth: 110; implicitHeight: 34
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.hovered ? root.theme.accent : root.theme.inputBg
                    radius: 4; border.color: root.theme.accent
                }
                onClicked: {
                    root.ausgewaehltId = root._selSymbolId
                    root.accept()
                }
            }
        }
    }
}
