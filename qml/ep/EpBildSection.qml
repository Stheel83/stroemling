import QtQuick
import "../components"

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "bild") ? bildCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    component Trennlinie: Rectangle {
        width: root.width - 16; height: 1; color: root.theme.border
        anchors.horizontalCenter: parent.horizontalCenter
    }

    component AbschnittTitel: Item {
        property string text: ""
        width: root.width; height: 26
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 9; font.weight: Font.Bold
            font.letterSpacing: 1.5; color: root.theme.borderLight
        }
    }

    component FeldLabel: Item {
        property string text: ""
        width: root.width; height: 20
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: parent.text; font.pixelSize: 10; color: root.theme.panelMid
        }
    }

    Column {
        id: bildCol
        width: parent.width; spacing: 0

        Trennlinie {}
        AbschnittTitel { text: qsTr("BILD") }

        FeldLabel { text: qsTr("Rotation") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: [
                    { anzeige: "0°",   wert: 0   },
                    { anzeige: "90°",  wert: 90  },
                    { anzeige: "180°", wert: 180 },
                    { anzeige: "270°", wert: 270 }
                ]
                MiniButton { theme: root.theme;
                    label:   modelData.anzeige
                    aktiv:   panel.s("rotation", 0) === modelData.wert
                    breite:  40
                    onKlick: panel.canvas.eigenschaftAktualisieren("rotation", modelData.wert)
                }
            }
        }
        Item { height: 4 }

        Item {
            width: root.width; height: 28
            Text {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: qsTr("Freier Winkel"); color: theme.panelMid; font.pixelSize: 10
            }
            Row {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 2
                Rectangle {
                    width: 40; height: 22; radius: 3
                    color: theme.inputBg; border.color: bildRotTf.activeFocus ? theme.accent : theme.border
                    TextInput {
                        id: bildRotTf
                        anchors { fill: parent; leftMargin: 4; rightMargin: 2 }
                        horizontalAlignment: TextInput.AlignRight
                        color: theme.textSecondary; font.pixelSize: 10
                        verticalAlignment: TextInput.AlignVCenter
                        // Ganze Grad (BILD-WINKEL-PRAEZISION-01): rotation ist in ElementeModel/
                        // Datenbank durchgängig ein int (GrafikElement::rotation, grafik_element.rotation
                        // INTEGER) – Nachkommastellen wurden hier zuvor nur suggeriert, aber beim
                        // Speichern immer verworfen. Feld entsprechend auf 0 Nachkommastellen begrenzt.
                        validator: IntValidator { bottom: 0; top: 359 }
                        text: panel.s("rotation", 0).toFixed(0)
                        Binding on text {
                            when:    !bildRotTf.activeFocus
                            value:   panel.s("rotation", 0).toFixed(0)
                            delayed: true
                        }
                        // BILD-WINKEL-FOKUS-01: Commit darf nicht am Fokusverlust hängen –
                        // Klicks auf Preset-/Spiegeln-Buttons (MiniButton) fordern keinen
                        // Tastaturfokus an, das Feld behält activeFocus dann unbegrenzt und
                        // onEditingFinished feuert nie.
                        // BILD-WINKEL-DEBOUNCE-01 (direkter Nachtrag): ein sofortiger Commit bei
                        // JEDEM Tastendruck (frühere Version dieses Fixes) hat beim schnellen
                        // Löschen+Neutippen die volle eigenschaftAktualisieren()-Pipeline
                        // (undoCheckpoint + grafikSpeichernJetzt-DB-Rewrite + auswahl-Reassign)
                        // im Sekundentakt reentrant ausgelöst – dabei verlor das Feld sporadisch
                        // den Fokus mitten in der Eingabe, wodurch nachfolgende Backspace-Tasten
                        // nicht mehr vom TextInput konsumiert wurden, sondern den globalen
                        // Backspace/Delete-Shortcut (Main.qml) auslösten und das Bild löschten.
                        // Fix: Commit läuft jetzt entprellt (350 ms nach der letzten Eingabe),
                        // onEditingFinished flusht sofort bei Enter/echtem Fokusverlust.
                        function commitRotation() {
                            var v = parseInt(text, 10)
                            if (!isNaN(v)) panel.canvas.eigenschaftAktualisieren("rotation", ((v % 360) + 360) % 360)
                        }
                        onTextEdited:      rotCommitTimer.restart()
                        onEditingFinished: { rotCommitTimer.stop(); commitRotation() }
                        Keys.onEscapePressed: { rotCommitTimer.stop(); text = panel.s("rotation", 0).toFixed(0); focus = false }

                        Timer { id: rotCommitTimer; interval: 350; onTriggered: bildRotTf.commitRotation() }
                    }
                }
                Column {
                    width: 14; height: 22
                    Rectangle {
                        width: 14; height: 11; radius: 2
                        color: bwUpMa.containsMouse ? theme.hover : theme.inputBg
                        border.color: theme.border
                        Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 6; color: theme.borderLight }
                        MouseArea {
                            id: bwUpMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: panel.canvas.eigenschaftAktualisieren("rotation", (panel.s("rotation", 0) + 1) % 360)
                        }
                    }
                    Rectangle {
                        width: 14; height: 11; radius: 2
                        color: bwDownMa.containsMouse ? theme.hover : theme.inputBg
                        border.color: theme.border
                        Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 6; color: theme.borderLight }
                        MouseArea {
                            id: bwDownMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: panel.canvas.eigenschaftAktualisieren("rotation", ((panel.s("rotation", 0) - 1) % 360 + 360) % 360)
                        }
                    }
                }
                Text { text: "°"; color: theme.borderLight; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Item { height: 6 }

        FeldLabel { text: qsTr("Spiegelung") }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            MiniButton { theme: root.theme;
                label:   qsTr("↔ H")
                tooltip: qsTr("Horizontal spiegeln (Taste X)")
                aktiv:   panel.s("spiegelX", false)
                breite:  56
                onKlick: panel.canvas.eigenschaftAktualisieren("spiegelX", !panel.s("spiegelX", false))
            }
            MiniButton { theme: root.theme;
                label:   qsTr("↕ V")
                tooltip: qsTr("Vertikal spiegeln (Taste Y)")
                aktiv:   panel.s("spiegelY", false)
                breite:  56
                onKlick: panel.canvas.eigenschaftAktualisieren("spiegelY", !panel.s("spiegelY", false))
            }
        }
        Item { height: 8 }

        Trennlinie {}
        AbschnittTitel { text: qsTr("GRÖßENÄNDERUNG") }
        Row {
            leftPadding: 12; height: 32; spacing: 8
            Rectangle {
                width: 20; height: 20; radius: 4; anchors.verticalCenter: parent.verticalCenter
                color: panel.s("proportional", false) ? theme.accent : theme.inputBg
                border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✓"); color: "#ffffff"
                       font.pixelSize: 12; visible: panel.s("proportional", false) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.canvas.eigenschaftAktualisieren("proportional",
                                   !panel.s("proportional", false)) }
            }
            Text { text: qsTr("Seitenverhältnis beibehalten"); color: theme.textMuted
                   font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
        }

        Trennlinie {}
        AbschnittTitel { text: qsTr("AUSSCHNITT") }

        Item {
            width: root.width; height: 22
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                   text: qsTr("Links  ") + Math.round(panel.s("ausschnittLinks", 0) * 100) + " %"
                   color: theme.panelMid; font.pixelSize: 10 }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3; visible: panel.s("ausschnittLinks", 0) > 0
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✕"); font.pixelSize: 9; color: theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.canvas.eigenschaftAktualisieren("ausschnittLinks", 0) }
            }
        }
        StilSlider { theme: root.theme; height: 36; width: root.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittLinks", 0)
            onGeaendert: function(v) { panel.canvas.eigenschaftAktualisieren("ausschnittLinks", v) } }

        Item {
            width: root.width; height: 22
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                   text: qsTr("Rechts  ") + Math.round(panel.s("ausschnittRechts", 0) * 100) + " %"
                   color: theme.panelMid; font.pixelSize: 10 }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3; visible: panel.s("ausschnittRechts", 0) > 0
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✕"); font.pixelSize: 9; color: theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.canvas.eigenschaftAktualisieren("ausschnittRechts", 0) }
            }
        }
        StilSlider { theme: root.theme; height: 36; width: root.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittRechts", 0)
            onGeaendert: function(v) { panel.canvas.eigenschaftAktualisieren("ausschnittRechts", v) } }

        Item {
            width: root.width; height: 22
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                   text: qsTr("Oben  ") + Math.round(panel.s("ausschnittOben", 0) * 100) + " %"
                   color: theme.panelMid; font.pixelSize: 10 }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3; visible: panel.s("ausschnittOben", 0) > 0
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✕"); font.pixelSize: 9; color: theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.canvas.eigenschaftAktualisieren("ausschnittOben", 0) }
            }
        }
        StilSlider { theme: root.theme; height: 36; width: root.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittOben", 0)
            onGeaendert: function(v) { panel.canvas.eigenschaftAktualisieren("ausschnittOben", v) } }

        Item {
            width: root.width; height: 22
            Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                   text: qsTr("Unten  ") + Math.round(panel.s("ausschnittUnten", 0) * 100) + " %"
                   color: theme.panelMid; font.pixelSize: 10 }
            Rectangle {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                width: 22; height: 18; radius: 3; visible: panel.s("ausschnittUnten", 0) > 0
                color: theme.inputBg; border.color: theme.border
                Text { anchors.centerIn: parent; text: qsTr("✕"); font.pixelSize: 9; color: theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: panel.canvas.eigenschaftAktualisieren("ausschnittUnten", 0) }
            }
        }
        StilSlider { theme: root.theme; height: 36; width: root.width - 16; anchors.horizontalCenter: parent.horizontalCenter
            von: 0; bis: 0.5; schritt: 0.01; wert: panel.s("ausschnittUnten", 0)
            onGeaendert: function(v) { panel.canvas.eigenschaftAktualisieren("ausschnittUnten", v) } }

        Item { height: 4 }
    }
}
