import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../SymbolKlassen.js" as SK

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width: parent ? parent.width : 0
    height: {
        if (!panel.el || panel.el.typ !== "symbol") return 0
        if ((panel.el.betriebsmittelId || 0) > 0) return 0   // Kontaktspiegel-Geräte: eigener Bauteil-Pfad
        var sid = panel.el.symbolId || ""
        if (SK.istVerbHelper(sid)) return 0
        return bzCol.implicitHeight
    }
    visible: height > 0
    clip:    true

    readonly property int _bauteilId: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bauteil_id)
                                       ? panel.el.extraDaten.bauteil_id : 0
    readonly property var _bauteilInfo: root._bauteilId > 0 ? bauteilModel.bauteilNachId(root._bauteilId) : ({})

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }
    function extraEntfernen(key) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        delete ed[key]
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

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

    Column {
        id: bzCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("BAUTEIL") }

        // Kein Bauteil verknüpft
        Item {
            visible: root._bauteilId === 0
            width: root.width; height: 40
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8
                Text {
                    text: qsTr("Kein Bauteil verknüpft")
                    font.pixelSize: 11; font.italic: true; color: root.theme.textMuted
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Rectangle {
                    width: 96; height: 24; radius: 3
                    color: bzVerknHover.hovered ? root.theme.hover : root.theme.inputBg
                    border.color: root.theme.border
                    HoverHandler { id: bzVerknHover }
                    Text {
                        anchors.centerIn: parent; text: qsTr("Verknüpfen")
                        font.pixelSize: 10; color: root.theme.textPrimary
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            bzPicker._liste = db.bauteilAlleFuerPicker()
                            bzPicker.open()
                        }
                    }
                }
            }
        }

        // Bauteil verknüpft
        Item {
            visible: root._bauteilId > 0
            width: root.width
            height: bzInfoCol.implicitHeight + 10
            RowLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 6 }
                anchors.leftMargin: 12; anchors.rightMargin: 8
                spacing: 6

                ColumnLayout {
                    id: bzInfoCol
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: root._bauteilInfo.bezeichnung || ""
                        font.pixelSize: 11; color: root.theme.textPrimary
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: root._bauteilInfo.hersteller || ""
                        visible: text !== ""
                        font.pixelSize: 10; color: root.theme.textMuted
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }

                Rectangle {
                    width: 20; height: 20; radius: 3
                    color: bzEntfMa.containsMouse ? "#2a1515" : "transparent"
                    border.color: bzEntfMa.containsMouse ? "#cc4444" : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: "#cc4444" }
                    MouseArea {
                        id: bzEntfMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.extraEntfernen("bauteil_id")
                    }
                    ToolTip.visible: bzEntfMa.containsMouse
                    ToolTip.text: qsTr("Verknüpfung entfernen")
                    ToolTip.delay: 500
                }
            }
        }

        Item { height: 4 }
    }

    // ── Bauteil-Picker-Dialog ─────────────────────────
    Dialog {
        id: bzPicker
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 320; height: 400
        padding: 0
        property var _liste: []

        background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 0

            Item {
                Layout.fillWidth: true; height: 40
                Text {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: qsTr("Bauteil verknüpfen")
                    font.pixelSize: 13; font.weight: Font.Medium; color: root.theme.textPrimary
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true

                ListView {
                    id: bzPickerList
                    model: bzPicker._liste

                    Text {
                        anchors.centerIn: parent
                        visible: bzPicker._liste.length === 0
                        text: qsTr("Keine Bauteile in der Bibliothek vorhanden.")
                        font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    delegate: Rectangle {
                        width: bzPickerList.width; height: 42
                        color: bzItemHover.hovered ? root.theme.hover : "transparent"
                        HoverHandler { id: bzItemHover }

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
                                text: [modelData.hersteller, modelData.artikelnummer]
                                      .filter(function(s) { return s })
                                      .join("  ·  ")
                                font.pixelSize: 10; color: root.theme.textMuted
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.extraSetzen("bauteil_id", modelData.id)
                                bzPicker.close()
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }
            Item {
                Layout.fillWidth: true; height: 36
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Abbrechen")
                    font.pixelSize: 12; color: root.theme.textMuted
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: bzPicker.close()
                    }
                }
            }
        }
    }
}
