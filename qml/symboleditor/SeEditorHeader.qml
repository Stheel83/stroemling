import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    required property var editor

    height: 44
    color: editor.theme.sidebar

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
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
            ToolTip.visible: hovered; ToolTip.delay: 400
            ToolTip.text: qsTr("Raster: große Punkte = 4mm-Raster · Pin-Abstände als Vielfaches von 4mm wählen")
            MouseArea { anchors.fill: parent; hoverEnabled: true }
        }

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
            ToolTip.text: qsTr("Position des BMK/Freitext-Labels bei Rotation 0°/180°.\nAuto: Label oben (für Grundausrichtung horizontal).\nSeitlich: Label links (für Grundausrichtung vertikal, wie Spule/Kontakte).")
            MouseArea { id: bmkHover; anchors.fill: parent; hoverEnabled: true }
        }
        ComboBox {
            id: bmkSeiteCombo
            model: ["auto", "vertikal"]
            currentIndex: Math.max(0, model.indexOf(editor.bmkSeiteText))
            onCurrentIndexChanged: editor.bmkSeiteText = model[currentIndex]
            implicitWidth: 100; implicitHeight: 28; font.pixelSize: 12
            background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
            contentItem: Text {
                text: bmkSeiteCombo.currentIndex === 1 ? qsTr("Seitlich") : qsTr("Auto")
                color: editor.theme.textPrimary; font.pixelSize: 12
                leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
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
            text: qsTr("Speichern")
            visible: !editor.istBuiltin
            implicitHeight: 28; implicitWidth: 90
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
            text:    qsTr("SQL")
            visible: editor.editSymbolId !== ""
            implicitHeight: 28; implicitWidth: 58
            onClicked: {
                var sql = editor.sqlAlsText(editor.editSymbolId)
                editor.kopiereInZwischenablage(sql)
                sqlKopiertTimer.restart()
            }
            background: Rectangle {
                color: parent.hovered ? editor.theme.accent : editor.theme.inputBg
                radius: 4; border.color: editor.theme.accent
            }
            contentItem: Text {
                text: sqlKopiertTimer.running ? qsTr("✓ OK") : parent.text
                color: editor.theme.textPrimary; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            Timer { id: sqlKopiertTimer; interval: 1500 }
            ToolTip.visible: hovered; ToolTip.delay: 600
            ToolTip.text: qsTr("Fertigen SQL-Block (Migration bei Kopie eines Originals, sonst Seed-INSERT) in Zwischenablage kopieren")
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
    DebugLabel { panelName: qsTr("SE Header"); visible: editor.debug }
}
