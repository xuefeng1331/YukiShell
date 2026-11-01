import QtQuick
import QtQuick.Effects

Item {
    id: k
    property real glass: 0
    property string material: "liquid"
    property real restW: 20
    property real restH: 20
    property real grow: 1.6
    property real growH: 0.18
    property bool dark: true
    property color fillColor: "#0A84FF"
    property color restColor: Qt.rgba(1, 1, 1, 0.2)
    property real trackH: 4
    property real leftRoom: 1e6
    property real rightRoom: 1e6

    readonly property bool liquid: material === "liquid" || material === "custom"
    readonly property real lens: material === "opaque" ? 0 : Math.max(0, Math.min(1, glass))
    width: restW + (restW * grow - restW) * glass
    height: restH + restH * growH * glass

    Rectangle {
        anchors.fill: body
        anchors.topMargin: 1.5; anchors.bottomMargin: -1.5
        radius: body.radius
        color: Qt.rgba(0, 0, 0, 0.22 * (1 - k.lens * 0.55))
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 10; blur: 0.7; autoPaddingEnabled: true }
    }
    Rectangle {
        id: body
        anchors.fill: parent
        radius: height / 2
        color: k.liquid ? Qt.rgba(1, 1, 1, 1 - 0.8 * k.lens) : Qt.rgba(1, 1, 1, 1 - 0.4 * k.lens)
        clip: true

        Item {
            visible: k.liquid && k.lens > 0.01
            opacity: k.lens * 0.9
            anchors.fill: parent
            readonly property real mag: 1.35
            readonly property real th: Math.min(parent.height * 0.8, k.trackH * mag)
            Rectangle {
                x: parent.width / 2 - width; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width / 2, k.leftRoom * parent.mag); height: parent.th; radius: height / 2
                color: k.fillColor
            }
            Rectangle {
                x: parent.width / 2; anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width / 2, k.rightRoom * parent.mag); height: parent.th; radius: height / 2
                color: k.restColor
            }
        }
        Rectangle {
            visible: k.lens > 0.01
            opacity: k.lens
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, k.liquid ? 0.34 : 0.22) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.04) }
                GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, k.liquid ? 0.16 : 0.08) }
            }
        }
    }
    Rectangle {
        visible: k.liquid && k.lens > 0.01
        opacity: k.lens * 0.5
        x: -0.7; y: 0; width: parent.width; height: parent.height
        radius: height / 2
        color: "transparent"
        border.width: 1.2
        border.color: Qt.rgba(1, 0.25, 0.3, 0.6)
    }
    Rectangle {
        visible: k.liquid && k.lens > 0.01
        opacity: k.lens * 0.5
        x: 0.7; y: 0; width: parent.width; height: parent.height
        radius: height / 2
        color: "transparent"
        border.width: 1.2
        border.color: Qt.rgba(0.3, 0.55, 1, 0.6)
    }
    Rectangle {
        visible: k.lens > 0.01
        opacity: k.lens
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 0.8
        border.color: Qt.rgba(1, 1, 1, k.liquid ? 0.6 : 0.4)
    }
}
