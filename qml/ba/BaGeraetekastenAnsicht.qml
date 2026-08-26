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
    signal kontaktenSequentiellPlatzierenAngefordert(string queueJson)
    // Gerätekasten-Bauteil-/Partner-Verknüpfung schreibt extra_daten per Roh-SQL direkt in
    // grafik_element, ohne das Canvas-ElementeModel zu aktualisieren. Ohne dieses Signal
    // überschreibt der nächste grafikSpeichernJetzt()-Autosave (DELETE+INSERT aus dem
    // veralteten In-Memory-Stand) die frisch gesetzten Felder wieder — Muster 1:1 von
    // KlemmenreihenAnsicht.qml übernommen (dort: klemmeNummerSetzen()+aktualisiereKanvasBmk()).
    signal leisteKanvasAktualisiert()

    property var _flachListe: []

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

    // Baut die Warteschlange aller noch nicht platzierten Positionen eines
    // Steckverbinder-Typs und startet das sequentielle Platzieren (analog
    // Klemmenreihen-Anschlüsse) — erspart pro Position den kompletten
    // Dialog-Zyklus (Öffnen → Position wählen → Bestätigen).
    function _kontaktSequenzStarten(geraetekastenId, svTypId, bmkTxt) {
        var positionen = db.steckverbinderPositionenLaden(svTypId)
        var queue = []
        for (var i = 0; i < positionen.length; i++) {
            var pos = positionen[i]
            if (db.steckverbinderPositionIstPlatziert(pos.id)) continue
            queue.push({
                geraetekastenId: geraetekastenId,
                positionId:      pos.id,
                symbolId:        pos.geschlecht === "stift" ? "stecker" : "buchse",
                bmk:             bmkTxt
            })
        }
        if (queue.length > 0)
            root.kontaktenSequentiellPlatzierenAngefordert(JSON.stringify(queue))
    }

    onVisibleChanged:  { if (visible) laden() }
    onProjektIdChanged: laden()

    // --------------------------------------------------------
    // Dialoge (REFACTOR-QML-02: ausgelagert in eigene Dateien)
    // --------------------------------------------------------
    BaSteckverbinderBauteilPickerDialog { id: svPicker;           theme: root.theme; ga: root }
    BaKontaktPlatzierenDialog           { id: kontaktPlatzierDlg; theme: root.theme; ga: root }
    BaPartnerPickerDialog               { id: partnerPicker;      theme: root.theme; ga: root }

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
                    color: reloadHover.hovered ? root.theme.hover : "transparent"
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
                                        color: vknHover.hovered ? root.theme.accent : "transparent"
                                        border.color: vknHover.hovered ? root.theme.accent : root.theme.border
                                        HoverHandler { id: vknHover }
                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("+ Verknüpfen")
                                            font.pixelSize: 10
                                            color: vknHover.hovered ? "white" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: svPicker.oeffnen(gkd.id)
                                        }
                                    }
                                    // Sprung-Button
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        color: sprungHover.hovered ? root.theme.accent : "transparent"
                                        border.color: sprungHover.hovered ? root.theme.accent : root.theme.border
                                        HoverHandler { id: sprungHover }
                                        Text {
                                            anchors.centerIn: parent; text: "→"
                                            font.pixelSize: 11
                                            color: sprungHover.hovered ? "white" : root.theme.accent
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
                                        color: kpHover.hovered ? root.theme.accent : "transparent"
                                        border.color: kpHover.hovered ? root.theme.accent : root.theme.border
                                        HoverHandler { id: kpHover }
                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("Kontakt platzieren")
                                            font.pixelSize: 9
                                            color: kpHover.hovered ? "white" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: kontaktPlatzierDlg.oeffnen(gkd.id, instDelegate.svTyp.id, gkd.bmk || "")
                                        }
                                    }
                                    // "⇥ Sequentiell platzieren" (alle offenen Positionen nacheinander,
                                    // ohne den Dialog je Position erneut zu öffnen)
                                    Rectangle {
                                        visible: instDelegate.svTyp && instDelegate.svTyp.id > 0
                                        width: 20; height: 18; radius: 3
                                        color: kpSeqMa.containsMouse ? root.theme.accent : "transparent"
                                        border.color: kpSeqMa.containsMouse ? root.theme.accent : root.theme.border
                                        Text {
                                            anchors.centerIn: parent
                                            text: "⇥"
                                            font.pixelSize: 11
                                            color: kpSeqMa.containsMouse ? "white" : root.theme.accent
                                        }
                                        ToolTip.visible: kpSeqMa.containsMouse
                                        ToolTip.text:    qsTr("Alle offenen Positionen nacheinander platzieren")
                                        ToolTip.delay:   400
                                        MouseArea {
                                            id: kpSeqMa; anchors.fill: parent
                                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root._kontaktSequenzStarten(gkd.id, instDelegate.svTyp.id, gkd.bmk || "")
                                        }
                                    }
                                    // "Anderes…" Link
                                    Text {
                                        text: qsTr("Anderes…")
                                        font.pixelSize: 10; color: root.theme.accent
                                        font.underline: andMa.containsMouse
                                        MouseArea {
                                            id: andMa
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: svPicker.oeffnen(gkd.id)
                                        }
                                    }
                                    // "× Aufheben"
                                    Rectangle {
                                        width: 18; height: 18; radius: 3
                                        color: aufhebHover.hovered ? "#3a1111" : "transparent"
                                        HoverHandler { id: aufhebHover }
                                        Text {
                                            anchors.centerIn: parent; text: "×"
                                            font.pixelSize: 12
                                            color: aufhebHover.hovered ? "#ff6666" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                db.geraetekastenBauteilSetzen(gkd.id, 0)
                                                root.laden()
                                                root.leisteKanvasAktualisiert()
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
                                        color: partnerSprungHover.hovered ? root.theme.accent : "transparent"
                                        border.color: partnerSprungHover.hovered ? root.theme.accent : root.theme.border
                                        HoverHandler { id: partnerSprungHover }
                                        Text {
                                            anchors.centerIn: parent; text: "→"; font.pixelSize: 10
                                            color: partnerSprungHover.hovered ? "white" : root.theme.accent
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
                                        font.underline: partnerLinkMa.containsMouse
                                        MouseArea {
                                            id: partnerLinkMa
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: partnerPicker.oeffnen(gkd.id)
                                        }
                                    }
                                    // "× Aufheben"
                                    Rectangle {
                                        visible: partnerRow.partnerObj !== null
                                        width: 18; height: 18; radius: 3
                                        color: partnerAufhebHover.hovered ? "#3a1111" : "transparent"
                                        HoverHandler { id: partnerAufhebHover }
                                        Text {
                                            anchors.centerIn: parent; text: "×"; font.pixelSize: 12
                                            color: partnerAufhebHover.hovered ? "#ff6666" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                db.geraetekastenPartnerAufheben(gkd.id)
                                                root.laden()
                                                root.leisteKanvasAktualisiert()
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
