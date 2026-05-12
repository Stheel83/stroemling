import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: panel

    property int  projektId: -1
    property var  theme
    property bool debug:     false

    // Modus-A-Platzierung: Klemme aus Klemmenreihe direkt im Canvas platzieren
    signal klemmeAnschlussModusAPlatzieren(int bauteilKlemmeId, string anschlussBezeichnung, string bmk, int klemmeId)

    onProjektIdChanged: {
        aktivLeistenId  = -1
        aktivKlemmeIdx  = -1
        if (projektId >= 0)
            klemmenleistenModel.laden(projektId)
    }

    // ── interner Zustand ────────────────────────────────────────────
    property int aktivLeistenId: -1
    property int aktivKlemmeIdx: -1   // Index in klemmenreiheModel.klemmen

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
                    background: Rectangle { color: parent.enabled ? (parent.hovered ? theme.btnPrimary : theme.activeItem) : theme.btnDisabled; radius: 4 }
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
                            klemmenreiheModel.klemmeBauteilSetzen(bauteilWaehlDlg.klemmeId, modelData.bauteilId)
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
                    background: Rectangle { color: parent.enabled ? (parent.hovered ? theme.btnPrimary : theme.activeItem) : theme.btnDisabled; radius: 4 }
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

        background: Rectangle {
            color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 6
        }

        onAboutToShow: {
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
                        contentItem: Text {
                            text: modelData.bezeichnung + "  Eb." + modelData.ebene
                            color: theme.textPrimary; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
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
                    enabled: modusAPlatzierDlg.selAnschluss !== "" && modusAPlatzierDlg.bauteilKlemmeId >= 0
                    contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? theme.btnPrimary : theme.activeItem) : theme.btnDisabled; radius: 4
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
                            color: addLeistenBtn.containsMouse ? theme.btnPrimary : theme.activeItem
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

                    Text {
                        anchors.centerIn: parent
                        visible: leisteListView.count === 0
                        text: projektId < 0
                              ? qsTr("Kein Projekt geöffnet")
                              : qsTr("Noch keine\nKlemmenleiste")
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 11; color: theme.textMuted
                    }
                }
            }
            DebugLabel { panelName: qsTr("Leistenliste"); visible: panel.debug }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: theme.border }

        // ============================================================
        // Mittlere Spalte – Klemmenreihen-Vorschau
        // ============================================================
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible:           aktivLeistenId >= 0

            DebugLabel { panelName: qsTr("Klemmenreihen-Vorschau"); visible: panel.debug }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Kopfzeile
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color:  theme.surfaceDeep
                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        Text {
                            text: klemmenreiheModel.hatLeiste
                                  ? (klemmenreiheModel.leiste["bmkKurz"] || "-" + (klemmenreiheModel.leiste["bezeichnung"] || ""))
                                  : ""
                            font.pixelSize: 14; font.weight: Font.Medium
                            color: theme.accent
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: klemmenreiheModel.hatLeiste && klemmenreiheModel.leiste["gesamtBreiteMm"] > 0
                            text: {
                                if (!klemmenreiheModel.hatLeiste) return ""
                                var kl = klemmenreiheModel.klemmen
                                var ohneAngabe = 0
                                for (var i = 0; i < kl.length; ++i)
                                    if (kl[i].breiteMm === 0) ohneAngabe++
                                var total = 0
                                for (var j = 0; j < kl.length; ++j)
                                    total += kl[j].breiteMm
                                var t = total.toFixed(1) + " mm"
                                if (ohneAngabe > 0) t += "  (" + ohneAngabe + qsTr(" ohne Angabe") + ")"
                                return t
                            }
                            font.pixelSize: 11
                            color: theme.textMuted
                        }
                    }
                }
                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                // Klemmen-Reihe mit Stegbrücken-Balken (scrollbar horizontal)
                ScrollView {
                    id:                klemScrollView
                    Layout.fillWidth:  true
                    Layout.fillHeight: true
                    contentWidth:      klemmenRow.x + klemmenRow.implicitWidth + 16
                    clip:              true

                    Item {
                        width:  Math.max(klemScrollView.availableWidth,
                                         klemmenRow.x + klemmenRow.implicitWidth + 16)
                        height: klemScrollView.availableHeight

                        Row {
                            id:      klemmenRow
                            x:       16
                            y:       Math.max(8, (parent.height
                                     - klemmenRow.implicitHeight
                                     - (stegBars.visible ? stegBars.height + 8 : 0)) / 2)
                            spacing: 2
                            padding: 0

                            Repeater {
                                model: klemmenreiheModel.klemmen

                                delegate: Rectangle {
                                    width:   Math.max(48, modelData.breiteMm > 0 ? modelData.breiteMm * 4 : 48)
                                    height:  80
                                    radius:  3
                                    color:   aktivKlemmeIdx === index
                                             ? theme.activeItemAlt
                                             : (klemmeMa.containsMouse ? theme.hover : theme.surface)
                                    border.color: aktivKlemmeIdx === index ? theme.accent : theme.border
                                    border.width: aktivKlemmeIdx === index ? 2 : 1

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text:            modelData.nummer || String(index + 1)
                                            font.pixelSize:  12; font.weight: Font.Bold
                                            color:           aktivKlemmeIdx === index ? theme.accent : theme.textPrimary
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: modelData.breiteMm > 0
                                            text:    modelData.breiteMm.toFixed(1)
                                            font.pixelSize: 9
                                            color:   theme.textMuted
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: modelData.bauteilName !== ""
                                            text:    modelData.bauteilName
                                            font.pixelSize: 8
                                            color:   theme.textSubtle
                                            width:   parent.parent.width - 8
                                            elide:   Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id:           klemmeMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked:    aktivKlemmeIdx = (aktivKlemmeIdx === index ? -1 : index)
                                    }
                                }
                            }

                            // Leere-Ansicht falls keine Klemmen
                            Item {
                                visible: klemmenreiheModel.klemmen.length === 0
                                width:   300; height: 80
                                Text {
                                    anchors.centerIn: parent
                                    text:    qsTr("Noch keine Klemmen\n+ Klemme hinzufügen")
                                    font.pixelSize: 12; color: theme.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Stegbrücken-Balken
                        Item {
                            id:      stegBars
                            x:       klemmenRow.x
                            y:       klemmenRow.y + klemmenRow.height + 8
                            width:   klemmenRow.implicitWidth
                            height:  klemmenreiheModel.stegbruecken.length * 22 + 4
                            visible: klemmenreiheModel.stegbruecken.length > 0

                            Repeater {
                                model: klemmenreiheModel.stegbruecken

                                delegate: Item {
                                    x:      klemmeX(modelData.vonIdx)
                                    y:      index * 22
                                    width:  klemmeBarWidth(modelData.vonIdx, modelData.bisIdx)
                                    height: 18

                                    Rectangle {
                                        anchors.fill: parent
                                        color:   modelData.hatKonflikt ? "#7a2020" : stegFarbe(index)
                                        radius:  3
                                        opacity: 0.85
                                    }
                                    Text {
                                        anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                                        text: "Eb." + modelData.ebene + "  "
                                              + modelData.vonNummer + "–" + modelData.bisNummer
                                              + (modelData.potenzialText ? "  " + modelData.potenzialText : "")
                                              + (modelData.hatKonflikt ? "  ⚠" : "")
                                        font.pixelSize: 9; color: "white"
                                        elide: Text.ElideRight; width: parent.width - 8
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { height: 1; Layout.fillWidth: true; color: theme.border }

                // Toolbar
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    color:  theme.surfaceDeep

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 8

                        Button {
                            text: qsTr("+ Klemme")
                            implicitHeight: 28
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 12; color: theme.textPrimary
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? theme.btnPrimary : theme.activeItem; radius: 4
                            }
                            onClicked: {
                                klemmenreiheModel.klemmeAnlegen(-1)
                                aktivKlemmeIdx = klemmenreiheModel.klemmen.length - 1
                            }
                        }

                        // Pfeil hoch/runter (nur wenn Klemme ausgewählt)
                        Button {
                            visible: aktivKlemmeIdx > 0
                            text: "▲"
                            implicitWidth: 32; implicitHeight: 28
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 12; color: theme.textSecondary
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 4
                            }
                            onClicked: {
                                var k = klemmenreiheModel.klemmen[aktivKlemmeIdx]
                                if (k && klemmenreiheModel.klemmeSchieben(k.klemmeId, -1))
                                    aktivKlemmeIdx -= 1
                            }
                        }
                        Button {
                            visible: aktivKlemmeIdx >= 0 && aktivKlemmeIdx < klemmenreiheModel.klemmen.length - 1
                            text: "▼"
                            implicitWidth: 32; implicitHeight: 28
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 12; color: theme.textSecondary
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? theme.hover : "transparent"; border.color: theme.border; border.width: 1; radius: 4
                            }
                            onClicked: {
                                var k = klemmenreiheModel.klemmen[aktivKlemmeIdx]
                                if (k && klemmenreiheModel.klemmeSchieben(k.klemmeId, 1))
                                    aktivKlemmeIdx += 1
                            }
                        }

                        // Löschen-Button (nur wenn Klemme ausgewählt)
                        Button {
                            visible: aktivKlemmeIdx >= 0
                            text: qsTr("Löschen")
                            implicitHeight: 28
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 12; color: "#e05050"
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? "#3a1010" : "transparent"; border.color: "#7a3030"; border.width: 1; radius: 4
                            }
                            onClicked: {
                                var k = klemmenreiheModel.klemmen[aktivKlemmeIdx]
                                if (k) {
                                    klemmenreiheModel.klemmeLoeschen(k.klemmeId)
                                    aktivKlemmeIdx = -1
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: klemmenreiheModel.hatLeiste
                            text: {
                                var aus = klemmenreiheModel.leiste["ausrichtung"] || "senkrecht"
                                return aus === "senkrecht" ? qsTr("Senkrecht") : qsTr("Liegend")
                            }
                            font.pixelSize: 11; color: theme.textMuted
                        }
                    }
                }
            }
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

        // ============================================================
        // Rechte Spalte – Klemmen-Eigenschaften
        // ============================================================
        Rectangle {
            id:                  eigenschaftenSpalte
            Layout.preferredWidth: 260
            Layout.fillHeight:   true
            color:               theme.sidebar
            visible:             aktivLeistenId >= 0

            DebugLabel { panelName: qsTr("Klemmen-Eigenschaften"); visible: panel.debug }

            Flickable {
                anchors.fill:        parent
                contentHeight:       eigenCol.implicitHeight + 16
                clip:                true
                ScrollBar.vertical:  ScrollBar {}

                ColumnLayout {
                    id:       eigenCol
                    x:        12; y: 12
                    width:    parent.width - 24
                    spacing:  6

                    // ── Klemmenleiste ────────────────────────────────
                    Text {
                        text: qsTr("KLEMMENLEISTE")
                        font.pixelSize: 9; font.weight: Font.Bold
                        color: theme.textMuted; font.letterSpacing: 1
                    }
                    Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }

                    // BMK
                    Text {
                        text: klemmenreiheModel.hatLeiste
                              ? (klemmenreiheModel.leiste["bmkVollstaendig"] || klemmenreiheModel.leiste["bmkKurz"] || "")
                              : ""
                        font.pixelSize: 14; font.weight: Font.Bold
                        color: theme.accent
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Bezeichnung editierbar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: qsTr("Bezeichnung:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        TextField {
                            id:               leisteBezeichnungField
                            Layout.fillWidth: true
                            text:             klemmenreiheModel.hatLeiste ? (klemmenreiheModel.leiste["bezeichnung"] || "") : ""
                            font.pixelSize:   12; color: theme.textPrimary
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                            onEditingFinished: {
                                if (klemmenreiheModel.hatLeiste) {
                                    var d = Object.assign({}, klemmenreiheModel.leiste)
                                    d["bezeichnung"] = text
                                    klemmenreiheModel.leisteAktualisieren(d)
                                }
                            }
                        }
                    }

                    // Ausrichtung
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: qsTr("Ausrichtung:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        ComboBox {
                            id:               ausrichtungCombo
                            Layout.fillWidth: true
                            model:            [qsTr("Senkrecht"), qsTr("Liegend")]
                            currentIndex:     klemmenreiheModel.hatLeiste && klemmenreiheModel.leiste["ausrichtung"] === "liegend" ? 1 : 0
                            font.pixelSize:   12
                            contentItem: Text {
                                text: ausrichtungCombo.displayText
                                font: ausrichtungCombo.font
                                color: theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 8
                            }
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                            popup.background: Rectangle { color: theme.sidebar; border.color: theme.border; border.width: 1; radius: 4 }
                            delegate: ItemDelegate {
                                width: ausrichtungCombo.width
                                contentItem: Text {
                                    text:  modelData
                                    color: theme.textPrimary; font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: parent.hovered ? theme.hover : theme.sidebar
                                }
                            }
                            onActivated: {
                                if (klemmenreiheModel.hatLeiste) {
                                    var d = Object.assign({}, klemmenreiheModel.leiste)
                                    d["ausrichtung"] = currentIndex === 1 ? "liegend" : "senkrecht"
                                    klemmenreiheModel.leisteAktualisieren(d)
                                }
                            }
                        }
                    }

                    // Anlage / Standort übergeordnet
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Text { text: qsTr("==Anlage:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        TextField {
                            Layout.fillWidth: true
                            text: klemmenreiheModel.hatLeiste ? (klemmenreiheModel.leiste["anlageUebergeordnet"] || "") : ""
                            font.pixelSize: 12; color: theme.textPrimary
                            placeholderText: qsTr("optional")
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                            onEditingFinished: {
                                if (klemmenreiheModel.hatLeiste) {
                                    var d = Object.assign({}, klemmenreiheModel.leiste)
                                    d["anlageUebergeordnet"] = text
                                    klemmenreiheModel.leisteAktualisieren(d)
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Text { text: qsTr("++Standort:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        TextField {
                            Layout.fillWidth: true
                            text: klemmenreiheModel.hatLeiste ? (klemmenreiheModel.leiste["standortUebergeordnet"] || "") : ""
                            font.pixelSize: 12; color: theme.textPrimary
                            placeholderText: qsTr("optional")
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                            onEditingFinished: {
                                if (klemmenreiheModel.hatLeiste) {
                                    var d = Object.assign({}, klemmenreiheModel.leiste)
                                    d["standortUebergeordnet"] = text
                                    klemmenreiheModel.leisteAktualisieren(d)
                                }
                            }
                        }
                    }

                    // Bemerkung
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Text { text: qsTr("Bemerkung:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        TextField {
                            Layout.fillWidth: true
                            text: klemmenreiheModel.hatLeiste ? (klemmenreiheModel.leiste["bemerkung"] || "") : ""
                            font.pixelSize: 12; color: theme.textPrimary
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                            onEditingFinished: {
                                if (klemmenreiheModel.hatLeiste) {
                                    var d = Object.assign({}, klemmenreiheModel.leiste)
                                    d["bemerkung"] = text
                                    klemmenreiheModel.leisteAktualisieren(d)
                                }
                            }
                        }
                    }

                    // Statistik
                    Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: qsTr("Klemmen:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        Text {
                            text: klemmenreiheModel.klemmen.length
                            font.pixelSize: 12; color: theme.textSecondary
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: qsTr("Gesamtbreite:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        Text {
                            text: {
                                var kl  = klemmenreiheModel.klemmen
                                var sum = 0; var ohne = 0
                                for (var i = 0; i < kl.length; ++i) {
                                    if (kl[i].breiteMm > 0) sum += kl[i].breiteMm
                                    else ohne++
                                }
                                if (sum === 0 && ohne > 0) return qsTr("unbekannt")
                                var t = sum.toFixed(1) + " mm"
                                if (ohne > 0) t += " (+" + ohne + qsTr(" o.A.") + ")"
                                return t
                            }
                            font.pixelSize: 12; color: theme.textSecondary
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                        }
                    }
                    Text {
                        visible: {
                            var kl = klemmenreiheModel.klemmen
                            for (var i = 0; i < kl.length; ++i)
                                if (kl[i].breiteMm === 0) return true
                            return false
                        }
                        text: qsTr("Richtwert – Endböcke und Trennplatten\nsind nicht eingerechnet.")
                        font.pixelSize: 9; color: theme.textMuted
                        wrapMode: Text.Wrap; Layout.fillWidth: true
                    }

                    // ── Stegbrücken (Leiste) ─────────────────────────
                    Item { height: 8 }
                    Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text {
                            text: qsTr("STEGBRÜCKEN")
                            font.pixelSize: 9; font.weight: Font.Bold
                            color: theme.textMuted; font.letterSpacing: 1
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            width: 22; height: 22; radius: 3
                            color: addStegBtn.containsMouse ? theme.btnPrimary : theme.activeItem
                            Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; color: theme.textPrimary }
                            MouseArea {
                                id: addStegBtn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                enabled: klemmenreiheModel.klemmen.length >= 2
                                onClicked: neueStegDlg.open()
                            }
                        }
                    }

                    // Liste der Stegbrücken
                    Repeater {
                        model: klemmenreiheModel.stegbruecken
                        delegate: ColumnLayout {
                            Layout.fillWidth: true; spacing: 3

                            RowLayout {
                                Layout.fillWidth: true; spacing: 4
                                Rectangle {
                                    width: 30; height: 18; radius: 3
                                    color: modelData.hatKonflikt ? "#7a2020" : stegFarbe(index)
                                    opacity: 0.85
                                    Text { anchors.centerIn: parent
                                           text: "Eb." + modelData.ebene; font.pixelSize: 8; color: "white" }
                                }
                                Text {
                                    text: modelData.vonNummer + "–" + modelData.bisNummer
                                    font.pixelSize: 11; color: theme.textSecondary
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: modelData.hatKonflikt
                                    text: "⚠"; font.pixelSize: 11; color: "#e05050"
                                    ToolTip.visible: hatKonfliktMa.containsMouse
                                    ToolTip.text: modelData.konfliktText || ""
                                    MouseArea { id: hatKonfliktMa; anchors.fill: parent; hoverEnabled: true }
                                }
                                Rectangle {
                                    width: 18; height: 18; radius: 3
                                    color: stegDelMa.containsMouse ? "#7a2020" : "transparent"
                                    border.color: "#7a3030"; border.width: 1
                                    Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 12; color: "#e05050" }
                                    MouseArea {
                                        id: stegDelMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: klemmenreiheModel.stegbrueckeLoeschen(modelData.stegId)
                                    }
                                }
                            }

                            // Potenzial-Textfeld
                            TextField {
                                Layout.fillWidth: true
                                text:             modelData.potenzialText || ""
                                placeholderText:  qsTr("Potenzial (z.B. L1, PE, 24VDC)")
                                font.pixelSize:   11; color: theme.textPrimary
                                background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                                onEditingFinished: klemmenreiheModel.stegbrueckePotenzialSetzen(modelData.stegId, text)
                            }
                        }
                    }

                    Text {
                        visible: klemmenreiheModel.stegbruecken.length === 0
                        text: qsTr("Keine Stegbrücken")
                        font.pixelSize: 10; color: theme.textMuted
                    }

                    // ── Klemme ausgewählt ────────────────────────────
                    Item { height: 8; visible: aktivKlemme !== null }
                    Text {
                        visible: aktivKlemme !== null
                        text: qsTr("KLEMME")
                        font.pixelSize: 9; font.weight: Font.Bold
                        color: theme.textMuted; font.letterSpacing: 1
                    }
                    Rectangle {
                        visible: aktivKlemme !== null
                        height: 1; Layout.fillWidth: true; color: theme.divider
                    }

                    // Klemmennummer editierbar
                    RowLayout {
                        visible: aktivKlemme !== null
                        Layout.fillWidth: true; spacing: 6
                        Text { text: qsTr("Nummer:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        TextField {
                            Layout.fillWidth: true
                            text: aktivKlemme ? (aktivKlemme.nummer || "") : ""
                            font.pixelSize: 13; font.weight: Font.Bold
                            color: theme.accent
                            background: Rectangle { color: theme.inputBg; border.color: theme.border; border.width: 1; radius: 3 }
                            onEditingFinished: {
                                if (aktivKlemme)
                                    klemmenreiheModel.klemmeNummerSetzen(aktivKlemme.klemmeId, text)
                            }
                        }
                    }

                    // Bauteil – immer anzeigen (mit "(kein)" wenn nicht zugewiesen)
                    RowLayout {
                        visible: aktivKlemme !== null
                        Layout.fillWidth: true; spacing: 0
                        Text { text: qsTr("Bauteil:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        Text {
                            text: aktivKlemme && aktivKlemme.bauteilId > 0
                                  ? (aktivKlemme.bauteilName || "")
                                  : qsTr("(kein)")
                            font.pixelSize: 12
                            color: aktivKlemme && aktivKlemme.bauteilId > 0 ? theme.textSecondary : theme.textMuted
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                        }
                    }

                    // Buttons: Zuweisen / Ändern / Entfernen
                    RowLayout {
                        visible: aktivKlemme !== null
                        Layout.fillWidth: true; spacing: 6
                        Button {
                            text: aktivKlemme && aktivKlemme.bauteilId > 0 ? qsTr("Ändern") : qsTr("Zuweisen")
                            implicitHeight: 24
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 11; color: theme.textPrimary
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? theme.btnPrimary : theme.activeItem; radius: 3
                            }
                            onClicked: {
                                bauteilWaehlDlg.klemmeId = aktivKlemme.klemmeId
                                bauteilWaehlDlg.open()
                            }
                        }
                        Button {
                            visible: aktivKlemme !== null && aktivKlemme.bauteilId > 0
                            text: qsTr("Entfernen")
                            implicitHeight: 24
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 11; color: "#e05050"
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? "#3a1010" : "transparent"; border.color: "#7a3030"; border.width: 1; radius: 3
                            }
                            onClicked: klemmenreiheModel.klemmeBauteilSetzen(aktivKlemme.klemmeId, 0)
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // Typ, Breite, Querschnitte (nur wenn Bauteil zugewiesen)
                    RowLayout {
                        visible: aktivKlemme !== null && aktivKlemme !== undefined && aktivKlemme.anschlussTyp !== ""
                        Layout.fillWidth: true; spacing: 0
                        Text { text: qsTr("Typ:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        Text {
                            text: aktivKlemme ? (aktivKlemme.anschlussTyp || "") : ""
                            font.pixelSize: 12; color: theme.textSecondary
                        }
                    }
                    RowLayout {
                        visible: aktivKlemme !== null && aktivKlemme !== undefined && aktivKlemme.breiteMm > 0
                        Layout.fillWidth: true; spacing: 0
                        Text { text: qsTr("Breite:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        Text {
                            text: aktivKlemme ? aktivKlemme.breiteMm.toFixed(1) + " mm" : ""
                            font.pixelSize: 12; color: theme.textSecondary
                        }
                    }
                    RowLayout {
                        visible: aktivKlemme !== null && aktivKlemme !== undefined && (aktivKlemme.querschnitteText || "") !== ""
                        Layout.fillWidth: true; spacing: 0
                        Text { text: qsTr("Querschnitt:"); font.pixelSize: 11; color: theme.textMuted; Layout.preferredWidth: 90 }
                        Text {
                            text: aktivKlemme ? (aktivKlemme.querschnitteText || "") : ""
                            font.pixelSize: 11; color: theme.textSecondary
                            Layout.fillWidth: true; wrapMode: Text.Wrap
                        }
                    }

                    // Im Canvas platzieren (Modus A – Verknüpft)
                    RowLayout {
                        visible: aktivKlemme !== null && aktivKlemme !== undefined && aktivKlemme.bauteilId > 0
                        Layout.fillWidth: true; spacing: 6
                        Item { Layout.fillWidth: true }
                        Button {
                            text: qsTr("Im Canvas platzieren")
                            implicitHeight: 24
                            contentItem: Text {
                                text: parent.text; font.pixelSize: 11; color: theme.textPrimary
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: parent.hovered ? theme.btnPrimary : theme.activeItem; radius: 3
                            }
                            onClicked: {
                                klemmeModel.laden(aktivKlemme.bauteilId)
                                var bkId      = klemmeModel.klemme["klemmeId"] || -1
                                var leisteBmk = klemmenreiheModel.leiste["bmkKurz"]
                                               || ("-" + (klemmenreiheModel.leiste["bezeichnung"] || ""))
                                modusAPlatzierDlg.klemmeId        = aktivKlemme.klemmeId
                                modusAPlatzierDlg.bauteilKlemmeId = bkId
                                modusAPlatzierDlg.bmkPrefix       = leisteBmk + ":" + (aktivKlemme.nummer || "")
                                modusAPlatzierDlg.open()
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // Stegbrücken dieser Klemme (gefiltert)
                    Item {
                        height: 8
                        visible: aktivKlemme !== null && klemmenreiheModel.stegbruecken.some(
                            function(s) { return s.vonKlemmeId === aktivKlemme.klemmeId || s.bisKlemmeId === aktivKlemme.klemmeId })
                    }
                    Text {
                        visible: aktivKlemme !== null && klemmenreiheModel.stegbruecken.some(
                            function(s) { return s.vonKlemmeId === aktivKlemme.klemmeId || s.bisKlemmeId === aktivKlemme.klemmeId })
                        text: qsTr("Stegbrücken (diese Klemme)")
                        font.pixelSize: 9; font.weight: Font.Bold
                        color: theme.textMuted; font.letterSpacing: 1
                    }
                    Repeater {
                        model: aktivKlemme !== null
                               ? klemmenreiheModel.stegbruecken.filter(function(s) {
                                     return s.vonKlemmeId === aktivKlemme.klemmeId
                                         || s.bisKlemmeId === aktivKlemme.klemmeId
                                 })
                               : []
                        delegate: RowLayout {
                            Layout.fillWidth: true; spacing: 4
                            Rectangle {
                                width: 30; height: 16; radius: 2
                                color: modelData.hatKonflikt ? "#7a2020" : "#4a7a9b"; opacity: 0.85
                                Text { anchors.centerIn: parent; text: "Eb." + modelData.ebene; font.pixelSize: 8; color: "white" }
                            }
                            Text {
                                text: modelData.vonNummer + "–" + modelData.bisNummer
                                      + (modelData.potenzialText ? "  " + modelData.potenzialText : "")
                                font.pixelSize: 11; color: theme.textMuted; Layout.fillWidth: true; wrapMode: Text.Wrap
                            }
                        }
                    }

                    // Leiste löschen
                    Item { height: 16 }
                    Rectangle { height: 1; Layout.fillWidth: true; color: theme.divider }
                    Button {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        text: qsTr("Klemmenleiste löschen")
                        contentItem: Text {
                            text: parent.text; font.pixelSize: 11; color: "#e05050"
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered ? "#3a1010" : "transparent"; border.color: "#7a3030"; border.width: 1; radius: 4
                        }
                        onClicked: {
                            klemmenleistenModel.loeschen(aktivLeistenId)
                            aktivLeistenId = -1
                            aktivKlemmeIdx = -1
                            leisteListView.currentIndex = -1
                        }
                    }
                    Item { height: 4 }
                }
            }
        }
    }
}
