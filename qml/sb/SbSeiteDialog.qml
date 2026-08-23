import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Dialog „Neue Seite" — ausgelagert aus SeitenBaum.qml (REFACTOR-QML-01).
Dialog {
    id: root
    required property var theme
    required property var sb   // SeitenBaum-Referenz, für _nurSeitenFilter

    title: qsTr("Neue Seite")
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 360
    padding: 20

    property int fuerOrtId: -1

    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }

    contentItem: ColumnLayout {
        spacing: 10
        Text { text: qsTr("Blattnummer (z.B. 001)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: inpBlatt; Layout.fillWidth: true; placeholderText: "001"
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Bezeichnung (optional)"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: inpSeiteBez; Layout.fillWidth: true; placeholderText: qsTr("Stromversorgung 24VDC")
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Seitentyp"); color: root.theme.textMuted; font.pixelSize: 12 }
        ComboBox {
            id: cmbTyp; Layout.fillWidth: true
            model: ["schaltplan", "klemmenplan", "kabelplan", "titelblatt", "inhaltsverzeichnis", "layout"]
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { leftPadding: 8; text: cmbTyp.displayText; color: root.theme.textPrimary;
                                font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
        }
        Text { text: qsTr("Format"); color: root.theme.textMuted; font.pixelSize: 12 }
        ComboBox {
            id: cmbFormat; Layout.fillWidth: true
            model: ListModel {
                ListElement { text: "A4 Querformat  (297 × 210 mm)"; breite: 297; hoehe: 210 }
                ListElement { text: "A4 Hochformat  (210 × 297 mm)"; breite: 210; hoehe: 297 }
                ListElement { text: "A3 Querformat  (420 × 297 mm)"; breite: 420; hoehe: 297 }
                ListElement { text: "A3 Hochformat  (297 × 420 mm)"; breite: 297; hoehe: 420 }
                ListElement { text: "A2 Querformat  (594 × 420 mm)"; breite: 594; hoehe: 420 }
                ListElement { text: "A2 Hochformat  (420 × 594 mm)"; breite: 420; hoehe: 594 }
            }
            textRole: "text"
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { leftPadding: 8; text: cmbFormat.displayText; color: root.theme.textPrimary;
                                font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
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
                enabled: inpBlatt.text.trim().length > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    var fmt = cmbFormat.model.get(cmbFormat.currentIndex)
                    seitenModel.seiteAnlegen(root.fuerOrtId,
                        inpBlatt.text.trim(), inpSeiteBez.text.trim(), cmbTyp.currentText,
                        fmt.breite, fmt.hoehe)
                    inpBlatt.text = ""; inpSeiteBez.text = ""; cmbTyp.currentIndex = 0; cmbFormat.currentIndex = 0
                    root.close()
                    root.sb._nurSeitenFilter = false
                }
            }
        }
    }
}
