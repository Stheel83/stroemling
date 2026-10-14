import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Normblatt-Einstellungen + Revisionsstatus – eingebettet in dlgSeiteBearbeiten.
ColumnLayout {
    id: root

    required property var theme
    property var _normblattVorlagen: []
    readonly property var _streifenModi: ["auto", "a4", "a3", "a2", "a1", "a0", "canvas", "aus"]

    Layout.fillWidth: true
    spacing: 10

    function laden(seiteId) {
        root._normblattVorlagen = db.normblattVorlagenListe().filter(function(v) { return v.art === "schriftfeld" })
        var nd = db.normblattDatenLaden(seiteId)
        if (nd) {
            chkNormblatt.checked       = nd.normblattAnzeigen === 1 || nd.normblattAnzeigen === true
            chkInDokuPdf.checked       = nd.inDokuPdf === undefined || nd.inDokuPdf === 1 || nd.inDokuPdf === true
            tfHintergrundFarbe.text    = nd.hintergrundFarbe  || ""
            chkAussenOverlay.checked   = nd.aussenOverlay === 1 || nd.aussenOverlay === true
            if (nd.normblattVorlageId) {
                cmbVorlage.currentIndex = 3  // "benutzerdefiniert"
                for (var j = 0; j < root._normblattVorlagen.length; j++) {
                    if (root._normblattVorlagen[j].id === nd.normblattVorlageId) {
                        cmbVorlageAuswahl.currentIndex = j; break
                    }
                }
            } else {
                var vi = cmbVorlage.model.indexOf(nd.titelblattVorlage || "din6771")
                cmbVorlage.currentIndex = vi >= 0 ? vi : 0
            }
            var ri = cmbRevisionStatus.model.indexOf(nd.revisionStatus || "")
            cmbRevisionStatus.currentIndex = ri >= 0 ? ri : 0
            tfRevisionKennung.text = nd.revisionKennung || ""
            var si = root._streifenModi.indexOf(nd.infostreifenModus || "auto")
            cmbInfostreifen.currentIndex = si >= 0 ? si : 0
        }
    }

    function speichern(seiteId) {
        db.normblattEinstellungenSetzen(
            seiteId,
            chkNormblatt.checked,
            tfHintergrundFarbe.text.trim(),
            chkAussenOverlay.checked,
            cmbVorlage.currentText,
            (cmbVorlage.currentText === "benutzerdefiniert"
             && cmbVorlageAuswahl.currentIndex >= 0
             && root._normblattVorlagen.length > 0)
                ? root._normblattVorlagen[cmbVorlageAuswahl.currentIndex].id : -1)
        db.seiteInDokuPdfSetzen(seiteId, chkInDokuPdf.checked)
        db.seiteInfostreifenSetzen(seiteId, root._streifenModi[Math.max(0, cmbInfostreifen.currentIndex)])
        db.seiteRevisionSetzen(
            seiteId,
            cmbRevisionStatus.currentText,
            tfRevisionKennung.text.trim())
    }

    // ── Normblatt-Einstellungen ──────────────────────────────────
    RowLayout {
        Layout.fillWidth: true; Layout.topMargin: 2
        CheckBox {
            id: chkNormblatt
            checked: true
            indicator: Rectangle {
                width: 16; height: 16; radius: 3
                border.color: chkNormblatt.checked ? root.theme.accent : root.theme.border
                color: chkNormblatt.checked ? root.theme.accent : root.theme.inputBg
                Text {
                    anchors.centerIn: parent
                    text: "✓"; color: root.theme.textPrimary
                    font.pixelSize: 11; visible: chkNormblatt.checked
                }
            }
            contentItem: Text {
                text: qsTr("Normblatt anzeigen")
                color: root.theme.textPrimary; font.pixelSize: 13
                leftPadding: chkNormblatt.indicator.width + chkNormblatt.spacing
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // DOKU-PDF-01: dauerhafte Voreinstellung für das Dokumentations-PDF
    RowLayout {
        Layout.fillWidth: true
        CheckBox {
            id: chkInDokuPdf
            checked: true
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Legt fest, ob diese Seite im PDF-Export des Schaltplans enthalten ist. Beim Export kann die Auswahl für den Einzelfall geändert werden.")
            indicator: Rectangle {
                width: 16; height: 16; radius: 3
                border.color: chkInDokuPdf.checked ? root.theme.accent : root.theme.border
                color: chkInDokuPdf.checked ? root.theme.accent : root.theme.inputBg
                Text {
                    anchors.centerIn: parent
                    text: "✓"; color: root.theme.textPrimary
                    font.pixelSize: 11; visible: chkInDokuPdf.checked
                }
            }
            contentItem: Text {
                text: qsTr("In Dokumentations-PDF aufnehmen")
                color: root.theme.textPrimary; font.pixelSize: 13
                leftPadding: chkInDokuPdf.indicator.width + chkInDokuPdf.spacing
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Infostreifen (nur ohne Normblatt): Breite folgt dem Seitenformat oder fest A4…A0 / Gesamtes Canvas / aus
    Text {
        text: qsTr("Infostreifen")
        color: root.theme.textMuted; font.pixelSize: 12
        visible: !chkNormblatt.checked
    }
    ComboBox {
        id: cmbInfostreifen
        Layout.fillWidth: true
        visible: !chkNormblatt.checked
        model: [qsTr("Automatisch (Seitenformat)"), "A4", "A3", "A2", "A1", "A0", qsTr("Gesamtes Canvas"), qsTr("Aus")]
        ToolTip.visible: hovered; ToolTip.delay: 600
        ToolTip.text: qsTr("Streifen mit Projekt-/Blattangaben unter den Elementen (Seiten ohne Schriftfeld). Vorlage: Projektseite → Infostreifen, Gestaltung unter „Blattvorlagen“.")
        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
        contentItem: Text { leftPadding: 8; text: cmbInfostreifen.displayText; color: root.theme.textPrimary
            font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    }

    // Titelblatt-Vorlage (nur wenn Normblatt aktiv)
    Text {
        text: qsTr("Schriftfeld-Vorlage")
        color: root.theme.textMuted; font.pixelSize: 12
        visible: chkNormblatt.checked
    }
    ComboBox {
        id: cmbVorlage
        Layout.fillWidth: true
        visible: chkNormblatt.checked
        model: ["din6771", "kompakt", "rahmen", "benutzerdefiniert"]
        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
        contentItem: Text {
            leftPadding: 8; text: {
                switch(cmbVorlage.currentText) {
                    case "din6771":           return qsTr("DIN 6771 (vollständiges Schriftfeld)")
                    case "kompakt":           return qsTr("Kompakt (2-zeiliges Schriftfeld)")
                    case "rahmen":            return qsTr("Nur Rahmen (kein Schriftfeld)")
                    case "benutzerdefiniert": return qsTr("Benutzerdefiniert …")
                    default:                  return cmbVorlage.currentText
                }
            }
            color: root.theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
        }
        delegate: ItemDelegate {
            width: cmbVorlage.width; implicitHeight: 32
            highlighted: cmbVorlage.highlightedIndex === index
            contentItem: Text {
                leftPadding: 8
                text: {
                    switch(modelData) {
                        case "din6771":           return qsTr("DIN 6771 (vollständiges Schriftfeld)")
                        case "kompakt":           return qsTr("Kompakt (2-zeiliges Schriftfeld)")
                        case "rahmen":            return qsTr("Nur Rahmen (kein Schriftfeld)")
                        case "benutzerdefiniert": return qsTr("Benutzerdefiniert …")
                        default:                  return modelData
                    }
                }
                color: root.theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
        }
    }

    // Benutzerdefinierte Vorlage auswaehlen
    Text {
        text: qsTr("Vorlage auswählen")
        color: root.theme.textMuted; font.pixelSize: 12
        visible: chkNormblatt.checked && cmbVorlage.currentText === "benutzerdefiniert"
        height: visible ? implicitHeight : 0
    }
    ComboBox {
        id: cmbVorlageAuswahl
        Layout.fillWidth: true
        visible: chkNormblatt.checked && cmbVorlage.currentText === "benutzerdefiniert"
                 && root._normblattVorlagen.length > 0
        model: root._normblattVorlagen.map(function(v) {
            return v.name + qsTr(" (%1×%2 mm)").arg(Math.round(v.breiteMm || 297)).arg(Math.round(v.hoeheMm || 210))
        })
        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
        contentItem: Text {
            leftPadding: 8; text: cmbVorlageAuswahl.displayText
            color: root.theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
        }
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: cmbVorlageAuswahl.width; implicitHeight: 32
            highlighted: cmbVorlageAuswahl.highlightedIndex === index
            contentItem: Text {
                leftPadding: 8; text: modelData
                color: root.theme.textPrimary; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
        }
    }
    Text {
        text: qsTr("Keine Vorlagen vorhanden. Über „Blattvorlagen“ in der Seitenleiste anlegen.")
        visible: chkNormblatt.checked && cmbVorlage.currentText === "benutzerdefiniert"
                 && root._normblattVorlagen.length === 0
        color: root.theme.textMuted; font.pixelSize: 11; wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    // Aussen-Overlay Checkbox (nur wenn Normblatt aktiv)
    RowLayout {
        Layout.fillWidth: true
        visible: chkNormblatt.checked
        CheckBox {
            id: chkAussenOverlay
            checked: false
            indicator: Rectangle {
                width: 16; height: 16; radius: 3
                border.color: chkAussenOverlay.checked ? root.theme.accent : root.theme.border
                color: chkAussenOverlay.checked ? root.theme.accent : root.theme.inputBg
                Text {
                    anchors.centerIn: parent
                    text: "✓"; color: root.theme.textPrimary
                    font.pixelSize: 11; visible: chkAussenOverlay.checked
                }
            }
            contentItem: Text {
                text: qsTr("Bereich außerhalb abdunkeln")
                color: root.theme.textPrimary; font.pixelSize: 13
                leftPadding: chkAussenOverlay.indicator.width + chkAussenOverlay.spacing
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Seitenhintergrundfarbe
    Text { text: qsTr("Seitenhintergrund (Farbe)"); color: root.theme.textMuted; font.pixelSize: 12 }
    RowLayout {
        Layout.fillWidth: true; spacing: 6
        TextField {
            id: tfHintergrundFarbe
            Layout.fillWidth: true
            placeholderText: qsTr("leer = transparent, z.B. #ffffff")
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 13
        }
        Rectangle {
            width: 28; height: 28; radius: 4
            color: tfHintergrundFarbe.text.trim() || "transparent"
            border.color: root.theme.border
        }
    }

    // ── Revisionsstatus ──────────────────────────────────────────
    Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 2 }
    Text { text: qsTr("Revisionsstatus"); color: root.theme.textMuted; font.pixelSize: 12 }
    ComboBox {
        id: cmbRevisionStatus
        Layout.fillWidth: true
        model: ["", "entwurf", "freigegeben", "veraltet"]
        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
        contentItem: Text {
            leftPadding: 8
            text: {
                switch(cmbRevisionStatus.currentText) {
                    case "entwurf":     return qsTr("Entwurf")
                    case "freigegeben": return qsTr("Freigegeben")
                    case "veraltet":    return qsTr("Veraltet")
                    default:            return qsTr("Kein Status")
                }
            }
            color: {
                switch(cmbRevisionStatus.currentText) {
                    case "entwurf":     return "#d97706"
                    case "freigegeben": return "#16a34a"
                    case "veraltet":    return "#dc2626"
                    default:            return root.theme.textMuted
                }
            }
            font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
        }
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: cmbRevisionStatus.width; implicitHeight: 32
            highlighted: cmbRevisionStatus.highlightedIndex === index
            contentItem: Text {
                leftPadding: 8
                text: {
                    switch(modelData) {
                        case "entwurf":     return qsTr("Entwurf")
                        case "freigegeben": return qsTr("Freigegeben")
                        case "veraltet":    return qsTr("Veraltet")
                        default:            return qsTr("Kein Status")
                    }
                }
                color: {
                    switch(modelData) {
                        case "entwurf":     return "#d97706"
                        case "freigegeben": return "#16a34a"
                        case "veraltet":    return "#dc2626"
                        default:            return root.theme.textMuted
                    }
                }
                font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
        }
    }
    Text {
        text: qsTr("Revisionskennzeichen (z. B. A, B, 1.0)")
        color: root.theme.textMuted; font.pixelSize: 12
        visible: cmbRevisionStatus.currentText !== ""
        height: visible ? implicitHeight : 0
    }
    TextField {
        id: tfRevisionKennung
        Layout.fillWidth: true
        visible: cmbRevisionStatus.currentText !== ""
        height: visible ? implicitHeight : 0
        placeholderText: qsTr("leer lassen wenn nicht relevant")
        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
        color: root.theme.textPrimary; font.pixelSize: 13
    }
    Item { height: 4 }
}
