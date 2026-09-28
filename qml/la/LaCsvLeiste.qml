import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var theme
    property string listenName: ""
    property int    anzahl:     0
    property bool   hatDaten:   anzahl > 0
    // LISTEN-IDEEN-01: optionales Freitext-Filterfeld (nur bei flachen Listen
    // sinnvoll verdrahtet, s. ListenAnsicht.qml) + PDF-Export-Button.
    property bool   filterAktiv: true
    property alias  filterText:  filterFeld.text
    signal csvKlick
    signal pdfKlick

    Layout.fillWidth: true
    height: 32
    color: theme.surface

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
        spacing: 8
        Text { text: root.listenName; font.pixelSize: 11; color: theme.textSubtle }

        Rectangle {
            visible: root.filterAktiv
            Layout.preferredWidth: 160; Layout.preferredHeight: 22; radius: 4
            color: theme.hover; border.color: filterFeld.activeFocus ? theme.accent : theme.border

            TextField {
                id: filterFeld
                anchors.fill: parent; anchors.margins: 1
                placeholderText: qsTr("Filtern…")
                font.pixelSize: 11; color: theme.textSecondary
                background: Item {}
                verticalAlignment: TextInput.AlignVCenter
                leftPadding: 6; rightPadding: 6
            }
        }
        Item { visible: root.filterAktiv; Layout.preferredWidth: 4 }

        Item { Layout.fillWidth: true }

        Rectangle {
            width: pdfBtnTxt.implicitWidth + 20; height: 24; radius: 4
            color: pdfBtnMa.containsMouse ? theme.activeItemAlt : theme.hover
            border.color: theme.border
            visible: root.hatDaten
            Text {
                id: pdfBtnTxt; anchors.centerIn: parent
                text: qsTr("PDF exportieren"); font.pixelSize: 11; color: theme.textSecondary
            }
            MouseArea {
                id: pdfBtnMa; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.pdfKlick()
            }
        }
        Rectangle {
            width: csvBtnTxt.implicitWidth + 20; height: 24; radius: 4
            color: csvBtnMa.containsMouse ? theme.activeItemAlt : theme.hover
            border.color: theme.border
            visible: root.hatDaten
            Text {
                id: csvBtnTxt; anchors.centerIn: parent
                text: qsTr("CSV exportieren"); font.pixelSize: 11; color: theme.textSecondary
            }
            MouseArea {
                id: csvBtnMa; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root.csvKlick()
            }
        }
    }
}
