import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Vorlagenbibliothek (BLATTVORLAGEN-03): app-weite Quelle für Blattvorlagen. Das Projekt hält immer eine eigene
// Kopie; hier wird ausdrücklich abgeglichen (kein stilles Überschreiben).
Popup {
    id: root

    required property var theme
    property var vorlage: null            // aktuell gewählte Projektvorlage (Map aus normblattVorlagenListe) oder null

    // Der Editor schreibt seine ungespeicherten Felder in die DB, bevor die Bibliothek sie liest.
    signal speichernAngefordert()
    // Projektvorlagen haben sich geändert; waehleId = danach zu wählende Vorlage
    signal vorlagenGeaendert(int waehleId)

    property var    _bib: []
    property var    _status: ({ status: "lokal" })
    property bool   _aktualisierenBestaetigen: false
    property string _loeschenUid: ""

    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 20
    width: 560
    height: Math.min(520, implicitHeight)
    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; radius: 6 }

    function oeffnen() { _neuLesen(); open() }

    function _neuLesen() {
        _aktualisierenBestaetigen = false
        _loeschenUid = ""
        _bib = db.vorlagenBibliothekListe()
        _status = vorlage ? db.vorlageBibliothekStatus(vorlage.id) : ({ status: "lokal" })
    }

    function _statusText() {
        switch (_status.status) {
        case "aktuell":          return qsTr("Verknüpft mit „%1“ – Stand identisch.").arg(_status.bibliothekName)
        case "bibliothekNeuer":  return qsTr("Die Bibliothek hat eine neuere Version von „%1“ (v%2, hier v%3).")
                                         .arg(_status.bibliothekName).arg(_status.bibliothekVersion).arg(_status.projektVersion)
        case "lokalGeaendert":   return qsTr("Verknüpft mit „%1“ – hier geändert, Bibliothek unverändert.").arg(_status.bibliothekName)
        case "beides":           return qsTr("Verknüpft mit „%1“ – hier geändert UND die Bibliothek hat eine neuere Version.")
                                         .arg(_status.bibliothekName)
        case "bibliothekFehlt":  return qsTr("Die verknüpfte Vorlage gibt es in der Bibliothek nicht mehr.")
        default:                 return qsTr("Diese Vorlage ist nur in diesem Projekt vorhanden.")
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        Text { text: qsTr("Vorlagenbibliothek"); color: root.theme.textPrimary; font.pixelSize: 15; font.bold: true }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: qsTr("Die Bibliothek gilt für alle Projekte auf diesem Rechner. Ein Projekt arbeitet immer mit seiner eigenen Kopie; "
                       + "Änderungen übernimmst du hier ausdrücklich.")
            color: root.theme.textMuted; font.pixelSize: 11
        }

        // ── aktuelle Vorlage ─────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            visible: root.vorlage !== null
            color: root.theme.inputBg; border.color: root.theme.border; radius: 5
            implicitHeight: aktuellCol.implicitHeight + 20

            ColumnLayout {
                id: aktuellCol
                anchors { fill: parent; margins: 10 }
                spacing: 8
                Text {
                    text: root.vorlage ? root.vorlage.name : ""
                    color: root.theme.textPrimary; font.pixelSize: 13; font.bold: true
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: root._statusText()
                    color: root._status.status === "beides" || root._status.status === "bibliothekFehlt"
                           ? "#e0a050" : root.theme.textMuted
                    font.pixelSize: 11
                }
                RowLayout {
                    spacing: 8
                    Button {
                        text: root._status.status === "lokal" || root._status.status === "bibliothekFehlt"
                              ? qsTr("In Bibliothek speichern") : qsTr("Bibliothek aktualisieren")
                        onClicked: {
                            root.speichernAngefordert()
                            var uid = db.vorlageInBibliothekSpeichern(root.vorlage.id)
                            if (uid === "") {
                                meldungManager.zeigen(qsTr("In Bibliothek speichern fehlgeschlagen"), false)
                                return
                            }
                            meldungManager.zeigen(qsTr("In der Bibliothek gespeichert."), true)
                            root.vorlagenGeaendert(root.vorlage.id)
                            root._neuLesen()
                        }
                    }
                    Button {
                        visible: root._status.status === "bibliothekNeuer" || root._status.status === "beides"
                        text: root._aktualisierenBestaetigen ? qsTr("Wirklich? Lokale Änderungen gehen verloren")
                              : root._status.status === "beides" ? qsTr("Aus Bibliothek aktualisieren …")
                              : qsTr("Aus Bibliothek aktualisieren")
                        onClicked: {
                            if (root._status.status === "beides" && !root._aktualisierenBestaetigen) {
                                root._aktualisierenBestaetigen = true
                                return
                            }
                            if (db.vorlageAusBibliothekAktualisieren(root.vorlage.id)) {
                                meldungManager.zeigen(qsTr("Vorlage aus der Bibliothek aktualisiert."), true)
                                root.vorlagenGeaendert(root.vorlage.id)
                            } else {
                                meldungManager.zeigen(qsTr("Aktualisieren fehlgeschlagen"), false)
                            }
                            root._neuLesen()
                        }
                    }
                }
            }
        }

        // ── Bibliotheksliste ─────────────────────────────────
        Text {
            text: qsTr("IN DER BIBLIOTHEK (%1)").arg(root._bib.length)
            color: root.theme.borderLight; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
        }
        Text {
            visible: root._bib.length === 0
            text: qsTr("Noch keine Vorlage in der Bibliothek. Wähle eine Projektvorlage und speichere sie hier.")
            color: root.theme.textMuted; font.pixelSize: 11
            Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
        ListView {
            id: liste
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 220)
            visible: root._bib.length > 0
            clip: true
            spacing: 6
            model: root._bib
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 50; radius: 5
                color: root.theme.inputBg; border.color: root.theme.border

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text {
                            text: modelData.name
                            color: root.theme.textPrimary; font.pixelSize: 12; font.bold: true
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: (modelData.art === "deckblatt" ? qsTr("Deckblatt") : qsTr("Schriftfeld"))
                                  + qsTr(" · %1×%2 mm · %3 Felder · v%4")
                                    .arg(Math.round(modelData.breiteMm)).arg(Math.round(modelData.hoeheMm))
                                    .arg(modelData.felder).arg(modelData.version)
                                  + (modelData.hatLogo ? qsTr(" · Logo") : "")
                            color: root.theme.textMuted; font.pixelSize: 10
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                    Button {
                        text: modelData.imProjekt > 0 ? qsTr("im Projekt") : qsTr("Übernehmen")
                        enabled: modelData.imProjekt === 0
                        onClicked: {
                            var id = db.vorlageAusBibliothekUebernehmen(modelData.uid)
                            if (id > 0) {
                                meldungManager.zeigen(qsTr("Vorlage ins Projekt übernommen."), true)
                                root.vorlagenGeaendert(id)
                                root.close()
                            } else {
                                meldungManager.zeigen(qsTr("Übernehmen fehlgeschlagen"), false)
                            }
                        }
                    }
                    Button {
                        text: root._loeschenUid === modelData.uid ? qsTr("Wirklich löschen?") : "✕"
                        ToolTip.visible: hovered; ToolTip.delay: 600
                        ToolTip.text: qsTr("Aus der Bibliothek löschen (Projektkopien bleiben bestehen)")
                        onClicked: {
                            if (root._loeschenUid !== modelData.uid) { root._loeschenUid = modelData.uid; return }
                            db.vorlageAusBibliothekLoeschen(modelData.uid)
                            root._neuLesen()
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Button { text: qsTr("Schließen"); onClicked: root.close() }
        }
    }
}
