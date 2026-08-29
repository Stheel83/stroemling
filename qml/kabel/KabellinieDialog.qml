import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

// ============================================================
// KabellinieDialog – Kabeldaten nach dem Zeichnen einer
// Kabeldefinitionslinie eingeben.
//
// KABELLINIE-DIALOG-SCHLANK-01 (Aug 2026): bewusst auf BMK +
// Bibliothek-Verknüpfung reduziert. Kabeltyp/Aderzahl/Querschnitt/Von/
// Nach lassen sich hier weiterhin über "Bestehendes Kabel zuordnen" oder
// "Aus Bibliothek …" implizit mitübernehmen (root.kabeltyp/aderzahl/
// querschnittMm2 werden dabei gesetzt), sind aber nicht mehr manuell
// editierbar — Nutzerwunsch: diese Angaben trägt man bei Bedarf danach
// im EigenschaftenPanel nach (EpKabelStammdatenBlock.qml deckt exakt
// dieselben Felder ab), das erneute Eintippen direkt nach dem Zeichnen
// war für den Normalfall unnötige Reibung.
// ============================================================

Dialog {
    id: root

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 380
    padding: 20

    required property var theme
    property bool   debug:      false
    property bool   _debugLokal: false
    property int    projektId:  -1

    // Elementindex im Canvas-Elemente-Array (gesetzt vor open())
    property int    elementIndex: -1

    // Ausgabe – gelesen von Canvas nach accepted. kabeltyp/aderzahl/
    // querschnittMm2 kommen ausschließlich aus "Bestehendes Kabel
    // zuordnen" oder "Aus Bibliothek …" (kein eigenes Eingabefeld mehr),
    // vonOrt/nachOrt sind ausschließlich im EP nachpflegbar.
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
        color:        theme.sidebar
        border.color: theme.border
        border.width: 1; radius: 6
    }

    function _uebernehmen() {
        if (tfBezeichnung.text.trim() === "") return
        root.bezeichnung        = tfBezeichnung.text.trim()
        root.bestehendesKabelId = (root._kabelAuswahl > 0)
                                 ? (root.vorhandeneKabel[root._kabelAuswahl - 1].id || 0)
                                 : 0
        root.accept()
    }

    contentItem: ColumnLayout {
        spacing: 12

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // Bestehende Kabel – nur anzeigen wenn mindestens ein Kabel existiert
        Item {
            Layout.fillWidth: true
            height: root.vorhandeneKabel.length > 0 ? vorhandeneKabelCol.implicitHeight : 0
            clip: true
            ColumnLayout {
                id: vorhandeneKabelCol
                width: parent.width; spacing: 4
                Text { text: qsTr("Bestehendes Kabel zuordnen"); color: theme.textMuted; font.pixelSize: 11 }
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
                            root.kabeltyp       = k.kabeltyp    || ""
                            root.aderzahl       = k.aderzahl    || 0
                            root.querschnittMm2 = k.querschnittMm2 || 0.0
                            root.bauteilKabelId = k.bauteilKabelId || 0
                        }
                    }
                    contentItem: Text {
                        text: kabelAuswahlCombo.displayText
                        color: theme.textPrimary; font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter; leftPadding: 8; elide: Text.ElideRight
                    }
                    background: Rectangle {
                        color: theme.inputBg; radius: 4
                        border.color: theme.border
                    }
                }
            }
        }

        // Bezeichnung / BMK
        RowLayout {
            Layout.fillWidth: true; spacing: 0
            Text { text: qsTr("Bezeichnung (BMK)"); color: theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
            Text {
                visible: root._kabelAuswahl > 0
                text: qsTr("✓ Bestehendes Kabel erkannt")
                color: theme.accent; font.pixelSize: 10
            }
        }
        TextField {
            id: tfBezeichnung
            Layout.fillWidth: true
            placeholderText: qsTr("z. B. -W1")
            color: theme.textPrimary
            font.pixelSize: 13
            background: Rectangle {
                color:        theme.inputBg; radius: 4
                border.color: root._kabelAuswahl > 0 ? theme.accent : theme.border
                border.width: root._kabelAuswahl > 0 ? 2 : 1
            }
            Keys.onReturnPressed: root._uebernehmen()
            onTextChanged: {
                var bmk = text.trim()
                if (bmk === "") { root._kabelAuswahl = 0; return }
                for (var i = 0; i < root.vorhandeneKabel.length; i++) {
                    if ((root.vorhandeneKabel[i].bezeichnung || "") === bmk) {
                        if (root._kabelAuswahl !== i + 1) {
                            root._kabelAuswahl = i + 1
                            var k = root.vorhandeneKabel[i]
                            root.kabeltyp       = k.kabeltyp        || ""
                            root.aderzahl       = k.aderzahl        || 0
                            root.querschnittMm2 = k.querschnittMm2  || 0.0
                            // KABEL-BAUTEIL-BMK-UEBERNAHME-01: Bauteil-Kabel-
                            // Verknüpfung des erkannten bestehenden Kabels
                            // übernehmen, sonst musste sie für jede weitere
                            // Kabellinie desselben Kabels manuell neu gewählt
                            // werden, obwohl das BMK identisch ist.
                            root.bauteilKabelId = k.bauteilKabelId || 0
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
                color: root.bauteilKabelId > 0 ? theme.accent : theme.textMuted
                font.pixelSize: 11; font.italic: root.bauteilKabelId <= 0
            }
            Button {
                text: qsTr("Aus Bibliothek …"); flat: true; implicitHeight: 26
                contentItem: Text { text: parent.text; color: theme.textPrimary
                                    font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 4; border.color: theme.border }
                onClicked: { kabelPicker.kabelListe = db.bauteilKabelListe(); kabelPicker.open() }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 32
                contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                onClicked: root.reject()
            }
            Button {
                text: qsTr("Übernehmen"); implicitWidth: 110; implicitHeight: 32
                enabled: tfBezeichnung.text.trim() !== ""
                contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 13
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                    radius: 4
                    border.color: parent.enabled ? theme.accent : theme.border
                }
                onClicked: root._uebernehmen()
            }
        }
    }

    onOpened: {
        root._kabelAuswahl = 0
        tfBezeichnung.text = root.bezeichnung
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
                        if (liste[i].kabeltyp)           root.kabeltyp       = liste[i].kabeltyp
                        if (liste[i].aderzahl > 0)       root.aderzahl       = liste[i].aderzahl
                        if (liste[i].querschnittMm2 > 0) root.querschnittMm2 = liste[i].querschnittMm2
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
