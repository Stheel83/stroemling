import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Klemmenleisten-Abschnitt im BAUTEILE-Bereich des Seitenbaums — ausgelagert
// aus SeitenBaumBauteilePanel.qml (REFACTOR-QML-03).
Column {
    id: root
    required property var panel
    required property var theme

    visible: panel._aktiveTab === "alles" || panel._aktiveTab === "klemmen"
    width: parent.width
    Repeater {
        model: klemmenleistenModel
        delegate: Column {
            id: leisteItem
            width: parent.width
            property int    leisteId:    model.leisteId
            property string bmkKurz:     model.bmkKurz
            property string bezeichnung: model.bezeichnung
            property bool   offen:       panel._leistenAufgeklappt[leisteId] === true

            // Leisten-Zeile
            Rectangle {
                width: parent.width; height: 32
                color: leisteMA.containsMouse ? root.theme.hover : "transparent"

                // leisteMA zuerst → liegt im Z-Stack unter dem RowLayout
                MouseArea {
                    id: leisteMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var lid = leisteItem.leisteId
                        var auf = Object.assign({}, panel._leistenAufgeklappt)
                        auf[lid] = !auf[lid]
                        if (auf[lid] && panel._klemmenCache[lid] === undefined) {
                            var c = Object.assign({}, panel._klemmenCache)
                            c[lid] = db.klemmenFuerLeiste(lid)
                            panel._klemmenCache = c
                        }
                        panel._leistenAufgeklappt = auf
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                    spacing: 5
                    Text { text: leisteItem.offen ? "▾" : "▸"; font.pixelSize: 9; color: root.theme.textMuted }
                    Text { text: "🔌"; font.pixelSize: 12 }
                    Text {
                        text: leisteItem.bmkKurz + "  " + leisteItem.bezeichnung
                        font.pixelSize: 12; color: root.theme.textPrimary
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    // Sequentiell-Platzieren-Button
                    Rectangle {
                        width: 22; height: 22; radius: 3
                        visible: leisteItem.offen
                        color: seqMa.containsMouse ? root.theme.activeItemAlt : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "⇥"; font.pixelSize: 13
                            color: root.theme.accent
                        }
                        ToolTip.visible: seqMa.containsMouse
                        ToolTip.text:    qsTr("Anschlüsse sequentiell platzieren")
                        ToolTip.delay:   400
                        MouseArea {
                            id: seqMa; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var klemmen = db.klemmenFuerLeiste(leisteItem.leisteId)
                                var queue = []
                                for (var i = 0; i < klemmen.length; i++) {
                                    var kl = klemmen[i]
                                    if (!kl.bauteilId || kl.bauteilId <= 0) continue
                                    var anschluesse = db.anschluesseFuerKlemme(kl.bauteilId)
                                    for (var j = 0; j < anschluesse.length; j++) {
                                        var ans = anschluesse[j]
                                        if (!panel.istPlatziert(kl.id, ans.bezeichnung)) {
                                            queue.push({
                                                klemmeId:             kl.id,
                                                bauteilKlemmeId:      kl.bauteilKlemmeId,
                                                anschlussBezeichnung: ans.bezeichnung,
                                                bmk: kl.leisteBmk + ":" + kl.nummer + ":" + ans.bezeichnung
                                            })
                                            break  // nur erster freier Anschluss je Klemme
                                        }
                                    }
                                }
                                if (queue.length > 0)
                                    panel.klemmenSequentiellStarten(JSON.stringify(queue))
                            }
                        }
                    }
                }
            }

            // Klemmen-Liste (lazy geladen)
            Column {
                width: parent.width
                visible: leisteItem.offen
                property var klemmen: panel._klemmenCache[leisteItem.leisteId] || []

                Repeater {
                    model: parent.klemmen
                    delegate: Column {
                        id: klemmeItem
                        width: parent.width
                        property var  kl:          modelData
                        property int  kId:         modelData ? (modelData.id        || -1) : -1
                        property int  bauteilId:   modelData ? (modelData.bauteilId || -1) : -1
                        property bool hatBauteil:  bauteilId > 0
                        property bool klemmeOffen: panel._klemmenAufgeklappt[kId] === true

                        // Klemmen-Zeile
                        Rectangle {
                            id: klemmeZeile
                            width: parent.width; height: 30
                            color: panel._highlightKlemmeId === klemmeItem.kId
                                ? root.theme.activeItem
                                : (klemmeMA.containsMouse && klemmeItem.hatBauteil ? root.theme.hover : "transparent")
                            RowLayout {
                                anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                                spacing: 4
                                Text {
                                    text: klemmeItem.hatBauteil ? (klemmeItem.klemmeOffen ? "▾" : "▸") : " "
                                    font.pixelSize: 9; color: root.theme.textMuted
                                }
                                Text {
                                    text: klemmeItem.kl
                                        ? (klemmeItem.kl.nummer + (klemmeItem.kl.bezeichnung ? "  " + klemmeItem.kl.bezeichnung : ""))
                                        : ""
                                    font.pixelSize: 12
                                    color: klemmeItem.hatBauteil ? root.theme.textSecondary : root.theme.borderDark
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: klemmeMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: klemmeItem.hatBauteil ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: klemmeItem.hatBauteil
                                onClicked: {
                                    var kid = klemmeItem.kId
                                    var bid = klemmeItem.bauteilId
                                    var auf = Object.assign({}, panel._klemmenAufgeklappt)
                                    auf[kid] = !auf[kid]
                                    if (auf[kid] && panel._anschluesseCache[bid] === undefined) {
                                        var c = Object.assign({}, panel._anschluesseCache)
                                        c[bid] = db.anschluesseFuerKlemme(bid)
                                        panel._anschluesseCache = c
                                    }
                                    panel._klemmenAufgeklappt = auf
                                }
                            }
                        }

                        // Anschluesse (lazy geladen)
                        Column {
                            width: parent.width
                            visible: klemmeItem.hatBauteil && klemmeItem.klemmeOffen
                            property var anschluesse: klemmeItem.bauteilId > 0
                                ? (panel._anschluesseCache[klemmeItem.bauteilId] || [])
                                : []
                            property var klemmenDaten: klemmeItem.kl

                            Repeater {
                                model: parent.anschluesse
                                delegate: Rectangle {
                                    width: parent.width; height: 28
                                    property var  ans:       modelData
                                    property var  kd:        parent.klemmenDaten
                                    property bool platziert: kd && ans
                                        ? panel.istPlatziert(kd.id, ans.bezeichnung)
                                        : false
                                    color: platziert
                                        ? "transparent"
                                        : (anschlussMA.containsMouse ? root.theme.activeItem : "transparent")

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 34; rightMargin: 6 }
                                        spacing: 4
                                        Text {
                                            text: "[" + (ans ? ans.bezeichnung : "") + "]"
                                            font.pixelSize: 11
                                            color: platziert ? root.theme.textMuted : root.theme.accent
                                            opacity: platziert ? 0.6 : 1.0
                                        }
                                        Text {
                                            text: ans ? (qsTr("Seite ") + ans.seite + "  Eb." + ans.ebene) : ""
                                            font.pixelSize: 11; color: root.theme.textMuted
                                            opacity: platziert ? 0.5 : 1.0
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            visible: platziert
                                            text: "✓"
                                            font.pixelSize: 11; color: "#60b060"
                                        }
                                        // Sprung-Button: nur wenn platziert
                                        Rectangle {
                                            visible: platziert
                                            implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                            color: sprungMA.containsMouse ? root.theme.accent : "transparent"
                                            Text {
                                                anchors.centerIn: parent
                                                text: "→"
                                                font.pixelSize: 11
                                                color: sprungMA.containsMouse ? "#ffffff" : root.theme.accent
                                            }
                                            MouseArea {
                                                id: sprungMA; anchors.fill: parent; hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!parent.parent.parent.kd || !parent.parent.parent.ans) return
                                                    var _kd  = parent.parent.parent.kd
                                                    var _ans = parent.parent.parent.ans
                                                    var pos  = db.klemmeAnschlussPosition(_kd.id, _ans.bezeichnung)
                                                    if (pos && pos.seiteId > 0)
                                                        panel.sprungAngefordert(pos.seiteId, pos.blattnr,
                                                                               pos.seiteBez, pos.weltX, pos.weltY)
                                                }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: anschlussMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: parent.platziert ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        enabled: !parent.platziert
                                        onClicked: {
                                            if (!parent.kd || !parent.ans) return
                                            var bmk = parent.kd.leisteBmk + ":"
                                                      + parent.kd.nummer   + ":"
                                                      + parent.ans.bezeichnung
                                            panel.klemmenAnschlussPlatzieren(
                                                parent.kd.id,
                                                parent.kd.bauteilKlemmeId,
                                                parent.ans.bezeichnung,
                                                bmk
                                            )
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
