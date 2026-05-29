import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var theme
    property bool debug: false

    // CE-04: Mehrfachauswahl
    property var _ausgewaehlt:    []
    property int _letzterKabelId: -1

    // Auswahl leeren wenn ein anderes Kabel geladen wird
    Connections {
        target: kabelModel
        function onGeladen() {
            var curId = kabelModel.hatKabel ? kabelModel.stammdaten.id : -1
            if (curId !== root._letzterKabelId) {
                root._ausgewaehlt   = []
                root._letzterKabelId = curId
            }
        }
    }

    function _toggleAuswahl(aderId) {
        var idx = root._ausgewaehlt.indexOf(aderId)
        var sel = root._ausgewaehlt.slice()
        if (idx >= 0) sel.splice(idx, 1)
        else          sel.push(aderId)
        root._ausgewaehlt = sel
    }

    function _alleToggle() {
        if (root._ausgewaehlt.length === kabelModel.adern.length)
            root._ausgewaehlt = []
        else
            root._ausgewaehlt = kabelModel.adern.map(function(a) { return a.id })
    }

    DebugLabel { panelName: qsTr("Ader-Tabelle"); visible: root.debug }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tabellenkopf
        Rectangle {
            Layout.fillWidth: true; height: 30; color: root.theme.sidebar
            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                spacing: 0

                // Alles-auswählen-Checkbox
                Item {
                    width: 28; height: 30
                    Rectangle {
                        anchors.centerIn: parent
                        width: 14; height: 14; radius: 2
                        color:        root.theme.inputBg
                        border.color: root.theme.border
                        Text {
                            anchors.centerIn: parent
                            text:  root._ausgewaehlt.length > 0
                                   && root._ausgewaehlt.length === kabelModel.adern.length ? "✓" : ""
                            color: root.theme.accent; font.pixelSize: 11; font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root._alleToggle()
                        cursorShape: Qt.PointingHandCursor
                    }
                    ToolTip.visible: hoverEnabled && containsMouse
                    ToolTip.delay: 500
                    ToolTip.text: qsTr("Alle auswählen / abwählen")
                    property bool containsMouse: false
                    HoverHandler { onHoveredChanged: parent.containsMouse = hovered }
                }

                Text { text: qsTr("Nr.");             color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 30 }
                Text { text: qsTr("Bezeichnung");     color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 112 }
                Text { text: qsTr("Farbe / Kennung"); color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 106 }
                Text { text: qsTr("mm²");             color: root.theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.fillWidth: true }
                Item { width: 70 }
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
                id: delegateRow
                width:  aderListe.width
                height: 34

                readonly property bool ausgewaehlt: root._ausgewaehlt.indexOf(modelData.id) >= 0

                color: ausgewaehlt ? root.theme.activeItemAlt
                                   : (index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd)

                RowLayout {
                    anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                    spacing: 4

                    // Zeilen-Checkbox
                    Item {
                        width: 24; height: 34
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14; height: 14; radius: 2
                            color:        delegateRow.ausgewaehlt ? root.theme.accent : root.theme.inputBg
                            border.color: delegateRow.ausgewaehlt ? root.theme.accent : root.theme.border
                            Text {
                                anchors.centerIn: parent
                                text:  delegateRow.ausgewaehlt ? "✓" : ""
                                color: "#ffffff"; font.pixelSize: 10; font.weight: Font.Bold
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root._toggleAuswahl(modelData.id)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    Text {
                        text:  String(modelData.aderNr)
                        color: root.theme.textMuted; font.pixelSize: 11
                        Layout.preferredWidth: 30
                    }

                    NavTextField {
                        id: tfAderBez
                        tabTarget:     tfAderFarbe
                        backtabTarget: tfAderMm2
                        Layout.preferredWidth: 108
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
                        Layout.preferredWidth: 102
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

        // CE-04: Sammel-Editierleiste (nur sichtbar wenn Adern ausgewählt)
        Rectangle {
            Layout.fillWidth: true
            height:  root._ausgewaehlt.length > 0 ? 56 : 0
            visible: root._ausgewaehlt.length > 0
            color:   root.theme.surfaceDeep
            clip:    true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: root.theme.accent; opacity: 0.4
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 6

                Text {
                    text: qsTr("%1 ausgewählt:").arg(root._ausgewaehlt.length)
                    color: root.theme.textMuted; font.pixelSize: 11
                    Layout.preferredWidth: 80
                }

                // Farbe
                ColumnLayout {
                    spacing: 2
                    Text { text: qsTr("Farbe"); color: root.theme.textMuted; font.pixelSize: 10 }
                    TextField {
                        id: bulkFarbe
                        implicitWidth:  100; implicitHeight: 24
                        font.pixelSize: 11
                        placeholderText: qsTr("leer = unveraendert")
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                    }
                }

                // mm²
                ColumnLayout {
                    spacing: 2
                    Text { text: qsTr("mm²"); color: root.theme.textMuted; font.pixelSize: 10 }
                    TextField {
                        id: bulkMm2
                        implicitWidth:  70; implicitHeight: 24
                        font.pixelSize: 11
                        placeholderText: qsTr("leer = unveraendert")
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                    }
                }

                // Bezeichnung
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 10 }
                    TextField {
                        id: bulkBez
                        Layout.fillWidth: true; implicitHeight: 24
                        font.pixelSize: 11
                        placeholderText: qsTr("leer = unveraendert")
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                    }
                }

                // Übernehmen
                Button {
                    text: qsTr("Uebernehmen"); implicitHeight: 28; implicitWidth: 90
                    contentItem: Text {
                        text: parent.text; color: root.theme.textPrimary
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius: 4; border.color: root.theme.accent
                    }
                    onClicked: {
                        var daten = {}
                        if (bulkFarbe.text.trim() !== "") daten["farbe"]          = bulkFarbe.text.trim()
                        if (bulkMm2.text.trim()   !== "") daten["querschnitt_mm2"] = bulkMm2.text.trim()
                        if (bulkBez.text.trim()   !== "") daten["bezeichnung"]    = bulkBez.text.trim()
                        kabelModel.aderMehrfachAktualisieren(root._ausgewaehlt, daten)
                        bulkFarbe.text = ""; bulkMm2.text = ""; bulkBez.text = ""
                    }
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Ausgefüllte Felder auf alle markierten Adern anwenden")
                }

                // Auswahl aufheben
                Button {
                    text: "×"; implicitHeight: 28; implicitWidth: 28
                    contentItem: Text {
                        text: parent.text; color: root.theme.textMuted
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color:        parent.hovered ? root.theme.activeItemAlt : "transparent"
                        radius: 4; border.color: root.theme.border
                    }
                    onClicked: root._ausgewaehlt = []
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Auswahl aufheben")
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // Fußzeile
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
