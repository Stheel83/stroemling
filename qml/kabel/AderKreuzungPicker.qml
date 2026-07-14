import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Inline-Auswahl für die Aderzuordnung direkt am Kreuzungspunkt einer
// Kabellinie (Canvas-Redesign §6.5.2). Zeigt nur freie Adern + "– keine –" –
// eine bereits belegte Ader kann darüber nicht übernommen werden (dafür
// muss sie an ihrer alten Stelle erst freigegeben werden). Der volle
// Aderzuordnungsdialog bleibt für die Erstzuordnung (Automatik-Modi)
// unverändert bestehen.
Popup {
    id: root
    required property var theme

    parent:      Overlay.overlay
    modal:       false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding:     8
    width:       180

    // Vom Aufrufer vor open() gesetzt
    property int    kabelId:        0
    property int    kabelGeid:      0
    property string aderKey:        ""
    property int    verbindungId:   0
    property int    aktuelleAderNr: 0     // 0 = keine
    property bool   istLeer:        true
    property var    alteAder:       ({})  // {aderNr, farbe, farbe2, bezeichnung} der bisherigen Ader (für Freigabe)
    property var    freieAdern:     []    // [{aderNr, farbe, farbe2, bezeichnung}, ...]

    // Signal: Nutzer hat eine Ader gewählt (neueNr = 0 → "– keine –").
    signal aderZugewiesen(int kabelId, int kabelGeid, string aderKey, int verbindungId,
                           int neueNr, string neueFarbe, string neueFarbe2, string neueBezeichnung,
                           int alteNr, string alteFarbe, string alteFarbe2, string alteBezeichnung)

    function oeffnen(p_kabelId, p_kabelGeid, p_aderKey, p_verbindungId,
                      p_aktuelleAderNr, p_istLeer, p_alteAder, p_freieAdern,
                      p_vpX, p_vpY) {
        kabelId        = p_kabelId
        kabelGeid      = p_kabelGeid
        aderKey        = p_aderKey
        verbindungId   = p_verbindungId
        aktuelleAderNr = p_aktuelleAderNr
        istLeer        = p_istLeer
        alteAder       = p_alteAder || {}
        freieAdern     = p_freieAdern || []
        x = p_vpX
        y = p_vpY
        open()
    }

    function _zuweisen(neueNr, neueFarbe, neueFarbe2, neueBezeichnung) {
        root.aderZugewiesen(kabelId, kabelGeid, aderKey, verbindungId,
            neueNr, neueFarbe || "", neueFarbe2 || "", neueBezeichnung || "",
            istLeer ? 0 : aktuelleAderNr,
            (alteAder && alteAder.farbe) || "",
            (alteAder && alteAder.farbe2) || "",
            (alteAder && alteAder.bezeichnung) || "")
        close()
    }

    function iecFarbe(code) {
        var m = {
            "BK": "#1a1a1a", "BN": "#7B3F00", "RD": "#CC0000", "OG": "#FF7700",
            "YE": "#CCCC00", "GN": "#006600", "BU": "#0044AA", "VT": "#660099",
            "GY": "#777777", "WH": "#CCCCCC", "PK": "#FF99BB"
        }
        return m[code] || "#888888"
    }

    background: Rectangle {
        color:        root.theme.surface
        radius:       6
        border.color: root.theme.border
        layer.enabled: true
    }

    contentItem: ColumnLayout {
        spacing: 4

        Text {
            text: root.istLeer ? qsTr("Aktuell: – keine –")
                                : qsTr("Aktuell: Ader %1").arg(root.aktuelleAderNr)
            font.pixelSize: 11; font.weight: Font.Medium
            color: root.theme.textSecondary
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true; height: 24; radius: 3
            visible: !root.istLeer
            color: keineMa.containsMouse ? root.theme.activeItemAlt : root.theme.inputBg
            Text {
                anchors { fill: parent; leftMargin: 8 }
                text: qsTr("– keine –")
                verticalAlignment: Text.AlignVCenter
                color: root.theme.textSecondary; font.pixelSize: 11
            }
            MouseArea {
                id: keineMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root._zuweisen(0, "", "", "")
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 168)
            model: root.freieAdern
            clip: true
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                width: ListView.view.width; height: 24; radius: 3
                color: zeileMa.containsMouse ? root.theme.activeItemAlt : root.theme.inputBg
                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                    spacing: 6
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        visible: !!modelData.farbe
                        color:   root.iecFarbe(modelData.farbe)
                        border.color: "#00000055"; border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: qsTr("Ader %1").arg(modelData.aderNr)
                              + (modelData.farbe ? "  " + modelData.farbe + (modelData.farbe2 ? "/" + modelData.farbe2 : "") : "")
                              + (modelData.bezeichnung ? "  " + modelData.bezeichnung : "")
                        color: root.theme.textSecondary; font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                MouseArea {
                    id: zeileMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root._zuweisen(modelData.aderNr, modelData.farbe || "", modelData.farbe2 || "", modelData.bezeichnung || "")
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.freieAdern.length === 0
                text: qsTr("keine freie Ader")
                color: root.theme.textMuted; font.pixelSize: 11
            }
        }
    }
}
