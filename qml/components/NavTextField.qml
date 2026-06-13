import QtQuick 2.15
import QtQuick.Controls 2.15

TextField {
    id: control

    property Item tabTarget:     null
    property Item backtabTarget: null

    activeFocusOnTab: false
    Keys.onTabPressed:     { event.accepted = true; if (tabTarget)     tabTarget.forceActiveFocus() }
    Keys.onBacktabPressed: { event.accepted = true; if (backtabTarget) backtabTarget.forceActiveFocus() }
}
