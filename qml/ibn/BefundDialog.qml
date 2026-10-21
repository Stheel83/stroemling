import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// FS-IBN-02 (konzept/features/55 §4a.2): Befund der Fehlersuche anlegen oder bearbeiten.
// Neu: `neuOeffnen(bezug)`; bearbeiten: `bearbeitenOeffnen(befund)`. Gespeichert wird über db.befundAnlegen/-Aendern.
Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  460
    padding: 20

    required property var theme
    required property int projektId
    property string vorgabeName: ""            // zuletzt benutzter Name für „Gefunden von“

    property int    _befundId: -1              // >= 0 = bearbeiten
    property var    _bezug: ({})               // {bezugArt, seiteId, bmk, kabelId, x, y} beim Anlegen
    property string _bezugText: ""
    property string fehlerText: ""

    signal gespeichert()

    readonly property var kategorien: [
        { key: "bauteil",     label: qsTr("Bauteil defekt") },
        { key: "verdrahtung", label: qsTr("Verdrahtung") },
        { key: "schaltplan",  label: qsTr("Schaltplan weicht von der Anlage ab") },
        { key: "sonstiges",   label: qsTr("Sonstiges") }
    ]
    readonly property var stati: [
        { key: "offen",       label: qsTr("Offen") },
        { key: "behoben",     label: qsTr("Behoben") },
        { key: "kein_fehler", label: qsTr("Kein Fehler") }
    ]

    function _index(liste, key) {
        for (var i = 0; i < liste.length; i++) if (liste[i].key === key) return i
        return 0
    }

    // bezug: {bezugArt, seiteId, bmk, kabelId, x, y, text (Anzeige des Bezugs)}
    function neuOeffnen(bezug) {
        root._befundId = -1
        root._bezug = bezug
        root._bezugText = bezug.text || ""
        fehlerText = ""
        cmbKategorie.currentIndex = root._index(root.kategorien, "bauteil")
        cmbStatus.currentIndex = 0
        taText.text = ""
        tfVon.text = root.vorgabeName
        open()
        taText.forceActiveFocus()
    }

    function bearbeitenOeffnen(b) {
        root._befundId = b.id
        root._bezug = ({})
        root._bezugText = b.bezugArt === "kabel" ? qsTr("Kabel %1").arg(b.kabelBezeichnung)
                        : b.bezugArt === "bmk" ? qsTr("Betriebsmittel %1").arg(b.bmk)
                        : qsTr("Stelle")
        if (b.blattnummer !== "")
            root._bezugText += qsTr(" · %1 / %2 / Blatt %3").arg(b.anlage).arg(b.ort).arg(b.blattnummer)
        fehlerText = ""
        cmbKategorie.currentIndex = root._index(root.kategorien, b.kategorie)
        cmbStatus.currentIndex = root._index(root.stati, b.status)
        taText.text = b.text
        tfVon.text = b.gefundenVon
        open()
        taText.forceActiveFocus()
    }

    function _speichern() {
        var kat = root.kategorien[cmbKategorie.currentIndex].key
        if (root._befundId >= 0) {
            var ok = db.befundAendern(root._befundId, { text: taText.text, kategorie: kat,
                                                       status: root.stati[cmbStatus.currentIndex].key,
                                                       gefundenVon: tfVon.text })
            if (!ok) {
                root.fehlerText = taText.text.trim() === ""
                    ? qsTr("Bitte einen Befundtext eingeben.")
                    : qsTr("Der Befund konnte nicht geändert werden (außerhalb des Bereichs dieser IBN-Kopie, schreibgeschützt oder siehe Log).")
                return
            }
        } else {
            var d = {}
            for (var k in root._bezug) d[k] = root._bezug[k]
            d.text = taText.text
            d.kategorie = kat
            d.gefundenVon = tfVon.text
            var r = db.befundAnlegen(root.projektId, d)
            if (!r.ok) { root.fehlerText = r.fehler; return }
        }
        root.vorgabeName = tfVon.text.trim()   // beim nächsten Befund wieder vorbelegt
        root.close()
        root.gespeichert()
    }

    title: root._befundId >= 0 ? qsTr("Befund bearbeiten") : qsTr("Neuer Befund")

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border
        border.width: 1; radius: 6
    }

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11; color: root.theme.textSecondary
            text: qsTr("Bezug: %1").arg(root._bezugText)
        }

        Text { text: qsTr("Kategorie"); font.pixelSize: 11; color: root.theme.textSecondary }
        ComboBox {
            id: cmbKategorie
            Layout.fillWidth: true; implicitHeight: 30
            model: root.kategorien
            textRole: "label"
            background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
            contentItem: Text {
                leftPadding: 8; text: cmbKategorie.displayText
                color: root.theme.textPrimary; font.pixelSize: 11
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text { text: qsTr("Befund"); font.pixelSize: 11; color: root.theme.textSecondary }
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: 90
            TextArea {
                id: taText
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: root.theme.textPrimary; font.pixelSize: 12
                placeholderText: qsTr("z. B. Spule offen, 0 Ω")
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Gefunden von"); font.pixelSize: 11; color: root.theme.textSecondary }
                TextField {
                    id: tfVon
                    Layout.fillWidth: true; implicitHeight: 30
                    color: root.theme.textPrimary; font.pixelSize: 12
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                }
            }
            ColumnLayout {
                visible: root._befundId >= 0
                Layout.preferredWidth: 150
                Text { text: qsTr("Status"); font.pixelSize: 11; color: root.theme.textSecondary }
                ComboBox {
                    id: cmbStatus
                    Layout.fillWidth: true; implicitHeight: 30
                    model: root.stati
                    textRole: "label"
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    contentItem: Text {
                        leftPadding: 8; text: cmbStatus.displayText
                        color: root.theme.textPrimary; font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Text {
            visible: root.fehlerText !== ""
            text: root.fehlerText
            color: "#e04040"; font.pixelSize: 11
            Layout.fillWidth: true; wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }

            Button {
                text: qsTr("Abbrechen")
                flat: true
                implicitHeight: 32
                contentItem: Text {
                    text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border
                }
                onClicked: root.reject()
            }

            Button {
                text: qsTr("Speichern")
                implicitHeight: 32
                enabled: taText.text.trim() !== ""
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg)
                                          : root.theme.inputBg
                    radius: 4
                    border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: root._speichern()
            }
        }
    }
}
