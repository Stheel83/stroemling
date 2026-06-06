import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog: Betriebsmittel verknüpfen oder neu anlegen.
// Aufbau analog MakroBibliothekDialog: festes height, padding 0,
// Titel als erstes contentItem-Kind → kein Header-Layout-Bug.
Dialog {
    id: root

    required property var panel
    required property var theme

    width:   400
    height:  390
    padding: 0
    modal:   true
    parent:  Overlay.overlay
    anchors.centerIn: parent
    standardButtons: Dialog.NoButton

    property int gewaehltId: 0

    background: Rectangle {
        color:        root.theme.sidebar
        border.color: root.theme.border
        border.width: 1
        radius:       6
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
        spacing: 0

        // ── Titelzeile ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color:  "transparent"
            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
                spacing: 8
                Text {
                    text: qsTr("Geräteverknüpfung")
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: root.theme.accent
                    Layout.fillWidth: true
                }
                Button {
                    text: "×"; flat: true; implicitWidth: 28; implicitHeight: 28
                    contentItem: Text {
                        text: parent.text; color: root.theme.textMuted
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? root.theme.hover : "transparent"; radius: 4
                    }
                    onClicked: root.reject()
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // ── Betriebsmittel-Liste ─────────────────────────────
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 10; Layout.leftMargin: 14; Layout.rightMargin: 14
            text:           qsTr("Vorhandenes Betriebsmittel wählen:")
            color:          root.theme.textMuted
            font.pixelSize: 11
        }

        ListView {
            id:                   bmListe
            Layout.fillWidth:     true
            Layout.fillHeight:    true
            Layout.leftMargin:    14; Layout.rightMargin: 14
            Layout.topMargin:     4;  Layout.bottomMargin: 4
            clip:                 true
            model:                panel.canvas.projektId >= 0
                                  ? db.betriebsmittelListe(panel.canvas.projektId) : []

            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                width:  bmListe.width
                height: 28; radius: 3
                color: root.gewaehltId === modelData.id
                       ? root.theme.activeItemAlt
                       : (bmDelegMa.containsMouse ? root.theme.hover : "transparent")
                border.color: root.gewaehltId === modelData.id ? root.theme.accent : "transparent"
                Row {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Text { text: modelData.kz;                font.pixelSize: 12; color: root.theme.accent;    width: 80;  elide: Text.ElideRight }
                    Text { text: modelData.bezeichnung || ""; font.pixelSize: 11; color: root.theme.textMuted; width: 150; elide: Text.ElideRight }
                    Text { text: modelData.anzahl > 0 ? "(" + modelData.anzahl + ")" : ""; font.pixelSize: 10; color: root.theme.borderLight }
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
                color:          root.theme.borderLight
                font.pixelSize: 10; font.italic: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // ── Neues Betriebsmittel anlegen ─────────────────────
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8; Layout.leftMargin: 14; Layout.rightMargin: 14
            text:           qsTr("… oder neues Betriebsmittel anlegen:")
            color:          root.theme.textMuted
            font.pixelSize: 11
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 4
            spacing: 6

            TextField {
                id:                    neuKzField
                Layout.preferredWidth: 110; implicitHeight: 30
                placeholderText:       qsTr("BMK z.B. -K1")
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                color: root.theme.textPrimary; font.pixelSize: 11
                onTextChanged: if (text.trim() !== "") root.gewaehltId = 0
            }
            TextField {
                id:               neuBezField
                Layout.fillWidth: true; implicitHeight: 30
                placeholderText:  qsTr("Bezeichnung (optional)")
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                color: root.theme.textPrimary; font.pixelSize: 11
            }
        }

        Text {
            visible:          root.gewaehltId > 0
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 2
            text:             qsTr("BMK wird automatisch vom gewählten Betriebsmittel übernommen.")
            color:            root.theme.textMuted
            font.pixelSize:   10; font.italic: true
            wrapMode:         Text.WordWrap
        }

        // ── Buttons ──────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 8 }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14; Layout.rightMargin: 14
            Layout.topMargin: 8;   Layout.bottomMargin: 12
            spacing: 8

            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Abbrechen")
                implicitWidth: 96; implicitHeight: 32
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12
                    color: root.theme.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius:       4
                    border.color: root.theme.border
                }
                onClicked: root.reject()
            }

            Button {
                text: qsTr("OK")
                implicitWidth: 80; implicitHeight: 32
                contentItem: Text {
                    text: parent.text; font.pixelSize: 12; font.weight: Font.Medium
                    color: parent.hovered ? "#ffffff" : root.theme.accent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? root.theme.accent : root.theme.inputBg
                    radius:       4
                    border.color: root.theme.accent
                }
                onClicked: root.accept()
            }
        }
    }
}
