// The login screen: the lock screen, signing in through greetd. greetd runs it as its "greeter" user, in its own Hyprland
// (greeter.lua). Who can sign in and how it looks come from /var/lib/yukigreet, which yuki-greeter-sync fills at every login
// (greeter-list.sh reads it). Along the bottom: the accounts (when there are several), the desktop session (when there are
// several) and Sleep, Restart, Shut Down.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import "I18n.js" as I18n

ShellRoot {
    id: root
    FontLoader { source: Qt.resolvedUrl("fonts/OpenRunde-Regular.otf") }
    FontLoader { source: Qt.resolvedUrl("fonts/OpenRunde-Semibold.otf") }
    settings.watchFiles: false

    readonly property string dir: Quickshell.env("YUKIGREET_DIR") || "/var/lib/yukigreet"
    // only the real login screen (started by greetd) turns the computer off or changes the keyboard: running this file by
    // hand to try it never does
    readonly property bool underGreetd: (Quickshell.env("GREETD_SOCK") || "") !== ""

    property var users: []        // [{ user, name, base, profile }] from greeter-list.sh
    property int userIdx: -1
    property var sessions: []     // [{ id, name, exec, desktop }]
    property int sessionIdx: 0
    readonly property var cu: userIdx >= 0 && userIdx < users.length ? users[userIdx] : null
    readonly property var profile: cu && cu.profile ? cu.profile : ({})
    readonly property var session: sessions.length > 0 ? sessions[Math.min(sessionIdx, sessions.length - 1)] : null
    // the screens are built once the account is known: its language is read as they are built. A list that fails or hangs
    // still gets you a login screen (the account folder's owner) after a moment.
    property bool ready: false
    Timer { interval: 1500; running: !root.ready; onTriggered: root.useUsers([]) }
    // the folder owner's own profile, read directly: signing in still works if greeter-list.sh doesn't
    property var ownProfile: ({})
    FileView {
        path: root.dir + "/profile.json"
        onLoaded: { try { root.ownProfile = JSON.parse(text()); } catch (e) { } }
    }
    function useUsers(us) {
        if (ready) return;
        var p = ownProfile;
        if (us.length === 0 && p && p.user) us = [{ user: p.user, name: p.name || p.user, base: dir, profile: p }];
        var first = 0;
        for (var i = 0; i < us.length; i++) if (us[i].user === lastUser) { first = i; break; }
        users = us;
        selectUser(first);
        ready = true;
    }
    property string lastUser: ""

    // a picture the account synced (a plain file name inside its own folder)
    function file(base, name) { return base && /^[A-Za-z0-9._-]+$/.test(name || "") ? base + "/" + name : ""; }
    function selectUser(i) {
        if (i === userIdx || i < 0 || i >= users.length || greetState.busy || greetState.unlocking) return;
        userIdx = i;
        var p = profile;
        greetState.pass = ""; greetState.message = ""; greetState.note = "";
        greetState.userName = cu.name || cu.user;
        greetState.avatar = file(cu.base, p.avatar);
        // an account that never synced keeps the wallpaper on screen rather than going black
        greetState.wallpaper = file(cu.base, p.wallpaper) || greetState.wallpaper;
        greetState.use24h = p.use24h !== false;
        greetState.artBg = p.artBg !== false;
        greetState.clockCfg = p.clock || ({});
        greetState.glassCfg = p.glass || ({});
        Qt.uiLanguage = !p.language || p.language === "auto" ? "" : p.language;
        // their last session, else plain Hyprland, else the first
        var want = String(p.session || ""), pick = -1, k;
        for (k = 0; k < sessions.length && pick < 0; k++) if (sessions[k].id === want) pick = k;
        for (k = 0; k < sessions.length && pick < 0; k++) if (sessions[k].id === "hyprland") pick = k;
        for (k = 0; k < sessions.length && pick < 0; k++) if (/hyprland/i.test(sessions[k].id)) pick = k;
        sessionIdx = Math.max(0, pick);
        // their keyboard layout, so the password is typed the way they type it; a layout xkb can't build is left alone
        var kb = p.kb || {}, lay = String(kb.layout || "us"), va = String(kb.variant || "");
        if (underGreetd && /^[A-Za-z0-9_,:.-]+$/.test(lay) && /^[A-Za-z0-9_,:.-]*$/.test(va))
            Quickshell.execDetached(["sh", "-c",
                "command -v xkbcli >/dev/null 2>&1 && xkbcli compile-keymap --layout \"$1\" --variant \"$2\" >/dev/null 2>&1 || exit 0; "
                + "hyprctl eval \"hl.config({ input = { kb_layout = '$1', kb_variant = '$2' } })\"", "sh", lay, va]);
    }
    function launch() {
        var s = session;
        // greetd runs the command through its own `sh -c` (after the profile), joined with spaces: Exec's words as they are
        var cmd = s ? String(s.exec).replace(/%[a-zA-Z]/g, "").trim() : "start-hyprland";
        // Hyprland 0.53+ wants to be started through start-hyprland
        cmd = cmd.replace(/^(\/usr\/bin\/)?Hyprland(?=\s|$)/, "start-hyprland");
        var env = ["XDG_SESSION_TYPE=wayland"];
        if (s) {
            env.push("XDG_SESSION_DESKTOP=" + s.id, "YUKI_SESSION=" + s.id);   // yuki-greeter-sync remembers it
            if (s.desktop) env.push("XDG_CURRENT_DESKTOP=" + s.desktop);
        }
        Greetd.launch(cmd.split(/\s+/), env, true);
    }
    function power(what) { if (underGreetd) Quickshell.execDetached(["systemctl", what]); }

    Process {
        running: true
        command: ["sh", Quickshell.shellDir + "/greeter-list.sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                var o = {};
                try { o = JSON.parse(text.trim().split("\n").pop()); } catch (e) { o = {}; }
                root.sessions = o.sessions || [];
                root.lastUser = o.last || "";
                root.useUsers(o.users || []);
            }
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
        function capsSeen(v) { capsLock = v; }
        function poke() { engaged = true; idleTimer.restart(); }
        function submit() {
            if (busy || unlocking || pass.length === 0) return;
            if (!root.cu) { fail("No user to sign in"); return; }
            busy = true;
            message = "";
            note = "";
            Greetd.createSession(root.cu.user);
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
        interval: 600
        onTriggered: root.launch()
    }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: greetState.now = new Date() }
    Timer { id: idleTimer; interval: 9000; onTriggered: if (greetState.pass.length === 0 && !greetState.busy) greetState.engaged = false }
    Timer { id: msgTimer; interval: Math.max(3500, greetState.message.length * 70); onTriggered: greetState.message = "" }

    // a piece of the lock screen's Liquid Glass, with a light that follows the pointer and a press
    component GlassButton: Item {
        id: gb
        required property Item ls
        property real radius: height / 2
        property bool selected: false
        readonly property bool hovered: gbMa.containsMouse
        signal clicked()
        Glass {
            anchors.fill: parent
            src: gb.ls.glassSrc; frame: gb.ls
            cornerR: gb.radius; thickness: 16; shadowAmt: 0.3
            tint: Math.max(gb.ls.gTint, gb.selected ? 0.55 : 0.45); rim: gb.ls.gRim; strength: gb.ls.gStrength
        }
        Rectangle {
            anchors.fill: parent; radius: gb.radius
            color: "white"
            opacity: gbMa.pressed ? 0.20 : (gb.selected ? 0.14 : (gbMa.containsMouse ? 0.08 : 0))
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        Rectangle {   // the chosen one: a clear white edge
            anchors.fill: parent; radius: gb.radius
            color: "transparent"
            border.width: 1.5; border.color: "white"
            opacity: gb.selected ? 0.75 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        opacity: enabled ? 1 : 0.5
        scale: gbMa.pressed ? 0.93 : 1
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
        MouseArea {
            id: gbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { gb.clicked(); gb.ls.forceActiveFocus(); }
        }
    }

    Variants {
        model: root.ready ? Quickshell.screens : []
        PanelWindow {
            id: pw
            required property var modelData
            readonly property bool primary: modelData === Quickshell.screens[0]
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "yukigreet"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            LockScreen {
                id: lsv
                anchors.fill: parent
                st: greetState
                isPrimary: pw.primary
            }

            Item {
                id: extras
                anchors.fill: parent
                visible: pw.primary
                readonly property real u: lsv.u
                readonly property bool idle: !greetState.busy && !greetState.unlocking
                property bool sessionMenu: false
                opacity: lsv.shown && !lsv.leaving ? 1 : 0
                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: lsv.inDelay(320) } NumberAnimation { duration: lsv.leaving ? 260 : 650; easing.type: Easing.OutQuint } } }

                // a click anywhere else closes the session menu
                MouseArea { anchors.fill: parent; visible: extras.sessionMenu; onClicked: extras.sessionMenu = false }

                // ── bottom left: the accounts (when there are several), then the session (when there are several) ──
                Column {
                    anchors { left: parent.left; bottom: parent.bottom; leftMargin: 30 * extras.u; bottomMargin: 30 * extras.u }
                    spacing: 12 * extras.u

                    Flow {
                        visible: root.users.length > 1
                        width: extras.width * 0.4
                        spacing: 8 * extras.u
                        Repeater {
                            model: root.users
                            delegate: GlassButton {
                                id: chip
                                required property var modelData
                                required property int index
                                readonly property string pic: root.file(modelData.base, modelData.profile ? modelData.profile.avatar : "")
                                ls: lsv
                                selected: index === root.userIdx
                                enabled: extras.idle
                                width: chipName.x + chipName.width + 14 * extras.u; height: 36 * extras.u
                                onClicked: root.selectUser(index)
                                Rectangle {
                                    id: chipPic
                                    x: 5 * extras.u; anchors.verticalCenter: parent.verticalCenter
                                    width: 26 * extras.u; height: width; radius: width / 2
                                    color: Qt.rgba(1, 1, 1, 0.22)
                                    clip: true
                                    Text {
                                        anchors.centerIn: parent
                                        visible: chipImg.status !== Image.Ready
                                        text: (chip.modelData.name || chip.modelData.user || "?").charAt(0).toUpperCase()
                                        color: "white"; font.family: lsv.fam; font.pixelSize: 13 * extras.u; font.weight: Font.DemiBold
                                    }
                                    Image {
                                        id: chipImg
                                        anchors.fill: parent
                                        source: chip.pic !== "" ? "file://" + chip.pic : ""
                                        fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true
                                        sourceSize: Qt.size(64, 64)
                                    }
                                }
                                Text {
                                    id: chipName
                                    x: 39 * extras.u; anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, 170 * extras.u)
                                    text: chip.modelData.name || chip.modelData.user
                                    elide: Text.ElideRight
                                    color: "white"; font.family: lsv.fam; font.pixelSize: 14 * extras.u; font.weight: Font.Medium
                                }
                            }
                        }
                    }

                    GlassButton {
                        id: sessBtn
                        visible: root.sessions.length > 1
                        ls: lsv
                        selected: extras.sessionMenu
                        enabled: extras.idle
                        width: sessName.x + sessName.width + 32 * extras.u; height: 36 * extras.u
                        onClicked: extras.sessionMenu = !extras.sessionMenu
                        Glyph {
                            x: 13 * extras.u; anchors.verticalCenter: parent.verticalCenter
                            width: 16 * extras.u; height: width
                            kind: "monitor"; color: "white"
                        }
                        Text {
                            id: sessName
                            x: 37 * extras.u; anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 240 * extras.u)
                            text: root.session ? root.session.name : ""
                            elide: Text.ElideRight
                            color: "white"; font.family: lsv.fam; font.pixelSize: 14 * extras.u; font.weight: Font.Medium
                        }
                        Glyph {
                            anchors { right: parent.right; rightMargin: 11 * extras.u; verticalCenter: parent.verticalCenter }
                            width: 13 * extras.u; height: width
                            kind: "chevR"; color: Qt.rgba(1, 1, 1, 0.8)
                            rotation: extras.sessionMenu ? 90 : -90
                            Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                // the session menu, opening up from the session button
                Item {
                    id: sessMenu
                    readonly property real rowH: 36 * extras.u
                    x: 30 * extras.u
                    y: extras.height - 30 * extras.u - sessBtn.height - 10 * extras.u - height
                    width: Math.max(sessBtn.width, 240 * extras.u)
                    height: root.sessions.length * rowH + 12 * extras.u
                    visible: opacity > 0.01
                    opacity: extras.sessionMenu ? 1 : 0
                    scale: extras.sessionMenu ? 1 : 0.92
                    transformOrigin: Item.BottomLeft
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                    Glass {
                        anchors.fill: parent
                        src: lsv.glassSrc; frame: lsv
                        cornerR: 16 * extras.u; thickness: 22; shadowAmt: 0.45
                        tint: Math.max(lsv.gTint, 0.5); rim: lsv.gRim; strength: lsv.gStrength
                    }
                    MouseArea { anchors.fill: parent }   // the gaps between rows don't close it
                    Column {
                        x: 6 * extras.u; y: 6 * extras.u
                        width: parent.width - 12 * extras.u
                        Repeater {
                            model: root.sessions
                            delegate: Rectangle {
                                id: srow
                                required property var modelData
                                required property int index
                                width: parent.width; height: sessMenu.rowH
                                radius: 10 * extras.u
                                color: srMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                                Glyph {
                                    x: 10 * extras.u; anchors.verticalCenter: parent.verticalCenter
                                    width: 14 * extras.u; height: width
                                    visible: srow.index === root.sessionIdx
                                    kind: "check"; color: "white"
                                }
                                Text {
                                    x: 32 * extras.u; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - x - 10 * extras.u
                                    text: srow.modelData.name
                                    elide: Text.ElideRight
                                    color: "white"; font.family: lsv.fam; font.pixelSize: 14 * extras.u
                                }
                                MouseArea {
                                    id: srMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.sessionIdx = srow.index; extras.sessionMenu = false; lsv.forceActiveFocus(); }
                                }
                            }
                        }
                    }
                }

                // ── bottom right: Sleep, Restart, Shut Down ──
                Row {
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 30 * extras.u; bottomMargin: 26 * extras.u }
                    spacing: 18 * extras.u
                    Repeater {
                        model: [{ k: "moon", t: "Sleep", a: "suspend" }, { k: "restart", t: "Restart", a: "reboot" }, { k: "power", t: "Shut Down", a: "poweroff" }]
                        delegate: Column {
                            id: pcol
                            required property var modelData
                            spacing: 6 * extras.u
                            width: 64 * extras.u
                            GlassButton {
                                id: pbtn
                                anchors.horizontalCenter: parent.horizontalCenter
                                ls: lsv
                                enabled: extras.idle
                                width: 42 * extras.u; height: width
                                onClicked: root.power(pcol.modelData.a)
                                Glyph {
                                    anchors.centerIn: parent
                                    width: 18 * extras.u; height: width
                                    kind: pcol.modelData.k; color: "white"
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr(pcol.modelData.t)
                                color: "white"; opacity: pbtn.hovered ? 1 : 0.8
                                font.family: lsv.fam; font.pixelSize: 12 * extras.u; font.weight: Font.Medium
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
