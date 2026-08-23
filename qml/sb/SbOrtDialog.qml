import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog „Neuer Ort" — ausgelagert aus SeitenBaum.qml (REFACTOR-QML-01).
Dialog {
    id: root
    required property var theme
    required property var sb   // SeitenBaum-Referenz, für _nurSeitenFilter

    title: qsTr("Neuer Ort")
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 360
    padding: 20

    property int  fuerAnlageId: -1
    property var  _cache:       []   // [{kuerzel, bezeichnung}] aller vorhandenen Orte
    property bool _duplikat:    false

    onOpened: {
        inpOrtKuerzel.text = ""; inpOrtBez.text = ""; inpOrtUO.text = ""
        ortVorschlaegeModel.clear(); root._duplikat = false
        var list = seitenModel.strukturListe()
        root._cache = []
        for (var i = 0; i < list.length; i++) {
            var orte = list[i].orte
            for (var j = 0; j < orte.length; j++)
                root._cache.push({ kuerzel: orte[j].ortKuerzel, bezeichnung: orte[j].ortBez,
                              anlageId: list[i].anlageId })
        }
    }

    ListModel { id: ortVorschlaegeModel }

    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

    contentItem: ColumnLayout {
        spacing: 10
        Text { text: qsTr("Kürzel (z.B. A1, B2)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: inpOrtKuerzel; Layout.fillWidth: true; placeholderText: "A1"
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
            onTextChanged: {
                var t = text.trim().toUpperCase()
                ortVorschlaegeModel.clear(); root._duplikat = false
                if (t.length === 0) return
                for (var i = 0; i < root._cache.length; i++) {
                    var kz = root._cache[i].kuerzel.toUpperCase()
                    if (kz.startsWith(t)) {
                        ortVorschlaegeModel.append(root._cache[i])
                        if (kz === t && root._cache[i].anlageId === root.fuerAnlageId)
                            root._duplikat = true
                    }
                }
            }
            onActiveFocusChanged: {
                if (!activeFocus) Qt.callLater(() => { ortVorschlaegeModel.clear() })
            }
        }
        // Vorschlagsliste
        Rectangle {
            Layout.fillWidth: true; Layout.topMargin: -6
            height: Math.min(ortVorschlaegeModel.count * 30, 90)
            visible: ortVorschlaegeModel.count > 0
            color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 4; clip: true; z: 10
            ListView {
                anchors.fill: parent; clip: true
                model: ortVorschlaegeModel
                delegate: ItemDelegate {
                    width: parent.width; height: 30
                    background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent" }
                    contentItem: Text {
                        text: model.kuerzel + "   " + model.bezeichnung
                        color: root.theme.textPrimary; font.pixelSize: 12; font.family: "monospace"
                        verticalAlignment: Text.AlignVCenter; leftPadding: 6
                    }
                    onClicked: {
                        inpOrtKuerzel.text = model.kuerzel
                        inpOrtBez.text = model.bezeichnung
                        ortVorschlaegeModel.clear()
                    }
                }
            }
        }
        // Duplikat-Warnung (nur wenn Kürzel in dieser Anlage schon existiert)
        Text {
            visible: root._duplikat
            text: "⚠ " + qsTr("Kürzel in dieser Anlage bereits vorhanden")
            color: "#cc6600"; font.pixelSize: 11; Layout.topMargin: -4
        }
        Text { text: qsTr("Bezeichnung (z.B. Hauptverteiler)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: inpOrtBez; Layout.fillWidth: true; placeholderText: qsTr("Hauptverteiler")
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Übergeordneter Ort ++ (optional, z.B. Halle2)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: inpOrtUO; Layout.fillWidth: true; placeholderText: qsTr("Halle2")
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border; Layout.topMargin: 4 }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 34
                contentItem: Text { text: parent.text; color: root.theme.textSecondary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onClicked: root.close()
            }
            Button {
                text: qsTr("Anlegen"); implicitWidth: 90; implicitHeight: 34
                enabled: inpOrtKuerzel.text.trim().length > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    seitenModel.ortAnlegen(root.fuerAnlageId,
                        inpOrtKuerzel.text.trim(), inpOrtBez.text.trim(), inpOrtUO.text.trim())
                    inpOrtKuerzel.text = ""; inpOrtBez.text = ""; inpOrtUO.text = ""
                    root.close()
                    root.sb._nurSeitenFilter = false   // neuer, noch leerer Ort bliebe sonst unsichtbar
                }
            }
        }
    }
}
