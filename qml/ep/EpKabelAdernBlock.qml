import QtQuick
import QtQuick.Layouts

Column {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width: parent ? parent.width : 0
    spacing: 0

    property bool _expanded: true

    // KABEL-ADERFARBE-PROPAGATION-02: "Dieser Linie zugeordnet" zeigt NICHT
    // die statische Ader-Roster-Liste des Kabeltyps (extra_daten.adern —
    // die bleibt unverändert, auch wenn die Linie gar keine Verbindung mehr
    // kreuzt), sondern nur die Adern, die AKTUELL an einer echten Kreuzung
    // hängen — via der geteilten CanvasGeometrie.qml::
    // kabelAktiveAderZuordnungen() (auch von CanvasCacheHandler.qml::
    // kabelAderSynchronisieren() beim Speichern genutzt, s. dort).
    //
    // panel._refresh als Dummy-Abhängigkeit nötig (wie überall sonst in
    // diesem EP-Panel, s. EigenschaftenPanel.qml::onGeaendert()) — die
    // Netz-/Kreuzungsberechnung sind reine C++/JS-Aufrufe ohne eigenes
    // QML-Property-Binding, ohne die Abhängigkeit würde sich die Liste
    // nicht neu berechnen, wenn die Linie verschoben wird.
    readonly property var zugewieseneAdern: {
        // AOT-Fallstrick (s. EigenschaftenPanel.qml): "* 0" hält die
        // panel._refresh-Abhängigkeit im kompilierten Binding, ohne den
        // Zähler selbst zu verändern — ein reiner, nirgends genutzter
        // Lese-Zugriff würde vom qmlcachegen sonst wegoptimiert.
        if (panel._refresh * 0 !== 0 || !panel.el || panel.el.typ !== "kabellinie") return []
        var netze = panel.canvas.netzberechnung.autoNetzeBerechnenCached()
        return panel.canvas.geometrie.kabelAktiveAderZuordnungen(panel.el, netze, true)
    }

    // KABEL-LINIEN-KOMPAKT-01 (Aug 2026): Kabel-weite freie Adern, vorher im
    // KABEL-LINIEN-Abschnitt versteckt — Nutzerwunsch, das direkt hier zu
    // sehen wo man ohnehin auf die Adern dieser Linie schaut.
    readonly property var freieAdern: {
        var kabelId = panel.el && panel.el.extraDaten
                      ? (panel.el.extraDaten.kabelId || 0) : 0
        return kabelId > 0 ? db.kabelFreieAderLaden(kabelId + (panel._refresh * 0)) : []
    }

    // KABEL-ADERN header (toggle)
    Item {
        width: parent.width; height: 26
        Rectangle {
            anchors.fill: parent
            color: klAdernHover.containsMouse ? root.theme.hover : "transparent"
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 4
            Text {
                text: qsTr("KABEL-ADERN")
                font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                color: root.theme.borderLight; Layout.fillWidth: true
            }
            Text {
                text: root._expanded ? "▾" : "▸"
                font.pixelSize: 11; color: root.theme.borderLight
                verticalAlignment: Text.AlignVCenter
            }
        }
        MouseArea {
            id: klAdernHover
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root._expanded = !root._expanded
        }
    }

    // Collapsible content
    Item {
        width: parent.width
        height: root._expanded ? adernInhaltCol.implicitHeight : 0
        clip: true
        Column {
            id: adernInhaltCol
            width: parent.width; spacing: 0

            Text {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 4
                text: qsTr("Dieser Linie zugeordnet:")
                color: root.theme.textMuted; font.pixelSize: 10; font.italic: true
            }
            Repeater {
                model: root.zugewieseneAdern
                delegate: Rectangle {
                    width: parent ? parent.width - 16 : 0
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    height: 24; radius: 3
                    color: root.theme.inputBg
                    border.color: root.theme.border
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            visible: (modelData.farbe || "") !== ""
                            color: panel.canvas.iecFarbe(modelData.farbe || "")
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
                            color: root.theme.textSecondary
                            font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
            }
            Text {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                visible: {
                    var kabelId = panel.el && panel.el.extraDaten
                                  ? (panel.el.extraDaten.kabelId || 0) : 0
                    if (kabelId <= 0) return false
                    return root.zugewieseneAdern.length === 0
                }
                text: qsTr("Keine Adern zugeordnet.")
                color: root.theme.textMuted; font.pixelSize: 10; font.italic: true
            }

            Item { height: root.freieAdern.length > 0 ? 8 : 0 }

            Text {
                width: parent.width - 16
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.freieAdern.length > 0
                text: qsTr("Frei (Kabel-weit, %1):").arg(root.freieAdern.length)
                color: root.theme.textMuted; font.pixelSize: 10; font.italic: true
            }
            Repeater {
                model: root.freieAdern
                delegate: Rectangle {
                    width: parent ? parent.width - 16 : 0
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    height: 24; radius: 3
                    color: "transparent"
                    border.color: root.theme.border
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            visible: (modelData.farbe || "") !== ""
                            color: panel.canvas.iecFarbe(modelData.farbe || "")
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
                            color: root.theme.textMuted
                            font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
            }
            Item { height: 8 }
        }
    }
}
