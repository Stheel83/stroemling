import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// VERT-00 (konzept/features/55 §8): neuen Pruefdurchgang anlegen.
// Archiviert die aktuellen IBN-Staende im gewaehlten Bereich und setzt sie auf "offen".
Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  460
    padding: 20

    required property var theme
    required property int projektId
    property var    liste: []          // IBN-BM-Liste (anlageKz, ortKz) -> Bereichsauswahl
    property int    aktuellerDurchgang: 1
    property string fehlerText: ""

    signal durchgangAngelegt(int nr)

    title: qsTr("Neuer Prüfdurchgang")

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border
        border.width: 1; radius: 6
    }

    function _anlagen() {
        var m = {}
        for (var i = 0; i < root.liste.length; i++)
            if (root.liste[i].anlageKz) m[root.liste[i].anlageKz] = true
        return [qsTr("Ganzes Projekt")].concat(Object.keys(m).sort())
    }

    function _orte(anlage) {
        var m = {}
        for (var i = 0; i < root.liste.length; i++)
            if (root.liste[i].anlageKz === anlage && root.liste[i].ortKz) m[root.liste[i].ortKz] = true
        return [qsTr("Alle Orte")].concat(Object.keys(m).sort())
    }

    onAboutToShow: {
        fehlerText = ""
        tfBezeichnung.text = qsTr("Wiederholungsprüfung")
        cmbArt.currentIndex = 0
        tfDatum.text = Qt.formatDate(new Date(), "yyyy-MM-dd")
        tfFaellig.text = ""
        cmbAnlage.model = root._anlagen()
        cmbAnlage.currentIndex = 0
        cbVorbelegen.checked = false
    }

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11; color: root.theme.textSecondary
            text: qsTr("Aktuell: Durchgang %1. Die Stände im gewählten Bereich werden archiviert "
                       + "und auf „offen“ zurückgesetzt. Archivierte Stände bleiben als Prüfnachweis erhalten.")
                  .arg(root.aktuellerDurchgang)
        }

        Text { text: qsTr("Bezeichnung"); font.pixelSize: 11; color: root.theme.textSecondary }
        TextField {
            id: tfBezeichnung
            Layout.fillWidth: true; implicitHeight: 30
            color: root.theme.textPrimary; font.pixelSize: 12
            background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Art"); font.pixelSize: 11; color: root.theme.textSecondary }
                ComboBox {
                    id: cmbArt
                    Layout.fillWidth: true; implicitHeight: 30
                    model: [
                        { key: "wiederholung", label: qsTr("Wiederholungsprüfung") },
                        { key: "nach_umbau",   label: qsTr("Prüfung nach Umbau")   }
                    ]
                    textRole: "label"
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                    contentItem: Text {
                        leftPadding: 8; text: cmbArt.displayText
                        color: root.theme.textPrimary; font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 110
                Text { text: qsTr("Datum"); font.pixelSize: 11; color: root.theme.textSecondary }
                TextField {
                    id: tfDatum
                    Layout.fillWidth: true; implicitHeight: 30
                    placeholderText: "JJJJ-MM-TT"
                    color: root.theme.textPrimary; font.pixelSize: 12
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 110
                Text { text: qsTr("Fällig am"); font.pixelSize: 11; color: root.theme.textSecondary }
                TextField {
                    id: tfFaellig
                    Layout.fillWidth: true; implicitHeight: 30
                    placeholderText: qsTr("optional")
                    color: root.theme.textPrimary; font.pixelSize: 12
                    background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                }
            }
        }

        Text { text: qsTr("Bereich"); font.pixelSize: 11; color: root.theme.textSecondary }
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            ComboBox {
                id: cmbAnlage
                Layout.fillWidth: true; implicitHeight: 30
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                contentItem: Text {
                    leftPadding: 8; text: cmbAnlage.displayText
                    color: root.theme.textPrimary; font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                }
                onCurrentIndexChanged: {
                    cmbOrt.model = currentIndex > 0 ? root._orte(currentText) : [qsTr("Alle Orte")]
                    cmbOrt.currentIndex = 0
                }
            }
            ComboBox {
                id: cmbOrt
                Layout.fillWidth: true; implicitHeight: 30
                enabled: cmbAnlage.currentIndex > 0
                model: [qsTr("Alle Orte")]
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                contentItem: Text {
                    leftPadding: 8; text: cmbOrt.displayText
                    color: cmbOrt.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 11; verticalAlignment: Text.AlignVCenter
                }
            }
        }

        CheckBox {
            id: cbVorbelegen
            text: qsTr("Werte aus dem Vorgänger vorbelegen")
            contentItem: Text {
                leftPadding: cbVorbelegen.indicator.width + 6
                text: cbVorbelegen.text
                color: root.theme.textPrimary; font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
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
                text: qsTr("Durchgang anlegen")
                implicitHeight: 32
                enabled: tfBezeichnung.text.trim() !== ""
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
                onClicked: {
                    var bereich = []
                    if (cmbAnlage.currentIndex > 0) {
                        var b = { "anlage": cmbAnlage.currentText }
                        if (cmbOrt.currentIndex > 0) b.ort = cmbOrt.currentText
                        bereich.push(b)
                    }
                    var nr = db.ibnDurchgangAnlegen(root.projektId, tfBezeichnung.text.trim(),
                                                    cmbArt.model[cmbArt.currentIndex].key,
                                                    tfDatum.text.trim(), tfFaellig.text.trim(),
                                                    bereich, cbVorbelegen.checked)
                    if (nr < 0) {
                        root.fehlerText = qsTr("Durchgang konnte nicht angelegt werden (siehe Log).")
                        return
                    }
                    root.close()
                    root.durchgangAngelegt(nr)
                }
            }
        }
    }
}
