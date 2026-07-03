import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

ScrollView {
    id: root

    required property int    bauteilId
    required property string bauteilBezeichnung
    required property string bauteilHersteller
    required property string bauteilArtikelnummer
    required property var    theme
    property bool            debug: false

    signal bauteilGespeichert(int bauteilId, string bezeichnung)

    contentWidth:  availableWidth
    contentHeight: leftCol.implicitHeight
    clip:          true

    property int  _svTypId:          -1
    property var  _kableinfListe:    []
    property var  _kontaktListe:     []
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
            _kableinfListe = db.steckverbinderKableinfLaden(_svTypId)
            _kontaktListe  = db.steckverbinderKontaktLaden(_svTypId)
        } else {
            _kableinfListe = []
            _kontaktListe  = []
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

        // ── KONTAKTTYPEN ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; Layout.margins: 12
            Text { text: qsTr("KONTAKTTYPEN"); font.pixelSize: 9; font.weight: Font.Bold
                   font.letterSpacing: 1.5; color: root.theme.borderLight; Layout.fillWidth: true }
            Button {
                text: "+"; flat: true; implicitWidth: 26; implicitHeight: 22
                contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 14; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 3; border.color: root.theme.border }
                enabled: root._svTypId > 0
                onClicked: {
                    db.steckverbinderKontaktHinzufuegen(root._svTypId)
                    root._kontaktListe = db.steckverbinderKontaktLaden(root._svTypId)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 4

            RowLayout {
                Layout.fillWidth: true
                visible: root._kontaktListe.length > 0
                spacing: 6
                Text { text: qsTr("Größe");     color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 70 }
                Text { text: qsTr("QS min");    color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 50 }
                Text { text: qsTr("QS max");    color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 50 }
                Text { text: qsTr("I_N (A)");   color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 48 }
                Text { text: qsTr("U_N (V)");   color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 48 }
                Text { text: qsTr("Verbindung");color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 80 }
                Text { text: qsTr("Litze-Farbe"); color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 80 }
                Text { text: qsTr("L-QS");      color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 66 }
                Text { text: qsTr("L-Bez");     color: root.theme.textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                Text { text: qsTr("SH");        color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 28 }
                Item { width: 26 }
            }

            Repeater {
                model: root._kontaktListe
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    property var cd: modelData

                    function save() {
                        db.steckverbinderKontaktAktualisieren(
                            cd.id, shToggle._isk,
                            kontaktFields.itemAt(0).children[0].text.trim(),
                            parseFloat(kontaktFields.itemAt(1).children[0].text.replace(",",".")) || 0,
                            parseFloat(kontaktFields.itemAt(2).children[0].text.replace(",",".")) || 0,
                            parseFloat(kontaktFields.itemAt(3).children[0].text.replace(",",".")) || 0,
                            parseFloat(kontaktFields.itemAt(4).children[0].text.replace(",",".")) || 0,
                            kontaktFields.itemAt(5).children[0].text.trim(),
                            cbLitzeFarbe.currentText,
                            parseFloat(cbLitzeQs.currentText.replace(",",".")) || 0,
                            tfLitzeBez.text.trim()
                        )
                        root._kontaktListe = db.steckverbinderKontaktLaden(root._svTypId)
                    }

                    Repeater {
                        id: kontaktFields
                        property var fDef: [
                            { key: "kontaktgroesse",    width: 70 },
                            { key: "qsMin",             width: 50 },
                            { key: "qsMax",             width: 50 },
                            { key: "nennstrom",         width: 48 },
                            { key: "nennspannung",      width: 48 },
                            { key: "verbindungstechnik",width: 80 }
                        ]
                        model: fDef
                        delegate: Rectangle {
                            Layout.preferredWidth: modelData.width
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
                                onEditingFinished: parent.parent.save()
                                Keys.onEscapePressed: focus = false
                            }
                        }
                    }

                    // Litze Farbe
                    ComboBox {
                        id: cbLitzeFarbe
                        Layout.preferredWidth: 80
                        height: 26
                        model: ["","BK","BN","RD","OG","YE","GN","BU","VT","GY","WH","PK","GNYE","CL"]
                        currentIndex: { var i = model.indexOf(cd.litzeFarbe || ""); return i >= 0 ? i : 0 }
                        font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                        contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                            leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                        onActivated: parent.save()
                    }

                    // Litze Querschnitt - Fix L-QS-01: Breite von 48 auf 66 erhöht, sonst
                    // rendert das Fusion-Style-Popup die Einträge sichtbar leer (Auswahl
                    // funktionierte trotzdem, aber blind - siehe Bugreport)
                    ComboBox {
                        id: cbLitzeQs
                        Layout.preferredWidth: 66
                        height: 26
                        model: ["","0.14","0.25","0.34","0.5","0.75","1.0","1.5","2.5","4.0","6.0"]
                        currentIndex: {
                            var v = cd.litzeQuerschnitt > 0 ? cd.litzeQuerschnitt.toString() : ""
                            var i = model.indexOf(v)
                            return i >= 0 ? i : 0
                        }
                        font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                        contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                            leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                        delegate: ItemDelegate {
                            width: cbLitzeQs.width
                            contentItem: Text {
                                text: modelData; color: root.theme.textPrimary; font.pixelSize: 11
                                leftPadding: 6; verticalAlignment: Text.AlignVCenter
                            }
                            highlighted: cbLitzeQs.highlightedIndex === index
                        }
                        onActivated: parent.save()
                    }

                    // Litze Bezeichnung
                    Rectangle {
                        Layout.fillWidth: true; height: 26
                        color: root.theme.inputBg; border.color: tfLitzeBez.activeFocus ? root.theme.accent : root.theme.border; radius: 3
                        TextInput {
                            id: tfLitzeBez
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            color: root.theme.textPrimary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            text: cd.litzeBezeichnung || ""
                            onEditingFinished: parent.parent.save()
                            Keys.onEscapePressed: focus = false
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
                            onClicked: { shToggle._isk = !shToggle._isk; shToggle.parent.save() }
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
        }

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
                        root._kableinfListe = db.steckverbinderKableinfLaden(root._svTypId)
                        root._kontaktListe  = db.steckverbinderKontaktLaden(root._svTypId)
                    }
                    bauteilModel.aktualisieren()
                    root.bauteilGespeichert(root.bauteilId, tfStamBez.text.trim())
                }
            }
        }
    }
}
