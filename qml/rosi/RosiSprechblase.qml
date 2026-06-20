import QtQuick
import QtQuick.Layouts

// Rosi Röhrenaal — Maskottchen-Assistentin, siehe konzept/features/48_rosi_roehrenaal.md.
// Taucht aus einer Rohröffnung am unteren Fensterrand auf, zeigt einen Spruch
// in einer Sprechblase, zieht sich nach ~12s oder per Klick wieder zurück.
// Verwendung: rosiSprechblase.zeigen(text) – ausgelöst von rosiManager.auftauchen.
//
// PLATZHALTER-GRAFIK: Körper und Rohröffnung sind einfache gezeichnete Formen,
// bis die echten Assets (rosi_roehrenaal.png / rosi_rohroeffnung.png) aus dem
// Bild-Prompt in stroemling-alle-bildprompts.md existieren. Dann hier die
// Rectangle-Platzhalter durch Image-Elemente ersetzen, siehe §6 im Konzept.

Item {
    id: root

    property var theme

    width:  240
    height: 180

    property bool _sichtbar: false

    function zeigen(text) {
        if (root._sichtbar) return // schon dabei, kein Überlagern
        root._sichtbar = true
        blaseText.text = text
        emergeAnim.restart()
    }

    function _zurueckziehen() {
        if (!root._sichtbar) return
        root._sichtbar = false
        emergeAnim.stop()
        retreatAnim.restart()
    }

    // ── Rohröffnung (Platzhalter, immer sichtbar, dezent) ─────────
    Rectangle {
        id: rohr
        width:  64; height: 18
        radius: 9
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.leftMargin: 20
        color:        "#3a3a3a"
        border.color: "#222222"
        z: 2
    }

    // ── Clip-Bereich: lässt den Körper "aus der Röhre" kommen ─────
    Item {
        id: clipArea
        anchors.bottom: rohr.verticalCenter
        anchors.left:   rohr.left
        width:  rohr.width
        height: 130
        clip:   true
        z: 1

        Rectangle {
            id:     koerper
            width:  48; height: 90
            radius: 24
            color:  "#E91E63"
            x: (clipArea.width - width) / 2
            y: clipArea.height // startet unterhalb des sichtbaren Bereichs

            Rectangle {
                width: 8; height: 8; radius: 4; color: "white"
                x: 12; y: 14
                Rectangle { width: 4; height: 4; radius: 2; color: "black"; anchors.centerIn: parent }
            }
            Rectangle {
                width: 8; height: 2; radius: 1; color: "black"
                x: 28; y: 17
            }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    root._zurueckziehen()
            }
        }
    }

    // ── Sprechblase ────────────────────────────────────────────────
    Rectangle {
        id:      blase
        visible: opacity > 0
        opacity: 0
        width:   200
        height:  blaseCol.implicitHeight + 20
        radius:  10
        color:        root.theme ? root.theme.surface : "#1e2a3a"
        border.color: root.theme ? root.theme.border  : "#2a3a4a"
        border.width: 1
        anchors.left:         clipArea.right
        anchors.leftMargin:   8
        anchors.bottom:       clipArea.bottom
        anchors.bottomMargin: 36

        ColumnLayout {
            id: blaseCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 8

            Text {
                id:               blaseText
                Layout.fillWidth: true
                wrapMode:         Text.WordWrap
                font.pixelSize:   12
                color:            root.theme ? root.theme.textPrimary : "#e2eaf4"
            }

            Rectangle {
                Layout.alignment: Qt.AlignRight
                width: 86; height: 22; radius: 4
                color: nervMa.containsMouse ? "#cc4444" : (root.theme ? root.theme.inputBg : "#222222")

                Text {
                    anchors.centerIn: parent
                    text:           qsTr("Nerv nicht")
                    font.pixelSize: 10
                    color:          nervMa.containsMouse ? "white" : (root.theme ? root.theme.textMuted : "#999999")
                }
                MouseArea {
                    id:           nervMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        rosiManager.nervNicht()
                        root._zurueckziehen()
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: emergeAnim
        NumberAnimation { target: koerper; property: "y";       to: 0; duration: 500; easing.type: Easing.OutBack }
        NumberAnimation { target: blase;   property: "opacity"; to: 1; duration: 250 }
        PauseAnimation  { duration: 12000 }
        ScriptAction    { script: root._zurueckziehen() }
    }

    SequentialAnimation {
        id: retreatAnim
        NumberAnimation { target: blase;   property: "opacity"; to: 0;               duration: 200 }
        NumberAnimation { target: koerper; property: "y";       to: clipArea.height; duration: 400; easing.type: Easing.InBack }
    }
}
