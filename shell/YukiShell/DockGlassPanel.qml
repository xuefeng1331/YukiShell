import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "GlassShape.js" as GS

Item {
    id: gp

    property var backdrop: null
    property bool live: false
    // frozen: keep the blurred picture as it is (no re-capture) until false again; it takes hold after a moment, so the bubble first
    // gets one current picture at its final place
    property bool frozen: false
    property bool hold: false
    Timer { id: holdT; interval: 160; onTriggered: gp.hold = true }
    onFrozenChanged: { if (frozen) holdT.restart(); else { holdT.stop(); hold = false; } }
    property bool shadow: true           // false: no drop shadow (the canvas is not even painted)
    property bool dark: false
    property real k: 1
    property real radius: 16
    property real bodyH: 28
    property real tailW: 0
    property real tailH: 0
    property real tailTipR: 3
    property real tailX: width / 2
    property real blurAmount: 0.85
    property bool tinted: false
    property color accent: "#0A84FF"
    // Liquid Glass, as the menus have it: give it the Dock (glassShaderUrl, liquidActive, glassOpacity ...). While that is on the
    // bubble is the liquid pane over the same backdrop instead of the plain blur, and has no tail.
    property var glass: null
    readonly property bool liquidOn: glass !== null && glass !== undefined && glass.liquidActive === true && backdrop !== null && live
    readonly property real tW: liquidOn ? 0 : tailW
    readonly property real tH: liquidOn ? 0 : tailH

    default property alias content: body.data

    height: bodyH + tailH

    readonly property real m: 64
    readonly property real sp: 48
    readonly property real hp: 2
    property real bx: 0
    property real by: 0
    readonly property string shapeKey: [width, bodyH, tailW, tailH, tailTipR, tailX, radius, dark, live, k, tinted, accent, liquidOn].join("|")

    function syncPos() {
        if (!gp.backdrop || gp.hold) return;
        var p = gp.backdrop.mapFromItem(gp, 0, 0);
        if (Math.abs(p.x - gp.bx) > 0.01) gp.bx = p.x;
        if (Math.abs(p.y - gp.by) > 0.01) gp.by = p.y;
    }
    FrameAnimation {
        running: gp.live && gp.visible && gp.backdrop !== null && !gp.hold
        onTriggered: gp.syncPos()
    }
    onVisibleChanged: if (visible) syncPos()
    Component.onCompleted: syncPos()

    Canvas {
        id: shadowCv
        visible: gp.shadow
        x: -gp.sp; y: -gp.sp
        width: gp.width + 2 * gp.sp
        height: gp.height + 2 * gp.sp
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (!gp.shadow || gp.width < 2 || gp.bodyH < 2) return;
            ctx.shadowColor = gp.dark ? "rgba(0,0,0,0.50)" : "rgba(0,0,0,0.26)";
            ctx.shadowBlur = 20 * gp.k;
            ctx.shadowOffsetX = 0;
            ctx.shadowOffsetY = 6 * gp.k;
            ctx.fillStyle = "#000000";
            GS.build(ctx, gp.sp, gp.sp, gp.width, gp.bodyH, gp.radius, gp.tailX, gp.tW, gp.tH, gp.tailTipR);
            ctx.fill();
            ctx.shadowColor = "rgba(0,0,0,0)";
            ctx.shadowBlur = 0;
            ctx.shadowOffsetY = 0;
            ctx.globalCompositeOperation = "destination-out";
            GS.build(ctx, gp.sp, gp.sp, gp.width, gp.bodyH, gp.radius, gp.tailX, gp.tW, gp.tH, gp.tailTipR);
            ctx.fill();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: gp; function onShapeKeyChanged() { shadowCv.requestPaint(); } }
        Component.onCompleted: requestPaint()
    }

    Loader {
        id: blurLoader
        active: gp.live && gp.backdrop !== null && !gp.liquidOn
        x: -gp.m; y: -gp.m
        width: gp.width + 2 * gp.m
        height: gp.height + 2 * gp.m
        sourceComponent: Item {
            ShaderEffectSource {
                id: ses
                sourceItem: gp.backdrop
                sourceRect: Qt.rect(gp.bx - gp.m, gp.by - gp.m, gp.width + 2 * gp.m, gp.height + 2 * gp.m)
                live: gp.visible && !gp.hold
                visible: false
            }
            Shape {
                id: maskShape
                width: parent.width
                height: parent.height
                layer.enabled: true
                layer.samples: 4
                visible: false
                ShapePath {
                    fillColor: "#000000"
                    strokeColor: "transparent"
                    strokeWidth: -1
                    PathSvg { path: GS.svg(gp.m, gp.m, gp.width, gp.bodyH, gp.radius, gp.tailX, gp.tailW, gp.tailH, gp.tailTipR) }
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: ses
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: gp.blurAmount
                saturation: 0.30
                brightness: gp.dark ? -0.03 : 0.03
                maskEnabled: true
                maskSource: maskShape
            }
        }
    }

    LiquidPane {
        visible: gp.liquidOn
        width: gp.width
        height: gp.bodyH
        backdrop: gp.liquidOn ? gp.backdrop : null
        shaderUrl: gp.glass ? gp.glass.glassShaderUrl : ""
        liquid: gp.liquidOn
        dark: gp.dark
        bx: gp.bx; by: gp.by
        shadowAmt: 0
        flatInner: 1
        rimTint: 1
        ringW: 0
        cornerR: gp.radius
        tint: gp.glass ? gp.glass.glassOpacity : 0.42
        thickness: 22
        strength: gp.glass ? gp.glass.glassLiquidEff : 1
        rim: gp.glass ? gp.glass.glassRimEff : 0.45
        grain: gp.glass ? gp.glass.glassGrain : 0.03
        blur: gp.glass ? gp.glass.glassBlurEff : 5
        accentTint: gp.glass ? gp.glass.accentTintVec : Qt.vector4d(0, 0, 0, 0)
    }
    MenuBorder {
        visible: gp.liquidOn
        z: 2
        width: gp.width
        height: gp.bodyH
        cornerR: gp.radius
        dark: gp.dark
        tint: gp.glass && gp.glass.bar ? gp.glass.bar.menuBorderColor : "#8A9AB5"
    }

    Canvas {
        id: skin
        visible: !gp.liquidOn
        x: -gp.hp; y: -gp.hp
        width: gp.width + 2 * gp.hp
        height: gp.height + 2 * gp.hp
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var W = gp.width, H = gp.bodyH, pd = gp.hp, TH = gp.tailH;
            if (W < 2 || H < 2) return;
            function outline() { GS.build(ctx, pd, pd, W, H, gp.radius, gp.tailX, gp.tailW, TH, gp.tailTipR); }
            function tc(r, g, b, a) {
                if (gp.tinted) {
                    var c = gp.accent;
                    var t = gp.dark ? [c.r * 0.40, c.g * 0.40, c.b * 0.40] : [c.r + (1 - c.r) * 0.70, c.g + (1 - c.g) * 0.70, c.b + (1 - c.b) * 0.70];
                    r += (t[0] * 255 - r) * 0.6; g += (t[1] * 255 - g) * 0.6; b += (t[2] * 255 - b) * 0.6;
                }
                return "rgba(" + Math.round(r) + "," + Math.round(g) + "," + Math.round(b) + "," + a + ")";
            }

            outline();
            ctx.lineWidth = 2;
            ctx.strokeStyle = gp.dark ? "rgba(0,0,0,0.40)" : "rgba(0,0,0,0.13)";
            ctx.stroke();
            ctx.globalCompositeOperation = "destination-out";
            outline();
            ctx.fillStyle = "#000000";
            ctx.fill();
            ctx.globalCompositeOperation = "source-over";

            var g = ctx.createLinearGradient(0, pd, 0, pd + H + TH);
            if (gp.dark) {
                g.addColorStop(0, gp.live ? tc(56, 56, 62, 0.50) : tc(54, 54, 59, 0.78));
                g.addColorStop(1, gp.live ? tc(30, 30, 34, 0.58) : tc(34, 34, 38, 0.82));
            } else {
                g.addColorStop(0, gp.live ? tc(255, 255, 255, 0.44) : tc(246, 246, 249, 0.80));
                g.addColorStop(1, gp.live ? tc(255, 255, 255, 0.36) : tc(236, 236, 241, 0.84));
            }
            outline();
            ctx.fillStyle = g;
            ctx.fill();

            ctx.save();
            outline();
            ctx.clip();
            var rg = ctx.createLinearGradient(0, pd, 0, pd + H);
            if (gp.dark) {
                rg.addColorStop(0.00, "rgba(255,255,255,0.30)");
                rg.addColorStop(0.30, "rgba(255,255,255,0.10)");
                rg.addColorStop(0.70, "rgba(255,255,255,0.08)");
                rg.addColorStop(1.00, "rgba(255,255,255,0.18)");
            } else {
                rg.addColorStop(0.00, "rgba(255,255,255,0.55)");
                rg.addColorStop(0.30, "rgba(255,255,255,0.18)");
                rg.addColorStop(0.70, "rgba(255,255,255,0.12)");
                rg.addColorStop(1.00, "rgba(255,255,255,0.22)");
            }
            outline();
            ctx.lineWidth = 2;
            ctx.strokeStyle = rg;
            ctx.stroke();
            ctx.restore();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: gp; function onShapeKeyChanged() { skin.requestPaint(); } }
        Component.onCompleted: requestPaint()
    }

    Item {
        id: body
        width: gp.width
        height: gp.bodyH
    }
}
