import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: shellRoot
    property var yukiBar: null
    property var yukiDock: null
    property var yukiWidgets: null
    property var clockApp: null
    property var aboutApp: null
    FontLoader { id: uiFontLoader; source: Qt.resolvedUrl("assets/fonts/OpenRunde-Regular.otf") }
    FontLoader { id: uiBoldFontLoader; source: Qt.resolvedUrl("assets/fonts/OpenRunde-Semibold.otf") }

    Scope {
        id: sharedHub

        property var monData: []
        property var glassClients: []
        property var wallpaperMap: ({})
        property var winAlphaFile: ({})
        property real kittyBgAlpha: 1
        readonly property var winAlphaMap: {
            var m = {}, cs = glassClients || [], f = winAlphaFile;
            for (var i = 0; i < cs.length; i++) {
                var a = String(cs[i].address).replace(/^0x/, ""), cls = String(cs[i]["class"] || "");
                var bg = (cls === "kitty" || cls.indexOf("dash-") === 0) ? kittyBgAlpha : 1, win = 1;
                var e = f["0x" + a];
                if (e) { if (typeof e.bg === "number") bg = e.bg; if (typeof e.win === "number") win = e.win; }
                if (bg < 0.999 || win < 0.999) m[a] = { bg: bg, win: win };
            }
            return m;
        }
        function winAlpha(addr) {
            var e = winAlphaMap[String(addr).replace(/^0x/, "")];
            return e ? e : { bg: 1, win: 1 };
        }
        FileView {
            path: Quickshell.env("XDG_RUNTIME_DIR") + "/yukishell-winalpha.json"
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: { try { sharedHub.winAlphaFile = JSON.parse(text()) || {}; } catch (e) { } }
            onLoadFailed: sharedHub.winAlphaFile = ({})
        }
        FileView {
            path: Quickshell.env("HOME") + "/.config/kitty/kitty.conf"
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onLoaded: {
                var m = /^\s*background_opacity\s+([0-9.]+)/m.exec(text());
                sharedHub.kittyBgAlpha = m ? Math.max(0, Math.min(1, parseFloat(m[1]))) : 1;
            }
        }
        property var tlNoHandle: ({})
        property int tlGhosts: 0
        function tlGhost(t) {
            var a = t.address;
            if (t.wayland) { if (tlNoHandle[a] !== undefined) delete tlNoHandle[a]; return false; }
            var now = Date.now(), s = tlNoHandle[a];
            if (s === undefined) { tlNoHandle[a] = now; return false; }
            return now - s > 2000;
        }
        function tlAnyHandle(ts) {
            for (var i = 0; i < ts.length; i++) if (ts[i].wayland) return true;
            return false;
        }
        readonly property string boldFontFamily: uiBoldFontLoader.status === FontLoader.Ready ? uiBoldFontLoader.name : "Open Runde Semibold"

        property var bar: yukiBar
        readonly property bool desktopFocused: desktopFocus.focused
        property var dock: yukiDock
        readonly property var vis: audioVis
        property var widgets: yukiWidgets
        property var clock: clockApp
        property var about: aboutApp
        function openSettings(pane) { yukiDock.openPrefs(pane); }

        property bool barWantsGeo: false
        property bool dockWantsGeo: false
        property bool barWantsWallpaper: false
        property bool dockWantsWallpaper: false
        property bool widgetsWantWallpaper: false

        property bool captureQuiet: false
        readonly property bool wantQuiet: !!yukiBar && (yukiBar.recording || yukiBar.recRun || yukiBar.privacy.share.length > 0)
        onWantQuietChanged: { if (wantQuiet) { quietRelease.stop(); captureQuiet = true; } else quietRelease.restart(); }
        Timer { id: quietRelease; interval: 1500; onTriggered: sharedHub.captureQuiet = false }

        readonly property bool windowCapture: yukiDock ? yukiDock.windowCapture : true
        property bool churn: false
        readonly property bool captureHold: churn || !windowCapture || (!!yukiBar && yukiBar.gaming)
        readonly property bool glassHold: churn || (!!yukiBar && yukiBar.gaming)
        property bool captureCut: false
        readonly property bool previewHold: !windowCapture || (!!yukiBar && yukiBar.gaming)
        property var closingWins: ({})
        onCaptureHoldChanged: { if (captureHold) cutDelay.restart(); else { cutDelay.stop(); captureCut = false; } }
        Timer { id: cutDelay; interval: 500; onTriggered: sharedHub.captureCut = true }
        Timer { id: closingForget; interval: 3000; onTriggered: sharedHub.closingWins = ({}) }
        Timer { id: churnRelease; interval: 1200; onTriggered: sharedHub.churn = false }
        function tlPrune() {
            var ts = Hyprland.toplevels.values, live = {}, k;
            for (var i = 0; i < ts.length; i++) live[ts[i].address] = true;
            for (k in tlState.ready) if (!live[k]) delete tlState.ready[k];
        }

        Timer { id: wpKick; interval: 250; onTriggered: sharedHub.refreshWallpaper() }
        function refreshWallpaper() { if (!wpProc.running) wpProc.running = true; }

        property bool wallpaperReady: false
        readonly property string firstWallpaperUrl: {
            if (!bar) return "";
            var s = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
            return bar.fileUrl(bar.wallpaperFor(s));
        }
        Image {
            visible: false
            asynchronous: true
            source: sharedHub.firstWallpaperUrl
            sourceSize.width: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920
            onStatusChanged: if (status === Image.Ready || status === Image.Error) sharedHub.wallpaperReady = true
        }
        Timer { interval: 2500; running: true; onTriggered: sharedHub.wallpaperReady = true }

        Process {
            id: geoProc
            command: ["sh", "-c", "printf '{\"m\":'; hyprctl -j monitors; printf ',\"c\":'; hyprctl -j clients; printf '}'"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text === sharedHub.geoLast) return;
                    sharedHub.geoLast = text;
                    sharedHub.geoHot = true; geoCool.restart();
                    try { var o = JSON.parse(text); sharedHub.monData = o.m; sharedHub.glassClients = o.c; } catch (err) { }
                }
            }
        }
        property bool geoHot: true
        property string lastActive: ""
        property string geoLast: ""
        property string geoClientsLast: ""
        Timer { id: geoCool; interval: 1500; onTriggered: sharedHub.geoHot = false }
        Timer {
            id: geoNudge; interval: 50; repeat: true
            property int pass: 0
            onRunningChanged: if (running) pass = 0
            onTriggered: { if (sharedHub.ipcOk && !sharedHub.ipcBroken) sharedHub.ipcPoll(); if (++pass >= 3) stop(); }
        }
        Connections {
            target: Hyprland
            function onRawEvent(event) {
                if (event.name === "openwindow" || event.name === "closewindow") { sharedHub.churn = true; churnRelease.restart(); }
                if (event.name === "closewindow") {
                    var cw = {}, a = String(event.data).replace(/^0x/, "");
                    for (var k in sharedHub.closingWins) cw[k] = true;
                    cw[a] = true;
                    sharedHub.closingWins = cw;
                    closingForget.restart();
                }
                var en = event.name;
                if (en === "windowtitle" || en === "windowtitlev2" || en === "activewindow") return;
                if (en === "screencast" || en === "screencastv2") return;
                if (en === "workspace" || en === "workspacev2" || en === "focusedmon" || en === "focusedmonv2" || en === "activespecial" || en === "activespecialv2"
                    || en === "moveworkspace" || en === "moveworkspacev2" || en === "movewindow" || en === "movewindowv2" || en === "fullscreen"
                    || en === "changefloatingmode" || en === "openwindow" || en === "closewindow") {
                    try { Hyprland.refreshMonitors(); Hyprland.refreshToplevels(); } catch (err) { }
                    if (en.indexOf("workspace") >= 0 || en.indexOf("focusedmon") === 0) wpKick.restart();
                }
                if (en === "activewindowv2") { if (event.data === sharedHub.lastActive) return; sharedHub.lastActive = event.data; }
                if (en === "workspace" || en === "workspacev2" || en === "focusedmon" || en === "focusedmonv2" || en === "activewindowv2"
                    || en === "activespecial" || en === "activespecialv2" || en === "createworkspace" || en === "createworkspacev2"
                    || en === "destroyworkspace" || en === "destroyworkspacev2" || en === "activelayout" || en === "submap" || en === "urgent") geoNudge.restart();
                else { sharedHub.geoHot = true; geoCool.restart(); }
                tlDebounce.restart();
            }
        }

        property int tlTick: 0
        property var tlState: ({ ready: {}, last: 0, next: 0 })
        Timer { id: tlYoung; onTriggered: { sharedHub.tlState.next = 0; sharedHub.tlTick++; } }
        Timer { id: tlDebounce; interval: 120; onTriggered: { sharedHub.tlPrune(); sharedHub.tlSeed(); sharedHub.tlTick++; } }
        function tlArm() {
            var st = tlState, d = st.next - Date.now();
            tlYoung.interval = Math.max(10, d) + 15;
            tlYoung.restart();
        }
        function tlSeed() {
            var ts = Hyprland.toplevels.values, st = tlState, now = Date.now();
            for (var i = 0; i < ts.length; i++) {
                var a = ts[i].address;
                if (st.ready[a] === undefined) { st.ready[a] = Math.max(now + 200, st.last + 110); st.last = st.ready[a]; }
            }
        }
        function tlFor(addr) {
            var a = String(addr).replace(/^0x/, "");
            var ts = Hyprland.toplevels.values;
            for (var i = 0; i < ts.length; i++) {
                if (ts[i].address !== a) continue;
                var st = tlState, now = Date.now();
                if (st.ready[a] === undefined) {
                    st.ready[a] = Math.max(now + 200, st.last + 110);
                    st.last = st.ready[a];
                }
                if (st.ready[a] > now) {
                    if (st.next === 0 || st.ready[a] < st.next) { st.next = st.ready[a]; Qt.callLater(tlArm); }
                    return null;
                }
                return ts[i].wayland;
            }
            return null;
        }
        Timer {
            interval: sharedHub.geoHot ? 90 : 250
            repeat: true
            running: (sharedHub.barWantsGeo || sharedHub.dockWantsGeo) && !sharedHub.ipcOk
            triggeredOnStart: true
            onTriggered: if (!geoProc.running) geoProc.running = true
        }

        property bool ipcOk: false
        property bool ipcBroken: false
        function ipcPoll() {
            var ts, ms, i, o, m, cl = [], mo = [], raw = 0, gh = 0, mapped;
            try {
                ts = Hyprland.toplevels.values;
                ms = Hyprland.monitors.values;
                mapped = tlAnyHandle(ts);
                for (i = 0; i < ts.length; i++) {
                    o = ts[i].lastIpcObject;
                    if (!(o && o.address !== undefined)) continue;
                    raw++;
                    if (mapped && tlGhost(ts[i])) { gh++; continue; }
                    cl.push(o);
                }
                if (gh !== tlGhosts) { tlGhosts = gh; console.log("[yukishell] " + gh + " ghost window(s) in Quickshell's Hyprland list are hidden"); }
                for (i = 0; i < ms.length; i++) { m = ms[i].lastIpcObject; if (m && m.name !== undefined) mo.push(m); }
                Hyprland.refreshToplevels();
                Hyprland.refreshMonitors();
            } catch (err) { ipcBroken = true; ipcOk = false; return; }
            if (mo.length === 0 || (ts.length > 0 && raw === 0)) { ipcOk = false; return; }
            ipcOk = true;
            tlSeed();
            var gk = [], j, c;
            for (j = 0; j < cl.length; j++) {
                c = cl[j];
                gk.push([c.address, c.at, c.size, c.workspace ? (c.workspace.name || c.workspace.id) : 0, c.monitor, c.floating, c.fullscreen, c.mapped, c.hidden]);
            }
            var mk = [];
            for (j = 0; j < mo.length; j++) mk.push([mo[j].name, mo[j].x, mo[j].y, mo[j].width, mo[j].height, mo[j].scale, mo[j].activeWorkspace ? mo[j].activeWorkspace.id : 0, mo[j].specialWorkspace ? mo[j].specialWorkspace.id : 0]);
            var key = JSON.stringify([mk, gk]), gKey = JSON.stringify(gk);
            if (key === geoLast) return;
            geoLast = key;
            if (gKey !== geoClientsLast) { geoClientsLast = gKey; geoHot = true; geoCool.restart(); }
            monData = mo;
            glassClients = cl;
        }
        function kickGeo() {
            geoLast = ""; geoHot = true; geoCool.restart(); tlDebounce.restart();
            kickPass = 0; kickT.restart();
        }
        property int kickPass: 0
        Timer {
            id: kickT; interval: 120; repeat: true
            onTriggered: {
                sharedHub.kickPass++;
                if (sharedHub.ipcOk && !sharedHub.ipcBroken) sharedHub.ipcPoll();
                else { try { Hyprland.refreshMonitors(); Hyprland.refreshToplevels(); } catch (err) { } if (!geoProc.running) geoProc.running = true; }
                if (sharedHub.kickPass >= 6) kickT.stop();
            }
        }
        Timer {
            interval: sharedHub.geoHot ? 16 : 400
            repeat: true
            running: (sharedHub.barWantsGeo || sharedHub.dockWantsGeo) && !sharedHub.ipcBroken
            triggeredOnStart: true
            onTriggered: sharedHub.ipcPoll()
        }

        Process {
            id: wpProc
            command: ["sh", "-c",
                ""
                + "out=\"\"\n"
                + "st=\"${XDG_STATE_HOME:-$HOME/.local/state}/noctalia\"; ns=\"${NOCTALIA_STATE_HOME:-/nonexistent}\"\n"
                + "for f in \"$ns/settings.toml\" \"$st/settings.toml\" \"$HOME/.config/noctalia/settings.toml\" \"$HOME/.config/noctalia/config.toml\"; do\n"
                + "  [ -f \"$f\" ] || continue\n"
                + "  out=\"$out$(awk '\n"
                + "    /^[ \\t]*\\[\\[/ { sec = \"\"; next }\n"
                + "    /^[ \\t]*\\[/ { sec = $0; gsub(/[\\[\\] \\t\"]/, \"\", sec); next }\n"
                + "    sec ~ /^wallpaper\\.(default|last|monitors\\..+)$/ && /^[ \\t]*path[ \\t]*=/ {\n"
                + "      v = $0; sub(/^[^=]*=[ \\t]*\"/, \"\", v); sub(/\".*$/, \"\", v); print sec \"\\t\" v\n"
                + "    }' \"$f\")\n"
                + "\"\n"
                + "done\n"
                + "if [ -z \"$(printf %s \"$out\" | tr -d ' \\t\\n')\" ]; then\n"
                + "  p=$(swww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1)\n"
                + "  [ -z \"$p\" ] && p=$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1)\n"
                + "  [ -z \"$p\" ] && p=$(hyprctl hyprpaper listactive 2>/dev/null | head -n1 | sed 's/.*= //')\n"
                + "  if [ -z \"$p\" ]; then f=\"$HOME/.config/hypr/hyprpaper.conf\"\n"
                + "    [ -f \"$f\" ] && p=$(grep -E '^[[:space:]]*(path|wallpaper)[[:space:]]*=' \"$f\" | head -n1 | sed -E 's/^[^=]*=[[:space:]]*//; s/^[^,\\/]*,//')\n"
                + "  fi\n"
                + "  p=$(printf %s \"$p\" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')\n"
                + "  [ -n \"$p\" ] && out=\"wallpaper.default$(printf '\\t')$p\"\n"
                + "fi\n"
                + "printf '%s' \"$out\"\n"
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    var m = {}, lines = text.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var k = lines[i].indexOf("\t");
                        if (k <= 0) continue;
                        var key = lines[i].substring(0, k).trim(), val = lines[i].substring(k + 1).trim();
                        if (val !== "" && m[key] === undefined) m[key] = val;
                    }
                    if (JSON.stringify(m) !== JSON.stringify(sharedHub.wallpaperMap)) sharedHub.wallpaperMap = m;
                }
            }
        }

        Timer {
            interval: 4000
            repeat: true
            running: sharedHub.barWantsWallpaper || sharedHub.dockWantsWallpaper || sharedHub.widgetsWantWallpaper
            onTriggered: sharedHub.refreshWallpaper()
        }
    }

    AudioVis { id: audioVis }
    DesktopFocus { id: desktopFocus; enabled: sharedHub.bar ? sharedHub.bar.cursorFollowFocus !== false : true }

    function makePart(name, props) {
        var urls = ["file://" + String(Quickshell.shellDir).replace(/\/$/, "") + "/" + name + ".qml", Qt.resolvedUrl(name + ".qml")];
        for (var i = 0; i < urls.length; i++) {
            var c = Qt.createComponent(urls[i], Component.PreferSynchronous);
            if (c.status === Component.Ready) {
                var o = c.createObject(shellRoot, props);
                if (o) return o;
            }
            console.warn("[startup] could not load", urls[i], c.status === Component.Error ? c.errorString() : "");
        }
        return null;
    }
    Component.onCompleted: {
        yukiBar = makePart("YukiBar", { hub: sharedHub });
        yukiDock = makePart("YukiDock", { hub: sharedHub, bar: yukiBar });
        yukiWidgets = makePart("YukiWidgets", { hub: sharedHub });
        clockApp = makePart("ClockApp", { hub: sharedHub });
        aboutApp = makePart("AboutApp", { hub: sharedHub });
    }

    IpcHandler {
        target: "settings"
        function open(): void { yukiDock.openPrefs("general"); }
        function toggle(): void { yukiDock.togglePrefs("general"); }
        function pane(id: string): void { yukiDock.openPrefs(id); }
        function shot(path: string): void { yukiDock.shotPrefs(path); }
    }
    IpcHandler {
        target: "clock"
        function open(): void { clockApp.open(); }
        function tab(name: string): void { clockApp.open(name); }
        function stop(): void { clockApp.stopRing(); }
        function snooze(): void { clockApp.snooze(); }
    }
    IpcHandler {
        target: "about"
        function open(): void { aboutApp.open(); }
        function close(): void { aboutApp.close(); }
        function toggle(): void { aboutApp.toggle(); }
    }
    IpcHandler {
        target: "notifications"
        function open(): void { yukiBar.notifPopRequest(true); }
        function close(): void { yukiBar.notifPopRequest(false); }
        function clear(): void { yukiBar.notifClearAnimated(); }
        function dismiss(id: int): void { yukiBar.notifDelete(id); }
    }
    IpcHandler {
        target: "gaming"
        function toggle(): void { yukiBar.gamingMode = !yukiBar.gaming; }
        function on(): void { yukiBar.gamingMode = true; }
        function off(): void { yukiBar.gamingMode = false; yukiBar.gamingAutoActive = false; }
    }
    IpcHandler {
        target: "glass"
        function captures(on: bool): void { yukiDock.windowCapture = on; }
    }
}
