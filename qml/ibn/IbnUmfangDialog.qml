import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// IBN-UMF-01 (konzept/features/55 §9): Prüfumfang der Inbetriebnahme festlegen.
// Kategorien und einzelne Symbole lassen sich abschalten, Kabel getrennt. Haken = wird geprüft.
// Bereits erfasste Prüfungen bleiben gespeichert, ausgeschlossene Betriebsmittel zählen nur nicht mehr.
Dialog {
    id: root

    modal:  true
    parent: Overlay.overlay
    anchors.centerIn: parent
    width:  540
    height: Math.min(640, (parent ? parent.height : 700) - 40)
    padding: 20

    required property var theme
    required property int projektId
    property string gesperrtGrund: ""          // nicht leer = nur ansehen, nicht speichern
    property string fehlerText: ""

    // Arbeitskopie des Umfangs; Schlüssel -> true = ausgeschlossen
    property var  _daten: ({ kategorien: [], kabelPruefen: true, kabelAnzahl: 0 })
    property var  _katAus: ({})
    property var  _symAus: ({})
    property bool _kabelAus: false
    property var  _offen: ({})                 // aufgeklappte Kategorien
    property var  _zeilen: []

    signal umfangGeaendert()

    title: qsTr("Prüfumfang")

    background: Rectangle {
        color: root.theme.sidebar; border.color: root.theme.border
        border.width: 1; radius: 6
    }

    function _kopie(o) { return JSON.parse(JSON.stringify(o)) }

    function _zeilenBauen() {
        var z = []
        var kat = root._daten.kategorien || []
        for (var i = 0; i < kat.length; i++) {
            var k = kat[i]
            var ohne = k.kategorie === ""
            var offen = ohne || root._offen[k.kategorie] === true
            z.push({ typ: "kat", kategorie: k.kategorie,
                     titel: ohne ? qsTr("Ohne Kategorie") : k.kategorie,
                     anzahl: k.anzahl, hatSymbole: k.symbole.length > 0, offen: offen })
            if (offen)
                for (var j = 0; j < k.symbole.length; j++)
                    z.push({ typ: "sym", kategorie: k.kategorie, symbolId: k.symbole[j].symbolId,
                             titel: k.symbole[j].name, anzahl: k.symbole[j].anzahl })
        }
        root._zeilen = z
    }

    function laden() {
        fehlerText = ""
        root._daten = db.ibnUmfangUebersicht(root.projektId)
        var ka = {}, sa = {}, kabel = false
        var rows = db.ibnUmfangLaden(root.projektId)       // auch Einträge, die im Projekt nicht (mehr) vorkommen
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].art === "kategorie") ka[rows[i].schluessel] = true
            else if (rows[i].art === "symbol") sa[rows[i].schluessel] = true
            else if (rows[i].art === "kabel") kabel = true
        }
        root._katAus = ka; root._symAus = sa; root._kabelAus = kabel
        root._offen = ({})
        root._zeilenBauen()
    }

    function _katUmschalten(kat) {
        var m = root._kopie(root._katAus)
        if (m[kat]) delete m[kat]; else m[kat] = true
        root._katAus = m
    }
    function _symUmschalten(sid) {
        var m = root._kopie(root._symAus)
        if (m[sid]) delete m[sid]; else m[sid] = true
        root._symAus = m
    }
    function _aufzuklappen(kat) {
        var m = root._kopie(root._offen)
        m[kat] = !m[kat]
        root._offen = m
        root._zeilenBauen()
    }

    function _speichern() {
        var l = []
        for (var k in root._katAus) l.push({ art: "kategorie", schluessel: k })
        for (var s in root._symAus) l.push({ art: "symbol", schluessel: s })
        if (root._kabelAus) l.push({ art: "kabel", schluessel: "alle" })
        if (!db.ibnUmfangSetzen(root.projektId, l)) {
            root.fehlerText = qsTr("Der Prüfumfang konnte nicht gespeichert werden (siehe Log).")
            return
        }
        root.close()
        root.umfangGeaendert()
    }

    onAboutToShow: laden()

    contentItem: ColumnLayout {
        spacing: 10

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11; color: root.theme.textSecondary
            text: qsTr("Haken = wird geprüft. Abgewählte Kategorien oder Symbole erscheinen nicht in der Inbetriebnahme-Liste "
                       + "und zählen nicht in Fortschritt und Prüfprotokoll. Bereits erfasste Prüfungen bleiben gespeichert. "
                       + "Ein Betriebsmittel bleibt in der Liste, solange mindestens eines seiner Symbole geprüft wird. "
                       + "Die Zählung (Prozent) ändert sich sofort.")
        }

        Text {
            visible: root.gesperrtGrund !== ""
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 11; color: "#e0a040"
            text: root.gesperrtGrund
        }

        CheckBox {
            id: cbKabel
            enabled: root.gesperrtGrund === ""
            checked: !root._kabelAus
            onToggled: root._kabelAus = !checked
            contentItem: Text {
                leftPadding: cbKabel.indicator.width + 6
                text: qsTr("Kabel mitprüfen (%1)").arg(root._daten.kabelAnzahl)
                color: root.theme.textPrimary; font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.theme.border }

        Text {
            text: qsTr("Betriebsmittel nach Kategorie")
            font.pixelSize: 11; color: root.theme.textSecondary
        }

        ListView {
            id: liste
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: root._zeilen
            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                width: liste.width - 12
                height: 28
                readonly property bool istKat: modelData.typ === "kat"
                readonly property bool katAus: root._katAus[modelData.kategorie] === true
                // Symbol: ausgeschlossen, wenn einzeln abgewählt oder die Kategorie abgewählt ist
                readonly property bool aus: istKat ? katAus : (katAus || root._symAus[modelData.symbolId] === true)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: istKat ? 0 : 28
                    spacing: 4

                    Text {
                        visible: istKat
                        Layout.preferredWidth: 16
                        text: !modelData.hatSymbole || modelData.kategorie === "" ? "" : (modelData.offen ? "▾" : "▸")
                        color: root.theme.textSecondary; font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root._aufzuklappen(modelData.kategorie)
                        }
                    }

                    CheckBox {
                        id: cb
                        // „Ohne Kategorie“ hat keinen Kategorie-Haken, nur einzelne Symbole
                        visible: !(istKat && modelData.kategorie === "")
                        enabled: root.gesperrtGrund === "" && (istKat || !katAus)
                        checked: !aus
                        onToggled: istKat ? root._katUmschalten(modelData.kategorie)
                                          : root._symUmschalten(modelData.symbolId)
                        indicator.implicitWidth: 18
                        indicator.implicitHeight: 18
                    }

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.titel + (istKat ? "" : "")
                        color: aus ? root.theme.textMuted : root.theme.textPrimary
                        font.pixelSize: 12
                        font.bold: istKat
                        MouseArea {
                            anchors.fill: parent
                            enabled: istKat && modelData.hatSymbole
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._aufzuklappen(modelData.kategorie)
                        }
                    }

                    Text {
                        text: qsTr("%1 BMK").arg(modelData.anzahl)
                        color: root.theme.textMuted; font.pixelSize: 11
                    }
                }
            }
        }

        Text {
            visible: root.fehlerText !== ""
            text: root.fehlerText
            color: "#e04040"; font.pixelSize: 11
            Layout.fillWidth: true; wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }

            Button {
                text: root.gesperrtGrund === "" ? qsTr("Abbrechen") : qsTr("Schließen")
                flat: true
                implicitHeight: 32
                contentItem: Text {
                    text: parent.text; color: root.theme.textSecondary; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? root.theme.hover : root.theme.inputBg
                    radius: 4; border.color: root.theme.border
                }
                onClicked: root.reject()
            }

            Button {
                text: qsTr("Übernehmen")
                implicitHeight: 32
                enabled: root.gesperrtGrund === ""
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? root.theme.textPrimary : root.theme.textMuted
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? root.theme.accent : root.theme.inputBg)
                                          : root.theme.inputBg
                    radius: 4
                    border.color: parent.enabled ? root.theme.accent : root.theme.border
                }
                onClicked: root._speichern()
            }
        }
    }
}
