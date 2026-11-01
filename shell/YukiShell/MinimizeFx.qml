import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: fx
    property var hub: null
    property string effect: "genie"

    property var job: null
    property real progress: 0
    readonly property bool busy: job !== null
    property real speed: 0.42
    readonly property int genieMs: Math.round(Math.max(0.2, Math.min(1.2, speed)) * 1000)
    readonly property int fadeMs: 350

    property bool captured: false
    property var winRect: ({ x: 0, y: 0, width: 1, height: 1 })
    property var targetRect: ({ x: 0, y: 0, width: 1, height: 1 })
    function rectsFrom(j) {
        winRect = j.winFn ? j.winFn() : j.win;
        targetRect = j.targetFn ? j.targetFn() : j.target;
    }
    function play(j) {
        if (busy) { finish(); }
        if (effect === "instant" || !j.tl) {
            if (j.before) j.before();
            if (j.after) j.after();
            return;
        }
        rectsFrom(j);
        progress = j.reverse ? 1 : 0;
        captured = false;
        job = j;
        captureWait.restart();
    }
    function giveUp() {
        console.log("[minimize] no capture in time, doing it without the effect");
        var j = job;
        job = null;
        if (j && j.before) j.before();
        if (j && j.after) j.after();
    }
    property real handover: 1
    function finish() {
        anim.stop();
        captureWait.stop();
        var j = job;
        if (j && j.reverse && effect !== "instant") {
            if (j.after) j.after();
            j.after = null;
            handoverAnim.restart();
            return;
        }
        job = null;
        handover = 1;
        if (j && j.after) j.after();
    }
    NumberAnimation {
        id: handoverAnim
        target: fx; property: "handover"; from: 1; to: 0; duration: 180; easing.type: Easing.OutCubic
        onFinished: { fx.job = null; fx.handover = 1; }
    }
    function start() {
        if (!job) return;
        rectsFrom(job);
        if (job.before) job.before();
        anim.from = job.reverse ? 1 : 0;
        anim.to = job.reverse ? 0 : 1;
        anim.duration = effect === "fade" ? fadeMs : genieMs;
        anim.restart();
    }
    Timer { id: captureWait; interval: 900; onTriggered: if (!fx.captured) fx.giveUp() }
    NumberAnimation {
        id: anim
        target: fx; property: "progress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.22, 0.8, 0.28, 1.0, 1.0, 1.0]
        onFinished: fx.finish()
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: ow
            required property var modelData
            screen: modelData
            readonly property bool mine: fx.job !== null && fx.job.screen === modelData.name
            visible: mine
            contentItem.opacity: fx.handover
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}
            WlrLayershell.namespace: "yukishell-minimize"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property var w: fx.winRect
            readonly property var t: fx.targetRect
            readonly property real ox: modelData.x
            readonly property real oy: modelData.y

            ScreencopyView {
                id: cap
                width: Math.max(1, ow.w.width)
                height: Math.max(1, ow.w.height)
                captureSource: ow.mine ? fx.job.tl : null
                live: false
                visible: false
                onHasContentChanged: {
                    if (hasContent && ow.mine && fx.job && !fx.captured) {
                        fx.captured = true;
                        captureWait.stop();
                        fx.start();
                    }
                }
            }
            ShaderEffectSource { id: capTex; sourceItem: cap; hideSource: true; visible: false; live: true; smooth: true }

            ShaderEffect {
                anchors.fill: parent
                visible: ow.mine && fx.effect === "genie" && fx.captured
                mesh: GridMesh { resolution: Qt.size(6, 64) }
                vertexShader: Qt.resolvedUrl("genie.vert.qsb")
                fragmentShader: Qt.resolvedUrl("genie.frag.qsb")
                property variant source: capTex
                property real progress: fx.progress
                property vector4d win: Qt.vector4d(ow.w.x - ow.ox, ow.w.y - ow.oy, ow.w.width, ow.w.height)
                property vector4d target: Qt.vector4d(ow.t.x - ow.ox, ow.t.y - ow.oy, ow.t.width, ow.t.height)
                onStatusChanged: if (status === ShaderEffect.Error) console.log("[minimize] genie shader:", log)
            }

            Item {
                visible: ow.mine && fx.effect === "fade" && fx.captured
                x: ow.w.x - ow.ox + (ow.t.x + ow.t.width / 2 - ow.w.x - ow.w.width / 2) * fx.progress * 0.12
                y: ow.w.y - ow.oy + (ow.t.y - ow.w.y) * fx.progress * 0.12
                width: ow.w.width
                height: ow.w.height
                opacity: 1 - fx.progress
                scale: 1 - 0.08 * fx.progress
                ShaderEffectSource { anchors.fill: parent; sourceItem: cap; live: true }
            }
        }
    }
}
