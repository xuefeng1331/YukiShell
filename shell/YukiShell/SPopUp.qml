import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "Fonts.js" as Fonts

Item {
    id: pu
    required property var t
    property var model: []
    property int current: 0
    signal picked(int index)
    width: 220; height: 28
    Rectangle {
        anchors.fill: parent; anchors.leftMargin: -8; anchors.rightMargin: -8; radius: 8
        color: puMa.containsMouse || menu.visible ? pu.t.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    Text {
        anchors.right: chev.left; anchors.rightMargin: 8
        y: Math.round((parent.height - height) / 2)
        width: parent.width - 16; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
        text: pu.model[pu.current] !== undefined ? pu.model[pu.current] : ""
        color: pu.t.text; font.family: pu.t.fam; font.pixelSize: 14
    }
    Canvas {
        id: chev
        anchors.right: parent.right
        y: 8
        width: 8; height: 12
        property color ink: pu.t.text2
        onInkChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            c.strokeStyle = ink; c.lineWidth = 1.4; c.lineCap = "round"; c.lineJoin = "round";
            c.beginPath(); c.moveTo(1, 4.2); c.lineTo(4, 1.2); c.lineTo(7, 4.2); c.stroke();
            c.beginPath(); c.moveTo(1, 7.8); c.lineTo(4, 10.8); c.lineTo(7, 7.8); c.stroke();
        }
    }
    function openMenu() { menu.open(); }
    MouseArea { id: puMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menu.open() }

    Popup {
        id: menu
        readonly property real rowH: 28
        width: Math.max(pu.width + 16, 192)
        x: pu.width + 8 - width
        margins: 8
        height: pu.model.length * rowH + 8
        y: -(4 + pu.current * rowH)
        padding: 4
        modal: false; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 320; easing.type: Easing.OutQuint }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; to: 0.97; duration: 180; easing.type: Easing.OutCubic }
            }
        }
        background: MenuGlass { t: pu.t; from: pu; open: menu.visible; cornerR: 12 }
        contentItem: Flickable {
            clip: true
            contentHeight: menuCol.height
            boundsBehavior: Flickable.StopAtBounds
            Component.onCompleted: contentY = Math.max(0, Math.min(contentHeight - height, (pu.current - 2) * menu.rowH))
        Column {
            id: menuCol
            Repeater {
                model: pu.model
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: menu.width - 8; height: menu.rowH; radius: 8
                    color: rowMa.containsMouse ? pu.t.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: 90 } }
                    Text {
                        x: 8; y: Math.round((parent.height - height) / 2)
                        text: "\u2713"; visible: row.index === pu.current
                        color: rowMa.containsMouse ? "white" : pu.t.text; font.family: Fonts.forWeight(Font.Bold, pu.t.fam); font.pixelSize: 12; font.bold: true
                    }
                    Text {
                        x: 28; y: Math.round((parent.height - height) / 2)
                        width: parent.width - 36; elide: Text.ElideRight
                        text: row.modelData
                        color: rowMa.containsMouse ? "white" : pu.t.text; font.family: pu.t.fam; font.pixelSize: 14
                    }
                    MouseArea {
                        id: rowMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: { menu.close(); if (row.index !== pu.current) pu.picked(row.index); }
                    }
                }
            }
        }
        }
    }
}
