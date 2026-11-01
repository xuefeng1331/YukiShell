import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "GlassShape.js" as GS

Item {
    id: gp

    property var backdrop: null
    property bool live: false
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

    default property alias content: body.data

    height: bodyH + tailH

    readonly property real m: 64
    readonly property real sp: 48
    readonly property real hp: 2
    property real bx: 0
    property real by: 0
    readonly property string shapeKey: [width, bodyH, tailW, tailH, tailTipR, tailX, radius, dark, live, k, tinted, accent].join("|")

    function syncPos() {
        if (!gp.backdrop) return;
        var p = gp.backdrop.mapFromItem(gp, 0, 0);
        if (Math.abs(p.x - gp.bx) > 0.01) gp.bx = p.x;
        if (Math.abs(p.y - gp.by) > 0.01) gp.by = p.y;
    }
    FrameAnimation {
        running: gp.live && gp.visible && gp.backdrop !== null
        onTriggered: gp.syncPos()
    }
    onVisibleChanged: if (visible) syncPos()
    Component.onCompleted: syncPos()

    Canvas {
        id: shadowCv
        x: -gp.sp; y: -gp.sp
        width: gp.width + 2 * gp.sp
        height: gp.height + 2 * gp.sp
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (gp.width < 2 || gp.bodyH < 2) return;
            ctx.shadowColor = gp.dark ? "rgba(0,0,0,0.50)" : "rgba(0,0,0,0.26)";
            ctx.shadowBlur = 20 * gp.k;
            ctx.shadowOffsetX = 0;
            ctx.shadowOffsetY = 6 * gp.k;
            ctx.fillStyle = "#000000";
            GS.build(ctx, gp.sp, gp.sp, gp.width, gp.bodyH, gp.radius, gp.tailX, gp.tailW, gp.tailH, gp.tailTipR);
            ctx.fill();
            ctx.shadowColor = "rgba(0,0,0,0)";
            ctx.shadowBlur = 0;
            ctx.shadowOffsetY = 0;
            ctx.globalCompositeOperation = "destination-out";
            GS.build(ctx, gp.sp, gp.sp, gp.width, gp.bodyH, gp.radius, gp.tailX, gp.tailW, gp.tailH, gp.tailTipR);
            ctx.fill();
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: gp; function onShapeKeyChanged() { shadowCv.requestPaint(); } }
        Component.onCompleted: requestPaint()
    }

    Loader {
        id: blurLoader
        active: gp.live && gp.backdrop !== null
        x: -gp.m; y: -gp.m
        width: gp.width + 2 * gp.m
        height: gp.height + 2 * gp.m
        sourceComponent: Item {
            ShaderEffectSource {
                id: ses
                sourceItem: gp.backdrop
                sourceRect: Qt.rect(gp.bx - gp.m, gp.by - gp.m, gp.width + 2 * gp.m, gp.height + 2 * gp.m)
                live: gp.visible
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

    Canvas {
        id: skin
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
