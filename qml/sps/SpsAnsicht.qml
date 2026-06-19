import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../components"

Item {
    id: root

    property int projektId: -1
    property var theme
    property bool debug: false

    // ── Auswahl-State ────────────────────────────────────────────
    property int _ausgewaehlterRackId:      -1
    property int _ausgewaehlterRackNr:       0
    property string _ausgewaehlterSystemTyp: "SPS"
    property int _ausgewaehlterBaugruppeId: -1
    property int _ausgewaehlterKanalId:     -1

    // ── Daten ────────────────────────────────────────────────────
    property var _racks:       []
    property var _baugruppen:  []
    property var _kanaele:     []
    property string _kanalFilter: "alle"
    property var _pendingAutoAnlegenBg: null

    function _ladeRacks() {
        if (root.projektId < 0) { _racks = []; return }
        _racks = db.spsRackListe(root.projektId)
        if (_ausgewaehlterRackId < 0 && _racks.length > 0) {
            _waehleRack(_racks[0])
        } else {
            _ladeBaugruppen()
        }
    }

    function _waehleRack(rack) {
        _ausgewaehlterRackId      = rack.id
        _ausgewaehlterRackNr      = rack.rack_nr
        _ausgewaehlterSystemTyp   = rack.system_typ
        _ausgewaehlterBaugruppeId = -1
        _ladeBaugruppen()
    }

    function _ladeBaugruppen() {
        if (_ausgewaehlterRackId < 0) { _baugruppen = []; return }
        _baugruppen = db.spsBaugruppeListe(_ausgewaehlterRackId)
        _ladeKanaele()
    }

    function _ladeKanaele() {
        if (root.projektId < 0) { _kanaele = []; return }
        _kanaele = db.spsKanalListe(root.projektId)
    }

    function _ausgewaehlterRackInfo() {
        for (var i = 0; i < _racks.length; i++)
            if (_racks[i].id === _ausgewaehlterRackId) return _racks[i]
        return null
    }

    function _kanaeleAutoAnlegen(bg) {
        if (!bg) return
        var keinIO = ["CPU", "PS", "CP", "FM", "andere"]
        for (var ki = 0; ki < keinIO.length; ki++) {
            if (bg.typ === keinIO[ki]) {
                meldungManager.zeigen(qsTr("%1-Baugruppen haben keine I/O-Kanäle").arg(bg.typ), false)
                return
            }
        }
        var isPls  = root._ausgewaehlterSystemTyp === "PLS"
        var n      = bg.kanaele
        var count  = 0
        var i, newId, byteNr, bitNr

        if (isPls) {
            var adressTypPls = (bg.typ === "AO" || bg.typ === "DO") ? "A" : "E"
            for (i = 0; i < n; i++) {
                newId = db.spsKanalAnlegen(root.projektId, bg.id, i,
                                           adressTypPls, 0, 0, "REAL", "", "")
                if (newId > 0) count++
            }
        } else {
            var isAnalog = (bg.typ === "AI" || bg.typ === "AO" || bg.typ === "AIO")
            var isDual   = (bg.typ === "DIO" || bg.typ === "AIO")
            var datentyp = isAnalog ? "WORD" : "BOOL"
            var byteStep = isAnalog ? 2 : 1
            var nE = isDual ? Math.ceil(n / 2) : n
            var nA = isDual ? Math.floor(n / 2) : n
            var machE = (bg.typ === "DI" || bg.typ === "AI" || bg.typ === "DIO" || bg.typ === "AIO")
            var machA = (bg.typ === "DO" || bg.typ === "AO" || bg.typ === "DIO" || bg.typ === "AIO")

            if (machE) {
                for (i = 0; i < nE; i++) {
                    if (isAnalog) { byteNr = bg.adress_byte_start + i * byteStep; bitNr = -1 }
                    else          { byteNr = bg.adress_byte_start + Math.floor(i / 8); bitNr = i % 8 }
                    newId = db.spsKanalAnlegen(root.projektId, bg.id, i,
                                               "E", byteNr, bitNr, datentyp, "", "")
                    if (newId > 0) count++
                }
            }
            if (machA) {
                for (i = 0; i < nA; i++) {
                    if (isAnalog) { byteNr = bg.adress_byte_start + i * byteStep; bitNr = -1 }
                    else          { byteNr = bg.adress_byte_start + Math.floor(i / 8); bitNr = i % 8 }
                    newId = db.spsKanalAnlegen(root.projektId, bg.id, i,
                                               "A", byteNr, bitNr, datentyp, "", "")
                    if (newId > 0) count++
                }
            }
        }

        root._ladeKanaele()
        if (count > 0)
            meldungManager.zeigen(count + " " + qsTr("Kanäle angelegt"), true)
        else
            meldungManager.zeigen(qsTr("Keine neuen Kanäle – Adresskonflikte oder bereits vorhanden"), false)
    }

    onProjektIdChanged: _ladeRacks()

    Component.onCompleted: _ladeRacks()

    // ── Rack-Dialog ───────────────────────────────────────────────
    SpsRackDialog {
        id: rackDialog
        theme: root.theme
        projektId: root.projektId
        onGespeichert: function(newId) {
            _ladeRacks()
            if (newId > 0) {
                for (var i = 0; i < _racks.length; i++)
                    if (_racks[i].id === newId) { _waehleRack(_racks[i]); break }
            }
        }
        onFehler: function(meldung) { meldungManager.zeigen(meldung, false) }
    }

    // ── Baugruppe-Dialog ──────────────────────────────────────────
    SpsBaugruppeDialog {
        id: bgDialog
        theme: root.theme
        rackId: root._ausgewaehlterRackId
        onGespeichert: function(newId) {
            if (newId > 0) root._ausgewaehlterBaugruppeId = newId
            _ladeBaugruppen()
        }
        onFehler: function(meldung) { meldungManager.zeigen(meldung, false) }
    }

    // ── Auto-Anlegen Bestätigung ──────────────────────────────────
    SpsAutoAnlegenDialog {
        id: autoAnlegenDialog
        theme: root.theme
        bg: root._pendingAutoAnlegenBg
        onBestaetigt: root._kanaeleAutoAnlegen(root._pendingAutoAnlegenBg)
    }

    // ── Kanal-Dialog ──────────────────────────────────────────────
    SpsKanalDialog {
        id: kanalDialog
        theme: root.theme
        projektId: root.projektId
        systemTyp: root._ausgewaehlterSystemTyp
        baugruppen: root._baugruppen
        aktBaugruppeId: root._ausgewaehlterBaugruppeId
        onGespeichert: function(newId) {
            if (newId > 0) root._ausgewaehlterKanalId = newId
            _ladeKanaele()
        }
        onFehler: function(meldung) { meldungManager.zeigen(meldung, false) }
    }

    // ── Export-Dialoge ────────────────────────────────────────────
    FileDialog {
        id: exportDialog
        fileMode: FileDialog.SaveFile
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: {
            var ok = db.spsIOListeCsvSpeichern(root.projektId, selectedFile)
            meldungManager.zeigen(ok ? qsTr("I/O-Liste exportiert") : qsTr("Export fehlgeschlagen"), ok)
        }
    }

    // ── Haupt-Layout ──────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tab-Bar
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            background: Rectangle { color: root.theme.surface }

            TabButton {
                text: qsTr("Hardware")
                background: Rectangle {
                    color: tabBar.currentIndex === 0 ? root.theme.accent : root.theme.surface
                    opacity: tabBar.currentIndex === 0 ? 0.12 : 0
                }
                contentItem: Label {
                    text: parent.text
                    color: tabBar.currentIndex === 0 ? root.theme.accent : root.theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            TabButton {
                text: qsTr("Kanäle / Adressen")
                background: Rectangle {
                    color: root.theme.accent
                    opacity: tabBar.currentIndex === 1 ? 0.12 : 0
                }
                contentItem: Label {
                    text: parent.text
                    color: tabBar.currentIndex === 1 ? root.theme.accent : root.theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            TabButton {
                text: qsTr("Export")
                background: Rectangle {
                    color: root.theme.accent
                    opacity: tabBar.currentIndex === 2 ? 0.12 : 0
                }
                contentItem: Label {
                    text: parent.text
                    color: tabBar.currentIndex === 2 ? root.theme.accent : root.theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

        // Tab-Inhalt
        StackLayout {
            currentIndex: tabBar.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Tab 0: Hardware ───────────────────────────────────
            Item {
                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ── Rack-Liste (links) ────────────────────────
                    ColumnLayout {
                        Layout.preferredWidth: 200
                        Layout.fillHeight: true
                        spacing: 0

                        // Header
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: root.theme.surfaceDeep

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 2

                                Label {
                                    text: qsTr("Racks")
                                    color: root.theme.textPrimary
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                RoundButton {
                                    text: "+"
                                    width: 26; height: 26
                                    font.pixelSize: 14
                                    palette.button:     root.theme.border
                                    palette.buttonText: root.theme.accent
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Rack anlegen")
                                    onClicked: rackDialog.oeffnenNeu()
                                }
                            }
                        }

                        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

                        ListView {
                            id: rackListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: root._racks
                            clip: true

                            Label {
                                anchors.centerIn: parent
                                visible: rackListView.count === 0
                                text: root.projektId < 0
                                      ? qsTr("Kein Projekt geöffnet")
                                      : qsTr("Noch keine Racks –\n[+] zum Anlegen")
                                horizontalAlignment: Text.AlignHCenter
                                color: root.theme.textMuted
                                font.pixelSize: 12
                            }

                            delegate: Rectangle {
                                id: rackDelegate
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 52
                                color: modelData.id === root._ausgewaehlterRackId
                                       ? Qt.rgba(root.theme.accent.r ?? 0.2,
                                                  root.theme.accent.g ?? 0.6,
                                                  root.theme.accent.b ?? 1.0, 0.15)
                                       : (rackHover.containsMouse ? root.theme.hover : root.theme.surface)

                                HoverHandler { id: rackHover }

                                ColumnLayout {
                                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 4 }
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Label {
                                        text: modelData.bezeichnung || ("Rack " + modelData.rack_nr)
                                        color: root.theme.textPrimary
                                        font.bold: modelData.id === root._ausgewaehlterRackId
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        text: "[" + modelData.system_typ + "] R" + modelData.rack_nr
                                            + (modelData.hersteller ? " · " + modelData.hersteller : "")
                                        color: root.theme.textMuted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root._waehleRack(rackDelegate.modelData)
                                    onDoubleClicked: rackDialog.oeffnenEdit(rackDelegate.modelData)
                                }

                                RoundButton {
                                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                    text: "✕"
                                    width: 22; height: 22
                                    font.pixelSize: 11
                                    visible: rackHover.containsMouse
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Rack löschen (alle Baugruppen + Kanäle)")
                                    onClicked: {
                                        if (db.spsRackLoeschen(rackDelegate.modelData.id)) {
                                            root._ausgewaehlterRackId = -1
                                            root._ladeRacks()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: 1; color: root.theme.border; Layout.fillHeight: true }

                    // ── Baugruppen-Liste (rechts) ─────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        // Header
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: root.theme.surfaceDeep

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 4

                                Label {
                                    text: {
                                        var r = root._ausgewaehlterRackInfo()
                                        if (!r) return qsTr("Baugruppen")
                                        return qsTr("Baugruppen in \"%1\" (%2)").arg(r.bezeichnung).arg(r.system_typ)
                                    }
                                    color: root.theme.textPrimary
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                RoundButton {
                                    text: "+"
                                    width: 26; height: 26
                                    font.pixelSize: 14
                                    enabled: root._ausgewaehlterRackId >= 0
                                    palette.button:     root.theme.border
                                    palette.buttonText: root.theme.accent
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Baugruppe anlegen")
                                    onClicked: bgDialog.oeffnenNeu()
                                }
                            }
                        }

                        // Spaltenköpfe
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            color: root.theme.surfaceDeep

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                spacing: 0

                                Label { text: "Slot"; color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 40 }
                                Label { text: "Typ";  color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 50 }
                                Label { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                                Label { text: qsTr("Kanäle"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 55 }
                                Label { text: qsTr("Startbyte"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                                Item { Layout.preferredWidth: 54 }
                            }
                        }

                        Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

                        ListView {
                            id: bgListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: root._baugruppen
                            clip: true

                            delegate: Rectangle {
                                id: bgDelegate
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 40
                                color: modelData.id === root._ausgewaehlterBaugruppeId
                                       ? Qt.rgba(0.2, 0.6, 1.0, 0.10)
                                       : (bgHover.containsMouse ? root.theme.hover : (index % 2 ? root.theme.surface : root.theme.surfaceDeep))

                                HoverHandler { id: bgHover }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 4
                                    spacing: 0

                                    Label { text: modelData.slot;        color: root.theme.textPrimary; Layout.preferredWidth: 40 }
                                    Label {
                                        text: modelData.typ
                                        color: {
                                            switch(modelData.typ) {
                                            case "DI": case "AI": return "#4caf50"
                                            case "DO": case "AO": return "#f44336"
                                            case "CPU": return "#2196f3"
                                            default: return root.theme.textMuted
                                            }
                                        }
                                        font.bold: true
                                        Layout.preferredWidth: 50
                                    }
                                    Label { text: modelData.bezeichnung; color: root.theme.textPrimary; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Label { text: modelData.kanaele;     color: root.theme.textMuted; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignHCenter }
                                    Label {
                                        text: (root._ausgewaehlterSystemTyp === "SPS") ? modelData.adress_byte_start : "–"
                                        color: root.theme.textMuted
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    RoundButton {
                                        text: "⚡"
                                        width: 22; height: 22
                                        font.pixelSize: 11
                                        visible: bgHover.containsMouse
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Kanäle automatisch anlegen")
                                        onClicked: {
                                            var bg = bgDelegate.modelData
                                            var vorh = db.spsKanalListeFuerBaugruppe(bg.id)
                                            if (vorh.length > 0) {
                                                root._pendingAutoAnlegenBg = bg
                                                autoAnlegenDialog.open()
                                            } else {
                                                root._kanaeleAutoAnlegen(bg)
                                            }
                                        }
                                    }
                                    RoundButton {
                                        text: "✕"
                                        width: 22; height: 22
                                        font.pixelSize: 11
                                        visible: bgHover.containsMouse
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Baugruppe löschen")
                                        onClicked: {
                                            if (db.spsBaugruppeLoeschen(bgDelegate.modelData.id)) {
                                                if (root._ausgewaehlterBaugruppeId === bgDelegate.modelData.id)
                                                    root._ausgewaehlterBaugruppeId = -1
                                                root._ladeBaugruppen()
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root._ausgewaehlterBaugruppeId = bgDelegate.modelData.id
                                    onDoubleClicked: bgDialog.oeffnenEdit(bgDelegate.modelData)
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: root._ausgewaehlterRackId < 0
                                      ? qsTr("Rack auswählen")
                                      : qsTr("Keine Baugruppen – [+] zum Anlegen")
                                color: root.theme.textMuted
                                visible: root._baugruppen.length === 0
                            }
                        }
                    }
                }
            }

            // ── Tab 1: Kanäle / Adressen ──────────────────────────
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Filter + Toolbar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: root.theme.surfaceDeep

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Label { text: qsTr("Filter:"); color: root.theme.textMuted }
                            ComboBox {
                                model: ["alle","E (Eingang)","A (Ausgang)","M (Merker)","PLS-AI","PLS-AO"]
                                Layout.preferredWidth: 140
                                onActivated: root._kanalFilter = model[currentIndex]
                                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: _gefiltert.length + " " + qsTr("Kanäle")
                                color: root.theme.textMuted
                                font.pixelSize: 11
                            }
                            RoundButton {
                                text: "+"
                                width: 26; height: 26
                                font.pixelSize: 14
                                enabled: root.projektId >= 0
                                palette.button:     root.theme.border
                                palette.buttonText: root.theme.accent
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Kanal anlegen")
                                onClicked: kanalDialog.oeffnenNeu()
                            }
                        }
                    }

                    // Spaltenkopf
                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        color: root.theme.surfaceDeep

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            spacing: 0
                            Label { text: qsTr("Adresse"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 100 }
                            Label { text: qsTr("Typ"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 50 }
                            Label { text: qsTr("Variable / Tag"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 130 }
                            Label { text: qsTr("Kommentar"); color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                            Label { text: qsTr("Einheit"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 55 }
                            Label { text: qsTr("Bereich"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 90 }
                            Label { text: qsTr("Element"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 120 }
                            Item { Layout.preferredWidth: 28 }
                        }
                    }

                    Rectangle { height: 1; color: root.theme.border; Layout.fillWidth: true }

                    property var _gefiltert: {
                        var f = root._kanalFilter
                        if (f === "alle") return root._kanaele
                        if (f === "E (Eingang)") return root._kanaele.filter(function(k) { return k.adress_typ === "E" })
                        if (f === "A (Ausgang)")  return root._kanaele.filter(function(k) { return k.adress_typ === "A" })
                        if (f === "M (Merker)")   return root._kanaele.filter(function(k) { return k.adress_typ === "M" })
                        if (f === "PLS-AI")       return root._kanaele.filter(function(k) { return k.system_typ === "PLS" && k.adress_typ === "E" })
                        if (f === "PLS-AO")       return root._kanaele.filter(function(k) { return k.system_typ === "PLS" && k.adress_typ === "A" })
                        return root._kanaele
                    }

                    ListView {
                        id: kanalListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: parent._gefiltert
                        clip: true

                        delegate: Rectangle {
                            id: kanalDelegate
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 38
                            color: modelData.id === root._ausgewaehlterKanalId
                                   ? Qt.rgba(0.2, 0.6, 1.0, 0.12)
                                   : (kanalHover.containsMouse ? root.theme.hover : (index % 2 ? root.theme.surface : root.theme.surfaceDeep))

                            HoverHandler { id: kanalHover }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 0

                                Label {
                                    text: modelData.adresse || "?"
                                    color: root.theme.accent
                                    font.family: "monospace"
                                    font.bold: true
                                    Layout.preferredWidth: 100
                                }
                                Label {
                                    text: (modelData.system_typ === "PLS" ? "PLS " : "") + modelData.datentyp
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 50
                                }
                                Label {
                                    text: modelData.variablenname || ""
                                    color: root.theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.preferredWidth: 130
                                }
                                Label {
                                    text: modelData.kommentar || ""
                                    color: root.theme.textMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: modelData.pls_einheit || ""
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 55
                                }
                                Label {
                                    text: {
                                        if (modelData.pls_bereich_min == null) return ""
                                        return modelData.pls_bereich_min + " – " + modelData.pls_bereich_max
                                    }
                                    color: root.theme.textMuted
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 90
                                }
                                Label {
                                    id: elementLabel
                                    property string _bmk: {
                                        var ed = modelData.element_extra_daten
                                        if (!ed) return ""
                                        try { return JSON.parse(ed).bmk || "" } catch(e) { return "" }
                                    }
                                    text: _bmk
                                          ? _bmk + (modelData.seite_name ? " · " + modelData.seite_name : "")
                                          : (modelData.grafik_element_id ? "–" : "")
                                    color: _bmk ? root.theme.accent : root.theme.borderLight
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.preferredWidth: 120
                                    ToolTip.visible: _bmk && elemLabelMa.containsMouse
                                    ToolTip.text: _bmk + (modelData.seite_name ? "  (" + modelData.seite_name + ")" : "")
                                    ToolTip.delay: 400
                                    MouseArea { id: elemLabelMa; anchors.fill: parent; hoverEnabled: true }
                                }
                                RoundButton {
                                    text: "✕"
                                    width: 22; height: 22
                                    font.pixelSize: 11
                                    visible: kanalHover.containsMouse
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Kanal löschen")
                                    onClicked: {
                                        if (db.spsKanalLoeschen(kanalDelegate.modelData.id)) {
                                            if (root._ausgewaehlterKanalId === kanalDelegate.modelData.id)
                                                root._ausgewaehlterKanalId = -1
                                            root._ladeKanaele()
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root._ausgewaehlterKanalId = kanalDelegate.modelData.id
                                onDoubleClicked: kanalDialog.oeffnenEdit(kanalDelegate.modelData)
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            text: root._kanaele.length === 0
                                  ? qsTr("Keine Kanäle – [+] zum Anlegen")
                                  : qsTr("Alle Kanäle gefiltert")
                            color: root.theme.textMuted
                            visible: kanalListView.count === 0
                        }
                    }
                }
            }

            // ── Tab 2: Export ─────────────────────────────────────
            Item {
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 20
                    width: Math.min(parent.width - 80, 500)

                    Label {
                        text: qsTr("Export")
                        font.pixelSize: 18
                        font.bold: true
                        color: root.theme.textPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Label {
                        text: qsTr("Alle %1 Kanäle des Projekts als I/O-Liste exportieren.").arg(root._kanaele.length)
                        color: root.theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Button {
                        text: qsTr("I/O-Liste als CSV exportieren")
                        Layout.alignment: Qt.AlignHCenter
                        enabled: root._kanaele.length > 0
                        onClicked: exportDialog.open()
                        background: Rectangle {
                            color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                            radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                        }
                        contentItem: Text { text: parent.text; color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted;
                                            font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }

                    Label {
                        text: qsTr("CSV-Format: Adresse, System, Typ, Variable/Tag, Kommentar,\nEinheit, Bereich, Alarme (LL/LO/HI/HH), Protokoll, Element-ID\n\nKompatibel mit Excel (UTF-8 BOM, Semikolon-getrennt).")
                        color: root.theme.textMuted
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

    }

    DebugLabel { panelName: qsTr("SPS-Ansicht"); visible: root.debug }
}
