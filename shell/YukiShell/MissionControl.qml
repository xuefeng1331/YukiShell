import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "I18n.js" as I18n
import "Fonts.js" as Fonts
import "MissionLayout.js" as MissionLayout

// Mission Control (every window on the current desktop, spread out, with the desktops along the top) and App Exposé (one app's
// windows on every desktop). Click a window to go to it, click a desktop to switch, drop a window on a desktop to move it there.
Scope {
    id: root
    property var hub: null
    readonly property var dock: hub ? hub.dock : null
    readonly property var bar: hub ? hub.bar : null
    readonly property string fam: dock ? dock.fontFamily : "Open Runde"

    property bool shown: false
    property string appClass: ""          // "" = Mission Control, a window class = App Exposé
    property int serial: 0                // bumped on every open: the windows are laid out again

    function open(cls) {
        appClass = cls || "";
        if (hub) hub.kickGeo();
        serial++;
        shown = true;
    }
    function close() { shown = false; }
    function toggle() { if (shown && appClass === "") close(); else open(""); }
    function showApp(cls) { if (shown && appClass === cls) close(); else open(cls); }
    function showActiveApp() {
        var a = Hyprland.activeToplevel, o = a ? a.lastIpcObject : null;
        if (o && o["class"]) showApp(o["class"]); else toggle();
    }

    function eval_(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }
    function goTo(c) {
        close();
        eval_("hl.dispatch(hl.dsp.focus({ workspace = \"" + c.ws + "\" })); hl.dispatch(hl.dsp.focus({ window = \"address:" + c.addr + "\" })); "
              + "hl.dispatch(hl.dsp.window.bring_to_top())");
    }
    function goToWs(id) { close(); eval_("hl.dispatch(hl.dsp.focus({ workspace = \"" + id + "\" }))"); }
    function sendTo(addr, id) {
        eval_("hl.dispatch(hl.dsp.window.move({ workspace = \"" + id + "\", follow = false, window = \"address:" + addr + "\" }))");
        if (hub) hub.kickGeo();
    }
    function iconFor(cls) { return bar && bar.appIconFor ? bar.appIconFor(cls) : ""; }

    readonly property var clients: hub ? (hub.glassClients || []) : []
    function monFor(name) {
        var ms = hub ? (hub.monData || []) : [];
        for (var i = 0; i < ms.length; i++) if (ms[i].name === name) return ms[i];
        return null;
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: w
            required property var modelData
            screen: modelData
            readonly property var mon: root.monFor(modelData.name)
            readonly property int monId: mon ? mon.id : -1
            readonly property int curWs: mon && mon.activeWorkspace ? mon.activeWorkspace.id : 0
            readonly property bool focusedHere: Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === modelData.name

            property real t: root.shown ? 1 : 0
            Behavior on t { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
            visible: root.shown || t > 0.002
            anchors { left: true; right: true; top: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "yukimission"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.shown && w.focusedHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // ── the windows of this screen, laid out once per open (and again when one of them closes) ──
            readonly property real sw: modelData.width       // the screen's size: the window itself is 0 x 0 until it is shown
            readonly property real sh: modelData.height
            readonly property real stripH: Math.round(sh * 0.15)
            ListModel { id: wm }
            property int sel: -1
            property var moved: ({})      // dropped on another desktop: gone from here before Hyprland's list says so
            property string key: ""
            // fresh: a new open (everything flies in from where it is); otherwise only what changed moves to its new place
            function build(fresh) {
                var cs = root.clients, list = [], i, c;
                for (i = 0; i < cs.length; i++) {
                    c = cs[i];
                    if (!c.workspace || c.workspace.id <= 0 || c.monitor !== w.monId || !c.mapped || c.hidden || moved[c.address]) continue;
                    if (root.appClass !== "" ? c["class"] !== root.appClass : c.workspace.id !== w.curWs) continue;
                    list.push(c);
                }
                // reading order of where they are now, so they move as little as possible
                list.sort(function (a, b) { return (a.at[1] - b.at[1]) || (a.at[0] - b.at[0]); });
                var k = list.map(function (c) { return c.address + c.workspace.id + "," + c.size; }).join(";");
                if (!fresh && k === key) return;
                key = k;
                var sizes = list.map(function (c) { return { w: Math.max(80, c.size[0]), h: Math.max(60, c.size[1]) }; });
                var top = stripH + 40, mx = 70;
                var g = MissionLayout.grid(sizes, w.sw - 2 * mx, w.sh - top - 70, 36, 0.85);
                var out = [];
                for (i = 0; i < list.length; i++) {
                    c = list[i];
                    var here = c.workspace.id === w.curWs && !!w.mon;
                    var gx = g[i].x + mx, gy = g[i].y + top;
                    out.push({ addr: c.address, cls: c["class"] || "", title: c.title || "", ws: c.workspace.id, floating: !!c.floating,
                               here: here, gx: gx, gy: gy, gw: g[i].w, gh: g[i].h,
                               rx: here ? c.at[0] - w.mon.x : gx + g[i].w * 0.08, ry: here ? c.at[1] - w.mon.y : gy + g[i].h * 0.08,
                               rw: here ? c.size[0] : g[i].w * 0.84, rh: here ? c.size[1] : g[i].h * 0.84 });
                }
                if (fresh) { wm.clear(); for (i = 0; i < out.length; i++) wm.append(out[i]); sel = -1; return; }
                var want = {};
                for (i = 0; i < out.length; i++) want[out[i].addr] = out[i];
                for (i = wm.count - 1; i >= 0; i--) if (!want[wm.get(i).addr]) wm.remove(i);
                for (i = 0; i < out.length; i++) {
                    var j = -1;
                    for (var n = 0; n < wm.count; n++) if (wm.get(n).addr === out[i].addr) { j = n; break; }
                    if (j >= 0) wm.set(j, out[i]); else wm.append(out[i]);
                }
                if (sel >= wm.count) sel = wm.count - 1;
            }
            Connections {
                target: root
                function onSerialChanged() { w.moved = ({}); w.build(true); }
            }
            onVisibleChanged: if (!visible) wm.clear()
            // windows closed, re-tiled or moved away while Mission Control is up: the rest move to their new places
            Connections {
                target: root.hub
                enabled: root.shown
                function onGlassClientsChanged() { w.build(false); }
            }

            // ── desktops along the top ──
            readonly property var spaces: {
                var ids = {}, cs = root.clients, i, out = [];
                if (curWs > 0) ids[curWs] = true;
                for (i = 0; i < cs.length; i++)
                    if (cs[i].workspace && cs[i].workspace.id > 0 && cs[i].monitor === monId) ids[cs[i].workspace.id] = true;
                for (var k in ids) out.push(parseInt(k));
                out.sort(function (a, b) { return a - b; });
                return out;
            }
            function freeWs() {
                var used = {}, cs = root.clients, i, n = 1;
                for (i = 0; i < cs.length; i++) if (cs[i].workspace) used[cs[i].workspace.id] = true;
                var ws = Hyprland.workspaces ? Hyprland.workspaces.values : [];
                for (i = 0; i < ws.length; i++) if (ws[i].id === curWs) used[curWs] = true;
                while (used[n]) n++;
                return n;
            }
            function spaceAt(p) {   // p in window coordinates
                for (var i = 0; i < spaceRow.children.length; i++) {
                    var s = spaceRow.children[i];
                    if (!s.wsId) continue;
                    var q = s.mapFromItem(content, p.x, p.y);
                    if (q.x >= 0 && q.y >= 0 && q.x <= s.width && q.y <= s.height) return s.wsId;
                }
                return 0;
            }
            property int dropWs: 0

            Item {
                id: content
                anchors.fill: parent
                focus: root.shown
                Keys.onPressed: e => {
                    var n = wm.count;
                    if (e.key === Qt.Key_Escape) { root.close(); e.accepted = true; }
                    else if (n > 0 && (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab)) { w.sel = (w.sel + 1) % n; e.accepted = true; }
                    else if (n > 0 && (e.key === Qt.Key_Left || e.key === Qt.Key_Up || e.key === Qt.Key_Backtab)) { w.sel = (w.sel + n - 1) % n; e.accepted = true; }
                    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && w.sel >= 0 && w.sel < n) { root.goTo(wm.get(w.sel)); e.accepted = true; }
                }

                // the wallpaper, a little blurred and dimmed, fading in over the real desktop
                Item {
                    anchors.fill: parent
                    opacity: w.t
                    Image {
                        id: wall
                        anchors.fill: parent
                        source: root.dock ? root.dock.fileUrl(root.dock.wallpaperFor(w.modelData.name)) : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: Math.round(w.width / 2)
                        asynchronous: true
                        visible: false
                    }
                    MultiEffect { anchors.fill: parent; source: wall; blurEnabled: true; blurMax: 48; blur: 0.5; autoPaddingEnabled: false }
                    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.30) }
                    TapHandler { onTapped: root.close() }
                }

                Text {
                    anchors.centerIn: parent
                    visible: wm.count === 0 && root.shown
                    opacity: w.t * 0.7
                    text: I18n.tr("No open windows")
                    color: "white"
                    font.family: Fonts.forWeight(Font.DemiBold, root.fam); font.pixelSize: 20; font.weight: Font.DemiBold
                }

                // ── desktop strip ──
                Item {
                    id: strip
                    visible: root.appClass === ""
                    width: parent.width; height: w.stripH
                    y: -height * 0.6 * (1 - w.t)
                    opacity: w.t
                    Row {
                        id: spaceRow
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 4
                        spacing: 18
                        Repeater {
                            model: w.spaces
                            delegate: Item {
                                id: sp
                                required property var modelData
                                readonly property int wsId: modelData
                                readonly property bool cur: wsId === w.curWs
                                readonly property bool hot: spHover.hovered || w.dropWs === wsId
                                height: w.stripH - 46
                                width: Math.round(height * w.sw / Math.max(1, w.sh))
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    radius: 10
                                    color: "transparent"
                                    border.width: 3
                                    border.color: sp.cur ? "white" : Qt.rgba(1, 1, 1, sp.hot ? 0.55 : 0)
                                }
                                Item {
                                    id: spPic
                                    anchors.fill: parent
                                    layer.enabled: true
                                    layer.effect: MultiEffect { maskEnabled: true; maskSource: spMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                                    Image { anchors.fill: parent; source: wall.source; fillMode: Image.PreserveAspectCrop; sourceSize.width: 320; asynchronous: true }
                                    Repeater {   // the desktop's windows as small tiles with their icons
                                        model: root.clients.filter(function (c) { return c.workspace && c.workspace.id === sp.wsId && c.monitor === w.monId && w.mon; })
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property real k: sp.width / Math.max(1, w.sw)
                                            x: (modelData.at[0] - w.mon.x) * k; y: (modelData.at[1] - w.mon.y) * k
                                            width: modelData.size[0] * k; height: modelData.size[1] * k
                                            radius: 3
                                            color: Qt.rgba(0.16, 0.16, 0.18, 0.92)
                                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                                            Image {
                                                anchors.centerIn: parent
                                                width: Math.min(28, parent.width * 0.6, parent.height * 0.6); height: width
                                                source: root.iconFor(parent.modelData["class"] || "")
                                                sourceSize: Qt.size(64, 64)
                                                asynchronous: true
                                            }
                                        }
                                    }
                                }
                                Item { id: spMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: 7; color: "black" } }
                                Text {
                                    anchors.top: parent.bottom; anchors.topMargin: 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: I18n.tr("Desktop") + " " + sp.wsId
                                    color: "white"
                                    font.family: Fonts.forWeight(Font.DemiBold, root.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                                    style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35)
                                }
                                HoverHandler { id: spHover }
                                TapHandler { onTapped: root.goToWs(sp.wsId) }
                            }
                        }
                        // a new, empty desktop
                        Item {
                            height: w.stripH - 46
                            width: Math.round(height * w.sw / Math.max(1, w.sh)) * 0.5
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Qt.rgba(1, 1, 1, plusHover.hovered ? 0.22 : 0.12)
                                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                            }
                            Text { anchors.centerIn: parent; text: "+"; color: "white"; font.pixelSize: 30; font.weight: Font.Light }
                            HoverHandler { id: plusHover }
                            TapHandler { onTapped: root.goToWs(w.freeWs()) }
                        }
                    }
                }

                // ── the windows ──
                Repeater {
                    model: wm
                    delegate: Item {
                        id: wi
                        required property int index
                        required property string addr
                        required property string cls
                        required property string title
                        required property int ws
                        required property bool floating
                        required property bool here
                        required property real gx
                        required property real gy
                        required property real gw
                        required property real gh
                        required property real rx
                        required property real ry
                        required property real rw
                        required property real rh
                        // the grid place eases to a new spot when the layout changes while open (a window left or was re-tiled)
                        property real ax: gx
                        property real ay: gy
                        property real aw: gw
                        property real ah: gh
                        Behavior on ax { enabled: w.t > 0.99; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on ay { enabled: w.t > 0.99; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on aw { enabled: w.t > 0.99; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on ah { enabled: w.t > 0.99; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        readonly property real k: w.t
                        readonly property bool hot: hov.hovered || w.sel === index
                        readonly property bool dragging: drag.active
                        x: rx + (ax - rx) * k + (dragging ? drag.activeTranslation.x : 0)
                        y: ry + (ay - ry) * k + (dragging ? drag.activeTranslation.y : 0)
                        width: rw + (aw - rw) * k
                        height: rh + (ah - rh) * k
                        z: dragging ? 10 : (hot ? 5 : (floating ? 2 : 1))
                        opacity: here ? 1 : k
                        scale: dragging ? 0.55 : 1
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        RectangularShadow {
                            anchors.fill: parent
                            radius: 10
                            blur: 28; spread: 0; offset.y: 8
                            color: Qt.rgba(0, 0, 0, 0.45 * wi.k)
                        }
                        Item {
                            id: pic
                            anchors.fill: parent
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: picMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                            Rectangle { anchors.fill: parent; color: Qt.rgba(0.13, 0.13, 0.15, 1) }
                            Capture {
                                id: cap
                                anchors.fill: parent
                                source: (w.visible && root.hub && root.hub.windowCapture) ? (root.hub.tlTick, root.hub.tlFor(wi.addr)) : null
                                Timer {
                                    interval: 250; repeat: true
                                    running: root.shown && cap.captureSource !== null
                                    onTriggered: if (typeof cap.captureFrame === "function") cap.captureFrame()
                                }
                            }
                            Image {   // no picture (yet): the app's icon
                                anchors.centerIn: parent
                                visible: !cap.hasContent
                                width: Math.min(96, parent.width * 0.4, parent.height * 0.4); height: width
                                source: root.iconFor(wi.cls)
                                sourceSize: Qt.size(128, 128)
                                asynchronous: true
                            }
                        }
                        Item { id: picMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: 10; color: "black" } }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: 13
                            color: "transparent"
                            border.width: 4
                            border.color: Qt.rgba(1, 1, 1, wi.hot && !wi.dragging ? 0.85 : 0)
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }
                        Image {   // the app's icon on the bottom edge, as macOS draws it
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.bottom
                            width: 52; height: 52
                            opacity: wi.k
                            source: root.iconFor(wi.cls)
                            sourceSize: Qt.size(104, 104)
                            asynchronous: true
                        }
                        Rectangle {   // title, while the pointer is on the window
                            visible: wi.hot && !wi.dragging && wi.title !== ""
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom; anchors.topMargin: 32
                            width: Math.min(titleText.implicitWidth + 24, Math.max(160, parent.width + 80)); height: 26
                            radius: 13
                            color: Qt.rgba(0.1, 0.1, 0.12, 0.82)
                            Text {
                                id: titleText
                                anchors.centerIn: parent
                                width: parent.width - 24
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: wi.title
                                color: "white"
                                font.family: Fonts.forWeight(Font.DemiBold, root.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                        }

                        HoverHandler { id: hov }
                        TapHandler { onTapped: root.goTo({ addr: wi.addr, ws: wi.ws }) }
                        DragHandler {
                            id: drag
                            target: null
                            enabled: root.appClass === ""
                            onCentroidChanged: if (active) w.dropWs = w.spaceAt(wi.mapToItem(content, centroid.position.x, centroid.position.y))
                            onActiveChanged: {
                                if (active) return;
                                var ws = w.dropWs;
                                w.dropWs = 0;
                                if (ws > 0 && ws !== wi.ws) { root.sendTo(wi.addr, ws); var mv = w.moved; mv[wi.addr] = true; w.moved = mv; w.build(false); }
                            }
                        }
                    }
                }
            }
        }
    }
}
