import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: root
    objectName: "kabelRechner"

    property var  theme
    property bool debug: false

    property string modus:    "schnell"   // "schnell" | "genau"
    property string material: "cu"        // "cu" | "al"

    readonly property bool    istGenau: modus === "genau"
    readonly property var     erg:      kabelRechnerModel.ergebnis

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

                Item { Layout.fillWidth: true }

                // Modus-Toggle
                Rectangle {
                    width: 188; height: 30
                    radius: 6
                    color:        theme.inputBg
                    border.color: theme.border; border.width: 1

                    Row {
                        anchors.fill: parent

                        Rectangle {
                            width: 93; height: parent.height; radius: 5
                            color: root.modus === "schnell" ? theme.accent : "transparent"
                            ToolTip.visible: schnellMa.containsMouse; ToolTip.delay: 600
                            ToolTip.text: qsTr("Schnell: Querschnitt aus Strom + Länge (Daumenregel)")
                            Text { anchors.centerIn: parent; text: qsTr("⚡ Schnell"); font.pixelSize: 12; color: root.modus === "schnell" ? "white" : theme.textMuted }
                            MouseArea { id: schnellMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.modus = "schnell"; cursorShape: Qt.PointingHandCursor }
                        }
                        Rectangle { width: 1; height: parent.height; color: theme.border }
                        Rectangle {
                            width: 94; height: parent.height; radius: 5
                            color: root.modus === "genau" ? theme.accent : "transparent"
                            ToolTip.visible: genauMa.containsMouse; ToolTip.delay: 600
                            ToolTip.text: qsTr("Genau: Vollständige Berechnung nach VDE 0298 / IEC 60364 (Verlegeart, Häufung, Schutzorgan)")
                            Text { anchors.centerIn: parent; text: qsTr("🔬 Genau"); font.pixelSize: 12; color: root.modus === "genau" ? "white" : theme.textMuted }
                            MouseArea { id: genauMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.modus = "genau"; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

        // ── Haupt-Split ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            spacing: 0

            // ── Eingabe-Panel (links, 300 px) ─────────────────────────────
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight:     true
                color: theme.sidebar

                ScrollView {
                    anchors.fill:  parent
                    contentWidth:  300
                    clip:          true

                    Column {
                        x: 16; y: 16
                        width:   268
                        spacing: 3

                        // ── Elektrische Parameter ────────────────────────
                        KrAbschnitt { titel: qsTr("ELEKTRISCHE PARAMETER"); theme: root.theme }

                        // Betriebsart (nur Genau)
                        RowLayout {
                            visible: root.istGenau
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
                                }
                            }
                            Item { Layout.preferredWidth: 28 }
                        }

                        KrZeile { id: stromZeile; label: qsTr("Strom I"); wert: "13"; einheit: "A"; theme: root.theme }

                        KrZeile {
                            id: spannungZeile
                            visible: root.istGenau
                            label: qsTr("Spannung U"); wert: "230"; einheit: "V"; theme: root.theme
                        }

                        KrZeile {
                            id: cosPhiZeile
                            visible: root.istGenau
                            label: "cos φ"; wert: "1,00"; einheit: ""; theme: root.theme
                        }

                        Item { height: 8 }

                        // ── Leitung ──────────────────────────────────────
                        KrAbschnitt { titel: qsTr("LEITUNG"); theme: root.theme }

                        KrZeile { id: laengeZeile; label: qsTr("Länge L"); wert: "25"; einheit: "m"; theme: root.theme }

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

                        // Verlegeart (nur Genau)
                        RowLayout {
                            visible: root.istGenau
                            width: parent.width; height: 32; spacing: 8
                            Text { text: qsTr("Verlegeart"); font.pixelSize: 12; color: theme.textPrimary; Layout.preferredWidth: 80 }
                            ComboBox {
                                id: verlegeartBox
                                Layout.fillWidth: true; font.pixelSize: 12
                                model: ["A1", "A2", "B1", "B2", "C", "D1", "D2", "E", "F"]
                                currentIndex: 3
                                background: Rectangle { color: theme.inputBg; border.color: theme.border; radius: 4 }
                                contentItem: Text { text: parent.displayText; color: theme.textPrimary; font.pixelSize: 12;
                                                    leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            }
                            Item { Layout.preferredWidth: 28 }
                        }
                        // Verlegeart-Erklärung
                        Text {
                            visible: root.istGenau
                            width: parent.width
                            leftPadding: 88
                            rightPadding: 28
                            font.pixelSize: 10
                            color: theme.textMuted
                            wrapMode: Text.Wrap
                            text: {
                                var idx = verlegeartBox.currentIndex
                                var bez = [
                                    qsTr("Einzelader in wärmegedämmter Wand"),
                                    qsTr("Mehradriges Kabel in wärmegedämmter Wand"),
                                    qsTr("Einzelader auf Holzwand / in Rohr auf Holzwand"),
                                    qsTr("Mehradriges Kabel auf Holzwand / in Rohr"),
                                    qsTr("Direkt auf Wand oder Decke"),
                                    qsTr("Einzelkabel direkt in Erde"),
                                    qsTr("Mehrere Kabel in Erde oder im Rohr"),
                                    qsTr("Freie Verlegung (Kabelrinne, Luftraum)"),
                                    qsTr("Freie Verlegung horizontal auf Oberfläche")
                                ]
                                return bez[idx] || ""
                            }
                        }

                        Item { height: 8; visible: root.istGenau }

                        // ── Umgebung (nur Genau) ─────────────────────────
                        KrAbschnitt { visible: root.istGenau; titel: qsTr("UMGEBUNG"); theme: root.theme }

                        KrZeile { id: temperaturZeile; visible: root.istGenau; label: qsTr("Temperatur"); wert: "30"; einheit: "°C"; theme: root.theme }

                        RowLayout {
                            visible: root.istGenau
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

                        Item { height: 8; visible: root.istGenau }

                        // ── Schutzorgan (nur Genau) ──────────────────────
                        KrAbschnitt { visible: root.istGenau; titel: qsTr("SCHUTZORGAN"); theme: root.theme }

                        RowLayout {
                            visible: root.istGenau
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
                                if (root.istGenau) {
                                    kabelRechnerModel.betriebsart      = betriebsartBox.currentIndex
                                    kabelRechnerModel.spannung         = parseFloat(spannungZeile.feldText.replace(",", ".")) || 230
                                    kabelRechnerModel.cosPhi           = parseFloat(cosPhiZeile.feldText.replace(",", ".")) || 1
                                    kabelRechnerModel.verlegeart       = verlegeartBox.currentIndex
                                    kabelRechnerModel.temperatur       = parseFloat(temperaturZeile.feldText.replace(",", ".")) || 30
                                    kabelRechnerModel.haefung          = haefungBox.currentIndex
                                    kabelRechnerModel.schutzOrganTyp   = schutzOrganTypBox.currentIndex
                                    kabelRechnerModel.schutzOrganStrom = parseFloat(schutzOrganStromFeld.text.replace(",", ".")) || 16
                                    kabelRechnerModel.berechnen()
                                } else {
                                    kabelRechnerModel.berechnenSchnell()
                                }
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
                                    text: qsTr("Empfohlener Querschnitt")
                                    font.pixelSize: 11; font.weight: Font.Medium; color: theme.textMuted
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
                            }
                        }

                        // ── Karte: Berechnungsdetails (nur Genau) ─────────
                        Rectangle {
                            width:   parent.width
                            height:  detCol.implicitHeight + 24
                            visible: root.istGenau
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
                                    Text { text: qsTr("Min. Querschnitt"); font.pixelSize: 11; font.weight: Font.Medium; color: theme.textMuted; Layout.preferredWidth: 120 }
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

                        // ── Karte: Praxisrichtwert ────────────────────────
                        Rectangle {
                            width:  parent.width
                            height: praxCol.implicitHeight + 24
                            color:        theme.sidebar
                            border.color: theme.border; border.width: 1
                            radius: 8

                            Column {
                                id: praxCol
                                anchors { left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16; top: parent.top; topMargin: 12 }
                                spacing: 6

                                Text {
                                    text: qsTr("Praxisrichtwert  (Daumenregel Cu, B2)")
                                    font.pixelSize: 11; font.weight: Font.Medium; color: theme.textMuted
                                }
                                Text {
                                    text: (erg && erg["praxis"]) ? erg["praxis"]["formel"] : "I / 6  =  … mm²"
                                    font.pixelSize: 14; color: theme.textPrimary
                                }
                                // L_max (Schnellmodus)
                                Text {
                                    visible: !root.istGenau && erg && erg["praxis"] && erg["praxis"]["lMaxText"]
                                    text: qsTr("Max. Leitungslänge bei %1 % ΔU: %2")
                                              .arg("3")
                                              .arg((erg && erg["praxis"]) ? (erg["praxis"]["lMaxText"] || "") : "")
                                    font.pixelSize: 12; color: theme.textMuted
                                }
                                Row {
                                    spacing: 6
                                    property bool stimmtUeberein: (erg && erg["praxis"])
                                                                   ? erg["praxis"]["stimmtUeberein"] : false
                                    Text {
                                        text: parent.stimmtUeberein ? "✓" : "△"
                                        font.pixelSize: 14
                                        color: parent.stimmtUeberein ? "#4caf50" : "#e0a000"
                                    }
                                    Text {
                                        text: root.istGenau
                                              ? (parent.parent.stimmtUeberein
                                                 ? qsTr("Praxiswert stimmt mit Genauberechnung überein")
                                                 : qsTr("Genauberechnung empfiehlt anderen Querschnitt"))
                                              : qsTr("Für sicherheitsrelevante Anwendungen Genaumodus verwenden")
                                        font.pixelSize: 12
                                        color: (root.istGenau && parent.parent.stimmtUeberein) ? "#4caf50" : theme.textMuted
                                    }
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
            Text { text: mindest;   font.pixelSize: 13; color: theme.textPrimary; Layout.preferredWidth: 120 }
            Text { text: kenngr;    font.pixelSize: 13; color: theme.textMuted;   Layout.fillWidth: true }
            Text { text: ok ? "✓" : "✗"; font.pixelSize: 14; color: ok ? "#4caf50" : "#f44336"; Layout.preferredWidth: 32 }
        }
    }
}
