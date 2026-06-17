import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import stroemling
import "../components"

Item {
    id: root
    required property int projektId
    required property var theme
    property bool debug: false

    signal sprungAngefordert(int seiteId, string blattnr, string seiteBez, real wx, real wy)

    property var _flachListe: []
    property int _pickerFuerElId: -1

    property var _gruppiert: {
        var gruppen = {}
        var reihenfolge = []
        for (var i = 0; i < root._flachListe.length; i++) {
            var gk = root._flachListe[i]
            var bmk = gk.bmk || ""
            if (!gruppen[bmk]) {
                gruppen[bmk] = { bmk: bmk, bezeichnung: gk.bezeichnung || "", instanzen: [] }
                reihenfolge.push(bmk)
            }
            gruppen[bmk].instanzen.push(gk)
        }
        return reihenfolge.map(function(b) { return gruppen[b] })
    }

    function laden() {
        root._flachListe = root.projektId >= 0
            ? db.geraetekastenListeMitPos(root.projektId)
            : []
    }

    onVisibleChanged:  { if (visible) laden() }
    onProjektIdChanged: laden()

    // ── Steckverbinder-Bauteil-Picker ─────────────────────────
    Popup {
        id: svPicker
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 420; height: 340
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var _liste: []
        function oeffnen(elementId) {
            root._pickerFuerElId = elementId
            svPicker._liste = db.steckverbinderBausteineListe()
            svPicker.open()
        }

        background: Rectangle {
            color: root.theme.surface
            border.color: root.theme.border; border.width: 1; radius: 6
        }

        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 0

            Text {
                width: parent.width
                text: qsTr("Steckverbinder-Bauteil wählen")
                font.pixelSize: 13; font.weight: Font.Medium
                color: root.theme.textPrimary; padding: 6
            }

            Rectangle { width: parent.width; height: 1; color: root.theme.border }

            ListView {
                id: pickerList
                width: parent.width
                height: parent.height - 50
                clip: true
                model: svPicker._liste

                Text {
                    visible: svPicker._liste.length === 0
                    anchors.centerIn: parent
                    text: qsTr("Keine Steckverbinder-Bauteile vorhanden.\nErstelle zuerst einen Eintrag unter Bibliothek → Steckverbinder.")
                    font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                }

                delegate: Rectangle {
                    width: pickerList.width; height: 42
                    color: pickerItemHover.containsMouse ? root.theme.hover : "transparent"
                    HoverHandler { id: pickerItemHover }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 2
                        Text {
                            width: parent.width
                            text: modelData.bezeichnung
                            font.pixelSize: 12; color: root.theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: (modelData.hersteller || "") +
                                  (modelData.polzahl > 0 ? "  ·  " + modelData.polzahl + qsTr("-polig") : "")
                            font.pixelSize: 10; color: root.theme.textMuted
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root._pickerFuerElId >= 0) {
                                db.geraetekastenBauteilSetzen(root._pickerFuerElId, modelData.id)
                                root.laden()
                            }
                            svPicker.close()
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.theme.border }

            Item {
                width: parent.width; height: 36
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Abbrechen")
                    font.pixelSize: 12; color: root.theme.textMuted
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: svPicker.close()
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Kopfzeile ────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 40
            color: root.theme.surfaceDeep
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1; color: root.theme.border
            }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12
                Text {
                    text: qsTr("Gerätekästen")
                    font.pixelSize: 13; font.weight: Font.Medium
                    color: root.theme.textPrimary; Layout.fillWidth: true
                }
                Text {
                    visible: root._flachListe.length > 0
                    text: root._gruppiert.length + qsTr(" Geräte  ·  ") + root._flachListe.length + qsTr(" Kästen")
                    font.pixelSize: 10; color: root.theme.textMuted
                }
                Rectangle {
                    width: 22; height: 22; radius: 3
                    color: reloadHover.containsMouse ? root.theme.hover : "transparent"
                    HoverHandler { id: reloadHover }
                    Text { anchors.centerIn: parent; text: "⟳"; font.pixelSize: 14; color: root.theme.accent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.laden()
                    }
                }
            }
        }

        // ── Leerzustand ──────────────────────────────────────
        Item {
            visible: root._gruppiert.length === 0
            Layout.fillWidth: true; Layout.fillHeight: true
            Column {
                anchors.centerIn: parent; spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📐"; font.pixelSize: 32; opacity: 0.3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Noch keine Gerätekästen im Projekt.")
                    font.pixelSize: 12; color: root.theme.textMuted; font.italic: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Gerätekästen mit der Taste G auf dem Canvas zeichnen.")
                    font.pixelSize: 11; color: root.theme.borderLight
                }
            }
        }

        // ── Geräte-Liste ─────────────────────────────────────
        ScrollView {
            visible: root._gruppiert.length > 0
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true

            Column {
                width: parent.width

                Repeater {
                    model: root._gruppiert
                    delegate: Column {
                        width: parent.width

                        // BMK-Gruppenzeile
                        Rectangle {
                            width: parent.width; height: 38
                            color: root.theme.surface
                            Rectangle {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                height: 1; color: root.theme.border
                            }
                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: 3; color: root.theme.accent
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12
                                spacing: 8
                                Text { text: "📐"; font.pixelSize: 13 }
                                Text {
                                    text: modelData.bmk
                                    font.pixelSize: 12; font.weight: Font.Medium
                                    color: root.theme.textPrimary
                                }
                                Text {
                                    text: modelData.bezeichnung
                                    font.pixelSize: 11; color: root.theme.textSecondary
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                                Text {
                                    visible: modelData.instanzen.length > 1
                                    text: modelData.instanzen.length + "×"
                                    font.pixelSize: 10; color: root.theme.textMuted
                                }
                            }
                        }

                        // Instanzen
                        Repeater {
                            model: modelData.instanzen
                            delegate: Rectangle {
                                id: instDelegate
                                width: parent.width
                                property var gkd: modelData
                                property bool hatBauteil: gkd.bauteilId > 0

                                height: hatBauteil ? 52 : 30
                                color: instHover.containsMouse ? root.theme.hover : "transparent"

                                MouseArea {
                                    id: instHover; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.ArrowCursor
                                }

                                Rectangle {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                    height: 1; color: root.theme.divider
                                }

                                // ── Navigations-Zeile (oben, 30px) ──────────────
                                RowLayout {
                                    anchors.top: parent.top; anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 28; anchors.rightMargin: 10
                                    height: 30; spacing: 6

                                    Text { text: "↳"; font.pixelSize: 11; color: root.theme.borderLight }
                                    Text {
                                        text: qsTr("Blatt ") + (gkd.blattnr || "–")
                                        font.pixelSize: 11; color: root.theme.textSecondary
                                        Layout.preferredWidth: 60
                                    }
                                    Text {
                                        text: gkd.seiteBez || ""
                                        font.pixelSize: 11; color: root.theme.textMuted
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    // "Verknüpfen"-Button (nur ohne Bauteil + bei Hover)
                                    Rectangle {
                                        visible: !instDelegate.hatBauteil && instHover.containsMouse
                                        width: 80; height: 20; radius: 3
                                        color: vknHover.containsMouse ? root.theme.accent : "transparent"
                                        border.color: vknHover.containsMouse ? root.theme.accent : root.theme.border
                                        HoverHandler { id: vknHover }
                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("+ Verknüpfen")
                                            font.pixelSize: 10
                                            color: vknHover.containsMouse ? "white" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: svPicker.oeffnen(gkd.id)
                                        }
                                    }
                                    // Sprung-Button
                                    Rectangle {
                                        width: 22; height: 22; radius: 3
                                        color: sprungHover.containsMouse ? root.theme.accent : "transparent"
                                        border.color: sprungHover.containsMouse ? root.theme.accent : root.theme.border
                                        HoverHandler { id: sprungHover }
                                        Text {
                                            anchors.centerIn: parent; text: "→"
                                            font.pixelSize: 11
                                            color: sprungHover.containsMouse ? "white" : root.theme.accent
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var d = gkd
                                                root.sprungAngefordert(d.seiteId, d.blattnr,
                                                                       d.seiteBez, d.weltX, d.weltY)
                                            }
                                        }
                                    }
                                }

                                // ── Bauteil-Info-Zeile (unten, 22px) ─────────────
                                RowLayout {
                                    visible: instDelegate.hatBauteil
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 42; anchors.rightMargin: 10
                                    height: 22; spacing: 6

                                    Text { text: "🔌"; font.pixelSize: 9 }
                                    Text {
                                        text: gkd.bauteilBez || ""
                                        font.pixelSize: 10; font.weight: Font.Medium
                                        color: root.theme.textSecondary; elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: gkd.bauteilHersteller || ""
                                        font.pixelSize: 10; color: root.theme.textMuted
                                        elide: Text.ElideRight; Layout.maximumWidth: 80
                                    }
                                    // "Anderes…" Link
                                    Text {
                                        text: qsTr("Anderes…")
                                        font.pixelSize: 10; color: root.theme.accent
                                        font.underline: andHover.containsMouse
                                        HoverHandler { id: andHover }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: svPicker.oeffnen(gkd.id)
                                        }
                                    }
                                    // "× Aufheben"
                                    Rectangle {
                                        width: 18; height: 18; radius: 3
                                        color: aufhebHover.containsMouse ? "#3a1111" : "transparent"
                                        HoverHandler { id: aufhebHover }
                                        Text {
                                            anchors.centerIn: parent; text: "×"
                                            font.pixelSize: 12
                                            color: aufhebHover.containsMouse ? "#ff6666" : root.theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                db.geraetekastenBauteilSetzen(gkd.id, 0)
                                                root.laden()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    DebugLabel { panelName: qsTr("Geraetekasten-Ansicht"); visible: root.debug }
}
