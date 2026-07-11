import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
    id: root
    required property var editor

    color:  editor.theme.sidebar

    ColumnLayout {
        anchors { fill: parent; margins: 8 }
        spacing: 4

        // Header
        RowLayout {
            Text { text: qsTr("Pins:"); font.pixelSize: 12; font.weight: Font.Medium; color: root.editor.theme.textPrimary }
            Text { text: "  " + qsTr("Name"); width: 56; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Text { text: qsTr("x (mm)");    width: 62; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Text { text: qsTr("y (mm)");    width: 62; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Text { text: qsTr("Richtung"); width: 96; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Text { text: qsTr("Signaltyp"); width: 95; font.pixelSize: 10; color: root.editor.theme.textMuted }
            Item { Layout.fillWidth: true }

            Button {
                text: "↔ H"; implicitHeight: 24; implicitWidth: 40
                ToolTip.visible: hovered; ToolTip.delay: 600
                ToolTip.text: qsTr("Waagerecht: Pin 1 links (0 mm), Pin 2 rechts (%1 mm)").arg(root.editor.breiteMm)
                onClicked: {
                    var yMid = 0.5
                    root.editor.pins = [
                        {name:"1", x:0.0, y:yMid, offenX:-1, offenY:0, signaltyp:"neutral", kontext:""},
                        {name:"2", x:1.0, y:yMid, offenX:1,  offenY:0, signaltyp:"neutral", kontext:""}
                    ]
                    root.editor.ausgewaehltPinIdx = -1
                    root.editor.repaintAll()
                }
                background: Rectangle { color: parent.hovered ? root.editor.theme.badge : "transparent"; radius: 4; border.color: root.editor.theme.accent; border.width: 1 }
                contentItem: Text { text: parent.text; color: root.editor.theme.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            Button {
                text: "↕ V"; implicitHeight: 24; implicitWidth: 40
                ToolTip.visible: hovered; ToolTip.delay: 600
                ToolTip.text: qsTr("Senkrecht: Pin 1 oben (0 mm), Pin 2 unten (%1 mm)").arg(root.editor.hoeheMm)
                onClicked: {
                    var xMid = 0.5
                    root.editor.pins = [
                        {name:"1", x:xMid, y:0.0, offenX:0, offenY:-1, signaltyp:"neutral", kontext:""},
                        {name:"2", x:xMid, y:1.0, offenX:0, offenY:1,  signaltyp:"neutral", kontext:""}
                    ]
                    root.editor.ausgewaehltPinIdx = -1
                    root.editor.repaintAll()
                }
                background: Rectangle { color: parent.hovered ? root.editor.theme.badge : "transparent"; radius: 4; border.color: root.editor.theme.accent; border.width: 1 }
                contentItem: Text { text: parent.text; color: root.editor.theme.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            Button {
                text: qsTr("+ Pin"); implicitHeight: 24; implicitWidth: 58
                onClicked: {
                    root.editor.pins = root.editor.pins.concat([{name:"P"+(root.editor.pins.length+1),x:0.5,y:1,offenX:0,offenY:1,signaltyp:"neutral",kontext:""}])
                    root.editor.ausgewaehltPinIdx = root.editor.pins.length - 1
                    root.editor.repaintAll()
                }
                background: Rectangle { color: parent.hovered ? root.editor.theme.badge : "transparent"; radius: 4; border.color: root.editor.theme.accent; border.width: 1 }
                contentItem: Text { text: parent.text; color: root.editor.theme.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }

        ListView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            model: root.editor.pins
            clip:  true

            delegate: Rectangle {
                width:  ListView.view.width; height: 30; radius: 3
                color:  root.editor.ausgewaehltPinIdx === index ? root.editor.theme.badge : "transparent"

                property int myIdx: index
                property var myPin: root.editor.pins[index] || {}

                TapHandler {
                    onTapped: {
                        root.editor.ausgewaehltPinIdx  = myIdx
                        root.editor.ausgewaehltPrimIdx = -1
                        root.editor.repaintAll()
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4; leftPadding: 4

                    TextField {
                        width: 54; height: 30; font.pixelSize: 11
                        text: parent.parent.myPin.name || ""
                        background: Rectangle { color: root.editor.theme.inputBg; radius: 3; border.color: root.editor.theme.border }
                        color: root.editor.theme.textPrimary
                        onEditingFinished: {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.name = text; arr[parent.parent.myIdx] = p; root.editor.pins = arr
                        }
                    }

                    TextField {
                        width: 58; height: 30; font.pixelSize: 11
                        text: root.editor.normToMmX(parent.parent.myPin.x !== undefined ? parent.parent.myPin.x : 0).toFixed(2)
                        validator: DoubleValidator { bottom: 0; top: root.editor.breiteMm; decimals: 2 }
                        background: Rectangle { color: root.editor.theme.inputBg; radius: 3; border.color: root.editor.theme.border }
                        color: root.editor.theme.textPrimary
                        onEditingFinished: {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.x = (parseFloat(text)||0) / root.editor.breiteMm
                            arr[parent.parent.myIdx] = p; root.editor.pins = arr
                            root.editor.repaintAll()
                        }
                    }

                    TextField {
                        width: 58; height: 30; font.pixelSize: 11
                        text: root.editor.normToMmY(parent.parent.myPin.y !== undefined ? parent.parent.myPin.y : 0.5).toFixed(2)
                        validator: DoubleValidator { bottom: 0; top: root.editor.hoeheMm; decimals: 2 }
                        background: Rectangle { color: root.editor.theme.inputBg; radius: 3; border.color: root.editor.theme.border }
                        color: root.editor.theme.textPrimary
                        onEditingFinished: {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.y = (parseFloat(text)||0.5) / root.editor.hoeheMm
                            arr[parent.parent.myIdx] = p; root.editor.pins = arr
                            root.editor.repaintAll()
                        }
                    }

                    // Richtung (offen-Vektor)
                    Row {
                        spacing: 2
                        Repeater {
                            model: [{l:"←",ox:-1,oy:0},{l:"→",ox:1,oy:0},{l:"↑",ox:0,oy:-1},{l:"↓",ox:0,oy:1}]
                            delegate: Rectangle {
                                width: 22; height: 30; radius: 3
                                property var outerPin: parent.parent.parent.myPin
                                property int outerIdx: parent.parent.parent.myIdx
                                color: (outerPin.offenX===modelData.ox && outerPin.offenY===modelData.oy)
                                       ? root.editor.theme.accent
                                       : (dirHover.containsMouse ? root.editor.theme.badge : "transparent")
                                Text {
                                    anchors.centerIn: parent; text: modelData.l; font.pixelSize: 13
                                    color: (parent.outerPin.offenX===modelData.ox && parent.outerPin.offenY===modelData.oy) ? "white" : root.editor.theme.textPrimary
                                }
                                HoverHandler { id: dirHover }
                                TapHandler {
                                    onTapped: {
                                        var arr = root.editor.pins.slice()
                                        var p   = Object.assign({}, arr[parent.outerIdx])
                                        p.offenX = modelData.ox; p.offenY = modelData.oy
                                        arr[parent.outerIdx] = p; root.editor.pins = arr
                                        root.editor.repaintAll()
                                    }
                                }
                            }
                        }
                    }

                    ComboBox {
                        width: 140; height: 30
                        model: ["neutral","power","pe","n","dc_plus","dc_minus","input_digital","output_digital","input_analog","output_analog","kommunikation","temp","stepper","sicherheit","fe"]
                        font.pixelSize: 10
                        currentIndex: {
                            var st = parent.parent.myPin.signaltyp || "neutral"
                            var i2 = model.indexOf(st); return i2 >= 0 ? i2 : 0
                        }
                        onActivated: function(idx) {
                            var arr = root.editor.pins.slice()
                            var p   = Object.assign({}, arr[parent.parent.myIdx])
                            p.signaltyp = model[idx]; arr[parent.parent.myIdx] = p; root.editor.pins = arr
                        }
                        background: Rectangle { color: root.editor.theme.inputBg; border.color: root.editor.theme.border; radius: 4 }
                        contentItem: Text { text: parent.displayText; color: root.editor.theme.textPrimary; font.pixelSize: 10;
                                            leftPadding: 6; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    }

                    Rectangle {
                        width: 22; height: 30; radius: 3
                        color: delHover.containsMouse ? "#3a1a1a" : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 12; color: "#ff4444" }
                        HoverHandler { id: delHover }
                        TapHandler {
                            onTapped: {
                                var myI = parent.parent.parent.myIdx
                                root.editor.pins = root.editor.pins.filter(function(_, i2) { return i2 !== myI })
                                if (root.editor.ausgewaehltPinIdx >= root.editor.pins.length)
                                    root.editor.ausgewaehltPinIdx = -1
                                root.editor.repaintAll()
                            }
                        }
                    }
                }
            }
        }
    }
    DebugLabel { panelName: qsTr("SE Pin-Liste"); visible: editor.debug }
}
