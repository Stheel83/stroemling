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
    height:  (panel.el && panel.el.typ === "kabellinie") ? klCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    property bool _linienExpanded: true
    property bool _adernExpanded:  true

    readonly property int freshGeid: {
        var kabelId = panel.el && panel.el.extraDaten
                      ? (panel.el.extraDaten.kabelId || 0) : 0
        if (kabelId <= 0) return 0
        var linien = db.kabelAlleLinienLaden(kabelId + (panel._refresh * 0))
        var mySeite = canvas.seiteId
        for (var li = 0; li < linien.length; li++) {
            if (linien[li].seiteId === mySeite)
                return linien[li].grafikElementId || 0
        }
        return 0
    }

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    function extraSetzenMehrfach(felder) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        for (var k in felder) ed[k] = felder[k]
        canvas.eigenschaftAktualisieren("extraDaten", ed)
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

    BauteilKabelPickerDialog {
        id: epKabelPicker
        theme: panel.theme
        onAccepted: {
            var bkId = epKabelPicker.ausgewaehltId
            var felder = { bauteilKabelId: bkId }

            if (bkId > 0) {
                var liste = epKabelPicker.kabelListe
                for (var i = 0; i < liste.length; i++) {
                    if (liste[i].id === bkId) {
                        var k = liste[i]
                        if (k.kabeltyp)                   felder.kabeltyp       = k.kabeltyp
                        if ((k.aderzahl || 0) > 0)        felder.aderzahl       = k.aderzahl
                        if ((k.querschnittMm2 || 0) > 0)  felder.querschnittMm2 = k.querschnittMm2
                        if (k.adern)                      felder.adern          = k.adern
                        break
                    }
                }
            } else {
                felder.adern = []
            }

            var ed0 = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
            var kabelId = ed0.kabelId || 0
            if (kabelId > 0) db.kabelBauteilKabelSetzen(kabelId, bkId)

            root.extraSetzenMehrfach(felder)
        }
    }

    Column {
        id: klCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("KABEL") }

        InputField {
            label: qsTr("Bezeichnung (BMK)")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
            theme: theme
            onCommit: function(t) { root.extraSetzen("bezeichnung", t.trim()) }
        }
        Item { height: 6 }

        InputField {
            label: qsTr("Kabeltyp")
            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.kabeltyp || "") : ""
            theme: theme
            onCommit: function(t) { root.extraSetzen("kabeltyp", t.trim()) }
        }
        Item { height: 6 }

        // Aderzahl + Querschnitt (halbe Breite nebeneinander)
        Row {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Column {
                width: (parent.width - 8) / 2; spacing: 4
                FeldLabel { text: qsTr("Aderzahl") }
                Rectangle {
                    width: parent.width; height: 28
                    color: theme.inputBg; radius: 3
                    border.color: klAderEdit.activeFocus ? theme.accent : theme.border
                    TextInput {
                        id: klAderEdit
                        anchors { fill: parent; margins: 5 }
                        color: theme.textSecondary; font.pixelSize: 11
                        verticalAlignment: TextInput.AlignVCenter
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 0; top: 999 }
                        text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.aderzahl)
                              ? panel.el.extraDaten.aderzahl.toString() : ""
                        Binding on text {
                            when: !klAderEdit.activeFocus
                            value: (panel.el && panel.el.extraDaten && panel.el.extraDaten.aderzahl)
                                   ? panel.el.extraDaten.aderzahl.toString() : ""
                        }
                        onEditingFinished: root.extraSetzen("aderzahl", parseInt(text) || 0)
                        Keys.onEscapePressed: focus = false
                    }
                }
            }
            Column {
                width: (parent.width - 8) / 2; spacing: 4
                FeldLabel { text: qsTr("Querschnitt mm²") }
                Rectangle {
                    width: parent.width; height: 28
                    color: theme.inputBg; radius: 3
                    border.color: klQsEdit.activeFocus ? theme.accent : theme.border
                    TextInput {
                        id: klQsEdit
                        anchors { fill: parent; margins: 5 }
                        color: theme.textSecondary; font.pixelSize: 11
                        verticalAlignment: TextInput.AlignVCenter
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        text: (panel.el && panel.el.extraDaten && panel.el.extraDaten.querschnittMm2)
                              ? panel.el.extraDaten.querschnittMm2.toString() : ""
                        Binding on text {
                            when: !klQsEdit.activeFocus
                            value: (panel.el && panel.el.extraDaten && panel.el.extraDaten.querschnittMm2)
                                   ? panel.el.extraDaten.querschnittMm2.toString() : ""
                        }
                        onEditingFinished: root.extraSetzen("querschnittMm2",
                                               parseFloat(text.replace(",", ".")) || 0.0)
                        Keys.onEscapePressed: focus = false
                    }
                }
            }
        }
        Item { height: 6 }

        // Bauteil-Kabel-Zuweisung
        FeldLabel { text: qsTr("Bauteil-Kabel") }
        Row {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Text {
                width: parent.width - klBkWaehlenBtn.implicitWidth
                       - (klBkLoeschenBtn.visible ? klBkLoeschenBtn.implicitWidth + 6 : 0) - 6
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: {
                    var ed   = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                    var bkId = ed.bauteilKabelId || 0
                    if (bkId > 0) {
                        var liste = db.bauteilKabelListe()
                        for (var i = 0; i < liste.length; i++) {
                            if (liste[i].id === bkId)
                                return (liste[i].bezeichnung || "") + (liste[i].kabeltyp ? "  " + liste[i].kabeltyp : "")
                        }
                        return qsTr("ID") + " " + bkId
                    }
                    return qsTr("–")
                }
                color: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) > 0
                       ? theme.accent : theme.textMuted
                font.pixelSize: 11
                font.italic: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) <= 0
                elide: Text.ElideRight
            }
            Button {
                id: klBkWaehlenBtn
                text: qsTr("Wählen …"); flat: true; implicitHeight: 24; implicitWidth: 72
                contentItem: Text { text: parent.text; color: theme.textPrimary; font.pixelSize: 10;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? theme.hover : theme.inputBg; radius: 3; border.color: theme.border }
                onClicked: {
                    epKabelPicker.kabelListe = db.bauteilKabelListe()
                    epKabelPicker.open()
                }
            }
            Button {
                id: klBkLoeschenBtn
                text: "×"; flat: true; implicitHeight: 24; implicitWidth: 24
                visible: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) > 0
                contentItem: Text { text: parent.text; color: theme.textMuted; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? theme.hover : "transparent"; radius: 3 }
                onClicked: {
                    var ed1 = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                    var klId1 = ed1.kabelId || 0
                    if (klId1 > 0) db.kabelBauteilKabelSetzen(klId1, 0)
                    root.extraSetzenMehrfach({ bauteilKabelId: 0, adern: [] })
                }
            }
        }
        Item { height: 4 }

        // Von / Nach (halbe Breite nebeneinander)
        Row {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Column {
                width: (parent.width - 8) / 2; spacing: 4
                FeldLabel { text: qsTr("Von") }
                Rectangle {
                    width: parent.width; height: 28
                    color: theme.inputBg; radius: 3
                    border.color: klVonEdit.activeFocus ? theme.accent : theme.border
                    TextInput {
                        id: klVonEdit
                        anchors { fill: parent; margins: 5 }
                        color: theme.textSecondary; font.pixelSize: 11
                        verticalAlignment: TextInput.AlignVCenter
                        text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.vonOrt || "") : ""
                        Binding on text {
                            when: !klVonEdit.activeFocus
                            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.vonOrt || "") : ""
                        }
                        onEditingFinished: {
                            root.extraSetzen("vonOrt", text.trim())
                            var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                            var kabelId = ed.kabelId || 0
                            if (kabelId > 0) db.kabelMetaAktualisieren(kabelId,
                                ed.bezeichnung || "", ed.kabeltyp || "",
                                ed.aderzahl || 0, ed.querschnittMm2 || 0,
                                text.trim(), ed.nachOrt || "")
                        }
                        Keys.onEscapePressed: focus = false
                    }
                }
            }
            Column {
                width: (parent.width - 8) / 2; spacing: 4
                FeldLabel { text: qsTr("Nach") }
                Rectangle {
                    width: parent.width; height: 28
                    color: theme.inputBg; radius: 3
                    border.color: klNachEdit.activeFocus ? theme.accent : theme.border
                    TextInput {
                        id: klNachEdit
                        anchors { fill: parent; margins: 5 }
                        color: theme.textSecondary; font.pixelSize: 11
                        verticalAlignment: TextInput.AlignVCenter
                        text: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.nachOrt || "") : ""
                        Binding on text {
                            when: !klNachEdit.activeFocus
                            value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.nachOrt || "") : ""
                        }
                        onEditingFinished: {
                            root.extraSetzen("nachOrt", text.trim())
                            var ed = panel.el && panel.el.extraDaten ? panel.el.extraDaten : {}
                            var kabelId = ed.kabelId || 0
                            if (kabelId > 0) db.kabelMetaAktualisieren(kabelId,
                                ed.bezeichnung || "", ed.kabeltyp || "",
                                ed.aderzahl || 0, ed.querschnittMm2 || 0,
                                ed.vonOrt || "", text.trim())
                        }
                        Keys.onEscapePressed: focus = false
                    }
                }
            }
        }
        Item { height: 4 }

        Button {
            width: parent.width - 16
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Aderzuordnung …")
            implicitHeight: 28
            enabled: (panel.el && panel.el.extraDaten && (panel.el.extraDaten.kabelId || 0) > 0)
            contentItem: Text {
                text: parent.text
                color: parent.enabled ? (theme ? theme.textPrimary : "#c0d8f0") : (theme ? theme.textMuted : "#7090b0")
                font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.hovered && parent.enabled ? (theme ? theme.hover : "#0f2540") : (theme ? theme.inputBg : "#0f1c2e")
                radius: 3; border.color: theme ? theme.border : "#2a4060"
            }
            onClicked: canvas.aderzuordnungDialogOeffnen(panel.el)
        }
        Item { height: 4 }

        // KABEL-LINIEN (aufklappbar)
        Item {
            width: parent.width; height: 26
            Rectangle {
                anchors.fill: parent
                color: klLinienHover.containsMouse ? (theme ? theme.hover : "#0f2540") : "transparent"
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 4
                Text {
                    text: qsTr("KABEL-LINIEN")
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                    color: theme ? theme.borderLight : "#6080a0"
                    Layout.fillWidth: true
                }
                Text {
                    text: root._linienExpanded ? "▾" : "▸"
                    font.pixelSize: 11; color: theme ? theme.borderLight : "#6080a0"
                    verticalAlignment: Text.AlignVCenter
                }
            }
            MouseArea {
                id: klLinienHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root._linienExpanded = !root._linienExpanded
            }
        }

        Item {
            width: parent.width
            height: root._linienExpanded ? linienInhaltCol.implicitHeight : 0
            clip: true
            Column {
                id: linienInhaltCol
                width: parent.width; spacing: 0

                Repeater {
                    model: {
                        var kabelId = panel.el && panel.el.extraDaten
                                      ? (panel.el.extraDaten.kabelId || 0) : 0
                        return kabelId > 0
                               ? db.kabelAlleLinienLaden(kabelId + (panel._refresh * 0))
                               : []
                    }
                    delegate: Rectangle {
                        width: parent ? parent.width - 16 : 0
                        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                        height: 32; radius: 3
                        color: (root.freshGeid > 0 && modelData.grafikElementId === root.freshGeid)
                               ? (theme ? theme.activeItemAlt : "#0f2540")
                               : (theme ? theme.inputBg       : "#0f1c2e")
                        border.color: theme ? theme.border : "#2a4060"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 6
                            Text {
                                text: modelData.seiteBezeichnung || ("Seite " + modelData.seiteId)
                                color: theme ? theme.textSecondary : "#88aacc"
                                font.pixelSize: 10; elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.aderAnzahl + " " + qsTr("Adr.")
                                color: modelData.aderAnzahl > 0
                                       ? (theme ? theme.accent   : "#e07000")
                                       : (theme ? theme.textMuted : "#7090b0")
                                font.pixelSize: 10
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { canvas.querverweisNavigieren(modelData.seiteId); panel._refresh++ }
                        }
                    }
                }

                Item {
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: {
                        var kabelId = panel.el && panel.el.extraDaten
                                      ? (panel.el.extraDaten.kabelId || 0) : 0
                        var freie = kabelId > 0
                                    ? db.kabelFreieAderLaden(kabelId + (panel._refresh * 0))
                                    : []
                        return freie.length > 0 ? freiAderCol.implicitHeight : 0
                    }
                    clip: true
                    Column {
                        id: freiAderCol
                        width: parent.width; spacing: 2
                        Text {
                            width: parent.width
                            text: qsTr("Freie Adern (nicht zugeordnet):")
                            color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10; font.italic: true
                        }
                        Repeater {
                            model: {
                                var kabelId = panel.el && panel.el.extraDaten
                                              ? (panel.el.extraDaten.kabelId || 0) : 0
                                return kabelId > 0
                                       ? db.kabelFreieAderLaden(kabelId + (panel._refresh * 0))
                                       : []
                            }
                            delegate: Text {
                                width: parent ? parent.width : 0
                                text: {
                                    var t = "Ader " + (modelData.aderNr || "?")
                                    if (modelData.farbe) t += "  " + modelData.farbe
                                    if (modelData.bezeichnung) t += "  " + modelData.bezeichnung
                                    return t
                                }
                                color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                Item { height: 4 }
            }
        }

        // KABEL-ADERN (aufklappbar)
        Item {
            width: parent.width; height: 26
            Rectangle {
                anchors.fill: parent
                color: klAdernHover.containsMouse ? (theme ? theme.hover : "#0f2540") : "transparent"
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 4
                Text {
                    text: qsTr("KABEL-ADERN")
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                    color: theme ? theme.borderLight : "#6080a0"
                    Layout.fillWidth: true
                }
                Text {
                    text: root._adernExpanded ? "▾" : "▸"
                    font.pixelSize: 11; color: theme ? theme.borderLight : "#6080a0"
                    verticalAlignment: Text.AlignVCenter
                }
            }
            MouseArea {
                id: klAdernHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: root._adernExpanded = !root._adernExpanded
            }
        }

        Item {
            width: parent.width
            height: root._adernExpanded ? adernInhaltCol.implicitHeight : 0
            clip: true
            Column {
                id: adernInhaltCol
                width: parent.width; spacing: 0

                Text {
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 4
                    text: qsTr("Dieser Linie zugeordnet:")
                    color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10; font.italic: true
                }
                Repeater {
                    model: {
                        var geid = root.freshGeid
                        return geid > 0
                               ? db.kabelAderFuerLinieLaden(geid + (panel._refresh * 0))
                               : []
                    }
                    delegate: Rectangle {
                        width: parent ? parent.width - 16 : 0
                        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                        height: 24; radius: 3
                        color: theme ? theme.inputBg : "#0f1c2e"
                        border.color: theme ? theme.border : "#2a4060"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 6
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                visible: (modelData.farbe || "") !== ""
                                color: canvas ? canvas.iecFarbe(modelData.farbe || "") : "#888888"
                                border.color: "#00000055"; border.width: 1
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: {
                                    var t = "Ader " + (modelData.aderNr || "?")
                                    if (modelData.farbe) t += "  " + modelData.farbe
                                    if (modelData.bezeichnung) t += "  " + modelData.bezeichnung
                                    return t
                                }
                                color: theme ? theme.textSecondary : "#88aacc"
                                font.pixelSize: 10; elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
                Text {
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: {
                        var geid = root.freshGeid
                        var kabelId = panel.el && panel.el.extraDaten
                                      ? (panel.el.extraDaten.kabelId || 0) : 0
                        if (kabelId <= 0) return false
                        if (geid <= 0) return true
                        return db.kabelAderFuerLinieLaden(geid + (panel._refresh * 0)).length === 0
                    }
                    text: qsTr("Keine Adern zugeordnet.")
                    color: theme ? theme.textMuted : "#7090b0"; font.pixelSize: 10; font.italic: true
                }
                Item { height: 8 }
            }
        }
    }
}
