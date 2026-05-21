import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

Item {
    id: root
    required property var theme

    signal jetztTesten()

    property var _infos: ({})

    TextEdit { id: _clipboard; visible: false }
    function _kopieren(text) {
        _clipboard.text = text
        _clipboard.selectAll()
        _clipboard.copy()
    }

    ListModel { id: gespraechModel }

    function _gespraechLaden() {
        gespraechModel.clear()
        try {
            var arr = JSON.parse(funSettings.gespraechTexte || "[]")
            for (var i = 0; i < arr.length; i++)
                gespraechModel.append(arr[i])
        } catch(e) {}
    }

    function _gespraechSpeichern() {
        var arr = []
        for (var i = 0; i < gespraechModel.count; i++)
            arr.push({ a: gespraechModel.get(i).a, b: gespraechModel.get(i).b })
        funSettings.gespraechTexte = JSON.stringify(arr)
    }

    Component.onCompleted: { _infos = db.datenbankInfos(); _gespraechLaden() }
    onVisibleChanged: if (visible) { _infos = db.datenbankInfos(); _gespraechLaden() }

    Rectangle { anchors.fill: parent; color: root.theme.surfaceDeep }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ───────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:           48
            color:            root.theme.surface
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.theme.border }
            Text {
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                text:           qsTr("Einstellungen")
                font.pixelSize: 15
                font.weight:    Font.Medium
                color:          root.theme.textPrimary
            }
        }

        // ── Scrollbarer Inhalt ────────────────────────────────────
        ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentWidth:      availableWidth
            clip:              true

            ColumnLayout {
                width:   parent.width
                spacing: 0

                // ── Sektion: Datenbankpfade ───────────────────────
                Item { height: 24 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Datenbankpfade")
                    font.pixelSize:      11
                    font.weight:         Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing:  1
                    color:               root.theme.textMuted
                }
                Item { height: 8 }

                Rectangle {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  12
                    Layout.rightMargin: 12
                    height:             3 * 60
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    Column {
                        anchors.fill: parent

                        Repeater {
                            model: [
                                { label: qsTr("Projektdatei"),       key: "hauptDb",   icon: "🗄" },
                                { label: qsTr("Wiki-Datenbank"),     key: "wikiDb",    icon: "📚" },
                                { label: qsTr("Backup-Verzeichnis"), key: "backupDir", icon: "💾" }
                            ]

                            delegate: Item {
                                width:  parent.width
                                height: 60

                                Rectangle {
                                    visible:        index < 2
                                    anchors.bottom: parent.bottom
                                    width:          parent.width; height: 1
                                    color:          root.theme.divider
                                }

                                RowLayout {
                                    anchors {
                                        fill:        parent
                                        leftMargin:  12
                                        rightMargin: 8
                                    }
                                    spacing: 8

                                    Text {
                                        text:             modelData.icon
                                        font.pixelSize:   14
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing:          4

                                        Text {
                                            Layout.fillWidth: true
                                            text:             modelData.label
                                            font.pixelSize:   11
                                            font.weight:      Font.Medium
                                            color:            root.theme.textMuted
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text:             root._infos[modelData.key] || qsTr("–")
                                            font.pixelSize:   11
                                            font.family:      "monospace"
                                            color:            root.theme.textPrimary
                                            elide:            Text.ElideMiddle
                                        }
                                    }

                                    // Pfad kopieren
                                    Rectangle {
                                        id:               kopBtn
                                        width:            28; height: 28; radius: 4
                                        color:            kopMouse.containsMouse ? root.theme.hover : "transparent"
                                        border.color:     root.theme.border
                                        Layout.alignment: Qt.AlignVCenter
                                        visible:          (root._infos[modelData.key] || "") !== ""

                                        Text {
                                            anchors.centerIn: parent
                                            text:             kopTimer.running ? "✓" : "⎘"
                                            font.pixelSize:   13
                                            color:            kopTimer.running ? root.theme.accent : root.theme.textMuted
                                        }
                                        Timer { id: kopTimer; interval: 1200 }
                                        MouseArea {
                                            id:           kopMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                root._kopieren(root._infos[modelData.key] || "")
                                                kopTimer.restart()
                                            }
                                        }
                                        ToolTip {
                                            visible: kopMouse.containsMouse
                                            text:    qsTr("Pfad kopieren")
                                            delay:   600
                                        }
                                    }

                                    // Im Dateimanager öffnen
                                    Rectangle {
                                        width:            28; height: 28; radius: 4
                                        color:            oeffMouse.containsMouse ? root.theme.hover : "transparent"
                                        border.color:     root.theme.border
                                        Layout.alignment: Qt.AlignVCenter
                                        visible:          (root._infos[modelData.key] || "") !== ""

                                        Text {
                                            anchors.centerIn: parent
                                            text:             "📂"
                                            font.pixelSize:   12
                                        }
                                        MouseArea {
                                            id:           oeffMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                var p = root._infos[modelData.key] || ""
                                                if (p !== "") Qt.openUrlExternally("file://" + p)
                                            }
                                        }
                                        ToolTip {
                                            visible: oeffMouse.containsMouse
                                            text:    qsTr("Im Dateimanager öffnen")
                                            delay:   600
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Sektion: Versionen ────────────────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Versionen")
                    font.pixelSize:      11
                    font.weight:         Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing:  1
                    color:               root.theme.textMuted
                }
                Item { height: 8 }

                Rectangle {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  12
                    Layout.rightMargin: 12
                    height:             3 * 44
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    Column {
                        anchors.fill: parent

                        Repeater {
                            model: [
                                { label: qsTr("Haupt-DB Schema"),   wert: root._infos["schemaVersion"]     || "–" },
                                { label: qsTr("Wiki-DB Schema"),    wert: root._infos["wikiSchemaVersion"] || "–" },
                                { label: qsTr("Backups vorhanden"), wert: root._infos["backupAnzahl"] !== undefined
                                                                          ? (root._infos["backupAnzahl"] + qsTr(" Datei(en)"))
                                                                          : "–" }
                            ]

                            delegate: Item {
                                width:  parent.width
                                height: 44

                                Rectangle {
                                    visible:        index < 2
                                    anchors.bottom: parent.bottom
                                    width:          parent.width; height: 1
                                    color:          root.theme.divider
                                }

                                RowLayout {
                                    anchors {
                                        fill:        parent
                                        leftMargin:  12
                                        rightMargin: 12
                                    }
                                    Text {
                                        text:             modelData.label
                                        font.pixelSize:   12
                                        color:            root.theme.textPrimary
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text:           modelData.wert.toString()
                                        font.pixelSize: 12
                                        font.family:    "monospace"
                                        color:          root.theme.accent
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Sektion: Datensicherung ───────────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Datensicherung")
                    font.pixelSize:      11
                    font.weight:         Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing:  1
                    color:               root.theme.textMuted
                }
                Item { height: 8 }

                Rectangle {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  12
                    Layout.rightMargin: 12
                    implicitHeight:     sicherungCol.implicitHeight + 20
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    property string _status: ""

                    FolderDialog {
                        id: exportDialog
                        title: qsTr("Archiv-Zielordner wählen")
                        onAccepted: {
                            var result = db.komplettarchivExportieren(selectedFolder)
                            parent._status = result.meldung || ""
                        }
                    }

                    FolderDialog {
                        id: importDialog
                        title: qsTr("Archivordner wählen")
                        onAccepted: {
                            var result = db.komplettarchivImportieren(selectedFolder)
                            parent._status = result.meldung || ""
                        }
                    }

                    ColumnLayout {
                        id:             sicherungCol
                        anchors {
                            left:  parent.left;  leftMargin:  12
                            right: parent.right; rightMargin: 12
                            top:   parent.top;   topMargin:   10
                        }
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Alle Projekte + Wiki in einen Ordner sichern oder aus einer Sicherung wiederherstellen.")
                            font.pixelSize: 11
                            color:          root.theme.textMuted
                            wrapMode:       Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Button {
                                text:          qsTr("Exportieren …")
                                implicitHeight: 32
                                Layout.fillWidth: true
                                contentItem: Text {
                                    text:  parent.text
                                    color: root.theme.textPrimary
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                                    radius:       4
                                    border.color: root.theme.border
                                }
                                onClicked: exportDialog.open()
                            }

                            Button {
                                text:          qsTr("Importieren …")
                                implicitHeight: 32
                                Layout.fillWidth: true
                                contentItem: Text {
                                    text:  parent.text
                                    color: root.theme.textPrimary
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment:   Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color:        parent.hovered ? root.theme.hover : root.theme.inputBg
                                    radius:       4
                                    border.color: root.theme.border
                                }
                                onClicked: importDialog.open()
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text:       parent.parent._status
                            visible:    text.length > 0
                            font.pixelSize: 11
                            color:          root.theme.accent
                            wrapMode:       Text.WordWrap
                        }

                        Item { height: 2 }
                    }
                }

                // ── Sektion: Fun-Modus ────────────────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Fun-Modus")
                    font.pixelSize:      11
                    font.weight:         Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing:  1
                    color:               root.theme.textMuted
                }
                Item { height: 8 }

                Rectangle {
                    Layout.fillWidth:   true
                    Layout.leftMargin:  12
                    Layout.rightMargin: 12
                    implicitHeight:     funCol.implicitHeight + 20
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    Settings {
                        id:       funSettings
                        category: "funmodus"
                        property bool   aktiv:         false
                        property int    wartezeitMin:  10
                        property string gespraechTexte: "[]"
                    }

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

                        // Aktiviert-Schalter
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text:           qsTr("Aktiviert")
                                font.pixelSize: 12
                                color:          root.theme.textPrimary
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width:  44
                                height: 24
                                radius: 12
                                color:  funSettings.aktiv ? root.theme.accent : root.theme.inputBg
                                border.color: root.theme.border

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    x:      funSettings.aktiv ? parent.width - width - 3 : 3
                                    y:      3
                                    width:  18
                                    height: 18
                                    radius: 9
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

                        // Wartezeit
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
                                        implicitWidth:  52
                                        implicitHeight: 28
                                        radius:         4
                                        color:          funSettings.wartezeitMin === modelData
                                                        ? root.theme.accent
                                                        : (wartMaus.containsMouse ? root.theme.hover : root.theme.inputBg)
                                        border.color:   root.theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text:           modelData + qsTr(" min")
                                            font.pixelSize: 11
                                            color:          funSettings.wartezeitMin === modelData
                                                            ? "white"
                                                            : root.theme.textPrimary
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

                        // Jetzt testen
                        Rectangle {
                            Layout.fillWidth: true
                            height:           34
                            radius:           4
                            color:            testMaus.containsMouse ? root.theme.accent : root.theme.inputBg
                            border.color:     root.theme.border

                            Text {
                                anchors.centerIn: parent
                                text:           qsTr("Jetzt testen")
                                font.pixelSize: 12
                                font.weight:    Font.Medium
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

                        // ── Eigene Gesprächstexte ──────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            height:           1
                            color:            root.theme.divider
                            visible:          funSettings.aktiv
                        }

                        Text {
                            Layout.fillWidth: true
                            text:             qsTr("Eigene Gesprächstexte")
                            font.pixelSize:   12
                            font.weight:      Font.Medium
                            color:            root.theme.textPrimary
                            visible:          funSettings.aktiv
                        }

                        Text {
                            Layout.fillWidth: true
                            text:             qsTr("Werden mit den eingebauten Dialogen gemischt.")
                            font.pixelSize:   11
                            color:            root.theme.textMuted
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
                                        text:             model.a + "  /  " + model.b
                                        font.pixelSize:   11
                                        color:            root.theme.textPrimary
                                        elide:            Text.ElideRight
                                    }

                                    Rectangle {
                                        width:  22; height: 22; radius: 4
                                        color:  delMaus.containsMouse ? "#cc2222" : root.theme.inputBg
                                        border.color: root.theme.border

                                        Text {
                                            anchors.centerIn: parent
                                            text:           "✕"
                                            font.pixelSize: 10
                                            color:          delMaus.containsMouse ? "white" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            id:           delMaus
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape:  Qt.PointingHandCursor
                                            onClicked: {
                                                gespraechModel.remove(index)
                                                root._gespraechSpeichern()
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

                            // Eingabe Person A
                            Rectangle {
                                Layout.fillWidth: true
                                height:           30; radius: 4
                                color:            root.theme.inputBg
                                border.color:     tfA.activeFocus ? root.theme.accent : root.theme.border

                                TextInput {
                                    id:             tfA
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                                    font.pixelSize: 11
                                    color:          root.theme.textPrimary
                                    selectionColor: root.theme.accent
                                    clip:           true

                                    Text {
                                        anchors.fill:   parent
                                        anchors.topMargin: 0
                                        text:           qsTr("Person A sagt …")
                                        font:           parent.font
                                        color:          root.theme.textMuted
                                        visible:        parent.text.length === 0
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            // Eingabe Person B
                            Rectangle {
                                Layout.fillWidth: true
                                height:           30; radius: 4
                                color:            root.theme.inputBg
                                border.color:     tfB.activeFocus ? root.theme.accent : root.theme.border

                                TextInput {
                                    id:             tfB
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 4 }
                                    font.pixelSize: 11
                                    color:          root.theme.textPrimary
                                    selectionColor: root.theme.accent
                                    clip:           true

                                    Text {
                                        anchors.fill:   parent
                                        anchors.topMargin: 0
                                        text:           qsTr("Person B antwortet …")
                                        font:           parent.font
                                        color:          root.theme.textMuted
                                        visible:        parent.text.length === 0
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            // Hinzufügen-Button
                            Rectangle {
                                Layout.fillWidth: true
                                height:           28; radius: 4
                                property bool bereit: tfA.text.trim().length > 0 && tfB.text.trim().length > 0
                                color:        bereit ? (hinzMaus.containsMouse ? root.theme.accent : root.theme.inputBg)
                                                     : root.theme.surfaceDeep
                                border.color: root.theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text:           qsTr("Hinzufügen")
                                    font.pixelSize: 11
                                    font.weight:    Font.Medium
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
                                        root._gespraechSpeichern()
                                        tfA.text = ""
                                        tfB.text = ""
                                    }
                                }
                            }
                        }

                        Item { height: 2 }
                    }
                }

                Item { height: 32 }
            }
        }
    }
}
