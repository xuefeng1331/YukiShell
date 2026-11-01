import QtQuick

Item {
    id: gs

    property var src: null
    property size srcSize: Qt.size(1, 1)
    property point origin: Qt.point(0, 0)
    property color baseColor: "#2B2B2D"

    property bool glass: true
    property url shaderUrl: ""
    property bool dark: true
    property real cornerR: height / 2
    property real thickness: 16
    property real strengthMul: 1.0
    property real liquid: 1.0
    property real rim: 0.45
    property real grain: 0.03
    property real tint: 0.42
    property real tintMul: 1.0
    property real shadowAmt: 0
    property real flatInner: 1
    property real blurPx: 1.5
    signal failed()

    readonly property real pad: 10
    readonly property bool own: src === null
    readonly property real ownM: 40

    Item {
        id: ownLayer
        visible: gs.own && gs.glass
        x: -gs.ownM; y: -gs.ownM
        width: gs.width + 2 * gs.ownM
        height: gs.height + 2 * gs.ownM
        Rectangle { anchors.fill: parent; color: gs.baseColor }
    }
    ShaderEffectSource {
        id: ownSes
        sourceItem: (gs.own && gs.glass) ? ownLayer : null
        hideSource: true
        live: true
        mipmap: true
        visible: false
    }

    Rectangle {
        visible: !gs.glass
        anchors.fill: parent
        radius: gs.cornerR
        color: gs.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.78)
        border.width: 1
        border.color: gs.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.06)
    }

    Loader {
        anchors.fill: parent
        active: gs.glass && gs.shaderUrl.toString() !== ""
        sourceComponent: Item {
            ShaderEffect {
            x: -gs.pad; y: -gs.pad
            width: gs.width + 2 * gs.pad
            height: gs.height + 2 * gs.pad
            fragmentShader: gs.shaderUrl
            onStatusChanged: if (status === ShaderEffect.Error) gs.failed()
            property variant src: gs.own ? ownSes : gs.src
            property vector2d itemSize: Qt.vector2d(width, height)
            property vector2d glassSize: Qt.vector2d(gs.width, gs.height)
            property vector2d srcSize: gs.own ? Qt.vector2d(ownLayer.width, ownLayer.height)
                                              : Qt.vector2d(gs.srcSize.width, gs.srcSize.height)
            property vector2d srcOffset: gs.own ? Qt.vector2d(gs.ownM - gs.pad, gs.ownM - gs.pad)
                                                : Qt.vector2d(gs.origin.x - gs.pad, gs.origin.y - gs.pad)
            property real pad: gs.pad
            property real radius: gs.cornerR
            property real bezel: Math.min(gs.height * 0.36, 26)
            property real thickness: gs.thickness * gs.liquid * gs.strengthMul * 1.6
            property real dispersion: 0.06 * gs.liquid * gs.strengthMul * 1.3
            property real magnify: 0.05 * gs.liquid * gs.strengthMul * 1.6
            property real rim: gs.rim
            property real grain: gs.grain * 0.2
            property real blurPx: gs.blurPx
            property real tintMix: gs.tint * 0.55 * gs.tintMul
            property real saturation: 1.25
            property real dark: gs.dark ? 1 : 0
            property real debug: 0
            property real shadowAmt: gs.shadowAmt
            property real flatInner: gs.flatInner
            property real rimTint: 1
            property real ringW: 0
        }
        }
    }
}
