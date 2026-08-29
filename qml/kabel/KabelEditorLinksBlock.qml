import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

// SPEICHERN-FUSSBEREICH-01 (Aug 2026): root ist keine ScrollView mehr, sondern
// ein ColumnLayout aus [scrollender Formularbereich, fester Speichern-Fuß] -
// vorher scrollte der Speichern-Button mit den Feldern mit und war bei langen
// Formularen (v.a. Klemme) erst nach Hochscrollen sichtbar. Gleiches Muster
// in KlemmenEditorLinksBlock.qml, SteckverbinderEditor.qml, KontaktEditor.qml,
// KonfkabelEditor.qml.
ColumnLayout {
    id: root
    spacing: 0

    required property int    bauteilId
    required property string bauteilBezeichnung
    required property string bauteilHersteller
    required property string bauteilArtikelnummer
    required property var    theme

    signal bauteilGespeichert(int id, string bezeichnung)

    function _bauteilLaden() {
        var d = bauteilModel.bauteilNachId(bauteilId)
        tfKabBez.text    = d.bezeichnung   || bauteilBezeichnung
        tfKabHer.text    = d.hersteller    || bauteilHersteller
        tfKabArt.text    = d.artikelnummer || bauteilArtikelnummer
        tfKabLief.text   = d.lieferant     || ""
        tfKabPreis.text  = (d.preisEur  > 0) ? d.preisEur.toFixed(2)  : ""
        tfKabU.text      = (d.spannungV > 0) ? d.spannungV.toString() : ""
        tfKabI.text      = (d.stromA    > 0) ? d.stromA.toString()    : ""
        tfKabP.text      = (d.leistungW > 0) ? d.leistungW.toString() : ""
        tfKabBem.text    = d.bemerkung     || ""
        tfKabUrlHer.text = d.urlHersteller || ""
        tfKabUrlDat.text = d.urlDatenblatt || ""
    }

    onBauteilIdChanged: {
        if (bauteilId >= 0) {
            kabelModel.laden(bauteilId)
            root._bauteilLaden()
        }
    }
    onBauteilBezeichnungChanged:   if (bauteilId >= 0) tfKabBez.text = bauteilBezeichnung
    onBauteilHerstellerChanged:    if (bauteilId >= 0) tfKabHer.text = bauteilHersteller
    onBauteilArtikelnummerChanged: if (bauteilId >= 0) tfKabArt.text = bauteilArtikelnummer

    Connections {
        target: kabelModel
        function onGeladen() { root.formBefuellen() }
    }

    function formBefuellen() {
        if (!kabelModel.hatKabel) return
        var k = kabelModel.stammdaten
        tfKabeltyp.text     = k.kabeltyp           || ""
        swGeschirmt.checked = k.geschirmt           || false
        swPaarweise.checked = k.paarweise_verdrillt || false
        tfMantelFarbe.text  = k.aussenmantel_farbe  || ""
        tfAussendm.text     = (k.aussenmantel_mm    > 0) ? k.aussenmantel_mm.toFixed(1) : ""
        tfMatLeiter.text    = k.material_leiter     || ""
        tfMatIso.text       = k.material_isolierung || ""
    }

    function kabelMapSammeln() {
        return {
            "kabeltyp":            tfKabeltyp.text.trim(),
            "geschirmt":           swGeschirmt.checked,
            "paarweise_verdrillt": swPaarweise.checked,
            "aussenmantel_farbe":  tfMantelFarbe.text.trim(),
            "aussenmantel_mm":     parseFloat(tfAussendm.text.replace(",",".")) || 0,
            "material_leiter":     tfMatLeiter.text.trim(),
            "material_isolierung": tfMatIso.text.trim(),
        }
    }

    function _aderLabel(a) {
        if (!a) return "–"
        var s = qsTr("Ader %1").arg(a.aderNr)
        if (a.bezeichnung) s += " – " + a.bezeichnung
        if (a.farbe) s += " (" + a.farbe + ")"
        return s
    }

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

            // STAMMDATEN
            Rectangle {
                Layout.fillWidth: true; height: 32; color: root.theme.surfaceDeep
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("STAMMDATEN"); font.pixelSize: 9; font.weight: Font.Medium
                    color: root.theme.textMuted
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                Text { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 11 }
                NavTextField {
                    id: tfKabBez; Layout.fillWidth: true
                    tabTarget:     tfKabHer
                    backtabTarget: tfMatIso
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    color: root.theme.textPrimary; font.pixelSize: 12
                }

                GridLayout {
                    columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 6
                    Text { text: qsTr("Hersteller");  color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Artikel-Nr."); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfKabHer; Layout.fillWidth: true
                        tabTarget: tfKabArt; backtabTarget: tfKabBez
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfKabArt; Layout.fillWidth: true
                        tabTarget: tfKabLief; backtabTarget: tfKabHer
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Lieferant");   color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Preis (EUR)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfKabLief; Layout.fillWidth: true
                        tabTarget: tfKabPreis; backtabTarget: tfKabArt
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfKabPreis; Layout.fillWidth: true
                        tabTarget: tfKabU; backtabTarget: tfKabLief
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0.00"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Spannung (V)"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Strom (A)");    color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfKabU; Layout.fillWidth: true
                        tabTarget: tfKabI; backtabTarget: tfKabPreis
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfKabI; Layout.fillWidth: true
                        tabTarget: tfKabP; backtabTarget: tfKabU
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Leistung (W)"); color: root.theme.textMuted; font.pixelSize: 11; Layout.columnSpan: 2 }
                    NavTextField {
                        id: tfKabP; Layout.fillWidth: true; Layout.columnSpan: 2
                        tabTarget: tfKabBem; backtabTarget: tfKabI
                        inputMethodHints: Qt.ImhFormattedNumbersOnly; placeholderText: "0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                }

                Text { text: qsTr("Bemerkung"); color: root.theme.textMuted; font.pixelSize: 11 }
                NavTextField {
                    id: tfKabBem; Layout.fillWidth: true
                    tabTarget: tfKabUrlHer; backtabTarget: tfKabP
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    color: root.theme.textPrimary; font.pixelSize: 12
                }

                Text { text: qsTr("Links"); color: root.theme.accent; font.pixelSize: 11; font.bold: true }
                Text { text: qsTr("Hersteller-Website"); color: root.theme.textMuted; font.pixelSize: 11 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    NavTextField {
                        id: tfKabUrlHer; Layout.fillWidth: true
                        tabTarget: tfKabUrlDat; backtabTarget: tfKabBem
                        placeholderText: "https://..."
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    Button {
                        implicitWidth: 60; implicitHeight: 28; enabled: tfKabUrlHer.text.trim().length > 0
                        text: qsTr("Oeffnen")
                        contentItem: Text { text: parent.text; color: parent.enabled ? root.theme.accent : root.theme.textMuted;
                                            font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered && parent.enabled ? root.theme.hover : root.theme.inputBg;
                                                radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                        onClicked: Qt.openUrlExternally(tfKabUrlHer.text.trim())
                    }
                }
                Text { text: qsTr("Datenblatt"); color: root.theme.textMuted; font.pixelSize: 11 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    NavTextField {
                        id: tfKabUrlDat; Layout.fillWidth: true
                        tabTarget: tfKabeltyp; backtabTarget: tfKabUrlHer
                        placeholderText: "https://..."
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    Button {
                        implicitWidth: 60; implicitHeight: 28; enabled: tfKabUrlDat.text.trim().length > 0
                        text: qsTr("Oeffnen")
                        contentItem: Text { text: parent.text; color: parent.enabled ? root.theme.accent : root.theme.textMuted;
                                            font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered && parent.enabled ? root.theme.hover : root.theme.inputBg;
                                                radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                        onClicked: Qt.openUrlExternally(tfKabUrlDat.text.trim())
                    }
                }

            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

            // KABEL-EIGENSCHAFTEN (KABEL-STATUSBLOCK-01, Aug 2026: den früheren
            // "Kabel-Daten vorhanden/Entfernen"-Umschalter entfernt — jeder Weg in
            // diesen Editor legt die Kabel-Daten schon bei der Bauteil-Erstellung an
            // (BaKategorieSidebar.qml "+"-Schnellanlage ruft stammdatenSpeichern()
            // direkt nach dem Anlegen auf, der ⚙-Editor-Button in BaBauteilListe.qml
            // erscheint nur bei bereits vorhandenen Kabel-Daten) — der Zustand
            // "kein Kabel" war über die normale Navigation nie erreichbar. Löschen
            // eines Kabel-Bauteils läuft komplett über das × in der Bauteilliste
            // (bauteil_kabel/-_ader/-_paar hängen per ON DELETE CASCADE an bauteil).
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                Text { text: qsTr("Kabeltyp"); color: root.theme.textMuted; font.pixelSize: 11 }
                NavTextField {
                    id: tfKabeltyp; Layout.fillWidth: true
                    tabTarget:     tfMantelFarbe
                    backtabTarget: tfKabArt
                    placeholderText: "z.B. NYM-J, H07V-K, ÖLFLEX"
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    color: root.theme.textPrimary; font.pixelSize: 12
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Geschirmt"); color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                    Switch { id: swGeschirmt }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: qsTr("Paarweise verdrillt"); color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                    Switch { id: swPaarweise }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 4 }
                Text { text: qsTr("Außenmantel"); color: root.theme.accent; font.pixelSize: 12; font.bold: true }

                GridLayout {
                    columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 6

                    Text { text: qsTr("Farbe");         color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Außen-Ø (mm)");  color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfMantelFarbe; Layout.fillWidth: true
                        tabTarget:     tfAussendm
                        backtabTarget: tfKabeltyp
                        placeholderText: "grau, schwarz …"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfAussendm; Layout.fillWidth: true
                        tabTarget:     tfMatLeiter
                        backtabTarget: tfMantelFarbe
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        placeholderText: "0.0"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }

                    Text { text: qsTr("Leiter-Material"); color: root.theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Iso.-Material");   color: root.theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfMatLeiter; Layout.fillWidth: true
                        tabTarget:     tfMatIso
                        backtabTarget: tfAussendm
                        placeholderText: "Cu, Al …"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                    NavTextField {
                        id: tfMatIso; Layout.fillWidth: true
                        tabTarget:     tfKabBez
                        backtabTarget: tfMatLeiter
                        placeholderText: "PVC, LSZH …"
                        background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                        color: root.theme.textPrimary; font.pixelSize: 12
                    }
                }

                // PAAR-ZUORDNUNG (nur wenn paarweise verdrillt)
                ColumnLayout {
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 6
                    visible: swPaarweise.checked

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }
                    Text {
                        text: qsTr("PAAR-ZUORDNUNG")
                        font.pixelSize: 9; font.weight: Font.Medium; color: root.theme.textMuted
                        Layout.fillWidth: true; Layout.topMargin: 4
                    }

                    Text {
                        visible: kabelModel.adern.length < 2 && kabelModel.paare.length === 0
                        text: qsTr("Mindestens 2 Adern anlegen.")
                        color: root.theme.textMuted; font.pixelSize: 11; font.italic: true
                    }

                    Repeater {
                        model: kabelModel.paare
                        delegate: RowLayout {
                            property var paarDaten: modelData
                            Layout.fillWidth: true; spacing: 4

                            Text {
                                text: "P" + paarDaten.paarNr
                                font.pixelSize: 11; font.bold: true; color: root.theme.textMuted
                                Layout.preferredWidth: 24
                            }

                            ComboBox {
                                id: cbA
                                Layout.fillWidth: true; implicitHeight: 26
                                model: kabelModel.adern
                                displayText: cbA.currentIndex >= 0
                                             ? root._aderLabel(kabelModel.adern[cbA.currentIndex]) : "–"
                                currentIndex: {
                                    var aId = paarDaten.aderA
                                    for (var i = 0; i < kabelModel.adern.length; i++) {
                                        if (kabelModel.adern[i].id === aId) return i
                                    }
                                    return -1
                                }
                                contentItem: Text {
                                    leftPadding: 6; rightPadding: 6; text: parent.displayText
                                    font.pixelSize: 11; color: root.theme.textPrimary
                                    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                }
                                background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                delegate: ItemDelegate {
                                    width: cbA.width; implicitHeight: 28
                                    highlighted: cbA.highlightedIndex === index
                                    contentItem: Text {
                                        leftPadding: 6; text: root._aderLabel(modelData)
                                        font.pixelSize: 11; color: root.theme.textPrimary
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                                }
                                onActivated: {
                                    var bId = cbB.currentIndex >= 0
                                              ? kabelModel.adern[cbB.currentIndex].id : paarDaten.aderB
                                    kabelModel.paarAktualisieren(paarDaten.id,
                                        kabelModel.adern[index].id, bId)
                                }
                            }

                            Text { text: "↔"; font.pixelSize: 11; color: root.theme.textMuted }

                            ComboBox {
                                id: cbB
                                Layout.fillWidth: true; implicitHeight: 26
                                model: kabelModel.adern
                                displayText: cbB.currentIndex >= 0
                                             ? root._aderLabel(kabelModel.adern[cbB.currentIndex]) : "–"
                                currentIndex: {
                                    var bId = paarDaten.aderB
                                    for (var i = 0; i < kabelModel.adern.length; i++) {
                                        if (kabelModel.adern[i].id === bId) return i
                                    }
                                    return -1
                                }
                                contentItem: Text {
                                    leftPadding: 6; rightPadding: 6; text: parent.displayText
                                    font.pixelSize: 11; color: root.theme.textPrimary
                                    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                }
                                background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                                delegate: ItemDelegate {
                                    width: cbB.width; implicitHeight: 28
                                    highlighted: cbB.highlightedIndex === index
                                    contentItem: Text {
                                        leftPadding: 6; text: root._aderLabel(modelData)
                                        font.pixelSize: 11; color: root.theme.textPrimary
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                                }
                                onActivated: {
                                    var aId = cbA.currentIndex >= 0
                                              ? kabelModel.adern[cbA.currentIndex].id : paarDaten.aderA
                                    kabelModel.paarAktualisieren(paarDaten.id,
                                        aId, kabelModel.adern[index].id)
                                }
                            }

                            Button {
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "×"; color: "#aa4444"; font.pixelSize: 14;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? root.theme.activeItemAlt : "transparent"; radius: 3 }
                                onClicked: kabelModel.paarLoeschen(paarDaten.id)
                                ToolTip.visible: hovered; ToolTip.delay: 500
                                ToolTip.text: qsTr("Paar entfernen")
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true; text: qsTr("+ Paar"); implicitHeight: 28
                        enabled: kabelModel.adern.length >= 2
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                            radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                        }
                        onClicked: {
                            var usedIds = []
                            for (var p of kabelModel.paare) { usedIds.push(p.aderA); usedIds.push(p.aderB) }
                            var free = kabelModel.adern.filter(function(a) {
                                return usedIds.indexOf(a.id) < 0
                            })
                            var aId = free.length >= 1 ? free[0].id : kabelModel.adern[0].id
                            var bId = free.length >= 2 ? free[1].id
                                      : (kabelModel.adern.length > 1 ? kabelModel.adern[1].id
                                                                      : kabelModel.adern[0].id)
                            kabelModel.paarAnlegen(aId, bId)
                        }
                    }
                }
            }
        }
    }

    // ── Fester Speichern-Fuß (SPEICHERN-FUSSBEREICH-01) ─────────────────
    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }
    Button {
        Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12
        Layout.topMargin: 8; Layout.bottomMargin: 12
        text: qsTr("Speichern")
        contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12;
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg;
                                radius: 4; border.color: root.theme.accent }
        onClicked: {
            bauteilModel.bearbeiten(root.bauteilId,
                tfKabBez.text.trim(), tfKabHer.text.trim(), tfKabArt.text.trim(),
                tfKabLief.text.trim(),
                parseFloat(tfKabPreis.text.replace(",",".")) || 0,
                parseFloat(tfKabU.text.replace(",","."))     || 0,
                parseFloat(tfKabI.text.replace(",","."))     || 0,
                parseFloat(tfKabP.text.replace(",","."))     || 0,
                tfKabBem.text.trim(),
                tfKabUrlHer.text.trim(), tfKabUrlDat.text.trim())
            if (kabelModel.hatKabel)
                kabelModel.stammdatenSpeichern(root.kabelMapSammeln())
            root.bauteilGespeichert(root.bauteilId, tfKabBez.text.trim())
        }
    }
}
