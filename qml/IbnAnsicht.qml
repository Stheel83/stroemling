import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "components"

Item {
    id: root

    property int    projektId:   -1
    property int    seiteId:     -1
    property var    theme
    property bool   debug:       false

    // "projekt" = alle Seiten, "seite" = nur aktuelle Seite
    property string ansichtModus: "projekt"

    // "bm" = Betriebsmittel, "kabel" = Kabel+Adern
    property string _kategorie: "bm"

    property int    ausgewaehlterIndex:       -1
    property int    kabelAusgewaehlterIndex: -1
    property var    _kabelAdern:              []

    // Dynamische Messfelder für das ausgewählte BM
    property var _dynFelder: []   // [{feldname, label, feldtyp, optionen, einheit, pflichtfeld}]
    property var _dynWerte:  ({}) // feldname → wert (String)

    function _dynWerteAlsListe() {
        var result = []
        for (var fn in root._dynWerte)
            result.push({ "feldname": fn, "wert": root._dynWerte[fn] })
        return result
    }

    signal bmkGewaehlt(int seiteId, int elementId, real x1, real y1)
    signal geschlossen()

    // ── BM-Liste ──────────────────────────────────────────────
    property var    _liste:  []
    property string _suche:  ""
    property string _filter: "alle"

    // Canvas-Overlay: bmk → status
    property var statusMap: ({})

    function _statusMapAktualisieren() {
        var m = {}
        for (var i = 0; i < root._liste.length; i++) {
            var e = root._liste[i]
            if (e.bmk) m[e.bmk] = e.status || "offen"
        }
        root.statusMap = m
    }

    // ── Kabel-Liste ───────────────────────────────────────────
    property var _kabelListe: []

    function kabelLaden() {
        root._kabelListe = (root.projektId >= 0)
                           ? db.ibnKabelListeLaden(root.projektId) : []
        root.kabelAusgewaehlterIndex = -1
        root._kabelAdern = []
    }

    function _gefilterteKabelListe() {
        var s = root._suche.trim().toLowerCase()
        return root._kabelListe.filter(function(k) {
            var textOk = s === ""
                || (k.bezeichnung || "").toLowerCase().indexOf(s) >= 0
                || (k.kabeltyp    || "").toLowerCase().indexOf(s) >= 0
                || (k.vonOrt      || "").toLowerCase().indexOf(s) >= 0
                || (k.nachOrt     || "").toLowerCase().indexOf(s) >= 0
            var statusOk = root._filter === "alle" || k.status === root._filter
            return textOk && statusOk
        })
    }

    // ── Gemeinsame Hilfsfunktionen ────────────────────────────
    function laden() {
        var sid = (root.ansichtModus === "seite" && root.seiteId >= 0)
                  ? root.seiteId : -1
        root._liste = db.ibnListeLaden(root.projektId, sid)
        root.ausgewaehlterIndex = -1
        root._statusMapAktualisieren()
        kabelLaden()
    }

    function _gefilterteListe() {
        var s = root._suche.trim().toLowerCase()
        return root._liste.filter(function(e) {
            var textOk = s === ""
                || e.bmk.toLowerCase().indexOf(s) >= 0
                || e.blattnummer.toLowerCase().indexOf(s) >= 0
                || (e.seitenbezeichnung || "").toLowerCase().indexOf(s) >= 0
            var statusOk = root._filter === "alle" || e.status === root._filter
            return textOk && statusOk
        })
    }

    function _statusFarbe(status) {
        switch (status) {
            case "in_arbeit":     return "#e0b040"
            case "abgeschlossen": return "#44aa66"
            default:              return "#666688"
        }
    }

    function _statusLabel(status) {
        switch (status) {
            case "in_arbeit":     return qsTr("In Arbeit")
            case "abgeschlossen": return qsTr("✓ Fertig")
            default:              return qsTr("Offen")
        }
    }

    onAnsichtModusChanged: laden()
    onSeiteIdChanged:      { if (ansichtModus === "seite") laden() }
    onProjektIdChanged:    { if (projektId >= 0) laden() }

    // ── Layout ────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 44; color: theme.surfaceDeep

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 6

                Text {
                    text: qsTr("⚡ Inbetriebnahme")
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: theme.textPrimary
                }

                Item { Layout.fillWidth: true }

                // BM / Kabel Toggle
                RowLayout {
                    spacing: 2
                    Repeater {
                        model: [
                            { key: "bm",    label: qsTr("BM")    },
                            { key: "kabel", label: qsTr("Kabel") }
                        ]
                        delegate: Rectangle {
                            implicitWidth: 48; implicitHeight: 26; radius: 4
                            color: root._kategorie === modelData.key
                                   ? theme.accent : theme.activeItem
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label; font.pixelSize: 11
                                color: root._kategorie === modelData.key
                                       ? "white" : theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root._kategorie = modelData.key
                            }
                        }
                    }
                }

                // Projekt / Seite Toggle
                RowLayout {
                    spacing: 2
                    Repeater {
                        model: [
                            { key: "projekt", label: qsTr("Projekt") },
                            { key: "seite",   label: qsTr("Seite")   }
                        ]
                        delegate: Rectangle {
                            implicitWidth: 52; implicitHeight: 26; radius: 4
                            color: root.ansichtModus === modelData.key
                                   ? theme.accent : theme.activeItem
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label; font.pixelSize: 11
                                color: root.ansichtModus === modelData.key
                                       ? "white" : theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.ansichtModus = modelData.key
                            }
                        }
                    }
                }

                Button {
                    flat: true; implicitWidth: 70; implicitHeight: 26
                    contentItem: Text { text: qsTr("⚙ Felder"); color: theme.textSecondary; font.pixelSize: 11;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : theme.activeItem; radius: 4;
                        border.color: theme.border }
                    onClicked: feldEditorDialog.open()
                    ToolTip.visible: hovered; ToolTip.text: qsTr("Benutzerdefinierte IBN-Felder bearbeiten")
                    ToolTip.delay: 600
                }

                Button {
                    flat: true; implicitWidth: 28; implicitHeight: 28
                    contentItem: Text { text: "✕"; color: theme.textMuted; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 4 }
                    onClicked: root.geschlossen()
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Suche + Filter ─────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; Layout.margins: 8; spacing: 6

            TextField {
                id: tfSuche
                Layout.fillWidth: true; implicitHeight: 30
                placeholderText: root._kategorie === "kabel"
                                 ? qsTr("Kabel / Typ / Ort suchen …")
                                 : qsTr("BMK / Blatt suchen …")
                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                color: theme.textPrimary; font.pixelSize: 12
                onTextChanged: root._suche = text
            }

            ComboBox {
                id: cmbFilter
                implicitWidth: 110; implicitHeight: 30
                model: [
                    { key: "alle",           label: qsTr("Alle")       },
                    { key: "offen",          label: qsTr("Offen")      },
                    { key: "in_arbeit",      label: qsTr("In Arbeit")  },
                    { key: "abgeschlossen",  label: qsTr("Fertig")     }
                ]
                textRole: "label"
                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                contentItem: Text {
                    leftPadding: 8; text: cmbFilter.displayText
                    color: theme.textPrimary; font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    width: cmbFilter.width; implicitHeight: 28
                    highlighted: cmbFilter.highlightedIndex === index
                    contentItem: Text {
                        leftPadding: 8; text: modelData.label
                        color: theme.textPrimary; font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                }
                onActivated: root._filter = model[index].key
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.divider }

        // ── BM-Split ───────────────────────────────────────────
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: root._kategorie === "bm"
            visible:           root._kategorie === "bm"
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

                ListView {
                    id: bmListe
                    anchors.fill: parent; clip: true

                    property var _gelistet: root._gefilterteListe()
                    model: _gelistet

                    Text {
                        anchors.centerIn: parent
                        visible: bmListe.count === 0
                        text: root._liste.length === 0
                              ? qsTr("Keine Betriebsmittel\nmit BMK gefunden.")
                              : qsTr("Kein Treffer.")
                        color: theme.textMuted; font.pixelSize: 11; font.italic: true
                        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        width: parent.width - 24
                    }

                    delegate: Rectangle {
                        width: bmListe.width; height: 42
                        color: root.ausgewaehlterIndex === index
                               ? theme.activeItemAlt
                               : (bmHover.containsMouse ? theme.hover : "transparent")
                        HoverHandler { id: bmHover }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 8
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: root._statusFarbe(modelData.status)
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
                                root.ausgewaehlterIndex = index
                                root.bmkGewaehlt(modelData.seiteId, modelData.elementId,
                                                 modelData.x1, modelData.y1)
                            }
                        }
                    }
                }
            }

            // Rechte Spalte: BM-Detailformular
            ScrollView {
                SplitView.fillWidth: true; SplitView.minimumWidth: 200
                contentWidth: availableWidth; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 0

                    Item {
                        visible: root.ausgewaehlterIndex < 0
                        Layout.fillWidth: true; height: 120
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Betriebsmittel\nauswählen")
                            color: theme.textMuted; font.pixelSize: 12; font.italic: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    ColumnLayout {
                        visible: root.ausgewaehlterIndex >= 0
                        Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                        Text {
                            text: {
                                if (root.ausgewaehlterIndex < 0) return ""
                                var fl = bmListe._gelistet
                                if (!fl || root.ausgewaehlterIndex >= fl.length) return ""
                                return fl[root.ausgewaehlterIndex].bmk
                            }
                            font.pixelSize: 16; font.bold: true; color: theme.accent
                            Layout.fillWidth: true
                        }
                        Text {
                            text: {
                                if (root.ausgewaehlterIndex < 0) return ""
                                var fl = bmListe._gelistet
                                if (!fl || root.ausgewaehlterIndex >= fl.length) return ""
                                var e = fl[root.ausgewaehlterIndex]
                                return qsTr("Blatt %1").arg(e.blattnummer)
                                       + (e.seitenbezeichnung ? "  –  " + e.seitenbezeichnung : "")
                            }
                            font.pixelSize: 11; color: theme.textMuted; Layout.fillWidth: true
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }

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
                                    color: root._statusFarbe(cmbStatus.model[cmbStatus.currentIndex]?.key ?? "offen")
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
                                        color: root._statusFarbe(modelData.key)
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

                        // ── Dynamische Messfelder ─────────────────────────
                        Repeater {
                            model: root._dynFelder
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
                                    text: root._dynWerte[modelData.feldname] || ""
                                    background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                                    color: theme.textPrimary; font.pixelSize: 12
                                    onTextChanged: {
                                        var tmp = Object.assign({}, root._dynWerte)
                                        tmp[modelData.feldname] = text
                                        root._dynWerte = tmp
                                    }
                                }

                                // boolean
                                CheckBox {
                                    visible: modelData.feldtyp === "boolean"
                                    checked: (root._dynWerte[modelData.feldname] || "") === "1"
                                    onCheckedChanged: {
                                        var tmp = Object.assign({}, root._dynWerte)
                                        tmp[modelData.feldname] = checked ? "1" : "0"
                                        root._dynWerte = tmp
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
                                        var v = root._dynWerte[modelData.feldname] || ""
                                        var idx = model.indexOf(v)
                                        return idx >= 0 ? idx : 0
                                    }
                                    background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                                    contentItem: Text {
                                        leftPadding: 8
                                        text: parent.displayText; color: theme.textPrimary
                                        font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                                    }
                                    // onActivated feuert nur bei echter Nutzer-Auswahl,
                                    // nicht bei programmatischen currentIndex-Änderungen durch das Binding
                                    onActivated: function(idx) {
                                        if (idx >= 0 && model.length > 0) {
                                            var tmp = Object.assign({}, root._dynWerte)
                                            tmp[modelData.feldname] = model[idx]
                                            root._dynWerte = tmp
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: root._dynFelder.length > 0
                            Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4
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
                            background: Rectangle { color: parent.hovered ? theme.btnPrimary : theme.activeItem; radius: 4 }
                            onClicked: {
                                var fl = bmListe._gelistet
                                if (!fl || root.ausgewaehlterIndex >= fl.length) return
                                var e = fl[root.ausgewaehlterIndex]
                                var stKey = cmbStatus.model[cmbStatus.currentIndex].key
                                db.ibnEintragSpeichern(root.projektId, e.seiteId, e.bmk,
                                    stKey, taNotiz.text.trim(),
                                    tfBauteilId.text.trim(),
                                    tfGeprueftVon.text.trim(),
                                    tfGeprueftAm.text.trim())
                                // Dynfelder speichern (ibnId nach Speichern neu laden)
                                if (root._dynFelder.length > 0) {
                                    // Nach ibnEintragSpeichern existiert der Eintrag → ID aus DB holen
                                    var tmpListe = db.ibnListeLaden(root.projektId,
                                        root.ansichtModus === "seite" ? root.seiteId : -1)
                                    for (var ti = 0; ti < tmpListe.length; ti++) {
                                        if (tmpListe[ti].seiteId === e.seiteId
                                                && tmpListe[ti].bmk === e.bmk) {
                                            var ibnId = tmpListe[ti].ibnId || 0
                                            if (ibnId > 0)
                                                db.ibnFeldwerteAktualisieren(ibnId,
                                                    root._dynWerteAlsListe())
                                            break
                                        }
                                    }
                                }
                                root.laden()
                                var fl2 = root._gefilterteListe()
                                for (var i = 0; i < fl2.length; i++) {
                                    if (fl2[i].seiteId === e.seiteId && fl2[i].bmk === e.bmk) {
                                        root.ausgewaehlterIndex = i; break
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
                                    onClicked: {
                                        var fl = bmListe._gelistet
                                        if (!fl || root.ausgewaehlterIndex >= fl.length) return
                                        var e = fl[root.ausgewaehlterIndex]
                                        db.ibnStatusSetzen(e.seiteId, e.bmk, modelData.key)
                                        root.laden()
                                        var fl2 = root._gefilterteListe()
                                        for (var i = 0; i < fl2.length; i++) {
                                            if (fl2[i].seiteId === e.seiteId && fl2[i].bmk === e.bmk) {
                                                root.ausgewaehlterIndex = i; break
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item { height: 12 }
                    }

                    Connections {
                        target: root
                        function onAusgewaehlterIndexChanged() {
                            var fl = bmListe._gelistet
                            if (!fl || root.ausgewaehlterIndex < 0
                                    || root.ausgewaehlterIndex >= fl.length) {
                                root._dynFelder = []
                                root._dynWerte  = ({})
                                return
                            }
                            var e = fl[root.ausgewaehlterIndex]
                            var si = ["offen","in_arbeit","abgeschlossen"].indexOf(e.status)
                            cmbStatus.currentIndex = si >= 0 ? si : 0
                            tfBauteilId.text       = e.bauteilId   || ""
                            taNotiz.text           = e.notiz       || ""
                            tfGeprueftVon.text     = e.geprueftVon || ""
                            tfGeprueftAm.text      = e.geprueftAm  || ""

                            // Dynamische Felder laden
                            var kat = e.symbolKategorie || ""
                            root._dynFelder = kat !== "" ? db.ibnFeldvorlagenLaden(kat) : []

                            var werteMap = {}
                            if (e.ibnId > 0) {
                                var wl = db.ibnFeldwerteLaden(e.ibnId)
                                for (var i = 0; i < wl.length; i++)
                                    werteMap[wl[i].feldname] = wl[i].wert || ""
                            }
                            root._dynWerte = werteMap
                        }
                    }
                }
            }
        }

        // ── Kabel-Split ────────────────────────────────────────
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: root._kategorie === "kabel"
            visible:           root._kategorie === "kabel"
            orientation: Qt.Horizontal

            handle: Rectangle {
                implicitWidth: 5
                color: SplitHandle.pressed ? theme.accent
                     : SplitHandle.hovered  ? theme.activeItem : theme.border
            }

            // Linke Spalte: Kabelliste
            Item {
                SplitView.preferredWidth: 220
                SplitView.minimumWidth:   150

                ListView {
                    id: kabelListe
                    anchors.fill: parent; clip: true

                    property var _gelistet: root._gefilterteKabelListe()
                    model: _gelistet

                    Text {
                        anchors.centerIn: parent
                        visible: kabelListe.count === 0
                        text: root._kabelListe.length === 0
                              ? qsTr("Keine Kabel im Projekt.")
                              : qsTr("Kein Treffer.")
                        color: theme.textMuted; font.pixelSize: 11; font.italic: true
                        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        width: parent.width - 24
                    }

                    delegate: Rectangle {
                        width: kabelListe.width; height: 48
                        color: root.kabelAusgewaehlterIndex === index
                               ? theme.activeItemAlt
                               : (kabelHover.containsMouse ? theme.hover : "transparent")
                        HoverHandler { id: kabelHover }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 8
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: root._statusFarbe(modelData.status)
                                Layout.alignment: Qt.AlignVCenter
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text {
                                    text: modelData.bezeichnung || qsTr("(kein Name)")
                                    font.pixelSize: 13; font.bold: true
                                    color: theme.textPrimary
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    text: {
                                        var t = modelData.kabeltyp || ""
                                        var n = modelData.aderzahl || 0
                                        var q2 = modelData.querschnittMm2 || 0
                                        var parts = []
                                        if (t) parts.push(t)
                                        if (n > 0) parts.push(n + "×" + q2 + " mm²")
                                        return parts.join("  ")
                                    }
                                    font.pixelSize: 10; color: theme.textMuted
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.kabelAusgewaehlterIndex = index
                        }
                    }
                }
            }

            // Rechte Spalte: Kabel-Detailformular
            ScrollView {
                SplitView.fillWidth: true; SplitView.minimumWidth: 200
                contentWidth: availableWidth; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 0

                    Item {
                        visible: root.kabelAusgewaehlterIndex < 0
                        Layout.fillWidth: true; height: 120
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Kabel auswählen")
                            color: theme.textMuted; font.pixelSize: 12; font.italic: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    ColumnLayout {
                        visible: root.kabelAusgewaehlterIndex >= 0
                        Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                        // Kabel-Titel
                        Text {
                            text: {
                                var fl = kabelListe._gelistet
                                if (!fl || root.kabelAusgewaehlterIndex >= fl.length) return ""
                                return fl[root.kabelAusgewaehlterIndex].bezeichnung || qsTr("(kein Name)")
                            }
                            font.pixelSize: 15; font.bold: true; color: theme.accent
                            Layout.fillWidth: true
                        }
                        // Info-Zeilen (read-only)
                        Text {
                            text: {
                                var fl = kabelListe._gelistet
                                if (!fl || root.kabelAusgewaehlterIndex >= fl.length) return ""
                                var k = fl[root.kabelAusgewaehlterIndex]
                                var parts = []
                                if (k.kabeltyp) parts.push(k.kabeltyp)
                                if (k.aderzahl > 0) parts.push(k.aderzahl + " Adern × " + k.querschnittMm2 + " mm²")
                                if (k.laengeM > 0) parts.push(k.laengeM + " m")
                                return parts.join("   ")
                            }
                            font.pixelSize: 11; color: theme.textMuted; Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                        Text {
                            text: {
                                var fl = kabelListe._gelistet
                                if (!fl || root.kabelAusgewaehlterIndex >= fl.length) return ""
                                var k = fl[root.kabelAusgewaehlterIndex]
                                if (!k.vonOrt && !k.nachOrt) return ""
                                return (k.vonOrt || "?") + "  →  " + (k.nachOrt || "?")
                            }
                            font.pixelSize: 11; color: theme.textMuted; Layout.fillWidth: true
                            visible: text !== ""
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }

                        // Status
                        Text { text: qsTr("Status"); color: theme.textMuted; font.pixelSize: 11 }
                        ComboBox {
                            id: cmbKabelStatus
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
                                    color: root._statusFarbe(cmbKabelStatus.model[cmbKabelStatus.currentIndex]?.key ?? "offen")
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Text {
                                    text: cmbKabelStatus.displayText; color: theme.textPrimary
                                    font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                                    Layout.fillWidth: true
                                }
                            }
                            delegate: ItemDelegate {
                                width: cmbKabelStatus.width; implicitHeight: 28
                                highlighted: cmbKabelStatus.highlightedIndex === index
                                contentItem: RowLayout {
                                    spacing: 6
                                    Item { width: 8 }
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: root._statusFarbe(modelData.key)
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Text { text: modelData.label; color: theme.textPrimary;
                                           font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                                }
                                background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                            }
                        }

                        // Aderliste
                        Text {
                            text: qsTr("Adern")
                            color: theme.textMuted; font.pixelSize: 11
                            visible: root._kabelAdern.length > 0
                        }
                        Rectangle {
                            visible: root._kabelAdern.length > 0
                            Layout.fillWidth: true
                            height: Math.min(root._kabelAdern.length * 22 + 4, 130)
                            color: theme.inputBg; radius: 4; border.color: theme.border
                            clip: true

                            Column {
                                anchors { fill: parent; margins: 4 }
                                spacing: 0

                                Repeater {
                                    model: root._kabelAdern
                                    delegate: RowLayout {
                                        width: parent.width; height: 22; spacing: 6
                                        Text {
                                            text: modelData.aderNr
                                            font.pixelSize: 11; color: theme.textMuted
                                            Layout.preferredWidth: 20
                                        }
                                        Text {
                                            text: modelData.farbe || "–"
                                            font.pixelSize: 11; color: theme.textPrimary
                                            Layout.preferredWidth: 60; elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData.bezeichnung || ""
                                            font.pixelSize: 11; color: theme.textSecondary
                                            Layout.fillWidth: true; elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        // Notiz
                        Text { text: qsTr("Notiz"); color: theme.textMuted; font.pixelSize: 11 }
                        Rectangle {
                            Layout.fillWidth: true; height: 60
                            color: theme.inputBg; radius: 4; border.color: theme.border
                            TextArea {
                                id: taKabelNotiz
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
                                id: tfKabelGeprueftVon; Layout.fillWidth: true; implicitHeight: 28
                                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                                color: theme.textPrimary; font.pixelSize: 12
                            }
                            TextField {
                                id: tfKabelGeprueftAm; Layout.fillWidth: true; implicitHeight: 28
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
                            background: Rectangle { color: parent.hovered ? theme.btnPrimary : theme.activeItem; radius: 4 }
                            onClicked: {
                                var fl = kabelListe._gelistet
                                if (!fl || root.kabelAusgewaehlterIndex >= fl.length) return
                                var k = fl[root.kabelAusgewaehlterIndex]
                                var stKey = cmbKabelStatus.model[cmbKabelStatus.currentIndex].key
                                db.ibnKabelSpeichern(root.projektId, k.kabelId,
                                    stKey, taKabelNotiz.text.trim(),
                                    tfKabelGeprueftVon.text.trim(),
                                    tfKabelGeprueftAm.text.trim())
                                kabelLaden()
                                var fl2 = root._gefilterteKabelListe()
                                for (var i = 0; i < fl2.length; i++) {
                                    if (fl2[i].kabelId === k.kabelId) {
                                        root.kabelAusgewaehlterIndex = i; break
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
                                    onClicked: {
                                        var fl = kabelListe._gelistet
                                        if (!fl || root.kabelAusgewaehlterIndex >= fl.length) return
                                        var k = fl[root.kabelAusgewaehlterIndex]
                                        db.ibnKabelStatusSetzen(k.kabelId, modelData.key)
                                        kabelLaden()
                                        var fl2 = root._gefilterteKabelListe()
                                        for (var i = 0; i < fl2.length; i++) {
                                            if (fl2[i].kabelId === k.kabelId) {
                                                root.kabelAusgewaehlterIndex = i; break
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item { height: 12 }
                    }

                    // Formular befüllen wenn Kabel-Selektion wechselt
                    Connections {
                        target: root
                        function onKabelAusgewaehlterIndexChanged() {
                            var fl = kabelListe._gelistet
                            if (!fl || root.kabelAusgewaehlterIndex < 0
                                    || root.kabelAusgewaehlterIndex >= fl.length) return
                            var k = fl[root.kabelAusgewaehlterIndex]
                            var si = ["offen","in_arbeit","abgeschlossen"].indexOf(k.status)
                            cmbKabelStatus.currentIndex = si >= 0 ? si : 0
                            taKabelNotiz.text           = k.notiz      || ""
                            tfKabelGeprueftVon.text     = k.geprueftVon || ""
                            tfKabelGeprueftAm.text      = k.geprueftAm  || ""
                            // Adern laden
                            if (k.grafikElementId > 0) {
                                var det = db.kabelLinieDetails(k.grafikElementId)
                                root._kabelAdern = det.adern || []
                            } else {
                                root._kabelAdern = []
                            }
                        }
                    }
                }
            }
        }

        // ── Statusleiste ──────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 28; color: theme.surfaceDeep
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                Text {
                    text: {
                        var fl = root._kategorie === "kabel"
                                 ? root._gefilterteKabelListe()
                                 : root._gefilterteListe()
                        var offen  = fl.filter(function(e){ return e.status === "offen"         }).length
                        var fertig = fl.filter(function(e){ return e.status === "abgeschlossen" }).length
                        return qsTr("%1 gesamt  ·  %2 offen  ·  %3 fertig")
                               .arg(fl.length).arg(offen).arg(fertig)
                    }
                    font.pixelSize: 10; color: theme.textMuted
                }
                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("PDF"); flat: true; implicitHeight: 24; implicitWidth: 44
                    contentItem: Text { text: parent.text; color: theme.accent; font.pixelSize: 11;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 3;
                        border.color: parent.hovered ? theme.border : "transparent" }
                    onClicked: pdfSaveDialog.open()
                    ToolTip.visible: hovered; ToolTip.text: qsTr("Prüfprotokoll als PDF exportieren")
                    ToolTip.delay: 600
                }

                Button {
                    text: qsTr("⟳"); flat: true; implicitHeight: 24; implicitWidth: 28
                    contentItem: Text { text: parent.text; color: theme.accent; font.pixelSize: 14;
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 3 }
                    onClicked: root.laden()
                }
            }
        }
    }

    IbnFeldEditorDialog {
        id: feldEditorDialog
        theme: root.theme
        onFelderGeaendert: {
            var fl = bmListe._gelistet
            if (!fl || root.ausgewaehlterIndex < 0 || root.ausgewaehlterIndex >= fl.length) return
            var e = fl[root.ausgewaehlterIndex]
            var kat = e.symbolKategorie || ""
            root._dynFelder = kat !== "" ? db.ibnFeldvorlagenLaden(kat) : []
        }
    }

    // ── PDF-Export ────────────────────────────────────────
    FileDialog {
        id: pdfSaveDialog
        title: qsTr("Prüfprotokoll speichern")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("PDF-Datei (*.pdf)"), qsTr("Alle Dateien (*)")]
        defaultSuffix: "pdf"
        onAccepted: {
            var sid = root.ansichtModus === "seite" ? root.seiteId : -1
            var ok  = db.ibnProtokollPdfSpeichern(root.projektId, sid,
                                                   selectedFile.toString())
            pdfMeldung.erfolg = ok
            pdfMeldung.open()
        }
    }

    Popup {
        id: pdfMeldung
        property bool erfolg: true
        modal: false; dim: false
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 280; height: 64
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: pdfMeldung.erfolg ? "#1e4d2b" : "#4d1e1e"
            radius: 6; border.color: pdfMeldung.erfolg ? "#2a8a4a" : "#aa3333"
        }
        contentItem: Text {
            text: pdfMeldung.erfolg ? qsTr("✓ PDF gespeichert.") : qsTr("✗ PDF konnte nicht gespeichert werden.")
            color: "white"; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }

        Timer { running: pdfMeldung.visible; interval: 2800; onTriggered: pdfMeldung.close() }
    }

    DebugLabel { panelName: qsTr("IBN-Ansicht"); visible: root.debug }
}
