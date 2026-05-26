import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Dialog {
    id: root

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 720
    height: 520
    padding: 0

    required property var theme
    property bool debug:       false
    property bool _debugLokal: false

    signal felderGeaendert()

    onOpened:  _laden()
    onClosed:  root._debugLokal = false

    Shortcut { sequence: "Ctrl+Shift+D"; onActivated: root._debugLokal = !root._debugLokal }

    // ── interner State ────────────────────────────────────────
    property var  _vorlagen:    []   // alle Felder aus DB
    property var  _kategorien:  []   // distinct Kategorien

    function _laden() {
        root._vorlagen   = db.ibnAlleVorlagenLaden()
        root._kategorien = db.ibnAlleKategorienLaden()
        _formReset()
    }

    function _formReset() {
        cmbKat.editText    = ""
        tfFeldname.text    = ""
        tfLabel.text       = ""
        cmbTyp.currentIndex = 0
        tfOptionen.text    = ""
        tfEinheit.text     = ""
        cbPflicht.checked  = false
        root._fehler       = ""
    }

    property string _fehler: ""

    function _speichern() {
        var kat  = cmbKat.editText.trim()
        var fn   = tfFeldname.text.trim().toLowerCase().replace(/\s+/g, "_")
        var lbl  = tfLabel.text.trim()
        var typ  = ["text","zahl","boolean","auswahl"][cmbTyp.currentIndex]
        var opt  = (typ === "auswahl") ? tfOptionen.text.trim() : ""
        var ein  = tfEinheit.text.trim()

        if (!kat) { root._fehler = qsTr("Symbolkategorie fehlt."); return }
        if (!fn)  { root._fehler = qsTr("Feldname fehlt.");        return }
        if (!lbl) { root._fehler = qsTr("Label fehlt.");           return }
        if (typ === "auswahl" && !opt) { root._fehler = qsTr("Optionen fehlen (kommagetrennt)."); return }

        var ok = db.ibnFeldVorlageSpeichern(kat, fn, lbl, typ, opt, ein, cbPflicht.checked)
        if (!ok) { root._fehler = qsTr("Fehler beim Speichern."); return }
        root._fehler = ""
        root.felderGeaendert()
        _laden()
    }

    function _loeschen(id) {
        db.ibnFeldVorlageLoeschen(id)
        root.felderGeaendert()
        _laden()
    }

    // ── Hintergrund ───────────────────────────────────────────
    background: Rectangle {
        color:  root.theme.sidebar
        border.color: root.theme.border
        border.width: 1; radius: 6
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Titelzeile
        Rectangle {
            Layout.fillWidth: true; height: 44
            color: root.theme.surfaceDeep
            radius: 6
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1; color: root.theme.border }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                Text {
                    text: qsTr("IBN-Felder bearbeiten")
                    color: root.theme.textPrimary
                    font.pixelSize: 13; font.weight: Font.Medium
                }
                Item { Layout.fillWidth: true }
                Button {
                    flat: true; implicitWidth: 28; implicitHeight: 28
                    contentItem: Text { text: "✕"; color: root.theme.textMuted
                        font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"; radius: 4 }
                    onClicked: root.reject()
                }
            }
        }

        // Hauptbereich: Links Liste, Rechts Formular
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ── Linke Spalte: Feldliste ───────────────────────
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                color: root.theme.sidebar
                Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                            width: 1; color: root.theme.border }

                ListView {
                    id: listeView
                    anchors { fill: parent; margins: 0 }
                    clip: true

                    model: root._vorlagen

                    section.property:   "symbolKategorie"
                    section.criteria:   ViewSection.FullString
                    section.delegate: Rectangle {
                        width: listeView.width; height: 26
                        color: root.theme.surfaceDeep
                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: section
                            font.pixelSize: 10; font.weight: Font.Medium
                            color: root.theme.textMuted
                            font.capitalization: Font.AllUppercase
                        }
                    }

                    delegate: Rectangle {
                        width: listeView.width; height: 36
                        color: listeHover.containsMouse ? root.theme.hover : root.theme.sidebar
                        HoverHandler { id: listeHover }

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1; color: root.theme.border; z: 1
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
                            spacing: 8

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: modelData.erstelltVon === "user"
                                       ? root.theme.accent
                                       : root.theme.textMuted
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text {
                                    text: modelData.label
                                    font.pixelSize: 11
                                    color: root.theme.textPrimary
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.feldtyp
                                          + (modelData.einheit ? "  [" + modelData.einheit + "]" : "")
                                          + (modelData.pflichtfeld ? "  *" : "")
                                    font.pixelSize: 9
                                    color: root.theme.textMuted
                                }
                            }

                            Button {
                                visible: modelData.erstelltVon === "user"
                                flat: true; implicitWidth: 22; implicitHeight: 22
                                contentItem: Text { text: "✕"; color: "#cc4444"; font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: parent.hovered ? theme.activeItemAlt : "transparent"; radius: 3 }
                                onClicked: root._loeschen(modelData.id)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: listeView.count === 0
                        text: qsTr("Keine Felder vorhanden.")
                        color: root.theme.textMuted
                        font.pixelSize: 11; font.italic: true
                    }
                }
            }

            // ── Rechte Spalte: Neues Feld anlegen ─────────────
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                Rectangle {
                    width: parent.width
                    implicitHeight: innerLayout.implicitHeight + 16
                    color: root.theme.sidebar

                ColumnLayout {
                    id: innerLayout
                    width: parent.width
                    spacing: 10
                    Layout.margins: 16

                    Item { height: 4 }

                    Text {
                        text: qsTr("Neues Feld anlegen")
                        color: root.theme.textPrimary
                        font.pixelSize: 12; font.weight: Font.Medium
                        Layout.leftMargin: 16
                    }

                    Rectangle { Layout.fillWidth: true; height: 1
                        color: root.theme.border
                        Layout.leftMargin: 16; Layout.rightMargin: 16 }

                    // Symbolkategorie
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 4

                        Text { text: qsTr("Symbolkategorie *")
                            color: root.theme.textMuted
                            font.pixelSize: 11 }
                        ComboBox {
                            id: cmbKat
                            Layout.fillWidth: true; implicitHeight: 30
                            editable: true
                            model: root._kategorien
                            background: Rectangle { color: root.theme.inputBg
                                radius: 4; border.color: root.theme.border }
                            contentItem: TextField {
                                leftPadding: 8
                                text: cmbKat.editText
                                color: root.theme.textPrimary
                                font.pixelSize: 12
                                background: null
                                onTextEdited: cmbKat.editText = text
                            }
                            popup.background: Rectangle {
                                color: root.theme.surfaceDeep
                                border.color: root.theme.border; radius: 4
                            }
                            delegate: ItemDelegate {
                                width: cmbKat.width; implicitHeight: 28
                                highlighted: cmbKat.highlightedIndex === index
                                contentItem: Text {
                                    leftPadding: 8; text: modelData
                                    color: root.theme.textPrimary; font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: highlighted ? root.theme.hover : "transparent"
                                }
                            }
                        }
                    }

                    // Feldname
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 4

                        Text { text: qsTr("Feldname * (intern, keine Leerzeichen)")
                            color: root.theme.textMuted
                            font.pixelSize: 11 }
                        TextField {
                            id: tfFeldname
                            Layout.fillWidth: true; implicitHeight: 30
                            placeholderText: qsTr("z. B. messwert_r")
                            color: root.theme.textPrimary
                            font.pixelSize: 12
                            background: Rectangle { color: root.theme.inputBg
                                radius: 4; border.color: root.theme.border }
                        }
                    }

                    // Label
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 4

                        Text { text: qsTr("Anzeigename (Label) *")
                            color: root.theme.textMuted
                            font.pixelSize: 11 }
                        TextField {
                            id: tfLabel
                            Layout.fillWidth: true; implicitHeight: 30
                            placeholderText: qsTr("z. B. Messwert R-Phase")
                            color: root.theme.textPrimary
                            font.pixelSize: 12
                            background: Rectangle { color: root.theme.inputBg
                                radius: 4; border.color: root.theme.border }
                        }
                    }

                    // Feldtyp
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 4

                        Text { text: qsTr("Feldtyp *")
                            color: root.theme.textMuted
                            font.pixelSize: 11 }
                        ComboBox {
                            id: cmbTyp
                            Layout.fillWidth: true; implicitHeight: 30
                            model: [
                                qsTr("Text"),
                                qsTr("Zahl"),
                                qsTr("Ja/Nein (Boolean)"),
                                qsTr("Auswahl")
                            ]
                            background: Rectangle { color: root.theme.inputBg
                                radius: 4; border.color: root.theme.border }
                            contentItem: Text {
                                leftPadding: 8; text: cmbTyp.displayText
                                color: root.theme.textPrimary
                                font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                            }
                            popup.background: Rectangle {
                                color: root.theme.surfaceDeep
                                border.color: root.theme.border; radius: 4
                            }
                            delegate: ItemDelegate {
                                width: cmbTyp.width; implicitHeight: 28
                                highlighted: cmbTyp.highlightedIndex === index
                                contentItem: Text {
                                    leftPadding: 8; text: modelData
                                    color: root.theme.textPrimary; font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: highlighted ? root.theme.hover : "transparent"
                                }
                            }
                        }
                    }

                    // Optionen (nur bei Auswahl)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 4
                        visible: cmbTyp.currentIndex === 3

                        Text { text: qsTr("Optionen * (kommagetrennt)")
                            color: root.theme.textMuted
                            font.pixelSize: 11 }
                        TextField {
                            id: tfOptionen
                            Layout.fillWidth: true; implicitHeight: 30
                            placeholderText: qsTr("z. B. Gut,Mängel,Fehler")
                            color: root.theme.textPrimary
                            font.pixelSize: 12
                            background: Rectangle { color: root.theme.inputBg
                                radius: 4; border.color: root.theme.border }
                        }
                    }

                    // Einheit
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 4

                        Text { text: qsTr("Einheit (optional)")
                            color: root.theme.textMuted
                            font.pixelSize: 11 }
                        TextField {
                            id: tfEinheit
                            Layout.fillWidth: true; implicitHeight: 30
                            placeholderText: qsTr("z. B. A, V, Ω")
                            color: root.theme.textPrimary
                            font.pixelSize: 12
                            background: Rectangle { color: root.theme.inputBg
                                radius: 4; border.color: root.theme.border }
                        }
                    }

                    // Pflichtfeld
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 8

                        CheckBox {
                            id: cbPflicht
                            indicator: Rectangle {
                                implicitWidth: 16; implicitHeight: 16; radius: 3
                                color: parent.checked ? root.theme.accent : root.theme.inputBg
                                border.color: root.theme.border
                                Text { anchors.centerIn: parent; text: "✓"; color: "white"
                                    font.pixelSize: 11; visible: parent.parent.checked }
                            }
                            contentItem: Text {
                                leftPadding: parent.indicator.width + 6
                                text: qsTr("Pflichtfeld")
                                color: root.theme.textPrimary
                                font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    // Fehlermeldung
                    Text {
                        visible: root._fehler !== ""
                        text: root._fehler
                        color: "#cc4444"; font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                    }

                    // Buttons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        spacing: 8

                        Button {
                            text: qsTr("Zurücksetzen"); Layout.fillWidth: true; implicitHeight: 30
                            contentItem: Text { text: parent.text
                                color: root.theme.textSecondary
                                font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg
                                radius: 4; border.color: root.theme.border }
                            onClicked: root._formReset()
                        }

                        Button {
                            text: qsTr("Feld anlegen"); Layout.fillWidth: true; implicitHeight: 30
                            enabled: cmbKat.editText.trim().length > 0
                                     && tfFeldname.text.trim().length > 0
                                     && tfLabel.text.trim().length > 0
                            contentItem: Text { text: parent.text
                                color: parent.enabled ? root.theme.textPrimary
                                                      : root.theme.textMuted
                                font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter }
                            background: Rectangle {
                                color: parent.enabled
                                       ? (parent.hovered ? root.theme.accent
                                                         : root.theme.inputBg)
                                       : root.theme.inputBg
                                radius: 4
                                border.color: parent.enabled ? root.theme.accent
                                                             : root.theme.border
                            }
                            onClicked: root._speichern()
                        }
                    }

                    Text {
                        visible: root._debugLokal
                        text: "Vorlagen: " + root._vorlagen.length + "  |  Kategorien: " + root._kategorien.length
                        color: "#44aaff"; font.pixelSize: 9; font.family: "monospace"
                        Layout.leftMargin: 16
                    }

                    Item { height: 8 }
                }
                } // Rectangle
            }
        }

        // Fußzeile
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: root.theme.surfaceDeep
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 1; color: root.theme.border }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                Text {
                    text: {
                        var sys  = root._vorlagen.filter(function(v){ return v.erstelltVon === "system" }).length
                        var user = root._vorlagen.filter(function(v){ return v.erstelltVon === "user"   }).length
                        return qsTr("%1 Systemfelder  ·  %2 eigene Felder").arg(sys).arg(user)
                    }
                    font.pixelSize: 10; color: root.theme.textMuted
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Schließen"); implicitHeight: 26; implicitWidth: 90
                    contentItem: Text { text: parent.text
                        color: root.theme.textSecondary
                        font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : "transparent"
                        radius: 4; border.color: root.theme.border }
                    onClicked: root.reject()
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("IBN-Felder bearbeiten"); visible: root.debug || root._debugLokal; parent: root.contentItem }
}
