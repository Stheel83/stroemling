import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling

Dialog {
    id: root

    required property var theme

    property int    bauteilId:   -1
    property string bezeichnung: ""

    property int    _konfkabelId:      -1
    property int    _bauteilKabelId:   -1
    property int    _steckerABauteilId: 0
    property int    _steckerBBauteilId: 0
    property real   _laengeM:          0
    property var    _kabelListe:        []
    property var    _steckverbinderListe: []

    title:   qsTr("Konfektioniertes Kabel – Editor")
    modal:   true
    parent:  Overlay.overlay
    anchors.centerIn: parent
    width:   640
    padding: 0

    background: Rectangle {
        color:        root.theme.sidebar
        border.color: root.theme.border
        border.width: 1
        radius:       6
    }

    onOpened: _laden()

    function _laden() {
        if (root.bauteilId < 0) return
        _kabelListe         = db.bauteilKabelListe()
        _steckverbinderListe = db.steckverbinderBausteineListe()

        var kk = db.konfkabelLaden(root.bauteilId)
        _konfkabelId       = kk.id           !== undefined ? kk.id           : -1
        _bauteilKabelId    = kk.bauteilKabelId !== undefined ? kk.bauteilKabelId : -1
        _steckerABauteilId = kk.steckerABauteilId !== undefined ? kk.steckerABauteilId : 0
        _steckerBBauteilId = kk.steckerBBauteilId !== undefined ? kk.steckerBBauteilId : 0
        _laengeM           = kk.laengeM      !== undefined ? kk.laengeM      : 0

        cbKabeltyp.currentIndex  = _kabelIndexFuer(_bauteilKabelId)
        cbSteckerA.currentIndex  = _steckerIndexFuer(_steckerABauteilId)
        cbSteckerB.currentIndex  = _steckerIndexFuer(_steckerBBauteilId)
        tfLaenge.text = _laengeM > 0 ? _laengeM.toString() : ""
    }

    function _kabelIndexFuer(id) {
        for (var i = 0; i < _kabelListe.length; i++) {
            if (_kabelListe[i].id === id) return i + 1
        }
        return 0
    }

    function _steckerIndexFuer(id) {
        if (id <= 0) return 0
        for (var i = 0; i < _steckverbinderListe.length; i++) {
            if (_steckverbinderListe[i].id === id) return i + 1
        }
        return 0
    }

    function _speichern() {
        var kabelId  = cbKabeltyp.currentIndex > 0 ? _kabelListe[cbKabeltyp.currentIndex - 1].id : -1
        var steckerA = cbSteckerA.currentIndex > 0 ? _steckverbinderListe[cbSteckerA.currentIndex - 1].id : 0
        var steckerB = cbSteckerB.currentIndex > 0 ? _steckverbinderListe[cbSteckerB.currentIndex - 1].id : 0
        var laenge   = parseFloat(tfLaenge.text.replace(",",".")) || 0

        var newId = db.konfkabelSpeichern(root.bauteilId, kabelId, steckerA, steckerB, laenge)
        if (newId > 0) _konfkabelId = newId
    }

    contentItem: ColumnLayout {
        spacing: 0

        // ── Titelzeile ────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 48; color: root.theme.surface
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                        height: 1; color: root.theme.border }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                Text { text: root.bezeichnung; font.pixelSize: 14; font.bold: true
                       color: root.theme.textPrimary; Layout.fillWidth: true }
                Text { text: qsTr("Konfektioniertes Kabel"); font.pixelSize: 11
                       color: root.theme.textMuted; font.italic: true }
            }
        }

        // ── Inhalt ────────────────────────────────────────────
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(implicitHeight, 420)
            contentWidth: availableWidth

            ColumnLayout {
                id: kkContent
                width: parent.width - 32
                x: 16
                spacing: 0

                Item { height: 12 }

                // Abschnittstitel STAMMDATEN
                Text {
                    text: qsTr("STAMMDATEN")
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                    color: root.theme.borderLight
                }

                Item { height: 6 }

                // Kabeltyp
                Text { text: qsTr("Kabeltyp (aus Bibliothek)"); font.pixelSize: 11; color: root.theme.textMuted }
                Item { height: 3 }
                ComboBox {
                    id: cbKabeltyp
                    Layout.fillWidth: true; height: 28
                    model: {
                        var m = [qsTr("— kein Kabeltyp —")]
                        for (var i = 0; i < root._kabelListe.length; i++)
                            m.push(root._kabelListe[i].bezeichnung || root._kabelListe[i].kabeltyp || ("ID " + root._kabelListe[i].bauteilId))
                        return m
                    }
                    font.pixelSize: 11
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                    contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                        leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                    onActivated: root._speichern()
                }

                Item { height: 10 }

                // Länge
                Text { text: qsTr("Länge (m)"); font.pixelSize: 11; color: root.theme.textMuted }
                Item { height: 3 }
                Rectangle {
                    Layout.fillWidth: true; height: 28
                    color: root.theme.inputBg; border.color: tfLaenge.activeFocus ? root.theme.accent : root.theme.border; radius: 3
                    TextInput {
                        id: tfLaenge
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        color: root.theme.textPrimary; font.pixelSize: 11
                        verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        onEditingFinished: root._speichern()
                        Keys.onEscapePressed: focus = false
                    }
                }

                Item { height: 10 }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }
                Item { height: 10 }

                // Stecker Ende A
                Text {
                    text: qsTr("STECKER / BUCHSE – ENDE A")
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                    color: root.theme.borderLight
                }
                Item { height: 3 }
                ComboBox {
                    id: cbSteckerA
                    Layout.fillWidth: true; height: 28
                    model: {
                        var m = [qsTr("— freies Ende —")]
                        for (var i = 0; i < root._steckverbinderListe.length; i++) {
                            var sv = root._steckverbinderListe[i]
                            m.push(sv.bezeichnung + (sv.polzahl > 0 ? " (" + sv.polzahl + "p)" : ""))
                        }
                        return m
                    }
                    font.pixelSize: 11
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                    contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                        leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                    onActivated: root._speichern()
                }

                Item { height: 10 }

                // Stecker Ende B
                Text {
                    text: qsTr("STECKER / BUCHSE – ENDE B")
                    font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                    color: root.theme.borderLight
                }
                Item { height: 3 }
                ComboBox {
                    id: cbSteckerB
                    Layout.fillWidth: true; height: 28
                    model: {
                        var m = [qsTr("— freies Ende —")]
                        for (var i = 0; i < root._steckverbinderListe.length; i++) {
                            var sv = root._steckverbinderListe[i]
                            m.push(sv.bezeichnung + (sv.polzahl > 0 ? " (" + sv.polzahl + "p)" : ""))
                        }
                        return m
                    }
                    font.pixelSize: 11
                    background: Rectangle { color: root.theme.inputBg; border.color: root.theme.border; radius: 3 }
                    contentItem: Text { text: parent.displayText; color: root.theme.textPrimary; font.pixelSize: 11
                        leftPadding: 8; verticalAlignment: Text.AlignVCenter }
                    onActivated: root._speichern()
                }

                Item { height: 12 }
            }
        }

        // ── Footer ────────────────────────────────────────────
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.border }
        Rectangle {
            Layout.fillWidth: true; height: 52; color: root.theme.surface; radius: 6
            Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        height: 1; color: root.theme.border }
            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                spacing: 8
                Text {
                    text: root._konfkabelId > 0
                          ? qsTr("Änderungen werden sofort gespeichert.")
                          : qsTr("Auswahl treffen um Datensatz anzulegen.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                    Layout.fillWidth: true
                }
                Button {
                    text: qsTr("Schließen"); implicitWidth: 90; implicitHeight: 34
                    contentItem: Text { text: parent.text; color: root.theme.textPrimary; font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        color: parent.hovered ? root.theme.accent : root.theme.inputBg
                        radius: 4; border.color: root.theme.accent
                    }
                    onClicked: root.close()
                }
            }
        }
    }
}
