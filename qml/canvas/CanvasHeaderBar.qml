import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling
import "../components"

Rectangle {
    id: root
    required property var canvas

    height: 40
    color: AppTheme.surfaceDeep
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: AppTheme.border }

    RowLayout {
        anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
        spacing: 4

        Text { text: canvas.seiteName; font.pixelSize: 13; font.weight: Font.Medium
               color: AppTheme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight }

        Button {
            flat: true; implicitWidth: 26; implicitHeight: 26; enabled: canvas.elementeModel.undoMoeglich
            contentItem: Text { text: qsTr("↩"); color: parent.enabled ? AppTheme.accent : AppTheme.border
                font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? AppTheme.activeItem : "transparent"; radius: 4 }
            onClicked: canvas.undo()
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: {
                var n = canvas.elementeModel.undoAnzahl
                return n > 0 ? "Rueckgaengig: " + n + (n === 1 ? " Schritt" : " Schritte") + "  (Ctrl+Z)"
                             : "Rueckgaengig – kein Schritt vorhanden  (Ctrl+Z)"
            }
        }
        Button {
            flat: true; implicitWidth: 26; implicitHeight: 26; enabled: canvas.elementeModel.redoMoeglich
            contentItem: Text { text: qsTr("↪"); color: parent.enabled ? AppTheme.accent : AppTheme.border
                font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? AppTheme.activeItem : "transparent"; radius: 4 }
            onClicked: canvas.redo()
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: {
                var n = canvas.elementeModel.redoAnzahl
                return n > 0 ? "Wiederholen: " + n + (n === 1 ? " Schritt" : " Schritte") + "  (Ctrl+Y)"
                             : "Wiederholen – kein Schritt vorhanden  (Ctrl+Y)"
            }
        }

        Rectangle { width: 1; height: 20; color: AppTheme.border }

        Button {
            text: qsTr("−"); flat: true; implicitWidth: 26; implicitHeight: 26
            contentItem: Text { text: parent.text; color: AppTheme.accent; font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? AppTheme.activeItem : "transparent"; radius: 4 }
            onClicked: canvas.zoomAnpassen(1/1.25)
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: qsTr("Herauszoomen  (Mausrad / Strg+−)")
        }
        Text {
            text: Math.round(canvas.zoom*100) + "%"; color: AppTheme.accent
            font.pixelSize: 12; font.weight: Font.Medium; leftPadding: 2; rightPadding: 2
            MouseArea {
                id: zoomResetMa
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                onClicked: canvas.ansichtZuruecksetzen()
            }
            ToolTip.visible: zoomResetMa.containsMouse; ToolTip.delay: 500
            ToolTip.text: qsTr("Zoom zurücksetzen auf 100 %  (Klick)")
        }
        Button {
            text: "+"; flat: true; implicitWidth: 26; implicitHeight: 26
            contentItem: Text { text: parent.text; color: AppTheme.accent; font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? AppTheme.activeItem : "transparent"; radius: 4 }
            onClicked: canvas.zoomAnpassen(1.25)
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: qsTr("Hineinzoomen  (Mausrad / Strg++)")
        }
        Button {
            flat: true; implicitWidth: 26; implicitHeight: 26; enabled: canvas.seiteId >= 0
            contentItem: Text { text: "⊡"; color: parent.enabled ? AppTheme.accent : AppTheme.border
                font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? AppTheme.activeItem : "transparent"; radius: 4 }
            onClicked: canvas.zoomAllesEinpassen()
            ToolTip.visible: hovered; ToolTip.text: qsTr("Alle Elemente einpassen (Ctrl+Shift+H)"); ToolTip.delay: 500
        }

        Rectangle { width: 1; height: 20; color: AppTheme.border }

        // GIT-01: Version anlegen (nur wenn Git verfügbar)
        Rectangle {
            id: versionBtn
            property bool _feedback:  false
            property bool _gitOk:     db.gitVerfuegbar()
            property bool _aktiv:     db.projektOffen && _gitOk

            Timer { id: versionTimer; interval: 2000; onTriggered: versionBtn._feedback = false }

            implicitWidth: versionBtnLabel.implicitWidth + 20
            height: 26; radius: 4
            enabled: _aktiv
            color: versionMa.containsMouse && enabled ? AppTheme.hover : "transparent"
            border.color: _aktiv ? AppTheme.border : "transparent"

            Text {
                id: versionBtnLabel
                anchors.centerIn: parent
                text:           versionBtn._feedback ? qsTr("✓ angelegt") : qsTr("Version anlegen")
                font.pixelSize: 11
                color: versionBtn._feedback ? AppTheme.accent
                     : versionBtn._aktiv    ? AppTheme.textSecondary
                                            : AppTheme.border
            }
            MouseArea {
                id: versionMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: parent._aktiv ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: parent._aktiv
                onClicked: {
                    canvas.grafikSpeichernJetzt()
                    db.gitAutoCommit(db.projektOrdner,
                                     Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm"))
                    versionBtn._feedback = true
                    versionTimer.restart()
                }
            }
            ToolTip.visible: versionMa.containsMouse; ToolTip.delay: 400
            ToolTip.text: versionBtn._gitOk
                ? qsTr("Legt einen Eintrag im Versionsverlauf an  (Ctrl+S)\n\n"
                      + "Der Schaltplan wird ständig automatisch gespeichert.\n"
                      + "Dieser Knopf erstellt einen benannten Stand,\n"
                      + "zu dem du im Projektverlauf zurückkehren kannst.")
                : qsTr("Git ist nicht installiert – keine Versionierung möglich.\n\n"
                      + "Der Schaltplan wird weiterhin automatisch gespeichert,\n"
                      + "aber es gibt keinen Versionsverlauf.\n\n"
                      + "Wiki: \"Versionierung mit Git\" für Alternativen.")
        }

        Rectangle { width: 1; height: 20; color: AppTheme.border }

        Button {
            flat: true; implicitWidth: 26; implicitHeight: 26
            enabled: canvas.seiteId >= 0 && canvas.normblattDaten !== null
            contentItem: Text { text: "⊟"
                color: parent.enabled ? AppTheme.accent : AppTheme.border
                font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? AppTheme.activeItem : "transparent"; radius: 4 }
            onClicked: canvas.zoomNormblattEinpassen()
            ToolTip.visible: hovered; ToolTip.delay: 500
            ToolTip.text: qsTr("Normblatt einpassen (Ctrl+Shift+N)")
        }
    }

    DebugLabel { panelName: qsTr("Canvas-Header"); corner: "tr"; visible: canvas.debug }
}
