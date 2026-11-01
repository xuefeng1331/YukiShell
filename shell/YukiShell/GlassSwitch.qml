import QtQuick

Item {
    id: s

    property bool checked: false
    signal toggled(bool value)
    signal glassFailed()

    property color accentColor: "#30D158"
    property color offColor: Qt.rgba(1, 1, 1, 0.22)
    property color knobColor: "#DCDDDA"
    property color baseColor: "#2B2B2D"
    property bool dark: true
    property bool glass: false
    property url shaderUrl: ""
    property real glassLiquid: 1.0
    property real glassRim: 0.45
    property real glassGrain: 0.03
    property real glassTint: 0.42
    property color borderTint: "#8A9AB5"

    width: 46; height: 21
    opacity: enabled ? 1 : 0.45

    readonly property real inset: Math.max(2, height * 0.085)
    readonly property real kh0: height - 2 * inset
    readonly property real kw0: Math.round(kh0 * 1.6)
    readonly property real travel: width - 2 * inset - kw0

    property real pL: 0
    property real pR: 0
    property real tgt: -1
    property bool ready: false
    property bool dragging: false
    property bool want: false
    readonly property real pm: Math.max(0, Math.min(1, (pL + pR) / 2))

    property bool hold: false
    readonly property bool glassOn: ma.pressed || hold
    property real pressT: glassOn ? 1 : 0
    Behavior on pressT { NumberAnimation { duration: s.glassOn ? 420 : 320; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
    onGlassOnChanged: if (glassOn) ses.scheduleUpdate()
    Timer { id: holdT; interval: 480; onTriggered: s.hold = false }

    readonly property real gw: height * 0.14
    readonly property real gh: height * 0.07
    readonly property real kw: kw0 + gw * pressT
    readonly property real kh: kh0 + gh * pressT
    readonly property real leftEdge: inset + pL * travel - (kw - kw0) / 2
    readonly property real rightEdge: inset + kw0 + pR * travel + (kw - kw0) / 2

    readonly property color trackCol: Qt.rgba(offColor.r + (accentColor.r - offColor.r) * pm,
                                              offColor.g + (accentColor.g - offColor.g) * pm,
                                              offColor.b + (accentColor.b - offColor.b) * pm,
                                              offColor.a + (accentColor.a - offColor.a) * pm)

    NumberAnimation { id: animL; target: s; property: "pL" }
    NumberAnimation { id: animR; target: s; property: "pR" }
    function settleTo(t) {
        if (!ready) { pL = t; pR = t; tgt = t; return; }
        if (t === tgt && (animL.running || animR.running)) return;
        tgt = t;
        var up = t >= (pL + pR) / 2;
        animL.stop(); animR.stop();
        var lead = up ? animR : animL, trail = up ? animL : animR;
        lead.duration = 300;  lead.easing.type = Easing.OutBack;  lead.easing.overshoot = 1.7;
        trail.duration = 440; trail.easing.type = Easing.OutBack; trail.easing.overshoot = 0.9;
        animL.to = t; animR.to = t;
        animL.start(); animR.start();
    }
    function commit(v) {
        if (v !== checked) { want = v; toggled(v); refuse.restart(); }
        settleTo(v ? 1 : 0);
    }
    Timer { id: refuse; interval: 1200; onTriggered: if (s.checked !== s.want) s.settleTo(s.checked ? 1 : 0) }
    onCheckedChanged: { if (ready && !dragging && !ma.pressed) settleTo(checked ? 1 : 0); }
    Component.onCompleted: { pL = checked ? 1 : 0; pR = pL; tgt = pL; ready = true; }

    Rectangle { anchors.fill: parent; radius: height / 2; color: s.trackCol }

    readonly property real m: 22
    Item {
        id: lyr
        visible: s.glass
        x: -s.m; y: -s.m
        width: s.width + 2 * s.m; height: s.height + 2 * s.m
        Rectangle { anchors.fill: parent; color: s.baseColor }
        Rectangle { x: s.m; y: s.m; width: s.width; height: s.height; radius: height / 2; color: s.trackCol; opacity: 0.28 }
    }
    ShaderEffectSource {
        id: ses
        sourceItem: s.glass ? lyr : null
        hideSource: true
        live: s.glass && (s.glassOn || s.pressT > 0.02)
        mipmap: true
        visible: false
    }

    Item {
        id: knob
        x: s.leftEdge
        y: (s.height - height) / 2
        width: Math.max(height, s.rightEdge - s.leftEdge)
        height: s.kh
        readonly property real rad: height / 2
        readonly property real plainOp: s.glass ? Math.max(0, Math.min(1, 1 - s.pressT * 1.4)) : 1

        Rectangle {
            anchors.fill: parent; radius: knob.rad
            color: s.knobColor
            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.08)
            opacity: knob.plainOp
        }
        Loader {
            anchors.fill: parent
            active: s.glass && s.pressT > 0.02
            opacity: Math.max(0, Math.min(1, s.pressT * 1.6))
            sourceComponent: Item {
                GlassSlab {
                    anchors.fill: parent
                    src: ses
                    srcSize: Qt.size(lyr.width, lyr.height)
                    origin: Qt.point(s.m + knob.x, s.m + knob.y)
                    glass: s.glass
                    shaderUrl: s.shaderUrl
                    dark: s.dark
                    cornerR: knob.rad
                    thickness: Math.round(s.kh0 * 1.1)
                    strengthMul: 0.85
                    liquid: s.glassLiquid
                    rim: s.glassRim
                    grain: s.glassGrain
                    tint: s.glassTint
                    shadowAmt: 0.5
                    flatInner: 1
                    onFailed: s.glassFailed()
                }
                CornerBorder { z: 2; anchors.fill: parent; cornerR: knob.rad; dark: s.dark; tint: s.borderTint; amount: 1; lineW: 0.9 }
                Rectangle {
                    anchors.fill: parent
                    radius: knob.rad
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, s.dark ? 0.12 : 0.2) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.02) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, s.dark ? 0.04 : 0.08) }
                    }
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -5
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        property real pressX: 0
        property real lastX: 0
        property real grabDx: 0
        property real vx: 0
        function sx(m) { return ma.mapToItem(s, m.x, m.y).x; }
        onPressed: mouse => {
            holdT.stop(); s.hold = false;
            animL.stop(); animR.stop();
            var a = (s.pL + s.pR) / 2;
            s.pL = a; s.pR = a;
            pressX = sx(mouse); lastX = pressX; vx = 0;
            grabDx = pressX - (s.inset + s.kw0 / 2 + a * s.travel);
            s.dragging = false;
        }
        onPositionChanged: mouse => {
            if (!pressed) return;
            var x = sx(mouse);
            if (!s.dragging && Math.abs(x - pressX) > 3) s.dragging = true;
            if (!s.dragging) return;
            var lo = s.inset + s.kw0 / 2, hi = s.width - s.inset - s.kw0 / 2;
            var c = Math.max(lo, Math.min(hi, x - grabDx));
            var p = (c - lo) / Math.max(1, hi - lo);
            s.pL = p; s.pR = p;
            vx = vx * 0.5 + (x - lastX) * 0.5;
            lastX = x;
        }
        onReleased: mouse => {
            var v;
            if (s.dragging) {
                var p = (s.pL + s.pR) / 2;
                v = Math.abs(vx) > 4 ? vx > 0 : p > 0.5;
            } else {
                v = !s.checked;
            }
            s.dragging = false;
            s.hold = true; holdT.restart();
            s.commit(v);
        }
        onCanceled: {
            s.dragging = false;
            s.hold = true; holdT.restart();
            s.settleTo(s.checked ? 1 : 0);
        }
    }
}
