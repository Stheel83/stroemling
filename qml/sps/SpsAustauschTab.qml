import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Tab „Import / Export" der SPS/PLS-Ansicht: ein Umschalter, darunter je nach Modus
// SpsExportTab oder SpsImportTab (gleiche Zweispalten-Gestaltung). Beide Seiten bleiben
// beim Umschalten erhalten (StackLayout), damit Konfiguration und Prüfergebnis nicht
// verloren gehen.
Item {
    id: root

    required property var theme
    property int    projektId: -1
    property var    racks: []
    property int    kanalAnzahl: 0
    property string projektName: ""

    // "export" | "import"
    property string modus: "export"

    signal importiert(var bericht)

    function importAnzeigen() { modus = "import" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Umschalter ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: root.theme.surfaceDeep

            Row {
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: [
                        { wert: "export", text: qsTr("Export") },
                        { wert: "import", text: qsTr("Import") }
                    ]
                    delegate: Rectangle {
                        id: seg
                        required property var modelData
                        required property int index
                        readonly property bool aktiv: root.modus === modelData.wert
                        width: 150; height: 30
                        radius: 4
                        color: aktiv ? root.theme.accent : (segMa.containsMouse ? root.theme.hover : root.theme.inputBg)
                        border.color: aktiv ? root.theme.accent : root.theme.border
                        Text {
                            anchors.centerIn: parent
                            text: seg.modelData.text
                            font.pixelSize: 13
                            font.bold: seg.aktiv
                            color: seg.aktiv ? "#ffffff" : root.theme.textPrimary
                        }
                        MouseArea {
                            id: segMa
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.modus = seg.modelData.wert
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.modus === "import" ? 1 : 0

            SpsExportTab {
                theme: root.theme
                projektId: root.projektId
                racks: root.racks
                kanalAnzahl: root.kanalAnzahl
                projektName: root.projektName
            }

            SpsImportTab {
                theme: root.theme
                projektId: root.projektId
                onImportiert: function(bericht) { root.importiert(bericht) }
            }
        }
    }
}
