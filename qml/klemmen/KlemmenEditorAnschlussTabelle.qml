import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var theme
    property bool         debug: false

    DebugLabel { panelName: qsTr("Anschluss-Liste"); visible: root.debug }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        KlemmenVorschau {
            Layout.fillWidth:       true
            Layout.preferredHeight: implicitHeight
            theme:              root.theme
            klemme:             klemmeModel.klemme
            anschluesse:        klemmeModel.anschluesse
            bruecken:           klemmeModel.bruecken
            zeigeBezeichnungen: true
            debug:              root.debug
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        Rectangle {
            Layout.fillWidth: true; height: 28; color: root.theme.surfaceDeep
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                Text { text: qsTr("Bezeichnung"); color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 80 }
                Text { text: qsTr("Seite");       color: root.theme.textMuted; font.pixelSize: 11; Layout.preferredWidth: 60 }
                Text { text: qsTr("Ebene");       color: root.theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true  }
            }
        }

        ListView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            clip: true
            model: klemmeModel.anschluesse

            delegate: Rectangle {
                width:  ListView.view.width
                height: 26
                color:  index % 2 === 0 ? root.theme.tableEven : root.theme.tableOdd

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    Text { text: modelData.bezeichnung;   color: root.theme.textPrimary;   font.pixelSize: 11; Layout.preferredWidth: 80 }
                    Text { text: modelData.seite;         color: root.theme.textSecondary; font.pixelSize: 11; Layout.preferredWidth: 60 }
                    Text { text: String(modelData.ebene); color: root.theme.textSecondary; font.pixelSize: 11; Layout.fillWidth: true }
                }
            }
        }
    }
}
