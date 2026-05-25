import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Item {
    id: root

    // Wird von BauteilAnsicht gesetzt
    property int    bauteilId:            -1
    property string bauteilBezeichnung:   ""
    property string bauteilHersteller:    ""
    property string bauteilArtikelnummer: ""
    property var    theme
    property bool   debug:                false

    // Signal: Nutzer möchte einen Anschluss auf dem Canvas platzieren
    signal anschlussPlatzieren(int bauteilKlemmeId, string anschlussBezeichnung, string modus)
    signal bauteilGespeichert(int bauteilId, string bezeichnung)

    onBauteilIdChanged: {
        if (bauteilId >= 0) {
            klemmeModel.laden(bauteilId)
            tfStamBez.text = bauteilBezeichnung
            tfStamHer.text = bauteilHersteller
            tfStamArt.text = bauteilArtikelnummer
        }
    }
    onBauteilBezeichnungChanged:   if (bauteilId >= 0) tfStamBez.text = bauteilBezeichnung
    onBauteilHerstellerChanged:    if (bauteilId >= 0) tfStamHer.text = bauteilHersteller
    onBauteilArtikelnummerChanged: if (bauteilId >= 0) tfStamArt.text = bauteilArtikelnummer

    // Interne Hilfsfunktion: Klemme-Map aus Formfeldern
    function klemmeMapSammeln() {
        return {
            "norm":               tfNorm.text,
            "anschlussTyp":       cbTyp.selectedTypValue,
            "ebenenAnzahl":       sbEbenen.value,
            "punkteSeitenA":      sbPktA.value,
            "punkteSeitenB":      sbPktB.value,
            "fussKontaktPe":      swPe.checked,
            "stegbrueckeFaehig":  swSteg.checked,
            "breiteMm":           parseFloat(tfBreite.text) || 0,
            "gehaeuseFarbeId":    farbCombo.currentFarbId,
            "bemerkung":          tfBemerkung.text
        }
    }

    // Formular mit Klemme-Daten befüllen
    function formBefuellen() {
        if (!klemmeModel.hatKlemme) return
        var k = klemmeModel.klemme
        tfNorm.text      = k.norm      || ""
        tfBreite.text    = k.breiteMm  > 0 ? k.breiteMm.toFixed(1) : ""
        tfBemerkung.text = k.bemerkung || ""
        sbEbenen.value   = k.ebenenAnzahl   || 1
        sbPktA.value     = k.punkteSeitenA  || 1
        sbPktB.value     = k.punkteSeitenB  || 1
        swPe.checked     = k.fussKontaktPe  || false
        swSteg.checked   = k.stegbrueckeFaehig || false

        // Anschlusstyp
        var idx = cbTyp.indexOfValue(k.anschlussTyp)
        if (idx >= 0) cbTyp.currentIndex = idx

        // Gehäusefarbe
        for (var i = 0; i < farbCombo.count; ++i) {
            if (farbCombo.model.get(i) && farbCombo.model.get(i).farbId === k.gehaeuseFarbeId) {
                farbCombo.currentIndex = i
                break
            }
        }
    }

    Connections {
        target: klemmeModel
        function onKlemmeGeladen() { formBefuellen() }
    }

    DebugLabel { panelName: qsTr("Klemmen-Eigenschaften"); visible: root.debug }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        handle: Rectangle {
            implicitWidth:  6
            implicitHeight: 6
            color:          SplitHandle.pressed  ? theme.accent
                          : SplitHandle.hovered  ? theme.activeItem
                          : theme.surface

            Rectangle {
                anchors.centerIn: parent
                width: 2; height: 24; radius: 1
                color: parent.SplitHandle.hovered || parent.SplitHandle.pressed ? theme.accentLight : theme.panelMid
            }
        }

        // ── Linke Spalte: Klemmen-Eigenschaften ──────────────────────────
        ScrollView {
            SplitView.preferredWidth: 420
            SplitView.minimumWidth:   260
            SplitView.fillHeight:     true
            contentWidth:  availableWidth
            contentHeight: leftCol.implicitHeight
            clip:          true

            ColumnLayout {
                id:      leftCol
                width:   parent.width
                spacing: 0

                // ── STAMMDATEN ───────────────────────────────────────
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
                        id: tfStamBez; Layout.fillWidth: true
                        tabTarget:     tfStamHer
                        backtabTarget: klemmeModel.hatKlemme ? tfBemerkung : tfStamArt
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }

                    GridLayout {
                        columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 6
                        Text { text: qsTr("Hersteller");  color: theme.textMuted; font.pixelSize: 11 }
                        Text { text: qsTr("Artikel-Nr."); color: theme.textMuted; font.pixelSize: 11 }
                        NavTextField {
                            id: tfStamHer; Layout.fillWidth: true
                        tabTarget:     tfStamArt
                        backtabTarget: tfStamBez
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                        }
                        NavTextField {
                            id: tfStamArt; Layout.fillWidth: true
                        tabTarget:     klemmeModel.hatKlemme ? tfBreite : tfStamBez
                        backtabTarget: tfStamHer
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Item { Layout.fillWidth: true }
                        Button {
                            text: qsTr("Übernehmen"); implicitHeight: 30
                            contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent }
                            onClicked: {
                                bauteilModel.bauteilTitelSpeichern(root.bauteilId,
                                    tfStamBez.text, tfStamHer.text, tfStamArt.text)
                                root.bauteilGespeichert(root.bauteilId, tfStamBez.text)
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                // Klemme vorhanden / nicht vorhanden
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    color: theme.surfaceDeep

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        Text {
                            text: klemmeModel.hatKlemme
                                  ? qsTr("Klemme vorhanden")
                                  : qsTr("Noch keine Klemme")
                            color: klemmeModel.hatKlemme ? theme.accent : theme.textMuted
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }
                        Button {
                            text: klemmeModel.hatKlemme
                                  ? qsTr("Klemme entfernen")
                                  : qsTr("Klemme anlegen")
                            font.pixelSize: 11
                            onClicked: {
                                if (klemmeModel.hatKlemme)
                                    klemmeModel.loeschen()
                                else
                                    klemmeModel.anlegen(root.bauteilId)
                            }
                            background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent }
                            contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 11;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                // Felder nur sichtbar wenn Klemme vorhanden
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    spacing: 8
                    visible: klemmeModel.hatKlemme

                    // Anschlusstyp
                    Text { text: qsTr("Anschlusstyp"); color: theme.textMuted; font.pixelSize: 11 }
                    ComboBox {
                        id: cbTyp
                        Layout.fillWidth: true
                        model: ListModel {
                            ListElement { text: "Schraube";    value: "schraube"    }
                            ListElement { text: "Federklemme"; value: "federklemme" }
                            ListElement { text: "Käfigklemme"; value: "kaefigklemme" }
                            ListElement { text: "Stecker";     value: "stecker"     }
                        }
                        textRole:  "text"
                        valueRole: "value"
                        function indexOfValue(val) {
                            for (var i = 0; i < count; ++i)
                                if (model.get(i).value === val) return i
                            return 0
                        }
                        property string selectedTypValue: model.get(currentIndex) ? model.get(currentIndex).value : "schraube"
                        background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                        contentItem: Text { text: parent.displayText; color: theme.textPrimary; font.pixelSize: 12;
                                            leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    }

                    // Ebenen / Punkte
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 8

                        Text { text: qsTr("Ebenen"); color: theme.textMuted; font.pixelSize: 11 }
                        SpinBox {
                            id: sbEbenen
                            from: 1; to: 4; value: 1
                            Layout.fillWidth: true
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                            contentItem: Text { text: parent.value; color: theme.textPrimary; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }

                        Text { text: qsTr("Punkte Seite A"); color: theme.textMuted; font.pixelSize: 11 }
                        SpinBox {
                            id: sbPktA
                            from: 1; to: 4; value: 1
                            Layout.fillWidth: true
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                            contentItem: Text { text: parent.value; color: theme.textPrimary; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }

                        Text { text: qsTr("Punkte Seite B"); color: theme.textMuted; font.pixelSize: 11 }
                        SpinBox {
                            id: sbPktB
                            from: 1; to: 4; value: 1
                            Layout.fillWidth: true
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                            contentItem: Text { text: parent.value; color: theme.textPrimary; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }

                    // Optionen
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: qsTr("PE-Fusskontakt"); color: theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                        Switch { id: swPe }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: qsTr("Stegbrücken-fähig"); color: theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                        Switch { id: swSteg }
                    }

                    // Breite
                    Text { text: qsTr("Breite (mm)"); color: theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfBreite
                        tabTarget:     tfNorm
                        backtabTarget: tfStamArt
                        Layout.fillWidth: true
                        placeholderText: "z.B. 6.2"
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }

                    // Gehäusefarbe
                    Text { text: qsTr("Gehäusefarbe"); color: theme.textMuted; font.pixelSize: 11 }
                    ComboBox {
                        id: farbCombo
                        Layout.fillWidth: true
                        model: farbModel
                        textRole: "bezeichnung"
                        background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }

                        property int currentFarbId: -1

                        onCurrentIndexChanged: {
                            currentFarbId = (currentIndex >= 0 && model)
                                ? model.data(model.index(currentIndex, 0), 0x101) // IdRole
                                : -1
                        }

                        contentItem: RowLayout {
                            spacing: 6
                            Rectangle {
                                width: 14; height: 14; radius: 3
                                color: farbCombo.currentIndex >= 0
                                       ? farbModel.data(farbModel.index(farbCombo.currentIndex, 0), 0x102)
                                       : "transparent"
                            }
                            Text {
                                text: farbCombo.currentIndex >= 0
                                      ? farbModel.data(farbModel.index(farbCombo.currentIndex, 0), 0x103)
                                      : ""
                                color: theme.textPrimary
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Norm
                    Text { text: qsTr("Norm"); color: theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfNorm
                        tabTarget:     tfBemerkung
                        backtabTarget: tfBreite
                        Layout.fillWidth: true
                        placeholderText: "z.B. DIN EN 60947-7-1"
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }

                    // Bemerkung
                    Text { text: qsTr("Bemerkung"); color: theme.textMuted; font.pixelSize: 11 }
                    NavTextField {
                        id: tfBemerkung
                        tabTarget:     tfStamBez
                        backtabTarget: tfNorm
                        Layout.fillWidth: true
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }

                    // Speichern + Platzieren
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Button {
                            Layout.fillWidth: true
                            text: qsTr("Speichern")
                            onClicked: klemmeModel.speichern(klemmeMapSammeln())
                            background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent }
                            contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            text: qsTr("Platzieren …")
                            enabled: klemmeModel.hatKlemme
                            onClicked: platzierDialog.open()
                            background: Rectangle { color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg; radius: 4; border.color: parent.enabled ? theme.accent : theme.border }
                            contentItem: Text { text: parent.text; color: parent.enabled ? theme.textPrimary : theme.textMuted; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }

                    KlemmePlatzierDialog {
                        id: platzierDialog
                        theme: root.theme
                        debug: root.debug
                        bauteilKlemmeId:    klemmeModel.hatKlemme ? klemmeModel.klemme.klemmeId : -1
                        bauteilBezeichnung: root.bauteilBezeichnung
                        onAccepted: root.anschlussPlatzieren(
                            klemmeModel.klemme.klemmeId,
                            gewaehltAnschluss,
                            gewaehltModus
                        )
                    }

                    // ── Querschnitte ─────────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
                    Text { text: qsTr("Querschnitte"); color: theme.accent; font.pixelSize: 12; font.bold: true }

                    Repeater {
                        model: ["starr", "flexibel", "aderendhulse"]
                        delegate: RowLayout {
                            property string adertyp: modelData
                            property var eintrag: {
                                var list = klemmeModel.querschnitte
                                for (var i = 0; i < list.length; ++i)
                                    if (list[i].adertyp === modelData) return list[i]
                                return null
                            }

                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: {
                                    if (modelData === "starr")       return qsTr("Starr")
                                    if (modelData === "flexibel")    return qsTr("Flexibel")
                                    return qsTr("Aderendhülse")
                                }
                                color: theme.textSecondary; font.pixelSize: 11
                                Layout.preferredWidth: 80
                            }
                            NavTextField {
                                id: tfMin
                        tabTarget:     tfMax
                        backtabTarget: tfMax
                                placeholderText: "min"
                                text: eintrag ? eintrag.minMm2.toFixed(1) : ""
                                Layout.preferredWidth: 52
                                font.pixelSize: 11
                                background: Rectangle { color: theme.inputBg; radius: 3; border.color: theme.border }
                                color: theme.textPrimary
                            }
                            Text { text: "–"; color: theme.textMuted }
                            NavTextField {
                                id: tfMax
                        tabTarget:     tfMin
                        backtabTarget: tfMin
                                placeholderText: "max mm²"
                                text: eintrag ? eintrag.maxMm2.toFixed(1) : ""
                                Layout.preferredWidth: 64
                                font.pixelSize: 11
                                background: Rectangle { color: theme.inputBg; radius: 3; border.color: theme.border }
                                color: theme.textPrimary
                            }
                            Button {
                                text: "✓"
                                font.pixelSize: 10
                                onClicked: klemmeModel.querschnittSetzen(
                                    adertyp, parseFloat(tfMin.text) || 0, parseFloat(tfMax.text) || 0)
                                background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 3; border.color: theme.accent }
                                contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 10;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                text: "✕"
                                font.pixelSize: 10
                                enabled: eintrag !== null
                                onClicked: klemmeModel.querschnittLoeschen(adertyp)
                                background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 3; border.color: "#aa4444" }
                                contentItem: Text { text: parent.text; color: "#aa4444"; font.pixelSize: 10;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }

                    // ── Brücken ──────────────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
                    Text { text: qsTr("Interne Brücken"); color: theme.accent; font.pixelSize: 12; font.bold: true }

                    Repeater {
                        model: klemmeModel.bruecken
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Ebene %1 → %2").arg(modelData.vonEbene).arg(modelData.nachEbene)
                                color: theme.textSecondary; font.pixelSize: 11
                                Layout.fillWidth: true
                            }
                            Button {
                                text: "✕"
                                font.pixelSize: 10
                                onClicked: klemmeModel.brueckeLoeschen(modelData.id)
                                background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 3; border.color: "#aa4444" }
                                contentItem: Text { text: parent.text; color: "#aa4444"; font.pixelSize: 10;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }

                    // Neue Brücke anlegen (nur wenn >1 Ebene)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: (klemmeModel.klemme.ebenenAnzahl || 1) > 1
                        spacing: 6

                        SpinBox {
                            id: sbVon; from: 1; to: klemmeModel.klemme.ebenenAnzahl || 1; value: 1; implicitWidth: 96; implicitHeight: 32
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                            contentItem: Text { text: parent.value; color: theme.textPrimary; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Text { text: "→"; color: theme.textMuted }
                        SpinBox {
                            id: sbNach; from: 1; to: klemmeModel.klemme.ebenenAnzahl || 1; value: 2; implicitWidth: 96; implicitHeight: 32
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                            contentItem: Text { text: parent.value; color: theme.textPrimary; font.pixelSize: 12;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            text: qsTr("Brücke")
                            font.pixelSize: 11
                            onClicked: klemmeModel.brueckeAnlegen(sbVon.value, sbNach.value)
                            background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent }
                            contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 11;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }
        }

        // ── Rechte Spalte: Anschluss-Liste ───────────────────────────────
        Item {
            SplitView.fillWidth:   true
            SplitView.minimumWidth: 180

            DebugLabel { panelName: qsTr("Anschluss-Liste"); visible: root.debug }

            ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Canvas-Vorschau – Höhe passt sich an pA/pB an
            KlemmenVorschau {
                id: vorschau
                Layout.fillWidth:    true
                Layout.preferredHeight: implicitHeight
                theme:       theme
                klemme:      klemmeModel.klemme
                anschluesse: klemmeModel.anschluesse
                bruecken:    klemmeModel.bruecken
                debug:       root.debug
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            // Anschluss-Tabelle
            Rectangle {
                Layout.fillWidth: true
                height: 28
                color: theme.surfaceDeep
                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    Text { text: qsTr("Bezeichnung"); color: theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 80 }
                    Text { text: qsTr("Seite");       color: theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 60 }
                    Text { text: qsTr("Ebene");       color: theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true  }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: klemmeModel.anschluesse

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 26
                    color: index % 2 === 0 ? theme.tableEven : theme.tableOdd

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        Text { text: modelData.bezeichnung; color: theme.textPrimary;   font.pixelSize: 11; Layout.preferredWidth: 80 }
                        Text { text: modelData.seite;       color: theme.textSecondary; font.pixelSize: 11; Layout.preferredWidth: 60 }
                        Text { text: String(modelData.ebene); color: theme.textSecondary; font.pixelSize: 11; Layout.fillWidth: true }
                    }
                }
            }
            }
        }
    }
}
