import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling
import "../components"

Item {
    id: root
    required property int projektId
    required property var theme
    property bool debug: false

    signal sprungAngefordert(int seiteId, string blattnr, string seiteBez, real wx, real wy)
    signal kontaktPlatzierenAngefordert(int geraetekastenId, int positionId, string symbolId, string bmk)

    property var _flachListe: []
    property int _pickerFuerElId: -1

    // Gruppierung über Anlage+Ort+BMK (nicht nur BMK!), da derselbe kurze BMK
    // in unterschiedlichen Anlagen/Orten verschiedene, eigenständige Geräte
    // bezeichnen kann (Strukturkasten-Override).
    property var _gruppiert: {
        var gruppen = {}
        var reihenfolge = []
        for (var i = 0; i < root._flachListe.length; i++) {
            var gk = root._flachListe[i]
            var bmk = gk.bmk || ""
            var anlage = gk.anlageKz || "", ort = gk.ortKz || ""
            var key = anlage + "|" + ort + "|" + bmk
            if (!gruppen[key]) {
                var vk = (gk.anlageUO ? ("==" + gk.anlageUO) : "") +
                         (gk.ortUO    ? ("++" + gk.ortUO)    : "") +
                         (anlage      ? ("=" + anlage)        : "") +
                         (ort         ? ("+" + ort)            : "") + bmk
                gruppen[key] = { bmk: bmk, vollkennzeichen: vk, bezeichnung: gk.bezeichnung || "", instanzen: [] }
                reihenfolge.push(key)
            }
            gruppen[key].instanzen.push(gk)
        }
        return reihenfolge.map(function(k) { return gruppen[k] })
    }

    function laden() {
        root._flachListe = root.projektId >= 0
            ? db.geraetekastenListeMitPos(root.projektId)
            : []
    }

    onVisibleChanged:  { if (visible) laden() }
    onProjektIdChanged: laden()

    // ── Steckverbinder-Bauteil-Picker ─────────────────────────
    Popup {
        id: svPicker
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 420; height: 340
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var _liste: []
        function oeffnen(elementId) {
            root._pickerFuerElId = elementId
            svPicker._liste = db.steckverbinderBausteineListe()
            svPicker.open()
        }

        background: Rectangle {
            color: root.theme.surface
            border.color: root.theme.border; border.width: 1; radius: 6
        }

        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 0

            Text {
                width: parent.width
                text: qsTr("Steckverbinder-Bauteil wählen")
                font.pixelSize: 13; font.weight: Font.Medium
                color: root.theme.textPrimary; padding: 6
            }

            Rectangle { width: parent.width; height: 1; color: root.theme.border }

            ListView {
                id: pickerList
                width: parent.width
                height: parent.height - 50
                clip: true
                model: svPicker._liste

                Text {
                    visible: svPicker._liste.length === 0
                    anchors.centerIn: parent
                    text: qsTr("Keine Steckverbinder-Bauteile vorhanden.\nErstelle zuerst einen Eintrag unter Bibliothek → Steckverbinder.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                }

                delegate: Rectangle {
                    width: pickerList.width; height: 42
                    color: pickerItemHover.containsMouse ? root.theme.hover : "transparent"
                    HoverHandler { id: pickerItemHover }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 2
                        Text {
                            width: parent.width
                            text: modelData.bezeichnung
                            font.pixelSize: 12; color: root.theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: (modelData.hersteller || "") +
                                  (modelData.polzahl > 0 ? "  ·  " + modelData.polzahl + qsTr("-polig") : "")
                            font.pixelSize: 10; color: root.theme.textMuted
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root._pickerFuerElId >= 0) {
                                db.geraetekastenBauteilSetzen(root._pickerFuerElId, modelData.id)
                                root.laden()
                            }
                            svPicker.close()
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.theme.border }

            Item {
                width: parent.width; height: 36
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Abbrechen")
                    font.pixelSize: 12; color: root.theme.textMuted
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: svPicker.close()
                    }
                }
            }
        }
    }

    // ── Kontakt-Platzieren-Dialog (verknüpfte Canvas-Platzierung, §8.2.1) ─
    Dialog {
        id: kontaktPlatzierDlg
        title: qsTr("Kontakt platzieren")
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 340
        padding: 16

        property int    geraetekastenId:     -1
        property int    steckverbinderTypId: -1
        property string bmk:                 ""
        property var    _positionen:         []
        property int    selPositionId:       -1

        function _laden() {
            _positionen = db.steckverbinderPositionenLaden(steckverbinderTypId)
            var idx = 0
            for (var i = 0; i < _positionen.length; i++) {
                if (!db.steckverbinderPositionIstPlatziert(_positionen[i].id)) { idx = i; break }
            }
            selPositionId = _positionen.length > 0 ? _positionen[idx].id : -1
            if (posCombo.count > 0) posCombo.currentIndex = idx
        }

        function oeffnen(elementId, svTypId, bmkTxt) {
            geraetekastenId     = elementId
            steckverbinderTypId = svTypId
            bmk                 = bmkTxt
            _laden()
            open()
        }

        background: Rectangle {
            color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 6
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: kontaktPlatzierDlg.bmk
                font.pixelSize: 12; font.weight: Font.Medium
                color: root.theme.accent; Layout.fillWidth: true; elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: qsTr("Position:"); font.pixelSize: 11; color: root.theme.textMuted; Layout.preferredWidth: 60 }
                ComboBox {
                    id: posCombo
                    Layout.fillWidth: true
                    model: kontaktPlatzierDlg._positionen
                    font.pixelSize: 12
                    contentItem: Text {
                        text: {
                            if (posCombo.currentIndex < 0 || posCombo.currentIndex >= kontaktPlatzierDlg._positionen.length) return ""
                            var p = kontaktPlatzierDlg._positionen[posCombo.currentIndex]
                            return qsTr("Pos. %1: %2").arg(p.positionNr).arg(p.bezeichnung)
                        }
                        color: root.theme.textPrimary; font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter; leftPadding: 8
                    }
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate {
                        width: posCombo.width
                        property bool istPlatziert: db.steckverbinderPositionIstPlatziert(modelData.id)
                        contentItem: Text {
                            text: (istPlatziert ? "✓ " : "") + qsTr("Pos. %1: %2").arg(modelData.positionNr).arg(modelData.bezeichnung)
                            color: istPlatziert ? root.theme.textMuted : root.theme.textPrimary
                            font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.sidebar }
                    }
                    onActivated: {
                        if (currentIndex >= 0 && currentIndex < kontaktPlatzierDlg._positionen.length)
                            kontaktPlatzierDlg.selPositionId = kontaktPlatzierDlg._positionen[currentIndex].id
                    }
                }
            }

            Text {
                visible: kontaktPlatzierDlg._positionen.length === 0
                text: qsTr("Keine Positionen definiert. Im Bauteil-Editor unter Steckverbinder → POSITIONEN anlegen.")
                font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                wrapMode: Text.WordWrap; Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Abbrechen"); implicitWidth: 90; implicitHeight: 28
                    contentItem: Text { text: parent.text; color: root.theme.textMuted; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; border.color: root.theme.border; border.width: 1; radius: 4 }
                    onClicked: kontaktPlatzierDlg.reject()
                }
                Button {
                    text: qsTr("Platzieren"); implicitWidth: 90; implicitHeight: 28
                    enabled: kontaktPlatzierDlg.selPositionId >= 0
                             && !db.steckverbinderPositionIstPlatziert(kontaktPlatzierDlg.selPositionId)
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
                        radius: 4; border.color: parent.enabled ? root.theme.accent : root.theme.border
                    }
                    onClicked: kontaktPlatzierDlg.accept()
                }
            }
        }

        onAccepted: {
            if (selPositionId < 0) return
            var pos = null
            for (var i = 0; i < _positionen.length; i++) {
                if (_positionen[i].id === selPositionId) { pos = _positionen[i]; break }
            }
            if (!pos) return
            var symbolId = pos.geschlecht === "stift" ? "stecker" : "buchse"
            root.kontaktPlatzierenAngefordert(geraetekastenId, selPositionId, symbolId, bmk)
        }
    }

    // ── Partner-Picker (Steckerpaar-Verknüpfung, §10.3) ───────────────────
    Popup {
        id: partnerPicker
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 420; height: 340
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property int _fuerElId: -1
        property var _liste:    []

        function _geschlecht(bauteilId) {
            if (bauteilId <= 0) return ""
            var t = db.steckverbinderTypLaden(bauteilId)
            if (!t || !t.montageform) return ""
            var teile = t.montageform.split("_")
            return teile.length > 1 ? teile[1] : ""
        }

        // Sortierung: gleiches BMK + komplementäres Geschlecht zuerst (§10.3).
        function oeffnen(elementId) {
            partnerPicker._fuerElId = elementId
            var eigenes = null
            for (var i = 0; i < root._flachListe.length; i++)
                if (root._flachListe[i].id === elementId) { eigenes = root._flachListe[i]; break }
            var eigenesBmk        = eigenes ? (eigenes.bmk || "") : ""
            var eigenesGeschlecht = eigenes ? partnerPicker._geschlecht(eigenes.bauteilId) : ""

            var kandidaten = []
            for (var j = 0; j < root._flachListe.length; j++) {
                var gk = root._flachListe[j]
                if (gk.id === elementId) continue
                var g = partnerPicker._geschlecht(gk.bauteilId)
                if (!g) continue   // nur Gerätekästen mit verknüpftem Steckverbinder-Bauteil
                var komplementaer = (eigenesGeschlecht === "stecker" && g === "buchse")
                                  || (eigenesGeschlecht === "buchse" && g === "stecker")
                var gleichesBmk = eigenesBmk !== "" && gk.bmk === eigenesBmk
                var score = 3
                if (gleichesBmk && komplementaer) score = 0
                else if (gleichesBmk)             score = 1
                else if (komplementaer)           score = 2
                kandidaten.push({ id: gk.id, bmk: gk.bmk, bauteilBez: gk.bauteilBez,
                                  geschlecht: g, blattnr: gk.blattnr, score: score })
            }
            kandidaten.sort(function(a, b) { return a.score - b.score })
            partnerPicker._liste = kandidaten
            partnerPicker.open()
        }

        background: Rectangle {
            color: root.theme.surface
            border.color: root.theme.border; border.width: 1; radius: 6
        }

        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 0

            Text {
                width: parent.width
                text: qsTr("Partner-Gerätekasten wählen")
                font.pixelSize: 13; font.weight: Font.Medium
                color: root.theme.textPrimary; padding: 6
            }
            Rectangle { width: parent.width; height: 1; color: root.theme.border }

            ListView {
                id: partnerPickerList
                width: parent.width
                height: parent.height - 50
                clip: true
                model: partnerPicker._liste

                Text {
                    visible: partnerPicker._liste.length === 0
                    anchors.centerIn: parent
                    text: qsTr("Keine passenden Gerätekästen gefunden.\nVerknüpfe zuerst ein Steckverbinder-Bauteil.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                }

                delegate: Rectangle {
                    width: partnerPickerList.width; height: 42
                    color: partnerItemHover.containsMouse ? root.theme.hover : "transparent"
                    HoverHandler { id: partnerItemHover }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 2
                        Text {
                            width: parent.width
                            text: (modelData.bmk || qsTr("(ohne BMK)")) + "  ·  " + (modelData.bauteilBez || "")
                            font.pixelSize: 12; color: root.theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: (modelData.geschlecht === "stecker" ? qsTr("Stecker") : qsTr("Buchse"))
                                  + "  ·  " + qsTr("Blatt ") + (modelData.blattnr || "–")
                                  + (modelData.score <= 1 ? "  ·  " + qsTr("gleiches BMK") : "")
                            font.pixelSize: 10; color: root.theme.textMuted
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            db.geraetekastenPartnerSetzen(partnerPicker._fuerElId, modelData.id)
                            root.laden()
                            partnerPicker.close()
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.theme.border }

            Item {
                width: parent.width; height: 36
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Abbrechen")
                    font.pixelSize: 12; color: root.theme.textMuted
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: partnerPicker.close()
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 40
            color: root.theme.surfaceDeep
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1; color: root.theme.border
            }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12
                Text {
                    text: qsTr("Gerätekästen")
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: root.theme.textPrimary; Layout.fillWidth: true
                }
                Text {
                    visible: root._flachListe.length > 0
                    text: root._gruppiert.length + qsTr(" Geräte  ·  ") + root._flachListe.length + qsTr(" Kästen")
                    font.pixelSize: 10; color: root.theme.textMuted
                }
                Rectangle {
                    width: 22; height: 22; radius: 3
                    color: reloadHover.containsMouse ? root.theme.hover : "transparent"
                    HoverHandler { id: reloadHover }
                    Text { anchors.centerIn: parent; text: "⟳"; font.pixelSize: 14; color: root.theme.accent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.laden()
                    }
                }
            }
        }

        // ── Leerzustand ──────────────────────────────────────
        Item {
            visible: root._gruppiert.length === 0
            Layout.fillWidth: true; Layout.fillHeight: true
            Column {
                anchors.centerIn: parent; spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📐"; font.pixelSize: 32; opacity: 0.3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Noch keine Gerätekästen im Projekt.")
                    font.pixelSize: 12; color: root.theme.textMuted; font.italic: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Gerätekästen mit der Taste G auf dem Canvas zeichnen.")
                    font.pixelSize: 11; color: root.theme.borderLight
                }
            }
        }

        // ── Geräte-Liste ─────────────────────────────────────
        ScrollView {
            visible: root._gruppiert.length > 0
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true

            Column {
                width: parent.width

                Repeater {
                    model: root._gruppiert
                    delegate: Column {
                        width: parent.width

                        // BMK-Gruppenzeile
                        Rectangle {
                            width: parent.width; height: 38
                            color: root.theme.surface
                            Rectangle {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                height: 1; color: root.theme.border
                            }
                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: 3; color: root.theme.accent
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12
                                spacing: 8
                                Text { text: "📐"; font.pixelSize: 13 }
                                Text {
                                    text: modelData.vollkennzeichen
                                    font.pixelSize: 12; font.weight: Font.Medium
                                    color: root.theme.textPrimary
                                }
                                Text {
                                    text: modelData.bezeichnung
                                    font.pixelSize: 11; color: root.theme.textSecondary
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Text {
                                    visible: modelData.instanzen.length > 1
                                    text: modelData.instanzen.length + "×"
                                    font.pixelSize: 10; color: root.theme.textMuted
                                }
                            }
                        }

                        // Instanzen
                        Repeater {
                            model: modelData.instanzen
                            delegate: Rectangle {
                                id: instDelegate
                                width: parent.width
                                property var gkd: modelData
                                property bool hatBauteil: gkd.bauteilId > 0
                                property var  svTyp: gkd.bauteilId > 0 ? db.steckverbinderTypLaden(gkd.bauteilId) : ({})
                                property bool istSteckverbinder: svTyp && svTyp.id > 0

                                height: !hatBauteil ? 30 : (istSteckverbinder ? 74 : 52)
                                color: instHover.containsMouse ? root.theme.hover : "transparent"

                                MouseArea {
                                    id: instHover; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.ArrowCursor
                                }

                                Rectangle {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                    height: 1; color: root.theme.divider
                                }

                                // ── Navigations-Zeile (oben, 30px) ──────────────
                                RowLayout {
                                    id: navRow
                                    anchors.top: parent.top; anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 28; anchors.rightMargin: 10
                                    height: 30; spacing: 6

                                    Text { text: "↳"; font.pixelSize: 11; color: root.theme.borderLight }
                                    Text {
                                        text: qsTr("Blatt ") + (gkd.blattnr || "–")
                                        font.pixelSize: 11; color: root.theme.textSecondary
                                        Layout.preferredWidth: 60
                                    }
                                    Text {
                                        text: gkd.seiteBez || ""
                                        font.pixelSize: 11; color: root.theme.textMuted
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    // "Verknüpfen"-Button (nur ohne Bauteil + bei Hover)
                                    Rectangle {
                                        visible: !instDelegate.hatBauteil && instHover.containsMouse
                                        width: 80; height: 20; radius: 3
                                        color: vknHover.containsMouse ? root.theme.accent : "transparent"
                                        border.color: vknHover.containsMouse ? root.theme.accent : root.theme.border
                                        HoverHandler { id: vknHover }
                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("+ Verknüpfen")
                                            font.pixelSize: 10
                                            color: vknHover.containsMouse ? "white" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: svPicker.oeffnen(gkd.id)
                                        }
                                    }
                                    // Sprung-Button
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        color: sprungHover.containsMouse ? root.theme.accent : "transparent"
                                        border.color: sprungHover.containsMouse ? root.theme.accent : root.theme.border
                                        HoverHandler { id: sprungHover }
                                        Text {
                                            anchors.centerIn: parent; text: "→"
                                            font.pixelSize: 11
                                            color: sprungHover.containsMouse ? "white" : root.theme.accent
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var d = gkd
                                                root.sprungAngefordert(d.seiteId, d.blattnr,
                                                                       d.seiteBez, d.weltX, d.weltY)
                                            }
                                        }
                                    }
                                }

                                // ── Bauteil-Info-Zeile (22px, unter der Navigations-Zeile) ─
                                RowLayout {
                                    id: bauteilRow
                                    visible: instDelegate.hatBauteil
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: navRow.bottom
                                    anchors.leftMargin: 42; anchors.rightMargin: 10
                                    height: 22; spacing: 6

                                    Text { text: "🔌"; font.pixelSize: 9 }
                                    Text {
                                        text: gkd.bauteilBez || ""
                                        font.pixelSize: 10; font.weight: Font.Medium
                                        color: root.theme.textSecondary; elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: gkd.bauteilHersteller || ""
                                        font.pixelSize: 10; color: root.theme.textMuted
                                        elide: Text.ElideRight; Layout.maximumWidth: 80
                                    }
                                    // "Kontakt platzieren" (nur wenn verknüpftes Bauteil ein Steckverbinder-Typ ist)
                                    Rectangle {
                                        visible: instDelegate.svTyp && instDelegate.svTyp.id > 0
                                        width: 96; height: 18; radius: 3
                                        color: kpHover.containsMouse ? root.theme.accent : "transparent"
                                        border.color: kpHover.containsMouse ? root.theme.accent : root.theme.border
                                        HoverHandler { id: kpHover }
                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("Kontakt platzieren")
                                            font.pixelSize: 9
                                            color: kpHover.containsMouse ? "white" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: kontaktPlatzierDlg.oeffnen(gkd.id, instDelegate.svTyp.id, gkd.bmk || "")
                                        }
                                    }
                                    // "Anderes…" Link
                                    Text {
                                        text: qsTr("Anderes…")
                                        font.pixelSize: 10; color: root.theme.accent
                                        font.underline: andHover.containsMouse
                                        HoverHandler { id: andHover }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: svPicker.oeffnen(gkd.id)
                                        }
                                    }
                                    // "× Aufheben"
                                    Rectangle {
                                        width: 18; height: 18; radius: 3
                                        color: aufhebHover.containsMouse ? "#3a1111" : "transparent"
                                        HoverHandler { id: aufhebHover }
                                        Text {
                                            anchors.centerIn: parent; text: "×"
                                            font.pixelSize: 12
                                            color: aufhebHover.containsMouse ? "#ff6666" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                db.geraetekastenBauteilSetzen(gkd.id, 0)
                                                root.laden()
                                            }
                                        }
                                    }
                                }

                                // ── Partner-Zeile (22px, nur bei verknüpftem Steckverbinder, §10.3) ─
                                RowLayout {
                                    id: partnerRow
                                    visible: instDelegate.istSteckverbinder
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.top: bauteilRow.bottom
                                    anchors.leftMargin: 42; anchors.rightMargin: 10
                                    height: 22; spacing: 6

                                    property var partnerObj: {
                                        if (!gkd.partnerGeraetekastenId || gkd.partnerGeraetekastenId <= 0) return null
                                        for (var i = 0; i < root._flachListe.length; i++)
                                            if (root._flachListe[i].id === gkd.partnerGeraetekastenId) return root._flachListe[i]
                                        return null
                                    }

                                    Text { text: "🔗"; font.pixelSize: 9 }
                                    Text {
                                        visible: partnerRow.partnerObj !== null
                                        text: partnerRow.partnerObj ? (qsTr("Partner: ") + (partnerRow.partnerObj.bmk || qsTr("(ohne BMK)"))) : ""
                                        font.pixelSize: 10; color: root.theme.textSecondary
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: partnerRow.partnerObj === null
                                        text: qsTr("Kein Partner verknüpft")
                                        font.pixelSize: 10; color: root.theme.textMuted; font.italic: true
                                        Layout.fillWidth: true
                                    }
                                    // Sprung zum Partner
                                    Rectangle {
                                        visible: partnerRow.partnerObj !== null
                                        width: 22; height: 18; radius: 3
                                        color: partnerSprungHover.containsMouse ? root.theme.accent : "transparent"
                                        border.color: partnerSprungHover.containsMouse ? root.theme.accent : root.theme.border
                                        HoverHandler { id: partnerSprungHover }
                                        Text {
                                            anchors.centerIn: parent; text: "→"; font.pixelSize: 10
                                            color: partnerSprungHover.containsMouse ? "white" : root.theme.accent
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var p = partnerRow.partnerObj
                                                if (p) root.sprungAngefordert(p.seiteId, p.blattnr, p.seiteBez, p.weltX, p.weltY)
                                            }
                                        }
                                    }
                                    // "Partner verknüpfen"/"Ändern" Link
                                    Text {
                                        text: partnerRow.partnerObj !== null ? qsTr("Ändern") : qsTr("Partner verknüpfen")
                                        font.pixelSize: 10; color: root.theme.accent
                                        font.underline: partnerLinkHover.containsMouse
                                        HoverHandler { id: partnerLinkHover }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: partnerPicker.oeffnen(gkd.id)
                                        }
                                    }
                                    // "× Aufheben"
                                    Rectangle {
                                        visible: partnerRow.partnerObj !== null
                                        width: 18; height: 18; radius: 3
                                        color: partnerAufhebHover.containsMouse ? "#3a1111" : "transparent"
                                        HoverHandler { id: partnerAufhebHover }
                                        Text {
                                            anchors.centerIn: parent; text: "×"; font.pixelSize: 12
                                            color: partnerAufhebHover.containsMouse ? "#ff6666" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                db.geraetekastenPartnerAufheben(gkd.id)
                                                root.laden()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Geraetekasten-Ansicht"); visible: root.debug }
}
