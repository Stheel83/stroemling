import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog „Neue Anlage" — ausgelagert aus SeitenBaum.qml (REFACTOR-QML-01).
Dialog {
    id: root
    required property var theme
    required property var sb   // SeitenBaum-Referenz, für _nurSeitenFilter

    title: qsTr("Neue Anlage")
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 360
    padding: 20

    property int  fuerProjektId:    -1
    property var  _cache:           []   // [{kuerzel, bezeichnung}] aller vorhandenen Anlagen
    property bool _duplikat:        false

    onOpened: {
        inpAnlageKuerzel.text = ""; inpAnlageBez.text = ""; inpAnlageUO.text = ""
        anlageVorschlaegeModel.clear(); root._duplikat = false
        var list = seitenModel.strukturListe()
        root._cache = []
        for (var i = 0; i < list.length; i++)
            root._cache.push({ kuerzel: list[i].anlageKuerzel, bezeichnung: list[i].anlageBez })
    }

    ListModel { id: anlageVorschlaegeModel }

    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

    contentItem: ColumnLayout {
        spacing: 10
        Text { text: qsTr("Kürzel (z.B. EG, OG, KG)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: inpAnlageKuerzel; Layout.fillWidth: true; placeholderText: "EG"
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
            onTextChanged: {
                var t = text.trim().toUpperCase()
                anlageVorschlaegeModel.clear(); root._duplikat = false
                if (t.length === 0) return
                for (var i = 0; i < root._cache.length; i++) {
                    var kz = root._cache[i].kuerzel.toUpperCase()
                    if (kz.startsWith(t)) {
                        anlageVorschlaegeModel.append(root._cache[i])
                        if (kz === t) root._duplikat = true
                    }
                }
            }
            onActiveFocusChanged: {
                if (!activeFocus) Qt.callLater(() => { anlageVorschlaegeModel.clear() })
            }
        }
        // Vorschlagsliste
        Rectangle {
            Layout.fillWidth: true; Layout.topMargin: -6
            height: Math.min(anlageVorschlaegeModel.count * 30, 90)
            visible: anlageVorschlaegeModel.count > 0
            color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 4; clip: true; z: 10
            ListView {
                anchors.fill: parent; clip: true
                model: anlageVorschlaegeModel
                delegate: ItemDelegate {
                    width: parent.width; height: 30
                    background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent" }
                    contentItem: Text {
                        text: model.kuerzel + "   " + model.bezeichnung
                        color: root.theme.textPrimary; font.pixelSize: 12; font.family: "monospace"
                        verticalAlignment: Text.AlignVCenter; leftPadding: 6
                    }
                    onClicked: {
                        inpAnlageKuerzel.text = model.kuerzel
                        inpAnlageBez.text = model.bezeichnung
                        anlageVorschlaegeModel.clear()
                    }
                }
            }
        }
        // Duplikat-Warnung
        Text {
            visible: root._duplikat
            text: "⚠ " + qsTr("Kürzel bereits vorhanden")
            color: "#cc6600"; font.pixelSize: 11; Layout.topMargin: -4
        }
        Text { text: qsTr("Bezeichnung (z.B. Erdgeschoss)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: inpAnlageBez; Layout.fillWidth: true; placeholderText: qsTr("Erdgeschoss")
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Übergeordnete Anlage == (optional, z.B. Werk1)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: inpAnlageUO; Layout.fillWidth: true; placeholderText: qsTr("Werk1")
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
                enabled: inpAnlageKuerzel.text.trim().length > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    seitenModel.anlageAnlegen(root.fuerProjektId,
                        inpAnlageKuerzel.text.trim(), inpAnlageBez.text.trim(), inpAnlageUO.text.trim())
                    inpAnlageKuerzel.text = ""; inpAnlageBez.text = ""; inpAnlageUO.text = ""
                    root.close()
                    root.sb._nurSeitenFilter = false   // neue, noch leere Anlage bliebe sonst unsichtbar
                }
            }
        }
    }
}
