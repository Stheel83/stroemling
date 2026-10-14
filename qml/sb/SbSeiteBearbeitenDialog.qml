import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import stroemling

// Dialog „Seite bearbeiten" — ausgelagert aus SeitenBaum.qml (REFACTOR-QML-01).
Dialog {
    id: root
    required property var theme
    required property var sb   // SeitenBaum-Referenz: debug, formatIndex(), seiteFormatGeaendert-Signal

    title: qsTr("Seite bearbeiten")
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 460
    padding: 20

    property int    itemId:               -1
    property string altBlattnummer:      ""
    property string altBezeichnung:      ""
    property string altSeitentyp:        ""
    property real   altBreiteMm:         297
    property real   altHoeheMm:          210
    property real   altRandLinks:        20
    property real   altRandRechts:       10
    property real   altRandOben:         10
    property real   altRandUnten:        10
    // Blattkopf der Seite: "schriftfeld" (Normblatt) | "infostreifen" | "keiner" (NORMBLATT-DYNAMISCH-01 N-01)
    readonly property var _blattkoepfe: ["schriftfeld", "infostreifen", "keiner"]
    readonly property string blattkopf: _blattkoepfe[Math.max(0, editBlattkopf.currentIndex)]
    // Normblatt-Position: "fest" (Blatt bei 0,0 im gewählten Format) | "inhalt" (Rahmen/Schriftfeld folgen den Elementen, N-02);
    // eigene Vorlagen sind bis N-03 formatgebunden und bleiben "fest"
    readonly property string position: (normblattPanel.vorlageBenutzerdefiniert || editPosition.currentIndex === 0) ? "fest" : "inhalt"

    height: Math.min(implicitHeight, 680)
    background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6 }
    DebugLabel { panelName: "Seite-ID: " + root.itemId; visible: root.sb.debug && root.visible; parent: root.background }

    onOpened: {
        editBlatt.text      = root.altBlattnummer
        editSeiteBez.text   = root.altBezeichnung
        editCmbFormat.currentIndex = root.sb.formatIndex(root.altBreiteMm, root.altHoeheMm)
        editRandLinks.value  = root.altRandLinks
        editRandRechts.value = root.altRandRechts
        editRandOben.value   = root.altRandOben
        editRandUnten.value  = root.altRandUnten
        var bk = normblattPanel.laden(root.itemId)
        editBlattkopf.currentIndex = Math.max(0, root._blattkoepfe.indexOf(bk))
        editPosition.currentIndex = normblattPanel.geladenePosition === "inhalt" ? 1 : 0
    }

    contentItem: ColumnLayout {
        spacing: 0

        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: scrollView.width
            spacing: 10
        Text { text: qsTr("Blattnummer"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: editBlatt; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 12 }
        TextField {
            id: editSeiteBez; Layout.fillWidth: true
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            color: root.theme.textPrimary; font.pixelSize: 14
        }
        Text { text: qsTr("Blattkopf"); color: root.theme.textMuted; font.pixelSize: 12 }
        ComboBox {
            id: editBlattkopf; Layout.fillWidth: true
            model: [qsTr("Schriftfeld (Normblatt)"), qsTr("Infostreifen"), qsTr("Keiner")]
            ToolTip.visible: hovered; ToolTip.delay: 600
            ToolTip.text: qsTr("Schriftfeld: Zeichnungsrahmen mit Schriftfeld in festem Blatt.\nInfostreifen: schmaler Streifen unter den Elementen, Fläche folgt dem Inhalt.\nKeiner: kein Blattkopf.")
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { leftPadding: 8; text: editBlattkopf.displayText; color: root.theme.textPrimary;
                                font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
        }
        Text { text: qsTr("Lage des Blatts"); color: root.theme.textMuted; font.pixelSize: 12; visible: root.blattkopf === "schriftfeld" }
        ComboBox {
            id: editPosition; Layout.fillWidth: true
            visible: root.blattkopf === "schriftfeld"
            enabled: !normblattPanel.vorlageBenutzerdefiniert
            model: [qsTr("Fest (Blatt bei 0,0 im gewählten Format)"), qsTr("Folgt dem Inhalt (Rahmen legt sich um die Elemente)")]
            ToolTip.visible: hovered; ToolTip.delay: 600
            ToolTip.text: normblattPanel.vorlageBenutzerdefiniert
                ? qsTr("Eigene Schriftfeld-Vorlagen sind an ein Blattformat gebunden und bleiben fest.")
                : qsTr("Fest: du zeichnest in den vorgegebenen Rahmen.\nFolgt dem Inhalt: Rahmen und Schriftfeld passen sich den Elementen an.")
            background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
            contentItem: Text { leftPadding: 8; text: editPosition.displayText; color: root.theme.textPrimary;
                                font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }
        Text { text: qsTr("Format"); color: root.theme.textMuted; font.pixelSize: 12
               visible: root.blattkopf === "schriftfeld" && root.position === "fest" }
        ComboBox {
            id: editCmbFormat; Layout.fillWidth: true
            visible: root.blattkopf === "schriftfeld" && root.position === "fest"
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
            contentItem: Text { leftPadding: 8; text: editCmbFormat.displayText; color: root.theme.textPrimary;
                                font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
        }

        Text { text: qsTr("Ränder (mm)"); color: root.theme.textMuted; font.pixelSize: 12; visible: root.blattkopf === "schriftfeld" }
        GridLayout {
            visible: root.blattkopf === "schriftfeld"
            columns: 4; columnSpacing: 6; rowSpacing: 4; Layout.fillWidth: true
            Text { text: qsTr("Links");  color: root.theme.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
            Text { text: qsTr("Rechts"); color: root.theme.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
            Text { text: qsTr("Oben");   color: root.theme.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
            Text { text: qsTr("Unten");  color: root.theme.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
            SpinBox { id: editRandLinks;  from: 5; to: 50; value: 20; implicitWidth: 88
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: editRandLinks.value; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            SpinBox { id: editRandRechts; from: 5; to: 30; value: 10; implicitWidth: 88
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: editRandRechts.value; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            SpinBox { id: editRandOben;   from: 5; to: 30; value: 10; implicitWidth: 88
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: editRandOben.value; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
            SpinBox { id: editRandUnten;  from: 5; to: 30; value: 10; implicitWidth: 88
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text { text: editRandUnten.value; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter } }
        }

        SeitenBaumNormblattPanel {
            id: normblattPanel
            theme: root.theme
            blattkopf: root.blattkopf
            position: root.position
            seiteId: root.itemId
        }
        } // ColumnLayout (ScrollView content)
        } // ScrollView

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
                text: qsTr("Speichern"); implicitWidth: 90; implicitHeight: 34
                enabled: editBlatt.text.trim().length > 0
                contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                    radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: {
                    var fmt = editCmbFormat.model.get(editCmbFormat.currentIndex)
                    seitenModel.seiteBearbeiten(root.itemId,
                        editBlatt.text.trim(), editSeiteBez.text.trim(), (root.altSeitentyp !== "" ? root.altSeitentyp : "schaltplan"),
                        fmt.breite, fmt.hoehe,
                        editRandLinks.value, editRandRechts.value,
                        editRandOben.value,  editRandUnten.value)
                    normblattPanel.speichern(root.itemId)
                    root.sb.seiteFormatGeaendert(root.itemId)
                    root.close()
                }
            }
        }
    }
}
