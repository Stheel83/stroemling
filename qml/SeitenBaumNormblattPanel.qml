import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Normblatt-Einstellungen + Revisionsstatus – eingebettet in dlgSeiteBearbeiten.
ColumnLayout {
    id: root

    required property var theme
    // Blattkopf der Seite: "schriftfeld" | "keiner" (vom Dialog gesetzt)
    property string blattkopf: "schriftfeld"
    // Lage des Normblatts (vom Dialog): "fest" | "inhalt"; seiteId für den Größen-Hinweis
    property string position: "fest"
    property int    seiteId: -1
    readonly property bool positionInhalt: normblattAn && position === "inhalt"
    property string geladenePosition: "fest"
    readonly property var _nbFormate: ["auto", "a4", "a3", "a2", "a1", "a0", "canvas"]
    property bool _nbZuGross: false
    function _nbPruefen() {
        _nbZuGross = positionInhalt && seiteId > 0 && db.normblattInhaltZuGross(seiteId,
                         _nbFormate[Math.max(0, cmbNbFormat.currentIndex)], cmbVorlage.currentText)
    }
    readonly property bool normblattAn: blattkopf === "schriftfeld"
    property var _normblattVorlagen: []
    // Lädt die Seiteneinstellungen; gibt den ermittelten Blattkopf zurück ("schriftfeld" | "keiner")
    function laden(seiteId) {
        var kopf = "schriftfeld"
        root._normblattVorlagen = db.normblattVorlagenListe().filter(function(v) { return v.art === "schriftfeld" })
        var nd = db.normblattDatenLaden(seiteId)
        if (nd) {
            var normblatt = nd.normblattAnzeigen === 1 || nd.normblattAnzeigen === true
            kopf = normblatt ? "schriftfeld" : "keiner"
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
            root.geladenePosition = nd.normblattPosition === "inhalt" ? "inhalt" : "fest"
            var nfi = root._nbFormate.indexOf(nd.normblattFormat || "auto")
            cmbNbFormat.currentIndex = nfi >= 0 ? nfi : 0
            cmbNbAusrichtung.currentIndex = nd.normblattAusrichtung === "rechts" ? 1 : 0
            chkRahmen.checked = nd.normblattRahmen !== false
        }
        return kopf
    }

    function speichern(seiteId) {
        db.normblattEinstellungenSetzen(
            seiteId,
            root.normblattAn,
            tfHintergrundFarbe.text.trim(),
            chkAussenOverlay.checked,
            cmbVorlage.currentText,
            (cmbVorlage.currentText === "benutzerdefiniert"
             && cmbVorlageAuswahl.currentIndex >= 0
             && root._normblattVorlagen.length > 0)
                ? root._normblattVorlagen[cmbVorlageAuswahl.currentIndex].id : -1)
        db.seiteInDokuPdfSetzen(seiteId, chkInDokuPdf.checked)
        db.seiteNormblattLageSetzen(seiteId,
                                    root.normblattAn ? root.position : "fest",
                                    root._nbFormate[Math.max(0, cmbNbFormat.currentIndex)],
                                    cmbNbAusrichtung.currentIndex === 1 ? "rechts" : "links",
                                    chkRahmen.checked)
        db.seiteRevisionSetzen(
            seiteId,
            cmbRevisionStatus.currentText,
            tfRevisionKennung.text.trim())
    }

    // Normblatt "folgt Inhalt": Format der Blatt-Fläche, Ausrichtung zu den Elementen (N-02)
    Text {
        text: qsTr("Format des Blatts")
        color: root.theme.textMuted; font.pixelSize: 12
        visible: root.positionInhalt
    }
    ComboBox {
        id: cmbNbFormat
        Layout.fillWidth: true
        visible: root.positionInhalt
        model: [qsTr("Automatisch (kleinstes passendes DIN-Format)"), "A4", "A3", "A2", "A1", "A0", qsTr("Gesamtes Canvas")]
        onActivated: root._nbPruefen()
        onVisibleChanged: if (visible) root._nbPruefen()
        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
        contentItem: Text { leftPadding: 8; text: cmbNbFormat.displayText; color: root.theme.textPrimary
            font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    }
    ComboBox {
        id: cmbNbAusrichtung
        Layout.fillWidth: true
        visible: root.positionInhalt
        model: [qsTr("Linksbündig zu den Elementen"), qsTr("Rechtsbündig zu den Elementen")]
        ToolTip.visible: hovered; ToolTip.delay: 600
        ToolTip.text: qsTr("Legt fest, ob der Rahmen links der Elemente beginnt oder rechts der Elemente endet.")
        background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
        contentItem: Text { leftPadding: 8; text: cmbNbAusrichtung.displayText; color: root.theme.textPrimary
            font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    }
    Text {
        Layout.fillWidth: true
        visible: root.positionInhalt && root._nbZuGross
        text: qsTr("Die Elemente passen nicht in das gewählte Format (inkl. Abstand, Ränder und Schriftfeld) – größeres Format oder „Automatisch“ wählen.")
        color: root.theme.warning !== undefined ? root.theme.warning : "#d08a20"
        font.pixelSize: 12; wrapMode: Text.WordWrap
    }

    // Titelblatt-Vorlage (nur wenn Normblatt aktiv)
    Text {
        text: qsTr("Schriftfeld-Vorlage")
        color: root.theme.textMuted; font.pixelSize: 12
        visible: root.normblattAn
    }
    ComboBox {
        id: cmbVorlage
        Layout.fillWidth: true
        visible: root.normblattAn
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
        visible: root.normblattAn && cmbVorlage.currentText === "benutzerdefiniert"
        height: visible ? implicitHeight : 0
    }
    ComboBox {
        id: cmbVorlageAuswahl
        Layout.fillWidth: true
        visible: root.normblattAn && cmbVorlage.currentText === "benutzerdefiniert"
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
        visible: root.normblattAn && cmbVorlage.currentText === "benutzerdefiniert"
                 && root._normblattVorlagen.length === 0
        color: root.theme.textMuted; font.pixelSize: 11; wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    // Rahmen anzeigen (nur Schriftfeld): aus = Seitenrand und Zeichnungsrahmen entfallen, Schriftfeld bleibt
    RowLayout {
        Layout.fillWidth: true
        visible: root.normblattAn
        CheckBox {
            id: chkRahmen
            checked: true
            indicator: Rectangle {
                width: 16; height: 16; radius: 3
                border.color: chkRahmen.checked ? root.theme.accent : root.theme.border
                color: chkRahmen.checked ? root.theme.accent : root.theme.inputBg
                Text { anchors.centerIn: parent; text: "✓"; color: root.theme.textPrimary; font.pixelSize: 11; visible: chkRahmen.checked }
            }
            contentItem: Text {
                text: qsTr("Zeichnungsrahmen anzeigen")
                color: root.theme.textPrimary; font.pixelSize: 13
                leftPadding: chkRahmen.indicator.width + chkRahmen.spacing
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // Aussen-Overlay Checkbox (nur wenn Normblatt aktiv)
    RowLayout {
        Layout.fillWidth: true
        visible: root.normblattAn
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
    Text { text: qsTr("Seitenhintergrund (Farbe)"); color: root.theme.textMuted; font.pixelSize: 12; visible: root.normblattAn }
    RowLayout {
        Layout.fillWidth: true; spacing: 6
        visible: root.normblattAn
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
