import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    required property var editor

    color:  editor.theme.sidebar

    // SYMBOL-ANKER-01: prüft, ob ein Pin bei jeder 90°-Rotation aufs
    // 4mm-Platzierraster fällt. Platziert/verschoben wird über den
    // Anker-Pin (= erster Pin der Liste, CanvasGeometrie.ankerPinFuerSymbolId),
    // Rotation dreht um den Bbox-Mittelpunkt (pinWeltPos) — entscheidend ist
    // daher nicht der Abstand zur Mitte, sondern der Abstand **zum
    // Anker-Pin** auf jeder Achse: der Term "-0,5" (Mittelpunkt) kürzt sich
    // beim Vergleich zweier Pins exakt heraus, es bleibt
    // (pin.x - anker.x) × Breite bzw. (pin.y - anker.y) × Höhe. Beide
    // müssen ein Vielfaches von 4mm sein, sonst bleibt der Pin bei Rotation
    // nicht am Anker-Pin ausgerichtet (siehe
    // konzept/features/04_symbolsystem.md §13/ARD-GRID-01).
    function pinAufRaster(pin, idx) {
        if (!pin || idx === 0) return true
        var anker = (root.editor.pins && root.editor.pins.length > 0) ? root.editor.pins[0] : pin
        function vielfachesVon4(mm) {
            var eps = 0.02
            var r = mm % 4
            if (r < 0) r += 4
            return r < eps || r > 4 - eps
        }
        var offXmm = (pin.x - anker.x) * root.editor.breiteMm
        var offYmm = (pin.y - anker.y) * root.editor.hoeheMm
        return vielfachesVon4(offXmm) && vielfachesVon4(offYmm)
    }

    ColumnLayout {
        anchors { fill: parent; margins: 8 }
        spacing: 4

        // Header
        RowLayout {
            Text { text: qsTr("Pins:"); font.pixelSize: 12; font.weight: Font.Medium; color: root.editor.theme.textPrimary }
            Text { text: "  " + qsTr("Name"); width: 56; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Text { text: qsTr("x (mm)");    width: 62; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Text { text: qsTr("y (mm)");    width: 62; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Text { text: qsTr("Richtung"); width: 96; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Text {
                text: qsTr("Signaltyp")
                width: 95; font.pixelSize: 10; color: root.editor.theme.textMuted
                ToolTip.visible: sigHeaderHover.hovered
                ToolTip.delay: 400
                ToolTip.text: qsTr("Steuert u.a. die Farbdarstellung der angeschlossenen Ader/Leitung (z.B. \"power\" = L-Leiter, \"pe\"/\"n\" = Schutz-/Neutralleiter, \"dc_plus\"/\"dc_minus\" = Gleichspannung, \"input_*\"/\"output_*\" = SPS-Ein-/Ausgänge).")
                HoverHandler { id: sigHeaderHover }
            }
            Text {
                text: qsTr("Rolle")
                width: 78; font.pixelSize: 10; color: root.editor.theme.textMuted
                ToolTip.visible: rolleHeaderHover.hovered
                ToolTip.delay: 400
                ToolTip.text: qsTr("Pin-Rolle (NETZTEIL-ROLLE-01): überschreibt für genau diesen Pin die Symbol-Rolle. \"Quelle\" macht den Signaltyp dieses Pins zu einer festen Netz-Quelle (z.B. Ausgangspin eines SPS-Kanals) – ohne diese Überschreibung hat der gewählte Signaltyp keine Wirkung auf die Netzberechnung.")
                HoverHandler { id: rolleHeaderHover }
            }
            Text {
                text: qsTr("Kn.-Gr.")
                width: 60; font.pixelSize: 10; color: root.editor.theme.textMuted
                ToolTip.visible: knGrHeaderHover.hovered
                ToolTip.delay: 400
                ToolTip.text: qsTr("Knoten-Gruppe: Pins mit unterschiedlicher Zahl gelten in der Netzberechnung als getrennte Anschlüsse desselben Symbols (z.B. bei Widerstand/Kondensator/Spule nötig, damit beide Pole nicht intern kurzgeschlossen erscheinen). Gleiche Zahl (Default 0) = Pins gelten als intern verbunden, wie bei Klemme/Schalter.")
                HoverHandler { id: knGrHeaderHover }
            }
            Item { Layout.fillWidth: true }

            Button {
                text: "↔ H"; implicitHeight: 24; implicitWidth: 40
                ToolTip.visible: hovered; ToolTip.delay: 600
                ToolTip.text: qsTr("Waagerecht: Pin 1 links (0 mm), Pin 2 rechts (%1 mm)").arg(root.editor.breiteMm)
                onClicked: {
                    root.editor.pushUndoSnapshot()
                    var yMid = 0.5
                    var kg2 = root.editor.rolleText === "verbraucher" ? 1 : 0
                    root.editor.pins = [
                        {name:"1", x:0.0, y:yMid, offenX:-1, offenY:0, signaltyp:"neutral", kontext:"", knotenGruppe:0},
                        {name:"2", x:1.0, y:yMid, offenX:1,  offenY:0, signaltyp:"neutral", kontext:"", knotenGruppe:kg2}
                    ]
                    root.editor.ausgewaehltPinIdx = -1
                    root.editor.repaintAll()
                }
                background: Rectangle { color: parent.hovered ? root.editor.theme.badge : "transparent"; radius: 4; border.color: root.editor.theme.accent; border.width: 1 }
                contentItem: Text { text: parent.text; color: root.editor.theme.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            Button {
                text: "↕ V"; implicitHeight: 24; implicitWidth: 40
                ToolTip.visible: hovered; ToolTip.delay: 600
                ToolTip.text: qsTr("Senkrecht: Pin 1 oben (0 mm), Pin 2 unten (%1 mm)").arg(root.editor.hoeheMm)
                onClicked: {
                    root.editor.pushUndoSnapshot()
                    var xMid = 0.5
                    var kg2 = root.editor.rolleText === "verbraucher" ? 1 : 0
                    root.editor.pins = [
                        {name:"1", x:xMid, y:0.0, offenX:0, offenY:-1, signaltyp:"neutral", kontext:"", knotenGruppe:0},
                        {name:"2", x:xMid, y:1.0, offenX:0, offenY:1,  signaltyp:"neutral", kontext:"", knotenGruppe:kg2}
                    ]
                    root.editor.ausgewaehltPinIdx = -1
                    root.editor.repaintAll()
                }
                background: Rectangle { color: parent.hovered ? root.editor.theme.badge : "transparent"; radius: 4; border.color: root.editor.theme.accent; border.width: 1 }
                contentItem: Text { text: parent.text; color: root.editor.theme.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }

        // SE-VERBRAUCHER-WARNUNG-01: proaktiver Hinweis statt der Fehlerklasse,
        // die im Symboleditor-Audit mehrfach gefunden wurde (Verbraucher-Symbol
        // mit zwei Pins in derselben Knoten-Gruppe, s. konzept/features/
        // 04_symbolsystem.md §21) - direkt im Editor sichtbar statt erst per
        // Migration/DB-Audit im Nachhinein.
        Rectangle {
            Layout.fillWidth: true
            visible: root.editor.gemeinsameKnotenBeiVerbraucher()
            implicitHeight: warnRow.implicitHeight + 6
            color: "#40331a"; radius: 4; border.color: "#cc8800"; border.width: 1
            Row {
                id: warnRow
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 }
                spacing: 6
                Text { text: "⚠"; color: "#ffbb44"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: qsTr("Verbraucher mit gemeinsamer Knoten-Gruppe – zwei Pins gelten dadurch als intern kurzgeschlossen. Meist ungewollt, prüfen ob das so beabsichtigt ist.")
                    color: "#ffbb44"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        ListView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            model: root.editor.pins
            clip:  true

            delegate: Rectangle {
                width:  ListView.view.width; height: 30; radius: 3
                color:  (root.editor.ausgewaehltPinIdx === index || root.editor.multiPins.indexOf(index) >= 0) ? root.editor.theme.badge : "transparent"

                property int myIdx: index
                property var myPin: root.editor.pins[index] || {}

                TapHandler {
                    onTapped: {
                        root.editor.ausgewaehltPinIdx  = myIdx
                        root.editor.ausgewaehltPrimIdx = -1
                        root.editor.repaintAll()
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4; leftPadding: 4

                    TextField {
                        width: 54; height: 30; font.pixelSize: 11
                        text: parent.parent.myPin.name || ""
                        background: Rectangle { color: root.editor.theme.inputBg; radius: 3; border.color: root.editor.theme.border }
                        color: root.editor.theme.textPrimary
                        onEditingFinished: {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.name = text; arr[parent.parent.myIdx] = p; root.editor.pins = arr
                        }
                    }

                    TextField {
                        width: 58; height: 30; font.pixelSize: 11
                        text: root.editor.normToMmX(parent.parent.myPin.x !== undefined ? parent.parent.myPin.x : 0).toFixed(2)
                        validator: DoubleValidator { bottom: 0; top: root.editor.breiteMm; decimals: 2 }
                        background: Rectangle { color: root.editor.theme.inputBg; radius: 3; border.color: root.editor.theme.border }
                        color: root.editor.theme.textPrimary
                        onEditingFinished: {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.x = (parseFloat(text)||0) / root.editor.breiteMm
                            arr[parent.parent.myIdx] = p; root.editor.pins = arr
                            root.editor.repaintAll()
                        }
                    }

                    TextField {
                        width: 58; height: 30; font.pixelSize: 11
                        text: root.editor.normToMmY(parent.parent.myPin.y !== undefined ? parent.parent.myPin.y : 0.5).toFixed(2)
                        validator: DoubleValidator { bottom: 0; top: root.editor.hoeheMm; decimals: 2 }
                        background: Rectangle { color: root.editor.theme.inputBg; radius: 3; border.color: root.editor.theme.border }
                        color: root.editor.theme.textPrimary
                        onEditingFinished: {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.y = (parseFloat(text)||0.5) / root.editor.hoeheMm
                            arr[parent.parent.myIdx] = p; root.editor.pins = arr
                            root.editor.repaintAll()
                        }
                    }

                    // Richtung (offen-Vektor)
                    Row {
                        spacing: 2
                        Repeater {
                            model: [{l:"←",ox:-1,oy:0},{l:"→",ox:1,oy:0},{l:"↑",ox:0,oy:-1},{l:"↓",ox:0,oy:1}]
                            delegate: Rectangle {
                                width: 22; height: 30; radius: 3
                                property var outerPin: parent.parent.parent.myPin
                                property int outerIdx: parent.parent.parent.myIdx
                                color: (outerPin.offenX===modelData.ox && outerPin.offenY===modelData.oy)
                                       ? root.editor.theme.accent
                                       : (dirHover.hovered ? root.editor.theme.badge : "transparent")
                                Text {
                                    anchors.centerIn: parent; text: modelData.l; font.pixelSize: 13
                                    color: (parent.outerPin.offenX===modelData.ox && parent.outerPin.offenY===modelData.oy) ? "white" : root.editor.theme.textPrimary
                                }
                                HoverHandler { id: dirHover }
                                TapHandler {
                                    onTapped: {
                                        var arr = root.editor.pins.slice()
                                        var p   = Object.assign({}, arr[parent.outerIdx])
                                        p.offenX = modelData.ox; p.offenY = modelData.oy
                                        arr[parent.outerIdx] = p; root.editor.pins = arr
                                        root.editor.repaintAll()
                                    }
                                }
                            }
                        }
                    }

                    // SYMBOL-ANKER-01: Warnung wenn der Pin bei Rotation
                    // nicht aufs 4mm-Raster fällt.
                    Rectangle {
                        width: 20; height: 30; radius: 3; color: "transparent"
                        visible: !root.pinAufRaster(parent.parent.myPin, parent.parent.myIdx)
                        Text {
                            anchors.centerIn: parent; text: "⚠"; font.pixelSize: 13; color: "#ffaa00"
                        }
                        ToolTip.visible: warnHover.hovered
                        ToolTip.delay: 300
                        ToolTip.text: qsTr("Pin fällt bei Rotation nicht aufs 4mm-Platzierraster: Abstand vom Symbol-Mittelpunkt muss auf beiden Achsen ein Vielfaches von 4mm sein.")
                        HoverHandler { id: warnHover }
                    }

                    ComboBox {
                        id: sigCombo
                        width: 140; height: 30
                        model: ["neutral","power","pe","n","dc_plus","dc_minus","input_digital","output_digital","input_analog","output_analog","kommunikation","temp","stepper","sicherheit","fe"]
                        font.pixelSize: 10
                        // Anzeige-Label je Schlüssel – gespeicherter Wert bleibt der Rohschlüssel
                        // SE-SIGNALTYP-LABEL-01: rohe Schlüssel wie "input_analog"
                        // waren bisher unübersetzt sichtbar - kurze, gebräuchliche
                        // Abkürzungen statt Rohwert, analog zum bestehenden BMK-Seite-/
                        // Linienart-label()-Muster. Gespeicherter Wert bleibt der Rohschlüssel.
                        function labelFuer(key) {
                            switch (key) {
                            case "power":          return "L"
                            case "pe":             return "PE"
                            case "n":              return "N"
                            case "dc_plus":        return "DC+"
                            case "dc_minus":       return "DC-"
                            case "input_digital":  return "DI"
                            case "output_digital": return "DO"
                            case "input_analog":   return "AI"
                            case "output_analog":  return "AO"
                            case "kommunikation":  return qsTr("Kom.")
                            case "temp":           return qsTr("Temp.")
                            case "stepper":        return qsTr("Schritt")
                            case "sicherheit":     return qsTr("Sicherheit")
                            case "fe":             return "FE"
                            default:               return qsTr("Neutral")
                            }
                        }
                        displayText: labelFuer(currentText)
                        currentIndex: {
                            var st = parent.parent.myPin.signaltyp || "neutral"
                            var i2 = model.indexOf(st); return i2 >= 0 ? i2 : 0
                        }
                        onActivated: function(idx) {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.signaltyp = model[idx]; arr[parent.parent.myIdx] = p; root.editor.pins = arr
                        }
                        delegate: ItemDelegate {
                            width: sigCombo.width
                            highlighted: sigCombo.highlightedIndex === index
                            contentItem: Text { text: sigCombo.labelFuer(modelData); font.pixelSize: 10;
                                                 color: root.editor.theme.textPrimary; leftPadding: 6;
                                                 verticalAlignment: Text.AlignVCenter }
                        }
                        background: Rectangle { color: root.editor.theme.inputBg; border.color: root.editor.theme.border; radius: 4 }
                        contentItem: Text { text: parent.displayText; color: root.editor.theme.textPrimary; font.pixelSize: 10;
                                            leftPadding: 6; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    }

                    ComboBox {
                        id: rolleCombo
                        width: 78; height: 30
                        model: ["", "quelle", "verbraucher"]
                        font.pixelSize: 10
                        function labelFuer(key) {
                            if (key === "quelle") return qsTr("Quelle")
                            if (key === "verbraucher") return qsTr("Verbr.")
                            return qsTr("Erben")
                        }
                        displayText: labelFuer(currentText)
                        currentIndex: {
                            var r = parent.parent.myPin.rolle || ""
                            var i3 = model.indexOf(r); return i3 >= 0 ? i3 : 0
                        }
                        onActivated: function(idx) {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.rolle = model[idx]; arr[parent.parent.myIdx] = p; root.editor.pins = arr
                        }
                        delegate: ItemDelegate {
                            width: rolleCombo.width
                            highlighted: rolleCombo.highlightedIndex === index
                            contentItem: Text { text: rolleCombo.labelFuer(modelData); font.pixelSize: 10;
                                                 color: root.editor.theme.textPrimary; leftPadding: 6;
                                                 verticalAlignment: Text.AlignVCenter }
                        }
                        background: Rectangle { color: root.editor.theme.inputBg; border.color: root.editor.theme.border; radius: 4 }
                        contentItem: Text { text: parent.displayText; color: root.editor.theme.textPrimary; font.pixelSize: 10;
                                            leftPadding: 6; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    }

                    TextField {
                        width: 60; height: 30; font.pixelSize: 14
                        text: (parent.parent.myPin.knotenGruppe !== undefined ? parent.parent.myPin.knotenGruppe : 0).toString()
                        // top:9 war zu eng für Boards mit vielen unabhängigen Pins
                        // (Arduino: ~27 Knoten, s. konzept/features/04_symbolsystem.md §9).
                        validator: IntValidator { bottom: 0; top: 99 }
                        horizontalAlignment: Text.AlignHCenter
                        background: Rectangle { color: root.editor.theme.inputBg; radius: 3; border.color: root.editor.theme.border }
                        color: root.editor.theme.textPrimary
                        ToolTip.visible: hovered
                        ToolTip.delay: 600
                        ToolTip.text: qsTr("Knoten-Gruppe (0 = mit anderen Pins gleicher Gruppe intern verbunden)")
                        onEditingFinished: {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.knotenGruppe = parseInt(text) || 0
                            arr[parent.parent.myIdx] = p; root.editor.pins = arr
                        }
                    }

                    Rectangle {
                        width: 22; height: 30; radius: 3
                        color: delHover.hovered ? "#3a1a1a" : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: "#ff4444" }
                        HoverHandler { id: delHover }
                        TapHandler {
                            onTapped: {
                                var myI = parent.parent.parent.myIdx
                                root.editor.pushUndoSnapshot()
                                root.editor.pins = root.editor.pins.filter(function(_, i2) { return i2 !== myI })
                                if (root.editor.ausgewaehltPinIdx >= root.editor.pins.length)
                                    root.editor.ausgewaehltPinIdx = -1
                                root.editor.repaintAll()
                            }
                        }
                    }
                }
            }
        }
    }
    DebugLabel { panelName: qsTr("SE Pin-Liste"); visible: editor.debug }
}
