import QtQuick
import QtQuick.Effects

Item {
    id: mg
    required property var t
    required property Item from
    property bool open: false
    property real cornerR: 12

    readonly property bool glassOn: t.glassReady === true && page !== null
    readonly property Item page: {
        var ci = from ? from.Window.contentItem : null;
        if (!ci) return null;
        var p = from;
        while (p && p.parent && p.parent !== ci) p = p.parent;
        return (p && p.parent === ci) ? p : null;
    }
    property point org: Qt.point(0, 0)
    function remap() { if (page) org = mg.mapToItem(page, 0, 0); }
    property int ticks: 0
    Timer {
        id: follow
        interval: 30; repeat: true
        onTriggered: { mg.remap(); if (++mg.ticks > 14) stop(); }
    }
    onOpenChanged: if (open) { ticks = 0; remap(); follow.restart(); }
    onWidthChanged: if (open) remap()
    onHeightChanged: if (open) remap()

    ShaderEffectSource {
        id: pageSrc
        sourceItem: (mg.open && mg.glassOn) ? mg.page : null
        hideSource: false
        live: mg.open
        mipmap: true
        visible: false
    }
    GlassSlab {
        anchors.fill: parent
        visible: mg.glassOn
        src: pageSrc
        srcSize: mg.page ? Qt.size(mg.page.width, mg.page.height) : Qt.size(1, 1)
        origin: mg.org
        cornerR: mg.cornerR
        glass: mg.glassOn
        shaderUrl: mg.t.shaderUrl
        dark: mg.t.dark
        thickness: 22
        liquid: mg.t.gLiquid
        rim: mg.t.gRim
        grain: mg.t.gGrain
        tint: mg.t.gTint
        blurPx: Math.max(1.5, mg.t.gBlur)
        shadowAmt: 0
        flatInner: 1
    }
    RectangularShadow { visible: !mg.glassOn; anchors.fill: parent; radius: mg.cornerR; blur: 24; offset.y: 8; color: Qt.rgba(0, 0, 0, 0.35) }
    Rectangle {
        anchors.fill: parent; radius: mg.cornerR
        color: mg.glassOn ? "transparent" : (mg.t.dark ? Qt.rgba(0.16, 0.16, 0.18, 0.985) : Qt.rgba(0.98, 0.98, 0.99, 0.99))
        border.width: 1; border.color: mg.t.dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.10)
    }
}
