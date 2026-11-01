import QtQuick
import QtQuick.Effects

Item {
    id: fb
    property Item target: null
    property real topHold: 52
    property real topDepth: 30
    property real topAmount: 1
    property real edgeAlpha: 0.35
    property real blurMax: 24
    property real radiusScale: 1.0
    readonly property real radius: 9
    readonly property real pad: 24
    readonly property real stripH: topHold + topDepth + pad
    readonly property real sp0: topHold / stripH
    readonly property real sp1: (topHold + topDepth) / stripH
    readonly property real hp0: Math.min(0.85, topHold / Math.max(1, height))
    readonly property real hp1: Math.min(0.95, Math.max(hp0 + 0.01, (topHold + topDepth) / Math.max(1, height)))

    ShaderEffectSource {
        id: raw
        sourceItem: fb.target
        hideSource: fb.target !== null
        live: true
        visible: false
        width: fb.width; height: fb.height
    }

    Item {
        id: sharpMask
        visible: false; layer.enabled: true
        width: fb.width; height: fb.height
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 0.0; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 1.00000) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 0.125; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 0.95703) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 0.25; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 0.84375) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 0.375; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 0.68359) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 0.5; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 0.50000) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 0.625; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 0.31641) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 0.75; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 0.15625) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 0.875; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 0.04297) }
                    GradientStop { position: fb.hp0 + (fb.hp1 - fb.hp0) * 1.0; color: Qt.rgba(0, 0, 0, 1 - fb.topAmount * 0.00000) }
                GradientStop { position: 1.0; color: "black" }
            }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: raw
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: sharpMask
    }

    Item {
        id: part
        visible: fb.target !== null && fb.topAmount > 0.01
        width: fb.width; height: fb.stripH
        ShaderEffectSource {
            id: src
            sourceItem: fb.target
            sourceRect: Qt.rect(0, 0, part.width, part.height)
            width: part.width; height: part.height
            live: true; visible: false
        }
        Item {
            id: blurMask
            visible: false; layer.enabled: true
            width: part.width; height: part.height
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, fb.topAmount) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 0.0; color: Qt.rgba(0, 0, 0, fb.topAmount * 1.00000) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 0.125; color: Qt.rgba(0, 0, 0, fb.topAmount * 0.95703) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 0.25; color: Qt.rgba(0, 0, 0, fb.topAmount * 0.84375) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 0.375; color: Qt.rgba(0, 0, 0, fb.topAmount * 0.68359) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 0.5; color: Qt.rgba(0, 0, 0, fb.topAmount * 0.50000) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 0.625; color: Qt.rgba(0, 0, 0, fb.topAmount * 0.31641) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 0.75; color: Qt.rgba(0, 0, 0, fb.topAmount * 0.15625) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 0.875; color: Qt.rgba(0, 0, 0, fb.topAmount * 0.04297) }
                    GradientStop { position: fb.sp0 + (fb.sp1 - fb.sp0) * 1.0; color: Qt.rgba(0, 0, 0, fb.topAmount * 0.00000) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
                }
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: src
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: fb.blurMax
            blur: Math.min(1, fb.radius * fb.radiusScale / fb.blurMax)
            maskEnabled: true
            maskSource: blurMask
        }
    }
}
