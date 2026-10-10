import QtQuick
import QtQuick.Window

// Eigene Titelleiste des rahmenlosen Hauptfensters: Fensterverschieben per Drag,
// Doppelklick maximiert, gezeichnete Minimieren/Maximieren/Schließen-Schaltflächen.
Rectangle {
    id:      root
    height:  36
    color:   root.theme.sidebar

    required property var theme
    property string projektName: ""
    readonly property var fenster: Window.window

    // Fenster verschieben per Drag (X11 + Wayland)
    DragHandler {
        target:          null
        onActiveChanged: if (active) root.fenster.startSystemMove()
    }

    TapHandler {
        onDoubleTapped: root.fenster.visibility === Window.Maximized
                        ? root.fenster.showNormal() : root.fenster.showMaximized()
    }

    // Trennlinie unten
    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 1
        color:  root.theme.border
    }

    // App-Titel (zentriert)
    Text {
        anchors.centerIn: parent
        text:             root.projektName !== ""
                          ? "Strömling Design – " + root.projektName
                          : "Strömling Design"
        color:            root.theme.textMuted
        font.pixelSize:   13
        font.weight:      Font.Medium
        elide:            Text.ElideRight
        width:            parent.width - 220
        horizontalAlignment: Text.AlignHCenter
    }

    // Fenster-Schaltflächen (rechts) – gezeichnete Icons, fontunabhängig
    Row {
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 2

        // Minimieren (—)
        Rectangle {
            width: 28; height: 28; radius: 4
            color: miniMa.containsMouse ? root.theme.hover : "transparent"
            Rectangle {
                width: 12; height: 2; radius: 1
                anchors.centerIn: parent
                color: miniMa.containsMouse ? root.theme.textPrimary : root.theme.textMuted
            }
            MouseArea {
                id: miniMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fenster.showMinimized()
            }
        }

        // Maximieren / Wiederherstellen (□ / ❐)
        Rectangle {
            width: 28; height: 28; radius: 4
            color: maxMa.containsMouse ? root.theme.hover : "transparent"
            Item {
                width: 12; height: 12
                anchors.centerIn: parent
                // Normal: einfaches Quadrat
                Rectangle {
                    visible:      root.fenster.visibility !== Window.Maximized
                    anchors.fill: parent
                    color:   "transparent"
                    border.color: maxMa.containsMouse ? root.theme.textPrimary : root.theme.textMuted
                    border.width: 1.5
                }
                // Maximiert: zwei versetzte Quadrate (Restore-Icon)
                Rectangle {
                    visible:      root.fenster.visibility === Window.Maximized
                    x: 2; y: 0; width: 10; height: 10
                    color:        "transparent"
                    border.color: maxMa.containsMouse ? root.theme.textPrimary : root.theme.textMuted
                    border.width: 1.5
                }
                Rectangle {
                    visible:      root.fenster.visibility === Window.Maximized
                    x: 0; y: 2; width: 10; height: 10
                    color:        root.theme.sidebar
                    border.color: maxMa.containsMouse ? root.theme.textPrimary : root.theme.textMuted
                    border.width: 1.5
                }
            }
            MouseArea {
                id: maxMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fenster.visibility === Window.Maximized
                           ? root.fenster.showNormal() : root.fenster.showMaximized()
            }
        }

        // Schließen (×)
        Rectangle {
            width: 28; height: 28; radius: 4
            color: closeMa.containsMouse ? "#c0392b" : "transparent"
            Item {
                width: 12; height: 12
                anchors.centerIn: parent
                Rectangle {
                    anchors.centerIn: parent; width: 14; height: 2; radius: 1
                    color:    closeMa.containsMouse ? "#ffffff" : root.theme.textMuted
                    rotation: 45
                }
                Rectangle {
                    anchors.centerIn: parent; width: 14; height: 2; radius: 1
                    color:    closeMa.containsMouse ? "#ffffff" : root.theme.textMuted
                    rotation: -45
                }
            }
            MouseArea {
                id: closeMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fenster.close()
            }
        }
    }
}
