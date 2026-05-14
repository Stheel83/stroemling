import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var canvas
    required property var theme

    height: 40
    color: theme ? theme.surfaceDeep : "#09121e"
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme ? theme.border : "#1e3a5f" }

    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
        spacing: 4

        Text { text: canvas.seiteName; font.pixelSize: 13; font.weight: Font.Medium
               color: theme ? theme.textSecondary : "#c0d8f0"; Layout.fillWidth: true; elide: Text.ElideRight }

        Button {
            flat: true; implicitWidth: 26; implicitHeight: 26; enabled: canvas.undoStack.length > 0
            contentItem: Text { text: qsTr("↩"); color: parent.enabled ? (theme ? theme.accent : "#4a9eff") : (theme ? theme.border : "#1e3a5f")
                font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? (theme ? theme.activeItem : "#1a3050") : "transparent"; radius: 4 }
            onClicked: canvas.undo()
            ToolTip.visible: hovered; ToolTip.text: qsTr("Rückgängig (Ctrl+Z)"); ToolTip.delay: 500
        }
        Button {
            flat: true; implicitWidth: 26; implicitHeight: 26; enabled: canvas.redoStack.length > 0
            contentItem: Text { text: qsTr("↪"); color: parent.enabled ? (theme ? theme.accent : "#4a9eff") : (theme ? theme.border : "#1e3a5f")
                font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? (theme ? theme.activeItem : "#1a3050") : "transparent"; radius: 4 }
            onClicked: canvas.redo()
            ToolTip.visible: hovered; ToolTip.text: qsTr("Wiederholen (Ctrl+Y)"); ToolTip.delay: 500
        }

        Rectangle { width: 1; height: 20; color: theme ? theme.border : "#1e3a5f" }

        Button {
            text: qsTr("−"); flat: true; implicitWidth: 26; implicitHeight: 26
            contentItem: Text { text: parent.text; color: theme ? theme.accent : "#4a9eff"; font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? (theme ? theme.activeItem : "#1a3050") : "transparent"; radius: 4 }
            onClicked: canvas.zoomAnpassen(1/1.25)
        }
        Text {
            text: Math.round(canvas.zoom*100) + "%"; color: theme ? theme.accent : "#4a9eff"
            font.pixelSize: 12; font.weight: Font.Medium; leftPadding: 2; rightPadding: 2
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: canvas.ansichtZuruecksetzen() }
        }
        Button {
            text: "+"; flat: true; implicitWidth: 26; implicitHeight: 26
            contentItem: Text { text: parent.text; color: theme ? theme.accent : "#4a9eff"; font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? (theme ? theme.activeItem : "#1a3050") : "transparent"; radius: 4 }
            onClicked: canvas.zoomAnpassen(1.25)
        }
        Button {
            flat: true; implicitWidth: 26; implicitHeight: 26; enabled: canvas.seiteId >= 0
            contentItem: Text { text: "⊡"; color: parent.enabled ? (theme ? theme.accent : "#4a9eff") : (theme ? theme.border : "#1e3a5f")
                font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? (theme ? theme.activeItem : "#1a3050") : "transparent"; radius: 4 }
            onClicked: canvas.zoomAllesEinpassen()
            ToolTip.visible: hovered; ToolTip.text: qsTr("Alle Elemente einpassen (Ctrl+Shift+H)"); ToolTip.delay: 500
        }

        Rectangle { width: 1; height: 20; color: theme ? theme.border : "#1e3a5f" }

        Rectangle {
            id: normblattToggle
            property bool aktiv: canvas.normblattDaten ? !!canvas.normblattDaten.normblattAnzeigen : false
            width: 26; height: 26; radius: 4
            enabled: canvas.seiteId >= 0
            color: aktiv ? (theme ? theme.activeItemAlt : "#1a3a6a")
                         : (nbMa.containsMouse && enabled ? (theme ? theme.hover : "#0f2540") : "transparent")
            border.color: aktiv ? (theme ? theme.accent : "#4a9eff") : "transparent"
            Text {
                anchors.centerIn: parent; text: "☐"; font.pixelSize: 14
                color: normblattToggle.aktiv ? (theme ? theme.accent : "#4a9eff") : (theme ? theme.panelMid : "#5577aa")
            }
            MouseArea {
                id: nbMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (canvas.seiteId < 0 || !canvas.normblattDaten) return
                    var neu = !canvas.normblattDaten.normblattAnzeigen
                    db.normblattAnzeigenSetzen(canvas.seiteId, neu)
                    canvas.normblattDaten = db.normblattDatenLaden(canvas.seiteId)
                    canvas.repaintAll()
                }
            }
            ToolTip.visible: nbMa.containsMouse; ToolTip.delay: 500
            ToolTip.text: qsTr("Normblattrahmen ein-/ausblenden")
        }

        Button {
            flat: true; implicitWidth: 26; implicitHeight: 26
            enabled: canvas.seiteId >= 0 && canvas.normblattDaten !== null
            contentItem: Text { text: "▭"
                color: parent.enabled ? (theme ? theme.accent : "#4a9eff") : (theme ? theme.border : "#1e3a5f")
                font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? (theme ? theme.activeItem : "#1a3050") : "transparent"; radius: 4 }
            onClicked: canvas.zoomNormblattEinpassen()
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: qsTr("Normblatt einpassen (Ctrl+Shift+N)")
        }
    }
}
