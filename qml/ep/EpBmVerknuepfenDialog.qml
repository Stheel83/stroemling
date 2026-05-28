import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog: Betriebsmittel verknüpfen oder neu anlegen.
// Kommuniziert über `panel` (EP-Panel-Referenz).
Dialog {
    id: root

    required property var panel
    required property var theme

    title:             qsTr("Geräteverknüpfung")
    width:             340
    anchors.centerIn:  Overlay.overlay
    modal:             true

    property int gewaehltId: 0

    background: Rectangle {
        color:        theme.sidebar
        border.color: theme.border
        border.width: 1
        radius:       6
    }

    header: Item {
        height: 36
        Text {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            text:            qsTr("Geräteverknüpfung")
            color:           theme.accent
            font.pixelSize:  13
            font.weight:     Font.Medium
        }
    }

    onOpened: {
        root.gewaehltId = panel.el ? (panel.el.betriebsmittelId || 0) : 0
        neuKzField.text  = (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "") : ""
        neuBezField.text = ""
    }

    standardButtons: Dialog.Ok | Dialog.Cancel

    onAccepted: {
        if (!panel.el) return
        var zielId = root.gewaehltId
        var zielKz = ""
        if (zielId <= 0 && neuKzField.text.trim() !== "") {
            zielKz = neuKzField.text.trim()
            zielId = db.betriebsmittelAnlegen(panel.canvas.projektId, zielKz, neuBezField.text.trim())
        } else if (zielId > 0) {
            zielKz = db.betriebsmittelKz(zielId)
        }
        if (zielId > 0) {
            db.grafikElementVerknuepfen(panel.el.id, zielId)
            panel.canvas.eigenschaftAktualisieren("betriebsmittelId", zielId)
            if (zielKz !== "") {
                var ed = panel.el.extraDaten
                         ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                ed["bmk"] = zielKz
                panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
            }
        }
    }

    ColumnLayout {
        width:   parent.width
        spacing: 8

        Text {
            text:           qsTr("Vorhandenes Betriebsmittel wählen:")
            color:          theme.textBright
            font.pixelSize: 11
        }

        ListView {
            id:     bmListe
            Layout.fillWidth: true
            height: Math.min(contentHeight, 160)
            clip:   true
            model:  panel.canvas.projektId >= 0 ? db.betriebsmittelListe(panel.canvas.projektId) : []

            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                width:  bmListe.width
                height: 28
                radius: 3
                color: root.gewaehltId === modelData.id
                       ? theme.activeItemAlt
                       : (bmDelegMa.containsMouse ? theme.hover : "transparent")
                border.color: root.gewaehltId === modelData.id ? theme.accent : "transparent"
                Row {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Text { text: modelData.kz;          font.pixelSize: 12; color: theme.accent;   width: 80; elide: Text.ElideRight }
                    Text { text: modelData.bezeichnung || ""; font.pixelSize: 11; color: theme.textMuted }
                    Text { text: modelData.anzahl > 0 ? "(" + modelData.anzahl + ")" : ""; font.pixelSize: 10; color: theme.borderLight }
                }
                MouseArea {
                    id: bmDelegMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: { root.gewaehltId = modelData.id; neuKzField.text = "" }
                }
            }
        }

        Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

        Text {
            text:           qsTr("… oder neues Betriebsmittel anlegen:")
            color:          theme.textBright
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            TextField {
                id:                   neuKzField
                placeholderText:      qsTr("BMK z.B. -K1")
                Layout.preferredWidth: 100
                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                color:          theme.textPrimary
                font.pixelSize: 11
                onTextChanged: if (text.trim() !== "") root.gewaehltId = 0
            }
            TextField {
                id:              neuBezField
                placeholderText: qsTr("Bezeichnung (optional)")
                Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                color:          theme.textPrimary
                font.pixelSize: 11
            }
        }

        Text {
            visible:        root.gewaehltId > 0
            text:           qsTr("Das BMK wird vom gewählten Betriebsmittel übernommen.")
            color:          theme.textMuted
            font.pixelSize: 10
            font.italic:    true
            wrapMode:       Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
