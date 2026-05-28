import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var theme
    property bool debug: false

    DebugLabel { panelName: qsTr("Ader-Tabelle"); visible: root.debug }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tabellenkopf
        Rectangle {
            Layout.fillWidth: true; height: 30; color: root.theme.sidebar
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                spacing: 0
                Text { text: qsTr("Nr.");             color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 36 }
                Text { text: qsTr("Bezeichnung");     color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 120 }
                Text { text: qsTr("Farbe / Kennung"); color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 110 }
                Text { text: qsTr("mm²");             color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.fillWidth: true }
                Item { width: 80 }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.divider }

        ListView {
            id: aderListe
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true
            model: kabelModel.adern

            Text {
                anchors.centerIn: parent
                visible: aderListe.count === 0
                text: kabelModel.hatKabel
                      ? qsTr("Noch keine Adern – mit '+ Ader' hinzufügen.")
                      : qsTr("Kabel-Daten anlegen um Adern zu definieren.")
                color: root.theme.borderDark; font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
            }

            delegate: Rectangle {
                width:  aderListe.width
                height: 34
                color:  index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                    spacing: 4

                    Text {
                        text:  String(modelData.aderNr)
                        color: root.theme.textMuted; font.pixelSize: 11
                        Layout.preferredWidth: 36
                    }

                    NavTextField {
                        id: tfAderBez
                        tabTarget:     tfAderFarbe
                        backtabTarget: tfAderMm2
                        Layout.preferredWidth: 116
                        text: modelData.bezeichnung
                        font.pixelSize: 11; implicitHeight: 26
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                        onEditingFinished: kabelModel.aderAktualisieren(modelData.id, {
                            "bezeichnung":     text,
                            "farbe":           tfAderFarbe.text,
                            "querschnitt_mm2": parseFloat(tfAderMm2.text) || 0
                        })
                    }

                    NavTextField {
                        id: tfAderFarbe
                        tabTarget:     tfAderMm2
                        backtabTarget: tfAderBez
                        Layout.preferredWidth: 106
                        text: modelData.farbe
                        font.pixelSize: 11; implicitHeight: 26
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                        onEditingFinished: kabelModel.aderAktualisieren(modelData.id, {
                            "bezeichnung":     tfAderBez.text,
                            "farbe":           text,
                            "querschnitt_mm2": parseFloat(tfAderMm2.text) || 0
                        })
                    }

                    NavTextField {
                        id: tfAderMm2
                        tabTarget:     tfAderBez
                        backtabTarget: tfAderFarbe
                        Layout.fillWidth: true
                        text: modelData.querschnittMm2 > 0 ? modelData.querschnittMm2.toFixed(2) : ""
                        placeholderText: "1.5"
                        font.pixelSize: 11; implicitHeight: 26
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                        onEditingFinished: kabelModel.aderAktualisieren(modelData.id, {
                            "bezeichnung":     tfAderBez.text,
                            "farbe":           tfAderFarbe.text,
                            "querschnitt_mm2": parseFloat(text) || 0
                        })
                    }

                    Row {
                        spacing: 2
                        Button {
                            width: 22; height: 22; flat: true
                            contentItem: Text { text: "↑"; color: root.theme.accent; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: kabelModel.aderSchieben(modelData.id, -1)
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: qsTr("Ader nach oben verschieben")
                        }
                        Button {
                            width: 22; height: 22; flat: true
                            contentItem: Text { text: "↓"; color: root.theme.accent; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: kabelModel.aderSchieben(modelData.id, 1)
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: qsTr("Ader nach unten verschieben")
                        }
                        Button {
                            width: 22; height: 22; flat: true
                            contentItem: Text { text: "×"; color: "#aa4444"; font.pixelSize: 16;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: kabelModel.aderLoeschen(modelData.id)
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: qsTr("Ader löschen")
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        Rectangle {
            Layout.fillWidth: true; height: 44; color: root.theme.surfaceDeep
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                Text {
                    text: qsTr("%1 Ader(n)").arg(kabelModel.adern.length)
                    color: root.theme.textMuted; font.pixelSize: 12; Layout.fillWidth: true
                }
                Button {
                    text: qsTr("+ Ader"); implicitHeight: 30
                    enabled: kabelModel.hatKabel
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                    }
                    onClicked: kabelModel.aderAnlegen()
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: kabelModel.hatKabel
                                  ? qsTr("Neue Ader hinzufügen")
                                  : qsTr("Zuerst Kabel-Daten anlegen")
                }
            }
        }
    }
}
