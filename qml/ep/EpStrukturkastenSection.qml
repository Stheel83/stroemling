import QtQuick
import QtQuick.Controls
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "strukturkasten") ? skCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    function extraMehrSetzen(updates) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        for (var k in updates) ed[k] = updates[k]
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

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
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

    // ── Einbauort-Picker ──────────────────────────────────────
    ListModel { id: skAnlageModel }
    ListModel { id: skOrteModel }

    property var skElRef: panel.el
    onSkElRefChanged: {
        var oid = panel.el && panel.el.extraDaten
                  ? (panel.el.extraDaten.ort_id || -1) : -1
        skSetFromOrtId(oid)
    }

    Component.onCompleted: skRefreshAnlagen()

    function skRefreshAnlagen() {
        skAnlageModel.clear()
        skAnlageModel.append({ itemId: -1, label: qsTr("(keine)") })
        var al = seitenModel.anlagenListe()
        for (var i = 0; i < al.length; i++) skAnlageModel.append(al[i])
    }
    function skRefreshOrte() {
        skOrteModel.clear()
        skOrteModel.append({ itemId: -1, label: qsTr("(kein)") })
        if (skAnlageCombo.currentIndex <= 0 || skAnlageModel.count <= 1) return
        var aId = skAnlageModel.get(skAnlageCombo.currentIndex).itemId
        if (aId < 0) return
        var ol = seitenModel.orteListe(aId)
        for (var i = 0; i < ol.length; i++) skOrteModel.append(ol[i])
    }
    function skApplyOrt() {
        var newOrtId = skOrteCombo.currentIndex > 0
                       ? skOrteModel.get(skOrteCombo.currentIndex).itemId : -1
        var updates = { ort_id: newOrtId > 0 ? newOrtId : null }
        if (newOrtId > 0) {
            var info = seitenModel.ortInfo(newOrtId)
            updates["skAnlage"]   = info.anlageKuerzel || ""
            updates["skOrt"]      = info.ortKuerzel    || ""
            updates["skAnlageUO"] = info.anlageUO      || ""
            updates["skOrtUO"]    = info.ortUO         || ""
        } else {
            updates["skAnlage"]   = ""
            updates["skOrt"]      = ""
            updates["skAnlageUO"] = ""
            updates["skOrtUO"]    = ""
        }
        root.extraMehrSetzen(updates)
    }
    function skSetFromOrtId(oid) {
        skRefreshAnlagen()
        if (oid > 0) {
            for (var ai = 1; ai < skAnlageModel.count; ai++) {
                var aId = skAnlageModel.get(ai).itemId
                var ol = seitenModel.orteListe(aId)
                for (var oi = 0; oi < ol.length; oi++) {
                    if (ol[oi].itemId === oid) {
                        skAnlageCombo.currentIndex = ai
                        skRefreshOrte()
                        for (var ri = 1; ri < skOrteModel.count; ri++) {
                            if (skOrteModel.get(ri).itemId === oid) {
                                skOrteCombo.currentIndex = ri
                                return
                            }
                        }
                        return
                    }
                }
            }
        }
        skAnlageCombo.currentIndex = 0
        skRefreshOrte()
        skOrteCombo.currentIndex = 0
    }

    Connections {
        target: seitenModel
        function onModelReset() { root.skRefreshAnlagen(); root.skRefreshOrte() }
    }

    Column {
        id: skCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("STRUKTURKASTEN") }

        // Bezeichnung: mehrzeilige Eingabe (Zeilenumbruch mit Enter)
        Item {
            width: parent.width
            implicitHeight: skBezLabel.height + skBezRect.height
            Item {
                id: skBezLabel
                width: parent.width; height: 20
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("Bezeichnung"); font.pixelSize: 10; color: root.theme.panelMid
                }
            }
            Rectangle {
                id: skBezRect
                anchors { top: skBezLabel.bottom; horizontalCenter: parent.horizontalCenter }
                width: parent.width - 16
                height: Math.max(28, skBezTa.implicitHeight + 8)
                radius: 3; color: root.theme.inputBg
                border.color: skBezTa.activeFocus ? root.theme.accent : root.theme.border
                TextArea {
                    id: skBezTa
                    anchors { fill: parent; margins: 4 }
                    color: root.theme.textSecondary; font.pixelSize: 11
                    wrapMode: TextArea.Wrap; background: null
                    placeholderText: qsTr("Bezeichnung …")
                    placeholderTextColor: root.theme.textMuted
                    text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                    Binding on text {
                        when: !skBezTa.activeFocus
                        value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                        delayed: true
                    }
                    onFocusChanged: if (!activeFocus) root.extraSetzen("bezeichnung", text)
                    Keys.onEscapePressed: focus = false
                }
            }
        }
        Item { height: 6 }

        // ── Anlage + Ort ──────────────────────────────────────
        Trennlinie {}
        AbschnittTitel { text: qsTr("STRUKTUR") }

        FeldLabel { text: qsTr("Anlage (=)") }
        ComboBox {
            id: skAnlageCombo
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28
            model: skAnlageModel
            textRole: "label"
            onCurrentIndexChanged: root.skRefreshOrte()
            onActivated: { skOrteCombo.currentIndex = 0; root.skApplyOrt() }
            delegate: ItemDelegate {
                required property var model
                text: model.label
                width: parent ? parent.width : 80
                font.pixelSize: 11
            }
            contentItem: Text {
                leftPadding: 8
                text: skAnlageCombo.displayText
                font.pixelSize: 11
                color: root.theme.textSecondary
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: root.theme.inputBg
                border.color: skAnlageCombo.activeFocus ? root.theme.accent : root.theme.border
                radius: 3
            }
        }

        Item { height: 4 }
        FeldLabel { text: qsTr("Ort (+)") }
        ComboBox {
            id: skOrteCombo
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28
            model: skOrteModel
            textRole: "label"
            enabled: skAnlageCombo.currentIndex > 0
            opacity: enabled ? 1.0 : 0.4
            onActivated: root.skApplyOrt()
            delegate: ItemDelegate {
                required property var model
                text: model.label
                width: parent ? parent.width : 80
                font.pixelSize: 11
            }
            contentItem: Text {
                leftPadding: 8
                text: skOrteCombo.displayText
                font.pixelSize: 11
                color: root.theme.textSecondary
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: root.theme.inputBg
                border.color: skOrteCombo.activeFocus ? root.theme.accent : root.theme.border
                radius: 3
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

        // ── Textposition ──────────────────────────────────────────
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
                        color: root.theme.inputBg; border.color: skOxTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: skOxTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetX !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetX : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !skOxTf.activeFocus; value: (skOxTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
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
                        color: root.theme.inputBg; border.color: skOyTf.activeFocus ? root.theme.accent : root.theme.border
                        TextInput {
                            id: skOyTf
                            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                            horizontalAlignment: TextInput.AlignRight
                            color: root.theme.textSecondary; font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: -999; top: 999; decimals: 1; notation: DoubleValidator.StandardNotation }
                            property real weltWert: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bmkOffsetY !== undefined)
                                                    ? panel.el.extraDaten.bmkOffsetY : 0
                            text: (weltWert / panel.canvas.mmToPx).toFixed(1)
                            Binding on text { when: !skOyTf.activeFocus; value: (skOyTf.weltWert / panel.canvas.mmToPx).toFixed(1); delayed: true }
                            onEditingFinished: { var v = parseFloat(text.replace(",",".")); if (!isNaN(v)) root.extraSetzen("bmkOffsetY", v * panel.canvas.mmToPx) }
                            Keys.onEscapePressed: focus = false
                        }
                    }
                    Text { text: "mm"; color: root.theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: 32; height: 22; radius: 3
                color: skResetMa.containsMouse ? root.theme.hover : "transparent"
                border.color: root.theme.border
                Text { anchors.centerIn: parent; text: "↺"; font.pixelSize: 12; color: root.theme.textMuted }
                MouseArea {
                    id: skResetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.extraSetzen("bmkOffsetX", 0); root.extraSetzen("bmkOffsetY", 0) }
                }
                ToolTip { visible: skResetMa.containsMouse; text: qsTr("Textposition zurücksetzen"); delay: 500 }
            }
        }
        Item { height: 4 }
    }
}
