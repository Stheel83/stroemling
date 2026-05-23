import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

Item {
    id: root
    required property var theme

    signal jetztTesten()
    signal gespraechTexteGeaendert(string json)

    property bool seiteOffen: true   // von Main.qml: root.aktivSeiteId >= 0

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
        var json = JSON.stringify(arr)
        funSettings.gespraechTexte = json
        root.gespraechTexteGeaendert(json)
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

                        Text {
                            Layout.fillWidth: true
                            visible:          !root.seiteOffen
                            text:             qsTr("⚠ Zuerst eine Seite im Schaltplan öffnen.")
                            font.pixelSize:   11
                            color:            root.theme.accent
                            wrapMode:         Text.WordWrap
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

                // ── Sektion: Version ─────────────────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Version")
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
                    height:             44
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    RowLayout {
                        anchors {
                            fill:        parent
                            leftMargin:  12
                            rightMargin: 12
                        }
                        Text {
                            text:             qsTr("Build-Datum")
                            font.pixelSize:   12
                            color:            root.theme.textPrimary
                            Layout.fillWidth: true
                        }
                        Text {
                            text:           buildDatum
                            font.pixelSize: 12
                            font.family:    "monospace"
                            color:          root.theme.accent
                        }
                    }
                }

                // ── Sektion: Strömlinge ──────────────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Strömlinge")
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
                    implicitHeight:     schwCol.implicitHeight + 24
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border
                    clip:               true

                    Column {
                        id:    schwCol
                        width: parent.width
                        anchors.top: parent.top
                        anchors.topMargin: 16

                        Image {
                            width:            parent.width - 32
                            anchors.horizontalCenter: parent.horizontalCenter
                            source:           "qrc:/assets/schwaerzchen_sheet.png"
                            fillMode:         Image.PreserveAspectFit
                            smooth:           true
                            mipmap:           true
                        }
                        Item { height: 10 }
                        Text {
                            width:          parent.width - 32
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:           qsTr("Die Strömlinge sind das lebendige Maskottchen-System von Strömling Design. Jeder Strömling repräsentiert einen elektrischen Leitertyp, ein Signal oder einen Systemzustand.")
                            font.pixelSize: 11
                            color:          root.theme.textMuted
                            wrapMode:       Text.WordWrap
                        }
                        Item { height: 8 }
                    }
                }

                // ── Sektion: Mitwirkende ─────────────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Mitwirkende")
                    font.pixelSize:      11
                    font.weight:         Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing:  1
                    color:               root.theme.textMuted
                }
                Item { height: 8 }

                Rectangle {
                    id:                 mitwCard
                    Layout.fillWidth:   true
                    Layout.leftMargin:  12
                    Layout.rightMargin: 12
                    implicitHeight:     mitwCol.implicitHeight + 24
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border

                    // ── Namen hier eintragen ──────────────────────
                    property var _fehlersuche: []
                    property var _tests:       ["Big B. hat fleißig das Programm missbraucht", "P.S. war sehr gründlich" ]
                    property var _design:      ["S.Z. hat des Strömling Design grundlegend definiert", "S.Z., M.M., J.T., M.T., A.R., K.K., Big B., K.M., A.K., P.S. haben mich grundlegend bei der rotierenden Logo Auswahl beeinflusst"]
                    property var _sonstiges:   []
                    // Beispiel: property var _fehlersuche: ["Max Muster", "Anna Beispiel"]

                    ColumnLayout {
                        id: mitwCol
                        anchors {
                            left:  parent.left;  leftMargin:  16
                            right: parent.right; rightMargin: 16
                            top:   parent.top;   topMargin:   16
                        }
                        spacing: 0

                        Text {
                            Layout.fillWidth:    true
                            Layout.bottomMargin: 16
                            text:     qsTr("Herzlichen Dank an alle, die durch Fehlermeldungen, Tests, Designfeedback und andere Beiträge zu diesem Projekt beitragen.")
                            font.pixelSize: 11
                            color:    root.theme.textMuted
                            wrapMode: Text.WordWrap
                        }

                        // ── Fehlersuche ───────────────────────────
                        Text {
                            Layout.bottomMargin: 6
                            text:                qsTr("Fehlersuche")
                            font.pixelSize:      9
                            font.weight:         Font.Medium
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing:  1.2
                            color:               root.theme.textMuted
                        }
                        Repeater {
                            id:    fehlerRep
                            model: mitwCard._fehlersuche
                            delegate: Text {
                                Layout.fillWidth:    true
                                Layout.bottomMargin: 4
                                text:           modelData
                                font.pixelSize: 12
                                color:          root.theme.textPrimary
                            }
                        }
                        Text {
                            Layout.bottomMargin: 4
                            visible:        fehlerRep.count === 0
                            text:           qsTr("(noch keine Einträge)")
                            font.pixelSize: 11
                            font.italic:    true
                            color:          root.theme.textMuted
                        }

                        // ── Tests ────────────────────────────────
                        Rectangle {
                            Layout.fillWidth:    true
                            Layout.topMargin:    10
                            Layout.bottomMargin: 10
                            height: 1; color: root.theme.divider
                        }
                        Text {
                            Layout.bottomMargin: 6
                            text:                qsTr("Tests")
                            font.pixelSize:      9
                            font.weight:         Font.Medium
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing:  1.2
                            color:               root.theme.textMuted
                        }
                        Repeater {
                            id:    testsRep
                            model: mitwCard._tests
                            delegate: Text {
                                Layout.fillWidth:    true
                                Layout.bottomMargin: 4
                                text:           modelData
                                font.pixelSize: 12
                                color:          root.theme.textPrimary
                            }
                        }
                        Text {
                            Layout.bottomMargin: 4
                            visible:        testsRep.count === 0
                            text:           qsTr("(noch keine Einträge)")
                            font.pixelSize: 11
                            font.italic:    true
                            color:          root.theme.textMuted
                        }

                        // ── Design ───────────────────────────────
                        Rectangle {
                            Layout.fillWidth:    true
                            Layout.topMargin:    10
                            Layout.bottomMargin: 10
                            height: 1; color: root.theme.divider
                        }
                        Text {
                            Layout.bottomMargin: 6
                            text:                qsTr("Design")
                            font.pixelSize:      9
                            font.weight:         Font.Medium
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing:  1.2
                            color:               root.theme.textMuted
                        }
                        Repeater {
                            id:    designRep
                            model: mitwCard._design
                            delegate: Text {
                                Layout.fillWidth:    true
                                Layout.bottomMargin: 4
                                text:           modelData
                                font.pixelSize: 12
                                color:          root.theme.textPrimary
                            }
                        }
                        Text {
                            Layout.bottomMargin: 4
                            visible:        designRep.count === 0
                            text:           qsTr("(noch keine Einträge)")
                            font.pixelSize: 11
                            font.italic:    true
                            color:          root.theme.textMuted
                        }

                        // ── Sonstiges ────────────────────────────
                        Rectangle {
                            Layout.fillWidth:    true
                            Layout.topMargin:    10
                            Layout.bottomMargin: 10
                            height: 1; color: root.theme.divider
                        }
                        Text {
                            Layout.bottomMargin: 6
                            text:                qsTr("Sonstiges")
                            font.pixelSize:      9
                            font.weight:         Font.Medium
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing:  1.2
                            color:               root.theme.textMuted
                        }
                        Repeater {
                            id:    sonstigesRep
                            model: mitwCard._sonstiges
                            delegate: Text {
                                Layout.fillWidth:    true
                                Layout.bottomMargin: 4
                                text:           modelData
                                font.pixelSize: 12
                                color:          root.theme.textPrimary
                            }
                        }
                        Text {
                            Layout.bottomMargin: 4
                            visible:        sonstigesRep.count === 0
                            text:           qsTr("(noch keine Einträge)")
                            font.pixelSize: 11
                            font.italic:    true
                            color:          root.theme.textMuted
                        }

                        Item { height: 8 }
                    }
                }

                // ── Sektion: Entstehung & KI-Werkzeuge ───────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Entstehung & KI-Werkzeuge")
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
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border
                    height:             entstehungCol.implicitHeight + 24

                    Column {
                        id:      entstehungCol
                        anchors {
                            left:    parent.left
                            right:   parent.right
                            top:     parent.top
                            margins: 12
                        }
                        spacing: 10

                        Text {
                            width:          parent.width
                            text:           qsTr("Strömling Design entstand am 08.04.2026 aus einem persönlichen Bedürfnis: Im Berufsalltag arbeite ich mit EPLAN P8 Electric, privat hatte ich QElectroTech genutzt — beides nicht das, was ich wollte. Also habe ich angefangen, selbst etwas zu bauen.")
                            font.pixelSize: 12
                            color:          root.theme.textPrimary
                            wrapMode:       Text.WordWrap
                        }
                        Text {
                            width:          parent.width
                            text:           qsTr("Den Begriff \"Strömlinge\" kenne ich noch aus meiner Lehrzeit um die Jahrtausendwende — endlich konnte ich ihn mal verwenden.")
                            font.pixelSize: 12
                            color:          root.theme.textPrimary
                            wrapMode:       Text.WordWrap
                        }

                        Rectangle { width: parent.width; height: 1; color: root.theme.border }

                        Text {
                            width:          parent.width
                            text:           qsTr("Dieses Projekt wurde mit Unterstützung von KI-Werkzeugen entwickelt:")
                            font.pixelSize: 12
                            color:          root.theme.textPrimary
                            wrapMode:       Text.WordWrap
                        }
                        Column {
                            width:   parent.width
                            spacing: 4
                            Repeater {
                                model: [
                                    qsTr("⚙  Claude Code (Anthropic) — Code & Konzepte"),
                                    qsTr("🖼  ChatGPT / DALL-E (OpenAI) — Strömlinge-Bilder")
                                ]
                                Text {
                                    width:          parent.width
                                    text:           modelData
                                    font.pixelSize: 12
                                    color:          root.theme.textSecondary
                                    wrapMode:       Text.WordWrap
                                }
                            }
                        }
                        Text {
                            width:          parent.width
                            text:           qsTr("Der Quellcode, alle Konzepte und die Projektidee stammen von mir. KI hat geholfen, sie umzusetzen — schneller und mit mehr Funktionen als ich es allein geschafft hätte.")
                            font.pixelSize: 11
                            color:          root.theme.textMuted
                            wrapMode:       Text.WordWrap
                        }
                        Item { height: 2 }
                    }
                }

                // ── Sektion: Lizenz & Open Source ────────────────
                Item { height: 28 }
                Text {
                    Layout.leftMargin:   20
                    text:                qsTr("Lizenz & Open Source")
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
                    color:              root.theme.surface
                    radius:             6
                    border.color:       root.theme.border
                    height:             lizenzCol.implicitHeight + 24

                    Column {
                        id:               lizenzCol
                        anchors {
                            left:         parent.left
                            right:        parent.right
                            top:          parent.top
                            margins:      12
                        }
                        spacing: 8

                        Text {
                            width:          parent.width
                            text:           qsTr("Strömling Design ist freie Software, lizenziert unter der GNU General Public License v3.")
                            font.pixelSize: 12
                            color:          root.theme.textPrimary
                            wrapMode:       Text.WordWrap
                        }
                        Column {
                            width:   parent.width
                            spacing: 4
                            Repeater {
                                model: [
                                    qsTr("✓  Privat nutzbar – kostenlos"),
                                    qsTr("✓  Bildungseinrichtungen – kostenlos"),
                                    qsTr("✓  Quellcode öffentlich einsehbar"),
                                    qsTr("✓  Zukünftige Versionen bleiben Open Source"),
                                    qsTr("✓  Beiträge und Verbesserungen willkommen")
                                ]
                                delegate: Text {
                                    width:          parent.width
                                    text:           modelData
                                    font.pixelSize: 12
                                    color:          root.theme.textPrimary
                                    wrapMode:       Text.WordWrap
                                }
                            }
                        }
                        Text {
                            width:          parent.width
                            text:           qsTr("Wenn dir das Programm nützt, freue ich mich über eine Spende – das hilft, das Projekt weiterzuentwickeln.")
                            font.pixelSize: 11
                            font.italic:    true
                            color:          root.theme.textMuted
                            wrapMode:       Text.WordWrap
                            topPadding:     4
                        }
                        Text {
                            width:          parent.width
                            text:           "GPL-3.0-or-later · https://www.gnu.org/licenses/gpl-3.0.txt"
                            font.pixelSize: 10
                            font.family:    "monospace"
                            color:          root.theme.textMuted
                            wrapMode:       Text.WordWrap
                        }
                    }
                }

                Item { height: 32 }
            }
        }
    }
}
