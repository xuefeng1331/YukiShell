import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam

ShellRoot {
    FontLoader { id: uiFontLoader; source: Qt.resolvedUrl("fonts/OpenRunde-Regular.otf") }
    FontLoader { id: uiBoldFontLoader; source: Qt.resolvedUrl("fonts/OpenRunde-Semibold.otf") }

    settings.watchFiles: false
    id: root
    readonly property bool preview: Quickshell.env("YUKILOCK_PREVIEW") === "1"
    readonly property bool daemonMode: Quickshell.env("YUKILOCK_DAEMON") === "1"
    property bool lockRequested: !daemonMode
    function requestLock() {
        if (preview || lockRequested) return;
        primary = "";
        pickPrimary();
        wallLookup.running = true;
        infoLookup.running = true;
        lockRequested = true;
    }
    property bool warm: false
    Timer { interval: 3000; running: root.daemonMode; onTriggered: if (!root.lockRequested) root.warm = true }
    Loader { active: root.warm; sourceComponent: Item { MediaPlayer { } } }
    IpcHandler {
        target: "lockscreen"
        function state(): string {
            if (lock.wasSecure) return lock.secure ? "busy" : "stopping";
            return root.lockRequested ? "busy" : "ready";
        }
        function lock(): void { root.requestLock(); }
    }

    property string primary: ""
    function pickPrimary() {
        if (primary === "" && Hyprland.focusedMonitor) primary = Hyprland.focusedMonitor.name;
    }
    Component.onCompleted: pickPrimary()
    Timer {
        interval: 400; running: true
        onTriggered: if (root.primary === "" && Quickshell.screens.length > 0) root.primary = Quickshell.screens[0].name
    }
    Connections { target: Hyprland; function onFocusedMonitorChanged() { root.pickPrimary(); } }

    QtObject {
        id: lockState
        property var now: new Date()
        property string wallpaper: ""
        property string wallpaperVideo: ""
        property string userName: Quickshell.env("USER") || ""
        property string avatar: ""
        property int wifiLevel: -1
        property bool ethernet: false
        property string pass: ""
        property bool busy: false
        property int fails: 0
        property string message: ""
        property bool engaged: false
        property bool unlocking: false
        property string mediaSlot: "bottom"
        property bool capsLock: false
        property bool use24h: true
        property var clockCfg: { try { return JSON.parse(Quickshell.env("YUKILOCK_CLOCK") || "{}"); } catch (e) { return {}; } }
        property bool artBg: true
        property bool sounds: false
        function sound(name) {
            if (sounds) Quickshell.execDetached(["pw-play", "--volume=0.7", Quickshell.env("HOME") + "/.local/share/sounds/yukishell/" + name + ".wav"]);
        }
        property string npMode: Quickshell.env("YUKILOCK_NP") || (Quickshell.env("YUKILOCK_ART") === "1" ? "art" : "")

        function setMediaSlot(v) {
            if (v === mediaSlot) return;
            mediaSlot = v;
            saveProc.command = ["sh", "-c", "mkdir -p \"$HOME/.config/yukilock\" && printf '{\\n  \"mediaSlot\": \"%s\"\\n}\\n' \"$1\" > \"$HOME/.config/yukilock/settings.json\"", "sh", v];
            saveProc.running = true;
        }
        function checkCaps() { if (!capsProc.running) capsProc.running = true; }

        function poke() {
            engaged = true;
            idleTimer.restart();
        }
        function submit() {
            if (busy || unlocking || pass.length === 0) return;
            busy = true;
            message = "";
            if (!pam.start()) { busy = false; fail("Couldn't start authentication"); }
        }
        function fail(msg) {
            pass = "";
            message = msg;
            fails++;
            msgTimer.restart();
        }
        function unlock() {
            unlocking = true;
            sound("unlock");
            unlockTimer.start();
        }
    }

    Process { id: saveProc }
    Process {
        id: capsProc
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[] | select(.main) | .capsLock] | any'"]
        stdout: StdioCollector {
            onStreamFinished: lockState.capsLock = text.trim() === "true"
        }
    }
    Timer { interval: 700; repeat: true; running: root.lockRequested || root.preview; triggeredOnStart: true; onTriggered: lockState.checkCaps() }

    Timer { interval: 1000; running: root.lockRequested || root.preview; repeat: true; triggeredOnStart: true; onTriggered: lockState.now = new Date() }
    Timer { interval: 1500; repeat: true; running: root.preview && Quickshell.env("YUKILOCK_TEST_MORPH") === "1"; onTriggered: lockState.use24h = !lockState.use24h }
    Timer { id: idleTimer; interval: 9000; onTriggered: if (lockState.pass.length === 0 && !lockState.busy) lockState.engaged = false }
    Timer { id: msgTimer; interval: 3500; onTriggered: lockState.message = "" }
    Timer {
        id: unlockTimer
        interval: 430
        onTriggered: {
            if (root.preview) Qt.quit();
            else {
                root.lockRequested = false;
                if (root.daemonMode)
                    Quickshell.execDetached(["sh", "-c", "sleep 0.6; YUKILOCK_DAEMON=1 exec qs -c YukiLock >/dev/null 2>&1"]);
                quitTimer.start();
            }
        }
    }
    Timer { id: quitTimer; interval: 150; onTriggered: Qt.quit() }

    PamContext {
        id: pam
        configDirectory: "/etc/pam.d"
        config: "login"   // what /etc/pam.d/hyprlock includes, and that file only exists with hyprlock installed
        onPamMessage: {
            if (this.responseRequired) this.respond(lockState.pass);
        }
        onCompleted: result => {
            lockState.busy = false;
            if (result === PamResult.Success) lockState.unlock();
            else lockState.fail(result === PamResult.MaxTries ? "Too many attempts, try again shortly" : "Incorrect password");
        }
        onError: err => {
            lockState.busy = false;
            lockState.fail("Authentication error");
        }
    }

    Process {
        id: wallLookup
        running: true
        command: ["sh", "-c",
            "lw=$(jq -r '.lockWallpaper // empty' \"$HOME/.config/yukibar/settings.json\" 2>/dev/null); "
            + "if [ -n \"$lw\" ] && [ -f \"$lw\" ]; then printf '%s\\n\\n' \"$lw\"; exit 0; fi; "
            + "p=$(jq -r '.wallpaperPath // empty' \"$HOME/.config/yukibar/settings.json\" 2>/dev/null); "
            + "[ -f \"$p\" ] || p=$(jq -r '.wallpaperPath // empty' \"$HOME/.config/yukidock/settings.json\" 2>/dev/null); "
            + "[ -f \"$p\" ] || p=$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1); "
            + "printf '%s\\n' \"$p\"; "
            + "v=$(cat \"$HOME/.config/yukishell/wallpaper-video-play\" 2>/dev/null); [ -f \"$v\" ] || v=$(cat \"$HOME/.config/yukishell/wallpaper-video\" 2>/dev/null); "
            + "[ -f \"$HOME/.config/yukishell/wallpaper-video\" ] && [ -f \"$v\" ] && printf '%s' \"$v\"; echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                lockState.wallpaper = (l[0] || "").trim();
                lockState.wallpaperVideo = (l[1] || "").trim();
            }
        }
    }

    Process {
        id: infoLookup
        running: true
        command: ["sh", "-c",
            "n=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1); printf '%s\\n' \"${n:-$USER}\"; "
            + "for a in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do [ -f \"$a\" ] && { printf '%s' \"$a\"; break; }; done; echo; "
            + "if [ \"$(nmcli radio wifi 2>/dev/null)\" = enabled ]; then s=$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -n1 | cut -d: -f2); "
            + "[ -n \"$s\" ] && printf '%s' \"$s\" || printf 0; else printf -- -1; fi; echo; "
            + "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected$' && echo eth || echo -; "
            + "jq -r '.mediaSlot // \"top\"' \"$HOME/.config/yukilock/settings.json\" 2>/dev/null || echo top; "
            + "[ \"$(jq -r '.uiSounds' \"$HOME/.config/yukibar/settings.json\" 2>/dev/null)\" != false ] && [ ! -f \"${XDG_RUNTIME_DIR:-/tmp}/yukishell-gaming.state\" ] && echo snd || echo -; "
            + "jq -r '.lockArtBackground' \"$HOME/.config/yukibar/settings.json\" 2>/dev/null || echo true; "
            + "jq -r '.use24h' \"$HOME/.config/yukibar/settings.json\" 2>/dev/null || echo true; "
            + "jq -r '.language // \"auto\"' \"$HOME/.config/yukibar/settings.json\" 2>/dev/null || echo auto; "
            + "jq -c '{f: .lockClockFont, w: .lockClockWeight, m: .lockClockMaterial, d: .lockClockDate, i: .lockClockIntensity, c: .lockClockTint}' \"$HOME/.config/yukibar/settings.json\" 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                if ((l[0] || "").trim() !== "") lockState.userName = l[0].trim();
                lockState.avatar = (l[1] || "").trim();
                var s = parseInt((l[2] || "-1").trim());
                lockState.wifiLevel = isNaN(s) || s < 0 ? -1 : (s === 0 ? 0 : (s > 66 ? 3 : (s > 33 ? 2 : 1)));
                lockState.ethernet = (l[3] || "").trim() === "eth";
                lockState.mediaSlot = (l[4] || "top").trim() === "bottom" ? "bottom" : "top";
                lockState.sounds = (l[5] || "").trim() === "snd";
                lockState.artBg = (l[6] || "true").trim() !== "false";
                lockState.use24h = (l[7] || "true").trim() !== "false";
                var lang = (l[8] || "auto").trim();
                Qt.uiLanguage = (lang === "auto" || lang === "null") ? "" : lang;
                if (!Quickshell.env("YUKILOCK_CLOCK")) { try { lockState.clockCfg = JSON.parse((l[9] || "{}").trim() || "{}"); } catch (e) { } }
                if (!root.preview && root.lockRequested) lockState.sound("lock");
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: root.lockRequested && !root.preview
        property bool wasSecure: false
        onSecureChanged: {
            if (secure) { wasSecure = true; return; }
            if (wasSecure && !root.preview && root.lockRequested) { console.log("[yukilock] lost the session lock: quitting"); quitTimer.start(); }
        }

        WlSessionLockSurface {
            id: surf
            color: "transparent"
            LockScreen {
                anchors.fill: parent
                st: lockState
                isPrimary: root.primary === "" || surf.screen === null || surf.screen.name === root.primary
            }
        }
    }

    Variants {
        model: root.preview ? Quickshell.screens : []
        PanelWindow {
            id: pw
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "yukilock-preview"
            WlrLayershell.keyboardFocus: Quickshell.env("YUKILOCK_PREVIEW_KB") === "1" && modelData.name === root.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            LockScreen {
                anchors.fill: parent
                st: lockState
                isPrimary: root.primary === "" || pw.modelData.name === root.primary
            }
        }
    }
}
