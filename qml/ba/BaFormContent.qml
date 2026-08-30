import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

ColumnLayout {
    id: root
    required property var theme

    property alias bezeichnung:   fBez.text
    property alias bmkVorlage:    fBmkVorlage.text
    property alias hersteller:    fHer.text
    property alias artikelnummer: fArt.text
    property alias lieferant:     fLief.text
    property alias preis:         fPreis.text
    property alias spannung:      fSpannung.text
    property alias strom:         fStrom.text
    property alias leistung:      fLeistung.text
    property alias bemerkung:     fBem.text
    property alias urlHersteller: fUrlHer.text
    property alias urlDatenblatt: fUrlDat.text

    width: parent.width
    spacing: 8

    Text { text: qsTr("Bezeichnung *"); color: theme.textMuted; font.pixelSize: 12 }
    NavTextField {
        id: fBez; Layout.fillWidth: true
        tabTarget: fBmkVorlage; backtabTarget: fUrlDat
        background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
        color: theme.textPrimary; font.pixelSize: 14
    }

    Text { text: qsTr("BMK-Vorlage (Kennbuchstabe, z.B. –K)"); color: theme.textMuted; font.pixelSize: 12 }
    NavTextField {
        id: fBmkVorlage; Layout.fillWidth: true; Layout.preferredWidth: 80
        tabTarget: fHer; backtabTarget: fBez
        background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
        color: theme.textPrimary; font.pixelSize: 14; placeholderText: "-K"
        ToolTip.visible: hovered; ToolTip.delay: 600
        ToolTip.text: qsTr("Vorschlag fuer den BMK-Kennbuchstaben, wird beim Platzieren dieses Bauteils als Platzhalter-BMK vorgeschlagen")
    }

    GridLayout {
        columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 8

        Text { text: qsTr("Hersteller");    color: theme.textMuted; font.pixelSize: 12 }
        Text { text: qsTr("Artikelnummer"); color: theme.textMuted; font.pixelSize: 12 }
        NavTextField {
            id: fHer; Layout.fillWidth: true
            tabTarget: fArt; backtabTarget: fBmkVorlage
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14
        }
        NavTextField {
            id: fArt; Layout.fillWidth: true
            tabTarget: fLief; backtabTarget: fHer
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14
        }

        Text { text: qsTr("Lieferant");  color: theme.textMuted; font.pixelSize: 12 }
        Text { text: qsTr("Preis (€)"); color: theme.textMuted; font.pixelSize: 12 }
        NavTextField {
            id: fLief; Layout.fillWidth: true
            tabTarget: fPreis; backtabTarget: fArt
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14
        }
        NavTextField {
            id: fPreis; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
            tabTarget: fSpannung; backtabTarget: fLief
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14; placeholderText: "0.00"
        }

        Text { text: qsTr("Spannung (V)"); color: theme.textMuted; font.pixelSize: 12 }
        Text { text: qsTr("Strom (A)");    color: theme.textMuted; font.pixelSize: 12 }
        NavTextField {
            id: fSpannung; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
            tabTarget: fStrom; backtabTarget: fPreis
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14; placeholderText: "0"
        }
        NavTextField {
            id: fStrom; Layout.fillWidth: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
            tabTarget: fLeistung; backtabTarget: fSpannung
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14; placeholderText: "0"
        }

        Text { text: qsTr("Leistung (W)"); color: theme.textMuted; font.pixelSize: 12; Layout.columnSpan: 2 }
        NavTextField {
            id: fLeistung; Layout.fillWidth: true; Layout.columnSpan: 2
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            tabTarget: fBem; backtabTarget: fStrom
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 14; placeholderText: "0"
        }
    }

    Text { text: qsTr("Bemerkung"); color: theme.textMuted; font.pixelSize: 12 }
    TextArea {
        id: fBem; Layout.fillWidth: true; height: 72
        wrapMode: TextArea.Wrap
        background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
        color: theme.textPrimary; font.pixelSize: 14; padding: 8
        Keys.onTabPressed:     { event.accepted = true; fUrlHer.forceActiveFocus() }
        Keys.onBacktabPressed: { event.accepted = true; fLeistung.forceActiveFocus() }
    }

    Text { text: qsTr("Links"); color: theme.accent; font.pixelSize: 12; font.bold: true; Layout.topMargin: 4 }

    Text { text: qsTr("Hersteller-Website"); color: theme.textMuted; font.pixelSize: 12 }
    RowLayout {
        Layout.fillWidth: true; spacing: 6
        NavTextField {
            id: fUrlHer; Layout.fillWidth: true
            tabTarget: fUrlDat; backtabTarget: fBem
            placeholderText: "https://..."
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 13
        }
        Button {
            implicitWidth: 60; implicitHeight: 34
            enabled: fUrlHer.text.trim().length > 0
            text: qsTr("Oeffnen")
            contentItem: Text { text: parent.text; color: parent.enabled ? theme.accent : theme.textMuted;
                                font.pixelSize: 11;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? theme.hover : theme.inputBg;
                                    radius: 4; border.color: parent.enabled ? theme.accent : theme.border }
            onClicked: Qt.openUrlExternally(fUrlHer.text.trim())
        }
    }

    Text { text: qsTr("Datenblatt"); color: theme.textMuted; font.pixelSize: 12 }
    RowLayout {
        Layout.fillWidth: true; spacing: 6
        NavTextField {
            id: fUrlDat; Layout.fillWidth: true
            tabTarget: fBez; backtabTarget: fUrlHer
            placeholderText: "https://..."
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary; font.pixelSize: 13
        }
        Button {
            implicitWidth: 60; implicitHeight: 34
            enabled: fUrlDat.text.trim().length > 0
            text: qsTr("Oeffnen")
            contentItem: Text { text: parent.text; color: parent.enabled ? theme.accent : theme.textMuted;
                                font.pixelSize: 11;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered && parent.enabled ? theme.hover : theme.inputBg;
                                    radius: 4; border.color: parent.enabled ? theme.accent : theme.border }
            onClicked: Qt.openUrlExternally(fUrlDat.text.trim())
        }
    }
}
