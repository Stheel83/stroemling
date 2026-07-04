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

    property int  _konfkabelId:         -1
    property var  _kabelListe:          []
    property var  _steckverbinderListe: []
    property var  _aderListeKabel:      []
    property var  _positionenA:         []
    property var  _positionenB:         []
    property var  _pinZuordnungA:       []
    property var  _pinZuordnungB:       []

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

    function _kkLaden() {
        if (bauteilId < 0) return
        _kabelListe          = db.bauteilKabelListe()
        _steckverbinderListe = db.steckverbinderBausteineListe()

        var kk = db.konfkabelLaden(bauteilId)
        _konfkabelId = kk.id !== undefined ? kk.id : -1
        var bauteilKabelId    = kk.bauteilKabelId    !== undefined ? kk.bauteilKabelId    : -1
        var steckerABauteilId = kk.steckerABauteilId !== undefined ? kk.steckerABauteilId : 0
        var steckerBBauteilId = kk.steckerBBauteilId !== undefined ? kk.steckerBBauteilId : 0
        var laengeM           = kk.laengeM           !== undefined ? kk.laengeM           : 0

        cbKabeltyp.currentIndex = _kabelIndexFuer(bauteilKabelId)
        cbSteckerA.currentIndex = _steckerIndexFuer(steckerABauteilId)
        cbSteckerB.currentIndex = _steckerIndexFuer(steckerBBauteilId)
        tfLaenge.text = laengeM > 0 ? laengeM.toString() : ""

        root._ladeAdern()
        root._ladePositionenA()
        root._ladePositionenB()
        root._ladePinZuordnungen()
    }

    // Pin-Zuordnung (§9.3): Adern des gewählten Kabeltyps + Positionen der
    // gewählten Steckverbinder je Seite, für die Auswahl-ComboBoxen.
    function _ladeAdern() {
        var kabelId = cbKabeltyp.currentIndex > 0 ? root._kabelListe[cbKabeltyp.currentIndex - 1].id : -1
        root._aderListeKabel = kabelId > 0 ? db.bauteilKabelAdernLaden(kabelId) : []
    }
    function _ladePositionenA() {
        var steckerId = cbSteckerA.currentIndex > 0 ? root._steckverbinderListe[cbSteckerA.currentIndex - 1].id : 0
        var svTyp = steckerId > 0 ? db.steckverbinderTypLaden(steckerId) : {}
        root._positionenA = (svTyp.id !== undefined && svTyp.id > 0) ? db.steckverbinderPositionenLaden(svTyp.id) : []
    }
    function _ladePositionenB() {
        var steckerId = cbSteckerB.currentIndex > 0 ? root._steckverbinderListe[cbSteckerB.currentIndex - 1].id : 0
        var svTyp = steckerId > 0 ? db.steckverbinderTypLaden(steckerId) : {}
        root._positionenB = (svTyp.id !== undefined && svTyp.id > 0) ? db.steckverbinderPositionenLaden(svTyp.id) : []
    }
    function _ladePinZuordnungen() {
        root._pinZuordnungA = root._konfkabelId > 0 ? db.konfkabelPinZuordnungLaden(root._konfkabelId, "A") : []
        root._pinZuordnungB = root._konfkabelId > 0 ? db.konfkabelPinZuordnungLaden(root._konfkabelId, "B") : []
    }

    function _kabelIndexFuer(id) {
        for (var i = 0; i < _kabelListe.length; i++)
            if (_kabelListe[i].id === id) return i + 1
        return 0
    }

    function _steckerIndexFuer(id) {
        if (id <= 0) return 0
        for (var i = 0; i < _steckverbinderListe.length; i++)
            if (_steckverbinderListe[i].id === id) return i + 1
        return 0
    }

    function _steckerLabel(sv) {
        var geschlecht = ""
        if (sv.montageform) {
            var teile = sv.montageform.split("_")
            if (teile[1] === "stecker") geschlecht = qsTr(" – Stecker")
            else if (teile[1] === "buchse") geschlecht = qsTr(" – Buchse")
        }
        return sv.bezeichnung + (sv.polzahl > 0 ? " (" + sv.polzahl + "p)" : "") + geschlecht
    }

    onBauteilIdChanged: {
        if (bauteilId >= 0) {
            root._bauteilLaden()
            root._kkLaden()
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
                backtabTarget: tfStamUrlDat
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
                    tabTarget: tfStamBez; backtabTarget: tfStamUrlHer
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

        // ── KONFEKTIONIERTES KABEL ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 32; color: root.theme.surfaceDeep
            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("KONFEKTIONIERTES KABEL"); font.pixelSize: 9; font.weight: Font.Medium; color: root.theme.textMuted
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: 12; spacing: 8

            Text { text: qsTr("Kabeltyp (aus Bibliothek)"); color: root.theme.textMuted; font.pixelSize: 11 }
            ComboBox {
                id: cbKabeltyp
                Layout.fillWidth: true; height: 28
                model: {
                    var m = [qsTr("— kein Kabeltyp —")]
                    for (var i = 0; i < root._kabelListe.length; i++)
                        m.push(root._kabelListe[i].bezeichnung || root._kabelListe[i].kabeltyp || ("ID " + root._kabelListe[i].bauteilId))
                    return m
                }
                font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                    leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                onActivated: root._ladeAdern()
            }

            Text { text: qsTr("Länge (m)"); color: root.theme.textMuted; font.pixelSize: 11 }
            NavTextField {
                id: tfLaenge; Layout.fillWidth: true
                tabTarget: tfStamBez; backtabTarget: tfStamBez
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                color: root.theme.textPrimary; font.pixelSize: 12
            }

            Text { text: qsTr("Stecker / Buchse – Ende A"); color: root.theme.accent; font.pixelSize: 11; font.bold: true }
            ComboBox {
                id: cbSteckerA
                Layout.fillWidth: true; height: 28
                model: {
                    var m = [qsTr("— freies Ende —")]
                    for (var i = 0; i < root._steckverbinderListe.length; i++)
                        m.push(root._steckerLabel(root._steckverbinderListe[i]))
                    return m
                }
                font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                    leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                onActivated: root._ladePositionenA()
            }

            Text { text: qsTr("Stecker / Buchse – Ende B"); color: root.theme.accent; font.pixelSize: 11; font.bold: true }
            ComboBox {
                id: cbSteckerB
                Layout.fillWidth: true; height: 28
                model: {
                    var m = [qsTr("— freies Ende —")]
                    for (var i = 0; i < root._steckverbinderListe.length; i++)
                        m.push(root._steckerLabel(root._steckverbinderListe[i]))
                    return m
                }
                font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                    leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                onActivated: root._ladePositionenB()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // ── PIN-ZUORDNUNG (§9.3: welche Ader liegt auf welchem Pin) ─────────
        Rectangle {
            Layout.fillWidth: true; height: 32; color: root.theme.surfaceDeep
            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("PIN-ZUORDNUNG"); font.pixelSize: 9; font.weight: Font.Medium; color: root.theme.textMuted
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        Text {
            visible: root._konfkabelId <= 0
            Layout.fillWidth: true; Layout.margins: 12
            text: qsTr("Erst speichern, um Adern den Pins zuzuordnen.")
            font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
        }

        // Seite A
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: 12; spacing: 6
            visible: root._konfkabelId > 0 && cbSteckerA.currentIndex > 0

            Text { text: qsTr("Seite A"); color: root.theme.accent; font.pixelSize: 11; font.bold: true }

            Repeater {
                model: root._pinZuordnungA
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    property var zd: modelData
                    Text {
                        text: qsTr("Ader %1").arg(zd.aderNr)
                        font.pixelSize: 11; color: root.theme.textPrimary; Layout.preferredWidth: 60
                    }
                    Text {
                        text: (zd.aderFarbe || "–") + (zd.aderBezeichnung ? " · " + zd.aderBezeichnung : "")
                              + (zd.aderQuerschnitt > 0 ? " · " + zd.aderQuerschnitt + " mm²" : "")
                        font.pixelSize: 11; color: root.theme.textMuted; Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: qsTr("→ Pos %1").arg(zd.pinNr)
                        font.pixelSize: 11; color: root.theme.accent; Layout.preferredWidth: 70
                    }
                    Rectangle {
                        width: 26; height: 22; radius: 3
                        color: delMaA.containsMouse ? "#662222" : root.theme.inputBg
                        border.color: root.theme.border
                        Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 14
                               color: delMaA.containsMouse ? "#ffffff" : root.theme.textMuted }
                        MouseArea {
                            id: delMaA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                db.konfkabelPinZuordnungLoeschen(zd.id)
                                root._pinZuordnungA = db.konfkabelPinZuordnungLaden(root._konfkabelId, "A")
                            }
                        }
                    }
                }
            }

            Text {
                visible: root._pinZuordnungA.length === 0
                text: qsTr("Noch keine Zuordnung.")
                font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                ComboBox {
                    id: cbAderA; Layout.preferredWidth: 150; height: 26
                    model: {
                        var m = []
                        for (var i = 0; i < root._aderListeKabel.length; i++) {
                            var a = root._aderListeKabel[i]
                            m.push(qsTr("Ader %1 (%2)").arg(a.aderNr).arg(a.farbe || "–"))
                        }
                        return m
                    }
                    font.pixelSize: 11
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                        leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                }
                ComboBox {
                    id: cbPinA; Layout.preferredWidth: 150; height: 26
                    model: {
                        var m = []
                        for (var i = 0; i < root._positionenA.length; i++) {
                            var p = root._positionenA[i]
                            m.push(qsTr("Pos %1 – %2").arg(p.positionNr).arg(p.bezeichnung))
                        }
                        return m
                    }
                    font.pixelSize: 11
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                        leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: "+"; implicitWidth: 28; implicitHeight: 26
                    enabled: root._aderListeKabel.length > 0 && root._positionenA.length > 0
                    contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 14; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg;
                                            radius: 4; border.color: root.theme.border }
                    onClicked: {
                        var aderNr = root._aderListeKabel[cbAderA.currentIndex].aderNr
                        var pinNr  = root._positionenA[cbPinA.currentIndex].positionNr
                        db.konfkabelPinZuordnen(root._konfkabelId, "A", aderNr, pinNr)
                        root._pinZuordnungA = db.konfkabelPinZuordnungLaden(root._konfkabelId, "A")
                    }
                }
            }
        }

        // Seite B
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: 12; spacing: 6
            visible: root._konfkabelId > 0 && cbSteckerB.currentIndex > 0

            Text { text: qsTr("Seite B"); color: root.theme.accent; font.pixelSize: 11; font.bold: true }

            Repeater {
                model: root._pinZuordnungB
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    property var zd: modelData
                    Text {
                        text: qsTr("Ader %1").arg(zd.aderNr)
                        font.pixelSize: 11; color: root.theme.textPrimary; Layout.preferredWidth: 60
                    }
                    Text {
                        text: (zd.aderFarbe || "–") + (zd.aderBezeichnung ? " · " + zd.aderBezeichnung : "")
                              + (zd.aderQuerschnitt > 0 ? " · " + zd.aderQuerschnitt + " mm²" : "")
                        font.pixelSize: 11; color: root.theme.textMuted; Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: qsTr("→ Pos %1").arg(zd.pinNr)
                        font.pixelSize: 11; color: root.theme.accent; Layout.preferredWidth: 70
                    }
                    Rectangle {
                        width: 26; height: 22; radius: 3
                        color: delMaB.containsMouse ? "#662222" : root.theme.inputBg
                        border.color: root.theme.border
                        Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 14
                               color: delMaB.containsMouse ? "#ffffff" : root.theme.textMuted }
                        MouseArea {
                            id: delMaB; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                db.konfkabelPinZuordnungLoeschen(zd.id)
                                root._pinZuordnungB = db.konfkabelPinZuordnungLaden(root._konfkabelId, "B")
                            }
                        }
                    }
                }
            }

            Text {
                visible: root._pinZuordnungB.length === 0
                text: qsTr("Noch keine Zuordnung.")
                font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                ComboBox {
                    id: cbAderB; Layout.preferredWidth: 150; height: 26
                    model: {
                        var m = []
                        for (var i = 0; i < root._aderListeKabel.length; i++) {
                            var a = root._aderListeKabel[i]
                            m.push(qsTr("Ader %1 (%2)").arg(a.aderNr).arg(a.farbe || "–"))
                        }
                        return m
                    }
                    font.pixelSize: 11
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                        leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                }
                ComboBox {
                    id: cbPinB; Layout.preferredWidth: 150; height: 26
                    model: {
                        var m = []
                        for (var i = 0; i < root._positionenB.length; i++) {
                            var p = root._positionenB[i]
                            m.push(qsTr("Pos %1 – %2").arg(p.positionNr).arg(p.bezeichnung))
                        }
                        return m
                    }
                    font.pixelSize: 11
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                        leftPadding: 6; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: "+"; implicitWidth: 28; implicitHeight: 26
                    enabled: root._aderListeKabel.length > 0 && root._positionenB.length > 0
                    contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 14; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg;
                                            radius: 4; border.color: root.theme.border }
                    onClicked: {
                        var aderNr = root._aderListeKabel[cbAderB.currentIndex].aderNr
                        var pinNr  = root._positionenB[cbPinB.currentIndex].positionNr
                        db.konfkabelPinZuordnen(root._konfkabelId, "B", aderNr, pinNr)
                        root._pinZuordnungB = db.konfkabelPinZuordnungLaden(root._konfkabelId, "B")
                    }
                }
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

                    var kabelId  = cbKabeltyp.currentIndex > 0 ? root._kabelListe[cbKabeltyp.currentIndex - 1].id : -1
                    var steckerA = cbSteckerA.currentIndex > 0 ? root._steckverbinderListe[cbSteckerA.currentIndex - 1].id : 0
                    var steckerB = cbSteckerB.currentIndex > 0 ? root._steckverbinderListe[cbSteckerB.currentIndex - 1].id : 0
                    var laenge   = parseFloat(tfLaenge.text.replace(",",".")) || 0

                    var newId = db.konfkabelSpeichern(root.bauteilId, kabelId, steckerA, steckerB, laenge)
                    if (newId > 0) root._konfkabelId = newId
                    root._ladeAdern()
                    root._ladePositionenA()
                    root._ladePositionenB()
                    root._ladePinZuordnungen()
                    bauteilModel.aktualisieren()
                    root.bauteilGespeichert(root.bauteilId, tfStamBez.text.trim())
                }
            }
        }
    }
}
