import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var editor

    height: 44
    color: editor.theme.sidebar

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 8

        TextField {
            id: nameFeld
            text:              editor.nameText
            onEditingFinished: editor.nameText = text
            placeholderText:   qsTr("Symbolname")
            implicitWidth: 170; implicitHeight: 28
            font.pixelSize: 13
            background: Rectangle { color: editor.theme.inputBg; radius: 4; border.color: editor.theme.border }
            color: editor.theme.textPrimary
        }

        TextField {
            id: katFeld
            text:              editor.kategorieText
            onEditingFinished: editor.kategorieText = text
            placeholderText:   qsTr("Kategorie")
            implicitWidth: 130; implicitHeight: 28
            font.pixelSize: 13
            background: Rectangle { color: editor.theme.inputBg; radius: 4; border.color: editor.theme.border }
            color: editor.theme.textPrimary
        }

        Text { text: qsTr("Breite:"); color: editor.theme.textMuted; font.pixelSize: 11 }
        ComboBox {
            model: [8, 16, 24, 32]
            currentIndex: Math.max(0, [8,16,24,32].indexOf(editor.breiteMm))
            onActivated: editor.breiteMm = model[currentIndex]
            implicitWidth: 68; implicitHeight: 28; font.pixelSize: 12
            background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
            contentItem: Text { text: parent.displayText; color: editor.theme.textPrimary; font.pixelSize: 12;
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }
        Text { text: "mm"; color: editor.theme.textMuted; font.pixelSize: 11 }

        Text { text: qsTr("Höhe:"); color: editor.theme.textMuted; font.pixelSize: 11 }
        ComboBox {
            model: [8, 16, 24, 32]
            currentIndex: Math.max(0, [8,16,24,32].indexOf(editor.hoeheMm))
            onActivated: editor.hoeheMm = model[currentIndex]
            implicitWidth: 68; implicitHeight: 28; font.pixelSize: 12
            background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
            contentItem: Text { text: parent.displayText; color: editor.theme.textPrimary; font.pixelSize: 12;
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }
        Text { text: "mm"; color: editor.theme.textMuted; font.pixelSize: 11 }

        Text { text: qsTr("Rolle:"); color: editor.theme.textMuted; font.pixelSize: 11 }
        ComboBox {
            model: ["durchleiter", "verbraucher", "quelle", "trenner", "variabel"]
            currentIndex: Math.max(0, model.indexOf(editor.rolleText))
            onCurrentIndexChanged: editor.rolleText = model[currentIndex]
            implicitWidth: 115; implicitHeight: 28; font.pixelSize: 12
            background: Rectangle { color: editor.theme.inputBg; border.color: editor.theme.border; radius: 4 }
            contentItem: Text { text: parent.displayText; color: editor.theme.textPrimary; font.pixelSize: 12;
                                leftPadding: 8; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: editor.istBuiltin
            radius: 4; color: "#40331a"
            border.color: "#cc8800"; border.width: 1
            implicitWidth: eingebautLabel.implicitWidth + 16; implicitHeight: 28
            Text {
                id: eingebautLabel
                anchors.centerIn: parent
                text: qsTr("⚠ Eingebaut – nur als Vorlage kopierbar")
                color: "#ffbb44"; font.pixelSize: 11
            }
        }

        Button {
            text: qsTr("Speichern")
            enabled: !editor.istBuiltin
            implicitHeight: 28; implicitWidth: 90
            onClicked: editor.speichern()
            background: Rectangle { color: parent.enabled ? (parent.hovered ? Qt.lighter(editor.theme.accent) : editor.theme.accent) : editor.theme.btnDisabled; radius: 4 }
            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }

        Button {
            text:    qsTr("SQL")
            visible: editor.editSymbolId !== ""
            implicitHeight: 28; implicitWidth: 58
            onClicked: {
                var sql = editor.sqlAlsText(editor.editSymbolId)
                editor.kopiereInZwischenablage(sql)
                sqlKopiertTimer.restart()
            }
            background: Rectangle {
                color: parent.hovered ? editor.theme.badge : "transparent"
                radius: 4; border.color: editor.theme.accent; border.width: 1
            }
            contentItem: Text {
                text: sqlKopiertTimer.running ? qsTr("✓ OK") : parent.text
                color: editor.theme.accent; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            Timer { id: sqlKopiertTimer; interval: 1500 }
            ToolTip.visible: hovered; ToolTip.delay: 600
            ToolTip.text: qsTr("SQL-INSERT für dieses Symbol in Zwischenablage kopieren")
        }

        Button {
            text: qsTr("Abbrechen")
            implicitHeight: 28; implicitWidth: 90
            flat: true
            onClicked: editor.abgebrochen()
            background: Rectangle { color: parent.hovered ? editor.theme.badge : "transparent"; radius: 4 }
            contentItem: Text { text: parent.text; color: editor.theme.textMuted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
    }
}
