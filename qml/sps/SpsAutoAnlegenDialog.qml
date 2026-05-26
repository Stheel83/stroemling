import QtQuick 2.15
import QtQuick.Controls 2.15

Dialog {
    id: root

    property var theme
    property var bg: null

    signal bestaetigt()

    title: qsTr("Kanäle automatisch anlegen")
    modal: true
    anchors.centerIn: parent
    width: 360
    standardButtons: Dialog.Ok | Dialog.Cancel

    Label {
        width: parent.width
        wrapMode: Text.WordWrap
        color: root.theme.textPrimary
        text: {
            if (!root.bg) return ""
            var vorh = db.spsKanalListeFuerBaugruppe(root.bg.id).length
            return qsTr("Die Baugruppe \"%1\" hat bereits %2 Kanal(e).\nNeu anlegen überspringt Adresskonflikte.\nFortfahren?").arg(root.bg.bezeichnung || root.bg.typ).arg(vorh)
        }
    }

    onAccepted: root.bestaetigt()
}
