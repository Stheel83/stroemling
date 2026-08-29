import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

// SPEICHERN-FUSSBEREICH-01 (Aug 2026): root ist keine ScrollView mehr, sondern
// ein ColumnLayout aus [scrollender Formularbereich, fester Speichern-Fuß] -
// vorher scrollte der Speichern-Button mit den Feldern mit und war bei langen
// Formularen erst nach Hochscrollen sichtbar. Gleiches Muster in
// KabelEditorLinksBlock.qml, KlemmenEditorLinksBlock.qml, KontaktEditor.qml,
// KonfkabelEditor.qml.
ColumnLayout {
    id: root
    spacing: 0

    required property int    bauteilId
    required property string bauteilBezeichnung
    required property string bauteilHersteller
    required property string bauteilArtikelnummer
    required property var    theme
    property bool            debug: false

    signal bauteilGespeichert(int bauteilId, string bezeichnung)

    property int  _svTypId:          -1
    property var  _kableinfListe:    []
    property var  _positionenListe:  []
    property bool _geschirmt:        false
    property bool _hatSchirmkontakt: false
    property string _geschlecht:     "stecker"   // "stecker" | "buchse"
    property string _montage:        "frei"      // "frei" | "einbau"

    function _bauteilLaden() {
        var d = bauteilModel.bauteilNachId(bauteilId)
        tfStamBez.text    = d.bezeichnung   || bauteilBezeichnung
        tfStamHer.text    = d.hersteller    || bauteilHersteller
        tfStamArt.text    = d.artikelnummer || bauteilArtikelnummer
        tfStamLief.text   = d.lieferant     || ""
        tfStamPreis.text  = (d.preisEur  > 0) ? d.preisEur.toFixed(2)    : ""
        tfStamU.text      = (d.spannungV > 0) ? d.spannungV.toString()   : ""
        tfStamI.text      = (d.stromA    > 0) ? d.stromA.toString()      : ""
        tfStamP.text      = (d.leistungW > 0) ? d.leistungW.toString()   : ""
        tfStamBem.text    = d.bemerkung     || ""
        tfStamUrlHer.text = d.urlHersteller || ""
        tfStamUrlDat.text = d.urlDatenblatt || ""
    }

    function _svLaden() {
        if (bauteilId < 0) return
        var typ = db.steckverbinderTypLaden(bauteilId)
        _svTypId = typ.id !== undefined ? typ.id : -1
        _geschirmt        = typ.geschirmt        || false
        _hatSchirmkontakt = typ.hatSchirmkontakt || false
        tfPolzahl.text      = typ.polzahl > 0 ? typ.polzahl.toString() : ""
        tfIpGetrennt.text   = typ.ipGetrennt    || ""
        tfIpGesteckt.text   = typ.ipGesteckt    || ""
        tfKodierung.text    = typ.kodierung     || ""
        tfVerriegelung.text = typ.verriegelung  || ""

        var mf = typ.montageform || "frei_stecker"
        var teile = mf.split("_")
        _montage    = teile[0] || "frei"
        _geschlecht = teile[1] || "stecker"

        if (_svTypId > 0) {
            _kableinfListe   = db.steckverbinderKableinfLaden(_svTypId)
            _positionenListe = db.steckverbinderPositionenLaden(_svTypId)
        } else {
            _kableinfListe   = []
            _positionenListe = []
        }
    }

    onBauteilIdChanged: {
        if (bauteilId >= 0) {
            root._bauteilLaden()
            root._svLaden()
        }
    }
    onBauteilBezeichnungChanged:   if (bauteilId >= 0) tfStamBez.text = bauteilBezeichnung
    onBauteilHerstellerChanged:    if (bauteilId >= 0) tfStamHer.text = bauteilHersteller
    onBauteilArtikelnummerChanged: if (bauteilId >= 0) tfStamArt.text = bauteilArtikelnummer

    ScrollView {
        id: scrollArea
        Layout.fillWidth:  true
        Layout.fillHeight: true
        contentWidth:  availableWidth
        contentHeight: leftCol.implicitHeight
        clip:          true

        ColumnLayout {
            id:      leftCol
            width:   parent.width
            spacing: 0

            // ── STAMMDATEN (Bauteil, allgemein) ────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 32; color: root.theme.surfaceDeep
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("STAMMDATEN"); font.pixelSize: 9; font.weight: Font.Medium; color: root.theme.textMuted
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                Text { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 11 }
                NavTextField {
                    id: tfStamBez; Layout.fillWidth: true
                    tabTarget:     tfStamHer
                    backtabTarget: tfIpGesteckt
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    color: root.theme.textPrimary; font.pixelSize: 12
                }

                GridLayout {
                    columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 6
                    Text { text: qsTr("Hersteller");  color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Artikel-Nr."); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfStamHer; Layout.fillWidth: true
                        tabTarget: tfStamArt; backtabTarget: tfStamBez
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfStamArt; Layout.fillWidth: true
                        tabTarget: tfStamLief; backtabTarget: tfStamHer
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Lieferant");  color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Preis (EUR)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfStamLief; Layout.fillWidth: true
                        tabTarget: tfStamPreis; backtabTarget: tfStamArt
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfStamPreis; Layout.fillWidth: true
                        tabTarget: tfStamU; backtabTarget: tfStamLief
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0.00"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Spannung (V)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Strom (A)");    color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfStamU; Layout.fillWidth: true
                        tabTarget: tfStamI; backtabTarget: tfStamPreis
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfStamI; Layout.fillWidth: true
                        tabTarget: tfStamP; backtabTarget: tfStamU
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Leistung (W)"); color: root.theme.textMuted; font.pixelSize: 11; Layout.columnSpan: 2 }
                    NavTextField {
                        id: tfStamP; Layout.fillWidth: true; Layout.columnSpan: 2
                        tabTarget: tfStamBem; backtabTarget: tfStamI
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                }

                Text { text: qsTr("Bemerkung Bauteil"); color: root.theme.textMuted; font.pixelSize: 11 }
                TextArea {
                    id: tfStamBem
                    Layout.fillWidth: true
                    wrapMode:        Text.Wrap
                    implicitHeight:  Math.max(36, contentHeight + topPadding + bottomPadding)
                    color:           root.theme.textPrimary
                    font.pixelSize:  12
                    topPadding: 6; bottomPadding: 6; leftPadding: 8; rightPadding: 8
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    Keys.onTabPressed:     { event.accepted = true; tfStamUrlHer.forceActiveFocus() }
                    Keys.onBacktabPressed: { event.accepted = true; tfStamP.forceActiveFocus() }
                }

                Text { text: qsTr("Links"); color: root.theme.accent; font.pixelSize: 11; font.bold: true }
                Text { text: qsTr("Hersteller-Website"); color: root.theme.textMuted; font.pixelSize: 11 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    NavTextField {
                        id: tfStamUrlHer; Layout.fillWidth: true
                        tabTarget: tfStamUrlDat; backtabTarget: tfStamBem
                        placeholderText: "https://..."
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    Button {
                        implicitWidth: 60; implicitHeight: 28; enabled: tfStamUrlHer.text.trim().length > 0
                        text: qsTr("Oeffnen")
                        contentItem: Text { text: parent.text; color: parent.enabled ? root.theme.accent : root.theme.textMuted;
                                            font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered && parent.enabled ? root.theme.hover : root.theme.inputBg;
                                                radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                        onClicked: Qt.openUrlExternally(tfStamUrlHer.text.trim())
                    }
                }
                Text { text: qsTr("Datenblatt"); color: root.theme.textMuted; font.pixelSize: 11 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    NavTextField {
                        id: tfStamUrlDat; Layout.fillWidth: true
                        tabTarget: tfPolzahl; backtabTarget: tfStamUrlHer
                        placeholderText: "https://..."
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    Button {
                        implicitWidth: 60; implicitHeight: 28; enabled: tfStamUrlDat.text.trim().length > 0
                        text: qsTr("Oeffnen")
                        contentItem: Text { text: parent.text; color: parent.enabled ? root.theme.accent : root.theme.textMuted;
                                            font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered && parent.enabled ? root.theme.hover : root.theme.inputBg;
                                                radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                        onClicked: Qt.openUrlExternally(tfStamUrlDat.text.trim())
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // ── STECKVERBINDER-EIGENSCHAFTEN ───────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 32; color: root.theme.surfaceDeep
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("STECKVERBINDER"); font.pixelSize: 9; font.weight: Font.Medium; color: root.theme.textMuted
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                Text { text: qsTr("Ausführung"); color: root.theme.textMuted; font.pixelSize: 11 }
                RowLayout {
                    spacing: 12
                    Row {
                        spacing: 4
                        Repeater {
                            model: [{ label: qsTr("Stecker"), val: "stecker" }, { label: qsTr("Buchse"), val: "buchse" }]
                            delegate: Rectangle {
                                width: 68; height: 26; radius: 3
                                property bool _aktiv: root._geschlecht === modelData.val
                                color: _aktiv ? root.theme.accent : root.theme.inputBg
                                border.color: _aktiv ? root.theme.accent : root.theme.border
                                Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11
                                       color: parent._aktiv ? "#ffffff" : root.theme.textSecondary }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root._geschlecht = modelData.val
                                }
                            }
                        }
                    }
                    Row {
                        spacing: 4
                        Repeater {
                            model: [{ label: qsTr("Frei"), val: "frei" }, { label: qsTr("Einbau"), val: "einbau" }]
                            delegate: Rectangle {
                                width: 68; height: 26; radius: 3
                                property bool _aktiv: root._montage === modelData.val
                                color: _aktiv ? root.theme.accent : root.theme.inputBg
                                border.color: _aktiv ? root.theme.accent : root.theme.border
                                Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11
                                       color: parent._aktiv ? "#ffffff" : root.theme.textSecondary }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root._montage = modelData.val
                                }
                            }
                        }
                    }
                }

                GridLayout {
                    columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 6

                    Text { text: qsTr("Polzahl"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Kodierung"); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfPolzahl; Layout.fillWidth: true
                        tabTarget: tfKodierung; backtabTarget: tfStamUrlDat
                        inputMethodHints: Qt.ImhDigitsOnly
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfKodierung; Layout.fillWidth: true
                        tabTarget: tfIpGetrennt; backtabTarget: tfPolzahl
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("IP getrennt"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Verriegelung"); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfIpGetrennt; Layout.fillWidth: true
                        tabTarget: tfVerriegelung; backtabTarget: tfKodierung
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfVerriegelung; Layout.fillWidth: true
                        tabTarget: tfIpGesteckt; backtabTarget: tfIpGetrennt
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("IP gesteckt"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Item {}
                    NavTextField {
                        id: tfIpGesteckt; Layout.fillWidth: true
                        tabTarget: tfStamBez; backtabTarget: tfVerriegelung
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    Item {}
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 24
                    RowLayout {
                        spacing: 6
                        Text { text: qsTr("Geschirmt"); color: root.theme.textMuted; font.pixelSize: 11 }
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
                                        onClicked: root._geschirmt = modelData.val
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        spacing: 6
                        Text { text: qsTr("Schirmkontakt"); color: root.theme.textMuted; font.pixelSize: 11 }
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
                                        onClicked: root._hatSchirmkontakt = modelData.val
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // ── KABELEINFÜHRUNGEN ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 12
                Text { text: qsTr("KABELEINFÜHRUNGEN"); font.pixelSize: 9; font.weight: Font.Bold
                       font.letterSpacing: 1.5; color: root.theme.borderLight; Layout.fillWidth: true }
                Button {
                    text: "+"; flat: true; implicitWidth: 26; implicitHeight: 22
                    contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 14; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 3; border.color: root.theme.border }
                    enabled: root._svTypId > 0
                    onClicked: {
                        db.steckverbinderKableinfHinzufuegen(root._svTypId)
                        root._kableinfListe = db.steckverbinderKableinfLaden(root._svTypId)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 4

                RowLayout {
                    Layout.fillWidth: true
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
                        Layout.fillWidth: true
                        spacing: 6
                        property var kd: modelData

                        Text { text: kd.einfNr; font.pixelSize: 11; color: root.theme.textMuted; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignHCenter }

                        Repeater {
                            id: kableinfFields
                            property var fDef: [
                                { key: "aussenMin", width: 75, fill: false },
                                { key: "aussenMax", width: 75, fill: false },
                                { key: "einfTyp",   width: -1, fill: true  },
                                { key: "zugentlastung", width: 100, fill: false }
                            ]
                            model: fDef

                            delegate: Rectangle {
                                Layout.preferredWidth: modelData.width > 0 ? modelData.width : -1
                                Layout.fillWidth: modelData.fill
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
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 8 }

            // ── POSITIONEN (Kontakt-Typ-Verknüpfung je Pin) ─────────────────────
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 12
                Text { text: qsTr("POSITIONEN"); font.pixelSize: 9; font.weight: Font.Bold
                       font.letterSpacing: 1.5; color: root.theme.borderLight; Layout.fillWidth: true }
                Button {
                    text: "+"; flat: true; implicitWidth: 26; implicitHeight: 22
                    contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 14; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 3; border.color: root.theme.border }
                    enabled: root._svTypId > 0
                    onClicked: ktPicker.oeffnenNeu()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    visible: root._positionenListe.length > 0
                    spacing: 6
                    Text { text: qsTr("Pos.");       color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 32 }
                    Text { text: qsTr("Kontakt");    color: root.theme.textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: qsTr("Größe");      color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 55 }
                    Text { text: qsTr("Verbindung"); color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 80 }
                    Text { text: qsTr("SH");         color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 28 }
                    Item { width: 56 }
                }

                Repeater {
                    model: root._positionenListe
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        property var pd: modelData

                        Text {
                            text: pd.positionNr; font.pixelSize: 11; color: root.theme.textMuted
                            Layout.preferredWidth: 32; horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: pd.bezeichnung + " (" + (pd.geschlecht === "stift" ? qsTr("Stift") : qsTr("Buchse")) + ")"
                            font.pixelSize: 11; color: root.theme.textPrimary
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Text {
                            text: pd.kontaktgroesse > 0 ? pd.kontaktgroesse + "" : "–"
                            font.pixelSize: 11; color: root.theme.textMuted; Layout.preferredWidth: 55
                        }
                        Text {
                            text: pd.verbindungstechnik || "–"
                            font.pixelSize: 11; color: root.theme.textMuted
                            Layout.preferredWidth: 80; elide: Text.ElideRight
                        }

                        // Schirmkontakt-Toggle
                        Rectangle {
                            id: shToggle
                            property bool _isk: pd.istSchirmkontakt || false
                            width: 28; height: 24; radius: 3
                            color: _isk ? root.theme.accent : root.theme.inputBg
                            border.color: _isk ? root.theme.accent : root.theme.border
                            Text { anchors.centerIn: parent; text: _isk ? "✓" : "–"; font.pixelSize: 11
                                   color: parent._isk ? "#ffffff" : root.theme.textMuted }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    shToggle._isk = !shToggle._isk
                                    db.steckverbinderPositionSchirmkontaktSetzen(pd.id, shToggle._isk)
                                    root._positionenListe = db.steckverbinderPositionenLaden(root._svTypId)
                                }
                            }
                        }

                        // Kontakt-Typ tauschen
                        Rectangle {
                            width: 24; height: 22; radius: 3
                            color: swapMa.containsMouse ? root.theme.hover : root.theme.inputBg
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "⇄"; font.pixelSize: 12; color: root.theme.accent }
                            MouseArea {
                                id: swapMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: ktPicker.oeffnenTausch(pd.id)
                            }
                        }

                        // Position entfernen (nicht den Kontakt-Typ-Bauteil)
                        Rectangle {
                            width: 26; height: 22; radius: 3
                            color: posDelMa.containsMouse ? "#662222" : root.theme.inputBg
                            border.color: root.theme.border
                            Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 14
                                   color: posDelMa.containsMouse ? "#ffffff" : root.theme.textMuted }
                            MouseArea {
                                id: posDelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    db.steckverbinderPositionLoeschen(pd.id)
                                    root._positionenListe = db.steckverbinderPositionenLaden(root._svTypId)
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root._positionenListe.length === 0
                    text: qsTr("Noch keine Positionen. Mit \"+\" einen Kontakt-Typ auswählen.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                }
            }

            // ── Kontakt-Typ-Picker (Positions-Picker) ───────────────────────────
            Popup {
                id: ktPicker
                parent: Overlay.overlay
                anchors.centerIn: parent
                width: 420; height: 400
                modal: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                property var _liste:         []
                property int _swapPositionId: -1   // >=0: Kontakt-Typ dieser Position tauschen statt neue Position anlegen

                function _geschlechtFilter() {
                    return root._geschlecht === "stecker" ? "stift" : "buchse"
                }
                function oeffnenNeu() {
                    ktPicker._swapPositionId = -1
                    ktPicker._liste = db.kontaktTypListe(ktPicker._geschlechtFilter())
                    tfAnzahl.text = "1"
                    ktPicker.open()
                }
                function oeffnenTausch(positionId) {
                    ktPicker._swapPositionId = positionId
                    ktPicker._liste = db.kontaktTypListe(ktPicker._geschlechtFilter())
                    ktPicker.open()
                }

                background: Rectangle {
                    color: root.theme.surface
                    border.color: root.theme.border; border.width: 1; radius: 6
                }

                Column {
                    anchors.fill: parent; anchors.margins: 8; spacing: 0

                    Text {
                        width: parent.width
                        text: ktPicker._swapPositionId >= 0 ? qsTr("Kontakt-Typ tauschen") : qsTr("Kontakt-Typ wählen")
                        font.pixelSize: 13; font.weight: Font.Medium
                        color: root.theme.textPrimary; padding: 6
                    }
                    Rectangle { width: parent.width; height: 1; color: root.theme.border }

                    RowLayout {
                        width: parent.width; height: 32; visible: ktPicker._swapPositionId < 0
                        Text { text: qsTr("Anzahl:"); color: root.theme.textMuted; font.pixelSize: 11; Layout.leftMargin: 8 }
                        NavTextField {
                            id: tfAnzahl; Layout.preferredWidth: 50
                            text: "1"; inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                            color: root.theme.textPrimary; font.pixelSize: 12
                        }
                        Item { Layout.fillWidth: true }
                    }

                    ListView {
                        id: ktPickerList
                        width: parent.width
                        height: parent.height - (ktPicker._swapPositionId >= 0 ? 82 : 114)
                        clip: true
                        model: ktPicker._liste

                        Text {
                            visible: ktPicker._liste.length === 0
                            anchors.centerIn: parent
                            text: qsTr("Keine passenden Kontakt-Typen vorhanden.\nErstelle zuerst einen Eintrag unter Bibliothek → Kontakte.")
                            font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        delegate: Rectangle {
                            width: ktPickerList.width; height: 42
                            color: ktItemHover.hovered ? root.theme.hover : "transparent"
                            HoverHandler { id: ktItemHover }

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
                                    text: (modelData.hersteller || "") +
                                          (modelData.kontaktgroesse > 0 ? "  ·  " + modelData.kontaktgroesse + " mm²" : "") +
                                          (modelData.verbindungstechnik ? "  ·  " + modelData.verbindungstechnik : "")
                                    font.pixelSize: 10; color: root.theme.textMuted
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (ktPicker._swapPositionId >= 0) {
                                        db.steckverbinderPositionKontaktTypAendern(ktPicker._swapPositionId, modelData.id)
                                    } else {
                                        var anzahl = Math.max(1, parseInt(tfAnzahl.text) || 1)
                                        for (var i = 0; i < anzahl; i++)
                                            db.steckverbinderPositionHinzufuegen(root._svTypId, modelData.id)
                                    }
                                    root._positionenListe = db.steckverbinderPositionenLaden(root._svTypId)
                                    ktPicker.close()
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: root.theme.border }

                    Item {
                        width: parent.width; height: 36
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Abbrechen")
                            font.pixelSize: 12; color: root.theme.textMuted
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: ktPicker.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Fester Speichern-Fuß (SPEICHERN-FUSSBEREICH-01) ─────────────────
    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }
    RowLayout {
        Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
        Layout.topMargin: 8; Layout.bottomMargin: 12; spacing: 6
        Button {
            Layout.fillWidth: true; text: qsTr("Speichern")
            contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg;
                                    radius: 4; border.color: root.theme.accent }
            onClicked: {
                bauteilModel.bearbeiten(root.bauteilId,
                    tfStamBez.text.trim(), tfStamHer.text.trim(), tfStamArt.text.trim(),
                    tfStamLief.text.trim(),
                    parseFloat(tfStamPreis.text.replace(",",".")) || 0,
                    parseFloat(tfStamU.text.replace(",","."))     || 0,
                    parseFloat(tfStamI.text.replace(",","."))     || 0,
                    parseFloat(tfStamP.text.replace(",","."))     || 0,
                    tfStamBem.text.trim(),
                    tfStamUrlHer.text.trim(), tfStamUrlDat.text.trim())

                var newSvId = db.steckverbinderTypSpeichern(
                    root.bauteilId,
                    parseInt(tfPolzahl.text) || 0,
                    tfIpGetrennt.text.trim(), tfIpGesteckt.text.trim(),
                    tfKodierung.text.trim(), tfVerriegelung.text.trim(),
                    root._hatSchirmkontakt, root._geschirmt,
                    root._montage + "_" + root._geschlecht)
                if (newSvId > 0) {
                    root._svTypId = newSvId
                    root._kableinfListe   = db.steckverbinderKableinfLaden(root._svTypId)
                    root._positionenListe = db.steckverbinderPositionenLaden(root._svTypId)
                }
                bauteilModel.aktualisieren()
                root.bauteilGespeichert(root.bauteilId, tfStamBez.text.trim())
            }
        }
    }
}
