import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// VERT-02b (konzept/features/55 §4.1a): Kopien-Register der Hauptkopie, neue IBN-Kopie
// erstellen, Schaltplan trotz ausgegebener Kopien freigeben (Override).
Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  560
    padding: 20

    required property var theme
    required property int projektId

    property var    _register: []
    property var    _liste:    []       // IBN-Liste fuer die Bereichsauswahl
    property var    _warnungen: []
    property string _ergebnis: ""
    property string _fehler:   ""

    title: qsTr("IBN-Kopien")

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border
        border.width: 1; radius: 6
    }

    function _bereich() {
        var b = []
        if (cmbAnlage.currentIndex > 0) {
            var e = { "anlage": cmbAnlage.currentText }
            if (cmbOrt.currentIndex > 0) e.ort = cmbOrt.currentText
            b.push(e)
        }
        return b
    }

    function _bereichText(b) {
        if (!b || b.length === 0) return qsTr("ganzes Projekt")
        var t = []
        for (var i = 0; i < b.length; i++)
            t.push([b[i].anlage || "", b[i].ort || "", b[i].seite || ""].filter(function(x){ return x !== "" }).join(" / "))
        return t.join(", ")
    }

    function _anlagen() {
        var m = {}
        for (var i = 0; i < root._liste.length; i++)
            if (root._liste[i].anlageKz) m[root._liste[i].anlageKz] = true
        return [qsTr("Ganzes Projekt")].concat(Object.keys(m).sort())
    }

    function _orte(anlage) {
        var m = {}
        for (var i = 0; i < root._liste.length; i++)
            if (root._liste[i].anlageKz === anlage && root._liste[i].ortKz) m[root._liste[i].ortKz] = true
        return [qsTr("Alle Orte")].concat(Object.keys(m).sort())
    }

    property var _overlayStatus: ({})

    function overlayStatusLaden() {
        root._overlayStatus = db.istIbnKopie ? db.ibnOverlayStatus() : ({})
    }

    // Overlay exportieren und das Ergebnis deutlich melden; bei Auffaelligkeiten bleibt der Dialog offen
    function overlayExportieren() {
        root._fehler = ""; root._ergebnis = ""
        var r = db.ibnOverlayExportieren("")
        if (!r.ok) {
            root._fehler = r.fehler
            meldungManager.zeigen(r.fehler, false)
            if (!root.visible) root.open()
            return
        }
        var summe = r.anzahlBm + r.anzahlKabel
        var t = qsTr("Overlay gespeichert (%1 Betriebsmittel, %2 Kabel): %3").arg(r.anzahlBm).arg(r.anzahlKabel).arg(r.pfad)
        var warn = ""
        if (summe === 0)
            warn = qsTr("Das Overlay enthält keine Prüfdaten – sind in dieser Kopie Einträge gespeichert?")
        if (r.ausserhalb > 0)
            warn += (warn ? "\n" : "") + qsTr("%1 Eintrag/Einträge liegen außerhalb des Bereichs dieser Kopie und wurden NICHT exportiert.").arg(r.ausserhalb)
        root._ergebnis = t
        root._fehler = warn
        root.overlayStatusLaden()
        meldungManager.zeigen(warn ? qsTr("Overlay exportiert – bitte Hinweis beachten.") : qsTr("Overlay exportiert (%1 Einträge).").arg(summe), warn === "")
        if (warn !== "" && !root.visible) root.open()
    }

    function _warnungenAktualisieren() {
        root._warnungen = db.ibnKopiePruefen(root.projektId, root._bereich())
    }

    function _neuLaden() {
        root._register = db.ibnKopieRegisterLaden(root.projektId)
        root._warnungenAktualisieren()
    }

    onAboutToShow: {
        _ergebnis = ""; _fehler = ""
        tfName.text = ""; tfOrdner.text = ""
        _liste = db.ibnListeLaden(root.projektId, -1)
        cmbAnlage.model = _anlagen()
        cmbAnlage.currentIndex = 0
        _neuLaden()
        overlayStatusLaden()
    }

    Connections {
        target: db
        function onIbnKopieChanged() { if (root.visible) { root._neuLaden(); root.overlayStatusLaden() } }
    }

    IbnOverlayImportDialog {
        id: importDialog
        theme: root.theme
    }

    // Rueckfrage fuer den Override
    Dialog {
        id: overrideDialog
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 440
        padding: 20
        title: qsTr("Schaltplan trotzdem bearbeiten?")
        background: Rectangle {
            color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6
        }
        contentItem: ColumnLayout {
            spacing: 12
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 12; color: root.theme.textPrimary
                text: qsTr("Es sind noch %1 IBN-Kopie(n) ausgegeben. Wenn Sie den Schaltplan jetzt ändern, "
                           + "gelten diese Kopien als veraltet; Prüfdaten daraus lassen sich nur noch teilweise "
                           + "zuordnen, und danach sollten neue Kopien erstellt werden.").arg(db.offeneKopien)
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); flat: true; implicitHeight: 32
                    contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                        radius: 4; border.color: root.theme.border }
                    onClicked: overrideDialog.close()
                }
                Button {
                    text: qsTr("Schaltplan freigeben"); implicitHeight: 32
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? "#c0602a" : root.theme.inputBg
                        radius: 4; border.color: "#c0602a" }
                    onClicked: {
                        db.ibnSchaltplanOverride()
                        overrideDialog.close()
                    }
                }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        // ── In einer IBN-Kopie ──────────────────────────────
        Text {
            visible: db.istIbnKopie
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 12; color: root.theme.textPrimary
            text: qsTr("Dies ist die IBN-Kopie „%1“. Der Schaltplan ist gesperrt; Inbetriebnahme und "
                       + "Fehlersuche lassen sich bearbeiten. Kopien können nur in der Hauptkopie erstellt werden.")
                  .arg(db.ibnKopieName)
        }

        // ── Overlay-Export (nur in einer IBN-Kopie) ─────────
        ColumnLayout {
            visible: db.istIbnKopie
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 11; color: root.theme.textSecondary
                text: qsTr("Am Ende der Prüfung das Overlay exportieren und der Hauptkopie übergeben: "
                           + "es enthält nur die Inbetriebnahme-Daten dieser Kopie, nicht den Schaltplan.")
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: (root._overlayStatus.aenderungenSeither || 0) > 0 || (root._overlayStatus.ausserhalb || 0) > 0
                       ? "#e0a040" : root.theme.textSecondary
                text: {
                    var s = root._overlayStatus
                    var t = s.exportiertAm ? qsTr("Letzter Export: %1 (UTC).").arg(s.exportiertAm)
                                           : qsTr("Noch nicht exportiert.")
                    t += " " + qsTr("%1 Eintrag/Einträge im Bereich der Kopie.").arg(s.gesamt || 0)
                    if ((s.aenderungenSeither || 0) > 0)
                        t += " ⚠ " + (s.exportiertAm ? qsTr("%1 Änderung(en) seit dem letzten Export – bitte erneut exportieren.").arg(s.aenderungenSeither)
                                                      : qsTr("Noch nichts exportiert."))
                    if ((s.ausserhalb || 0) > 0)
                        t += " ⚠ " + qsTr("%1 Eintrag/Einträge außerhalb des Bereichs werden nicht exportiert.").arg(s.ausserhalb)
                    return t
                }
            }
            Button {
                text: qsTr("⇪  Overlay exportieren"); implicitHeight: 38
                Layout.fillWidth: true
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13; font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? Qt.lighter(root.theme.accent, 1.15) : root.theme.accent
                    radius: 4 }
                onClicked: root.overlayExportieren()
            }
            Text {
                visible: db.istIbnKopie && root._fehler !== ""
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 11; color: "#e04040"; text: root._fehler
            }
            Text {
                visible: db.istIbnKopie && root._ergebnis !== ""
                Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
                font.pixelSize: 11; color: "#44aa66"; text: root._ergebnis
            }
        }

        // ── Register ────────────────────────────────────────
        Text {
            visible: !db.istIbnKopie
            text: qsTr("Ausgegebene Kopien")
            font.pixelSize: 12; font.weight: Font.Medium; color: root.theme.textPrimary
        }
        Text {
            visible: !db.istIbnKopie && root._register.length === 0
            text: qsTr("Noch keine Kopie erstellt.")
            font.pixelSize: 11; color: root.theme.textMuted
        }
        ListView {
            visible: !db.istIbnKopie && root._register.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 200)
            clip: true
            spacing: 4
            model: root._register
            delegate: Rectangle {
                width: ListView.view.width
                height: 48
                radius: 4
                color: root.theme.inputBg
                border.color: root.theme.border

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: modelData.name + "  ·  R" + modelData.hauptRevision
                                  + "  ·  " + root._bereichText(modelData.bereich)
                            font.pixelSize: 12; color: root.theme.textPrimary
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: qsTr("erstellt %1  ·  %2").arg(modelData.erstelltAm).arg(modelData.dateiname)
                            font.pixelSize: 10; color: root.theme.textMuted
                            elide: Text.ElideMiddle; Layout.fillWidth: true
                        }
                    }
                    Text {
                        visible: modelData.veraltet && modelData.status === "ausgegeben"
                        text: qsTr("veraltet")
                        font.pixelSize: 10; color: "#e0a040"
                    }
                    Text {
                        text: modelData.status === "ausgegeben" ? qsTr("ausgegeben")
                              : modelData.status === "eingesammelt" ? qsTr("✓ eingesammelt")
                                                                      : qsTr("verworfen")
                        font.pixelSize: 11
                        color: modelData.status === "eingesammelt" ? "#44aa66"
                               : modelData.status === "ausgegeben" ? root.theme.accent
                                                                   : root.theme.textMuted
                    }
                    Button {
                        visible: modelData.vorhanden
                        flat: true; implicitHeight: 24; implicitWidth: 56
                        contentItem: Text { text: qsTr("Öffnen"); color: root.theme.accent; font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"
                            radius: 4; border.color: root.theme.accent }
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: qsTr("Diese Kopie öffnen (das aktuelle Projekt wird geschlossen)")
                        onClicked: { var p = modelData.pfad; root.close(); db.openProjekt(p) }
                    }
                    Button {
                        visible: modelData.vorhanden
                        flat: true; implicitHeight: 24; implicitWidth: 56
                        contentItem: Text { text: qsTr("Ordner"); color: root.theme.textSecondary; font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"
                            radius: 4; border.color: root.theme.border }
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: qsTr("Ordner der Kopie im Dateimanager zeigen")
                        onClicked: Qt.openUrlExternally("file://" + modelData.pfad.substring(0, modelData.pfad.lastIndexOf("/")))
                    }
                    Button {
                        visible: modelData.status !== "eingesammelt"
                        flat: true; implicitHeight: 24; implicitWidth: 96
                        contentItem: Text {
                            text: modelData.status === "ausgegeben" ? qsTr("verwerfen") : qsTr("wieder ausgeben")
                            color: root.theme.textSecondary; font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"
                            radius: 4; border.color: root.theme.border }
                        onClicked: db.ibnKopieStatusSetzen(modelData.id,
                                       modelData.status === "ausgegeben" ? "verworfen" : "ausgegeben")
                    }
                }
            }
        }

        // ── Override ────────────────────────────────────────
        RowLayout {
            visible: !db.istIbnKopie && db.offeneKopien > 0 && db.schaltplanGesperrt
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 11; color: root.theme.textSecondary
                text: qsTr("Der Schaltplan ist gesperrt, bis alle Kopien eingesammelt oder verworfen sind.")
            }
            Button {
                text: qsTr("Trotzdem bearbeiten …"); flat: true; implicitHeight: 28
                contentItem: Text { text: parent.text; color: "#e0a040"; font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"
                    radius: 4; border.color: "#e0a040" }
                onClicked: overrideDialog.open()
            }
        }

        Rectangle { visible: !db.istIbnKopie; Layout.fillWidth: true; height: 1; color: root.theme.border }

        // ── Neue Kopie ──────────────────────────────────────
        ColumnLayout {
            visible: !db.istIbnKopie
            Layout.fillWidth: true
            spacing: 8

            Text { text: qsTr("Neue Kopie für die Inbetriebnahme"); font.pixelSize: 12
                font.weight: Font.Medium; color: root.theme.textPrimary }

            Text { text: qsTr("Name (z. B. Abteilung)"); font.pixelSize: 11; color: root.theme.textSecondary }
            TextField {
                id: tfName
                Layout.fillWidth: true; implicitHeight: 30
                color: root.theme.textPrimary; font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
            }

            Text { text: qsTr("Bereich"); font.pixelSize: 11; color: root.theme.textSecondary }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                ComboBox {
                    id: cmbAnlage
                    Layout.fillWidth: true; implicitHeight: 30
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    contentItem: Text { leftPadding: 8; text: cmbAnlage.displayText
                        color: root.theme.textPrimary; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                    onCurrentIndexChanged: {
                        cmbOrt.model = currentIndex > 0 ? root._orte(currentText) : [qsTr("Alle Orte")]
                        cmbOrt.currentIndex = 0
                        root._warnungenAktualisieren()
                    }
                }
                ComboBox {
                    id: cmbOrt
                    Layout.fillWidth: true; implicitHeight: 30
                    enabled: cmbAnlage.currentIndex > 0
                    model: [qsTr("Alle Orte")]
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    contentItem: Text { leftPadding: 8; text: cmbOrt.displayText
                        color: cmbOrt.enabled ? root.theme.textPrimary : root.theme.textMuted
                        font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                    onCurrentIndexChanged: root._warnungenAktualisieren()
                }
            }

            Text { text: qsTr("Zielordner (leer = ibn_kopien/ im Projektordner)")
                font.pixelSize: 11; color: root.theme.textSecondary }
            TextField {
                id: tfOrdner
                Layout.fillWidth: true; implicitHeight: 30
                color: root.theme.textPrimary; font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
            }

            Repeater {
                model: root._warnungen
                delegate: Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11; color: "#e0a040"
                    text: "⚠ " + modelData
                }
            }

            Text {
                visible: root._fehler !== ""
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                font.pixelSize: 11; color: "#e04040"; text: root._fehler
            }
            Text {
                visible: root._ergebnis !== ""
                Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
                font.pixelSize: 11; color: "#44aa66"; text: root._ergebnis
            }
        }

        // ── Schaltflaechen ──────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Schließen"); flat: true; implicitHeight: 32
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }

            Button {
                visible: !db.istIbnKopie
                text: qsTr("Overlay importieren …")
                flat: true; implicitHeight: 32
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border }
                onClicked: importDialog.open()
            }

            Button {
                visible: !db.istIbnKopie
                text: qsTr("Kopie erstellen")
                implicitHeight: 32
                enabled: tfName.text.trim() !== "" && !db.schreibgeschuetzt
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4
                    border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    root._fehler = ""; root._ergebnis = ""
                    var r = db.ibnKopieErstellen(root.projektId, tfName.text.trim(),
                                                 root._bereich(), tfOrdner.text.trim())
                    if (!r.ok) { root._fehler = r.fehler; return }
                    root._ergebnis = qsTr("Kopie erstellt: %1").arg(r.pfad)
                    tfName.text = ""
                    root._neuLaden()
                }
            }
        }
    }
}
