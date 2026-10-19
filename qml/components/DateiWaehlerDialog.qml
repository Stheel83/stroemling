import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

// Eigener Dateiwähler (der native FileDialog fällt im AppImage aus): Schnellzugriffe, Ordner anklicken, „nach oben“, Pfad tippen.
// Die Ordner listet das C++-Objekt `dateiBrowser` (nur lesend). Modus "oeffnen" wählt eine vorhandene Datei, "speichern" einen Dateinamen
// in einem Ordner. Ergebnis über das Signal `gewaehlt(pfad)`.
Dialog {
    id: root

    required property var theme
    property string modus: "oeffnen"            // "oeffnen" | "speichern"
    property string titelText: qsTr("Datei auswählen")
    property var    endungen: []                // Dateifilter, z. B. [".json"]; Ordner bleiben immer sichtbar
    property string dateiEndung: ""             // beim Speichern angehängt, falls sie im Namen fehlt
    property string vorschlagName: ""           // Dateiname-Vorschlag beim Speichern

    signal gewaehlt(string pfad)

    property string ordner: ""
    property var    eintraege: []
    property string auswahl: ""                 // Modus "oeffnen": gewählte Datei

    readonly property bool speichern: modus === "speichern"
    readonly property string zielPfad: speichern ? dateiBrowser.verbinde(ordner, _mitEndung(dateiname.text.trim())) : auswahl
    readonly property bool zielGueltig: speichern ? dateiname.text.trim().length > 0 : auswahl.length > 0
    readonly property bool ueberschreibt: speichern && zielGueltig && dateiBrowser.dateiExistiert(zielPfad)

    function _mitEndung(name) {
        if (name.length === 0 || dateiEndung.length === 0) return name
        return name.toLowerCase().endsWith(dateiEndung.toLowerCase()) ? name : name + dateiEndung
    }
    function _pfad(s) {
        s = String(s)
        if (s.startsWith("file:///")) return s.substring(7)
        if (s.startsWith("file://")) return s.substring(7)
        return s
    }
    function oeffnenMit(startPfad) {
        var start = _pfad(startPfad || "")
        if (start.length === 0)
            start = _pfad(StandardPaths.writableLocation(StandardPaths.DocumentsLocation))
        ordner = dateiBrowser.ordnerVon(start)
        auswahl = ""
        dateiname.text = vorschlagName
        laden()
        open()
    }
    function laden() {
        eintraege = dateiBrowser.inhalt(ordner, endungen)
        pfadFeld.text = ordner
    }
    function wechsleOrdner(neu) {
        ordner = neu
        auswahl = ""
        laden()
    }
    function bestaetigen() {
        if (!zielGueltig) return
        root.gewaehlt(zielPfad)
        root.accept()
    }

    title: titelText
    modal: true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(680, parent ? parent.width - 40 : 680)
    height: Math.min(540, parent ? parent.height - 40 : 540)
    padding: 14
    closePolicy: Popup.CloseOnEscape

    background: Rectangle { color: root.theme.sidebar; radius: 6; border.color: root.theme.border; border.width: 1 }
    header: Text {
        text: root.title; font.pixelSize: 14; font.weight: Font.Medium; color: root.theme.textPrimary
        leftPadding: 14; topPadding: 12; bottomPadding: 2
    }

    contentItem: ColumnLayout {
        id: inhalt
        spacing: 8

        // Schnellzugriffe
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: [
                    { label: "Home", pfad: StandardPaths.writableLocation(StandardPaths.HomeLocation) },
                    { label: qsTr("Dokumente"), pfad: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) },
                    { label: qsTr("Downloads"), pfad: StandardPaths.writableLocation(StandardPaths.DownloadLocation) },
                    { label: qsTr("Desktop"), pfad: StandardPaths.writableLocation(StandardPaths.DesktopLocation) }
                ]
                Button {
                    required property var modelData
                    text: modelData.label
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1      // gleich breite Schnellzugriffe
                    implicitHeight: 28
                    onClicked: root.wechsleOrdner(dateiBrowser.ordnerVon(root._pfad(modelData.pfad)))
                    contentItem: Text { text: parent.text; font.pixelSize: 11; color: root.theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 4; border.color: root.theme.border }
                }
            }
        }

        // Pfadzeile
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Button {
                text: "↑"
                implicitWidth: 34; implicitHeight: 30
                ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: qsTr("Übergeordneter Ordner")
                onClicked: root.wechsleOrdner(dateiBrowser.eltern(root.ordner))
                contentItem: Text { text: parent.text; font.pixelSize: 14; color: root.theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? root.theme.hover : root.theme.inputBg; radius: 4; border.color: root.theme.border }
            }
            TextField {
                id: pfadFeld
                Layout.fillWidth: true
                selectByMouse: true
                color: root.theme.textPrimary; font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                // Eingabe + Enter: Ordner öffnen, bei einer vorhandenen Datei diese (Modus „öffnen“) auswählen
                onAccepted: {
                    var eingabe = root._pfad(text)
                    if (!root.speichern && dateiBrowser.dateiExistiert(eingabe)) {
                        root.ordner = dateiBrowser.ordnerVon(eingabe)
                        root.laden()
                        root.auswahl = dateiBrowser.verbinde(root.ordner, dateiBrowser.dateiname(eingabe))
                    } else {
                        root.wechsleOrdner(dateiBrowser.ordnerVon(eingabe))
                    }
                }
            }
        }

        // Inhalt des Ordners
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: root.theme.inputBg; radius: 4; border.color: root.theme.border; clip: true
            ListView {
                id: liste
                anchors.fill: parent; anchors.margins: 2
                clip: true
                model: root.eintraege
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: zeile
                    required property var modelData
                    width: ListView.view.width - 8
                    height: 28
                    color: root.auswahl === zeile.modelData.pfad ? root.theme.accent
                           : (zeileHover.hovered ? root.theme.hover : "transparent")
                    radius: 3
                    HoverHandler { id: zeileHover }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                        Text { text: zeile.modelData.istOrdner ? "📁" : "📄"; font.pixelSize: 13 }
                        Text {
                            text: zeile.modelData.name
                            Layout.fillWidth: true; elide: Text.ElideMiddle; font.pixelSize: 12
                            color: root.auswahl === zeile.modelData.pfad ? "white" : root.theme.textPrimary
                        }
                        Text {
                            text: zeile.modelData.istOrdner ? "" : zeile.modelData.groesse
                            color: root.auswahl === zeile.modelData.pfad ? "white" : root.theme.textMuted; font.pixelSize: 11
                            Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: zeile.modelData.geaendert
                            color: root.auswahl === zeile.modelData.pfad ? "white" : root.theme.textMuted; font.pixelSize: 11
                            Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight
                        }
                    }
                    TapHandler {
                        onTapped: {
                            if (zeile.modelData.istOrdner)
                                root.wechsleOrdner(zeile.modelData.pfad)
                            else if (root.speichern)
                                dateiname.text = zeile.modelData.name
                            else
                                root.auswahl = zeile.modelData.pfad
                        }
                        onDoubleTapped: {
                            if (!zeile.modelData.istOrdner && !root.speichern) {
                                root.auswahl = zeile.modelData.pfad
                                root.bestaetigen()
                            }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.eintraege.length === 0
                text: root.endungen.length > 0
                      ? qsTr("Keine Unterordner oder %1-Dateien in diesem Ordner.").arg(root.endungen.join(", "))
                      : qsTr("Dieser Ordner ist leer.")
                color: root.theme.textMuted; font.pixelSize: 12
            }
        }

        // Dateiname (Speichern) bzw. gewählte Datei (Öffnen)
        RowLayout {
            Layout.fillWidth: true
            visible: root.speichern
            Text { text: qsTr("Dateiname"); color: root.theme.textMuted; font.pixelSize: 11 }
            TextField {
                id: dateiname
                Layout.fillWidth: true; selectByMouse: true
                color: root.theme.textPrimary; font.pixelSize: 12
                background: Rectangle { color: root.theme.inputBg; radius: 4; border.color: root.theme.border }
                onAccepted: root.bestaetigen()
            }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WrapAnywhere
            font.pixelSize: 11
            color: root.ueberschreibt ? "#b9770e" : root.theme.textMuted
            text: root.speichern
                  ? (root.ueberschreibt ? qsTr("⚠ Diese Datei existiert bereits und wird überschrieben.") : root.zielPfad)
                  : (root.auswahl.length > 0 ? qsTr("Ausgewählt: %1").arg(root.auswahl) : qsTr("Keine Datei ausgewählt."))
        }
    }

    footer: DialogButtonBox {
        background: Rectangle { color: "transparent" }
        Button { text: qsTr("Abbrechen"); DialogButtonBox.buttonRole: DialogButtonBox.RejectRole; onClicked: root.reject() }
        Button {
            text: root.speichern ? qsTr("Speichern") : qsTr("Öffnen")
            enabled: root.zielGueltig
            highlighted: true
            DialogButtonBox.buttonRole: DialogButtonBox.ActionRole
            onClicked: root.bestaetigen()
        }
    }
}
