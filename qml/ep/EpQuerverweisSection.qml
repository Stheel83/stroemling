import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "symbol"
              && panel.el.symbolId === "querverweis")
             ? qvCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    property var qvPartner: {
        if (!panel.el || panel.el.typ !== "symbol" || panel.el.symbolId !== "querverweis") return null
        var sn = (panel.el.extraDaten && panel.el.extraDaten.signalname) || ""
        if (!sn || canvas.projektId < 0) return null
        var alle = db.querverweiseLadenProjekt(canvas.projektId)
        for (var k = 0; k < alle.length; k++) {
            var qv = alle[k]
            if (qv.signalname !== sn) continue
            if (qv.seiteId === canvas.seiteId && panel.el
                && Math.abs(qv.x1 - panel.el.x1) < 0.5
                && Math.abs(qv.y1 - panel.el.y1) < 0.5) continue
            return qv
        }
        return null
    }

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    Column {
        id: qvCol
        width: parent.width
        spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("QUERVERWEIS") }

        InputField {
            label: qsTr("Signalname")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.signalname || "") : ""
            theme: theme
            onCommit: function(t) { root.extraSetzen("signalname", t.trim()) }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Suchmodus") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: theme;
                label: qsTr("Signalname")
                aktiv: !panel.el || !panel.el.extraDaten
                       || !panel.el.extraDaten.suchmodus
                       || panel.el.extraDaten.suchmodus === "signal"
                breite: 84
                onKlick: root.extraSetzen("suchmodus", "signal")
            }
            MiniButton { theme: theme;
                label: qsTr("mit BMK")
                aktiv: panel.el && panel.el.extraDaten
                       && panel.el.extraDaten.suchmodus === "bmk"
                breite: 84
                onKlick: root.extraSetzen("suchmodus", "bmk")
            }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Rolle") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: theme;
                label: qsTr("→ Ausgang")
                aktiv:  !panel.el || !panel.el.extraDaten
                        || (panel.el.extraDaten.richtung || "ausgang") === "ausgang"
                breite: 84
                onKlick: root.extraSetzen("richtung", "ausgang")
            }
            MiniButton { theme: theme;
                label: qsTr("Eingang ←")
                aktiv:  panel.el && panel.el.extraDaten
                        && panel.el.extraDaten.richtung === "eingang"
                breite: 84
                onKlick: root.extraSetzen("richtung", "eingang")
            }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Pfeilrichtung") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3
            Repeater {
                model: [
                    { label: qsTr("→"), rot: 0   },
                    { label: qsTr("↓"), rot: 90  },
                    { label: qsTr("←"), rot: 180 },
                    { label: qsTr("↑"), rot: 270 }
                ]
                delegate: MiniButton { theme: theme;
                    label:  modelData.label
                    aktiv:  panel.s("rotation", 0) === modelData.rot
                    breite: 36
                    onKlick: canvas.eigenschaftAktualisieren("rotation", modelData.rot)
                }
            }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Gegenseite") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Text {
                width: 128
                text: root.qvPartner
                      ? (root.qvPartner.blattnummer
                         + (root.qvPartner.seitenBezeichnung
                            ? " " + root.qvPartner.seitenBezeichnung : ""))
                      : qsTr("– keine Gegenstelle –")
                color: root.qvPartner ? theme.accent : theme.textSecondary
                font.pixelSize: 11
                font.bold: root.qvPartner !== null
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                height: 22
            }
            MiniButton { theme: theme;
                visible: root.qvPartner !== null
                label: qsTr("→ (F)")
                breite: 48
                onKlick: canvas.querverweisZurGegenseiteNavigieren()
            }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Verbinden mit") }
        Item {
            id: qvDropItem
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28

            property var offeneQv: {
                var liste   = [{ label: qsTr("– auswählen –"), sn: "" }]
                var curEl   = panel.el
                var curSid  = canvas.seiteId
                var curMode = (curEl && curEl.extraDaten && curEl.extraDaten.suchmodus)
                              || "signal"
                var alle    = canvas.projektId >= 0
                              ? db.querverweiseLadenProjekt(canvas.projektId)
                              : []

                var filterAnlage = "", filterOrt = ""
                if (curMode === "bmk" && curEl) {
                    var nd   = canvas.normblattDaten
                    var sk   = panel.strukturkastenFuer(curEl)
                    filterAnlage = sk && sk.anlage ? sk.anlage
                                  : (nd ? nd.anlageKuerzel || "" : "")
                    filterOrt    = sk && sk.ort    ? sk.ort
                                  : (nd ? nd.ortKuerzel    || "" : "")
                }

                for (var k = 0; k < alle.length; k++) {
                    var qv = alle[k]
                    if (qv.seiteId === curSid && curEl
                            && Math.abs(qv.x1 - curEl.x1) < 0.5
                            && Math.abs(qv.y1 - curEl.y1) < 0.5) continue
                    if (curMode === "bmk") {
                        if ((qv.anlageKuerzel || "") !== filterAnlage) continue
                        if ((qv.ortKuerzel    || "") !== filterOrt)    continue
                    }
                    var rich  = qv.richtung || "ausgang"
                    var sn    = qv.signalname || ""
                    var pfeil = (rich === "ausgang") ? "→" : "←"
                    var seite = qv.blattnummer
                                + (qv.seitenBezeichnung ? " " + qv.seitenBezeichnung : "")
                    var bez   = pfeil + " " + (sn !== "" ? sn : "(kein Name)")
                                + "  —  " + seite
                    liste.push({ label: bez, sn: sn })
                }
                return liste
            }

            ComboBox {
                id: qvVerbindenBox
                anchors.fill: parent
                model: parent.offeneQv.map(function(e) { return e.label })
                currentIndex: 0

                Connections {
                    target: panel
                    function onElChanged() { qvVerbindenBox.currentIndex = 0 }
                }

                onActivated: function(idx) {
                    if (idx <= 0) return
                    var sn = qvDropItem.offeneQv[idx].sn
                    if (sn !== "") root.extraSetzen("signalname", sn)
                    currentIndex = 0
                }

                background: Rectangle {
                    color: theme.inputBg; radius: 3
                    border.color: qvVerbindenBox.pressed ? theme.accent : theme.border
                }
                contentItem: Text {
                    leftPadding: 6
                    text: qvVerbindenBox.displayText
                    color: theme.textSecondary; font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                delegate: Rectangle {
                    width: qvVerbindenBox.width
                    height: 24
                    color: qvVerbindenBox.highlightedIndex === index
                           ? theme.activeItemAlt : theme.inputBg
                    Text {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                        text: modelData
                        color: theme.textSecondary
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: qvVerbindenBox.highlightedIndex = index
                        onExited:  qvVerbindenBox.highlightedIndex = -1
                        onClicked: {
                            qvVerbindenBox.currentIndex = index
                            qvVerbindenBox.activated(index)
                            qvVerbindenBox.popup.close()
                        }
                    }
                }
                popup: Popup {
                    y: qvVerbindenBox.height
                    width: qvVerbindenBox.width
                    padding: 0
                    contentItem: ListView {
                        implicitHeight: Math.min(contentHeight, 200)
                        model: qvVerbindenBox.delegateModel
                        clip: true
                        ScrollBar.vertical: ScrollBar {}
                    }
                    background: Rectangle {
                        color: theme.inputBg
                        border.color: theme.border; radius: 3
                    }
                }
            }
        }
        Item { height: 6 }
    }
}
