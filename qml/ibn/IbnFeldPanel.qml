import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import stroemling
import "../components"

Item {
    id: root
    required property var theme
    property bool debug: false

    signal felderGeaendert()

    property var    _vorlagen:     []
    property var    _kategorien:   []
    property string _selKat:       ""
    property int    _editId:       -1   // -1 = neu, >= 0 = bestehendes Feld
    property bool   _formSichtbar: false
    property string _fehler:       ""
    property bool   _neuKatSichtbar: false

    property var _katFelder: {
        if (root._selKat === "") return []
        var kat = root._selKat
        return root._vorlagen.filter(function(v) { return v.symbolKategorie === kat })
    }

    function laden() {
        root._vorlagen   = db.ibnAlleVorlagenLaden()
        root._kategorien = db.ibnAlleKategorienLaden()
        if (root._selKat === "" && root._kategorien.length > 0)
            root._selKat = root._kategorien[0].toString()
    }

    function _formReset() {
        tfFeldname.text = ""
        tfLabel.text    = ""
        cmbTyp.currentIndex = 0
        tfOptionen.text = ""
        tfEinheit.text  = ""
        cbPflicht.checked = false
        root._fehler  = ""
        root._editId  = -1
    }

    function _editLaden(v) {
        root._editId = v.id
        tfLabel.text = v.label || ""
        var typen = ["text", "zahl", "boolean", "auswahl"]
        var idx = typen.indexOf(v.feldtyp)
        cmbTyp.currentIndex = idx >= 0 ? idx : 0
        tfOptionen.text = v.optionen  || ""
        tfEinheit.text  = v.einheit   || ""
        cbPflicht.checked = v.pflichtfeld === 1 || v.pflichtfeld === true
        root._fehler = ""
        root._formSichtbar = true
    }

    function _speichern() {
        var lbl = tfLabel.text.trim()
        var typ = ["text", "zahl", "boolean", "auswahl"][cmbTyp.currentIndex]
        var opt = (typ === "auswahl") ? tfOptionen.text.trim() : ""
        var ein = tfEinheit.text.trim()

        if (!lbl) { root._fehler = qsTr("Label fehlt."); return }
        if (typ === "auswahl" && !opt) { root._fehler = qsTr("Optionen fehlen (kommagetrennt)."); return }

        var ok
        if (root._editId >= 0) {
            ok = db.ibnFeldVorlageAktualisieren(root._editId, lbl, typ, opt, ein, cbPflicht.checked)
        } else {
            var fn = tfFeldname.text.trim().toLowerCase().replace(/\s+/g, "_")
            if (!fn) { root._fehler = qsTr("Feldname fehlt."); return }
            ok = db.ibnFeldVorlageSpeichern(root._selKat, fn, lbl, typ, opt, ein, cbPflicht.checked)
        }

        if (!ok) { root._fehler = qsTr("Fehler beim Speichern."); return }
        root.felderGeaendert()
        _formReset()
        root._formSichtbar = false
        laden()
    }

    function _loeschen(id) {
        db.ibnFeldVorlageLoeschen(id)
        if (root._editId === id) { _formReset(); root._formSichtbar = false }
        root.felderGeaendert()
        laden()
    }

    function _kategorieAnlegen() {
        var kat = tfNeuKat.text.trim()
        if (!kat) return
        // Nur lokal vormerken – wird persistent wenn erstes Feld angelegt wird
        var bereits = false
        for (var i = 0; i < root._kategorien.length; i++) {
            if (root._kategorien[i].toString() === kat) { bereits = true; break }
        }
        if (!bereits) root._kategorien = root._kategorien.concat([kat])
        root._selKat = kat
        tfNeuKat.text = ""
        root._neuKatSichtbar = false
        _formReset()
        root._formSichtbar = true
    }

    onVisibleChanged: { if (visible) laden() }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Linke Spalte: Kategorie-Liste ─────────────────────
        Rectangle {
            Layout.preferredWidth: 170
            Layout.fillHeight: true
            color: root.theme.surfaceDeep

            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: 1; color: root.theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Spaltenheader
                Rectangle {
                    Layout.fillWidth: true; height: 30
                    color: root.theme.surfaceDeep
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1; color: root.theme.border
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: qsTr("KATEGORIE")
                        font.pixelSize: 9; font.weight: Font.Medium
                        color: root.theme.textMuted
                        font.capitalization: Font.AllUppercase
                    }
                }

                // Kategorie-Liste
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Column {
                        width: parent.width

                        Repeater {
                            model: root._kategorien
                            delegate: Rectangle {
                                required property var  modelData
                                required property int  index
                                width: parent.width; height: 34
                                color: root._selKat === modelData.toString()
                                       ? root.theme.activeItemAlt
                                       : (katHover.containsMouse ? root.theme.hover : "transparent")

                                HoverHandler { id: katHover }

                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                    width: 3; color: root.theme.accent
                                    visible: root._selKat === modelData.toString()
                                }

                                Text {
                                    anchors {
                                        left: parent.left; leftMargin: 16
                                        right: parent.right; rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: modelData.toString()
                                    font.pixelSize: 11; elide: Text.ElideRight
                                    color: root._selKat === modelData.toString()
                                           ? root.theme.textPrimary
                                           : root.theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root._selKat = modelData.toString()
                                        _formReset()
                                        root._formSichtbar = false
                                    }
                                }
                            }
                        }
                    }
                }

                // Neue Kategorie
                Rectangle {
                    Layout.fillWidth: true
                    height: root._neuKatSichtbar ? 78 : 32
                    clip: true
                    color: root.theme.surfaceDeep
                    Behavior on height { NumberAnimation { duration: 140 } }

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 1; color: root.theme.border
                    }

                    Column {
                        anchors { fill: parent; margins: 6 }
                        spacing: 4

                        Rectangle {
                            width: parent.width; height: 22; radius: 4
                            color: neuKatHover.containsMouse
                                   ? root.theme.hover : root.theme.inputBg
                            border.color: root.theme.border
                            HoverHandler { id: neuKatHover }
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("+ Neue Kategorie")
                                font.pixelSize: 10; color: root.theme.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root._neuKatSichtbar = !root._neuKatSichtbar
                            }
                        }

                        TextField {
                            id: tfNeuKat
                            visible: root._neuKatSichtbar
                            width: parent.width; implicitHeight: 22
                            placeholderText: qsTr("Kategoriename")
                            font.pixelSize: 11; color: root.theme.textPrimary
                            background: Rectangle {
                                color: root.theme.inputBg; radius: 3
                                border.color: root.theme.border
                            }
                            Keys.onReturnPressed: root._kategorieAnlegen()
                        }

                        Rectangle {
                            visible: root._neuKatSichtbar
                            width: parent.width; height: 22; radius: 3
                            color: anlHover.containsMouse ? root.theme.accent : root.theme.inputBg
                            border.color: root.theme.accent
                            HoverHandler { id: anlHover }
                            Text {
                                anchors.centerIn: parent; text: qsTr("Anlegen")
                                font.pixelSize: 10
                                color: anlHover.containsMouse ? "white" : root.theme.textPrimary
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root._kategorieAnlegen()
                            }
                        }
                    }
                }
            }
        }

        // ── Rechte Spalte: Felder + Formular ──────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Rechte Spalte: Header
            Rectangle {
                Layout.fillWidth: true; height: 30
                color: root.theme.surface
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1; color: root.theme.border
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    Text {
                        text: root._selKat !== ""
                              ? (qsTr("Felder fuer: ") + root._selKat)
                              : qsTr("Kategorie waehlen")
                        font.pixelSize: 11; font.weight: Font.Medium
                        color: root._selKat !== "" ? root.theme.textPrimary : root.theme.textMuted
                        font.italic: root._selKat === ""
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: root._selKat !== ""
                        text: root._katFelder.length + qsTr(" Felder")
                        font.pixelSize: 10; color: root.theme.textMuted
                    }
                }
            }

            // Leerzustand wenn keine Kategorie gewählt
            Item {
                visible: root._selKat === ""
                Layout.fillWidth: true; Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Kategorie in der linken Liste waehlen\noder neue Kategorie anlegen.")
                    color: root.theme.textMuted; font.pixelSize: 11; font.italic: true
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
            }

            // Feldliste
            ScrollView {
                visible: root._selKat !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: feldListe
                    width: parent.width
                    model: root._katFelder

                    Text {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 24 }
                        visible: feldListe.count === 0 && root._selKat !== ""
                        text: qsTr("Noch keine Felder in dieser Kategorie.")
                        color: root.theme.textMuted; font.pixelSize: 11; font.italic: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: feldListe.width; height: 38
                        color: root._editId === modelData.id
                               ? root.theme.activeItemAlt
                               : (reiheHover.containsMouse ? root.theme.hover : "transparent")

                        HoverHandler { id: reiheHover }

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1; color: root.theme.divider
                        }

                        // Linker Akzentstreifen wenn im Bearbeitungsmodus
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: 3; color: root.theme.accent
                            visible: root._editId === modelData.id
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 6

                            // ≡ Sortier-Handle (visuell)
                            Text {
                                text: "≡"; font.pixelSize: 14
                                color: root.theme.borderLight
                                opacity: modelData.erstelltVon === "user" ? 0.8 : 0.3
                            }

                            // Label + interner Feldname
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text {
                                    text: modelData.label
                                    font.pixelSize: 11; elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    color: modelData.erstelltVon === "system"
                                           ? root.theme.textMuted
                                           : root.theme.textPrimary
                                }
                                Text {
                                    text: modelData.feldname
                                    font.pixelSize: 9; elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    color: root.theme.borderLight
                                }
                            }

                            // Typ (kurzform)
                            Text {
                                text: {
                                    switch (modelData.feldtyp) {
                                        case "zahl":    return qsTr("Zahl")
                                        case "boolean": return qsTr("Bool.")
                                        case "auswahl": return qsTr("Ausw.")
                                        default:        return qsTr("Text")
                                    }
                                }
                                font.pixelSize: 10; color: root.theme.textMuted; width: 34
                            }

                            // Einheit
                            Text {
                                text: modelData.einheit || "–"
                                font.pixelSize: 10; color: root.theme.borderLight; width: 22
                            }

                            // [✎] Bearbeiten (nur user-Felder)
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                visible: modelData.erstelltVon === "user"
                                color: editHover.hovered ? root.theme.hover : "transparent"
                                border.color: editHover.hovered ? root.theme.border : "transparent"
                                HoverHandler { id: editHover }
                                Text {
                                    anchors.centerIn: parent; text: "✎"
                                    font.pixelSize: 11; color: root.theme.textMuted
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root._editLaden(modelData)
                                }
                            }
                            Item { visible: modelData.erstelltVon !== "user"; width: 22; height: 22 }

                            // [×] Löschen (nur user-Felder)
                            Rectangle {
                                width: 22; height: 22; radius: 3
                                visible: modelData.erstelltVon === "user"
                                color: delHover.hovered ? "#2a1515" : "transparent"
                                border.color: delHover.hovered ? "#cc4444" : "transparent"
                                HoverHandler { id: delHover }
                                Text {
                                    anchors.centerIn: parent; text: "✕"
                                    font.pixelSize: 11; color: "#cc4444"
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root._loeschen(modelData.id)
                                }
                            }
                            Item { visible: modelData.erstelltVon !== "user"; width: 22; height: 22 }
                        }
                    }
                }
            }

            // Trennlinie vor Formular/Footer
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: root.theme.border
                visible: root._selKat !== ""
            }

            // Inline-Formular (Anlegen / Bearbeiten)
            Rectangle {
                id: formBereich
                visible: root._formSichtbar && root._selKat !== ""
                Layout.fillWidth: true
                implicitHeight: visible ? formLayout.implicitHeight + 24 : 0
                color: root.theme.surface
                clip: true

                Behavior on implicitHeight { NumberAnimation { duration: 160 } }

                ColumnLayout {
                    id: formLayout
                    anchors {
                        left: parent.left; right: parent.right
                        top: parent.top
                        leftMargin: 14; rightMargin: 14; topMargin: 10
                    }
                    spacing: 6

                    Text {
                        text: root._editId >= 0 ? qsTr("Feld bearbeiten") : qsTr("Neues Feld anlegen")
                        font.pixelSize: 11; font.weight: Font.Medium
                        color: root.theme.textPrimary
                    }

                    // Feldname (nur bei Neuanlage)
                    RowLayout {
                        visible: root._editId < 0
                        Layout.fillWidth: true; spacing: 8
                        Text { text: qsTr("Feldname *"); font.pixelSize: 10
                            color: root.theme.textMuted; Layout.preferredWidth: 72 }
                        TextField {
                            id: tfFeldname
                            Layout.fillWidth: true; implicitHeight: 26
                            placeholderText: qsTr("intern, z. B. messwert_r")
                            font.pixelSize: 11; color: root.theme.textPrimary
                            background: Rectangle {
                                color: root.theme.inputBg; radius: 3
                                border.color: root.theme.border
                            }
                        }
                    }

                    // Label
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: qsTr("Label *"); font.pixelSize: 10
                            color: root.theme.textMuted; Layout.preferredWidth: 72 }
                        TextField {
                            id: tfLabel
                            Layout.fillWidth: true; implicitHeight: 26
                            placeholderText: qsTr("Anzeigename")
                            font.pixelSize: 11; color: root.theme.textPrimary
                            background: Rectangle {
                                color: root.theme.inputBg; radius: 3
                                border.color: root.theme.border
                            }
                        }
                    }

                    // Typ
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: qsTr("Typ *"); font.pixelSize: 10
                            color: root.theme.textMuted; Layout.preferredWidth: 72 }
                        ComboBox {
                            id: cmbTyp
                            Layout.fillWidth: true; implicitHeight: 26
                            model: [qsTr("Text"), qsTr("Zahl"), qsTr("Ja/Nein"), qsTr("Auswahl")]
                            background: Rectangle {
                                color: root.theme.inputBg; radius: 3
                                border.color: root.theme.border
                            }
                            contentItem: Text {
                                leftPadding: 8; text: cmbTyp.displayText
                                font.pixelSize: 11; color: root.theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                            }
                            popup.background: Rectangle {
                                color: root.theme.surfaceDeep
                                border.color: root.theme.border; radius: 4
                            }
                            delegate: ItemDelegate {
                                width: cmbTyp.width; implicitHeight: 26
                                highlighted: cmbTyp.highlightedIndex === index
                                contentItem: Text {
                                    leftPadding: 8; text: modelData
                                    font.pixelSize: 11; color: root.theme.textPrimary
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: highlighted ? root.theme.hover : "transparent"
                                }
                            }
                        }
                    }

                    // Optionen (nur bei Auswahlfeld)
                    RowLayout {
                        visible: cmbTyp.currentIndex === 3
                        Layout.fillWidth: true; spacing: 8
                        Text { text: qsTr("Optionen *"); font.pixelSize: 10
                            color: root.theme.textMuted; Layout.preferredWidth: 72 }
                        TextField {
                            id: tfOptionen
                            Layout.fillWidth: true; implicitHeight: 26
                            placeholderText: qsTr("Gut,Maengel,Fehler")
                            font.pixelSize: 11; color: root.theme.textPrimary
                            background: Rectangle {
                                color: root.theme.inputBg; radius: 3
                                border.color: root.theme.border
                            }
                        }
                    }

                    // Einheit + Pflichtfeld
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: qsTr("Einheit"); font.pixelSize: 10
                            color: root.theme.textMuted; Layout.preferredWidth: 72 }
                        TextField {
                            id: tfEinheit
                            implicitWidth: 80; implicitHeight: 26
                            placeholderText: qsTr("A, V, Ohm ...")
                            font.pixelSize: 11; color: root.theme.textPrimary
                            background: Rectangle {
                                color: root.theme.inputBg; radius: 3
                                border.color: root.theme.border
                            }
                        }
                        CheckBox {
                            id: cbPflicht
                            indicator: Rectangle {
                                implicitWidth: 14; implicitHeight: 14; radius: 2
                                color: parent.checked ? root.theme.accent : root.theme.inputBg
                                border.color: root.theme.border
                                Text {
                                    anchors.centerIn: parent; text: "✓"; color: "white"
                                    font.pixelSize: 9; visible: parent.parent.checked
                                }
                            }
                            contentItem: Text {
                                leftPadding: parent.indicator.width + 4
                                text: qsTr("Pflichtfeld")
                                font.pixelSize: 10; color: root.theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // Fehlermeldung
                    Text {
                        visible: root._fehler !== ""
                        text: root._fehler
                        color: "#cc4444"; font.pixelSize: 10
                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }

                    // Aktions-Buttons
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 76; height: 24; radius: 3
                            color: abbHover.containsMouse ? root.theme.hover : root.theme.inputBg
                            border.color: root.theme.border
                            HoverHandler { id: abbHover }
                            Text {
                                anchors.centerIn: parent; text: qsTr("Abbrechen")
                                font.pixelSize: 10; color: root.theme.textPrimary
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { root._formReset(); root._formSichtbar = false }
                            }
                        }

                        Rectangle {
                            width: 88; height: 24; radius: 3
                            color: speichHover.containsMouse ? root.theme.accent : root.theme.inputBg
                            border.color: root.theme.accent
                            HoverHandler { id: speichHover }
                            Text {
                                anchors.centerIn: parent
                                text: root._editId >= 0 ? qsTr("Aktualisieren") : qsTr("Anlegen")
                                font.pixelSize: 10
                                color: speichHover.containsMouse ? "white" : root.theme.textPrimary
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root._speichern()
                            }
                        }
                    }

                    Item { height: 2 }
                }
            }

            // Footer: [+ Neues Feld]
            Rectangle {
                visible: root._selKat !== "" && !root._formSichtbar
                Layout.fillWidth: true; height: 36
                color: root.theme.surfaceDeep

                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 1; color: root.theme.border
                }

                Rectangle {
                    anchors {
                        left: parent.left; right: parent.right
                        top: parent.top
                        leftMargin: 12; rightMargin: 12; topMargin: 6
                    }
                    height: 24; radius: 4
                    color: addHover.containsMouse ? root.theme.hover : root.theme.inputBg
                    border.color: root.theme.border
                    HoverHandler { id: addHover }
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("+ Neues Feld hinzufuegen")
                        font.pixelSize: 11; color: root.theme.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { _formReset(); root._formSichtbar = true }
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("IBN-FeldPanel"); visible: root.debug }
}
