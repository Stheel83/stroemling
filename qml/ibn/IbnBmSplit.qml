import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling
import "../components"

SplitView {
    id: root
    required property var panel
    required property var theme
    property bool debug: false

    signal bmkGewaehlt(int seiteId, int elementId, real x1, real y1)

    function openFeldEditor() { feldEditorDialog.open() }

    orientation: Qt.Horizontal

    handle: Rectangle {
        implicitWidth: 5
        color: SplitHandle.pressed ? theme.accent
             : SplitHandle.hovered  ? theme.activeItem : theme.border
    }

    // Linke Spalte: BM-Liste
    Item {
        SplitView.preferredWidth: 220
        SplitView.minimumWidth:   150

        DebugLabel { panelName: qsTr("IBN-BmSplit"); visible: root.debug }

        ScrollView {
            anchors.fill: parent; clip: true

            ListView {
                id: bmListe
                width: parent.width; clip: true

            property var _gelistet: panel._gefilterteListe()
            model: _gelistet

            Text {
                anchors.centerIn: parent
                visible: bmListe.count === 0
                text: panel._liste.length === 0
                      ? qsTr("Keine Betriebsmittel\nmit BMK gefunden.")
                      : qsTr("Kein Treffer.")
                color: theme.textMuted; font.pixelSize: 11; font.italic: true
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                width: parent.width - 24
            }

            delegate: Rectangle {
                width: bmListe.width; height: 42
                color: panel.ausgewaehlterIndex === index
                       ? theme.activeItemAlt
                       : (bmHover.containsMouse ? theme.hover : "transparent")
                HoverHandler { id: bmHover }
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 8
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: panel._statusFarbe(modelData.status)
                        Layout.alignment: Qt.AlignVCenter
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text {
                            text: modelData.bmk
                            font.pixelSize: 13; font.bold: true
                            color: theme.textPrimary
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.blattnummer
                                  + (modelData.seitenbezeichnung
                                     ? "  –  " + modelData.seitenbezeichnung : "")
                            font.pixelSize: 10; color: theme.textMuted
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.ausgewaehlterIndex = index
                        root.bmkGewaehlt(modelData.seiteId, modelData.elementId,
                                         modelData.x1, modelData.y1)
                    }
                }
            }
        }
        }
    }

    // Rechte Spalte: BM-Detailformular
    ScrollView {
        SplitView.fillWidth: true; SplitView.minimumWidth: 200
        contentWidth: availableWidth; clip: true
        background: Rectangle { color: theme.sidebar }

        ColumnLayout {
            width: parent.width; spacing: 0

            Item {
                visible: panel.ausgewaehlterIndex < 0
                Layout.fillWidth: true; height: 120
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Betriebsmittel\nauswählen")
                    color: theme.textMuted; font.pixelSize: 12; font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ColumnLayout {
                visible: panel.ausgewaehlterIndex >= 0
                Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                Text {
                    text: {
                        if (panel.ausgewaehlterIndex < 0) return ""
                        var fl = bmListe._gelistet
                        if (!fl || panel.ausgewaehlterIndex >= fl.length) return ""
                        return fl[panel.ausgewaehlterIndex].bmk
                    }
                    font.pixelSize: 16; font.bold: true; color: theme.accent
                    Layout.fillWidth: true
                }
                Text {
                    text: {
                        if (panel.ausgewaehlterIndex < 0) return ""
                        var fl = bmListe._gelistet
                        if (!fl || panel.ausgewaehlterIndex >= fl.length) return ""
                        var e = fl[panel.ausgewaehlterIndex]
                        return qsTr("Blatt %1").arg(e.blattnummer)
                               + (e.seitenbezeichnung ? "  –  " + e.seitenbezeichnung : "")
                    }
                    font.pixelSize: 11; color: theme.textMuted; Layout.fillWidth: true
                }

                // ── PRÜFSTATUS ────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 6
                    Text { text: qsTr("PRÜFSTATUS"); font.pixelSize: 10; font.weight: Font.Medium; color: theme.textMuted }
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.alignment: Qt.AlignVCenter }
                }

                Text { text: qsTr("Status"); color: theme.textMuted; font.pixelSize: 11 }
                ComboBox {
                    id: cmbStatus
                    Layout.fillWidth: true; implicitHeight: 30
                    model: [
                        { key: "offen",         label: qsTr("Offen")      },
                        { key: "in_arbeit",     label: qsTr("In Arbeit")  },
                        { key: "abgeschlossen", label: qsTr("Fertig")     }
                    ]
                    textRole: "label"
                    background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                    contentItem: RowLayout {
                        spacing: 6
                        Item { width: 8 }
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: panel._statusFarbe(cmbStatus.model[cmbStatus.currentIndex]?.key ?? "offen")
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: cmbStatus.displayText; color: theme.textPrimary
                            font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                            Layout.fillWidth: true
                        }
                    }
                    delegate: ItemDelegate {
                        width: cmbStatus.width; implicitHeight: 28
                        highlighted: cmbStatus.highlightedIndex === index
                        contentItem: RowLayout {
                            spacing: 6
                            Item { width: 8 }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: panel._statusFarbe(modelData.key)
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text { text: modelData.label; color: theme.textPrimary;
                                   font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                        }
                        background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                    }
                }

                Text { text: qsTr("Seriennummer / Bauteil-ID"); color: theme.textMuted; font.pixelSize: 11 }
                TextField {
                    id: tfBauteilId
                    Layout.fillWidth: true; implicitHeight: 30
                    placeholderText: qsTr("optional")
                    background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                    color: theme.textPrimary; font.pixelSize: 12
                }

                // ── MESSWERTE ─────────────────────────────────────
                RowLayout {
                    visible: panel._dynFelder.length > 0
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 6
                    Text { text: qsTr("MESSWERTE"); font.pixelSize: 10; font.weight: Font.Medium; color: theme.textMuted }
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.alignment: Qt.AlignVCenter }
                }

                Repeater {
                    model: panel._dynFelder
                    delegate: ColumnLayout {
                        Layout.fillWidth: true; spacing: 3

                        Text {
                            text: modelData.label
                                  + (modelData.pflichtfeld ? " *" : "")
                                  + (modelData.einheit ? "  [" + modelData.einheit + "]" : "")
                            color: theme.textMuted; font.pixelSize: 11
                        }

                        // text / zahl
                        TextField {
                            visible: modelData.feldtyp === "text" || modelData.feldtyp === "zahl"
                            Layout.fillWidth: true; implicitHeight: 28
                            inputMethodHints: modelData.feldtyp === "zahl"
                                              ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
                            text: panel._dynWerte[modelData.feldname] || ""
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            color: theme.textPrimary; font.pixelSize: 12
                            onTextChanged: {
                                var tmp = Object.assign({}, panel._dynWerte)
                                tmp[modelData.feldname] = text
                                panel._dynWerte = tmp
                            }
                        }

                        // boolean
                        CheckBox {
                            visible: modelData.feldtyp === "boolean"
                            checked: (panel._dynWerte[modelData.feldname] || "") === "1"
                            onCheckedChanged: {
                                var tmp = Object.assign({}, panel._dynWerte)
                                tmp[modelData.feldname] = checked ? "1" : "0"
                                panel._dynWerte = tmp
                            }
                            indicator: Rectangle {
                                implicitWidth: 16; implicitHeight: 16; radius: 3
                                color: parent.checked ? theme.accent : theme.inputBg
                                border.color: theme.border
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"; color: "white"; font.pixelSize: 11
                                    visible: parent.parent.checked
                                }
                            }
                            contentItem: Text {
                                leftPadding: parent.indicator.width + 6
                                text: qsTr("Ja")
                                color: theme.textPrimary; font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // auswahl
                        ComboBox {
                            visible: modelData.feldtyp === "auswahl"
                            Layout.fillWidth: true; implicitHeight: 28
                            model: modelData.optionen ? modelData.optionen.split(",") : []
                            currentIndex: {
                                var v = panel._dynWerte[modelData.feldname] || ""
                                var idx = model.indexOf(v)
                                return idx >= 0 ? idx : 0
                            }
                            background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                            contentItem: Text {
                                leftPadding: 8
                                text: parent.displayText; color: theme.textPrimary
                                font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                            }
                            onActivated: function(idx) {
                                if (idx >= 0 && model.length > 0) {
                                    var tmp = Object.assign({}, panel._dynWerte)
                                    tmp[modelData.feldname] = model[idx]
                                    panel._dynWerte = tmp
                                }
                            }
                        }
                    }
                }

                // ── PRÜFPROTOKOLL ─────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 6
                    Text { text: qsTr("PRÜFPROTOKOLL"); font.pixelSize: 10; font.weight: Font.Medium; color: theme.textMuted }
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.alignment: Qt.AlignVCenter }
                }

                Text { text: qsTr("Notiz"); color: theme.textMuted; font.pixelSize: 11 }
                Rectangle {
                    Layout.fillWidth: true; height: 70
                    color: theme.inputBg; radius: 4; border.color: theme.border
                    TextArea {
                        id: taNotiz
                        anchors { fill: parent; margins: 4 }
                        wrapMode: TextArea.Wrap; background: null
                        color: theme.textPrimary; font.pixelSize: 12
                        placeholderText: qsTr("Bemerkungen …")
                    }
                }

                GridLayout {
                    Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 4
                    Text { text: qsTr("Geprüft von"); color: theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Datum");       color: theme.textMuted; font.pixelSize: 11 }
                    TextField {
                        id: tfGeprueftVon; Layout.fillWidth: true; implicitHeight: 28
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }
                    TextField {
                        id: tfGeprueftAm; Layout.fillWidth: true; implicitHeight: 28
                        placeholderText: "TT.MM.JJJJ"
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }

                Button {
                    Layout.fillWidth: true; text: qsTr("Speichern"); implicitHeight: 32
                    contentItem: Text { text: parent.text; color: theme.textPrimary;
                        font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter;
                        verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent }
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Status, Notiz, Prüfer und Datum speichern")
                    onClicked: {
                        var fl = bmListe._gelistet
                        if (!fl || panel.ausgewaehlterIndex >= fl.length) return
                        var e = fl[panel.ausgewaehlterIndex]
                        var stKey = cmbStatus.model[cmbStatus.currentIndex].key
                        db.ibnEintragSpeichern(panel.projektId, e.seiteId, e.bmk,
                            stKey, taNotiz.text.trim(),
                            tfBauteilId.text.trim(),
                            tfGeprueftVon.text.trim(),
                            tfGeprueftAm.text.trim())
                        if (panel._dynFelder.length > 0) {
                            var tmpListe = db.ibnListeLaden(panel.projektId,
                                panel.ansichtModus === "seite" ? panel.seiteId : -1)
                            for (var ti = 0; ti < tmpListe.length; ti++) {
                                if (tmpListe[ti].seiteId === e.seiteId
                                        && tmpListe[ti].bmk === e.bmk) {
                                    var ibnId = tmpListe[ti].ibnId || 0
                                    if (ibnId > 0)
                                        db.ibnFeldwerteAktualisieren(ibnId,
                                            panel._dynWerteAlsListe())
                                    break
                                }
                            }
                        }
                        panel.laden()
                        var fl2 = panel._gefilterteListe()
                        for (var i = 0; i < fl2.length; i++) {
                            if (fl2[i].seiteId === e.seiteId && fl2[i].bmk === e.bmk) {
                                panel.ausgewaehlterIndex = i; break
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: [
                            { key: "offen",         label: qsTr("Offen"),     farbe: "#666688" },
                            { key: "in_arbeit",     label: qsTr("In Arbeit"), farbe: "#e0b040" },
                            { key: "abgeschlossen", label: qsTr("✓ Fertig"),  farbe: "#44aa66" }
                        ]
                        delegate: Button {
                            Layout.fillWidth: true; implicitHeight: 26
                            contentItem: Text { text: modelData.label; color: "white";
                                font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter;
                                verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered
                                ? Qt.darker(modelData.farbe, 1.2) : modelData.farbe; radius: 4 }
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: qsTr("Status direkt auf '%1' setzen (nur Status, ohne Prüfer/Datum)").arg(modelData.label)
                            onClicked: {
                                var fl = bmListe._gelistet
                                if (!fl || panel.ausgewaehlterIndex >= fl.length) return
                                var e = fl[panel.ausgewaehlterIndex]
                                db.ibnStatusSetzen(e.seiteId, e.bmk, modelData.key)
                                if (modelData.key === "abgeschlossen")
                                    achievementManager.ereignis("ibn_element_gruen",
                                        { "elementeAufSeite": fl.length,
                                          "gruenAufSeite": fl.filter(function(x) { return x.status === "abgeschlossen" }).length + 1 })
                                panel.laden()
                                var fl2 = panel._gefilterteListe()
                                for (var i = 0; i < fl2.length; i++) {
                                    if (fl2[i].seiteId === e.seiteId && fl2[i].bmk === e.bmk) {
                                        panel.ausgewaehlterIndex = i; break
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 12 }
            }

            Connections {
                target: panel
                function onAusgewaehlterIndexChanged() {
                    var fl = bmListe._gelistet
                    if (!fl || panel.ausgewaehlterIndex < 0
                            || panel.ausgewaehlterIndex >= fl.length) {
                        panel._dynFelder = []
                        panel._dynWerte  = ({})
                        return
                    }
                    var e = fl[panel.ausgewaehlterIndex]
                    var si = ["offen","in_arbeit","abgeschlossen"].indexOf(e.status)
                    cmbStatus.currentIndex = si >= 0 ? si : 0
                    tfBauteilId.text       = e.bauteilId   || ""
                    taNotiz.text           = e.notiz       || ""
                    tfGeprueftVon.text     = e.geprueftVon || ""
                    tfGeprueftAm.text      = e.geprueftAm  || ""

                    var kat = e.symbolKategorie || ""
                    panel._dynFelder = kat !== "" ? db.ibnFeldvorlagenLaden(kat) : []

                    var werteMap = {}
                    if (e.ibnId > 0) {
                        var wl = db.ibnFeldwerteLaden(e.ibnId)
                        for (var i = 0; i < wl.length; i++)
                            werteMap[wl[i].feldname] = wl[i].wert || ""
                    }
                    panel._dynWerte = werteMap
                }
            }
        }
    }

    IbnFeldEditorDialog {
        id: feldEditorDialog
        theme: root.theme
        debug: root.debug
        onFelderGeaendert: {
            var fl = bmListe._gelistet
            if (!fl || panel.ausgewaehlterIndex < 0 || panel.ausgewaehlterIndex >= fl.length) return
            var e = fl[panel.ausgewaehlterIndex]
            var kat = e.symbolKategorie || ""
            panel._dynFelder = kat !== "" ? db.ibnFeldvorlagenLaden(kat) : []
        }
    }

}
