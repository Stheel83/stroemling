import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ============================================================
// BauteilKabelPickerDialog – Kabel-Bibliothekseintrag auswählen
// Zeigt alle bauteil_kabel-Einträge mit Kabeltyp, Aderzahl × Querschnitt
// und farbiger Ader-Vorschau.  Erste Zeile: „– kein Bauteil-Kabel –"
// zum Aufheben der Zuweisung.
// ============================================================

Dialog {
    id: root

    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 420
    height: 460
    padding: 16

    required property var theme

    // Ergebnis – wird gesetzt wenn der Nutzer „Übernehmen" klickt
    property int ausgewaehltId: 0       // 0 = kein Bauteil-Kabel
    property string ausgewaehltTyp: ""

    title: qsTr("Kabel aus Bauteilbibliothek wählen")

    background: Rectangle {
        color: theme.sidebar
        border.color: theme.border
        border.width: 1; radius: 6
    }

    // IEC-60757-Code → Hex-Farbe (lokale Kopie für den Dialog)
    function iecZuHex(code) {
        if (code === "BK")   return "#222222"
        if (code === "BN")   return "#7b3f00"
        if (code === "RD")   return "#cc0000"
        if (code === "OG")   return "#ff6600"
        if (code === "YE")   return "#ccaa00"
        if (code === "GN")   return "#006600"
        if (code === "BU")   return "#0044cc"
        if (code === "VT")   return "#880099"
        if (code === "GY")   return "#666666"
        if (code === "WH")   return "#dddddd"
        if (code === "PK")   return "#ff88aa"
        return "#4a9eff"
    }

    property int selIdx: -1         // -1 = „kein Bauteil-Kabel"-Zeile
    property var kabelListe: []    // Caller setzt dies vor open()

    contentItem: ColumnLayout {
        spacing: 10

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Liste ──────────────────────────────────────────────
        ListView {
            id: liste
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.kabelListe

            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Text {
                anchors.centerIn: parent
                visible: liste.count === 0
                text: qsTr("Keine Kabel in der Bibliothek.\nIn der Bauteilbibliothek ein Kabel anlegen.")
                color: theme.textMuted
                font.pixelSize: 11; font.italic: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width - 20
            }

            // Kopf-Eintrag: „kein Bauteil-Kabel"
            header: Rectangle {
                width: liste.width
                height: 36
                color: root.selIdx === -1
                       ? theme.activeItem
                       : (keinHover.hovered ? theme.hover : "transparent")
                radius: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 10
                    text: qsTr("– kein Bauteil-Kabel –")
                    color: theme.textMuted
                    font.pixelSize: 12; font.italic: true
                }
                HoverHandler { id: keinHover }
                TapHandler { onTapped: root.selIdx = -1 }
            }

            delegate: Rectangle {
                width: liste.width
                height: 44
                color: root.selIdx === index
                       ? theme.activeItem
                       : (rowHover.hovered ? theme.hover : "transparent")
                radius: 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 8
                    spacing: 8

                    // Farbpunkte der Adern (max 8)
                    Row {
                        spacing: 2
                        Repeater {
                            model: {
                                var adr = modelData.adern || []
                                return adr.length > 8 ? adr.slice(0, 8) : adr
                            }
                            Rectangle {
                                width: 10; height: 10; radius: 2
                                color: root.iecZuHex(modelData ? modelData.farbe : "")
                                border.color: "#000000"; border.width: 0.5
                            }
                        }
                    }

                    // Bezeichnung + Kabeltyp
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: {
                                var s = modelData.bezeichnung || ""
                                if (modelData.kabeltyp) s += (s ? "  " : "") + modelData.kabeltyp
                                return s
                            }
                            color: theme.textPrimary
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: (modelData.aderzahl || 0) > 0 || (modelData.querschnittMm2 || 0) > 0
                            text: {
                                var s = ""
                                if (modelData.aderzahl > 0) s += modelData.aderzahl + " × "
                                if (modelData.querschnittMm2 > 0)
                                    s += (modelData.querschnittMm2 + "").replace(".", ",") + " mm²"
                                return s
                            }
                            color: theme.textMuted
                            font.pixelSize: 10
                        }
                    }
                }

                HoverHandler { id: rowHover }
                TapHandler { onTapped: root.selIdx = index }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Buttons ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: qsTr("Abbrechen"); flat: true; implicitHeight: 32
                contentItem: Text {
                    text: parent.text
                    color: theme.textMuted
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? theme.hover : "transparent"; radius: 4
                }
                onClicked: root.reject()
            }
            Button {
                text: qsTr("Übernehmen"); implicitWidth: 110; implicitHeight: 32
                contentItem: Text {
                    text: parent.text
                    color: theme.textPrimary
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? theme.accent : theme.inputBg
                    radius: 4; border.color: theme.accent
                }
                onClicked: {
                    if (root.selIdx === -1) {
                        root.ausgewaehltId  = 0
                        root.ausgewaehltTyp = ""
                    } else {
                        var m = root.kabelListe[root.selIdx]
                        root.ausgewaehltId  = m ? (m.id || 0) : 0
                        root.ausgewaehltTyp = m ? (m.kabeltyp || "") : ""
                    }
                    root.accept()
                }
            }
        }
    }

    onOpened: {
        root.selIdx = -1
    }
}
