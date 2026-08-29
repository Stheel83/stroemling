import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

SplitView {
    id: root
    required property var panel
    required property var theme
    property bool debug: false

    signal kabelGewaehlt(int seiteId, int elementId, real x1, real y1)

    orientation: Qt.Horizontal

    handle: Rectangle {
        implicitWidth: 5
        color: SplitHandle.pressed ? theme.accent
             : SplitHandle.hovered  ? theme.activeItem : theme.border
    }

    // Linke Spalte: Kabelliste
    Item {
        SplitView.preferredWidth: 220
        SplitView.minimumWidth:   150

        DebugLabel { panelName: qsTr("IBN-KabelSplit"); visible: root.debug }

        ScrollView {
            anchors.fill: parent; clip: true

            ListView {
                id: kabelListe
                width: parent.width; clip: true

            property var _gelistet: panel._gefilterteKabelListe()
            model: _gelistet

            Text {
                anchors.centerIn: parent
                visible: kabelListe.count === 0
                text: panel._kabelListe.length === 0
                      ? qsTr("Keine Kabel im Projekt.")
                      : qsTr("Kein Treffer.")
                color: theme.textMuted; font.pixelSize: 11; font.italic: true
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                width: parent.width - 24
            }

            delegate: Rectangle {
                width: kabelListe.width; height: 48
                color: panel.kabelAusgewaehlterIndex === index
                       ? theme.activeItemAlt
                       : (kabelHover.hovered ? theme.hover : "transparent")
                HoverHandler { id: kabelHover }
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                    spacing: 8
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: panel._statusFarbe(modelData.status)
                        Layout.alignment: Qt.AlignVCenter
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text {
                            text: modelData.bezeichnung || qsTr("(kein Name)")
                            font.pixelSize: 13; font.bold: true
                            color: theme.textPrimary
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            text: {
                                var t = modelData.kabeltyp || ""
                                var n = modelData.aderzahl || 0
                                var q2 = modelData.querschnittMm2 || 0
                                var parts = []
                                if (t) parts.push(t)
                                if (n > 0) parts.push(n + "×" + q2 + " mm²")
                                return parts.join("  ")
                            }
                            font.pixelSize: 10; color: theme.textMuted
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.kabelAusgewaehlterIndex = index
                        if (modelData.grafikElementId > 0 && modelData.seiteId > 0)
                            root.kabelGewaehlt(modelData.seiteId, modelData.grafikElementId,
                                               modelData.x1, modelData.y1)
                    }
                }
            }
        }
        }
    }

    // Rechte Spalte: Kabel-Detailformular
    ScrollView {
        SplitView.fillWidth: true; SplitView.minimumWidth: 200
        contentWidth: availableWidth; clip: true
        background: Rectangle { color: theme.sidebar }

        ColumnLayout {
            width: parent.width; spacing: 0

            Item {
                visible: panel.kabelAusgewaehlterIndex < 0
                Layout.fillWidth: true; height: 120
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Kabel auswählen")
                    color: theme.textMuted; font.pixelSize: 12; font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            ColumnLayout {
                visible: panel.kabelAusgewaehlterIndex >= 0
                Layout.fillWidth: true; Layout.margins: 12; spacing: 8

                // Kabel-Titel
                Text {
                    text: {
                        var fl = kabelListe._gelistet
                        if (!fl || panel.kabelAusgewaehlterIndex < 0 || panel.kabelAusgewaehlterIndex >= fl.length) return ""
                        return fl[panel.kabelAusgewaehlterIndex].bezeichnung || qsTr("(kein Name)")
                    }
                    font.pixelSize: 15; font.bold: true; color: theme.accent
                    Layout.fillWidth: true
                }
                // Info-Zeilen (read-only)
                Text {
                    text: {
                        var fl = kabelListe._gelistet
                        if (!fl || panel.kabelAusgewaehlterIndex < 0 || panel.kabelAusgewaehlterIndex >= fl.length) return ""
                        var k = fl[panel.kabelAusgewaehlterIndex]
                        var parts = []
                        if (k.kabeltyp) parts.push(k.kabeltyp)
                        if (k.aderzahl > 0) parts.push(k.aderzahl + " Adern × " + k.querschnittMm2 + " mm²")
                        if (k.laengeM > 0) parts.push(k.laengeM + " m")
                        return parts.join("   ")
                    }
                    font.pixelSize: 11; color: theme.textMuted; Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
                Text {
                    text: {
                        var fl = kabelListe._gelistet
                        if (!fl || panel.kabelAusgewaehlterIndex < 0 || panel.kabelAusgewaehlterIndex >= fl.length) return ""
                        var k = fl[panel.kabelAusgewaehlterIndex]
                        if (!k.vonOrt && !k.nachOrt) return ""
                        return (k.vonOrt || "?") + "  →  " + (k.nachOrt || "?")
                    }
                    font.pixelSize: 11; color: theme.textMuted; Layout.fillWidth: true
                    visible: text !== ""
                }

                // ── PRÜFSTATUS ────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 6
                    Text { text: qsTr("PRÜFSTATUS"); font.pixelSize: 10; font.weight: Font.Medium; color: theme.textMuted }
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.alignment: Qt.AlignVCenter }
                }

                // Status
                Text { text: qsTr("Status"); color: theme.textMuted; font.pixelSize: 11 }
                ComboBox {
                    id: cmbKabelStatus
                    Layout.fillWidth: true; implicitHeight: 30
                    model: [
                        { key: "offen",         label: qsTr("Offen")      },
                        { key: "in_arbeit",     label: qsTr("In Arbeit")  },
                        { key: "abgeschlossen", label: qsTr("Fertig")     }
                    ]
                    textRole: "label"
                    background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                    contentItem: RowLayout {
                        spacing: 6
                        Item { width: 8 }
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: panel._statusFarbe(cmbKabelStatus.model[cmbKabelStatus.currentIndex]?.key ?? "offen")
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: cmbKabelStatus.displayText; color: theme.textPrimary
                            font.pixelSize: 12; verticalAlignment: Text.AlignVCenter
                            Layout.fillWidth: true
                        }
                    }
                    delegate: ItemDelegate {
                        width: cmbKabelStatus.width; implicitHeight: 28
                        highlighted: cmbKabelStatus.highlightedIndex === index
                        contentItem: RowLayout {
                            spacing: 6
                            Item { width: 8 }
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: panel._statusFarbe(modelData.key)
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text { text: modelData.label; color: theme.textPrimary;
                                   font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                        }
                        background: Rectangle { color: highlighted ? theme.hover : "transparent" }
                    }
                }

                // Aderliste
                Text {
                    text: qsTr("Adern")
                    color: theme.textMuted; font.pixelSize: 11
                    visible: panel._kabelAdern.length > 0
                }
                Rectangle {
                    visible: panel._kabelAdern.length > 0
                    Layout.fillWidth: true
                    height: Math.min(panel._kabelAdern.length * 22 + 4, 130)
                    color: theme.inputBg; radius: 4; border.color: theme.border
                    clip: true

                    Column {
                        anchors { fill: parent; margins: 4 }
                        spacing: 0

                        Repeater {
                            model: panel._kabelAdern
                            delegate: RowLayout {
                                width: parent.width; height: 22; spacing: 6
                                Text {
                                    text: modelData.aderNr
                                    font.pixelSize: 11; color: theme.textMuted
                                    Layout.preferredWidth: 20
                                }
                                Text {
                                    text: modelData.farbe || "–"
                                    font.pixelSize: 11; color: theme.textPrimary
                                    Layout.preferredWidth: 60; elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.bezeichnung || ""
                                    font.pixelSize: 11; color: theme.textSecondary
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                // ── PRÜFPROTOKOLL ─────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 6
                    Text { text: qsTr("PRÜFPROTOKOLL"); font.pixelSize: 10; font.weight: Font.Medium; color: theme.textMuted }
                    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.alignment: Qt.AlignVCenter }
                }

                // Notiz
                Text { text: qsTr("Notiz"); color: theme.textMuted; font.pixelSize: 11 }
                Rectangle {
                    Layout.fillWidth: true; height: 60
                    color: theme.inputBg; radius: 4; border.color: theme.border
                    TextArea {
                        id: taKabelNotiz
                        anchors { fill: parent; margins: 4 }
                        wrapMode: TextArea.Wrap; background: null
                        color: theme.textPrimary; font.pixelSize: 12
                        placeholderText: qsTr("Bemerkungen …")
                    }
                }

                GridLayout {
                    Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 4
                    Text { text: qsTr("Geprüft von"); color: theme.textMuted; font.pixelSize: 11 }
                    Text { text: qsTr("Datum");       color: theme.textMuted; font.pixelSize: 11 }
                    TextField {
                        id: tfKabelGeprueftVon; Layout.fillWidth: true; implicitHeight: 28
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }
                    TextField {
                        id: tfKabelGeprueftAm; Layout.fillWidth: true; implicitHeight: 28
                        placeholderText: "TT.MM.JJJJ"
                        background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border }
                        color: theme.textPrimary; font.pixelSize: 12
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.border; Layout.topMargin: 4 }

                Button {
                    Layout.fillWidth: true; text: qsTr("Speichern"); implicitHeight: 32
                    contentItem: Text { text: parent.text; color: theme.textPrimary;
                        font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter;
                        verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? theme.accent : theme.inputBg; radius: 4; border.color: theme.accent }
                    ToolTip.visible: hovered; ToolTip.delay: 500
                    ToolTip.text: qsTr("Status, Notiz, Prüfer und Datum speichern")
                    onClicked: {
                        var fl = kabelListe._gelistet
                        if (!fl || panel.kabelAusgewaehlterIndex < 0 || panel.kabelAusgewaehlterIndex >= fl.length) return
                        var k = fl[panel.kabelAusgewaehlterIndex]
                        var stKey = cmbKabelStatus.model[cmbKabelStatus.currentIndex].key
                        db.ibnKabelSpeichern(panel.projektId, k.kabelId,
                            stKey, taKabelNotiz.text.trim(),
                            tfKabelGeprueftVon.text.trim(),
                            tfKabelGeprueftAm.text.trim())
                        panel.kabelLaden()
                        var fl2 = panel._gefilterteKabelListe()
                        for (var i = 0; i < fl2.length; i++) {
                            if (fl2[i].kabelId === k.kabelId) {
                                panel.kabelAusgewaehlterIndex = i; break
                            }
                        }
                        meldungManager.zeigen(qsTr("Kabel-Eintrag gespeichert."), true)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: [
                            { key: "offen",         label: qsTr("Offen"),     farbe: "#666688" },
                            { key: "in_arbeit",     label: qsTr("In Arbeit"), farbe: "#e0b040" },
                            { key: "abgeschlossen", label: qsTr("✓ Fertig"),  farbe: "#44aa66" }
                        ]
                        delegate: Button {
                            Layout.fillWidth: true; implicitHeight: 26
                            contentItem: Text { text: modelData.label; color: "white";
                                font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter;
                                verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.hovered
                                ? Qt.darker(modelData.farbe, 1.2) : modelData.farbe; radius: 4 }
                            ToolTip.visible: hovered; ToolTip.delay: 500
                            ToolTip.text: qsTr("Status direkt auf '%1' setzen (nur Status, ohne Prüfer/Datum)").arg(modelData.label)
                            onClicked: {
                                var fl = kabelListe._gelistet
                                if (!fl || panel.kabelAusgewaehlterIndex < 0 || panel.kabelAusgewaehlterIndex >= fl.length) return
                                var k = fl[panel.kabelAusgewaehlterIndex]
                                db.ibnKabelStatusSetzen(k.kabelId, modelData.key)
                                panel.kabelLaden()
                                var fl2 = panel._gefilterteKabelListe()
                                for (var i = 0; i < fl2.length; i++) {
                                    if (fl2[i].kabelId === k.kabelId) {
                                        panel.kabelAusgewaehlterIndex = i; break
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 12 }
            }

            // Formular befüllen wenn Kabel-Selektion wechselt
            Connections {
                target: panel
                function onKabelAusgewaehlterIndexChanged() {
                    var fl = kabelListe._gelistet
                    if (!fl || panel.kabelAusgewaehlterIndex < 0
                            || panel.kabelAusgewaehlterIndex >= fl.length) return
                    var k = fl[panel.kabelAusgewaehlterIndex]
                    var si = ["offen","in_arbeit","abgeschlossen"].indexOf(k.status)
                    cmbKabelStatus.currentIndex = si >= 0 ? si : 0
                    taKabelNotiz.text           = k.notiz      || ""
                    tfKabelGeprueftVon.text     = k.geprueftVon || ""
                    tfKabelGeprueftAm.text      = k.geprueftAm  || ""
                    if (k.grafikElementId > 0) {
                        var det = db.kabelLinieDetails(k.grafikElementId)
                        panel._kabelAdern = det.adern || []
                    } else {
                        panel._kabelAdern = []
                    }
                }
            }
        }
    }

}
