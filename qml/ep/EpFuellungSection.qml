import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && (panel.el.typ === "rechteck" || panel.el.typ === "kreis"))
             ? fuellCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    Column {
        id: fuellCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("FÜLLUNG") }

        Row {
            leftPadding: 12; height: 32; spacing: 8
            Rectangle {
                width: 20; height: 20; radius: 4; anchors.verticalCenter: parent.verticalCenter
                color: panel.s("fuell", false) ? theme.accent : theme.inputBg
                border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✓"); color: "#ffffff"; font.pixelSize: 12
                       visible: panel.s("fuell", false) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: canvas.eigenschaftAktualisieren("fuell", !panel.s("fuell", false))
                            ToolTip.visible: containsMouse
                            ToolTip.text:    qsTr("Füllung ein-/ausschalten")
                            ToolTip.delay:   500 }
            }
            Text { text: qsTr("Füllung aktivieren"); color: theme.textMuted; font.pixelSize: 11
                   anchors.verticalCenter: parent.verticalCenter }
        }

        Item {
            width: parent.width
            height: panel.s("fuell", false) ? fuellDetailCol.implicitHeight : 0
            visible: height > 0; clip: true

            Column {
                id: fuellDetailCol
                width: parent.width; spacing: 0

                FeldLabel { text: qsTr("Füllfarbe") }
                ColorPalette {
                    model: panel.farbpalette
                    value: panel.s("fuellFarbe", theme.activeItemAlt)
                    theme: theme
                    onColorSelected: function(c) { canvas.eigenschaftAktualisieren("fuellFarbe", c) }
                }
                Item { height: 8 }

                Item {
                    width: root.width; height: 22
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: qsTr("Füllopazität"); color: theme.panelMid; font.pixelSize: 10
                    }
                    Row {
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Rectangle {
                            width: 36; height: 18; radius: 3; anchors.verticalCenter: parent.verticalCenter
                            color: theme.inputBg; border.color: fuOpTf.activeFocus ? theme.accent : theme.border
                            TextInput {
                                id: fuOpTf
                                anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                                horizontalAlignment: TextInput.AlignRight
                                color: theme.textSecondary; font.pixelSize: 10; verticalAlignment: TextInput.AlignVCenter
                                validator: IntValidator { bottom: 5; top: 100 }
                                text: Math.round(panel.s("fuellOpazitaet", 0.3) * 100)
                                Binding on text {
                                    when: !fuOpTf.activeFocus
                                    value: Math.round(panel.s("fuellOpazitaet", 0.3) * 100)
                                }
                                onEditingFinished: {
                                    var v = parseInt(text)
                                    if (!isNaN(v)) canvas.eigenschaftAktualisieren("fuellOpazitaet", Math.max(0.05, Math.min(1.0, v/100)))
                                }
                                Keys.onEscapePressed: { text = Math.round(panel.s("fuellOpazitaet", 0.3) * 100); focus = false }
                            }
                        }
                        Text { text: "%"; color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                StilSlider { theme: theme;
                    width: root.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    von: 0.05; bis: 1.0; schritt: 0.05
                    wert: panel.s("fuellOpazitaet", 0.3)
                    onGeaendert: function(v) { canvas.eigenschaftAktualisieren("fuellOpazitaet", v) }
                }
            }
        }
    }
}
