import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import stroemling

ColumnLayout {
    id: root
    required property var panel
    required property var theme
    spacing: 0

    FileDialog {
        id: csvDialogKabel
        fileMode: FileDialog.SaveFile
        title: qsTr("Kabelliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.kabellisteCsvSpeichern(panel.projektId, selectedFile)
    }

    LaCsvLeiste {
        theme: root.theme
        listenName: qsTr("Kabelliste")
        anzahl: panel._kabelDaten.length
        onCsvKlick: csvDialogKabel.open()
    }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    LaSpaltenHeader { panel: root.panel; theme: root.theme; colsProp: "klCols"; leftMargin: 32 }
    Rectangle { height: 1; Layout.fillWidth: true; color: root.theme.border }

    ScrollView {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentWidth: availableWidth
        background: Rectangle { color: root.theme.surface }

        Column {
            width: parent.width

            Repeater {
                model: panel._kabelDaten
                delegate: Column {
                    width: parent.width
                    property var  kbl:        modelData
                    property bool aufgeklappt: panel._kabelExpanded[kbl.id] || false

                    // Kabel-Kopfzeile
                    Rectangle {
                        width: parent.width; height: 30
                        color: hovered ? root.theme.hover
                                       : (index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd)
                        property bool hovered: false
                        HoverHandler { onHoveredChanged: parent.hovered = hovered }

                        Row {
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 4
                            Text {
                                text: aufgeklappt ? "▼" : "▶"; font.pixelSize: 10; color: root.theme.textMuted
                                width: 20; verticalAlignment: Text.AlignVCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text { width: panel.klCols[0].w; text: kbl.bezeichnung    || "–"; font.pixelSize: 12; font.weight: Font.Medium; color: root.theme.accent;         elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: panel.klCols[1].w; text: kbl.kabeltyp       || "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: panel.klCols[2].w; text: kbl.aderzahl       > 0 ? kbl.aderzahl       : "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: panel.klCols[3].w; text: kbl.querschnittMm2 > 0 ? (kbl.querschnittMm2 + "").replace(".", ",") : "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: panel.klCols[4].w; text: kbl.laengeM        > 0 ? (kbl.laengeM + "").replace(".", ",") + " m" : "–"; font.pixelSize: 12; color: root.theme.textSecondary; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: panel.klCols[5].w; text: kbl.vonOrt         || "–"; font.pixelSize: 12; color: root.theme.borderLight;   elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: panel.klCols[6].w; text: kbl.nachOrt        || "–"; font.pixelSize: 12; color: root.theme.borderLight;   elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: panel.klCols[7].w; text: kbl.linienAnzahl   > 0 ? kbl.linienAnzahl   : "–"; font.pixelSize: 12; color: root.theme.textMuted;      elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var tmp = Object.assign({}, panel._kabelExpanded)
                                tmp[kbl.id] = !aufgeklappt
                                panel._kabelExpanded = tmp
                            }
                        }
                    }

                    // Ader-Unterzeilen
                    Column {
                        visible: aufgeklappt; width: parent.width

                        Rectangle {
                            width: parent.width; height: 22; color: root.theme.tableHeader
                            Row {
                                anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
                                Repeater {
                                    model: panel.klAderCols
                                    delegate: Text { width: modelData.w; text: modelData.header;
                                        font.pixelSize: 10; color: root.theme.textSubtle }
                                }
                            }
                        }

                        Repeater {
                            model: kbl.adern || []
                            delegate: Rectangle {
                                width: parent.width; height: 24; color: root.theme.tableEven
                                Row {
                                    anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
                                    spacing: 0
                                    Text { width: panel.klAderCols[0].w; text: modelData.nr || "–"; font.pixelSize: 11; color: root.theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                    Row {
                                        width: panel.klAderCols[1].w; spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            width: 10; height: 10; radius: 5
                                            visible: modelData.farbe !== ""
                                            color: {
                                                var m = { "BK": "#1a1a1a", "BN": "#7B3F00", "RD": "#CC0000", "OG": "#FF7700",
                                                          "YE": "#CCCC00", "GN": "#006600", "BU": "#0044AA", "VT": "#660099",
                                                          "GY": "#777777", "WH": "#CCCCCC", "PK": "#FF99BB", "GNYE": "#447700" }
                                                return m[modelData.farbe] || "#888888"
                                            }
                                            border.color: "#00000044"; border.width: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text { text: modelData.farbe || "–"; font.pixelSize: 11; color: root.theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text { width: panel.klAderCols[2].w; text: modelData.bezeichnung || "–"; font.pixelSize: 11; color: root.theme.textSecondary; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        width: panel.klAderCols[3].w
                                        text: {
                                            var s = modelData.blattnummer || ""
                                            var b = modelData.seitenBez  || ""
                                            return s ? (b ? s + " " + b : s) : "–"
                                        }
                                        font.pixelSize: 11; color: root.theme.textSecondary; elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text { width: panel.klAderCols[4].w; text: modelData.netz || "–"; font.pixelSize: 11; color: root.theme.textSecondary; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                    Text { width: panel.klAderCols[5].w; text: modelData.vonGeratPin || "–"; font.pixelSize: 11; color: modelData.vonGeratPin ? root.theme.textSecondary : root.theme.textMuted; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                    Text { width: panel.klAderCols[6].w; text: modelData.nachGeratPin || "–"; font.pixelSize: 11; color: modelData.nachGeratPin ? root.theme.textSecondary : root.theme.textMuted; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }

                        Text {
                            visible: (kbl.adern || []).length === 0
                            leftPadding: 32
                            text: qsTr("– Noch keine Adern zugeordnet –")
                            font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                            height: 24; verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.theme.border }
                }
            }

            Text {
                visible: panel._kabelDaten.length === 0
                width: parent.width; height: 60
                text: panel.projektId >= 0 ? qsTr("Keine Kabel im Projekt") : qsTr("Kein Projekt ausgewählt")
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14; color: root.theme.borderDark
            }
            Text {
                visible: panel._kabelDaten.length === 0 && panel.projektId >= 0
                width: parent.width; height: 24
                text: qsTr("Kabeldefinitionslinie im Canvas zeichnen (Werkzeug: ┄) und Kabel im Bauteilkatalog verknüpfen.")
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
            }
        }
    }
}
