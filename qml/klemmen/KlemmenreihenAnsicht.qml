import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: panel

    property int  projektId: -1
    property var  theme
    property bool debug:     false

    // Modus-A-Platzierung: Klemme aus Klemmenreihe direkt im Canvas platzieren
    signal klemmeAnschlussModusAPlatzieren(int bauteilKlemmeId, string anschlussBezeichnung, string bmk, int klemmeId)
    // Platzierte Canvas-Elemente wurden mit aktuellem Bauteil synchronisiert → Canvas neu laden
    signal leisteKanvasAktualisiert()

    onProjektIdChanged: {
        aktivLeistenId  = -1
        aktivKlemmeIdx  = -1
        if (projektId >= 0)
            klemmenleistenModel.laden(projektId)
    }

    // ── interner Zustand ────────────────────────────────────────────
    property int aktivLeistenId: -1
    property int aktivKlemmeIdx: -1   // Index in klemmenreiheModel.klemmen

    // CE-05: Mehrfachauswahl (klemmeIds)
    property var _ausgewaehlt: []

    Connections {
        target: klemmenreiheModel
        function onLeisteGeladen() {
            // Auswahl leeren wenn eine andere Leiste geladen wird
            var ids = klemmenreiheModel.klemmen.map(function(k) { return k.klemmeId })
            var ungueltig = panel._ausgewaehlt.some(function(id) { return ids.indexOf(id) < 0 })
            if (ungueltig) panel._ausgewaehlt = []
        }
        function onKanvasGeaendert() {
            panel.leisteKanvasAktualisiert()
        }
    }

    readonly property var aktivKlemme:
        (aktivKlemmeIdx >= 0 && aktivKlemmeIdx < klemmenreiheModel.klemmen.length)
        ? klemmenreiheModel.klemmen[aktivKlemmeIdx]
        : null

    // ── Hilfsfunktionen für Stegbrücken-Balken ─────────────────────
    function klemmeX(idx) {
        if (idx < 0) return 0
        var x = 0; var kl = klemmenreiheModel.klemmen
        for (var i = 0; i < idx && i < kl.length; ++i)
            x += Math.max(48, kl[i].breiteMm > 0 ? kl[i].breiteMm * 4 : 48) + 2
        return x
    }
    function klemmeBarWidth(vonIdx, bisIdx) {
        var kl = klemmenreiheModel.klemmen
        if (vonIdx < 0 || bisIdx < 0 || bisIdx >= kl.length) return 48
        return klemmeX(bisIdx) + Math.max(48, kl[bisIdx].breiteMm > 0 ? kl[bisIdx].breiteMm * 4 : 48) - klemmeX(vonIdx)
    }
    function stegFarbe(idx) {
        var farben = ["#4a7a9b", "#7a4a9b", "#4a9b7a", "#9b7a4a", "#7a9b4a"]
        return farben[idx % farben.length]
    }

    // Klemmen-Nummern für Stegbrücken-Dialog (ComboBox-Modell)
    readonly property var klemmenNummern: {
        var nrs = []; var kl = klemmenreiheModel.klemmen
        for (var i = 0; i < kl.length; ++i)
            nrs.push(kl[i].nummer !== "" ? kl[i].nummer : String(i + 1))
        return nrs
    }

    // ── Dialog: Leiste anlegen ──────────────────────────────────────
    Dialog {
        id:    neueLeisteDlg
        title: qsTr("Neue Klemmenleiste")
        modal: true
        parent:  Overlay.overlay
        anchors.centerIn: parent
        width:  300
        padding: 16
        background: Rectangle {
            color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6
        }

        property string eingegebenerName: ""

        onAboutToShow: { eingegebenerName = ""; neueLeisteName.forceActiveFocus() }

        contentItem: ColumnLayout {
            spacing: 10
            Text {
                text: qsTr("Bezeichnung (z. B. X1):")
                color: theme.textSecondary; font.pixelSize: 12
            }
            TextField {
                id:               neueLeisteName
                Layout.fillWidth: true
                placeholderText:  "X1"
                color:            theme.textPrimary
                font.pixelSize:   13
                background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 4 }
                onTextChanged: neueLeisteDlg.eingegebenerName = text
                Keys.onReturnPressed: neueLeisteDlg.accept()
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen")
                    implicitWidth: 90; implicitHeight: 28
                    contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 4 }
                    onClicked: neueLeisteDlg.reject()
                }
                Button {
                    text: qsTr("Anlegen")
                    implicitWidth: 80; implicitHeight: 28
                    enabled: neueLeisteDlg.eingegebenerName.trim().length > 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: neueLeisteDlg.accept()
                }
            }
        }
        onAccepted: {
            var name = eingegebenerName.trim()
            if (name.length > 0 && projektId >= 0) {
                var newId = klemmenleistenModel.anlegen(projektId, name)
                if (newId >= 0) {
                    // Neue Leiste direkt auswählen
                    for (var i = 0; i < klemmenleistenModel.rowCount(); ++i) {
                        var idx = klemmenleistenModel.index(i, 0)
                        if (klemmenleistenModel.data(idx, Qt.UserRole + 1) === newId) {
                            leisteListView.currentIndex = i
                            break
                        }
                    }
                    aktivLeistenId = newId
                    klemmenreiheModel.laden(newId)
                    aktivKlemmeIdx = -1
                }
            }
        }
    }

    // ── Dialog: Bauteil aus Katalog zuweisen ────────────────────────
    Dialog {
        id:    bauteilWaehlDlg
        title: qsTr("Bauteil zuweisen")
        modal: true
        parent:  Overlay.overlay
        anchors.centerIn: parent
        width:  420
        height: 380
        padding: 0

        property int    klemmeId:       -1
        property string suchtext:       ""
        property int    refreshCounter: 0

        background: Rectangle {
            color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6
        }

        onAboutToShow: {
            refreshCounter++
            suchtext = ""
            bauteilSuchfeld.text = ""
            bauteilSuchfeld.forceActiveFocus()
        }

        contentItem: ColumnLayout {
            spacing: 0

            // Header
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: theme.surfaceDeep
                radius: 6
                // Ecken unten nicht runden
                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 8; color: parent.color }
                Text {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: qsTr("Bauteil zuweisen")
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: theme.textPrimary
                }
            }
            Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

            // Suchfeld
            TextField {
                id:               bauteilSuchfeld
                Layout.fillWidth: true
                Layout.margins:   10
                placeholderText:  qsTr("Klemme suchen…")
                color:            theme.textPrimary
                font.pixelSize:   13
                background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 4 }
                onTextChanged: bauteilWaehlDlg.suchtext = text
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

            // Ergebnisliste
            ListView {
                id:               bauteilSuchListe
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip:             true
                model: {
                    bauteilWaehlDlg.refreshCounter
                    return klemmenreiheModel.klemmeBauteileHolen(bauteilWaehlDlg.suchtext)
                }

                ScrollBar.vertical: ScrollBar {}

                delegate: Rectangle {
                    width:  parent ? parent.width : 0
                    height: 54
                    color:  bauteilMa.containsMouse ? theme.hover : "transparent"

                    Column {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text {
                            text:           modelData.bezeichnung
                            font.pixelSize: 13; font.weight: Font.Medium
                            color:          theme.textPrimary
                            elide:          Text.ElideRight
                            width:          bauteilSuchListe.width - 28
                        }
                        Text {
                            text: {
                                var t = modelData.anschlussTyp || ""
                                if (modelData.breiteMm > 0) t += (t ? "  ·  " : "") + modelData.breiteMm.toFixed(1) + " mm"
                                if (modelData.hersteller)   t += (t ? "  ·  " : "") + modelData.hersteller
                                return t
                            }
                            font.pixelSize: 10
                            color:          theme.textMuted
                        }
                    }
                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: theme.border; opacity: 0.5 }

                    MouseArea {
                        id:           bauteilMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            if (panel._ausgewaehlt.length >= 2) {
                                klemmenreiheModel.klemmeMehrfachBauteilSetzen(panel._ausgewaehlt, modelData.bauteilId)
                                panel._ausgewaehlt = []
                            } else {
                                klemmenreiheModel.klemmeBauteilSetzen(bauteilWaehlDlg.klemmeId, modelData.bauteilId)
                            }
                            bauteilWaehlDlg.close()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible:          bauteilSuchListe.count === 0
                    text:             qsTr("Keine Klemmen-Bauteile gefunden.\nBauteil-Datenbank zuerst befüllen.")
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize:   12; color: theme.textMuted
                }
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

            // Footer
            RowLayout {
                Layout.fillWidth: true
                Layout.margins:   10
                spacing: 6
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen")
                    implicitWidth: 90; implicitHeight: 28
                    contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 4 }
                    onClicked: bauteilWaehlDlg.close()
                }
            }
        }
    }

    // ── Dialog: Neue Stegbrücke ─────────────────────────────────────
    Dialog {
        id:    neueStegDlg
        title: qsTr("Stegbrücke anlegen")
        modal: true
        parent:  Overlay.overlay
        anchors.centerIn: parent
        width:  280
        padding: 16

        property int selEbene:  1
        property int selVonIdx: 0
        property int selBisIdx: 0

        background: Rectangle {
            color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6
        }

        onAboutToShow: {
            selEbene  = 1
            selVonIdx = 0
            selBisIdx = Math.min(1, klemmenreiheModel.klemmen.length - 1)
            ebeneField.text = "1"
        }

        contentItem: ColumnLayout {
            spacing: 10

            // Ebene
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: qsTr("Ebene:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 55 }
                TextField {
                    id: ebeneField
                    text: "1"; implicitWidth: 60; implicitHeight: 28
                    font.pixelSize: 12; color: theme.textPrimary
                    validator: IntValidator { bottom: 1; top: 20 }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    onTextChanged: neueStegDlg.selEbene = parseInt(text) || 1
                }
            }

            // Von-Klemme
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: qsTr("Von:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 55 }
                ComboBox {
                    id: vonCombo
                    Layout.fillWidth: true
                    model: klemmenNummern
                    currentIndex: neueStegDlg.selVonIdx
                    font.pixelSize: 12
                    contentItem: Text { text: vonCombo.displayText; color: theme.textPrimary; font: vonCombo.font; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate { width: vonCombo.width
                        contentItem: Text { text: modelData; color: theme.textPrimary; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? theme.hover : theme.sidebar } }
                    onActivated: neueStegDlg.selVonIdx = currentIndex
                }
            }

            // Bis-Klemme
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: qsTr("Bis:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 55 }
                ComboBox {
                    id: bisCombo
                    Layout.fillWidth: true
                    model: klemmenNummern
                    currentIndex: neueStegDlg.selBisIdx
                    font.pixelSize: 12
                    contentItem: Text { text: bisCombo.displayText; color: theme.textPrimary; font: bisCombo.font; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate { width: bisCombo.width
                        contentItem: Text { text: modelData; color: theme.textPrimary; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? theme.hover : theme.sidebar } }
                    onActivated: neueStegDlg.selBisIdx = currentIndex
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); implicitWidth: 90; implicitHeight: 28
                    contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 4 }
                    onClicked: neueStegDlg.reject()
                }
                Button {
                    text: qsTr("Anlegen"); implicitWidth: 80; implicitHeight: 28
                    enabled: klemmenreiheModel.klemmen.length >= 2
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: neueStegDlg.accept()
                }
            }
        }

        onAccepted: {
            var kl = klemmenreiheModel.klemmen
            if (kl.length < 1) return
            var vonId = kl[Math.min(selVonIdx, kl.length - 1)].klemmeId
            var bisId = kl[Math.min(selBisIdx, kl.length - 1)].klemmeId
            klemmenreiheModel.stegbrueckeAnlegen(selEbene, vonId, bisId)
        }
    }

    // ── Dialog: Anschluss im Canvas platzieren (Modus A) ───────────
    Dialog {
        id: modusAPlatzierDlg
        title: qsTr("Anschluss platzieren")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 320
        padding: 16

        property int    klemmeId:        -1
        property int    bauteilKlemmeId: -1
        property string bmkPrefix:       ""
        property string selAnschluss:    ""
        property var    _platziert:      ({})   // anschlussBezeichnung → true

        function _ladeStatus() {
            var alle = db.platzierteKlemmenAnschluesse()
            var map  = {}
            for (var i = 0; i < alle.length; i++) {
                if (alle[i].klemmeId === klemmeId)
                    map[alle[i].anschlussBezeichnung] = true
            }
            _platziert = map
        }

        background: Rectangle {
            color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6
        }

        onAboutToShow: {
            _ladeStatus()
            selAnschluss = klemmeModel.anschluesse.length > 0
                           ? klemmeModel.anschluesse[0].bezeichnung : ""
            if (anschlussComboA.count > 0) anschlussComboA.currentIndex = 0
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: aktivKlemme ? (aktivKlemme.bauteilName || "") : ""
                font.pixelSize: 12; font.weight: Font.Medium
                color: theme.accent; Layout.fillWidth: true; elide: Text.ElideRight
                visible: text !== ""
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: qsTr("Anschluss:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 80 }
                ComboBox {
                    id: anschlussComboA
                    Layout.fillWidth: true
                    model: klemmeModel.anschluesse
                    textRole: "bezeichnung"
                    font.pixelSize: 12
                    contentItem: Text {
                        text: anschlussComboA.displayText
                        font: anschlussComboA.font; color: theme.textPrimary
                        verticalAlignment: Text.AlignVCenter; leftPadding: 8
                    }
                    background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate {
                        width: anschlussComboA.width
                        property bool istPlatziert: modusAPlatzierDlg._platziert[modelData.bezeichnung] === true
                        contentItem: Text {
                            text: (parent.istPlatziert ? "✓ " : "") + modelData.bezeichnung + "  Eb." + modelData.ebene
                            color: parent.istPlatziert ? theme.textMuted : theme.textPrimary
                            font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { color: parent.hovered ? theme.hover : theme.sidebar }
                    }
                    onActivated: {
                        var list = klemmeModel.anschluesse
                        if (currentIndex >= 0 && currentIndex < list.length)
                            modusAPlatzierDlg.selAnschluss = list[currentIndex].bezeichnung
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: qsTr("BMK:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 80 }
                Text {
                    text: modusAPlatzierDlg.bmkPrefix + ":" + modusAPlatzierDlg.selAnschluss
                    font.pixelSize: 12; font.weight: Font.Bold
                    color: theme.accent; Layout.fillWidth: true; elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); implicitWidth: 90; implicitHeight: 28
                    contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 4 }
                    onClicked: modusAPlatzierDlg.reject()
                }
                Button {
                    text: qsTr("Platzieren"); implicitWidth: 90; implicitHeight: 28
                    enabled: modusAPlatzierDlg.selAnschluss !== ""
                             && modusAPlatzierDlg.bauteilKlemmeId >= 0
                             && !modusAPlatzierDlg._platziert[modusAPlatzierDlg.selAnschluss]
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.accent : theme.inputBg) : theme.inputBg
                        radius: 4; border.color: parent.enabled ? theme.accent : theme.border
                    }
                    onClicked: modusAPlatzierDlg.accept()
                }
            }
        }

        onAccepted: {
            if (selAnschluss !== "" && bauteilKlemmeId >= 0) {
                var fullBmk = bmkPrefix + ":" + selAnschluss
                panel.klemmeAnschlussModusAPlatzieren(bauteilKlemmeId, selAnschluss, fullBmk, klemmeId)
            }
        }
    }

    // ── Hauptlayout ─────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ============================================================
        // Linke Spalte – Klemmenleisten-Liste
        // ============================================================
        Rectangle {
            id:                 leistenSpalte
            Layout.preferredWidth: 200
            Layout.fillHeight:  true
            color:              theme.sidebar

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: 0
                spacing:         0

                // Header
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color:  theme.surfaceDeep
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
                        Text {
                            text: qsTr("Klemmenleisten")
                            font.pixelSize: 12; font.weight: Font.Medium
                            color: theme.textSecondary
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            width: 26; height: 26; radius: 4
                            color: duplizierLeisteBtn.containsMouse ? theme.hover : "transparent"
                            border.color: theme.border
                            opacity: duplizierLeisteBtn.enabled ? 1.0 : 0.4
                            Text { anchors.centerIn: parent; text: "❐"; font.pixelSize: 13; color: theme.textSecondary }
                            ToolTip.visible: duplizierLeisteBtn.containsMouse
                            ToolTip.text:    qsTr("Ausgewählte Klemmenleiste duplizieren (alle Klemmen + Stegbrücken)")
                            ToolTip.delay:   500
                            MouseArea {
                                id:            duplizierLeisteBtn
                                anchors.fill:  parent
                                hoverEnabled:  true
                                cursorShape:   Qt.PointingHandCursor
                                enabled:       leisteListView.currentIndex >= 0
                                onClicked: {
                                    var newId = klemmenleistenModel.duplizieren(aktivLeistenId)
                                    if (newId > 0) {
                                        for (var i = 0; i < klemmenleistenModel.rowCount(); ++i) {
                                            var idx = klemmenleistenModel.index(i, 0)
                                            if (klemmenleistenModel.data(idx, Qt.UserRole + 1) === newId) {
                                                leisteListView.currentIndex = i
                                                break
                                            }
                                        }
                                        aktivLeistenId = newId
                                        klemmenreiheModel.laden(newId)
                                        aktivKlemmeIdx = -1
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: 26; height: 26; radius: 4
                            color: addLeistenBtn.containsMouse ? theme.accent : theme.inputBg
                            border.color: theme.accent
                            Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 18; color: theme.textPrimary }
                            MouseArea {
                                id:            addLeistenBtn
                                anchors.fill:  parent
                                hoverEnabled:  true
                                cursorShape:   Qt.PointingHandCursor
                                enabled:       projektId >= 0
                                onClicked:     neueLeisteDlg.open()
                            }
                        }
                    }
                }

                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                ListView {
                    id:               leisteListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model:            klemmenleistenModel
                    clip:             true
                    currentIndex:     -1

                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        width:  parent ? parent.width : 0
                        height: 52
                        color:  leisteListView.currentIndex === index
                                ? theme.activeItem
                                : (leisteMa.containsMouse ? theme.hoverSidebar : "transparent")

                        Column {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text {
                                text:           "-" + bezeichnung
                                font.pixelSize: 13; font.weight: Font.Medium
                                color:          leisteListView.currentIndex === index ? theme.accent : theme.textPrimary
                                elide:          Text.ElideRight
                                width:          160
                            }
                            Text {
                                text:           anzahlKlemmen + qsTr(" Kl.") +
                                                (gesamtBreiteMm > 0 ? "  –  " + gesamtBreiteMm.toFixed(1) + " mm" : "")
                                font.pixelSize: 10
                                color:          theme.textMuted
                            }
                        }
                        MouseArea {
                            id:           leisteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked: {
                                leisteListView.currentIndex = index
                                aktivLeistenId  = leisteId
                                aktivKlemmeIdx  = -1
                                klemmenreiheModel.laden(leisteId)
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: leisteListView.count === 0 && projektId >= 0
                        spacing: 10
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Noch keine\nKlemmenleiste")
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: 11; color: theme.textMuted
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 160; height: 28; radius: 4
                            color: beispielBtn.containsMouse ? theme.accent : theme.inputBg
                            border.color: theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Beispiel-Leiste anlegen")
                                font.pixelSize: 11; color: theme.textPrimary
                            }
                            MouseArea {
                                id: beispielBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    klemmenleistenModel.beispielLeistenAnlegen(projektId)
                                    aktivLeistenId = -1
                                    aktivKlemmeIdx = -1
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: leisteListView.count === 0 && projektId < 0
                        text: qsTr("Kein Projekt geöffnet")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 11; color: theme.textMuted
                    }
                }
            }
            DebugLabel { panelName: qsTr("Leistenliste"); visible: panel.debug }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: theme.border }


        KrVorschauPanel {
            panel: panel
            theme: panel.theme
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible:           aktivLeistenId >= 0
        }

        // Platzhalter wenn keine Leiste ausgewählt
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible:           aktivLeistenId < 0

            Text {
                anchors.centerIn: parent
                text: projektId < 0
                      ? qsTr("Kein Projekt geöffnet.\nWähle links ein Projekt aus.")
                      : qsTr("Wähle links eine\nKlemmenleiste aus.")
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 14; color: theme.textMuted
            }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: theme.border; visible: aktivLeistenId >= 0 }


        KrEigenschaftenPanel {
            panel: panel
            theme: panel.theme
            visible:               aktivLeistenId >= 0
            Layout.preferredWidth: 260
            Layout.fillHeight:     true
            onNeueStegAngefordert:       neueStegDlg.open()
            onBauteilWaehlenAngefordert: function(kId) {
                bauteilWaehlDlg.klemmeId = kId
                bauteilWaehlDlg.open()
            }
            onModusAPlatzierenAngefordert: function(kId, bkId, prefix) {
                modusAPlatzierDlg.klemmeId        = kId
                modusAPlatzierDlg.bauteilKlemmeId = bkId
                modusAPlatzierDlg.bmkPrefix       = prefix
                modusAPlatzierDlg.open()
            }
            onLeisteGeloescht:           leisteListView.currentIndex = -1
            onLeisteKanvasAktualisiert:  panel.leisteKanvasAktualisiert()
        }
    }
}
