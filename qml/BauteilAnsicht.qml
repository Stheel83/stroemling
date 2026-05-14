import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "ba"

Item {
    id: root

    property var    theme
    property bool   debug:                      false
    property int    projektId:                  -1
    property string aktiveSpezialAnsicht:       ""   // "" | "klemmenreihen" | "makros"
    property var    makroListe:                 []   // [{id, name, beschreibung, kategorie, elementAnzahl}]
    property int    selectedBauteilId:            -1
    property string selectedBauteilBezeichnung:   ""
    property string selectedBauteilHersteller:    ""
    property string selectedBauteilArtikelnummer: ""

    signal klemmeAnschlussModusAPlatzieren(int bauteilKlemmeId, string anschlussBezeichnung, string bmk, int klemmeId)
    signal klemmenEditorAngefordert(int bauteilId, string bezeichnung)
    signal kabelEditorAngefordert(int bauteilId, string bezeichnung)
    signal makroEinfuegenAngefordert(int makroId, string name)

    function makroListeAktualisieren() {
        root.makroListe = db.makroListe()
    }

    RowLayout {
        anchors.fill: parent; spacing: 0

        BaKategorieSidebar {
            panel: root; theme: root.theme
            Layout.fillHeight: true; width: 240
            onKlemmenEditorAngefordert: function(id, bez) { root.klemmenEditorAngefordert(id, bez) }
            onKabelEditorAngefordert:   function(id, bez) { root.kabelEditorAngefordert(id, bez)  }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: theme.border }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 400

            BaBauteilListe {
                anchors.fill: parent
                visible: root.aktiveSpezialAnsicht === ""
                panel: root; theme: root.theme
                onKlemmenEditorAngefordert: function(id, bez) { root.klemmenEditorAngefordert(id, bez) }
                onKabelEditorAngefordert:   function(id, bez) { root.kabelEditorAngefordert(id, bez)  }
            }

            KlemmenreihenAnsicht {
                anchors.fill: parent
                visible:   root.aktiveSpezialAnsicht === "klemmenreihen"
                theme:     root.theme
                debug:     root.debug
                projektId: root.projektId
                onKlemmeAnschlussModusAPlatzieren: function(bkId, bez, bmk, kId) {
                    root.klemmeAnschlussModusAPlatzieren(bkId, bez, bmk, kId)
                }
            }

            BaMakroAnsicht {
                anchors.fill: parent
                visible: root.aktiveSpezialAnsicht === "makros"
                panel: root; theme: root.theme
                onMakroEinfuegenAngefordert: function(id, name) { root.makroEinfuegenAngefordert(id, name) }
            }

            DebugLabel {
                panelName: root.aktiveSpezialAnsicht === "" ? qsTr("Bauteil-Liste") : qsTr("Klemmenreihen-Ansicht")
                visible:   root.debug
            }
        }
    }

    DebugLabel { panelName: qsTr("Bauteile-Ansicht"); visible: root.debug }
}
