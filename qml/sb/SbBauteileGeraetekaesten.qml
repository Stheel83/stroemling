import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Gerätekästen-Abschnitt im BAUTEILE-Bereich des Seitenbaums — ausgelagert
// aus SeitenBaumBauteilePanel.qml (REFACTOR-QML-03).
Column {
    id: root
    required property var panel
    required property var theme

    visible: panel._aktiveTab === "alles" || panel._aktiveTab === "sonstiges"
    width: parent.width
    property var _gkFlachListe: {
        var _v = panel._gkVersion
        return panel.visible && panel.projektId >= 0
            ? db.geraetekastenListeMitPos(panel.projektId)
            : []
    }

    property var _gkGruppiert: {
        var gruppen = {}
        var reihenfolge = []
        var liste = root._gkFlachListe
        for (var i = 0; i < liste.length; i++) {
            var gk = liste[i]
            var bmk = gk.bmk || ""
            if (!gruppen[bmk]) {
                gruppen[bmk] = { bmk: bmk, bezeichnung: gk.bezeichnung || "", instanzen: [] }
                reihenfolge.push(bmk)
            }
            gruppen[bmk].instanzen.push(gk)
        }
        return reihenfolge.map(function(b) { return gruppen[b] })
    }

    Rectangle {
        width: parent.width; height: 1; color: root.theme.divider
    }

    Rectangle {
        width: parent.width; height: 28; color: "transparent"
        visible: parent._gkGruppiert.length === 0
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
            spacing: 6
            Text { text: "📐"; font.pixelSize: 11; opacity: 0.35; color: root.theme.textMuted }
            Text {
                text: qsTr("Geraetekaesten – mit G zeichnen")
                font.pixelSize: 11; color: root.theme.textMuted; opacity: 0.6
                Layout.fillWidth: true
            }
        }
    }

    Repeater {
        model: parent._gkGruppiert
        delegate: Column {
            id: gkGruppeItem
            width: parent.width
            property string gkBmk:  modelData.bmk
            property string gkBez:  modelData.bezeichnung
            property var    gkInst: modelData.instanzen
            property bool   auf:    panel._gkAufgeklappt[gkBmk] === true

            // Gruppen-Kopfzeile (BMK)
            Rectangle {
                width: parent.width; height: 32
                color: gkKopfMA.containsMouse ? root.theme.hover : "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                    spacing: 5
                    Text { text: gkGruppeItem.auf ? "▾" : "▸"; font.pixelSize: 9; color: root.theme.textMuted }
                    Text { text: "📐"; font.pixelSize: 12; color: root.theme.textMuted }
                    Text {
                        text: gkGruppeItem.gkBmk
                              + (gkGruppeItem.gkBez ? "  " + gkGruppeItem.gkBez : "")
                        font.pixelSize: 12; color: root.theme.textPrimary
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        visible: gkGruppeItem.gkInst.length > 1
                        text: gkGruppeItem.gkInst.length
                        font.pixelSize: 10; color: root.theme.textMuted
                    }
                }
                MouseArea {
                    id: gkKopfMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var b = gkGruppeItem.gkBmk
                        var auf = Object.assign({}, panel._gkAufgeklappt)
                        auf[b] = !auf[b]
                        panel._gkAufgeklappt = auf
                    }
                }
            }

            // Instanzen-Liste
            Column {
                width: parent.width
                visible: gkGruppeItem.auf

                Repeater {
                    model: gkGruppeItem.gkInst
                    delegate: Rectangle {
                        id: gkInstDelegate
                        width: parent.width; height: 26
                        color: panel._highlightGkId === gkd.id
                            ? root.theme.activeItem
                            : (gkInstMA.containsMouse ? root.theme.hover : "transparent")
                        property var gkd: modelData
                        property var  svTyp: gkd.bauteilId > 0 ? db.steckverbinderTypLaden(gkd.bauteilId) : ({})
                        property bool istSteckverbinder: svTyp && svTyp.id > 0

                        MouseArea {
                            id: gkInstMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.ArrowCursor
                        }

                        // Positions-Picker: Steckverbinder-Kontakte dieser Instanz platzieren
                        // (analog kontaktPicker der GERÄTE-Sektion, → PLATZIER-WEG-VEREINHEITLICHUNG-01 Teil 2)
                        Popup {
                            id: svPosPicker
                            x: 10; y: gkInstDelegate.height
                            width: 220
                            padding: 4
                            background: Rectangle {
                                color: root.theme.surface; radius: 4
                                border.color: root.theme.border
                            }

                            property var _positionen: []
                            onOpened: svPosPicker._positionen = gkInstDelegate.istSteckverbinder
                                ? db.steckverbinderPositionenLaden(gkInstDelegate.svTyp.id) : []

                            Column {
                                width: parent.width
                                spacing: 1

                                Repeater {
                                    model: svPosPicker._positionen
                                    delegate: Rectangle {
                                        width: parent.width; height: 26; radius: 3
                                        property bool platziert: db.steckverbinderPositionIstPlatziert(modelData.id)
                                        color: (!platziert && svPosMA.containsMouse) ? root.theme.activeItem : "transparent"
                                        opacity: platziert ? 0.5 : 1.0
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            Text {
                                                text: (platziert ? "✓ " : "") + qsTr("Pos. %1: %2")
                                                      .arg(modelData.positionNr).arg(modelData.bezeichnung)
                                                font.pixelSize: 11
                                                color: platziert ? root.theme.textMuted : root.theme.textPrimary
                                                Layout.fillWidth: true; elide: Text.ElideRight
                                            }
                                        }
                                        MouseArea {
                                            id: svPosMA; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: platziert ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            enabled: !platziert
                                            onClicked: {
                                                svPosPicker.close()
                                                var symbolId = modelData.geschlecht === "stift" ? "stecker" : "buchse"
                                                panel.steckverbinderKontaktPlatzieren(
                                                    gkInstDelegate.gkd.id, modelData.id, symbolId,
                                                    gkGruppeItem.gkBmk)
                                            }
                                        }
                                    }
                                }
                                Text {
                                    visible: svPosPicker._positionen.length === 0
                                    width: parent.width; padding: 8
                                    text: qsTr("Keine Positionen definiert.")
                                    font.pixelSize: 10; font.italic: true
                                    color: root.theme.textMuted; wrapMode: Text.WordWrap
                                }
                            }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                            spacing: 4
                            Text {
                                text: gkd.blattnr || ""
                                font.pixelSize: 11; color: root.theme.textSecondary
                                elide: Text.ElideRight
                            }
                            Text {
                                text: gkd.seiteBez || ""
                                font.pixelSize: 10; color: root.theme.textMuted
                                elide: Text.ElideRight; Layout.fillWidth: true
                                Layout.maximumWidth: 80
                            }
                            // Kontakt-Picker öffnen
                            Rectangle {
                                visible: gkInstDelegate.istSteckverbinder
                                implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                color: svPlusMA.containsMouse ? root.theme.activeItemAlt : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"; font.pixelSize: 14; font.bold: true
                                    color: root.theme.accent
                                }
                                ToolTip.visible: svPlusMA.containsMouse
                                ToolTip.text:    qsTr("Kontakt platzieren")
                                ToolTip.delay:   400
                                MouseArea {
                                    id: svPlusMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { mouse.accepted = true; svPosPicker.open() }
                                }
                            }
                            // Alle offenen Positionen sequentiell platzieren
                            Rectangle {
                                visible: gkInstDelegate.istSteckverbinder
                                implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                color: svSeqMA.containsMouse ? root.theme.activeItemAlt : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "⇥"; font.pixelSize: 12
                                    color: root.theme.accent
                                }
                                ToolTip.visible: svSeqMA.containsMouse
                                ToolTip.text:    qsTr("Alle offenen Positionen nacheinander platzieren")
                                ToolTip.delay:   400
                                MouseArea {
                                    id: svSeqMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var positionen = db.steckverbinderPositionenLaden(gkInstDelegate.svTyp.id)
                                        var queue = []
                                        for (var i = 0; i < positionen.length; i++) {
                                            var pos = positionen[i]
                                            if (db.steckverbinderPositionIstPlatziert(pos.id)) continue
                                            queue.push({
                                                geraetekastenId: gkInstDelegate.gkd.id,
                                                positionId:      pos.id,
                                                symbolId:        pos.geschlecht === "stift" ? "stecker" : "buchse",
                                                bmk:             gkGruppeItem.gkBmk
                                            })
                                        }
                                        if (queue.length > 0)
                                            panel.steckverbinderSequentiellStarten(JSON.stringify(queue))
                                    }
                                }
                            }
                            Rectangle {
                                implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                color: gkSprungMA.containsMouse ? root.theme.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent; text: "→"; font.pixelSize: 11
                                    color: gkSprungMA.containsMouse ? "#ffffff" : root.theme.accent
                                }
                                MouseArea {
                                    id: gkSprungMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var d = gkd
                                        panel.sprungAngefordert(d.seiteId, d.blattnr,
                                                               d.seiteBez, d.weltX, d.weltY)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
