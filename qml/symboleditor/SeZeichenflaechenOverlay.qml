import QtQuick
import QtQuick.Controls

// Overlay-Bedienelemente der Symboleditor-Zeichenfläche: Vorschau-Drehung/Spiegelung (oben links),
// Zoom-Steuerung (oben rechts), Koordinaten-Anzeige und Werkzeug-Status (unten).
// Füllt die Zeichenfläche; Zustand liegt im Editor (`editor`), neu gezeichnet wird über `canvas`.
Item {
    id: root
    required property var editor
    required property var canvas

    anchors.fill: parent

    // Vorschau-Drehung (SYMBOL-TEXT-LESBAR-01-Folge, oben links): rein
    // visuelle Kontrolle, ob Primitive/Text bei allen 4 Symbol-Rotationen +
    // Spiegelungen noch in die Box passen - ändert keine gespeicherten Daten.
    Row {
        anchors { top: parent.top; left: parent.left; topMargin: 4; leftMargin: 6 }
        spacing: 3

        Text {
            text: qsTr("Vorschau:")
            color: editor.theme.textMuted; font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 3
        }

        Repeater {
            model: [0, 90, 180, 270]
            Button {
                required property int modelData
                text: modelData + "°"
                flat: true; checkable: true; implicitWidth: 32; implicitHeight: 24
                checked: editor._sePreviewRotation === modelData
                ToolTip.text: qsTr("Symbol in der Vorschau um %1° drehen").arg(modelData)
                ToolTip.visible: hovered; ToolTip.delay: 500
                onClicked: {
                    editor._sePreviewRotation = modelData
                    root.canvas.requestPaint()
                }
                contentItem: Text {
                    text: parent.text; font.pixelSize: 10
                    color: parent.checked ? editor.theme.accent : editor.theme.textMuted
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.checked ? editor.theme.hover : "transparent"
                    radius: 4; border.color: editor.theme.border
                }
            }
        }
        Button {
            text: qsTr("↔ H"); flat: true; checkable: true; implicitWidth: 42; implicitHeight: 24
            checked: editor._sePreviewSpiegelX
            ToolTip.text: qsTr("Vorschau horizontal spiegeln"); ToolTip.visible: hovered; ToolTip.delay: 500
            onClicked: { editor._sePreviewSpiegelX = checked; root.canvas.requestPaint() }
            contentItem: Text {
                text: parent.text; font.pixelSize: 10
                color: parent.checked ? editor.theme.accent : editor.theme.textMuted
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.checked ? editor.theme.hover : "transparent"
                radius: 4; border.color: editor.theme.border
            }
        }
        Button {
            text: qsTr("↕ V"); flat: true; checkable: true; implicitWidth: 42; implicitHeight: 24
            checked: editor._sePreviewSpiegelY
            ToolTip.text: qsTr("Vorschau vertikal spiegeln"); ToolTip.visible: hovered; ToolTip.delay: 500
            onClicked: { editor._sePreviewSpiegelY = checked; root.canvas.requestPaint() }
            contentItem: Text {
                text: parent.text; font.pixelSize: 10
                color: parent.checked ? editor.theme.accent : editor.theme.textMuted
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.checked ? editor.theme.hover : "transparent"
                radius: 4; border.color: editor.theme.border
            }
        }
    }

    // Zoom-Steuerung (oben rechts, analog zu CanvasHeaderBar)
    Row {
        anchors { top: parent.top; right: parent.right; topMargin: 4; rightMargin: 6 }
        spacing: 0

        Button {
            text: qsTr("−"); flat: true; implicitWidth: 26; implicitHeight: 26
            contentItem: Text { text: parent.text; color: editor.theme.accent; font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? editor.theme.hover : "transparent"; radius: 4 }
            onClicked: {
                var s = Math.max(0.15, editor._seZoom / 1.25) / editor._seZoom
                editor._sePanX = editor._sePanX * s; editor._sePanY = editor._sePanY * s
                editor._seZoom = Math.max(0.15, editor._seZoom / 1.25)
                root.canvas.requestPaint()
            }
        }
        Text {
            text: Math.round(editor._seZoom * 100) + "%"
            color: editor.theme.accent; font.pixelSize: 12; font.weight: Font.Medium
            leftPadding: 2; rightPadding: 2
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    editor._seZoom = 1.0; editor._sePanX = 0.0; editor._sePanY = 0.0
                    root.canvas.requestPaint()
                }
            }
        }
        Button {
            text: "+"; flat: true; implicitWidth: 26; implicitHeight: 26
            contentItem: Text { text: parent.text; color: editor.theme.accent; font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: parent.hovered ? editor.theme.hover : "transparent"; radius: 4 }
            onClicked: {
                var s = Math.min(8.0, editor._seZoom * 1.25) / editor._seZoom
                editor._sePanX = editor._sePanX * s; editor._sePanY = editor._sePanY * s
                editor._seZoom = Math.min(8.0, editor._seZoom * 1.25)
                root.canvas.requestPaint()
            }
        }
    }

    // Koordinaten-Anzeige
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; margins: 6 }
        color: "#80000018"; radius: 3
        width: koordinatenLbl.implicitWidth + 22; height: 30
        Text {
            id: koordinatenLbl
            anchors.centerIn: parent
            text: editor.mausImCanvas
                  ? "x: " + editor.normToMmX(editor.mausNormPos.x).toFixed(1) + " mm   y: " + editor.normToMmY(editor.mausNormPos.y).toFixed(1) + " mm"
                  : ""
            font.pixelSize: 13; color: "#aabbcc"
        }
    }

    // Werkzeug-Status
    Rectangle {
        anchors { bottom: parent.bottom; right: parent.right; margins: 6 }
        color: "#80000018"; radius: 3
        width: werkzeugStatusLbl.implicitWidth + 12; height: 20
        visible: editor.werkzeugPunkte.length > 0
        Text {
            id: werkzeugStatusLbl
            anchors.centerIn: parent
            text: {
                switch (editor.aktivesWerkzeug) {
                case "linie":
                case "rechteck":
                case "kreis_offen": return qsTr("Endpunkt klicken")
                case "bogen":
                    if (editor.werkzeugPunkte.length === 1) return qsTr("Startwinkel klicken")
                    return qsTr("Endwinkel klicken")
                default: return ""
                }
            }
            font.pixelSize: 11; color: "#ffcc66"
        }
    }
}
