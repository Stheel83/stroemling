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
                    bauteilModel.aktualisieren()
                    root.bauteilGespeichert(root.bauteilId, tfStamBez.text.trim())
                }
            }
        }
    }
}
