import QtQuick

Item {
    id: mb
    property color tint: "#8A9AB5"
    property bool dark: true
    property real cornerR: 14
    property real amount: 1
    property bool outline: true

    Behavior on tint { ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }

    Rectangle {
        visible: mb.outline
        anchors.fill: parent
        anchors.margins: -1
        radius: mb.cornerR + 1
        color: "transparent"
        antialiasing: true
        border.width: 1
        border.color: mb.dark ? Qt.rgba(0, 0, 0, 0.42 * mb.amount) : Qt.rgba(0, 0, 0, 0.14 * mb.amount)
    }
    Rectangle {
        anchors.fill: parent
        radius: mb.cornerR
        color: "transparent"
        antialiasing: true
        border.width: 1.25
        border.color: Qt.rgba(mb.tint.r, mb.tint.g, mb.tint.b, (mb.dark ? 0.16 : 0.12) * mb.amount)
    }
}
