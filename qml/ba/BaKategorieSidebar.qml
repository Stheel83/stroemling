import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling

Rectangle {
    id: root
    required property var panel
    required property var theme
    color: theme.sidebar

    signal klemmenEditorAngefordert(int bauteilId, string bezeichnung)
    signal kabelEditorAngefordert(int bauteilId, string bezeichnung)

    // ── Dialog – Neue Kategorie ──────────────────────────────
    Dialog {
        id: dlgKategorieNeu
        title: qsTr("Neue Kategorie")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: 340; padding: 20
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

    // ── Dialog – Kategorie bearbeiten ────────────────────────
    Dialog {
        id: dlgKategorieBearbeiten
        title: qsTr("Kategorie bearbeiten")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: 340; padding: 20
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

    // ── Dialog – Neues Bauteil ───────────────────────────────
    Dialog {
        id: dlgBauteilNeu
        title: qsTr("Neues Bauteil")
        modal: true; parent: Overlay.overlay; anchors.centerIn: parent
        width: 480; padding: 20
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
            Text { text: dlgBauteilNeu.title; font.pixelSize: 15; font.weight: Font.Medium;
                   color: theme.textPrimary; Layout.bottomMargin: 2 }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.bottomMargin: 8 }
            ScrollView {
                Layout.fillWidth: true
                height: Math.min(neuForm.implicitHeight + 16, 460)
                clip: true
                BaFormContent { id: neuForm; theme: theme }
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

    // ── Kategoriebaum ────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ── BIBLIOTHEK ──────────────────────────────────────────
        Text {
            text: qsTr("BIBLIOTHEK")
            font.pixelSize: 9; font.weight: Font.Medium; color: theme.textMuted
            leftPadding: 16; Layout.fillWidth: true
            Layout.topMargin: 8; Layout.bottomMargin: 2
        }

        // Bauteile
        Rectangle {
            Layout.fillWidth: true; height: 36
            property bool sel: panel.aktiveSpezialAnsicht === "" && !bauteilModel.nurKlemmen && !bauteilModel.nurKabel
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
                bauteilModel.laden(-1); panel.aktiveSpezialAnsicht = ""
            }}
        }

        // Klemmen
        Rectangle {
            Layout.fillWidth: true; height: 36
            property bool sel: panel.aktiveSpezialAnsicht === "" && bauteilModel.nurKlemmen
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
                            panel.selectedBauteilId            = newId
                            panel.selectedBauteilBezeichnung   = qsTr("Neue Klemme")
                            panel.selectedBauteilHersteller    = ""
                            panel.selectedBauteilArtikelnummer = ""
                            panel.aktiveSpezialAnsicht = ""
                            root.klemmenEditorAngefordert(newId, qsTr("Neue Klemme"))
                        }
                    }
                }
            }
            MouseArea { anchors.fill: parent; z: -1; onClicked: {
                bauteilModel.setNurKlemmen(true); bauteilModel.setNurKabel(false)
                bauteilModel.laden(-1); panel.aktiveSpezialAnsicht = ""
            }}
        }

        // Kabel
        Rectangle {
            Layout.fillWidth: true; height: 36
            property bool sel: panel.aktiveSpezialAnsicht === "" && bauteilModel.nurKabel
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
                            panel.selectedBauteilId            = newId
                            panel.selectedBauteilBezeichnung   = qsTr("Neues Kabel")
                            panel.selectedBauteilHersteller    = ""
                            panel.selectedBauteilArtikelnummer = ""
                            panel.aktiveSpezialAnsicht = ""
                            root.kabelEditorAngefordert(newId, qsTr("Neues Kabel"))
                        }
                    }
                }
            }
            MouseArea { anchors.fill: parent; z: -1; onClicked: {
                bauteilModel.setNurKlemmen(false); bauteilModel.setNurKabel(true)
                bauteilModel.laden(-1); panel.aktiveSpezialAnsicht = ""
            }}
        }

        // Geräte (Platzhalter)
        Rectangle {
            Layout.fillWidth: true; height: 36; color: "transparent"
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                spacing: 6
                Text { text: "⚡"; font.pixelSize: 12; opacity: 0.4 }
                Text { text: qsTr("Geräte"); font.pixelSize: 13; color: theme.textMuted; opacity: 0.6; Layout.fillWidth: true }
                Text { text: qsTr("(später)"); font.pixelSize: 10; color: theme.textMuted; opacity: 0.5 }
            }
        }

        // ── KATEGORIEN ──────────────────────────────────────────
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

                    MouseArea {
                        anchors.fill: parent; z: -1
                        onClicked: { bauteilModel.laden(model.kategorieId); panel.aktiveSpezialAnsicht = "" }
                    }
                }
            }
        }

        // ── ZUSAMMENSTELLUNGEN ──────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
        Text {
            text: qsTr("ZUSAMMENSTELLUNGEN")
            font.pixelSize: 9; font.weight: Font.Medium; color: theme.textMuted
            leftPadding: 16; Layout.fillWidth: true
            Layout.topMargin: 5; Layout.bottomMargin: 2
        }

        Rectangle {
            Layout.fillWidth: true; height: 36
            color: panel.aktiveSpezialAnsicht === "klemmenreihen"
                   ? theme.hover : (krHover.containsMouse ? theme.hover : "transparent")
            HoverHandler { id: krHover }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                Text { text: "🔌"; font.pixelSize: 12 }
                Text {
                    text: qsTr("Klemmenreihen"); font.pixelSize: 13
                    color: panel.aktiveSpezialAnsicht === "klemmenreihen"
                           ? theme.textPrimary : theme.textSecondary
                    Layout.fillWidth: true
                }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: panel.aktiveSpezialAnsicht = "klemmenreihen"
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 36
            color: panel.aktiveSpezialAnsicht === "makros"
                   ? theme.hover : (mkHover.containsMouse ? theme.hover : "transparent")
            HoverHandler { id: mkHover }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                Text { text: "🔷"; font.pixelSize: 12 }
                Text {
                    text: qsTr("Makros"); font.pixelSize: 13
                    color: panel.aktiveSpezialAnsicht === "makros"
                           ? theme.textPrimary : theme.textSecondary
                    Layout.fillWidth: true
                }
                Text {
                    text: panel.makroListe.length > 0 ? "(" + panel.makroListe.length + ")" : ""
                    color: theme.textMuted; font.pixelSize: 10
                }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    panel.makroListeAktualisieren()
                    panel.aktiveSpezialAnsicht = "makros"
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Kategoriebaum"); visible: panel.debug }
}
