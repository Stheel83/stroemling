import QtQuick
import QtQuick.Layouts

Column {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width: parent ? parent.width : 0
    spacing: 0

    property bool _expanded: true

    readonly property int freshGeid: {
        var kabelId = panel.el && panel.el.extraDaten
                      ? (panel.el.extraDaten.kabelId || 0) : 0
        if (kabelId <= 0) return 0
        var linien = db.kabelAlleLinienLaden(kabelId + (panel._refresh * 0))
        var mySeite = panel.canvas.seiteId
        for (var li = 0; li < linien.length; li++) {
            if (linien[li].seiteId === mySeite)
                return linien[li].grafikElementId || 0
        }
        return 0
    }

    // KABEL-LINIEN header (toggle)
    Item {
        width: parent.width; height: 26
        Rectangle {
            anchors.fill: parent
            color: klLinienHover.containsMouse ? root.theme.hover : "transparent"
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 4
            Text {
                text: qsTr("KABEL-LINIEN")
                font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                color: root.theme.borderLight; Layout.fillWidth: true
            }
            Text {
                text: root._expanded ? "▾" : "▸"
                font.pixelSize: 11; color: root.theme.borderLight
                verticalAlignment: Text.AlignVCenter
            }
        }
        MouseArea {
            id: klLinienHover
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root._expanded = !root._expanded
        }
    }

    // Collapsible content
    Item {
        width: parent.width
        height: root._expanded ? linienInhaltCol.implicitHeight : 0
        clip: true
        Column {
            id: linienInhaltCol
            width: parent.width; spacing: 0

            Repeater {
                model: {
                    var kabelId = panel.el && panel.el.extraDaten
                                  ? (panel.el.extraDaten.kabelId || 0) : 0
                    return kabelId > 0
                           ? db.kabelAlleLinienLaden(kabelId + (panel._refresh * 0))
                           : []
                }
                delegate: Rectangle {
                    width: parent ? parent.width - 16 : 0
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    height: 32; radius: 3
                    color: (root.freshGeid > 0 && modelData.grafikElementId === root.freshGeid)
                           ? root.theme.activeItemAlt : root.theme.inputBg
                    border.color: root.theme.border
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6
                        Text {
                            text: modelData.seiteBezeichnung || ("Seite " + modelData.seiteId)
                            color: root.theme.textSecondary
                            font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.aderAnzahl + " " + qsTr("Adr.")
                            color: modelData.aderAnzahl > 0 ? root.theme.accent : root.theme.textMuted
                            font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { panel.canvas.querverweisNavigieren(modelData.seiteId); panel._refresh++ }
                    }
                }
            }

            // Freie Adern (nicht zugeordnet)
            Item {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                height: {
                    var kabelId = panel.el && panel.el.extraDaten
                                  ? (panel.el.extraDaten.kabelId || 0) : 0
                    var freie = kabelId > 0
                                ? db.kabelFreieAderLaden(kabelId + (panel._refresh * 0))
                                : []
                    return freie.length > 0 ? freiAderCol.implicitHeight : 0
                }
                clip: true
                Column {
                    id: freiAderCol
                    width: parent.width; spacing: 2
                    Text {
                        width: parent.width
                        text: qsTr("Freie Adern (nicht zugeordnet):")
                        color: root.theme.textMuted; font.pixelSize: 10; font.italic: true
                    }
                    Repeater {
                        model: {
                            var kabelId = panel.el && panel.el.extraDaten
                                          ? (panel.el.extraDaten.kabelId || 0) : 0
                            return kabelId > 0
                                   ? db.kabelFreieAderLaden(kabelId + (panel._refresh * 0))
                                   : []
                        }
                        delegate: Text {
                            width: parent ? parent.width : 0
                            text: {
                                var t = "Ader " + (modelData.aderNr || "?")
                                if (modelData.farbe) t += "  " + modelData.farbe
                                if (modelData.bezeichnung) t += "  " + modelData.bezeichnung
                                return t
                            }
                            color: root.theme.textMuted; font.pixelSize: 10; elide: Text.ElideRight
                        }
                    }
                }
            }
            Item { height: 4 }
        }
    }
}
