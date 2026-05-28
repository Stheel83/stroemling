import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    property int    bauteilId:            -1
    property string bauteilBezeichnung:   ""
    property string bauteilHersteller:    ""
    property string bauteilArtikelnummer: ""
    property var    theme
    property bool   debug:                false

    signal bauteilGespeichert(int bauteilId, string bezeichnung)

    DebugLabel { panelName: qsTr("Kabel-Editor"); visible: root.debug }

    SplitView {
        anchors.fill: parent
        orientation:  Qt.Horizontal

        handle: Rectangle {
            implicitWidth: 6; implicitHeight: 6
            color: SplitHandle.pressed ? theme.accent : SplitHandle.hovered ? theme.activeItem : theme.surface
            Rectangle {
                anchors.centerIn: parent; width: 2; height: 24; radius: 1
                color: parent.SplitHandle.hovered || parent.SplitHandle.pressed ? theme.accentLight : theme.panelMid
            }
        }

        KabelEditorLinksBlock {
            SplitView.preferredWidth: 380
            SplitView.minimumWidth:   260
            SplitView.fillHeight:     true
            bauteilId:            root.bauteilId
            bauteilBezeichnung:   root.bauteilBezeichnung
            bauteilHersteller:    root.bauteilHersteller
            bauteilArtikelnummer: root.bauteilArtikelnummer
            theme:                root.theme
            onBauteilGespeichert: function(id, bez) { root.bauteilGespeichert(id, bez) }
        }

        KabelEditorAdernTabelle {
            SplitView.fillWidth:    true
            SplitView.minimumWidth: 200
            theme: root.theme
            debug: root.debug
        }
    }
}
