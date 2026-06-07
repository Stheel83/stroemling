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

    signal anschlussPlatzieren(int bauteilKlemmeId, string anschlussBezeichnung, string modus)
    signal bauteilGespeichert(int bauteilId, string bezeichnung)

    contentWidth:  availableWidth
    contentHeight: leftCol.implicitHeight
    clip:          true

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

    onBauteilIdChanged: {
        if (bauteilId >= 0) {
            klemmeModel.laden(bauteilId)
            root._bauteilLaden()
        }
    }
    onBauteilBezeichnungChanged:   if (bauteilId >= 0) tfStamBez.text = bauteilBezeichnung
    onBauteilHerstellerChanged:    if (bauteilId >= 0) tfStamHer.text = bauteilHersteller
    onBauteilArtikelnummerChanged: if (bauteilId >= 0) tfStamArt.text = bauteilArtikelnummer

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

    function formBefuellen() {
        if (!klemmeModel.hatKlemme) return
        var k = klemmeModel.klemme
        tfNorm.text      = k.norm      || ""
        tfBreite.text    = k.breiteMm  > 0 ? k.breiteMm.toFixed(1) : ""
        tfBemerkung.text = k.bemerkung || ""
        sbEbenen.value   = k.ebenenAnzahl  !== undefined ? k.ebenenAnzahl  : 1
        sbPktA.value     = k.punkteSeitenA !== undefined ? k.punkteSeitenA : 1
        sbPktB.value     = k.punkteSeitenB !== undefined ? k.punkteSeitenB : 1
        swPe.checked     = k.fussKontaktPe     || false
        swSteg.checked   = k.stegbrueckeFaehig || false

        var idx = cbTyp.indexOfValue(k.anschlussTyp)
        if (idx >= 0) cbTyp.currentIndex = idx

        for (var i = 0; i < farbCombo.count; ++i) {
            if (farbCombo.model.get(i) && farbCombo.model.get(i).farbId === k.gehaeuseFarbeId) {
                farbCombo.currentIndex = i
                break
            }
        }
    }

    Connections {
        target: klemmeModel
        function onKlemmeGeladen() { root.formBefuellen() }
    }

    ColumnLayout {
        id:      leftCol
        width:   parent.width
        spacing: 0

        // ── STAMMDATEN ────────────────────────────────────────────────────
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
                backtabTarget: klemmeModel.hatKlemme ? tfBemerkung : tfStamArt
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
                    tabTarget: klemmeModel.hatKlemme ? tfBreite : tfStamBez; backtabTarget: tfStamUrlHer
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

        // ── Klemme vorhanden / nicht vorhanden ────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 48; color: root.theme.surfaceDeep
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                Text {
                    text: klemmeModel.hatKlemme ? qsTr("Klemme vorhanden") : qsTr("Noch keine Klemme")
                    color: klemmeModel.hatKlemme ? root.theme.accent : root.theme.textMuted
                    font.pixelSize: 13; Layout.fillWidth: true
                }
                Button {
                    text: klemmeModel.hatKlemme ? qsTr("Klemme entfernen") : qsTr("Klemme anlegen")
                    font.pixelSize: 11
                    onClicked: {
                        if (klemmeModel.hatKlemme) klemmeModel.loeschen()
                        else klemmeModel.anlegen(root.bauteilId)
                    }
                    background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg; radius: 4; border.color: root.theme.accent }
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 11;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        // ── Klemme-Eigenschaften (nur wenn Klemme vorhanden) ─────────────
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: 12; spacing: 8
            visible: klemmeModel.hatKlemme

            Text { text: qsTr("Anschlusstyp"); color: root.theme.textMuted; font.pixelSize: 11 }
            ComboBox {
                id: cbTyp
                Layout.fillWidth: true
                model: ListModel {
                    ListElement { text: "Schraube";    value: "schraube"     }
                    ListElement { text: "Federklemme"; value: "federklemme"  }
                    ListElement { text: "Käfigklemme"; value: "kaefigklemme" }
                    ListElement { text: "Stecker";     value: "stecker"      }
                }
                textRole:  "text"
                valueRole: "value"
                function indexOfValue(val) {
                    for (var i = 0; i < count; ++i)
                        if (model.get(i).value === val) return i
                    return 0
                }
                property string selectedTypValue: model.get(currentIndex) ? model.get(currentIndex).value : "schraube"
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 12;
                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            }

            GridLayout {
                Layout.fillWidth: true; columns: 2; rowSpacing: 6; columnSpacing: 8

                Text { text: qsTr("Ebenen");        color: root.theme.textMuted; font.pixelSize: 11 }
                SpinBox {
                    id: sbEbenen; from: 1; to: 10; value: 1; Layout.fillWidth: true
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Text { text: qsTr("Punkte Seite A"); color: root.theme.textMuted; font.pixelSize: 11 }
                SpinBox {
                    id: sbPktA
                    from: sbPktB.value === 0 ? 1 : 0
                    to: 10; value: 1; Layout.fillWidth: true
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Text { text: qsTr("Punkte Seite B"); color: root.theme.textMuted; font.pixelSize: 11 }
                SpinBox {
                    id: sbPktB
                    from: sbPktA.value === 0 ? 1 : 0
                    to: 10; value: 1; Layout.fillWidth: true
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("PE-Fusskontakt");   color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                Switch { id: swPe }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Stegbrücken-fähig"); color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
                Switch { id: swSteg }
            }

            Text { text: qsTr("Breite (mm)"); color: root.theme.textMuted; font.pixelSize: 11 }
            NavTextField {
                id: tfBreite; Layout.fillWidth: true
                tabTarget:        tfNorm
                backtabTarget:    tfStamArt
                placeholderText:  "z.B. 6.2"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                color: root.theme.textPrimary; font.pixelSize: 12
            }

            Text { text: qsTr("Gehäusefarbe"); color: root.theme.textMuted; font.pixelSize: 11 }
            ComboBox {
                id: farbCombo
                Layout.fillWidth: true
                model: farbModel
                textRole: "bezeichnung"
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                property int currentFarbId: -1
                onCurrentIndexChanged: {
                    currentFarbId = (currentIndex >= 0 && model)
                        ? model.data(model.index(currentIndex, 0), 0x101)
                        : -1
                }
                contentItem: RowLayout {
                    spacing: 6
                    Rectangle {
                        width: 14; height: 14; radius: 3
                        property string hex: farbCombo.currentIndex >= 0
                                             ? farbModel.data(farbModel.index(farbCombo.currentIndex, 0), 0x102)
                                             : ""
                        color:        hex || "transparent"
                        border.color: (hex === "transparent" || hex === "") ? root.theme.border : "transparent"
                        border.width: 1
                    }
                    Text {
                        text: farbCombo.currentIndex >= 0
                              ? farbModel.data(farbModel.index(farbCombo.currentIndex, 0), 0x103)
                              : ""
                        color: root.theme.textPrimary; font.pixelSize: 12
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                }
            }

            Text { text: qsTr("Norm"); color: root.theme.textMuted; font.pixelSize: 11 }
            NavTextField {
                id: tfNorm; Layout.fillWidth: true
                tabTarget:       tfBemerkung
                backtabTarget:   tfBreite
                placeholderText: "z.B. DIN EN 60947-7-1"
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                color: root.theme.textPrimary; font.pixelSize: 12
            }

            Text { text: qsTr("Bemerkung Klemme"); color: root.theme.textMuted; font.pixelSize: 11 }
            TextArea {
                id: tfBemerkung
                Layout.fillWidth: true
                wrapMode:        Text.Wrap
                implicitHeight:  Math.max(36, contentHeight + topPadding + bottomPadding)
                color:           root.theme.textPrimary
                font.pixelSize:  12
                topPadding: 6; bottomPadding: 6; leftPadding: 8; rightPadding: 8
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                Keys.onTabPressed:     { event.accepted = true; tfStamBez.forceActiveFocus() }
                Keys.onBacktabPressed: { event.accepted = true; tfNorm.forceActiveFocus() }
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

            // ── Querschnitte ─────────────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 4 }
            Text { text: qsTr("Querschnitte"); color: root.theme.accent; font.pixelSize: 12; font.bold: true }

            Repeater {
                model: ["starr", "flexibel", "aenh_blank", "aenh_isoliert"]
                delegate: RowLayout {
                    property string adertyp: modelData
                    property var eintrag: {
                        var list = klemmeModel.querschnitte
                        for (var i = 0; i < list.length; ++i)
                            if (list[i].adertyp === modelData) return list[i]
                        return null
                    }
                    Layout.fillWidth: true; spacing: 6

                    Item {
                        Layout.preferredWidth: 80
                        implicitHeight: lbl.implicitHeight

                        Text {
                            id: lbl
                            text: {
                                if (modelData === "starr")         return qsTr("Starr")
                                if (modelData === "flexibel")      return qsTr("Flexibel")
                                if (modelData === "aenh_blank")    return qsTr("AEH blank")
                                if (modelData === "aenh_isoliert") return qsTr("AEH isoliert")
                                return modelData
                            }
                            color: root.theme.textSecondary; font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            ToolTip.visible: containsMouse && (modelData === "aenh_blank" || modelData === "aenh_isoliert")
                            ToolTip.text:    modelData === "aenh_blank"
                                             ? qsTr("Aderendhülse (nicht isoliert)")
                                             : qsTr("Aderendhülse (mit Isolationskragen)")
                            ToolTip.delay:   600
                        }
                    }
                    NavTextField {
                        id: tfMin; tabTarget: tfMax; backtabTarget: tfMax
                        placeholderText: "min"
                        text: eintrag ? eintrag.minMm2.toFixed(1) : ""
                        Layout.preferredWidth: 52; font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                    }
                    Text { text: "–"; color: root.theme.textMuted }
                    NavTextField {
                        id: tfMax; tabTarget: tfMin; backtabTarget: tfMin
                        placeholderText: "max mm²"
                        text: eintrag ? eintrag.maxMm2.toFixed(1) : ""
                        Layout.preferredWidth: 64; font.pixelSize: 11
                        background: Rectangle { color: root.theme.inputBg; radius: 3; border.color: root.theme.border }
                        color: root.theme.textPrimary
                    }
                    Button {
                        text: "✓"; font.pixelSize: 10
                        onClicked: klemmeModel.querschnittSetzen(
                            adertyp, parseFloat(tfMin.text) || 0, parseFloat(tfMax.text) || 0)
                        background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg; radius: 3; border.color: root.theme.accent }
                        contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 10;
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "✕"; font.pixelSize: 10; enabled: eintrag !== null
                        onClicked: klemmeModel.querschnittLoeschen(adertyp)
                        background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 3; border.color: "#aa4444" }
                        contentItem: Text { text: parent.text; color: "#aa4444"; font.pixelSize: 10;
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            // ── Brücken ───────────────────────────────────────────────────
            Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 4 }
            Text { text: qsTr("Interne Brücken"); color: root.theme.accent; font.pixelSize: 12; font.bold: true }

            Repeater {
                model: klemmeModel.bruecken
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Ebene %1 → %2").arg(modelData.vonEbene).arg(modelData.nachEbene)
                        color: root.theme.textSecondary; font.pixelSize: 11; Layout.fillWidth: true
                    }
                    Button {
                        text: "✕"; font.pixelSize: 10
                        onClicked: klemmeModel.brueckeLoeschen(modelData.id)
                        background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 3; border.color: "#aa4444" }
                        contentItem: Text { text: parent.text; color: "#aa4444"; font.pixelSize: 10;
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                visible: (klemmeModel.klemme.ebenenAnzahl || 1) > 1

                SpinBox {
                    id: sbVon; from: 1; to: klemmeModel.klemme.ebenenAnzahl || 1; value: 1
                    implicitWidth: 96; implicitHeight: 32
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Text { text: "→"; color: root.theme.textMuted }
                SpinBox {
                    id: sbNach; from: 1; to: klemmeModel.klemme.ebenenAnzahl || 1; value: 2
                    implicitWidth: 96; implicitHeight: 32
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: Text { text: parent.value; color: root.theme.textPrimary; font.pixelSize: 12;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                Button {
                    text: qsTr("Brücke"); font.pixelSize: 11
                    onClicked: klemmeModel.brueckeAnlegen(sbVon.value, sbNach.value)
                    background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg; radius: 4; border.color: root.theme.accent }
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 11;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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
                        parseFloat(tfStamPreis.text) || 0,
                        parseFloat(tfStamU.text)     || 0,
                        parseFloat(tfStamI.text)     || 0,
                        parseFloat(tfStamP.text)     || 0,
                        tfStamBem.text.trim(),
                        tfStamUrlHer.text.trim(), tfStamUrlDat.text.trim())
                    if (klemmeModel.hatKlemme)
                        klemmeModel.speichern(root.klemmeMapSammeln())
                    root.bauteilGespeichert(root.bauteilId, tfStamBez.text.trim())
                }
            }
            Button {
                text: qsTr("Platzieren ..."); enabled: klemmeModel.hatKlemme
                contentItem: Text { text: parent.text; font.pixelSize: 12;
                                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: platzierDialog.open()
            }
        }
    }
}
