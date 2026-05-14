import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

// ============================================================
// KabellinieDialog – Kabeldaten nach dem Zeichnen einer
// Kabeldefinitionslinie eingeben.
// ============================================================

Dialog {
    id: root

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 380
    padding: 20

    property var    theme
    property bool   debug:      false
    property bool   _debugLokal: false
    property int    projektId:  -1

    // Elementindex im Canvas-Elemente-Array (gesetzt vor open())
    property int    elementIndex: -1

    // Ausgabe – gelesen von Canvas nach accepted
    property string bezeichnung:        ""
    property string kabeltyp:           ""
    property int    aderzahl:           0
    property real   querschnittMm2:     0.0
    property int    bauteilKabelId:     0
    property string vonOrt:             ""
    property string nachOrt:            ""
    // > 0: bestehende Kabel-ID; neu anlegen wenn 0
    property int    bestehendesKabelId: 0

    // Bestehende Kabel für Dropdown (vor open() von Canvas befüllt)
    property var    vorhandeneKabel:    []

    // Interner Index in vorhandeneKabel (0 = Neues Kabel)
    property int    _kabelAuswahl: 0

    title: qsTr("Kabeldefinitionslinie – Kabeldaten")

    background: Rectangle {
        color: theme ? theme.sidebar : "#1a2332"
        border.color: theme ? theme.border : "#2a4060"
        border.width: 1; radius: 6
    }

    contentItem: ColumnLayout {
        spacing: 12

        Text {
            text: root.title
            color: theme ? theme.textPrimary : "#c0d8f0"
            font.pixelSize: 14; font.weight: Font.Medium
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme ? theme.border : "#2a4060" }

        // Bestehende Kabel – nur anzeigen wenn mindestens ein Kabel existiert
        Item {
            Layout.fillWidth: true
            height: root.vorhandeneKabel.length > 0 ? vorhandeneKabelCol.implicitHeight : 0
            clip: true
            ColumnLayout {
                id: vorhandeneKabelCol
                width: parent.width; spacing: 4
                Text { text: qsTr("Bestehendes Kabel zuordnen"); color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 11 }
                ComboBox {
                    id: kabelAuswahlCombo
                    Layout.fillWidth: true
                    model: {
                        var opts = [qsTr("– Neues Kabel –")]
                        for (var i = 0; i < root.vorhandeneKabel.length; i++) {
                            var k = root.vorhandeneKabel[i]
                            opts.push((k.bezeichnung || "") + (k.kabeltyp ? "  " + k.kabeltyp : ""))
                        }
                        return opts
                    }
                    currentIndex: root._kabelAuswahl
                    onActivated: {
                        root._kabelAuswahl = index
                        if (index > 0) {
                            var k = root.vorhandeneKabel[index - 1]
                            tfBezeichnung.text  = k.bezeichnung || ""
                            tfKabeltyp.text     = k.kabeltyp    || ""
                            tfAderzahl.text     = (k.aderzahl  || 0) > 0 ? k.aderzahl.toString()  : ""
                            tfQuerschnitt.text  = (k.querschnittMm2 || 0) > 0 ? k.querschnittMm2.toString() : ""
                        }
                    }
                    contentItem: Text {
                        text: kabelAuswahlCombo.displayText
                        color: theme ? theme.textPrimary : "#c0d8f0"; font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter; leftPadding: 8; elide: Text.ElideRight
                    }
                    background: Rectangle {
                        color: theme ? theme.inputBg : "#0f1c2e"; radius: 4
                        border.color: theme ? theme.border : "#2a4060"
                    }
                }
            }
        }

        // Bezeichnung / BMK
        RowLayout {
            Layout.fillWidth: true; spacing: 0
            Text { text: qsTr("Bezeichnung (BMK)"); color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 11; Layout.fillWidth: true }
            Text {
                visible: root._kabelAuswahl > 0
                text: qsTr("✓ Bestehendes Kabel erkannt")
                color: theme ? theme.accent : "#e07000"; font.pixelSize: 10
            }
        }
        TextField {
            id: tfBezeichnung
            Layout.fillWidth: true
            placeholderText: qsTr("z. B. -W1")
            color: theme ? theme.textPrimary : "#c0d8f0"
            font.pixelSize: 13
            background: Rectangle {
                color:        theme ? theme.inputBg : "#0f1c2e"; radius: 4
                border.color: root._kabelAuswahl > 0 ? (theme ? theme.accent : "#e07000")
                                                     : (theme ? theme.border : "#2a4060")
                border.width: root._kabelAuswahl > 0 ? 2 : 1
            }
            Keys.onReturnPressed: tfKabeltyp.forceActiveFocus()
            onTextChanged: {
                var bmk = text.trim()
                if (bmk === "") { root._kabelAuswahl = 0; return }
                for (var i = 0; i < root.vorhandeneKabel.length; i++) {
                    if ((root.vorhandeneKabel[i].bezeichnung || "") === bmk) {
                        if (root._kabelAuswahl !== i + 1) {
                            root._kabelAuswahl = i + 1
                            var k = root.vorhandeneKabel[i]
                            tfKabeltyp.text    = k.kabeltyp        || ""
                            tfAderzahl.text    = (k.aderzahl     || 0) > 0 ? k.aderzahl.toString()        : ""
                            tfQuerschnitt.text = (k.querschnittMm2 || 0) > 0 ? k.querschnittMm2.toString() : ""
                        }
                        return
                    }
                }
                root._kabelAuswahl = 0
            }
        }

        // Aus Bauteilbibliothek wählen
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text {
                id: lblBauteilKabel
                Layout.fillWidth: true
                text: root.bauteilKabelId > 0 ? qsTr("Bauteil-Kabel verknüpft") : qsTr("Kein Bauteil-Kabel")
                color: root.bauteilKabelId > 0 ? (theme ? theme.accent : "#4a9eff") : (theme ? theme.textMuted : "#7090b0")
                font.pixelSize: 11; font.italic: root.bauteilKabelId <= 0
            }
            Button {
                text: qsTr("Aus Bibliothek …"); flat: true; implicitHeight: 26
                contentItem: Text { text: parent.text; color: theme ? theme.textPrimary : "#c0d8f0";
                                    font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? (theme ? theme.hover : "#0f2540") : (theme ? theme.inputBg : "#0f1c2e"); radius: 4; border.color: theme ? theme.border : "#2a4060" }
                onClicked: { kabelPicker.kabelListe = db.bauteilKabelListe(); kabelPicker.open() }
            }
        }

        // Kabeltyp
        Text { text: qsTr("Kabeltyp"); color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 11 }
        TextField {
            id: tfKabeltyp
            Layout.fillWidth: true
            placeholderText: qsTr("z. B. NYM-J 3x1,5")
            color: theme ? theme.textPrimary : "#c0d8f0"
            font.pixelSize: 13
            background: Rectangle { color: theme ? theme.inputBg : "#0f1c2e"; radius: 4; border.color: theme ? theme.border : "#2a4060" }
            Keys.onReturnPressed: tfAderzahl.forceActiveFocus()
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 12

            ColumnLayout {
                spacing: 4; Layout.fillWidth: true
                Text { text: qsTr("Aderzahl"); color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 11 }
                TextField {
                    id: tfAderzahl
                    Layout.fillWidth: true
                    placeholderText: "0"
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 0; top: 999 }
                    color: theme ? theme.textPrimary : "#c0d8f0"
                    font.pixelSize: 13
                    background: Rectangle { color: theme ? theme.inputBg : "#0f1c2e"; radius: 4; border.color: theme ? theme.border : "#2a4060" }
                    Keys.onReturnPressed: tfQuerschnitt.forceActiveFocus()
                }
            }

            ColumnLayout {
                spacing: 4; Layout.fillWidth: true
                Text { text: qsTr("Querschnitt (mm²)"); color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 11 }
                TextField {
                    id: tfQuerschnitt
                    Layout.fillWidth: true
                    placeholderText: "0.0"
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    validator: DoubleValidator { bottom: 0.0; decimals: 2 }
                    color: theme ? theme.textPrimary : "#c0d8f0"
                    font.pixelSize: 13
                    background: Rectangle { color: theme ? theme.inputBg : "#0f1c2e"; radius: 4; border.color: theme ? theme.border : "#2a4060" }
                }
            }
        }

        // Von / Nach
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            ColumnLayout {
                spacing: 4; Layout.fillWidth: true
                Text { text: qsTr("Von (Ort / Gerät)"); color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 11 }
                TextField {
                    id: tfVonOrt
                    Layout.fillWidth: true
                    placeholderText: qsTr("z. B. Schrank A")
                    color: theme ? theme.textPrimary : "#c0d8f0"; font.pixelSize: 13
                    background: Rectangle { color: theme ? theme.inputBg : "#0f1c2e"; radius: 4; border.color: theme ? theme.border : "#2a4060" }
                }
            }
            ColumnLayout {
                spacing: 4; Layout.fillWidth: true
                Text { text: qsTr("Nach (Ort / Gerät)"); color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 11 }
                TextField {
                    id: tfNachOrt
                    Layout.fillWidth: true
                    placeholderText: qsTr("z. B. Motor M1")
                    color: theme ? theme.textPrimary : "#c0d8f0"; font.pixelSize: 13
                    background: Rectangle { color: theme ? theme.inputBg : "#0f1c2e"; radius: 4; border.color: theme ? theme.border : "#2a4060" }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme ? theme.border : "#2a4060"; Layout.topMargin: 4 }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 32
                contentItem: Text { text: parent.text; color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? (theme ? theme.hover : "#0f2540") : "transparent"; radius: 4 }
                onClicked: root.reject()
            }
            Button {
                text: qsTr("Übernehmen"); implicitWidth: 110; implicitHeight: 32
                enabled: tfBezeichnung.text.trim() !== ""
                contentItem: Text { text: parent.text; color: theme ? theme.textPrimary : "#c0d8f0"; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (theme ? theme.activeItem : "#1a3a6a") : (theme ? theme.btnDisabled : "#1a2030")
                    radius: 4
                }
                onClicked: {
                    root.bezeichnung        = tfBezeichnung.text.trim()
                    root.kabeltyp           = tfKabeltyp.text.trim()
                    root.aderzahl           = parseInt(tfAderzahl.text) || 0
                    root.querschnittMm2     = parseFloat(tfQuerschnitt.text.replace(",", ".")) || 0.0
                    root.vonOrt             = tfVonOrt.text.trim()
                    root.nachOrt            = tfNachOrt.text.trim()
                    root.bestehendesKabelId = (root._kabelAuswahl > 0)
                                             ? (root.vorhandeneKabel[root._kabelAuswahl - 1].id || 0)
                                             : 0
                    root.accept()
                }
            }
        }
    }

    onOpened: {
        root._kabelAuswahl  = 0
        tfBezeichnung.text  = root.bezeichnung
        tfKabeltyp.text     = root.kabeltyp
        tfAderzahl.text     = root.aderzahl > 0 ? root.aderzahl.toString() : ""
        tfQuerschnitt.text  = root.querschnittMm2 > 0 ? root.querschnittMm2.toString() : ""
        tfVonOrt.text       = root.vonOrt
        tfNachOrt.text      = root.nachOrt
        tfBezeichnung.forceActiveFocus()
    }

    // Picker-Dialog (eingebettet als Kind, erbt Overlay)
    BauteilKabelPickerDialog {
        id: kabelPicker
        theme: root.theme
        onAccepted: {
            root.bauteilKabelId = kabelPicker.ausgewaehltId
            if (kabelPicker.ausgewaehltId > 0) {
                // Felder aus Bibliothek befüllen
                var liste = kabelPicker.kabelListe
                for (var i = 0; i < liste.length; i++) {
                    if (liste[i].id === kabelPicker.ausgewaehltId) {
                        if (liste[i].kabeltyp)       tfKabeltyp.text    = liste[i].kabeltyp
                        if (liste[i].aderzahl > 0)   tfAderzahl.text    = liste[i].aderzahl.toString()
                        if (liste[i].querschnittMm2 > 0) tfQuerschnitt.text = liste[i].querschnittMm2.toString()
                        break
                    }
                }
            }
        }
    }

    onClosed: root._debugLokal = false

    Shortcut {
        sequence: "Ctrl+Shift+D"
        onActivated: root._debugLokal = !root._debugLokal
    }

    DebugLabel { parent: root.background; panelName: qsTr("Kabellinie-Dialog"); visible: (root.debug || root._debugLokal) && root.visible }
}
