import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling

Item {
    id: root
    required property var panel
    required property var theme

    // BAUTEILLISTE-KONTEXTSPALTEN-01: bestimmt, welcher Satz an Fachspalten
    // in Kopf- und Datenzeile gezeigt wird. "alle" (kein Filter aktiv) zeigt
    // weiterhin nur die generischen Spalten, da Zeilen dort gemischten Typs
    // sind – Fachspalten wären dort größtenteils leer/uneinheitlich.
    readonly property string _kontext:
        bauteilModel.nurKlemmen        ? "klemme"
      : bauteilModel.nurKabel          ? "kabel"
      : bauteilModel.nurSteckverbinder ? "steckverbinder"
      : bauteilModel.nurKontakt        ? "kontakt"
      : bauteilModel.nurKonfkabel      ? "konfkabel"
      : "alle"

    signal klemmenEditorAngefordert(int bauteilId, string bezeichnung)
    signal kabelEditorAngefordert(int bauteilId, string bezeichnung)
    signal steckverbinderEditorAngefordert(int bauteilId, string bezeichnung)
    signal konfkabelEditorAngefordert(int bauteilId, string bezeichnung)
    signal kontaktEditorAngefordert(int bauteilId, string bezeichnung)

    // ── Dialog – Neues Bauteil (in aktiver Kategorie) ─────────
    BaBauteilNeuDialog {
        id: dlgBauteilNeu
        theme: root.theme
    }

    // ── Dialog – Bauteil bearbeiten (QML-REFACTOR-06: ausgelagert) ──
    BaBauteilBearbeitenDialog {
        id: dlgBauteilBearbeiten
        theme: root.theme
    }

    // ── Bauteil-Liste ────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent; spacing: 0

        Rectangle {
            Layout.fillWidth: true; height: 52; color: theme.surface
            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                Text {
                    text: bauteilModel.nurKlemmen       ? qsTr("Klemmen")
                        : bauteilModel.nurKabel          ? qsTr("Kabel")
                        : bauteilModel.nurSteckverbinder ? qsTr("Steckverbinder")
                        : bauteilModel.nurKonfkabel      ? qsTr("Konf. Kabel")
                        : bauteilModel.nurKontakt        ? qsTr("Kontakte")
                        : qsTr("Alle Bauteile")
                    font.pixelSize: 15; font.weight: Font.Medium; color: theme.textPrimary
                    Layout.fillWidth: true
                }
                Button {
                    visible: !bauteilModel.nurKlemmen && !bauteilModel.nurKabel
                             && !bauteilModel.nurSteckverbinder && !bauteilModel.nurKonfkabel
                             && !bauteilModel.nurKontakt
                    text: qsTr("+ Neu"); implicitHeight: 30
                    contentItem: Text { text: parent.text; color: theme.accent; font.pixelSize: 12;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.accent }
                    onClicked: {
                        dlgBauteilNeu.kategorieId = bauteilModel.aktiveKategorieId
                        dlgBauteilNeu.open()
                    }
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
                Text { visible: root._kontext === "alle"; text: qsTr("Typ"); color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 70;  font.weight: Font.Medium }
                Item { visible: root._kontext !== "alle"; Layout.preferredWidth: 70 }
                // Symbol-Badge-Spalte (nur "alle") – muss in derselben Reihenfolge wie in
                // der Datenzeile stehen (dort: Typ → Symbol-Badge → 🔒-Icon → Bezeichnung),
                // sonst passt nur die Gesamtbreite, nicht aber wo Bezeichnung beginnt.
                Text { visible: root._kontext === "alle"; text: qsTr("Symbol"); color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 70; font.weight: Font.Medium }
                // Platz für die 🔒-Icon-Spalte in der Datenzeile (mitgeliefertes Bauteil)
                Item { Layout.preferredWidth: 14 }
                Text { text: qsTr("Bezeichnung");    color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 180; font.weight: Font.Medium }
                Text { text: qsTr("Hersteller");     color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 130; font.weight: Font.Medium }
                Text { text: qsTr("Artikel-Nr.");    color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 110; font.weight: Font.Medium }

                // ── Kontextabhängige Fachspalten (BAUTEILLISTE-KONTEXTSPALTEN-01) ──
                Text { visible: root._kontext === "klemme"; text: qsTr("Anschluss");  color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 90;  font.weight: Font.Medium }
                Text { visible: root._kontext === "klemme"; text: qsTr("Ebenen");     color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 60;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight; rightPadding: 12 }
                Text { visible: root._kontext === "klemme"; text: qsTr("Gehäuse");    color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 110; font.weight: Font.Medium }

                Text { visible: root._kontext === "kabel"; text: qsTr("Kabeltyp");     color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 120; font.weight: Font.Medium }
                Text { visible: root._kontext === "kabel"; text: qsTr("Außenmantel");  color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 90;  font.weight: Font.Medium }
                Text { visible: root._kontext === "kabel"; text: qsTr("Adern");        color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 50;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }

                Text { visible: root._kontext === "steckverbinder"; text: qsTr("Ausführung"); color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 130; font.weight: Font.Medium }
                Text { visible: root._kontext === "steckverbinder"; text: qsTr("Pol");        color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 50;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }

                Text { visible: root._kontext === "kontakt"; text: qsTr("Geschlecht");         color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 70;  font.weight: Font.Medium }
                Text { visible: root._kontext === "kontakt"; text: qsTr("Größe (mm²)");        color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 80;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }
                Text { visible: root._kontext === "kontakt"; text: qsTr("Verbindung");         color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 100; font.weight: Font.Medium }

                Text { visible: root._kontext === "konfkabel"; text: qsTr("Kabeltyp"); color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 120; font.weight: Font.Medium }
                Text { visible: root._kontext === "konfkabel"; text: qsTr("Länge (m)");color: theme.borderLight; font.pixelSize: 11; Layout.preferredWidth: 70;  font.weight: Font.Medium; horizontalAlignment: Text.AlignRight }

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
                        visible:  bauteilModel.nurKabel && suchfeld.text.length === 0
                        source:   "qrc:/assets/kabeljau_uebersicht.png"
                        width:    560; height: 560
                        fillMode: Image.PreserveAspectFit
                        smooth:   true; mipmap: true
                    }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:  !(bauteilModel.nurKabel && suchfeld.text.length === 0)
                        source:   "qrc:/assets/pokestroem_cee.png"
                        width:    560; height: 560
                        fillMode: Image.PreserveAspectFit
                        smooth:   true; mipmap: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: suchfeld.text.length > 0
                              ? qsTr("Keine Ergebnisse für \"%1\"").arg(suchfeld.text)
                              : bauteilModel.nurKabel
                                ? qsTr("Noch keine Kabel – mit '+ Neu' anlegen.")
                                : bauteilModel.nurSteckverbinder
                                  ? qsTr("Noch keine Steckverbinder – mit '+ Neu' anlegen.")
                                  : bauteilModel.nurKonfkabel
                                    ? qsTr("Noch keine konfektionierten Kabel – mit '+ Neu' anlegen.")
                                    : bauteilModel.nurKontakt
                                      ? qsTr("Noch keine Kontakte – mit '+ Neu' anlegen.")
                                      : qsTr("Noch keine Bauteile – mit '+ Neu' anlegen.")
                        color:          theme.textMuted
                        font.pixelSize: 13
                    }
                }

                delegate: Rectangle {
                    width: bauteilListe.width; height: 38
                    property bool isSelected: panel.selectedBauteilId === model.bauteilId
                    color: isSelected ? theme.activeItemAlt
                           : (rowHover.hovered ? theme.hover
                           : (index % 2 === 0 ? theme.tableEven : theme.tableOdd))
                    // ONBOARDING-KETTEN-01: reiner Entwicklungs-Merker, kein Nutzer-Feature
                    // (analog markiertLoeschen im Symboleditor) – bleibt auch ohne Hover sichtbar.
                    border.width: model.fuerSeedVormerken ? 1 : 0
                    border.color: "#4caf7d"

                    // Eigener HoverHandler statt bMa.containsMouse für alle visuellen
                    // Zustände (Zeilenfarbe, Aktions-Buttons einblenden) – ZEILE-FLACKERN-01:
                    // eine MouseArea, die von Buttons/Icons darüber optisch überdeckt wird,
                    // verliert dort containsMouse (Occlusion), was Row.visible/Farbe im
                    // selben Frame kippen ließ → Button verschwindet → MouseArea bekommt
                    // Hover zurück → Button erscheint wieder → Endlosschleife = Flackern.
                    // HoverHandler ist nicht-exklusiv und bleibt auch unter Geschwister-
                    // Items mit eigenem Hover stabil.
                    HoverHandler { id: rowHover }

                    MouseArea {
                        id: bMa
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
                            visible: root._kontext === "alle"
                            Layout.preferredWidth: 70; height: 20; radius: 3
                            color: model.istKlemme ? "#1a4a2a"
                                 : model.istKabel  ? "#1a3a4a"
                                 : model.istSteckverbinder ? "#2a1a4a"
                                 : model.istKontakt ? "#4a3a1a"
                                 : "transparent"
                            border.color: model.istKlemme ? "#2d7a4a"
                                        : model.istKabel  ? "#2d6a8a"
                                        : model.istSteckverbinder ? "#6a3a9a"
                                        : model.istKontakt ? "#8a6a2d"
                                        : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: model.istKlemme ? qsTr("Klemme")
                                    : model.istKabel  ? qsTr("Kabel")
                                    : model.istSteckverbinder ? qsTr("Stecker")
                                    : model.istKontakt ? qsTr("Kontakt")
                                    : ""
                                font.pixelSize: 10
                                color: model.istKlemme ? "#5dba7d"
                                     : model.istKabel  ? "#5daacc"
                                     : model.istSteckverbinder ? "#aa7ddd"
                                     : model.istKontakt ? "#ddaa5d"
                                     : "transparent"
                            }
                        }
                        Item { visible: root._kontext !== "alle"; Layout.preferredWidth: 70 }

                        // Symbol-Badge für generische Bauteile mit direktem Symbolverweis
                        // (z.B. einfache Geräte) – nur relevant in der ungefilterten Ansicht,
                        // da typisierte Bauteile (Klemme/Kabel/Steckverbinder) dieses Feld
                        // praktisch nie gesetzt haben. Kein eigener Spaltenkopf vorhanden
                        // (auch schon vor BAUTEILLISTE-KONTEXTSPALTEN-01 so) – Badge und
                        // Platzhalter reservieren deshalb nur innerhalb von "alle" Platz,
                        // sonst käme wieder eine Spaltenverschiebung wie bei ZEILE-FLACKERN-
                        // benachbarten Funden zustande (Kopf- und Datenzeile müssen exakt
                        // dieselbe Breite reservieren).
                        Rectangle {
                            visible: root._kontext === "alle" && !model.istKlemme && !model.istKabel && !model.istSteckverbinder && (model.hauptfunktionSymbolId || "") !== ""
                            Layout.preferredWidth: 70; height: 20; radius: 3
                            color: "#1a2a4a"; border.color: "#2d5a8a"
                            Text {
                                anchors.centerIn: parent
                                text: model.hauptfunktionSymbolId || ""
                                font.pixelSize: 10; color: "#7db8e8"; elide: Text.ElideRight
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        Item {
                            visible: root._kontext === "alle" && !(!model.istKlemme && !model.istKabel && !model.istSteckverbinder && (model.hauptfunktionSymbolId || "") !== "")
                            Layout.preferredWidth: 70
                        }

                        Text {
                            text: "🔒"; visible: model.istSystem; font.pixelSize: 10
                            ToolTip.visible: lockMa.containsMouse; ToolTip.delay: 400
                            ToolTip.text: qsTr("Mitgeliefertes Bauteil")
                            Layout.preferredWidth: 14
                            MouseArea { id: lockMa; anchors.fill: parent; hoverEnabled: true }
                        }
                        Item { visible: !model.istSystem; Layout.preferredWidth: 14 }
                        Text { text: model.bezeichnung;   font.pixelSize: 13; color: theme.textSecondary; Layout.preferredWidth: 180; elide: Text.ElideRight }
                        Text { text: model.hersteller;    font.pixelSize: 13; color: theme.textMuted;      Layout.preferredWidth: 130; elide: Text.ElideRight }
                        Text { text: model.artikelnummer; font.pixelSize: 13; color: theme.textMuted;      Layout.preferredWidth: 110; elide: Text.ElideRight }
                        // ── Kontextabhängige Fachspalten (BAUTEILLISTE-KONTEXTSPALTEN-01) ──
                        // Klemme: Anschlusstyp, Ebenen, Gehäusefarbe (Swatch + Name)
                        Text {
                            visible: root._kontext === "klemme"
                            text: model.anschlussTyp || "–"
                            font.pixelSize: 11; color: theme.textSecondary
                            Layout.preferredWidth: 90; elide: Text.ElideRight
                        }
                        Text {
                            visible: root._kontext === "klemme"
                            text: model.ebenenAnzahl > 0 ? model.ebenenAnzahl : "–"
                            font.pixelSize: 11; color: theme.textMuted
                            Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight; rightPadding: 12
                        }
                        RowLayout {
                            visible: root._kontext === "klemme"
                            Layout.preferredWidth: 110; spacing: 4
                            Rectangle {
                                visible: (model.gehaeuseFarbeHex || "") !== ""
                                width: 10; height: 14; radius: 2
                                color: model.gehaeuseFarbeHex || "transparent"
                                border.color: theme.border; border.width: 1
                            }
                            Text {
                                Layout.fillWidth: true
                                text: model.gehaeuseFarbeBezeichnung || "–"
                                font.pixelSize: 11; color: theme.textMuted; elide: Text.ElideRight
                            }
                        }

                        // Kabel: Kabeltyp, Außenmantelfarbe, Adernzahl
                        Text {
                            visible: root._kontext === "kabel"
                            text: model.kabeltyp || "–"
                            font.pixelSize: 11; color: theme.accent
                            Layout.preferredWidth: 120; elide: Text.ElideRight
                        }
                        Text {
                            visible: root._kontext === "kabel"
                            text: model.aussenmantelFarbe || "–"
                            font.pixelSize: 11; color: theme.textMuted
                            Layout.preferredWidth: 90; elide: Text.ElideRight
                        }
                        Text {
                            visible: root._kontext === "kabel"
                            text: model.aderAnzahl > 0 ? model.aderAnzahl : "–"
                            font.pixelSize: 11; color: theme.textMuted
                            Layout.preferredWidth: 50; horizontalAlignment: Text.AlignRight
                        }

                        // Steckverbinder: Ausführung (Geschlecht + Montage), Polzahl
                        Text {
                            visible: root._kontext === "steckverbinder"
                            text: {
                                var teile = (model.montageform || "").split("_")
                                var montage    = teile[0] === "einbau" ? qsTr("Einbau") : teile[0] === "frei" ? qsTr("Frei") : ""
                                var geschlecht = teile[1] === "stecker" ? qsTr("Stecker") : teile[1] === "buchse" ? qsTr("Buchse") : ""
                                return (montage || geschlecht) ? [montage, geschlecht].filter(function(s){return s}).join(", ") : "–"
                            }
                            font.pixelSize: 11; color: theme.textSecondary
                            Layout.preferredWidth: 130; elide: Text.ElideRight
                        }
                        Text {
                            visible: root._kontext === "steckverbinder"
                            text: model.polzahl > 0 ? model.polzahl : "–"
                            font.pixelSize: 11; color: theme.textMuted
                            Layout.preferredWidth: 50; horizontalAlignment: Text.AlignRight
                        }

                        // Kontakt: Geschlecht, Kontaktgröße, Verbindungstechnik
                        Text {
                            visible: root._kontext === "kontakt"
                            text: model.geschlecht === "stift" ? qsTr("Stift") : model.geschlecht === "buchse" ? qsTr("Buchse") : "–"
                            font.pixelSize: 11; color: theme.textSecondary
                            Layout.preferredWidth: 70; elide: Text.ElideRight
                        }
                        Text {
                            visible: root._kontext === "kontakt"
                            text: model.kontaktgroesse > 0 ? model.kontaktgroesse : "–"
                            font.pixelSize: 11; color: theme.textMuted
                            Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            visible: root._kontext === "kontakt"
                            text: model.verbindungstechnik || "–"
                            font.pixelSize: 11; color: theme.textMuted
                            Layout.preferredWidth: 100; elide: Text.ElideRight
                        }

                        // Konf. Kabel: referenzierter Kabeltyp, Länge
                        Text {
                            visible: root._kontext === "konfkabel"
                            text: model.konfkabelKabeltyp || "–"
                            font.pixelSize: 11; color: theme.accent
                            Layout.preferredWidth: 120; elide: Text.ElideRight
                        }
                        Text {
                            visible: root._kontext === "konfkabel"
                            text: model.laengeM > 0 ? model.laengeM : "–"
                            font.pixelSize: 11; color: theme.textMuted
                            Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight
                        }

                        Text { text: model.preisEur > 0 ? model.preisEur.toFixed(2) : "–";
                               font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight }
                        Text { text: model.spannungV > 0 ? model.spannungV : "–";
                               font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                        Text { text: model.stromA > 0 ? model.stromA : "–";
                               font.pixelSize: 13; color: theme.textMuted; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }

                        Item { Layout.fillWidth: true }

                        // ONBOARDING-KETTEN-01: "Für Bauteil-Seed vormerken" — reiner
                        // Entwicklungs-Merker (analog markiertLoeschen im Symboleditor),
                        // kein Nutzer-Feature. Bleibt bei aktiver Vormerkung auch ohne
                        // Hover sichtbar, damit die Liste durchscrollbar bleibt.
                        Button {
                            width: 24; height: 24; flat: true
                            visible: rowHover.hovered || model.fuerSeedVormerken
                            contentItem: Text {
                                text: "🌱"; font.pixelSize: 13
                                color: model.fuerSeedVormerken ? "#4caf7d" : theme.textMuted
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                            ToolTip.visible: hovered; ToolTip.delay: 400
                            ToolTip.text: model.fuerSeedVormerken
                                ? qsTr("Vormerkung für Bauteil-Seed aufheben")
                                : qsTr("Für Bauteil-Seed vormerken (Entwicklungswerkzeug)")
                            onClicked: bauteilModel.fuerSeedUmschalten(model.bauteilId)
                        }

                        Row {
                            spacing: 4; visible: rowHover.hovered
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
                                visible: model.istSteckverbinder; width: 24; height: 24; flat: true
                                contentItem: Text { text: "⚙"; color: theme.accent; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Steckverbinder-Editor öffnen")
                                onClicked: {
                                    panel.selectedBauteilId            = model.bauteilId
                                    panel.selectedBauteilBezeichnung   = model.bezeichnung
                                    panel.selectedBauteilHersteller    = model.hersteller
                                    panel.selectedBauteilArtikelnummer = model.artikelnummer
                                    root.steckverbinderEditorAngefordert(model.bauteilId, model.bezeichnung)
                                }
                            }
                            Button {
                                visible: model.istKonfkabel; width: 24; height: 24; flat: true
                                contentItem: Text { text: "⚙"; color: theme.accent; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Konfektioniertes Kabel – Editor öffnen")
                                onClicked: {
                                    panel.selectedBauteilId            = model.bauteilId
                                    panel.selectedBauteilBezeichnung   = model.bezeichnung
                                    panel.selectedBauteilHersteller    = model.hersteller
                                    panel.selectedBauteilArtikelnummer = model.artikelnummer
                                    root.konfkabelEditorAngefordert(model.bauteilId, model.bezeichnung)
                                }
                            }
                            Button {
                                visible: model.istKontakt; width: 24; height: 24; flat: true
                                contentItem: Text { text: "⚙"; color: theme.accent; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.text: qsTr("Kontakt-Editor öffnen")
                                onClicked: {
                                    panel.selectedBauteilId            = model.bauteilId
                                    panel.selectedBauteilBezeichnung   = model.bezeichnung
                                    panel.selectedBauteilHersteller    = model.hersteller
                                    panel.selectedBauteilArtikelnummer = model.artikelnummer
                                    root.kontaktEditorAngefordert(model.bauteilId, model.bezeichnung)
                                }
                            }
                            Button {
                                visible: !model.istKlemme && !model.istKabel && !model.istSteckverbinder && !model.istKonfkabel && !model.istKontakt
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "✎"; color: theme.accent; font.pixelSize: 14;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                onClicked: {
                                    dlgBauteilBearbeiten.itemId           = model.bauteilId
                                    dlgBauteilBearbeiten.altBezeichnung   = model.bezeichnung
                                    dlgBauteilBearbeiten.altBmkVorlage    = model.bmkVorlage
                                    dlgBauteilBearbeiten.altHersteller    = model.hersteller
                                    dlgBauteilBearbeiten.altArtikelnummer = model.artikelnummer
                                    dlgBauteilBearbeiten.altLieferant     = model.lieferant
                                    dlgBauteilBearbeiten.altPreis         = model.preisEur
                                    dlgBauteilBearbeiten.altSpannung      = model.spannungV
                                    dlgBauteilBearbeiten.altStrom         = model.stromA
                                    dlgBauteilBearbeiten.altLeistung      = model.leistungW
                                    dlgBauteilBearbeiten.altBemerkung     = model.bemerkung
                                    dlgBauteilBearbeiten.altUrlHersteller = model.urlHersteller
                                    dlgBauteilBearbeiten.altUrlDatenblatt = model.urlDatenblatt
                                    dlgBauteilBearbeiten.altSymbolId      = model.hauptfunktionSymbolId || ""
                                    dlgBauteilBearbeiten.altIstSystem     = model.istSystem
                                    dlgBauteilBearbeiten.open()
                                }
                            }
                            Button {
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "❐"; color: theme.textMuted; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.delay: 700; ToolTip.text: qsTr("Kopieren")
                                onClicked: {
                                    var newId = bauteilModel.duplizieren(model.bauteilId)
                                    if (newId > 0) {
                                        panel.selectedBauteilId            = newId
                                        panel.selectedBauteilBezeichnung   = model.bezeichnung + qsTr(" (Kopie)")
                                        panel.selectedBauteilHersteller    = model.hersteller
                                        panel.selectedBauteilArtikelnummer = model.artikelnummer
                                        if (model.istKlemme)
                                            root.klemmenEditorAngefordert(newId, model.bezeichnung + qsTr(" (Kopie)"))
                                        else if (model.istKabel)
                                            root.kabelEditorAngefordert(newId, model.bezeichnung + qsTr(" (Kopie)"))
                                        else if (model.istSteckverbinder)
                                            root.steckverbinderEditorAngefordert(newId, model.bezeichnung + qsTr(" (Kopie)"))
                                        else if (model.istKonfkabel)
                                            root.konfkabelEditorAngefordert(newId, model.bezeichnung + qsTr(" (Kopie)"))
                                        else if (model.istKontakt)
                                            root.kontaktEditorAngefordert(newId, model.bezeichnung + qsTr(" (Kopie)"))
                                    }
                                }
                            }
                            Button {
                                width: 24; height: 24; flat: true
                                contentItem: Text { text: "×"; color: "#aa4444"; font.pixelSize: 16;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 4 }
                                ToolTip.visible: hovered; ToolTip.delay: 700; ToolTip.text: qsTr("Löschen")
                                onClicked: bauteilModel.loeschen(model.bauteilId)
                            }
                        }
                    }
                }
            }
        }
    }
}
