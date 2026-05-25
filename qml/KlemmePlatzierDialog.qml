import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

// ============================================================
// KlemmePlatzierDialog – Anschluss auswählen + Modus wählen
// ============================================================
// Zeigt alle Anschlüsse einer geladenen Klemme (klemmeModel)
// und lässt den Nutzer einen davon zum Platzieren auswählen.
// Modus "Skizze" (Standard) oder "Verknüpft" (grayed out bis
// Klemmenreihen-Editor implementiert ist).
// ============================================================

Dialog {
    id: root

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 360
    padding: 20

    property var    theme
    property bool   debug: false

    // Vom KlemmenEditor gesetzt
    property int    bauteilKlemmeId: -1
    property string bauteilBezeichnung: ""

    // Ausgabe – gelesen von außen nach accepted
    property string gewaehltAnschluss: ""
    property string gewaehltModus:     "skizze"

    title: qsTr("Klemmen-Anschluss platzieren")

    background: Rectangle {
        color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6
    }

    contentItem: ColumnLayout {
        spacing: 12

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // Bauteil-Info
        Text {
            text: root.bauteilBezeichnung
            color: theme.accent; font.pixelSize: 12
            visible: root.bauteilBezeichnung !== ""
        }

        // Anschluss auswählen
        Text { text: qsTr("Anschluss"); color: theme.textMuted; font.pixelSize: 11 }
        ComboBox {
            id: anschlussCombo
            Layout.fillWidth: true
            model: klemmeModel.anschluesse
            textRole: "bezeichnung"

            delegate: ItemDelegate {
                width: anschlussCombo.width
                contentItem: RowLayout {
                    spacing: 8
                    Text { text: modelData.bezeichnung; color: theme.textPrimary;   font.pixelSize: 12; Layout.preferredWidth: 60 }
                    Text { text: qsTr("Seite %1").arg(modelData.seite);   color: theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Ebene %1").arg(modelData.ebene);   color: theme.textMuted; font.pixelSize: 11 }
                }
                background: Rectangle {
                    color: parent.highlighted ? theme.activeItem : "transparent"
                }
            }
            contentItem: Text {
                text: anschlussCombo.currentIndex >= 0
                      ? (klemmeModel.anschluesse[anschlussCombo.currentIndex]
                         ? klemmeModel.anschluesse[anschlussCombo.currentIndex].bezeichnung
                         : "")
                      : ""
                color: theme.textPrimary; font.pixelSize: 12
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
        }

        // Modus
        Text { text: qsTr("Platziermodus"); color: theme.textMuted; font.pixelSize: 11 }
        ButtonGroup { id: modusGruppe }

        ColumnLayout {
            spacing: 4
            RowLayout {
                RadioButton {
                    id: rbSkizze
                    text: qsTr("Skizze (freie Platzierung)")
                    checked: true
                    ButtonGroup.group: modusGruppe
                    contentItem: Text {
                        text: parent.text; color: theme.textPrimary; font.pixelSize: 12
                        leftPadding: parent.indicator.width + 6
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            RowLayout {
                RadioButton {
                    id: rbVerknuepft
                    text: qsTr("Verknüpft (aus Klemmenreihe)")
                    enabled: false
                    ButtonGroup.group: modusGruppe
                    contentItem: Text {
                        text: parent.text; color: theme.textSubtle; font.pixelSize: 12
                        leftPadding: parent.indicator.width + 6
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            Text {
                text: qsTr("→ Platzierung über den Klemmenreihen-Editor")
                color: theme.textSubtle; font.pixelSize: 10; leftPadding: 26
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 32
                contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                onClicked: root.reject()
            }
            Button {
                text: qsTr("Platzieren"); implicitWidth: 100; implicitHeight: 32
                enabled: anschlussCombo.currentIndex >= 0 && klemmeModel.anschluesse.length > 0
                contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                    radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                }
                onClicked: {
                    var list = klemmeModel.anschluesse
                    if (anschlussCombo.currentIndex >= 0 && anschlussCombo.currentIndex < list.length)
                        root.gewaehltAnschluss = list[anschlussCombo.currentIndex].bezeichnung
                    root.gewaehltModus = rbSkizze.checked ? "skizze" : "verknuepft"
                    root.accept()
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Klemme-Platzier-Dialog"); visible: root.debug && root.visible }
}
