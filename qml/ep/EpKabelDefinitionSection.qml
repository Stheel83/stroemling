import QtQuick
import stroemling

Item {
    id: root

    required property var canvas
    required property var panel
    required property var theme

    width:   parent ? parent.width : 0
    height:  (panel.el && panel.el.typ === "kabellinie") ? klCol.implicitHeight : 0
    visible: height > 0
    clip:    true

    Column {
        id: klCol
        width: parent.width; spacing: 0

        EpKabelStammdatenBlock { canvas: root.canvas; panel: root.panel; theme: root.theme }
        EpKabelLinienBlock     { canvas: root.canvas; panel: root.panel; theme: root.theme }
        EpKabelAdernBlock      { canvas: root.canvas; panel: root.panel; theme: root.theme }
    }
}
