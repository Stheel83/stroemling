import QtQuick
import QtQuick.Layouts
import "components"
import "ba"
import stroemling

Item {
    id: root

    property var    theme
    property bool   debug:                      false
    property int    projektId:                  -1
    property string aktiveSpezialAnsicht:       ""   // "" | "klemmenreihen" | "geraetekaesten"
    property int    selectedBauteilId:            -1
    property string selectedBauteilBezeichnung:   ""
    property string selectedBauteilHersteller:    ""
    property string selectedBauteilArtikelnummer: ""

    signal klemmeAnschlussModusAPlatzieren(int bauteilKlemmeId, string anschlussBezeichnung, string bmk, int klemmeId)
    signal klemmenEditorAngefordert(int bauteilId, string bezeichnung)
    signal leisteKanvasAktualisiert()
    signal kabelEditorAngefordert(int bauteilId, string bezeichnung)
    signal steckverbinderEditorAngefordert(int bauteilId, string bezeichnung)
    signal konfkabelEditorAngefordert(int bauteilId, string bezeichnung)
    signal kontaktEditorAngefordert(int bauteilId, string bezeichnung)
    signal geraetekastenSprungAngefordert(int seiteId, string blattnr, string seiteBez, real wx, real wy)
    signal makroListeGeaendert()

    Connections {
        target: kabelModel
        function onKanvasGeaendert() { root.leisteKanvasAktualisiert() }
    }
    Connections {
        target: klemmenreiheModel
        function onKanvasGeaendert() { root.leisteKanvasAktualisiert() }
    }

    RowLayout {
        anchors.fill: parent; spacing: 0

        BaKategorieSidebar {
            panel: root; theme: root.theme
            Layout.fillHeight: true; width: 240
            onKlemmenEditorAngefordert:       function(id, bez) { root.klemmenEditorAngefordert(id, bez) }
            onKabelEditorAngefordert:         function(id, bez) { root.kabelEditorAngefordert(id, bez)  }
            onSteckverbinderEditorAngefordert: function(id, bez) { root.steckverbinderEditorAngefordert(id, bez) }
            onKonfkabelEditorAngefordert:      function(id, bez) { root.konfkabelEditorAngefordert(id, bez) }
            onKontaktEditorAngefordert:        function(id, bez) { root.kontaktEditorAngefordert(id, bez) }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: theme.border }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 400

            BaBauteilListe {
                anchors.fill: parent
                visible: root.aktiveSpezialAnsicht === ""
                panel: root; theme: root.theme
                onKlemmenEditorAngefordert:       function(id, bez) { root.klemmenEditorAngefordert(id, bez) }
                onKabelEditorAngefordert:         function(id, bez) { root.kabelEditorAngefordert(id, bez)  }
                onSteckverbinderEditorAngefordert: function(id, bez) { root.steckverbinderEditorAngefordert(id, bez) }
                onKonfkabelEditorAngefordert:      function(id, bez) { root.konfkabelEditorAngefordert(id, bez) }
                onKontaktEditorAngefordert:        function(id, bez) { root.kontaktEditorAngefordert(id, bez) }
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
                onLeisteKanvasAktualisiert: root.leisteKanvasAktualisiert()
            }

            BaGeraetekastenAnsicht {
                anchors.fill: parent
                visible:   root.aktiveSpezialAnsicht === "geraetekaesten"
                theme:     root.theme
                debug:     root.debug
                projektId: root.projektId
                onSprungAngefordert: function(seiteId, blattnr, seiteBez, wx, wy) {
                    root.geraetekastenSprungAngefordert(seiteId, blattnr, seiteBez, wx, wy)
                }
            }

            BaMakroBibliothek {
                anchors.fill: parent
                visible: root.aktiveSpezialAnsicht === "makros"
                theme:   root.theme
                debug:   root.debug
                onMakroListeGeaendert: root.makroListeGeaendert()
            }

            DebugLabel {
                panelName: {
                    switch (root.aktiveSpezialAnsicht) {
                        case "klemmenreihen":  return qsTr("Klemmenreihen-Ansicht")
                        case "geraetekaesten": return qsTr("Geraetekaesten-Ansicht")
                        case "makros":         return qsTr("Makro-Bibliothek")
                        default:               return qsTr("Bauteil-Liste")
                    }
                }
                visible: root.debug
            }
        }
    }

    DebugLabel { panelName: qsTr("Bauteile-Ansicht"); visible: root.debug }
}
