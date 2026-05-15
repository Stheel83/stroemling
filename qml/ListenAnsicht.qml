import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "la"

Item {
    id: panel

    property int    projektId:   -1
    property string projektName: ""
    property var    theme
    property bool   debug:       false
    property var    canvas:      null

    onProjektIdChanged: laden()
    onVisibleChanged:   if (visible && projektId >= 0) laden()

    function laden() {
        if (projektId < 0) {
            stuecklisteModel.clear(); querverweisModel.clear()
            aderlisteModel.clear();   klemmenplanModel.clear()
            panel._kabelDaten = []; return
        }
        stuecklisteModel.clear()
        var sl = db.stueckliste(projektId)
        for (var i = 0; i < sl.length; i++) stuecklisteModel.append(sl[i])

        querverweisModel.clear()
        var qvl = db.querverweisListe(projektId)
        for (var j = 0; j < qvl.length; j++) querverweisModel.append(qvl[j])

        aderlisteModel.clear()
        var al = db.aderliste(projektId)
        for (var k = 0; k < al.length; k++) aderlisteModel.append(al[k])

        klemmenplanModel.clear()
        var kp = db.klemmenplan(projektId)
        for (var m = 0; m < kp.length; m++) klemmenplanModel.append(kp[m])

        panel._kabelDaten    = db.kabelListeAufgeschluesselt(projektId)
        panel._kabelExpanded = {}
    }

    ListModel { id: stuecklisteModel }
    ListModel { id: querverweisModel }
    ListModel { id: aderlisteModel }
    ListModel { id: klemmenplanModel }

    property alias _stuecklisteModel: stuecklisteModel
    property alias _querverweisModel: querverweisModel
    property alias _aderlisteModel:   aderlisteModel
    property alias _klemmenplanModel: klemmenplanModel

    property var _kabelDaten:    []
    property var _kabelExpanded: ({})

    readonly property int klemmenplanZaehler: {
        var n = 0
        for (var i = 0; i < klemmenplanModel.count; i++)
            if (klemmenplanModel.get(i).typ === "klemme") n++
        return n
    }

    readonly property var slCols: [
        { header: "BMK",        w: 110 }, { header: "Typ",        w: 110 },
        { header: "Freitext 1", w: 130 }, { header: "Freitext 2", w: 130 },
        { header: "Seite",      w: 65  }, { header: "==Anlage",   w: 65  },
        { header: "++Ort",      w: 65  }, { header: "=Anlage",    w: 55  },
        { header: "+Ort",       w: 55  }
    ]
    readonly property var qvCols: [
        { header: "Signalname", w: 160 }, { header: "Richtung",  w: 100 },
        { header: "Seite",      w: 90  }, { header: "Zielseite", w: 90  }
    ]
    readonly property var alCols: [
        { header: "Bezeichnung",  w: 80 }, { header: "Aderfarbe",   w: 70 },
        { header: "Querschnitt",  w: 80 }, { header: "Länge (m)",   w: 70 },
        { header: "Seite",        w: 60 }, { header: "==Anlage",    w: 60 },
        { header: "++Ort",        w: 60 }, { header: "=Anlage",     w: 55 },
        { header: "+Ort",         w: 55 }
    ]
    readonly property var kpCols: [
        { header: "Nr.",         w: 55  }, { header: "Bauteil",     w: 155 },
        { header: "Typ",         w: 90  }, { header: "Querschnitt", w: 110 },
        { header: "Farbe",       w: 100 }, { header: "Potenzial",   w: 100 },
        { header: "+Ort",        w: 80  }
    ]
    readonly property var klCols: [
        { header: "Bezeichnung", w: 110 }, { header: "Kabeltyp",  w: 130 },
        { header: "Adern",       w: 50  }, { header: "mm²",       w: 55  },
        { header: "Länge (m)",   w: 70  }, { header: "Von-Ort",   w: 100 },
        { header: "Nach-Ort",    w: 100 }, { header: "Linien",    w: 50  }
    ]
    readonly property var klAderCols: [
        { header: "Nr",          w: 40  }, { header: "Farbe",       w: 70  },
        { header: "Bezeichnung", w: 90  }, { header: "Seite",       w: 80  },
        { header: "Netz",        w: 130 }, { header: "Von",         w: 90  },
        { header: "Nach",        w: 90  }
    ]

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ── Titelleiste ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 48; color: theme.sidebar
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                spacing: 12
                Text { text: qsTr("Listen"); font.pixelSize: 16; font.weight: Font.Medium; color: theme.textSecondary }
                Text { text: projektName ? "– " + projektName : ""; font.pixelSize: 13; color: theme.borderLight;
                       Layout.fillWidth: true; elide: Text.ElideRight }
                Rectangle {
                    width: 32; height: 32; radius: 6
                    color: refreshMa.containsMouse ? theme.activeItemAlt : "transparent"
                    Text { anchors.centerIn: parent; text: "↻"; font.pixelSize: 18; color: theme.accent }
                    MouseArea {
                        id: refreshMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (panel.canvas) panel.canvas.verdrahtungswegeAktualisieren()
                            panel.laden()
                        }
                    }
                    ToolTip.visible: refreshMa.containsMouse; ToolTip.text: qsTr("Neu laden"); ToolTip.delay: 400
                }
            }
        }

        Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

        // ── Tab-Leiste ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36; color: theme.surface
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 2
                Repeater {
                    model: [
                        { label: qsTr("Stückliste  (")   + stuecklisteModel.count + ")",  tab: 0 },
                        { label: qsTr("Querverweise  (") + querverweisModel.count + ")",  tab: 1 },
                        { label: qsTr("Aderliste  (")    + aderlisteModel.count   + ")",  tab: 2 },
                        { label: qsTr("Klemmenplan  (")  + klemmenplanZaehler     + ")",  tab: 3 },
                        { label: qsTr("Kabelliste  (")   + panel._kabelDaten.length + ")", tab: 4 }
                    ]
                    delegate: Rectangle {
                        width: tabLabel.implicitWidth + 24; height: 28; radius: 5
                        color: tabStack.currentIndex === modelData.tab
                               ? theme.activeItemAlt : (tabMa.containsMouse ? theme.hover : "transparent")
                        border.color: tabStack.currentIndex === modelData.tab ? theme.accent : "transparent"
                        Text {
                            id: tabLabel; anchors.centerIn: parent
                            text: modelData.label; font.pixelSize: 12
                            color: tabStack.currentIndex === modelData.tab ? theme.textSecondary : theme.borderLight
                        }
                        MouseArea {
                            id: tabMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: tabStack.currentIndex = modelData.tab
                        }
                    }
                }
            }
        }

        Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

        // ── Tab-Inhalt ───────────────────────────────────────────
        StackLayout {
            id: tabStack
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: 0

            LaTabStueckliste  { panel: panel; theme: theme }
            LaTabQuerverweise { panel: panel; theme: theme }
            LaTabAderliste    { panel: panel; theme: theme }
            LaTabKlemmenplan  { panel: panel; theme: theme }
            LaTabKabelliste   { panel: panel; theme: theme }
        }
    }

    DebugLabel { panelName: qsTr("Listen-Ansicht"); visible: panel.debug }
}
