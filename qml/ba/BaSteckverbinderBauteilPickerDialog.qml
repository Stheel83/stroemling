import QtQuick
import QtQuick.Controls

// Steckverbinder-Bauteil-Picker — ausgelagert aus BaGeraetekastenAnsicht.qml
// (REFACTOR-QML-02).
Popup {
    id: root
    required property var theme
    required property var ga   // BaGeraetekastenAnsicht-Referenz (laden(), leisteKanvasAktualisiert)

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 420; height: 340
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property int _fuerElId: -1
    property var _liste:    []
    function oeffnen(elementId) {
        root._fuerElId = elementId
        root._liste = db.steckverbinderBausteineListe()
        root.open()
    }

    background: Rectangle {
        color: root.theme.surface
        border.color: root.theme.border; border.width: 1; radius: 6
    }

    Column {
        anchors.fill: parent; anchors.margins: 8; spacing: 0

        Text {
            width: parent.width
            text: qsTr("Steckverbinder-Bauteil wählen")
            font.pixelSize: 13; font.weight: Font.Medium
            color: root.theme.textPrimary; padding: 6
        }

        Rectangle { width: parent.width; height: 1; color: root.theme.border }

        ListView {
            id: pickerList
            width: parent.width
            height: parent.height - 50
            clip: true
            model: root._liste

            Text {
                visible: root._liste.length === 0
                anchors.centerIn: parent
                text: qsTr("Keine Steckverbinder-Bauteile vorhanden.\nErstelle zuerst einen Eintrag unter Bibliothek → Steckverbinder.")
                font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                horizontalAlignment: Text.AlignHCenter
            }

            delegate: Rectangle {
                width: pickerList.width; height: 42
                color: pickerItemHover.hovered ? root.theme.hover : "transparent"
                HoverHandler { id: pickerItemHover }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 12
                    spacing: 2
                    Text {
                        width: parent.width
                        text: modelData.bezeichnung
                        font.pixelSize: 12; color: root.theme.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: (modelData.hersteller || "") +
                              (modelData.polzahl > 0 ? "  ·  " + modelData.polzahl + qsTr("-polig") : "")
                        font.pixelSize: 10; color: root.theme.textMuted
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root._fuerElId >= 0) {
                            db.geraetekastenBauteilSetzen(root._fuerElId, modelData.id)
                            root.ga.laden()
                            root.ga.leisteKanvasAktualisiert()
                        }
                        root.close()
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: root.theme.border }

        Item {
            width: parent.width; height: 36
            Text {
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Abbrechen")
                font.pixelSize: 12; color: root.theme.textMuted
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }
    }
}
