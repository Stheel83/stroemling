import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// VERT-04 (konzept/features/55 §4.3): Overlay einer IBN-Kopie in die Hauptkopie importieren.
// Ablauf: Datei waehlen -> Analyse (ohne Schreiben) -> Konflikte entscheiden -> Importieren.
Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  640
    padding: 20

    required property var theme

    property int    _schritt:   0          // 0 Auswahl, 1 Analyse, 2 Ergebnis
    property var    _dateien:   []
    property string _pfad:      ""
    property var    _analyse:   ({})
    property var    _wahl:      ({})       // konflikt-key -> "kopie" | "haupt"
    property var    _ergebnis:  ({})
    property string _fehler:    ""

    title: qsTr("Overlay importieren")

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border
        border.width: 1; radius: 6
    }

    function _zustandText(z) {
        if (!z) return ""
        if (z.istBefund) {   // FS-IBN-03: Befund statt IBN-Stand
            var b = z.status === "behoben" ? qsTr("Behoben") : z.status === "kein_fehler" ? qsTr("Kein Fehler") : qsTr("Offen")
            if (z.gefundenVon) b += " · " + z.gefundenVon
            if (z.gefundenAm)  b += " · " + z.gefundenAm
            if (z.text)        b += " · „" + z.text + "“"
            if (z.geaendertAm) b += "\n" + qsTr("geändert %1").arg(z.geaendertAm)
            return b
        }
        var t = z.status === "abgeschlossen" ? qsTr("✓ Fertig") : z.status === "in_arbeit" ? qsTr("In Arbeit") : qsTr("Offen")
        if (z.geprueftVon) t += " · " + z.geprueftVon
        if (z.geprueftAm)  t += " · " + z.geprueftAm
        if (z.notiz)       t += " · „" + z.notiz + "“"
        if (z.geaendertAm) t += "\n" + qsTr("geändert %1").arg(z.geaendertAm)
        return t
    }

    function _setWahl(key, wert) {
        var w = root._wahl
        w[key] = wert
        root._wahl = w
        root._wahlVersion++
    }
    property int _wahlVersion: 0

    function _alleSetzen(modus) {
        var k = root._analyse.konflikte || []
        var w = {}
        for (var i = 0; i < k.length; i++) {
            if (modus === "neuester")
                w[k[i].key] = (k[i].kopie.geaendertAm > k[i].haupt.geaendertAm) ? "kopie" : "haupt"
            else
                w[k[i].key] = modus
        }
        root._wahl = w
        root._wahlVersion++
    }

    function _analysieren(pfad) {
        root._fehler = ""
        var a = db.ibnOverlayPruefen(pfad)
        if (!a.ok) { root._fehler = a.fehler; return }
        root._pfad = pfad
        root._analyse = a
        root._alleSetzen("haupt")          // Vorgabe: Hauptkopie behalten
        root._schritt = 1
    }

    onAboutToShow: {
        _schritt = 0; _fehler = ""; _pfad = ""; _analyse = ({}); _ergebnis = ({})
        _dateien = db.ibnOverlayDateienFinden()
        tfPfad.text = ""
    }

    contentItem: ColumnLayout {
        spacing: 10

        // ── Schritt 0: Auswahl ─────────────────────────────
        ColumnLayout {
            visible: root._schritt === 0
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: qsTr("Gefundene Overlays (Ordner ibn_kopien/ im Projektordner)")
                font.pixelSize: 12; font.weight: Font.Medium; color: root.theme.textPrimary
            }
            Text {
                visible: root._dateien.length === 0
                text: qsTr("Keine Overlay-Dateien gefunden. Pfad unten eintragen.")
                font.pixelSize: 11; color: root.theme.textMuted
            }
            ListView {
                visible: root._dateien.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 160)
                clip: true; spacing: 4
                model: root._dateien
                delegate: Rectangle {
                    width: ListView.view.width; height: 34; radius: 4
                    color: ma.containsMouse ? root.theme.hover : root.theme.inputBg
                    border.color: root.theme.border
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        Text { text: modelData.name; font.pixelSize: 12; color: root.theme.textPrimary
                            Layout.fillWidth: true; elide: Text.ElideMiddle }
                        Text { text: modelData.geaendert; font.pixelSize: 10; color: root.theme.textMuted }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._analysieren(modelData.pfad) }
                }
            }

            Text { text: qsTr("Oder Pfad der Overlay-Datei"); font.pixelSize: 11; color: root.theme.textSecondary }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                TextField {
                    id: tfPfad
                    Layout.fillWidth: true; implicitHeight: 30
                    color: root.theme.textPrimary; font.pixelSize: 12
                    placeholderText: "/pfad/zur/datei.strl-overlay"
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    onAccepted: if (text.trim() !== "") root._analysieren(text.trim())
                }
                Button {
                    text: qsTr("Analysieren"); implicitHeight: 30
                    enabled: tfPfad.text.trim() !== ""
                    contentItem: Text { text: parent.text
                        color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.enabled && parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border }
                    onClicked: root._analysieren(tfPfad.text.trim())
                }
            }
        }

        // ── Schritt 1: Analyse ─────────────────────────────
        ColumnLayout {
            visible: root._schritt === 1
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 12; font.weight: Font.Medium; color: root.theme.textPrimary
                text: qsTr("Kopie „%1“ · Durchgang %2").arg((root._analyse.kopie || {}).name || "")
                      .arg(root._analyse.durchgangNr || 1)
            }
            Repeater {
                model: root._analyse.warnungen || []
                delegate: Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    font.pixelSize: 11; color: "#e0a040"; text: "⚠ " + modelData
                }
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 11; color: root.theme.textSecondary
                text: qsTr("%1 Einträge werden übernommen · %2 unverändert · %3 Konflikt(e) · %4 nicht zuordenbar")
                      .arg(root._analyse.uebernehmen || 0).arg(root._analyse.unveraendert || 0)
                      .arg((root._analyse.konflikte || []).length)
                      .arg((root._analyse.nichtZuordenbar || []).length)
                      + ((root._analyse.anzahlBefunde || 0) > 0
                         ? "\n" + qsTr("Das Overlay enthält %1 Befund(e) der Fehlersuche.").arg(root._analyse.anzahlBefunde) : "")
            }
            Text {
                visible: (root._analyse.befundeOhneZuordnung || []).length > 0
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 11; color: "#e0a040"
                text: qsTr("%1 Befund(e) lassen sich keiner Seite mehr zuordnen. Sie werden trotzdem übernommen und mit ihrem alten Schlüssel angezeigt:\n%2")
                      .arg((root._analyse.befundeOhneZuordnung || []).length)
                      .arg((root._analyse.befundeOhneZuordnung || []).map(function(e) { return "• " + e.label }).join("\n"))
            }

            // Konflikte
            RowLayout {
                visible: (root._analyse.konflikte || []).length > 0
                Layout.fillWidth: true; spacing: 6
                Text { text: qsTr("Konflikte"); font.pixelSize: 12; font.weight: Font.Medium
                    color: root.theme.textPrimary; Layout.fillWidth: true }
                Repeater {
                    model: [ { m: "neuester", t: qsTr("Neuester gewinnt") },
                             { m: "kopie",    t: qsTr("Alle: Kopie") },
                             { m: "haupt",    t: qsTr("Alle: Hauptkopie") } ]
                    delegate: Button {
                        flat: true; implicitHeight: 24
                        contentItem: Text { text: modelData.t; color: root.theme.textSecondary; font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"
                            radius: 4; border.color: root.theme.border }
                        onClicked: root._alleSetzen(modelData.m)
                    }
                }
            }
            ListView {
                visible: (root._analyse.konflikte || []).length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 220)
                clip: true; spacing: 6
                model: root._analyse.konflikte || []
                delegate: Rectangle {
                    width: ListView.view.width; height: 96; radius: 4
                    color: root.theme.inputBg; border.color: root.theme.border
                    ColumnLayout {
                        anchors { fill: parent; margins: 8 }
                        spacing: 4
                        Text { text: modelData.label; font.pixelSize: 12; color: root.theme.textPrimary
                            elide: Text.ElideMiddle; Layout.fillWidth: true }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { Layout.fillWidth: true; Layout.preferredWidth: 1
                                font.pixelSize: 10; color: root.theme.textSecondary; wrapMode: Text.WordWrap
                                text: qsTr("Hauptkopie: ") + root._zustandText(modelData.haupt) }
                            Text { Layout.fillWidth: true; Layout.preferredWidth: 1
                                font.pixelSize: 10; color: root.theme.textSecondary; wrapMode: Text.WordWrap
                                text: qsTr("Kopie: ") + root._zustandText(modelData.kopie) }
                            ComboBox {
                                Layout.preferredWidth: 150; implicitHeight: 26
                                model: [qsTr("Hauptkopie behalten"), qsTr("Kopie übernehmen")]
                                currentIndex: { root._wahlVersion; return root._wahl[modelData.key] === "kopie" ? 1 : 0 }
                                onActivated: function(i) { root._setWahl(modelData.key, i === 1 ? "kopie" : "haupt") }
                                background: Rectangle { color: root.theme.sidebar; radius: 4; border.color: root.theme.border }
                                contentItem: Text { leftPadding: 6; text: parent.displayText
                                    color: root.theme.textPrimary; font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }
            }

            // Nicht zuordenbar / ausserhalb
            Text {
                visible: (root._analyse.nichtZuordenbar || []).length > 0
                text: qsTr("Nicht zuordenbar (werden nicht importiert)")
                font.pixelSize: 12; font.weight: Font.Medium; color: "#e0a040"
            }
            Repeater {
                model: root._analyse.nichtZuordenbar || []
                delegate: Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    font.pixelSize: 11; color: root.theme.textSecondary
                    text: "• " + modelData.label + " – " + modelData.grund
                }
            }
            Text {
                visible: (root._analyse.ausserhalbBereich || []).length > 0
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 11; color: "#e0a040"
                text: qsTr("%1 Eintrag/Einträge liegen außerhalb des Bereichs der Kopie und werden nicht importiert.")
                      .arg((root._analyse.ausserhalbBereich || []).length)
            }
        }

        // ── Schritt 2: Ergebnis ────────────────────────────
        ColumnLayout {
            visible: root._schritt === 2
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 12; color: "#44aa66"
                text: qsTr("Import abgeschlossen: %1 Einträge übernommen (%2 Konflikte zugunsten der Kopie, %3 zugunsten der Hauptkopie), %4 unverändert. Die Kopie gilt jetzt als eingesammelt.")
                      .arg(root._ergebnis.uebernommen || 0).arg(root._ergebnis.konfliktKopie || 0)
                      .arg(root._ergebnis.konfliktHaupt || 0).arg(root._ergebnis.unveraendert || 0)
            }
            Text {
                visible: (root._ergebnis.befundeOhneZuordnung || []).length > 0
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 11; color: "#e0a040"
                text: qsTr("%1 Befund(e) wurden ohne Seitenzuordnung übernommen (in der Befundliste der Fehlersuche zu finden).")
                      .arg((root._ergebnis.befundeOhneZuordnung || []).length)
            }
            Text {
                visible: (root._ergebnis.nichtZuordenbar || []).length > 0
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 11; color: "#e0a040"
                text: qsTr("%1 Eintrag/Einträge waren nicht zuordenbar und wurden nicht übernommen.")
                      .arg((root._ergebnis.nichtZuordenbar || []).length)
            }
        }

        Text {
            visible: root._fehler !== ""
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            font.pixelSize: 11; color: "#e04040"; text: root._fehler
        }

        // ── Schaltflaechen ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                visible: root._schritt === 1
                text: qsTr("Zurück"); flat: true; implicitHeight: 32
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border }
                onClicked: root._schritt = 0
            }
            Button {
                text: root._schritt === 2 ? qsTr("Schließen") : qsTr("Abbrechen")
                flat: true; implicitHeight: 32
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }
            Button {
                visible: root._schritt === 1
                text: qsTr("Importieren"); implicitHeight: 32
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.accent : root.theme.inputBg
                    radius: 4; border.color: root.theme.accent }
                onClicked: {
                    root._fehler = ""
                    var r = db.ibnOverlayImportieren(root._pfad, root._wahl, false)
                    if (!r.ok) { root._fehler = r.fehler; return }
                    root._ergebnis = r
                    root._schritt = 2
                }
            }
        }
    }
}
