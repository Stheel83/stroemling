import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    required property var editor

    color: editor.theme.sidebar
    height: headerColumn.implicitHeight + 12

    ColumnLayout {
        id: headerColumn
        anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 6; bottomMargin: 6 }
        spacing: 6

        // Zeile 1: Stammdaten (Name, Kategorie, Größe) — SE-HEADER-ZWEIZEILIG-01
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: nameFeld
                text:              editor.nameText
                onEditingFinished: editor.nameText = text
                placeholderText:   qsTr("Symbolname")
                implicitWidth: 170; implicitHeight: 28
                font.pixelSize: 13
                background: Rectangle { color: editor.theme.inputBg; radius: 4; border.color: editor.theme.border }
                color: editor.theme.textPrimary
            }

            TextField {
                id: katFeld
                text:              editor.kategorieText
                onEditingFinished: editor.kategorieText = text
                placeholderText:   qsTr("Kategorie")
                implicitWidth: 130; implicitHeight: 28
                font.pixelSize: 13
                background: Rectangle { color: editor.theme.inputBg; radius: 4; border.color: editor.theme.border }
                color: editor.theme.textPrimary
            }

            Text { text: qsTr("Breite:"); color: editor.theme.textMuted; font.pixelSize: 11 }
            SpinBox {
                id: breiteBox
                from: 4; to: 400; stepSize: 4
                value: editor.breiteMm
                onValueModified: editor.breiteMm = value
                implicitWidth: 80; implicitHeight: 28
                background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
                contentItem: TextInput {
                    text: breiteBox.textFromValue(breiteBox.value, breiteBox.locale)
                    color: editor.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                    readOnly: !breiteBox.editable; validator: breiteBox.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
                up.indicator:   Rectangle { x: parent.width - width; width: 22; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 8; color: editor.theme.textMuted } }
                down.indicator: Rectangle { width: 22; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 8; color: editor.theme.textMuted } }
                ToolTip.visible: hovered; ToolTip.delay: 600
                ToolTip.text: qsTr("Breite in mm (Vielfaches von 4 empfohlen)")
            }
            Text { text: "mm"; color: editor.theme.textMuted; font.pixelSize: 11 }

            Text { text: qsTr("Höhe:"); color: editor.theme.textMuted; font.pixelSize: 11 }
            SpinBox {
                id: hoeheBox
                from: 4; to: 400; stepSize: 4
                value: editor.hoeheMm
                onValueModified: editor.hoeheMm = value
                implicitWidth: 80; implicitHeight: 28
                background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
                contentItem: TextInput {
                    text: hoeheBox.textFromValue(hoeheBox.value, hoeheBox.locale)
                    color: editor.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                    readOnly: !hoeheBox.editable; validator: hoeheBox.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
                up.indicator:   Rectangle { x: parent.width - width; width: 22; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 8; color: editor.theme.textMuted } }
                down.indicator: Rectangle { width: 22; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 8; color: editor.theme.textMuted } }
                ToolTip.visible: hovered; ToolTip.delay: 600
                ToolTip.text: qsTr("Höhe in mm (Vielfaches von 4 empfohlen, z.B. 104 mm für 26 Pins)")
            }
            Text { text: "mm"; color: editor.theme.textMuted; font.pixelSize: 11 }

            Text {
                text: qsTr("⊞ 4mm")
                color: editor.theme.accent; font.pixelSize: 10
                ToolTip.visible: rasterHover.containsMouse; ToolTip.delay: 400
                ToolTip.text: qsTr("Raster: große Punkte = 4mm-Raster · Pin-Abstände als Vielfaches von 4mm wählen")
                MouseArea { id: rasterHover; anchors.fill: parent; hoverEnabled: true }
            }

            Text {
                text: qsTr("Pin-Schrift:"); color: editor.theme.textMuted; font.pixelSize: 11
                ToolTip.visible: pinSchriftHover.containsMouse; ToolTip.delay: 400
                ToolTip.text: qsTr("Schriftgröße der Pin-Beschriftungen im Canvas/PDF-Export.\nBei eng stehenden Pins (z.B. Arduino, SPS-Baugruppen) kleiner wählen.")
                MouseArea { id: pinSchriftHover; anchors.fill: parent; hoverEnabled: true }
            }
            SpinBox {
                id: pinSchriftBox
                from: 10; to: 50; stepSize: 5
                value: Math.round(editor.pinSchriftMm * 10)
                onValueModified: editor.pinSchriftMm = value / 10
                textFromValue: function(value) { return (value / 10).toFixed(1) }
                valueFromText: function(text)  { return Math.round(parseFloat(text) * 10) }
                implicitWidth: 70; implicitHeight: 28
                background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
                contentItem: TextInput {
                    text: pinSchriftBox.textFromValue(pinSchriftBox.value)
                    color: editor.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter
                    readOnly: !pinSchriftBox.editable; validator: pinSchriftBox.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
                up.indicator:   Rectangle { x: parent.width - width; width: 22; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 8; color: editor.theme.textMuted } }
                down.indicator: Rectangle { width: 22; height: parent.height; color: "transparent"
                    Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 8; color: editor.theme.textMuted } }
            }
            Text { text: "mm"; color: editor.theme.textMuted; font.pixelSize: 11 }

            Item { Layout.fillWidth: true }
        }

        // Zeile 2: Klassifikation + Aktionen — SE-HEADER-ZWEIZEILIG-01
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text { text: qsTr("Rolle:"); color: editor.theme.textMuted; font.pixelSize: 11 }
            ComboBox {
                model: ["durchleiter", "verbraucher", "quelle", "trenner", "variabel"]
                currentIndex: Math.max(0, model.indexOf(editor.rolleText))
                onCurrentIndexChanged: editor.rolleText = model[currentIndex]
                implicitWidth: 115; implicitHeight: 28; font.pixelSize: 12
                background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
                contentItem: Text { text: parent.displayText; color: editor.theme.textPrimary; font.pixelSize: 12;
                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            }

            Text {
                text: qsTr("BMK:"); color: editor.theme.textMuted; font.pixelSize: 11
                ToolTip.visible: bmkHover.containsMouse; ToolTip.delay: 400
                ToolTip.text: qsTr("Position des BMK/Freitext-Labels bei Rotation 0°/180°.\nAuto: Label oben (für Grundausrichtung horizontal).\nSeitlich: Label links (für Grundausrichtung vertikal, wie Spule/Kontakte).\nUnten: BMK+Freitext unten (wenn Pins bei 0° an der Oberkante sitzen, z.B. SPS-Eingänge).\nOben: BMK+Freitext oben (wenn Pins bei 0° an der Unterkante sitzen, z.B. SPS-Ausgänge).")
                MouseArea { id: bmkHover; anchors.fill: parent; hoverEnabled: true }
            }
            ComboBox {
                id: bmkSeiteCombo
                model: ["auto", "vertikal", "unten", "oben"]
                currentIndex: Math.max(0, model.indexOf(editor.bmkSeiteText))
                onCurrentIndexChanged: editor.bmkSeiteText = model[currentIndex]
                implicitWidth: 100; implicitHeight: 28; font.pixelSize: 12
                background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
                contentItem: Text {
                    text: {
                        switch (bmkSeiteCombo.currentIndex) {
                        case 1: return qsTr("Seitlich")
                        case 2: return qsTr("Unten")
                        case 3: return qsTr("Oben")
                        default: return qsTr("Auto")
                        }
                    }
                    color: editor.theme.textPrimary; font.pixelSize: 12
                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                }
            }

            Text {
                text: qsTr("Kennbuchstaben:"); color: editor.theme.textMuted; font.pixelSize: 11
                ToolTip.visible: kbHover.containsMouse; ToolTip.delay: 400
                ToolTip.text: qsTr("BMK-Kennbuchstaben nach DIN EN 81346 (z.B. \"M\" fuer Motor, \"K\"/\"Q\" fuer eine Spule die je nach Geraet Schuetz oder Leistungsschalter ist). Mehrere moeglich - der markierte (farbig) wird beim Platzieren automatisch vorbelegt, die uebrigen erscheinen als Umschalt-Chips im Eigenschaften-Panel. Klick auf einen Chip macht ihn zum Standard, × entfernt ihn. Keine Eintraege = kein Vorschlag. Wirkt auch bei eingebauten Symbolen (reine Klassifikations-Metadatur, keine Geometrie).")
                MouseArea { id: kbHover; anchors.fill: parent; hoverEnabled: true }
            }
            Row {
                spacing: 4
                Repeater {
                    model: editor.bmkKennbuchstaben
                    delegate: Rectangle {
                        id: kbChip
                        implicitHeight: 22
                        implicitWidth: kbChipRow.implicitWidth + 12
                        radius: 11
                        color: modelData.istStandard ? editor.theme.accent : editor.theme.inputBg
                        border.color: modelData.istStandard ? editor.theme.accent : editor.theme.border

                        // Muss VOR dem RowLayout stehen, sonst blockiert sie den ×-Klick darunter.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editor.bmkStandardSetzen(index)
                        }
                        RowLayout {
                            id: kbChipRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: modelData.kennbuchstabe
                                color: modelData.istStandard ? "white" : editor.theme.textPrimary
                                font.pixelSize: 11; font.bold: modelData.istStandard
                            }
                            Text {
                                text: "×"; font.pixelSize: 12
                                color: modelData.istStandard ? "white" : editor.theme.textMuted
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -2
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: editor.bmkBuchstabeEntfernen(index)
                                }
                            }
                        }
                        ToolTip.visible: modelData.istStandard ? false : kbChipHover.containsMouse
                        ToolTip.text: qsTr("Als Standard setzen")
                        ToolTip.delay: 500
                        MouseArea { id: kbChipHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                }
                TextField {
                    id: kbNeuFeld
                    implicitWidth: 64; implicitHeight: 24
                    font.pixelSize: 11
                    placeholderText: qsTr("Buchstabe")
                    placeholderTextColor: editor.theme.accent
                    // Auffälliger Akzent-Rahmen statt des sonst üblichen unscheinbaren
                    // theme.border - sonst wirkt das Feld bei leerer Kennbuchstaben-
                    // Liste wie ein deaktiviertes/übersehbares Eingabefeld.
                    background: Rectangle { color: editor.theme.inputBg; radius: 4; border.color: editor.theme.accent }
                    color: editor.theme.textPrimary
                    onAccepted: kbAddBtn.hinzufuegen()
                }
                // Expliziter Button statt nur Enter-Taste (SE-KENNBUCHSTABEN-ADD-BUG-01:
                // Enter-only war fuer den Nutzer nicht erkennbar/auffindbar - "wie trage
                // ich einen zweiten Buchstaben ein?"). Enter im Feld bleibt zusaetzlich
                // als Shortcut nutzbar (siehe onAccepted oben).
                Rectangle {
                    id: kbAddBtn
                    function hinzufuegen() { editor.bmkBuchstabeHinzufuegen(kbNeuFeld.text); kbNeuFeld.text = ""; kbNeuFeld.forceActiveFocus() }
                    implicitWidth: 24; implicitHeight: 24; radius: 4
                    color: kbAddMa.containsMouse ? editor.theme.accent : editor.theme.inputBg
                    border.color: editor.theme.accent
                    Text {
                        anchors.centerIn: parent; text: "+"; font.pixelSize: 14; font.bold: true
                        color: kbAddMa.containsMouse ? "white" : editor.theme.accent
                    }
                    MouseArea {
                        id: kbAddMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: kbAddBtn.hinzufuegen()
                    }
                    ToolTip.visible: kbAddMa.containsMouse
                    ToolTip.text: qsTr("Kennbuchstaben hinzufügen (auch mit Enter im Feld links)")
                    ToolTip.delay: 500
                }
                Text {
                    visible: editor.bmkKennbuchstaben.length === 0
                    text: qsTr("(noch keine hinterlegt)")
                    color: editor.theme.textMuted; font.pixelSize: 10; font.italic: true
                    anchors.verticalCenter: kbNeuFeld.verticalCenter
                }
            }

            Item { Layout.fillWidth: true }

            // Vergleichs-Navigation (SE-VERGLEICH-01) — nur sichtbar sobald 2+
            // Symbole über das 📌-Icon in der Liste markiert wurden.
            Rectangle {
                visible: editor.vergleichsListe.length >= 2
                implicitHeight: 28
                implicitWidth: vglRow.implicitWidth + 10
                radius: 4; color: editor.theme.inputBg; border.color: editor.theme.border

                RowLayout {
                    id: vglRow
                    anchors.centerIn: parent
                    spacing: 2

                    Rectangle {
                        implicitWidth: 20; implicitHeight: 20; radius: 3
                        color: vglZurueckHover.hovered ? editor.theme.badge : "transparent"
                        Text { anchors.centerIn: parent; text: "◀"; font.pixelSize: 10; color: editor.theme.textSecondary }
                        HoverHandler { id: vglZurueckHover }
                        TapHandler { onTapped: editor.vergleichZurueck() }
                        ToolTip.visible: vglZurueckHover.hovered; ToolTip.delay: 600
                        ToolTip.text: qsTr("Vorheriges markiertes Symbol")
                    }
                    Text {
                        text: {
                            var idx = editor.vergleichsListe.indexOf(editor.editSymbolId)
                            return (idx >= 0 ? (idx + 1) : "–") + "/" + editor.vergleichsListe.length
                        }
                        font.pixelSize: 11; color: editor.theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Rectangle {
                        implicitWidth: 20; implicitHeight: 20; radius: 3
                        color: vglVorHover.hovered ? editor.theme.badge : "transparent"
                        Text { anchors.centerIn: parent; text: "▶"; font.pixelSize: 10; color: editor.theme.textSecondary }
                        HoverHandler { id: vglVorHover }
                        TapHandler { onTapped: editor.vergleichVor() }
                        ToolTip.visible: vglVorHover.hovered; ToolTip.delay: 600
                        ToolTip.text: qsTr("Nächstes markiertes Symbol")
                    }
                    Rectangle {
                        implicitWidth: 20; implicitHeight: 20; radius: 3
                        color: vglClearHover.hovered ? editor.theme.badge : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 9; color: editor.theme.textMuted }
                        HoverHandler { id: vglClearHover }
                        TapHandler { onTapped: editor.vergleichLeeren() }
                        ToolTip.visible: vglClearHover.hovered; ToolTip.delay: 600
                        ToolTip.text: qsTr("Vergleichsliste leeren")
                    }
                }
            }

            Rectangle {
                visible: editor.istBuiltin
                radius: 4; color: "#40331a"
                border.color: "#cc8800"; border.width: 1
                implicitWidth: eingebautLabel.implicitWidth + 16; implicitHeight: 28
                Text {
                    id: eingebautLabel
                    anchors.centerIn: parent
                    text: qsTr("⚠ Eingebaut – nur als Vorlage kopierbar")
                    color: "#ffbb44"; font.pixelSize: 11
                }
            }

            Button {
                // NKZ-05: Button war bei eingebauten Symbolen bisher komplett
                // ausgeblendet (visible: !istBuiltin) - dadurch war editor.speichern()
                // nie erreichbar, obwohl die Funktion selbst schon extra so gebaut ist,
                // dass sie bei ist_builtin=1 wenigstens die Kennbuchstaben speichert.
                // Jetzt immer sichtbar, Beschriftung macht bei eingebauten Symbolen
                // klar, dass nur die Kennbuchstaben gespeichert werden.
                text: editor.istBuiltin ? qsTr("Kennbuchstaben speichern") : qsTr("Speichern")
                implicitHeight: 28; implicitWidth: editor.istBuiltin ? 150 : 90
                onClicked: editor.speichern()
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? editor.theme.accent : editor.theme.inputBg) : editor.theme.inputBg
                    radius: 4; border.color: parent.enabled ? editor.theme.accent : editor.theme.border
                }
                contentItem: Text { text: parent.text; color: parent.enabled ? editor.theme.textPrimary : editor.theme.textMuted;
                                    font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            Button {
                text: qsTr("❐ Kopie")
                visible: editor.editSymbolId !== ""
                implicitHeight: 28; implicitWidth: 78
                onClicked: editor.kopieErstellen()
                background: Rectangle {
                    color: parent.hovered ? editor.theme.hover : editor.theme.inputBg
                    radius: 4; border.color: editor.theme.border
                }
                contentItem: Text { text: parent.text; color: editor.theme.textSecondary;
                                    font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                ToolTip.visible: hovered; ToolTip.delay: 400
                ToolTip.text: qsTr("Aktives Symbol als neue bearbeitbare Kopie anlegen")
            }

            Button {
                text: qsTr("Abbrechen")
                implicitHeight: 28; implicitWidth: 90
                flat: true
                onClicked: editor.abgebrochen()
                background: Rectangle { color: parent.hovered ? editor.theme.hover : editor.theme.inputBg; radius: 4; border.color: editor.theme.border }
                contentItem: Text { text: parent.text; color: editor.theme.textSecondary; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }
    DebugLabel { panelName: qsTr("SE Header"); visible: editor.debug }
}
