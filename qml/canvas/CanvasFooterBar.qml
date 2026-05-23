import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling
import "../components"

Rectangle {
    id: root
    required property var canvas

    property string koordinatenText: ""

    height: 34
    color: AppTheme.surfaceDeep
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: AppTheme.border }

    function rasterLaden(mm, rs) {
        cmbRaster._laden = true
        var idx = cmbRaster.mmWerte.indexOf(mm)
        cmbRaster.currentIndex = idx >= 0 ? idx : 1
        canvas.rastend = rs
        canvas.gridMm  = mm > 0 ? mm : 4.0
        cmbRaster._laden = false
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 8

        Text { text: qsTr("Raster:"); color: AppTheme.borderLight; font.pixelSize: 11 }

        ComboBox {
            id: cmbRaster
            implicitWidth: 84; implicitHeight: 24
            model: ["2 mm","4 mm","6 mm","8 mm","10 mm"]; currentIndex: 1
            readonly property var mmWerte: [2,4,6,8,10]
            property bool _laden: false
            onCurrentIndexChanged: {
                canvas.gridMm = mmWerte[currentIndex]; canvas.repaintAll()
                if (!_laden && canvas.seiteId >= 0)
                    seitenModel.seiteRasterSpeichern(canvas.seiteId, canvas.gridMm, canvas.rastend)
            }
            background: Rectangle { color: AppTheme.inputBg; border.color: AppTheme.border; radius: 4 }
            contentItem: Text { leftPadding: 8; text: cmbRaster.displayText
                color: AppTheme.textSecondary; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
        }

        Rectangle {
            implicitWidth: 96; implicitHeight: 24; radius: 4
            color: canvas.rastend ? AppTheme.activeItemAlt : AppTheme.inputBg
            border.color: canvas.rastend ? AppTheme.accent : AppTheme.border
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 5
                Text { text: canvas.rastend ? "✓" : "··"
                       color: canvas.rastend ? AppTheme.accent : AppTheme.borderLight
                       font.pixelSize: 12; font.weight: Font.Medium }
                Text { text: canvas.rastend ? qsTr("Rastend") : qsTr("Frei")
                       color: canvas.rastend ? AppTheme.accent : AppTheme.panelMid
                       font.pixelSize: 11; Layout.fillWidth: true }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    canvas.rastend = !canvas.rastend; canvas.repaintAll()
                    if (canvas.seiteId >= 0)
                        seitenModel.seiteRasterSpeichern(canvas.seiteId, canvas.gridMm, canvas.rastend)
                }
            }
        }

        Text { text: canvas.gridMm+" mm · "+canvas.gridPx+" px"; color: AppTheme.borderDark; font.pixelSize: 10 }

        Rectangle { width: 1; height: 18; color: AppTheme.border }

        Text { text: qsTr("Canvas:"); color: AppTheme.borderLight; font.pixelSize: 11 }

        Repeater {
            model: [
                { farbe: "#080f1c", tooltip: qsTr("Dunkel") },
                { farbe: "#e8edf2", tooltip: qsTr("Hell")   },
                { farbe: "#fdf8e8", tooltip: qsTr("Papier") }
            ]
            Rectangle {
                required property var modelData
                width: 20; height: 20; radius: 3
                color: modelData.farbe
                border.color: canvas.hintergrundFarbe === modelData.farbe ? AppTheme.accent : AppTheme.borderLight
                border.width: canvas.hintergrundFarbe === modelData.farbe ? 2 : 1
                ToolTip.visible: hoverHandler.hovered; ToolTip.text: modelData.tooltip; ToolTip.delay: 400
                HoverHandler { id: hoverHandler }
                TapHandler {
                    onTapped: {
                        canvas.hintergrundFarbe = parent.modelData.farbe
                        canvas.hintergrundGeaendert(parent.modelData.farbe)
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
        Text { text: root.koordinatenText; color: AppTheme.borderLight; font.pixelSize: 10; font.family: "monospace" }
    }

    DebugLabel { panelName: qsTr("Canvas-Footer"); corner: "br"; visible: canvas.debug }
}
