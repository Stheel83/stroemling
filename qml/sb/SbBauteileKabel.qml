import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Kabel-Abschnitt im BAUTEILE-Bereich des Seitenbaums — ausgelagert aus
// SeitenBaumBauteilePanel.qml (REFACTOR-QML-03).
Column {
    id: root
    required property var panel
    required property var theme

    visible: panel._aktiveTab === "alles" || panel._aktiveTab === "kabel"
    width: parent.width
    property var _kabelListe: {
        var _v = panel._kabelVersion
        return panel.visible && panel.projektId >= 0
            ? db.kabelListeMitPos(panel.projektId)
            : []
    }

    Rectangle {
        width: parent.width; height: 1; color: root.theme.divider
    }

    Rectangle {
        width: parent.width; height: 28; color: "transparent"
        visible: parent._kabelListe.length === 0
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
            spacing: 6
            Text { text: "⚡"; font.pixelSize: 11; opacity: 0.35; color: root.theme.textMuted }
            Text {
                text: qsTr("Kabel – mit C zeichnen")
                font.pixelSize: 11; color: root.theme.textMuted; opacity: 0.6
                Layout.fillWidth: true
            }
        }
    }

    Repeater {
        model: parent._kabelListe
        delegate: Column {
            id: kabelItem
            width: parent.width
            property int    kId:          modelData.id
            property string kBez:         modelData.bezeichnung || "–"
            property string kTyp:         modelData.kabeltyp || ""
            property bool   aufgeklappt:  panel._kabelAufgeklappt[kId] === true

            // Kabel-Kopfzeile
            Rectangle {
                width: parent.width; height: 32
                color: panel._highlightKabelId === kabelItem.kId
                    ? root.theme.activeItem
                    : (kabelKopfMA.containsMouse ? root.theme.hover : "transparent")

                // kabelKopfMA zuerst → RowLayout-Kinder liegen darüber
                MouseArea {
                    id: kabelKopfMA; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var kid = kabelItem.kId
                        var auf = Object.assign({}, panel._kabelAufgeklappt)
                        auf[kid] = !auf[kid]
                        if (auf[kid] && panel._kabellinienCache[kid] === undefined) {
                            var c = Object.assign({}, panel._kabellinienCache)
                            c[kid] = db.kabellinienMitPos(kid)
                            panel._kabellinienCache = c
                        }
                        panel._kabelAufgeklappt = auf
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                    spacing: 5
                    Text { text: kabelItem.aufgeklappt ? "▾" : "▸"; font.pixelSize: 9; color: root.theme.textMuted }
                    Text { text: "⚡"; font.pixelSize: 11; color: root.theme.textMuted }
                    Text {
                        text: kabelItem.kBez
                        font.pixelSize: 12; color: root.theme.textPrimary
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
                        text: kabelItem.kTyp
                        font.pixelSize: 10; color: root.theme.textMuted
                        elide: Text.ElideRight
                        Layout.maximumWidth: 90; Layout.minimumWidth: 0
                    }
                }
            }

            // Kabellinie-Liste (lazy geladen)
            Column {
                width: parent.width
                visible: kabelItem.aufgeklappt
                property var linien: panel._kabellinienCache[kabelItem.kId] || []

                // KABEL-VERWAIST-01: keine Kabellinie vorhanden — nie
                // platziert oder die gezeichnete Linie wurde gelöscht.
                Rectangle {
                    width: parent.width; height: 40
                    visible: parent.linien.length === 0
                    color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 22; rightMargin: 8 }
                        spacing: 6
                        Text {
                            text: qsTr("Keine Kabellinie – nie platziert")
                            font.pixelSize: 10; font.italic: true
                            color: root.theme.textMuted; opacity: 0.75
                            Layout.fillWidth: true; elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            implicitWidth: kabelLoeschenText.implicitWidth + 12
                            Layout.minimumWidth: 0
                            height: 20; radius: 3
                            color: kabelLoeschenMA.containsMouse ? root.theme.hover : "transparent"
                            border.color: root.theme.border; border.width: 1
                            Text {
                                id: kabelLoeschenText
                                anchors.centerIn: parent
                                text: qsTr("Löschen")
                                font.pixelSize: 10; color: root.theme.textSecondary
                            }
                            MouseArea {
                                id: kabelLoeschenMA; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: panel.kabelOhneLinieLoeschen(kabelItem.kId)
                            }
                        }
                    }
                }

                Repeater {
                    model: parent.linien
                    delegate: Rectangle {
                        width: parent.width; height: 26
                        color: kabelLinieMA.containsMouse ? root.theme.hover : "transparent"
                        property var ld: modelData

                        // Hover-MA zuerst → Sprung-Button liegt darüber
                        MouseArea {
                            id: kabelLinieMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.ArrowCursor
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 22; rightMargin: 6 }
                            spacing: 4
                            Text {
                                text: ld.blattnr || ""
                                font.pixelSize: 11; color: root.theme.textSecondary
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            Text {
                                text: ld.seiteBez || ""
                                font.pixelSize: 10; color: root.theme.textMuted
                                Layout.minimumWidth: 0
                                elide: Text.ElideRight; Layout.maximumWidth: 80
                            }
                            Rectangle {
                                implicitWidth: 20; Layout.minimumWidth: 0; height: 20; radius: 3
                                color: kabelSprungMA.containsMouse ? root.theme.accent : "transparent"
                                Text {
                                    anchors.centerIn: parent; text: "→"; font.pixelSize: 11
                                    color: kabelSprungMA.containsMouse ? "#ffffff" : root.theme.accent
                                }
                                MouseArea {
                                    id: kabelSprungMA; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var d = ld
                                        panel.sprungAngefordert(d.seiteId, d.blattnr,
                                                               d.seiteBez, d.weltX, d.weltY)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
