import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

// ============================================================
// AderzuordnungDialog – für jeden Kreuzungspunkt der Kabellinie
// (in räumlicher Reihenfolge) die zugehörige Ader auswählen.
//
// Perspektive: Verbindung → Ader  (nicht Ader → Verbindung)
// Zeilen = Kreuzungspunkte (Position 1, 2, 3 …)
// Dropdown je Zeile = Ader auswählen (Ader 1 / Ader 2 / …)
// ============================================================

Dialog {
    id: root

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 580
    padding: 20

    required property var theme
    property bool   debug:             false
    property bool   _debugLokal:       false
    property int    kabelId:           0
    property string kabelBezeichnung:  ""
    property string kabeltyp:          ""
    property int    aderzahl:          0    // Fallback wenn adern leer
    // Grafik-Element-ID der spezifischen Kabellinie, der die Adern zugeordnet werden
    property int    kabellinieGrafikElementId: 0

    // Eingabedaten – vor open() setzen
    property var    adern:        []   // [{aderNr, farbe, bezeichnung, verbindungId}]
    property var    schnittNetze: []   // [{netKey, verbindungId, bezeichnung, signaltyp}] sortiert nach t

    // Modus: 0=Reihenfolge, 1=Signalname, 2=Manuell, 3=Pin-Nummer
    property int modus: 0

    // netKey → anschlusskennzeichnung des Geräte-Pins am Ende des Netzes
    // (wird aus SchaltplanCanvas befüllt, bevor der Dialog geöffnet wird)
    property var pinNummernMap: ({})

    // _auswahl[i] = Ader-Index + 1 (1-basiert in _effektiveAdern(); 0 = keine)
    // für Kreuzungspunkt i (Index in schnittNetze)
    property var _auswahl: []

    // _gespeichert[i]: gespeicherter Zustand beim Öffnen (read-only Referenz, ändert sich nicht)
    property var _gespeichert: []

    // netKey → aderNr-Zuordnung aus el.extraDaten (zuverlässiger als verbindungId-Matching)
    property var aderZuordnung: ({})

    // Wird nach Übernehmen ausgesendet damit SchaltplanCanvas extraDaten aktualisieren kann
    signal zuordnungGespeichert(var netKeyMap)

    // ─── Hilfsfunktionen ─────────────────────────────────────

    function _effektiveAdern() {
        if (root.adern.length > 0) {
            var eigeneGeid = root.kabellinieGrafikElementId
            return root.adern.filter(function(ad) {
                var geid = ad.kabellinieGrafikElementId || 0
                return geid === 0 || geid === eigeneGeid
            })
        }
        // Fallback: aderzahl, sonst mindestens so viele wie Kreuzungspunkte vorhanden
        var count = root.aderzahl > 0 ? root.aderzahl : root.schnittNetze.length
        var result = []
        for (var i = 0; i < count; i++)
            result.push({ aderNr: i + 1, farbe: "", bezeichnung: "", verbindungId: 0 })
        return result
    }

    function iecFarbe(code) {
        var m = {
            "BK": "#1a1a1a", "BN": "#7B3F00", "RD": "#CC0000", "OG": "#FF7700",
            "YE": "#CCCC00", "GN": "#006600", "BU": "#0044AA", "VT": "#660099",
            "GY": "#777777", "WH": "#CCCCCC", "PK": "#FF99BB", "GNYE": "#447700"
        }
        return m[code] || "#888888"
    }

    // Optionen für das Ader-Dropdown: ["– keine –", "Ader 1  BN  L", …]
    function _aderOptionen() {
        var opts = [qsTr("– keine –")]
        var ef = root._effektiveAdern()
        for (var i = 0; i < ef.length; i++) {
            var ad  = ef[i]
            var lbl = qsTr("Ader") + " " + ad.aderNr
            if (ad.farbe)       lbl += "  " + ad.farbe
            if (ad.bezeichnung) lbl += "  " + ad.bezeichnung
            opts.push(lbl)
        }
        return opts
    }

    // Farbe der i-ten Dropdown-Option (0 = keine)
    function _aderFarbe(optionIndex) {
        if (optionIndex <= 0) return "#888888"
        var ef = root._effektiveAdern()
        var j  = optionIndex - 1
        return (j < ef.length && ef[j].farbe) ? root.iecFarbe(ef[j].farbe) : "#888888"
    }

    function _aderHatFarbe(optionIndex) {
        if (optionIndex <= 0) return false
        var ef = root._effektiveAdern()
        var j  = optionIndex - 1
        return j < ef.length && ef[j].farbe !== ""
    }

    // Anzeigetext für den gespeicherten Zustand an Position i
    function _gespeichertLabel(i) {
        var idx = (i < root._gespeichert.length) ? root._gespeichert[i] : 0
        if (idx <= 0) return "–"
        var ef = root._effektiveAdern()
        var j  = idx - 1
        if (j >= ef.length) return "–"
        var ad  = ef[j]
        if (!ad) return "–"
        var txt = qsTr("Ader") + " " + ad.aderNr
        if (ad.farbe)       txt += "  " + ad.farbe
        if (ad.bezeichnung) txt += "  " + ad.bezeichnung
        return txt
    }

    // Initialzustand laden: primär via aderKey (lokal, NETZ-02), dann netKey
    // (NETZ-01, ganzes Potenzial-Netz), dann legacyNetKey (positionsbasiert)
    // als ältere Übergangs-Fallbacks, zuletzt Fallback via verbindungId
    function _initialisieren() {
        var ef = root._effektiveAdern()
        var a  = []
        for (var i = 0; i < root.schnittNetze.length; i++) {
            var nkAder = root.schnittNetze[i].aderKey      || ""
            var nk     = root.schnittNetze[i].netKey       || ""
            var nkAlt  = root.schnittNetze[i].legacyNetKey || ""
            var found = 0

            // 1) Primär: aderKey (lokal) → netKey (ganzes Netz) → legacyNetKey
            //    (positionsbasiert) → aderNr aus aderZuordnung (in extraDaten
            //    gespeichert). Die zwei älteren Stufen sind Übergangshilfen
            //    für Zuordnungen, die noch unter einem älteren Key-Format
            //    gespeichert sind.
            var nkTreffer = (nkAder && root.aderZuordnung[nkAder] !== undefined) ? nkAder
                          : (nk     && root.aderZuordnung[nk]     !== undefined) ? nk
                          : (nkAlt  && root.aderZuordnung[nkAlt]  !== undefined) ? nkAlt : ""
            if (nkTreffer) {
                var zielNr = root.aderZuordnung[nkTreffer]
                for (var j = 0; j < ef.length; j++) {
                    var nr = ef[j].aderNr !== undefined ? ef[j].aderNr : (j + 1)
                    if (nr === zielNr) { found = j + 1; break }
                }
            }

            // 2) Fallback: verbindungId-Matching (falls aderZuordnung noch nicht existiert)
            if (!found) {
                var vId = root.schnittNetze[i].verbindungId || 0
                if (vId > 0) {
                    for (var j = 0; j < ef.length; j++) {
                        if ((ef[j].verbindungId || 0) === vId) { found = j + 1; break }
                    }
                }
            }

            a.push(found)
        }
        root._auswahl     = a
        root._gespeichert = a.slice()
        _modelNeuAufbauen()
    }

    function _modelNeuAufbauen() {
        schnittModel.clear()
        for (var i = 0; i < root.schnittNetze.length; i++) {
            var n = root.schnittNetze[i]
            schnittModel.append({
                position:    i + 1,
                bezeichnung: n.bezeichnung || ((n.aderKey || n.netKey) ? (n.aderKey || n.netKey).substring(0, 16) : "?"),
                signaltyp:   n.signaltyp   || ""
            })
        }
    }

    function automatischZuordnen() {
        var n  = root.schnittNetze.length
        var ef = root._effektiveAdern()
        var a  = []
        for (var k = 0; k < n; k++) a.push(0)

        if (root.modus === 0) {
            // Reihenfolge: Kreuzungspunkt i → Ader i (1-basiert)
            for (var i = 0; i < n; i++)
                a[i] = (i < ef.length) ? (i + 1) : 0

        } else if (root.modus === 1) {
            // Signalname: Verbindungsbezeichnung mit Aderbezeichnung abgleichen
            for (var i = 0; i < n; i++) {
                var nb    = root.schnittNetze[i].bezeichnung || ""
                var found = 0
                if (!nb) { a[i] = 0; continue }
                // 1) Exakter Treffer
                for (var j = 0; j < ef.length; j++) {
                    if ((ef[j].bezeichnung || "") === nb) { found = j + 1; break }
                }
                // 2) Aderbezeichnung ist Präfix des Verbindungsnamens (z.B. "L" in "L1")
                if (!found) {
                    for (var j = 0; j < ef.length; j++) {
                        var ab = ef[j].bezeichnung || ""
                        if (ab && nb.indexOf(ab) === 0) { found = j + 1; break }
                    }
                }
                a[i] = found
            }
        } else if (root.modus === 2) {
            // Pin-Nummer: Geräte-Pin am Netzende gibt die Adernummer vor
            for (var i = 0; i < n; i++) {
                var nk    = root.schnittNetze[i].netKey || ""
                var pinNr = nk ? (root.pinNummernMap[nk] || "") : ""
                var found = 0
                if (pinNr) {
                    for (var j = 0; j < ef.length; j++) {
                        if ((ef[j].bezeichnung || "") === pinNr) { found = j + 1; break }
                    }
                }
                a[i] = found
            }
        }

        root._auswahl = a
        _modelNeuAufbauen()
    }

    // ─── Modell ──────────────────────────────────────────────

    ListModel { id: schnittModel }

    // ─── Aussehen ────────────────────────────────────────────

    background: Rectangle {
        color:        theme.sidebar
        border.color: theme.border
        border.width: 1; radius: 6
    }

    contentItem: ColumnLayout {
        spacing: 10

        // Titel
        Text {
            text: {
                var t = root.kabelBezeichnung
                if (root.kabeltyp) t += "  " + root.kabeltyp
                return t || qsTr("Aderzuordnung")
            }
            color: theme.accent
            font.pixelSize: 13; font.weight: Font.Medium
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // Modus + Auto-Button
        RowLayout {
            Layout.fillWidth: true; spacing: 10

            Text {
                text: qsTr("Modus:")
                color: theme.textMuted; font.pixelSize: 11
            }

            Repeater {
                model: [qsTr("Reihenfolge"), qsTr("Signalname"), qsTr("Pin-Nummer"), qsTr("Manuell")]
                RadioButton {
                    checked: root.modus === index
                    onClicked: root.modus = index
                    contentItem: Text {
                        text: modelData
                        color: theme.textPrimary; font.pixelSize: 11
                        leftPadding: parent.indicator ? (parent.indicator.width + 4) : 20
                        verticalAlignment: Text.AlignVCenter
                    }
                    indicator: Rectangle {
                        implicitWidth: 14; implicitHeight: 14
                        x: parent.leftPadding; y: (parent.height - height) / 2
                        radius: 7
                        color:        parent.checked ? theme.accent   : "transparent"
                        border.color: parent.checked ? theme.accent   : theme.border
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                visible: root.modus !== 3
                text: qsTr("Automatisch ▶")
                flat: true; implicitHeight: 26
                contentItem: Text {
                    text: parent.text; color: theme.textPrimary
                    font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color:        parent.hovered ? theme.hover : theme.inputBg
                    radius: 4; border.color: theme.border
                }
                onClicked: root.automatischZuordnen()
            }
        }

        // Tabellen-Kopfzeile
        Rectangle {
            Layout.fillWidth: true; height: 24
            color: theme.hover; radius: 3
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 6
                Text { text: qsTr("Pos.");             width: 32;  color: theme.textMuted; font.pixelSize: 10 }
                Text { text: qsTr("Verbindung (Netz)");width: 130; color: theme.textMuted; font.pixelSize: 10 }
                Text { text: qsTr("Aktuell");          width: 110; color: theme.textMuted; font.pixelSize: 10 }
                Text { text: qsTr("Neue Zuweisung");   Layout.fillWidth: true; color: theme.textMuted; font.pixelSize: 10 }
            }
        }

        // Schnittpunkt-Zeilen
        Column {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: schnittModel

                delegate: Item {
                    width: parent.width
                    height: schnittZeile.implicitHeight + 2

                    RowLayout {
                        id: schnittZeile
                        property int rowIdx: index
                        anchors {
                            left: parent.left; right: parent.right
                            leftMargin: 8; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 6

                        // Position
                        Text {
                            text: model.position
                            width: 32
                            color: theme.textMuted; font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Verbindungsname + Signaltyp
                        Text {
                            width: 130
                            text: {
                                var t = model.bezeichnung
                                if (model.signaltyp && model.signaltyp !== "neutral")
                                    t += "  [" + model.signaltyp + "]"
                                return t
                            }
                            color: theme.textSecondary
                            font.pixelSize: 11; elide: Text.ElideRight
                        }

                        // Aktuell gespeicherte Zuweisung (read-only)
                        Text {
                            width: 110
                            text: root._gespeichertLabel(schnittZeile.rowIdx)
                            color: root._gespeichert[schnittZeile.rowIdx] > 0
                                   ? theme.accent : theme.textMuted
                            font.pixelSize: 10; elide: Text.ElideRight
                            font.italic: root._gespeichert[schnittZeile.rowIdx] <= 0
                        }

                        // Ader-Dropdown
                        ComboBox {
                            id: aderCombo
                            Layout.fillWidth: true
                            rightPadding: 22
                            model: root._aderOptionen()

                            Component.onCompleted:
                                currentIndex = (schnittZeile.rowIdx < root._auswahl.length)
                                              ? root._auswahl[schnittZeile.rowIdx] : 0

                            onCurrentIndexChanged: {
                                if (schnittZeile.rowIdx < root._auswahl.length) {
                                    var tmp = root._auswahl.slice()
                                    tmp[schnittZeile.rowIdx] = currentIndex
                                    root._auswahl = tmp
                                }
                            }

                            contentItem: RowLayout {
                                spacing: 6
                                Item { width: 4; height: 1 }
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    visible: root._aderHatFarbe(aderCombo.currentIndex)
                                    color:   root._aderFarbe(aderCombo.currentIndex)
                                    border.color: "#00000055"; border.width: 1
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Text {
                                    text: aderCombo.displayText
                                    color: theme.textPrimary; font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            indicator: Text {
                                x: aderCombo.width - width - 6
                                y: (aderCombo.height - height) / 2
                                text: "▾"
                                color: theme.textMuted
                                font.pixelSize: 13
                            }

                            background: Rectangle {
                                color:        theme.inputBg; radius: 3
                                border.color: parent.hovered || parent.pressed ? theme.accent : theme.border
                            }

                            popup: Popup {
                                y: aderCombo.height; width: aderCombo.width; padding: 0
                                contentItem: ListView {
                                    id: popupListe
                                    implicitHeight: Math.min(contentHeight, 200)
                                    model: root._aderOptionen()
                                    clip: true
                                    ScrollBar.vertical: ScrollBar {}

                                    delegate: Rectangle {
                                        width: popupListe.width; height: 24
                                        color: aderCombo.currentIndex === index
                                               ? theme.activeItemAlt : theme.inputBg
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                                            spacing: 6
                                            Rectangle {
                                                width: 10; height: 10; radius: 5
                                                visible: root._aderHatFarbe(index)
                                                color:   root._aderFarbe(index)
                                                border.color: "#00000055"; border.width: 1
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                            Text {
                                                text: modelData
                                                color: theme.textSecondary; font.pixelSize: 11
                                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: { aderCombo.currentIndex = index; aderCombo.popup.close() }
                                        }
                                    }
                                }
                                background: Rectangle {
                                    color:        theme.inputBg
                                    border.color: theme.border; radius: 3
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hinweis wenn keine Schnittpunkte
        Text {
            visible: root.schnittNetze.length === 0
            text: qsTr("Keine Verbindungskreuzungen erkannt. Bitte Kabellinie über Auto-Verbindungen ziehen.")
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            color: theme.textMuted; font.pixelSize: 11; font.italic: true
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // Buttons
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 32
                contentItem: Text {
                    text: parent.text; color: theme.textSecondary; font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border
                }
                onClicked: root.reject()
            }
            Button {
                text: qsTr("Übernehmen"); implicitWidth: 110; implicitHeight: 32
                contentItem: Text {
                    text: parent.text; color: theme.textPrimary; font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? theme.accent : theme.inputBg
                    radius: 4; border.color: theme.accent
                }
                onClicked: {
                    var ef          = root._effektiveAdern()
                    var aderVerbMap = {}
                    var netKeyMap   = {}
                    for (var i = 0; i < root.schnittNetze.length; i++) {
                        var wIdx = (i < root._auswahl.length) ? root._auswahl[i] : 0
                        if (wIdx > 0 && (wIdx - 1) < ef.length) {
                            aderVerbMap[wIdx - 1] = root.schnittNetze[i].verbindungId || 0
                            // NETZ-02: bevorzugt lokalen Ader-Schlüssel speichern (überlebt
                            // Topologie-Änderungen anderswo im selben Potenzial-Netz);
                            // nur wenn dafür kein stabiler Punkt existiert, auf die
                            // gröberen Schlüssel zurückfallen.
                            var nk = root.schnittNetze[i].aderKey || root.schnittNetze[i].netKey ||
                                     root.schnittNetze[i].legacyNetKey || ""
                            if (nk) {
                                var aderNr = ef[wIdx - 1].aderNr !== undefined
                                             ? ef[wIdx - 1].aderNr : wIdx
                                netKeyMap[nk] = aderNr
                            }
                        }
                    }
                    for (var j = 0; j < ef.length; j++) {
                        var ad = ef[j]
                        if (j in aderVerbMap) {
                            db.kabelAderZuordnen(root.kabelId, ad.aderNr, ad.farbe, ad.bezeichnung,
                                                 aderVerbMap[j], root.kabellinieGrafikElementId)
                        } else if ((ad.kabellinieGrafikElementId || 0) === root.kabellinieGrafikElementId
                                   && root.kabellinieGrafikElementId > 0) {
                            // War auf dieser Linie, jetzt abgewählt → freigeben
                            db.kabelAderZuordnen(root.kabelId, ad.aderNr, ad.farbe, ad.bezeichnung, 0, 0)
                        }
                        // Freie Adern die nicht ausgewählt wurden: unberührt lassen
                    }
                    root.zuordnungGespeichert(netKeyMap)
                    root.accept()
                }
            }
        }
    }

    onOpened: {
        root.modus = 0
        root._initialisieren()
    }
    onClosed: root._debugLokal = false

    Shortcut {
        sequence: "Ctrl+Shift+D"
        onActivated: root._debugLokal = !root._debugLokal
    }

    DebugLabel {
        parent: root.background
        panelName: qsTr("Aderzuordnung-Dialog")
        visible: (root.debug || root._debugLokal) && root.visible
    }
}
