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
            klaModel.clear()
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

        klaModel.clear()
        var kla = db.klemmlistenauszug(projektId)
        for (var n = 0; n < kla.length; n++) klaModel.append(kla[n])

        panel._kabelDaten    = db.kabelListeAufgeschluesselt(projektId)
        panel._kabelExpanded = {}

        panel._svDaten = db.steckverbinderListe(projektId)
        panel._bpDaten = db.steckverbinderBelegungsplan(projektId)
    }

    ListModel { id: stuecklisteModel }
    ListModel { id: querverweisModel }
    ListModel { id: aderlisteModel }
    ListModel { id: klemmenplanModel }
    ListModel { id: klaModel }

    property alias _stuecklisteModel: stuecklisteModel
    property alias _querverweisModel: querverweisModel
    property alias _aderlisteModel:   aderlisteModel
    property alias _klemmenplanModel: klemmenplanModel
    property alias _klaModel:         klaModel

    property var _kabelDaten:    []
    property var _kabelExpanded: ({})
    property var _svDaten:       []
    property var _bpDaten:       []

    readonly property int _bpKontaktAnzahl: {
        var n = 0
        for (var i = 0; i < _bpDaten.length; i++)
            if (_bpDaten[i] && _bpDaten[i].typ === "kontakt") n++
        return n
    }

    function netzeNummerieren(praefix, start, schrittweite) {
        if (projektId < 0) return 0
        var sc   = Math.max(1, schrittweite)
        var alle = db.verbindungenProjektLaden(projektId)

        // Bereits vergebene Nummern sammeln (nur passend zum Schema)
        var verwendet = {}
        for (var i = 0; i < alle.length; i++) {
            var bez = alle[i].bezeichnung || ""
            if (!bez || !bez.startsWith(praefix)) continue
            var rest = bez.substring(praefix.length)
            var n = parseInt(rest, 10)
            if (!isNaN(n) && n.toString() === rest) verwendet[n] = true
        }

        // Unbenannte Netze (nicht pe/n, keine bestehende Bezeichnung) nummerieren
        var zuweisungen = []
        var n = start
        for (var j = 0; j < alle.length; j++) {
            var v = alle[j]
            if (v.bezeichnung) continue
            var st = v.signaltyp || ""
            if (st === "pe" || st === "n") continue
            while (verwendet[n]) n += sc
            zuweisungen.push({id: v.id, bezeichnung: praefix + n})
            verwendet[n] = true
            n += sc
        }

        if (zuweisungen.length > 0) {
            db.verbindungenBulkBezeichnungSetzen(projektId, zuweisungen)
            panel.laden()
            // Canvas-Annotationscache der aktuellen Seite aktualisieren
            if (panel.canvas) panel.canvas.verbindungAnnotationenNeuLaden()
        }
        return zuweisungen.length
    }

    readonly property int klemmenplanZaehler: {
        var n = 0
        for (var i = 0; i < klemmenplanModel.count; i++)
            if (klemmenplanModel.get(i).typ === "klemme") n++
        return n
    }

    readonly property int _klaAnschlussZaehler: {
        var n = 0
        for (var i = 0; i < klaModel.count; i++)
            if (klaModel.get(i).typ === "anschluss") n++
        return n
    }
    readonly property int _klaMaxStegSpalten: {
        var max = 0
        for (var i = 0; i < klaModel.count; i++) {
            var row = klaModel.get(i)
            if (row.typ === "leiste") { var n = row.stegAnzahl || 0; if (n > max) max = n }
        }
        return max
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
    readonly property var klaCols: [
        { header: qsTr("Nr."),            w: 50  },
        { header: qsTr("Von (Seite A)"),  w: 210 },
        { header: qsTr("Qs"),             w: 80  },
        { header: qsTr("Farbe"),          w: 90  },
        { header: qsTr("Nach (Seite B)"), w: 210 }
    ]
    readonly property var klCols: [
        { header: "Bezeichnung", w: 110 }, { header: "Kabeltyp",  w: 130 },
        { header: "Adern",       w: 50  }, { header: "mm²",       w: 55  },
        { header: "Länge (m)",   w: 70  }, { header: "Von-Ort",   w: 100 },
        { header: "Nach-Ort",    w: 100 }, { header: "Linien",    w: 50  }
    ]
    readonly property var svCols: [
        { header: "BMK",         w: 80  }, { header: "Bezeichnung", w: 120 },
        { header: "Bauteil/Typ", w: 130 }, { header: "Hersteller",  w: 110 },
        { header: "Polzahl",     w: 60  }, { header: "IP gesteckt", w: 75  },
        { header: "Kodierung",   w: 70  }, { header: "Geschirmt",   w: 70  },
        { header: "Seite",       w: 55  }, { header: "==Anlage",    w: 65  },
        { header: "++Ort",       w: 65  }, { header: "=Anlage",     w: 55  },
        { header: "+Ort",        w: 55  }
    ]
    readonly property var bpCols: [
        { header: qsTr("Pin"),        w: 45  }, { header: qsTr("Typ"),       w: 90  },
        { header: qsTr("Symbol-BMK"), w: 100 }, { header: qsTr("Signal"),    w: 130 },
        { header: qsTr("Farbe"),      w: 80  }, { header: qsTr("mm²"),       w: 60  },
        { header: qsTr("Seite"),      w: 60  }
    ]
    readonly property var klAderCols: [
        { header: "Nr",          w: 40  }, { header: "Farbe",       w: 70  },
        { header: "Bezeichnung", w: 90  }, { header: "Seite",       w: 80  },
        { header: "Netz",        w: 130 }, { header: "Von",         w: 90  },
        { header: "Nach",        w: 90  }
    ]

    Rectangle { anchors.fill: parent; color: theme.surface }

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
                // ── Netze nummerieren ───────────────────────────────────
                Rectangle {
                    id: numBtn
                    width: 32; height: 32; radius: 6
                    color: numMa.containsMouse ? theme.activeItemAlt : "transparent"
                    Text { anchors.centerIn: parent; text: "N"; font.pixelSize: 14; font.weight: Font.Medium; color: theme.accent }
                    MouseArea {
                        id: numMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: numPopup.open()
                    }
                    ToolTip.visible: numMa.containsMouse; ToolTip.text: qsTr("Verbindungen nummerieren – allen unbeschrifteten Leitungen automatisch fortlaufende Nummern zuweisen"); ToolTip.delay: 400

                    Popup {
                        id: numPopup
                        parent: Overlay.overlay
                        x: numBtn.mapToItem(parent, 0, 0).x - width + numBtn.width
                        y: numBtn.mapToItem(parent, 0, 0).y + numBtn.height + 4
                        width: 240; padding: 12
                        modal: false; closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        background: Rectangle {
                            color: theme.surface; radius: 6
                            border.color: theme.border
                            layer.enabled: true
                        }

                        property string _praefix:      ""
                        property int    _start:        1
                        property int    _schrittweite: 1
                        property string _meldung:      ""

                        Column {
                            width: parent.width; spacing: 8

                            Text {
                                text: qsTr("Netze nummerieren")
                                font.pixelSize: 12; font.weight: Font.Medium
                                color: theme.textSecondary
                            }

                            // Präfix
                            Column {
                                width: parent.width; spacing: 3
                                Text { text: qsTr("Präfix"); font.pixelSize: 10; color: theme.panelMid }
                                Rectangle {
                                    width: parent.width; height: 28; radius: 3
                                    color: theme.inputBg; border.color: praefixTf.activeFocus ? theme.accent : theme.border
                                    TextInput {
                                        id: praefixTf
                                        anchors { fill: parent; margins: 5 }
                                        color: theme.textSecondary; font.pixelSize: 11
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: numPopup._praefix
                                        onTextChanged: numPopup._praefix = text
                                    }
                                }
                            }

                            // Startnummer + Schrittweite nebeneinander
                            Row {
                                width: parent.width; spacing: 8
                                Column {
                                    width: (parent.width - 8) / 2; spacing: 3
                                    Text { text: qsTr("Startnummer"); font.pixelSize: 10; color: theme.panelMid }
                                    Rectangle {
                                        width: parent.width; height: 28; radius: 3
                                        color: theme.inputBg; border.color: startTf.activeFocus ? theme.accent : theme.border
                                        TextInput {
                                            id: startTf
                                            anchors { fill: parent; margins: 5 }
                                            color: theme.textSecondary; font.pixelSize: 11
                                            verticalAlignment: TextInput.AlignVCenter
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            text: numPopup._start
                                            onTextChanged: { var n = parseInt(text, 10); if (!isNaN(n) && n >= 1) numPopup._start = n }
                                        }
                                    }
                                }
                                Column {
                                    width: (parent.width - 8) / 2; spacing: 3
                                    Text { text: qsTr("Schrittweite"); font.pixelSize: 10; color: theme.panelMid }
                                    Rectangle {
                                        width: parent.width; height: 28; radius: 3
                                        color: theme.inputBg; border.color: schrittTf.activeFocus ? theme.accent : theme.border
                                        TextInput {
                                            id: schrittTf
                                            anchors { fill: parent; margins: 5 }
                                            color: theme.textSecondary; font.pixelSize: 11
                                            verticalAlignment: TextInput.AlignVCenter
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            text: numPopup._schrittweite
                                            onTextChanged: { var n = parseInt(text, 10); if (!isNaN(n) && n >= 1) numPopup._schrittweite = n }
                                        }
                                    }
                                }
                            }

                            // Meldung nach Ausführung
                            Text {
                                visible: numPopup._meldung !== ""
                                text: numPopup._meldung
                                font.pixelSize: 10; color: theme.accent
                                wrapMode: Text.Wrap; width: parent.width
                            }

                            // Buttons
                            Row {
                                spacing: 8
                                Rectangle {
                                    width: 120; height: 30; radius: 5
                                    color: ausfuehrenMa.containsMouse ? theme.accent : theme.activeItemAlt
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Nummerieren")
                                        font.pixelSize: 11; color: theme.textSecondary
                                    }
                                    MouseArea {
                                        id: ausfuehrenMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var anz = panel.netzeNummerieren(numPopup._praefix,
                                                                              numPopup._start,
                                                                              numPopup._schrittweite)
                                            numPopup._meldung = anz > 0
                                                ? qsTr("%1 Netz(e) nummeriert").arg(anz)
                                                : qsTr("Keine unbeschrifteten Netze")
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 80; height: 30; radius: 5
                                    color: schliesseMa.containsMouse ? theme.hover : "transparent"
                                    border.color: theme.border
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Schließen")
                                        font.pixelSize: 11; color: theme.borderLight
                                    }
                                    MouseArea {
                                        id: schliesseMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { numPopup._meldung = ""; numPopup.close() }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: 32; height: 32; radius: 6
                    color: refreshMa.containsMouse ? theme.activeItemAlt : "transparent"
                    Text { anchors.centerIn: parent; text: "↻"; font.pixelSize: 18; color: theme.accent }
                    MouseArea {
                        id: refreshMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (panel.projektId >= 0)
                                db.kabelAderEndpunkteBerechnenUndSpeichern(panel.projektId)
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
                        { label: qsTr("Stückliste  (")        + stuecklisteModel.count    + ")",  tab: 0 },
                        { label: qsTr("Querverweise  (")      + querverweisModel.count    + ")",  tab: 1 },
                        { label: qsTr("Aderliste  (")         + aderlisteModel.count      + ")",  tab: 2 },
                        { label: qsTr("Klemmenplan  (")       + klemmenplanZaehler        + ")",  tab: 3 },
                        { label: qsTr("Klemmlistenauszug  (") + panel._klaAnschlussZaehler + ")", tab: 4 },
                        { label: qsTr("Kabelliste  (")        + panel._kabelDaten.length  + ")",  tab: 5 },
                        { label: qsTr("Steckverbinder  (")    + panel._svDaten.length     + ")",  tab: 6 },
                        { label: qsTr("Belegungsplan  (")     + panel._bpKontaktAnzahl    + ")",  tab: 7 }
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

            LaTabStueckliste       { panel: panel; theme: panel.theme }
            LaTabQuerverweise      { panel: panel; theme: panel.theme }
            LaTabAderliste         { panel: panel; theme: panel.theme }
            LaTabKlemmenplan       { panel: panel; theme: panel.theme }
            LaTabKlemmlistenauszug { panel: panel; theme: panel.theme }
            LaTabKabelliste        { panel: panel; theme: panel.theme }
            LaTabSteckverbinder    { panel: panel; theme: panel.theme }
            LaTabBelegungsplan     { panel: panel; theme: panel.theme }
        }
    }

    DebugLabel { panelName: qsTr("Listen-Ansicht"); visible: panel.debug }
}
