import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Geräte-Abschnitt im BAUTEILE-Bereich des Seitenbaums — ausgelagert aus
// SeitenBaumBauteilePanel.qml (REFACTOR-QML-03).
Column {
    id: root
    required property var panel
    required property var theme

    visible: panel._aktiveTab === "alles" || panel._aktiveTab === "sonstiges"
    width: parent.width
    property var _geraeteListe: {
        var _v = panel._geraeteVersion;
        return panel.visible && panel.projektId >= 0
            ? db.betriebsmittelListe(panel.projektId).filter(function(b) { return b.anzahl > 0 })
            : [];
    }

    Rectangle {
        width: parent.width; height: 1; color: root.theme.divider
        visible: parent._geraeteListe.length > 0
    }

    Repeater {
        model: parent._geraeteListe
        delegate: Column {
            id: geraetItem
            width: parent.width
            property int    bmId:        modelData.id
            property string bmKz:        modelData.kz
            property string bmBez:       modelData.bezeichnung || ""
            property bool   aufgeklappt: panel._geraeteAufgeklappt[bmId] === true

            // Betriebsmittel-Zeile
            Rectangle {
                id: geraetZeile
                width: parent.width; height: 32
                color: geraetMA.containsMouse ? root.theme.hover : "transparent"

                // Picker-Popup: Anschlussbelegung (wenn vorhanden) oder generische Symbolliste
                Popup {
                    id: kontaktPicker
                    x: 10; y: geraetZeile.height
                    width: 220
                    padding: 4
                    background: Rectangle {
                        color: root.theme.surface; radius: 4
                        border.color: root.theme.border
                    }

                    property var _anschluesse: []
                    property bool _hatAnschluesse: _anschluesse.length > 0

                    onOpened: {
                        var bid = db.betriebsmittelBauteilId(geraetItem.bmId)
                        _anschluesse = bid > 0 ? db.bauteilKontaktListe(bid) : []
                    }

                    Column {
                        width: parent.width
                        spacing: 1

                        // ── Kontaktbelegung aus DB ───────────────────
                        Repeater {
                            model: kontaktPicker._hatAnschluesse ? kontaktPicker._anschluesse : []
                            delegate: Rectangle {
                                width: parent.width; height: 28; radius: 3
                                color: aMA.containsMouse ? root.theme.activeItem : "transparent"
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    Text {
                                        text: modelData.bezeichnung || modelData.symbolId
                                        font.pixelSize: 11; font.weight: Font.Medium
                                        color: root.theme.accent
                                        Layout.preferredWidth: 60
                                    }
                                    Text {
                                        text: modelData.symbolId
                                        font.pixelSize: 10; color: root.theme.textMuted
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    id: aMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        kontaktPicker.close()
                                        var pb = {}
                                        try { pb = JSON.parse(modelData.pinBez || "{}") } catch(e) {}
                                        panel.betriebsmittelKontaktPlatzieren(
                                            geraetItem.bmId,
                                            modelData.symbolId,
                                            geraetItem.bmKz,
                                            pb
                                        )
                                    }
                                }
                            }
                        }

                        // ── Generische Relais-Fallback-Liste ──────────
                        // Nur wenn das Bauteil keine eigenen bauteil_kontakt-
                        // Einträge hat (sonst nur verwirrender Ballast, z.B.
                        // bei einer SPS-Karte mit eigenem Kanal-Katalog).
                        Repeater {
                            model: kontaktPicker._hatAnschluesse ? [] : [
                                { id: "schliesser",  name: qsTr("Schließer (NO)") },
                                { id: "oeffner",     name: qsTr("Öffner (NC)") },
                                { id: "wechsler",    name: qsTr("Wechsler") },
                                { id: "taster_no",   name: qsTr("Taster (NO)") },
                                { id: "taster_nc",   name: qsTr("Taster (NC)") },
                                { id: "bimetall_nc", name: qsTr("Bimetall-Kontakt (NC)") }
                            ]
                            delegate: Rectangle {
                                width: parent.width; height: 28; radius: 3
                                color: pickerMA.containsMouse ? root.theme.activeItem : "transparent"
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    Text {
                                        text: modelData.name
                                        font.pixelSize: 11; color: root.theme.textPrimary
                                        Layout.fillWidth: true
                                    }
                                }
                                MouseArea {
                                    id: pickerMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        kontaktPicker.close()
                                        panel.betriebsmittelKontaktPlatzieren(
                                            geraetItem.bmId,
                                            modelData.id,
                                            geraetItem.bmKz,
                                            {}
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // Hover-MA zuerst → RowLayout-Kinder liegen darüber
                MouseArea {
                    id: geraetMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var bid = geraetItem.bmId
                        var auf = Object.assign({}, panel._geraeteAufgeklappt)
                        auf[bid] = !auf[bid]
                        if (auf[bid] && panel._mitgliederCache[bid] === undefined) {
                            var c = Object.assign({}, panel._mitgliederCache)
                            c[bid] = db.betriebsmittelMitgliederMitPos(bid)
                            panel._mitgliederCache = c
                        }
                        panel._geraeteAufgeklappt = auf
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                    spacing: 5
                    Text { text: geraetItem.aufgeklappt ? "▾" : "▸"; font.pixelSize: 9; color: root.theme.textMuted }
                    Text { text: "⚙"; font.pixelSize: 12; color: root.theme.textMuted }
                    Text {
                        text: "-" + geraetItem.bmKz + (geraetItem.bmBez ? "  " + geraetItem.bmBez : "")
                        font.pixelSize: 12; color: root.theme.textPrimary
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.anzahl
                        font.pixelSize: 10; color: root.theme.textMuted
                    }
                    // Kontakt-hinzufügen-Button
                    Rectangle {
                        width: 22; height: 22; radius: 3
                        color: plusMA.containsMouse ? root.theme.activeItemAlt : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "+"; font.pixelSize: 14; font.bold: true
                            color: root.theme.accent
                        }
                        ToolTip.visible: plusMA.containsMouse
                        ToolTip.text:    qsTr("Kontakt platzieren")
                        ToolTip.delay:   400
                        MouseArea {
                            id: plusMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { mouse.accepted = true; kontaktPicker.open() }
                        }
                    }
                }
            }

            // Mitglieder-Liste
            Column {
                width: parent.width
                visible: geraetItem.aufgeklappt
                property var mitglieder: panel._mitgliederCache[geraetItem.bmId] || []

                Repeater {
                    model: parent.mitglieder
                    delegate: Rectangle {
                        width: parent.width; height: 26
                        color: mitgliedMA.containsMouse ? root.theme.hover : "transparent"
                        property var md: modelData

                        // Hover-MA zuerst → Sprung-Button liegt darüber
                        MouseArea {
                            id: mitgliedMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.ArrowCursor
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                            spacing: 4
                            Text {
                                text: md.istHauptfunktion ? "★" : "◇"
                                font.pixelSize: 9
                                color: md.istHauptfunktion ? root.theme.accent : root.theme.textMuted
                            }
                            Text {
                                text: md.symbolId || ""
                                font.pixelSize: 11; color: root.theme.textSecondary
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: md.blattnr || ""
                                font.pixelSize: 10; color: root.theme.textMuted
                                elide: Text.ElideRight; Layout.minimumWidth: 0
                            }
                            Rectangle {
                                implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                color: sprungGMA.containsMouse ? root.theme.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent; text: "→"; font.pixelSize: 11
                                    color: sprungGMA.containsMouse ? "#ffffff" : root.theme.accent
                                }
                                MouseArea {
                                    id: sprungGMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var d = md
                                        if (d && d.seiteId > 0)
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
