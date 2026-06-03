import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog: Betriebsmittel verknüpfen oder neu anlegen.
// Kommuniziert über `panel` (EP-Panel-Referenz).
Dialog {
    id: root

    required property var panel
    required property var theme

    width:            400
    anchors.centerIn: Overlay.overlay
    modal:            true
    padding:          14
    standardButtons:  Dialog.NoButton

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
            text:           qsTr("Geräteverknüpfung")
            color:          theme.accent
            font.pixelSize: 13
            font.weight:    Font.Medium
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: theme.border }
    }

    onOpened: {
        root.gewaehltId = panel.el ? (panel.el.betriebsmittelId || 0) : 0
        neuKzField.text  = (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "") : ""
        neuBezField.text = ""
    }

    onAccepted: {
        if (!panel.el) return
        var zielId = root.gewaehltId
        if (zielId <= 0 && neuKzField.text.trim() !== "") {
            zielId = db.betriebsmittelAnlegen(panel.canvas.projektId,
                                              neuKzField.text.trim(),
                                              neuBezField.text.trim())
        }
        if (zielId > 0) {
            db.grafikElementVerknuepfen(panel.el.id, zielId)
            panel.canvas.eigenschaftAktualisieren("betriebsmittelId", zielId)
            db.betriebsmittelBmkSynchronisieren(zielId)
            panel.canvas.seiteNeuLaden()
        }
    }

    contentItem: ColumnLayout {
        spacing: 8

        Text {
            text:           qsTr("Vorhandenes Betriebsmittel wählen:")
            color:          theme.textMuted
            font.pixelSize: 11
        }

        ListView {
            id:               bmListe
            Layout.fillWidth: true
            height:           Math.min(contentHeight, 160)
            clip:             true
            model:            panel.canvas.projektId >= 0 ? db.betriebsmittelListe(panel.canvas.projektId) : []

            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                width:  bmListe.width
                height: 28; radius: 3
                color: root.gewaehltId === modelData.id
                       ? theme.activeItemAlt
                       : (bmDelegMa.containsMouse ? theme.hover : "transparent")
                border.color: root.gewaehltId === modelData.id ? theme.accent : "transparent"
                Row {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Text { text: modelData.kz;                font.pixelSize: 12; color: theme.accent;    width: 80;  elide: Text.ElideRight }
                    Text { text: modelData.bezeichnung || ""; font.pixelSize: 11; color: theme.textMuted; width: 150; elide: Text.ElideRight }
                    Text { text: modelData.anzahl > 0 ? "(" + modelData.anzahl + ")" : ""; font.pixelSize: 10; color: theme.borderLight }
                }
                MouseArea {
                    id: bmDelegMa; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.gewaehltId = modelData.id; neuKzField.text = "" }
                }
            }

            Text {
                anchors.centerIn: parent
                visible:        bmListe.count === 0
                text:           qsTr("Noch keine Betriebsmittel im Projekt")
                color:          theme.borderLight
                font.pixelSize: 10; font.italic: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        Text {
            text:           qsTr("… oder neues Betriebsmittel anlegen:")
            color:          theme.textMuted
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 6
            TextField {
                id:                    neuKzField
                Layout.preferredWidth: 110; implicitHeight: 30
                placeholderText:       qsTr("BMK z.B. -K1")
                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                color: theme.textPrimary; font.pixelSize: 11
                onTextChanged: if (text.trim() !== "") root.gewaehltId = 0
            }
            TextField {
                id:               neuBezField
                Layout.fillWidth: true; implicitHeight: 30
                placeholderText:  qsTr("Bezeichnung (optional)")
                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                color: theme.textPrimary; font.pixelSize: 11
            }
        }

        Text {
            visible:          root.gewaehltId > 0
            Layout.fillWidth: true
            text:             qsTr("BMK wird automatisch vom gewählten Betriebsmittel übernommen.")
            color:            theme.textMuted
            font.pixelSize:   10; font.italic: true
            wrapMode:         Text.WordWrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        RowLayout {
            Layout.fillWidth: true; spacing: 8

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Abbrechen")
                implicitWidth: 96; implicitHeight: 32; flat: true
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12
                    color: theme.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? theme.hover : theme.inputBg
                    radius:       4
                    border.color: theme.border
                }
                onClicked: root.reject()
            }

            Button {
                text: qsTr("OK")
                implicitWidth: 80; implicitHeight: 32
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12; font.weight: Font.Medium
                    color: parent.hovered ? "#ffffff" : theme.accent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? theme.accent : theme.inputBg
                    radius:       4
                    border.color: theme.accent
                }
                onClicked: root.accept()
            }
        }
    }
}
