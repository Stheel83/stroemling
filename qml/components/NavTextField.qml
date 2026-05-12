import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: control

    property Item tabTarget:     null
    property Item backtabTarget: null

    activeFocusOnTab:      false
    KeyNavigation.tab:     tabTarget
    KeyNavigation.backtab: backtabTarget
}
