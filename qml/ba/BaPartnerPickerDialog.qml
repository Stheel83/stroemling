import QtQuick
import QtQuick.Controls

// Partner-Picker (Steckerpaar-Verknüpfung, §10.3) — ausgelagert aus
// BaGeraetekastenAnsicht.qml (REFACTOR-QML-02).
Popup {
    id: root
    required property var theme
    required property var ga   // BaGeraetekastenAnsicht-Referenz (_flachListe, laden(), leisteKanvasAktualisiert)

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 420; height: 340
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property int _fuerElId: -1
    property var _liste:    []

    function _geschlecht(bauteilId) {
        if (bauteilId <= 0) return ""
        var t = db.steckverbinderTypLaden(bauteilId)
        if (!t || !t.montageform) return ""
        var teile = t.montageform.split("_")
        return teile.length > 1 ? teile[1] : ""
    }

    // Sortierung: gleiches BMK + komplementäres Geschlecht zuerst (§10.3).
    function oeffnen(elementId) {
        root._fuerElId = elementId
        var eigenes = null
        for (var i = 0; i < root.ga._flachListe.length; i++)
            if (root.ga._flachListe[i].id === elementId) { eigenes = root.ga._flachListe[i]; break }
        var eigenesBmk        = eigenes ? (eigenes.bmk || "") : ""
        var eigenesGeschlecht = eigenes ? root._geschlecht(eigenes.bauteilId) : ""

        var kandidaten = []
        for (var j = 0; j < root.ga._flachListe.length; j++) {
            var gk = root.ga._flachListe[j]
            if (gk.id === elementId) continue
            var g = root._geschlecht(gk.bauteilId)
            if (!g) continue   // nur Gerätekästen mit verknüpftem Steckverbinder-Bauteil
            var komplementaer = (eigenesGeschlecht === "stecker" && g === "buchse")
                              || (eigenesGeschlecht === "buchse" && g === "stecker")
            var gleichesBmk = eigenesBmk !== "" && gk.bmk === eigenesBmk
            var score = 3
            if (gleichesBmk && komplementaer) score = 0
            else if (gleichesBmk)             score = 1
            else if (komplementaer)           score = 2
            kandidaten.push({ id: gk.id, bmk: gk.bmk, bauteilBez: gk.bauteilBez,
                              geschlecht: g, blattnr: gk.blattnr, score: score })
        }
        kandidaten.sort(function(a, b) { return a.score - b.score })
        root._liste = kandidaten
        root.open()
    }

    background: Rectangle {
        color: root.theme.surface
        border.color: root.theme.border; border.width: 1; radius: 6
    }

    Column {
        anchors.fill: parent; anchors.margins: 8; spacing: 0

        Text {
            width: parent.width
            text: qsTr("Partner-Gerätekasten wählen")
            font.pixelSize: 13; font.weight: Font.Medium
            color: root.theme.textPrimary; padding: 6
        }
        Rectangle { width: parent.width; height: 1; color: root.theme.border }

        ListView {
            id: partnerPickerList
            width: parent.width
            height: parent.height - 50
            clip: true
            model: root._liste

            Text {
                visible: root._liste.length === 0
                anchors.centerIn: parent
                text: qsTr("Keine passenden Gerätekästen gefunden.\nVerknüpfe zuerst ein Steckverbinder-Bauteil.")
                font.pixelSize: 11; color: root.theme.textMuted; font.italic: true
                horizontalAlignment: Text.AlignHCenter
            }

            delegate: Rectangle {
                width: partnerPickerList.width; height: 42
                color: partnerItemHover.hovered ? root.theme.hover : "transparent"
                HoverHandler { id: partnerItemHover }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.right: parent.right; anchors.rightMargin: 12
                    spacing: 2
                    Text {
                        width: parent.width
                        text: (modelData.bmk || qsTr("(ohne BMK)")) + "  ·  " + (modelData.bauteilBez || "")
                        font.pixelSize: 12; color: root.theme.textPrimary
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: (modelData.geschlecht === "stecker" ? qsTr("Stecker") : qsTr("Buchse"))
                              + "  ·  " + qsTr("Blatt ") + (modelData.blattnr || "–")
                              + (modelData.score <= 1 ? "  ·  " + qsTr("gleiches BMK") : "")
                        font.pixelSize: 10; color: root.theme.textMuted
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        db.geraetekastenPartnerSetzen(root._fuerElId, modelData.id)
                        root.ga.laden()
                        root.ga.leisteKanvasAktualisiert()
                        root.close()
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: root.theme.border }

        Item {
            width: parent.width; height: 36
            Text {
                anchors.left: parent.left; anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Abbrechen")
                font.pixelSize: 12; color: root.theme.textMuted
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }
    }
}
