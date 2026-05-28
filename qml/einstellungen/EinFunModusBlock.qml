import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sektion "Fun-Modus": Aktivierung, Wartezeit, eigene Gesprächstexte.
// Signale: jetztTesten(), gespraechTexteGeaendert(json)
ColumnLayout {
    id: root

    required property var  theme
    required property bool seiteOffen

    signal jetztTesten()
    signal gespraechTexteGeaendert(string json)

    Layout.fillWidth: true
    spacing: 0

    Settings {
        id:       funSettings
        category: "funmodus"
        property bool   aktiv:          false
        property int    wartezeitMin:   10
        property string gespraechTexte: "[]"
    }

    ListModel { id: gespraechModel }

    function laden() {
        gespraechModel.clear()
        try {
            var arr = JSON.parse(funSettings.gespraechTexte || "[]")
            for (var i = 0; i < arr.length; i++)
                gespraechModel.append(arr[i])
        } catch(e) {}
    }

    function _speichern() {
        var arr = []
        for (var i = 0; i < gespraechModel.count; i++)
            arr.push({ a: gespraechModel.get(i).a, b: gespraechModel.get(i).b })
        var json = JSON.stringify(arr)
        funSettings.gespraechTexte = json
        root.gespraechTexteGeaendert(json)
    }

    Component.onCompleted: root.laden()

    Item { implicitHeight: 28 }
    Text {
        Layout.leftMargin:   20
        text:                qsTr("Fun-Modus")
        font.pixelSize:      11
        font.weight:         Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing:  1
        color:               root.theme.textMuted
    }
    Item { implicitHeight: 8 }

    Rectangle {
        Layout.fillWidth:   true
        Layout.leftMargin:  12
        Layout.rightMargin: 12
        implicitHeight:     funCol.implicitHeight + 20
        color:              root.theme.surface
        radius:             6
        border.color:       root.theme.border

        ColumnLayout {
            id: funCol
            anchors {
                left:  parent.left;  leftMargin:  12
                right: parent.right; rightMargin: 12
                top:   parent.top;   topMargin:   12
            }
            spacing: 12

            Text {
                Layout.fillWidth: true
                text:    qsTr("Nach einer Leerlaufzeit ohne Maus- oder Tastatureingaben erwachen die Canvas-Elemente zum Leben und spielen miteinander.")
                font.pixelSize: 11
                color:          root.theme.textMuted
                wrapMode:       Text.WordWrap
            }

            // ── Aktiviert-Schalter ────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text:             qsTr("Aktiviert")
                    font.pixelSize:   12
                    color:            root.theme.textPrimary
                    Layout.fillWidth: true
                }

                Rectangle {
                    width:  44; height: 24; radius: 12
                    color:  funSettings.aktiv ? root.theme.accent : root.theme.inputBg
                    border.color: root.theme.border

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        x:      funSettings.aktiv ? parent.width - width - 3 : 3
                        y:      3; width: 18; height: 18; radius: 9
                        color:  "white"
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    funSettings.aktiv = !funSettings.aktiv
                    }
                }
            }

            // ── Wartezeit ─────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: funSettings.aktiv

                Text {
                    text:           qsTr("Wartezeit bis zur Aktivierung")
                    font.pixelSize: 12
                    color:          root.theme.textPrimary
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [1, 5, 10, 15, 30, 60]
                        delegate: Rectangle {
                            implicitWidth:  52; implicitHeight: 28; radius: 4
                            color:          funSettings.wartezeitMin === modelData
                                            ? root.theme.accent
                                            : (wartMaus.containsMouse ? root.theme.hover : root.theme.inputBg)
                            border.color:   root.theme.border

                            Text {
                                anchors.centerIn: parent
                                text:           modelData + qsTr(" min")
                                font.pixelSize: 11
                                color:          funSettings.wartezeitMin === modelData
                                                ? "white" : root.theme.textPrimary
                            }
                            MouseArea {
                                id:           wartMaus
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked:    funSettings.wartezeitMin = modelData
                            }
                        }
                    }
                }
            }

            // ── Jetzt testen ──────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height:       34; radius: 4
                color:        testMaus.containsMouse ? root.theme.accent : root.theme.inputBg
                border.color: root.theme.border

                Text {
                    anchors.centerIn: parent
                    text:           qsTr("Jetzt testen")
                    font.pixelSize: 12; font.weight: Font.Medium
                    color:          testMaus.containsMouse ? "white" : root.theme.textPrimary
                }
                MouseArea {
                    id:           testMaus
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.jetztTesten()
                }
            }

            Text {
                Layout.fillWidth: true
                visible:          !root.seiteOffen
                text:             qsTr("⚠ Zuerst eine Seite im Schaltplan öffnen.")
                font.pixelSize:   11
                color:            root.theme.accent
                wrapMode:         Text.WordWrap
            }

            // ── Eigene Gesprächstexte ─────────────────
            Rectangle {
                Layout.fillWidth: true
                height:  1; color: root.theme.divider
                visible: funSettings.aktiv
            }

            Text {
                Layout.fillWidth: true
                text:             qsTr("Eigene Gesprächstexte")
                font.pixelSize:   12; font.weight: Font.Medium
                color:            root.theme.textPrimary
                visible:          funSettings.aktiv
            }

            Text {
                Layout.fillWidth: true
                text:             qsTr("Werden mit den eingebauten Dialogen gemischt.")
                font.pixelSize:   11; color: root.theme.textMuted
                wrapMode:         Text.WordWrap
                visible:          funSettings.aktiv
            }

            // Vorhandene Einträge
            Column {
                Layout.fillWidth: true
                spacing:          4
                visible:          funSettings.aktiv && gespraechModel.count > 0

                Repeater {
                    model: gespraechModel
                    delegate: RowLayout {
                        width:   parent.width
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text:           model.a + "  /  " + model.b
                            font.pixelSize: 11
                            color:          root.theme.textPrimary
                            elide:          Text.ElideRight
                        }

                        Rectangle {
                            width:  22; height: 22; radius: 4
                            color:  delMaus.containsMouse ? "#cc2222" : root.theme.inputBg
                            border.color: root.theme.border

                            Text {
                                anchors.centerIn: parent
                                text:           "✕"; font.pixelSize: 10
                                color:          delMaus.containsMouse ? "white" : root.theme.textMuted
                            }
                            MouseArea {
                                id:           delMaus
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    gespraechModel.remove(index)
                                    root._speichern()
                                }
                            }
                        }
                    }
                }
            }

            // Neuen Eintrag hinzufügen
            ColumnLayout {
                Layout.fillWidth: true
                spacing:          6
                visible:          funSettings.aktiv

                Rectangle {
                    Layout.fillWidth: true
                    height:       30; radius: 4
                    color:        root.theme.inputBg
                    border.color: tfA.activeFocus ? root.theme.accent : root.theme.border

                    TextInput {
                        id:             tfA
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                        font.pixelSize: 11; color: root.theme.textPrimary
                        selectionColor: root.theme.accent; clip: true

                        Text {
                            anchors.fill: parent; anchors.topMargin: 0
                            text:    qsTr("Person A sagt …"); font: parent.font
                            color:   root.theme.textMuted
                            visible: parent.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:       30; radius: 4
                    color:        root.theme.inputBg
                    border.color: tfB.activeFocus ? root.theme.accent : root.theme.border

                    TextInput {
                        id:             tfB
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                        font.pixelSize: 11; color: root.theme.textPrimary
                        selectionColor: root.theme.accent; clip: true

                        Text {
                            anchors.fill: parent; anchors.topMargin: 0
                            text:    qsTr("Person B antwortet …"); font: parent.font
                            color:   root.theme.textMuted
                            visible: parent.text.length === 0
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height:       28; radius: 4
                    property bool bereit: tfA.text.trim().length > 0 && tfB.text.trim().length > 0
                    color:        bereit ? (hinzMaus.containsMouse ? root.theme.accent : root.theme.inputBg)
                                         : root.theme.surfaceDeep
                    border.color: root.theme.border

                    Text {
                        anchors.centerIn: parent
                        text:           qsTr("Hinzufügen")
                        font.pixelSize: 11; font.weight: Font.Medium
                        color:          parent.bereit
                                        ? (hinzMaus.containsMouse ? "white" : root.theme.textPrimary)
                                        : root.theme.textMuted
                    }
                    MouseArea {
                        id:           hinzMaus
                        anchors.fill: parent
                        enabled:      parent.bereit
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            gespraechModel.append({ a: tfA.text.trim(), b: tfB.text.trim() })
                            root._speichern()
                            tfA.text = ""; tfB.text = ""
                        }
                    }
                }
            }

            Item { implicitHeight: 2 }
        }
    }
}
