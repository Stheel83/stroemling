import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Item {
    id: root

    property int    bauteilId:            -1
    property string bauteilBezeichnung:   ""
    property string bauteilHersteller:    ""
    property string bauteilArtikelnummer: ""
    property var    theme
    property bool   debug:                false

    signal bauteilGespeichert(int bauteilId, string bezeichnung)

    function _aderLabel(a) {
        if (!a) return "–"
        var s = qsTr("Ader %1").arg(a.aderNr)
        if (a.bezeichnung) s += " – " + a.bezeichnung
        if (a.farbe) s += " (" + a.farbe + ")"
        return s
    }

    onBauteilIdChanged: {
        if (bauteilId >= 0) {
            kabelModel.laden(bauteilId)
            tfKabBez.text = bauteilBezeichnung
            tfKabHer.text = bauteilHersteller
            tfKabArt.text = bauteilArtikelnummer
        }
    }
    onBauteilBezeichnungChanged:   if (bauteilId >= 0) tfKabBez.text = bauteilBezeichnung
    onBauteilHerstellerChanged:    if (bauteilId >= 0) tfKabHer.text = bauteilHersteller
    onBauteilArtikelnummerChanged: if (bauteilId >= 0) tfKabArt.text = bauteilArtikelnummer

    Connections {
        target: kabelModel
        function onGeladen() { formBefuellen() }
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
            "aussenmantel_mm":     parseFloat(tfAussendm.text) || 0,
            "material_leiter":     tfMatLeiter.text.trim(),
            "material_isolierung": tfMatIso.text.trim(),
        }
    }

    DebugLabel { panelName: qsTr("Kabel-Editor"); visible: root.debug }

    SplitView {
        anchors.fill: parent
        orientation:  Qt.Horizontal

        handle: Rectangle {
            implicitWidth: 6; implicitHeight: 6
            color: SplitHandle.pressed ? theme.accent : SplitHandle.hovered ? theme.activeItem : theme.surface
            Rectangle {
                anchors.centerIn: parent; width: 2; height: 24; radius: 1
                color: parent.SplitHandle.hovered || parent.SplitHandle.pressed ? theme.accentLight : theme.panelMid
            }
        }

        // ── Linke Spalte: STAMMDATEN + Kabel-Eigenschaften ───────────────
        ScrollView {
            SplitView.preferredWidth: 380
            SplitView.minimumWidth:   260
            SplitView.fillHeight:     true
            contentWidth:  availableWidth
            contentHeight: leftCol.implicitHeight
            clip:          true

            ColumnLayout {
                id:      leftCol
                width:   parent.width
                spacing: 0

                // STAMMDATEN
                Rectangle {
                    Layout.fillWidth: true; height: 32; color: theme.surfaceDeep
                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: qsTr("STAMMDATEN"); font.pixelSize: 9; font.weight: Font.Medium; color: theme.textMuted
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                ColumnLayout {
                    Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                    Text { text: qsTr("Bezeichnung"); color: theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfKabBez; Layout.fillWidth: true
                        tabTarget:     tfKabHer
                        backtabTarget: kabelModel.hatKabel ? tfMatIso : tfKabArt
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }

                    GridLayout {
                        columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 6
                        Text { text: qsTr("Hersteller");  color: theme.textMuted; font.pixelSize: 11 }
                        Text { text: qsTr("Artikel-Nr."); color: theme.textMuted; font.pixelSize: 11 }
                        NavTextField {
                            id: tfKabHer; Layout.fillWidth: true
                        tabTarget:     tfKabArt
                        backtabTarget: tfKabBez
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                        }
                        NavTextField {
                            id: tfKabArt; Layout.fillWidth: true
                        tabTarget:     kabelModel.hatKabel ? tfKabeltyp : tfKabBez
                        backtabTarget: tfKabHer
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Button {
                            text: qsTr("Übernehmen"); implicitHeight: 30
                            contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent }
                            onClicked: {
                                bauteilModel.bauteilTitelSpeichern(root.bauteilId,
                                    tfKabBez.text, tfKabHer.text, tfKabArt.text)
                                root.bauteilGespeichert(root.bauteilId, tfKabBez.text)
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                // Kabel-Status
                Rectangle {
                    Layout.fillWidth: true; height: 48; color: theme.surfaceDeep
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        Text {
                            text: kabelModel.hatKabel ? qsTr("Kabel-Daten vorhanden")
                                                       : qsTr("Noch keine Kabel-Daten")
                            color: kabelModel.hatKabel ? theme.accent : theme.textMuted
                            font.pixelSize: 13; Layout.fillWidth: true
                        }
                        Button {
                            text: kabelModel.hatKabel ? qsTr("Entfernen") : qsTr("Anlegen")
                            font.pixelSize: 11
                            onClicked: {
                                if (kabelModel.hatKabel) {
                                    kabelModel.kabelLoeschen()
                                } else {
                                    kabelModel.laden(root.bauteilId)
                                    kabelModel.stammdatenSpeichern({ geschirmt: false, paarweise_verdrillt: false })
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                // Kabel-Eigenschaften (nur wenn Kabel-Daten vorhanden)
                ColumnLayout {
                    Layout.fillWidth: true; Layout.margins: 12; spacing: 8
                    visible: kabelModel.hatKabel

                    // Kabeltyp
                    Text { text: qsTr("Kabeltyp"); color: theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfKabeltyp; Layout.fillWidth: true
                        tabTarget:     tfMantelFarbe
                        backtabTarget: tfKabArt
                        placeholderText: "z.B. NYM-J, H07V-K, ÖLFLEX"
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }

                    // Optionen
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: qsTr("Geschirmt");          color: theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                        Switch { id: swGeschirmt }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: qsTr("Paarweise verdrillt"); color: theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                        Switch { id: swPaarweise }
                    }

                    // Außenmantel
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
                    Text { text: qsTr("Außenmantel"); color: theme.accent; font.pixelSize: 12; font.bold: true }

                    GridLayout {
                        columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 6

                        Text { text: qsTr("Farbe");      color: theme.textMuted; font.pixelSize: 11 }
                        Text { text: qsTr("Außen-Ø (mm)"); color: theme.textMuted; font.pixelSize: 11 }
                        NavTextField {
                            id: tfMantelFarbe; Layout.fillWidth: true
                        tabTarget:     tfAussendm
                        backtabTarget: tfKabeltyp
                            placeholderText: "grau, schwarz …"
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                        }
                        NavTextField {
                            id: tfAussendm; Layout.fillWidth: true
                        tabTarget:     tfMatLeiter
                        backtabTarget: tfMantelFarbe
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            placeholderText: "0.0"
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                        }

                        Text { text: qsTr("Leiter-Material"); color: theme.textMuted; font.pixelSize: 11 }
                        Text { text: qsTr("Iso.-Material");   color: theme.textMuted; font.pixelSize: 11 }
                        NavTextField {
                            id: tfMatLeiter; Layout.fillWidth: true
                        tabTarget:     tfMatIso
                        backtabTarget: tfAussendm
                            placeholderText: "Cu, Al …"
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                        }
                        NavTextField {
                            id: tfMatIso; Layout.fillWidth: true
                        tabTarget:     tfKabBez
                        backtabTarget: tfMatLeiter
                            placeholderText: "PVC, LSZH …"
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                        }
                    }

                    // Speichern
                    Button {
                        Layout.fillWidth: true; text: qsTr("Kabel-Daten speichern")
                        contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 12;
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent }
                        onClicked: {
                            if (kabelModel.stammdatenSpeichern(kabelMapSammeln()))
                                root.bauteilGespeichert(root.bauteilId, tfKabBez.text)
                        }
                    }

                    // ── PAAR-ZUORDNUNG (nur wenn paarweise verdrillt) ──────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 6
                        visible: swPaarweise.checked

                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
                        Text {
                            text: qsTr("PAAR-ZUORDNUNG")
                            font.pixelSize: 9; font.weight: Font.Medium; color: theme.textMuted
                            Layout.fillWidth: true; Layout.topMargin: 4
                        }

                        Text {
                            visible: kabelModel.adern.length < 2 && kabelModel.paare.length === 0
                            text: qsTr("Mindestens 2 Adern anlegen.")
                            color: theme.textMuted; font.pixelSize: 11; font.italic: true
                        }

                        Repeater {
                            model: kabelModel.paare
                            delegate: RowLayout {
                                property var paarDaten: modelData
                                Layout.fillWidth: true; spacing: 4

                                Text {
                                    text: "P" + paarDaten.paarNr
                                    font.pixelSize: 11; font.bold: true; color: theme.textMuted
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
                                        leftPadding: 6; rightPadding: 6
                                        text: parent.displayText
                                        font.pixelSize: 11; color: theme.textPrimary
                                        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                    }
                                    background: Rectangle { color: theme.inputBg; radius: 3; border.color: theme.border }
                                    delegate: ItemDelegate {
                                        width: cbA.width; implicitHeight: 28
                                        highlighted: cbA.highlightedIndex === index
                                        contentItem: Text {
                                            leftPadding: 6; text: root._aderLabel(modelData)
                                            font.pixelSize: 11; color: theme.textPrimary
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                                    }
                                    onActivated: {
                                        var bId = cbB.currentIndex >= 0
                                                  ? kabelModel.adern[cbB.currentIndex].id : paarDaten.aderB
                                        kabelModel.paarAktualisieren(paarDaten.id,
                                            kabelModel.adern[index].id, bId)
                                    }
                                }

                                Text { text: "↔"; font.pixelSize: 11; color: theme.textMuted }

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
                                        leftPadding: 6; rightPadding: 6
                                        text: parent.displayText
                                        font.pixelSize: 11; color: theme.textPrimary
                                        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                    }
                                    background: Rectangle { color: theme.inputBg; radius: 3; border.color: theme.border }
                                    delegate: ItemDelegate {
                                        width: cbB.width; implicitHeight: 28
                                        highlighted: cbB.highlightedIndex === index
                                        contentItem: Text {
                                            leftPadding: 6; text: root._aderLabel(modelData)
                                            font.pixelSize: 11; color: theme.textPrimary
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle { color: highlighted ? theme.hover : "transparent" }
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
                                    background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 3 }
                                    onClicked: kabelModel.paarLoeschen(paarDaten.id)
                                }
                            }
                        }

                        Button {
                            Layout.fillWidth: true; text: qsTr("+ Paar"); implicitHeight: 28
                            enabled: kabelModel.adern.length >= 2
                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? theme.accent : theme.textMuted
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? theme.activeItemAlt : theme.activeItem; radius: 4
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

        // ── Rechte Spalte: Ader-Tabelle ──────────────────────────────────
        Item {
            SplitView.fillWidth:    true
            SplitView.minimumWidth: 200

            DebugLabel { panelName: qsTr("Ader-Tabelle"); visible: root.debug }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Tabellenkopf
                Rectangle {
                    Layout.fillWidth: true; height: 30; color: theme.sidebar
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                        spacing: 0
                        Text { text: qsTr("Nr."); color: theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 36 }
                        Text { text: qsTr("Bezeichnung"); color: theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 120 }
                        Text { text: qsTr("Farbe / Kennung"); color: theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 110 }
                        Text { text: qsTr("mm²"); color: theme.borderLight; font.pixelSize: 11; font.weight: Font.Medium; Layout.fillWidth: true }
                        Item { width: 80 }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                ListView {
                    id: aderListe
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    clip: true
                    model: kabelModel.adern

                    Text {
                        anchors.centerIn: parent
                        visible: aderListe.count === 0
                        text: kabelModel.hatKabel
                              ? qsTr("Noch keine Adern – mit '+ Ader' hinzufügen.")
                              : qsTr("Kabel-Daten anlegen um Adern zu definieren.")
                        color: theme.borderDark; font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                    }

                    delegate: Rectangle {
                        width:  aderListe.width
                        height: 34
                        color:  index % 2 === 0 ? theme.tableEven : theme.tableOdd

                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                            spacing: 4

                            Text {
                                text:  String(modelData.aderNr)
                                color: theme.textMuted; font.pixelSize: 11
                                Layout.preferredWidth: 36
                            }

                            NavTextField {
                                id: tfAderBez
                        tabTarget:     tfAderFarbe
                        backtabTarget: tfAderMm2
                                Layout.preferredWidth: 116
                                text: modelData.bezeichnung
                                font.pixelSize: 11; implicitHeight: 26
                                background: Rectangle { color: theme.inputBg; radius: 3; border.color: theme.border }
                                color: theme.textPrimary
                                onEditingFinished: kabelModel.aderAktualisieren(modelData.id, {
                                    "bezeichnung": text,
                                    "farbe":       tfAderFarbe.text,
                                    "querschnitt_mm2": parseFloat(tfAderMm2.text) || 0
                                })
                            }

                            NavTextField {
                                id: tfAderFarbe
                        tabTarget:     tfAderMm2
                        backtabTarget: tfAderBez
                                Layout.preferredWidth: 106
                                text: modelData.farbe
                                font.pixelSize: 11; implicitHeight: 26
                                background: Rectangle { color: theme.inputBg; radius: 3; border.color: theme.border }
                                color: theme.textPrimary
                                onEditingFinished: kabelModel.aderAktualisieren(modelData.id, {
                                    "bezeichnung": tfAderBez.text,
                                    "farbe":       text,
                                    "querschnitt_mm2": parseFloat(tfAderMm2.text) || 0
                                })
                            }

                            NavTextField {
                                id: tfAderMm2
                        tabTarget:     tfAderBez
                        backtabTarget: tfAderFarbe
                                Layout.fillWidth: true
                                text: modelData.querschnittMm2 > 0 ? modelData.querschnittMm2.toFixed(2) : ""
                                placeholderText: "1.5"
                                font.pixelSize: 11; implicitHeight: 26
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                background: Rectangle { color: theme.inputBg; radius: 3; border.color: theme.border }
                                color: theme.textPrimary
                                onEditingFinished: kabelModel.aderAktualisieren(modelData.id, {
                                    "bezeichnung": tfAderBez.text,
                                    "farbe":       tfAderFarbe.text,
                                    "querschnitt_mm2": parseFloat(text) || 0
                                })
                            }

                            Row {
                                spacing: 2
                                Button {
                                    width: 22; height: 22; flat: true
                                    contentItem: Text { text: "↑"; color: theme.accent; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                                    onClicked: kabelModel.aderSchieben(modelData.id, -1)
                                }
                                Button {
                                    width: 22; height: 22; flat: true
                                    contentItem: Text { text: "↓"; color: theme.accent; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                                    onClicked: kabelModel.aderSchieben(modelData.id, 1)
                                }
                                Button {
                                    width: 22; height: 22; flat: true
                                    contentItem: Text { text: "×"; color: "#aa4444"; font.pixelSize: 16;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 3 }
                                    onClicked: kabelModel.aderLoeschen(modelData.id)
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                Rectangle {
                    Layout.fillWidth: true; height: 44; color: theme.surfaceDeep
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        Text {
                            text: qsTr("%1 Ader(n)").arg(kabelModel.adern.length)
                            color: theme.textMuted; font.pixelSize: 12; Layout.fillWidth: true
                        }
                        Button {
                            text: qsTr("+ Ader"); implicitHeight: 30
                            enabled: kabelModel.hatKabel
                            contentItem: Text { text: parent.text; color: parent.enabled ? theme.accent : theme.textMuted; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.activeItemAlt : theme.activeItem; radius: 4 }
                            onClicked: kabelModel.aderAnlegen()
                        }
                    }
                }
            }
        }
    }
}
