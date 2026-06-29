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

    property bool _ghExpanded: false

    // ── Anlage+Ort-Picker (gleicher ListModel-Ansatz wie KR-Editor) ──
    ListModel { id: gkAnlageModel }
    ListModel { id: gkOrteModel }

    property var _elRef: panel.el
    onElRefChanged: {
        var oid = panel.el && panel.el.extraDaten
                  ? (panel.el.extraDaten.ort_id || -1) : -1
        gkSetFromOrtId(oid)
    }

    Component.onCompleted: gkRefreshAnlagen()

    function gkRefreshAnlagen() {
        gkAnlageModel.clear()
        gkAnlageModel.append({itemId: -1, label: qsTr("(keine)")})
        var al = seitenModel.anlagenListe()
        for (var i = 0; i < al.length; i++) gkAnlageModel.append(al[i])
    }
    function gkRefreshOrte() {
        gkOrteModel.clear()
        gkOrteModel.append({itemId: -1, label: qsTr("(kein)")})
        if (gkAnlageCombo.currentIndex <= 0 || gkAnlageModel.count <= 1) return
        var aId = gkAnlageModel.get(gkAnlageCombo.currentIndex).itemId
        if (aId < 0) return
        var ol = seitenModel.orteListe(aId)
        for (var i = 0; i < ol.length; i++) gkOrteModel.append(ol[i])
    }
    function gkApplyOrt() {
        var newOrtId = gkOrteCombo.currentIndex > 0
                       ? gkOrteModel.get(gkOrteCombo.currentIndex).itemId : -1
        root.extraSetzen("ort_id", newOrtId > 0 ? newOrtId : null)
    }
    function gkSetFromOrtId(oid) {
        gkRefreshAnlagen()
        var anlageIdx = 0
        if (oid > 0) {
            for (var k = 1; k < gkAnlageModel.count; k++) {
                var lo = seitenModel.orteListe(gkAnlageModel.get(k).itemId)
                for (var m = 0; m < lo.length; m++) {
                    if (lo[m].itemId === oid) { anlageIdx = k; break }
                }
                if (anlageIdx > 0) break
            }
        }
        gkAnlageCombo.currentIndex = anlageIdx  // löst gkRefreshOrte() via onCurrentIndexChanged aus
        var ortIdx = 0
        if (oid > 0) {
            for (var i = 1; i < gkOrteModel.count; i++) {
                if (gkOrteModel.get(i).itemId === oid) { ortIdx = i; break }
            }
        }
        gkOrteCombo.currentIndex = ortIdx
    }

    Connections {
        target: seitenModel
        function onModelReset() { root.gkRefreshAnlagen(); root.gkRefreshOrte() }
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

        // Bezeichnung: mehrzeilige Eingabe (Zeilenumbruch mit Enter)
        Item {
            width: parent.width
            implicitHeight: gkBezLabel.height + gkBezRect.height
            Item {
                id: gkBezLabel
                width: parent.width; height: 20
                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: qsTr("Bezeichnung"); font.pixelSize: 10; color: root.theme.panelMid
                }
            }
            Rectangle {
                id: gkBezRect
                anchors { top: gkBezLabel.bottom; horizontalCenter: parent.horizontalCenter }
                width: parent.width - 16
                height: Math.max(28, gkBezTa.implicitHeight + 8)
                radius: 3; color: root.theme.inputBg
                border.color: gkBezTa.activeFocus ? root.theme.accent : root.theme.border
                TextArea {
                    id: gkBezTa
                    anchors { fill: parent; margins: 4 }
                    color: root.theme.textSecondary; font.pixelSize: 11
                    wrapMode: TextArea.Wrap; background: null
                    placeholderText: qsTr("Bezeichnung …")
                    placeholderTextColor: root.theme.textMuted
                    text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                    Binding on text {
                        when: !gkBezTa.activeFocus
                        value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
                        delayed: true
                    }
                    onFocusChanged: if (!activeFocus) root.extraSetzen("bezeichnung", text)
                    Keys.onEscapePressed: focus = false
                }
            }
        }
        Item { height: 6 }

        Trennlinie {}
        AbschnittTitel { text: qsTr("EINBAUORT") }

        Item {
            width: parent.width; height: 28
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 6
                Text { text: qsTr("Anlage:"); font.pixelSize: 10; color: root.theme.panelMid; Layout.preferredWidth: 60 }
                ComboBox {
                    id: gkAnlageCombo
                    Layout.fillWidth: true; font.pixelSize: 11
                    model: gkAnlageModel; textRole: "label"; currentIndex: 0
                    contentItem: Text { text: gkAnlageCombo.displayText; font: gkAnlageCombo.font
                        color: root.theme.textSecondary; verticalAlignment: Text.AlignVCenter; leftPadding: 6 }
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate {
                        required property var model
                        width: gkAnlageCombo.width
                        contentItem: Text { text: model.label; color: root.theme.textPrimary; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.sidebar }
                    }
                    onCurrentIndexChanged: root.gkRefreshOrte()
                    onActivated: { gkOrteCombo.currentIndex = 0; root.gkApplyOrt() }
                }
            }
        }

        Item {
            width: parent.width; height: 28
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 6
                Text { text: qsTr("Ort:"); font.pixelSize: 10; color: root.theme.panelMid; Layout.preferredWidth: 60 }
                ComboBox {
                    id: gkOrteCombo
                    Layout.fillWidth: true; font.pixelSize: 11
                    enabled: gkAnlageCombo.currentIndex > 0
                    opacity: enabled ? 1.0 : 0.4
                    model: gkOrteModel; textRole: "label"; currentIndex: 0
                    contentItem: Text { text: gkOrteCombo.displayText; font: gkOrteCombo.font
                        color: root.theme.textSecondary; verticalAlignment: Text.AlignVCenter; leftPadding: 6 }
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; border.width: 1; radius: 3 }
                    popup.background: Rectangle { color: root.theme.sidebar; border.color: root.theme.border; border.width: 1; radius: 4 }
                    delegate: ItemDelegate {
                        required property var model
                        width: gkOrteCombo.width
                        contentItem: Text { text: model.label; color: root.theme.textPrimary; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.sidebar }
                    }
                    onActivated: root.gkApplyOrt()
                }
            }
        }

        Item { height: 4 }

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

        // ── Gehäusedaten (read-only, verknüpftes Bauteil) ──────
        Trennlinie {}

        // Picker-Popup für Bauteil-Auswahl
        Popup {
            id: svPicker
            modal: true; focus: true
            parent: Overlay.overlay
            width: 360; height: Math.min(svPickerListe.count * 46 + 96, 380)
            anchors.centerIn: parent
            padding: 0
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            background: Rectangle {
                color: root.theme.sidebar; radius: 6
                border.color: root.theme.border; border.width: 1
            }

            property var _liste: []

            onOpened: _liste = db.steckverbinderBausteineListe()

            Column {
                width: parent.width; spacing: 0

                Rectangle {
                    width: parent.width; height: 44; color: root.theme.surface
                    radius: 6
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.theme.border }
                    Text {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        text: qsTr("Steckverbinder verknüpfen")
                        font.pixelSize: 13; font.weight: Font.Medium; color: root.theme.textPrimary
                    }
                    Rectangle {
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        width: 28; height: 28; radius: 4
                        color: svPickerSchliessen.containsMouse ? root.theme.hover : "transparent"
                        Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 16; color: root.theme.textMuted }
                        MouseArea { id: svPickerSchliessen; anchors.fill: parent; hoverEnabled: true; onClicked: svPicker.close() }
                    }
                }

                Text {
                    visible: svPicker._liste.length === 0
                    width: parent.width; height: 60
                    text: qsTr("Keine Steckverbinder in der Bibliothek.\nIm BAUTEILE-Panel unter Steckverbinder anlegen.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                }

                ScrollView {
                    width: parent.width
                    height: Math.min(svPicker._liste.length * 46, 280)
                    clip: true

                    ListView {
                        id: svPickerListe
                        model: svPicker._liste
                        delegate: Rectangle {
                            width: svPickerListe.width; height: 46
                            color: svPkH.containsMouse ? root.theme.hover : "transparent"
                            MouseArea {
                                id: svPkH; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.extraSetzen("bauteil_id", modelData.id)
                                    svPicker.close()
                                }
                            }
                            Column {
                                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text { text: modelData.bezeichnung; font.pixelSize: 12; color: root.theme.textPrimary }
                                Text {
                                    text: [modelData.hersteller,
                                           modelData.polzahl > 0 ? modelData.polzahl + "-polig" : ""].filter(Boolean).join(" · ")
                                    font.pixelSize: 10; color: root.theme.textMuted
                                }
                            }
                        }
                    }
                }
            }
        }

        // Steckverbinder-Editor (in-place, kein Navigations-Wechsel nötig)
        BaSteckverbinderEditorDialog {
            id: dlgSvEditor
            theme: root.theme
        }

        Item {
            id: ghSection
            width: parent.width
            property int _bauteilId: (panel.el && panel.el.extraDaten && panel.el.extraDaten.bauteil_id > 0)
                                     ? panel.el.extraDaten.bauteil_id : -1
            property var  _bauteil:  _bauteilId > 0 ? bauteilModel.bauteilNachId(_bauteilId) : ({})
            property var  _svTyp:    _bauteilId > 0 ? db.steckverbinderTypLaden(_bauteilId) : ({})

            height: ghSectionCol.implicitHeight
            clip: false

            Column {
                id: ghSectionCol
                width: parent.width; spacing: 0

                // Header
                Item {
                    width: parent.width; height: 26
                    Rectangle { anchors.fill: parent; color: ghHdrMa.containsMouse ? root.theme.hover : "transparent" }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                        spacing: 4
                        Text {
                            text: qsTr("GEHÄUSEDATEN")
                            font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                            color: root.theme.borderLight; Layout.fillWidth: true
                        }
                        // Aufheben-Button (nur wenn verknüpft)
                        Rectangle {
                            visible: ghSection._bauteilId > 0
                            width: 18; height: 18; radius: 3
                            color: ghAufhebenMa.containsMouse ? "#662222" : "transparent"
                            Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 13
                                   color: parent.color !== "transparent" ? "#ffffff" : root.theme.borderDark }
                            MouseArea {
                                id: ghAufhebenMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.extraSetzen("bauteil_id", 0)
                            }
                        }
                        Text {
                            text: root._ghExpanded ? "▾" : "▸"
                            font.pixelSize: 11; color: root.theme.borderLight
                        }
                    }
                    MouseArea {
                        id: ghHdrMa; anchors.fill: parent; hoverEnabled: true; z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._ghExpanded = !root._ghExpanded
                    }
                }

                // Einklappbarer Inhalt
                Item {
                    width: parent.width
                    height: root._ghExpanded ? ghInhaltCol.implicitHeight : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Column {
                        id: ghInhaltCol
                        width: parent.width; spacing: 0

                        // Kein Bauteil verknüpft
                        Item {
                            visible: ghSection._bauteilId < 0
                            width: parent.width; height: 52

                            Text {
                                anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 6 }
                                text: qsTr("Kein Bauteil verknüpft")
                                font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                            }
                            Rectangle {
                                anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 6 }
                                height: 26; width: 110; radius: 4
                                color: svVerknuepfenMa.containsMouse ? root.theme.accent : root.theme.inputBg
                                border.color: root.theme.accent
                                Text { anchors.centerIn: parent; text: qsTr("Verknüpfen …")
                                       font.pixelSize: 11
                                       color: svVerknuepfenMa.containsMouse ? "#ffffff" : root.theme.accent }
                                MouseArea {
                                    id: svVerknuepfenMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: svPicker.open()
                                }
                            }
                        }

                        // Read-only Anzeige wenn Bauteil verknüpft
                        Column {
                            visible: ghSection._bauteilId >= 0
                            width: parent.width; spacing: 0

                            component InfoZeile: Item {
                                property string label: ""
                                property string wert:  ""
                                width: parent ? parent.width : 0
                                height: wert.length > 0 ? 20 : 0; clip: true; visible: height > 0
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                                    spacing: 6
                                    Text { text: label; font.pixelSize: 10; color: root.theme.textMuted; Layout.preferredWidth: 80 }
                                    Text { text: wert;  font.pixelSize: 11; color: root.theme.textSecondary; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                            }

                            Item { height: 4 }
                            InfoZeile { label: qsTr("Bezeichnung"); wert: ghSection._bauteil.bezeichnung   || "" }
                            InfoZeile { label: qsTr("Hersteller");  wert: ghSection._bauteil.hersteller    || "" }
                            InfoZeile { label: qsTr("Artikel-Nr."); wert: ghSection._bauteil.artikelnummer || "" }
                            InfoZeile {
                                label: qsTr("Polzahl")
                                wert: ghSection._svTyp.polzahl > 0 ? ghSection._svTyp.polzahl.toString() : ""
                            }
                            InfoZeile { label: qsTr("IP gesteckt"); wert: ghSection._svTyp.ipGesteckt  || "" }
                            InfoZeile { label: qsTr("IP getrennt"); wert: ghSection._svTyp.ipGetrennt  || "" }
                            InfoZeile { label: qsTr("Kodierung");   wert: ghSection._svTyp.kodierung   || "" }
                            InfoZeile { label: qsTr("Verriegelung");wert: ghSection._svTyp.verriegelung|| "" }
                            InfoZeile {
                                label: qsTr("Geschirmt")
                                wert: {
                                    if (ghSection._svTyp.geschirmt === undefined) return ""
                                    return ghSection._svTyp.geschirmt ? qsTr("Ja") : qsTr("Nein")
                                }
                            }
                            Item { height: 4 }

                            // Buttons: Verknüpfen / Im Editor öffnen
                            Item {
                                width: parent.width; height: 34
                                Row {
                                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    spacing: 6
                                    Rectangle {
                                        height: 24; width: 90; radius: 4
                                        color: svAendernMa.containsMouse ? root.theme.hover : "transparent"
                                        border.color: root.theme.border
                                        Text { anchors.centerIn: parent; text: qsTr("Anderes …")
                                               font.pixelSize: 10; color: root.theme.textSecondary }
                                        MouseArea {
                                            id: svAendernMa; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: svPicker.open()
                                        }
                                    }
                                    Rectangle {
                                        height: 24; width: 110; radius: 4
                                        color: svEditorMa.containsMouse ? root.theme.accent : "transparent"
                                        border.color: root.theme.accent
                                        Text { anchors.centerIn: parent; text: qsTr("Im Editor öffnen →")
                                               font.pixelSize: 10
                                               color: svEditorMa.containsMouse ? "#ffffff" : root.theme.accent }
                                        MouseArea {
                                            id: svEditorMa; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                dlgSvEditor.bauteilId   = ghSection._bauteilId
                                                dlgSvEditor.bezeichnung = ghSection._bauteil.bezeichnung || ""
                                                dlgSvEditor.open()
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
