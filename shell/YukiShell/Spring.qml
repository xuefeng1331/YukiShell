import QtQuick

Item {
    id: sp
    width: 0; height: 0; visible: false

    property real target: 0
    property real value: 0
    property real velocity: 0
    property real response: 0.30
    property real damping: 1.0
    property real epsilon: 0.001
    property bool animated: true
    readonly property bool running: fa.running

    Component.onCompleted: { value = target; velocity = 0; }

    function snap() {
        fa.stop();
        value = target; velocity = 0;
    }

    onTargetChanged: {
        if (!animated) { fa.stop(); value = target; velocity = 0; return; }
        if (Math.abs(target - value) > epsilon || Math.abs(velocity) > epsilon * 10) fa.start();
    }
    onAnimatedChanged: if (!animated) { fa.stop(); value = target; velocity = 0; }

    function step(dt) {
        dt = Math.min(Math.max(dt, 0), 0.05);
        var w = 2 * Math.PI / Math.max(response, 0.02);
        var k = w * w;
        var c = 2 * damping * w;
        var n = Math.max(1, Math.ceil(dt / 0.004));
        var h = dt / n;
        var v = velocity, x = value;
        for (var i = 0; i < n; i++) {
            v += (k * (target - x) - c * v) * h;
            x += v * h;
        }
        velocity = v;
        value = x;
        if (Math.abs(target - x) < epsilon && Math.abs(v) < epsilon * 10) {
            value = target; velocity = 0; fa.stop();
        }
    }

    FrameAnimation {
        id: fa
        onTriggered: sp.step(frameTime)
    }
}
