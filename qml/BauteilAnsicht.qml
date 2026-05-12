import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

// ============================================================
// BauteilAnsicht.qml
// Bauteil-Datenbank: Kategoriebaum links, Bauteile rechts
// ============================================================

Item {
    id: root

    property var    theme
    property bool   debug:                      false
    property int    projektId:                  -1
    property string aktiveSpezialAnsicht:       ""   // "" | "klemmenreihen" | "makros"
    property var    makroListe:                 []   // [{id, name, beschreibung, kategorie, elementAnzahl}]
    property int    selectedBauteilId:            -1
    property string selectedBauteilBezeichnung:   ""
    property string selectedBauteilHersteller:    ""
    property string selectedBauteilArtikelnummer: ""

    // Wird von KlemmenreihenAnsicht weitergeleitet
    signal klemmeAnschlussModusAPlatzieren(int bauteilKlemmeId, string anschlussBezeichnung, string bmk, int klemmeId)
    signal klemmenEditorAngefordert(int bauteilId, string bezeichnung)
    signal kabelEditorAngefordert(int bauteilId, string bezeichnung)
    signal makroEinfuegenAngefordert(int makroId, string name)

    function makroListeAktualisieren() {
        root.makroListe = db.makroListe()
    }

    // --------------------------------------------------------
    // Dialoge – Kategorie
    // --------------------------------------------------------

    Dialog {
        id: dlgKategorieNeu
        title: qsTr("Neue Kategorie")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 340
        padding: 20

        property int parentId: -1

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: dlgKategorieNeu.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
            Text { text: qsTr("Name"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: inpKatName; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgKategorieNeu.close()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                    enabled: inpKatName.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
                    onClicked: {
                        kategorieModel.anlegen(dlgKategorieNeu.parentId, inpKatName.text.trim())
                        inpKatName.text = ""
                        dlgKategorieNeu.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: dlgKategorieBearbeiten
        title: qsTr("Kategorie bearbeiten")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 340
        padding: 20

        property int    itemId:  -1
        property string altName: ""

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        onOpened: editKatName.text = dlgKategorieBearbeiten.altName

        contentItem: ColumnLayout {
            spacing: 10
            Text { text: dlgKategorieBearbeiten.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
            Text { text: qsTr("Name"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: editKatName; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgKategorieBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editKatName.text.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
                    onClicked: {
                        kategorieModel.bearbeiten(dlgKategorieBearbeiten.itemId, editKatName.text.trim())
                        dlgKategorieBearbeiten.close()
                    }
                }
            }
        }
    }

    // --------------------------------------------------------
    // Bauteil-Formular (wiederverwendbar in beiden Dialogen)
    // --------------------------------------------------------

    component BauteilFormContent: ColumnLayout {
        property alias bezeichnung:   fBez.text
        property alias hersteller:    fHer.text
        property alias artikelnummer: fArt.text
        property alias lieferant:     fLief.text
        property alias preis:         fPreis.text
        property alias spannung:      fSpannung.text
        property alias strom:         fStrom.text
        property alias leistung:      fLeistung.text
        property alias bemerkung:     fBem.text

        width: parent.width
        spacing: 8

        Text { text: qsTr("Bezeichnung *"); color: theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: fBez; Layout.fillWidth: true
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14
        }

        GridLayout {
            columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 8

            Text { text: qsTr("Hersteller");    color: theme.textMuted; font.pixelSize: 12 }
            Text { text: qsTr("Artikelnummer"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: fHer; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            TextField {
                id: fArt; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }

            Text { text: qsTr("Lieferant");  color: theme.textMuted; font.pixelSize: 12 }
            Text { text: qsTr("Preis (€)"); color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: fLief; Layout.fillWidth: true
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14
            }
            TextField {
                id: fPreis; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14; placeholderText: "0.00"
            }

            Text { text: qsTr("Spannung (V)"); color: theme.textMuted; font.pixelSize: 12 }
            Text { text: qsTr("Strom (A)");    color: theme.textMuted; font.pixelSize: 12 }
            TextField {
                id: fSpannung; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14; placeholderText: "0"
            }
            TextField {
                id: fStrom; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14; placeholderText: "0"
            }

            Text { text: qsTr("Leistung (W)"); color: theme.textMuted; font.pixelSize: 12; Layout.columnSpan: 2 }
            TextField {
                id: fLeistung; Layout.fillWidth: true; Layout.columnSpan: 2
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                color: theme.textPrimary; font.pixelSize: 14; placeholderText: "0"
            }
        }

        Text { text: qsTr("Bemerkung"); color: theme.textMuted; font.pixelSize: 12 }
        TextArea {
            id: fBem; Layout.fillWidth: true; height: 72
            wrapMode: TextArea.Wrap
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14; padding: 8
        }
    }

    // --------------------------------------------------------
    // Dialoge – Bauteil anlegen / bearbeiten
    // --------------------------------------------------------

    Dialog {
        id: dlgBauteilNeu
        title: qsTr("Neues Bauteil")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 480
        padding: 20

        property int kategorieId: -1

        background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6 }

        onOpened: {
            neuForm.bezeichnung = ""; neuForm.hersteller    = ""
            neuForm.artikelnummer = ""; neuForm.lieferant   = ""
            neuForm.preis = "";       neuForm.spannung      = ""
            neuForm.strom = "";       neuForm.leistung      = ""
            neuForm.bemerkung = ""
        }

        contentItem: ColumnLayout {
            spacing: 0

            Text { text: dlgBauteilNeu.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary; Layout.bottomMargin: 2 }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.bottomMargin: 8 }

            ScrollView {
                Layout.fillWidth: true
                height: Math.min(neuForm.implicitHeight + 16, 460)
                clip: true
                BauteilFormContent { id: neuForm }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 12 }

            RowLayout {
                Layout.fillWidth: true; spacing: 8; Layout.topMargin: 10
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgBauteilNeu.close()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                    enabled: neuForm.bezeichnung.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
                    onClicked: {
                        bauteilModel.anlegen(
                            dlgBauteilNeu.kategorieId,
                            neuForm.bezeichnung.trim(), neuForm.hersteller.trim(),
                            neuForm.artikelnummer.trim(), neuForm.lieferant.trim(),
                            parseFloat(neuForm.preis)    || 0,
                            parseFloat(neuForm.spannung) || 0,
                            parseFloat(neuForm.strom)    || 0,
                            parseFloat(neuForm.leistung) || 0,
                            neuForm.bemerkung.trim()
                        )
                        dlgBauteilNeu.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: dlgBauteilBearbeiten
        title: qsTr("Bauteil bearbeiten")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 480
        padding: 20

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

            Text { text: dlgBauteilBearbeiten.title; font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary; Layout.bottomMargin: 2 }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.bottomMargin: 8 }

            ScrollView {
                Layout.fillWidth: true
                height: Math.min(editForm.implicitHeight + 16, 460)
                clip: true
                BauteilFormContent { id: editForm }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 12 }

            RowLayout {
                Layout.fillWidth: true; spacing: 8; Layout.topMargin: 10
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: theme.panelMid; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                    onClicked: dlgBauteilBearbeiten.close()
                }
                Button {
                    text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                    enabled: editForm.bezeichnung.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13;
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled ? theme.btnPrimary : theme.btnDisabled; radius: 4 }
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

    // --------------------------------------------------------
    // Hauptlayout
    // --------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Kategoriebaum (links) -------------------------
        Rectangle {
            Layout.fillHeight: true
            width: 240
            color: theme.sidebar

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── BIBLIOTHEK ─────────────────────────────────────
                Text {
                    text: qsTr("BIBLIOTHEK")
                    font.pixelSize: 9; font.weight: Font.Medium; color: theme.textMuted
                    leftPadding: 16; Layout.fillWidth: true
                    Layout.topMargin: 8; Layout.bottomMargin: 2
                }

                // Bauteile
                Rectangle {
                    Layout.fillWidth: true; height: 36
                    property bool sel: root.aktiveSpezialAnsicht === "" && !bauteilModel.nurKlemmen && !bauteilModel.nurKabel
                    color: sel ? theme.hover : (baulibH.hovered ? theme.hover : "transparent")
                    HoverHandler { id: baulibH }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                        spacing: 6
                        Text { text: "📦"; font.pixelSize: 12 }
                        Text { text: qsTr("Bauteile"); font.pixelSize: 13; Layout.fillWidth: true
                               color: parent.parent.sel ? theme.textPrimary : theme.textSecondary }
                        Button {
                            visible: baulibH.hovered; width: 22; height: 22; flat: true
                            contentItem: Text { text: "+"; color: theme.accent; font.pixelSize: 14;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: { dlgBauteilNeu.kategorieId = bauteilModel.aktiveKategorieId; dlgBauteilNeu.open() }
                        }
                    }
                    MouseArea { anchors.fill: parent; z: -1; onClicked: {
                        bauteilModel.setNurKlemmen(false); bauteilModel.setNurKabel(false)
                        bauteilModel.laden(-1); root.aktiveSpezialAnsicht = ""
                    }}
                }

                // Klemmen
                Rectangle {
                    Layout.fillWidth: true; height: 36
                    property bool sel: root.aktiveSpezialAnsicht === "" && bauteilModel.nurKlemmen
                    color: sel ? theme.hover : (klemmlibH.hovered ? theme.hover : "transparent")
                    HoverHandler { id: klemmlibH }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                        spacing: 6
                        Text { text: "🔌"; font.pixelSize: 12 }
                        Text { text: qsTr("Klemmen"); font.pixelSize: 13; Layout.fillWidth: true
                               color: parent.parent.sel ? theme.textPrimary : theme.textSecondary }
                        Button {
                            visible: klemmlibH.hovered; width: 22; height: 22; flat: true
                            contentItem: Text { text: "+"; color: theme.accent; font.pixelSize: 14;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: {
                                var newId = bauteilModel.anlegen(-1, qsTr("Neue Klemme"), "", "", "", 0, 0, 0, 0, "")
                                if (newId > 0) {
                                    klemmeModel.anlegen(newId)
                                    bauteilModel.setNurKlemmen(true)
                                    bauteilModel.setNurKabel(false)
                                    bauteilModel.laden(-1)
                                    root.selectedBauteilId          = newId
                                    root.selectedBauteilBezeichnung = qsTr("Neue Klemme")
                                    root.selectedBauteilHersteller    = ""
                                    root.selectedBauteilArtikelnummer = ""
                                    root.aktiveSpezialAnsicht = ""
                                    root.klemmenEditorAngefordert(newId, qsTr("Neue Klemme"))
                                }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; z: -1; onClicked: {
                        bauteilModel.setNurKlemmen(true); bauteilModel.setNurKabel(false)
                        bauteilModel.laden(-1); root.aktiveSpezialAnsicht = ""
                    }}
                }

                // Kabel
                Rectangle {
                    Layout.fillWidth: true; height: 36
                    property bool sel: root.aktiveSpezialAnsicht === "" && bauteilModel.nurKabel
                    color: sel ? theme.hover : (kabellibH.hovered ? theme.hover : "transparent")
                    HoverHandler { id: kabellibH }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                        spacing: 6
                        Text { text: "🔗"; font.pixelSize: 12 }
                        Text { text: qsTr("Kabel"); font.pixelSize: 13; Layout.fillWidth: true
                               color: parent.parent.sel ? theme.textPrimary : theme.textSecondary }
                        Button {
                            visible: kabellibH.hovered; width: 22; height: 22; flat: true
                            contentItem: Text { text: "+"; color: theme.accent; font.pixelSize: 14;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                            onClicked: {
                                var newId = bauteilModel.anlegen(-1, qsTr("Neues Kabel"), "", "", "", 0, 0, 0, 0, "")
                                if (newId > 0) {
                                    kabelModel.laden(newId)
                                    kabelModel.stammdatenSpeichern({ geschirmt: false, paarweise_verdrillt: false })
                                    bauteilModel.setNurKabel(true)
                                    bauteilModel.setNurKlemmen(false)
                                    bauteilModel.laden(-1)
                                    root.selectedBauteilId          = newId
                                    root.selectedBauteilBezeichnung = qsTr("Neues Kabel")
                                    root.selectedBauteilHersteller    = ""
                                    root.selectedBauteilArtikelnummer = ""
                                    root.aktiveSpezialAnsicht = ""
                                    root.kabelEditorAngefordert(newId, qsTr("Neues Kabel"))
                                }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; z: -1; onClicked: {
                        bauteilModel.setNurKlemmen(false); bauteilModel.setNurKabel(true)
                        bauteilModel.laden(-1); root.aktiveSpezialAnsicht = ""
                    }}
                }

                // Geräte (Platzhalter)
                Rectangle {
                    Layout.fillWidth: true; height: 36
                    color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                        spacing: 6
                        Text { text: "⚡"; font.pixelSize: 12; opacity: 0.4 }
                        Text { text: qsTr("Geräte"); font.pixelSize: 13; color: theme.textMuted; opacity: 0.6; Layout.fillWidth: true }
                        Text { text: qsTr("(später)"); font.pixelSize: 10; color: theme.textMuted; opacity: 0.5 }
                    }
                }


                // ── KATEGORIEN ──────────────────────────────────────
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 2 }

                Rectangle {
                    Layout.fillWidth: true; height: 44; color: theme.sidebar
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                        Text { text: qsTr("KATEGORIEN"); font.pixelSize: 9; font.weight: Font.Medium;
                               color: theme.textMuted; Layout.fillWidth: true }
                        Button {
                            text: qsTr("+ Neu"); flat: true
                            contentItem: Text { text: parent.text; color: theme.accent; font.pixelSize: 12 }
                            background: Rectangle { color: parent.hovered ? theme.badge : "transparent"; radius: 4 }
                            onClicked: { dlgKategorieNeu.parentId = -1; dlgKategorieNeu.open() }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true

                    ListView {
                        id: katListe
                        model: kategorieModel
                        clip: true

                        delegate: Rectangle {
                            width: katListe.width; height: 36
                            color: isSelected ? theme.hover : (katHover.hovered ? theme.hover : "transparent")
                            property bool isSelected: bauteilModel.aktiveKategorieId === model.kategorieId

                            HoverHandler { id: katHover }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16 + model.tiefe * 14; rightMargin: 4 }
                                spacing: 6

                                Text { text: model.hatKinder ? "📁" : "🏷"; font.pixelSize: 12 }
                                Text {
                                    text: model.name; font.pixelSize: 13
                                    color: isSelected ? theme.textPrimary : theme.textSecondary
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }

                                Row {
                                    spacing: 2; visible: katHover.hovered
                                    Button {
                                        width: 22; height: 22; flat: true
                                        contentItem: Text { text: "+"; color: theme.accent; font.pixelSize: 14;
                                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                                        onClicked: { dlgKategorieNeu.parentId = model.kategorieId; dlgKategorieNeu.open() }
                                    }
                                    Button {
                                        width: 22; height: 22; flat: true
                                        contentItem: Text { text: "✎"; color: theme.accent; font.pixelSize: 13;
                                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                                        onClicked: {
                                            dlgKategorieBearbeiten.itemId  = model.kategorieId
                                            dlgKategorieBearbeiten.altName = model.name
                                            dlgKategorieBearbeiten.open()
                                        }
                                    }
                                    Button {
                                        width: 22; height: 22; flat: true
                                        contentItem: Text { text: "×"; color: "#aa4444"; font.pixelSize: 16;
                                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        background: Rectangle { color: parent.hovered ? "#3a1a1a" : "transparent"; radius: 3 }
                                        onClicked: kategorieModel.loeschen(model.kategorieId)
                                    }
                                }
                            }

                            MouseArea { anchors.fill: parent; z: -1; onClicked: { bauteilModel.laden(model.kategorieId); root.aktiveSpezialAnsicht = "" } }
                        }
                    }
                }

                // ── ZUSAMMENSTELLUNGEN ─────────────────────────────
                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
                Text {
                    text: qsTr("ZUSAMMENSTELLUNGEN")
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    color: theme.textMuted
                    leftPadding: 16
                    Layout.fillWidth: true
                    Layout.topMargin: 5
                    Layout.bottomMargin: 2
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    color: root.aktiveSpezialAnsicht === "klemmenreihen"
                           ? theme.hover : (krHover.containsMouse ? theme.hover : "transparent")
                    HoverHandler { id: krHover }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                        Text { text: "🔌"; font.pixelSize: 12 }
                        Text {
                            text: qsTr("Klemmenreihen")
                            font.pixelSize: 13
                            color: root.aktiveSpezialAnsicht === "klemmenreihen"
                                   ? theme.textPrimary : theme.textSecondary
                            Layout.fillWidth: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked:   root.aktiveSpezialAnsicht = "klemmenreihen"
                    }
                }

                // 🔷 Makros
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    color: root.aktiveSpezialAnsicht === "makros"
                           ? theme.hover : (mkHover.containsMouse ? theme.hover : "transparent")
                    HoverHandler { id: mkHover }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                        Text { text: "🔷"; font.pixelSize: 12 }
                        Text {
                            text: qsTr("Makros")
                            font.pixelSize: 13
                            color: root.aktiveSpezialAnsicht === "makros"
                                   ? theme.textPrimary : theme.textSecondary
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.makroListe.length > 0 ? "(" + root.makroListe.length + ")" : ""
                            color: theme.textMuted; font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.makroListeAktualisieren()
                            root.aktiveSpezialAnsicht = "makros"
                        }
                    }
                }

            }

            DebugLabel { panelName: qsTr("Kategoriebaum"); visible: root.debug }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: theme.border }

        // ---- Bauteil-Liste / Spezialansicht (rechts) -------
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.minimumWidth: 400

            ColumnLayout {
                anchors.fill: parent; spacing: 0
                visible: root.aktiveSpezialAnsicht === ""

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

                // ---- Suchleiste ----
                Rectangle {
                    Layout.fillWidth: true; height: 44; color: theme.surface
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 8
                        Text { text: "🔍"; font.pixelSize: 14; color: theme.textMuted }
                        TextField {
                            id: suchfeld
                            Layout.fillWidth: true
                            placeholderText: qsTr("Bezeichnung, Hersteller oder Artikel-Nr. suchen …")
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                            color: theme.textPrimary; font.pixelSize: 13
                            onTextChanged: bauteilModel.suchen(text)
                        }
                        Button {
                            visible: suchfeld.text.length > 0
                            text: "×"; flat: true; implicitWidth: 28; implicitHeight: 28
                            contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 16;
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? theme.hoverBtn : "transparent"; radius: 4 }
                            onClicked: { suchfeld.text = ""; bauteilModel.laden(bauteilModel.aktiveKategorieId) }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

                // ---- Spaltenkopf ----
                Rectangle {
                    Layout.fillWidth: true; height: 30; color: theme.sidebar
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                        spacing: 0
                        Text { text: qsTr("Typ");          color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 70;  font.weight: Font.Medium }
                        Text { text: qsTr("Bezeichnung");  color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 180; font.weight: Font.Medium }
                        Text { text: qsTr("Hersteller");   color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 130; font.weight: Font.Medium }
                        Text { text: qsTr("Artikel-Nr.");  color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 110; font.weight: Font.Medium }
                        Text { text: qsTr("Preis (\u20AC)"); color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 80;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }
                        Text { text: qsTr("U (V)");        color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 60;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }
                        Text { text: qsTr("I (A)");        color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 60;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }
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

                        Text {
                            anchors.centerIn: parent
                            visible: bauteilListe.count === 0
                            text: qsTr("Keine Bauteile \u2013 mit '+ Neu' anlegen.")
                            color: theme.borderDark; font.pixelSize: 14
                        }

                        delegate: Rectangle {
                            width: bauteilListe.width; height: 38
                            property bool isSelected: root.selectedBauteilId === model.bauteilId
                            color: isSelected ? theme.activeItemAlt
                                   : (bHover.containsMouse ? theme.hover
                                   : (index % 2 === 0 ? theme.tableEven : theme.tableOdd))

                            HoverHandler { id: bHover }
                            MouseArea {
                                anchors.fill: parent; z: -1
                                onClicked: {
                                    root.selectedBauteilId          = model.bauteilId
                                    root.selectedBauteilBezeichnung = model.bezeichnung
                                }
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                                spacing: 0

                                // Typ-Badge
                                Rectangle {
                                    Layout.preferredWidth: 70
                                    height: 20; radius: 3
                                    color:        model.istKlemme ? "#1a4a2a"
                                                : model.istKabel  ? "#1a3a4a" : "transparent"
                                    border.color: model.istKlemme ? "#2d7a4a"
                                                : model.istKabel  ? "#2d6a8a" : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text:  model.istKlemme ? qsTr("Klemme")
                                             : model.istKabel  ? qsTr("Kabel") : ""
                                        font.pixelSize: 10
                                        color: model.istKlemme ? "#5dba7d"
                                             : model.istKabel  ? "#5daacc" : "transparent"
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
                                Text { text: model.preisEur > 0 ? model.preisEur.toFixed(2) : "\u2013";
                                       font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                                Text { text: model.spannungV > 0 ? model.spannungV : "\u2013";
                                       font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                                Text { text: model.stromA > 0 ? model.stromA : "\u2013";
                                       font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }

                                Item { Layout.fillWidth: true }

                                Row {
                                    spacing: 4; visible: bHover.containsMouse
                                    Button {
                                        visible: model.istKlemme
                                        width: 24; height: 24; flat: true
                                        contentItem: Text { text: "⚙"; color: theme.accent; font.pixelSize: 13;
                                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                        ToolTip.visible: hovered; ToolTip.text: qsTr("Klemmen-Editor öffnen")
                                        onClicked: {
                                            root.selectedBauteilId            = model.bauteilId
                                            root.selectedBauteilBezeichnung   = model.bezeichnung
                                            root.selectedBauteilHersteller    = model.hersteller
                                            root.selectedBauteilArtikelnummer = model.artikelnummer
                                            root.klemmenEditorAngefordert(model.bauteilId, model.bezeichnung)
                                        }
                                    }
                                    Button {
                                        visible: model.istKabel
                                        width: 24; height: 24; flat: true
                                        contentItem: Text { text: "⚙"; color: theme.accent; font.pixelSize: 13;
                                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                        ToolTip.visible: hovered; ToolTip.text: qsTr("Kabel-Editor öffnen")
                                        onClicked: {
                                            root.selectedBauteilId            = model.bauteilId
                                            root.selectedBauteilBezeichnung   = model.bezeichnung
                                            root.selectedBauteilHersteller    = model.hersteller
                                            root.selectedBauteilArtikelnummer = model.artikelnummer
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
            DebugLabel {
                panelName: root.aktiveSpezialAnsicht === "" ? qsTr("Bauteil-Liste") : qsTr("Klemmenreihen-Ansicht")
                visible:   root.debug
            }

            KlemmenreihenAnsicht {
                anchors.fill: parent
                visible:      root.aktiveSpezialAnsicht === "klemmenreihen"
                theme:        root.theme
                debug:        root.debug
                projektId:    root.projektId

                onKlemmeAnschlussModusAPlatzieren: function(bauteilKlemmeId, anschlussBezeichnung, bmk, klemmeId) {
                    root.klemmeAnschlussModusAPlatzieren(bauteilKlemmeId, anschlussBezeichnung, bmk, klemmeId)
                }
            }

            // ── Makro-Listenansicht ─────────────────────────────────
            Item {
                anchors.fill: parent
                visible:      root.aktiveSpezialAnsicht === "makros"

                ColumnLayout {
                    anchors.fill: parent; spacing: 0

                    // Kopfzeile
                    Rectangle {
                        Layout.fillWidth: true; height: 40
                        color: theme.sidebar
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                            Text {
                                text: qsTr("Makros")
                                font.pixelSize: 13; font.weight: Font.Medium
                                color: theme.textPrimary; Layout.fillWidth: true
                            }
                            Button {
                                text: "✕"; flat: true; implicitWidth: 24; implicitHeight: 24
                                contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 13;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                                onClicked: root.aktiveSpezialAnsicht = ""
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                    // Makro-Liste
                    ListView {
                        id: makroListView
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        model: root.makroListe
                        delegate: Rectangle {
                            width: makroListView.width
                            height: 48
                            color: mkRowHover.containsMouse ? theme.hover : "transparent"
                            HoverHandler { id: mkRowHover }

                            ColumnLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                                spacing: 1
                                Text {
                                    text: modelData.name
                                    font.pixelSize: 12; font.weight: Font.Medium
                                    color: theme.textPrimary; Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: (modelData.kategorie ? modelData.kategorie + " · " : "")
                                          + modelData.elementAnzahl + " " + qsTr("Elemente")
                                    font.pixelSize: 10; color: theme.textMuted
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            // Einfügen-Button
                            Button {
                                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: qsTr("Einfügen")
                                implicitHeight: 26; implicitWidth: 70
                                visible: mkRowHover.hovered
                                contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 11;
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle {
                                    color: parent.hovered ? theme.accent : theme.inputBg
                                    radius: 4; border.color: theme.accent
                                }
                                onClicked: root.makroEinfuegenAngefordert(modelData.id, modelData.name)
                            }

                            Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: 1; color: theme.border; opacity: 0.4 }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.makroListe.length === 0
                            text: qsTr("Keine Makros gespeichert.\nMakrokasten zeichnen (M),\nbenennen – fertig.")
                            color: theme.textMuted; font.pixelSize: 11; font.italic: true
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            width: parent.width - 24
                        }
                    }
                }
            }
        }

    }

    DebugLabel { panelName: qsTr("Bauteile-Ansicht"); visible: root.debug }
}
