import QtQuick
import QtQuick.Controls
import stroemling
import "../components"

Column {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width: parent ? parent.width : 0
    spacing: 0

    function extraSetzen(key, val) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        ed[key] = val
        panel.canvas.eigenschaftAktualisieren("extraDaten", ed)
    }

    function extraSetzenMehrfach(felder) {
        var ed = panel.el && panel.el.extraDaten
                 ? JSON.parse(JSON.stringify(panel.el.extraDaten)) : {}
        for (var k in felder) ed[k] = felder[k]
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

    BauteilKabelPickerDialog {
        id: epKabelPicker
        theme: root.theme
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

    Trennlinie {}
    AbschnittTitel { text: qsTr("KABEL") }

    InputField {
        label: qsTr("Bezeichnung (BMK)")
        value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.bezeichnung || "") : ""
        theme: root.theme
        onCommit: function(t) { root.extraSetzen("bezeichnung", t.trim()) }
    }
    Item { height: 6 }

    InputField {
        label: qsTr("Kabeltyp")
        value: (panel.el && panel.el.extraDaten) ? (panel.el.extraDaten.kabeltyp || "") : ""
        theme: root.theme
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
                color: root.theme.inputBg; radius: 3
                border.color: klAderEdit.activeFocus ? root.theme.accent : root.theme.border
                TextInput {
                    id: klAderEdit
                    anchors { fill: parent; margins: 5 }
                    color: root.theme.textSecondary; font.pixelSize: 11
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
                color: root.theme.inputBg; radius: 3
                border.color: klQsEdit.activeFocus ? root.theme.accent : root.theme.border
                TextInput {
                    id: klQsEdit
                    anchors { fill: parent; margins: 5 }
                    color: root.theme.textSecondary; font.pixelSize: 11
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
                return "–"
            }
            color: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) > 0
                   ? root.theme.accent : root.theme.textMuted
            font.pixelSize: 11
            font.italic: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) <= 0
            elide: Text.ElideRight
        }
        Button {
            id: klBkWaehlenBtn
            text: qsTr("Wählen …"); flat: true; implicitHeight: 24; implicitWidth: 72
            contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 10;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 3; border.color: root.theme.border }
            onClicked: {
                epKabelPicker.kabelListe = db.bauteilKabelListe()
                epKabelPicker.open()
            }
        }
        Button {
            id: klBkLoeschenBtn
            text: "×"; flat: true; implicitHeight: 24; implicitWidth: 24
            visible: (panel.el && panel.el.extraDaten ? (panel.el.extraDaten.bauteilKabelId || 0) : 0) > 0
            contentItem: Text { text: parent.text; color: root.theme.textMuted; font.pixelSize: 13;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 3 }
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
                color: root.theme.inputBg; radius: 3
                border.color: klVonEdit.activeFocus ? root.theme.accent : root.theme.border
                TextInput {
                    id: klVonEdit
                    anchors { fill: parent; margins: 5 }
                    color: root.theme.textSecondary; font.pixelSize: 11
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
                color: root.theme.inputBg; radius: 3
                border.color: klNachEdit.activeFocus ? root.theme.accent : root.theme.border
                TextInput {
                    id: klNachEdit
                    anchors { fill: parent; margins: 5 }
                    color: root.theme.textSecondary; font.pixelSize: 11
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
            color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
            font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg) : root.theme.inputBg
            radius: 3; border.color: parent.enabled ? root.theme.accent : root.theme.border
        }
        onClicked: panel.canvas.aderzuordnungDialogOeffnen(panel.el)
    }
    Item { height: 4 }
}
