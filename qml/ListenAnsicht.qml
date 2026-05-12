import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"

Item {
    id: panel

    property int    projektId:   -1
    property string projektName: ""
    property var    theme
    property bool   debug:       false

    onProjektIdChanged:  laden()
    onVisibleChanged:    if (visible && projektId >= 0) laden()

    function laden() {
        if (projektId < 0) {
            stuecklisteModel.clear()
            querverweisModel.clear()
            aderlisteModel.clear()
            klemmenplanModel.clear()
            kabellisteModel.clear()
            return
        }
        stuecklisteModel.clear()
        var sl = db.stueckliste(projektId)
        for (var i = 0; i < sl.length; i++)
            stuecklisteModel.append(sl[i])

        querverweisModel.clear()
        var qvl = db.querverweisListe(projektId)
        for (var j = 0; j < qvl.length; j++)
            querverweisModel.append(qvl[j])

        aderlisteModel.clear()
        var al = db.aderliste(projektId)
        for (var k = 0; k < al.length; k++)
            aderlisteModel.append(al[k])

        klemmenplanModel.clear()
        var kp = db.klemmenplan(projektId)
        for (var m = 0; m < kp.length; m++)
            klemmenplanModel.append(kp[m])

        kabellisteModel.clear()
        var kbl = db.kabelListe(projektId)
        for (var n = 0; n < kbl.length; n++)
            kabellisteModel.append(kbl[n])
    }

    ListModel { id: stuecklisteModel }
    ListModel { id: querverweisModel }
    ListModel { id: aderlisteModel }
    ListModel { id: klemmenplanModel }
    ListModel { id: kabellisteModel }

    // Anzahl echter Klemmen-Zeilen im Klemmenplan (ohne Gruppen-Header)
    readonly property int klemmenplanZaehler: {
        var n = 0
        for (var i = 0; i < klemmenplanModel.count; i++)
            if (klemmenplanModel.get(i).typ === "klemme") n++
        return n
    }

    // Spaltendefinitionen (Header-Texte + Breiten)
    readonly property var slCols: [
        { header: "BMK",        w: 110 },
        { header: "Typ",        w: 110 },
        { header: "Freitext 1", w: 130 },
        { header: "Freitext 2", w: 130 },
        { header: "Seite",      w: 65  },
        { header: "==Anlage",   w: 65  },
        { header: "++Ort",      w: 65  },
        { header: "=Anlage",    w: 55  },
        { header: "+Ort",       w: 55  }
    ]
    readonly property var qvCols: [
        { header: "Signalname", w: 160 },
        { header: "Richtung",   w: 100 },
        { header: "Seite",      w: 90  },
        { header: "Zielseite",  w: 90  }
    ]
    readonly property var alCols: [
        { header: "Bezeichnung",  w: 80 },
        { header: "Aderfarbe",    w: 70 },
        { header: "Querschnitt",  w: 80 },
        { header: "Länge (m)",    w: 70 },
        { header: "Seite",        w: 60 },
        { header: "==Anlage",     w: 60 },
        { header: "++Ort",        w: 60 },
        { header: "=Anlage",      w: 55 },
        { header: "+Ort",         w: 55 }
    ]
    readonly property var kpCols: [
        { header: "Nr.",         w: 55  },
        { header: "Bauteil",     w: 155 },
        { header: "Typ",         w: 90  },
        { header: "Querschnitt", w: 110 },
        { header: "Farbe",       w: 100 },
        { header: "Potenzial",   w: 100 },
        { header: "+Ort",        w: 80  }
    ]
    readonly property var klCols: [
        { header: "Bezeichnung", w: 120 },
        { header: "Kabeltyp",    w: 140 },
        { header: "Adern",       w: 60  },
        { header: "mm²",         w: 60  },
        { header: "Länge (m)",   w: 80  },
        { header: "Von-Ort",     w: 120 },
        { header: "Nach-Ort",    w: 120 }
    ]

    // Wiederverwendbare CSV-Export-Leiste (Inline-Komponente)
    component CsvLeiste: Rectangle {
        id: csvLeiste
        property string listenName: ""
        property int    anzahl:     0
        property bool   hatDaten:   anzahl > 0
        signal csvKlick

        Layout.fillWidth: true
        height:           32
        color:            theme.surface

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 8

            Text {
                text:           csvLeiste.listenName
                font.pixelSize: 11
                color:          theme.textSubtle
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width:  csvBtnTxt.implicitWidth + 20; height: 24; radius: 4
                color:  csvBtnMa2.containsMouse ? theme.activeItemAlt : theme.hover
                border.color: theme.border
                visible: csvLeiste.hatDaten
                Text {
                    id:               csvBtnTxt
                    anchors.centerIn: parent
                    text:             qsTr("CSV exportieren")
                    font.pixelSize:   11
                    color:            theme.textSecondary
                }
                MouseArea {
                    id:           csvBtnMa2
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    csvLeiste.csvKlick()
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing:      0

        // ── Titelleiste ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:           48
            color:            theme.sidebar

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                spacing: 12

                Text {
                    text:           qsTr("Listen")
                    font.pixelSize: 16
                    font.weight:    Font.Medium
                    color:          theme.textSecondary
                }
                Text {
                    text:             projektName ? "– " + projektName : ""
                    font.pixelSize:   13
                    color:            theme.borderLight
                    Layout.fillWidth: true
                    elide:            Text.ElideRight
                }

                Rectangle {
                    width: 32; height: 32; radius: 6
                    color: refreshMa.containsMouse ? theme.activeItemAlt : "transparent"
                    Text { anchors.centerIn: parent; text: "↻"; font.pixelSize: 18; color: theme.accent }
                    MouseArea {
                        id: refreshMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: panel.laden()
                    }
                    ToolTip.visible: refreshMa.containsMouse
                    ToolTip.text:    qsTr("Neu laden")
                    ToolTip.delay:   400
                }
            }
        }

        Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

        // ── Tab-Leiste ───────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height:           36
            color:            theme.surface

            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 2

                Repeater {
                    model: [
                        { label: qsTr("Stückliste  (")   + stuecklisteModel.count + ")",  tab: 0 },
                        { label: qsTr("Querverweise  (") + querverweisModel.count + ")",  tab: 1 },
                        { label: qsTr("Aderliste  (")    + aderlisteModel.count + ")",    tab: 2 },
                        { label: qsTr("Klemmenplan  (")  + klemmenplanZaehler + ")",      tab: 3 },
                        { label: qsTr("Kabelliste  (")   + kabellisteModel.count + ")",   tab: 4 }
                    ]
                    delegate: Rectangle {
                        width:  tabLabel.implicitWidth + 24; height: 28; radius: 5
                        color:  tabStack.currentIndex === modelData.tab
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
            id:                tabStack
            Layout.fillWidth:  true
            Layout.fillHeight: true
            currentIndex:      0

            // ── Tab 0: Stückliste ────────────────────────────────
            ColumnLayout {
                spacing: 0

                CsvLeiste {
                    listenName: qsTr("Stückliste")
                    anzahl:     stuecklisteModel.count
                    onCsvKlick: csvDialogStueckliste.open()
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                Rectangle {
                    Layout.fillWidth: true
                    height:           30
                    color:            theme.tableHeader

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: panel.slCols
                            delegate: Text {
                                width:          modelData.w
                                text:           modelData.header
                                font.pixelSize: 11
                                font.weight:    Font.Medium
                                color:          theme.textSubtle
                            }
                        }
                    }
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                ListView {
                    id:                 slView
                    Layout.fillWidth:   true
                    Layout.fillHeight:  true
                    model:              stuecklisteModel
                    clip:               true
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        width:  slView.width
                        height: 30
                        color:  index % 2 === 0 ? theme.tableEven : theme.tableOdd

                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 0

                            Text { width: panel.slCols[0].w; text: model.bmk       || ""; font.pixelSize: 12; color: theme.accent;       elide: Text.ElideRight }
                            Text { width: panel.slCols[1].w; text: model.symbolId  || ""; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.slCols[2].w; text: model.freitext1 || ""; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.slCols[3].w; text: model.freitext2 || ""; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.slCols[4].w; text: model.seite     || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                            Text { width: panel.slCols[5].w; text: model.anlageUO  || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                            Text { width: panel.slCols[6].w; text: model.ortUO     || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                            Text { width: panel.slCols[7].w; text: model.anlageKz  || ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                            Text { width: panel.slCols[8].w; text: model.ortKz     || ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                        }
                    }
                }

                Text {
                    visible:          stuecklisteModel.count === 0
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    text:             projektId >= 0 ? "Keine Symbole im Projekt" : "Kein Projekt ausgewählt"
                    font.pixelSize:   14; color: theme.borderDark
                }
            }

            // ── Tab 1: Querverweise ──────────────────────────────
            ColumnLayout {
                spacing: 0

                CsvLeiste {
                    listenName: qsTr("Querverweisliste")
                    anzahl:     querverweisModel.count
                    onCsvKlick: csvDialogQV.open()
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                Rectangle {
                    Layout.fillWidth: true
                    height:           30
                    color:            theme.tableHeader

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: panel.qvCols
                            delegate: Text {
                                width:          modelData.w
                                text:           modelData.header
                                font.pixelSize: 11
                                font.weight:    Font.Medium
                                color:          theme.textSubtle
                            }
                        }
                    }
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                ListView {
                    id:                 qvView
                    Layout.fillWidth:   true
                    Layout.fillHeight:  true
                    model:              querverweisModel
                    clip:               true
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        width:  qvView.width
                        height: 30
                        color:  index % 2 === 0 ? theme.tableEven : theme.tableOdd

                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 0

                            Text { width: panel.qvCols[0].w; text: model.signalname || "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.qvCols[1].w; text: model.richtung   || ""; font.pixelSize: 12;
                                   color: model.richtung === "ausgang" ? theme.accent : "#66ddaa"; elide: Text.ElideRight }
                            Text { width: panel.qvCols[2].w; text: model.seite      || ""; font.pixelSize: 12; color: theme.accentLight; elide: Text.ElideRight }
                            Text { width: panel.qvCols[3].w; text: model.zielSeite  || "–"; font.pixelSize: 12;
                                   color: model.zielSeite ? theme.accentLight : theme.borderDark; elide: Text.ElideRight }
                        }
                    }
                }

                Text {
                    visible:          querverweisModel.count === 0
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    text:             projektId >= 0 ? "Keine Querverweise im Projekt" : "Kein Projekt ausgewählt"
                    font.pixelSize:   14; color: theme.borderDark
                }
            }

            // ── Tab 2: Aderliste ─────────────────────────────────
            ColumnLayout {
                spacing: 0

                CsvLeiste {
                    listenName: qsTr("Aderliste")
                    anzahl:     aderlisteModel.count
                    onCsvKlick: csvDialogAder.open()
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                Rectangle {
                    Layout.fillWidth: true
                    height:           30
                    color:            theme.tableHeader

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: panel.alCols
                            delegate: Text {
                                width:          modelData.w
                                text:           modelData.header
                                font.pixelSize: 11
                                font.weight:    Font.Medium
                                color:          theme.textSubtle
                            }
                        }
                    }
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                ListView {
                    id:                 alView
                    Layout.fillWidth:   true
                    Layout.fillHeight:  true
                    model:              aderlisteModel
                    clip:               true
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        width:  alView.width
                        height: 30
                        color:  index % 2 === 0 ? theme.tableEven : theme.tableOdd

                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 0

                            Text { width: panel.alCols[0].w; text: model.bezeichnung    || "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.alCols[1].w; text: model.aderfarbe      || "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.alCols[2].w; text: model.querschnittMm2 > 0 ? model.querschnittMm2 + " mm²" : "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.alCols[3].w; text: model.laengeM        > 0 ? model.laengeM + " m"    : "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.alCols[4].w; text: model.seite          || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                            Text { width: panel.alCols[5].w; text: model.anlageUO       || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                            Text { width: panel.alCols[6].w; text: model.ortUO          || ""; font.pixelSize: 12; color: theme.accentLight;   elide: Text.ElideRight }
                            Text { width: panel.alCols[7].w; text: model.anlageKz       || ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                            Text { width: panel.alCols[8].w; text: model.ortKz          || ""; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                        }
                    }
                }

                Text {
                    visible:          aderlisteModel.count === 0
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    text:             projektId >= 0 ? "Keine Aderdefinitionen im Projekt" : "Kein Projekt ausgewählt"
                    font.pixelSize:   14; color: theme.borderDark
                }
            }

            // ── Tab 3: Klemmenplan ───────────────────────────────
            ColumnLayout {
                spacing: 0

                // CSV-Export-Leiste
                Rectangle {
                    Layout.fillWidth: true
                    height:           32
                    color:            theme.surface

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                        spacing: 8

                        Text {
                            text:           qsTr("Klemmenplan")
                            font.pixelSize: 11
                            color:          theme.textSubtle
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: csvBtn.implicitWidth + 20; height: 24; radius: 4
                            color: csvBtnMa.containsMouse ? theme.activeItemAlt : theme.hover
                            border.color: theme.border
                            visible: klemmenplanZaehler > 0
                            Text {
                                id:             csvBtn
                                anchors.centerIn: parent
                                text:           qsTr("CSV exportieren")
                                font.pixelSize: 11
                                color:          theme.textSecondary
                            }
                            MouseArea {
                                id:            csvBtnMa
                                anchors.fill:  parent
                                hoverEnabled:  true
                                cursorShape:   Qt.PointingHandCursor
                                onClicked:     csvDialog.open()
                            }
                        }
                    }
                }

                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                // Spalten-Header (nur für Klemmen-Zeilen, nicht Leisten-Header)
                Rectangle {
                    Layout.fillWidth: true
                    height:           30
                    color:            theme.tableHeader

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: panel.kpCols
                            delegate: Text {
                                width:          modelData.w
                                text:           modelData.header
                                font.pixelSize: 11
                                font.weight:    Font.Medium
                                color:          theme.textSubtle
                            }
                        }
                    }
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                ListView {
                    id:                 kpView
                    Layout.fillWidth:   true
                    Layout.fillHeight:  true
                    model:              klemmenplanModel
                    clip:               true
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        width:  kpView.width
                        height: model.typ === "leiste" ? 26 : 28

                        // Leisten-Gruppen-Header
                        color: model.typ === "leiste"
                               ? theme.tableHeader
                               : (index % 2 === 0 ? theme.tableEven : theme.tableOdd)

                        // Gruppen-Header: Leiste-BMK über volle Breite
                        Row {
                            visible:  model.typ === "leiste"
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            Text {
                                text:           model.typ === "leiste" ? model.bmk : ""
                                font.pixelSize: 11
                                font.weight:    Font.Bold
                                color:          theme.accent
                            }
                            Text {
                                text:           model.typ === "leiste" ? "– " + model.bezeichnung : ""
                                font.pixelSize: 11
                                color:          theme.textSubtle
                            }
                        }

                        // Klemmen-Zeile
                        Row {
                            visible:  model.typ === "klemme"
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 0

                            Text { width: panel.kpCols[0].w; text: model.typ === "klemme" ? (model.nummer || "–") : ""; font.pixelSize: 12; color: theme.textSecondary;  elide: Text.ElideRight }
                            Text { width: panel.kpCols[1].w; text: model.typ === "klemme" ? (model.bauteilBez || "–") : ""; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.kpCols[2].w; text: model.typ === "klemme" ? (model.anschlussTyp || "–") : ""; font.pixelSize: 12; color: theme.borderLight;  elide: Text.ElideRight }
                            Text { width: panel.kpCols[3].w; text: model.typ === "klemme" ? (model.querschnitt || "–") : ""; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }

                            // Farbe mit farbigem Punkt
                            Row {
                                width:   panel.kpCols[4].w
                                spacing: 4
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    width:  10; height: 10; radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: model.typ === "klemme" && model.farbeHex !== ""
                                    color:   model.typ === "klemme" ? (model.farbeHex || "transparent") : "transparent"
                                    border.color: theme.border; border.width: 1
                                }
                                Text {
                                    width:          panel.kpCols[4].w - 18
                                    text:           model.typ === "klemme" ? (model.farbeBez || "–") : ""
                                    font.pixelSize: 12
                                    color:          theme.textSecondary
                                    elide:          Text.ElideRight
                                }
                            }

                            Text { width: panel.kpCols[5].w; text: model.typ === "klemme" ? (model.potenzial || "–") : ""; font.pixelSize: 12; color: model.typ === "klemme" && model.potenzial ? theme.accent : theme.borderDark; elide: Text.ElideRight }
                            Text { width: panel.kpCols[6].w; text: model.typ === "klemme" ? (model.ortKz || "–") : ""; font.pixelSize: 12; color: theme.borderLight; elide: Text.ElideRight }
                        }
                    }
                }

                Text {
                    visible:          klemmenplanZaehler === 0
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    text:             projektId >= 0 ? "Keine Klemmenleisten im Projekt" : "Kein Projekt ausgewählt"
                    font.pixelSize:   14; color: theme.borderDark
                }
            }

            // ── Tab 4: Kabelliste ────────────────────────────────
            ColumnLayout {
                spacing: 0

                CsvLeiste {
                    listenName: qsTr("Kabelliste")
                    anzahl:     kabellisteModel.count
                    onCsvKlick: csvDialogKabel.open()
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                Rectangle {
                    Layout.fillWidth: true
                    height:           30
                    color:            theme.tableHeader

                    Row {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: panel.klCols
                            delegate: Text {
                                width:          modelData.w
                                text:           modelData.header
                                font.pixelSize: 11
                                font.weight:    Font.Medium
                                color:          theme.textSubtle
                            }
                        }
                    }
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                ListView {
                    id:                 klView
                    Layout.fillWidth:   true
                    Layout.fillHeight:  true
                    model:              kabellisteModel
                    clip:               true
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        width:  klView.width
                        height: 30
                        color:  index % 2 === 0 ? theme.tableEven : theme.tableOdd

                        Row {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 0

                            Text { width: panel.klCols[0].w; text: model.bezeichnung    || "–"; font.pixelSize: 12; color: theme.accent;       elide: Text.ElideRight }
                            Text { width: panel.klCols[1].w; text: model.kabeltyp       || "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.klCols[2].w; text: model.aderzahl       > 0 ? model.aderzahl       : "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.klCols[3].w; text: model.querschnittMm2 > 0 ? model.querschnittMm2 + " mm²" : "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.klCols[4].w; text: model.laengeM        > 0 ? model.laengeM        + " m"   : "–"; font.pixelSize: 12; color: theme.textSecondary; elide: Text.ElideRight }
                            Text { width: panel.klCols[5].w; text: model.vonOrt         || "–"; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                            Text { width: panel.klCols[6].w; text: model.nachOrt        || "–"; font.pixelSize: 12; color: theme.borderLight;   elide: Text.ElideRight }
                        }
                    }
                }

                Text {
                    visible:          kabellisteModel.count === 0
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    text:             projektId >= 0 ? "Keine Kabel im Projekt" : "Kein Projekt ausgewählt"
                    font.pixelSize:   14; color: theme.borderDark
                }
            }
        }
    }

    // ── CSV-Dialoge ──────────────────────────────────────────────
    FileDialog {
        id:          csvDialogStueckliste
        fileMode:    FileDialog.SaveFile
        title:       qsTr("Stückliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.stuecklisteCsvSpeichern(projektId, selectedFile)
    }
    FileDialog {
        id:          csvDialogQV
        fileMode:    FileDialog.SaveFile
        title:       qsTr("Querverweisliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.querverweislisteCsvSpeichern(projektId, selectedFile)
    }
    FileDialog {
        id:          csvDialogAder
        fileMode:    FileDialog.SaveFile
        title:       qsTr("Aderliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.aderlisteCsvSpeichern(projektId, selectedFile)
    }
    FileDialog {
        id:          csvDialog
        fileMode:    FileDialog.SaveFile
        title:       qsTr("Klemmenplan als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.klemmenplanCsvSpeichern(projektId, selectedFile)
    }
    FileDialog {
        id:          csvDialogKabel
        fileMode:    FileDialog.SaveFile
        title:       qsTr("Kabelliste als CSV speichern")
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*)"]
        defaultSuffix: "csv"
        onAccepted: db.kabellisteCsvSpeichern(projektId, selectedFile)
    }

    DebugLabel { panelName: qsTr("Listen-Ansicht"); visible: panel.debug }
}
