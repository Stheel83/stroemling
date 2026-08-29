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

    function _aderLabel(m) {
        if (!m.aderAnzahl) return qsTr("– keine Kreuzung –")
        if (m.aderVon === m.aderBis) return qsTr("Ader %1").arg(m.aderVon)
        return qsTr("Adern %1–%2").arg(m.aderVon).arg(m.aderBis)
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
                    id: klZeile
                    readonly property bool istAktuell: root.freshGeid > 0
                            && modelData.grafikElementId === root.freshGeid
                    width: parent ? parent.width - 16 : 0
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    height: 24; radius: 2
                    color: istAktuell ? root.theme.activeItemAlt
                           : (klZeileMa.containsMouse ? root.theme.hover : "transparent")

                    MouseArea {
                        id: klZeileMa
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: panel.canvas.bmElementSprungAnfordern(
                            modelData.seiteId,
                            modelData.blattnummer,
                            modelData.seiteBezeichnung,
                            modelData.weltX,
                            modelData.weltY)
                    }

                    Row {
                        anchors { left: parent.left; right: parent.right
                                  leftMargin: 4; rightMargin: 4
                                  verticalCenter: parent.verticalCenter }
                        spacing: 0

                        Rectangle {
                            width: 3; height: 14; radius: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: klZeile.istAktuell ? root.theme.accent : "transparent"
                        }

                        Text {
                            width: parent.width - 3 - 90 - 24
                            leftPadding: 6
                            height: klZeile.height
                            verticalAlignment: Text.AlignVCenter
                            text: root._aderLabel(modelData)
                            font.pixelSize: 10
                            color: modelData.aderAnzahl > 0 ? root.theme.textSecondary : root.theme.textMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            width: 90
                            height: klZeile.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.seiteBezeichnung || ("Seite " + modelData.seiteId)
                            font.pixelSize: 9
                            color: root.theme.textMuted
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: 20; height: 18; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: klSprungMa.containsMouse ? root.theme.accent : "transparent"
                            border.color: klSprungMa.containsMouse ? root.theme.accent : root.theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "→"; font.pixelSize: 10
                                color: klSprungMa.containsMouse ? "#ffffff" : root.theme.accent
                            }
                            MouseArea {
                                id: klSprungMa; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: panel.canvas.bmElementSprungAnfordern(
                                    modelData.seiteId,
                                    modelData.blattnummer,
                                    modelData.seiteBezeichnung,
                                    modelData.weltX,
                                    modelData.weltY)
                            }
                        }
                    }
                }
            }
            Item { height: 4 }
        }
    }
}
