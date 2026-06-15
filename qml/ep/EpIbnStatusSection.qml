import QtQuick
import "../components"
import "../SymbolKlassen.js" as SK

Item {
    id: root

    required property var panel
    required property var theme

    width:  parent ? parent.width : 0
    height: visible ? col.implicitHeight : 0
    visible: _ibnDaten && Object.keys(_ibnDaten).length > 0

    readonly property string _bmk: (panel.el && panel.el.extraDaten)
                                    ? (panel.el.extraDaten.bmk || "") : ""

    readonly property bool _istSymbolMitBmk: {
        var el = panel.el
        if (!el || el.typ !== "symbol") return false
        var sid = el.symbolId || ""
        if (SK.istVerbHelper(sid)) return false
        return _bmk !== ""
    }

    readonly property var _ibnDaten: {
        if (!_istSymbolMitBmk) return null
        return db.ibnEintragFuerBmk(panel.seiteId, _bmk)
    }

    readonly property string _status: _ibnDaten ? (_ibnDaten.status || "offen") : "offen"

    readonly property color _statusFarbe: {
        if (_status === "abgeschlossen") return "#30c060"
        if (_status === "in_arbeit")     return "#d09020"
        return root.theme.borderLight
    }

    readonly property string _statusLabel: {
        if (_status === "abgeschlossen") return qsTr("Abgeschlossen")
        if (_status === "in_arbeit")     return qsTr("In Arbeit")
        return qsTr("Offen")
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

    Column {
        id: col
        width: parent.width

        Trennlinie {}
        AbschnittTitel { text: qsTr("INBETRIEBNAHME") }

        // ── Status-Badge ─────────────────────────────────
        Item {
            width: parent.width; height: 30
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Status:")
                    font.pixelSize: 10; color: root.theme.panelMid
                }
                Rectangle {
                    height: 18; radius: 3; width: badgeText.implicitWidth + 12
                    color: Qt.rgba(root._statusFarbe.r, root._statusFarbe.g,
                                   root._statusFarbe.b, 0.18)
                    border.color: root._statusFarbe
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root._statusLabel
                        font.pixelSize: 10; color: root._statusFarbe
                    }
                }
            }
        }

        // ── Bauteil-ID ───────────────────────────────────
        Item {
            width: parent.width
            height: _bauteilId !== "" ? 22 : 0
            visible: height > 0
            readonly property string _bauteilId:
                root._ibnDaten ? (root._ibnDaten.bauteilId || "") : ""
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 6
                Text { text: qsTr("Bauteil-ID:"); font.pixelSize: 10; color: root.theme.panelMid }
                Text { text: parent.parent._bauteilId; font.pixelSize: 10
                       color: root.theme.textSecondary; font.family: "monospace" }
            }
        }

        // ── Geprüft von / am ─────────────────────────────
        Item {
            width: parent.width
            height: _geprueftText !== "" ? 22 : 0
            visible: height > 0
            readonly property string _geprueftText: {
                var von = root._ibnDaten ? (root._ibnDaten.geprueftVon || "") : ""
                var am  = root._ibnDaten ? (root._ibnDaten.geprueftAm  || "") : ""
                if (von && am)  return von + " · " + am
                if (von)        return von
                if (am)         return am
                return ""
            }
            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 6
                Text { text: qsTr("Geprüft:"); font.pixelSize: 10; color: root.theme.panelMid }
                Text { text: parent.parent._geprueftText; font.pixelSize: 10
                       color: root.theme.textSecondary }
            }
        }

        // ── Notiz ────────────────────────────────────────
        Item {
            width: parent.width
            height: _notiz !== "" ? notizText.implicitHeight + 10 : 0
            visible: height > 0
            readonly property string _notiz:
                root._ibnDaten ? (root._ibnDaten.notiz || "") : ""
            Row {
                anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 5 }
                spacing: 6
                Text { text: qsTr("Notiz:"); font.pixelSize: 10; color: root.theme.panelMid
                       topPadding: 1 }
                Text {
                    id: notizText
                    width: root.width - 80
                    text: parent.parent._notiz
                    font.pixelSize: 10; color: root.theme.textSecondary
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ── Messwerte ────────────────────────────────────
        Repeater {
            model: {
                if (!root._ibnDaten) return []
                var felder = root._ibnDaten.felder || []
                return felder.filter(function(f) { return (f.wert || "") !== "" })
            }
            Item {
                width: col.width; height: 22
                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Text {
                        text: (modelData.feldname || "") + ":"
                        font.pixelSize: 10; color: root.theme.panelMid
                    }
                    Text {
                        text: modelData.wert || ""
                        font.pixelSize: 10; color: root.theme.textSecondary
                    }
                }
            }
        }

        Item { height: 6 }
    }
}
