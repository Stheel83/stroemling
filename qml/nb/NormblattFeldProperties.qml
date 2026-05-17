import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var theme

    property var feld:    null
    property int feldIdx: -1

    signal feldGeaendert(int idx, var feld)
    signal feldLoeschen(int idx)

    readonly property var _typen:    ["fest","projekt","seite","datum","vollkennzeichen","format","logo"]
    readonly property var _pSpalten: ["name","projektnummer","auftraggeber","auftragnehmer","bearbeiter","norm"]
    readonly property var _sSpalten: ["blattnummer","bezeichnung","anlage_kuerzel","ort_kuerzel"]

    // Inputs werden bei Feldwechsel (neues feldIdx) zurückgesetzt
    Timer {
        id: resetTimer
        interval: 0
        onTriggered: _resetInputs()
    }
    onFeldIdxChanged: resetTimer.restart()

    function _resetInputs() {
        if (!feld) return
        var ti = _typen.indexOf(feld.feldtyp || "fest")
        cmbTyp.currentIndex    = ti >= 0 ? ti : 0
        tfLabel.text           = feld.label  || ""
        tfInhalt.text          = feld.inhalt || ""
        sbX.value  = Math.round(feld.xMm      || 0)
        sbY.value  = Math.round(feld.yMm      || 0)
        sbB.value  = Math.round(feld.breiteMm || 50)
        sbH.value  = Math.round(feld.hoeheMm  || 13)
        cbFett.checked   = (feld.fett   || 0) !== 0
        cbRahmen.checked = (feld.rahmen !== undefined && feld.rahmen !== null)
                           ? feld.rahmen !== 0 : true
        _aktualisiereQuelleCombo(feld.feldtyp || "fest", feld.quelleSpalte || "")
    }

    function _aktualisiereQuelleCombo(ft, qs) {
        if (ft === "projekt") {
            cmbQuelle.model        = _pSpalten
            cmbQuelle.currentIndex = Math.max(0, _pSpalten.indexOf(qs))
        } else if (ft === "seite") {
            cmbQuelle.model        = _sSpalten
            cmbQuelle.currentIndex = Math.max(0, _sSpalten.indexOf(qs))
        } else {
            cmbQuelle.model        = []
            cmbQuelle.currentIndex = -1
        }
    }

    // Kopie des Feldes mit geändertem Schlüssel erzeugen und emittieren
    function _emit(key, val) {
        if (feldIdx < 0 || !feld) return
        var f = _kopieren()
        if (!f) return
        f[key] = val
        feldGeaendert(feldIdx, f)
    }

    function _kopieren() {
        if (!feld) return null
        return {
            feldtyp:       feld.feldtyp        !== undefined ? feld.feldtyp        : "fest",
            label:         feld.label          !== undefined ? feld.label          : "",
            inhalt:        feld.inhalt         !== undefined ? feld.inhalt         : "",
            quelleSpalte:  feld.quelleSpalte   !== undefined ? feld.quelleSpalte   : "",
            xMm:           feld.xMm            !== undefined ? feld.xMm            : 0,
            yMm:           feld.yMm            !== undefined ? feld.yMm            : 0,
            breiteMm:      feld.breiteMm       !== undefined ? feld.breiteMm       : 50,
            hoeheMm:       feld.hoeheMm        !== undefined ? feld.hoeheMm        : 13,
            schriftgroesse:feld.schriftgroesse  !== undefined ? feld.schriftgroesse  : 3.5,
            fett:          feld.fett           !== undefined ? feld.fett           : 0,
            rahmen:        feld.rahmen         !== undefined ? feld.rahmen         : 1,
            reihenfolge:   feld.reihenfolge    !== undefined ? feld.reihenfolge    : 0
        }
    }

    // ── Leerzustand ───────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: root.feld === null
        Text {
            anchors.centerIn: parent
            text: qsTr("Kein Feld\nausgewählt")
            color: root.theme.textMuted; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── Formular ──────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        visible: root.feld !== null
        contentHeight: col.implicitHeight + 16
        clip: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: parent.width; padding: 8; spacing: 5

            component AbsTitel: Text {
                height: 22; verticalAlignment: Text.AlignBottom
                color: root.theme.borderLight
                font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
            }
            component FeldLabel: Text {
                color: root.theme.panelMid; font.pixelSize: 10
            }

            AbsTitel { text: qsTr("FELDTYP") }

            ComboBox {
                id: cmbTyp
                width: col.width - col.padding * 2
                model: root._typen
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text {
                    leftPadding: 8; text: cmbTyp.displayText
                    color: root.theme.textPrimary; font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: cmbTyp.width; implicitHeight: 30
                    highlighted: cmbTyp.highlightedIndex === index
                    contentItem: Text {
                        leftPadding: 8; text: modelData
                        color: root.theme.textPrimary; font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                }
                onActivated: function(i) {
                    var ft = model[i]
                    root._aktualisiereQuelleCombo(ft, root.feld ? (root.feld.quelleSpalte || "") : "")
                    root._emit("feldtyp", ft)
                }
            }

            AbsTitel { text: qsTr("BESCHRIFTUNG") }

            FeldLabel { text: qsTr("Label (Titelzeile)") }
            TextField {
                id: tfLabel
                width: col.width - col.padding * 2
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                color: root.theme.textPrimary; font.pixelSize: 12
                placeholderText: qsTr("z.B. PROJEKT")
                onEditingFinished: root._emit("label", text)
            }

            FeldLabel {
                text: qsTr("Text (fester Inhalt)")
                visible: root.feld !== null && (root.feld.feldtyp || "fest") === "fest"
                height: visible ? implicitHeight : 0
            }
            TextField {
                id: tfInhalt
                visible: root.feld !== null && (root.feld.feldtyp || "fest") === "fest"
                height: visible ? implicitHeight : 0
                width: col.width - col.padding * 2
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                color: root.theme.textPrimary; font.pixelSize: 12
                onEditingFinished: root._emit("inhalt", text)
            }

            FeldLabel {
                text: qsTr("Quellfeld")
                visible: root.feld !== null &&
                         (root.feld.feldtyp === "projekt" || root.feld.feldtyp === "seite")
                height: visible ? implicitHeight : 0
            }
            ComboBox {
                id: cmbQuelle
                visible: root.feld !== null &&
                         (root.feld.feldtyp === "projekt" || root.feld.feldtyp === "seite")
                height: visible ? implicitHeight : 0
                width: col.width - col.padding * 2
                background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                contentItem: Text {
                    leftPadding: 8
                    text: cmbQuelle.currentIndex >= 0 && cmbQuelle.model
                          ? (cmbQuelle.model[cmbQuelle.currentIndex] || "") : ""
                    color: root.theme.textPrimary; font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: cmbQuelle.width; implicitHeight: 30
                    highlighted: cmbQuelle.highlightedIndex === index
                    contentItem: Text {
                        leftPadding: 8; text: modelData
                        color: root.theme.textPrimary; font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: highlighted ? root.theme.hover : "transparent" }
                }
                onActivated: function(i) {
                    root._emit("quelleSpalte", model[i] || "")
                }
            }

            AbsTitel { text: qsTr("POSITION & GRÖẞE") }

            GridLayout {
                width: col.width - col.padding * 2
                columns: 2; columnSpacing: 6; rowSpacing: 4

                FeldLabel { text: qsTr("X (mm)") }
                FeldLabel { text: qsTr("Y (mm)") }

                SpinBox {
                    id: sbX; from: 0; to: 1000; stepSize: 1; editable: true
                    Layout.preferredWidth: (parent.width - 6) / 2
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: TextInput {
                        text: sbX.textFromValue(sbX.value, sbX.locale)
                        color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        validator: sbX.validator
                    }
                    onValueModified: root._emit("xMm", value)
                }
                SpinBox {
                    id: sbY; from: 0; to: 1000; stepSize: 1; editable: true
                    Layout.preferredWidth: (parent.width - 6) / 2
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: TextInput {
                        text: sbY.textFromValue(sbY.value, sbY.locale)
                        color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        validator: sbY.validator
                    }
                    onValueModified: root._emit("yMm", value)
                }

                FeldLabel { text: qsTr("Breite (mm)") }
                FeldLabel { text: qsTr("Höhe (mm)") }

                SpinBox {
                    id: sbB; from: 10; to: 1000; stepSize: 1; editable: true
                    Layout.preferredWidth: (parent.width - 6) / 2
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: TextInput {
                        text: sbB.textFromValue(sbB.value, sbB.locale)
                        color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        validator: sbB.validator
                    }
                    onValueModified: root._emit("breiteMm", value)
                }
                SpinBox {
                    id: sbH; from: 5; to: 500; stepSize: 1; editable: true
                    Layout.preferredWidth: (parent.width - 6) / 2
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 4 }
                    contentItem: TextInput {
                        text: sbH.textFromValue(sbH.value, sbH.locale)
                        color: root.theme.textPrimary; font.pixelSize: 12
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        validator: sbH.validator
                    }
                    onValueModified: root._emit("hoeheMm", value)
                }
            }

            AbsTitel { text: qsTr("STIL") }

            CheckBox {
                id: cbFett
                contentItem: Text {
                    leftPadding: cbFett.indicator.width + cbFett.spacing
                    text: qsTr("Fett")
                    color: root.theme.textPrimary; font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    width: 16; height: 16; radius: 3
                    x: cbFett.leftPadding; y: (cbFett.height - 16) / 2
                    color: cbFett.checked ? root.theme.accent : root.theme.inputBg
                    border.color: cbFett.checked ? root.theme.accent : root.theme.border
                    Text {
                        anchors.centerIn: parent; text: "✓"; color: "white"
                        font.pixelSize: 11; visible: cbFett.checked
                    }
                }
                onToggled: root._emit("fett", checked ? 1 : 0)
            }

            CheckBox {
                id: cbRahmen
                contentItem: Text {
                    leftPadding: cbRahmen.indicator.width + cbRahmen.spacing
                    text: qsTr("Rahmen zeichnen")
                    color: root.theme.textPrimary; font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                }
                indicator: Rectangle {
                    width: 16; height: 16; radius: 3
                    x: cbRahmen.leftPadding; y: (cbRahmen.height - 16) / 2
                    color: cbRahmen.checked ? root.theme.accent : root.theme.inputBg
                    border.color: cbRahmen.checked ? root.theme.accent : root.theme.border
                    Text {
                        anchors.centerIn: parent; text: "✓"; color: "white"
                        font.pixelSize: 11; visible: cbRahmen.checked
                    }
                }
                onToggled: root._emit("rahmen", checked ? 1 : 0)
            }

            Item { height: 8 }

            Rectangle {
                width: col.width - col.padding * 2; height: 1
                color: root.theme.divider
            }

            Item { height: 4 }

            Rectangle {
                width: col.width - col.padding * 2; height: 30; radius: 5
                color: loeschMA.containsMouse ? "#802020" : Qt.rgba(0.35, 0.1, 0.1, 1)
                border.color: "#a03030"; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Feld löschen")
                    color: "#f0c0c0"; font.pixelSize: 12
                }
                MouseArea {
                    id: loeschMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.feldLoeschen(root.feldIdx)
                }
            }
        }
    }
}
