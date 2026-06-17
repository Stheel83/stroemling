import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "geraetekasten") ? gkCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
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

    component SchriftgrosseSelektor: Item {
        id: sgRoot
        property real wert: 2.5
        signal wertGeaendert(real neuerWert)

        readonly property var schritte: [1.5, 2.0, 2.5, 3.5, 5.0, 7.0, 10.0, 15.0, 20.0, 30.0, 40.0]
        readonly property int aktIdx: {
            var best = 0, bestD = 9999
            for (var i = 0; i < schritte.length; i++) {
                var d = Math.abs(schritte[i] - wert)
                if (d < bestD) { bestD = d; best = i }
            }
            return best
        }

        width: root.width; height: 32

        Row {
            anchors.centerIn: parent; spacing: 6
            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgKlMa.containsMouse ? root.theme.border : root.theme.inputBg
                border.color: sgRoot.aktIdx > 0 ? root.theme.border : root.theme.divider
                Text { anchors.centerIn: parent; text: "◄"; font.pixelSize: 11
                       color: sgRoot.aktIdx > 0 ? root.theme.accent : root.theme.borderDark }
                MouseArea { id: sgKlMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; enabled: sgRoot.aktIdx > 0
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx - 1]) }
            }
            Rectangle {
                width: 60; height: 28; radius: 4
                color: root.theme.inputBg; border.color: root.theme.border
                Text { anchors.centerIn: parent; color: root.theme.textSecondary; font.pixelSize: 11
                       text: sgRoot.wert.toFixed(1) + " mm" }
            }
            Rectangle {
                width: 28; height: 28; radius: 4
                color: sgGrMa.containsMouse ? root.theme.border : root.theme.inputBg
                border.color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? root.theme.border : root.theme.divider
                Text { anchors.centerIn: parent; text: "►"; font.pixelSize: 11
                       color: sgRoot.aktIdx < sgRoot.schritte.length - 1 ? root.theme.accent : root.theme.borderDark }
                MouseArea { id: sgGrMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: sgRoot.aktIdx < sgRoot.schritte.length - 1
                    onClicked: sgRoot.wertGeaendert(sgRoot.schritte[sgRoot.aktIdx + 1]) }
            }
        }
    }

    property bool _ghExpanded: false

    Column {
        id: gkCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("GERÄTEKASTEN") }

        InputField {
            label: qsTr("BMK")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bmk || "") : ""
            theme: root.theme
            onCommit: function(t) {
                var kz = t.trim()
                if (kz !== "" && !kz.startsWith("-")) kz = "-" + kz
                root.extraSetzen("bmk", kz)
            }
        }
        Item { height: 6 }

        InputField {
            label: qsTr("Bezeichnung")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
            theme: root.theme
            onCommit: function(t) { root.extraSetzen("bezeichnung", t.trim()) }
        }
        Item { height: 6 }

        Trennlinie {}
        AbschnittTitel { text: qsTr("SCHRIFTGRÖSSE") }
        SchriftgrosseSelektor {
            wert: (panel.el && panel.el.extraDaten
                   && panel.el.extraDaten.schriftgroesse !== undefined)
                  ? panel.el.extraDaten.schriftgroesse : 2.5
            onWertGeaendert: function(v) { root.extraSetzen("schriftgroesse", v) }
        }
        Item { height: 4 }

        // ── Gehäusedaten (einklappbar) ─────────────────────
        Trennlinie {}
        Item {
            width: parent.width; height: 26
            Rectangle {
                anchors.fill: parent
                color: ghHdrMa.containsMouse ? root.theme.hover : "transparent"
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 4
                Text {
                    text: qsTr("GEHÄUSEDATEN")
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                    color: root.theme.borderLight; Layout.fillWidth: true
                }
                Text {
                    text: root._ghExpanded ? "▾" : "▸"
                    font.pixelSize: 11; color: root.theme.borderLight
                }
            }
            MouseArea {
                id: ghHdrMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._ghExpanded = !root._ghExpanded
            }
        }

        Item {
            width: parent.width
            height: root._ghExpanded ? ghInhaltCol.implicitHeight : 0
            clip: true
            Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            Column {
                id: ghInhaltCol
                width: parent.width; spacing: 0

                InputField {
                    label: qsTr("Hersteller")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_hersteller || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_hersteller", t.trim()) }
                }
                Item { height: 4 }
                InputField {
                    label: qsTr("Typ / Bezeichnung")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_typ || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_typ", t.trim()) }
                }
                Item { height: 4 }
                InputField {
                    label: qsTr("Polzahl")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_polzahl || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_polzahl", t.trim()) }
                }
                Item { height: 4 }
                InputField {
                    label: qsTr("IP gesteckt")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_ip_gesteckt || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_ip_gesteckt", t.trim()) }
                }
                Item { height: 4 }
                InputField {
                    label: qsTr("IP getrennt")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_ip_getrennt || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_ip_getrennt", t.trim()) }
                }
                Item { height: 4 }
                InputField {
                    label: qsTr("Kodierung")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_kodierung || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_kodierung", t.trim()) }
                }
                Item { height: 4 }
                InputField {
                    label: qsTr("Verriegelung")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_verriegelung || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_verriegelung", t.trim()) }
                }
                Item { height: 6 }

                // Geschirmt – Ja/Nein Toggle
                Item {
                    width: parent.width; height: 48
                    property bool _geschirmt: (panel.el && panel.el.extraDaten)
                                              ? (panel.el.extraDaten.gh_geschirmt === true) : false
                    Text {
                        anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 4 }
                        text: qsTr("Geschirmt"); font.pixelSize: 10; color: root.theme.panelMid
                    }
                    Row {
                        anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 4 }
                        spacing: 4
                        Repeater {
                            model: [{ label: qsTr("Nein"), val: false }, { label: qsTr("Ja"), val: true }]
                            delegate: Rectangle {
                                width: 52; height: 24; radius: 3
                                property bool _aktiv: parent.parent.parent._geschirmt === modelData.val
                                      && (panel.el && panel.el.extraDaten
                                          && panel.el.extraDaten.gh_geschirmt !== undefined)
                                color: _aktiv ? root.theme.accent : root.theme.inputBg
                                border.color: _aktiv ? root.theme.accent : root.theme.border
                                Text {
                                    anchors.centerIn: parent; text: modelData.label
                                    font.pixelSize: 11
                                    color: parent._aktiv ? "#ffffff" : root.theme.textSecondary
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.extraSetzen("gh_geschirmt", modelData.val)
                                }
                            }
                        }
                    }
                }

                Item { height: 4 }
                InputField {
                    label: qsTr("Datenblatt-URL")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_datenblatt || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_datenblatt", t.trim()) }
                }
                Item { height: 4 }
                InputField {
                    label: qsTr("Notiz")
                    value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.gh_notiz || "") : ""
                    theme: root.theme
                    onCommit: function(t) { root.extraSetzen("gh_notiz", t.trim()) }
                }
                Item { height: 6 }
            }
        }

        // ── Weitere Kästen mit gleichem BMK ────────────────
        Loader {
            id: weitereKaestenLoader
            width: root.width
            active: panel.el
                    && panel.el.extraDaten
                    && (panel.el.extraDaten.bmk || "").length > 0
                    && panel.canvas.projektId >= 0

            sourceComponent: Component {
                Column {
                    width: root.width; spacing: 0

                    property string _bmk: (panel.el && panel.el.extraDaten)
                                          ? (panel.el.extraDaten.bmk || "") : ""
                    property int _projektId: panel.canvas.projektId

                    property var _weitereKaesten: {
                        if (_bmk === "" || _projektId < 0) return []
                        return db.geraetekastenNachBmk(_projektId, _bmk)
                    }

                    Trennlinie {}
                    AbschnittTitel { text: qsTr("WEITERE KÄSTEN") }

                    Rectangle {
                        width: root.width; height: 28; color: "transparent"
                        visible: parent._weitereKaesten.length <= 1
                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: qsTr("Nur dieser Kasten mit BMK ") + parent._bmk
                            font.pixelSize: 10; color: root.theme.textMuted; font.italic: true
                        }
                    }

                    Repeater {
                        model: parent._weitereKaesten
                        delegate: Rectangle {
                            width: root.width; height: 28
                            color: weitHover.containsMouse ? root.theme.hover : "transparent"
                            property var gkd: modelData

                            MouseArea {
                                id: weitHover; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.ArrowCursor
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                                spacing: 4
                                Text {
                                    text: "↳"; font.pixelSize: 11; color: root.theme.borderLight
                                }
                                Text {
                                    text: (gkd.blattnr || "") + (gkd.seiteBez ? ": " + gkd.seiteBez : "")
                                    font.pixelSize: 11; color: root.theme.textSecondary
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Rectangle {
                                    width: 20; height: 20; radius: 3
                                    color: gkEpSprungMA.containsMouse ? root.theme.accent : "transparent"
                                    Text {
                                        anchors.centerIn: parent; text: "→"; font.pixelSize: 11
                                        color: gkEpSprungMA.containsMouse ? "#ffffff" : root.theme.accent
                                    }
                                    MouseArea {
                                        id: gkEpSprungMA; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var d = gkd
                                            if (d && d.seiteId > 0)
                                                panel.canvas.gkSprungAngefordert(
                                                    d.seiteId, d.blattnr,
                                                    d.seiteBez, d.weltX, d.weltY)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item { height: 4 }
                }
            }
        }
    }
}
