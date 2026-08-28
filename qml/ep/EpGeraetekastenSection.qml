import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling
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

        // Bezeichnung: mehrzeilige Eingabe (BEZEICHNUNG-SHIFT-ENTER-01: Shift+Enter
        // = neue Zeile, Enter allein committet + verlässt das Feld – dieselbe
        // Konvention wie EpTextInhaltSection.qml/EpNotizSection.qml, dort TextEdit
        // statt TextArea, da Keys.onReturnPressed so direkt verfügbar ist).
        Item {
            width: parent.width
            implicitHeight: gkBezLabel.height + gkBezRect.height
            Item {
                id: gkBezLabel
                width: parent.width; height: 20
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("Bezeichnung (Shift + Enter = neue Zeile)"); font.pixelSize: 10; color: root.theme.panelMid
                }
            }
            Rectangle {
                id: gkBezRect
                anchors { top: gkBezLabel.bottom; horizontalCenter: parent.horizontalCenter }
                width: parent.width - 16
                height: Math.max(28, gkBezTe.implicitHeight + 8)
                radius: 3; color: root.theme.inputBg
                border.color: gkBezTe.activeFocus ? root.theme.accent : root.theme.border
                TextEdit {
                    id: gkBezTe
                    anchors { fill: parent; margins: 4 }
                    color: root.theme.textSecondary; font.pixelSize: 11
                    wrapMode: TextEdit.WordWrap
                    text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                    Binding on text {
                        when: !gkBezTe.activeFocus
                        value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                        delayed: true
                    }
                    Keys.onReturnPressed: function(event) {
                        if (event.modifiers & Qt.ShiftModifier) {
                            event.accepted = false
                        } else {
                            root.extraSetzen("bezeichnung", text)
                            focus = false; event.accepted = true
                        }
                    }
                    Keys.onEscapePressed: {
                        text = (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                        focus = false
                    }
                    onEditingFinished: root.extraSetzen("bezeichnung", text)
                }
            }
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

        // ── Textposition (draggable via Canvas, editierbar hier) ──────
        Trennlinie {}
        AbschnittTitel { text: qsTr("TEXTPOSITION") }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Column {
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Versatz X"); color: root.theme.panelMid; font.pixelSize: 10 }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: root.theme.inputBg; border.color: gkOxTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: gkOxTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetX !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetX : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !gkOxTf.activeFocus; value: (gkOxTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetX", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Column {
                spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Versatz Y"); color: root.theme.panelMid; font.pixelSize: 10 }
                Row {
                    spacing: 2
                    Rectangle {
                        width: 52; height: 22; radius: 3
                        color: root.theme.inputBg; border.color: gkOyTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: gkOyTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetY !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetY : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !gkOyTf.activeFocus; value: (gkOyTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetY", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 0
                width: 32; height: 22; radius: 3
                color: gkResetMa.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 12; color: root.theme.textMuted }
                MouseArea {
                    id: gkResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.extraSetzen("bmkOffsetX", 0); root.extraSetzen("bmkOffsetY", 0) }
                }
                ToolTip { visible: gkResetMa.containsMouse; text: qsTr("Textposition zurücksetzen"); delay: 500 }
            }
        }
        Item { height: 4 }

        // ── Weitere Kästen mit gleichem BMK ────────────────
        Loader {
            id: weitereKaestenLoader
            width: root.width
            active: panel.el
                    && panel.el.extraDaten
                    && (panel.el.extraDaten.bmk || "").length > 0
                    && panel.canvas.projektId >= 0
            // Explizite Höhenbindung nötig: Loader.implicitHeight schrumpft nach
            // active:false→true→false nicht zuverlässig zurück (Qt6-Positioner-
            // Quirk, EP-LOADER-HOEHE-01).
            height: active && item ? item.implicitHeight : 0

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
