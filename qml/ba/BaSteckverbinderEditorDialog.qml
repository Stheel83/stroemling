import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling

Dialog {
    id: root

    required property var theme

    property int    bauteilId:   -1
    property string bezeichnung: ""

    // Intern: geladene Daten
    property int  _svTypId:          -1
    property var  _kableinfListe:    []
    property var  _kontaktListe:     []
    property bool _geschirmt:        false
    property bool _hatSchirmkontakt: false

    title:   qsTr("Steckverbinder-Editor")
    modal:   true
    parent:  Overlay.overlay
    anchors.centerIn: parent
    width:   600
    padding: 0

    background: Rectangle {
        color:        root.theme.sidebar
        border.color: root.theme.border
        border.width: 1
        radius:       6
    }

    onOpened: _laden()

    function _laden() {
        if (root.bauteilId < 0) return
        var typ = db.steckverbinderTypLaden(root.bauteilId)
        _svTypId = typ.id !== undefined ? typ.id : -1
        _geschirmt        = typ.geschirmt        || false
        _hatSchirmkontakt = typ.hatSchirmkontakt || false
        tfPolzahl.text    = typ.polzahl > 0 ? typ.polzahl.toString() : ""
        tfIpGetrennt.text = typ.ipGetrennt      || ""
        tfIpGesteckt.text = typ.ipGesteckt      || ""
        tfKodierung.text  = typ.kodierung       || ""
        tfVerriegelung.text = typ.verriegelung  || ""
        if (_svTypId > 0) {
            _kableinfListe = db.steckverbinderKableinfLaden(_svTypId)
            _kontaktListe  = db.steckverbinderKontaktLaden(_svTypId)
        } else {
            _kableinfListe = []
            _kontaktListe  = []
        }
    }

    function _speichern() {
        var polzahl = parseInt(tfPolzahl.text) || 0
        var newId = db.steckverbinderTypSpeichern(
            root.bauteilId, polzahl,
            tfIpGetrennt.text.trim(), tfIpGesteckt.text.trim(),
            tfKodierung.text.trim(), tfVerriegelung.text.trim(),
            _hatSchirmkontakt, _geschirmt)
        if (newId > 0) {
            _svTypId = newId
            _kableinfListe = db.steckverbinderKableinfLaden(_svTypId)
            _kontaktListe  = db.steckverbinderKontaktLaden(_svTypId)
            bauteilModel.aktualisieren()
        }
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ── Header ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 48; color: root.theme.surface
            radius: 6
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.theme.border }
            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                spacing: 8
                Text { text: "🔌"; font.pixelSize: 16 }
                Column {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: qsTr("Steckverbinder"); font.pixelSize: 11; color: root.theme.textMuted }
                    Text { text: root.bezeichnung; font.pixelSize: 14; font.weight: Font.Medium; color: root.theme.textPrimary }
                }
                Button {
                    text: "×"; flat: true; implicitWidth: 32; implicitHeight: 32
                    contentItem: Text { text: parent.text; color: root.theme.textMuted; font.pixelSize: 18;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4 }
                    onClicked: root.close()
                }
            }
        }

        // ── Scrollbarer Inhalt ───────────────────────────────
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(svContent.implicitHeight + 24, 560)
            clip: true

            Column {
                id: svContent
                width: root.width - 2
                padding: 16
                spacing: 12

                // ── Stammdaten ────────────────────────────────
                Text {
                    text: qsTr("STAMMDATEN")
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                    color: root.theme.borderLight
                }

                GridLayout {
                    width: parent.width - 32
                    columns: 4; rowSpacing: 6; columnSpacing: 8

                    Text { text: qsTr("Polzahl"); font.pixelSize: 11; color: root.theme.textMuted }
                    Rectangle {
                        Layout.preferredWidth: 70; height: 28
                        color: root.theme.inputBg; border.color: tfPolzahl.activeFocus ? root.theme.accent : root.theme.border; radius: 4
                        TextInput {
                            id: tfPolzahl
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            color: root.theme.textPrimary; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            inputMethodHints: Qt.ImhDigitsOnly
                            onEditingFinished: root._speichern()
                            Keys.onEscapePressed: focus = false
                        }
                    }

                    Text { text: qsTr("Kodierung"); font.pixelSize: 11; color: root.theme.textMuted }
                    Rectangle {
                        Layout.fillWidth: true; height: 28
                        color: root.theme.inputBg; border.color: tfKodierung.activeFocus ? root.theme.accent : root.theme.border; radius: 4
                        TextInput {
                            id: tfKodierung
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            color: root.theme.textPrimary; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onEditingFinished: root._speichern()
                            Keys.onEscapePressed: focus = false
                        }
                    }

                    Text { text: qsTr("IP getrennt"); font.pixelSize: 11; color: root.theme.textMuted }
                    Rectangle {
                        Layout.preferredWidth: 70; height: 28
                        color: root.theme.inputBg; border.color: tfIpGetrennt.activeFocus ? root.theme.accent : root.theme.border; radius: 4
                        TextInput {
                            id: tfIpGetrennt
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            color: root.theme.textPrimary; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onEditingFinished: root._speichern()
                            Keys.onEscapePressed: focus = false
                        }
                    }

                    Text { text: qsTr("Verriegelung"); font.pixelSize: 11; color: root.theme.textMuted }
                    Rectangle {
                        Layout.fillWidth: true; height: 28
                        color: root.theme.inputBg; border.color: tfVerriegelung.activeFocus ? root.theme.accent : root.theme.border; radius: 4
                        TextInput {
                            id: tfVerriegelung
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            color: root.theme.textPrimary; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onEditingFinished: root._speichern()
                            Keys.onEscapePressed: focus = false
                        }
                    }

                    Text { text: qsTr("IP gesteckt"); font.pixelSize: 11; color: root.theme.textMuted }
                    Rectangle {
                        Layout.preferredWidth: 70; height: 28
                        color: root.theme.inputBg; border.color: tfIpGesteckt.activeFocus ? root.theme.accent : root.theme.border; radius: 4
                        TextInput {
                            id: tfIpGesteckt
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            color: root.theme.textPrimary; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onEditingFinished: root._speichern()
                            Keys.onEscapePressed: focus = false
                        }
                    }

                    // Geschirmt + Schirmkontakt Toggles
                    Text { text: qsTr("Geschirmt"); font.pixelSize: 11; color: root.theme.textMuted }
                    Row {
                        spacing: 4
                        Repeater {
                            model: [{ label: qsTr("Nein"), val: false }, { label: qsTr("Ja"), val: true }]
                            delegate: Rectangle {
                                width: 48; height: 24; radius: 3
                                property bool _aktiv: root._geschirmt === modelData.val
                                color: _aktiv ? root.theme.accent : root.theme.inputBg
                                border.color: _aktiv ? root.theme.accent : root.theme.border
                                Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11
                                       color: parent._aktiv ? "#ffffff" : root.theme.textSecondary }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root._geschirmt = modelData.val; root._speichern() }
                                }
                            }
                        }
                    }

                    Text { text: qsTr("Schirmkontakt"); font.pixelSize: 11; color: root.theme.textMuted }
                    Row {
                        spacing: 4
                        Repeater {
                            model: [{ label: qsTr("Nein"), val: false }, { label: qsTr("Ja"), val: true }]
                            delegate: Rectangle {
                                width: 48; height: 24; radius: 3
                                property bool _aktiv: root._hatSchirmkontakt === modelData.val
                                color: _aktiv ? root.theme.accent : root.theme.inputBg
                                border.color: _aktiv ? root.theme.accent : root.theme.border
                                Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11
                                       color: parent._aktiv ? "#ffffff" : root.theme.textSecondary }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root._hatSchirmkontakt = modelData.val; root._speichern() }
                                }
                            }
                        }
                    }
                }

                // ── Kabeleinführungen ─────────────────────────
                Rectangle { width: parent.width - 32; height: 1; color: root.theme.border }

                RowLayout {
                    width: parent.width - 32
                    Text { text: qsTr("KABELEINFÜHRUNGEN"); font.pixelSize: 9; font.weight: Font.Bold
                           font.letterSpacing: 1.5; color: root.theme.borderLight; Layout.fillWidth: true }
                    Button {
                        text: "+"; flat: true; implicitWidth: 26; implicitHeight: 22
                        contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 14; font.bold: true
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        enabled: root._svTypId > 0
                        onClicked: {
                            if (root._svTypId < 0) root._speichern()
                            db.steckverbinderKableinfHinzufuegen(root._svTypId)
                            root._kableinfListe = db.steckverbinderKableinfLaden(root._svTypId)
                        }
                    }
                }

                // Kabeleinf-Kopfzeile
                RowLayout {
                    width: parent.width - 32
                    visible: root._kableinfListe.length > 0
                    spacing: 6
                    Text { text: qsTr("Nr.");        color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 30 }
                    Text { text: qsTr("∅ min (mm)"); color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 75 }
                    Text { text: qsTr("∅ max (mm)"); color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 75 }
                    Text { text: qsTr("Typ");        color: root.theme.textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: qsTr("Zugentlastung"); color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 100 }
                    Item { width: 26 }
                }

                Repeater {
                    model: root._kableinfListe
                    delegate: RowLayout {
                        width: svContent.width - 32
                        spacing: 6
                        property var kd: modelData

                        Text { text: kd.einfNr; font.pixelSize: 11; color: root.theme.textMuted; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignHCenter }

                        Repeater {
                            id: kableinfFields
                            property var fDef: [
                                { key: "aussenMin", width: 75, hint: "0.00" },
                                { key: "aussenMax", width: 75, hint: "0.00" },
                                { key: "einfTyp",   width: -1, hint: "" },
                                { key: "zugentlastung", width: 100, hint: "" }
                            ]
                            model: fDef

                            delegate: Rectangle {
                                Layout.preferredWidth: modelData.width > 0 ? modelData.width : -1
                                Layout.fillWidth: modelData.width < 0
                                height: 26
                                color: root.theme.inputBg
                                border.color: kaTf.activeFocus ? root.theme.accent : root.theme.border
                                radius: 3

                                TextInput {
                                    id: kaTf
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    color: root.theme.textPrimary; font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                    text: {
                                        var v = kd[modelData.key]
                                        if (v === undefined || v === null) return ""
                                        if (typeof v === "number") return v > 0 ? v.toString() : ""
                                        return v.toString()
                                    }
                                    onEditingFinished: {
                                        db.steckverbinderKableinfAktualisieren(
                                            kd.id,
                                            parseFloat(kableinfFields.itemAt(0).children[0].text.replace(",",".")) || 0,
                                            parseFloat(kableinfFields.itemAt(1).children[0].text.replace(",",".")) || 0,
                                            kableinfFields.itemAt(2).children[0].text.trim(),
                                            kableinfFields.itemAt(3).children[0].text.trim()
                                        )
                                        root._kableinfListe = db.steckverbinderKableinfLaden(root._svTypId)
                                    }
                                    Keys.onEscapePressed: focus = false
                                }
                            }
                        }

                        Rectangle {
                            width: 26; height: 22; radius: 3
                            color: keiDelMa.containsMouse ? "#662222" : root.theme.inputBg
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 14
                                   color: keiDelMa.containsMouse ? "#ffffff" : root.theme.textMuted }
                            MouseArea {
                                id: keiDelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    db.steckverbinderKableinfLoeschen(kd.id)
                                    root._kableinfListe = db.steckverbinderKableinfLaden(root._svTypId)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root._kableinfListe.length === 0
                    text: qsTr("Noch keine Einträge. Mit \"+\" Einführung hinzufügen.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                    leftPadding: 0
                }

                // ── Kontakttypen ──────────────────────────────
                Rectangle { width: parent.width - 32; height: 1; color: root.theme.border }

                RowLayout {
                    width: parent.width - 32
                    Text { text: qsTr("KONTAKTTYPEN"); font.pixelSize: 9; font.weight: Font.Bold
                           font.letterSpacing: 1.5; color: root.theme.borderLight; Layout.fillWidth: true }
                    Button {
                        text: "+"; flat: true; implicitWidth: 26; implicitHeight: 22
                        contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 14; font.bold: true
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        enabled: root._svTypId > 0
                        onClicked: {
                            if (root._svTypId < 0) root._speichern()
                            db.steckverbinderKontaktHinzufuegen(root._svTypId)
                            root._kontaktListe = db.steckverbinderKontaktLaden(root._svTypId)
                        }
                    }
                }

                // Kontakt-Kopfzeile
                RowLayout {
                    width: parent.width - 32
                    visible: root._kontaktListe.length > 0
                    spacing: 6
                    Text { text: qsTr("Größe");     color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 70 }
                    Text { text: qsTr("QS min");    color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 60 }
                    Text { text: qsTr("QS max");    color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 60 }
                    Text { text: qsTr("I_N (A)");   color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 55 }
                    Text { text: qsTr("U_N (V)");   color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 55 }
                    Text { text: qsTr("Verbindung");color: root.theme.textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: qsTr("SH");        color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 28 }
                    Item { width: 26 }
                }

                Repeater {
                    model: root._kontaktListe
                    delegate: RowLayout {
                        width: svContent.width - 32
                        spacing: 6
                        property var cd: modelData

                        Repeater {
                            id: kontaktFields
                            property var fDef: [
                                { key: "kontaktgroesse", width: 70 },
                                { key: "qsMin",          width: 60 },
                                { key: "qsMax",          width: 60 },
                                { key: "nennstrom",      width: 55 },
                                { key: "nennspannung",   width: 55 },
                                { key: "verbindungstechnik", width: -1 }
                            ]
                            model: fDef
                            delegate: Rectangle {
                                Layout.preferredWidth: modelData.width > 0 ? modelData.width : -1
                                Layout.fillWidth: modelData.width < 0
                                height: 26
                                color: root.theme.inputBg
                                border.color: ktTf.activeFocus ? root.theme.accent : root.theme.border
                                radius: 3
                                TextInput {
                                    id: ktTf
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    color: root.theme.textPrimary; font.pixelSize: 11
                                    verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                    text: {
                                        var v = cd[modelData.key]
                                        if (v === undefined || v === null) return ""
                                        if (typeof v === "number") return v > 0 ? v.toString() : ""
                                        return v.toString()
                                    }
                                    onEditingFinished: {
                                        db.steckverbinderKontaktAktualisieren(
                                            cd.id, shToggle._isk,
                                            kontaktFields.itemAt(0).children[0].text.trim(),
                                            parseFloat(kontaktFields.itemAt(1).children[0].text.replace(",",".")) || 0,
                                            parseFloat(kontaktFields.itemAt(2).children[0].text.replace(",",".")) || 0,
                                            parseFloat(kontaktFields.itemAt(3).children[0].text.replace(",",".")) || 0,
                                            parseFloat(kontaktFields.itemAt(4).children[0].text.replace(",",".")) || 0,
                                            kontaktFields.itemAt(5).children[0].text.trim()
                                        )
                                        root._kontaktListe = db.steckverbinderKontaktLaden(root._svTypId)
                                    }
                                    Keys.onEscapePressed: focus = false
                                }
                            }
                        }

                        // Schirmkontakt-Toggle
                        Rectangle {
                            id: shToggle
                            property bool _isk: cd.istSchirmkontakt || false
                            width: 28; height: 24; radius: 3
                            color: _isk ? root.theme.accent : root.theme.inputBg
                            border.color: _isk ? root.theme.accent : root.theme.border
                            Text { anchors.centerIn: parent; text: _isk ? "✓" : "–"; font.pixelSize: 11
                                   color: parent._isk ? "#ffffff" : root.theme.textMuted }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    shToggle._isk = !shToggle._isk
                                    db.steckverbinderKontaktAktualisieren(
                                        cd.id, shToggle._isk,
                                        kontaktFields.itemAt(0).children[0].text.trim(),
                                        parseFloat(kontaktFields.itemAt(1).children[0].text.replace(",",".")) || 0,
                                        parseFloat(kontaktFields.itemAt(2).children[0].text.replace(",",".")) || 0,
                                        parseFloat(kontaktFields.itemAt(3).children[0].text.replace(",",".")) || 0,
                                        parseFloat(kontaktFields.itemAt(4).children[0].text.replace(",",".")) || 0,
                                        kontaktFields.itemAt(5).children[0].text.trim()
                                    )
                                    root._kontaktListe = db.steckverbinderKontaktLaden(root._svTypId)
                                }
                            }
                        }

                        Rectangle {
                            width: 26; height: 22; radius: 3
                            color: ktDelMa.containsMouse ? "#662222" : root.theme.inputBg
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 14
                                   color: ktDelMa.containsMouse ? "#ffffff" : root.theme.textMuted }
                            MouseArea {
                                id: ktDelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    db.steckverbinderKontaktLoeschen(cd.id)
                                    root._kontaktListe = db.steckverbinderKontaktLaden(root._svTypId)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root._kontaktListe.length === 0
                    text: qsTr("Noch keine Einträge. Mit \"+\" Kontakttyp hinzufügen.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                }

                Item { height: 4 }
            }
        }

        // ── Footer ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 1; color: root.theme.border
        }
        Rectangle {
            Layout.fillWidth: true; height: 52; color: root.theme.surface
            radius: 6
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: root.theme.border }

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                spacing: 8
                Text {
                    text: root._svTypId > 0
                          ? qsTr("Änderungen werden sofort gespeichert.")
                          : qsTr("Stammdaten ausfüllen und Tab drücken um Datensatz anzulegen.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                    Layout.fillWidth: true
                }
                Button {
                    text: qsTr("Schließen"); implicitWidth: 90; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius: 4; border.color: root.theme.accent
                    }
                    onClicked: root.close()
                }
            }
        }
    }
}
