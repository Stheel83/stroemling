import QtQuick
import QtQuick.Layouts

// Rosi Röhrenaal — Maskottchen-Assistentin, siehe konzept/features/48_rosi_roehrenaal.md.
// Taucht aus einer Rohröffnung am unteren Fensterrand auf, zeigt einen Spruch
// in einer Sprechblase, zieht sich nach ~12s oder per Klick wieder zurück.
// Verwendung: rosiSprechblase.zeigen(text) – ausgelöst von rosiManager.auftauchen.
// rosiSprechblase.vorwarnen(sekunden) – ausgelöst von rosiManager.vorwarnung,
// lässt die Rohröffnung über die angegebene Dauer langsam einfaden, damit
// sich der Nutzer auf den Auftritt einstellen kann (konzept §4/§6).
//
// Körper-Asset (rosi_roehrenaal.png) und Rohröffnung (rosi_rohroeffnung.png)
// sind seit ROSI-01 echte Bilder.

Item {
    id: root

    property var theme

    width:  240
    height: 180

    property bool _sichtbar:          false
    property real _rohrOpazitaetBasis: 0.45
    property real _rohrOpazitaet:      _rohrOpazitaetBasis

    function zeigen(text) {
        if (root._sichtbar) return // schon dabei, kein Überlagern
        root._sichtbar = true
        blaseText.text = text
        emergeAnim.restart()
    }

    function vorwarnen(sekunden) {
        rohrRueckgangAnim.stop()
        rohrFadeAnim.duration = Math.max(500, sekunden * 1000)
        rohrFadeAnim.restart()
    }

    function _zurueckziehen() {
        if (!root._sichtbar) return
        root._sichtbar = false
        emergeAnim.stop()
        retreatAnim.restart()
        rohrFadeAnim.stop()
        rohrRueckgangAnim.restart()
    }

    NumberAnimation {
        id:       rohrFadeAnim
        target:   root
        property: "_rohrOpazitaet"
        to:       1.0
    }

    NumberAnimation {
        id:       rohrRueckgangAnim
        target:   root
        property: "_rohrOpazitaet"
        to:       root._rohrOpazitaetBasis
        duration: 2000
    }

    // ── Rohröffnung (immer sichtbar, dezent, fadet vor dem Auftritt ein) ──
    Image {
        id:       rohr
        source:   "qrc:/assets/rosi_rohroeffnung.png"
        width:    100; height: width * 403 / 443 // Bild-Seitenverhältnis
        fillMode: Image.PreserveAspectFit
        opacity:  root._rohrOpazitaet
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.leftMargin: 12
        z: 2
    }

    // ── Clip-Bereich: lässt den Körper aus der Öffnung im Rohr-Bild
    //    kommen (Öffnung sitzt oben mittig im Bild, daher negativer
    //    bottomMargin, um in das Rohr-Bild einzutauchen) ───────────
    Item {
        id: clipArea
        anchors.horizontalCenter: rohr.horizontalCenter
        anchors.bottom:           rohr.top
        anchors.bottomMargin:     -18
        width:  56
        height: 130
        clip:   true
        z: 1

        Image {
            id:       koerper
            source:   "qrc:/assets/rosi_roehrenaal.png"
            width:    56; height: 112
            fillMode: Image.PreserveAspectFit
            x: (clipArea.width - width) / 2
            y: clipArea.height // startet unterhalb des sichtbaren Bereichs

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
