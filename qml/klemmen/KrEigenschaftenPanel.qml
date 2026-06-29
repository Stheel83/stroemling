import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    required property var panel
    required property var theme

    signal neueStegAngefordert()
    signal bauteilWaehlenAngefordert(int klemmeId)
    signal modusAPlatzierenAngefordert(int klemmeId, int bauteilKlemmeId, string bmkPrefix)
    signal leisteGeloescht()
    signal leisteKanvasAktualisiert()

    color: theme.sidebar

    DebugLabel { panelName: qsTr("Klemmen-Eigenschaften"); visible: panel.debug }

    Flickable {
        anchors.fill:        parent
        contentHeight:       eigenCol.implicitHeight + 16
        clip:                true
        ScrollBar.vertical:  ScrollBar {}

        ColumnLayout {
            id:       eigenCol
            x:        12; y: 12
            width:    parent.width - 24
            spacing:  6

            // ── Klemmenleiste ────────────────────────────────
            Text {
                text: qsTr("KLEMMENLEISTE")
                font.pixelSize: 9; font.weight: Font.Bold
                color: theme.textMuted; font.letterSpacing: 1
            }
            Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }

            // BMK
            Text {
                text: klemmenreiheModel.hatLeiste
                      ? (klemmenreiheModel.leiste["bmkVollstaendig"] || klemmenreiheModel.leiste["bmkKurz"] || "")
                      : ""
                font.pixelSize: 14; font.weight: Font.Bold
                color: theme.accent
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }

            // Bezeichnung editierbar
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: qsTr("Bezeichnung:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                TextField {
                    id:               leisteBezeichnungField
                    Layout.fillWidth: true
                    text:             klemmenreiheModel.hatLeiste ? (klemmenreiheModel.leiste["bezeichnung"] || "") : ""
                    font.pixelSize:   12; color: theme.textPrimary
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    onEditingFinished: {
                        if (klemmenreiheModel.hatLeiste) {
                            var d = Object.assign({}, klemmenreiheModel.leiste)
                            d["bezeichnung"] = text
                            klemmenreiheModel.leisteAktualisieren(d)
                        }
                    }
                }
            }

            // Ausrichtung
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: qsTr("Ausrichtung:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                ComboBox {
                    id:               ausrichtungCombo
                    Layout.fillWidth: true
                    model:            [qsTr("Senkrecht"), qsTr("Liegend")]
                    currentIndex:     klemmenreiheModel.hatLeiste && klemmenreiheModel.leiste["ausrichtung"] === "liegend" ? 1 : 0
                    font.pixelSize:   12
                    contentItem: Text {
                        text: ausrichtungCombo.displayText
                        font: ausrichtungCombo.font
                        color: theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                    }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate {
                        width: ausrichtungCombo.width
                        contentItem: Text {
                            text:  modelData
                            color: theme.textPrimary; font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered ? theme.hover : theme.sidebar
                        }
                    }
                    onActivated: {
                        if (klemmenreiheModel.hatLeiste) {
                            var d = Object.assign({}, klemmenreiheModel.leiste)
                            d["ausrichtung"] = currentIndex === 1 ? "liegend" : "senkrecht"
                            klemmenreiheModel.leisteAktualisieren(d)
                        }
                    }
                }
            }

            // Ort-Zuweisung (DIN 81346: =Anlage +Ort)
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: qsTr("Anlage:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                ComboBox {
                    id: anlageCombo
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    property var _anlagenListe: []
                    Component.onCompleted: _anlagenListe = seitenModel.anlagenListe()
                    currentIndex: 0
                    model: {
                        var items = [qsTr("(keine)")]
                        for (var i = 0; i < _anlagenListe.length; i++) items.push(_anlagenListe[i].label)
                        return items
                    }
                    contentItem: Text {
                        text: anlageCombo.displayText; font: anlageCombo.font
                        color: theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8
                    }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate {
                        width: anlageCombo.width
                        contentItem: Text { text: modelData; color: theme.textPrimary; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? theme.hover : theme.sidebar }
                    }
                    onActivated: { ortCombo.currentIndex = 0; _applyOrt() }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: qsTr("Ort:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                ComboBox {
                    id: ortCombo
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    currentIndex: 0
                    // Reaktives Binding: aktualisiert automatisch wenn Anlage-Auswahl sich ändert
                    property var _orteListe: {
                        var idx = anlageCombo.currentIndex
                        if (idx <= 0 || idx > anlageCombo._anlagenListe.length) return []
                        return seitenModel.orteListe(anlageCombo._anlagenListe[idx - 1].itemId)
                    }
                    model: {
                        var items = [qsTr("(kein)")]
                        for (var i = 0; i < _orteListe.length; i++) items.push(_orteListe[i].label)
                        return items
                    }
                    contentItem: Text {
                        text: ortCombo.displayText; font: ortCombo.font
                        color: theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8
                    }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate {
                        width: ortCombo.width
                        contentItem: Text { text: modelData; color: theme.textPrimary; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? theme.hover : theme.sidebar }
                    }
                    onActivated: _applyOrt()
                }
            }

            // Verhindert dass onLeisteGeladen nach eigenem Speichern die
            // Combo-Auswahl zurücksetzt (leisteAktualisieren → laden → leisteGeladen).
            property bool _ortSaving: false

            function _applyOrt() {
                if (!klemmenreiheModel.hatLeiste) return
                var ortIdx = ortCombo.currentIndex
                var newOrtId = (ortIdx > 0 && ortCombo._orteListe.length >= ortIdx)
                              ? ortCombo._orteListe[ortIdx - 1].itemId : -1
                var d = Object.assign({}, klemmenreiheModel.leiste)
                d["ortId"] = newOrtId
                _ortSaving = true
                klemmenreiheModel.leisteAktualisieren(d)
            }

            // Wenn eine andere Leiste geladen wird: Anlage- und Ort-Combo
            // explizit auf den gespeicherten Ort setzen.
            Connections {
                target: klemmenreiheModel
                function onLeisteGeladen() {
                    if (eigenCol._ortSaving) { eigenCol._ortSaving = false; return }
                    var oid = klemmenreiheModel.hatLeiste
                             ? (klemmenreiheModel.leiste["ortId"] || -1) : -1
                    var anlageIdx = 0
                    if (oid > 0) {
                        var al = anlageCombo._anlagenListe
                        outer: for (var k = 0; k < al.length; k++) {
                            var lo = seitenModel.orteListe(al[k].itemId)
                            for (var m = 0; m < lo.length; m++)
                                if (lo[m].itemId === oid) { anlageIdx = k + 1; break outer }
                        }
                    }
                    anlageCombo.currentIndex = anlageIdx
                    // _orteListe aktualisiert sich reaktiv; jetzt Ort suchen
                    var ortIdx = 0
                    if (oid > 0) {
                        var ol = ortCombo._orteListe
                        for (var i = 0; i < ol.length; i++)
                            if (ol[i].itemId === oid) { ortIdx = i + 1; break }
                    }
                    ortCombo.currentIndex = ortIdx
                }
            }
            Connections {
                target: seitenModel
                function onModelReset() {
                    anlageCombo._anlagenListe = seitenModel.anlagenListe()
                    // ortCombo._orteListe aktualisiert sich reaktiv via Binding
                }
            }

            // Anlage / Standort übergeordnet
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: qsTr("==Anlage:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                TextField {
                    Layout.fillWidth: true
                    text: klemmenreiheModel.hatLeiste ? (klemmenreiheModel.leiste["anlageUebergeordnet"] || "") : ""
                    font.pixelSize: 12; color: theme.textPrimary
                    placeholderText: qsTr("optional")
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    onEditingFinished: {
                        if (klemmenreiheModel.hatLeiste) {
                            var d = Object.assign({}, klemmenreiheModel.leiste)
                            d["anlageUebergeordnet"] = text
                            klemmenreiheModel.leisteAktualisieren(d)
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: qsTr("++Standort:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                TextField {
                    Layout.fillWidth: true
                    text: klemmenreiheModel.hatLeiste ? (klemmenreiheModel.leiste["standortUebergeordnet"] || "") : ""
                    font.pixelSize: 12; color: theme.textPrimary
                    placeholderText: qsTr("optional")
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    onEditingFinished: {
                        if (klemmenreiheModel.hatLeiste) {
                            var d = Object.assign({}, klemmenreiheModel.leiste)
                            d["standortUebergeordnet"] = text
                            klemmenreiheModel.leisteAktualisieren(d)
                        }
                    }
                }
            }

            // Bemerkung
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: qsTr("Bemerkung:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                TextField {
                    Layout.fillWidth: true
                    text: klemmenreiheModel.hatLeiste ? (klemmenreiheModel.leiste["bemerkung"] || "") : ""
                    font.pixelSize: 12; color: theme.textPrimary
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    onEditingFinished: {
                        if (klemmenreiheModel.hatLeiste) {
                            var d = Object.assign({}, klemmenreiheModel.leiste)
                            d["bemerkung"] = text
                            klemmenreiheModel.leisteAktualisieren(d)
                        }
                    }
                }
            }

            // Highlight-Override (pro Leiste)
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: qsTr("Highlight:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                ComboBox {
                    Layout.fillWidth: true
                    font.pixelSize: 12
                    model: [qsTr("Global (Standard)"), qsTr("Immer aus")]
                    currentIndex: {
                        if (!klemmenreiheModel.hatLeiste) return 0
                        var hlo = klemmenreiheModel.leiste["highlightOverride"]
                        return (hlo !== null && hlo !== undefined && hlo === 0) ? 1 : 0
                    }
                    contentItem: Text {
                        text: parent.displayText; font: parent.font
                        color: theme.textPrimary; verticalAlignment: Text.AlignVCenter; leftPadding: 8
                    }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate {
                        width: parent.width
                        contentItem: Text { text: modelData; color: theme.textPrimary; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? theme.hover : theme.sidebar }
                    }
                    onActivated: {
                        if (!klemmenreiheModel.hatLeiste) return
                        var d = Object.assign({}, klemmenreiheModel.leiste)
                        d["highlightOverride"] = currentIndex === 1 ? 0 : null
                        klemmenreiheModel.leisteAktualisieren(d)
                    }
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Beim Anklicken eines Klemmenanschlusses dieser Leiste\nzugehörige Anschlüsse auf dem Canvas hervorheben.\n\"Immer aus\" überschreibt den globalen Schalter im EP.")
                }
            }

            // Statistik
            Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }
            RowLayout {
                Layout.fillWidth: true; spacing: 0
                Text { text: qsTr("Klemmen:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                Text {
                    text: klemmenreiheModel.klemmen.length
                    font.pixelSize: 12; color: theme.textSecondary
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 0
                Text { text: qsTr("Gesamtbreite:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                Text {
                    text: {
                        var kl  = klemmenreiheModel.klemmen
                        var sum = 0; var ohne = 0
                        for (var i = 0; i < kl.length; ++i) {
                            if (kl[i].breiteMm > 0) sum += kl[i].breiteMm
                            else ohne++
                        }
                        if (sum === 0 && ohne > 0) return qsTr("unbekannt")
                        var t = sum.toFixed(1) + " mm"
                        if (ohne > 0) t += " (+" + ohne + qsTr(" o.A.") + ")"
                        return t
                    }
                    font.pixelSize: 12; color: theme.textSecondary
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                }
            }
            Text {
                visible: {
                    var kl = klemmenreiheModel.klemmen
                    for (var i = 0; i < kl.length; ++i)
                        if (kl[i].breiteMm === 0) return true
                    return false
                }
                text: qsTr("Richtwert – Endböcke und Trennplatten\nsind nicht eingerechnet.")
                font.pixelSize: 9; color: theme.textMuted
                wrapMode: Text.Wrap; Layout.fillWidth: true
            }

            // ── Stegbrücken (Leiste) ─────────────────────────
            Item { height: 8 }
            Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }
            RowLayout {
                Layout.fillWidth: true; spacing: 0
                Text {
                    text: qsTr("STEGBRÜCKEN")
                    font.pixelSize: 9; font.weight: Font.Bold
                    color: theme.textMuted; font.letterSpacing: 1
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 22; height: 22; radius: 3
                    color: addStegBtn.containsMouse ? theme.accent : theme.inputBg
                    border.color: theme.accent
                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; color: theme.textPrimary }
                    MouseArea {
                        id: addStegBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: klemmenreiheModel.klemmen.length >= 2
                        onClicked: root.neueStegAngefordert()
                    }
                }
            }

            // Liste der Stegbrücken
            Repeater {
                model: klemmenreiheModel.stegbruecken
                delegate: ColumnLayout {
                    Layout.fillWidth: true; spacing: 3

                    RowLayout {
                        Layout.fillWidth: true; spacing: 4
                        Rectangle {
                            width: 30; height: 18; radius: 3
                            color: modelData.hatKonflikt ? "#7a2020" : panel.stegFarbe(index)
                            opacity: 0.85
                            Text { anchors.centerIn: parent
                                   text: "Eb." + modelData.ebene; font.pixelSize: 8; color: "white" }
                        }
                        Text {
                            text: modelData.vonNummer + "–" + modelData.bisNummer
                            font.pixelSize: 11; color: theme.textSecondary
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: modelData.hatKonflikt
                            text: "⚠"; font.pixelSize: 11; color: "#e05050"
                            ToolTip.visible: hatKonfliktMa.containsMouse
                            ToolTip.text: modelData.konfliktText || ""
                            MouseArea { id: hatKonfliktMa; anchors.fill: parent; hoverEnabled: true }
                        }
                        Rectangle {
                            width: 18; height: 18; radius: 3
                            color: stegDelMa.containsMouse ? "#7a2020" : "transparent"
                            border.color: "#7a3030"; border.width: 1
                            Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 12; color: "#e05050" }
                            MouseArea {
                                id: stegDelMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: klemmenreiheModel.stegbrueckeLoeschen(modelData.stegId)
                            }
                        }
                    }

                    // Potenzial-Textfeld
                    TextField {
                        Layout.fillWidth: true
                        text:             modelData.potenzialText || ""
                        placeholderText:  qsTr("Potenzial (z.B. L1, PE, 24VDC)")
                        font.pixelSize:   11; color: theme.textPrimary
                        background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                        onEditingFinished: klemmenreiheModel.stegbrueckePotenzialSetzen(modelData.stegId, text)
                    }
                }
            }

            Text {
                visible: klemmenreiheModel.stegbruecken.length === 0
                text: qsTr("Keine Stegbrücken")
                font.pixelSize: 10; color: theme.textMuted
            }

            // ── CE-05: Mehrfachauswahl ───────────────────────
            Item { height: 8; visible: panel._ausgewaehlt.length >= 2 }
            Text {
                visible: panel._ausgewaehlt.length >= 2
                text: qsTr("MEHRFACHAUSWAHL")
                font.pixelSize: 9; font.weight: Font.Bold
                color: theme.accent; font.letterSpacing: 1
            }
            Rectangle {
                visible: panel._ausgewaehlt.length >= 2
                height: 1; Layout.fillWidth: true; color: theme.divider
            }
            Text {
                visible: panel._ausgewaehlt.length >= 2
                text: qsTr("%1 Klemmen ausgewählt").arg(panel._ausgewaehlt.length)
                font.pixelSize: 11; color: theme.textSecondary; Layout.fillWidth: true
            }

            // Bauteil zuweisen (Multi)
            Button {
                visible: panel._ausgewaehlt.length >= 2
                text: qsTr("Bauteil zuweisen...")
                Layout.fillWidth: true; implicitHeight: 26
                contentItem: Text {
                    text: parent.text; font.pixelSize: 11; color: theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? theme.accent : theme.inputBg; radius: 3; border.color: theme.accent
                }
                ToolTip.visible: hovered; ToolTip.delay: 500
                ToolTip.text: qsTr("Dasselbe Bauteil allen markierten Klemmen zuweisen")
                onClicked: root.bauteilWaehlenAngefordert(-1)
            }

            // Auto-Nummerieren (Multi)
            RowLayout {
                visible: panel._ausgewaehlt.length >= 2
                Layout.fillWidth: true; spacing: 6

                Text {
                    text: qsTr("Ab Nr.:")
                    font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 55
                }
                SpinBox {
                    id: multiStartNr
                    from: 1; to: 9999; value: 1; editable: true
                    implicitWidth: 80; implicitHeight: 26
                    font.pixelSize: 11
                    contentItem: TextInput {
                        text: parent.textFromValue(parent.value, parent.locale)
                        font: parent.font; color: theme.textPrimary
                        verticalAlignment: Text.AlignVCenter; leftPadding: 8
                        readOnly: !parent.editable; validator: parent.validator
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                    }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                }
                Button {
                    text: qsTr("Nummerieren")
                    implicitHeight: 26; Layout.fillWidth: true
                    contentItem: Text {
                        text: parent.text; font.pixelSize: 11; color: theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? theme.accent : theme.inputBg; radius: 3; border.color: theme.accent
                    }
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Markierte Klemmen von links nach rechts fortlaufend nummerieren")
                    onClicked: {
                        var kl = klemmenreiheModel.klemmen
                        var sorted = panel._ausgewaehlt.slice().sort(function(a, b) {
                            var ia = -1, ib = -1
                            for (var j = 0; j < kl.length; j++) {
                                if (kl[j].klemmeId === a) ia = j
                                if (kl[j].klemmeId === b) ib = j
                            }
                            return ia - ib
                        })
                        klemmenreiheModel.klemmeMehrfachNummerieren(sorted, multiStartNr.value)
                    }
                }
            }

            // Auswahl aufheben
            Button {
                visible: panel._ausgewaehlt.length >= 2
                text: qsTr("Auswahl aufheben")
                Layout.fillWidth: true; implicitHeight: 24
                contentItem: Text {
                    text: parent.text; font.pixelSize: 11; color: theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 3
                }
                onClicked: panel._ausgewaehlt = []
            }

            // ── Klemme ausgewählt ────────────────────────────
            Item { height: 8; visible: panel.aktivKlemme !== null }
            Text {
                visible: panel.aktivKlemme !== null
                text: qsTr("KLEMME")
                font.pixelSize: 9; font.weight: Font.Bold
                color: theme.textMuted; font.letterSpacing: 1
            }
            Rectangle {
                visible: panel.aktivKlemme !== null
                height: 1; Layout.fillWidth: true; color: theme.divider
            }

            // Klemmennummer editierbar
            RowLayout {
                visible: panel.aktivKlemme !== null
                Layout.fillWidth: true; spacing: 6
                Text { text: qsTr("Nummer:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                TextField {
                    Layout.fillWidth: true
                    text: panel.aktivKlemme ? (panel.aktivKlemme.nummer || "") : ""
                    font.pixelSize: 13; font.weight: Font.Bold
                    color: theme.accent
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    onEditingFinished: {
                        if (panel.aktivKlemme)
                            klemmenreiheModel.klemmeNummerSetzen(panel.aktivKlemme.klemmeId, text)
                    }
                }
            }

            // Bauteil – immer anzeigen (mit "(kein)" wenn nicht zugewiesen)
            RowLayout {
                visible: panel.aktivKlemme !== null
                Layout.fillWidth: true; spacing: 0
                Text { text: qsTr("Bauteil:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                Text {
                    text: panel.aktivKlemme && panel.aktivKlemme.bauteilId > 0
                          ? (panel.aktivKlemme.bauteilName || "")
                          : qsTr("(kein)")
                    font.pixelSize: 12
                    color: panel.aktivKlemme && panel.aktivKlemme.bauteilId > 0 ? theme.textSecondary : theme.textMuted
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                }
            }

            // Buttons: Zuweisen / Ändern / Entfernen
            RowLayout {
                visible: panel.aktivKlemme !== null
                Layout.fillWidth: true; spacing: 6
                Button {
                    text: panel.aktivKlemme && panel.aktivKlemme.bauteilId > 0 ? qsTr("Ändern") : qsTr("Zuweisen")
                    implicitHeight: 24
                    contentItem: Text {
                        text: parent.text; font.pixelSize: 11; color: theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? theme.accent : theme.inputBg; radius: 3; border.color: theme.accent
                    }
                    onClicked: root.bauteilWaehlenAngefordert(panel.aktivKlemme.klemmeId)
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: panel.aktivKlemme && panel.aktivKlemme.bauteilId > 0
                                  ? qsTr("Anderes Klemmen-Bauteil aus dem Katalog wählen")
                                  : qsTr("Klemmen-Bauteil aus dem Katalog zuweisen")
                }
                Button {
                    visible: panel.aktivKlemme !== null && panel.aktivKlemme.bauteilId > 0
                    text: qsTr("Entfernen")
                    implicitHeight: 24
                    contentItem: Text {
                        text: parent.text; font.pixelSize: 11; color: "#e05050"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? "#3a1010" : "transparent"; border.color: "#7a3030"; border.width: 1; radius: 3
                    }
                    onClicked: klemmenreiheModel.klemmeBauteilSetzen(panel.aktivKlemme.klemmeId, 0)
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Bauteil-Zuweisung dieser Klemme entfernen")
                }
                Item { Layout.fillWidth: true }
            }

            // Typ, Breite, Querschnitte (nur wenn Bauteil zugewiesen)
            RowLayout {
                visible: panel.aktivKlemme !== null && panel.aktivKlemme !== undefined && panel.aktivKlemme.anschlussTyp !== ""
                Layout.fillWidth: true; spacing: 0
                Text { text: qsTr("Typ:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                Text {
                    text: panel.aktivKlemme ? (panel.aktivKlemme.anschlussTyp || "") : ""
                    font.pixelSize: 12; color: theme.textSecondary
                }
            }
            RowLayout {
                visible: panel.aktivKlemme !== null && panel.aktivKlemme !== undefined && panel.aktivKlemme.breiteMm > 0
                Layout.fillWidth: true; spacing: 0
                Text { text: qsTr("Breite:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                Text {
                    text: panel.aktivKlemme ? panel.aktivKlemme.breiteMm.toFixed(1) + " mm" : ""
                    font.pixelSize: 12; color: theme.textSecondary
                }
            }
            RowLayout {
                visible: panel.aktivKlemme !== null && panel.aktivKlemme !== undefined && (panel.aktivKlemme.querschnitteText || "") !== ""
                Layout.fillWidth: true; spacing: 0
                Text { text: qsTr("Querschnitt:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                Text {
                    text: panel.aktivKlemme ? (panel.aktivKlemme.querschnitteText || "") : ""
                    font.pixelSize: 11; color: theme.textSecondary
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                }
            }

            // Im Canvas platzieren (Modus A – Verknüpft)
            RowLayout {
                visible: panel.aktivKlemme !== null && panel.aktivKlemme !== undefined && panel.aktivKlemme.bauteilId > 0
                Layout.fillWidth: true; spacing: 6
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Im Canvas platzieren")
                    implicitHeight: 24
                    contentItem: Text {
                        text: parent.text; font.pixelSize: 11; color: theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.hovered ? theme.accent : theme.inputBg; radius: 3; border.color: theme.accent
                    }
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Klemme als verknüpftes Symbol in den Schaltplan platzieren")
                    onClicked: {
                        klemmeModel.laden(panel.aktivKlemme.bauteilId)
                        var bkId      = klemmeModel.klemme["klemmeId"] || -1
                        var leisteBmk = klemmenreiheModel.leiste["bmkKurz"]
                                       || ("-" + (klemmenreiheModel.leiste["bezeichnung"] || ""))
                        root.modusAPlatzierenAngefordert(
                            panel.aktivKlemme.klemmeId, bkId,
                            leisteBmk + ":" + (panel.aktivKlemme.nummer || ""))
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // Stegbrücken dieser Klemme (gefiltert)
            Item {
                height: 8
                visible: panel.aktivKlemme !== null && klemmenreiheModel.stegbruecken.some(
                    function(s) { return s.vonKlemmeId === panel.aktivKlemme.klemmeId || s.bisKlemmeId === panel.aktivKlemme.klemmeId })
            }
            Text {
                visible: panel.aktivKlemme !== null && klemmenreiheModel.stegbruecken.some(
                    function(s) { return s.vonKlemmeId === panel.aktivKlemme.klemmeId || s.bisKlemmeId === panel.aktivKlemme.klemmeId })
                text: qsTr("Stegbrücken (diese Klemme)")
                font.pixelSize: 9; font.weight: Font.Bold
                color: theme.textMuted; font.letterSpacing: 1
            }
            Repeater {
                model: panel.aktivKlemme !== null
                       ? klemmenreiheModel.stegbruecken.filter(function(s) {
                             return s.vonKlemmeId === panel.aktivKlemme.klemmeId
                                 || s.bisKlemmeId === panel.aktivKlemme.klemmeId
                         })
                       : []
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Rectangle {
                        width: 30; height: 16; radius: 2
                        color: modelData.hatKonflikt ? "#7a2020" : "#4a7a9b"; opacity: 0.85
                        Text { anchors.centerIn: parent; text: "Eb." + modelData.ebene; font.pixelSize: 8; color: "white" }
                    }
                    Text {
                        text: modelData.vonNummer + "–" + modelData.bisNummer
                              + (modelData.potenzialText ? "  " + modelData.potenzialText : "")
                        font.pixelSize: 11; color: theme.textMuted; Layout.fillWidth: true; wrapMode: Text.Wrap
                    }
                }
            }

            // Platzierte Klemmen synchronisieren
            Item { height: 8 }
            Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }
            Button {
                Layout.fillWidth: true
                implicitHeight: 28
                text: qsTr("Platzierte Klemmen synchronisieren")
                contentItem: Text {
                    text: parent.text; font.pixelSize: 11; color: theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? theme.accent : theme.inputBg
                    border.color: theme.accent; border.width: 1; radius: 4
                }
                ToolTip.visible: hovered; ToolTip.delay: 500
                ToolTip.text: qsTr("Bauteil-Artikel aller platzierten Klemmenanschlüsse\ndieser Leiste auf die aktuelle Zuweisung aktualisieren.\nNötig wenn ein Bauteil nach dem Platzieren gewechselt wurde.")
                onClicked: {
                    var n = klemmenreiheModel.leisteKanvasAktualisieren()
                    if (n < 0) {
                        meldungManager.zeigen(qsTr("Fehler beim Aktualisieren der platzierten Klemmen."), false)
                    } else if (n === 0) {
                        meldungManager.zeigen(qsTr("Keine platzierten Anschlüsse dieser Leiste gefunden."), true)
                    } else {
                        meldungManager.zeigen(qsTr("%1 Klemmenanschluss/-anschlüsse auf neues Bauteil aktualisiert.").arg(n), true)
                        root.leisteKanvasAktualisiert()
                    }
                }
            }

            // Leiste löschen
            Item { height: 8 }
            Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }
            Button {
                Layout.fillWidth: true
                implicitHeight: 28
                text: qsTr("Klemmenleiste löschen")
                contentItem: Text {
                    text: parent.text; font.pixelSize: 11; color: "#e05050"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? "#3a1010" : "transparent"; border.color: "#7a3030"; border.width: 1; radius: 4
                }
                ToolTip.visible: hovered; ToolTip.delay: 500
                ToolTip.text: qsTr("Diese Klemmenleiste mit allen Klemmen unwiderruflich löschen")
                onClicked: {
                    klemmenleistenModel.loeschen(panel.aktivLeistenId)
                    panel.aktivLeistenId = -1
                    panel.aktivKlemmeIdx = -1
                    root.leisteGeloescht()
                }
            }
            Item { height: 4 }
        }
    }
}
