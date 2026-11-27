// The login screen: the lock screen, signing in through greetd. greetd runs it as its "greeter" user, in its own Hyprland
// (greeter.lua). Who signs in and how it looks come from /var/lib/yukigreet, which yuki-greeter-sync fills at every login.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: root
    FontLoader { source: Qt.resolvedUrl("fonts/OpenRunde-Regular.otf") }
    FontLoader { source: Qt.resolvedUrl("fonts/OpenRunde-Semibold.otf") }
    settings.watchFiles: false

    readonly property string dir: Quickshell.env("YUKIGREET_DIR") || "/var/lib/yukigreet"
    property var profile: ({})
    FileView {
        path: root.dir + "/profile.json"
        onLoaded: {
            var p = {};
            try { p = JSON.parse(text()); } catch (e) { }
            root.profile = p;
            greetState.userName = p.name || p.user || "";
            greetState.avatar = p.avatar ? root.dir + "/" + p.avatar : "";
            greetState.wallpaper = p.wallpaper ? root.dir + "/" + p.wallpaper : "";
            greetState.use24h = p.use24h !== false;
            greetState.artBg = p.artBg !== false;
            if (p.clock) greetState.clockCfg = p.clock;
            if (p.glass) greetState.glassCfg = p.glass;
            Qt.uiLanguage = !p.language || p.language === "auto" ? "" : p.language;
        }
    }

    QtObject {
        id: greetState
        property var now: new Date()
        property string wallpaper: ""
        property string wallpaperVideo: ""
        property string userName: ""
        property string avatar: ""
        property int wifiLevel: -1
        property bool ethernet: false
        property string pass: ""
        property bool busy: false
        property int fails: 0
        property string message: ""
        property bool engaged: false
        property bool unlocking: false
        property string mediaSlot: "top"
        property bool capsLock: false
        property bool use24h: true
        property var clockCfg: ({})
        property bool artBg: true
        property var glassCfg: ({})
        property string note: ""   // what PAM said besides asking for the password: why it refused, e.g. a locked account
        property string npMode: ""
        property string hint: "Enter your password to sign in"
        function sound(name) { }
        function setMediaSlot(v) { mediaSlot = v; }
        function checkCaps() { }
        function poke() { engaged = true; idleTimer.restart(); }
        function submit() {
            if (busy || unlocking || pass.length === 0) return;
            if (!root.profile.user) { fail("No user to sign in"); return; }
            busy = true;
            message = "";
            note = "";
            Greetd.createSession(root.profile.user);
        }
        function fail(msg) {
            busy = false;
            pass = "";
            message = msg;
            fails++;
            msgTimer.restart();
        }
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(greetState.pass);
            else if (message) greetState.note += (greetState.note ? " " : "") + message.trim();
        }
        function onAuthFailure(message) { greetState.fail(greetState.note || "Incorrect password"); }
        function onError(error) { console.warn("[yukigreet]", error); greetState.fail("Authentication error"); }
        function onReadyToLaunch() { greetState.unlocking = true; launchTimer.start(); }
    }
    Timer {   // the lock screen's unlock animation, then the session
        id: launchTimer
        interval: 430
        onTriggered: Greetd.launch(root.profile.session || ["start-hyprland"], ["XDG_SESSION_TYPE=wayland"], true)
    }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: greetState.now = new Date() }
    Timer { id: idleTimer; interval: 9000; onTriggered: if (greetState.pass.length === 0 && !greetState.busy) greetState.engaged = false }
    Timer { id: msgTimer; interval: Math.max(3500, greetState.message.length * 70); onTriggered: greetState.message = "" }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: pw
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "yukigreet"
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0] ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            LockScreen {
                anchors.fill: parent
                st: greetState
                isPrimary: pw.modelData === Quickshell.screens[0]
            }
        }
    }
}
