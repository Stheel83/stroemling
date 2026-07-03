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
    signal steckverbinderEditorAngefordert(int bauteilId, string bezeichnung)
    signal konfkabelEditorAngefordert(int bauteilId, string bezeichnung)

    BaKategorieNeuDialog        { id: dlgKategorieNeu;        theme: root.theme }
    BaKategorieBearbeitenDialog { id: dlgKategorieBearbeiten; theme: root.theme }
    BaBauteilNeuDialog          { id: dlgBauteilNeu;          theme: root.theme }
    BaCsvImportDialog           { id: dlgCsvImport;           theme: root.theme }

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
            property bool sel: panel.aktiveSpezialAnsicht === "" && !bauteilModel.nurKlemmen && !bauteilModel.nurKabel && !bauteilModel.nurSteckverbinder
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
                    contentItem: Text { text: "⇩"; color: theme.textMuted; font.pixelSize: 13;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                    ToolTip.visible: hovered; ToolTip.delay: 700; ToolTip.text: qsTr("CSV importieren")
                    onClicked: dlgCsvImport.open()
                }
                Button {
                    visible: baulibH.hovered; width: 22; height: 22; flat: true
                    contentItem: Text { text: "+"; color: theme.accent; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                    onClicked: { dlgBauteilNeu.kategorieId = bauteilModel.aktiveKategorieId; dlgBauteilNeu.open() }
                }
            }
            MouseArea { anchors.fill: parent; z: -1; onClicked: {
                bauteilModel.setNurKlemmen(false); bauteilModel.setNurKabel(false); bauteilModel.setNurSteckverbinder(false)
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
                bauteilModel.setNurKlemmen(true); bauteilModel.setNurKabel(false); bauteilModel.setNurSteckverbinder(false)
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
                bauteilModel.setNurKlemmen(false); bauteilModel.setNurKabel(true); bauteilModel.setNurSteckverbinder(false)
                bauteilModel.laden(-1); panel.aktiveSpezialAnsicht = ""
            }}
        }

        // Steckverbinder
        Rectangle {
            Layout.fillWidth: true; height: 36
            property bool sel: panel.aktiveSpezialAnsicht === "" && bauteilModel.nurSteckverbinder
            color: sel ? theme.hover : (svlibH.hovered ? theme.hover : "transparent")
            HoverHandler { id: svlibH }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                spacing: 6
                Text { text: "🔌"; font.pixelSize: 12 }
                Text { text: qsTr("Steckverbinder"); font.pixelSize: 13; Layout.fillWidth: true
                       color: parent.parent.sel ? theme.textPrimary : theme.textSecondary }
                Button {
                    visible: svlibH.hovered; width: 22; height: 22; flat: true
                    contentItem: Text { text: "+"; color: theme.accent; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                    onClicked: {
                        var newId = bauteilModel.anlegen(-1, qsTr("Neuer Steckverbinder"), "", "", "", 0, 0, 0, 0, "")
                        if (newId > 0) {
                            db.steckverbinderTypSpeichern(newId, 0, "", "", "", "", false, false)
                            bauteilModel.setNurSteckverbinder(true)
                            bauteilModel.setNurKlemmen(false)
                            bauteilModel.setNurKabel(false)
                            bauteilModel.laden(-1)
                            panel.selectedBauteilId            = newId
                            panel.selectedBauteilBezeichnung   = qsTr("Neuer Steckverbinder")
                            panel.selectedBauteilHersteller    = ""
                            panel.selectedBauteilArtikelnummer = ""
                            panel.aktiveSpezialAnsicht = ""
                            root.steckverbinderEditorAngefordert(newId, qsTr("Neuer Steckverbinder"))
                        }
                    }
                }
            }
            MouseArea { anchors.fill: parent; z: -1; onClicked: {
                bauteilModel.setNurSteckverbinder(true)
                bauteilModel.setNurKlemmen(false)
                bauteilModel.setNurKabel(false)
                bauteilModel.laden(-1); panel.aktiveSpezialAnsicht = ""
            }}
        }

        // Konfektionierte Kabel
        Rectangle {
            Layout.fillWidth: true; height: 36
            property bool sel: panel.aktiveSpezialAnsicht === "" && bauteilModel.nurKonfkabel
            color: sel ? theme.hover : (kkH.hovered ? theme.hover : "transparent")
            HoverHandler { id: kkH }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                spacing: 6
                Text { text: "🔗"; font.pixelSize: 12 }
                Text { text: qsTr("Konf. Kabel"); font.pixelSize: 13; Layout.fillWidth: true
                       color: parent.parent.sel ? theme.textPrimary : theme.textSecondary }
                Button {
                    visible: kkH.hovered; width: 22; height: 22; flat: true
                    contentItem: Text { text: "+"; color: theme.accent; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                    onClicked: {
                        var newId = bauteilModel.anlegen(-1, qsTr("Neues konf. Kabel"), "", "", "", 0, 0, 0, 0, "")
                        if (newId > 0) {
                            db.konfkabelSpeichern(newId, -1, 0, -1, -1)
                            bauteilModel.setNurKonfkabel(true)
                            bauteilModel.setNurKlemmen(false)
                            bauteilModel.setNurKabel(false)
                            bauteilModel.setNurSteckverbinder(false)
                            bauteilModel.laden(-1)
                            panel.selectedBauteilId          = newId
                            panel.selectedBauteilBezeichnung = qsTr("Neues konf. Kabel")
                            panel.aktiveSpezialAnsicht       = ""
                            root.konfkabelEditorAngefordert(newId, qsTr("Neues konf. Kabel"))
                        }
                    }
                }
            }
            MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    bauteilModel.setNurKonfkabel(true)
                    bauteilModel.setNurKlemmen(false)
                    bauteilModel.setNurKabel(false)
                    bauteilModel.setNurSteckverbinder(false)
                    bauteilModel.laden(-1)
                    panel.aktiveSpezialAnsicht = ""
                }
            }
        }

        // Makros
        Rectangle {
            Layout.fillWidth: true; height: 36
            property bool sel: panel.aktiveSpezialAnsicht === "makros"
            color: sel ? theme.hover : (makrolibH.hovered ? theme.hover : "transparent")
            HoverHandler { id: makrolibH }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 4 }
                spacing: 6
                Text { text: "📎"; font.pixelSize: 12 }
                Text { text: qsTr("Makros"); font.pixelSize: 13; Layout.fillWidth: true
                       color: parent.parent.sel ? theme.textPrimary : theme.textSecondary }
            }
            MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor
                onClicked: panel.aktiveSpezialAnsicht = "makros" }
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

        // ── PROJEKT ─────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 2 }
        Text {
            text: qsTr("PROJEKT")
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
            color: panel.aktiveSpezialAnsicht === "geraetekaesten"
                   ? theme.hover : (gkHover.containsMouse ? theme.hover : "transparent")
            HoverHandler { id: gkHover }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                Text { text: "📐"; font.pixelSize: 12 }
                Text {
                    text: qsTr("Gerätekästen"); font.pixelSize: 13
                    color: panel.aktiveSpezialAnsicht === "geraetekaesten"
                           ? theme.textPrimary : theme.textSecondary
                    Layout.fillWidth: true
                }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: panel.aktiveSpezialAnsicht = "geraetekaesten"
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
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
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
    }

    DebugLabel { panelName: qsTr("Kategoriebaum"); visible: panel.debug }
}
