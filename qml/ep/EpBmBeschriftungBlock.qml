import QtQuick
import QtQuick.Controls

// BESCHRIFTUNGSZEILEN-Block: Reihenfolge + Sichtbarkeit der Freitext-Zeilen.
Column {
    id: root

    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    spacing: 0

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

    Trennlinie {}
    AbschnittTitel { text: qsTr("BESCHRIFTUNGSZEILEN") }

    Item {
        width: parent.width; height: 18
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: qsTr("BMK  –  erste Zeile (fest)")
            color: root.theme.borderLight; font.pixelSize: 10; font.italic: true
        }
    }

    Repeater {
        id: ftRepeater
        model: {
            var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
            return ed.textReihenfolge || ["freitext1", "freitext2"]
        }

        Item {
            id: ftZeileRoot
            width:  root.width
            height: ftZeileCol.implicitHeight

            readonly property string ftKey:      modelData
            readonly property int    ftPos:      index
            readonly property bool   ftSichtbar: {
                var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                return ed[ftKey + "Sichtbar"] !== false
            }
            readonly property string ftLabel:    ftKey === "freitext1" ? "Typ / Bezeichnung" : "Bemerkung"
            readonly property string ftWert: {
                var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                return ed[ftKey] || ""
            }

            function setWert(v) {
                var ed = panel.el && panel.el.extraDaten
                         ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                ed[ftKey] = v
                panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
            }
            function toggleSichtbar() {
                var ed = panel.el && panel.el.extraDaten
                         ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                ed[ftKey + "Sichtbar"] = !ftSichtbar
                panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
            }
            function verschiebeUm(delta) {
                var ed  = panel.el && panel.el.extraDaten
                          ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
                var arr = (ed.textReihenfolge || ["freitext1", "freitext2"]).slice()
                var ziel = ftPos + delta
                if (ziel < 0 || ziel >= arr.length) return
                var tmp = arr[ziel]; arr[ziel] = arr[ftPos]; arr[ftPos] = tmp
                ed.textReihenfolge = arr
                panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
            }

            Column {
                id: ftZeileCol
                width: parent.width
                spacing: 2

                FeldLabel { text: ftZeileRoot.ftLabel }

                Row {
                    anchors { left: parent.left; leftMargin: 8
                              right: parent.right; rightMargin: 8 }
                    spacing: 4

                    Rectangle {
                        width: 26; height: 26; radius: 3
                        color: visMa.containsMouse ? root.theme.border : root.theme.inputBg
                        border.color: root.theme.border
                        ToolTip.visible: visMa.containsMouse
                        ToolTip.text:    ftZeileRoot.ftSichtbar ? "Zeile ausblenden" : "Zeile einblenden"
                        ToolTip.delay:   400
                        Text {
                            anchors.centerIn: parent
                            text:  ftZeileRoot.ftSichtbar ? "👁" : "⃠"
                            color: ftZeileRoot.ftSichtbar ? root.theme.accent : root.theme.borderDark
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: visMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ftZeileRoot.toggleSichtbar()
                        }
                    }

                    Rectangle {
                        width: parent.width - 26 - 22 - 22 - 3 * 4
                        height: 26; radius: 3
                        color: root.theme.inputBg
                        border.color: ftEdit.activeFocus ? root.theme.accent : root.theme.border
                        opacity: ftZeileRoot.ftSichtbar ? 1.0 : 0.45
                        TextInput {
                            id: ftEdit
                            anchors { fill: parent; margins: 5 }
                            color: root.theme.textSecondary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter
                            text: ftZeileRoot.ftWert
                            Binding on text {
                                when:    !ftEdit.activeFocus
                                value:   ftZeileRoot.ftWert
                                delayed: true
                            }
                            onEditingFinished: ftZeileRoot.setWert(text.trim())
                            Keys.onEscapePressed: focus = false
                        }
                    }

                    Rectangle {
                        width: 22; height: 26; radius: 3
                        color: upMa.containsMouse && ftZeileRoot.ftPos > 0
                               ? root.theme.border : root.theme.inputBg
                        border.color: ftZeileRoot.ftPos > 0 ? root.theme.border : root.theme.divider
                        Text {
                            anchors.centerIn: parent; text: qsTr("▲"); font.pixelSize: 9
                            color: ftZeileRoot.ftPos > 0 ? root.theme.accent : root.theme.borderDark
                        }
                        MouseArea {
                            id: upMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: ftZeileRoot.ftPos > 0
                            onClicked: ftZeileRoot.verschiebeUm(-1)
                        }
                    }

                    Rectangle {
                        width: 22; height: 26; radius: 3
                        color: downMa.containsMouse && ftZeileRoot.ftPos < ftRepeater.count - 1
                               ? root.theme.border : root.theme.inputBg
                        border.color: ftZeileRoot.ftPos < ftRepeater.count - 1
                                      ? root.theme.border : root.theme.divider
                        Text {
                            anchors.centerIn: parent; text: qsTr("▼"); font.pixelSize: 9
                            color: ftZeileRoot.ftPos < ftRepeater.count - 1
                                   ? root.theme.accent : root.theme.borderDark
                        }
                        MouseArea {
                            id: downMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: ftZeileRoot.ftPos < ftRepeater.count - 1
                            onClicked: ftZeileRoot.verschiebeUm(1)
                        }
                    }
                }
                Item { height: 4 }
            }
        }
    }
    Item { height: 2 }
}
