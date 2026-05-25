import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling

Item {
    id: root
    required property var panel
    required property var theme

    signal klemmenEditorAngefordert(int bauteilId, string bezeichnung)
    signal kabelEditorAngefordert(int bauteilId, string bezeichnung)

    // ── Dialog – Bauteil bearbeiten ──────────────────────────
    Dialog {
        id: dlgBauteilBearbeiten
        title: qsTr("Bauteil bearbeiten")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: 480; padding: 20

        property int    itemId:           -1
        property string altBezeichnung:   ""
        property string altHersteller:    ""
        property string altArtikelnummer: ""
        property string altLieferant:     ""
        property real   altPreis:         0
        property real   altSpannung:      0
        property real   altStrom:         0
        property real   altLeistung:      0
        property string altBemerkung:     ""

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        onOpened: {
            editForm.bezeichnung   = dlgBauteilBearbeiten.altBezeichnung
            editForm.hersteller    = dlgBauteilBearbeiten.altHersteller
            editForm.artikelnummer = dlgBauteilBearbeiten.altArtikelnummer
            editForm.lieferant     = dlgBauteilBearbeiten.altLieferant
            editForm.preis         = dlgBauteilBearbeiten.altPreis    > 0 ? dlgBauteilBearbeiten.altPreis.toFixed(2)    : ""
            editForm.spannung      = dlgBauteilBearbeiten.altSpannung > 0 ? dlgBauteilBearbeiten.altSpannung.toString() : ""
            editForm.strom         = dlgBauteilBearbeiten.altStrom    > 0 ? dlgBauteilBearbeiten.altStrom.toString()    : ""
            editForm.leistung      = dlgBauteilBearbeiten.altLeistung > 0 ? dlgBauteilBearbeiten.altLeistung.toString() : ""
            editForm.bemerkung     = dlgBauteilBearbeiten.altBemerkung
        }

        contentItem: ColumnLayout {
            spacing: 0
            Text { text: dlgBauteilBearbeiten.title; font.pixelSize: 15; font.weight: Font.Medium;
                   color: theme.textPrimary; Layout.bottomMargin: 2 }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.bottomMargin: 8 }
            ScrollView {
                Layout.fillWidth: true
                height: Math.min(editForm.implicitHeight + 16, 460)
                clip: true
                BaFormContent { id: editForm; theme: theme }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 12 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8; Layout.topMargin: 10
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.textSecondary; font.pixelSize: 13;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: dlgBauteilBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editForm.bezeichnung.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: {
                        bauteilModel.bearbeiten(
                            dlgBauteilBearbeiten.itemId,
                            editForm.bezeichnung.trim(), editForm.hersteller.trim(),
                            editForm.artikelnummer.trim(), editForm.lieferant.trim(),
                            parseFloat(editForm.preis)    || 0,
                            parseFloat(editForm.spannung) || 0,
                            parseFloat(editForm.strom)    || 0,
                            parseFloat(editForm.leistung) || 0,
                            editForm.bemerkung.trim()
                        )
                        dlgBauteilBearbeiten.close()
                    }
                }
            }
        }
    }

    // ── Bauteil-Liste ────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; spacing: 0

        Rectangle {
            Layout.fillWidth: true; height: 52; color: theme.surface
            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                Text {
                    text: bauteilModel.nurKlemmen ? qsTr("Klemmen")
                        : bauteilModel.nurKabel   ? qsTr("Kabel")
                        : qsTr("Alle Bauteile")
                    font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 44; color: theme.surface
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                spacing: 8
                Text { text: "🔍"; font.pixelSize: 14; color: theme.textMuted }
                TextField {
                    id: suchfeld; Layout.fillWidth: true
                    placeholderText: qsTr("Bezeichnung, Hersteller oder Artikel-Nr. suchen …")
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                    color: theme.textPrimary; font.pixelSize: 13
                    onTextChanged: bauteilModel.suchen(text)
                }
                Button {
                    visible: suchfeld.text.length > 0; text: "×"; flat: true; implicitWidth: 28; implicitHeight: 28
                    contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 16;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                    onClicked: { suchfeld.text = ""; bauteilModel.laden(bauteilModel.aktiveKategorieId) }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        Rectangle {
            Layout.fillWidth: true; height: 30; color: theme.sidebar
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                spacing: 0
                Text { text: qsTr("Typ");            color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 70;  font.weight: Font.Medium }
                Text { text: qsTr("Bezeichnung");    color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 180; font.weight: Font.Medium }
                Text { text: qsTr("Hersteller");     color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 130; font.weight: Font.Medium }
                Text { text: qsTr("Artikel-Nr.");    color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 110; font.weight: Font.Medium }
                Text { text: qsTr("Preis (€)"); color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 80;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }
                Text { text: qsTr("U (V)");          color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 60;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }
                Text { text: qsTr("I (A)");          color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 60;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }
                Item { Layout.fillWidth: true }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true

            ListView {
                id: bauteilListe
                model: bauteilModel
                clip: true

                Column {
                    anchors.centerIn: parent
                    visible:  bauteilListe.count === 0
                    spacing:  12

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source:   "qrc:/assets/pokestroem_cee.png"
                        width:    560; height: 560
                        fillMode: Image.PreserveAspectFit
                        smooth:   true; mipmap: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: suchfeld.text.length > 0
                              ? qsTr("Keine Ergebnisse für \"%1\"").arg(suchfeld.text)
                              : qsTr("Noch keine Bauteile – mit '+ Neu' anlegen.")
                        color:          theme.textMuted
                        font.pixelSize: 13
                    }
                }

                delegate: Rectangle {
                    width: bauteilListe.width; height: 38
                    property bool isSelected: panel.selectedBauteilId === model.bauteilId
                    color: isSelected ? theme.activeItemAlt
                           : (bHover.containsMouse ? theme.hover
                           : (index % 2 === 0 ? theme.tableEven : theme.tableOdd))

                    HoverHandler { id: bHover }
                    MouseArea {
                        anchors.fill: parent; z: -1
                        onClicked: {
                            panel.selectedBauteilId          = model.bauteilId
                            panel.selectedBauteilBezeichnung = model.bezeichnung
                        }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                        spacing: 0

                        Rectangle {
                            Layout.preferredWidth: 70; height: 20; radius: 3
                            color:        model.istKlemme ? "#1a4a2a" : model.istKabel ? "#1a3a4a" : "transparent"
                            border.color: model.istKlemme ? "#2d7a4a" : model.istKabel ? "#2d6a8a" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text:  model.istKlemme ? qsTr("Klemme") : model.istKabel ? qsTr("Kabel") : ""
                                font.pixelSize: 10
                                color: model.istKlemme ? "#5dba7d" : model.istKabel ? "#5daacc" : "transparent"
                            }
                        }

                        Text { text: model.bezeichnung;   font.pixelSize: 13; color: theme.textSecondary; Layout.preferredWidth: 180; elide: Text.ElideRight }
                        Text { text: model.hersteller;    font.pixelSize: 13; color: theme.textMuted;      Layout.preferredWidth: 130; elide: Text.ElideRight }
                        Text { text: model.artikelnummer; font.pixelSize: 13; color: theme.textMuted;      Layout.preferredWidth: 110; elide: Text.ElideRight }
                        Text {
                            visible: model.istKabel && (model.kabeltyp || "") !== ""
                            text: model.kabeltyp || ""
                            font.pixelSize: 11; color: theme.accent
                            Layout.preferredWidth: 120; elide: Text.ElideRight
                        }
                        Text { text: model.preisEur > 0 ? model.preisEur.toFixed(2) : "–";
                               font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                        Text { text: model.spannungV > 0 ? model.spannungV : "–";
                               font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                        Text { text: model.stromA > 0 ? model.stromA : "–";
                               font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }

                        Item { Layout.fillWidth: true }

                        Row {
                            spacing: 4; visible: bHover.containsMouse
                            Button {
                                visible: model.istKlemme; width: 24; height: 24; flat: true
                                contentItem: Text { text: "⚙"; color: theme.accent; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Klemmen-Editor öffnen")
                                onClicked: {
                                    panel.selectedBauteilId            = model.bauteilId
                                    panel.selectedBauteilBezeichnung   = model.bezeichnung
                                    panel.selectedBauteilHersteller    = model.hersteller
                                    panel.selectedBauteilArtikelnummer = model.artikelnummer
                                    root.klemmenEditorAngefordert(model.bauteilId, model.bezeichnung)
                                }
                            }
                            Button {
                                visible: model.istKabel; width: 24; height: 24; flat: true
                                contentItem: Text { text: "⚙"; color: theme.accent; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Kabel-Editor öffnen")
                                onClicked: {
                                    panel.selectedBauteilId            = model.bauteilId
                                    panel.selectedBauteilBezeichnung   = model.bezeichnung
                                    panel.selectedBauteilHersteller    = model.hersteller
                                    panel.selectedBauteilArtikelnummer = model.artikelnummer
                                    root.kabelEditorAngefordert(model.bauteilId, model.bezeichnung)
                                }
                            }
                            Button {
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "✎"; color: theme.accent; font.pixelSize: 14;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                onClicked: {
                                    dlgBauteilBearbeiten.itemId           = model.bauteilId
                                    dlgBauteilBearbeiten.altBezeichnung   = model.bezeichnung
                                    dlgBauteilBearbeiten.altHersteller    = model.hersteller
                                    dlgBauteilBearbeiten.altArtikelnummer = model.artikelnummer
                                    dlgBauteilBearbeiten.altLieferant     = model.lieferant
                                    dlgBauteilBearbeiten.altPreis         = model.preisEur
                                    dlgBauteilBearbeiten.altSpannung      = model.spannungV
                                    dlgBauteilBearbeiten.altStrom         = model.stromA
                                    dlgBauteilBearbeiten.altLeistung      = model.leistungW
                                    dlgBauteilBearbeiten.altBemerkung     = model.bemerkung
                                    dlgBauteilBearbeiten.open()
                                }
                            }
                            Button {
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "×"; color: "#aa4444"; font.pixelSize: 16;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 4 }
                                onClicked: bauteilModel.loeschen(model.bauteilId)
                            }
                        }
                    }
                }
            }
        }
    }
}
