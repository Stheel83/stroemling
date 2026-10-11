import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    objectName: "kabelRechner"

    property var  theme
    property bool debug: false

    property string material: "cu"        // "cu" | "al"

    // Breite des Eingabe-Panels (links); Inhalt = Breite - 2 × 16 px Rand
    readonly property int     panelBreite: 400
    readonly property var     erg:      kabelRechnerModel.ergebnis

    // Anwendungsfall-Vorlagen (Praxiswerte), aus dem C++-Modell
    readonly property var     vorlagen: kabelRechnerModel.vorlagen()
    // true, solange eine Vorlage Felder setzt – verhindert das Zurückspringen auf "Eigene Eingabe"
    property bool             vorlageWirdAngewendet: false

    function vorlageAnwenden(idx) {
        if (idx <= 0 || idx > vorlagen.length) return
        var v = vorlagen[idx - 1]
        vorlageWirdAngewendet = true
        // Betriebsart zuerst: ihr Handler überschreibt das Spannungsfeld
        betriebsartBox.currentIndex = v.betriebsart
        spannungZeile.feldText      = String(v.spannung).replace(".", ",")
        stromZeile.feldText         = String(v.strom).replace(".", ",")
        cosPhiZeile.feldText        = String(v.cosPhi.toFixed(2)).replace(".", ",")
        laengeZeile.feldText        = String(v.laenge).replace(".", ",")
        duMaxZeile.feldText         = String(v.duMaxProzent).replace(".", ",")
        verlegeartBox.currentIndex  = v.verlegeart
        schutzOrganTypBox.currentIndex = v.schutzOrganTyp
        schutzOrganStromFeld.text   = String(v.schutzOrganStrom).replace(".", ",")
        netzImpedanzZeile.feldText  = "0,30"
        vorlageWirdAngewendet = false
    }
    function vorlageManuellGeaendert() {
        if (!vorlageWirdAngewendet && vorlageBox.currentIndex !== 0)
            vorlageBox.currentIndex = 0
    }

    DebugLabel { panelName: qsTr("Kabelrechner"); visible: root.debug }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ───────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: theme.sidebar

            RowLayout {
                anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                spacing: 12

                Text {
                    text: qsTr("Kabelquerschnitt-Rechner")
                    font.pixelSize: 15
                    font.weight:    Font.Medium
                    color:          theme.textPrimary
                }

            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Haupt-Split ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            // ── Eingabe-Panel (links, Breite = root.panelBreite) ───────────
            Rectangle {
                Layout.preferredWidth: root.panelBreite
                Layout.fillHeight:     true
                color: theme.sidebar

                ScrollView {
                    anchors.fill:  parent
                    contentWidth:  root.panelBreite
                    clip:          true

                    Column {
                        x: 16; y: 16
                        width:   root.panelBreite - 32
                        spacing: 3

                        // ── Elektrische Parameter ────────────────────────
                        KrAbschnitt { titel: qsTr("ELEKTRISCHE PARAMETER"); theme: root.theme }

                        // Anwendungsfall (Praxis-Vorlagen); ohne hinterlegte Vorlagen ausgeblendet
                        RowLayout {
                            visible: root.vorlagen.length > 0
                            width: parent.width; height: 32; spacing: 8
                            Text { text: qsTr("Anwendung"); font.pixelSize: 12; color: theme.textPrimary; Layout.preferredWidth: 80 }
                            ComboBox {
                                id: vorlageBox
                                Layout.fillWidth: true; font.pixelSize: 12
                                model: {
                                    var m = [qsTr("Eigene Eingabe")]
                                    for (var i = 0; i < root.vorlagen.length; ++i) m.push(root.vorlagen[i].name)
                                    return m
                                }
                                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                                contentItem: Text { text: parent.displayText; color: theme.textPrimary; font.pixelSize: 12;
                                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                                onActivated: root.vorlageAnwenden(currentIndex)
                                // Liste so breit wie das Eingabe-Panel (ab Label), damit lange Namen lesbar sind
                                popup.x: -88
                                popup.width: root.panelBreite - 32
                            }
                            Item { Layout.preferredWidth: 28 }
                        }

                        // Betriebsart
                        RowLayout {
                            width: parent.width; height: 32; spacing: 8
                            Text { text: qsTr("Betriebsart"); font.pixelSize: 12; color: theme.textPrimary; Layout.preferredWidth: 80 }
                            ComboBox {
                                id: betriebsartBox
                                Layout.fillWidth: true; font.pixelSize: 12
                                model: [qsTr("AC einphasig"), qsTr("Drehstrom"), "DC"]
                                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                                contentItem: Text { text: parent.displayText; color: theme.textPrimary; font.pixelSize: 12;
                                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                                onCurrentIndexChanged: {
                                    if      (currentIndex === 0) spannungZeile.feldText = "230"
                                    else if (currentIndex === 1) spannungZeile.feldText = "400"
                                    else                         spannungZeile.feldText = ""
                                }
                            }
                            Item { Layout.preferredWidth: 28 }
                        }

                        KrZeile { id: stromZeile; onFeldTextChanged: root.vorlageManuellGeaendert(); label: qsTr("Strom I"); wert: "13"; einheit: "A"; theme: root.theme }

                        KrZeile {
                            id: spannungZeile; onFeldTextChanged: root.vorlageManuellGeaendert();
                            label: qsTr("Spannung U"); wert: "230"; einheit: "V"; theme: root.theme
                        }

                        KrZeile {
                            id: cosPhiZeile; onFeldTextChanged: root.vorlageManuellGeaendert();
                            visible: betriebsartBox.currentIndex !== 2
                            label: "cos φ"; wert: "1,00"; einheit: ""; theme: root.theme
                        }
                        Text {
                            visible: betriebsartBox.currentIndex !== 2
                            width: parent.width
                            leftPadding: 88
                            rightPadding: 28
                            font.pixelSize: 10
                            color: theme.textMuted
                            wrapMode: Text.Wrap
                            text: qsTr("Richtwerte: ohmsch (Heizung/Glühlampe) 1,0 · Asynchronmotor Volllast 0,8–0,85, Teillast/Leerlauf 0,5–0,7 (induktiv) · Leuchtstofflampe unkompensiert ~0,5 (induktiv), kompensiert ~0,9 · Schaltnetzteil ohne aktive PFC 0,5–0,7 (kapazitiv/verzerrt), mit PFC >0,95. Für diese Formel zählt nur der Betrag |cos φ| – induktiv/kapazitiv ändert nichts am Ergebnis, da nur der ohmsche Spannungsfall-Anteil berücksichtigt wird.")
                        }

                        KrZeile {
                            id: duMaxZeile; onFeldTextChanged: root.vorlageManuellGeaendert();
                            label: qsTr("ΔU max"); wert: "3"; einheit: "%"; theme: root.theme
                        }
                        Text {
                            width: parent.width
                            leftPadding: 88
                            rightPadding: 28
                            font.pixelSize: 10
                            color: theme.textMuted
                            wrapMode: Text.Wrap
                            text: qsTr("Empfehlung DIN VDE 0100-520 (Anhang, informativ): 3 % für Beleuchtung, 5 % für sonstige Verbraucher, ab Anlagenübergabepunkt. Für empfindliche Lasten (Motoranlauf, Elektronik) auch kleinere Werte sinnvoll.")
                        }

                        Item { height: 8 }

                        // ── Leitung ──────────────────────────────────────
                        KrAbschnitt { titel: qsTr("LEITUNG"); theme: root.theme }

                        KrZeile { id: laengeZeile; onFeldTextChanged: root.vorlageManuellGeaendert(); label: qsTr("Länge L"); wert: "25"; einheit: "m"; theme: root.theme }

                        // Material-Toggle
                        RowLayout {
                            width: parent.width; height: 32; spacing: 8
                            Text { text: qsTr("Material"); font.pixelSize: 12; color: theme.textPrimary; Layout.preferredWidth: 80 }
                            Rectangle {
                                Layout.fillWidth: true; height: 26; radius: 4
                                color: theme.inputBg; border.color: theme.border; border.width: 1
                                Row {
                                    anchors.fill: parent
                                    Rectangle {
                                        width: parent.width / 2; height: parent.height; radius: 4
                                        color: root.material === "cu" ? theme.accent : "transparent"
                                        Text { anchors.centerIn: parent; text: "Cu (γ 56)"; font.pixelSize: 11; color: root.material === "cu" ? "white" : theme.textMuted }
                                        MouseArea { anchors.fill: parent; onClicked: root.material = "cu"; cursorShape: Qt.PointingHandCursor }
                                    }
                                    Rectangle { width: 1; height: parent.height; color: theme.border }
                                    Rectangle {
                                        width: parent.width / 2 - 1; height: parent.height; radius: 4
                                        color: root.material === "al" ? theme.accent : "transparent"
                                        Text { anchors.centerIn: parent; text: "Al (γ 36)"; font.pixelSize: 11; color: root.material === "al" ? "white" : theme.textMuted }
                                        MouseArea { anchors.fill: parent; onClicked: root.material = "al"; cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }
                            Item { Layout.preferredWidth: 28 }
                        }

                        // Verlegeart
                        RowLayout {
                            width: parent.width; height: 32; spacing: 8
                            Text { text: qsTr("Verlegeart"); font.pixelSize: 12; color: theme.textPrimary; Layout.preferredWidth: 80 }
                            ComboBox {
                                id: verlegeartBox
                                Layout.fillWidth: true; font.pixelSize: 12
                                // Kurzcode + Kategorie (Norm-Gruppen DIN VDE 0298-4); Details in der Erklärung darunter
                                model: [qsTr("A1 · Gedämmte Wand"), qsTr("A2 · Gedämmte Wand"),
                                        qsTr("B1 · Rohr auf Wand"), qsTr("B2 · Rohr auf Wand"),
                                        qsTr("C · Direkt auf Wand"), qsTr("D · Im Erdboden"),
                                        qsTr("E · Frei in Luft"),
                                        qsTr("F · Luft, mit Berührung"), qsTr("G · Luft, mit Abstand")]
                                currentIndex: 3
                                popup.x: -88
                                popup.width: root.panelBreite - 32
                                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                                contentItem: Text { text: parent.displayText; color: theme.textPrimary; font.pixelSize: 12;
                                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            }
                            Item { Layout.preferredWidth: 28 }
                        }
                        // Verlegeart-Erklärung
                        Text {
                            width: parent.width
                            leftPadding: 88
                            rightPadding: 28
                            font.pixelSize: 10
                            color: theme.textMuted
                            wrapMode: Text.Wrap
                            text: {
                                var idx = verlegeartBox.currentIndex
                                var bez = [
                                    qsTr("Aderleitungen im Rohr in wärmegedämmter Wand"),
                                    qsTr("Mehradriges Kabel / Mantelleitung im Rohr in wärmegedämmter Wand"),
                                    qsTr("Aderleitungen im Rohr auf einer Wand"),
                                    qsTr("Mehradriges Kabel / Mantelleitung im Rohr auf einer Wand"),
                                    qsTr("Ein- oder mehradriges Kabel direkt auf einer Wand"),
                                    qsTr("Mehradriges Kabel im Rohr oder Kabelschacht im Erdboden"),
                                    qsTr("Mehradriges Kabel frei in Luft, Wandabstand ≥ 0,3 · d"),
                                    qsTr("Einadrige Kabel mit Berührung frei in Luft (ab 25 mm²)"),
                                    qsTr("Einadrige Kabel mit Abstand d frei in Luft (ab 25 mm²)")
                                ]
                                return bez[idx] || ""
                            }
                        }

                        Item { height: 8 }

                        // ── Umgebung ─────────────────────────
                        KrAbschnitt { titel: qsTr("UMGEBUNG"); theme: root.theme }

                        KrZeile { id: temperaturZeile; label: qsTr("Temperatur"); wert: "30"; einheit: "°C"; theme: root.theme }

                        RowLayout {
                            width: parent.width; height: 32; spacing: 8
                            Text { text: qsTr("Häufung"); font.pixelSize: 12; color: theme.textPrimary; Layout.preferredWidth: 80 }
                            ComboBox {
                                id: haefungBox
                                Layout.fillWidth: true; font.pixelSize: 12
                                model: [qsTr("1 (keine)"), "2", "3", "4", "5", "6+"]
                                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                                contentItem: Text { text: parent.displayText; color: theme.textPrimary; font.pixelSize: 12;
                                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            }
                            Item { Layout.preferredWidth: 28 }
                        }

                        Item { height: 8 }

                        // ── Schutzorgan ──────────────────────
                        KrAbschnitt { titel: qsTr("SCHUTZORGAN"); theme: root.theme }

                        RowLayout {
                            width: parent.width; height: 32; spacing: 8
                            Text { text: qsTr("Typ / I_n"); font.pixelSize: 12; color: theme.textPrimary; Layout.preferredWidth: 80 }
                            ComboBox {
                                id: schutzOrganTypBox; Layout.preferredWidth: 64; font.pixelSize: 12
                                model: ["B", "C", "D"]; currentIndex: 1
                                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                                contentItem: Text { text: parent.displayText; color: theme.textPrimary; font.pixelSize: 12;
                                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            }
                            NavTextField { id: schutzOrganStromFeld; Layout.fillWidth: true; text: "16"; font.pixelSize: 12; horizontalAlignment: TextInput.AlignRight
                                color: theme.textPrimary
                                background: Rectangle { color: theme.inputBg; radius: 4; border.color: theme.border } }
                            Text { text: "A"; font.pixelSize: 12; color: theme.textMuted; Layout.preferredWidth: 28 }
                        }

                        KrZeile {
                            id: netzImpedanzZeile; onFeldTextChanged: root.vorlageManuellGeaendert();
                            visible: betriebsartBox.currentIndex !== 2
                            label: qsTr("R_netz"); wert: "0,30"; einheit: "Ω"; theme: root.theme
                        }
                        Text {
                            visible: betriebsartBox.currentIndex !== 2
                            width: parent.width
                            leftPadding: 88
                            rightPadding: 28
                            font.pixelSize: 10
                            color: theme.textMuted
                            wrapMode: Text.Wrap
                            text: qsTr("Netzimpedanz am Einspeisepunkt für die Abschaltbedingung. 0,30 Ω ist eine Annahme, kein Normwert – näher am Transformator ist sie kleiner. Wenn bekannt: gemessenen Wert eintragen.")
                        }

                        Item { height: 16 }

                        // ── Berechnen ────────────────────────────────────
                        Button {
                            width:  parent.width
                            height: 36
                            text:   qsTr("Berechnen")
                            font.pixelSize: 13
                            contentItem: Text {
                                text: parent.text; font: parent.font
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment:   Text.AlignVCenter
                            }
                            background: Rectangle {
                                color:  parent.hovered ? Qt.darker(theme.accent, 1.15) : theme.accent
                                radius: 6
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            onClicked: {
                                kabelRechnerModel.material = (root.material === "cu") ? 0 : 1
                                kabelRechnerModel.strom    = parseFloat(stromZeile.feldText.replace(",", ".")) || 0
                                kabelRechnerModel.laenge   = parseFloat(laengeZeile.feldText.replace(",", ".")) || 0
                                kabelRechnerModel.betriebsart      = betriebsartBox.currentIndex
                                kabelRechnerModel.spannung         = parseFloat(spannungZeile.feldText.replace(",", ".")) || 230
                                kabelRechnerModel.cosPhi           = parseFloat(cosPhiZeile.feldText.replace(",", ".")) || 1
                                kabelRechnerModel.duMaxProzent     = parseFloat(duMaxZeile.feldText.replace(",", ".")) || 3
                                kabelRechnerModel.verlegeart       = verlegeartBox.currentIndex
                                kabelRechnerModel.temperatur       = parseFloat(temperaturZeile.feldText.replace(",", ".")) || 30
                                kabelRechnerModel.haefung          = haefungBox.currentIndex
                                kabelRechnerModel.schutzOrganTyp   = schutzOrganTypBox.currentIndex
                                kabelRechnerModel.schutzOrganStrom = parseFloat(schutzOrganStromFeld.text.replace(",", ".")) || 16
                                var rn = parseFloat(netzImpedanzZeile.feldText.replace(",", "."))
                                kabelRechnerModel.netzImpedanz     = isNaN(rn) ? 0.3 : rn
                                kabelRechnerModel.berechnen()
                            }
                        }

                        Item { height: 20 }
                    }
                }
            }

            Rectangle { width: 1; Layout.fillHeight: true; color: theme.border }

            // ── Ergebnis-Panel (rechts) ───────────────────────────────────
            Rectangle {
                Layout.fillWidth:  true
                Layout.fillHeight: true
                color: theme.surface

                ScrollView {
                    id: resultSv
                    anchors { fill: parent; margins: 20 }
                    clip: true

                    Column {
                        width:   resultSv.availableWidth
                        spacing: 12

                        // ── Karte: Empfehlung ─────────────────────────────
                        Rectangle {
                            width:  parent.width
                            height: empCol.implicitHeight + 24
                            color:        theme.sidebar
                            border.color: theme.accent; border.width: 2
                            radius: 8

                            Column {
                                id: empCol
                                anchors { left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; top: parent.top; topMargin: 12 }
                                spacing: 4

                                Text {
                                    text: (erg && erg["thermikFehlt"])
                                          ? qsTr("Keine Empfehlung möglich")
                                          : (erg && erg["ueberTabelle"])
                                          ? qsTr("Kein Normquerschnitt ausreichend")
                                          : qsTr("Empfohlener Querschnitt")
                                    font.pixelSize: 11; font.weight: Font.Medium
                                    color: (erg && erg["ueberTabelle"]) ? "#e0a000" : theme.textMuted
                                }
                                Text {
                                    text: (erg && erg["gueltig"]) ? erg["querschnittText"] : "—"
                                    font.pixelSize: 40; font.weight: Font.Bold; color: theme.accent
                                }
                                Text {
                                    text: (erg && erg["gueltig"])
                                          ? erg["zusammenfassung"]
                                          : qsTr("Eingaben prüfen und Berechnen klicken")
                                    font.pixelSize: 12; color: theme.textMuted
                                }
                                Text {
                                    visible: !!(erg && erg["gueltig"])
                                    text: qsTr("Wirkleistung aufgenommen ≈ %1").arg((erg && erg["leistungText"]) ? erg["leistungText"] : "")
                                    font.pixelSize: 12; color: theme.textPrimary
                                }
                                Text {
                                    visible: !!(erg && erg["gueltig"])
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: qsTr("Hinweis: Auf dem Motortypenschild steht immer die abgegebene Wellenleistung. Die aufgenommene elektrische Leistung ist wegen des Wirkungsgrads höher.")
                                    font.pixelSize: 10; color: theme.textMuted
                                }
                                Text {
                                    visible: !!(erg && erg["ueberTabelle"])
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: (erg && erg["ueberTabelleGrund"]) ? erg["ueberTabelleGrund"] : ""
                                    font.pixelSize: 12; color: "#e0a000"
                                }
                            }
                        }

                        // ── Karte: Berechnungsdetails ─────────
                        Rectangle {
                            width:   parent.width
                            height:  detCol.implicitHeight + 24
                            color:        theme.sidebar
                            border.color: theme.border; border.width: 1
                            radius: 8

                            Column {
                                id: detCol
                                anchors { left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; top: parent.top; topMargin: 12 }
                                spacing: 6

                                Text { text: qsTr("Berechnungsdetails"); font.pixelSize: 11; font.weight: Font.Medium; color: theme.textMuted }

                                RowLayout {
                                    width: parent.width
                                    Text { text: qsTr("Kriterium");        font.pixelSize: 11; font.weight: Font.Medium; color: theme.textMuted; Layout.preferredWidth: 130 }
                                    Text { text: qsTr("Min. Querschnitt"); font.pixelSize: 11; font.weight: Font.Medium; color: theme.textMuted; Layout.preferredWidth: 180 }
                                    Text { text: qsTr("Kenngröße");        font.pixelSize: 11; font.weight: Font.Medium; color: theme.textMuted; Layout.fillWidth: true }
                                    Text { text: "OK";                     font.pixelSize: 11; font.weight: Font.Medium; color: theme.textMuted; Layout.preferredWidth: 32 }
                                }
                                Rectangle { width: parent.width; height: 1; color: theme.border }

                                KrDetailZeile {
                                    width: parent.width
                                    kriterium: qsTr("Spannungsfall")
                                    mindest: (erg && erg["spannungsfall"] && erg["spannungsfall"]["aktiv"])
                                             ? erg["spannungsfall"]["mindestText"] : "—"
                                    kenngr:  (erg && erg["spannungsfall"] && erg["spannungsfall"]["aktiv"])
                                             ? erg["spannungsfall"]["kenngroesse"] : ""
                                    ok:      (erg && erg["spannungsfall"])
                                             ? erg["spannungsfall"]["ok"] : false
                                    theme:   root.theme
                                }
                                KrDetailZeile {
                                    width: parent.width
                                    kriterium: qsTr("Thermik")
                                    mindest: (erg && erg["thermik"] && erg["thermik"]["aktiv"])
                                             ? erg["thermik"]["mindestText"] : "—"
                                    kenngr:  (erg && erg["thermik"] && erg["thermik"]["aktiv"])
                                             ? erg["thermik"]["kenngroesse"] : ""
                                    ok:      (erg && erg["thermik"])
                                             ? erg["thermik"]["ok"] : false
                                    theme:   root.theme
                                }
                                KrDetailZeile {
                                    width: parent.width
                                    visible: !!(erg && erg["ueberlast"] && erg["ueberlast"]["aktiv"])
                                    kriterium: qsTr("Überlast")
                                    mindest: (erg && erg["ueberlast"] && erg["ueberlast"]["aktiv"])
                                             ? erg["ueberlast"]["mindestText"] : "—"
                                    kenngr:  (erg && erg["ueberlast"] && erg["ueberlast"]["aktiv"])
                                             ? erg["ueberlast"]["kenngroesse"] : ""
                                    ok:      (erg && erg["ueberlast"]) ? erg["ueberlast"]["ok"] : true
                                    theme:   root.theme
                                }
                                KrDetailZeile {
                                    width: parent.width
                                    kriterium: qsTr("Kurzschluss")
                                    mindest: (erg && erg["kurzschluss"] && erg["kurzschluss"]["aktiv"])
                                             ? erg["kurzschluss"]["mindestText"] : "—"
                                    kenngr:  (erg && erg["kurzschluss"])
                                             ? erg["kurzschluss"]["kenngroesse"] : ""
                                    ok:      (erg && erg["kurzschluss"])
                                             ? erg["kurzschluss"]["ok"] : true
                                    theme:   root.theme
                                }
                            }
                        }

                        // ── Warnungen ─────────────────────────────────────
                        Repeater {
                            model: (erg && erg["warnungen"]) ? erg["warnungen"] : []
                            Rectangle {
                                width:  resultSv.availableWidth
                                height: warnText.implicitHeight + 16
                                color:        "transparent"
                                border.color: "#e0a000"; border.width: 1
                                radius: 6

                                Text {
                                    id: warnText
                                    anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; top: parent.top; topMargin: 8 }
                                    text: modelData
                                    font.pixelSize: 11; color: "#e0a000"
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        Item { height: 10 }

                        // ── Kabeljau – dauerhaft sichtbarer Begleiter ─────────
                        Item {
                            width:  resultSv.availableWidth
                            height: 640

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source:   "qrc:/assets/kabeljau_uebersicht.png"
                                width:    640; height: 640
                                fillMode: Image.PreserveAspectFit
                                smooth:   true; mipmap: true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Inline-Hilfskomponenten ───────────────────────────────────────────────

    component KrAbschnitt: Item {
        property var    theme
        property string titel: ""
        width: parent.width; height: 28
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: titel; font.pixelSize: 10; font.weight: Font.Medium
            color: theme.textMuted; font.letterSpacing: 0.5
        }
    }

    component KrZeile: RowLayout {
        property var    theme
        property string label:   ""
        property string wert:    ""
        property string einheit: ""
        property alias  feldText: eingabe.text

        width: parent.width; height: 32; spacing: 8
        Text { text: label; font.pixelSize: 12; color: theme.textPrimary; Layout.preferredWidth: 80 }
        TextField {
            id: eingabe; Layout.fillWidth: true; text: wert; font.pixelSize: 12; horizontalAlignment: TextInput.AlignRight
            background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
            color: theme.textPrimary
        }
        Text { text: einheit; font.pixelSize: 12; color: theme.textMuted; Layout.preferredWidth: 28 }
    }

    component KrDetailZeile: Item {
        property var    theme
        property string kriterium: ""
        property string mindest:   ""
        property string kenngr:    ""
        property bool   ok:        true
        height: 24
        RowLayout {
            anchors.fill: parent
            Text { text: kriterium; font.pixelSize: 13; color: theme.textPrimary; Layout.preferredWidth: 130 }
            Text { text: mindest;   font.pixelSize: 13; color: theme.textPrimary; Layout.preferredWidth: 180 }
            Text { text: kenngr;    font.pixelSize: 13; color: theme.textMuted;   Layout.fillWidth: true }
            Text { text: ok ? "✓" : "✗"; font.pixelSize: 14; color: ok ? "#4caf50" : "#f44336"; Layout.preferredWidth: 32 }
        }
    }
}
