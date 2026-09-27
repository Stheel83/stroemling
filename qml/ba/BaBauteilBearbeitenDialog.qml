import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// QML-REFACTOR-06: aus BaBauteilListe.qml ausgelagert (analog zum "Neu"-
// Dialog, der bei REFACTOR-QML-01-05 schon als eigene BaBauteilNeuDialog.qml
// existierte - der "Bearbeiten"-Dialog war der bis dahin vergessene Zwilling).
Dialog {
    id: root
    required property var theme

    title: qsTr("Bauteil bearbeiten")
    modal: true; parent: Overlay.overlay; anchors.centerIn: parent
    width: 480; padding: 20

    property int    itemId:           -1
    property string altBezeichnung:   ""
    property string altBmkVorlage:    ""
    property string altHersteller:    ""
    property string altArtikelnummer: ""
    property string altLieferant:     ""
    property real   altPreis:         0
    property real   altSpannung:      0
    property real   altStrom:         0
    property real   altLeistung:      0
    property string altBemerkung:     ""
    property string altUrlHersteller: ""
    property string altUrlDatenblatt: ""
    property string altSymbolId: ""
    property bool   altIstSystem:     false
    property var    _kontaktListe:    []

    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

    // ── Symbol-Picker (eigene Instanz, analog BaBauteilNeuDialog.qml) ──
    BaSymbolPickerDialog {
        id: symbolPicker
        theme: root.theme
        onAccepted: root.altSymbolId = ausgewaehltId
    }

    onOpened: {
        editForm.bezeichnung   = root.altBezeichnung
        editForm.bmkVorlage    = root.altBmkVorlage
        editForm.hersteller    = root.altHersteller
        editForm.artikelnummer = root.altArtikelnummer
        editForm.lieferant     = root.altLieferant
        editForm.preis         = root.altPreis    > 0 ? root.altPreis.toFixed(2)    : ""
        editForm.spannung      = root.altSpannung > 0 ? root.altSpannung.toString() : ""
        editForm.strom         = root.altStrom    > 0 ? root.altStrom.toString()    : ""
        editForm.leistung      = root.altLeistung > 0 ? root.altLeistung.toString() : ""
        editForm.bemerkung     = root.altBemerkung
        editForm.urlHersteller = root.altUrlHersteller
        editForm.urlDatenblatt = root.altUrlDatenblatt
        _kontaktListe          = db.bauteilKontaktListe(root.itemId)
    }

    contentItem: ColumnLayout {
        spacing: 0
        Text { text: root.title; font.pixelSize: 15; font.weight: Font.Medium;
               color: root.theme.textPrimary; Layout.bottomMargin: 2 }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.bottomMargin: 8 }

        // BAUTEIL-IST-SYSTEM-01: Warnhinweis statt Sperre — Bearbeiten bleibt
        // frei möglich, Änderungen wirken sich aber auf alle Projekte aus, die
        // dieses mitgelieferte Bauteil bereits verwenden (lebende Referenz).
        Rectangle {
            visible: root.altIstSystem
            Layout.fillWidth: true; Layout.bottomMargin: 8
            implicitHeight: sysWarnText.implicitHeight + 12
            radius: 4; color: "#3a2f10"; border.color: "#8a6a2d"
            Text {
                id: sysWarnText
                anchors { fill: parent; margins: 6 }
                text: qsTr("🔒 Mitgeliefertes Bauteil — Änderungen wirken sich auf alle Projekte aus, die es bereits verwenden.")
                font.pixelSize: 11; color: "#ddaa5d"; wrapMode: Text.WordWrap
            }
        }
        ScrollView {
            Layout.fillWidth: true
            height: Math.min(editForm.implicitHeight + 16, 460)
            clip: true
            BaFormContent { id: editForm; theme: root.theme }
        }

        ColumnLayout {
            Layout.fillWidth: true; Layout.topMargin: 4; spacing: 4
            Text { text: qsTr("Symbol (Hauptfunktion)"); color: root.theme.textMuted; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 34
                    color: root.theme.inputBg; border.color: root.theme.border; radius: 4
                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                        text: root.altSymbolId !== ""
                              ? root.altSymbolId
                              : qsTr("(kein Symbol)")
                        color: root.altSymbolId !== ""
                               ? root.theme.textPrimary : root.theme.textMuted
                        font.pixelSize: 13; font.italic: root.altSymbolId === ""
                    }
                }
                Button {
                    text: qsTr("Waehlen …"); implicitHeight: 34; implicitWidth: 90
                    contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 12;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg;
                        radius: 4; border.color: root.theme.accent }
                    onClicked: {
                        symbolPicker.aktuelleSymbolId = root.altSymbolId
                        symbolPicker.open()
                    }
                }
            }
        }

        // ── Kontaktbelegung (Schütz/Relais) ──────────────────────────────
        // Jede Zeile = ein Kontakt: Bezeichnung + Symbol + Pin-Zuordnung als "pin:label"-Paare
        ColumnLayout {
            Layout.fillWidth: true; Layout.topMargin: 12; spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Kontaktbelegung"); color: root.theme.accent; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                Button {
                    text: "+"; flat: true; implicitWidth: 28; implicitHeight: 24
                    contentItem: Text { text: parent.text; color: root.theme.accent; font.pixelSize: 15; font.bold: true;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 3; border.color: root.theme.border }
                    ToolTip.visible: hovered; ToolTip.text: qsTr("Kontakt hinzufügen"); ToolTip.delay: 400
                    onClicked: {
                        var id = db.bauteilKontaktHinzufuegen(
                            root.itemId, "schliesser", "", "{}")
                        if (id > 0)
                            root._kontaktListe = db.bauteilKontaktListe(root.itemId)
                    }
                }
            }

            Text {
                visible: root._kontaktListe.length === 0
                text: qsTr("Noch keine Einträge. Mit \"+\" Kontakt hinzufügen.\nFormat Pin-Zuordnung: \"1:13  2:14\"")
                font.pixelSize: 11; color: root.theme.textMuted; wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Repeater {
                model: root._kontaktListe
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    property var kDaten: modelData

                    // Bezeichnung (Picker-Label, z.B. "13/14")
                    Rectangle {
                        Layout.preferredWidth: 56; height: 28
                        color: root.theme.inputBg; border.color: bezTf.activeFocus ? root.theme.accent : root.theme.border; radius: 3
                        TextInput {
                            id: bezTf
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            text: kDaten.bezeichnung || ""
                            color: root.theme.accent; font.pixelSize: 12; font.weight: Font.Medium
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onEditingFinished: {
                                db.bauteilKontaktAktualisieren(kDaten.id,
                                    kSymTf.text.trim() || "schliesser",
                                    text.trim(), kPinTf.text.trim())
                                root._kontaktListe = db.bauteilKontaktListe(root.itemId)
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    // Symbol-ID
                    Rectangle {
                        Layout.preferredWidth: 80; height: 28
                        color: root.theme.inputBg; border.color: kSymTf.activeFocus ? root.theme.accent : root.theme.border; radius: 3
                        TextInput {
                            id: kSymTf
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            text: kDaten.symbolId || ""
                            color: root.theme.textPrimary; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onEditingFinished: {
                                db.bauteilKontaktAktualisieren(kDaten.id,
                                    text.trim() || "schliesser",
                                    bezTf.text.trim(), kPinTf.text.trim())
                                root._kontaktListe = db.bauteilKontaktListe(root.itemId)
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    // Pin-Zuordnung: "1:13  2:14"
                    Rectangle {
                        Layout.fillWidth: true; height: 28
                        color: root.theme.inputBg; border.color: kPinTf.activeFocus ? root.theme.accent : root.theme.border; radius: 3
                        TextInput {
                            id: kPinTf
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            text: {
                                try {
                                    var obj = JSON.parse(kDaten.pinBez || "{}")
                                    var parts = []
                                    for (var k in obj) parts.push(k + ":" + obj[k])
                                    return parts.join("  ")
                                } catch(e) { return "" }
                            }
                            color: root.theme.textMuted; font.pixelSize: 11
                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                            onEditingFinished: {
                                var pb = {}
                                var parts = text.trim().split(/[\s,]+/)
                                for (var i = 0; i < parts.length; i++) {
                                    var kv = parts[i].split(":")
                                    if (kv.length === 2 && kv[0].trim() !== "")
                                        pb[kv[0].trim()] = kv[1].trim()
                                }
                                db.bauteilKontaktAktualisieren(kDaten.id,
                                    kSymTf.text.trim() || "schliesser",
                                    bezTf.text.trim(), JSON.stringify(pb))
                                root._kontaktListe = db.bauteilKontaktListe(root.itemId)
                            }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    // Löschen
                    Rectangle {
                        width: 24; height: 24; radius: 3
                        color: kDelMA.containsMouse ? "#662222" : root.theme.inputBg
                        border.color: root.theme.border
                        Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 14;
                               color: kDelMA.containsMouse ? "#ffffff" : root.theme.textMuted }
                        MouseArea {
                            id: kDelMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                db.bauteilKontaktLoeschen(kDaten.id)
                                root._kontaktListe = db.bauteilKontaktListe(root.itemId)
                            }
                        }
                    }
                }
            }

            // Spalten-Header
            RowLayout {
                Layout.fillWidth: true; spacing: 4
                visible: root._kontaktListe.length > 0
                Text { text: qsTr("Bez."); color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 56 }
                Text { text: qsTr("Symbol"); color: root.theme.textMuted; font.pixelSize: 10; Layout.preferredWidth: 80 }
                Text { text: qsTr("Pin-Zuordnung (pin:label)"); color: root.theme.textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                Item { width: 28 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 12 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8; Layout.topMargin: 10
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }
            Button {
                text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                enabled: editForm.bezeichnung.trim().length > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    bauteilModel.bearbeiten(
                        root.itemId,
                        editForm.bezeichnung.trim(), editForm.hersteller.trim(),
                        editForm.artikelnummer.trim(), editForm.lieferant.trim(),
                        parseFloat(editForm.preis.replace(",","."))    || 0,
                        parseFloat(editForm.spannung.replace(",",".")) || 0,
                        parseFloat(editForm.strom.replace(",","."))    || 0,
                        parseFloat(editForm.leistung.replace(",",".")) || 0,
                        editForm.bemerkung.trim(),
                        editForm.urlHersteller.trim(),
                        editForm.urlDatenblatt.trim()
                    )
                    bauteilModel.symbolSpeichern(root.itemId, root.altSymbolId)
                    bauteilModel.bmkVorlageSpeichern(root.itemId, editForm.bmkVorlage.trim())
                    root.close()
                }
            }
        }
    }
}
