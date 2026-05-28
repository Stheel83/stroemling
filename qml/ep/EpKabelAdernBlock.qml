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

    // KABEL-ADERN header (toggle)
    Item {
        width: parent.width; height: 26
        Rectangle {
            anchors.fill: parent
            color: klAdernHover.containsMouse ? root.theme.hover : "transparent"
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 4
            Text {
                text: qsTr("KABEL-ADERN")
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
            id: klAdernHover
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root._expanded = !root._expanded
        }
    }

    // Collapsible content
    Item {
        width: parent.width
        height: root._expanded ? adernInhaltCol.implicitHeight : 0
        clip: true
        Column {
            id: adernInhaltCol
            width: parent.width; spacing: 0

            Text {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 4
                text: qsTr("Dieser Linie zugeordnet:")
                color: root.theme.textMuted; font.pixelSize: 10; font.italic: true
            }
            Repeater {
                model: {
                    var geid = root.freshGeid
                    return geid > 0
                           ? db.kabelAderFuerLinieLaden(geid + (panel._refresh * 0))
                           : []
                }
                delegate: Rectangle {
                    width: parent ? parent.width - 16 : 0
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    height: 24; radius: 3
                    color: root.theme.inputBg
                    border.color: root.theme.border
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            visible: (modelData.farbe || "") !== ""
                            color: panel.canvas.iecFarbe(modelData.farbe || "")
                            border.color: "#00000055"; border.width: 1
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: {
                                var t = "Ader " + (modelData.aderNr || "?")
                                if (modelData.farbe) t += "  " + modelData.farbe
                                if (modelData.bezeichnung) t += "  " + modelData.bezeichnung
                                return t
                            }
                            color: root.theme.textSecondary
                            font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
            }
            Text {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                visible: {
                    var geid = root.freshGeid
                    var kabelId = panel.el && panel.el.extraDaten
                                  ? (panel.el.extraDaten.kabelId || 0) : 0
                    if (kabelId <= 0) return false
                    if (geid <= 0) return true
                    return db.kabelAderFuerLinieLaden(geid + (panel._refresh * 0)).length === 0
                }
                text: qsTr("Keine Adern zugeordnet.")
                color: root.theme.textMuted; font.pixelSize: 10; font.italic: true
            }
            Item { height: 8 }
        }
    }
}
