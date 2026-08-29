import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../Normwerte.js" as NW

// SPEICHERN-FUSSBEREICH-01 (Aug 2026): root ist keine ScrollView mehr, sondern
// ein ColumnLayout aus [scrollender Formularbereich, fester Speichern-Fuß] -
// vorher scrollte der Speichern-Button mit den Feldern mit und war bei langen
// Formularen erst nach Hochscrollen sichtbar. Gleiches Muster in
// KabelEditorLinksBlock.qml, KlemmenEditorLinksBlock.qml,
// SteckverbinderEditor.qml, KonfkabelEditor.qml.
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

    property string _geschlecht: "stift"   // "stift" | "buchse"

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

    function _ktLaden() {
        if (bauteilId < 0) return
        var kt = db.kontaktTypLaden(bauteilId)
        root._geschlecht = kt.geschlecht || "stift"
        cbKontaktgroesse.currentIndex = (kt.kontaktgroesse > 0)
            ? cbKontaktgroesse.model.indexOf(kt.kontaktgroesse) : -1
        cbVerbindungstechnik.currentIndex = cbVerbindungstechnik.model.indexOf(kt.verbindungstechnik || "")
        tfQsSteckMin.text  = (kt.querschnittSteckseiteMin > 0) ? kt.querschnittSteckseiteMin.toString() : ""
        tfQsSteckMax.text  = (kt.querschnittSteckseiteMax > 0) ? kt.querschnittSteckseiteMax.toString() : ""
        tfQsKabelMin.text  = (kt.querschnittKabelMin      > 0) ? kt.querschnittKabelMin.toString()      : ""
        tfQsKabelMax.text  = (kt.querschnittKabelMax      > 0) ? kt.querschnittKabelMax.toString()      : ""
        tfNennstrom.text   = (kt.nennstromA               > 0) ? kt.nennstromA.toString()               : ""
        tfNennspannung.text= (kt.nennspannungV            > 0) ? kt.nennspannungV.toString()            : ""
    }

    onBauteilIdChanged: {
        if (bauteilId >= 0) {
            root._bauteilLaden()
            root._ktLaden()
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
        // SCROLL-ERKENNBAR-01 (Aug 2026): Scrollbar explizit statt Default
        // erzwingen, damit bei langen Formularen (v.a. Klemme) sichtbar wird,
        // dass oberhalb des festen Speichern-Fußes noch mehr Inhalt folgt.
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

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
                    backtabTarget: tfNennspannung
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
                        tabTarget: tfQsSteckMin; backtabTarget: tfStamUrlHer
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

            // ── KONTAKT-EIGENSCHAFTEN ───────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 32; color: root.theme.surfaceDeep
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("KONTAKT"); font.pixelSize: 9; font.weight: Font.Medium; color: root.theme.textMuted
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                Text { text: qsTr("Geschlecht"); color: root.theme.textMuted; font.pixelSize: 11 }
                Row {
                    spacing: 4
                    Repeater {
                        model: [{ label: qsTr("Stift"), val: "stift" }, { label: qsTr("Buchse"), val: "buchse" }]
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

                GridLayout {
                    columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 6

                    Text { text: qsTr("Kontaktgröße (mm²)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Verbindungstechnik"); color: root.theme.textMuted; font.pixelSize: 11 }
                    ComboBox {
                        id: cbKontaktgroesse
                        Layout.fillWidth: true; height: 28
                        model: NW.QUERSCHNITT_WERTE
                        font.pixelSize: 12
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                        contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                            leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                        delegate: ItemDelegate {
                            width: cbKontaktgroesse.width
                            contentItem: Text { text: modelData; color: root.theme.textPrimary; font.pixelSize: 12
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                            highlighted: cbKontaktgroesse.highlightedIndex === index
                        }
                    }
                    ComboBox {
                        id: cbVerbindungstechnik
                        Layout.fillWidth: true; height: 28
                        model: ["crimp", "loet", "idc", "schraube", "federklemme", "schneidring"]
                        font.pixelSize: 12
                        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                        contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12
                            leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                        delegate: ItemDelegate {
                            width: cbVerbindungstechnik.width
                            contentItem: Text { text: modelData; color: root.theme.textPrimary; font.pixelSize: 12
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                            highlighted: cbVerbindungstechnik.highlightedIndex === index
                        }
                    }

                    Text { text: qsTr("Querschnitt Steckseite min (mm²)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Querschnitt Steckseite max (mm²)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfQsSteckMin; Layout.fillWidth: true
                        tabTarget: tfQsSteckMax; backtabTarget: tfStamUrlDat
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfQsSteckMax; Layout.fillWidth: true
                        tabTarget: tfQsKabelMin; backtabTarget: tfQsSteckMin
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Querschnitt Kabelseite min (mm²)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Querschnitt Kabelseite max (mm²)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfQsKabelMin; Layout.fillWidth: true
                        tabTarget: tfQsKabelMax; backtabTarget: tfQsSteckMax
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfQsKabelMax; Layout.fillWidth: true
                        tabTarget: tfNennstrom; backtabTarget: tfQsKabelMin
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Nennstrom (A)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Nennspannung (V)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfNennstrom; Layout.fillWidth: true
                        tabTarget: tfNennspannung; backtabTarget: tfQsKabelMax
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfNennspannung; Layout.fillWidth: true
                        tabTarget: tfStamBez; backtabTarget: tfNennstrom
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
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

                db.kontaktTypSpeichern(
                    root.bauteilId,
                    root._geschlecht,
                    parseFloat((cbKontaktgroesse.displayText || "0").replace(",",".")) || 0,
                    parseFloat(tfQsSteckMin.text.replace(",",".")) || 0,
                    parseFloat(tfQsSteckMax.text.replace(",",".")) || 0,
                    parseFloat(tfQsKabelMin.text.replace(",",".")) || 0,
                    parseFloat(tfQsKabelMax.text.replace(",",".")) || 0,
                    parseFloat(tfNennstrom.text.replace(",",".")) || 0,
                    parseFloat(tfNennspannung.text.replace(",",".")) || 0,
                    cbVerbindungstechnik.displayText)

                bauteilModel.aktualisieren()
                meldungManager.zeigen(qsTr("Kontakt gespeichert."), true)
                root.bauteilGespeichert(root.bauteilId, tfStamBez.text.trim())
            }
        }
    }
}
