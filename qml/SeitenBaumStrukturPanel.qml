import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ============================================================
// SeitenBaumStrukturPanel.qml
// Zeigt ALLE Anlagen und Orte (auch ohne Seiten) als Übersicht.
// Die Seitenanzahl jedes Ortes wird als Badge angezeigt.
// Aktionen: Anlage/Ort anlegen, bearbeiten, löschen.
//
// Kommunikation:
//   Signale → SeitenBaum öffnet die vorhandenen Dialoge
//   Löschen → intern per Bestätigungsdialog
// ============================================================

Item {
    id: root

    property var theme
    property int projektId: -1

    signal anlageAnlegenAngefordert()
    signal anlageBearbeitenAngefordert(int id, string kuerzel, string bez, string uo)
    signal ortAnlegenAngefordert(int anlageId)
    signal ortSeiteAnlegenAngefordert(int ortId)
    signal ortBearbeitenAngefordert(int id, string kuerzel, string bez, string uo)

    property var _daten: []
    property var _expanded: ({})     // anlageId → bool (default: true = aufgeklappt)
    property int _expandedVersion: 0 // Zähler zum Triggern von Bindings

    function aktualisieren() {
        _daten = seitenModel.strukturListe()
    }

    function toggleAnlage(anlageId) {
        var e = Object.assign({}, _expanded)
        e[anlageId] = (_expanded[anlageId] !== false) ? false : true
        _expanded = e
        _expandedVersion++
    }

    onProjektIdChanged: { if (projektId >= 0) Qt.callLater(aktualisieren) }

    Connections {
        target: seitenModel
        function onModelReset() { Qt.callLater(root.aktualisieren) }
    }

    // ── Löschen-Bestätigungsdialog ──────────────────────────
    Dialog {
        id: dlgLoeschen
        anchors.centerIn: Overlay.overlay
        title: qsTr("Löschen bestätigen")
        modal: true

        property int    loeschTyp:         -1
        property int    loeschId:          -1
        property string loeschName:        ""
        property int    loeschSeitenAnzahl: 0

        background: Rectangle {
            color: root.theme.sidebar; radius: 6
            border.color: root.theme.border; border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 10
            Text {
                Layout.maximumWidth: 320
                wrapMode: Text.Wrap
                font.pixelSize: 13
                color: dlgLoeschen.loeschSeitenAnzahl > 0 ? "#cc3300" : root.theme.textPrimary
                text: dlgLoeschen.loeschSeitenAnzahl > 0
                    ? qsTr("\"%1\" löschen?\nEnthält %2 Seite(n), die ebenfalls gelöscht werden!")
                        .arg(dlgLoeschen.loeschName).arg(dlgLoeschen.loeschSeitenAnzahl)
                    : qsTr("\"%1\" wirklich löschen?").arg(dlgLoeschen.loeschName)
            }
        }

        footer: RowLayout {
            spacing: 8; Layout.margins: 12
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen")
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4;
                                        border.color: root.theme.border; border.width: 1 }
                onClicked: dlgLoeschen.reject()
            }
            Button {
                text: qsTr("Löschen")
                contentItem: Text { text: parent.text; color: "#ffffff"; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? "#cc1100" : "#bb2200"; radius: 4 }
                onClicked: dlgLoeschen.accept()
            }
        }

        onAccepted: seitenModel.loeschen(loeschTyp, loeschId)
    }

    clip: true

    ScrollView {
        anchors.fill: parent
        clip: true

            Column {
                id: strukturCol
                width: parent.width

                // Leer-Zustand
                Item {
                    visible: root._daten.length === 0
                    width: strukturCol.width; height: 52
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Keine Anlagen vorhanden.")
                        color: root.theme.textMuted; font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // ── Anlagen ───────────────────────────────────
                Repeater {
                    model: root._daten

                    delegate: Column {
                        id: anlageDelegate
                        width: strukturCol.width

                        property var  anlage:     modelData
                        property bool isExpanded: {
                            root._expandedVersion  // Binding-Abhängigkeit
                            return root._expanded[anlage.anlageId] !== false
                        }

                        // ── Anlage-Zeile ──
                        Rectangle {
                            id: anlageRow
                            width: parent.width; height: 32
                            color: anlageHover.hovered ? root.theme.hover : root.theme.surfaceDeep

                            HoverHandler { id: anlageHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: anlageDelegate.anlage.orte.length > 0
                                             ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (anlageDelegate.anlage.orte.length > 0)
                                        root.toggleAnlage(anlageDelegate.anlage.anlageId)
                                }
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                                spacing: 4

                                // Expand-Pfeil
                                Text {
                                    text: anlageDelegate.isExpanded ? "▾" : "▸"
                                    color: root.theme.textMuted; font.pixelSize: 9
                                    visible: anlageDelegate.anlage.orte.length > 0
                                    width: 10
                                }
                                Item { width: anlageDelegate.anlage.orte.length === 0 ? 14 : 0 }

                                // = Kürzel
                                Text {
                                    text: "=" + anlageDelegate.anlage.anlageKuerzel
                                    color: root.theme.accent
                                    font.bold: true; font.pixelSize: 12; font.family: "monospace"
                                }

                                // Bezeichnung
                                Text {
                                    text: anlageDelegate.anlage.anlageBez
                                    color: root.theme.textPrimary; font.pixelSize: 12
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }

                                // Seitenanzahl-Badge
                                Rectangle {
                                    visible: anlageDelegate.anlage.seitenAnzahl > 0
                                    width:  anlageBadgeText.implicitWidth + 8
                                    height: 16; radius: 8
                                    color: root.theme.badge
                                    Text {
                                        id: anlageBadgeText
                                        anchors.centerIn: parent
                                        text: anlageDelegate.anlage.seitenAnzahl + " S"
                                        color: root.theme.accent; font.pixelSize: 9
                                    }
                                }

                                // Aktions-Buttons (nur bei Hover sichtbar)
                                Row {
                                    spacing: 2
                                    visible: anlageHover.hovered

                                    Button {
                                        width: 24; height: 24; flat: true
                                        contentItem: Text {
                                            text: "+"; color: root.theme.accent; font.pixelSize: 16
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            color: parent.hovered ? root.theme.activeItemAlt : "transparent"
                                            radius: 4
                                        }
                                        ToolTip.visible: hovered; ToolTip.delay: 600
                                        ToolTip.text: qsTr("Neuen Ort anlegen")
                                        onClicked: root.ortAnlegenAngefordert(anlageDelegate.anlage.anlageId)
                                    }

                                    Button {
                                        width: 24; height: 24; flat: true
                                        contentItem: Text {
                                            text: "✎"; color: root.theme.accent; font.pixelSize: 13
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            color: parent.hovered ? root.theme.activeItemAlt : "transparent"
                                            radius: 4
                                        }
                                        ToolTip.visible: hovered; ToolTip.delay: 600
                                        ToolTip.text: qsTr("Anlage bearbeiten")
                                        onClicked: root.anlageBearbeitenAngefordert(
                                            anlageDelegate.anlage.anlageId,
                                            anlageDelegate.anlage.anlageKuerzel,
                                            anlageDelegate.anlage.anlageBez,
                                            anlageDelegate.anlage.anlageUO
                                        )
                                    }

                                    Button {
                                        width: 24; height: 24; flat: true
                                        contentItem: Text {
                                            text: "✕"; color: "#cc3300"; font.pixelSize: 12
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle {
                                            color: parent.hovered ? root.theme.activeItemAlt : "transparent"
                                            radius: 4
                                        }
                                        ToolTip.visible: hovered; ToolTip.delay: 600
                                        ToolTip.text: qsTr("Anlage löschen")
                                        onClicked: {
                                            dlgLoeschen.loeschTyp = 0   // BaumKnoten::Anlage
                                            dlgLoeschen.loeschId   = anlageDelegate.anlage.anlageId
                                            dlgLoeschen.loeschName = "=" + anlageDelegate.anlage.anlageKuerzel
                                            dlgLoeschen.loeschSeitenAnzahl = anlageDelegate.anlage.seitenAnzahl
                                            dlgLoeschen.open()
                                        }
                                    }
                                }
                            }
                        }

                        // ── Ort-Zeilen (nur wenn Anlage aufgeklappt) ──
                        Repeater {
                            model: anlageDelegate.isExpanded ? anlageDelegate.anlage.orte : []

                            delegate: Rectangle {
                                id: ortRow
                                width: anlageDelegate.width; height: 28
                                color: ortHover.hovered ? root.theme.hover : root.theme.surface

                                property var ort: modelData

                                HoverHandler { id: ortHover }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 26; rightMargin: 4 }
                                    spacing: 4

                                    // + Kürzel
                                    Text {
                                        text: "+" + ortRow.ort.ortKuerzel
                                        color: root.theme.accentLight
                                        font.bold: true; font.pixelSize: 11; font.family: "monospace"
                                    }

                                    // Bezeichnung
                                    Text {
                                        text: ortRow.ort.ortBez
                                        color: root.theme.textSecondary; font.pixelSize: 11
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }

                                    // Seitenanzahl
                                    Text {
                                        text: ortRow.ort.seitenAnzahl > 0
                                              ? ortRow.ort.seitenAnzahl + " S" : "—"
                                        color: ortRow.ort.seitenAnzahl > 0
                                               ? root.theme.accent : root.theme.textMuted
                                        font.pixelSize: 10
                                        font.bold: ortRow.ort.seitenAnzahl > 0
                                    }

                                    // Aktions-Buttons (Hover)
                                    Row {
                                        spacing: 2
                                        visible: ortHover.hovered

                                        Button {
                                            width: 24; height: 24; flat: true
                                            contentItem: Text {
                                                text: "+"; color: "#44aa66"; font.pixelSize: 16
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle {
                                                color: parent.hovered ? root.theme.activeItemAlt : "transparent"
                                                radius: 4
                                            }
                                            ToolTip.visible: hovered; ToolTip.delay: 600
                                            ToolTip.text: qsTr("Neue Seite in diesem Ort anlegen")
                                            onClicked: root.ortSeiteAnlegenAngefordert(ortRow.ort.ortId)
                                        }

                                        Button {
                                            width: 24; height: 24; flat: true
                                            contentItem: Text {
                                                text: "✎"; color: root.theme.accent; font.pixelSize: 13
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle {
                                                color: parent.hovered ? root.theme.activeItemAlt : "transparent"
                                                radius: 4
                                            }
                                            ToolTip.visible: hovered; ToolTip.delay: 600
                                            ToolTip.text: qsTr("Ort bearbeiten")
                                            onClicked: root.ortBearbeitenAngefordert(
                                                ortRow.ort.ortId,
                                                ortRow.ort.ortKuerzel,
                                                ortRow.ort.ortBez,
                                                ortRow.ort.ortUO
                                            )
                                        }

                                        Button {
                                            width: 24; height: 24; flat: true
                                            contentItem: Text {
                                                text: "✕"; color: "#cc3300"; font.pixelSize: 12
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle {
                                                color: parent.hovered ? root.theme.activeItemAlt : "transparent"
                                                radius: 4
                                            }
                                            ToolTip.visible: hovered; ToolTip.delay: 600
                                            ToolTip.text: qsTr("Ort löschen")
                                            onClicked: {
                                                dlgLoeschen.loeschTyp = 1   // BaumKnoten::Ort
                                                dlgLoeschen.loeschId   = ortRow.ort.ortId
                                                dlgLoeschen.loeschName = "+" + ortRow.ort.ortKuerzel
                                                dlgLoeschen.loeschSeitenAnzahl = ortRow.ort.seitenAnzahl
                                                dlgLoeschen.open()
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
    }
