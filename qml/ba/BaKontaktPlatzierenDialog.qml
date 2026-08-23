import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Kontakt-Platzieren-Dialog (verknüpfte Canvas-Platzierung, §8.2.1) —
// ausgelagert aus BaGeraetekastenAnsicht.qml (REFACTOR-QML-02).
Dialog {
    id: root
    required property var theme
    required property var ga   // BaGeraetekastenAnsicht-Referenz (kontaktPlatzierenAngefordert-Signal)

    title: qsTr("Kontakt platzieren")
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 340
    padding: 16

    property int    geraetekastenId:     -1
    property int    steckverbinderTypId: -1
    property string bmk:                 ""
    property var    _positionen:         []
    property int    selPositionId:       -1

    function _laden() {
        _positionen = db.steckverbinderPositionenLaden(steckverbinderTypId)
        var idx = 0
        for (var i = 0; i < _positionen.length; i++) {
            if (!db.steckverbinderPositionIstPlatziert(_positionen[i].id)) { idx = i; break }
        }
        selPositionId = _positionen.length > 0 ? _positionen[idx].id : -1
        if (posCombo.count > 0) posCombo.currentIndex = idx
    }

    function oeffnen(elementId, svTypId, bmkTxt) {
        geraetekastenId     = elementId
        steckverbinderTypId = svTypId
        bmk                 = bmkTxt
        _laden()
        open()
    }

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6
    }

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            text: root.bmk
            font.pixelSize: 12; font.weight: Font.Medium
            color: root.theme.accent; Layout.fillWidth: true; elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: qsTr("Position:"); font.pixelSize: 11; color: root.theme.textMuted; Layout.preferredWidth: 60 }
            ComboBox {
                id: posCombo
                Layout.fillWidth: true
                model: root._positionen
                font.pixelSize: 12
                contentItem: Text {
                    text: {
                        if (posCombo.currentIndex < 0 || posCombo.currentIndex >= root._positionen.length) return ""
                        var p = root._positionen[posCombo.currentIndex]
                        return qsTr("Pos. %1: %2").arg(p.positionNr).arg(p.bezeichnung)
                    }
                    color: root.theme.textPrimary; font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter; leftPadding: 8
                }
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; border.width: 1; radius: 3 }
                popup.background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 4 }
                delegate: ItemDelegate {
                    width: posCombo.width
                    property bool istPlatziert: db.steckverbinderPositionIstPlatziert(modelData.id)
                    contentItem: Text {
                        text: (istPlatziert ? "✓ " : "") + qsTr("Pos. %1: %2").arg(modelData.positionNr).arg(modelData.bezeichnung)
                        color: istPlatziert ? root.theme.textMuted : root.theme.textPrimary
                        font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.sidebar }
                }
                onActivated: {
                    if (currentIndex >= 0 && currentIndex < root._positionen.length)
                        root.selPositionId = root._positionen[currentIndex].id
                }
            }
        }

        Text {
            visible: root._positionen.length === 0
            text: qsTr("Keine Positionen definiert. Im Bauteil-Editor unter Steckverbinder → POSITIONEN anlegen.")
            font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
            wrapMode: Text.WordWrap; Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); implicitWidth: 90; implicitHeight: 28
                contentItem: Text { text: parent.text; color: root.theme.textMuted; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; border.color: root.theme.border; border.width: 1; radius: 4 }
                onClicked: root.reject()
            }
            Button {
                text: qsTr("Platzieren"); implicitWidth: 90; implicitHeight: 28
                enabled: root.selPositionId >= 0
                         && !db.steckverbinderPositionIstPlatziert(root.selPositionId)
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: root.accept()
            }
        }
    }

    onAccepted: {
        if (selPositionId < 0) return
        var pos = null
        for (var i = 0; i < _positionen.length; i++) {
            if (_positionen[i].id === selPositionId) { pos = _positionen[i]; break }
        }
        if (!pos) return
        var symbolId = pos.geschlecht === "stift" ? "stecker" : "buchse"
        root.ga.kontaktPlatzierenAngefordert(geraetekastenId, selPositionId, symbolId, bmk)
    }
}
