import QtQuick
import QtQuick.Effects

Item {
    id: g
    property Item backdrop: null
    property url shaderUrl: ""
    property bool liquid: false
    property bool dark: true
    property real bx: 0
    property real by: 0
    property real cornerR: 20
    property real tint: 0.4
    property real thickness: 30
    property real strength: 1.0
    property real rim: 0.45
    property real rimTint: 0
    property real shadowAmt: 1
    property real flatInner: 0
    property real ringW: 0
    property real grain: 0.03
    property real blur: 5
    property bool debug: false
    property vector4d accentTint: Qt.vector4d(0, 0, 0, 0)
    signal shaderError()

    Rectangle {
        visible: !g.liquid
        anchors.fill: parent
        radius: g.cornerR
        color: g.dark ? Qt.rgba(0.12, 0.12, 0.13, 0.30 + g.tint * 0.9) : Qt.rgba(1, 1, 1, 0.30 + g.tint * 0.7)
        border.width: 1
        border.color: g.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.55)
    }
    Loader {
        anchors.fill: parent
        active: g.liquid && g.backdrop !== null && g.visible
        sourceComponent: Item {
            id: lg
            readonly property real m: 72
            readonly property real p: 10
            readonly property real ds: g.blur >= 8 ? 0.5 : 1.0
            readonly property real bn: g.blur * 1.4 * ds / 64.0
            ShaderEffectSource {
                id: bsrc
                sourceItem: g.backdrop
                hideSource: true
                live: true
                visible: false
                sourceRect: Qt.rect(g.bx - lg.p - lg.m, g.by - lg.p - lg.m,
                                    g.width + 2 * (lg.p + lg.m), g.height + 2 * (lg.p + lg.m))
                textureSize: Qt.size(Math.max(1, Math.round(sourceRect.width * lg.ds)), Math.max(1, Math.round(sourceRect.height * lg.ds)))
            }
            MultiEffect {
                id: bblurFx
                source: bsrc
                width: bsrc.sourceRect.width * lg.ds; height: bsrc.sourceRect.height * lg.ds
                blurEnabled: true
                blurMax: 64
                blur: Math.min(1.0, lg.bn)
                autoPaddingEnabled: false
                visible: false
            }
            ShaderEffectSource {
                id: bblur
                sourceItem: bblurFx
                live: true
                visible: false
            }
            MultiEffect {
                id: bblur2Fx
                source: bblur
                width: bsrc.sourceRect.width * lg.ds; height: bsrc.sourceRect.height * lg.ds
                blurEnabled: lg.bn > 1.0
                blurMax: 64
                blur: Math.max(0.0, Math.min(1.0, lg.bn - 1.0))
                autoPaddingEnabled: false
                visible: false
            }
            ShaderEffectSource {
                id: bblur2
                sourceItem: lg.bn > 1.0 ? bblur2Fx : null
                live: true
                visible: false
            }
            ShaderEffect {
                id: fx
                x: -lg.p; y: -lg.p
                width: g.width + 2 * lg.p
                height: g.height + 2 * lg.p
                fragmentShader: g.shaderUrl
                onStatusChanged: {
                    console.log("[yukibar-glass] shader status:", status, "(0 = compiled, 1 = uncompiled, 2 = error)", log);
                    if (status === ShaderEffect.Error) g.shaderError();
                }
                property variant src: lg.bn > 1.0 ? bblur2 : bblur
                property real padPx: lg.p
                property vector2d itemSize: Qt.vector2d(width, height)
                property vector2d glassSize: Qt.vector2d(g.width, g.height)
                property vector2d srcSize: Qt.vector2d(bsrc.sourceRect.width, bsrc.sourceRect.height)
                property vector2d srcOffset: Qt.vector2d(lg.m, lg.m)
                property real pad: lg.p
                property real radius: g.cornerR
                property real bezel: Math.min(g.height * 0.36, 26)
                property real thickness: g.thickness * g.strength * 1.6
                property real dispersion: 0.06 * g.strength * 1.3
                property real magnify: 0.05 * g.strength * 1.6
                property real rim: g.rim
                property real grain: g.grain * 0.2
                property real blurPx: 1.5
                property real tintMix: g.tint * 0.55
                property vector4d accentTint: g.accentTint
                property real saturation: 1.25
                property real dark: g.dark ? 1 : 0
                property real debug: g.debug ? 1 : 0
                property real shadowAmt: g.shadowAmt
                property real flatInner: g.flatInner
                property real rimTint: g.rimTint
                property real ringW: g.ringW
            }
        }
    }
}
