import QtQuick

Item {
    id: r
    property bool on: false
    property bool dark: true
    property real radius: 10
    property real ringW: 2.5
    opacity: on ? 1 : 0
    scale: on ? 1 : 1.07
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    Loader {
        anchors.fill: parent
        active: r.on || r.visible
        sourceComponent: Item {
            Rectangle {
                anchors.fill: parent; anchors.margins: -2
                radius: r.radius + 2; color: "transparent"
                border.width: 2
                border.color: r.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0.2, 0.3, 0.5, 0.14)
            }
            Rectangle {
                anchors.fill: parent
                radius: r.radius; color: "transparent"
                border.width: r.ringW
                border.color: r.dark ? Qt.rgba(1, 1, 1, 0.78) : Qt.rgba(0.30, 0.36, 0.48, 0.62)
            }
            Rectangle {
                anchors.fill: parent; anchors.margins: r.ringW
                radius: Math.max(0, r.radius - r.ringW); color: "transparent"
                border.width: 1
                border.color: r.dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.7)
            }
            CornerBorder { anchors.fill: parent; cornerR: r.radius; dark: r.dark; tint: "#BFD0F0"; amount: 1; lineW: 1.1; fade: false }
        }
    }
}
