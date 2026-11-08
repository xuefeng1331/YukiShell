// yukibar - a macOS Tahoe style menu bar for Hyprland, built on Quickshell.
//
// Part of the combined yukibar + yukidock shell (see shell.qml). Keep this file, YukiDock.qml, shell.qml,
// liquidglass.frag and apple-logo-*.svg together in ~/.config/quickshell/yukibar/ and run:  qs -c YukiShell
//
// Settings live in ~/.config/yukibar/settings.json (Apple menu -> System Settings..., or Control Center -> Edit Controls).
// On first run, appearance (accent, font, glass tuning, wallpaper) is inherited from yukidock's settings.json.
//
// Hyprland (hyprland.conf syntax):
//   windowrule = float, title:^(yukibar Settings)$
//   windowrule = center, title:^(yukibar Settings)$
//   layerrule  = blur, yukispot          (Spotlight is its own layer; the bar itself needs no blur rule)
//   layerrule  = ignorealpha 0.05, yukispot
//   # the bar's background is its own layer ("yukibarbg", under the bar): blur it with Hyprland like this
//   layerrule  = blur, yukibarbg
//   layerrule  = ignorealpha 0.05, yukibarbg
// Hyprland (Lua):
//   hl.layer_rule({ name = "yukispot", match = { namespace = "yukispot" }, blur = true, ignore_alpha = 0.05, no_anim = true })
//   hl.layer_rule({ name = "yukibarbg", match = { namespace = "yukibarbg" }, blur = true, ignore_alpha = 0.05, no_anim = true })
//
// Optional tools used by the Control Center:
//   nmcli (Wi-Fi / VPN / Ethernet), pactl (audio device routing), hyprctl (keyboard layouts), pw-dump (privacy dots),
//   wf-recorder (screen recording), hyprpicker (color picker), bluetoothctl (Bluetooth), brightnessctl (Display), hyprsunset (Night Shift),
//   systemd-inhibit (Keep Awake), grim + slurp + wl-copy + notify-send (File -> Screenshot),
//   man / xdg-open (Help), wl-clipboard + cliphist (Spotlight -> Clipboard, Emoji),
//   wtype (only if you set keysViaWtype: true; menu shortcuts are otherwise sent with Hyprland's sendshortcut),
//   rfkill (Airplane mode), dunstctl / makoctl / swaync-client (Focus). Missing tools just do nothing.
//
// Wi-Fi: click the Wi-Fi icon in the bar (or the Wi-Fi tile in Control Center) for a list of nearby networks (nmcli).
//
// Notifications: the bar is also a notification daemon (org.freedesktop.Notifications). Stop dunst / mako / swaync first,
// e.g. `systemctl --user disable --now dunst`, otherwise only one of them can own the D-Bus name. Popups appear top right in
// Liquid Glass; the bell in the bar opens the "Notification system" panel (history, delete, Clear All, Do Not Disturb).
// Test with: notify-send "Fitness" "Move goal achieved"
//
// Spotlight (the search icon) is built in and drawn in Liquid Glass. Bind it to a key with:
//   bind = ALT, space, exec, qs -c YukiShell ipc call spotlight toggle
// Hyprland (Lua):
//   hl.bind("ALT + Space", hl.dsp.exec_cmd("qs -c YukiShell ipc call spotlight toggle"))
//   Reduced motion: set "reduceMotion": true in ~/.config/yukibar/settings.json to turn off Spotlight's pop / stagger / slide animations.
// Wallpapers: Ctrl+Alt+W opens the wallpaper picker (Liquid Glass). Bind it with:
//   hl.bind("CTRL + ALT + W", hl.dsp.exec_cmd("qs -c YukiShell ipc call wallpapers toggle"))
//   (hyprlang:  bind = CTRL ALT, W, exec, qs -c YukiShell ipc call wallpapers toggle)
// Folders: ~/Pictures/Wallpapers by default (add more in Settings -> Wallpaper, or "wallpaperDirs" in settings.json).
// Star a wallpaper to pin it to the top. Applied through Noctalia / awww / swww / hyprpaper, or your own "wallpaperCmd" ({} = image path).
// Clipboard history + Emoji live inside Spotlight (the clipboard and smiley buttons next to the search field):
//   needs wl-clipboard + cliphist (this shell starts the `wl-paste --watch cliphist store` watchers itself, unless you already run them).
//   bind = SUPER, V, exec, qs -c YukiShell ipc call spotlight clipboard       # Clipboard history (replace any default SUPER+V bind)
//   bind = SUPER, period, exec, qs -c YukiShell ipc call spotlight emoji      # Emoji picker
// Hyprland (Lua):
//   hl.bind("SUPER + V", hl.dsp.exec_cmd("qs -c YukiShell ipc call spotlight clipboard"))
//   hl.bind("SUPER + period", hl.dsp.exec_cmd("qs -c YukiShell ipc call spotlight emoji"))
//   (use the same `qs -c <name>` prefix you use for the Spotlight bind; `ipc call spotlight apps` opens the Applications panel)
// Return pastes the entry into the focused app, Shift+Return only copies it, Delete removes it from the history.
// Files runs filesCmd.
//
// Screenshots (Print key): the screen freezes and dims, drag to select an area (a size badge follows the pointer), release to capture.
// Return/Space = whole screen, Esc or right-click = cancel. Where it is saved (and clipboard / notification) is in System Settings -> Menu Bar.
//   bind = , Print, exec, qs -c YukiShell ipc call screenshot region
//   bind = SHIFT, Print, exec, qs -c YukiShell ipc call screenshot screen
//   bind = ALT, Print, exec, qs -c YukiShell ipc call screenshot window
// Hyprland (Lua):
//   hl.bind("Print", hl.dsp.exec_cmd("qs -c YukiShell ipc call screenshot region"))
// Optional (no fade on the picker):  layerrule = noanim, yukishot   (Lua: hl.layer_rule({ name = "yukishot", match = { namespace = "yukishot" }, no_anim = true }))
// Needs grim (and wl-clipboard for the clipboard copy).

import QtQuick
import QtQuick.Effects
import Quickshell
import "Launch.js" as Launch
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import "EmojiData.js" as EmojiData
import "I18n.js" as I18n
import "Fonts.js" as Fonts

Scope {
    id: root

    property var hub: null
    readonly property bool captureQuiet: hub ? hub.captureQuiet : recording
    readonly property bool captureHeld: hub ? hub.glassHold : false

    property bool barEnabled: true
    property bool spotlightEnabled: true
    property bool reduceMotion: false
    property bool ccEnabled: true
    property string ccStyle: "tiles"
    property bool notificationsEnabled: true
    property bool clockAppEnabled: true
    readonly property bool barLayerNeeded: barEnabled || spotlightEnabled || ccEnabled || notificationsEnabled
    readonly property bool darkMode: true
    readonly property bool panelDarkMode: darkMode
    readonly property bool panelTextWhite: true
    readonly property bool toneMeasuring: false
    property color accent: "#eeacbe"
    property bool accentUi: false
    readonly property color accentInk: panelTextWhite ? Qt.tint(accent, Qt.rgba(1, 1, 1, 0.18)) : Qt.tint(accent, Qt.rgba(0, 0, 0, 0.25))
    readonly property vector4d accentTintVec: Qt.vector4d(accent.r, accent.g, accent.b, accentUi ? 1 : 0)
    function accentWash(c, k, dark) {
        if (!accentUi) return c;
        var a = accent, t = dark ? Qt.rgba(a.r * 0.40, a.g * 0.40, a.b * 0.40, 1) : Qt.rgba(a.r + (1 - a.r) * 0.70, a.g + (1 - a.g) * 0.70, a.b + (1 - a.b) * 0.70, 1);
        return Qt.rgba(c.r + (t.r - c.r) * k, c.g + (t.g - c.g) * k, c.b + (t.b - c.b) * k, c.a);
    }
    property string fontFamily: "Open Runde"
    readonly property string boldFontFamily: hub && hub.boldFontFamily ? hub.boldFontFamily : "Open Runde Semibold"
    function fontForWeight(weight, regularFamily) { return (Number(weight) >= Font.DemiBold && regularFamily === "Open Runde") ? boldFontFamily : regularFamily; }
    onFontFamilyChanged: if (fontFamily.indexOf("Inter") === 0) fontFamily = "Open Runde"
    property int barHeight: 28
    property bool uiScaleAuto: true
    property real uiScaleManual: 1.0
    readonly property real autoUiScale: {
        var sc = Quickshell.screens;
        if (!sc || sc.length === 0) return 1;
        var s = sc[0];
        for (var i = 0; i < sc.length; i++) if (sc[i].width * sc[i].height < s.width * s.height) s = sc[i];
        return Math.max(0.7, Math.min(1, Math.min(s.width / 1920, s.height / 1080)));
    }
    readonly property real uiScale: Math.max(0.5, Math.min(1.25, (uiScaleAuto ? autoUiScale : 1) * uiScaleManual))
    readonly property int barH: Math.max(14, Math.round(barHeight * uiScale))
    signal barRelayout()
    onBarHeightChanged: { if (settingsReady) barRelayoutT.restart(); }
    Timer {
        id: barRelayoutT; interval: 180
        property int pass: 0
        onTriggered: {
            if (root.hub && root.hub.kickGeo) root.hub.kickGeo();
            root.barRelayout();
            pass++;
            if (pass < 2) restart(); else pass = 0;
        }
    }
    property string barLogoMode: "apple"
    property string barCustomLogoPath: ""
    readonly property real barWidgetScale: Math.max(0.45, Math.min(1.55, barHeight / 28 * uiScale))
    readonly property real barPopupScale: Math.max(0.5, Math.min(1.25, (1 + (barHeight - 28) / 60) * uiScale))
    property real glassOpacity: 0.42
    property string barStyle: "liquid"
    property real glassRim: 0.45
    property real glassGrain: 0.015
    property real glassLiquid: 1.5
    property real glassBlur: 5
    // menuStyle "blur" is Acrylic: the Liquid Glass pipeline without refraction or rim, blurred 24 more; "normal" is a plain panel
    readonly property bool acrylic: barStyle === "blur"
    readonly property real glassLiquidEff: acrylic ? 0 : glassLiquid
    readonly property real glassRimEff: acrylic ? 0 : glassRim
    readonly property real glassBlurEff: acrylic ? glassBlur + 24 : glassBlur
    property int kbRepeatRate: 35
    property int kbRepeatDelay: 250
    property real mouseSens: 0
    property bool mouseNatural: false
    property bool mouseAccel: false
    property bool tpNatural: true
    property bool tpTap: true
    property bool tpDwt: true
    property real tpScroll: 0.7
    property string kbLayout: ""   // empty: whatever input.lua says
    readonly property string inputSig: [kbLayout, kbRepeatRate, kbRepeatDelay, mouseSens, mouseNatural, mouseAccel, tpNatural, tpTap, tpDwt, tpScroll].join("|")
    onInputSigChanged: if (settingsReady) inputApplyT.restart()
    Timer { id: inputApplyT; interval: 150; onTriggered: root.applyInput() }
    property string cursorTheme: "Bibata-Modern-Classic"
    property int cursorSize: 24
    property bool cursorHideTyping: false
    property real cursorHideIdle: 10
    property bool cursorFollowFocus: true
    property bool cursorWarpWs: false
    property real cursorZoom: 1.0
    readonly property string cursorScript: decodeURIComponent(String(Qt.resolvedUrl("assets/cursors.py")).replace(/^file:\/\//, ""))
    readonly property string cursorLook: cursorTheme + "|" + cursorSize
    onCursorLookChanged: if (settingsReady) cursorLookT.restart()
    Timer { id: cursorLookT; interval: 250; onTriggered: Quickshell.execDetached([root.cursorScript, "apply", root.cursorTheme, String(root.cursorSize)]) }
    readonly property string cursorSig: [cursorHideTyping, cursorHideIdle, cursorFollowFocus, cursorWarpWs, cursorZoom].join("|")
    onCursorSigChanged: if (settingsReady) cursorApplyT.restart()
    Timer { id: cursorApplyT; interval: 120; onTriggered: root.applyCursor() }
    function applyCursor() {
        function b(v) { return v ? "true" : "false"; }
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { hide_on_key_press = " + b(cursorHideTyping) + ", inactive_timeout = " + cursorHideIdle.toFixed(1)
            + ", warp_on_change_workspace = " + (cursorWarpWs ? 1 : 0) + ", zoom_factor = " + Math.max(1, cursorZoom).toFixed(2)
            + " }, input = { follow_mouse = " + (cursorFollowFocus ? 1 : 0) + ", focus_on_close = " + (cursorFollowFocus ? 1 : 0) + " } })"]);
    }
    property int windowBorder: 1
    onAccentChanged: if (settingsReady) borderApplyT.restart()
    onWindowBorderChanged: if (settingsReady) borderApplyT.restart()
    property bool floatNewWindows: true
    onFloatNewWindowsChanged: if (settingsReady) borderApplyT.restart()
    function applyWindowRules() {
        Quickshell.execDetached(["hyprctl", "eval", "if FLOAT_NEW_RULE then FLOAT_NEW_RULE:set_enabled(" + (floatNewWindows ? "true" : "false") + ") end"]);
    }
    onDesktopFocusedChanged: if (settingsReady) root.applyBorders()
    Timer { id: borderApplyT; interval: 150; onTriggered: { root.applyBorders(); root.applyWindowRules(); } }
    function applyBorders() {
        function hx(v) { var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16); return s.length < 2 ? "0" + s : s; }
        var a = root.accent, rgb = hx(a.r) + hx(a.g) + hx(a.b);
        var act = root.desktopFocused ? "40" : "ff";
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ general = { border_size = " + Math.max(0, Math.min(8, Math.round(windowBorder))) + ", col = { active_border = \"rgba(" + rgb + act + ")\", inactive_border = \"rgba(" + rgb + "40)\" } } })"]);
    }
    function applyInput() {
        function b(v) { return v ? "true" : "false"; }
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ input = { " + (/^[a-z,]+$/.test(kbLayout) ? "kb_layout = \"" + kbLayout + "\", " : "") + "repeat_rate = " + Math.round(kbRepeatRate) + ", repeat_delay = " + Math.round(kbRepeatDelay)
            + ", sensitivity = " + mouseSens.toFixed(2) + ", accel_profile = \"" + (mouseAccel ? "adaptive" : "flat") + "\", natural_scroll = " + b(mouseNatural)
            + ", touchpad = { natural_scroll = " + b(tpNatural) + ", tap_to_click = " + b(tpTap) + ", disable_while_typing = " + b(tpDwt)
            + ", scroll_factor = " + tpScroll.toFixed(2) + " } } })"]);
    }
    readonly property string openUrlScript: decodeURIComponent(String(Qt.resolvedUrl("assets/open-url.py")).replace(/^file:\/\//, ""))
    function openUrl(u) { Quickshell.execDetached([openUrlScript, u]); }
    readonly property string toneScript: decodeURIComponent(String(Qt.resolvedUrl("assets/tone.sh")).replace(/^file:\/\//, ""))
    function pickTone(cur, v, sd, fresh) {
        v = Math.max(0, Math.min(1, v)); sd = Math.max(0, Math.min(0.5, sd || 0));
        var hi = Math.min(1, v + 0.6 * sd), lo = Math.max(0, v - 0.6 * sd);
        var cw = 1.05 / (Math.pow(hi, 2.2) + 0.05);
        var cd = (Math.pow(lo, 2.2) + 0.05) / 0.0623;
        if (!fresh && cur === 1) return cw > cd * 1.2 ? -1 : 1;
        if (!fresh && cur === -1) return cd > cw * 1.2 ? 1 : -1;
        if (Math.abs(cw - cd) < 0.08 * Math.max(cw, cd)) return darkMode ? -1 : 1;
        return cd > cw ? 1 : -1;
    }
    property var tonePending: null
    function measureTone(sx, sy, sw, sh) { measureArea(null, Qt.rect(sx, sy, sw, sh), null, true); }
    function measureArea(scr, rect, inner, fresh) {
        if (!toneMeasuring) return;
        var x = rect.x, y = rect.y, w = rect.width, h = rect.height;
        if (scr) {
            var x1 = Math.max(scr.x, x), y1 = Math.max(scr.y, y), x2 = Math.min(scr.x + scr.width, x + w), y2 = Math.min(scr.y + scr.height, y + h);
            x = x1; y = y1; w = x2 - x1; h = y2 - y1;
        }
        if (w < 8 || h < 8) return;
        var args = [Number(0.1), Math.round(x), Math.round(y), Math.round(w), Math.round(h)];
        if (inner) args.push(Math.round(inner.x), Math.round(inner.y), Math.round(inner.width), Math.round(inner.height));
        var req = { args: args, fresh: fresh === true };
        if (panelToneProc.running) { tonePending = req; return; }
        runPanelTone(req);
    }
    function runPanelTone(req) {
        panelToneProc.fresh = req.fresh;
        panelToneProc.command = ["sh", toneScript].concat(req.args.map(String));
        panelToneProc.running = true;
    }
    function measureAround(scr, panelRect, fresh) {
        var m = 160;
        measureArea(scr, Qt.rect(panelRect.x - m, panelRect.y - m, panelRect.width + 2 * m, panelRect.height + 2 * m), panelRect, fresh);
    }
    Process {
        id: panelToneProc
        property bool fresh: false
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(/\s+/);
                var v = parseFloat(p[0]), sd = parseFloat(p[1]);
                if (isNaN(v)) return;
                root.panelTone = root.pickTone(root.panelTone, v, isNaN(sd) ? 0 : sd, panelToneProc.fresh);
            }
        }
        onRunningChanged: if (!running && root.tonePending) { var r = root.tonePending; root.tonePending = null; root.runPanelTone(r); }
    }
    function measureBar() {
        return;
        if (!toneMeasuring || !barEnabled || barToneProc.running) return;
        var sc = Quickshell.screens && Quickshell.screens.length ? Quickshell.screens[0] : null;
        if (!sc) return;
        barToneProc.command = ["sh", toneScript, "0.25", String(Math.round(sc.x)), String(Math.round(sc.y)), String(Math.max(8, Math.round(sc.width))), String(Math.max(8, Math.round(barH)))];
        barToneProc.running = true;
    }
    Timer { id: barToneT; interval: 350; onTriggered: { root.toneStable = 0; root.measureBar(); } }
    property int toneStable: 0
    property real toneLastV: -1
    property real toneLastSd: -1
    Connections {
        target: root
        function onBarHeightChanged() { barToneT.restart(); }
        function onBarEnabledChanged() { if (root.barEnabled) barToneT.restart(); }
        function onWallpaperAccentChanged() { barToneT.restart(); }
        function onGlassClientsChanged() { barToneT.restart(); }
        function onAutoContrastChanged() { root.barTone = 0; root.panelTone = 0; }
    }
    Process {
        id: barToneProc
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(/\s+/);
                var v = parseFloat(p[0]), sd = parseFloat(p[1]);
                if (isNaN(v)) return;
                var s2 = isNaN(sd) ? 0 : sd;
                root.toneStable = (Math.abs(v - root.toneLastV) < 0.015 && Math.abs(s2 - root.toneLastSd) < 0.02) ? root.toneStable + 1 : 0;
                root.toneLastV = v; root.toneLastSd = s2;
                root.barTone = root.pickTone(root.barTone, v, s2, false);
            }
        }
    }
    property bool lockArtBackground: true
    property string lockClockStyle: "custom"
    property string lockClockFont: "rounded"
    property int lockClockWeight: 1000
    property string lockClockMaterial: "glass"
    property real lockClockIntensity: 0.099
    property string lockClockTint: "#EEACBE"
    property string lockClockDate: "long"
    readonly property var lockClockPresets: ({
        glass:   { f: "rounded",   w: 680, m: "glass", i: 0.6,  d: "long" },
        classic: { f: "rounded",   w: 600, m: "solid", i: 0.8,  d: "long" },
        serif:   { f: "serif",     w: 560, m: "solid", i: 0.85, d: "short" },
        liquid:  { f: "rounded",   w: 560, m: "glass", i: 0.12, d: "short" },
        thin:    { f: "rounded",   w: 200, m: "solid", i: 0.6,  d: "short" }
    })
    onLockClockFontChanged: if (lockClockFont === "condensed") Qt.callLater(function () { lockClockFont = "rounded"; })
    onLockClockMaterialChanged: Qt.callLater(function () {
        if (lockClockMaterial !== "frosted" && lockClockMaterial !== "liquid") return;
        if (lockClockPresets[lockClockStyle]) { applyLockClockPreset(lockClockStyle); return; }
        lockClockIntensity = lockClockMaterial === "liquid" ? 0.12 : 0.6;
        lockClockMaterial = "glass";
    })
    function applyLockClockPreset(name) {
        var p = lockClockPresets[name]; if (!p) return;
        lockClockFont = p.f; lockClockWeight = p.w; lockClockMaterial = p.m; lockClockIntensity = p.i; lockClockDate = p.d;
        lockClockStyle = name;
    }
    property bool uiSounds: true
    property real uiSoundVolume: 1
    property string alertSound: "glass"
    property bool gamingMode: false
    property bool gamingAuto: true
    property bool gamingAutoActive: false
    readonly property bool gaming: gamingMode || gamingAutoActive
    property bool ccMigGame: false
    property bool barGlass: true
    property real barBgOpacity: 0.10
    property bool glassRealtime: true
    property bool liveWallGlass: true
    property bool wallPauseCovered: false
    property bool wallUserPaused: false
    property bool showWallButton: true
    property bool glassDebug: false
    property string wallpaperPath: ""
    property bool use24h: true
    property string language: "auto"
    onLanguageChanged: Qt.uiLanguage = language === "auto" ? "" : language
    property bool showDate: true
    property bool showSeconds: true
    property bool showBatteryPercent: false
    property bool showTray: true
    property bool showSearch: true
    property bool weekStartsMonday: true
    property string terminal: "kitty"
    property string launcher: ""
    property string filesCmd: "xdg-open \"$HOME\""
    property string clipboardCmd: "cliphist list | (fuzzel --dmenu || wofi --dmenu || rofi -dmenu) | cliphist decode | wl-copy"
    property var appUsage: ({})
    property bool clipHistory: true
    property bool clipAutoPaste: true
    property var emojiRecent: []
    property string screenshotDir: Quickshell.env("HOME") + "/Screenshots"
    property bool screenshotSave: true
    property bool screenshotClipboard: true
    property bool screenshotNotify: true
    property int spotRequest: 0
    property string spotWant: "home"
    property int nightTemp: 4000
    property bool visOn: true
    property string visStyle: "mirror"
    property string visColor: "white"
    property real visGain: 2.0
    property int visCount: 128
    property real visWidth: 0.7
    property real mwGlow: 0.6
    property bool mwMotion: true
    property string mwBar: "slim"
    property string mwVisMode: "ambient"
    property bool visInCC: true
    property var ccControls: ["nowplaying", "focus", "record", "keepawake", "nightshift", "display", "sound", "micmute", "settings", "wallpapers", "lock", "screenshot"]
    property bool ccMigRec: false
    property bool recording: false
    property int recSecs: 0
    property var otherConnections: []
    property string keyboardLayout: "EN"
    property var kbLayouts: []
    property int kbIndex: 0
    property string kbMain: ""
    property string recordFile: ""
    property string fileQuery: ""
    property string fileSearchFor: ""
    property bool fileSearchPending: false
    property var fileHits: []

    readonly property var settingKeys: ["barEnabled", "accent", "accentUi", "fontFamily", "barHeight", "uiScaleAuto", "uiScaleManual", "glassOpacity",
        "barStyle", "barGlass", "glassRim", "glassGrain", "glassLiquid", "glassBlur", "barBgOpacity", "glassRealtime", "liveWallGlass", "wallPauseCovered", "wallUserPaused", "showWallButton", "glassDebug", "wallpaperPath", "use24h", "language", "showDate",
        "showSeconds", "showBatteryPercent", "showTray", "showSearch",
        "spotlightEnabled", "reduceMotion", "ccEnabled", "notificationsEnabled", "clockAppEnabled", "ccStyle", "barLogoMode", "barCustomLogoPath", "barWidgets", "weekStartsMonday", "terminal", "launcher",
        "filesCmd", "clipboardCmd", "appUsage", "clipHistory", "clipAutoPaste", "emojiRecent", "screenshotDir", "screenshotSave", "screenshotClipboard", "screenshotNotify", "nightTemp", "ccControls", "ccSizes", "ccPos", "ccRowH", "ccGapPx", "ccOnColor", "ccMigRec", "visOn", "visStyle", "visColor", "visGain", "visCount", "visWidth", "visInCC", "mwGlow", "mwMotion", "mwBar", "mwVisMode", "wallpaperDir", "wallpaperDirs", "wallpaperFavs", "wallpaperCmd", "wallpaperVideo", "wpRestorePath", "uiSounds", "gamingMode", "gamingAuto", "ccMigGame", "lockArtBackground",
        "lockClockStyle", "switcherStyle", "lockClockFont", "lockClockWeight", "lockClockMaterial", "lockClockIntensity", "lockClockTint", "lockClockDate", "autoContrast", "wallpaperAppearance", "wpPairLight", "wpPairDark",
        "idleLockMins", "idleScreenMins", "kbLayout", "notifDnd", "dnd", "nightOn", "keepAwake", "notifBannerSecs", "notifMutedApps", "notifAppsSeen", "focusSchedule", "focusFrom", "focusTo",
        "focusFullscreen", "focusAllowUrgent", "lockShowNotifs", "lockWallpaper", "uiSoundVolume", "alertSound",
        "kbRepeatRate", "kbRepeatDelay", "mouseSens", "mouseNatural", "mouseAccel", "tpNatural", "tpTap", "tpDwt", "tpScroll",
        "cursorTheme", "cursorSize", "cursorHideTyping", "cursorHideIdle", "cursorFollowFocus", "cursorWarpWs", "cursorZoom", "windowBorder", "floatNewWindows",
        "wsNumerals"]
    property var barWidgets: ["appleMenu", "appMenus", "workspaces", "volume", "keyboard", "notifications", "privacy", "controlCenter", "clock", "wifi", "bluetooth"]
    function barWidgetEnabled(id) { return barWidgets.indexOf(id) >= 0; }
    function resolvedBarLogoUrl() {
        var p = String(barCustomLogoPath || "").trim();
        if (p === "") return "";
        if (p.indexOf("://") >= 0) return p;
        var home = Quickshell.env("HOME") || "";
        if (p === "~") p = home;
        else if (p.indexOf("~/") === 0) p = home + p.substring(1);
        else if (p.charAt(0) !== "/") p = home + "/" + p;
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }
    readonly property string barCustomLogoUrl: resolvedBarLogoUrl()
    function setBarWidget(id, enabled) {
        var next = [];
        for (var i = 0; i < barWidgets.length; i++) if (barWidgets[i] !== id) next.push(barWidgets[i]);
        if (enabled) next.push(id);
        barWidgets = next;
    }
    readonly property var accentChoices: [
        { name: "Blue", c: "#0a84ff" }, { name: "Purple", c: "#bf5af2" }, { name: "Pink", c: "#ff375f" },
        { name: "Red", c: "#ff453a" }, { name: "Orange", c: "#ff9f0a" }, { name: "Yellow", c: "#ffd60a" },
        { name: "Green", c: "#30d158" }, { name: "Graphite", c: "#8e8e93" }
    ]

    readonly property var ccCatalog: [
        { id: "wifi",       label: I18n.tr("Wi-Fi"),         glyph: "wifi",       w: 2, h: 1, sizes: [[2, 1], [1, 1], [4, 1], [2, 2]] },
        { id: "bluetooth",  label: I18n.tr("Bluetooth"),     glyph: "bluetooth",  w: 2, h: 1, sizes: [[2, 1], [1, 1], [4, 1], [2, 2]] },
        { id: "airplane",   label: I18n.tr("Airplane Mode"), glyph: "airplane",   w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] },
        { id: "focus",      label: I18n.tr("Focus"),         glyph: "moon",       w: 2, h: 1, sizes: [[2, 1], [1, 1], [4, 1], [2, 2]] },
        { id: "nightshift", label: I18n.tr("Night Shift"),   glyph: "nightshift", w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] },
        { id: "keepawake",  label: I18n.tr("Keep Awake"),    glyph: "coffee",     w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] },
        { id: "gaming",     label: I18n.tr("Game Mode"),     glyph: "gamepad",    w: 2, h: 1, sizes: [[2, 1], [1, 1], [4, 1], [2, 2]] },
        { id: "record",     label: I18n.tr("Screen Recording"), glyph: "record",  w: 2, h: 1, sizes: [[2, 1], [1, 1], [4, 1], [2, 2]] },
        { id: "nowplaying", label: I18n.tr("Now Playing"),   glyph: "note",       w: 2, h: 2, sizes: [[2, 2], [4, 2]], range: [2, 4, 2, 2] },
        { id: "display",    label: I18n.tr("Display"),       glyph: "sun",        w: 4, h: 1, sizes: [[4, 1], [3, 1], [2, 1]], range: [2, 4, 1, 1] },
        { id: "sound",      label: I18n.tr("Sound"),         glyph: "speaker",    w: 4, h: 1, sizes: [[4, 1], [3, 1], [2, 1]], range: [2, 4, 1, 1] },
        { id: "lock",        label: I18n.tr("Lock Screen"),     glyph: "lock",    w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] },
        { id: "screenshot",  label: I18n.tr("Screenshot"),      glyph: "camera",  w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] },
        { id: "colorpicker", label: I18n.tr("Color Picker"),    glyph: "dropper", w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] },
        { id: "wallpapers",  label: I18n.tr("Wallpapers"),      glyph: "photo",   w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] },
        { id: "settings",    label: I18n.tr("System Settings"), glyph: "gear",    w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] },
        { id: "micmute",     label: I18n.tr("Microphone"),      glyph: "mic",     w: 4, h: 1, sizes: [[4, 1], [3, 1], [2, 1]], range: [2, 4, 1, 1] },
        { id: "powermode",   label: I18n.tr("Power Mode"),      glyph: "bolt",    w: 1, h: 1, sizes: [[1, 1], [2, 1], [4, 1], [2, 2]] }
    ]
    property var ccSizes: ({ "micmute": "4x1", "nowplaying": "4x2", "wallpapers": "2x1", "settings": "1x1", "lock": "2x1" })
    function ccRange(id) {
        var d = ccDef(id);
        return d && d.range ? d.range : [1, 4, 1, 2];
    }
    function ccSizeFor(id) {
        var d = ccDef(id);
        if (!d) return [1, 1];
        var m = /^(\d)x(\d)$/.exec(String(ccSizes[id] || "")), r = ccRange(id);
        if (m) {
            var w = parseInt(m[1]), h = parseInt(m[2]);
            if (w >= r[0] && w <= r[1] && h >= r[2] && h <= r[3]) return [w, h];
        }
        return [d.w, d.h];
    }
    function ccSetSize(id, w, h) { var m = {}; for (var k in ccSizes) m[k] = ccSizes[k]; m[id] = w + "x" + h; ccSizes = m; }
    function ccResizeTo(id, w, h) {
        var r = ccRange(id);
        w = Math.max(r[0], Math.min(r[1], w)); h = Math.max(r[2], Math.min(r[3], h));
        var cur = ccSizeFor(id);
        if (cur[0] === w && cur[1] === h) return;
        if (ccFree) {
            var me = ccItem(id), pos = ccFreezeMap();
            if (me) {
                var col = Math.min(me.col, 4 - w);
                pos[id] = col + "," + me.row;
                var it = ccPlan.items;
                for (var i = 0; i < it.length; i++) {
                    var o = it[i];
                    if (o.id !== id && col < o.col + o.w && o.col < col + w && me.row < o.row + o.h && o.row < me.row + h) delete pos[o.id];
                }
            }
            ccPos = pos;
        }
        ccSetSize(id, w, h);
    }
    function ccCycleSize(id) {
        var d = ccDef(id);
        if (!d || !d.sizes || d.sizes.length < 2) return;
        var cur = ccSizeFor(id), at = 0;
        for (var i = 0; i < d.sizes.length; i++) if (d.sizes[i][0] === cur[0] && d.sizes[i][1] === cur[1]) at = i;
        var nx = d.sizes[(at + 1) % d.sizes.length];
        ccResizeTo(id, nx[0], nx[1]);
    }
    function ccResetLayout() { ccControls = ccDefault.slice(); ccSizes = ({}); ccPos = ({}); }
    function ccResetAll() { ccResetLayout(); ccRowH = 66; ccGapPx = 6; ccOnColor = ""; }
    property real ccRowH: 68
    property real ccGapPx: 8
    property var ccPos: ({})
    readonly property bool ccFree: Object.keys(ccPos).length > 0
    function ccTidy() { ccPos = ({}); }
    property string ccOnColor: "#eeacbe"
    readonly property color ccOnFill: ccOnColor !== "" ? Qt.color(ccOnColor) : Qt.color("white")
    readonly property bool ccOnLight: (0.299 * ccOnFill.r + 0.587 * ccOnFill.g + 0.114 * ccOnFill.b) > 0.62
    readonly property color ccOnInk: ccOnLight ? Qt.rgba(0.07, 0.07, 0.09, 1) : Qt.color("white")
    readonly property var ccDefault: ["wifi", "nowplaying", "bluetooth", "airplane", "focus", "record", "nightshift", "keepawake", "display", "sound"]
    function ccDef(id) {
        for (var i = 0; i < ccCatalog.length; i++) if (ccCatalog[i].id === id) return ccCatalog[i];
        return null;
    }
    function ccLayout(ids) {
        var cols = 4, occ = [], out = [], seen = {}, rows = 0;
        function isFree(r, c, w, h) {
            for (var y = r; y < r + h; y++) for (var x = c; x < c + w; x++) if (occ[y] && occ[y][x]) return false;
            return true;
        }
        function mark(r, c, w, h) {
            for (var y = r; y < r + h; y++) { if (!occ[y]) occ[y] = []; for (var x = c; x < c + w; x++) occ[y][x] = true; }
        }
        var todo = [];
        for (var i = 0; i < ids.length; i++) {
            var d = ccDef(ids[i]);
            if (!d || seen[d.id]) continue;
            seen[d.id] = true;
            todo.push(d);
        }
        var rest = [];
        for (var q = 0; q < todo.length; q++) {
            var pz = ccSizeFor(todo[q].id), pin = ccPosOf(todo[q].id);
            if (pin && pin[0] + pz[0] <= cols && isFree(pin[1], pin[0], pz[0], pz[1])) {
                mark(pin[1], pin[0], pz[0], pz[1]);
                out.push({ id: todo[q].id, col: pin[0], row: pin[1], w: pz[0], h: pz[1] });
                rows = Math.max(rows, pin[1] + pz[1]);
            } else rest.push(todo[q]);
        }
        for (var i2 = 0; i2 < rest.length; i2++) {
            var d = rest[i2];
            var sz = ccSizeFor(d.id), dw = sz[0], dh = sz[1];
            var placed = false;
            for (var r = 0; !placed; r++) {
                for (var c = 0; c + dw <= cols; c++) {
                    if (isFree(r, c, dw, dh)) {
                        mark(r, c, dw, dh);
                        out.push({ id: d.id, col: c, row: r, w: dw, h: dh });
                        rows = Math.max(rows, r + dh);
                        placed = true;
                        break;
                    }
                }
            }
        }
        var sliderRow = [], ys = [];
        for (var k = 0; k < out.length; k++) {
            if (out[k].id === "display" || out[k].id === "sound" || out[k].id === "micmute")
                for (var rr = out[k].row; rr < out[k].row + out[k].h; rr++) sliderRow[rr] = true;
        }
        for (var r2 = 0; r2 <= rows; r2++)
            ys[r2] = r2 === 0 ? 0 : ys[r2 - 1] + ccCellH + ((sliderRow[r2] || sliderRow[r2 - 1]) ? ccSliderGap : ccGap);
        for (var m = 0; m < out.length; m++) {
            out[m].y = ys[out[m].row];
            out[m].hpx = ys[out[m].row + out[m].h - 1] + ccCellH - ys[out[m].row];
        }
        return { items: out, rows: rows, ys: ys, total: rows > 0 ? ys[rows - 1] + ccCellH : 0 };
    }
    function ccPosOf(id) {
        var p = String(ccPos[id] || "").split(",");
        if (p.length !== 2) return null;
        var c = parseInt(p[0]), r = parseInt(p[1]);
        return (isNaN(c) || isNaN(r) || c < 0 || c > 3 || r < 0 || r > 40) ? null : [c, r];
    }
    function ccItem(id) {
        var it = ccPlan.items;
        for (var i = 0; i < it.length; i++) if (it[i].id === id) return it[i];
        return null;
    }
    function ccFreezeMap() {
        var m = {}, it = ccPlan.items;
        for (var i = 0; i < it.length; i++) m[it[i].id] = it[i].col + "," + it[i].row;
        return m;
    }
    readonly property real ccCellH: Math.max(40, Math.min(110, ccRowH))
    readonly property real ccGap: Math.max(1, Math.min(20, ccGapPx))
    readonly property real ccSliderGap: ccGap + 4
    function ccAvailable(id) {
        if (id === "wifi") return hasWifi;
        if (id === "bluetooth") return hasBt;
        if (id === "airplane") return hasRadios;
        return true;
    }
    readonly property var ccPlan: ccLayout(ccControls.filter(function (id) { return root.ccAvailable(id); }))
    property var ccSnap: null
    function ccEditBegin() { ccSnap = { c: ccControls.slice(), s: JSON.parse(JSON.stringify(ccSizes)), p: JSON.parse(JSON.stringify(ccPos)) }; }
    function ccEditSave() { ccSnap = null; saveTimer.restart(); }
    function ccEditCancel() {
        if (!ccSnap) return;
        var o = ccSnap;
        ccSnap = null;
        ccControls = o.c; ccSizes = o.s; ccPos = o.p;
        saveTimer.restart();
    }
    function ccAdd(id) {
        if (ccControls.indexOf(id) < 0) ccControls = ccControls.concat([id]);
    }
    function ccRemove(id) {
        ccControls = ccControls.filter(function (x) { return x !== id; });
        if (ccPos[id] !== undefined) { var m = {}; for (var k in ccPos) if (k !== id) m[k] = ccPos[k]; ccPos = m; }
    }
    function ccTarget(id, tx, ty, cw) {
        var me = ccItem(id);
        if (!me) return null;
        var plan = ccPlan, it = plan.items, i;
        var col = Math.max(0, Math.min(4 - me.w, Math.round(tx / (cw + ccGap)))), row = 0, best = 1e18;
        for (var r = 0; r <= plan.rows; r++) {
            var dd = Math.abs(plan.ys[r] - ty);
            if (dd < best) { best = dd; row = r; }
        }
        function clash(c, r2, w, h, skipA, skipB) {
            var hit = [];
            for (var k = 0; k < it.length; k++) {
                var o = it[k];
                if (o.id === skipA || o.id === skipB) continue;
                if (c < o.col + o.w && o.col < c + w && r2 < o.row + o.h && o.row < r2 + h) hit.push(o);
            }
            return hit;
        }
        if (col === me.col && row === me.row) return { col: col, row: row, kind: "stay" };
        var hits = clash(col, row, me.w, me.h, id, "");
        if (hits.length === 0) return { col: col, row: row, kind: "free" };
        if (!ccFree) return { col: col, row: row, kind: "order" };
        if (hits.length === 1) {
            var o2 = hits[0];
            if (me.col + o2.w <= 4 && clash(me.col, me.row, o2.w, o2.h, id, o2.id).length === 0
                && !(me.col < col + me.w && col < me.col + o2.w && me.row < row + me.h && row < me.row + o2.h))
                return { col: col, row: row, kind: "swap", other: o2 };
        }
        return { col: col, row: row, kind: "none" };
    }
    function ccDrop(id, tx, ty, px, py, cw) {
        var t = ccTarget(id, tx, ty, cw);
        if (!t || t.kind === "stay" || t.kind === "none") return;
        if (t.kind === "free" || t.kind === "swap") {
            var me = ccItem(id), pos = ccFreezeMap();
            pos[id] = t.col + "," + t.row;
            if (t.kind === "swap" && me) pos[t.other.id] = me.col + "," + me.row;
            ccPos = pos;
            return;
        }
        var order = ccControls.slice(), from = order.indexOf(id);
        if (from < 0) return;
        var to = -1, best = 1e18, it = ccPlan.items;
        for (var i = 0; i < it.length; i++) {
            if (it[i].id === id) continue;
            var o = it[i];
            var cx = o.col * (cw + ccGap) + (o.w * cw + (o.w - 1) * ccGap) / 2;
            var cy = o.y + o.hpx / 2;
            var dd = (cx - px) * (cx - px) + (cy - py) * (cy - py);
            if (dd < best) { best = dd; to = order.indexOf(o.id); }
        }
        if (to < 0 || to === from) return;
        order.splice(from, 1);
        order.splice(to, 0, id);
        ccControls = order;
    }

    readonly property string configDir: Quickshell.env("HOME") + "/.config/yukibar"
    readonly property string dockConfigDir: Quickshell.env("HOME") + "/.config/yukidock"
    readonly property int popRoom: 900

    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    function lockScreen() {
        sh('sh ~/.config/quickshell/YukiLock/lock-via-ipc.sh');
    }
    function sleepMachine() {
        sh('sh ~/.config/quickshell/YukiLock/lock-via-ipc.sh; sleep 0.5; systemctl suspend');
    }
    function logOut() {
        sh('if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then uwsm stop; '
           + 'else hyprctl dispatch "hl.dsp.exit()" || hyprctl dispatch exit; fi');
    }

    property bool autoContrast: true
    property int panelTone: 0
    readonly property bool effDark: panelDarkMode
    property real dk: effDark ? 1 : 0
    Behavior on dk { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
    function mixc(l, d) { return Qt.rgba(l.r + (d.r - l.r) * dk, l.g + (d.g - l.g) * dk, l.b + (d.b - l.b) * dk, l.a + (d.a - l.a) * dk); }
    property int barTone: 0
    readonly property bool barTextDark: false
    property real btk: barTextDark ? 0 : 1
    Behavior on btk { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    function mixb(l, d) { return Qt.rgba(l.r + (d.r - l.r) * btk, l.g + (d.g - l.g) * btk, l.b + (d.b - l.b) * btk, l.a + (d.a - l.a) * btk); }
    readonly property bool panelTextDark: !panelTextWhite
    property real ptk: panelTextDark ? 0 : 1
    Behavior on ptk { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    function mixp(l, d) { return Qt.rgba(l.r + (d.r - l.r) * ptk, l.g + (d.g - l.g) * ptk, l.b + (d.b - l.b) * ptk, l.a + (d.a - l.a) * ptk); }
    readonly property bool ccDark: panelDarkMode
    property real ccDk: ccDark ? 1 : 0
    Behavior on ccDk { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
    function ccMix(l, d) { return Qt.rgba(l.r + (d.r - l.r) * ccDk, l.g + (d.g - l.g) * ccDk, l.b + (d.b - l.b) * ccDk, l.a + (d.a - l.a) * ccDk); }

    QtObject {
        id: bpal
        readonly property bool dark: !root.barTextDark
        readonly property string fam: root.fontFamily
        readonly property color accent: root.accent
        readonly property color fg: root.mixb(Qt.color("#1D1D1F"), Qt.color("#FFFFFF"))
        readonly property color fg2: root.mixb(Qt.rgba(0, 0, 0, 0.55), Qt.rgba(1, 1, 1, 0.62))
        readonly property color ink: fg
        readonly property color ink2: fg2
        readonly property color fg3: root.mixb(Qt.rgba(0, 0, 0, 0.32), Qt.rgba(1, 1, 1, 0.34))
        readonly property color tile: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.42)
        readonly property color tileBorder: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.70)
        readonly property color btnOff: dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.10)
        readonly property color btnHover: dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0, 0, 0, 0.16)
        readonly property color hover: root.mixb(Qt.rgba(0, 0, 0, 0.09), Qt.rgba(1, 1, 1, 0.14))
        readonly property color sep: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)
        readonly property color track: dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.12)
        readonly property color content: dark ? "#1E1E1E" : "#F5F5F7"
        readonly property color card: root.accentWash(dark ? Qt.color("#2B2B2D") : Qt.color("#FFFFFF"), 0.30, dark)
        readonly property color cardBorder: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08)
        readonly property color switchOff: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.16)
    }
    QtObject {
        id: spotPal
        readonly property bool dark: true
        readonly property string fam: root.fontFamily
        readonly property color accent: root.accent
        readonly property color fg: "#FFFFFF"
        readonly property color fg2: Qt.rgba(1, 1, 1, 0.62)
        readonly property color ink: fg
        readonly property color ink2: fg2
        readonly property color fg3: Qt.rgba(1, 1, 1, 0.34)
        readonly property color tile: Qt.rgba(1, 1, 1, 0.10)
        readonly property color tileBorder: Qt.rgba(1, 1, 1, 0.16)
        readonly property color btnOff: Qt.rgba(1, 1, 1, 0.20)
        readonly property color btnHover: Qt.rgba(1, 1, 1, 0.30)
        readonly property color hover: Qt.rgba(1, 1, 1, 0.14)
        readonly property color sep: Qt.rgba(1, 1, 1, 0.14)
        readonly property color track: Qt.rgba(1, 1, 1, 0.20)
        readonly property color content: "#1E1E1E"
        readonly property color card: root.accentWash(Qt.color("#2B2B2D"), 0.30, true)
        readonly property color cardBorder: Qt.rgba(1, 1, 1, 0.07)
        readonly property color switchOff: Qt.rgba(1, 1, 1, 0.22)
    }
    QtObject {
        id: panelPal
        readonly property bool dark: root.panelDarkMode
        readonly property string fam: root.fontFamily
        readonly property color accent: root.accent
        readonly property color fg: root.mixp(Qt.color("#1D1D1F"), Qt.color("#FFFFFF"))
        readonly property color fg2: root.mixp(Qt.rgba(0, 0, 0, 0.55), Qt.rgba(1, 1, 1, 0.62))
        readonly property color ink: fg
        readonly property color ink2: fg2
        readonly property color fg3: root.mixp(Qt.rgba(0, 0, 0, 0.32), Qt.rgba(1, 1, 1, 0.34))
        readonly property color tile: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.42)
        readonly property color tileBorder: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.70)
        readonly property color btnOff: dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.10)
        readonly property color btnHover: dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0, 0, 0, 0.16)
        readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09)
        readonly property color sep: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)
        readonly property color track: dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.12)
        readonly property color content: dark ? "#1E1E1E" : "#F5F5F7"
        readonly property color card: root.accentWash(dark ? Qt.color("#2B2B2D") : Qt.color("#FFFFFF"), 0.30, dark)
        readonly property color cardBorder: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08)
        readonly property color switchOff: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.16)
    }
    QtObject {
        id: pal
        readonly property bool dark: root.effDark
        readonly property string fam: root.fontFamily
        readonly property color accent: root.accent
        readonly property color fg: root.mixp(Qt.color("#1D1D1F"), Qt.color("#FFFFFF"))
        readonly property color fg2: root.mixp(Qt.rgba(0, 0, 0, 0.55), Qt.rgba(1, 1, 1, 0.62))
        readonly property color ink: fg
        readonly property color ink2: fg2
        readonly property color fg3: root.mixp(Qt.rgba(0, 0, 0, 0.32), Qt.rgba(1, 1, 1, 0.34))
        readonly property color tile: root.mixc(Qt.rgba(1, 1, 1, 0.42), Qt.rgba(1, 1, 1, 0.10))
        readonly property color tileBorder: root.mixc(Qt.rgba(1, 1, 1, 0.70), Qt.rgba(1, 1, 1, 0.16))
        readonly property color btnOff: root.mixc(Qt.rgba(0, 0, 0, 0.10), Qt.rgba(1, 1, 1, 0.20))
        readonly property color btnHover: root.mixc(Qt.rgba(0, 0, 0, 0.16), Qt.rgba(1, 1, 1, 0.30))
        readonly property color hover: root.mixc(Qt.rgba(0, 0, 0, 0.09), Qt.rgba(1, 1, 1, 0.14))
        readonly property color sep: root.mixc(Qt.rgba(0, 0, 0, 0.12), Qt.rgba(1, 1, 1, 0.14))
        readonly property color track: root.mixc(Qt.rgba(0, 0, 0, 0.12), Qt.rgba(1, 1, 1, 0.20))
        readonly property color content: dark ? "#1E1E1E" : "#F5F5F7"
        readonly property color card: root.accentWash(dark ? Qt.color("#2B2B2D") : Qt.color("#FFFFFF"), 0.30, dark)
        readonly property color cardBorder: root.mixc(Qt.rgba(0, 0, 0, 0.08), Qt.rgba(1, 1, 1, 0.07))
        readonly property color switchOff: root.mixc(Qt.rgba(0, 0, 0, 0.16), Qt.rgba(1, 1, 1, 0.22))
    }
    QtObject {
        id: ccPal
        readonly property bool dark: root.ccDark
        readonly property string fam: root.fontFamily
        readonly property color accent: root.accent
        readonly property color fg: root.mixp(Qt.color("#1D1D1F"), Qt.color("#FFFFFF"))
        readonly property color fg2: root.mixp(Qt.rgba(0, 0, 0, 0.55), Qt.rgba(1, 1, 1, 0.62))
        readonly property color ink: root.accentUi ? root.accentInk : fg
        readonly property color ink2: root.accentUi ? Qt.rgba(root.accentInk.r, root.accentInk.g, root.accentInk.b, 0.75) : fg2
        readonly property color fg3: root.mixp(Qt.rgba(0, 0, 0, 0.32), Qt.rgba(1, 1, 1, 0.34))
        readonly property color tile: root.ccMix(Qt.rgba(1, 1, 1, 0.42), Qt.rgba(1, 1, 1, 0.10))
        readonly property color tileBorder: root.ccMix(Qt.rgba(1, 1, 1, 0.70), Qt.rgba(1, 1, 1, 0.16))
        readonly property color btnOff: root.ccMix(Qt.rgba(0, 0, 0, 0.10), Qt.rgba(1, 1, 1, 0.20))
        readonly property color btnHover: root.ccMix(Qt.rgba(0, 0, 0, 0.16), Qt.rgba(1, 1, 1, 0.30))
        readonly property color hover: root.ccMix(Qt.rgba(0, 0, 0, 0.09), Qt.rgba(1, 1, 1, 0.14))
        readonly property color sep: root.ccMix(Qt.rgba(0, 0, 0, 0.12), Qt.rgba(1, 1, 1, 0.14))
        readonly property color track: root.ccMix(Qt.rgba(0, 0, 0, 0.12), Qt.rgba(1, 1, 1, 0.20))
        readonly property color content: dark ? "#1E1E1E" : "#F5F5F7"
        readonly property color card: root.accentWash(dark ? Qt.color("#2B2B2D") : Qt.color("#FFFFFF"), 0.30, dark)
        readonly property color cardBorder: root.ccMix(Qt.rgba(0, 0, 0, 0.08), Qt.rgba(1, 1, 1, 0.07))
        readonly property color switchOff: root.ccMix(Qt.rgba(0, 0, 0, 0.16), Qt.rgba(1, 1, 1, 0.22))
    }

    component Glyph: Canvas {
        id: gl
        property string kind: ""
        property color color: "white"
        property real level: 3
        property bool flag: false
        width: 18; height: 18
        antialiasing: true
        onKindChanged: requestPaint()
        onColorChanged: requestPaint()
        onLevelChanged: requestPaint()
        onFlagChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var s = Math.min(width, height) / 18;
            ctx.scale(s, s);
            ctx.strokeStyle = color;
            ctx.fillStyle = color;
            ctx.lineWidth = 1.5;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            var PI = Math.PI;
            function circ(x, y, r) { ctx.beginPath(); ctx.arc(x, y, r, 0, PI * 2); }
            function line(x1, y1, x2, y2) { ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); }
            function poly(p, fill) {
                ctx.beginPath(); ctx.moveTo(p[0], p[1]);
                for (var i = 2; i < p.length; i += 2) ctx.lineTo(p[i], p[i + 1]);
                if (fill) { ctx.closePath(); ctx.fill(); } else ctx.stroke();
            }
            function rpoly(p, r) {
                var n = p.length / 2;
                ctx.beginPath();
                ctx.moveTo((p[0] + p[2 * (n - 1)]) / 2, (p[1] + p[2 * (n - 1) + 1]) / 2);
                for (var q = 0; q < n; q++) {
                    var x = p[2 * q], y = p[2 * q + 1];
                    var nx = p[2 * ((q + 1) % n)], ny = p[2 * ((q + 1) % n) + 1];
                    ctx.arcTo(x, y, (x + nx) / 2, (y + ny) / 2, r);
                }
                ctx.closePath(); ctx.fill();
            }
            function rrect(x, y, w, h, r) {
                ctx.beginPath(); ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
                ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
                ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
                ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r); ctx.closePath();
            }
            var k = kind, i2;

            if (k === "arch") {
                ctx.translate(0.43, 0);
                ctx.beginPath();
                ctx.moveTo(8.54, 0.45);
                ctx.bezierCurveTo(7.78, 2.32, 7.32, 3.54, 6.48, 5.35);
                ctx.bezierCurveTo(7, 5.9, 7.63, 6.54, 8.67, 7.26);
                ctx.bezierCurveTo(7.56, 6.81, 6.8, 6.35, 6.23, 5.87);
                ctx.bezierCurveTo(5.15, 8.13, 3.45, 11.35, 0, 17.55);
                ctx.bezierCurveTo(2.71, 15.98, 4.81, 15.02, 6.77, 14.65);
                ctx.lineTo(6.64, 13.49);
                ctx.lineTo(6.64, 13.4);
                ctx.bezierCurveTo(6.68, 11.67, 7.59, 10.33, 8.66, 10.42);
                ctx.bezierCurveTo(9.72, 10.51, 10.56, 12, 10.51, 13.73);
                ctx.lineTo(10.4, 14.66);
                ctx.bezierCurveTo(12.34, 15.04, 14.44, 16, 17.13, 17.55);
                ctx.bezierCurveTo(16.6, 16.58, 16.12, 15.71, 15.67, 14.88);
                ctx.bezierCurveTo(14.96, 14.33, 14.22, 13.61, 12.75, 12.86);
                ctx.bezierCurveTo(13.77, 13.13, 14.51, 13.44, 15.08, 13.78);
                ctx.bezierCurveTo(10.24, 6.35, 9.4, 3.82, 8.54, 0.45);
                ctx.closePath();
                ctx.fill();
            } else if (k === "wifi") {
                var radii = [3.8, 7.2, 10.6];
                for (i2 = 0; i2 < 3; i2++) {
                    if (i2 >= level) ctx.globalAlpha = 0.3; else ctx.globalAlpha = 1;
                    ctx.beginPath(); ctx.arc(9, 14.6, radii[i2], -PI * 0.75, -PI * 0.25); ctx.stroke();
                }
                ctx.globalAlpha = 1;
                circ(9, 14.6, 1.3); ctx.fill();
                if (flag) line(2.5, 2.5, 15.5, 15.5);
            } else if (k === "bluetooth") {
                poly([5, 5.5, 13, 12.5, 9, 16, 9, 2, 13, 5.5, 5, 12.5], false);
                if (flag) line(2.5, 2.5, 15.5, 15.5);
            } else if (k === "airplane") {
                line(9, 1.8, 9, 16.2);
                poly([2, 10.5, 9, 7, 16, 10.5], false);
                poly([6, 15.5, 9, 13.5, 12, 15.5], false);
            } else if (k === "moon") {
                circ(9, 9, 6.8); ctx.fill();
                ctx.globalCompositeOperation = "destination-out";
                circ(12.2, 6.4, 5.6); ctx.fill();
                ctx.globalCompositeOperation = "source-over";
            } else if (k === "sun") {
                var r = 2.2 + level * 0.5, a = r + 2.2, b = a + 1.2 + level * 0.4;
                circ(9, 9, r); ctx.stroke();
                for (i2 = 0; i2 < 8; i2++) {
                    var ang = i2 * PI / 4;
                    line(9 + Math.cos(ang) * a, 9 + Math.sin(ang) * a, 9 + Math.cos(ang) * b, 9 + Math.sin(ang) * b);
                }
            } else if (k === "nightshift") {
                ctx.beginPath(); ctx.arc(9, 11, 4, PI, PI * 2); ctx.stroke();
                line(2, 11, 16, 11);
                line(5.5, 14.5, 12.5, 14.5);
                line(9, 3.2, 9, 5);
                line(3.6, 5.6, 4.9, 6.9);
                line(14.4, 5.6, 13.1, 6.9);
            } else if (k === "coffee") {
                ctx.beginPath(); ctx.moveTo(3.5, 7.5); ctx.lineTo(12, 7.5); ctx.lineTo(12, 11.5);
                ctx.quadraticCurveTo(12, 15, 7.75, 15); ctx.quadraticCurveTo(3.5, 15, 3.5, 11.5); ctx.closePath(); ctx.stroke();
                ctx.beginPath(); ctx.arc(12.4, 10, 2.2, -PI * 0.5, PI * 0.5); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(6, 2.6); ctx.quadraticCurveTo(7.2, 4, 6, 5.4); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(9.4, 2.6); ctx.quadraticCurveTo(10.6, 4, 9.4, 5.4); ctx.stroke();
            } else if (k === "speaker") {
                poly([2.2, 7, 5.4, 7, 9.2, 3.6, 9.2, 14.4, 5.4, 11, 2.2, 11], true);
                if (level <= 0) {
                    line(12, 6.8, 16, 11.2); line(16, 6.8, 12, 11.2);
                } else {
                    for (i2 = 1; i2 <= Math.min(2, Math.ceil(level / 1.5)); i2++) {
                        ctx.beginPath(); ctx.arc(9.2, 9, 2.4 + i2 * 3.0, -0.62, 0.62); ctx.stroke();
                    }
                }
            } else if (k === "record") {
                circ(9, 9, 7); ctx.stroke();
                circ(9, 9, 3.7); ctx.fill();
            } else if (k === "stoprec") {
                circ(9, 9, 7); ctx.stroke();
                rrect(5.9, 5.9, 6.2, 6.2, 1.6); ctx.fill();
            } else if (k === "mic") {
                rrect(6.5, 1.8, 5, 8.6, 2.5); ctx.stroke();
                ctx.beginPath(); ctx.arc(9, 8.4, 5, 0.12, PI - 0.12, false); ctx.stroke();
                line(9, 13.4, 9, 16); line(6.2, 16, 11.8, 16);
                if (flag) line(2.5, 2.5, 15.5, 15.5);
            } else if (k === "headphones") {
                ctx.beginPath(); ctx.arc(9, 9.8, 5.9, PI, 0, false); ctx.stroke();
                rrect(2.5, 9.4, 3.3, 5.8, 1.5); ctx.fill();
                rrect(12.2, 9.4, 3.3, 5.8, 1.5); ctx.fill();
            } else if (k === "monitor") {
                rrect(2, 3, 14, 9.4, 1.8); ctx.stroke();
                line(6.4, 15.4, 11.6, 15.4); line(9, 12.4, 9, 15.4);
            } else if (k === "camera") {
                rrect(2, 4.6, 14, 9.6, 2.2); ctx.stroke();
                circ(9, 9.4, 2.7); ctx.stroke();
                line(6.8, 3, 11.2, 3);
            } else if (k === "gamepad") {
                ctx.beginPath();
                ctx.moveTo(5, 5); ctx.lineTo(13, 5);
                ctx.bezierCurveTo(16.4, 5, 17.4, 9.5, 16.6, 12.6); ctx.bezierCurveTo(16.1, 14.4, 14.2, 14.6, 13.1, 13.2);
                ctx.lineTo(11.8, 11.6); ctx.lineTo(6.2, 11.6); ctx.lineTo(4.9, 13.2);
                ctx.bezierCurveTo(3.8, 14.6, 1.9, 14.4, 1.4, 12.6); ctx.bezierCurveTo(0.6, 9.5, 1.6, 5, 5, 5);
                ctx.closePath(); ctx.stroke();
                line(5.3, 7.4, 5.3, 10.2); line(3.9, 8.8, 6.7, 8.8);
                circ(12.4, 8.0, 0.9); ctx.fill();
                circ(14.0, 9.6, 0.9); ctx.fill();
            } else if (k === "ethernet") {
                poly([5.2, 4.6, 1.6, 9, 5.2, 13.4], false);
                poly([12.8, 4.6, 16.4, 9, 12.8, 13.4], false);
                circ(6.5, 9, 1.1); ctx.fill();
                circ(9, 9, 1.1); ctx.fill();
                circ(11.5, 9, 1.1); ctx.fill();
            } else if (k === "play") {
                rpoly([5, 3.2, 15, 9, 5, 14.8], 0.8);
            } else if (k === "pause") {
                rrect(4.2, 3.4, 3.4, 11.2, 0.7); ctx.fill();
                rrect(10.4, 3.4, 3.4, 11.2, 0.7); ctx.fill();
            } else if (k === "keyboard") {
                rrect(1.5, 3.8, 15, 10.4, 2.4); ctx.stroke();
                for (var kr = 0; kr < 4; kr++) { circ(5.1 + kr * 2.6, 7.4, 0.85); ctx.fill(); }
                line(6, 10.8, 12, 10.8);
            } else if (k === "livewall") {
                rrect(1.8, 3.2, 14.4, 11.6, 2.6); ctx.stroke();
                if (flag) rpoly([7.3, 6.3, 12, 9, 7.3, 11.7], 0.5);
                else { rrect(6.5, 6.4, 1.9, 5.2, 0.5); ctx.fill(); rrect(9.6, 6.4, 1.9, 5.2, 0.5); ctx.fill(); }
            } else if (k === "next") {
                rpoly([1.8, 4, 8.6, 9, 1.8, 14], 0.6);
                rpoly([9.4, 4, 16.2, 9, 9.4, 14], 0.6);
            } else if (k === "prev") {
                rpoly([16.2, 4, 9.4, 9, 16.2, 14], 0.6);
                rpoly([8.6, 4, 1.8, 9, 8.6, 14], 0.6);
            } else if (k === "note") {
                line(7, 12.5, 7, 3.5); line(7, 3.5, 14, 2.2); line(14, 2.2, 14, 11);
                circ(5.2, 13, 2); ctx.fill();
                circ(12.2, 11.6, 2); ctx.fill();
            } else if (k === "search") {
                circ(7.6, 7.6, 4.8); ctx.stroke();
                line(11.2, 11.2, 15.4, 15.4);
            } else if (k === "cc") {
                rrect(2, 3, 14, 5.2, 2.6); ctx.stroke();
                circ(12.4, 5.6, 1.5); ctx.fill();
                rrect(2, 9.8, 14, 5.2, 2.6); ctx.stroke();
                circ(5.6, 12.4, 1.5); ctx.fill();
            } else if (k === "volume") {
                poly([2.2, 7, 5.4, 7, 9.2, 3.6, 9.2, 14.4, 5.4, 11, 2.2, 11], true);
                ctx.beginPath(); ctx.arc(9.2, 9, 4.4, -0.62, 0.62); ctx.stroke();
                ctx.beginPath(); ctx.arc(9.2, 9, 7.4, -0.62, 0.62); ctx.stroke();
            } else if (k === "bolt") {
                poly([10, 1.5, 4.5, 10, 8.4, 10, 7.6, 16.5, 13.5, 7.6, 9.6, 7.6], true);
            } else if (k === "appstore") {
                line(9, 2.8, 3.8, 14.6);
                line(9, 2.8, 14.2, 14.6);
                line(5.4, 11.2, 12.6, 11.2);
            } else if (k === "folder") {
                ctx.beginPath();
                ctx.moveTo(2.2, 13);
                ctx.lineTo(2.2, 5.6);
                ctx.arcTo(2.2, 3.8, 4, 3.8, 1.8);
                ctx.lineTo(6.6, 3.8);
                ctx.lineTo(8.2, 5.8);
                ctx.lineTo(14, 5.8);
                ctx.arcTo(15.8, 5.8, 15.8, 7.6, 1.8);
                ctx.lineTo(15.8, 13);
                ctx.arcTo(15.8, 15.2, 13.6, 15.2, 2.2);
                ctx.lineTo(4.4, 15.2);
                ctx.arcTo(2.2, 15.2, 2.2, 13, 2.2);
                ctx.closePath(); ctx.stroke();
            } else if (k === "layers") {
                ctx.beginPath(); ctx.moveTo(9, 2.4); ctx.lineTo(15.6, 5.8); ctx.lineTo(9, 9.2); ctx.lineTo(2.4, 5.8); ctx.closePath(); ctx.stroke();
                poly([2.4, 9.2, 9, 12.6, 15.6, 9.2], false);
                poly([2.4, 12.4, 9, 15.8, 15.6, 12.4], false);
            } else if (k === "clipboard") {
                rrect(3.6, 3.4, 10.8, 12.6, 2); ctx.stroke();
                rrect(6.4, 1.9, 5.2, 3.4, 1.2); ctx.stroke();
                line(6.4, 9, 11.6, 9);
                line(6.4, 12, 10, 12);
            } else if (k === "smile") {
                circ(9, 9, 6.6); ctx.stroke();
                circ(6.7, 7.5, 0.95); ctx.fill();
                circ(11.3, 7.5, 0.95); ctx.fill();
                ctx.beginPath(); ctx.arc(9, 9.2, 3.7, 0.25, PI - 0.25, false); ctx.stroke();
            } else if (k === "doc") {
                ctx.beginPath(); ctx.moveTo(4.6, 2.2); ctx.lineTo(10.2, 2.2); ctx.lineTo(13.8, 5.8); ctx.lineTo(13.8, 15.8); ctx.lineTo(4.6, 15.8); ctx.closePath(); ctx.stroke();
                poly([10.2, 2.2, 10.2, 5.8, 13.8, 5.8], false);
                line(6.8, 9.6, 11.6, 9.6);
                line(6.8, 12.4, 11.6, 12.4);
            } else if (k === "link") {
                ctx.save(); ctx.translate(9, 9); ctx.rotate(-PI / 4);
                rrect(-7.2, -2.7, 8.2, 5.4, 2.7); ctx.stroke();
                rrect(-1, -2.7, 8.2, 5.4, 2.7); ctx.stroke();
                ctx.restore();
            } else if (k === "photo") {
                rrect(2.4, 3.4, 13.2, 11.2, 2.2); ctx.stroke();
                circ(6.4, 7.4, 1.3); ctx.fill();
                poly([3.2, 13.4, 7.6, 9.4, 10.4, 12, 12.4, 10.2, 14.8, 13.4], false);
            } else if (k === "return") {
                poly([14.5, 4, 14.5, 10, 4.5, 10], false);
                poly([7.5, 7, 4.5, 10, 7.5, 13], false);
            } else if (k === "dots") {
                circ(3.6, 9, 1.35); ctx.fill();
                circ(9, 9, 1.35); ctx.fill();
                circ(14.4, 9, 1.35); ctx.fill();
            } else if (k === "lock") {
                rrect(3.6, 8, 10.8, 7.8, 2); ctx.stroke();
                ctx.beginPath(); ctx.moveTo(6, 8); ctx.lineTo(6, 6); ctx.arc(9, 6, 3, PI, 0, false); ctx.lineTo(12, 8); ctx.stroke();
            } else if (k === "power") {
                ctx.beginPath(); ctx.arc(9, 9.6, 6, -PI / 2 + 0.65, -PI / 2 - 0.65 + PI * 2, false); ctx.stroke();
                line(9, 2.2, 9, 8.4);
            } else if (k === "restart") {
                ctx.beginPath(); ctx.arc(9, 9, 5.8, -1.0, 4.4, false); ctx.stroke();
                poly([9.7, 2.7, 6.6, 1.6, 7.8, 5.4], true);
            } else if (k === "logout") {
                poly([9, 3, 3.5, 3, 3.5, 15, 9, 15], false);
                line(7.5, 9, 15.5, 9);
                poly([12.5, 6, 15.5, 9, 12.5, 12], false);
            } else if (k === "contrast") {
                circ(9, 9, 6.5); ctx.stroke();
                ctx.beginPath(); ctx.arc(9, 9, 6.5, -PI / 2, PI / 2, false); ctx.closePath(); ctx.fill();
            } else if (k === "check") {
                poly([3.5, 9.5, 7.5, 13.5, 14.5, 4.5], false);
            } else if (k === "chevL") {
                poly([11, 3.5, 5.5, 9, 11, 14.5], false);
            } else if (k === "chevR") {
                poly([7, 3.5, 12.5, 9, 7, 14.5], false);
            } else if (k === "bell") {
                ctx.beginPath(); ctx.moveTo(3.4, 12.9);
                ctx.bezierCurveTo(4.6, 11.8, 5.0, 10.6, 5.0, 8.2);
                ctx.bezierCurveTo(5.0, 5.6, 6.8, 3.9, 9.0, 3.9);
                ctx.bezierCurveTo(11.2, 3.9, 13.0, 5.6, 13.0, 8.2);
                ctx.bezierCurveTo(13.0, 10.6, 13.4, 11.8, 14.6, 12.9);
                ctx.closePath(); ctx.stroke();
                line(9, 2.2, 9, 3.9);
                ctx.beginPath(); ctx.arc(9, 14.3, 1.7, 0.25, PI - 0.25); ctx.stroke();
            } else if (k === "close") {
                line(5, 5, 13, 13); line(13, 5, 5, 13);
            } else if (k === "dropper") {
                ctx.save(); ctx.translate(9, 9); ctx.rotate(-PI / 4);
                rrect(2.6, -2.9, 4.8, 5.8, 2); ctx.stroke();
                line(1.2, -2.9, 1.2, 2.9);
                ctx.beginPath(); ctx.moveTo(1.2, -1.3); ctx.lineTo(-4.8, -1.3); ctx.lineTo(-8, -0.3); ctx.lineTo(-8, 0.3); ctx.lineTo(-4.8, 1.3); ctx.lineTo(1.2, 1.3); ctx.stroke();
                ctx.restore();
            } else if (k === "gear") {
                circ(9, 9, 2.6); ctx.stroke();
                for (i2 = 0; i2 < 8; i2++) {
                    var g2 = i2 * PI / 4;
                    line(9 + Math.cos(g2) * 5.6, 9 + Math.sin(g2) * 5.6, 9 + Math.cos(g2) * 7.6, 9 + Math.sin(g2) * 7.6);
                }
                circ(9, 9, 5.6); ctx.stroke();
            } else if (k.indexOf("m_") === 0) {
                ctx.lineWidth = 1.4;
                var ell = function (cx, cy, rx, ry, fill) {
                    ctx.save(); ctx.translate(cx, cy); ctx.scale(rx, ry); ctx.beginPath(); ctx.arc(0, 0, 1, 0, PI * 2); ctx.restore();
                    if (fill) ctx.fill(); else ctx.stroke();
                };
                if (k === "m_about") {
                    ell(9, 9.2, 4.6, 6.6, false);
                    ctx.lineWidth = 1.1; ell(9, 11.6, 2.7, 3.5, false); ctx.lineWidth = 1.4;
                    circ(7.5, 6.2, 0.85); ctx.fill(); circ(10.5, 6.2, 0.85); ctx.fill();
                    poly([7.7, 7.6, 10.3, 7.6, 9, 9.1], true);
                    ell(6.1, 16.3, 2.1, 0.95, true); ell(11.9, 16.3, 2.1, 0.95, true);
                    line(4.5, 10, 3.1, 13.6); line(13.5, 10, 14.9, 13.6);
                } else if (k === "m_settings") {
                    circ(9, 9, 6.7); ctx.stroke();
                    ctx.beginPath(); ctx.arc(9, 9, 3.2, -PI / 2, PI / 2, false); ctx.closePath(); ctx.fill();
                    line(9, 5.6, 9, 12.4);
                } else if (k === "m_sleep") {
                    circ(9, 9, 6.7); ctx.stroke();
                    ctx.beginPath(); ctx.arc(9, 9, 6.7, 0, PI, false); ctx.closePath(); ctx.fill();
                } else if (k === "m_restart") {
                    ctx.lineWidth = 1.5;
                    poly([12.6, 3.6, 4.6, 9, 12.6, 14.4, 12.6, 3.6], false);
                } else if (k === "m_power") {
                    ctx.beginPath(); ctx.arc(9, 9.6, 5.8, -PI / 2 + 0.7, -PI / 2 - 0.7 + PI * 2, false); ctx.stroke();
                    line(9, 2.6, 9, 8.4);
                } else if (k === "m_lock") {
                    rrect(4, 8, 10, 7.6, 1.8); ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(6.4, 8); ctx.lineTo(6.4, 6.4); ctx.arc(9, 6.4, 2.6, PI, 0, false); ctx.lineTo(11.6, 8); ctx.stroke();
                    circ(9, 11.8, 1.1); ctx.fill();
                } else if (k === "m_logout") {
                    circ(9, 9, 6.7); ctx.stroke();
                    circ(9, 7.2, 1.9); ctx.fill();
                    ctx.beginPath(); ctx.arc(9, 14.4, 4.2, PI * 1.22, PI * 1.78, false); ctx.stroke();
                }
            }
        }
    }

    component LGlass: LiquidPane { accentTint: root.accentTintVec }

    component GlassCtx: QtObject {
        property var src: null
        property rect srcRect: Qt.rect(0, 0, 1, 1)
        property Item frame: null
        property bool liquid: false
        property url shaderUrl: ""
        property bool dark: true
        property real tint: 0.4
        property real strength: 1.0
        property real blur: 5
        property real blurMul: 1.0
        property real liquidMul: 1.0
        property real paneOpacity: 1.0
        property real rim: 0.45
        property real rimTint: 0
        property real ringW: 0
        property color borderTint: "#8A9AB5"
        property real borderAmount: 1
        property bool whiteEdge: true
        property real grain: 0.03
        property bool debug: false
        signal failed()
    }

    component PopGlassCtx: Item {
        id: pg
        required property Item pop
        required property Item frame
        required property var source
        property real fullW: pop.width
        property real fullH: pop.height
        property bool fromCC: false
        readonly property real topBarBlur: root.glassBlurEff
        property alias ctx: pgc
        readonly property real m: 64 * root.barPopupScale
        ShaderEffectSource {
            id: pgSrc
            sourceItem: pg.source
            hideSource: true
            live: pg.pop.visible
            visible: false
            sourceRect: Qt.rect(pg.pop.x - pg.m, pg.pop.y - pg.m, pg.fullW * root.barPopupScale + 2 * pg.m, pg.fullH * root.barPopupScale + 2 * pg.m)
        }
        MultiEffect {
            id: pgFx
            source: pgSrc
            width: pgSrc.sourceRect.width; height: pgSrc.sourceRect.height
            blurEnabled: true
            blurMax: 64
            blur: Math.min(1.0, (pgc.blur * pgc.blurMul) * 1.4 / 64.0)
            autoPaddingEnabled: false
            visible: false
        }
        ShaderEffectSource {
            id: pgBlur
            sourceItem: pgFx
            live: pg.pop.visible
            visible: false
        }
        GlassCtx {
            id: pgc
            src: pgBlur
            srcRect: pgSrc.sourceRect
            frame: pg.frame
            liquid: root.liquidActive
            shaderUrl: root.glassShaderUrl
            dark: root.effDark
            tint: root.glassOpacity
            strength: root.glassLiquidEff
            rim: root.glassRimEff
            rimTint: 1
            ringW: 0
            borderTint: root.menuBorderColor
            borderAmount: 1
            whiteEdge: false
            grain: root.glassGrain
            blur: pg.fromCC ? root.glassBlurEff : pg.topBarBlur
            debug: root.glassDebug
            onFailed: root.glassState = "failed"
        }
    }

    component GGlass: Item {
        id: gg
        required property var gx
        property real cornerR: 22
        property real thickness: 24
        property real strengthMul: 1.0
        property real tintMul: 1.0
        property real shadowAmt: 0.5
        property real flatInner: 0
        readonly property real pad: 10

        function framePos() {
            var px = 0, py = 0, it = gg;
            while (it && it !== gx.frame) { px += it.x; py += it.y; it = it.parent; }
            return Qt.point(px, py);
        }
        readonly property point fp: framePos()

        Rectangle {
            visible: !gg.gx.liquid
            anchors.fill: parent
            radius: gg.cornerR
            color: gg.gx.dark ? Qt.rgba(0.10, 0.10, 0.11, gg.gx.tint) : Qt.rgba(1, 1, 1, gg.gx.tint * 0.55)
            border.width: 1
            border.color: gg.gx.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.12)
            Rectangle {
                anchors.fill: parent
                visible: gg.gx.whiteEdge
                anchors.margins: 1
                radius: parent.radius - 1
                color: "transparent"
                border.width: 1
                border.color: gg.gx.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.45)
            }
        }
        Loader {
            anchors.fill: parent
            active: gg.gx.liquid && gg.gx.src !== null && gg.visible
            sourceComponent: Item {
                ShaderEffect {
                    x: -gg.pad; y: -gg.pad
                    width: gg.width + 2 * gg.pad
                    height: gg.height + 2 * gg.pad
                    fragmentShader: gg.gx.shaderUrl
                    onStatusChanged: if (status === ShaderEffect.Error) gg.gx.failed()
                    opacity: gg.gx.paneOpacity
                    property variant src: gg.gx.src
                    property vector2d itemSize: Qt.vector2d(width, height)
                    property vector2d glassSize: Qt.vector2d(gg.width, gg.height)
                    property vector2d srcSize: Qt.vector2d(gg.gx.srcRect.width, gg.gx.srcRect.height)
                    property vector2d srcOffset: Qt.vector2d(gg.fp.x - gg.pad - gg.gx.srcRect.x,
                                                             gg.fp.y - gg.pad - gg.gx.srcRect.y)
                    property real pad: gg.pad
                    property real radius: gg.cornerR
                    property real bezel: Math.min(gg.height * 0.36, 26)
                    property real thickness: gg.thickness * gg.gx.strength * gg.strengthMul * gg.gx.liquidMul * 1.6
                    property real dispersion: 0.06 * gg.gx.strength * gg.strengthMul * gg.gx.liquidMul * 1.3
                    property real magnify: 0.05 * gg.gx.strength * gg.strengthMul * gg.gx.liquidMul * 1.6
                    property real rim: gg.gx.rim
                    property real grain: gg.gx.grain * 0.2
                    property real blurPx: 1.5
                    property real tintMix: gg.gx.tint * 0.55 * gg.tintMul
                    property vector4d accentTint: root.accentTintVec
                    property real saturation: 1.25
                    property real dark: gg.gx.dark ? 1 : 0
                    property real debug: gg.gx.debug ? 1 : 0
                    property real shadowAmt: gg.shadowAmt
                    property real flatInner: gg.flatInner
                    property real rimTint: gg.gx.rimTint
                    property real ringW: gg.gx.ringW
                }
            }
        }
    }

    component CCTile: Item {
        id: tile
        required property var t
        required property var gx
        property real radius: 34
        property bool on: false
        property string onTint: ""
        property bool clickable: false
        readonly property bool whole: on && width <= 110
        readonly property color fg: whole ? root.ccOnInk : t.fg
        readonly property color fg2: whole ? Qt.rgba(root.ccOnInk.r, root.ccOnInk.g, root.ccOnInk.b, 0.55) : t.fg2
        signal clicked()
        scale: (clickable && tma.pressed) ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
        GGlass { anchors.fill: parent; gx: tile.gx; cornerR: tile.radius; thickness: 22; shadowAmt: 0; flatInner: 1 }
        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            color: root.ccOnFill
            opacity: tile.whole ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            color: (tile.clickable && tma.containsMouse) ? (tile.t.dark ? Qt.rgba(1, 1, 1, 0.025) : Qt.rgba(1, 1, 1, 0.07)) : Qt.rgba(1, 1, 1, 0)
            Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        CornerBorder { z: 2; anchors.fill: parent; cornerR: tile.radius; dark: tile.gx.dark; tint: tile.gx.borderTint; amount: tile.gx.borderAmount; lineW: 0.8 }
        MouseArea { id: tma; anchors.fill: parent; enabled: tile.clickable; hoverEnabled: true; onClicked: tile.clicked() }
    }

    component CCPill: Item {
        id: pl
        required property var t
        required property var gx
        property string text: ""
        property bool strong: false
        signal clicked()
        width: plText.implicitWidth + 32; height: 28
        GGlass { anchors.fill: parent; gx: pl.gx; cornerR: 14; thickness: 14; strengthMul: 0.6; shadowAmt: 0; flatInner: 1 }
        CornerBorder { z: 2; anchors.fill: parent; cornerR: 14; dark: pl.gx.dark; tint: pl.gx.borderTint; amount: pl.gx.borderAmount; lineW: 0.8 }
        Rectangle {
            anchors.fill: parent; radius: 14
            color: pla.containsMouse ? (pl.t.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.09)) : Qt.rgba(1, 1, 1, 0)
        }
        Text {
            id: plText
            anchors.centerIn: parent
            text: pl.text
            color: pl.t.fg; font.family: root.fontForWeight(pl.strong ? Font.DemiBold : Font.Normal, pl.t.fam); font.pixelSize: 12
            font.weight: pl.strong ? Font.DemiBold : Font.Normal
        }
        MouseArea { id: pla; anchors.fill: parent; hoverEnabled: true; onClicked: pl.clicked() }
    }

    component ContourGlow: ShaderEffect {
        id: cgl
        property real cornerR: 24
        property bool hovered: false
        property point at: Qt.point(width / 2, height / 2)
        property real pad: 14
        property color glowColor: "white"
        anchors.fill: parent
        anchors.margins: -pad
        fragmentShader: Qt.resolvedUrl("contourglow.frag.qsb")
        property vector2d itemSize: Qt.vector2d(width, height)
        property vector2d mouse: Qt.vector2d(at.x, at.y)
        property real cornerRadius: cornerR
        property real amount: hovered ? 1 : 0
        Behavior on amount { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        property real spread: Math.max(40, Math.min(width, height) * 0.9)
        property vector4d tint: Qt.vector4d(glowColor.r, glowColor.g, glowColor.b, 1)
        visible: amount > 0.005
    }

    component CCBtn: Item {
        id: b
        required property var t
        required property var gx
        property string kind: ""
        property bool on: false
        property real level: 3
        property bool flag: false
        property string onTint: ""
        property real d: 40
        property real shadow: 0
        signal clicked()
        property bool bounce: false
        property bool glass: true
        property bool matchMenuBorder: false
        property bool plain: false
        readonly property bool inWide: plain && parent && parent.width > 110
        readonly property bool circleBtn: plain && parent && parent.width <= 110
        width: circleBtn ? 21 : d; height: width
        scale: (bounce && bma.pressed) ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 230; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
        GGlass { visible: !b.plain && b.glass; anchors.fill: parent; gx: b.gx; cornerR: b.d / 2; thickness: 14; strengthMul: 0.6; shadowAmt: 0; flatInner: 1 }
        CornerBorder { visible: !b.plain && b.glass && !b.matchMenuBorder; z: 2; anchors.fill: parent; cornerR: b.d / 2; dark: b.gx.dark; tint: b.gx.borderTint; amount: b.gx.borderAmount; lineW: 0.8 }
        MenuBorder { visible: !b.plain && b.glass && b.matchMenuBorder; z: 2; anchors.fill: parent; cornerR: b.d / 2; dark: root.panelDarkMode; tint: root.menuBorderColor; amount: 0.5 }
        Rectangle {
            anchors.fill: parent
            radius: b.width / 2
            color: b.on ? (b.plain ? root.ccOnFill : "white")
                        : (b.plain ? (b.inWide ? (b.t.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14))
                                               : Qt.rgba(1, 1, 1, 0))
                                   : (!b.glass ? (b.t.dark ? Qt.rgba(1, 1, 1, bma.containsMouse ? 0.22 : 0.16) : Qt.rgba(0, 0, 0, bma.containsMouse ? 0.18 : 0.14))
                                               : (bma.containsMouse ? (b.t.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.09)) : Qt.rgba(1, 1, 1, 0))))
            Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        property real pop: 0
        onOnChanged: popAnim.restart()
        SequentialAnimation {
            id: popAnim
            NumberAnimation { target: b; property: "pop"; to: 1; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { target: b; property: "pop"; to: 0; duration: 420; easing.type: Easing.OutQuint }
        }
        Glyph {
            scale: 1 - 0.22 * b.pop
            rotation: (b.on ? -14 : 14) * b.pop
            anchors.centerIn: parent
            width: b.circleBtn ? 23 : b.width * 0.46; height: width
            kind: b.kind; level: b.level; flag: b.flag
            color: b.on ? ((b.plain && root.ccOnColor !== "") ? root.ccOnInk : (b.onTint !== "" ? Qt.color(b.onTint) : b.t.accent)) : b.t.ink
            Behavior on color { ColorAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
        MouseArea { id: bma; anchors.fill: parent; enabled: !b.plain; hoverEnabled: true; onClicked: b.clicked() }
    }

    component CCSimpleTile: CCTile {
        id: stl
        property string kind: ""
        property string title: ""
        property string status: ""
        property string tint: ""
        property bool flag: false
        readonly property bool wide: width > 110
        CCBtn {
            plain: true
            t: stl.t; gx: stl.gx
            x: stl.wide ? 12 : (stl.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            kind: stl.kind; flag: stl.flag; on: stl.on; onTint: stl.tint
        }
        Column {
            visible: stl.wide
            x: 60; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 60 - 8
            spacing: 1
            Text { width: parent.width; elide: Text.ElideRight; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 10; text: stl.title; color: stl.fg; font.family: root.fontForWeight(Font.DemiBold, stl.t.fam); font.pixelSize: 13; font.weight: Font.DemiBold }
            MorphText { visible: stl.status !== ""; animateWidth: false; duration: 420; width: parent.width; elide: Text.ElideRight; text: stl.status; color: stl.fg2; font.family: root.fontForWeight(Font.Normal, stl.t.fam); font.pixelSize: 12 }
        }
    }

    component CCSlider: Item {
        id: s
        required property var t
        property real value: 0
        property string leftKind: "sun"
        property string rightKind: "sun"
        property real leftLevel: 1
        property real rightLevel: 3
        property var gx: null
        property real glassMul: 1.0
        signal moved(real v)
        height: 28
        property bool tileHover: false
        readonly property bool hovering: sma.containsMouse || sma.pressed || tileHover
        property real hoverT: hovering ? 1 : 0
        Behavior on hoverT { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
        property real pressT: sma.pressed ? 1 : 0
        Behavior on pressT { NumberAnimation { duration: sma.pressed ? 420 : 300; easing.type: Easing.OutBack; easing.overshoot: 3.0 } }
        readonly property real trackX: 28
        readonly property real trackW: Math.max(1, s.width - 28 - 26)
        property real vel: 0
        property real jig: 0
        property real lastV: value
        property real lastT: 0
        Behavior on jig { SpringAnimation { spring: 3.4; damping: 0.2; epsilon: 0.004 } }
        onValueChanged: {
            var now = Date.now();
            if (lastT > 0) {
                var dt = Math.max(1, now - lastT);
                vel = vel * 0.45 + ((value - lastV) * trackW / dt) * 0.55;
                jig = Math.max(-1.5, Math.min(1.5, vel * 0.6));
            }
            lastV = value; lastT = now;
            jigIdle.restart();
        }
        Timer { id: jigIdle; interval: 70; onTriggered: { s.vel = 0; s.jig = 0; } }
        Glyph {
            x: 4; anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            kind: s.leftKind; level: s.leftLevel
            color: s.t.ink
        }
        Rectangle {
            x: s.trackX; width: s.trackW; height: 4; radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: s.t.track
        }
        Rectangle {
            x: s.trackX
            width: Math.max(0, Math.min(1, s.value)) * s.trackW
            height: 4; radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: s.t.ink
        }
        Glyph {
            x: s.width - 20; anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            kind: s.rightKind; level: s.rightLevel
            color: s.t.ink2
        }
        Item {
            id: knob
            readonly property real kw: 21 + 6 * s.pressT
            readonly property real kh: 14 + 3 * s.pressT
            width: Math.max(1, kw); height: Math.max(1, kh)
            x: s.trackX + Math.max(0, Math.min(1, s.value)) * s.trackW - width / 2 - s.jig * 3
            anchors.verticalCenter: parent.verticalCenter
            visible: s.hoverT > 0.01
            opacity: Math.min(1, s.hoverT * 1.6)
            scale: 0.5 + 0.5 * s.hoverT
            rotation: s.jig * 7
            transform: Scale {
                origin.x: knob.width / 2; origin.y: knob.height / 2
                xScale: 1 + 0.32 * Math.min(1.5, Math.abs(s.jig))
                yScale: 1 - 0.16 * Math.min(1.5, Math.abs(s.jig))
            }
            readonly property real rad: Math.max(2, Math.min(height / 2, 8 + 3 * s.pressT))
            Rectangle {
                anchors.fill: parent
                radius: knob.rad
                color: s.t.fg
                opacity: s.gx ? Math.max(0, 1 - s.pressT * 1.4) : 1
            }
            Loader {
                anchors.fill: parent
                active: s.gx !== null && s.pressT > 0.02
                opacity: Math.min(1, s.pressT * 1.6)
                sourceComponent: Item {
                    GGlass { anchors.fill: parent; gx: s.gx; cornerR: knob.rad; thickness: 16; strengthMul: s.glassMul * 0.85; shadowAmt: 0.5 }
                    Item {
                        anchors.fill: parent
                        clip: true
                        Rectangle {
                            x: s.trackX - knob.x; width: s.trackW; height: 4; radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(s.t.fg.r, s.t.fg.g, s.t.fg.b, 0.35)
                        }
                        Rectangle {
                            x: s.trackX - knob.x
                            width: Math.max(0, Math.min(1, s.value)) * s.trackW
                            height: 4; radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(s.t.fg.r, s.t.fg.g, s.t.fg.b, 0.9)
                        }
                    }
                    CornerBorder { z: 2; anchors.fill: parent; cornerR: knob.rad; dark: s.gx.dark; tint: s.gx.borderTint; amount: s.gx.borderAmount; lineW: 0.8 }
                    Rectangle {
                        anchors.fill: parent
                        radius: knob.rad
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, s.t.dark ? 0.12 : 0.2) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.02) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, s.t.dark ? 0.04 : 0.08) }
                        }
                    }
                }
            }
        }
        MouseArea {
            id: sma
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            function setFrom(mx) { s.moved(Math.max(0, Math.min(1, (mx - s.trackX) / s.trackW))); }
            onPressed: mouse => setFrom(mouse.x)
            onPositionChanged: mouse => { if (pressed) setFrom(mouse.x); }
        }
    }

    component AudioRow: Item {
        id: ar
        required property var t
        property string title: ""
        property string sub: ""
        property string kind: "speaker"
        property bool selected: false
        signal clicked()
        width: parent ? parent.width : 300
        height: 46
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: ar.t.hover
            opacity: arMa.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }
        Rectangle {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 16
            color: ar.selected ? ar.t.accent : ar.t.btnOff
            Behavior on color { ColorAnimation { duration: 120 } }
            Glyph { anchors.centerIn: parent; width: 16; height: 16; kind: ar.kind; level: 3; color: ar.selected ? "white" : ar.t.fg }
        }
        Column {
            x: 50
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 50 - 14
            spacing: 1
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: ar.title
                color: ar.t.fg
                font.family: root.fontForWeight(ar.selected ? Font.DemiBold : Font.Normal, ar.t.fam); font.pixelSize: 13
                font.weight: ar.selected ? Font.DemiBold : Font.Normal
            }
            Text {
                visible: ar.sub !== ""
                width: parent.width
                elide: Text.ElideRight
                text: ar.sub
                color: ar.t.fg2
                font.family: root.fontForWeight(Font.Normal, ar.t.fam); font.pixelSize: 11
            }
        }
        MouseArea { id: arMa; anchors.fill: parent; hoverEnabled: true; onClicked: ar.clicked() }
    }

    component NotifBody: Item {
        id: nb
        required property var t
        property string app: ""
        property string summary: ""
        property string body: ""
        property string icon: ""
        property int urgency: 1
        property real stamp: 0
        property real nowMs: 0
        property bool showClose: false
        property bool showTime: false
        signal closeClicked()
        width: parent ? parent.width : 340
        height: Math.max(74, textCol.height + 30)

        readonly property string agoText: {
            var m = Math.floor((nb.nowMs - nb.stamp) / 60000);
            return m < 1 ? I18n.tr("now") : (m < 60 ? m + I18n.tr("m ago") : (m < 1440 ? Math.floor(m / 60) + I18n.tr("h ago") : Math.floor(m / 1440) + I18n.tr("d ago")));
        }

        Item {
            x: 14; y: 15; width: 44; height: 44
            Rectangle {
                anchors.fill: parent; radius: 10
                visible: nimg.status !== Image.Ready
                color: nb.t.accent
                Glyph { anchors.centerIn: parent; width: 24; height: 24; kind: "bell"; color: "white" }
            }
            Image {
                id: nimg
                anchors.fill: parent
                visible: status === Image.Ready
                source: nb.icon
                sourceSize.width: 96; sourceSize.height: 96
                fillMode: Image.PreserveAspectFit
                asynchronous: true; smooth: true
            }
        }
        Column {
            id: textCol
            property real refocus: 0
            layer.enabled: refocus > 0.001
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: textCol.refocus; autoPaddingEnabled: true }
            opacity: 1 - 0.5 * refocus
            NumberAnimation { id: refocusAnim; target: textCol; property: "refocus"; from: 1; to: 0; duration: 460; easing.type: Easing.OutQuint }
            Connections {
                target: nb
                function onSummaryChanged() { refocusAnim.restart(); }
                function onBodyChanged() { refocusAnim.restart(); }
            }
            x: 70; y: 14
            width: parent.width - 70 - 44
            spacing: 1
            Text {
                width: parent.width
                text: nb.urgency === 2 ? I18n.tr("TIME SENSITIVE") : nb.app
                horizontalAlignment: /[\u0590-\u08ff]/.test(text) ? Text.AlignRight : Text.AlignLeft
                visible: text !== ""
                color: nb.urgency === 2 ? nb.t.fg2 : nb.t.fg
                font.family: root.fontForWeight(Font.DemiBold, nb.t.fam); font.pixelSize: nb.urgency === 2 ? 12 : 14
                font.weight: Font.DemiBold
                font.letterSpacing: nb.urgency === 2 ? 0.4 : 0
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: nb.summary
                horizontalAlignment: /[\u0590-\u08ff]/.test(text) ? Text.AlignRight : Text.AlignLeft
                visible: text !== ""
                color: nb.t.fg
                font.family: root.fontForWeight(Font.Bold, nb.t.fam); font.pixelSize: 14; font.weight: Font.Bold
                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: nb.body
                horizontalAlignment: /[\u0590-\u08ff]/.test(text) ? Text.AlignRight : Text.AlignLeft
                visible: text !== ""
                color: nb.t.fg
                font.family: root.fontForWeight(Font.Normal, nb.t.fam); font.pixelSize: 13
                wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
            }
        }
        Text {
            visible: nb.showTime && !nb.showClose
            anchors.right: parent.right; anchors.rightMargin: 14
            y: 15
            text: nb.agoText
            color: nb.t.fg2
            font.family: root.fontForWeight(Font.Normal, nb.t.fam); font.pixelSize: 12
        }
        Rectangle {
            id: xbtn
            visible: nb.showClose
            anchors.right: parent.right; anchors.rightMargin: 10
            y: 10
            width: 22; height: 22; radius: 11
            color: xma.containsMouse ? nb.t.btnHover : nb.t.btnOff
            Glyph { anchors.centerIn: parent; width: 12; height: 12; kind: "close"; color: nb.t.fg }
            MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: nb.closeClicked() }
        }
    }

    component PRow: Item {
        id: r
        required property var t
        property string title: ""
        default property alias control: slot.data
        width: parent ? parent.width : 0
        height: 42
        Rectangle { visible: r.y > 0.5; x: 14; width: parent.width - 14; height: 1; color: r.t.sep }
        Text {
            x: 14; anchors.verticalCenter: parent.verticalCenter
            text: r.title; color: r.t.fg
            font.family: root.fontForWeight(Font.Normal, r.t.fam); font.pixelSize: 13
        }
        Item {
            id: slot
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width; height: childrenRect.height
        }
    }
    component PCard: Rectangle {
        required property var t
        default property alias content: pcol.data
        width: parent ? parent.width : 0
        height: pcol.implicitHeight
        radius: 10
        color: t.card
        border.width: 1
        border.color: t.cardBorder
        Column { id: pcol; width: parent.width }
    }
    component PSwitch: GlassSwitch {
        required property var t
        accentColor: root.accent
        offColor: t.switchOff
        dark: t.dark
        baseColor: t.dark ? "#2B2B2D" : "#FFFFFF"
        glass: root.liquidActive
        shaderUrl: root.glassShaderUrl
        glassLiquid: root.glassLiquidEff
        glassRim: root.glassRimEff
        glassGrain: root.glassGrain
        glassTint: root.glassOpacity
        borderTint: root.menuBorderColor
        onGlassFailed: root.glassState = "failed"
    }
    component PSlider: GlassSlider {
        required property var t
        decimals: 2
        width: 190
        fg: t.fg
        trackColor: t.track
        labelColor: t.fg2
        fontFamily: t.fam
        dark: t.dark
        baseColor: t.dark ? "#2B2B2D" : "#FFFFFF"
        glass: root.liquidActive
        shaderUrl: root.glassShaderUrl
        glassLiquid: root.glassLiquidEff
        glassRim: root.glassRimEff
        glassGrain: root.glassGrain
        glassTint: root.glassOpacity
        borderTint: root.menuBorderColor
        onGlassFailed: root.glassState = "failed"
    }
    component PSeg: Item {
        id: sg
        required property var t
        property var model: []
        property int current: 0
        property real segWidth: 100
        signal picked(int index)
        width: model.length * segWidth + 4; height: 26
        Rectangle { anchors.fill: parent; radius: 7; color: sg.t.btnOff }
        Rectangle {
            y: 2; x: 2 + sg.current * sg.segWidth; width: sg.segWidth; height: parent.height - 4; radius: 5
            color: sg.t.dark ? "#636366" : "#FFFFFF"
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
        Row {
            x: 2; y: 2
            Repeater {
                model: sg.model
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: sg.segWidth; height: sg.height - 4
                    Text {
                        anchors.centerIn: parent; text: I18n.tr(parent.modelData)
                        color: sg.t.fg
                        font.family: root.fontForWeight(Font.Normal, sg.t.fam); font.pixelSize: 12
                    }
                    MouseArea { anchors.fill: parent; onClicked: sg.picked(parent.index) }
                }
            }
        }
    }

    SystemClock { id: clock; precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }

    readonly property string clockText: {
        var d = clock.date;
        var tf = root.use24h ? (root.showSeconds ? "HH:mm:ss" : "HH:mm") : (root.showSeconds ? "h:mm:ss AP" : "h:mm AP");
        var t = Qt.formatDateTime(d, tf);
        return root.showDate ? I18n.locale().toString(d, "ddd d MMM") + "  " + t : t;
    }

    function lookup(appId) {
        if (!appId) return null;
        var e = (root.hub && root.hub.steamEntry(appId)) || DesktopEntries.byId(appId);
        if (!e && DesktopEntries.heuristicLookup) e = DesktopEntries.heuristicLookup(appId);
        return e;
    }
    readonly property bool desktopFocused: hub ? hub.desktopFocused === true : false
    readonly property var activeTl: desktopFocused ? null : ToplevelManager.activeToplevel
    readonly property string activeAppId: activeTl ? (activeTl.appId || "") : ""
    readonly property string appName: {
        if (activeAppId === "") return I18n.tr("Desktop");
        if (activeAppId === "org.quickshell") return (activeTl.title === "Clock" || activeTl.title === "App Store") ? I18n.tr(activeTl.title)
                                                     : (activeTl.title === "YukiShell Settings" ? I18n.tr("System Settings") : "YukiShell");
        var e = lookup(activeAppId);
        return e ? e.name : activeAppId;
    }
    property var activeWin: null
    function refreshActive() { if (!awProc.running) awProc.running = true; }
    onActiveTlChanged: { refreshActive(); swTrack(); }
    Process {
        id: awProc
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                var o = null;
                try { o = JSON.parse(text); } catch (err) { o = null; }
                root.activeWin = (o && o.address) ? o : null;
            }
        }
    }
    readonly property var menuTitles: [
        { id: "apple", label: "" },
        { id: "app", label: appName, bold: true },
        { id: "file", label: I18n.tr("File") },
        { id: "edit", label: I18n.tr("Edit") },
        { id: "view", label: I18n.tr("View") },
        { id: "window", label: I18n.tr("Window") }
    ]

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.sink] }
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false
    property bool osdReady: false
    property bool osdVisible: false
    property string osdKind: "volume"
    property real osdValue: 0
    property real osdQuietVolUntil: 0
    property real osdQuietBrightUntil: 0
    function osdQuiet(kind, ms) {
        var t = Date.now() + ms;
        if (kind === "brightness") osdQuietBrightUntil = Math.max(osdQuietBrightUntil, t);
        else osdQuietVolUntil = Math.max(osdQuietVolUntil, t);
    }
    readonly property string soundDir: Quickshell.env("HOME") + "/.local/share/sounds/yukishell"
    property var soundLast: ({})
    function playSound(name, vol) {
        if (!uiSounds || gaming) return;
        var now = Date.now(), last = soundLast[name] || 0;
        if (now - last < 90) return;
        soundLast[name] = now;
        Quickshell.execDetached(["pw-play", "--volume=" + ((vol === undefined ? 0.8 : vol) * uiSoundVolume).toFixed(3), soundDir + "/" + name + ".wav"]);
    }
    onChargingChanged: if (charging && osdReady) playSound("charge")
    function showOsd(kind, value) {
        if (!osdReady) return;
        if (Date.now() < (kind === "brightness" ? osdQuietBrightUntil : osdQuietVolUntil)) return;
        if (kind === "volume") playSound("pop", 0.55 + 0.45 * Math.max(0, Math.min(1, value)));
        osdKind = kind;
        osdValue = Math.max(0, Math.min(1, value));
        osdVisible = true;
        osdTimer.restart();
    }
    onVolumeChanged: showOsd("volume", muted ? 0 : volume)
    onMutedChanged: showOsd("volume", muted ? 0 : volume)
    Timer { id: osdTimer; interval: 1500; onTriggered: root.osdVisible = false }
    Timer { interval: 1200; running: true; repeat: false; onTriggered: root.osdReady = true }
    function setVolume(v) { osdQuiet("volume", 600); if (sink && sink.audio) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, v)); } }
    function toggleMute() { osdQuiet("volume", 600); if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }
    readonly property var micSource: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.micSource] }
    readonly property bool micMuted: (micSource && micSource.audio) ? micSource.audio.muted : true
    property string powerProfile: "balanced"
    Process { id: ppGetBar; command: ["powerprofilesctl", "get"]; stdout: StdioCollector { onStreamFinished: { var v = text.trim(); if (v !== "") root.powerProfile = v; } } }
    function refreshPowerProfile() { if (!ppGetBar.running) ppGetBar.running = true; }
    function cyclePowerProfile() {
        var order = ["power-saver", "balanced", "performance"], nx = order[(Math.max(0, order.indexOf(powerProfile)) + 1) % order.length];
        powerProfile = nx;
        Quickshell.execDetached(["powerprofilesctl", "set", nx]);
    }
    function toggleMicMute() { if (micSource && micSource.audio) micSource.audio.muted = !micSource.audio.muted; }
    readonly property real volLevel: muted || volume <= 0.001 ? 0 : (volume < 0.34 ? 1 : (volume < 0.67 ? 2 : 3))
    readonly property real micVolume: (micSource && micSource.audio) ? micSource.audio.volume : 0
    function setMicVolume(v) { if (micSource && micSource.audio) { micSource.audio.muted = false; micSource.audio.volume = Math.max(0, Math.min(1, v)); } }

    PwObjectTracker { objects: Pipewire.nodes.values }
    function audioDevices(wantOutput) {
        var ns = Pipewire.nodes.values, out = [];
        for (var i = 0; i < ns.length; i++) {
            var n = ns[i];
            if (!n || !n.audio || n.isStream) continue;
            var isOut = n.type !== undefined ? ((n.type & PwNodeType.Sink) !== 0 && (n.type & PwNodeType.Source) === 0) : n.isSink;
            var isIn = n.type !== undefined ? ((n.type & PwNodeType.Source) !== 0 && (n.type & PwNodeType.Sink) === 0) : !n.isSink;
            if (wantOutput ? isOut : isIn) out.push(n);
        }
        out.sort(function (a, b) { return String(a.description || a.name).localeCompare(String(b.description || b.name)); });
        return out;
    }
    property int audioTick: 0
    function audioApps() {
        var tick = audioTick, ns = Pipewire.nodes.values, groups = {}, out = [];
        for (var i = 0; i < ns.length; i++) {
            var n = ns[i];
            if (!n || !n.audio || !n.isStream) continue;
            var playback = n.type !== undefined ? ((n.type & PwNodeType.AudioOutStream) !== 0) : !n.isSink;
            if (!playback) continue;
            var p = n.properties || {};
            var name = String(p["application.name"] || p["node.description"] || n.description || p["application.process.binary"] || p["node.name"] || n.name || "App");
            if (name.toLowerCase() === "peak detect") continue;
            var key = String(p["application.id"] || p["application.process.binary"] || name).toLowerCase();
            if (!groups[key]) groups[key] = { key: key, name: name, nodes: [], volume: 0, muted: true };
            var g = groups[key];
            g.nodes.push(n);
            g.volume += Math.max(0, Math.min(1, Number(n.audio.volume) || 0));
            g.muted = g.muted && !!n.audio.muted;
        }
        for (var k in groups) {
            var g = groups[k];
            g.volume /= Math.max(1, g.nodes.length);
            out.push(g);
        }
        out.sort(function (a, b) { return a.name.localeCompare(b.name); });
        return out;
    }
    readonly property var appAudioStreams: audioApps()
    property var appAudioKeys: []
    function syncAppKeys() {
        var k = [], l = appAudioStreams;
        for (var i = 0; i < l.length; i++) k.push(l[i].key);
        if (JSON.stringify(k) !== JSON.stringify(appAudioKeys)) appAudioKeys = k;
    }
    onAppAudioStreamsChanged: syncAppKeys()
    function appByKey(key) {
        var l = appAudioStreams;
        for (var i = 0; i < l.length; i++) if (l[i].key === key) return l[i];
        return null;
    }
    function setAppVolume(app, v) {
        if (!app || !app.nodes) return;
        osdQuiet("volume", 600);
        var value = Math.max(0, Math.min(1, v));
        for (var i = 0; i < app.nodes.length; i++) {
            var n = app.nodes[i];
            if (n && n.audio) { n.audio.muted = false; n.audio.volume = value; }
        }
    }
    readonly property var audioOutputs: audioDevices(true)
    readonly property var audioInputs: audioDevices(false)
    function audioKind(n, isOut) {
        if (!isOut) return "mic";
        var p = n.properties || {}, f = String(p["device.form-factor"] || "").toLowerCase();
        var t = (String(n.description) + " " + String(n.name)).toLowerCase();
        if (f === "headphone" || f === "headset" || /headphone|headset|airpods|buds|bluez/.test(t)) return "headphones";
        if (f === "hdmi" || f === "tv" || f === "monitor" || /hdmi|displayport|display port/.test(t)) return "monitor";
        return "speaker";
    }
    function audioSplit(d) {
        d = String(d || "");
        var m = /^(.*?)\s+((?:Analog|Digital|Pro|Stereo|Mono|Speaker|Headphones|Headset|Microphone|Line|HDMI|DisplayPort|S\/PDIF|Surround)\b.*)$/i.exec(d);
        return (m && m[1].length > 2) ? [m[1], m[2]] : [d, ""];
    }
    function chooseAudio(n) {
        if (!n) return;
        osdQuiet("volume", 1500);
        Quickshell.execDetached(["sh", "-c", "wpctl set-default \"$1\" 2>/dev/null || pactl \"$3\" \"$2\"", "sh", String(n.id), String(n.name),
                                 (n.type !== undefined ? ((n.type & PwNodeType.Sink) !== 0) : n.isSink) ? "set-default-sink" : "set-default-source"]);
    }

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBattery: bat !== null && bat !== undefined && bat.isPresent
    readonly property real batPct: {
        if (!hasBattery) return 0;
        var p = bat.percentage;
        return Math.round(p <= 1.0 ? p * 100 : p);
    }
    readonly property bool charging: hasBattery && (bat.state === UPowerDeviceState.Charging
                                                     || bat.state === UPowerDeviceState.FullyCharged)

    PlayerPicker { id: playerPick }
    readonly property var player: playerPick.player

    property bool wifiOn: true
    property bool hasWifi: true
    property bool hasBt: true
    property string wifiSsid: ""
    property int wifiSignal: 0
    property bool ethernetUp: false
    readonly property bool showEthernet: ethernetUp && wifiSsid === ""
    readonly property int wifiLevel: !wifiOn ? 0 : (wifiSsid === "" ? 0 : (wifiSignal > 66 ? 3 : (wifiSignal > 33 ? 2 : 1)))
    function refreshWifi() { if (!wifiProc.running) wifiProc.running = true; }
    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli radio wifi 2>/dev/null; nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -n1; echo; nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected$' && echo eth || echo -; { [ -n \"$(ls /sys/class/ieee80211 2>/dev/null)\" ] || nmcli -t -f TYPE dev 2>/dev/null | grep -qx wifi; } && echo hw || echo nohw"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                root.hasWifi = !l.some(function (x) { return x.trim() === "nohw"; });
                root.wifiOn = root.hasWifi && (l[0] || "").trim() === "enabled";
                root.ethernetUp = l.some(function (x) { return x.trim() === "eth"; });
                var a = (l[1] || "").trim();
                if (a !== "") {
                    var parts = a.split(":");
                    root.wifiSignal = parseInt(parts[parts.length - 1]) || 0;
                    root.wifiSsid = parts.slice(1, parts.length - 1).join(":").replace(/\\/g, "");
                } else { root.wifiSsid = ""; root.wifiSignal = 0; }
            }
        }
    }
    function toggleWifi() {
        if (!root.hasWifi) return;
        root.wifiOn = !root.wifiOn;
        Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "on" : "off"]);
        settleTimer.restart();
    }

    property var wifiNets: []
    property bool wifiScanning: false
    property string wifiBusy: ""
    property string wifiError: ""
    function sigLevel(s) { return s > 66 ? 3 : (s > 33 ? 2 : 1); }
    function splitNm(line) {
        var out = [], cur = "";
        for (var i = 0; i < line.length; i++) {
            var c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; }
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }
    function nmErr(t) {
        var s = (t || "").trim().split("\n")[0].replace(/^Error:\s*/, "");
        if (/secrets were required|no secrets|password/i.test(s)) return I18n.tr("Incorrect password.");
        if (/no network with ssid|not found/i.test(s)) return I18n.tr("Network not found.");
        return s !== "" ? s : I18n.tr("Couldn't join the network.");
    }
    function scanWifi() {
        if (wifiListProc.running || !hasWifi) return;
        wifiScanning = true;
        wifiListProc.running = true;
    }
    Process {
        id: wifiListProc
        command: ["sh", "-c",
            "nmcli dev wifi rescan >/dev/null 2>&1; "
            + "nmcli -t -f NAME,TYPE connection show 2>/dev/null | sed -n 's/:802-11-wireless$//p' | sed 's/^/S:/'; "
            + "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null | sed 's/^/N:/'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n"), saved = {}, best = {}, i, f;
                for (i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("S:") === 0) saved[root.splitNm(lines[i].substring(2))[0]] = true;
                }
                for (i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("N:") !== 0) continue;
                    f = root.splitNm(lines[i].substring(2));
                    if (f.length < 4 || f[1] === "") continue;
                    var ssid = f[1], sig = parseInt(f[2]) || 0, sec = f[3];
                    var n = { ssid: ssid, signal: sig, secure: (sec !== "" && sec !== "--"),
                              inUse: f[0] === "*", saved: saved[ssid] === true };
                    var o = best[ssid];
                    if (!o) best[ssid] = n;
                    else {
                        if (n.signal > o.signal) o.signal = n.signal;
                        if (n.inUse) o.inUse = true;
                    }
                }
                var arr = [];
                for (var k in best) arr.push(best[k]);
                arr.sort(function (a, b) {
                    if (a.inUse !== b.inUse) return a.inUse ? -1 : 1;
                    return b.signal - a.signal;
                });
                if (JSON.stringify(arr) !== JSON.stringify(root.wifiNets)) root.wifiNets = arr;
                root.wifiScanning = false;
            }
        }
        onExited: root.wifiScanning = false
    }
    function connectWifi(ssid, pw) {
        if (!hasWifi) return;
        if (wifiConnProc.running) return;
        wifiError = "";
        wifiBusy = ssid;
        var cmd = ["nmcli", "--wait", "25", "dev", "wifi", "connect", ssid];
        if (pw && pw !== "") { cmd.push("password"); cmd.push(pw); }
        wifiConnProc.command = cmd;
        wifiConnProc.running = true;
    }
    Process {
        id: wifiConnProc
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") root.wifiError = root.nmErr(text) }
        onExited: (code, status) => {
            root.wifiBusy = "";
            if (code !== 0 && root.wifiError === "") root.wifiError = I18n.tr("Couldn't join the network.");
            if (code === 0) root.wifiError = "";
            wifiAfter.restart();
        }
    }
    function disconnectWifi() {
        sh("nmcli -t -f DEVICE,TYPE dev | grep ':wifi$' | cut -d: -f1 | head -n1 | xargs -r nmcli dev disconnect");
        wifiAfter.restart();
    }
    Timer { id: wifiAfter; interval: 1200; onTriggered: { root.scanWifi(); root.refreshWifi(); root.refreshConnections(); } }
    function refreshConnections() { if (!connProc.running) connProc.running = true; }
    Process {
        id: connProc
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,DEVICE connection show 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [], lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue;
                    var f = root.splitNm(lines[i]);
                    if (f.length < 3) continue;
                    var type = f[1];
                    if (type !== "vpn" && type !== "802-3-ethernet") continue;
                    rows.push({ name: f[0], type: type, device: f[2] === "--" ? "" : f[2], active: f[2] !== "--" });
                }
                rows.sort(function (a,b) { return (b.active?1:0)-(a.active?1:0); });
                root.otherConnections = rows;
            }
        }
    }
    function toggleConnection(c) {
        if (!c) return;
        var args = c.active ? ["nmcli", "connection", "down", "id", c.name] : ["nmcli", "connection", "up", "id", c.name];
        Quickshell.execDetached(args); connectionRefresh.restart();
    }
    Timer { id: connectionRefresh; interval: 1200; onTriggered: root.refreshConnections() }

    property bool btOn: false
    property int btConnected: 0
    property string btConnectedName: ""
    property bool btScanning: false
    property var btDevices: []
    property string btBusy: ""
    property string btError: ""

    function btIconFor(name) {
        var n = (name || "").toLowerCase();
        if (n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0 || n.indexOf("earbud") >= 0 || n.indexOf("airpod") >= 0 || n.indexOf("buds") >= 0 || n.indexOf("wh-") >= 0 || n.indexOf("wf-") >= 0) return "headphones";
        if (n.indexOf("mouse") >= 0 || n.indexOf("trackpad") >= 0 || n.indexOf("magic mouse") >= 0) return "mouse";
        if (n.indexOf("keyboard") >= 0 || n.indexOf("keychron") >= 0) return "keyboard";
        if (n.indexOf("speaker") >= 0 || n.indexOf("soundbar") >= 0 || n.indexOf("echo") >= 0 || n.indexOf("homepod") >= 0) return "speaker";
        if (n.indexOf("controller") >= 0 || n.indexOf("gamepad") >= 0 || n.indexOf("xbox") >= 0 || n.indexOf("dualshock") >= 0 || n.indexOf("dualsense") >= 0) return "gamepad";
        if (n.indexOf("phone") >= 0 || n.indexOf("iphone") >= 0 || n.indexOf("galaxy") >= 0 || n.indexOf("pixel") >= 0) return "phone";
        return "bluetooth";
    }

    function refreshBt() { if (!btProc.running) btProc.running = true; }
    Process {
        id: btProc
        command: ["sh", "-c",
            "[ -n \"$(ls /sys/class/bluetooth 2>/dev/null)\" ] || { echo A:0; echo P:; exit 0; }; echo A:1; "
            + "p=$(timeout 4 bluetoothctl show 2>/dev/null </dev/null | grep -i 'Powered:' | head -n1); echo \"P:$p\"; "
            + "timeout 4 bluetoothctl devices 2>/dev/null </dev/null | while read -r _ mac name; do "
            + "[ -n \"$mac\" ] || continue; "
            + "i=$(timeout 3 bluetoothctl info \"$mac\" 2>/dev/null </dev/null); "
            + "pr=$(printf '%s\\n' \"$i\" | grep -Ec 'Paired: yes|Bonded: yes'); "
            + "c=$(printf '%s\\n' \"$i\" | grep -c 'Connected: yes'); "
            + "b=$(printf '%s\\n' \"$i\" | sed -n 's/.*Battery Percentage: 0x[0-9a-fA-F]* (\\([0-9]*\\)).*/\\1/p' | head -n1); "
            + "printf 'D:%s\\t%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$pr\" \"$c\" \"$b\" \"$name\"; "
            + "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n"), on = false, devList = [], connCount = 0, firstConnName = "", i;
                for (i = 0; i < lines.length; i++) {
                    var l = lines[i].replace(/\r$/, "");
                    if (!l) continue;
                    if (l === "A:0" || l === "A:1") { root.hasBt = l === "A:1"; continue; }
                    if (l.indexOf("P:") === 0) { on = l.toLowerCase().indexOf("yes") >= 0; continue; }
                    if (l.indexOf("D:") !== 0) continue;
                    var f = l.substring(2).split("\t");
                    if (f.length < 5 || !f[0]) continue;
                    var mac = f[0], isPair = f[1] === "1", isConn = f[2] === "1", name = (f[4] || "").trim() || mac;
                    if (isConn) { connCount++; if (!firstConnName) firstConnName = name; }
                    devList.push({ mac: mac, name: name, connected: isConn, paired: isPair, bat: f[3] || "", icon: root.btIconFor(name) });
                }
                root.btOn = on;
                devList.sort(function (a, b) {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1;
                    if (a.paired !== b.paired) return a.paired ? -1 : 1;
                    return a.name.localeCompare(b.name);
                });
                root.btConnected = connCount;
                root.btConnectedName = connCount === 1 ? firstConnName : (connCount > 1 ? connCount + " Connected" : "");
                if (JSON.stringify(devList) !== JSON.stringify(root.btDevices)) root.btDevices = devList;
            }
        }
    }

    function scanBt() {
        if (!root.btOn || btScanProc.running) return;
        root.btScanning = true;
        btScanProc.running = true;
    }
    Process {
        id: btScanProc
        command: ["sh", "-c", "bluetoothctl --timeout 10 scan on >/dev/null 2>&1 </dev/null; exit 0"]
        onExited: {
            root.btScanning = false;
            root.refreshBt();
        }
    }
    Timer { interval: 2500; repeat: true; running: root.btScanning; onTriggered: root.refreshBt() }

    function connectBt(mac, connected) {
        if (btActionProc.running || !mac) return;
        root.btError = "";
        root.btBusy = mac;
        if (connected) {
            btActionProc.command = ["sh", "-c", "bluetoothctl disconnect \"$1\" >/dev/null 2>&1 </dev/null; exit 0", "sh", mac];
        } else {
            btActionProc.command = ["sh", "-c",
                "d=\"$1\"; "
                + "fail() { m=$(printf '%s\\n' \"$1\" | grep -iE 'fail|error|not available|timeout|rejected|canceled' | tail -n1); "
                + "[ -n \"$m\" ] || m=\"$2\"; echo \"$m\" >&2; exit 1; }; "
                + "if ! bluetoothctl info \"$d\" 2>/dev/null </dev/null | grep -qE 'Paired: yes|Bonded: yes'; then "
                + "o=$(timeout 45 bluetoothctl --agent NoInputNoOutput pair \"$d\" 2>&1 </dev/null); "
                + "printf '%s\\n' \"$o\" | grep -qi 'Pairing successful' || fail \"$o\" 'Could not pair. Put the device in pairing mode and try again.'; "
                + "fi; "
                + "bluetoothctl trust \"$d\" >/dev/null 2>&1 </dev/null; "
                + "o=$(timeout 25 bluetoothctl connect \"$d\" 2>&1 </dev/null); "
                + "printf '%s\\n' \"$o\" | grep -qi 'Connection successful' || fail \"$o\" 'Could not connect to the device.'",
                "sh", mac];
        }
        btActionProc.running = true;
    }
    Process {
        id: btActionProc
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") root.btError = text.trim(); }
        onExited: (code, status) => {
            root.btBusy = "";
            if (code !== 0 && root.btError === "") root.btError = I18n.tr("Failed to connect to device.");
            btAfter.restart();
        }
    }
    Timer { id: btAfter; interval: 800; onTriggered: root.refreshBt() }

    function toggleBt() {
        root.btOn = !root.btOn;
        Quickshell.execDetached(["sh", "-c",
            "[ -n \"$(ls /sys/class/bluetooth 2>/dev/null)\" ] || exit 0; "
            + (root.btOn ? "rfkill unblock bluetooth 2>/dev/null; sleep 0.3; timeout 8 bluetoothctl power on"
                         : "timeout 8 bluetoothctl power off")]);
        settleTimer.interval = 1500;
        settleTimer.restart();
    }
    property bool hasRadios: false
    property bool airplane: false
    function refreshAirplane() { if (!rfProc.running) rfProc.running = true; }
    Process {
        id: rfProc
        command: ["sh", "-c", "timeout 3 rfkill -n -o SOFT,HARD 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = text.split("\n").map(function (r) { return r.trim(); }).filter(function (r) { return r !== ""; });
                root.hasRadios = rows.length > 0;
                root.airplane = rows.length > 0 && rows.every(function (r) { return /(^|\s)blocked(\s|$)/.test(r); });
            }
        }
    }
    function toggleAirplane() {
        if (!hasRadios) return;
        var turnOn = !airplane;
        sh(turnOn ? "rfkill block all"
                  : "rfkill unblock all; sleep 0.5; rfkill list bluetooth 2>/dev/null | grep -q . && timeout 5 bluetoothctl power on");
        airplane = turnOn;
        wifiOn = !turnOn && hasWifi; btOn = !turnOn;
        settleTimer.restart();
    }
    Timer { id: settleTimer; interval: 900; onTriggered: { root.refreshWifi(); root.refreshBt(); root.refreshAirplane(); } }
    readonly property bool radioUiOpen: popCount > 0 || (hub && hub.dock && hub.dock.prefsOpen === true)
    onRadioUiOpenChanged: if (radioUiOpen) { refreshWifi(); refreshBt(); refreshAirplane(); }
    Timer { interval: root.radioUiOpen ? 6000 : 20000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { root.refreshWifi(); root.refreshBt(); root.refreshAirplane(); } }

    property real brightness: 0.5
    function refreshBrightness() { if (brightProc.running || brightWrite.running || brightSync.running || brightSettle.running || brightDirty || Date.now() - brightTouched < 2500) return; brightProc.running = true; }
    Process {
        id: brightProc
        command: ["sh", "-c", "yuki-brightness getm 2>/dev/null || brightnessctl -c backlight -m 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var f = text.trim().split(",");
                if (f.length >= 4) { var p = parseInt(f[3]); if (!isNaN(p)) root.brightness = p / 100; }
                root.brightLaptop = f.length >= 4 && f[0] !== "yuki";
            }
        }
    }
    property bool brightDirty: false
    property int brightSent: -1
    property double brightTouched: 0
    Process {
        id: brightWrite
        onRunningChanged: if (!running && root.brightDirty) root.brightFlush()
    }
    function brightFlush() {
        var want = Math.max(1, Math.round(brightness * 100));
        if (brightWrite.running) { brightDirty = true; return; }
        brightDirty = false;
        if (want === brightSent) return;
        brightSent = want;
        brightWrite.command = ["yuki-brightness", "set", String(want)];
        brightWrite.running = true;
    }
    function brightUser() { brightTouched = Date.now(); brightFlush(); brightSettle.restart(); }
    Timer {
        id: brightSettle
        interval: 350
        onTriggered: {
            if (brightWrite.running || brightDirty) { restart(); return; }
            brightSync.command = ["yuki-brightness", "sync", String(Math.max(1, Math.round(root.brightness * 100)))];
            brightSync.running = true;
        }
    }
    Process {
        id: brightSync
        onRunningChanged: if (!running) { root.brightTouched = Date.now() - 2600; root.refreshBrightness(); }
    }
    function setBrightness(v) { osdQuiet("brightness", 1800); brightness = Math.max(0.01, Math.min(1, v)); brightUser(); }
    onBrightnessChanged: showOsd("brightness", brightness)
    function hwVolume(d) {
        if (!sink || !sink.audio) return;
        var v = Math.max(0, Math.min(1, Math.round((sink.audio.volume + d) * 100) / 100));
        if (d > 0) sink.audio.muted = false;
        sink.audio.volume = v;
        showOsd("volume", sink.audio.muted ? 0 : v);
    }
    function hwMute() {
        if (!sink || !sink.audio) return;
        sink.audio.muted = !sink.audio.muted;
        showOsd("volume", sink.audio.muted ? 0 : sink.audio.volume);
    }
    function hwMicMute() { if (micSource && micSource.audio) micSource.audio.muted = !micSource.audio.muted; }
    function hwBrightness(d) {
        brightness = Math.max(0.01, Math.min(1, Math.round((brightness + d) * 100) / 100));
        brightUser();
        showOsd("brightness", brightness);
    }
    // A laptop backlight is cheap to read and firmware keys change it behind our back, so it is polled quickly; an external monitor
    // (DDC/CI, cached for 30 s by yuki-brightness) or no brightness control at all is polled slowly. Opening Control Center refreshes it too.
    property bool brightLaptop: true
    Timer { interval: root.brightLaptop ? 850 : (root.radioUiOpen ? 6000 : 30000); repeat: true; running: true; onTriggered: root.refreshBrightness() }
    readonly property var kbNames: ({
        us: "English (US)", gb: "English (UK)", ca: "Canadian", au: "English (Australian)", ie: "Irish", in: "Indian",
        ru: "Russian", ua: "Ukrainian", by: "Belarusian", bg: "Bulgarian", rs: "Serbian", hr: "Croatian", si: "Slovenian", mk: "Macedonian",
        de: "German", at: "German (Austria)", ch: "Swiss", fr: "French", be: "Belgian", es: "Spanish", latam: "Spanish (Latin American)",
        it: "Italian", pt: "Portuguese", br: "Portuguese (Brazil)", nl: "Dutch", se: "Swedish", no: "Norwegian", dk: "Danish", fi: "Finnish",
        is: "Icelandic", pl: "Polish", cz: "Czech", sk: "Slovak", hu: "Hungarian", ro: "Romanian", gr: "Greek", tr: "Turkish",
        il: "Hebrew", ara: "Arabic", ir: "Persian", pk: "Urdu", bd: "Bangla", th: "Thai", vn: "Vietnamese", jp: "Japanese", kr: "Korean",
        cn: "Chinese", tw: "Taiwanese", mn: "Mongolian", ge: "Georgian", am: "Armenian", kz: "Kazakh", ee: "Estonian", lv: "Latvian", lt: "Lithuanian"
    })
    readonly property var kbCodeAliases: ({
        "english": "EN", "us": "US", "uk": "GB", "united kingdom": "GB",
        "swedish": "SV", "svenska": "SV", "se": "SV",
        "german": "DE", "deutsch": "DE", "de": "DE",
        "french": "FR", "français": "FR", "fr": "FR",
        "spanish": "ES", "español": "ES", "es": "ES",
        "italian": "IT", "italiano": "IT", "it": "IT",
        "portuguese": "PT", "português": "PT", "pt": "PT",
        "russian": "RU", "русский": "RU", "ru": "RU",
        "ukrainian": "UA", "українська": "UA", "ua": "UA",
        "polish": "PL", "polski": "PL", "pl": "PL",
        "dutch": "NL", "nederlands": "NL", "nl": "NL",
        "norwegian": "NO", "norsk": "NO", "no": "NO",
        "danish": "DA", "dansk": "DA", "dk": "DA",
        "finnish": "FI", "suomi": "FI", "fi": "FI",
        "japanese": "JA", "jp": "JA",
        "korean": "KO", "kr": "KO",
        "chinese": "ZH", "cn": "ZH",
        "arabic": "AR", "ara": "AR",
        "hebrew": "HE", "il": "HE",
        "turkish": "TR", "tr": "TR",
        "greek": "EL", "gr": "EL"
    })
    function imLabelFor(icon, name) {
        var i = icon.toLowerCase(), n = name.toLowerCase();
        if (i.indexOf("keyboard") >= 0 || n.indexOf("keyboard") === 0 || (i === "" && n === "")) return "";
        var known = [["pinyin", "\u62fc"], ["shuangpin", "\u53cc"], ["rime", "\u4e2d"], ["chewing", "\u6ce8"], ["zhuyin", "\u6ce8"],
                     ["mozc", "\u3042"], ["anthy", "\u3042"], ["kkc", "\u3042"], ["skk", "\u3042"], ["hangul", "\ud55c"],
                     ["bamboo", "VI"], ["unikey", "VI"], ["telex", "VI"]];
        for (var k = 0; k < known.length; k++) if (i.indexOf(known[k][0]) >= 0 || n.indexOf(known[k][0]) >= 0) return known[k][1];
        var w = name || icon;
        return w.replace(/[^A-Za-z]/g, "").substring(0, 2).toUpperCase() || w.substring(0, 1);
    }
    property string fcitxIM: ""
    readonly property bool imTrayShown: {
        if (!barEnabled || !showTray) return false;
        var v = SystemTray.items.values;
        for (var k = 0; k < v.length; k++) if (String(v[k].id).toLowerCase() === "fcitx") return true;
        return false;
    }
    readonly property string imWatchScript: decodeURIComponent(String(Qt.resolvedUrl("assets/imwatch.py")).replace(/^file:\/\//, ""))
    OwnedProcess {
        id: imWatch
        cmd: ["python3", "-I", root.imWatchScript]
        running: root.imTrayShown
        onRunningChanged: if (!running) root.fcitxIM = ""
        stdout: SplitParser { onRead: data => root.fcitxIM = data.trim() }
    }
    function refreshKeyboardLayout() { if (!kbdProc.running) kbdProc.running = true; }
    Timer {
        interval: 5000; repeat: true
        running: root.barEnabled && root.barWidgetEnabled("keyboard") && root.kbLayouts.length > 1
        onTriggered: root.refreshKeyboardLayout()
    }
    Timer { id: kbEventRefresh; interval: 120; onTriggered: root.refreshKeyboardLayout() }
    Process {
        id: kbdProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text), ks = d.keyboards || [], k = null, i;
                    for (i = 0; i < ks.length; i++) if (ks[i].main) { k = ks[i]; break; }
                    if (!k && ks.length) k = ks[0];
                    if (!k) return;
                    var codes = String(k.layout || "").split(",");
                    var list = [];
                    for (i = 0; i < codes.length; i++) {
                        var c = codes[i].trim();
                        if (c !== "") list.push({ code: c, name: root.kbNames[c] || c.toUpperCase() });
                    }
                    if (list.length <= 1) {
                        for (var j = 0; j < ks.length; j++) {
                            var otherCodes = String(ks[j].layout || "").split(",");
                            if (otherCodes.length > list.length) {
                                var olist = [];
                                for (var m = 0; m < otherCodes.length; m++) {
                                    var oc = otherCodes[m].trim();
                                    if (oc !== "") olist.push({ code: oc, name: root.kbNames[oc] || oc.toUpperCase() });
                                }
                                if (olist.length > list.length) { list = olist; k = ks[j]; }
                            }
                        }
                    }
                    root.kbMain = k.name || "";
                    root.kbLayouts = list;
                    root.kbSetActive(k.active_keymap || "", k.active_layout_index);
                } catch (err) { }
            }
        }
    }
    function kbSetActive(name, idx) {
        var L = kbLayouts, found = -1, i;
        var n = String(name || "").toLowerCase().trim();
        if (idx !== undefined && idx !== null && idx >= 0 && idx < L.length) found = idx;
        for (i = 0; found < 0 && i < L.length; i++) {
            if (L[i].name.toLowerCase() === n || L[i].code.toLowerCase() === n) found = i;
        }
        for (i = 0; found < 0 && i < L.length; i++) {
            var firstWord = L[i].name.toLowerCase().split(" ")[0];
            if (n !== "" && (n.indexOf(firstWord) === 0 || firstWord.indexOf(n) === 0)) found = i;
        }
        if (found >= 0) {
            kbIndex = found;
            keyboardLayout = L[found].code.substring(0, 2).toUpperCase();
        } else if (n !== "") {
            var words = n.split(/[\s,()_-]+/);
            var mapped = "";
            for (var w = 0; w < words.length; w++) {
                if (root.kbCodeAliases[words[w]]) { mapped = root.kbCodeAliases[words[w]]; break; }
            }
            keyboardLayout = mapped || String(name).replace(/[^A-Za-z]/g, "").substring(0, 2).toUpperCase() || "??";
        }
    }
    function switchKeyboardLayout(i) {
        var n = kbLayouts.length;
        if (n < 2) return;
        i = ((i % n) + n) % n;
        kbIndex = i; keyboardLayout = kbLayouts[i].code.substring(0, 2).toUpperCase();
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)]);
        kbEventRefresh.restart();
    }
    function cycleKeyboardLayout(step) { switchKeyboardLayout(kbIndex + (step === undefined ? 1 : step)); }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                var d = String(event.data), c = d.indexOf(",");
                if (c < 0) return;
                var lay = d.substring(c + 1).trim();
                root.kbSetActive(lay, undefined);
                kbEventRefresh.restart();
            } else if (event.name === "configreloaded") { root.refreshKeyboardLayout(); if (root.settingsReady) borderApplyT.restart(); }
            else if (event.name === "custom" && event.data.indexOf("yukidrag ") === 0) root.dragEvent(event.data.split(" "));
        }
    }

    // Super-dragging a window (binds.lua reports it as "yukidrag" events) onto a workspace number turns it into its app icon,
    // letting go there sends it to that workspace. Over a number: a live snapshot covers the window, the window is hidden
    // (opacity 0), the snapshot shrinks into the icon. Off the number it grows back and the window returns.
    property var drag: null              // { addr, x, y (rect at the start), floating, ws, fs (fullscreen mode), hidden, op (props to give back), opReady }
    property string dragIcon: ""
    property var dragTl: null            // the window, for the snapshot
    property bool dragSnapReady: false   // the snapshot has a frame
    property real dragX: -1              // pointer
    property real dragY: -1
    property real dragWinX: 0            // the window's rect right now
    property real dragWinY: 0
    property real dragWinW: 0
    property real dragWinH: 0
    property var dragWs: null            // the workspace number under the pointer
    property real dragWsX: 0             // its centre, where the icon drops into
    property bool dragCover: false       // the snapshot is up (at t = 0 it sits exactly on the window)
    property real dragT: 0               // 0 = the window, 1 = its icon
    Behavior on dragT { NumberAnimation { duration: 460; easing.type: Easing.OutQuint } }
    property real dropT: 0               // the icon falling into the number after letting go
    property point dropFrom
    property point dropTo
    NumberAnimation on dropT { id: dropAnim; running: false; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
    readonly property var dragProps: ["opacity", "opacity_inactive", "opacity_fullscreen", "no_anim"]
    onDragWsChanged: {
        if (!drag) return;
        if (dragWs !== null) { dragCover = true; dragHideT.tries = 0; dragHideT.restart(); }
        else { dragHideT.stop(); dragT = 0; if (!drag.hidden) dragCover = false; }
    }
    // hide once the snapshot has a frame on screen and the window's own props are known (or give up waiting after 300 ms)
    Timer {
        id: dragHideT
        property int tries: 0
        interval: 50
        onTriggered: {
            if (!root.drag || root.dragWs === null) return;
            if ((!root.dragSnapReady || !root.drag.opReady) && ++tries < 6) { restart(); return; }
            if (!root.drag.opReady) return;   // never hide what can't be given back exactly
            root.dragHide(true);
            root.dragT = 1;
        }
    }
    onDragTChanged: if (drag && drag.hidden && dragWs === null && dragT < 0.02) { dragHide(false); dragUncoverT.restart(); }
    Timer { id: dragUncoverT; interval: 60; onTriggered: if (root.drag && !root.drag.hidden) root.dragCover = false }   // the window is drawn again first
    // the drag events stop without an "end" (Hyprland reloaded its config mid-drag): put everything back
    Timer { id: dragWatch; interval: 600; onTriggered: root.dragFinish(false) }
    function dragSetProps(addr, vals) {
        for (var i = 0; i < dragProps.length; i++)
            Hyprland.dispatch('hl.dsp.window.set_prop({ prop = "' + dragProps[i] + '", value = "' + vals[i] + '", window = "address:' + addr + '" })');
    }
    // Hyprland has no way to unset a window prop, so the values read at the start go back; a file remembers them for a shell
    // restarted while the window is hidden
    function dragHide(on) {
        if (on === drag.hidden) return;
        drag.hidden = on;
        if (root.hub) root.hub.dragHidden = on ? drag.addr.replace(/^0x/, "") : "";
        if (on) {
            dragAnimBack.flush();
            dragSetProps(drag.addr, ["0", "0", "0", "true"]);
            dragFile.setText(drag.addr + " " + drag.op.join(" "));
        } else {
            // the window comes back at once; its animations only once it is drawn, or Hyprland fades it in from 0
            dragSetProps(drag.addr, drag.op.slice(0, 3).concat(["true"]));
            dragAnimBack.addr = drag.addr; dragAnimBack.val = drag.op[3]; dragAnimBack.restart();
        }
    }
    Timer {
        id: dragAnimBack
        property string addr: ""
        property string val: "false"
        interval: 400
        onTriggered: flush()
        function flush() {
            stop();
            if (addr === "") return;
            Hyprland.dispatch('hl.dsp.window.set_prop({ prop = "no_anim", value = "' + val + '", window = "address:' + addr + '" })');
            addr = "";
            dragFile.setText("");
        }
    }
    function dragFinish(drop) {
        dragWatch.stop(); dragHideT.stop();
        if (!drag) return;
        var d = drag, ws = drop ? dragWs : null, sel = 'window = "address:' + d.addr + '"';
        if (ws !== null) {
            dropFrom = Qt.point(dragX, dragY + 36); dropTo = Qt.point(dragWsX, root.barH / 2); dropAnim.restart();
            if (ws !== d.ws) Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + ws + '", follow = false, ' + sel + ' })');
            // Hyprland lets go of fullscreen and maximized to drag: the window arrives the way it was
            if (d.fs > 0) Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "' + (d.fs === 1 ? "maximized" : "fullscreen") + '", action = "set", ' + sel + ' })');
            else if (d.floating) Hyprland.dispatch('hl.dsp.window.move({ x = ' + d.x + ', y = ' + d.y + ', "exact", ' + sel + ' })');
        }
        dragHide(false);
        drag = null; dragWs = null; dragTl = null; dragCover = false; dragT = 0;
    }
    function dragEvent(a) {
        if (a[1] === "start") {
            if (drag) dragFinish(false);
            dragAnimBack.flush();
            var cls = a.slice(12).join(" "), e = lookup(cls), ts = Hyprland.toplevels.values, ad = a[2].replace(/^0x/, "");
            drag = { addr: a[2], x: +a[3], y: +a[4], floating: a[5] === "1", ws: +a[6], fs: +a[11], hidden: false, op: [], opReady: false };
            dragX = +a[9]; dragY = +a[10];
            dragWinX = +a[3]; dragWinY = +a[4]; dragWinW = +a[7]; dragWinH = +a[8];
            dragTl = null; dragSnapReady = false;
            for (var i = 0; i < ts.length; i++) if (ts[i].address === ad) { dragTl = ts[i].wayland; break; }
            dragIcon = cls === "org.quickshell" ? Qt.resolvedUrl("assets/yukishell-logo.png")
                     : (Quickshell.iconPath(e && e.icon ? e.icon : cls.toLowerCase(), true) || Quickshell.iconPath("application-x-executable", true) || "");
            dragOpProc.running = false;
            dragOpProc.command = ["sh", "-c", 'echo "$1"; for p in ' + dragProps.join(" ") + '; do hyprctl getprop "address:$1" "$p"; done', "sh", a[2]];
            dragOpProc.running = true;
            dragWatch.restart();
        } else if (!drag) {
            return;
        } else if (a[1] === "move") {
            dragWatch.restart();
            dragX = +a[2]; dragY = +a[3];
            if (a.length < 8) { dragFinish(false); return; }   // the window closed: nothing left to send
            dragWinX = +a[4]; dragWinY = +a[5]; dragWinW = +a[6]; dragWinH = +a[7];
        } else if (a[1] === "end") {
            dragFinish(true);
        }
    }
    Process {
        id: dragOpProc
        stdout: StdioCollector {
            onStreamFinished: {
                var v = text.trim().split(/\s+/), d = root.drag;
                // the reply belongs to this drag, and every value parses (a window that closed gives errors: it is never hidden)
                if (!d || d.hidden || v.length !== 5 || v[0] !== d.addr) return;
                if (isNaN(+v[1]) || isNaN(+v[2]) || isNaN(+v[3]) || !/^(true|false)$/.test(v[4])) return;
                d.op = v.slice(1); d.opReady = true;
            }
        }
    }
    FileView {
        id: dragFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/yukishell-drag-hidden"
        blockWrites: true
        printErrors: false
        // a window hidden by a shell that is gone: give its props back
        onLoaded: {
            var v = text().trim().split(/\s+/);
            if (v.length === 5 && /^0x[0-9a-f]+$/.test(v[0])) root.dragSetProps(v[0], v.slice(1));
            if (text() !== "") setText("");
        }
    }

    PwObjectTracker { objects: Pipewire.linkGroups.values }
    function computePrivacy() {
        var mic = [], cam = [], share = [], L = Pipewire.linkGroups.values;
        function add(list, name) { if (list.indexOf(name) < 0) list.push(name); }
        for (var i = 0; i < L.length; i++) {
            var g = L[i];
            if (!g || g.state !== PwLinkState.Active) continue;
            var s = g.source, t = g.target;
            if (!s || !t || s.type === undefined) continue;
            var tp = t.properties || {}, sp = s.properties || {};
            var who = String(tp["application.name"] || tp["node.description"] || t.description || tp["node.name"] || t.name || I18n.tr("An app"))
                .replace(/\s+(input|output)$/i, "");
            if ((t.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream) {
                if ((s.type & PwNodeType.Sink) !== 0) continue;
                if (String(tp["media.name"]).toLowerCase() === "peak detect" || String(tp["application.id"]).indexOf("pavucontrol") >= 0) continue;
                add(mic, who);
            } else if ((t.type & PwNodeType.Video) !== 0 && (s.type & PwNodeType.Video) !== 0) {
                var isCam = sp["device.api"] !== undefined || String(sp["media.role"]) === "Camera"
                            || String(sp["node.name"]).indexOf("v4l2") === 0 || String(sp["node.name"]).indexOf("libcamera") === 0;
                add(isCam ? cam : share, who);
            }
        }
        return { mic: mic, cam: cam, share: share };
    }
    readonly property var privacy: computePrivacy()
    readonly property bool privacyAny: privacy.mic.length > 0 || privacy.cam.length > 0 || privacy.share.length > 0 || recording
    readonly property var privacyDots: {
        var a = [];
        if (privacy.mic.length > 0) a.push("#FF9F0A");
        if (privacy.cam.length > 0) a.push("#30D158");
        if (privacy.share.length > 0 || recording) a.push("#BF5AF2");
        return a;
    }
    readonly property var privacyRows: {
        var a = [];
        if (privacy.mic.length > 0) a.push({ k: "mic", glyph: "mic", c: "#FF9F0A", title: I18n.tr("Microphone"), sub: privacy.mic.join(", ") });
        if (privacy.cam.length > 0) a.push({ k: "cam", glyph: "camera", c: "#30D158", title: "Camera", sub: privacy.cam.join(", ") });
        if (privacy.share.length > 0) a.push({ k: "share", glyph: "monitor", c: "#BF5AF2", title: I18n.tr("Screen Sharing"), sub: privacy.share.join(", ") });
        if (recording) a.push({ k: "rec", glyph: "monitor", c: "#BF5AF2", title: I18n.tr("Screen Recording"), sub: I18n.tr("Recording ") + recTime() });
        return a;
    }
    property bool recRun: false
    property real recGuardUntil: 0
    Timer { id: recStartDelay; interval: 900; onTriggered: if (root.recording) root.recRun = true }
    Process {
        id: recordProc
        command: ["sh", "-c", [
            'f="$1"; out="$2"; pf="${XDG_RUNTIME_DIR:-/tmp}/yukibar-recorder.pid"; log="${XDG_RUNTIME_DIR:-/tmp}/yukibar-recorder.log"',
            'mkdir -p "$(dirname "$f")"',
            '# a recorder left behind by an earlier crash would record forever: finish it first',
            'if [ -f "$pf" ]; then op=$(cat "$pf" 2>/dev/null); if [ -n "$op" ] && [ "$(cat /proc/$op/comm 2>/dev/null)" = wf-recorder ]; then kill -INT "$op" 2>/dev/null; sleep 0.6; fi; fi',
            'echo $$ > "$pf"',
            'set -- -f "$f" -p preset=veryfast -p crf=20',
            '# with more than one monitor wf-recorder stops to ask which one (and fails with no terminal): record the focused one',
            '[ -n "$out" ] && set -- "$@" -o "$out"',
            'exec 2>"$log" </dev/null',
            '# wf-recorder records at the monitor refresh rate (144 fps on a 144 Hz screen): cap it at 60',
            'if wf-recorder --help 2>&1 | grep -q -- "--framerate"; then set -- "$@" -r 60; fi',
            '# --pdeathsig: if the shell dies, the recorder is told to finish (and close the file) instead of running on',
            'if command -v setpriv >/dev/null 2>&1; then exec setpriv --pdeathsig INT wf-recorder "$@"; fi',
            'exec wf-recorder "$@"'
        ].join("\n"), "sh", root.recordFile, Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""]
        running: root.recRun
        onExited: (code, status) => {
            root.recRun = false;
            if (root.recording) root.recording = false;
            Quickshell.execDetached(["sh", "-c", "rm -f \"${XDG_RUNTIME_DIR:-/tmp}/yukibar-recorder.pid\"; if [ -s \"$1\" ]; then notify-send -a yukibar 'Screen Recording Saved' \"$1\"; "
                + "elif ! command -v wf-recorder >/dev/null 2>&1; then notify-send -a yukibar 'Screen Recording Failed' 'wf-recorder is not installed'; "
                + "else notify-send -a yukibar 'Screen Recording Failed' \"$(grep -v '^\\s*$' \"${XDG_RUNTIME_DIR:-/tmp}/yukibar-recorder.log\" 2>/dev/null | tail -n 2)\"; fi", "sh", root.recordFile]);
        }
    }
    function toggleRecording() {
        if (Date.now() < recGuardUntil) return;
        recGuardUntil = Date.now() + 1500;
        if (!recording) {
            recordFile = Quickshell.env("HOME") + "/Videos/Screen-Recording-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".mp4";
            recSecs = 0;
            recording = true;
            recStartDelay.restart();
        } else {
            recStartDelay.stop();
            recording = false;
            if (recRun) {
                Quickshell.execDetached(["sh", "-c", "kill -INT \"$(cat \"${XDG_RUNTIME_DIR:-/tmp}/yukibar-recorder.pid\" 2>/dev/null)\" 2>/dev/null || pkill -INT -x wf-recorder"]);
                recKill.restart();
            }
        }
    }
    Timer { id: recKill; interval: 10000; onTriggered: root.recRun = false }
    Timer { interval: 1000; repeat: true; running: root.recRun; onTriggered: root.recSecs++ }
    Process {
        id: reapOrphans
        running: true
        command: ["sh", "-c", [
            'orph() { pp=$(ps -o ppid= -p "$1" 2>/dev/null | tr -d " "); [ -n "$pp" ] || return 1; [ "$pp" = 1 ] && return 0; c=$(cat /proc/$pp/comm 2>/dev/null); [ "$c" = systemd ] || [ "$c" = init ]; }',
            'has() { tr "\\0" " " < /proc/$1/cmdline 2>/dev/null | grep -qF -- "$2"; }',
            'for p in $(pgrep -x wf-recorder); do orph "$p" && kill -INT "$p"; done',
            'for p in $(pgrep -x systemd-inhibit); do has "$p" "--who=yukibar" && orph "$p" && { pkill -P "$p"; kill "$p"; }; done',
            'for p in $(pgrep -x inotifywait); do has "$p" "%e|%w%f" && orph "$p" && kill "$p"; done',
            'for p in $(pgrep -x cava); do has "$p" "yukishell-cava.conf" && orph "$p" && kill "$p"; done',
            'for p in $(pgrep -x python3); do has "$p" "assets/imwatch.py" && orph "$p" && kill "$p"; done',
            'exit 0'].join("\n")]
    }
    function recTime() {
        var m = Math.floor(recSecs / 60), r = recSecs % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
    function pickColor() { sh("c=$(hyprpicker -a) && [ -n \"$c\" ] && notify-send -a yukibar 'Color copied' \"$c\""); }
    Process {
        id: fileSearchProc
        command: ["sh", "-c", "find \"$HOME\" -type f -iname \"*$1*\" -not -path '*/.cache/*' -not -path '*/.local/share/Trash/*' 2>/dev/null | head -n 60", "sh", root.fileQuery]
        stdout: StdioCollector { onStreamFinished: {
            var a=text.trim().split("\n").filter(function(x){return x!=="";});
            if (root.fileSearchFor === root.fileQuery) { root.fileHits=a; root.fileSearchPending=false; }
            else fileDebounce.restart();
        } }
        onExited: if (root.fileSearchFor !== root.fileQuery) fileDebounce.restart()
    }
    Timer { id: fileDebounce; interval: 260; onTriggered: {
        if (root.fileQuery.length > 0 && !fileSearchProc.running) { root.fileSearchFor=root.fileQuery; root.fileSearchPending=true; fileSearchProc.running=true; }
    } }
    function updateFileSearch(q) { fileQuery=q; fileHits=[]; fileSearchPending=true; fileDebounce.restart(); }

    property bool dnd: false
    onNotifDndChanged: if (dnd !== notifDnd) dnd = notifDnd
    onDndChanged: if (notifDnd !== dnd) notifDnd = dnd
    function toggleDnd() {
        dnd = !dnd;
        if (dnd) sh("dunstctl set-paused true 2>/dev/null || makoctl mode -a do-not-disturb 2>/dev/null || swaync-client -dn 2>/dev/null");
        else sh("dunstctl set-paused false 2>/dev/null || makoctl mode -r do-not-disturb 2>/dev/null || swaync-client -df 2>/dev/null");
    }
    property bool nightOn: false
    OwnedProcess { id: nightProc; cmd: ["hyprsunset", "-t", String(root.nightTemp)]; running: root.nightOn }
    property bool keepAwake: false
    property int idleLockMins: 0
    property int idleScreenMins: 0
    IdleMonitor {
        enabled: root.settingsReady && root.idleLockMins > 0 && !root.keepAwake && !root.gaming
        timeout: root.idleLockMins * 60
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["sh", "-c", 'sh "$HOME/.config/quickshell/YukiLock/lock-via-ipc.sh"'])
    }
    IdleMonitor {
        enabled: root.settingsReady && root.idleScreenMins > 0 && !root.keepAwake && !root.gaming
        timeout: root.idleScreenMins * 60
        onIsIdleChanged: Hyprland.dispatch('hl.dsp.dpms({ action = "' + (isIdle ? "off" : "on") + '" })')
    }
    OwnedProcess {
        id: awakeProc
        cmd: ["systemd-inhibit", "--what=idle:sleep", "--who=yukibar", "--why=Keep Awake", "setpriv", "--pdeathsig", "TERM", "--", "sleep", "infinity"]
        running: root.keepAwake
    }

    property var bindKeys: ({})
    function parseBinds() {
        var map = {};
        function rd(t, cols) {
            var ls = String(t || "").split("\n");
            for (var i = 0; i < ls.length; i++) {
                var p = ls[i].replace(/\r$/, "").split("\t");
                if (p.length >= cols && p[0] !== "") map[p[0]] = p[1];
            }
        }
        rd(bindsDefault.text(), 2);
        rd(bindsUser.text(), 2);
        bindKeys = map;
    }
    FileView { id: bindsDefault; path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/yukishell/keybinds.tsv"; watchChanges: true; printErrors: false; onFileChanged: reload(); onLoaded: root.parseBinds(); onLoadFailed: root.parseBinds() }
    FileView { id: bindsUser; path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/yukishell/keybinds.tsv"; watchChanges: true; printErrors: false; onFileChanged: reload(); onLoaded: root.parseBinds(); onLoadFailed: root.parseBinds() }
    function hk(desc) {
        var k = bindKeys[desc];
        if (!k) return "";
        var names = { SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", CONTROL: "Ctrl", ALT: "Alt", Return: "Enter", space: "Space", Space: "Space",
                      period: ".", comma: ",", PRINT: "Print", Print: "Print", Tab: "Tab", TAB: "Tab", left: "\u2190", right: "\u2192", up: "\u2191", down: "\u2193", Page_Down: "PgDn", Page_Up: "PgUp" };
        return k.split("+").map(function (x) { x = x.trim(); return names[x] || (x.length === 1 ? x.toUpperCase() : x); }).join("+");
    }
    function mi(label, shortcut, run) { return { kind: "item", label: label, shortcut: shortcut || "", run: run }; }
    function mc(label, run) { return { kind: "item", label: label, shortcut: "", run: run, confirm: true }; }
    function msep() { return { kind: "sep" }; }
    function ico(item, g) { item.glyph = g; return item; }
    function hlx(expr) { Quickshell.execDetached(["hyprctl", "dispatch", expr]); }
    function disp(expr) { return function () { root.hlx(expr); }; }
    // Menu shortcuts are sent to the focused window with Hyprland's sendshortcut (no extra tool needed).
    // If some app ignores them, set this to true to type them with wtype instead.
    function keys(mods, k) {
        return function () {
            var targetAddr = root.activeWin ? (root.activeWin.address || "") : "";
            var modMap = {
                "ctrl": "ctrl", "control": "ctrl",
                "shift": "shift",
                "alt": "alt",
                "super": "logo", "win": "logo", "cmd": "logo"
            };
            var wtypeMods = mods.map(function(m) { return modMap[m.toLowerCase()] || m.toLowerCase(); });
            var hyprMods = mods.map(function(m) { return m.toUpperCase(); }).join(" ");
            var luaMods = mods.map(function(m) { return m.toUpperCase(); }).join(" + ");

            var kNorm = k;
            var wtypeK = k;
            if (k === "comma") { kNorm = "comma"; wtypeK = "comma"; }
            else if (k === "equal") { kNorm = "equal"; wtypeK = "equal"; }
            else if (k === "minus") { kNorm = "minus"; wtypeK = "minus"; }
            else if (k === "period") { kNorm = "period"; wtypeK = "period"; }

            var wtypeCmd = "wtype";
            for (var i = 0; i < wtypeMods.length; i++) wtypeCmd += " -M " + wtypeMods[i];
            wtypeCmd += " -k " + wtypeK;
            for (var j = wtypeMods.length - 1; j >= 0; j--) wtypeCmd += " -m " + wtypeMods[j];

            var focusCmd = targetAddr !== "" ? "hyprctl dispatch focuswindow address:" + targetAddr + " >/dev/null 2>&1; sleep 0.04; " : "sleep 0.03; ";
            var sendArg = targetAddr !== "" ? (hyprMods !== "" ? hyprMods + ", " : "") + kNorm + ", address:" + targetAddr
                                           : (hyprMods !== "" ? hyprMods + ", " : "") + kNorm + ", activewindow";

            var fullScript = focusCmd + 'if command -v wtype >/dev/null 2>&1; then ' + wtypeCmd + '; '
                           + 'elif command -v ydotool >/dev/null 2>&1; then ydotool key ' + (mods.length ? mods.join("+") + "+" : "") + kNorm + '; '
                           + 'else hyprctl dispatch sendshortcut "' + sendArg + '" 2>/dev/null || hyprctl dispatch sendshortcut "' + (hyprMods ? hyprMods + ", " : "") + kNorm + ', activewindow" 2>/dev/null || true; fi';

            Quickshell.execDetached(["sh", "-c", fullScript]);
        };
    }
    function mchk(label, shortcut, checked, run) { return { kind: "item", label: label, shortcut: shortcut || "", run: run, checked: checked === true }; }
    function dis(item, off) { if (off) item.disabled = true; return item; }

    function appKind(id) {
        var c = (id || "").toLowerCase();
        function any(list) { for (var i = 0; i < list.length; i++) if (c.indexOf(list[i]) >= 0) return true; return false; }
        if (any(["kitty", "alacritty", "foot", "wezterm", "ghostty", "konsole", "terminal", "xterm", "urxvt", "terminator", "tilix", "ptyxis"])) return "terminal";
        if (c === "zen" || any(["firefox", "chromium", "chrome", "brave", "zen-browser", "zen_browser", "vivaldi", "librewolf", "floorp", "waterfox", "opera", "epiphany", "falkon", "helium", "thorium", "microsoft-edge", "qutebrowser"])) return "browser";
        if (any(["nautilus", "dolphin", "thunar", "nemo", "pcmanfm", "caja", "krusader"])) return "files";
        if (any(["code", "codium", "cursor", "dev.zed", "kate", "gedit", "sublime", "geany", "neovide", "emacs", "jetbrains", "pycharm", "intellij", "clion", "webstorm"])) return "editor";
        return "";
    }
    function shot(region) {
        if (region === "sel") shotStart();
        else shotFinish(region, "");
    }
    function shotWindow(aw) {
        if (!aw || !aw.at || !aw.size) return;
        shot(Math.round(aw.at[0]) + "," + Math.round(aw.at[1]) + " " + Math.round(aw.size[0]) + "x" + Math.round(aw.size[1]));
    }
    function aboutActive(aw, n) {
        var l = [];
        if (aw) {
            l.push("Class: " + aw["class"]);
            l.push("PID: " + aw.pid);
            if (aw.workspace) l.push("Workspace: " + aw.workspace.name);
            if (aw.title) l.push("Title: " + aw.title);
        } else l.push("Class: " + activeAppId);
        Quickshell.execDetached(["notify-send", "-a", "yukibar", "About " + n, l.join("\n")]);
    }
    function forceQuitActive(aw) {
        if (aw && aw.pid > 0) Quickshell.execDetached(["kill", "-9", String(Math.floor(aw.pid))]);
    }
    function helpFor(id, n) {
        var c = (id || "").toLowerCase().replace(/[^a-z0-9._+-]/g, "");
        if (c === "") return;
        var q = encodeURIComponent(n + " linux help").replace(/'/g, "%27");
        sh("if man -w " + c + " >/dev/null 2>&1; then " + terminal + " -e man " + c + "; else '" + openUrlScript + "' 'https://duckduckgo.com/?q=" + q + "'; fi");
    }
    function emoji() {
        sh("for c in emote bemoji smile rofimoji wofi-emoji; do command -v $c >/dev/null 2>&1 && exec $c; done");
    }
    function quitActive() {
        var tls = ToplevelManager.toplevels.values;
        for (var i = 0; i < tls.length; i++) if (tls[i].appId === activeAppId) tls[i].close();
    }
    function launchActive() {
        var e = lookup(activeAppId);
        if (e) e.execute();
    }
    function search() {
        if (!spotlightEnabled && launcher === "") return;
        spotWant = "home";
        if (launcher !== "") sh(launcher);
        else spotRequest++;
    }
    function spotOpen(mode) { if (!spotlightEnabled) return; spotWant = mode; spotRequest++; }
    signal ccRequest(bool open)
    IpcHandler {
        target: "controlcenter"
        function toggle(): void { root.ccRequest(true); }
        function open(): void { root.ccRequest(true); }
        function close(): void { root.ccRequest(false); }
    }
    IpcHandler {
        target: "hardware"
        function volumeUp(): void { root.hwVolume(0.05); }
        function volumeDown(): void { root.hwVolume(-0.05); }
        function mute(): void { root.hwMute(); }
        function micMute(): void { root.hwMicMute(); }
        function brightnessUp(): void { root.hwBrightness(0.05); }
        function brightnessDown(): void { root.hwBrightness(-0.05); }
    }
    IpcHandler {
        target: "spotlight"
        function toggle(): void { root.search(); }
        function clipboard(): void { root.spotOpen("clip"); }
        function emoji(): void { root.spotOpen("emoji"); }
        function apps(): void { root.spotOpen("apps"); }
    }

    property string clipState: "unknown"
    property var clipEntries: []
    property bool clipLoading: false
    readonly property string clipDir: Quickshell.env("HOME") + "/.cache/yukibar"
    property string emojiFont: "Noto Color Emoji"
    Process {
        running: true
        command: ["sh", "-c", "fc-match -f '%{family[0]}|%{color}' emoji 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split("|");
                if (p.length === 2 && p[0] !== "" && p[1].toLowerCase() === "true") root.emojiFont = p[0];
            }
        }
    }

    readonly property string clipStoreCmd: "cliphist store; id=$(cliphist list | head -n1 | cut -f1); t=\"$HOME/.cache/yukibar/clip-times\"; "
        + "[ -n \"$id\" ] && [ \"$id\" != \"$(tail -n1 \"$t\" 2>/dev/null | cut -f1)\" ] && printf '%s\\t%s\\n' \"$id\" \"$(date +%s)\" >> \"$t\""
    readonly property string clipListCmd: [
        "if ! command -v cliphist >/dev/null 2>&1; then echo '@@MISSING@@'; exit 0; fi",
        "d=\"$HOME/.cache/yukibar\"; mkdir -p \"$d/clip\"; t=\"$d/clip-times\"; touch \"$t\"",
        "l=$(mktemp); cliphist list 2>/dev/null | head -n 300 > \"$l\"",
        "awk -F'\\t' -v now=\"$(date +%s)\" 'FILENAME==ARGV[1]{s[$1]=1;next} !($1 in s){print $1\"\\t\"now}' \"$t\" \"$l\" >> \"$t\"",
        "tail -n 3000 \"$t\" > \"$t.tmp\" && mv \"$t.tmp\" \"$t\"",
        "awk -F'\\t' '$2 ~ /^\\[\\[ binary data/ {print $1}' \"$l\" | head -n 30 | while read -r id; do [ -s \"$d/clip/$id.img\" ] || cliphist decode \"$id\" > \"$d/clip/$id.img\" 2>/dev/null; done",
        "find \"$d/clip\" -type f -mtime +3 -delete 2>/dev/null",
        "cat \"$l\"; echo '@@TIMES@@'; cat \"$t\"; rm -f \"$l\""
    ].join("\n")

    function clipStart() {
        if (clipHistory && barEnabled && settingsReady) clipProbe.running = true;
        else { clipWatchText.running = false; clipWatchImg.running = false; }
    }
    onSettingsReadyChanged: { clipStart(); emojiEnsure(); }
    onClipHistoryChanged: clipStart()
    Process {
        id: clipProbe
        command: ["sh", "-c",
            "if ! command -v wl-paste >/dev/null 2>&1 || ! command -v cliphist >/dev/null 2>&1; then echo missing; exit 0; fi; "
            + "mkdir -p \"$HOME/.cache/yukibar/clip\"; "
            + "for p in $(pgrep -x wl-paste 2>/dev/null); do pp=$(ps -o ppid= -p \"$p\" | tr -d ' '); "
            + "if [ \"$pp\" = 1 ] && tr '\\0' ' ' < /proc/$p/cmdline 2>/dev/null | grep -q '.cache/yukibar'; then kill \"$p\"; fi; done; "
            + "ext=0; for p in $(pgrep -x wl-paste 2>/dev/null); do "
            + "if tr '\\0' ' ' < /proc/$p/cmdline 2>/dev/null | grep -q cliphist; then ext=1; fi; done; "
            + "if [ $ext = 1 ]; then echo external; else echo ok; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipState = text.trim();
                if (root.clipState === "ok") { clipWatchText.running = true; clipWatchImg.running = true; }
            }
        }
    }
    OwnedProcess { id: clipWatchText; cmd: ["wl-paste", "--type", "text", "--watch", "sh", "-c", root.clipStoreCmd, "sh"] }
    OwnedProcess { id: clipWatchImg; cmd: ["wl-paste", "--type", "image", "--watch", "sh", "-c", root.clipStoreCmd, "sh"] }

    function clipRefresh() {
        if (clipLoading) return;
        clipLoading = true;
        clipListProc.running = true;
    }
    Process {
        id: clipListProc
        command: ["sh", "-c", root.clipListCmd]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clipLoading = false;
                if (text.indexOf("@@MISSING@@") === 0) { root.clipState = "missing"; root.clipEntries = []; return; }
                root.clipEntries = root.clipParse(text);
            }
        }
    }
    function clipWhen(ts) {
        if (!ts) return "";
        var d = new Date(ts * 1000), n = new Date();
        var tm = Qt.formatDateTime(d, root.use24h ? "HH:mm" : "h:mm ap");
        var today = new Date(n.getFullYear(), n.getMonth(), n.getDate()).getTime();
        var day = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        if (day === today) return I18n.tr("Copied ") + tm;
        if (day === today - 86400000) return I18n.tr("Copied Yesterday, ") + tm;
        return I18n.tr("Copied ") + I18n.locale().toString(d, "d MMM") + ", " + tm;
    }
    function clipEntry(id, txt, ts) {
        var en = { id: id, text: txt, kind: "text", title: txt, label: I18n.tr("Text"), host: "", thumb: "", color: "" };
        var m = /^\[\[ binary data ([\d.]+ \w+) (\w+) (\d+x\d+) \]\]$/.exec(txt);
        if (m) {
            en.kind = "image";
            en.title = I18n.tr("Image") + " " + m[3].replace("x", "\u00D7");
            en.label = I18n.tr("Image") + " \u2022 " + m[2].toUpperCase() + " \u2022 " + m[1];
            en.thumb = "file://" + clipDir + "/clip/" + id + ".img";
        } else if (/^(https?|ftp):\/\/\S+$/i.test(txt) || /^www\.\S+\.\S+$/i.test(txt)) {
            en.kind = "url";
            en.host = txt.replace(/^[a-z]+:\/\//i, "").split(/[\/?#]/)[0];
            en.label = "URL \u2022 " + en.host;
        } else if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(txt)) {
            en.kind = "color";
            en.color = txt;
            en.label = "Color";
        }
        var w = clipWhen(ts);
        en.sub = en.label + (w !== "" ? " \u2022 " + w : "");
        return en;
    }
    function clipParse(out) {
        var parts = out.split("@@TIMES@@\n");
        var lines = parts[0].split("\n"), tl = (parts[1] || "").split("\n"), times = {}, res = [], i;
        for (i = 0; i < tl.length; i++) {
            var p = tl[i].split("\t");
            if (p.length >= 2) times[p[0]] = parseInt(p[1]);
        }
        for (i = 0; i < lines.length; i++) {
            var tab = lines[i].indexOf("\t");
            if (tab < 1) continue;
            var id = lines[i].substring(0, tab);
            res.push(clipEntry(id, lines[i].substring(tab + 1), times[id] || 0));
        }
        return res;
    }
    function clipRunner(en) { return function () { root.clipPick(en, undefined); }; }
    function clipFiltered(q) {
        q = (q || "").trim().toLowerCase();
        var src = clipEntries, out = [];
        for (var i = 0; i < src.length && out.length < 150; i++) {
            var en = src[i];
            if (q !== "" && en.text.toLowerCase().indexOf(q) < 0 && en.label.toLowerCase().indexOf(q) < 0) continue;
            var it = {};
            for (var k in en) it[k] = en[k];
            it.confirm = false;
            it.run = clipRunner(en);
            out.push(it);
        }
        return out;
    }
    function clipPick(en, paste) {
        var id = parseInt(en.id);
        if (isNaN(id)) return;
        sh("cliphist decode " + id + " | wl-copy");
        if (paste === undefined ? clipAutoPaste : paste) pasteSoon();
    }
    function clipOpen(en) {
        var id = parseInt(en.id);
        if (isNaN(id)) return;
        if (en.kind === "url") { root.openUrl(/^www\./i.test(en.text) ? "https://" + en.text : en.text); return; }
        var ext = en.kind === "image" ? (/(png|jpe?g|webp|gif|bmp)/i.exec(en.label) || ["png"])[0].toLowerCase() : "txt";
        Quickshell.execDetached(["sh", "-c", 'd="${XDG_RUNTIME_DIR:-/tmp}/yukishell-clip"; mkdir -p "$d"; f="$d/clip-$1.$2"; cliphist decode "$1" > "$f" && exec xdg-open "$f"',
                                 "sh", String(id), ext]);
    }
    function clipDelete(en) {
        if (!en) return;
        var id = parseInt(en.id);
        if (isNaN(id)) return;
        clipEntries = clipEntries.filter(function (x) { return x.id !== en.id; });
        sh("printf '%s\\t\\n' " + id + " | cliphist delete; rm -f \"$HOME/.cache/yukibar/clip/" + id + ".img\"");
    }
    function clipClear() {
        clipEntries = [];
        sh("cliphist wipe; rm -f \"$HOME/.cache/yukibar/clip-times\" \"$HOME/.cache/yukibar/clip/\"*");
    }
    property var pasteFn: null
    function pasteSoon() {
        pasteFn = appKind(activeAppId) === "terminal" ? keys(["ctrl", "shift"], "v") : keys(["ctrl"], "v");
        pasteTimer.restart();
    }
    Timer { id: pasteTimer; interval: 230; onTriggered: if (root.pasteFn) root.pasteFn() }

    property var emojiList: EmojiData.list
    property string emojiSource: "bundled"
    property bool emojiTried: false
    readonly property var emojiIndex: {
        var m = {}, L = root.emojiList;
        for (var i = 0; i < L.length; i++) m[L[i][0]] = L[i];
        return m;
    }
    function emojiEnsure() {
        if (emojiTried) return;
        emojiTried = true;
        emojiLoadProc.running = true;
    }
    readonly property string emojiLoadCmd: [
        "t=''; for f in /usr/share/unicode/emoji/emoji-test.txt /usr/share/unicode/ucd/emoji/emoji-test.txt /usr/share/unicode-emoji/emoji-test.txt /usr/local/share/unicode/emoji/emoji-test.txt \"$HOME/.local/share/unicode/emoji-test.txt\"; do [ -r \"$f\" ] && { t=\"$f\"; break; }; done",
        "[ -z \"$t\" ] && t=$(find /usr/share /usr/local/share -maxdepth 6 -name emoji-test.txt 2>/dev/null | head -n1)",
        "[ -z \"$t\" ] && { echo '@@NONE@@'; exit 0; }",
        "echo '@@TEST@@'; grep -E '^(# (sub)?group:|[0-9A-F])' \"$t\"",
        "echo '@@CLDR@@'",
        "for d in annotations annotationsDerived; do f=''; for b in /usr/share/unicode/cldr/common /usr/share/unicode-cldr/common /usr/share/cldr/common /usr/share/unicode/cldr; do [ -r \"$b/$d/en.xml\" ] && { f=\"$b/$d/en.xml\"; break; }; done",
        "  [ -z \"$f\" ] && f=$(find /usr/share /usr/local/share -maxdepth 7 -path \"*/$d/en.xml\" 2>/dev/null | head -n1)",
        "  [ -n \"$f\" ] && grep -h '<annotation ' \"$f\"; done; true"
    ].join("\n")
    Process {
        id: emojiLoadProc
        command: ["sh", "-c", root.emojiLoadCmd]
        stdout: StdioCollector { onStreamFinished: root.emojiLoad(text) }
    }
    function emojiLoad(out) {
        var iT = out.indexOf("@@TEST@@\n"), iC = out.indexOf("@@CLDR@@\n");
        if (iT < 0 || iC < iT) return;
        var testTxt = out.substring(iT + 9, iC), cldrTxt = out.substring(iC + 9), m, i;
        function unesc(x) { return x.replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&"); }
        var kw = {}, re = /<annotation cp="([^"]+)"( type="tts")?>([^<]*)<\/annotation>/g;
        while ((m = re.exec(cldrTxt)) !== null) {
            if (m[2]) continue;
            var key = m[1].replace(/\uFE0F/g, "");
            kw[key] = (kw[key] ? kw[key] + " | " : "") + unesc(m[3]);
        }
        var cats = { "Smileys & Emotion": 0, "People & Body": 1, "Animals & Nature": 2, "Food & Drink": 3, "Travel & Places": 4,
                     "Activities": 5, "Objects": 6, "Symbols": 7, "Flags": 8 };
        var cat = -1, list = [], lines = testTxt.split("\n");
        for (i = 0; i < lines.length; i++) {
            var ln = lines[i];
            if (ln.charAt(0) === "#") {
                m = /^# group: (.+)$/.exec(ln);
                if (m) cat = cats[m[1].trim()] !== undefined ? cats[m[1].trim()] : -1;
                continue;
            }
            if (cat < 0) continue;
            m = /^[0-9A-F ]+;\s*(\S+)\s*#\s*(\S+)\s+E\d+(?:\.\d+)?\s+(.+)$/.exec(ln);
            if (!m || m[1] !== "fully-qualified") continue;
            var name = m[3].trim();
            if (name.indexOf("skin tone") >= 0) continue;
            var extra = (kw[m[2].replace(/\uFE0F/g, "")] || "").replace(/ \| /g, " ");
            list.push([m[2], name, extra, cat, (name + " " + extra).toLowerCase()]);
        }
        if (list.length < 800) return;
        root.emojiList = list;
        root.emojiSource = "system";
    }
    function emojiItems(q, cat) {
        var L = root.emojiList, out = [], i;
        q = (q || "").trim().toLowerCase();
        if (q !== "") {
            var hits = [];
            for (i = 0; i < L.length; i++) {
                var p = L[i][4].indexOf(q);
                if (p < 0) continue;
                var nm = L[i][1].toLowerCase();
                hits.push([nm === q ? 0 : (nm.indexOf(q) === 0 ? 1 : ((" " + L[i][2] + " ").indexOf(" " + q + " ") >= 0 ? 2
                           : (nm.indexOf(" " + q) >= 0 ? 3 : (p === 0 ? 4 : 5)))), i]);
            }
            hits.sort(function (a, b) { return a[0] - b[0] || a[1] - b[1]; });
            for (i = 0; i < hits.length && i < 240; i++) out.push(L[hits[i][1]]);
            return out;
        }
        if (cat === 0) {
            for (i = 0; i < emojiRecent.length; i++) if (emojiIndex[emojiRecent[i]]) out.push(emojiIndex[emojiRecent[i]]);
            return out;
        }
        for (i = 0; i < L.length; i++) if (L[i][3] === cat - 1) out.push(L[i]);
        return out;
    }
    function emojiPick(en) {
        if (!en) return;
        var r = [en[0]];
        for (var i = 0; i < emojiRecent.length && r.length < 24; i++) if (emojiRecent[i] !== en[0]) r.push(emojiRecent[i]);
        emojiRecent = r;
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", en[0]]);
        if (clipAutoPaste) pasteSoon();
    }

    readonly property string logoPath: decodeURIComponent(String(Qt.resolvedUrl("assets/yukishell-logo.png")).replace(/^file:\/\//, ""))
    function iconSrc(name) {
        var fb = Quickshell.iconPath("application-x-executable", true);
        if (!name) return fb;
        if (name.indexOf("/") === 0) return "file://" + name;
        var p = Quickshell.iconPath(name, true);
        return p !== "" ? p : fb;
    }
    readonly property var appList: {
        var vals = DesktopEntries.applications.values, out = [];
        for (var i = 0; i < vals.length; i++) if (!vals[i].noDisplay) out.push(vals[i]);
        out.sort(function (a, b) { return a.name.localeCompare(b.name); });
        return out;
    }
    readonly property var appCats: [
        ["Game", "Games"], ["Office", "Productivity & Finance"], ["Finance", "Productivity & Finance"],
        ["Network", "Internet & Social"], ["WebBrowser", "Internet & Social"], ["Development", "Developer Tools"],
        ["Graphics", "Graphics & Design"], ["AudioVideo", "Music & Video"], ["Audio", "Music & Video"],
        ["Video", "Music & Video"], ["Education", "Education & Science"], ["Science", "Education & Science"],
        ["Settings", "System"], ["System", "System"], ["Utility", "Utilities"]
    ]
    readonly property var catOrder: ["Games", "Productivity & Finance", "Internet & Social", "Developer Tools",
                                     "Graphics & Design", "Music & Video", "Education & Science", "Utilities", "System"]
    function appCategory(e) {
        var c = e.categories || [];
        for (var i = 0; i < appCats.length; i++)
            for (var j = 0; j < c.length; j++)
                if (c[j] === appCats[i][0]) return appCats[i][1];
        return "Utilities";
    }
    readonly property var appSections: {
        var list = appList, usage = appUsage, i, j;
        var used = list.filter(function (e) { return (usage[e.id] || 0) > 0; });
        used.sort(function (a, b) { return (usage[b.id] || 0) - (usage[a.id] || 0); });
        var sug = used.slice(0, 10);
        for (i = 0; i < list.length && sug.length < 5; i++) {
            var dup = false;
            for (j = 0; j < sug.length; j++) if (sug[j].id === list[i].id) { dup = true; break; }
            if (!dup) sug.push(list[i]);
        }
        var map = {};
        for (i = 0; i < list.length; i++) {
            var cat = appCategory(list[i]);
            if (!map[cat]) map[cat] = [];
            map[cat].push(list[i]);
        }
        var secs = [{ name: "Suggestions", apps: sug }];
        for (i = 0; i < catOrder.length; i++) if (map[catOrder[i]]) secs.push({ name: catOrder[i], apps: map[catOrder[i]] });
        return secs;
    }
    function searchApps(q) {
        q = (q || "").trim().toLowerCase();
        if (q === "") return [];
        var list = appList, hits = [];
        for (var i = 0; i < list.length; i++) {
            var e = list[i], n = e.name.toLowerCase(), sc = 0;
            if (n === q) sc = 100;
            else if (n.indexOf(q) === 0) sc = 80;
            else if (n.indexOf(" " + q) >= 0) sc = 60;
            else if (n.indexOf(q) >= 0) sc = 40;
            else if ((e.genericName || "").toLowerCase().indexOf(q) >= 0) sc = 25;
            else if ((e.comment || "").toLowerCase().indexOf(q) >= 0) sc = 10;
            else {
                var kw = e.keywords || [];
                for (var k = 0; k < kw.length; k++) if (String(kw[k]).toLowerCase().indexOf(q) >= 0) { sc = 15; break; }
            }
            if (sc > 0) hits.push({ e: e, s: sc + Math.min(appUsage[e.id] || 0, 20) });
        }
        hits.sort(function (a, b) { return b.s - a.s; });
        return hits.map(function (h) { return h.e; });
    }
    function appSearchSection(q) {
        var r = searchApps(q);
        return r.length > 0 ? [{ name: "Top Hits", apps: r }] : [];
    }
    function launchApp(e, floating) {
        var u = {};
        for (var k in appUsage) u[k] = appUsage[k];
        u[e.id] = (u[e.id] || 0) + 1;
        appUsage = u;
        saveTimer.restart();
        var a = Launch.argv(e, floating === true, terminal);
        if (a) Quickshell.execDetached(a); else e.execute();
    }
    function appRunner(e) { return function (floating) { launchApp(e, floating); }; }
    function appItems(q, limit) {
        var r = searchApps(q), out = [];
        for (var i = 0; i < r.length && i < limit; i++)
            out.push({ title: r[i].name, sub: r[i].genericName || I18n.tr("Application"), icon: iconSrc(r[i].icon),
                       glyph: "", confirm: false, run: appRunner(r[i]) });
        return out;
    }
    function actionItems(q) {
        var all = [
            { title: I18n.tr("Lock Screen"), glyph: "lock", run: function () { root.lockScreen(); } },
            { title: I18n.tr("Sleep"), glyph: "moon", run: function () { root.sleepMachine(); } },
            { title: I18n.tr("System Settings\u2026"), glyph: "gear", run: function () { openSettings(); } },
            { title: I18n.tr("Log Out"), glyph: "logout", confirm: true, run: function () { root.logOut(); } },
            { title: I18n.tr("Restart"), glyph: "restart", confirm: true, run: function () { sh("systemctl reboot"); } },
            { title: I18n.tr("Shut Down"), glyph: "power", confirm: true, run: function () { sh("systemctl poweroff"); } }
        ];
        var s = (q || "").trim().toLowerCase(), out = [];
        for (var i = 0; i < all.length; i++) {
            if (s !== "" && all[i].title.toLowerCase().indexOf(s) < 0) continue;
            out.push({ title: all[i].title, sub: I18n.tr("Action"), icon: "", glyph: all[i].glyph,
                       confirm: all[i].confirm === true, run: all[i].run });
        }
        return out;
    }
    function calcValue(expr) {
        var t=String(expr || "").replace(/[xX×]/g, "*").replace(/÷/g, "/");
        if (!/^[0-9+\-*/%.()\s]+$/.test(t) || !/[0-9]/.test(t)) return null;
        var i=0;
        function ws(){ while(i<t.length && /\s/.test(t[i])) i++; }
        function atom(){ ws(); if(t[i]==="+"){i++;return atom();} if(t[i]==="-"){i++;return -atom();} if(t[i]==="("){i++;var v=sum();ws();if(t[i]!==")")throw 0;i++;return v;} var m=t.substring(i).match(/^(?:\d+(?:\.\d*)?|\.\d+)/);if(!m)throw 0;i+=m[0].length;return Number(m[0]); }
        function term(){ var v=atom(); for(;;){ws();var op=t[i];if(op!=="*"&&op!=="/"&&op!=="%")break;i++;var r=atom();if((op==="/"||op==="%")&&r===0)throw 0;v=op==="*"?v*r:(op==="/"?v/r:v%r);}return v; }
        function sum(){var v=term();for(;;){ws();var op=t[i];if(op!=="+"&&op!=="-")break;i++;var r=term();v=op==="+"?v+r:v-r;}return v;}
        try { var v=sum(); ws(); return i===t.length && isFinite(v) ? v : null; } catch(e){ return null; }
    }
    function conversion(q) {
        var m=(q||"").trim().match(/^(-?\d+(?:\.\d+)?)\s*([a-z°]+)\s+(?:to|in)\s+([a-z°]+)$/i); if(!m)return null;
        var val=Number(m[1]), a=m[2].toLowerCase(), b=m[3].toLowerCase();
        var units={mm:["len",.001],cm:["len",.01],m:["len",1],km:["len",1000],in:["len",.0254],ft:["len",.3048],mi:["len",1609.344],g:["mass",.001],kg:["mass",1],lb:["mass",.45359237],oz:["mass",.0283495],ml:["vol",.001],l:["vol",1],gal:["vol",3.78541],ms:["time",.001],s:["time",1],min:["time",60],h:["time",3600],c:["temp",1],"°c":["temp",1],f:["temp",1],"°f":["temp",1]};
        if(!units[a]||!units[b]||units[a][0]!==units[b][0])return null;
        var result;
        if(units[a][0]==="temp") result=(a==="f"||a==="°f")?(val-32)*5/9:val, result=(b==="f"||b==="°f")?result*9/5+32:result;
        else result=val*units[a][1]/units[b][1];
        return {title:Number(result.toPrecision(7))+" "+b,sub:I18n.tr("Unit conversion"),glyph:"link",run:function(){Quickshell.execDetached(["wl-copy",String(result)]);}};
    }
    function windowItems(q) {
        var out=[], s=(q||"").trim().toLowerCase(); if(!s)return out;
        var ts=Hyprland.toplevels.values;
        for(var i=0;i<ts.length&&out.length<4;i++){
            if(root.hub&&root.hub.tlGhost(ts[i]))continue;
            var t=ts[i], o=t.lastIpcObject||{}, title=String(o.title||t.title||""), cls=String(o["class"]||t.appId||""), app=root.lookup(cls), label=title||app&&app.name||cls;
            if((label+" "+cls+" "+(app?app.name:" ")).toLowerCase().indexOf(s)<0)continue;
            var addr=String(o.address||t.address||""); if(addr!=="" && addr.indexOf("0x")!==0) addr="0x"+addr;
            (function(win,addr,workspace,cl,name,icon){out.push({title:name,sub:I18n.tr("Open Window"),icon:icon||"",glyph:"layers",run:function(){root.swPending={addr:addr,ws:workspace,cls:cl};swFocusTimer.restart();}});})(t,addr,o.workspace&&o.workspace.id>0?o.workspace.id:0,cls,label,app?root.iconSrc(app.icon):"");
        }
        return out;
    }
    function fileItems(q) {
        var out=[], home=Quickshell.env("HOME")||""; for(var i=0;i<fileHits.length&&out.length<60;i++){var path=fileHits[i];out.push({title:path.substring(path.lastIndexOf("/")+1)||path,sub:(home&&path.indexOf(home+"/")===0?"~"+path.substring(home.length):path),path:true,glyph:"folder",run:(function(p){return function(){Quickshell.execDetached(["xdg-open",p]);};})(path)});} return out;
    }
    function homeItems(q) {
        var out = [], s = (q || "").trim().toLowerCase();
        if (s.indexOf("file ") === 0 || s.indexOf("find ") === 0) {
            var fq=s.replace(/^(file|find)\s+/,"").trim(); if(fq!=="" && fileQuery!==fq) updateFileSearch(fq);
            out=fileItems(fq); if(out.length===0) out.push({title:fileSearchPending?I18n.tr("Searching files…"):I18n.tr("No matching files"),sub:I18n.tr("Files"),glyph:"folder",run:function(){}});
            return out;
        }
        if(s.length>0) out=appItems(q,4);
        var cv=conversion(s); if(cv) out.unshift(cv);
        else { var expr=s.replace(/^=\s*/,""); var v=calcValue(expr); if(v!==null && (s.charAt(0)==="=" || /[+*/%xX×÷()]/.test(s))) out.unshift({title:String(Number(v.toPrecision(10))),sub:I18n.tr("Calculator · Return to copy"),glyph:"search",run:function(){Quickshell.execDetached(["wl-copy",String(v)]);}}); }
        var wins=windowItems(q); for(var j=0;j<wins.length&&out.length<6;j++)out.push(wins[j]);
        var acts=actionItems(q); for(var k=0;k<acts.length&&out.length<6;k++)if(acts[k].title.toLowerCase().indexOf(s)===0)out.push(acts[k]);
        return out.slice(0,8);
    }

    function menuModelFor(name) {
        var m = [], i;
        if (name === "apple") {
            m.push(ico(mi("About This Linux", "", function () {
                if (hub && hub.about) hub.about.open();
                else sh(terminal + " -e sh -c 'fastfetch || neofetch; echo; read -p \"Press Enter\" _'");
            }), "m_about"));
            m.push(msep());
            m.push(ico(mi("System Settings\u2026", hk("System Settings"), function () { root.openSettings(); }), "gear"));
            m.push(msep());
            m.push(ico(mi("Sleep", "", function () { root.sleepMachine(); }), "moon"));
            m.push(ico(mc("Restart\u2026", function () { sh("systemctl reboot"); }), "m_restart"));
            m.push(ico(mc("Shut Down\u2026", function () { sh("systemctl poweroff"); }), "m_power"));
            m.push(msep());
            m.push(ico(mi("Lock Screen", hk("Lock Screen"), function () { root.lockScreen(); }), "m_lock"));
            m.push(ico(mc("Log Out\u2026", function () { root.logOut(); }), "m_logout"));
        } else {
            var id = activeAppId.toLowerCase(), kind = appKind(id), has = activeAppId !== "";
            var aw = (has && activeWin && String(activeWin["class"]).toLowerCase() === id) ? activeWin : null;
            var term = kind === "terminal", browser = kind === "browser", files = kind === "files", editor = kind === "editor";
            var floating = aw ? aw.floating === true : false, fsMode = aw ? Number(aw.fullscreen) : 0;
            var n = appName;

            if (name === "app") {
                if (!has) {
                    m.push(mi("New Terminal", hk("Open Terminal"), function () { sh(terminal); }));
                    m.push(mi("Open Home Folder", hk("Open Files"), function () { sh(filesCmd); }));
                    m.push(msep());
                    m.push(mi("Search\u2026", hk("Spotlight"), function () { root.search(); }));
                } else {
                    m.push(mi(I18n.tr("About ") + n, "", function () { root.aboutActive(aw, n); }));
                    if (editor || files) {
                        m.push(msep());
                        m.push((files ? mi("Preferences\u2026", "Ctrl+Shift+,", keys(["ctrl", "shift"], "comma")) : mi("Preferences\u2026", "Ctrl+,", keys(["ctrl"], "comma"))));
                    }
                    m.push(msep());
                    m.push(mi(I18n.tr("Hide ") + n, hk("Hide or Show Window"), function () { root.sh("~/.config/hypr/bin/hide-window hide"); }));
                    m.push(mi("Show Hidden Windows", "", function () { root.sh("~/.config/hypr/bin/hide-window show"); }));
                    m.push(msep());
                    m.push(mi(I18n.tr("Quit ") + n, (term || (browser && !/firefox|librewolf|floorp|zen|waterfox/.test(id))) ? "Ctrl+Shift+Q" : "Ctrl+Q", function () { root.quitActive(); }));
                    var fq = mc(I18n.tr("Force Quit ") + n, function () { root.forceQuitActive(aw); }); fq.shortcut = hk("Force Quit Window"); m.push(fq);
                }
            } else if (name === "file") {
                if (!has) {
                    m.push(mi("New Terminal", hk("Open Terminal"), function () { sh(terminal); }));
                    m.push(mi("New Files Window", hk("Open Files"), function () { sh(filesCmd); }));
                } else {
                    m.push(mi("New Window", term ? "Ctrl+Shift+N" : ((browser || files || editor) ? "Ctrl+N" : ""), function () { root.launchActive(); }));
                    if (browser) {
                        var ff = /firefox|librewolf|floorp|zen|waterfox/.test(id);
                        m.push(mi("New Private Window", ff ? "Ctrl+Shift+P" : "Ctrl+Shift+N", keys(["ctrl", "shift"], ff ? "p" : "n")));
                    }
                    if (browser || files) m.push(mi("New Tab", "Ctrl+T", keys(["ctrl"], "t")));
                    if (term) m.push(mi("New Tab", "Ctrl+Shift+T", keys(["ctrl", "shift"], "t")));
                    if (browser) m.push(mi("Reopen Closed Tab", "Ctrl+Shift+T", keys(["ctrl", "shift"], "t")));
                    if (!term && !files) m.push(mi("Open\u2026", "Ctrl+O", keys(["ctrl"], "o")));
                    if (!term && !files) {
                        m.push(msep());
                        m.push(mi(browser ? "Save Page As\u2026" : "Save", "Ctrl+S", keys(["ctrl"], "s")));
                        if (!browser) m.push(mi("Save As\u2026", "Ctrl+Shift+S", keys(["ctrl", "shift"], "s")));
                        m.push(mi("Print\u2026", "Ctrl+P", keys(["ctrl"], "p")));
                    }
                    m.push(msep());
                    if (browser || files || editor) m.push(mi("Close Tab", "Ctrl+W", keys(["ctrl"], "w")));
                    if (term) m.push(mi("Close Tab", "Ctrl+Shift+W", keys(["ctrl", "shift"], "w")));
                    m.push(mi("Close Window", hk("Close Window"), disp('hl.dsp.window.close()')));
                }
                m.push(msep());
                if (aw) m.push(mi("Screenshot Window", hk("Screenshot a Window"), function () { root.shotWindow(aw); }));
                m.push(mi("Screenshot Selection\u2026", hk("Screenshot a Region"), function () { root.shot("sel"); }));
                m.push(mi("Screenshot Screen", hk("Screenshot the Screen"), function () { root.shot(""); }));
                m.push(mi(root.recording ? "Stop Screen Recording" : "Start Screen Recording", hk("Start or Stop Screen Recording"), function () { root.toggleRecording(); }));
                m.push(mi("Pick Color", hk("Pick Color"), function () { root.pickColor(); }));
            } else if (name === "edit") {
                if (has && term) {
                    m.push(mi("Copy", "Ctrl+Shift+C", keys(["ctrl", "shift"], "c")));
                    m.push(mi("Paste", "Ctrl+Shift+V", keys(["ctrl", "shift"], "v")));
                } else if (has) {
                    m.push(mi("Undo", "Ctrl+Z", keys(["ctrl"], "z")));
                    m.push(mi("Redo", "Ctrl+Shift+Z", keys(["ctrl", "shift"], "z")));
                    m.push(msep());
                    m.push(mi("Cut", "Ctrl+X", keys(["ctrl"], "x")));
                    m.push(mi("Copy", "Ctrl+C", keys(["ctrl"], "c")));
                    m.push(mi("Paste", "Ctrl+V", keys(["ctrl"], "v")));
                    if (browser || editor) m.push(mi("Paste and Match Style", "Ctrl+Shift+V", keys(["ctrl", "shift"], "v")));
                    m.push(mi("Select All", "Ctrl+A", keys(["ctrl"], "a")));
                    m.push(msep());
                    m.push(mi("Find\u2026", "Ctrl+F", keys(["ctrl"], "f")));
                }
                if (has) m.push(msep());
                m.push(mi("Clipboard History\u2026", hk("Clipboard History"), function () { root.spotOpen("clip"); }));
                m.push(mi("Emoji & Symbols", hk("Emoji Picker"), function () { root.spotOpen("emoji"); }));
            } else if (name === "view") {
                if (has) {
                    m.push(mi(fsMode === 2 ? "Exit Full Screen" : "Enter Full Screen", hk("Full Screen"), disp('hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })')));
                    m.push(msep());
                    m.push(mchk("Floating", hk("Toggle Floating"), floating, disp('hl.dsp.window.float({ action = "toggle" })')));
                    m.push(dis(mchk("Pin to All Workspaces", hk("Pin Window to All Workspaces"), aw && aw.pinned === true, disp('hl.dsp.window.pin({ action = "toggle" })')), !floating));
                    m.push(dis(mi("Center Window", hk("Center Window"), disp('hl.dsp.window.center()')), !floating));
                    m.push(dis(mi("Toggle Split Direction", hk("Toggle Split Direction"), disp('hl.dsp.layout("togglesplit")')), floating));
                    if (!term) {
                        m.push(msep());
                        m.push(mi("Actual Size", "Ctrl+0", keys(["ctrl"], "0")));
                        m.push(mi("Zoom In", "Ctrl+=", keys(["ctrl"], "equal")));
                        m.push(mi("Zoom Out", "Ctrl+-", keys(["ctrl"], "minus")));
                    }
                    if (browser || files) {
                        m.push(msep());
                        m.push(mi("Reload", "F5", keys([], "F5")));
                        if (browser) {
                            m.push(mi("Reload Ignoring Cache", "Ctrl+Shift+R", keys(["ctrl", "shift"], "r")));
                            m.push(mi("Developer Tools", "F12", keys([], "F12")));
                        }
                    }
                } else m.push(mi("Wallpapers", hk("Wallpapers"), function () { root.wpToggle(); }));
            } else if (name === "window") {
                if (has) {
                    m.push(mi("Minimize", hk("Minimize Window"), disp('hl.dsp.window.move({ workspace = "special:minimized", follow = false })')));
                    m.push(mchk("Zoom", hk("Maximize Window"), fsMode === 1, disp('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })')));
                    m.push(mi(floating ? "Tile Window" : "Float Window", hk("Toggle Floating"), disp('hl.dsp.window.float({ action = "toggle" })')));
                    m.push(msep());
                    m.push(mi("Move Window Left", hk("Swap Window with Neighbour"), disp('hl.dsp.window.swap({ direction = "left" })')));
                    m.push(mi("Move Window Right", hk("Swap Window with Neighbour").replace("\u2190", "\u2192"), disp('hl.dsp.window.swap({ direction = "right" })')));
                    m.push(mi("Make Wider", hk("Resize Window").replace("\u2190", "\u2192"), disp('hl.dsp.window.resize({ x = 100, y = 0, relative = true })')));
                    m.push(mi("Make Narrower", hk("Resize Window"), disp('hl.dsp.window.resize({ x = -100, y = 0, relative = true })')));
                    if (Quickshell.screens.length > 1) m.push(mi("Move to Next Monitor", hk("Move Window to Next Monitor"), disp('hl.dsp.window.move({ monitor = "+1" })')));
                    m.push(mi("Move to Next Workspace", hk("Move Window to Next Workspace"), disp('hl.dsp.window.move({ workspace = "+1" })')));
                    m.push(mi("Move to Previous Workspace", hk("Move Window to Previous Workspace"), disp('hl.dsp.window.move({ workspace = "-1" })')));
                    m.push(msep());
                }
                m.push(mi("Show Hidden Windows", "", function () { root.sh("~/.config/hypr/bin/hide-window show"); }));
                m.push(mi("Show Minimized Windows", hk("Show Minimized Windows"), disp('hl.dsp.workspace.toggle_special("minimized")')));
                var tls = ToplevelManager.toplevels.values;
                if (tls.length > 0) m.push(msep());
                for (i = 0; i < tls.length && i < 8; i++) {
                    (function (w) {
                        var t = (w.title && w.title.length > 0) ? w.title : w.appId;
                        m.push(mchk(t, "", w.activated, function () { w.activate(); }));
                    })(tls[i]);
                }
            } else if (name === "help") {
                m.push(mi("Search\u2026", hk("Spotlight"), function () { root.search(); }));
                if (has) m.push(mi(n + " Help", "", function () { root.helpFor(id, n); }));
                m.push(msep());
                m.push(mi("Hyprland Keybinds", "", function () { root.openUrl("https://github.com/xuefeng1331/YukiShell#keybinds"); }));
                m.push(mi("Reload Hyprland Config", hk("Reload Hyprland Config"), function () { Quickshell.execDetached(["hyprctl", "reload"]); }));
                m.push(msep());
                m.push(mi("Hyprland Wiki", "", function () { root.openUrl("https://wiki.hypr.land"); }));
                m.push(mi("Quickshell Documentation", "", function () { root.openUrl("https://quickshell.org/docs"); }));
            }
        }
        return m;
    }

    property bool shotOpen: false
    property bool shotBusy: false
    property int shotId: 0
    readonly property string shotTmp: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string shotFinishScript: [
        "d=\"$1\"; sv=\"$2\"; cl=\"$3\"; nt=\"$4\"; tmp=\"$5\"; g=\"$6\"",
        "if [ \"$g\" = '@' ]; then :; elif [ -n \"$g\" ]; then grim -g \"$g\" \"$tmp\"; else grim \"$tmp\"; fi || exit 1",
        "[ -s \"$tmp\" ] || exit 1",
        "f=\"$tmp\"",
        "if [ \"$sv\" = 1 ]; then",
        "  [ -z \"$d\" ] && d=\"$HOME/Pictures/Screenshots\"",
        "  case \"$d\" in '~') d=\"$HOME\";; '~/'*) d=\"$HOME/${d#'~/'}\";; esac",
        "  n=\"$d/Screenshot-$(date +%F_%H-%M-%S).png\"",
        "  mkdir -p \"$d\" && mv -f \"$tmp\" \"$n\" && f=\"$n\"",
        "fi",
        "[ \"$cl\" = 1 ] && wl-copy --type image/png < \"$f\"",
        "if [ \"$nt\" = 1 ]; then if [ \"$f\" = \"$tmp\" ]; then notify-send -a yukibar 'Screenshot copied' 'Copied to the clipboard'; else notify-send -a yukibar 'Screenshot saved' \"$f\"; fi; fi",
        "[ \"$f\" = \"$tmp\" ] && rm -f \"$tmp\"",
        "true"
    ].join("\n")
    function shotFinish(geom, tmpPath) {
        playSound("shutter", 0.8);
        var tmp = tmpPath || (shotTmp + "/yukishot-out-" + Date.now() + ".png");
        var save = screenshotSave || !screenshotClipboard;
        Quickshell.execDetached(["sh", "-c", shotFinishScript, "sh", screenshotDir, save ? "1" : "0", screenshotClipboard ? "1" : "0",
                                 screenshotNotify ? "1" : "0", tmp, geom]);
    }
    function shotStart() {
        if (shotOpen) { shotClose(); return; }
        if (shotBusy) return;
        var scr = Quickshell.screens, names = [];
        for (var i = 0; i < scr.length; i++) names.push(scr[i].name);
        if (names.length === 0) return;
        shotBusy = true;
        shotId++;
        shotSnap.command = ["sh", "-c",
            "d=\"$1\"; i=\"$2\"; shift 2; for n in \"$@\"; do grim -t ppm -o \"$n\" \"$d/yukishot-$i-$n.ppm\" & done; wait; "
            + "for n in \"$@\"; do [ -s \"$d/yukishot-$i-$n.ppm\" ] || exit 1; done", "sh", shotTmp, String(shotId)].concat(names);
        shotSnap.running = true;
    }
    function shotClose() {
        shotOpen = false;
        Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"/yukishot-*.ppm", "sh", shotTmp]);
    }
    Process {
        id: shotSnap
        onExited: (code, status) => {
            root.shotBusy = false;
            if (code === 0) root.shotOpen = true;
            else root.shotClose();
        }
    }
    IpcHandler {
        target: "actions"
        function recording(): void { root.toggleRecording(); }
        function pickColor(): void { root.pickColor(); }
    }
    IpcHandler {
        target: "screenshot"
        function region(): void { root.shotStart(); }
        function screen(): void { root.shotFinish("", ""); }
        function window(): void { root.shotWindow(root.activeWin); }
    }
    Variants {
        model: root.shotOpen ? Quickshell.screens : []
        PanelWindow {
            id: shw
            required property var modelData
            screen: modelData
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "yukishot"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property url snap: "file://" + root.shotTmp + "/yukishot-" + root.shotId + "-" + modelData.name + ".ppm"
            readonly property real k: frozen.implicitWidth > 0 ? frozen.implicitWidth / width : 1
            property real ax: 0
            property real ay: 0
            property real px: 0
            property real py: 0
            property real selX: 0
            property real selY: 0
            property real selW: 0
            property real selH: 0
            property bool dragging: false
            property bool grabbing: false
            readonly property bool hasSel: selW > 1 && selH > 1

            function capture(x, y, w, h) {
                if (grabbing) return;
                grabbing = true;
                selX = Math.round(x); selY = Math.round(y); selW = Math.round(w); selH = Math.round(h);
                grabTimer.restart();
            }
            Timer {
                id: grabTimer
                interval: 40
                onTriggered: {
                    var out = root.shotTmp + "/yukishot-out-" + Date.now() + ".png";
                    var kk = shw.k;
                    var ok = cut.grabToImage(function (res) {
                        var saved = res.saveToFile(out);
                        root.shotClose();
                        if (saved) root.shotFinish("@", out);
                    }, Qt.size(Math.max(1, Math.round(shw.selW * kk)), Math.max(1, Math.round(shw.selH * kk))));
                    if (!ok) root.shotClose();
                }
            }

            Item {
                id: sroot
                anchors.fill: parent
                focus: true
                Component.onCompleted: forceActiveFocus()
                NumberAnimation on opacity { from: 0; to: 1; duration: 120 }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { root.shotClose(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        shw.capture(0, 0, shw.width, shw.height);
                        event.accepted = true;
                    }
                }

                Image { id: frozen; anchors.fill: parent; source: shw.snap; fillMode: Image.Stretch; smooth: true }
                // the glass pills sample (and so hide) their backdrop: give them a copy of the frozen screen
                Image { id: frozenGlass; anchors.fill: parent; source: shw.snap; fillMode: Image.Stretch; opacity: 0 }
                Rectangle { anchors.fill: parent; color: "black"; opacity: 0.42 }

                Item {
                    id: cut
                    visible: shw.hasSel
                    x: shw.selX; y: shw.selY; width: shw.selW; height: shw.selH
                    clip: true
                    Image { x: -cut.x; y: -cut.y; width: shw.width; height: shw.height; source: shw.snap; fillMode: Image.Stretch; smooth: true }
                }
                Rectangle {
                    visible: shw.hasSel && !shw.grabbing
                    x: cut.x - 1; y: cut.y - 1; width: cut.width + 2; height: cut.height + 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: "white"
                }

                Rectangle {
                    visible: shw.hasSel && !shw.grabbing
                    x: Math.max(8, Math.min(shw.width - width - 8, shw.px + 14))
                    y: Math.max(8, Math.min(shw.height - height - 8, shw.py + 18))
                    width: sizeTxt.implicitWidth + 18; height: 24; radius: 12
                    color: "transparent"
                    LGlass {
                        anchors.fill: parent; z: -1
                        backdrop: frozenGlass; shaderUrl: root.glassShaderUrl; liquid: root.liquidActive; dark: true
                        bx: parent.x; by: parent.y; cornerR: height / 2
                        tint: root.glassOpacity; thickness: 14; strength: root.glassLiquidEff; rim: root.glassRimEff
                        grain: root.glassGrain; blur: root.glassBlurEff; shadowAmt: 0; flatInner: 1
                    }
                    Text {
                        id: sizeTxt
                        anchors.centerIn: parent
                        text: Math.round(shw.selW * shw.k) + " \u00D7 " + Math.round(shw.selH * shw.k)
                        color: "white"
                        font.family: root.fontForWeight(Font.Medium, root.fontFamily); font.pixelSize: 12; font.weight: Font.Medium
                    }
                }
                Rectangle {
                    visible: !shw.hasSel && !shw.grabbing
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 56
                    width: hintTxt.implicitWidth + 28; height: 32; radius: 16
                    color: "transparent"
                    LGlass {
                        anchors.fill: parent; z: -1
                        backdrop: frozenGlass; shaderUrl: root.glassShaderUrl; liquid: root.liquidActive; dark: true
                        bx: parent.x; by: parent.y; cornerR: height / 2
                        tint: root.glassOpacity; thickness: 14; strength: root.glassLiquidEff; rim: root.glassRimEff
                        grain: root.glassGrain; blur: root.glassBlurEff; shadowAmt: 0; flatInner: 1
                    }
                    Text {
                        id: hintTxt
                        anchors.centerIn: parent
                        text: I18n.tr("Drag to select an area   \u2022   Return: whole screen   \u2022   Esc: cancel")
                        color: "white"
                        font.family: root.fontForWeight(Font.Normal, root.fontFamily); font.pixelSize: 13
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.CrossCursor
                    onPressed: m => {
                        if (m.button === Qt.RightButton) { root.shotClose(); return; }
                        if (shw.grabbing) return;
                        shw.dragging = true;
                        shw.ax = m.x; shw.ay = m.y; shw.px = m.x; shw.py = m.y;
                        shw.selX = m.x; shw.selY = m.y; shw.selW = 0; shw.selH = 0;
                    }
                    onPositionChanged: m => {
                        shw.px = m.x; shw.py = m.y;
                        if (!shw.dragging) return;
                        var x2 = Math.max(0, Math.min(shw.width, m.x)), y2 = Math.max(0, Math.min(shw.height, m.y));
                        shw.selX = Math.min(shw.ax, x2); shw.selY = Math.min(shw.ay, y2);
                        shw.selW = Math.abs(x2 - shw.ax); shw.selH = Math.abs(y2 - shw.ay);
                    }
                    onReleased: m => {
                        if (!shw.dragging) return;
                        shw.dragging = false;
                        if (shw.selW >= 4 && shw.selH >= 4) shw.capture(shw.selX, shw.selY, shw.selW, shw.selH);
                        else { shw.selW = 0; shw.selH = 0; }
                    }
                }
            }
        }
    }

    readonly property bool videoWall: wallpaperVideo !== ""
    property var wallPaused: ({})
    property string wallCovList: "?"
    property var screenCovered: ({})
    property var screenFullscreen: ({})
    function wallHold(name) { return wallUserPaused || (wallPauseCovered && screenCovered[name] === true); }
    function wallIdle(name) { return gaming || wallHold(name); }

    readonly property QtObject wallClock: QtObject {
        property bool ok: false
        property real pos: 0
        property real at: 0
    }
    readonly property bool wallClockWanted: glassVideo !== "" && Quickshell.screens.length > 0 && !wallIdle(Quickshell.screens[0].name)
    onWallClockWantedChanged: { if (!wallClockWanted) { wallClock.ok = false; mpvSock.connected = false; } }
    property real wallClockAsked: 0
    Socket {
        id: mpvSock
        path: Quickshell.screens.length > 0 ? Quickshell.env("XDG_RUNTIME_DIR") + "/yukishell-mpv-" + Quickshell.screens[0].name + ".sock" : ""
        parser: SplitParser {
            onRead: line => {
                var o; try { o = JSON.parse(line); } catch (e) { return; }
                if (o.request_id !== 71) return;
                if (typeof o.data !== "number") { root.wallClock.ok = false; return; }
                var now = Date.now();
                root.wallClock.pos = o.data;
                root.wallClock.at = now - Math.min(20, (now - root.wallClockAsked) / 2);
                root.wallClock.ok = true;
            }
        }
        onConnectedChanged: { if (!connected) root.wallClock.ok = false; }
    }
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.wallClockWanted
        onTriggered: {
            if (!mpvSock.connected) { mpvSock.connected = true; return; }
            root.wallClockAsked = Date.now();
            mpvSock.write('{"command":["get_property","time-pos"],"request_id":71}\n');
            mpvSock.flush();
        }
    }
    readonly property string wallPauseScript: Quickshell.env("HOME") + "/.config/hypr-yukishell/scripts/yukishell-wallpause.sh"
    function wallApply() {
        if (!videoWall) return;
        var next = {}, names = Object.keys(screenCovered);
        if (names.length === 0) return;
        for (var i = 0; i < names.length; i++) next[names[i]] = wallHold(names[i]);
        for (var k in next) if (next[k] !== (wallPaused[k] === true))
            Quickshell.execDetached([wallPauseScript, k, next[k] ? "pause" : "resume"]);
        var cov = []; for (var n in next) if (next[n]) cov.push(n);
        if (cov.join(",") !== wallCovList) {
            wallCovList = cov.join(",");
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$@\" > \"${XDG_RUNTIME_DIR:-/tmp}/yukishell-wallpaused\"", "sh"].concat(cov));
        }
        wallPaused = next;
    }
    onWallUserPausedChanged: wallApply()
    onWallPauseCoveredChanged: wallApply()
    Process {
        id: coverProbe
        command: ["sh", "-c", "printf '{\"m\":'; hyprctl -j monitors; printf ',\"c\":'; hyprctl -j clients; printf '}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var o; try { o = JSON.parse(text); } catch (e) { return; }
                var next = {}, fullMap = {};
                for (var i = 0; i < o.m.length; i++) {
                    var m = o.m[i], ws = m.activeWorkspace ? m.activeWorkspace.id : -999, mw = m.width / (m.scale || 1), mh = m.height / (m.scale || 1);
                    var area = 0, full = false;
                    for (var j = 0; j < o.c.length; j++) {
                        var c = o.c[j];
                        if (!c.mapped || c.hidden || c.monitor !== m.id || c.workspace.id !== ws) continue;
                        if (c.fullscreen > 0 || c.fullscreen === true) { full = true; break; }
                        if (!c.floating) area += Math.min(c.size[0], mw) * Math.min(c.size[1], mh);
                    }
                    next[m.name] = full || area >= mw * mh * 0.86;
                    fullMap[m.name] = full;
                }
                var sameF = true;
                for (var f in fullMap) if (fullMap[f] !== (root.screenFullscreen[f] === true)) sameF = false;
                if (!sameF) root.screenFullscreen = fullMap;
                var same = Object.keys(next).length === Object.keys(root.screenCovered).length;
                for (var q in next) if (!(q in root.screenCovered) || next[q] !== (root.screenCovered[q] === true)) same = false;
                if (!same) root.screenCovered = next;
                root.wallApply();
            }
        }
    }
    Timer { id: coverDelay; interval: 300; onTriggered: if (!coverProbe.running) coverProbe.running = true }
    Timer { interval: 1500; running: true; onTriggered: coverDelay.restart() }
    onVideoWallChanged: { wallPaused = ({}); if (videoWall) coverDelay.restart(); else wallUserPaused = false; }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "workspacev2" || n === "fullscreen"
                || n === "changefloatingmode" || n === "focusedmonv2" || n === "activespecialv2") coverDelay.restart();
        }
    }

    property var glassProxy: ({})
    property var glassProxyFailed: ({})
    property string glassProxyFor: ""
    readonly property int glassProxyWidth: 720
    readonly property int glassProxyFps: 60
    Loader {
        id: wallPlayer
        Component.onCompleted: setSource(Qt.resolvedUrl("WallPlayer.qml"), { host: root })
        onStatusChanged: if (status === Loader.Error) console.log("[yukibar] YukiVideo plugin not installed: every window plays the glass video itself (tools/build-plugins)")
    }
    readonly property string glassVideo: {
        if (!liveWallGlass || wallpaperVideo === "") return "";
        var p = glassProxy[wallpaperVideo];
        if (p) return p;
        return glassProxyFailed[wallpaperVideo] === true ? wallpaperVideo : "";
    }
    function glassProxyEnsure() {
        if (!liveWallGlass || wallpaperVideo === "" || glassProxy[wallpaperVideo] || glassProxyFailed[wallpaperVideo] === true) return;
        if (glassProxyBuild.running) return;
        glassProxyFor = wallpaperVideo;
        glassProxyBuild.command = ["sh", "-c", [
            'v="$1"; w="$2"; f="$3"',
            'command -v ffmpeg >/dev/null 2>&1 || exit 1',
            'd="$HOME/.cache/yukishell/glass"; mkdir -p "$d"',
            'find "$d" -name "*.mp4" -mtime +60 -delete 2>/dev/null',
            'k="$(printf "%s:%s:%s:%s" "$v" "$(stat -c %Y "$v" 2>/dev/null)" "$w" "$f" | md5sum | cut -c1-16)"',
            'o="$d/$k.mp4"',
            'if [ ! -s "$o" ]; then',
            '  t="$d/$k.part.mp4"',
            '  nice -n 15 ffmpeg -loglevel error -y -i "$v" -an -sn -dn -vf "scale=\'min($w,iw)\':-2" -fpsmax "$f" -c:v libx264 -preset veryfast -crf 30 -pix_fmt yuv420p -g 60 -movflags +faststart -f mp4 "$t" </dev/null >/dev/null 2>&1 \\',
            '    && mv -f "$t" "$o" || { rm -f "$t"; exit 1; }',
            'fi',
            'printf "P:%s\\n" "$o"'
        ].join("\n"), "sh", glassProxyFor, String(glassProxyWidth), String(glassProxyFps)];
        glassProxyBuild.running = true;
    }
    Process {
        id: glassProxyBuild
        stdout: StdioCollector {
            onStreamFinished: {
                var m = /^P:(.+)$/m.exec(text);
                var v = root.glassProxyFor;
                if (m) { var ok = Object.assign({}, root.glassProxy); ok[v] = m[1]; root.glassProxy = ok; }
            }
        }
        onExited: (code, status) => {
            var v = root.glassProxyFor;
            if (code !== 0 && !root.glassProxy[v]) { var bad = Object.assign({}, root.glassProxyFailed); bad[v] = true; root.glassProxyFailed = bad; }
            root.glassProxyFor = "";
            root.glassProxyEnsure();
        }
    }
    onLiveWallGlassChanged: glassProxyEnsure()
    onWallpaperVideoChanged: glassProxyEnsure()
    Timer { interval: 2500; running: true; onTriggered: root.glassProxyEnsure() }

    readonly property string gamingScript: Quickshell.env("HOME") + "/.config/hypr-yukishell/scripts/yukishell-gaming.sh"
    property bool gamingApplied: false
    onGamingChanged: gamingApply.restart()
    Timer {
        id: gamingApply
        interval: 150
        onTriggered: {
            if (!root.settingsReady || root.gaming === root.gamingApplied) return;
            root.gamingApplied = root.gaming;
            Quickshell.execDetached([root.gamingScript, root.gaming ? "on" : "off"]);
            if (root.uiSounds) Quickshell.execDetached(["pw-play", "--volume=0.6", root.soundDir + "/tink.wav"]);
        }
    }
    Timer { interval: 1500; running: true; onTriggered: { if (!root.gaming) Quickshell.execDetached([root.gamingScript, "off"]); else gamingApply.restart(); } }
    readonly property var gameClassRe: /^(steam_app_\d+|gamescope|org\.vinegarhq\.sober|sober|robloxplayer.*|minecraft.*|com\.mojang.*|lutris|heroic|.*\.exe|osu!?|cs2|dota2|hl2_linux|factorio|terraria.*|stardew.*)$/i
    Process {
        id: gameProbe
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                var w = {};
                try { w = JSON.parse(text || "{}"); } catch (e) { w = {}; }
                var cls = (w["class"] || w.initialClass || "");
                root.gamingAutoActive = root.gamingAuto && ((w.fullscreen & 2) !== 0 || w.fullscreen === true) && root.gameClassRe.test(cls);
            }
        }
    }
    Timer { id: gameProbeDelay; interval: 250; onTriggered: if (!gameProbe.running) gameProbe.running = true }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n === "fullscreen" || n === "activewindowv2" || n === "closewindow" || n === "workspacev2") gameProbeDelay.restart();
        }
    }
    onGamingAutoChanged: { if (!gamingAuto) gamingAutoActive = false; else gameProbeDelay.restart(); }

    readonly property string settingsSig: settingKeys.map(function (k) { return (k === "ccSizes" || k === "ccPos") ? JSON.stringify(root[k]) : String(root[k]); }).join("|")
    property bool settingsReady: false
    onSettingsSigChanged: if (settingsReady) saveTimer.restart()
    Timer { id: saveTimer; interval: 400; onTriggered: root.saveSettings() }

    function saveSettings() {
        if (ccSnap) return;
        var o = {};
        for (var i = 0; i < settingKeys.length; i++) {
            var k = settingKeys[i];
            o[k] = (k === "accent") ? String(root[k]) : root[k];
        }
        store.setText(JSON.stringify(o, null, 2));
    }
    function applySettings(o, keysToApply) {
        if (!o || typeof o !== "object") return;
        for (var i = 0; i < keysToApply.length; i++) {
            var k = keysToApply[i];
            if (o[k] === undefined) continue;
            try { root[k] = o[k]; } catch (err) { }
        }
    }
    FileView {
        id: dockStore
        path: root.dockConfigDir + "/settings.json"
        printErrors: false
        onLoaded: {
            try {
                var o = JSON.parse(text());
                root.applySettings(o, ["accent", "accentUi", "fontFamily", "glassOpacity", "glassRim", "glassGrain", "glassLiquid", "glassBlur", "wallpaperPath"]);
                if (o.dockStyle !== undefined) root.barStyle = (o.dockStyle === "liquid") ? "liquid" : "blur";
            } catch (err) { }
            store.path = root.configDir + "/settings.json";
        }
        onLoadFailed: store.path = root.configDir + "/settings.json"
    }
    FileView {
        id: store
        path: ""
        printErrors: false
        onLoaded: {
            try {
                var saved = JSON.parse(text());
                root.applySettings(saved, root.settingKeys);
                if (saved.ccRowH === undefined && saved.ccTileSize !== undefined) root.ccRowH = ({ compact: 56, regular: 66, large: 78 })[saved.ccTileSize] || 66;
                if (saved.ccGapPx === undefined && saved.ccSpacing !== undefined) root.ccGapPx = ({ tight: 3, normal: 6, loose: 10 })[saved.ccSpacing] || 6;
            } catch (err) { }
            if ((root.wallpaperDirs || []).length === 0 && (root.wallpaperDir || "").trim() !== "") root.wallpaperDirs = [root.wallpaperDir.trim()];
            root.wallpaperDir = "";
            if (!root.ccMigGame) {
                root.ccMigGame = true;
                var cg = root.ccControls.slice();
                if (cg.indexOf("gaming") < 0) { var ri = cg.indexOf("record"); cg.splice(ri >= 0 ? ri + 1 : cg.length, 0, "gaming"); root.ccControls = cg; }
            }
            if (!root.ccMigRec) {
                root.ccMigRec = true;
                var cl = root.ccControls.slice();
                if (cl.indexOf("record") < 0) { var fi = cl.indexOf("focus"); cl.splice(fi >= 0 ? fi + 1 : cl.length, 0, "record"); root.ccControls = cl; }
            }
            if (root.ccControls.indexOf("darkmode") >= 0)
                root.ccControls = root.ccControls.filter(function (x) { return x !== "darkmode"; });
            root.settingsReady = true;
            inputApplyT.restart();
            cursorApplyT.restart();
            borderApplyT.restart();
            if (root.barStyle !== "normal") root.startGlass();
        }
        onLoadFailed: { root.ccMigRec = true; root.ccMigGame = true; root.settingsReady = true; if (root.barStyle !== "normal") root.startGlass(); }
    }

    property string glassState: "idle"
    readonly property bool liquidBase: barStyle !== "normal" && glassState === "ready" && !gaming
    property bool glassWarm: false
    readonly property bool glassWarmWanted: liquidBase && (!hub || hub.wallpaperReady)
    onGlassWarmWantedChanged: { if (glassWarmWanted) glassWarmT.restart(); else { glassWarmT.stop(); glassWarm = false; } }
    Timer { id: glassWarmT; interval: 350; onTriggered: root.glassWarm = true }
    readonly property bool liquidActive: liquidBase && glassWarm
    readonly property string glassShaderSrc: decodeURIComponent(Qt.resolvedUrl("liquidglass.frag").toString().replace("file://", ""))
    readonly property string glassShaderOut: configDir + "/liquidglass.frag.qsb"
    readonly property url glassShaderUrl: "file://" + glassShaderOut

    onBarStyleChanged: if (barStyle !== "normal") startGlass()
    onGlassStateChanged: console.log("[yukibar-glass] state:", glassState)
    function startGlass() {
        if (glassState === "ready" || glassState === "building") return;
        glassState = "building";
        qsbProc.running = true;
        hub.refreshWallpaper();
    }
    Process {
        id: qsbProc
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\"; "
            + "[ -s \"$2\" ] && [ \"$2\" -nt \"$1\" ] && exit 0; "
            + "for q in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb /usr/lib/qt/bin/qsb; do "
            + "  if command -v \"$q\" >/dev/null 2>&1; then \"$q\" --qt6 -o \"$2\" \"$1\" && exit 0; fi; "
            + "done; "
            + "[ -f \"$1.qsb\" ] && cp \"$1.qsb\" \"$2\" && exit 0; "
            + "[ -f \"$HOME/.config/yukidock/liquidglass.frag.qsb\" ] && cp \"$HOME/.config/yukidock/liquidglass.frag.qsb\" \"$2\" && exit 0; "
            + "exit 1",
            "sh", root.glassShaderSrc, root.glassShaderOut]
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[yukibar-glass] qsb:", text.trim()) }
        onExited: (code, status) => root.glassState = (code === 0 ? "ready" : "failed")
    }

    readonly property var wallpaperMap: hub ? hub.wallpaperMap : ({})
    Binding { target: root.hub; property: "barWantsWallpaper"; value: root.liquidBase }
    function wallpaperFor(screenName) {
        var p = wallpaperPath !== "" ? wallpaperPath
              : (wallpaperMap["wallpaper.monitors." + screenName] || wallpaperMap["wallpaper.last"]
                 || wallpaperMap["wallpaper.default"] || "");
        if (p.indexOf("~/") === 0) p = Quickshell.env("HOME") + p.substring(1);
        return p;
    }
    function fileUrl(p) {
        if (p === "") return "";
        if (p.indexOf("file://") === 0) return p;
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }
    property color wallpaperAccent: "#8A9AB5"
    property string wallpaperAccentFor: ""
    readonly property color menuBorderColor: {
        var c = wallpaperAccent;
        var h = c.hslHue < 0 ? 0 : c.hslHue, sat = c.hslSaturation, l = c.hslLightness;
        var s2 = sat < 0.06 ? sat : Math.max(0.28, Math.min(0.75, sat));
        var l2 = panelDarkMode ? Math.max(0.66, Math.min(0.86, l * 0.5 + 0.50))
                               : Math.max(0.30, Math.min(0.52, l * 0.5 + 0.05));
        return Qt.hsla(h, s2, l2, 1);
    }
    property string awwwWallpaperPath: ""
    readonly property string dominantWallpaperPath: {
        if (root.awwwWallpaperPath !== "") return root.awwwWallpaperPath;
        var screens = Quickshell.screens;
        return root.wallpaperFor(screens && screens.length ? screens[0].name : "");
    }
    property bool wallpaperSampleForce: true
    onWallpaperPathChanged: { wallpaperSampleForce = true; wallpaperColorTimer.restart(); }
    onWallpaperMapChanged: { wallpaperSampleForce = true; wallpaperColorTimer.restart(); }
    onDominantWallpaperPathChanged: { wallpaperSampleForce = true; wallpaperColorTimer.restart(); }
    function sampleWallpaperColor() {
        if (awwwQueryProc.running || wallpaperColorProc.running) { wallpaperColorTimer.restart(); return; }
        awwwQueryProc.running = true;
    }
    Timer { id: wallpaperColorTimer; interval: 500; onTriggered: root.sampleWallpaperColor() }
    Timer { interval: 30000; repeat: true; running: root.barEnabled && !root.gaming; onTriggered: root.sampleWallpaperColor() }
    Process {
        id: awwwQueryProc
        command: ["sh", "-c", "awww query -j 2>/dev/null || swww query -j 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim(), path = "";
                try {
                    var data = JSON.parse(out);
                    function findImage(v) {
                        if (!v || typeof v !== "object") return "";
                        if (typeof v.image === "string" && v.image !== "") return v.image;
                        for (var k in v) { var found = findImage(v[k]); if (found) return found; }
                        return "";
                    }
                    path = findImage(data);
                } catch (e) {
                    var match = out.match(/image:\s*(.+)/i);
                    if (match) path = match[1].trim();
                }
                if (path.indexOf("~/") === 0) path = Quickshell.env("HOME") + path.substring(1);
                if (root.awwwWallpaperPath !== path) root.awwwWallpaperPath = path;
                var fallback = root.wallpaperFor(Quickshell.screens && Quickshell.screens.length ? Quickshell.screens[0].name : "");
                var p = path || fallback;
                if (p.indexOf("file://") === 0) p = decodeURIComponent(p.substring(7));
                if (p === "") return;
                if (p === root.wallpaperAccentFor && !root.wallpaperSampleForce) return;
                root.wallpaperSampleForce = false;
                wallpaperColorProc.samplePath = p;
                wallpaperColorProc.command = ["sh", "-c",
                    'f="$1"; for t in magick convert; do command -v "$t" >/dev/null 2>&1 && ' +
                    '{ "$t" "${f}[0]" -alpha off -resize 64x64! -colors 8 -depth 8 -format %c histogram:info:- 2>/dev/null && exit 0; }; done; exit 0',
                    "sh", p];
                wallpaperColorProc.running = true;
            }
        }
    }
    Process {
        id: wallpaperColorProc
        property string samplePath: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = text.split("\n"), bestCount = -1, bestColor = "";
                for (var i = 0; i < rows.length; i++) {
                    var m = rows[i].match(/^\s*(\d+):.*?(#[0-9a-f]{6})/i);
                    if (m && Number(m[1]) > bestCount) { bestCount = Number(m[1]); bestColor = m[2]; }
                }
                if (bestColor) { root.wallpaperAccent = bestColor; root.wallpaperAccentFor = wallpaperColorProc.samplePath; }
            }
        }
    }

    readonly property var monData: hub ? hub.monData : []
    readonly property var glassClients: hub ? hub.glassClients : []
    property int popCount: 0
    onBarEnabledChanged: { if (!barEnabled) popCount = 0; clipStart(); }
    Binding { target: root.hub; property: "barWantsGeo"; value: root.liquidActive }

    Component.onCompleted: {
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"]);
        syncAppKeys();
        Quickshell.execDetached(["mkdir", "-p", configDir]);
        wallpaperColorTimer.start();
        refreshWifi();
        refreshKeyboardLayout();
        refreshConnections();
    }

    function openSettings(pane) { if (hub) hub.openSettings(pane || "menubar"); }

    signal notifPopRequest(bool open)
    property bool notifDnd: false
    property int notifBannerSecs: 6
    property var notifMutedApps: []
    property var notifAppsSeen: []
    property bool focusSchedule: false
    property int focusFrom: 1320
    property int focusTo: 420
    property bool focusFullscreen: false
    property bool focusAllowUrgent: true
    property bool scheduleNow: false
    function inFocusSchedule() {
        var d = new Date(), m = d.getHours() * 60 + d.getMinutes();
        return focusFrom <= focusTo ? (m >= focusFrom && m < focusTo) : (m >= focusFrom || m < focusTo);
    }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.scheduleNow = root.inFocusSchedule() }
    onFocusFromChanged: scheduleNow = inFocusSchedule()
    onFocusToChanged: scheduleNow = inFocusSchedule()
    readonly property bool fullscreenNow: activeWin !== null && Number(activeWin.fullscreen) === 2
    readonly property bool dndActive: notifDnd || (focusSchedule && scheduleNow) || (focusFullscreen && fullscreenNow)
    property bool lockShowNotifs: true
    onLockShowNotifsChanged: lockNotifWrite()
    property string lockWallpaper: ""
    property real notifBlur: 14
    property int notifUnread: 0
    property int notifSeq: 0
    property var notifRefs: ({})
    ListModel { id: notifHist }
    readonly property int notifHistCount: notifHist.count
    ListModel { id: notifToasts }

    Loader {
        active: root.notificationsEnabled
        sourceComponent: NotificationServer {
            keepOnReload: false
            bodySupported: true
            bodyMarkupSupported: false
            imageSupported: true
            actionsSupported: true
            persistenceSupported: true
            onNotification: n => root.notifReceive(n)
        }
    }
    function notifIndex(model, id) {
        for (var i = 0; i < model.count; i++) if (model.get(i).nid === id) return i;
        return -1;
    }
    readonly property var systemNotifApps: ["", "yukibar", "yukishell", "settings", "system", "notify-send", "networkmanager", "network",
        "power", "upower", "battery", "udiskie", "udisks", "disks", "polkit", "systemd", "screenshot", "grim", "hyprland", "bluetooth", "blueman", "updates", "pacman"]
    function isSystemNotif(n) {
        var app = (n.appName || "").toLowerCase();
        try { if (n.hints && (n.hints["sound-file"] || n.hints["sound-name"])) return false; } catch (e) {}
        return systemNotifApps.indexOf(app) >= 0;
    }
    function notifReceive(n) {
        n.tracked = true;
        var id = ++root.notifSeq;
        root.notifRefs[id] = n;
        var ic = "";
        if (n.image && n.image !== "") ic = n.image;
        else if (n.appIcon && n.appIcon !== "") ic = Quickshell.iconPath(n.appIcon, true);
        var urg = 1;
        if (n.urgency === NotificationUrgency.Critical) urg = 2;
        else if (n.urgency === NotificationUrgency.Low) urg = 0;
        var rec = {
            nid: id, app: n.appName || "", summary: n.summary || "", body: n.body || "",
            icon: ic || "", urgency: urg, time: Date.now(),
            timeout: n.expireTimeout > 0 ? Math.round(n.expireTimeout * 1000) : 0
        };
        notifHist.insert(0, rec);
        while (notifHist.count > 60) {
            var old = notifHist.get(notifHist.count - 1).nid;
            notifHist.remove(notifHist.count - 1);
            delete root.notifRefs[old];
        }
        if (rec.app !== "" && root.notifAppsSeen.indexOf(rec.app) < 0) root.notifAppsSeen = root.notifAppsSeen.concat([rec.app]).slice(-40);
        var muted = root.notifMutedApps.indexOf(rec.app) >= 0;
        if (!muted && (!root.dndActive || (urg === 2 && root.focusAllowUrgent)) && !root.notifOpen) {
            if (root.isSystemNotif(n) && !(rec.app === "yukibar" && rec.summary.indexOf("Screenshot") === 0)) root.playSound(root.alertSound, 0.7);
            notifToasts.insert(0, rec);
            while (notifToasts.count > 4) notifToasts.remove(notifToasts.count - 1);
        }
        if (!root.notifOpen) root.notifUnread++;
        try { n.closed.connect(function () { root.notifToastRemove(id); }); } catch (e) {}
        function upd(role, val) {
            var i = notifIndex(notifToasts, id); if (i >= 0) notifToasts.setProperty(i, role, val || "");
            var j = notifIndex(notifHist, id); if (j >= 0) notifHist.setProperty(j, role, val || "");
        }
        try { n.summaryChanged.connect(function () { upd("summary", n.summary); }); } catch (e) {}
        try { n.bodyChanged.connect(function () { upd("body", n.body); }); } catch (e) {}
    }
    onNotifUnreadChanged: lockNotifSave.restart()
    Connections { target: notifHist; function onCountChanged() { lockNotifSave.restart(); } }
    Timer { id: lockNotifSave; interval: 300; onTriggered: root.lockNotifWrite() }
    function appIconFor(app) {
        if (!app) return "";
        var e = null;
        try { e = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(app) : null; } catch (err) { e = null; }
        var nm = (e && e.icon) ? e.icon : app.toLowerCase();
        return Quickshell.iconPath(nm, true) || "";
    }
    function lockNotifWrite() {
        var out = [], n = lockShowNotifs ? Math.min(notifUnread, notifHist.count, 20) : 0;
        for (var i = 0; i < n; i++) {
            var r = notifHist.get(i);
            out.push({ id: r.nid, app: r.app || "Notification", icon: appIconFor(r.app), time: r.time });
        }
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.cache/yukishell\" && printf '%s\\n' \"$1\" > \"$HOME/.cache/yukishell/lock-notifs.json.tmp\" && mv -f \"$HOME/.cache/yukishell/lock-notifs.json.tmp\" \"$HOME/.cache/yukishell/lock-notifs.json\"",
            "sh", JSON.stringify(out)]);
    }

    property bool notifOpen: false
    function notifToastRemove(id) {
        var i = notifIndex(notifToasts, id);
        if (i >= 0) notifToasts.remove(i);
    }
    function notifDelete(id) {
        notifToastRemove(id);
        var i = notifIndex(notifHist, id);
        if (i >= 0) {
            if (i < root.notifUnread) root.notifUnread--;  // unread ones are the newest, at the top of the history
            notifHist.remove(i);
        }
        var n = root.notifRefs[id];
        if (n) { try { n.dismiss(); } catch (e) {} delete root.notifRefs[id]; }
    }
    signal notifDustAll()
    property bool notifClearing: false
    property var notifMergeFrom: ({})
    property bool notifFlying: false
    onNotifMergeFromChanged: { if (Object.keys(notifMergeFrom).length > 0) { notifFlying = true; flyEnd.restart(); } }
    Timer { id: flyEnd; interval: 900; onTriggered: root.notifFlying = false }
    onNotifOpenChanged: if (!notifOpen) notifMergeFrom = ({})
    function notifClearAnimated() {
        if (notifHist.count === 0) return;
        notifClearing = true;
        notifDustAll();
        notifClearLater.interval = 950 + Math.min(notifHist.count, 12) * 55;
        notifClearLater.restart();
    }
    Timer { id: notifClearLater; onTriggered: { root.notifClear(); root.notifClearing = false; } }
    function notifClear() {
        notifToasts.clear();
        for (var i = 0; i < notifHist.count; i++) {
            var n = root.notifRefs[notifHist.get(i).nid];
            if (n) { try { n.dismiss(); } catch (e) {} }
        }
        notifHist.clear();
        root.notifRefs = ({});
        root.notifUnread = 0;
    }
    function notifActivate(id) {
        var n = root.notifRefs[id];
        if (n) {
            try {
                for (var i = 0; i < n.actions.length; i++)
                    if (n.actions[i].identifier === "default") { n.actions[i].invoke(); break; }
            } catch (e) {}
        }
        notifToastRemove(id);
    }

    property string wallpaperDir: ""
    property var wallpaperDirs: []
    property var wallpaperFavs: []
    property string wallpaperVideo: ""
    property string wpRestorePath: ""
    property var wpThumbs: ({})
    property var wpPreviews: ({})
    property string wallpaperCmd: ""
    property real wpBlur: 40
    property bool wpOpen: false
    property string wpStatus: ""
    property var wpDirList: []
    property var wpFolders: []
    property var wpDirCount: ({})
    property var wpFavOk: ({})
    property var wpFiles: []
    property string wpQuery: ""
    readonly property var wpShown: {
        var q = root.wpQuery.trim().toLowerCase(), f = root.wpFiles;
        if (q === "") return f;
        var out = [];
        for (var i = 0; i < f.length; i++) if (f[i].name.toLowerCase().indexOf(q) >= 0) out.push(f[i]);
        return out;
    }
    function wpResolveOne(dir) {
        var d = (dir || "").trim();
        if (d === "") d = "~/Pictures/Wallpapers";
        if (d.indexOf("~") === 0) d = Quickshell.env("HOME") + d.substring(1);
        while (d.length > 1 && d.charAt(d.length - 1) === "/") d = d.substring(0, d.length - 1);
        return d;
    }
    function wpResolveDirs() {
        var src = root.wallpaperDirs || [], out = [], seen = {};
        for (var i = 0; i < src.length; i++) {
            var p = root.wpResolveOne(src[i]);
            if (p !== "" && !seen[p]) { seen[p] = true; out.push(p); }
        }
        if (out.length === 0) out.push(root.wpResolveOne(""));
        return out;
    }
    readonly property var wpDirsEff: { root.wallpaperDirs; return root.wpResolveDirs(); }
    readonly property string wpDirEff: wpDirsEff[0]
    readonly property bool wpDefaultDirs: (root.wallpaperDirs || []).length === 0
    function wpName(path) {
        var n = path.substring(path.lastIndexOf("/") + 1);
        var k = n.lastIndexOf(".");
        return k > 0 ? n.substring(0, k) : n;
    }
    function wpRebuild() {
        var favs = root.wallpaperFavs || [], inDir = {}, seen = {}, out = [], i;
        for (i = 0; i < root.wpDirList.length; i++) inDir[root.wpDirList[i]] = true;
        for (i = 0; i < favs.length; i++) {
            if (!(inDir[favs[i]] || root.wpFavOk[favs[i]]) || seen[favs[i]]) continue;
            seen[favs[i]] = true;
            out.push({ path: favs[i], name: root.wpName(favs[i]), fav: true, video: root.wpIsVideo(favs[i]), thumb: root.wpThumbs[favs[i]] || "", preview: root.wpPreviews[favs[i]] || "" });
        }
        for (i = 0; i < root.wpDirList.length; i++) {
            var f = root.wpDirList[i];
            if (seen[f]) continue;
            out.push({ path: f, name: root.wpName(f), fav: false, video: root.wpIsVideo(f), thumb: root.wpThumbs[f] || "", preview: root.wpPreviews[f] || "" });
        }
        if (JSON.stringify(out) !== JSON.stringify(root.wpFiles)) root.wpFiles = out;
    }
    function wpParse(text) {
        var lines = text.split("\n"), dir = [], seenDir = {}, ok = {}, th = {}, pv = {}, folders = [];
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i];
            if (l.indexOf("A:") === 0) { var a = l.substring(2); if (!seenDir[a]) { seenDir[a] = true; dir.push(a); } }
            else if (l.indexOf("T:") === 0) { var k = l.indexOf("\t"); if (k > 2) th[l.substring(2, k)] = l.substring(k + 1); }
            else if (l.indexOf("P:") === 0) { var k2 = l.indexOf("\t"); if (k2 > 2) pv[l.substring(2, k2)] = l.substring(k2 + 1); }
            else if (l.indexOf("D:") === 0) folders.push(l.substring(2));
            else if (l === "W:0") root.wpWatchBroken = true;
            else if (l.indexOf("F:") === 0) ok[l.substring(2)] = true;
        }
        var counts = {}, fl = root.wpDirsEff;
        for (var c = 0; c < fl.length; c++) counts[fl[c]] = 0;
        for (var n = 0; n < dir.length; n++) {
            var best = "";
            for (var m = 0; m < fl.length; m++) if (dir[n].indexOf(fl[m] + "/") === 0 && fl[m].length > best.length) best = fl[m];
            if (best !== "") counts[best]++;
        }
        if (JSON.stringify(counts) !== JSON.stringify(root.wpDirCount)) root.wpDirCount = counts;
        if (folders.join("\n") !== root.wpFolders.join("\n")) root.wpFolders = folders;
        var sameList = dir.join("\n") === root.wpDirList.join("\n") && JSON.stringify(ok) === JSON.stringify(root.wpFavOk);
        root.wpThumbs = th;
        root.wpPreviews = pv;
        if (!sameList) {
            root.wpDirList = dir;
            root.wpFavOk = ok;
        }
        root.wpRebuild();

        var videos = [];
        for (var j = 0; j < dir.length; j++) if (root.wpIsVideo(dir[j])) videos.push(dir[j]);
        if (videos.length && !wpThumbBuild.running) {
            var script = [
                'tc="$HOME/.cache/yukishell/thumbs"; mkdir -p "$tc"',
                'for v do',
                '  t="$tc/$(printf "%s:%s" "$v" "$(stat -c %Y "$v" 2>/dev/null)" | md5sum | cut -c1-16).jpg"',
                '  if [ ! -s "$t" ]; then ffmpeg -loglevel error -y -ss 1 -i "$v" -frames:v 1 -vf "scale=360:-2" "$t" </dev/null >/dev/null 2>&1; fi',
                '  [ -s "$t" ] && printf "T:%s\\t%s\\n" "$v" "$t"',
                'done',
                's="$HOME/.config/hypr-yukishell/scripts/yukishell-setwall.sh"',
                '[ -x "$s" ] && setsid nice -n 15 "$s" --prepare-all "$@" >/dev/null 2>&1 </dev/null &'
            ].join("\n");
            wpThumbBuild.command = ["sh", "-c", script, "sh"].concat(videos);
            wpThumbBuild.running = true;
        }
    }
    function wpMergeThumbs(text) {
        var th = Object.assign({}, root.wpThumbs || {}), lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("T:") !== 0) continue;
            var k = lines[i].indexOf("\t");
            if (k > 2) th[lines[i].substring(2, k)] = lines[i].substring(k + 1);
        }
        root.wpThumbs = th;
        root.wpRebuild();
    }
    function wpRefresh() {
        if (wpScan.running) { wpRescan = true; return; }
        wpRescan = false;
        var script = [
            'mk="$1"; n="$2"; shift 2',
            'i=0; while [ "$i" -lt "$n" ]; do',
            '  d="$1"; shift; i=$((i+1))',
            '  [ "$mk" = "1" ] && [ ! -d "$d" ] && mkdir -p "$d" 2>/dev/null',
            '  [ -d "$d" ] || continue',
            '  echo "D:$d"',
            '  find -L "$d" -maxdepth 3 -type f 2>/dev/null | grep -iE "[.](jpe?g|png|webp|bmp|gif|mp4|webm|mkv|mov|m4v)$" | sort -V | sed "s/^/A:/"',
            'done',
            'for f in "$@"; do [ -f "$f" ] && echo "F:$f"; done',
            'command -v inotifywait >/dev/null 2>&1 && echo "W:1" || echo "W:0"',
            'exit 0'
        ].join("\n");
        var dirs = root.wpDirsEff;
        wpScan.command = ["sh", "-c", script, "sh", root.wpDefaultDirs ? "1" : "0", String(dirs.length)].concat(dirs, root.wallpaperFavs || []);
        wpScan.running = true;
    }
    property bool wpRescan: false
    function wpSetDirs(list) {
        var out = [], seen = {};
        for (var i = 0; i < list.length; i++) {
            var d = String(list[i] || "").trim();
            if (d.indexOf("~") === 0) d = Quickshell.env("HOME") + d.substring(1);
            while (d.length > 1 && d.charAt(d.length - 1) === "/") d = d.substring(0, d.length - 1);
            if (d !== "" && !seen[d]) { seen[d] = true; out.push(d); }
        }
        if (out.length === 1 && out[0] === root.wpResolveOne("")) out = [];
        root.wallpaperDirs = out;
        root.wpStatus = "";
        root.wpRefresh();
    }
    function wpAddDir(d) {
        var cur = root.wpDefaultDirs ? [] : root.wpDirsEff.slice();
        if (root.wpDefaultDirs) cur = [root.wpResolveOne("")];
        cur.push(d);
        root.wpSetDirs(cur);
    }
    function wpRemoveDir(d) {
        root.wpSetDirs(root.wpDirsEff.filter(function (x) { return x !== d; }));
    }
    function wpToggleFav(path) {
        var f = (root.wallpaperFavs || []).slice(), i = f.indexOf(path);
        if (i >= 0) f.splice(i, 1); else f.push(path);
        root.wallpaperFavs = f;
        root.wpRebuild();
    }
    function wpIsVideo(p) { return /[.](mp4|webm|mkv|mov|m4v)$/i.test(p || ""); }
    readonly property string setwallScript: Quickshell.env("HOME") + "/.config/hypr-yukishell/scripts/yukishell-setwall.sh"
    property string wallpaperAppearance: "dark"
    property string wpPairLight: ""
    property string wpPairDark: ""
    readonly property bool wpHasPair: wpPairLight !== "" && wpPairDark !== ""
    readonly property string dynwallScript: Quickshell.env("HOME") + "/.config/hypr-yukishell/scripts/yukishell-dynwall.sh"
    function wpPairOf(path) {
        var m = /^(.*[-_ ])(light|dark)(\.[a-z0-9]+)$/i.exec(path || "");
        if (!m) return null;
        var other = m[2].toLowerCase() === "light" ? "Dark" : "Light", list = root.wpDirList, cand = null;
        for (var i = 0; i < list.length; i++) {
            var mm = /^(.*[-_ ])(light|dark)(\.[a-z0-9]+)$/i.exec(list[i]);
            if (mm && mm[1] === m[1] && mm[2].toLowerCase() === other.toLowerCase()) { cand = list[i]; break; }
        }
        if (!cand) return null;
        return m[2].toLowerCase() === "light" ? { light: path, dark: cand } : { light: cand, dark: path };
    }
    function hhmmToMin(t) { var m = /T(\d+):(\d+)/.exec(t || ""); return m ? parseInt(m[1]) * 60 + parseInt(m[2]) : -1; }
    readonly property string stopVideoScript: [
        'state="$HOME/.config/yukishell/wallpaper-video"',
        'rm -f "$state" "$HOME/.config/yukishell/wallpaper-video-play" "$HOME/.config/yukishell/wallpaper-video-glass"',
        'supfile="$HOME/.cache/yukishell/wallsup.pid"',
        'if [ -f "$supfile" ]; then g=$(cat "$supfile" 2>/dev/null); case "$g" in ""|*[!0-9]*) ;; *) kill -TERM -- "-$g" 2>/dev/null ;; esac; rm -f "$supfile"; fi',
        'pkill -CONT -x mpvpaper >/dev/null 2>&1',
        'pkill -TERM -x mpvpaper >/dev/null 2>&1',
        'for i in 1 2 3 4 5; do pgrep -x mpvpaper >/dev/null || break; sleep 0.1; done',
        'pkill -KILL -x mpvpaper >/dev/null 2>&1'
    ].join("\n")
    readonly property string awwwScript: [
        'p="$1"',
        root.stopVideoScript,
        'if command -v awww >/dev/null 2>&1; then',
        '  if ! awww query >/dev/null 2>&1; then',
        '    if command -v awww-daemon >/dev/null 2>&1; then setsid awww-daemon >/dev/null 2>&1 & fi',
        '    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do awww query >/dev/null 2>&1 && break; sleep 0.3; done',
        '  fi',
        '  if awww img "$p" --transition-type fade --transition-duration 0.7; then echo "applied with: awww"; exit 0; fi',
        'fi',
        'if command -v swww >/dev/null 2>&1 && swww query >/dev/null 2>&1 && swww img "$p" --transition-type fade --transition-duration 0.7; then echo "applied with: swww"; exit 0; fi',
        'if command -v noctalia >/dev/null 2>&1 && noctalia msg wallpaper-set "$p" >/dev/null 2>&1; then echo "applied with: noctalia"; exit 0; fi',
        'if pgrep -x hyprpaper >/dev/null 2>&1; then',
        '  if hyprctl hyprpaper wallpaper ",$p" >/dev/null 2>&1 || { hyprctl hyprpaper preload "$p" >/dev/null 2>&1; hyprctl hyprpaper wallpaper ",$p" >/dev/null 2>&1; }; then echo "applied with: hyprpaper"; exit 0; fi',
        'fi',
        'if pgrep -f noctalia-shell >/dev/null 2>&1 && qs -c noctalia-shell ipc call wallpaper set "$p" "" >/dev/null 2>&1; then echo "applied with: noctalia-shell (qs ipc)"; exit 0; fi',
        'if pgrep -x swaybg >/dev/null 2>&1; then pkill -x swaybg; setsid swaybg -i "$p" -m fill >/dev/null 2>&1 & echo "applied with: swaybg"; exit 0; fi',
        'echo "no wallpaper daemon accepted the image (tried awww, swww, noctalia, hyprpaper, noctalia-shell, swaybg)" >&2',
        'notify-send "Wallpaper" "Could not set it: install awww (and start awww-daemon), or set wallpaperCmd in settings.json." 2>/dev/null',
        'exit 1'
    ].join("\n")
    property string wpAppliedPair: ""
    function wpApplyAppearance() {
        if (!wpHasPair) return;
        var mode = wallpaperAppearance === "auto" ? (darkMode ? "dark" : "light") : wallpaperAppearance;
        var rise = 390, set_ = 1110;
        try {
            var wx = root.hub && root.hub.widgets ? root.hub.widgets.weather : null;
            if (wx && wx.daily && wx.daily.sunrise) { var a = hhmmToMin(wx.daily.sunrise[0]), b2 = hhmmToMin(wx.daily.sunset[0]); if (a > 0) rise = a; if (b2 > 0) set_ = b2; }
        } catch (e) {}
        if (mode === "dynamic") { var d = new Date(), n = d.getHours() * 60 + d.getMinutes(); mode = (n >= rise && n < set_) ? "light" : "dark"; }
        var p = mode === "dark" ? wpPairDark : wpPairLight;
        if (p === "") return;
        root.wallpaperVideo = "";
        root.wallpaperPath = p;
        try { if (root.hub && root.hub.dock) root.hub.dock.wallpaperPath = p; } catch (e) {}
        if (p === root.wpAppliedPair) return;
        root.wpAppliedPair = p;
        wpApplyProc.command = ["sh", "-c", root.awwwScript, "sh", p];
        wpApplyProc.running = true;
    }
    onWallpaperAppearanceChanged: wpApplyAppearance()
    Timer { interval: 60000; repeat: true; running: root.wpHasPair && root.wallpaperAppearance === "dynamic" && !root.gaming; onTriggered: root.wpApplyAppearance() }
    Timer { interval: 1500; running: true; onTriggered: root.wpRefresh() }
    onWpDirListChanged: {
        if (wpHasPair) return;
        var p = wpPairOf(wallpaperPath);
        if (p) { wpPairLight = p.light; wpPairDark = p.dark; wpApplyAppearance(); }
    }
    Timer { interval: 2500; running: true; onTriggered: root.wpApplyAppearance() }

    function wpApply(path) {
        var pair = wpPairOf(path);
        if (pair) { wpPairLight = pair.light; wpPairDark = pair.dark; root.wpAppliedPair = ""; wpApplyAppearance(); return; }
        wpPairLight = ""; wpPairDark = ""; root.wpAppliedPair = "";
        if (root.wpIsVideo(path)) {
            root.wallpaperVideo = path;
            setwallProc.command = [root.setwallScript, path];
            setwallProc.running = true;
            return;
        }
        root.wallpaperVideo = "";
        root.wpRestorePath = path;
        root.wallpaperPath = path;
        try { if (root.hub && root.hub.dock) root.hub.dock.wallpaperPath = path; } catch (e) {}
        var cmd = (root.wallpaperCmd || "").trim();
        var script = cmd !== "" ? root.stopVideoScript + "\n" + cmd.split("{}").join('"$1"') : root.awwwScript;
        wpApplyProc.command = ["sh", "-c", script, "sh", path];
        wpApplyProc.running = true;
    }
    function wpRestore() {
        if (wpHasPair) return;
        if (wallpaperVideo !== "") {
            setwallProc.command = ["sh", "-c", '[ -x "$1" ] && exec "$1" "$2"', "sh", setwallScript, wallpaperVideo];
            setwallProc.running = true;
            return;
        }
        var p = wpRestorePath;
        if (p === "") return;
        var cmd = (wallpaperCmd || "").trim();
        var script = cmd !== "" ? '[ -f "$1" ] || exit 0\n' + root.stopVideoScript + "\n" + cmd.split("{}").join('"$1"')
                                : '[ -f "$1" ] || exit 0\nif command -v awww >/dev/null 2>&1 && q=$(awww query 2>/dev/null) && [ -n "$q" ] && ! printf "%s\\n" "$q" | grep -vqF -- "$1"; then exit 0; fi\n' + root.awwwScript;
        wpApplyProc.command = ["sh", "-c", script, "sh", p];
        wpApplyProc.running = true;
    }
    Timer { interval: 1000; running: true; onTriggered: root.wpRestore() }
    // first run: nothing has ever set a wallpaper, so the desktop would stay blank behind glass with nothing to refract
    Timer {
        interval: 6000; running: true
        onTriggered: {
            if (root.wallpaperPath !== "" || root.wallpaperVideo !== "" || Object.keys(root.hub.wallpaperMap).length > 0) return;
            root.wpApply(decodeURIComponent(Qt.resolvedUrl("assets/default-wallpaper.jpg").toString().replace("file://", "")));
            Quickshell.execDetached(["notify-send", "-a", "yukishell", I18n.tr("Welcome to YukiShell"), I18n.tr("Super+Space searches, Super+Z opens Settings and Super+/ lists every shortcut.")]);
        }
    }
    Connections { target: Quickshell; function onScreensChanged() { wpHotplug.restart(); } }   // a monitor plugged in later has no wallpaper yet
    Timer { id: wpHotplug; interval: 1500; onTriggered: root.wpRestore() }
    Process {
        id: setwallProc
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n"), still = (l[l.length - 1] || "").trim();
                if (still === "") return;
                root.wallpaperPath = still;
                try { if (root.hub && root.hub.dock) root.hub.dock.wallpaperPath = still; } catch (e) {}
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[wallpaper] error:", text.trim()) }
    }
    Process {
        id: wpApplyProc
        onExited: { root.wallpaperSampleForce = true; wallpaperColorTimer.restart(); }
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[wallpaper]", text.trim()) }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[wallpaper] error:", text.trim()) }
    }
    function wpToggle() {
        root.wpOpen = !root.wpOpen;
        if (root.wpOpen) root.wpRefresh();
    }
    property string wpTermAddr: ""
    property real wpTermAsked: 0
    function wpOpenFolder(dir, panel, scr) {
        var sx = scr ? scr.x : 0, sy = scr ? scr.y : 0, sw = scr ? scr.width : 1920, sh = scr ? scr.height : 1080;
        var p = panel.mapToItem(null, 0, 0), gap = 16, w, h = Math.round(panel.height), x, y = Math.round(sy + p.y);
        var right = sw - (p.x + panel.width) - 2 * gap, left = p.x - 2 * gap;
        if (right >= 360) { w = Math.min(560, Math.round(right)); x = Math.round(sx + p.x + panel.width + gap); }
        else if (left >= 360) { w = Math.min(560, Math.round(left)); x = Math.round(sx + p.x - gap - w); }
        else { w = 560; h = 400; x = sx + sw - w - gap; y = sy + sh - h - 80; }
        var q = "'" + String(dir).split("'").join("'\\''") + "'";
        var cmd = "cd " + q + " && exec " + root.terminal;
        wpTermAsked = Date.now();
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd([==[" + cmd + "]==], { float = true, size = \"" + w + " " + h + "\", move = \"" + x + " " + y + "\" })"]);
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" && root.wpTermAsked > 0 && Date.now() - root.wpTermAsked < 5000) {
                root.wpTermAddr = String(event.data).split(",")[0].replace(/^0x/, "");
                root.wpTermAsked = 0;
            } else if (event.name === "closewindow" && root.wpTermAddr !== "" && String(event.data).replace(/^0x/, "") === root.wpTermAddr) {
                root.wpTermAddr = "";
            }
        }
    }
    function wpPickFolder() {
        var fp = root.hub && root.hub.dock ? root.hub.dock.filePicker : null;
        if (!fp) { root.wpStatus = "The folder chooser is not ready yet."; return; }
        var wasOpen = root.wpOpen;
        root.wpOpen = false;
        fp.pick({ mode: "folder", title: I18n.tr("Add a wallpaper folder"), startDir: root.wpDirEff }, function (path) {
            if (path !== "") root.wpAddDir(path);
            if (wasOpen) root.wpOpen = true;
            root.wpRefresh();
        });
    }
    Process {
        id: wpScan
        stdout: StdioCollector { onStreamFinished: root.wpParse(text) }
        onExited: if (root.wpRescan) root.wpRefresh()
    }
    Process { id: wpThumbBuild; stdout: StdioCollector { onStreamFinished: root.wpMergeThumbs(text) } }

    property bool wpWatchBroken: false
    property int wpWatchFails: 0
    property bool wpWatchPause: false
    onWpFoldersChanged: { wpWatchPause = true; wpWatchResume.restart(); }
    Timer { id: wpWatchResume; interval: 300; onTriggered: root.wpWatchPause = false }
    function wpWatchHit(line) {
        wpWatchFails = 0;
        wpWatchDebounce.interval = line.indexOf("CREATE") >= 0 && line.indexOf("CLOSE_WRITE") < 0 ? 2500 : 900;
        wpWatchDebounce.restart();
    }
    Timer { id: wpWatchDebounce; onTriggered: root.wpRefresh() }
    OwnedProcess {
        id: wpWatch
        running: root.wpWatchOn
        cmd: ["inotifywait", "-m", "-r", "-q", "--format", "%e|%w%f", "-e", "close_write", "-e", "moved_to", "-e", "moved_from", "-e", "delete", "-e", "create"].concat(root.wpFolders)
        stdout: SplitParser { onRead: line => root.wpWatchHit(line) }
        onExited: {
            if (!root.wpWatchOn) return;
            if (++root.wpWatchFails >= 3) root.wpWatchBroken = true;
            wpWatchRetry.restart();
        }
    }
    readonly property bool wpWatchOn: root.wpFolders.length > 0 && !root.wpWatchBroken && !root.wpWatchPause && !wpWatchRetry.running
    Timer { id: wpWatchRetry; interval: 15000 }
    Timer {
        interval: 20000; repeat: true
        running: root.wpWatchBroken && (root.wpOpen || root.wpPaneOpen)
        onTriggered: root.wpRefresh()
    }
    property bool wpPaneOpen: false
    onWallpaperFavsChanged: if (wpOpen) wpRebuild()
    IpcHandler {
        target: "wallpapers"
        function toggle(): void { root.wpToggle(); }
        function set(path: string): void { root.wpApply(path); }
        function appearance(mode: string): void { if (["auto", "light", "dark", "dynamic"].indexOf(mode) >= 0) root.wallpaperAppearance = mode; }
        function open(): void { if (!root.wpOpen) root.wpToggle(); }
        function close(): void { root.wpOpen = false; }
    }

    property string wsNumerals: "han"
    readonly property string wsStyle: {
        if (wsNumerals !== "auto") return wsNumerals;
        var c = language === "auto" ? I18n.code() : language;
        return c.indexOf("zh") === 0 ? "han" : c === "ja" ? "katakana" : c === "ko" ? "hangul" : "numbers";
    }
    function cjkNum(n, d, ten) {
        if (n < 10) return d[n];
        if (n < 20) return ten + d[n - 10];
        if (n < 100) return d[Math.floor(n / 10)] + ten + d[n % 10];
        return "" + n;
    }
    function zhNum(n) {
        return cjkNum(n, ["", "\u4e00", "\u4e8c", "\u4e09", "\u56db", "\u4e94", "\u516d", "\u4e03", "\u516b", "\u4e5d"], "\u5341");
    }
    function kanaNum(n) {
        return cjkNum(n, ["", "\u30a4\u30c1", "\u30cb", "\u30b5\u30f3", "\u30e8\u30f3", "\u30b4", "\u30ed\u30af", "\u30ca\u30ca",
                          "\u30cf\u30c1", "\u30ad\u30e5\u30a6"], "\u30b8\u30e5\u30a6");
    }
    function hangulNum(n) {
        return cjkNum(n, ["", "\uc77c", "\uc774", "\uc0bc", "\uc0ac", "\uc624", "\uc721", "\uce60", "\ud314", "\uad6c"], "\uc2ed");
    }
    function romanNum(n) {
        if (n >= 4000) return "" + n;
        var v = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1], r = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"], o = "";
        for (var i = 0; i < v.length; i++) while (n >= v[i]) { o += r[i]; n -= v[i]; }
        return o;
    }
    function wsLabel(n) {
        if (n <= 0) return "" + n;
        var st = wsStyle;
        return st === "katakana" ? kanaNum(n) : st === "hangul" ? hangulNum(n) : st === "roman" ? romanNum(n)
             : st === "numbers" ? "" + n : zhNum(n);
    }
    FontMetrics { id: wsFm; font.family: root.fontForWeight(Font.DemiBold, root.fontFamily); font.pixelSize: 13; font.weight: Font.DemiBold }
    function wsCellW(n) { return Math.max(22, Math.ceil(wsFm.advanceWidth(wsLabel(n))) + 12); }
    function hlWorkspace(sel) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + sel + "\" })"]);
    }
    // The counter shows the workspaces Hyprland really has (0.55+ creates and destroys them on demand), nothing more.
    // Set wsMin above 0 only if you want workspaces 1..wsMin to be shown even when they do not exist.
    property int wsMin: 0
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n === "createworkspacev2" || n === "destroyworkspacev2" || n === "workspacev2" || n === "moveworkspacev2" || n === "renameworkspace")
                Hyprland.refreshWorkspaces();
            if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "createworkspacev2" || n === "destroyworkspacev2" || n === "configreloaded")
                wsKick.restart();
        }
    }
    readonly property var wsIds: {
        var ids = [], vals = Hyprland.workspaces.values;
        for (var i = 1; i <= root.wsMin; i++) ids.push(i);
        for (var j = 0; j < vals.length; j++) {
            var id = vals[j].id;
            if (id > 0 && ids.indexOf(id) < 0) ids.push(id);
        }
        var fw = Hyprland.focusedWorkspace;
        if (fw && fw.id > 0 && ids.indexOf(fw.id) < 0) ids.push(fw.id);
        if (ids.length === 0) ids.push(1);
        ids.sort(function (a, b) { return a - b; });
        return ids;
    }
    property var wsCounts: ({})
    property bool wsAgain: false
    function wsOccupied(id) { return (wsCounts[id] || 0) > 0; }
    Process {
        id: wsProbe
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                var c; try { c = JSON.parse(text); } catch (e) { return; }
                var m = {}, n = 0, same = true, k;
                for (var i = 0; i < c.length; i++) {
                    if (!c[i].mapped || !c[i].workspace) continue;
                    var id = c[i].workspace.id;
                    if (m[id] === undefined) { m[id] = 0; n++; }
                    m[id]++;
                }
                for (k in m) if (root.wsCounts[k] !== m[k]) same = false;
                if (n !== Object.keys(root.wsCounts).length) same = false;
                if (!same) root.wsCounts = m;
            }
        }
        onExited: { if (root.wsAgain) { root.wsAgain = false; wsKick.restart(); } }
    }
    Timer { id: wsKick; interval: 120; onTriggered: { if (wsProbe.running) root.wsAgain = true; else wsProbe.running = true; } }
    Timer { interval: 15000; running: root.barEnabled && root.barWidgetEnabled("workspaces"); repeat: true; triggeredOnStart: true; onTriggered: wsKick.restart() }

    property real switcherBlur: 15
    property string switcherStyle: "glass"
    property bool swOpen: false
    property var swApps: []
    property int swIndex: 0
    property var swMru: []
    function swTrack() {
        var t = root.activeTl;
        if (!t) return;
        var a = [t];
        for (var i = 0; i < root.swMru.length && a.length < 60; i++) if (root.swMru[i] !== t) a.push(root.swMru[i]);
        root.swMru = a;
    }
    function swIcon(a) {
        if (a.icon) return root.iconSrc(a.icon);
        var p = Quickshell.iconPath(a.appId, true);
        if (p === "") p = Quickshell.iconPath(a.appId.toLowerCase(), true);
        return p !== "" ? p : root.iconSrc("");
    }
    function swBuild() {
        var vals = ToplevelManager.toplevels.values, all = [];
        for (var i = 0; i < vals.length; i++) all.push(vals[i]);
        var order = [];
        if (root.activeTl && all.indexOf(root.activeTl) >= 0) order.push(root.activeTl);
        for (var m = 0; m < root.swMru.length; m++) if (all.indexOf(root.swMru[m]) >= 0 && order.indexOf(root.swMru[m]) < 0) order.push(root.swMru[m]);
        for (var j = 0; j < all.length; j++) if (order.indexOf(all[j]) < 0) order.push(all[j]);
        var seen = {}, apps = [];
        for (var k = 0; k < order.length; k++) {
            var t = order[k], id = t.appId || "";
            if (id === "") continue;
            if (id === "org.quickshell") id = t.title === "Clock" ? "yukishell-clock"
                                             : (t.title === "App Store" ? "yukishell-appstore"
                                             : (t.title === "YukiShell Settings" ? "systemsettings" : id));
            if (seen[id] !== undefined) { apps[seen[id]].count++; continue; }
            var e = root.lookup(id);
            seen[id] = apps.length;
            apps.push({ appId: id, cls: t.appId, name: id === "systemsettings" ? "System Settings" : (id === "org.quickshell" ? "YukiShell" : (e ? e.name : id)),
                        icon: id === "systemsettings" ? "preferences-system" : (id === "org.quickshell" ? root.logoPath : (e ? e.icon : "")), win: t, count: 1 });
        }
        return apps;
    }
    function swNext(dir) {
        if (!root.swOpen) {
            var apps = root.swBuild();
            if (apps.length === 0) return;
            root.swApps = apps;
            // index 0 is the app you are in, or from the desktop the app you just left; set before opening so nothing reads -1
            var n0 = apps.length;
            root.swIndex = dir < 0 ? n0 - 1 : (root.desktopFocused ? 0 : 1 % n0);
            root.swOpen = true;
            return;
        }
        var n = root.swApps.length;
        root.swIndex = (root.swIndex + (dir >= 0 ? 1 : n - 1)) % n;
    }
    property var swPending: null
    Timer {
        id: swFocusTimer
        interval: 60
        onTriggered: {
            var t = root.swPending;
            root.swPending = null;
            if (!t) return;
            var lua = "";
            if (t.ws > 0) lua += "hl.dispatch(hl.dsp.focus({ workspace = \"" + t.ws + "\" })); ";
            lua += "hl.dispatch(hl.dsp.focus({ window = \"" + (t.addr !== "" ? "address:" + t.addr : "class:^(" + t.cls + ")$") + "\" })); ";
            lua += "hl.dispatch(hl.dsp.window.bring_to_top())";
            console.log("[switcher] hyprctl eval '" + lua + "'");
            Quickshell.execDetached(["hyprctl", "eval", lua]);
        }
    }
    function swCommit() {
        if (!root.swOpen) return;
        var a = root.swApps[root.swIndex];
        root.swOpen = false;
        if (!a || !a.win) return;
        try { Hyprland.refreshToplevels(); } catch (e) {}
        var ts = Hyprland.toplevels.values, hit = null, i;
        for (i = 0; i < ts.length; i++) if (ts[i].wayland === a.win) { hit = ts[i]; break; }
        if (!hit) {
            var cls = (a.cls || a.appId || "").toLowerCase(), ttl = a.win.title || "", loose = null;
            for (i = 0; i < ts.length; i++) {
                if (root.hub && root.hub.tlGhost(ts[i])) continue;
                var o = ts[i].lastIpcObject || {};
                if (("" + (o["class"] || "")).toLowerCase() !== cls) continue;
                if (("" + (o.title || "")) === ttl) { hit = ts[i]; break; }
                if (!loose) loose = ts[i];
            }
            if (!hit) hit = loose;
        }
        var addr = "", ws = 0;
        if (hit) {
            addr = "" + hit.address;
            if (addr.indexOf("0x") !== 0) addr = "0x" + addr;
            var w = hit.workspace;
            if (w && w.id > 0) ws = w.id;
            else if (hit.lastIpcObject && hit.lastIpcObject.workspace && hit.lastIpcObject.workspace.id > 0) ws = hit.lastIpcObject.workspace.id;
        }
        console.log("[switcher] app=" + a.appId + " matched=" + (hit ? "yes" : "no") + " addr=" + addr + " ws=" + ws);
        if (!hit && !a.appId) { try { a.win.activate(); } catch (e2) {} return; }
        root.swPending = { addr: addr, ws: ws, cls: (a.cls || a.appId || "").replace(/[\\"']/g, "") };
        swFocusTimer.restart();
    }
    function swCancel() { root.swOpen = false; }
    IpcHandler {
        target: "switcher"
        function next(): void { root.swNext(1); }
        function prev(): void { root.swNext(-1); }
        function commit(): void { root.swCommit(); }
        function cancel(): void { root.swCancel(); }
    }

    Variants {
        model: (root.settingsReady && root.barLayerNeeded) ? Quickshell.screens : []

        Scope {
            id: perScreen
            required property var modelData

        PanelWindow {
            id: barBgWin
            screen: perScreen.modelData
            visible: root.barBgOpacity > 0.001
            anchors { left: true; right: true; top: true }
            implicitHeight: root.barH
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region { }

            WlrLayershell.namespace: "yukibarbg"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                color: root.darkMode ? Qt.rgba(0.10, 0.10, 0.11, root.barBgOpacity) : Qt.rgba(1, 1, 1, root.barBgOpacity)
            }
        }

        PanelWindow {
            id: win
            property var modelData: perScreen.modelData
            screen: perScreen.modelData

            anchors { left: true; right: true; top: true }
            implicitHeight: root.barH + root.popRoom
            color: "transparent"

            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.barEnabled ? root.barH : 0

            WlrLayershell.namespace: "yukibar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: ((ui.pop === "wifi" || (ui.pop === "cc" && ui.ccPage === "wifi")) && ui.wifiPrompt !== "") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            mask: Region { item: maskItem; Region { item: toastMask } }

            Item {
                id: ui
                anchors.fill: parent

                property string pop: ""
                property real menuX: 0
                property real calSrcW: 0
                property var menuModel: []
                property string armed: ""
                property int calYear: 2026
                property int calMonth: 0
                property string wifiPrompt: ""
                property bool ccEdit: false
                property string ccPage: ""
                onCcPageChanged: wifiPrompt = ""
                property var trayItem: null
                property var trayStack: []
                Timer { interval: 400; repeat: true; running: ui.pop === "vol"; onTriggered: root.audioTick++ }
                readonly property bool toastScreen: Quickshell.screens.length === 1 || (Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === win.modelData.name)
                Connections {
                    target: root
                    function onCcRequest(open) {
                        if (!ui.toastScreen || !root.ccEnabled) return;
                        ui.pop = (open && ui.pop !== "cc") ? "cc" : "";
                    }
                }
                readonly property bool toastsShown: toastScreen && notifToasts.count > 0
                onToastsShownChanged: if (toastsShown && pop === "") root.measureTone(win.modelData.x + ui.width - 374, win.modelData.y + root.barH + 8, 364, 90)

                function openTray(item, x) {
                    if (!item || !item.hasMenu) return;
                    if (pop === "tray" && trayItem === item) { pop = ""; return; }
                    trayStack = [];
                    trayItem = item;
                    menuX = x;
                    pop = "tray";
                }

                function wifiPick(n) {
                    if (n.inUse) { root.disconnectWifi(); return; }
                    if (root.wifiBusy !== "") return;
                    if (n.secure && !n.saved) { wifiPrompt = (wifiPrompt === n.ssid) ? "" : n.ssid; return; }
                    wifiPrompt = "";
                    root.connectWifi(n.ssid, "");
                }
                function wifiSubmit(ssid, pw) {
                    if (pw === "") return;
                    wifiPrompt = "";
                    root.connectWifi(ssid, pw);
                }
                Timer {
                    interval: 4000; repeat: true
                    running: (ui.pop === "wifi" || (ui.pop === "cc" && ui.ccPage === "wifi")) && ui.wifiPrompt === ""
                    onTriggered: root.scanWifi()
                }
                Timer {
                    interval: 4000; repeat: true
                    running: ui.pop === "bt" || (ui.pop === "cc" && ui.ccPage === "bt")
                    onTriggered: root.scanBt()
                }

                property string spMode: "home"
                property string spQuery: ""
                property string spHoverLabel: ""
                property int spSel: 0
                property var spExpanded: ({})
                property bool clipMenu: false
                property bool spCalm: false
                property bool spReqCalm: false
                property int emCat: 0
                property bool spHover: false
                property point spPtr: Qt.point(-1e6, -1e6)
                function spPointerMoved(item, mx, my) {
                    var p = item.mapToGlobal(mx, my);
                    if (Math.abs(p.x - spPtr.x) < 1 && Math.abs(p.y - spPtr.y) < 1) return false;
                    spPtr = p;
                    return true;
                }
                readonly property int emCols: 12
                readonly property bool spFull: spMode === "apps" || spMode === "clip" || spMode === "emoji"
                property var spResults: spMode === "actions" ? root.actionItems(spQuery)
                                        : (spMode === "clip" ? root.clipFiltered(spQuery)
                                        : (spMode === "emoji" ? root.emojiItems(spQuery, emCat)
                                        : (spQuery.trim() === "" ? [] : root.homeItems(spQuery))))

                function spSetMode(m) {
                    spMode = m; spQuery = ""; spHoverLabel = ""; spSel = 0; armed = ""; clipMenu = false;
                    spInput.text = ""; appsInput.text = ""; clipInput.text = ""; emojiInput.text = "";
                    if (m === "clip") root.clipRefresh();
                    if (m === "emoji") emCat = root.emojiRecent.length > 0 ? 0 : 1;
                    spFocusTimer.restart();
                }
                function spEscape() {
                    if (clipMenu) clipMenu = false;
                    else if (spQuery !== "") { spInput.text = ""; appsInput.text = ""; clipInput.text = ""; emojiInput.text = ""; spQuery = ""; }
                    else if (spMode !== "home") spSetMode("home");
                    else pop = "";
                }
                function spMove(d) {
                    var n = spResults.length;
                    if (n > 0) spSel = (Math.min(spSel, n - 1) + d + n) % n;
                }
                function spActivate(i, floating) {
                    var it = spResults[i];
                    if (!it) return;
                    if (it.confirm === true && armed !== it.title) { armed = it.title; return; }
                    pop = "";
                    if (it.run) it.run(floating === true);
                }
                function spEnter(floating) {
                    if (spMode === "apps") {
                        var r = root.searchApps(spQuery);
                        if (r.length > 0) { pop = ""; root.launchApp(r[0], floating === true); }
                    } else if (spMode === "emoji") {
                        var em = spResults[Math.min(spSel, spResults.length - 1)];
                        if (em) { pop = ""; root.emojiPick(em); }
                    } else spActivate(Math.min(spSel, spResults.length - 1), floating === true);
                }
                function spKey(ev) {
                    var k = ev.key, n = spResults.length;
                    if (k === Qt.Key_Escape) { spEscape(); ev.accepted = true; }
                    else if (spMode === "emoji" && (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down)) {
                        var d = k === Qt.Key_Left ? -1 : (k === Qt.Key_Right ? 1 : (k === Qt.Key_Up ? -emCols : emCols));
                        if (n > 0) spSel = Math.max(0, Math.min(n - 1, Math.min(spSel, n - 1) + d));
                        ev.accepted = true;
                    }
                    else if (spMode === "emoji" && (k === Qt.Key_Tab || k === Qt.Key_Backtab)) {
                        if (spQuery.trim() === "") { emCat = (emCat + (k === Qt.Key_Tab ? 1 : 9)) % 10; spSel = 0; }
                        ev.accepted = true;
                    }
                    else if (k === Qt.Key_Down) { spMove(1); ev.accepted = true; }
                    else if (k === Qt.Key_Up) { spMove(-1); ev.accepted = true; }
                    else if (spMode === "clip" && k === Qt.Key_Delete) {
                        if (n > 0) root.clipDelete(spResults[Math.min(spSel, n - 1)]);
                        ev.accepted = true;
                    }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                        if (spMode === "clip" && (ev.modifiers & Qt.ShiftModifier) && n > 0) {
                            var it = spResults[Math.min(spSel, n - 1)];
                            pop = "";
                            root.clipPick(it, false);
                        } else spEnter((ev.modifiers & Qt.ShiftModifier) !== 0);
                        ev.accepted = true;
                    }
                }
                function spToggleSection(name) {
                    var o = {};
                    for (var k in spExpanded) o[k] = spExpanded[k];
                    o[name] = !o[name];
                    spExpanded = o;
                }
                readonly property bool menuLead: {
                    for (var i = 0; i < menuModel.length; i++) if (menuModel[i].checked !== undefined || menuModel[i].glyph !== undefined) return true;
                    return false;
                }
                Connections {
                    target: root
                    function onActiveWinChanged() { if (ui.isMenu) ui.menuModel = root.menuModelFor(ui.pop); }
                }
                readonly property rect glassRect: {
                    var items = [menuPop, cc, cal, wifiPop, btPop, trayPop, notifPop, toastArea, volPop, kbPop, levelOsd], x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9, any = false;
                    for (var i = 0; i < items.length; i++) {
                        var it = items[i];
                        if (!it.visible) continue;
                        any = true;
                        x0 = Math.min(x0, it.x); y0 = Math.min(y0, it.y); x1 = Math.max(x1, it.x + it.width); y1 = Math.max(y1, it.y + it.height);
                    }
                    return any ? Qt.rect(x0 - 64, y0 - 64, x1 - x0 + 128, y1 - y0 + 128) : Qt.rect(0, 0, 0, 0);
                }
                readonly property bool isMenu: ["apple", "app", "file", "edit", "view", "window", "help"].indexOf(pop) >= 0
                readonly property bool anyVisible: menuPop.visible || cc.visible || cal.visible || wifiPop.visible || btPop.visible || trayPop.visible || notifPop.visible || toastArea.visible || volPop.visible || kbPop.visible
                onAnyVisibleChanged: root.popCount += (anyVisible ? 1 : -1)
                onPopChanged: {
                    if (pop !== "" && pop !== "spot") toneT.restart();
                    if (pop === "spot" && ui.toastScreen) root.measureTone(win.modelData.x + ui.width / 2 - 320, win.modelData.y + ui.height * 0.4 - 30, 640, 60);
                    armed = "";
                    wifiPrompt = "";
                    spHoverLabel = "";
                    if (pop !== "cc" && ccEdit) { root.ccEditCancel(); ccEdit = false; }
                    if (pop !== "cc") ccPage = "";
                    root.notifOpen = (pop === "notif");
                    if (root.notifOpen) root.notifUnread = 0;
                    if (pop === "wifi") { root.wifiError = ""; root.scanWifi(); root.refreshConnections(); }
                    if (pop === "bt") { root.btError = ""; root.scanBt(); root.refreshBt(); }
                    if (pop === "spot") {
                        spMode = "home"; spQuery = ""; spSel = 0; spExpanded = ({}); clipMenu = false;
                        spInput.text = ""; appsInput.text = ""; clipInput.text = ""; emojiInput.text = "";
                        spFocusTimer.restart();
                    }
                }
                Connections {
                    target: root
                    function onSpotRequestChanged() {
                        var fm = Hyprland.focusedMonitor;
                        if (!(!fm || fm.name === win.modelData.name || Quickshell.screens.length === 1)) return;
                        var want = root.spotWant;
                        if (ui.pop === "spot") {
                            if (want === "home" || want === ui.spMode) ui.pop = "";
                            else ui.spSetMode(want);
                        } else {
                            ui.spReqCalm = (want === "clip" || want === "emoji");
                            ui.openPop("spot", 0);
                            if (want !== "home") ui.spSetMode(want);
                        }
                    }
                }

                Connections {
                    target: root
                    function onNotifPopRequest(open) {
                        if (!ui.toastScreen) return;
                        if (open) ui.openPop("notif", bellBtn.visible ? bellBtn.mapToItem(ui, 0, 0).x : ui.width - 60); else if (ui.pop === "notif") ui.pop = "";
                    }
                }
                function openPop(name, x) {
                    if (pop === name) { pop = ""; return; }
                    if (name === "spot") { spCalm = spReqCalm; spReqCalm = false; }
                    menuX = x;
                    if (["apple", "app", "file", "edit", "view", "window", "help"].indexOf(name) >= 0) root.refreshActive();
                    if (["apple", "app", "file", "edit", "view", "window", "help"].indexOf(name) >= 0) menuModel = root.menuModelFor(name);
                    if (name === "cal") { var d = new Date(); calYear = d.getFullYear(); calMonth = d.getMonth(); }
                    pop = name;
                }
                function hoverPop(name, x) {
                    if (!isMenu || name === pop) return;
                    menuX = x;
                    menuModel = root.menuModelFor(name);
                    pop = name;
                }
                function calCells() {
                    var first = new Date(calYear, calMonth, 1);
                    var off = (first.getDay() - (root.weekStartsMonday ? 1 : 0) + 7) % 7;
                    var today = new Date(), out = [];
                    for (var i = 0; i < 42; i++) {
                        var d = new Date(calYear, calMonth, 1 - off + i);
                        out.push({ n: d.getDate(), cur: d.getMonth() === calMonth,
                                   today: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate() });
                    }
                    return out;
                }
                function shiftMonth(delta) {
                    var d = new Date(calYear, calMonth + delta, 1);
                    calYear = d.getFullYear(); calMonth = d.getMonth();
                }
                readonly property var calData: { clock.date; return calCells(); }

                Loader {
                    id: glassBackdrop
                    active: root.liquidBase
                    sourceComponent: backdropComp
                    onLoaded: item.region = Qt.binding(function () { return ui.glassRect; })
                }
                Capture {
                    id: screenSnap
                    x: 0; y: 0
                    width: win.modelData.width; height: win.modelData.height
                    opacity: 0
                    source: root.liquidActive && !root.captureQuiet && !glassBackdrop.item ? win.modelData : null
                    live: false
                    paintCursor: false
                    property real takenAt: 0
                    function grab() { if (captureSource && typeof captureFrame === "function") { captureFrame(); takenAt = Date.now(); } }
                }
                property bool snapFresh: false
                Timer {
                    id: toneT; interval: 20
                    onTriggered: {
                        var r = ui.glassRect;
                        if (r.width <= 128) return;
                        root.measureAround(win.modelData, Qt.rect(win.modelData.x + r.x + 64, win.modelData.y + r.y + 64, r.width - 128, r.height - 128), false);
                    }
                }
                Connections {
                    target: root
                    function onBarRelayout() {
                        screenSnap.takenAt = 0;
                        ui.snapFresh = false;
                        if (ui.pop !== "" && ui.pop !== "spot") toneT.restart();
                        else if (barHover.hovered && ui.pop === "") screenSnap.grab();
                    }
                }
                readonly property Item glassSrc: glassBackdrop.item ? glassBackdrop.item : ((snapFresh && screenSnap.hasContent) ? screenSnap : null)
                HoverHandler {
                    id: barHover
                    onHoveredChanged: if (hovered && ui.pop === "") screenSnap.grab()
                }
                Timer { interval: 600; repeat: true; running: barHover.hovered && ui.pop === ""; onTriggered: screenSnap.grab() }
                Timer { interval: 250; repeat: true; running: true; onTriggered: ui.snapFresh = (Date.now() - screenSnap.takenAt) < 3000 || (ui.pop !== "" && ui.snapFresh) }

                ShaderEffectSource {
                    sourceItem: glassBackdrop.item
                    hideSource: true
                    live: true
                    width: 1; height: 1
                    opacity: 0.01
                    sourceRect: Qt.rect(0, 0, 1, 1)
                }
                Component {
                    id: backdropComp
                    Item {
                        id: bd
                        opacity: 0
                        property bool hostShown: true
                        property bool onDemand: false
                        property rect region: Qt.rect(0, 0, 0, 0)
                        x: 0; y: 0
                        width: win.modelData ? win.modelData.width : 0
                        height: win.modelData ? win.modelData.height : 0

                        Rectangle {
                            z: -3
                            anchors.fill: parent
                            visible: bdWall.status === Image.Error || (bdWall.source == "" && !!root.hub && root.hub.wallpaperReady)
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#2f6bff" }
                                GradientStop { position: 0.5; color: "#b44cff" }
                                GradientStop { position: 1.0; color: "#ff8a3d" }
                            }
                        }
                        Image {
                            id: bdWall
                            z: -2
                            anchors.fill: parent
                            visible: status === Image.Ready
                            source: root.fileUrl(root.wallpaperFor(win.modelData?.name))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: bd.width
                            smooth: true
                        }
                        LiveWall {
                            id: barWall
                            z: -2
                            anchors.fill: parent
                            video: root.glassVideo
                            live: true
                            paused: root.wallIdle(win.modelData?.name) || !bd.hostShown
                            startDelay: bd.onDemand ? 250 : -1
                            clock: root.wallClock
                        }

                        Repeater {
                            model: (root.hub && root.hub.widgets && Quickshell.screens.length > 0 && win.modelData?.name === Quickshell.screens[0].name)
                                   ? root.hub.widgets.model : null
                            delegate: Item {
                                id: mw
                                visible: ui.anyVisible || levelOsd.visible || spotWin.openish || swWin.visible || wpWin.visible
                                required property string wid
                                required property string wtype
                                required property string wsrc
                                required property string wstyle
                                required property string wsize
                                required property string wspan
                                required property string wmode
                                required property real wx
                                required property real wy
                                z: -1
                                x: wx; y: wy
                                width: root.hub.widgets.dims(wspan)[0]
                                height: root.hub.widgets.dims(wspan)[1]
                                WidgetVisual {
                                    anchors.fill: parent
                                    host: root.hub.widgets
                                    wallItem: barWall
                                    wtype: mw.wtype; wstyle: mw.wstyle; wsize: mw.wsize; wmode: mw.wmode; wsrc: mw.wsrc
                                    wlay: root.hub.widgets.layoutOf(mw.wspan, mw.wtype)
                                    sx: mw.x; sy: mw.y
                                    sname: win.modelData.name; sw: win.modelData.width; sh: win.modelData.height
                                }
                            }
                        }

                        ListModel { id: wm }
                        Repeater {
                            id: wrep
                            model: wm
                            delegate: Item {
                                id: gw
                                required property string addr
                                required property real wx
                                required property real wy
                                required property real ww
                                required property real wh
                                required property real wz
                                required property bool gone
                                property alias cap: sv
                                x: wx; y: wy; width: ww; height: wh; z: wz
                                readonly property var tl: { if (!root.hub) return null; var t = root.hub.tlTick; return root.hub.tlFor(addr); }
                                readonly property bool folderTerm: root.wpTermAddr !== "" && String(addr).replace(/^0x/, "") === root.wpTermAddr
                                readonly property bool onGlass: bd.region.width > 0 && x < bd.region.x + bd.region.width && x + width > bd.region.x
                                                                && y < bd.region.y + bd.region.height && y + height > bd.region.y
                                Capture {
                                    id: sv
                                    anchors.fill: parent
                                    source: gw.tl
                                    readonly property var wa: root.hub ? root.hub.winAlpha(gw.addr) : ({ bg: 1, win: 1 })
                                    opacity: wa.win
                                    layer.enabled: wa.bg < 0.999
                                    layer.effect: ShaderEffect { property real bgAlpha: sv.wa.bg; fragmentShader: Qt.resolvedUrl("capalpha.frag.qsb") }
                                    property bool hush: root.captureQuiet
                                    Connections {
                                        target: root
                                        function onCaptureQuietChanged() { hushT.interval = 20 + Math.random() * 600; hushT.restart(); }
                                    }
                                    Timer { id: hushT; onTriggered: sv.hush = root.captureQuiet }
                                    readonly property bool glassUp: ui.anyVisible || levelOsd.visible || spotWin.openish || swWin.visible || wpWin.visible
                                    readonly property bool onBar: root.barGlass && root.liquidActive && gw.y < root.barH + 4
                                    readonly property bool need: !gw.gone && !root.captureHeld && bd.hostShown && (!sv.hush || gw.onGlass) && (glassUp || onBar)
                                                                 && (!gw.folderTerm || gw.onGlass)
                                    onNeedChanged: { if (need && captureSource !== null && typeof captureFrame === "function") captureFrame(); }
                                    onCaptureSourceChanged: {
                                        if (captureSource !== null && need) firstShot.restart();
                                    }
                                    Timer {
                                        id: firstShot
                                        interval: 90
                                        onTriggered: { if (sv.need && sv.captureSource !== null && typeof sv.captureFrame === "function") sv.captureFrame(); }
                                    }
                                    Timer {
                                        interval: sv.hush ? 150 : ((sv.glassUp && root.glassRealtime) ? 33 : 250); repeat: true
                                        running: sv.need && sv.captureSource !== null
                                        onTriggered: { if (typeof sv.captureFrame === "function") sv.captureFrame(); }
                                    }
                                }
                            }
                        }

                        function recapture() {
                            for (var q = 0; q < wrep.count; q++) {
                                var it = wrep.itemAt(q);
                                if (it && it.cap && it.cap.captureSource !== null && typeof it.cap.captureFrame === "function") it.cap.captureFrame();
                            }
                        }
                        Connections {
                            target: root
                            function onBarRelayout() { bd.sync(); bd.recapture(); }
                        }
                        function sync() {
                            var mon = null, i;
                            for (i = 0; i < root.monData.length; i++)
                                if (root.monData[i].name === win.modelData.name) mon = root.monData[i];
                            if (!mon) return;
                            var ws = [mon.activeWorkspace && mon.activeWorkspace.name ? mon.activeWorkspace.name : "\u0000none"];
                            if (mon.specialWorkspace && mon.specialWorkspace.name) ws.push(mon.specialWorkspace.name);
                            var zoneBottom = bd.height;
                            var want = {};
                            var cs = root.glassClients;
                            for (var c = 0; c < cs.length; c++) {
                                var cl = cs[c];
                                if (!cl.mapped || cl.hidden || cl.monitor !== mon.id || !cl.workspace || ws.indexOf(cl.workspace.name) < 0) continue;
                                var x = cl.at[0] - mon.x, y = cl.at[1] - mon.y, w = cl.size[0], h = cl.size[1];
                                if (x + w <= 0 || x >= bd.width || y + h <= 0 || y >= zoneBottom) continue;
                                var z = cl.floating ? 100 - Math.min(cl.focusHistoryID, 90) : 0;
                                want[cl.address] = { addr: cl.address, wx: x, wy: y, ww: w, wh: h, wz: z, gone: false };
                            }
                            for (var j = wm.count - 1; j >= 0; j--) {
                                var a = wm.get(j).addr;
                                if (want[a] === undefined) { if (!wm.get(j).gone) { wm.setProperty(j, "gone", true); sweep.restart(); } }
                                else { wm.set(j, want[a]); delete want[a]; }
                            }
                            for (var k in want) wm.append(want[k]);
                        }
                        Timer {
                            id: sweep
                            interval: 600
                            onTriggered: { for (var q = wm.count - 1; q >= 0; q--) if (wm.get(q).gone) wm.remove(q); }
                        }
                        Connections {
                            target: root
                            function onGlassClientsChanged() { bd.sync(); }
                            function onMonDataChanged() { bd.sync(); }
                        }
                        Component.onCompleted: sync()
                    }
                }

                Item {
                    id: maskItem
                    x: 0; y: 0
                    width: ui.width
                    height: (ui.pop !== "" && ui.pop !== "spot") ? ui.height : root.barH
                }

                ShaderEffectSource {
                    id: bhSrc
                    readonly property real m: 64
                    sourceItem: root.liquidActive ? ui.glassSrc : null
                    hideSource: true
                    live: true
                    visible: false
                    sourceRect: Qt.rect(-m, -m, ui.width + 2 * m, root.barH + 2 * m)
                }
                MultiEffect {
                    id: bhFx
                    source: bhSrc
                    width: bhSrc.sourceRect.width; height: bhSrc.sourceRect.height
                    blurEnabled: true
                    blurMax: 64
                    blur: Math.min(1.0, root.glassBlurEff * 1.4 / 64.0)
                    autoPaddingEnabled: false
                    visible: false
                }
                ShaderEffectSource { id: bhBlur; sourceItem: bhFx; live: true; visible: false }
                GlassCtx {
                    id: barCtx
                    src: bhBlur
                    srcRect: bhSrc.sourceRect
                    frame: ui
                    liquid: root.liquidActive && ui.glassSrc !== null
                    shaderUrl: root.glassShaderUrl
                    dark: !root.barTextDark
                    tint: root.glassOpacity * 0.6
                    strength: root.glassLiquidEff
                    blur: root.glassBlurEff
                    rim: root.glassRimEff
                    grain: root.glassGrain
                    debug: root.glassDebug
                    onFailed: root.glassState = "failed"
                }
                Component {
                    id: barTileGlassComp
                    GGlass { gx: barCtx; cornerR: 8; thickness: 10; strengthMul: 1.0; shadowAmt: 0 }
                }
                readonly property Component barTileGlass: barCtx.liquid ? barTileGlassComp : null

                GGlass {
                    id: barGlassStrip
                    visible: root.barGlass && barCtx.liquid
                    x: 0; y: 0
                    width: ui.width
                    height: root.barH
                    gx: barCtx
                    cornerR: 0
                    thickness: 16
                    strengthMul: 0.9
                    shadowAmt: 1
                }

                MouseArea {
                    anchors.fill: parent
                    z: 5
                    visible: ui.pop !== "" && ui.pop !== "spot"
                    acceptedButtons: Qt.AllButtons
                    onPressed: ui.pop = ""
                }

                // the dragged window morphing into its app icon under the cursor while it is over a workspace number, and back;
                // after letting go the icon drops into the number
                Item {
                    id: dragGhost
                    readonly property var scr: perScreen.modelData
                    readonly property bool dropping: dropAnim.running
                    readonly property real t: dropping ? 1 : root.dragT
                    function mix(a, b, k) { return a + (b - a) * k; }
                    function ease(a, b, k) { k = Math.max(0, Math.min(1, (k - a) / (b - a))); return k * k * (3 - 2 * k); }
                    readonly property bool here: root.dragX >= scr.x && root.dragX < scr.x + scr.width && root.dragY >= scr.y && root.dragY < scr.y + scr.height
                    readonly property real ds: mix(48, 12, root.dropT)
                    z: 1001
                    visible: dropping || (root.drag !== null && here && (root.dragCover || root.dragT > 0.002))
                    x: dropping ? mix(root.dropFrom.x, root.dropTo.x, root.dropT) - scr.x - ds / 2 : mix(root.dragWinX - scr.x, root.dragX - scr.x - 24, t)
                    y: dropping ? mix(root.dropFrom.y, root.dropTo.y, root.dropT) - scr.y - ds / 2 : mix(root.dragWinY - scr.y, root.dragY - scr.y + 12, t)
                    width: dropping ? ds : mix(root.dragWinW, 48, t)
                    height: dropping ? ds : mix(root.dragWinH, 48, t)
                    opacity: dropping ? 1 - ease(0.55, 1, root.dropT) : 1
                    RectangularShadow {
                        anchors.fill: parent; radius: ghostSnap.radius; blur: dragGhost.mix(30, 14, dragGhost.t); offset.y: dragGhost.mix(10, 4, dragGhost.t)
                        // Hyprland draws the window's own shadow until it is hidden
                        color: Qt.rgba(0, 0, 0, 0.32 * dragGhost.ease(0, 0.15, dragGhost.t) * (1 - dragGhost.ease(0.3, 0.9, dragGhost.t)))
                    }
                    Item {
                        id: ghostSnap
                        readonly property real radius: dragGhost.mix(16, 12, dragGhost.t)
                        anchors.fill: parent
                        opacity: 1 - dragGhost.ease(0.3, 0.8, dragGhost.t)
                        visible: opacity > 0
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: ghostMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                        // live: a capture ignores the window's opacity, so it keeps showing the window's content while it is hidden;
                        // started over the number, as a capture breaks when Hyprland resizes the window (fullscreen let go to drag)
                        Capture {
                            anchors.fill: parent
                            source: dragGhost.here && dragGhost.visible && !dragGhost.dropping ? root.dragTl : null
                            live: dragGhost.visible && !dragGhost.dropping
                            onHasContentChanged: if (dragGhost.here) root.dragSnapReady = hasContent
                        }
                    }
                    Item { id: ghostMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: ghostSnap.radius; color: "black" } }
                    Image {
                        anchors.fill: parent
                        source: root.dragIcon
                        sourceSize: Qt.size(96, 96)
                        smooth: true; mipmap: true
                        opacity: dragGhost.ease(0.35, 0.85, dragGhost.t)
                        visible: opacity > 0
                    }
                }

                Item {
                    id: levelOsd
                    z: 1000
                    width: 256; height: 67
                    x: ui.width - width - 22
                    y: root.barH + 14
                    visible: ui.toastScreen && opacity > 0
                    opacity: root.osdVisible ? 1 : 0
                    scale: root.osdVisible ? 1 : 0.94
                    transformOrigin: Item.TopRight
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    // the same glass as the bar's popups (volume, Wi-Fi, calendar); it is drawn unscaled, hence the division
                    PopGlassCtx { id: osdGlass; pop: levelOsd; frame: ui; source: ui.glassSrc; fullW: levelOsd.width / root.barPopupScale; fullH: levelOsd.height / root.barPopupScale }
                    GGlass { anchors.fill: parent; gx: osdGlass.ctx; cornerR: height / 2; thickness: 22; shadowAmt: 0; flatInner: 1 }
                    MenuBorder { z: 2; anchors.fill: parent; cornerR: height / 2; dark: osdGlass.ctx.dark; tint: osdGlass.ctx.borderTint; amount: 1 }
                    Glyph {
                        x: 20; anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24
                        kind: root.osdKind === "brightness" ? "sun" : "speaker"
                        level: root.osdKind === "brightness" ? 3 : (root.osdValue < 0.34 ? 1 : (root.osdValue < 0.67 ? 2 : 3))
                        color: pal.fg
                    }
                    Row {
                        id: osdBar
                        x: 62; anchors.verticalCenter: parent.verticalCenter
                        readonly property int n: 22
                        readonly property real segW: (levelOsd.width - 62 - 24 - (n - 1) * 3) / n
                        spacing: 3
                        Repeater {
                            model: osdBar.n
                            Rectangle {
                                required property int index
                                width: osdBar.segW; height: 4; radius: 2
                                color: pal.fg
                                opacity: Math.max(0.28, Math.min(1, root.osdValue * osdBar.n - index) * 0.95)
                                Behavior on opacity { NumberAnimation { duration: 90 } }
                            }
                        }
                    }
                }
                Rectangle {
                    id: barBg
                    visible: root.barEnabled
                    z: 20
                    x: 0; y: 0
                    width: ui.width
                    height: root.barH
                    color: "transparent"
                    MouseArea {
                        id: barWheel
                        anchors.fill: parent
                        onClicked: ui.pop = ""
                        // scrolling the empty bar: left of the workspace numbers sets the brightness, right of them the volume
                        // (one 5% step per mouse notch; a touchpad's small deltas add up to a notch)
                        property real wheelAcc: 0
                        property string wheelSide: ""
                        onWheel: wheel => {
                            var l = leftRow.mapToItem(barWheel, leftRow.width, 0).x, r = rightRow.mapToItem(barWheel, 0, 0).x;
                            var a = wsRow.visible ? wsRow.mapToItem(barWheel, 0, 0).x : width / 2;
                            var b = wsRow.visible ? wsRow.mapToItem(barWheel, wsRow.width, 0).x : width / 2;
                            var side = wheel.x > l && wheel.x < a ? "brightness" : (wheel.x > b && wheel.x < r ? "volume" : "");
                            if (side === "") { wheel.accepted = false; return; }
                            if (side !== wheelSide) { wheelSide = side; wheelAcc = 0; }
                            wheelAcc += wheel.angleDelta.y;
                            while (Math.abs(wheelAcc) >= 120) {
                                var d = wheelAcc > 0 ? 0.05 : -0.05;
                                wheelAcc -= wheelAcc > 0 ? 120 : -120;
                                if (side === "brightness") root.hwBrightness(d); else root.hwVolume(d);
                            }
                        }
                    }

                    Row {
                        id: leftRow
                        x: 8
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        transformOrigin: Item.Left
                        scale: root.barWidgetScale
                        Repeater {
                            model: root.menuTitles.filter(function (item) {
                                return item.id === "apple" ? root.barWidgetEnabled("appleMenu") : root.barWidgetEnabled("appMenus");
                            })
                            delegate: Item {
                                id: mt
                                required property var modelData
                                readonly property bool open: ui.pop === modelData.id
                                readonly property bool activeApp: modelData.id === "app"
                                width: modelData.id === "apple" ? 30 : tl.implicitWidth + 20
                                height: 28
                                BarHover { glass: ui.barTileGlass; id: mtHl; dark: bpal.dark; area: mtMa; hot: mtMa.containsMouse; pressed: mtMa.pressed; open: mt.open }
                                Glyph {
                                    visible: mt.modelData.id === "apple" && root.barLogoMode === "arch"
                                    anchors.centerIn: parent
                                    scale: mtHl.lift
                                    width: 15; height: 15
                                    kind: "arch"
                                    color: bpal.fg
                                }
                                Image {
                                    visible: mt.modelData.id === "apple" && root.barLogoMode === "apple"
                                    anchors.centerIn: parent
                                    scale: mtHl.lift
                                    width: 15; height: 15
                                    source: !root.barTextDark ? Qt.resolvedUrl("apple-logo-white.svg") : Qt.resolvedUrl("apple-logo-black.svg")
                                    sourceSize: Qt.size(128, 160)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }
                                Image {
                                    id: customBarLogo
                                    visible: mt.modelData.id === "apple" && root.barLogoMode === "custom" && root.barCustomLogoUrl !== ""
                                    anchors.centerIn: parent
                                    scale: mtHl.lift
                                    width: 17; height: 17
                                    source: root.barCustomLogoUrl
                                    sourceSize: Qt.size(64, 64)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }
                                Glyph {
                                    visible: mt.modelData.id === "apple" && root.barLogoMode === "custom"
                                             && (root.barCustomLogoUrl === "" || customBarLogo.status === Image.Error)
                                    anchors.centerIn: parent
                                    scale: mtHl.lift
                                    width: 15; height: 15
                                    kind: "arch"
                                    color: bpal.fg
                                }
                                Text {
                                    id: tl
                                    visible: mt.modelData.id !== "apple"
                                    anchors.centerIn: parent
                                    scale: 1 + (mtHl.lift - 1) * 0.4
                                    text: I18n.tr(mt.modelData.label)
                                    color: bpal.fg
                                    font.family: mt.activeApp ? Fonts.forWeight(mt.activeApp ? Font.DemiBold : Font.Normal, root.boldFontFamily)
                                                              : Fonts.forWeight(mt.activeApp ? Font.DemiBold : Font.Normal, "Open Runde")
                                    font.pixelSize: 14
                                    font.weight: mt.activeApp ? Font.DemiBold : Font.Normal
                                }
                                MouseArea {
                                    id: mtMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: ui.openPop(mt.modelData.id, mt.mapToItem(ui, 0, 0).x)
                                    onEntered: ui.hoverPop(mt.modelData.id, mt.mapToItem(ui, 0, 0).x)
                                }
                            }
                        }
                    }

                    Row {
                        id: wsRow
                        visible: root.barWidgetEnabled("workspaces")
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        transformOrigin: Item.Center
                        scale: root.barWidgetScale
                        spacing: 0
                        readonly property var mon: Hyprland.monitorFor(perScreen.modelData)
                        readonly property int activeId: mon && mon.activeWorkspace ? mon.activeWorkspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1)
                        function runAt(i) {
                            var ids = root.wsIds;
                            if (!root.wsOccupied(ids[i]) || (i > 0 && root.wsOccupied(ids[i - 1]))) return 0;
                            var n = 0;
                            while (i + n < ids.length && root.wsOccupied(ids[i + n])) n++;
                            return n;
                        }
                        Repeater {
                            model: root.wsIds
                            delegate: Item {
                                id: wsi
                                required property var modelData
                                required property int index
                                readonly property bool cur: wsRow.activeId === modelData
                                readonly property bool busy: root.wsOccupied(modelData)
                                readonly property int run: { root.wsCounts; root.wsIds; return wsRow.runAt(index); }
                                // a dragged window is over this number (from the screen's top edge down to just under the bar)
                                readonly property bool dropHot: {
                                    if (!root.drag || !wsRow.visible) return false;
                                    var a = wsi.mapToItem(null, 0, 0), b = wsi.mapToItem(null, wsi.width, 0), s = perScreen.modelData;
                                    return root.dragX >= s.x + a.x && root.dragX < s.x + b.x && root.dragY >= s.y && root.dragY < s.y + root.barH + 6;
                                }
                                onDropHotChanged: {
                                    if (dropHot) { root.dragWsX = perScreen.modelData.x + wsi.mapToItem(null, wsi.width / 2, 0).x; root.dragWs = modelData; }
                                    else if (root.dragWs === modelData) root.dragWs = null;
                                }
                                width: root.wsCellW(modelData); height: 28
                                GlassHover {
                                    id: wsRun
                                    property int cells: 1
                                    readonly property int want: wsi.run
                                    onWantChanged: if (want > 0) cells = want
                                    Component.onCompleted: if (want > 0) cells = want
                                    x: 1; y: 3
                                    width: { var w = 0, ids = root.wsIds; for (var k = 0; k < cells; k++) w += root.wsCellW(ids[wsi.index + k] || 0); return w - 2; }
                                    height: 22
                                    radius: 8
                                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                    dark: bpal.dark
                                    filled: wsi.run > 0
                                    glass: ui.barTileGlass
                                }
                                BarHover { glass: ui.barTileGlass; id: wsHl; dark: bpal.dark; area: wsMa; hot: wsMa.containsMouse || wsi.dropHot; pressed: wsMa.pressed; open: wsi.cur }
                                Text {
                                    anchors.centerIn: parent
                                    scale: wsi.cur ? 1 : wsHl.lift
                                    text: root.wsLabel(wsi.modelData)
                                    color: wsi.cur ? bpal.fg : (wsi.busy ? bpal.fg2 : bpal.fg3)
                                    font.family: root.fontForWeight(wsi.cur ? Font.DemiBold : Font.Normal, bpal.fam)
                                    font.pixelSize: 13
                                    font.weight: wsi.cur ? Font.DemiBold : Font.Normal
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                }
                                MouseArea {
                                    id: wsMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { ui.pop = ""; root.hlWorkspace("" + wsi.modelData); }
                                }
                            }
                        }
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => root.hlWorkspace(event.angleDelta.y > 0 ? "e-1" : "e+1")
                        }
                    }

                    Row {
                        id: rightRow
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28
                        transformOrigin: Item.Right
                        scale: root.barWidgetScale
                        spacing: 0

                        Repeater {
                            model: root.showTray ? SystemTray.items : null
                            delegate: Item {
                                id: tray
                                required property var modelData
                                width: 26; height: 28
                                BarHover { glass: ui.barTileGlass; id: trHl; dark: bpal.dark; area: trMa; hot: trMa.containsMouse; pressed: trMa.pressed; open: ui.pop === "tray" && ui.trayItem === tray.modelData }
                                readonly property bool isIM: String(modelData.id).toLowerCase() === "fcitx"
                                readonly property string imLabel: !isIM ? ""
                                    : root.fcitxIM !== "" ? root.imLabelFor(root.fcitxIM, "")
                                    : root.imLabelFor(String(modelData.icon), String(modelData.tooltipTitle))
                                Glyph {
                                    visible: tray.isIM && tray.imLabel === ""
                                    anchors.centerIn: parent
                                    scale: trHl.lift
                                    width: 17; height: 17
                                    kind: "keyboard"
                                    color: bpal.fg
                                }
                                Text {
                                    visible: tray.isIM && tray.imLabel !== ""
                                    anchors.centerIn: parent
                                    scale: trHl.lift
                                    text: tray.imLabel
                                    color: bpal.fg
                                    font.family: root.fontForWeight(Font.DemiBold, bpal.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                                }
                                Image {
                                    visible: !tray.isIM
                                    anchors.centerIn: parent
                                    scale: trHl.lift
                                    width: 16; height: 16
                                    source: tray.isIM ? "" : tray.modelData.icon
                                    sourceSize: Qt.size(32, 32)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                                MouseArea {
                                    id: trMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onClicked: mouse => {
                                        var p = tray.mapToItem(ui, 0, 0);
                                        if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && tray.modelData.onlyMenu))
                                            ui.openTray(tray.modelData, p.x);
                                        else if (mouse.button === Qt.MiddleButton)
                                            tray.modelData.secondaryActivate();
                                        else
                                            tray.modelData.activate();
                                    }
                                }
                            }
                        }

                        Item {
                            id: wallBtn
                            readonly property bool shown: root.showWallButton && root.videoWall
                            readonly property bool idle: root.wallIdle(win.modelData.name)
                            visible: shown
                            width: shown ? 28 : 0; height: 28
                            BarHover { glass: ui.barTileGlass; id: wallHl; dark: bpal.dark; area: wallMa; hot: wallMa.containsMouse; pressed: wallMa.pressed }
                            Glyph { anchors.centerIn: parent; scale: wallHl.lift; width: 16; height: 16; kind: "livewall"; flag: wallBtn.idle; color: wallBtn.idle ? bpal.fg2 : bpal.fg }
                            MouseArea { id: wallMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.wallUserPaused = !root.wallUserPaused }
                        }
                        Item {
                            id: btBtn
                            visible: root.barWidgetEnabled("bluetooth") && root.hasBt
                            width: (root.barWidgetEnabled("bluetooth") && root.hasBt) ? 26 : 0; height: 28
                            BarHover { glass: ui.barTileGlass; id: btHl; dark: bpal.dark; area: btMa; hot: btMa.containsMouse; pressed: btMa.pressed; open: ui.pop === "bt" }
                            Glyph { anchors.centerIn: parent; scale: btHl.lift; width: 15; height: 15; kind: "bluetooth"; color: root.btOn && root.btConnected > 0 ? bpal.fg : bpal.fg2 }
                            MouseArea { id: btMa; anchors.fill: parent; hoverEnabled: true; onClicked: ui.openPop("bt", btBtn.mapToItem(ui, 0, 0).x) }
                        }
                        Item {
                            id: volBtn
                            visible: root.barWidgetEnabled("volume")
                            width: root.barWidgetEnabled("volume") ? 28 : 0; height: 28
                            BarHover { glass: ui.barTileGlass; id: volHl; dark: bpal.dark; area: volMa; hot: volMa.containsMouse; pressed: volMa.pressed; open: ui.pop === "vol" }
                            Glyph { anchors.centerIn: parent; scale: volHl.lift; width: 16; height: 16; kind: "speaker"; level: root.volLevel; color: bpal.fg }
                            MouseArea {
                                id: volMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ui.openPop("vol", volBtn.mapToItem(ui, 0, 0).x + volBtn.width / 2)
                                onWheel: wheel => root.setVolume(root.volume + (wheel.angleDelta.y > 0 ? 0.03 : -0.03))
                            }
                        }
                        Item {
                            id: kbBtn
                            visible: root.barWidgetEnabled("keyboard") && root.kbLayouts.length > 1
                            width: root.barWidgetEnabled("keyboard") && root.kbLayouts.length > 1 ? 34 : 0; height: 28
                            BarHover { glass: ui.barTileGlass; id: kbHl; dark: bpal.dark; area: kbMouse; hot: kbMouse.containsMouse; pressed: kbMouse.pressed; open: ui.pop === "kb" }
                            Text {
                                anchors.centerIn: parent
                                scale: kbHl.lift
                                text: root.keyboardLayout
                                color: bpal.fg
                                font.family: root.fontForWeight(Font.DemiBold, bpal.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: kbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) ui.openPop("kb", kbBtn.mapToItem(ui, 0, 0).x + kbBtn.width / 2);
                                    else root.cycleKeyboardLayout(1);
                                }
                                onWheel: wheel => root.cycleKeyboardLayout(wheel.angleDelta.y > 0 ? -1 : 1)
                            }
                        }
                        Item {
                            visible: root.hasBattery
                            width: root.hasBattery ? batRow.width + 14 : 0; height: 28
                            BarHover { glass: ui.barTileGlass; id: batHl; dark: bpal.dark; area: batMa; hot: batMa.containsMouse; pressed: batMa.pressed; open: ui.pop === "cc" }
                            Row {
                                id: batRow
                                anchors.centerIn: parent
                                scale: 1 + (batHl.lift - 1) * 0.5
                                spacing: 5
                                Text {
                                    visible: root.showBatteryPercent
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.batPct + "%"
                                    color: bpal.fg
                                    font.family: root.fontForWeight(Font.Normal, bpal.fam); font.pixelSize: 12
                                }
                                Item {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 25; height: 12
                                    Rectangle {
                                        id: bbody
                                        width: 22; height: 12; radius: 3.5
                                        color: "transparent"
                                        border.width: 1
                                        border.color: bpal.fg2
                                        Rectangle {
                                            x: 1.5; y: 1.5
                                            width: Math.max(2, (parent.width - 3) * Math.min(1, root.batPct / 100))
                                            height: parent.height - 3
                                            radius: 2
                                            color: root.charging ? "#30D158" : (root.batPct <= 15 ? "#FF453A" : bpal.fg)
                                        }
                                    }
                                    Rectangle { x: 23; y: 4; width: 2; height: 4; radius: 1; color: bpal.fg2 }
                                    Glyph {
                                        visible: root.charging
                                        anchors.centerIn: bbody
                                        width: 9; height: 9
                                        kind: "bolt"
                                        color: bpal.dark ? "#111" : "#fff"
                                    }
                                }
                            }
                            MouseArea { id: batMa; anchors.fill: parent; hoverEnabled: true; onClicked: ui.openPop("cc", 0) }
                        }
                        Item {
                            id: bellBtn
                            visible: root.barWidgetEnabled("notifications")
                            width: root.barWidgetEnabled("notifications") ? 28 : 0; height: 28
                            BarHover { glass: ui.barTileGlass; id: bellHl; dark: bpal.dark; area: bellMa; hot: bellMa.containsMouse; pressed: bellMa.pressed; open: ui.pop === "notif" }
                            Glyph { anchors.centerIn: parent; scale: bellHl.lift; width: 16; height: 16; kind: "bell"; color: root.dndActive ? bpal.fg2 : bpal.fg }
                            Rectangle {
                                visible: root.notifUnread > 0 && !root.dndActive
                                x: parent.width / 2 + 2; y: parent.height / 2 - 8
                                width: 7; height: 7; radius: 3.5
                                color: "#FF453A"
                            }
                            MouseArea { id: bellMa; anchors.fill: parent; hoverEnabled: true; onClicked: ui.openPop("notif", bellBtn.mapToItem(ui, 0, 0).x) }
                        }
                        Item {
                            id: wifiBtn
                            visible: root.barWidgetEnabled("wifi")
                            width: root.barWidgetEnabled("wifi") ? 28 : 0; height: 28
                            BarHover { glass: ui.barTileGlass; id: wifiHl; dark: bpal.dark; area: wifiMa; hot: wifiMa.containsMouse; pressed: wifiMa.pressed; open: ui.pop === "wifi" }
                            Glyph { anchors.centerIn: parent; scale: wifiHl.lift; width: 16; height: 16; kind: root.showEthernet ? "ethernet" : "wifi"; level: root.wifiOn ? (root.wifiLevel || 1) : 3; flag: !root.wifiOn && !root.showEthernet; color: (root.wifiOn || root.showEthernet) ? bpal.fg : bpal.fg2 }
                            MouseArea { id: wifiMa; anchors.fill: parent; hoverEnabled: true; onClicked: ui.openPop("wifi", wifiBtn.mapToItem(ui, 0, 0).x) }
                        }
                        Item {
                            visible: root.showSearch
                            width: root.showSearch ? 28 : 0; height: 28
                            BarHover { glass: ui.barTileGlass; id: srchHl; dark: bpal.dark; area: srchMa; hot: srchMa.containsMouse; pressed: srchMa.pressed; open: ui.pop === "spot" }
                            Glyph { anchors.centerIn: parent; scale: srchHl.lift; width: 15; height: 15; kind: "search"; color: bpal.fg }
                            MouseArea { id: srchMa; anchors.fill: parent; hoverEnabled: true; onClicked: { if (root.launcher !== "") { ui.pop = ""; root.search(); } else ui.openPop("spot", 0); } }
                        }
                        Item {
                            id: ccBtn
                            visible: root.ccEnabled && root.barWidgetEnabled("controlCenter")
                            readonly property bool dotsOn: root.privacyAny && root.barWidgetEnabled("privacy")
                            width: (root.ccEnabled && root.barWidgetEnabled("controlCenter")) ? 30 + (dotsOn ? ccDots.width + 2 : 0) : 0; height: 28
                            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            BarHover { glass: ui.barTileGlass; id: ccHl; dark: bpal.dark; area: ccMa; hot: ccMa.containsMouse; pressed: ccMa.pressed; open: ui.pop === "cc" }
                            Glyph { x: 7; anchors.verticalCenter: parent.verticalCenter; scale: ccHl.lift; width: 16; height: 16; kind: "cc"; color: bpal.fg }
                            Row {
                                id: ccDots
                                visible: ccBtn.dotsOn
                                x: 27
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Repeater {
                                    model: root.privacyDots
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 7; height: 7; radius: 3.5
                                        color: modelData
                                        border.width: 0.5
                                        border.color: Qt.rgba(0, 0, 0, 0.35)
                                    }
                                }
                            }
                            MouseArea { id: ccMa; anchors.fill: parent; hoverEnabled: true; onClicked: ui.openPop("cc", 0) }
                        }
                        Item {
                            id: clockBtn
                            visible: root.barWidgetEnabled("clock")
                            width: root.barWidgetEnabled("clock") ? clockText.implicitWidth + 16 : 0
                            height: 28
                            BarHover { glass: ui.barTileGlass; id: clockHl; dark: bpal.dark; area: clockMa; hot: clockMa.containsMouse; pressed: clockMa.pressed; open: ui.pop === "cal" }
                            Text {
                                id: clockText
                                anchors.centerIn: parent
                                scale: 1 + (clockHl.lift - 1) * 0.4
                                text: root.clockText
                                color: bpal.fg
                                font.family: Fonts.forWeight(Font.DemiBold, root.boldFontFamily)
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.1
                                font.hintingPreference: Font.PreferNoHinting
                                font.kerning: true
                                renderType: Text.QtRendering
                                verticalAlignment: Text.AlignVCenter
                                anchors.verticalCenterOffset: 0.5
                            }
                            MouseArea { id: clockMa; anchors.fill: parent; hoverEnabled: true; onClicked: { ui.calSrcW = clockBtn.width; ui.openPop("cal", clockBtn.mapToItem(ui, 0, 0).x); } }
                        }
                    }
                }

                Item {
                    id: volPop
                    z: 10
    readonly property real ps: root.barPopupScale
                    readonly property real fullW: 330
                    readonly property real fullH: Math.min(volCol.height + 28, ui.height - root.barH - 40)
                    readonly property real srcW: 26
                    readonly property real srcH: 22
                    readonly property real srcX: ui.menuX - 13
                    readonly property real srcY: Math.max(0, (root.barH - srcH) / 2)
                    readonly property real dstX: Math.max(6, Math.min(ui.width - fullW * ps - 8, ui.menuX - fullW * ps / 2))
                    readonly property real dstY: root.barH + 6

                    readonly property bool opening: ui.pop === "vol"
                    property real openT: opening ? 1 : 0
                    Behavior on openT {
                        id: volPopOpenB
                        NumberAnimation {
                            duration: volPopOpenB.targetValue > 0.5 ? 520 : 220
                            easing.type: volPopOpenB.targetValue > 0.5 ? Easing.OutBack : Easing.InOutCubic
                            easing.overshoot: 0.7
                        }
                    }
                    readonly property real t: Math.max(0, Math.min(1, openT))
                    readonly property real contentT: Math.max(0, Math.min(1, (openT - 0.28) / 0.55))

                    width: (srcW + (fullW * ps - srcW) * openT) / ps
                    height: (srcH + (fullH * ps - srcH) * openT) / ps
                    x: srcX + (dstX - srcX) * openT
                    y: srcY + (dstY - srcY) * openT
                    opacity: Math.min(1, t * 4)
                    visible: openT > 0.002
                    scale: ps
                    transformOrigin: Item.TopLeft

                    readonly property real blurAmt: Math.pow(1 - t, 1.3)
                    readonly property bool morphing: openT > 0.002 && Math.abs(openT - 1) > 0.002
                    layer.enabled: morphing
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 48
                        blur: volPop.blurAmt * 0.9
                        autoPaddingEnabled: true
                    }

                    PopGlassCtx { id: volPopGlass; pop: volPop; frame: ui; source: ui.glassSrc; fullW: volPop.fullW; fullH: volPop.fullH }
                    GGlass { anchors.fill: parent; gx: volPopGlass.ctx; cornerR: Math.min(26, 8 + 18 * volPop.t); thickness: 22; shadowAmt: 0; flatInner: 1 }
                    MenuBorder { z: 2; anchors.fill: parent; cornerR: Math.min(26, 8 + 18 * volPop.t); dark: volPopGlass.ctx.dark; tint: volPopGlass.ctx.borderTint; amount: 1 }
                    MouseArea { anchors.fill: parent }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true
                    Item {
                        id: volBody
                        x: -1; y: -1 + 10 * (1 - volPop.contentT)
                        width: volPop.fullW; height: volPop.fullH
                        opacity: volPop.contentT
                    Flickable {
                        id: volFlick
                        x: 0; y: 14
                        width: parent.width
                        height: parent.height - 28
                        contentWidth: width
                        contentHeight: volCol.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        Column {
                            id: volCol
                            x: 14
                            width: volFlick.width - 28
                            spacing: 3

                            Text { x: 4; text: I18n.tr("Output"); color: pal.fg2; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 12; font.weight: Font.DemiBold; bottomPadding: 3 }
                            Item {
                                width: parent.width; height: 32
                                CCSlider {
                                    t: pal; gx: volPopGlass.ctx
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    value: root.muted ? 0 : root.volume
                                    leftKind: "speaker"; leftLevel: root.volLevel
                                    rightKind: "speaker"; rightLevel: 3
                                    onMoved: v => root.setVolume(v)
                                }
                                MouseArea { width: 28; height: parent.height; onClicked: root.toggleMute() }
                            }
                            Repeater {
                                model: root.audioOutputs
                                delegate: AudioRow {
                                    required property var modelData
                                    t: pal
                                    readonly property var parts: root.audioSplit(modelData.description || modelData.name)
                                    title: parts[0]
                                    sub: parts[1]
                                    kind: root.audioKind(modelData, true)
                                    selected: root.sink !== null && root.sink !== undefined && root.sink.id === modelData.id
                                    onClicked: root.chooseAudio(modelData)
                                }
                            }
                            Text { visible: root.audioOutputs.length === 0; x: 4; text: I18n.tr("No output devices"); color: pal.fg2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 12; topPadding: 4; bottomPadding: 4 }
                            Item { width: 1; height: 5 }
                            Text { x: 4; text: I18n.tr("Apps"); color: pal.fg2; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 12; font.weight: Font.DemiBold; bottomPadding: 2 }
                            Repeater {
                                model: root.appAudioKeys
                                delegate: Item {
                                    id: appRow
                                    required property string modelData
                                    readonly property var app: root.appByKey(modelData)
                                    property bool dragging: false
                                    property real dragV: 0
                                    readonly property real vol: dragging ? dragV : (app ? app.volume : 0)
                                    Timer { id: dragEnd; interval: 500; onTriggered: appRow.dragging = false }
                                    visible: app !== null
                                    width: volCol.width - 28; height: app ? 54 : 0
                                    Text {
                                        x: 4; y: 0; width: parent.width - 8
                                        text: (appRow.app ? appRow.app.name : "") + "  ·  " + Math.round(appRow.vol * 100) + "%"
                                        color: pal.fg; elide: Text.ElideRight
                                        font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 12
                                    }
                                    CCSlider {
                                        t: pal; gx: volPopGlass.ctx; x: 0; y: 20; width: parent.width
                                        value: appRow.vol
                                        leftKind: "speaker"; leftLevel: appRow.vol < 0.34 ? 1 : (appRow.vol < 0.67 ? 2 : 3)
                                        rightKind: "speaker"; rightLevel: 3
                                        onMoved: v => {
                                            appRow.dragV = v; appRow.dragging = true; dragEnd.restart();
                                            root.setAppVolume(appRow.app, v);
                                        }
                                    }
                                }
                            }
                            Text { visible: root.appAudioKeys.length === 0; x: 4; text: I18n.tr("No apps are playing audio"); color: pal.fg2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 11; topPadding: 2; bottomPadding: 4 }
                            Item { width: 1; height: 5 }
                            Rectangle { width: parent.width; height: 1; color: pal.sep }
                            Item { width: 1; height: 5 }
                            Item {
                                width: parent.width; height: 32
                                Text { x: 4; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Input"); color: pal.fg2; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 12; font.weight: Font.DemiBold }
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 30; radius: 15
                                    color: root.micMuted ? pal.btnOff : pal.accent
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Glyph { anchors.centerIn: parent; width: 16; height: 16; kind: "mic"; flag: root.micMuted; color: root.micMuted ? pal.fg : "white" }
                                    MouseArea { anchors.fill: parent; onClicked: root.toggleMicMute() }
                                }
                            }
                            Item {
                                width: parent.width; height: 32
                                CCSlider {
                                    t: pal; gx: volPopGlass.ctx
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    value: root.micMuted ? 0 : root.micVolume
                                    leftKind: "mic"; rightKind: "mic"
                                    onMoved: v => root.setMicVolume(v)
                                }
                            }
                            Repeater {
                                model: root.audioInputs
                                delegate: AudioRow {
                                    required property var modelData
                                    t: pal
                                    readonly property var parts: root.audioSplit(modelData.description || modelData.name)
                                    title: parts[0]
                                    sub: parts[1]
                                    kind: "mic"
                                    selected: root.micSource !== null && root.micSource !== undefined && root.micSource.id === modelData.id
                                    onClicked: root.chooseAudio(modelData)
                                }
                            }
                            Text { visible: root.audioInputs.length === 0; x: 4; text: I18n.tr("No input devices"); color: pal.fg2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 12; topPadding: 4; bottomPadding: 4 }
                        }
                    }
                    }
                    }
                }

                Item {
                    id: kbPop
                    z: 10
                    width: 250
                    height: kbCol.height + 16
                    x: Math.max(6, Math.min(ui.width - width * root.barPopupScale - 8, ui.menuX - width / 2))
                    y: root.barH + 6
                    opacity: ui.pop === "kb" ? 1 : 0
                    visible: opacity > 0
                    scale: root.barPopupScale * (ui.pop === "kb" ? 1 : 0.96)
                    transformOrigin: Item.Top
                    Behavior on opacity { NumberAnimation { duration: 110 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    LGlass {
                        anchors.fill: parent
                        backdrop: ui.glassSrc
                        shaderUrl: root.glassShaderUrl
                        liquid: root.liquidActive
                        dark: root.effDark
                        bx: kbPop.x; by: kbPop.y
                        cornerR: 22
                        tint: root.glassOpacity
                        thickness: 22
                        strength: root.glassLiquidEff
                        rim: root.glassRimEff
                        grain: root.glassGrain
                        blur: root.glassBlurEff
                        debug: root.glassDebug
                        onShaderError: root.glassState = "failed"
                        rimTint: 1
                        ringW: 0
                    }
                    MenuBorder {
                        z: 2
                        anchors.fill: parent
                        cornerR: 22
                        dark: root.effDark
                        tint: root.menuBorderColor
                    }
                    MouseArea { anchors.fill: parent }
                    Column {
                        id: kbCol
                        x: 8; y: 8
                        width: parent.width - 16
                        Repeater {
                            model: root.kbLayouts
                            delegate: Item {
                                id: kr
                                required property var modelData
                                required property int index
                                width: parent.width; height: 40
                                Rectangle { anchors.fill: parent; radius: 12; color: pal.hover; opacity: krMa.containsMouse ? 1 : 0 }
                                Text {
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 84
                                    elide: Text.ElideRight
                                    text: kr.modelData.name
                                    color: pal.fg
                                    font.family: root.fontForWeight(kr.index === root.kbIndex ? Font.DemiBold : Font.Normal, pal.fam); font.pixelSize: 13
                                    font.weight: kr.index === root.kbIndex ? Font.DemiBold : Font.Normal
                                }
                                Text {
                                    anchors.right: parent.right; anchors.rightMargin: 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: kr.modelData.code.toUpperCase()
                                    color: pal.fg2
                                    font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 11
                                }
                                Glyph {
                                    visible: kr.index === root.kbIndex
                                    anchors.right: parent.right; anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16; height: 16
                                    kind: "check"; color: pal.fg
                                }
                                MouseArea { id: krMa; anchors.fill: parent; hoverEnabled: true; onClicked: { root.switchKeyboardLayout(kr.index); ui.pop = ""; } }
                            }
                        }
                    }
                }

                Item {
                    id: toastMask
                    x: toastArea.x; y: toastArea.y
                    width: ui.toastsShown ? toastArea.width : 0
                    height: ui.toastsShown ? toastArea.height : 0
                }
                Item {
                    id: toastArea
                    z: 12
                    width: 364
                    x: ui.width - width - 10
                    readonly property real popBottom: {
                        if (ui.pop === "" || ui.pop === "spot") return 0;
                        var items = [menuPop, cc, cal, wifiPop, trayPop, volPop, kbPop], b = 0;
                        for (var i = 0; i < items.length; i++) {
                            var it = items[i];
                            if (!it || !it.visible) continue;
                            if (it.x < x + width && it.x + it.width > x) b = Math.max(b, it.y + it.height);
                        }
                        return b;
                    }
                    y: popBottom > 0 ? popBottom + 12 : root.barH + 8
                    Behavior on y { NumberAnimation { duration: 770; easing.type: Easing.OutQuint } }
                    height: toastCol.height
                    visible: ui.toastsShown && root.notificationsEnabled
                    Column {
                        id: toastCol
                        width: parent.width
                        spacing: 10
                        move: Transition { NumberAnimation { properties: "y"; duration: 770; easing.type: Easing.OutQuint } }
                        Repeater {
                            model: notifToasts
                            delegate: Item {
                                id: toast
                                required property int nid
                                required property string app
                                required property string summary
                                required property string body
                                required property string icon
                                required property int urgency
                                required property real time
                                required property int timeout
                                property bool shown: false
                                property bool leaving: false
                                readonly property int life: timeout > 0 ? timeout : (urgency === 2 ? 10000 : root.notifBannerSecs * 1000)
                                property real t: (shown && !leaving) ? 1 : 0
                                Behavior on t { NumberAnimation { duration: 770; easing.type: toast.leaving ? Easing.OutCubic : Easing.OutQuint } }
                                readonly property real tc: Math.max(0, Math.min(1, t))
                                width: toastCol.width
                                height: tbody.height * (0.35 + 0.65 * tc) + (toastCol.spacing * (tc - 1))
                                opacity: Math.min(1, tc * 2.2)
                                Component.onCompleted: shown = true
                                function dismiss() { if (leaving) return; leaving = true; goneTimer.restart(); }
                                property real mergeDy: 0
                                Timer { id: handOff; interval: 30; onTriggered: root.notifToastRemove(toast.nid) }
                                Connections {
                                    target: root
                                    function onNotifOpenChanged() {
                                        if (!root.notifOpen || toast.leaving || toast.tc < 0.5) return;
                                        var g = tslab.mapToItem(ui, 0, 0);
                                        var m = {}, old = root.notifMergeFrom;
                                        for (var k in old) m[k] = old[k];
                                        m[toast.nid] = { x: g.x, y: g.y, w: tslab.width };
                                        root.notifMergeFrom = m;
                                        toast.leaving = true;
                                        toast.visible = false;
                                        handOff.restart();
                                    }
                                }
                                Timer { interval: 790; id: goneTimer; onTriggered: root.notifToastRemove(toast.nid) }
                                Timer {
                                    interval: toast.life
                                    running: toast.shown && !toast.leaving && !thov.hovered
                                    onTriggered: toast.dismiss()
                                }
                                HoverHandler { id: thov }

                                LGlass {
                                    id: tslab
                                    readonly property real slide: (1 - toast.tc) * 46
                                    width: toast.width * (0.42 + 0.58 * toast.tc)
                                    height: Math.max(36, toast.height)
                                    x: toast.width - width + slide
                                    backdrop: ui.glassSrc
                                    shaderUrl: root.glassShaderUrl
                                    liquid: root.liquidActive
                                    dark: root.effDark
                                    bx: toastArea.x + toast.x + tslab.x; by: toastArea.y + toast.y
                                    cornerR: Math.min(24 + (1 - toast.tc) * 40, height / 2)
                                    tint: root.glassOpacity
                                    thickness: 22
                                    strength: 0.7 * root.glassLiquidEff
                                    rim: root.glassRimEff
                                    grain: root.glassGrain
                                    blur: root.notifBlur
                                    debug: root.glassDebug
                                    onShaderError: root.glassState = "failed"
                                    rimTint: 1
                                    ringW: 0.9
                                    shadowAmt: 0.35
                                }
                                MenuBorder {
                                    z: 2
                                    anchors.fill: tslab
                                    cornerR: Math.min(24 + (1 - toast.tc) * 40, height / 2)
                                    dark: root.effDark
                                    tint: root.menuBorderColor
                                    amount: 0.5
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { root.notifActivate(toast.nid); toast.dismiss(); }
                                }
                                Item {
                                    id: tcontent
                                    x: tslab.x; width: tslab.width; height: toast.height
                                    clip: toast.tc < 0.999
                                    opacity: Math.pow(toast.tc, 1.3)
                                Item {
                                    width: toast.width; height: toast.height
                                    x: tslab.width - width
                                    layer.enabled: toast.tc < 0.999
                                    layer.smooth: true
                                    layer.effect: MultiEffect { blurEnabled: true; blurMax: 56; blur: Math.pow(1 - toast.tc, 0.8); autoPaddingEnabled: true }
                                NotifBody {
                                    id: tbody
                                    t: pal
                                    width: toast.width
                                    app: toast.app; summary: toast.summary; body: toast.body; icon: toast.icon
                                    urgency: toast.urgency; stamp: toast.time; nowMs: clock.date.getTime()
                                    showClose: thov.hovered
                                    onCloseClicked: toast.dismiss()
                                }
                                }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: notifPop
                    z: 10
                    property real fullH: 92 + (notifHist.count === 0 ? 70 : (root.notifClearing ? Math.max(70, nfl.height) : nfl.height)) + 14
                    Behavior on fullH { enabled: !root.notifClearing; NumberAnimation { duration: 560; easing.type: Easing.OutQuint } }
                    readonly property real ps: root.barPopupScale
                    readonly property real fullW: 380
                    readonly property real srcW: 26
                    readonly property real srcH: 22
                    readonly property real srcX: Math.max(0, Math.min(ui.width - srcW, ui.menuX + 1))
                    readonly property real srcY: Math.max(0, (root.barH - srcH) / 2)
                    readonly property real dstX: Math.max(6, ui.width - fullW * ps - 8)
                    readonly property real dstY: root.barH + 6

                    readonly property bool merging: ui.toastsShown
                    readonly property bool opening: ui.pop === "notif"
                    property real openT: opening ? 1 : 0
                    Behavior on openT {
                        id: notifPopOpenB
                        enabled: !notifPop.merging
                        NumberAnimation {
                            duration: notifPopOpenB.targetValue > 0.5 ? 520 : 220
                            easing.type: notifPopOpenB.targetValue > 0.5 ? Easing.OutBack : Easing.InOutCubic
                            easing.overshoot: 0.7
                        }
                    }
                    readonly property real t: Math.max(0, Math.min(1, openT))
                    readonly property real contentT: Math.max(0, Math.min(1, (openT - 0.28) / 0.55))
                    property real chromeM: ui.pop === "notif" ? 1 : 0
                    Behavior on chromeM { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                    readonly property real chrome: merging ? chromeM : contentT

                    width: (srcW + (fullW * ps - srcW) * openT) / ps
                    height: (srcH + (fullH * ps - srcH) * openT) / ps
                    x: srcX + (dstX - srcX) * openT
                    y: srcY + (dstY - srcY) * openT
                    opacity: Math.min(1, t * 4)
                    visible: openT > 0.002
                    scale: ps
                    transformOrigin: Item.TopLeft

                    readonly property real blurAmt: Math.pow(1 - t, 1.3)
                    readonly property bool morphing: openT > 0.002 && Math.abs(openT - 1) > 0.002
                    layer.enabled: morphing
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 48
                        blur: notifPop.blurAmt * 0.9
                        autoPaddingEnabled: true
                    }

                    PopGlassCtx { id: notifPopGlass; pop: notifPop; frame: ui; source: ui.glassSrc; fullW: notifPop.fullW; fullH: notifPop.fullH }
                    GGlass {
                        anchors.fill: parent
                        opacity: notifPop.merging ? notifPop.chromeM : 1
                        gx: notifPopGlass.ctx
                        cornerR: Math.min(26, 8 + 18 * notifPop.t)
                        thickness: 22
                        shadowAmt: 0
                        flatInner: 1
                    }
                    MenuBorder {
                        z: 2
                        anchors.fill: parent
                        cornerR: Math.min(26, 8 + 18 * notifPop.t)
                        dark: notifPopGlass.ctx.dark
                        tint: notifPopGlass.ctx.borderTint
                        amount: 1
                    }
                    MouseArea { anchors.fill: parent }

                    Item {
                        anchors.fill: parent
                        clip: true
                    Item {
                        id: notifBody
                        x: 0; y: notifPop.merging ? 0 : 10 * (1 - notifPop.contentT)
                        width: notifPop.fullW; height: notifPop.fullH

                    Item {
                        x: 18; y: 14; width: parent.width - 36; height: 26
                        opacity: notifPop.chrome
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Notification system")
                            color: pal.fg
                            font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 17; font.weight: Font.DemiBold
                        }
                        Rectangle {
                            visible: notifHist.count > 0
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: clrText.implicitWidth + 20; height: 24; radius: 12
                            color: clrMa.containsMouse ? pal.btnHover : pal.btnOff
                            Text {
                                id: clrText
                                anchors.centerIn: parent
                                text: I18n.tr("Clear All")
                                color: pal.fg
                                font.family: root.fontForWeight(Font.Medium, pal.fam); font.pixelSize: 12; font.weight: Font.Medium
                            }
                            MouseArea { id: clrMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.notifClearAnimated() }
                        }
                    }
                    Item {
                        x: 12; y: 46; width: parent.width - 24; height: 36
                        opacity: notifPop.chrome
                        Rectangle { anchors.fill: parent; radius: 12; color: pal.tile; border.width: 1; border.color: Qt.rgba(pal.tileBorder.r, pal.tileBorder.g, pal.tileBorder.b, pal.tileBorder.a * 0.4) }
                        Glyph { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; kind: "moon"; color: pal.fg }
                        Text {
                            x: 36; anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Do Not Disturb")
                            color: pal.fg
                            font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 13
                        }
                        PSwitch {
                            t: pal
                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            checked: root.notifDnd
                            onToggled: v => root.notifDnd = v
                        }
                    }
                    Text {
                        opacity: notifHist.count === 0 ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                        x: 0; y: 96; width: parent.width; height: 60
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: I18n.tr("No Notifications")
                        color: pal.fg2
                        font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 14
                    }
                    Flickable {
                        id: nfl
                        opacity: notifPop.merging ? 1 : notifPop.contentT
                        x: 12; y: 92
                        width: parent.width - 24
                        height: Math.min(ncol.height, 440)
                        contentHeight: ncol.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: ncol
                            width: nfl.width
                            spacing: 8
                            Repeater {
                                model: notifHist
                                delegate: Dissolve {
                                    id: hcd
                                    required property int nid
                                    required property int index
                                    required property string app
                                    required property string summary
                                    required property string body
                                    required property string icon
                                    required property int urgency
                                    required property real time
                                    width: ncol.width
                                    property real inT: 0
                                    property bool snapIn: false
                                    Component.onCompleted: inT = 1
                                    Behavior on inT { enabled: !hcd.snapIn && !root.notifClearing; NumberAnimation { duration: 560; easing.type: Easing.OutQuint } }
                                    property real flipX: 0
                                    property real flipY: 0
                                    property real flipS: 1
                                    function flyFromPopup() {
                                        var f = root.notifMergeFrom[hcd.nid];
                                        if (!f || flipAnim.running) return;
                                        var cw = notifPop.fullW - 24;
                                        if (!(cw > 0)) return;
                                        var here = hcd.mapToItem(ui, 0, 0);
                                        hcd.flipX = f.x + f.w - (here.x + cw);
                                        var listTop = nfl.mapToItem(ui, 0, 0).y;
                                        hcd.flipY = Math.max(f.y, listTop) - here.y;
                                        hcd.flipS = Math.max(0.5, Math.min(1.5, f.w / cw));
                                        flyDelay.interval = 1 + Math.max(0, hcd.index) * 40;
                                        flyDelay.restart();
                                    }
                                    Timer { id: flyDelay; onTriggered: flipAnim.restart() }
                                    ParallelAnimation {
                                        id: flipAnim
                                        NumberAnimation { target: hcd; property: "flipX"; to: 0; duration: 620; easing.type: Easing.OutQuint }
                                        NumberAnimation { target: hcd; property: "flipY"; to: 0; duration: 620; easing.type: Easing.OutQuint }
                                        NumberAnimation { target: hcd; property: "flipS"; to: 1; duration: 620; easing.type: Easing.OutQuint }
                                    }
                                    Connections {
                                        target: root
                                        function onNotifMergeFromChanged() { Qt.callLater(hcd.flyFromPopup); }
                                    }
                                    height: hc.height * inT
                                    cardH: hc.height
                                    opacity: inT
                                    transform: [
                                        Scale { origin.x: hcd.width; origin.y: 0; xScale: hcd.flipS; yScale: hcd.flipS },
                                        Translate { x: hcd.flipX; y: (hcd.inT - 1) * 18 + hcd.flipY }
                                    ]
                                    z: (flipAnim.running || flyDelay.running) ? 10 : 0
                                    onDone: { if (root.notifClearing) return; hcd.inT = 0; delT.restart(); }
                                    Timer { id: delT; interval: 560; onTriggered: root.notifDelete(hcd.nid) }
                                    Timer { id: collapseT; onTriggered: collapseAnim.restart() }
                                    NumberAnimation { id: collapseAnim; target: hcd; property: "inT"; to: 0; duration: 820; easing.type: Easing.InOutCubic }
                                    Connections {
                                        target: root
                                        function onNotifDustAll() {
                                            hcd.dissolve(hcd.index * 55);
                                            collapseT.interval = 120 + hcd.index * 55; collapseT.restart();
                                        }
                                    }
                                Rectangle {
                                    id: hc
                                    readonly property int nid: hcd.nid
                                    readonly property string app: hcd.app
                                    readonly property string summary: hcd.summary
                                    readonly property string body: hcd.body
                                    readonly property string icon: hcd.icon
                                    readonly property int urgency: hcd.urgency
                                    readonly property real time: hcd.time
                                    width: hcd.width
                                    height: hbody.height
                                    radius: 18
                                    color: pal.tile
                                    border.width: 1; border.color: Qt.rgba(pal.tileBorder.r, pal.tileBorder.g, pal.tileBorder.b, pal.tileBorder.a * 0.4)
                                    HoverHandler { id: hhov }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: { root.notifActivate(hc.nid); ui.pop = ""; }
                                    }
                                    NotifBody {
                                        id: hbody
                                        t: pal
                                        width: parent.width
                                        app: hc.app; summary: hc.summary; body: hc.body; icon: hc.icon
                                        urgency: hc.urgency; stamp: hc.time; nowMs: clock.date.getTime()
                                        showTime: true
                                        showClose: hhov.hovered
                                        onCloseClicked: hcd.dissolve(1)
                                    }
                                }
                                }
                            }
                        }
                    }
                    }
                    }
                }

                Item {
                    id: menuPop
                    z: 10
                    // grows out of the menu title like the right-hand popups (volPop, wifiPop)
                    readonly property real ps: root.barPopupScale
                    readonly property real fullW: {
                        var w = 248;
                        for (var i = 0; i < menuRep.count; i++) { var c = menuRep.itemAt(i); if (c) w = Math.max(w, c.need); }
                        return Math.min(Math.ceil(w), 428) + 12;
                    }
                    readonly property real fullH: menuCol.height + 14
                    readonly property real srcW: 26
                    readonly property real srcH: 22
                    readonly property real srcX: ui.menuX + 1
                    readonly property real srcY: Math.max(0, (root.barH - srcH) / 2)
                    readonly property real dstX: Math.max(6, Math.min(ui.width - fullW * ps - 6, ui.menuX - 4))
                    readonly property real dstY: root.barH + 3

                    property real openT: ui.isMenu ? 1 : 0
                    Behavior on openT {
                        id: menuPopOpenB
                        NumberAnimation {
                            duration: menuPopOpenB.targetValue > 0.5 ? 520 : 220
                            easing.type: menuPopOpenB.targetValue > 0.5 ? Easing.OutBack : Easing.InOutCubic
                            easing.overshoot: 0.7
                        }
                    }
                    readonly property real t: Math.max(0, Math.min(1, openT))
                    readonly property real contentT: Math.max(0, Math.min(1, (openT - 0.28) / 0.55))

                    width: (srcW + (fullW * ps - srcW) * openT) / ps
                    height: (srcH + (fullH * ps - srcH) * openT) / ps
                    x: srcX + (dstX - srcX) * openT
                    y: srcY + (dstY - srcY) * openT
                    opacity: Math.min(1, t * 4)
                    visible: openT > 0.002
                    scale: ps
                    transformOrigin: Item.TopLeft

                    readonly property bool morphing: openT > 0.002 && Math.abs(openT - 1) > 0.002
                    layer.enabled: morphing
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 48
                        blur: Math.pow(1 - menuPop.t, 1.3) * 0.9
                        autoPaddingEnabled: true
                    }

                    LGlass {
                        anchors.fill: parent
                        backdrop: ui.glassSrc
                        shaderUrl: root.glassShaderUrl
                        liquid: root.liquidActive
                        dark: root.panelDarkMode
                        bx: menuPop.x; by: menuPop.y
                        shadowAmt: 0
                        flatInner: 1
                        rimTint: 1
                        ringW: 0
                        cornerR: 14
                        tint: root.glassOpacity
                        thickness: 22
                        strength: root.glassLiquidEff
                        rim: root.glassRimEff
                        grain: root.glassGrain
                        blur: root.glassBlurEff
                        debug: root.glassDebug
                        onShaderError: root.glassState = "failed"
                    }
                    MenuBorder {
                        id: menuBorder
                        z: 2
                        anchors.fill: parent
                        cornerR: 14
                        dark: root.panelDarkMode
                        tint: root.menuBorderColor
                    }
                    Item {
                        anchors.fill: parent
                        clip: true
                    Item {
                        width: menuPop.fullW; height: menuPop.fullH
                        y: 8 * (1 - menuPop.contentT)
                        opacity: menuPop.contentT
                    Column {
                        id: menuCol
                        x: 6; y: 7
                        width: parent.width - 12
                        Repeater {
                            id: menuRep
                            model: ui.menuModel
                            delegate: Item {
                                id: it
                                required property var modelData
                                readonly property bool isSep: modelData.kind === "sep"
                                readonly property real need: isSep ? 0 : (ui.menuLead ? 28 : 12) + lbl.implicitWidth + (sc.visible ? sc.implicitWidth + 24 : 12) + 8
                                readonly property bool armedNow: !isSep && modelData.confirm === true && ui.armed === modelData.label
                                readonly property bool off: !isSep && modelData.disabled === true
                                readonly property bool hot: !isSep && !off && ima.containsMouse
                                width: menuCol.width
                                height: isSep ? 11 : 26

                                Rectangle {
                                    visible: it.isSep
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 8; width: parent.width - 16; height: 1
                                    color: panelPal.sep
                                }
                                Rectangle {
                                    visible: it.hot
                                    anchors.fill: parent
                                    radius: 6
                                    color: it.armedNow ? "#FF453A" : root.accent
                                }
                                Glyph {
                                    visible: !it.isSep && it.modelData.glyph !== undefined
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15; height: 15
                                    kind: it.modelData.glyph !== undefined ? it.modelData.glyph : ""
                                    color: it.hot ? "white" : (it.off ? panelPal.fg2 : panelPal.fg)
                                }
                                Text {
                                    visible: !it.isSep && it.modelData.checked === true
                                    x: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\u2713"
                                    color: it.hot ? "white" : panelPal.fg
                                    font.family: Fonts.forWeight(Font.Normal, "Open Runde")
                                    font.pixelSize: 13
                                    font.weight: Font.Normal
                                }
                                Text {
                                    id: lbl
                                    visible: !it.isSep
                                    x: ui.menuLead ? 28 : 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - x - 12 - (sc.visible ? sc.implicitWidth + 12 : 0)
                                    elide: Text.ElideRight
                                    text: it.isSep ? "" : (it.armedNow ? I18n.tr("Click again to confirm") : I18n.tr(it.modelData.label))
                                    color: it.hot ? "white" : (it.off ? panelPal.fg2 : panelPal.fg)
                                    font.family: Fonts.forWeight(Font.Normal, "Open Runde")
                                    font.pixelSize: 13
                                    font.weight: Font.Normal
                                }
                                Text {
                                    id: sc
                                    visible: !it.isSep && it.modelData.shortcut !== undefined && it.modelData.shortcut !== ""
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: it.isSep ? "" : (it.modelData.shortcut || "")
                                    color: it.hot ? Qt.rgba(1, 1, 1, 0.8) : panelPal.fg2
                                    font.family: Fonts.forWeight(Font.Normal, "Open Runde")
                                    font.pixelSize: 12
                                    font.weight: Font.Normal
                                }
                                MouseArea {
                                    id: ima
                                    anchors.fill: parent
                                    enabled: !it.isSep && !it.off
                                    hoverEnabled: true
                                    onClicked: {
                                        if (it.modelData.confirm === true && ui.armed !== it.modelData.label) {
                                            ui.armed = it.modelData.label;
                                            return;
                                        }
                                        var run = it.modelData.run;
                                        ui.pop = "";
                                        if (run) run();
                                    }
                                }
                            }
                        }
                    }
                    }
                    }
                }

                Item {
                    id: trayPop
                    z: 10
                    readonly property bool shown: ui.pop === "tray"
                    readonly property var cur: ui.trayStack.length > 0 ? ui.trayStack[ui.trayStack.length - 1]
                                               : (ui.trayItem ? ui.trayItem.menu : null)
                    readonly property bool hasLead: {
                        var v = trayOpener.children ? trayOpener.children.values : [];
                        for (var i = 0; i < v.length; i++)
                            if (v[i].buttonType !== QsMenuButtonType.None || (v[i].icon && v[i].icon !== "")) return true;
                        return false;
                    }
                    function clean(t) {
                        return (t || "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_");
                    }
                    width: 260
                    height: Math.min(trayCol.height + 14, root.popRoom - 20)
                    x: Math.max(6, Math.min(ui.width - width * root.barPopupScale - 6, ui.menuX - 4))
                    y: root.barH + 3
                    opacity: shown ? 1 : 0
                    visible: opacity > 0
                    scale: root.barPopupScale * (shown ? 1 : 0.97)
                    transformOrigin: Item.TopLeft
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    QsMenuOpener { id: trayOpener; menu: trayPop.cur }

                    LGlass {
                        anchors.fill: parent
                        backdrop: ui.glassSrc
                        shaderUrl: root.glassShaderUrl
                        liquid: root.liquidActive
                        dark: root.panelDarkMode
                        bx: trayPop.x; by: trayPop.y
                        shadowAmt: 0
                        flatInner: 1
                        rimTint: 1
                        ringW: 0
                        cornerR: 14
                        tint: root.glassOpacity
                        thickness: 22
                        strength: root.glassLiquidEff
                        rim: root.glassRimEff
                        grain: root.glassGrain
                        blur: root.glassBlurEff
                        debug: root.glassDebug
                        onShaderError: root.glassState = "failed"
                    }
                    MenuBorder {
                        id: trayBorder
                        z: 2
                        anchors.fill: parent
                        cornerR: 14
                        dark: root.panelDarkMode
                        tint: root.menuBorderColor
                        amount: 1
                    }

                    Flickable {
                        id: trayFlick
                        x: 6; y: 7
                        width: parent.width - 12
                        height: parent.height - 14
                        contentWidth: width
                        contentHeight: trayCol.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        Connections { target: trayPop; function onCurChanged() { trayFlick.contentY = 0; } }

                        Column {
                            id: trayCol
                            width: trayFlick.width

                            Item {
                                id: trayBack
                                visible: ui.trayStack.length > 0
                                width: trayCol.width
                                height: visible ? 26 : 0
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: backMa.containsMouse ? root.accent : "transparent"
                                }
                                Text {
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 24
                                    elide: Text.ElideRight
                                    text: "\u2039  " + (ui.trayStack.length > 0 ? trayPop.clean(ui.trayStack[ui.trayStack.length - 1].text) : "")
                                    color: backMa.containsMouse ? "white" : panelPal.fg
                                    font.family: root.fontForWeight(Font.DemiBold, panelPal.fam); font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    id: backMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: ui.trayStack = ui.trayStack.slice(0, ui.trayStack.length - 1)
                                }
                            }
                            Item {
                                visible: trayBack.visible
                                width: trayCol.width; height: visible ? 11 : 0
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 8; width: parent.width - 16; height: 1; color: panelPal.sep }
                            }

                            Repeater {
                                model: trayOpener.children
                                delegate: Item {
                                    id: te
                                    required property var modelData
                                    readonly property bool isSep: modelData.isSeparator
                                    readonly property bool live: !isSep && modelData.enabled
                                    readonly property bool hot: live && tma.containsMouse
                                    width: trayCol.width
                                    height: isSep ? 11 : 26

                                    Rectangle {
                                        visible: te.isSep
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 8; width: parent.width - 16; height: 1
                                        color: panelPal.sep
                                    }
                                    Rectangle {
                                        visible: te.hot
                                        anchors.fill: parent
                                        radius: 6
                                        color: root.accent
                                    }
                                    Text {
                                        visible: !te.isSep && te.modelData.buttonType !== QsMenuButtonType.None && te.modelData.checkState === Qt.Checked
                                        x: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: te.modelData.buttonType === QsMenuButtonType.RadioButton ? I18n.tr("\u25CF") : "\u2713"
                                        color: te.hot ? "white" : (te.live ? panelPal.fg : panelPal.fg2)
                                        font.family: root.fontForWeight(Font.Normal, panelPal.fam)
                                        font.pixelSize: te.modelData.buttonType === QsMenuButtonType.RadioButton ? 8 : 13
                                    }
                                    Image {
                                        visible: !te.isSep && te.modelData.buttonType === QsMenuButtonType.None && te.modelData.icon !== ""
                                        x: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16; height: 16
                                        source: te.modelData.icon
                                        sourceSize: Qt.size(32, 32)
                                        fillMode: Image.PreserveAspectFit
                                        opacity: te.live ? 1 : 0.4
                                    }
                                    Text {
                                        visible: !te.isSep
                                        x: trayPop.hasLead ? 32 : 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - x - 12 - (te.modelData.hasChildren ? 14 : 0)
                                        elide: Text.ElideRight
                                        text: te.isSep ? "" : trayPop.clean(te.modelData.text)
                                        color: te.hot ? "white" : (te.live ? panelPal.fg : panelPal.fg2)
                                        font.family: root.fontForWeight(Font.Normal, panelPal.fam)
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        visible: !te.isSep && te.modelData.hasChildren
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "\u203A"
                                        color: te.hot ? "white" : panelPal.fg2
                                        font.family: root.fontForWeight(Font.Normal, panelPal.fam); font.pixelSize: 15
                                    }
                                    MouseArea {
                                        id: tma
                                        anchors.fill: parent
                                        enabled: te.live
                                        hoverEnabled: true
                                        onClicked: {
                                            if (te.modelData.hasChildren) {
                                                ui.trayStack = ui.trayStack.concat([te.modelData]);
                                            } else {
                                                te.modelData.triggered();
                                                ui.pop = "";
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: wifiContent
                    Column {
                        id: wifiCol
                        property var pp: pal
                        property bool showBack: false
                        signal back()
                        width: parent ? parent.width : 296
                        spacing: 6

                        Item {
                            width: parent.width; height: 32
                            Item {
                                visible: wifiCol.showBack
                                x: 0; width: 30; height: parent.height
                                Glyph { anchors.centerIn: parent; width: 12; height: 12; kind: "chevL"; color: pp.fg }
                                MouseArea { anchors.fill: parent; onClicked: wifiCol.back() }
                            }
                            Text {
                                x: wifiCol.showBack ? 30 : 6; anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Wi-Fi")
                                color: pp.fg
                                font.family: root.fontForWeight(Font.DemiBold, pp.fam); font.pixelSize: 15; font.weight: Font.DemiBold
                            }
                            PSwitch {
                                t: pp
                                anchors.right: parent.right; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.wifiOn
                                enabled: root.hasWifi
                                opacity: root.hasWifi ? 1 : 0.4
                                onToggled: { root.toggleWifi(); wifiAfter.restart(); }
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: pp.sep }
                        Text { visible: root.otherConnections.length>0; width:parent.width; leftPadding:6; text:I18n.tr("Ethernet & VPN"); color:pp.fg2; font.family: root.fontForWeight(Font.DemiBold, pp.fam); font.pixelSize:11; font.weight:Font.DemiBold }
                        Column {
                            width: parent.width
                            Repeater {
                                model: root.otherConnections.slice(0,5)
                                delegate: Item {
                                    required property var modelData
                                    width: parent.width; height: 30
                                    Rectangle { anchors.fill:parent; radius:8; color:connMa.containsMouse?pp.hover:"transparent" }
                                    Glyph { x:8; anchors.verticalCenter:parent.verticalCenter; width:14; height:14; kind:modelData.type==="vpn"?"lock":"wifi"; color:pp.fg }
                                    Text { x:30; anchors.verticalCenter:parent.verticalCenter; width:parent.width-42; elide:Text.ElideRight; text:modelData.name+(modelData.active?I18n.tr(" · Connected"):""); color:pp.fg; font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize:12 }
                                    MouseArea { id:connMa; anchors.fill:parent; hoverEnabled:true; onClicked:root.toggleConnection(modelData) }
                                }
                            }
                        }

                        Text {
                            visible: !root.wifiOn && root.hasWifi
                            width: parent.width; height: 56
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: I18n.tr("Wi-Fi is turned off")
                            color: pp.fg2
                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 13
                        }
                        Text {
                            visible: !root.hasWifi || (root.wifiOn && root.wifiNets.length === 0)
                            width: parent.width; height: 56
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: !root.hasWifi ? I18n.tr("No Wi-Fi adapter") : root.wifiScanning ? I18n.tr("Searching\u2026") : I18n.tr("No networks found")
                            color: pp.fg2
                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 13
                        }
                        Text {
                            visible: root.wifiOn && root.wifiNets.length > 0
                            leftPadding: 6
                            text: I18n.tr("Networks")
                            color: pp.fg2
                            font.family: root.fontForWeight(Font.DemiBold, pp.fam); font.pixelSize: 11; font.weight: Font.DemiBold
                        }

                        Flickable {
                            id: wifiFlick
                            visible: root.wifiOn && root.wifiNets.length > 0
                            width: parent.width
                            height: Math.min(wifiList.height, 300)
                            contentWidth: width
                            contentHeight: wifiList.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: wifiList
                                width: wifiFlick.width
                                Repeater {
                                    model: root.wifiNets
                                    delegate: Column {
                                        id: nr
                                        required property var modelData
                                        readonly property bool busy: root.wifiBusy === modelData.ssid
                                        readonly property bool prompting: ui.wifiPrompt === modelData.ssid
                                        width: wifiList.width

                                        Item {
                                            width: parent.width; height: 38
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 8
                                                color: root.accent
                                                visible: wma.containsMouse
                                            }
                                            Glyph {
                                                visible: nr.modelData.inUse
                                                x: 9; anchors.verticalCenter: parent.verticalCenter
                                                width: 14; height: 14
                                                kind: "check"
                                                color: wma.containsMouse ? "white" : pp.fg
                                            }
                                            Text {
                                                x: 30
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 30 - 96
                                                elide: Text.ElideRight
                                                text: nr.modelData.ssid
                                                color: wma.containsMouse ? "white" : pp.fg
                                                font.family: root.fontForWeight(nr.modelData.inUse ? Font.DemiBold : Font.Normal, pp.fam); font.pixelSize: 13
                                                font.weight: nr.modelData.inUse ? Font.DemiBold : Font.Normal
                                            }
                                            Text {
                                                visible: nr.busy
                                                anchors.right: parent.right; anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: I18n.tr("Connecting\u2026")
                                                color: pp.fg2
                                                font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                                            }
                                            Text {
                                                visible: !nr.busy && nr.modelData.inUse && wma.containsMouse
                                                anchors.right: parent.right; anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: I18n.tr("Disconnect")
                                                color: "white"
                                                font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                                            }
                                            Row {
                                                visible: !nr.busy && !(nr.modelData.inUse && wma.containsMouse)
                                                anchors.right: parent.right; anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 7
                                                Glyph {
                                                    visible: nr.modelData.secure
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 13; height: 13
                                                    kind: "lock"
                                                    color: wma.containsMouse ? "white" : pp.fg2
                                                }
                                                Glyph {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 16; height: 16
                                                    kind: "wifi"; level: root.sigLevel(nr.modelData.signal)
                                                    color: wma.containsMouse ? "white" : pp.fg
                                                }
                                            }
                                            MouseArea {
                                                id: wma
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: !nr.busy
                                                onClicked: ui.wifiPick(nr.modelData)
                                            }
                                        }

                                        Item {
                                            visible: nr.prompting
                                            width: parent.width; height: 42
                                            Rectangle {
                                                x: 30; y: 3
                                                width: parent.width - 30 - 4; height: 32; radius: 10
                                                color: pp.btnOff
                                            }
                                            Text {
                                                x: 42; y: 3; height: 32
                                                verticalAlignment: Text.AlignVCenter
                                                visible: pw.text === ""
                                                text: I18n.tr("Password")
                                                color: pp.fg3
                                                font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 13
                                            }
                                            TextInput {
                                                id: pw
                                                x: 42; y: 3
                                                width: parent.width - 42 - 62; height: 32
                                                verticalAlignment: TextInput.AlignVCenter
                                                clip: true
                                                echoMode: TextInput.Password
                                                color: pp.fg
                                                selectionColor: root.accent
                                                selectedTextColor: "white"
                                                font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 13
                                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                                                Keys.onPressed: event => {
                                                    if (event.key === Qt.Key_Escape) { ui.wifiPrompt = ""; event.accepted = true; }
                                                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                        ui.wifiSubmit(nr.modelData.ssid, text); event.accepted = true;
                                                    }
                                                }
                                            }
                                            Text {
                                                anchors.right: parent.right; anchors.rightMargin: 16
                                                y: 3; height: 32
                                                verticalAlignment: Text.AlignVCenter
                                                text: I18n.tr("Join")
                                                color: pw.text.length > 0 ? root.accent : pp.fg3
                                                font.family: root.fontForWeight(Font.DemiBold, pp.fam); font.pixelSize: 13; font.weight: Font.DemiBold
                                                MouseArea {
                                                    anchors.fill: parent; anchors.margins: -6
                                                    onClicked: ui.wifiSubmit(nr.modelData.ssid, pw.text)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.wifiError !== ""
                            width: parent.width
                            leftPadding: 6; rightPadding: 6
                            wrapMode: Text.WordWrap
                            text: root.wifiError
                            color: "#FF6961"
                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                        }

                        Rectangle { width: parent.width; height: 1; color: pp.sep }
                        Item {
                            width: parent.width; height: 30
                            Rectangle {
                                anchors.fill: parent; radius: 8
                                color: root.accent
                                visible: wsa.containsMouse
                            }
                            Text {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Network Settings\u2026")
                                color: wsa.containsMouse ? "white" : pp.fg
                                font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 13
                            }
                            MouseArea {
                                id: wsa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { ui.pop = ""; root.openSettings("network"); }
                            }
                        }
                    }
                }

                Item {
                    id: wifiPop
                    z: 10
                    readonly property real ps: root.barPopupScale
                    readonly property real fullW: 320
                    readonly property real fullH: (wifiLoad.item ? wifiLoad.item.height : 120) + 24
                    readonly property bool fromCC: ui.menuX >= ui.width - 1
                    readonly property real srcW: fromCC ? 44 : 26
                    readonly property real srcH: fromCC ? 30 : 22
                    readonly property real srcX: fromCC ? ui.width - 64 : ui.menuX + 1
                    readonly property real srcY: fromCC ? root.barH + 36 : Math.max(0, (root.barH - 22) / 2)
                    readonly property real dstX: Math.max(6, Math.min(ui.width - fullW * ps - 8, ui.menuX + 14 - fullW * ps / 2))
                    readonly property real dstY: root.barH + 6

                    readonly property bool opening: ui.pop === "wifi"
                    property real openT: opening ? 1 : 0
                    Behavior on openT {
                        id: wifiPopOpenB
                        NumberAnimation {
                            duration: wifiPopOpenB.targetValue > 0.5 ? 520 : 220
                            easing.type: wifiPopOpenB.targetValue > 0.5 ? Easing.OutBack : Easing.InOutCubic
                            easing.overshoot: 0.7
                        }
                    }
                    readonly property real t: Math.max(0, Math.min(1, openT))
                    readonly property real contentT: Math.max(0, Math.min(1, (openT - 0.28) / 0.55))

                    width: (srcW + (fullW * ps - srcW) * openT) / ps
                    height: (srcH + (fullH * ps - srcH) * openT) / ps
                    x: srcX + (dstX - srcX) * openT
                    y: srcY + (dstY - srcY) * openT
                    opacity: Math.min(1, t * 4)
                    visible: openT > 0.002
                    scale: ps
                    transformOrigin: Item.TopLeft

                    readonly property real blurAmt: Math.pow(1 - t, 1.3)
                    readonly property bool morphing: openT > 0.002 && Math.abs(openT - 1) > 0.002
                    layer.enabled: morphing
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 48
                        blur: wifiPop.blurAmt * 0.9
                        autoPaddingEnabled: true
                    }

                    PopGlassCtx { id: wifiPopGlass; pop: wifiPop; fromCC: wifiPop.fromCC; frame: ui; source: ui.glassSrc; fullW: wifiPop.fullW; fullH: wifiPop.fullH }
                    GGlass { anchors.fill: parent; gx: wifiPopGlass.ctx; cornerR: Math.min(26, 8 + 18 * wifiPop.t); thickness: 22; shadowAmt: 0; flatInner: 1 }
                    MenuBorder { z: 2; anchors.fill: parent; cornerR: Math.min(26, 8 + 18 * wifiPop.t); dark: wifiPopGlass.ctx.dark; tint: wifiPopGlass.ctx.borderTint; amount: 1 }
                    MouseArea { anchors.fill: parent }

                    Item {
                        id: wifiClip
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true
                    Loader {
                        id: wifiLoad
                        sourceComponent: wifiContent
                        x: 11; y: 11 + 10 * (1 - wifiPop.contentT)
                        width: wifiPop.fullW - 24
                        opacity: wifiPop.contentT
                    }
                    }
                }

                Component {
                    id: btContent
                    Column {
                        id: btCol
                        property var pp: pal
                        property bool showBack: false
                        signal back()
                        width: parent ? parent.width : 296
                        spacing: 6

                        Item {
                            width: parent.width; height: 32
                            Item {
                                visible: btCol.showBack
                                x: 0; width: 30; height: parent.height
                                Glyph { anchors.centerIn: parent; width: 12; height: 12; kind: "chevL"; color: pp.fg }
                                MouseArea { anchors.fill: parent; onClicked: btCol.back() }
                            }
                            Text {
                                x: btCol.showBack ? 30 : 6; anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Bluetooth")
                                color: pp.fg
                                font.family: root.fontForWeight(Font.DemiBold, pp.fam); font.pixelSize: 15; font.weight: Font.DemiBold
                            }
                            PSwitch {
                                t: pp
                                anchors.right: parent.right; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.btOn
                                onToggled: root.toggleBt()
                            }
                        }
                        Rectangle { width: parent.width; height: 1; color: pp.sep }

                        Text {
                            visible: !root.btOn
                            width: parent.width; height: 56
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: I18n.tr("Bluetooth is turned off")
                            color: pp.fg2
                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 13
                        }

                        Text {
                            visible: root.btOn && root.btDevices.length === 0
                            width: parent.width; height: 56
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: root.btScanning ? I18n.tr("Searching for devices\u2026") : I18n.tr("No devices found")
                            color: pp.fg2
                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 13
                        }

                        Item {
                            visible: root.btOn && root.btDevices.length > 0
                            width: parent.width; height: 22
                            Text {
                                x: 6; anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Devices")
                                color: pp.fg2
                                font.family: root.fontForWeight(Font.DemiBold, pp.fam); font.pixelSize: 11; font.weight: Font.DemiBold
                            }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    visible: root.btScanning
                                    text: I18n.tr("Scanning\u2026")
                                    color: pp.fg2; font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 11
                                }
                                Text {
                                    visible: !root.btScanning
                                    text: I18n.tr("Scan")
                                    color: root.accent; font.family: root.fontForWeight(Font.DemiBold, pp.fam); font.pixelSize: 11; font.weight: Font.DemiBold
                                    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.scanBt() }
                                }
                            }
                        }

                        Flickable {
                            id: btFlick
                            visible: root.btOn && root.btDevices.length > 0
                            width: parent.width
                            height: Math.min(btList.height, 300)
                            contentWidth: width
                            contentHeight: btList.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: btList
                                width: btFlick.width
                                Repeater {
                                    model: root.btDevices
                                    delegate: Item {
                                        id: devRow
                                        required property var modelData
                                        readonly property bool busy: root.btBusy === modelData.mac
                                        width: btList.width; height: 38

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: root.accent
                                            visible: bma.containsMouse
                                        }

                                        Glyph {
                                            visible: devRow.modelData.connected
                                            x: 9; anchors.verticalCenter: parent.verticalCenter
                                            width: 14; height: 14
                                            kind: "check"
                                            color: bma.containsMouse ? "white" : pp.fg
                                        }
                                        Glyph {
                                            visible: !devRow.modelData.connected
                                            x: 9; anchors.verticalCenter: parent.verticalCenter
                                            width: 14; height: 14
                                            kind: devRow.modelData.icon || "bluetooth"
                                            color: bma.containsMouse ? "white" : pp.fg2
                                        }

                                        Text {
                                            x: 30
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 30 - 100
                                            elide: Text.ElideRight
                                            text: devRow.modelData.name || devRow.modelData.mac
                                            color: bma.containsMouse ? "white" : pp.fg
                                            font.family: root.fontForWeight(devRow.modelData.connected ? Font.DemiBold : Font.Normal, pp.fam); font.pixelSize: 13
                                            font.weight: devRow.modelData.connected ? Font.DemiBold : Font.Normal
                                        }

                                        Text {
                                            visible: devRow.busy
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: devRow.modelData.connected ? I18n.tr("Disconnecting\u2026") : I18n.tr("Connecting\u2026")
                                            color: bma.containsMouse ? "white" : pp.fg2
                                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                                        }

                                        Text {
                                            visible: !devRow.busy && devRow.modelData.connected && bma.containsMouse
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: I18n.tr("Disconnect")
                                            color: "white"
                                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                                        }

                                        Text {
                                            visible: !devRow.busy && devRow.modelData.connected && !bma.containsMouse
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: I18n.tr("Connected")
                                            color: pp.fg2
                                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                                        }

                                        Text {
                                            visible: !devRow.busy && !devRow.modelData.connected && bma.containsMouse
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: I18n.tr("Connect")
                                            color: "white"
                                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                                        }

                                        Text {
                                            visible: !devRow.busy && !devRow.modelData.connected && !bma.containsMouse && devRow.modelData.paired
                                            anchors.right: parent.right; anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: I18n.tr("Paired")
                                            color: pp.fg2
                                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                                        }

                                        MouseArea {
                                            id: bma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !devRow.busy
                                            onClicked: root.connectBt(devRow.modelData.mac, devRow.modelData.connected)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.btError !== ""
                            width: parent.width
                            leftPadding: 6; rightPadding: 6
                            wrapMode: Text.WordWrap
                            text: root.btError
                            color: "#FF6961"
                            font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 12
                        }

                        Rectangle { width: parent.width; height: 1; color: pp.sep }
                        Item {
                            width: parent.width; height: 30
                            Rectangle {
                                anchors.fill: parent; radius: 8
                                color: root.accent
                                visible: bsa.containsMouse
                            }
                            Text {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Bluetooth Settings\u2026")
                                color: bsa.containsMouse ? "white" : pp.fg
                                font.family: root.fontForWeight(Font.Normal, pp.fam); font.pixelSize: 13
                            }
                            MouseArea {
                                id: bsa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { ui.pop = ""; root.openSettings("bluetooth"); }
                            }
                        }
                    }
                }

                Item {
                    id: btPop
                    z: 10
    readonly property real ps: root.barPopupScale
                    readonly property real fullW: 320
                    readonly property real fullH: (btLoad.item ? btLoad.item.height : 120) + 24
                    readonly property real srcW: 26
                    readonly property real srcH: 22
                    readonly property real srcX: ui.menuX + 1
                    readonly property real srcY: Math.max(0, (root.barH - srcH) / 2)
                    readonly property real dstX: Math.max(6, Math.min(ui.width - fullW * ps - 8, ui.menuX + 14 - fullW * ps / 2))
                    readonly property real dstY: root.barH + 6

                    readonly property bool opening: ui.pop === "bt"
                    property real openT: opening ? 1 : 0
                    Behavior on openT {
                        id: btPopOpenB
                        NumberAnimation {
                            duration: btPopOpenB.targetValue > 0.5 ? 520 : 220
                            easing.type: btPopOpenB.targetValue > 0.5 ? Easing.OutBack : Easing.InOutCubic
                            easing.overshoot: 0.7
                        }
                    }
                    readonly property real t: Math.max(0, Math.min(1, openT))
                    readonly property real contentT: Math.max(0, Math.min(1, (openT - 0.28) / 0.55))

                    width: (srcW + (fullW * ps - srcW) * openT) / ps
                    height: (srcH + (fullH * ps - srcH) * openT) / ps
                    x: srcX + (dstX - srcX) * openT
                    y: srcY + (dstY - srcY) * openT
                    opacity: Math.min(1, t * 4)
                    visible: openT > 0.002
                    scale: ps
                    transformOrigin: Item.TopLeft

                    readonly property real blurAmt: Math.pow(1 - t, 1.3)
                    readonly property bool morphing: openT > 0.002 && Math.abs(openT - 1) > 0.002
                    layer.enabled: morphing
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 48
                        blur: btPop.blurAmt * 0.9
                        autoPaddingEnabled: true
                    }

                    PopGlassCtx { id: btPopGlass; pop: btPop; frame: ui; source: ui.glassSrc; fullW: btPop.fullW; fullH: btPop.fullH }
                    GGlass { anchors.fill: parent; gx: btPopGlass.ctx; cornerR: Math.min(26, 8 + 18 * btPop.t); thickness: 22; shadowAmt: 0; flatInner: 1 }
                    MenuBorder { z: 2; anchors.fill: parent; cornerR: Math.min(26, 8 + 18 * btPop.t); dark: btPopGlass.ctx.dark; tint: btPopGlass.ctx.borderTint; amount: 1 }
                    MouseArea { anchors.fill: parent }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true
                        Loader {
                            id: btLoad
                            sourceComponent: btContent
                            x: 11; y: 11 + 10 * (1 - btPop.contentT)
                            width: btPop.fullW - 24
                            opacity: btPop.contentT
                        }
                    }
                }

                Item {
                    id: cal
                    z: 10
                    readonly property real ps: root.barPopupScale
                    readonly property real fullW: 310
                    readonly property real fullH: calCol.height + 28
                    readonly property real srcW: Math.max(26, ui.calSrcW)
                    readonly property real srcH: 22
                    readonly property real srcX: Math.min(ui.menuX, ui.width - srcW)
                    readonly property real srcY: Math.max(0, (root.barH - 22) / 2)
                    readonly property real dstX: Math.max(6, ui.width - fullW * ps - 8)
                    readonly property real dstY: root.barH + 6

                    readonly property bool opening: ui.pop === "cal"
                    property real openT: opening ? 1 : 0
                    Behavior on openT {
                        id: calOpenB
                        NumberAnimation {
                            duration: calOpenB.targetValue > 0.5 ? 540 : 220
                            easing.type: calOpenB.targetValue > 0.5 ? Easing.OutBack : Easing.InOutCubic
                            easing.overshoot: 0.7
                        }
                    }
                    readonly property real t: Math.max(0, Math.min(1, openT))
                    readonly property real contentT: Math.max(0, Math.min(1, (openT - 0.28) / 0.55))

                    width: (srcW + (fullW * ps - srcW) * openT) / ps
                    height: (srcH + (fullH * ps - srcH) * openT) / ps
                    x: srcX + (dstX - srcX) * openT
                    y: srcY + (dstY - srcY) * openT
                    opacity: Math.min(1, t * 4)
                    visible: openT > 0.002
                    scale: ps
                    transformOrigin: Item.TopLeft

                    readonly property real blurAmt: Math.pow(1 - t, 1.3)
                    readonly property bool morphing: openT > 0.002 && Math.abs(openT - 1) > 0.002
                    layer.enabled: morphing
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 48
                        blur: cal.blurAmt * 0.9
                        autoPaddingEnabled: true
                    }

                    PopGlassCtx { id: calGlass; pop: cal; frame: ui; source: ui.glassSrc; fullW: cal.fullW; fullH: cal.fullH }
                    GGlass { anchors.fill: parent; gx: calGlass.ctx; cornerR: Math.min(24, 8 + 16 * cal.t); thickness: 22; shadowAmt: 0; flatInner: 1 }
                    MenuBorder { z: 2; anchors.fill: parent; cornerR: Math.min(24, 8 + 16 * cal.t); dark: calGlass.ctx.dark; tint: calGlass.ctx.borderTint; amount: 1 }
                    MouseArea { anchors.fill: parent }

                    Item {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    Column {
                        id: calCol
                        x: 15; y: 13 + 10 * (1 - cal.contentT)
                        opacity: cal.contentT
                        width: parent.width - 32
                        spacing: 8

                        Text {
                            text: I18n.locale().toString(clock.date, "dddd")
                            color: pal.fg2
                            font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                        Text {
                            text: I18n.locale().toString(clock.date, I18n.tr("d MMMM yyyy"))
                            color: pal.fg
                            font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 22; font.weight: Font.DemiBold
                        }
                        Item { width: 1; height: 2 }
                        Item {
                            width: parent.width; height: 26
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.locale().monthName(ui.calMonth, Locale.LongFormat) + " " + ui.calYear
                                color: pal.fg
                                font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 14; font.weight: Font.DemiBold
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Repeater {
                                    model: [{ k: "chevL", d: -1 }, { k: "chevR", d: 1 }]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 26; height: 26; radius: 13
                                        color: cna.containsMouse ? pal.hover : "transparent"
                                        Glyph { anchors.centerIn: parent; width: 13; height: 13; kind: parent.modelData.k; color: pal.fg }
                                        MouseArea { id: cna; anchors.fill: parent; hoverEnabled: true; onClicked: ui.shiftMonth(parent.modelData.d) }
                                    }
                                }
                            }
                        }
                        Row {
                            Repeater {
                                model: 7
                                delegate: Text {
                                    required property int index
                                    width: calCol.width / 7
                                    horizontalAlignment: Text.AlignHCenter
                                    text: I18n.locale().dayName((index + (root.weekStartsMonday ? 1 : 0)) % 7, Locale.ShortFormat).substring(0, 2)
                                    color: pal.fg2
                                    font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 11; font.weight: Font.DemiBold
                                }
                            }
                        }
                        Grid {
                            columns: 7
                            Repeater {
                                model: ui.calData
                                delegate: Item {
                                    required property var modelData
                                    width: calCol.width / 7
                                    height: 32
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 28; height: 28; radius: 14
                                        color: parent.modelData.today ? root.accent : "transparent"
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.modelData.n
                                        color: parent.modelData.today ? "white" : (parent.modelData.cur ? pal.fg : pal.fg3)
                                        font.family: root.fontForWeight(parent.modelData.today ? Font.DemiBold : Font.Normal, pal.fam)
                                        font.pixelSize: 13
                                        font.weight: parent.modelData.today ? Font.DemiBold : Font.Normal
                                    }
                                }
                            }
                        }
                    }
                    }
                }

                Item {
                    id: cc
                    z: 10
                    width: 300
                    readonly property real maxH: Math.max(260, (ui.height - cc.y - 14) / Math.max(0.5, root.barPopupScale))
                    height: ui.ccPage === "" ? Math.min(ccCol.height, maxH) : (ui.ccPage === "wifi" ? ccWifiPage.height : ccBtPage.height)
                    x: Math.max(8, ui.width - width - 10)
                    y: root.barH + 6
                    readonly property bool opening: ui.pop === "cc"
                    property int openSeq: 0
                    property real openT: opening ? 1 : 0
                    Behavior on openT {
                        id: ccOpenB
                        NumberAnimation {
                            duration: ccOpenB.targetValue > 0.5 ? 520 : 150
                            easing.type: ccOpenB.targetValue > 0.5 ? Easing.OutBack : Easing.OutCubic
                            easing.overshoot: 1.5
                        }
                    }
                    opacity: Math.max(0, Math.min(1, openT * 2.2))
                    visible: opacity > 0
                    scale: root.barPopupScale * (0.94 + 0.06 * Math.min(1.0, openT))
                    transformOrigin: Item.TopRight
                    readonly property real blurAmt: Math.pow(Math.max(0, 1 - Math.min(1, openT)), 1.4)
                    readonly property bool morphing: openT > 0.002 && Math.abs(openT - 1) > 0.002
                    layer.enabled: morphing
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 40
                        blur: cc.blurAmt * 0.85
                        autoPaddingEnabled: true
                    }
                    onOpeningChanged: if (opening) openSeq++
                    onVisibleChanged: if (visible) { root.refreshWifi(); root.refreshBt(); root.refreshBrightness(); root.refreshPowerProfile(); }

                    property bool glassFlip: false
                    readonly property rect capLocal: Qt.rect(cc.x - 64, cc.y - 64, cc.width + 128, cc.height + 128)
                    readonly property real capS: root.barPopupScale
                    readonly property rect capScreen: Qt.rect((cc.x + cc.width) + (capLocal.x - (cc.x + cc.width)) * capS,
                                                              cc.y + (capLocal.y - cc.y) * capS,
                                                              capLocal.width * capS, capLocal.height * capS)
                    Timer {
                        id: ccRefresh
                        interval: 40
                        onTriggered: {
                            if (!cc.glassFlip) { cc.glassFlip = true; ccRefresh.restart(); }
                            else {
                                cc.glassFlip = false;
                                ccSrc.scheduleUpdate(); ccBlur.scheduleUpdate(); ccBlur2.scheduleUpdate();
                            }
                        }
                    }
                    function refreshGlass() { cc.glassFlip = false; ccRefresh.restart(); }
                    Connections { target: root; function onBarHeightChanged() { cc.refreshGlass(); } function onBarPopupScaleChanged() { cc.refreshGlass(); } }
                    onWidthChanged: refreshGlass()
                    onHeightChanged: refreshGlass()
                    onXChanged: refreshGlass()
                    onYChanged: refreshGlass()

                    ShaderEffectSource {
                        id: ccSrc
                        sourceItem: cc.glassFlip ? null : ui.glassSrc
                        hideSource: true
                        live: true
                        visible: false
                        sourceRect: cc.capScreen
                    }
                    MultiEffect {
                        id: ccBlurFx
                        source: ccSrc
                        width: ccSrc.sourceRect.width; height: ccSrc.sourceRect.height
                        blurEnabled: true
                        blurMax: 64
                        blur: Math.min(1.0, (ccg.blur * ccg.blurMul) * 1.4 / 64.0)
                        autoPaddingEnabled: false
                        visible: false
                    }
                    ShaderEffectSource {
                        id: ccBlur
                        sourceItem: ccBlurFx
                        live: true
                        visible: false
                    }
                    MultiEffect {
                        id: ccBlur2Fx
                        source: ccBlur
                        width: ccSrc.sourceRect.width; height: ccSrc.sourceRect.height
                        blurEnabled: (ccg.blur * ccg.blurMul) * 1.4 / 64.0 > 1.0
                        blurMax: 64
                        blur: Math.max(0.0, Math.min(1.0, (ccg.blur * ccg.blurMul) * 1.4 / 64.0 - 1.0))
                        autoPaddingEnabled: false
                        visible: false
                    }
                    ShaderEffectSource {
                        id: ccBlur2
                        sourceItem: (ccg.blur * ccg.blurMul) * 1.4 / 64.0 > 1.0 ? ccBlur2Fx : null
                        live: true
                        visible: false
                    }
                    GlassCtx {
                        id: ccg
                        src: (blur * blurMul) * 1.4 / 64.0 > 1.0 ? ccBlur2 : ccBlur
                        srcRect: cc.capLocal
                        frame: ui
                        liquid: root.liquidActive
                        shaderUrl: root.glassShaderUrl
                        dark: root.ccDark
                        tint: root.ccStyle === "macos" ? root.glassOpacity * 0.30 : root.glassOpacity
                        strength: root.ccStyle === "macos" ? root.glassLiquidEff * 0.30 : root.glassLiquidEff
                        rim: root.ccStyle === "macos" ? root.glassRimEff * 0.4 : root.glassRimEff
                        rimTint: 1
                        ringW: 0
                        borderTint: root.menuBorderColor
                        borderAmount: 1
                        whiteEdge: false
                        grain: root.glassGrain
                        blur: root.glassBlurEff
                        debug: root.glassDebug
                        onFailed: root.glassState = "failed"
                    }

                    function ccComp(id) {
                        switch (id) {
                        case "wifi": return cWifi;
                        case "bluetooth": return cBt;
                        case "airplane": return cAirplane;
                        case "focus": return cFocus;
                        case "nightshift": return cNight;
                        case "keepawake": return cAwake;
                        case "nowplaying": return cNowPlaying;
                        case "lock": return cLock;
                        case "screenshot": return cShot;
                        case "colorpicker": return cPicker;
                        case "wallpapers": return cWalls;
                        case "settings": return cSettings;
                        case "micmute": return cMic;
                        case "powermode": return cPower;
                        case "display": return cDisplay;
                        case "sound": return cSound;
                        case "record": return cRecord;
                        case "gaming": return cGaming;
                        }
                        return null;
                    }
                    Component {
                        id: cWifi
                        CCTile {
                            id: tl
                            clickable: root.hasWifi
                            opacity: root.hasWifi ? 1 : 0.4
                            on: root.wifiOn && root.hasWifi
                            onClicked: root.toggleWifi()
                            t: ccPal; gx: ccg
                            CCBtn {
                                plain: true
                                t: ccPal; gx: ccg
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                kind: "wifi"; level: root.wifiOn ? (root.wifiLevel || 3) : 3
                                on: root.wifiOn
                            }
                            MouseArea {
                                enabled: root.hasWifi
                                x: parent.width - 48; width: 48; height: parent.height
                                onClicked: { root.wifiError = ""; root.scanWifi(); root.refreshConnections(); ui.ccPage = "wifi"; }
                            }
                            Column {
                                x: 62; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 62 - 24
                                spacing: 1
                                Text { text: I18n.tr("Wi-Fi"); color: tl.fg; font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 13; font.weight: Font.DemiBold }
                                MorphText {
                                    animateWidth: false; duration: 420
                                    width: parent.width; elide: Text.ElideRight
                                    text: !root.hasWifi ? "N/A" : (!root.wifiOn ? I18n.tr("Off") : (root.wifiSsid !== "" ? root.wifiSsid : I18n.tr("Not Connected")))
                                    color: tl.fg2; font.family: root.fontForWeight(Font.Normal, ccPal.fam); font.pixelSize: 12
                                }
                            }
                        }
                    }
                    Component {
                        id: cBt
                        CCTile {
                            clickable: root.hasBt
                            opacity: root.hasBt ? 1 : 0.4
                            on: root.btOn && root.hasBt
                            onClicked: root.toggleBt()
                            id: btTile
                            t: ccPal; gx: ccg
                            readonly property bool wide: width > 110
                            CCBtn {
                                plain: true
                                t: ccPal; gx: ccg
                                x: btTile.wide ? 12 : (parent.width - width) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "bluetooth"; on: root.btOn
                            }
                            MouseArea {
                                visible: btTile.wide
                                enabled: root.hasBt
                                x: parent.width - 48; width: 48; height: parent.height
                                onClicked: { root.btError = ""; root.scanBt(); root.refreshBt(); ui.ccPage = "bt"; }
                            }
                            Column {
                                visible: btTile.wide
                                x: 62; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 62 - 24
                                spacing: 1
                                Text { text: I18n.tr("Bluetooth"); color: btTile.fg; font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 13; font.weight: Font.DemiBold }
                                MorphText {
                                    animateWidth: false; duration: 420
                                    width: parent.width; elide: Text.ElideRight
                                    text: !root.hasBt ? "N/A" : !root.btOn ? I18n.tr("Off") : (root.btConnected > 0 ? (root.btConnectedName || (root.btConnected + I18n.tr(" Connected"))) : I18n.tr("Not Connected"))
                                    color: btTile.fg2; font.family: root.fontForWeight(Font.Normal, ccPal.fam); font.pixelSize: 12
                                }
                            }
                        }
                    }
                    Component {
                        id: cAirplane
                        CCSimpleTile {
                            clickable: root.hasRadios
                            opacity: root.hasRadios ? 1 : 0.4
                            on: root.airplane
                            onClicked: root.toggleAirplane()
                            t: ccPal; gx: ccg
                            kind: "airplane"; title: I18n.tr("Airplane Mode")
                            status: !root.hasRadios ? "N/A" : (root.airplane ? I18n.tr("On") : I18n.tr("Off"))
                        }
                    }
                    Component {
                        id: cFocus
                        CCSimpleTile {
                            clickable: true
                            on: root.dnd
                            onClicked: root.toggleDnd()
                            t: ccPal; gx: ccg
                            kind: "moon"; title: I18n.tr("Focus"); status: root.dnd ? I18n.tr("On") : I18n.tr("Off")
                        }
                    }
                    Component {
                        id: cGaming
                        CCSimpleTile {
                            clickable: true
                            on: root.gaming
                            onClicked: root.gamingMode = !root.gaming
                            t: ccPal; gx: ccg
                            kind: "gamepad"; tint: "#30D158"; onTint: "#30D158"; title: I18n.tr("Game Mode")
                            status: root.gamingAutoActive && !root.gamingMode ? I18n.tr("On (game detected)") : (root.gaming ? I18n.tr("On") : (root.gamingAuto ? I18n.tr("Auto") : I18n.tr("Off")))
                        }
                    }
                    Component {
                        id: cRecord
                        CCSimpleTile {
                            clickable: true
                            on: root.recording
                            onClicked: root.toggleRecording()
                            t: ccPal; gx: ccg
                            kind: root.recording ? "stoprec" : "record"; tint: "#FF453A"; onTint: "#FF453A"
                            title: root.recording ? "Stop" : I18n.tr("Record")
                            status: root.recording ? root.recTime() : I18n.tr("Screen")
                        }
                    }
                    Component {
                        id: cNight
                        CCSimpleTile {
                            clickable: true
                            on: root.nightOn
                            onClicked: root.nightOn = !root.nightOn
                            t: ccPal; gx: ccg
                            kind: "nightshift"; title: I18n.tr("Night Shift"); status: root.nightOn ? I18n.tr("On") : I18n.tr("Off")
                        }
                    }
                    Component {
                        id: cAwake
                        CCSimpleTile {
                            clickable: true
                            on: root.keepAwake
                            onClicked: root.keepAwake = !root.keepAwake
                            t: ccPal; gx: ccg
                            kind: "coffee"; title: I18n.tr("Keep Awake"); status: root.keepAwake ? I18n.tr("On") : I18n.tr("Off")
                        }
                    }
                    Component {
                        id: cLock
                        CCSimpleTile {
                            clickable: true
                            onClicked: { ui.pop = ""; root.lockScreen(); }
                            t: ccPal; gx: ccg
                            kind: "lock"; title: I18n.tr("Lock Screen")
                        }
                    }
                    Component {
                        id: cShot
                        CCSimpleTile {
                            clickable: true
                            onClicked: { ui.pop = ""; root.shotStart(); }
                            t: ccPal; gx: ccg
                            kind: "camera"; title: I18n.tr("Screenshot")
                        }
                    }
                    Component {
                        id: cPicker
                        CCSimpleTile {
                            clickable: true
                            onClicked: { ui.pop = ""; root.pickColor(); }
                            t: ccPal; gx: ccg
                            kind: "dropper"; title: I18n.tr("Color Picker")
                        }
                    }
                    Component {
                        id: cWalls
                        CCSimpleTile {
                            clickable: true
                            onClicked: { ui.pop = ""; root.wpToggle(); }
                            t: ccPal; gx: ccg
                            kind: "photo"; title: I18n.tr("Wallpapers")
                        }
                    }
                    Component {
                        id: cSettings
                        CCSimpleTile {
                            clickable: true
                            onClicked: { ui.pop = ""; root.openSettings("general"); }
                            t: ccPal; gx: ccg
                            kind: "gear"; title: I18n.tr("System Settings")
                        }
                    }
                    Component {
                        id: cMic
                        CCTile {
                            t: ccPal; gx: ccg
                            radius: 26
                            Text {
                                x: 14; y: 8
                                text: I18n.tr("Microphone")
                                color: ccPal.fg; font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            HoverHandler { id: tileHovMic }
                            CCSlider {
                                tileHover: tileHovMic.hovered
                                t: ccPal
                                gx: ccg; glassMul: root.ccStyle === "macos" ? 3 : 1
                                x: 12; y: 28
                                width: parent.width - 24 - 36
                                value: root.micMuted ? 0 : root.micVolume
                                leftKind: "mic"; rightKind: "mic"
                                onMoved: v => root.setMicVolume(v)
                            }
                            CCBtn {
                                t: ccPal; gx: ccg
                                d: 28
                                glass: false
                                x: parent.width - 12 - 28; y: 28
                                kind: "mic"; flag: root.micMuted
                                on: root.micMuted
                                onClicked: root.toggleMicMute()
                            }
                        }
                    }
                    Component {
                        id: cPower
                        CCSimpleTile {
                            clickable: true
                            on: root.powerProfile !== "balanced"
                            onClicked: root.cyclePowerProfile()
                            t: ccPal; gx: ccg
                            kind: "bolt"; tint: "#FF9F0A"; onTint: "#FF9F0A"
                            title: I18n.tr("Power Mode")
                            status: root.powerProfile === "power-saver" ? I18n.tr("Low Power") : (root.powerProfile === "performance" ? I18n.tr("High Power") : I18n.tr("Automatic"))
                        }
                    }
                    Component {
                        id: cNowPlaying
                        CCTile {
                            id: np
                            t: ccPal; gx: ccg
                            readonly property var pl: root.player
                            Rectangle {
                                id: art
                                x: 12; y: 12
                                width: 52; height: 52; radius: 10
                                color: "transparent"
                                Glyph { visible: artImg.status !== Image.Ready; anchors.centerIn: parent; width: 30; height: 30; kind: "note"; color: ccPal.fg2 }
                                Item {
                                    id: artMask
                                    anchors.fill: parent
                                    visible: false
                                    layer.enabled: true
                                    layer.smooth: true
                                    Rectangle { anchors.fill: parent; radius: art.radius; color: "black" }
                                }
                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: np.pl && np.pl.trackArtUrl ? np.pl.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: artMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                    }
                                }
                                Rectangle {
                                    visible: artImg.status === Image.Ready
                                    anchors.fill: parent
                                    radius: art.radius
                                    color: "transparent"
                                    border.width: 1
                                    border.color: ccPal.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
                                }
                            }
                            VisBars {
                                x: art.x + art.width + 14; y: art.y
                                width: parent.width - x - 14; height: art.height
                                src: root.hub ? root.hub.vis : null
                                active: root.visOn && root.visInCC && np.pl !== null && np.pl !== undefined
                                        && (np.pl.isPlaying || np.pl.playbackState === MprisPlaybackState.Paused)
                                hold: !np.pl || !np.pl.isPlaying
                                style: root.visStyle
                                gain: root.visGain
                                count: Math.max(6, Math.round(root.visCount * 0.75))
                                barFill: root.visWidth
                                ArtTint { id: npTint; source: artImg.source }
                                readonly property color base: (root.visColor === "accent" || root.accentUi) ? root.accentInk
                                    : (root.visColor === "art" && npTint.known ? Qt.hsla(npTint.h, Math.min(0.95, npTint.s * 1.15 + 0.2), ccPal.dark ? 0.70 : 0.42, 1)
                                       : ccPal.fg)
                                colorTop: Qt.rgba(base.r, base.g, base.b, 0.55)
                                colorBottom: Qt.rgba(base.r, base.g, base.b, 0.10)
                            }
                            Column {
                                x: 12; y: 66
                                width: parent.width - 24
                                spacing: 1
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: !np.pl ? I18n.tr("No Music Playing") : (np.pl.trackTitle ? np.pl.trackTitle : I18n.tr("Now Playing"))
                                    color: np.pl ? ccPal.fg : ccPal.fg2
                                    font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 13; font.weight: Font.DemiBold
                                }
                                Text {
                                    visible: np.pl !== null && np.pl !== undefined
                                    width: parent.width; elide: Text.ElideRight
                                    text: np.pl && np.pl.trackArtist ? np.pl.trackArtist : ""
                                    color: ccPal.fg2; font.family: root.fontForWeight(Font.Normal, ccPal.fam); font.pixelSize: 12
                                }
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: parent.height - 38
                                spacing: 2
                                opacity: np.pl ? 1 : 0.4
                                Repeater {
                                    model: ["prev", "play", "next"]
                                    delegate: Item {
                                        id: pbtn
                                        required property string modelData
                                        width: 32; height: 30
                                        Glyph {
                                            anchors.centerIn: parent
                                            width: 26; height: 26
                                            kind: pbtn.modelData === "play" ? (np.pl && np.pl.isPlaying ? "pause" : "play") : pbtn.modelData
                                            color: ccPal.ink
                                            scale: pma.pressed ? 0.88 : 1
                                            Behavior on scale { NumberAnimation { duration: 230; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
                                        }
                                        MouseArea {
                                            id: pma
                                            anchors.fill: parent
                                            enabled: np.pl !== null && np.pl !== undefined
                                            onClicked: {
                                                if (pbtn.modelData === "prev") np.pl.previous();
                                                else if (pbtn.modelData === "next") np.pl.next();
                                                else np.pl.togglePlaying();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Component {
                        id: cDisplay
                        CCTile {
                            t: ccPal; gx: ccg
                            radius: 26
                            Text {
                                x: 14; y: 8
                                text: I18n.tr("Display")
                                color: ccPal.fg; font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            HoverHandler { id: tileHovDisplay }
                            CCSlider {
                                tileHover: tileHovDisplay.hovered
                                t: ccPal
                                gx: ccg; glassMul: root.ccStyle === "macos" ? 3 : 1
                                x: 12; y: 28
                                width: parent.width - 24
                                value: root.brightness
                                leftKind: "sun"; leftLevel: 1
                                rightKind: "sun"; rightLevel: 3
                                onMoved: v => root.setBrightness(v)
                            }
                        }
                    }
                    Component {
                        id: cSound
                        CCTile {
                            t: ccPal; gx: ccg
                            radius: 26
                            Text {
                                x: 14; y: 8
                                text: I18n.tr("Sound")
                                color: ccPal.fg; font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            HoverHandler { id: tileHovSound }
                            CCSlider {
                                tileHover: tileHovSound.hovered
                                t: ccPal
                                gx: ccg; glassMul: root.ccStyle === "macos" ? 3 : 1
                                x: 12; y: 28
                                width: parent.width - 24 - 36
                                value: root.muted ? 0 : root.volume
                                leftKind: "speaker"; leftLevel: 1
                                rightKind: "speaker"; rightLevel: 3
                                onMoved: v => root.setVolume(v)
                            }
                            CCBtn {
                                t: ccPal; gx: ccg
                                d: 28
                                glass: false
                                x: parent.width - 12 - 28; y: 28
                                kind: "speaker"; level: root.muted ? 0 : 3
                                on: root.muted
                                onClicked: root.toggleMute()
                            }
                        }
                    }

                    Loader {
                        active: root.ccStyle === "macos"
                        x: -12; y: -12
                        width: cc.width + 24; height: cc.height + 24
                        sourceComponent: Item {
                            GGlass { anchors.fill: parent; gx: ccg; cornerR: 24; thickness: 26; strengthMul: 1.0; shadowAmt: 0.6 }
                            CornerBorder { z: 2; anchors.fill: parent; cornerR: 24; dark: ccg.dark; tint: root.menuBorderColor; amount: ccg.borderAmount; lineW: 0.8 }
                        }
                    }

                    Item {
                        id: ccWifiPage
                        readonly property bool shown: ui.ccPage === "wifi"
                        width: parent.width
                        height: wifiPageLoad.height + 24
                        opacity: shown ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        GGlass { visible: root.ccStyle !== "macos"; anchors.fill: parent; gx: ccg; cornerR: 26; thickness: 22; shadowAmt: 0.45 }
                        CornerBorder { visible: root.ccStyle !== "macos"; z: 2; anchors.fill: parent; cornerR: 26; dark: ccg.dark; tint: ccg.borderTint; amount: ccg.borderAmount; lineW: 0.8 }
                        MouseArea { anchors.fill: parent }
                        Loader {
                            id: wifiPageLoad
                            active: ccWifiPage.shown || ccWifiPage.visible
                            x: 12; y: 12
                            width: parent.width - 24
                            sourceComponent: wifiContent
                            onLoaded: { item.pp = ccPal; item.showBack = true; item.back.connect(function () { ui.ccPage = ""; }); }
                        }
                    }

                    Item {
                        id: ccBtPage
                        readonly property bool shown: ui.ccPage === "bt"
                        width: parent.width
                        height: btPageLoad.height + 24
                        opacity: shown ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        GGlass { visible: root.ccStyle !== "macos"; anchors.fill: parent; gx: ccg; cornerR: 26; thickness: 22; shadowAmt: 0.45 }
                        CornerBorder { visible: root.ccStyle !== "macos"; z: 2; anchors.fill: parent; cornerR: 26; dark: ccg.dark; tint: ccg.borderTint; amount: ccg.borderAmount; lineW: 0.8 }
                        MouseArea { anchors.fill: parent }
                        Loader {
                            id: btPageLoad
                            active: ccBtPage.shown || ccBtPage.visible
                            x: 12; y: 12
                            width: parent.width - 24
                            sourceComponent: btContent
                            onLoaded: { item.pp = ccPal; item.showBack = true; item.back.connect(function () { ui.ccPage = ""; }); }
                        }
                    }

                    Flickable {
                        id: ccFlick
                        x: -10; y: -10
                        width: cc.width + 20
                        height: cc.height + 20
                        contentWidth: width
                        contentHeight: ccCol.height + 20
                        clip: true
                        interactive: contentHeight > height + 1
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: ccCol
                        x: 10; y: 10
                        width: cc.width
                        spacing: 10
                        opacity: ui.ccPage === "" ? 1 : 0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Item {
                            id: ccPriv
                            visible: root.privacyAny && root.barWidgetEnabled("privacy")
                            width: parent.width
                            height: visible ? 32 : 0
                            readonly property var icons: {
                                var a = [], seen = {};
                                for (var i = 0; i < root.privacyRows.length; i++) {
                                    var r = root.privacyRows[i];
                                    if (seen[r.c + r.glyph]) continue;
                                    seen[r.c + r.glyph] = true;
                                    a.push({ glyph: r.glyph, c: r.c });
                                }
                                return a;
                            }
                            readonly property string names: {
                                var all = root.privacy.mic.concat(root.privacy.cam).concat(root.privacy.share), out = [];
                                for (var i = 0; i < all.length; i++) if (out.indexOf(all[i]) < 0) out.push(all[i]);
                                if (out.length === 0 && root.recording) return "Screen Recording " + root.recTime();
                                return out.join(", ");
                            }
                            Item {
                                id: privPill
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: 32
                                width: Math.min(parent.width, 14 + privIcons.width + 8 + privText.implicitWidth + (root.recording ? 8 + 44 : 0) + 14)
                                CCTile { anchors.fill: parent; t: ccPal; gx: ccg; radius: 16 }
                                Row {
                                    id: privIcons
                                    x: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Repeater {
                                        model: ccPriv.icons
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 18; height: 18; radius: 9
                                            color: modelData.c
                                            Glyph { anchors.centerIn: parent; width: 10; height: 10; kind: modelData.glyph; color: "white" }
                                        }
                                    }
                                }
                                Text {
                                    id: privText
                                    x: 14 + privIcons.width + 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, privPill.width - x - 14 - (root.recording ? 52 : 0))
                                    elide: Text.ElideRight
                                    text: ccPriv.names
                                    color: ccPal.fg
                                    font.family: root.fontForWeight(Font.Medium, ccPal.fam); font.pixelSize: 13; font.weight: Font.Medium
                                }
                                Rectangle {
                                    visible: root.recording
                                    anchors.right: parent.right; anchors.rightMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 44; height: 20; radius: 10
                                    color: "#FF453A"
                                    Text { anchors.centerIn: parent; text: "Stop"; color: "white"; font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 11; font.weight: Font.DemiBold }
                                    MouseArea { anchors.fill: parent; onClicked: root.toggleRecording() }
                                }
                            }
                        }

                        Item {
                            id: ccGrid
                            width: parent.width
                            height: Math.max(root.ccCellH, root.ccPlan.total + (ui.ccEdit ? root.ccCellH + root.ccGap : 0))
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            readonly property real cw: (width - 3 * root.ccGap) / 4
                            readonly property real chh: root.ccCellH

                            Repeater {
                                model: ui.ccEdit ? (root.ccPlan.rows + 1) * 4 : 0
                                delegate: Rectangle {
                                    required property int index
                                    readonly property int cr: Math.floor(index / 4)
                                    x: (index % 4) * (ccGrid.cw + root.ccGap)
                                    y: root.ccPlan.ys[cr] !== undefined ? root.ccPlan.ys[cr] : 0
                                    width: ccGrid.cw; height: root.ccCellH
                                    radius: Math.min(width, height) * 0.3
                                    color: ccPal.dark ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(0, 0, 0, 0.035)
                                    border.width: 1
                                    border.color: ccPal.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
                                }
                            }

                            Text {
                                visible: root.ccPlan.items.length === 0
                                anchors.centerIn: parent
                                text: I18n.tr("No controls. Use Edit Controls to add some.")
                                color: ccPal.fg2; font.family: root.fontForWeight(Font.Normal, ccPal.fam); font.pixelSize: 12
                            }

                            Repeater {
                                model: root.ccCatalog
                                delegate: Item {
                                    id: ct
                                    required property var modelData
                                    readonly property var slot: {
                                        var it = root.ccPlan.items;
                                        for (var i = 0; i < it.length; i++) if (it[i].id === modelData.id) return it[i];
                                        return null;
                                    }
                                    property real dx: 0
                                    property real dy: 0
                                    property bool dragging: false

                                    visible: slot !== null
                                    x: (slot ? slot.col * (ccGrid.cw + root.ccGap) : 0) + dx
                                    y: (slot ? slot.y : 0) + dy
                                    width: slot ? slot.w * ccGrid.cw + (slot.w - 1) * root.ccGap : 0
                                    height: slot ? slot.hpx : 0
                                    z: dragging ? 100 : 0
                                    property real ap: 1
                                    Connections {
                                        target: cc
                                        function onOpenSeqChanged() { ct.ap = 0; tileIn.restart(); }
                                    }
                                    SequentialAnimation {
                                        id: tileIn
                                        PauseAnimation { duration: ct.slot ? Math.min(220, ct.slot.row * 55 + ct.slot.col * 18) : 0 }
                                        NumberAnimation { target: ct; property: "ap"; from: 0; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                                    }
                                    transform: Translate { y: (1 - ct.ap) * 16 }
                                    opacity: Math.max(0, Math.min(1, ct.ap * 1.6))
                                    scale: dragging ? 1.04 : 1
                                    Behavior on x { enabled: !ct.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on y { enabled: !ct.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                                    readonly property bool small: slot !== null && slot.w === 1 && slot.h === 1
                                    Loader {
                                        anchors.centerIn: parent
                                        width: ct.small ? Math.min(ct.width, ct.height) - 3 : ct.width
                                        height: ct.small ? Math.min(ct.width, ct.height) - 3 : ct.height
                                        active: ct.slot !== null
                                        sourceComponent: cc.ccComp(ct.modelData.id)
                                    }

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        z: 50
                                        enabled: ui.ccEdit
                                        visible: ui.ccEdit
                                        preventStealing: true
                                        cursorShape: !ui.ccEdit ? Qt.ArrowCursor : (ct.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                                        property point startP: Qt.point(0, 0)
                                        onPressed: mouse => {
                                            var q = mapToItem(ccGrid, mouse.x, mouse.y);
                                            startP = Qt.point(q.x, q.y);
                                            ct.dragging = true;
                                        }
                                        onPositionChanged: mouse => {
                                            if (!pressed) return;
                                            var q = mapToItem(ccGrid, mouse.x, mouse.y);
                                            ct.dx = q.x - startP.x;
                                            ct.dy = q.y - startP.y;
                                        }
                                        onReleased: mouse => {
                                            var q = mapToItem(ccGrid, mouse.x, mouse.y);
                                            var tx = ct.x, ty = ct.y;
                                            ct.dragging = false;
                                            ct.dx = 0; ct.dy = 0;
                                            root.ccDrop(ct.modelData.id, tx, ty, q.x, q.y, ccGrid.cw);
                                        }
                                        onCanceled: { ct.dragging = false; ct.dx = 0; ct.dy = 0; }
                                    }

                                    readonly property var tgt: dragging ? root.ccTarget(modelData.id, x, y, ccGrid.cw) : null
                                    Rectangle {
                                        readonly property bool ok: ct.tgt !== null && (ct.tgt.kind === "free" || ct.tgt.kind === "swap")
                                        visible: ct.tgt !== null && (ok || ct.tgt.kind === "none")
                                        z: -1
                                        x: ct.tgt ? ct.tgt.col * (ccGrid.cw + root.ccGap) - ct.x : 0
                                        y: ct.tgt ? root.ccPlan.ys[ct.tgt.row] - ct.y : 0
                                        width: ct.slot ? ct.slot.w * ccGrid.cw + (ct.slot.w - 1) * root.ccGap : 0
                                        height: ct.slot ? ct.slot.hpx : 0
                                        radius: Math.min(width, height) * 0.3
                                        color: ok ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 0.27, 0.23, 0.18)
                                        border.width: 1.5
                                        border.color: ok ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 0.27, 0.23, 0.7)
                                    }

                                    property int rw: slot ? slot.w : 1
                                    property int rh: slot ? slot.h : 1
                                    property bool resizing: false
                                    readonly property var rng: root.ccRange(modelData.id)
                                    Rectangle {
                                        visible: ct.resizing
                                        z: -1
                                        width: ct.rw * ccGrid.cw + (ct.rw - 1) * root.ccGap
                                        height: ct.rh * root.ccCellH + (ct.rh - 1) * root.ccGap
                                        radius: Math.min(width, height) * 0.3
                                        color: Qt.rgba(1, 1, 1, 0.12)
                                        border.width: 1.5
                                        border.color: Qt.rgba(1, 1, 1, 0.6)
                                    }
                                    Rectangle {
                                        id: grip
                                        visible: ui.ccEdit && (ct.rng[1] > ct.rng[0] || ct.rng[3] > ct.rng[2])
                                        z: 70
                                        width: 20; height: 20; radius: 10
                                        anchors.right: parent.right; anchors.bottom: parent.bottom
                                        anchors.rightMargin: -4; anchors.bottomMargin: -4
                                        color: ccPal.dark ? "#636366" : "#8E8E93"
                                        border.width: 1.5
                                        border.color: ccPal.dark ? Qt.rgba(1, 1, 1, 0.35) : "white"
                                        scale: gripMa.pressed ? 1.18 : 1
                                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u2922"
                                            color: "white"; font.pixelSize: 11
                                        }
                                        MouseArea {
                                            id: gripMa
                                            anchors.fill: parent; anchors.margins: -4
                                            preventStealing: true
                                            cursorShape: Qt.SizeFDiagCursor
                                            property point startP: Qt.point(0, 0)
                                            onPressed: mouse => {
                                                var q = mapToItem(ccGrid, mouse.x, mouse.y);
                                                startP = Qt.point(q.x, q.y);
                                                ct.rw = ct.slot ? ct.slot.w : 1; ct.rh = ct.slot ? ct.slot.h : 1;
                                                ct.resizing = true;
                                            }
                                            onPositionChanged: mouse => {
                                                if (!pressed || !ct.slot) return;
                                                var q = mapToItem(ccGrid, mouse.x, mouse.y);
                                                var wc = Math.round((ct.width + (q.x - startP.x) + root.ccGap) / (ccGrid.cw + root.ccGap));
                                                var hc = Math.round((ct.height + (q.y - startP.y) + root.ccGap) / (root.ccCellH + root.ccGap));
                                                ct.rw = Math.max(ct.rng[0], Math.min(Math.min(ct.rng[1], 4 - ct.slot.col), wc));
                                                ct.rh = Math.max(ct.rng[2], Math.min(ct.rng[3], hc));
                                            }
                                            onReleased: { ct.resizing = false; root.ccResizeTo(ct.modelData.id, ct.rw, ct.rh); }
                                            onCanceled: ct.resizing = false
                                        }
                                    }

                                    Rectangle {
                                        readonly property var opts: ct.modelData.sizes || []
                                        visible: ui.ccEdit && opts.length > 1
                                        z: 60
                                        anchors.right: parent.right; anchors.top: parent.top
                                        anchors.rightMargin: -3; anchors.topMargin: -5
                                        width: sizeLbl.implicitWidth + 12; height: 20; radius: 10
                                        color: ccPal.dark ? "#636366" : "#8E8E93"
                                        border.width: 1.5
                                        border.color: ccPal.dark ? Qt.rgba(1, 1, 1, 0.35) : "white"
                                        Text {
                                            id: sizeLbl
                                            anchors.centerIn: parent
                                            text: ct.resizing ? (ct.rw + "×" + ct.rh) : (ct.slot ? (ct.slot.w + "×" + ct.slot.h) : "")
                                            color: "white"; font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 10; font.weight: Font.DemiBold
                                        }
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -3
                                            onClicked: root.ccCycleSize(ct.modelData.id)
                                        }
                                    }

                                    Rectangle {
                                        visible: ui.ccEdit
                                        z: 60
                                        x: -5; y: -5
                                        width: 22; height: 22; radius: 11
                                        color: ccPal.dark ? "#636366" : "#8E8E93"
                                        border.width: 1.5
                                        border.color: ccPal.dark ? Qt.rgba(1, 1, 1, 0.35) : "white"
                                        Rectangle { anchors.centerIn: parent; width: 10; height: 2; radius: 1; color: "white" }
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -3
                                            onClicked: root.ccRemove(ct.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            visible: ui.ccEdit && ccAddRep.count > 0
                            width: parent.width
                            spacing: 8
                            Text {
                                leftPadding: 4
                                text: I18n.tr("Add Controls")
                                color: ccPal.fg2
                                font.family: root.fontForWeight(Font.DemiBold, ccPal.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            Flow {
                                width: parent.width
                                spacing: 8
                                Repeater {
                                    id: ccAddRep
                                    model: root.ccCatalog.filter(function (d) { return root.ccControls.indexOf(d.id) < 0 && root.ccAvailable(d.id); })
                                    delegate: CCTile {
                                        id: chip
                                        required property var modelData
                                        t: ccPal; gx: ccg
                                        radius: 17
                                        width: chipRow.implicitWidth + 24; height: 34
                                        Row {
                                            id: chipRow
                                            anchors.centerIn: parent
                                            spacing: 7
                                            Rectangle {
                                                width: 18; height: 18; radius: 9
                                                color: "#30D158"
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text { anchors.centerIn: parent; text: "+"; color: "white"; font.family: Fonts.forWeight(Font.Bold, pal.fam); font.pixelSize: 14; font.weight: Font.Bold }
                                            }
                                            Glyph {
                                                width: 16; height: 16
                                                anchors.verticalCenter: parent.verticalCenter
                                                kind: chip.modelData.glyph; color: ccPal.ink
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: I18n.tr(chip.modelData.label)
                                                color: ccPal.fg; font.family: root.fontForWeight(Font.Normal, ccPal.fam); font.pixelSize: 12
                                            }
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: root.ccAdd(chip.modelData.id) }
                                    }
                                }
                            }
                        }

                        Item {
                            id: ccEditRow
                            width: parent.width; height: 28
                            property real ap: 1
                            Connections {
                                target: cc
                                function onOpenSeqChanged() { ccEditRow.ap = 0; editIn.restart(); }
                            }
                            SequentialAnimation {
                                id: editIn
                                PauseAnimation { duration: Math.min(220, root.ccPlan.rows * 55 + 40) }
                                NumberAnimation { target: ccEditRow; property: "ap"; from: 0; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                            }
                            transform: Translate { y: (1 - ccEditRow.ap) * 16 }
                            opacity: Math.max(0, Math.min(1, ccEditRow.ap * 1.6))
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                CCPill {
                                    visible: ui.ccEdit && root.ccFree
                                    t: ccPal; gx: ccg
                                    text: I18n.tr("Tidy Up")
                                    onClicked: root.ccTidy()
                                }
                                CCPill {
                                    visible: ui.ccEdit
                                    t: ccPal; gx: ccg
                                    text: I18n.tr("Reset")
                                    onClicked: root.ccResetLayout()
                                }
                                CCPill {
                                    visible: ui.ccEdit
                                    t: ccPal; gx: ccg
                                    text: I18n.tr("Cancel")
                                    onClicked: { root.ccEditCancel(); ui.ccEdit = false; }
                                }
                                CCPill {
                                    t: ccPal; gx: ccg
                                    text: ui.ccEdit ? I18n.tr("Save") : I18n.tr("Edit Controls")
                                    strong: ui.ccEdit
                                    onClicked: {
                                        if (ui.ccEdit) { root.ccEditSave(); ui.ccEdit = false; }
                                        else { root.ccEditBegin(); ui.ccEdit = true; }
                                    }
                                }
                            }
                        }
                    }
                    }
                }
            }
        }

        PanelWindow {
            id: swWin
            screen: perScreen.modelData
            visible: (root.swOpen && ui.toastScreen) || swPanel.opacity > 0
            onVisibleChanged: root.popCount += (visible ? 1 : -1)
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "yukiswitch"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (root.swOpen && ui.toastScreen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: swRoot
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right) { root.swNext(1); event.accepted = true; }
                    else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left) { root.swNext(-1); event.accepted = true; }
                    else if (event.key === Qt.Key_Escape) { root.swCancel(); event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.swCommit(); event.accepted = true; }
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt && !event.isAutoRepeat) { root.swCommit(); event.accepted = true; }
                }

                Loader {
                    id: swBackdrop
                    active: root.liquidBase
                    sourceComponent: backdropComp
                    onLoaded: { item.onDemand = true; item.hostShown = Qt.binding(function () { return swWin.visible; });
                                item.region = Qt.binding(function () { return Qt.rect(swPanel.x - 96, swPanel.y - 96, swPanel.width + 192, swPanel.height + 192); }); }
                }
                MouseArea { anchors.fill: parent; onPressed: root.swCancel() }

                Item {
                    id: swPanel
                    z: 10
                    readonly property int n: root.swApps.length
                    readonly property real cw: Math.min(92, (swRoot.width - 160) / Math.max(n, 1))
                    readonly property real ico: Math.round(cw * 0.7)
                    readonly property real pad: 14
                    readonly property real cellH: Math.round(cw * 0.8)
                    readonly property real padY: 9
                    width: n * cw + 2 * pad
                    height: padY + cellH + 25
                    x: Math.round((swRoot.width - width) / 2)
                    y: Math.round(swRoot.height * 0.42 - height / 2)
                    readonly property bool shown: root.swOpen && ui.toastScreen
                    opacity: shown ? 1 : 0
                    visible: opacity > 0
                    scale: shown ? 1 : 0.92
                    transformOrigin: Item.Center
                    Behavior on opacity { NumberAnimation { duration: swPanel.shown ? 220 : 160; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: swPanel.shown ? 420 : 200; easing.type: Easing.OutQuint } }
                    property real soft: shown ? 0 : 1
                    Behavior on soft { NumberAnimation { duration: swPanel.shown ? 300 : 160; easing.type: Easing.OutCubic } }
                    layer.enabled: soft > 0.01
                    layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: swPanel.soft * 0.8; autoPaddingEnabled: true }

                    readonly property string style: root.switcherStyle
                    LGlass {
                        anchors.fill: parent
                        visible: swPanel.style !== "opaque"
                        backdrop: swBackdrop.item
                        shaderUrl: root.glassShaderUrl
                        liquid: root.liquidActive
                        dark: root.effDark
                        bx: swPanel.x; by: swPanel.y
                        cornerR: 26
                        tint: swPanel.style === "frosted" ? Math.max(0.5, root.glassOpacity) : root.glassOpacity
                        thickness: swPanel.style === "frosted" ? 6 : 20
                        strength: swPanel.style === "frosted" ? 0.0 : 0.75 * root.glassLiquidEff
                        rim: swPanel.style === "frosted" ? 0.15 : root.glassRimEff
                        grain: root.glassGrain
                        blur: swPanel.style === "frosted" ? 30 : root.switcherBlur
                        debug: root.glassDebug
                        onShaderError: root.glassState = "failed"
                        rimTint: 1
                        ringW: 1.4
                    }
                    MenuBorder {
                        z: 2
                        anchors.fill: parent
                        visible: swPanel.style !== "opaque"
                        cornerR: 26
                        dark: root.effDark
                        tint: root.menuBorderColor
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: swPanel.style === "opaque"
                        radius: 26
                        color: root.effDark ? "#232325" : "#F2F2F5"
                        border.width: 1; border.color: root.effDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 1.0; shadowOpacity: 0.35; shadowVerticalOffset: 8 }
                    }

                    Rectangle {
                        visible: swPanel.n > 0
                        x: swPanel.pad + root.swIndex * swPanel.cw
                        y: swPanel.padY
                        width: swPanel.cw; height: swPanel.cellH
                        radius: 17
                        color: root.darkMode ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.11)
                        border.width: 1
                        border.color: root.darkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.06)
                        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                    }
                    Repeater {
                        model: root.swApps
                        delegate: Item {
                            id: swCell
                            required property int index
                            required property var modelData
                            x: swPanel.pad + index * swPanel.cw
                            y: swPanel.padY
                            width: swPanel.cw; height: swPanel.cellH
                            Image {
                                anchors.centerIn: parent
                                width: swPanel.ico; height: swPanel.ico
                                source: root.swIcon(swCell.modelData)
                                sourceSize.width: 128; sourceSize.height: 128
                                fillMode: Image.PreserveAspectFit
                                smooth: true; mipmap: true
                                asynchronous: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onPositionChanged: root.swIndex = swCell.index
                                onClicked: { root.swIndex = swCell.index; root.swCommit(); }
                            }
                        }
                    }
                    TextMetrics { id: swNameM; font.family: root.fontForWeight(Font.Medium, pal.fam); font.pixelSize: 13; font.weight: Font.Medium; text: swName.text }
                    Item {
                        id: swNameBox
                        visible: swPanel.n > 0
                        width: 260; height: swName.implicitHeight
                        readonly property real cx: swPanel.pad + root.swIndex * swPanel.cw + swPanel.cw / 2
                        readonly property real tw: Math.min(swNameM.advanceWidth, swPanel.width - 20)
                        readonly property real cxc: Math.max(10 + tw / 2, Math.min(swPanel.width - 10 - tw / 2, cx))
                        x: cxc - width / 2
                        y: swPanel.padY + swPanel.cellH + 3
                        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
                        MorphText {
                            id: swName
                            width: parent.width
                            text: root.swApps.length > root.swIndex ? root.swApps[root.swIndex].name : ""
                            color: swPanel.style === "opaque" ? (root.effDark ? "white" : "#1D1D1F") : pal.fg
                            font.family: root.fontForWeight(Font.Medium, pal.fam); font.pixelSize: 13; font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            animateWidth: false
                            duration: 320
                        }
                    }
                }
            }
        }

        PanelWindow {
            id: wpWin
            screen: perScreen.modelData
            visible: (root.wpOpen && ui.toastScreen) || wpPanel.opacity > 0
            onVisibleChanged: root.popCount += (visible ? 1 : -1)
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "yukiwall"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: !(root.wpOpen && ui.toastScreen) ? WlrKeyboardFocus.None
                                       : (root.wpTermAddr !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)

            Item {
                id: wpRoot
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: event => { if (root.wpQuery !== "") root.wpQuery = ""; else root.wpOpen = false; event.accepted = true; }
                Connections {
                    target: root
                    function onWpOpenChanged() { if (root.wpOpen) { root.wpQuery = ""; wpGrid.currentIndex = 0; wpGrid.forceActiveFocus(); } }
                    function onWpQueryChanged() {
                        if (wpSearch.text !== root.wpQuery) wpSearch.text = root.wpQuery;
                        wpGrid.currentIndex = 0;
                        wpGrid.positionViewAtBeginning();
                    }
                }

                Loader {
                    id: wpBackdrop
                    active: root.liquidBase
                    sourceComponent: backdropComp
                    onLoaded: { item.onDemand = true; item.hostShown = Qt.binding(function () { return wpWin.visible; });
                                item.region = Qt.binding(function () { return Qt.rect(wpPanel.x - 96, wpPanel.y - 96, wpPanel.width + 192, wpPanel.height + 192); }); }
                }
                MouseArea { anchors.fill: parent; onPressed: root.wpOpen = false }

                Item {
                    id: wpPanel
                    z: 10
                    width: Math.min(980, wpRoot.width - 120)
                    height: Math.min(640, wpRoot.height - 160)
                    x: Math.round((wpRoot.width - width) / 2)
                    y: Math.round((wpRoot.height - height) / 2)
                    opacity: (root.wpOpen && ui.toastScreen) ? 1 : 0
                    visible: opacity > 0
                    scale: (root.wpOpen && ui.toastScreen) ? 1 : 0.96
                    transformOrigin: Item.Center
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    LGlass {
                        anchors.fill: parent
                        backdrop: wpBackdrop.item
                        shaderUrl: root.glassShaderUrl
                        liquid: root.liquidActive
                        dark: root.effDark
                        bx: wpPanel.x; by: wpPanel.y
                        cornerR: 28
                        tint: root.glassOpacity
                        thickness: 22
                        strength: 0.75 * root.glassLiquidEff
                        rim: root.glassRimEff
                        grain: root.glassGrain
                        blur: root.wpBlur
                        debug: root.glassDebug
                        onShaderError: root.glassState = "failed"
                        rimTint: 1
                        ringW: 1.4
                    }
                    MenuBorder {
                        z: 2
                        anchors.fill: parent
                        cornerR: 28
                        dark: root.effDark
                        tint: root.menuBorderColor
                    }

                    Item {
                        id: wpHead
                        x: 22; y: 14
                        width: parent.width - 44; height: 34
                        Text {
                            id: wpTitle
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Wallpapers")
                            color: pal.fg
                            font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 15; font.weight: Font.DemiBold
                        }
                        Rectangle {
                            id: wpChoose
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 112; height: 30; radius: 10
                            color: wpChooseMa.containsMouse ? pal.btnHover : pal.btnOff
                            Text { anchors.centerIn: parent; text: I18n.tr("Add Folder\u2026"); color: pal.fg; font.family: root.fontForWeight(Font.Medium, pal.fam); font.pixelSize: 12; font.weight: Font.Medium }
                            MouseArea { id: wpChooseMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.wpPickFolder() }
                        }
                        ListView {
                            id: wpChips
                            anchors.left: wpTitle.right; anchors.leftMargin: 18
                            anchors.right: wpChoose.left; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 30
                            orientation: ListView.Horizontal
                            spacing: 6
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.wpDirsEff
                            delegate: Rectangle {
                                id: dirChip
                                required property string modelData
                                readonly property bool removable: root.wpDirsEff.length > 1
                                height: 30; radius: 10
                                width: Math.min(220, chipTxt.implicitWidth + 24 + (removable ? 22 : 0))
                                color: chipMa.containsMouse ? pal.btnHover : pal.tile
                                border.width: 1; border.color: pal.tileBorder
                                Text {
                                    id: chipTxt
                                    x: 12; anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, dirChip.width - 24 - (dirChip.removable ? 22 : 0))
                                    elide: Text.ElideMiddle
                                    text: dirChip.modelData.replace(Quickshell.env("HOME"), "~")
                                    color: pal.fg
                                    font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 12
                                }
                                MouseArea {
                                    id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.wpOpenFolder(dirChip.modelData, wpPanel, wpWin.screen)
                                }
                                Rectangle {
                                    visible: dirChip.removable
                                    anchors.right: parent.right; anchors.rightMargin: 5; anchors.verticalCenter: parent.verticalCenter
                                    width: 18; height: 18; radius: 9
                                    color: chipX.containsMouse ? pal.btnHover : "transparent"
                                    Text { anchors.centerIn: parent; text: "\u00d7"; color: pal.fg2; font.family: Fonts.forWeight(Font.Normal, pal.fam); font.pixelSize: 14 }
                                    MouseArea { id: chipX; anchors.fill: parent; hoverEnabled: true; onClicked: root.wpRemoveDir(dirChip.modelData) }
                                }
                            }
                        }
                    }
                    Rectangle {
                        id: wpSearchBox
                        x: 22; y: 54
                        width: Math.min(260, parent.width * 0.4); height: 28; radius: 10
                        color: pal.tile
                        border.width: 1
                        border.color: wpSearch.activeFocus ? pal.accent : pal.tileBorder
                        Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; kind: "search"; color: pal.fg2 }
                        TextInput {
                            id: wpSearch
                            anchors.fill: parent
                            anchors.leftMargin: 30; anchors.rightMargin: 26
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            color: pal.fg
                            selectionColor: pal.accent
                            font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 12
                            onTextChanged: if (root.wpQuery !== text) root.wpQuery = text
                            Keys.onDownPressed: wpGrid.forceActiveFocus()
                            Keys.onReturnPressed: {
                                if (root.wpShown.length > 0) { root.wpApply(root.wpShown[Math.max(0, wpGrid.currentIndex)].path); root.wpOpen = false; }
                            }
                            Text {
                                visible: wpSearch.text === "" && !wpSearch.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Search")
                                color: pal.fg3
                                font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 12
                            }
                        }
                        Rectangle {
                            visible: root.wpQuery !== ""
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: pal.btnOff
                            Text { anchors.centerIn: parent; text: "\u00d7"; color: pal.fg; font.family: Fonts.forWeight(Font.Normal, pal.fam); font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; onClicked: { root.wpQuery = ""; wpGrid.forceActiveFocus(); } }
                        }
                    }
                    Text {
                        id: wpSub
                        anchors.left: wpSearchBox.right; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 22
                        y: 54; height: 28
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: root.wpStatus !== "" ? root.wpStatus
                              : (root.wpShown.length + (root.wpShown.length === 1 ? I18n.tr(" image") : I18n.tr(" images"))
                                 + ((root.wallpaperFavs || []).length > 0 ? I18n.tr("  \u00b7  \u2605 first") : "")
                                 + I18n.tr("  \u00b7  Type to search, Enter apply, Space favourite"))
                        color: pal.fg3
                        font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 11
                    }

                    GridView {
                        id: wpGrid
                        x: 16; y: 94
                        width: parent.width - 38; height: parent.height - 94 - 14
                        clip: true
                        readonly property int cols: Math.max(2, Math.floor(width / 210))
                        cellWidth: Math.floor(width / cols)
                        cellHeight: Math.round(cellWidth * 0.64)
                        model: root.wpShown
                        currentIndex: 0
                        keyNavigationEnabled: true
                        highlightMoveDuration: 0
                        Keys.onPressed: event => {
                            var ok = currentIndex >= 0 && currentIndex < root.wpShown.length;
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && ok) {
                                root.wpApply(root.wpShown[currentIndex].path); root.wpOpen = false; event.accepted = true;
                            } else if (event.key === Qt.Key_Space && ok) {
                                root.wpToggleFav(root.wpShown[currentIndex].path); event.accepted = true;
                            } else if (event.key === Qt.Key_Slash || (event.text.length === 1 && event.text > " " && event.text !== "\u007f"
                                       && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))) {
                                wpSearch.forceActiveFocus();
                                if (event.key !== Qt.Key_Slash) root.wpQuery += event.text;
                                wpSearch.cursorPosition = wpSearch.length;
                                event.accepted = true;
                            }
                        }

                        delegate: Item {
                            id: wc
                            required property int index
                            required property var modelData
                            width: wpGrid.cellWidth; height: wpGrid.cellHeight
                            readonly property bool sel: wpGrid.currentIndex === index
                            readonly property bool cur: modelData.video ? root.wallpaperVideo === modelData.path
                                                                        : (root.wallpaperVideo === "" && root.wallpaperPath === modelData.path)
                            Item {
                                id: wcBox
                                anchors.fill: parent
                                anchors.margins: 5
                                Item {
                                    id: wcMask
                                    anchors.fill: parent
                                    visible: false
                                    layer.enabled: true
                                    layer.smooth: true
                                    Rectangle { anchors.fill: parent; radius: 12; color: "black" }
                                }
                                Item {
                                    anchors.fill: parent
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: wcMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                    }
                                    Rectangle { anchors.fill: parent; color: pal.btnOff }
                                    Image {
                                        anchors.fill: parent
                                        source: root.fileUrl(wc.modelData.video ? wc.modelData.thumb : wc.modelData.path)
                                        sourceSize.width: 420
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                    }
                                    Rectangle {
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                        height: 26
                                        color: Qt.rgba(0, 0, 0, 0.5)
                                        opacity: (wc.sel || wcMa.containsMouse) ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10; anchors.rightMargin: 36
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                            text: wc.modelData.name
                                            color: "white"
                                            font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 11
                                        }
                                    }
                                    Loader {
                                        anchors.fill: parent
                                        active: wc.modelData.video && wc.modelData.preview !== "" && (wcMa.containsMouse || wc.sel) && root.wpOpen
                                        sourceComponent: AnimatedImage {
                                            source: root.fileUrl(wc.modelData.preview)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: false
                                            playing: true
                                        }
                                    }
                                    Rectangle {
                                        visible: wc.modelData.video
                                        x: 8; y: 8
                                        width: wcBadge.implicitWidth + 14; height: 20; radius: 10
                                        color: Qt.rgba(0, 0, 0, 0.5)
                                        Text {
                                            id: wcBadge
                                            anchors.centerIn: parent
                                            text: I18n.tr("\u25B6  Animated")
                                            color: "white"
                                            font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 10; font.weight: Font.DemiBold
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: "transparent"
                                    border.width: wc.sel ? 3 : (wc.cur ? 2 : 0)
                                    border.color: wc.sel ? pal.accent : "white"
                                }
                                MouseArea {
                                    id: wcMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onPositionChanged: wpGrid.currentIndex = wc.index
                                    onClicked: { root.wpApply(wc.modelData.path); root.wpOpen = false; }
                                }
                                Rectangle {
                                    anchors.right: parent.right; anchors.top: parent.top
                                    anchors.margins: 7
                                    width: 26; height: 26; radius: 13
                                    visible: wc.modelData.fav || wcMa.containsMouse || wcStarMa.containsMouse
                                    color: Qt.rgba(0, 0, 0, wcStarMa.containsMouse ? 0.62 : 0.45)
                                    Text {
                                        anchors.centerIn: parent
                                        text: wc.modelData.fav ? "\u2605" : "\u2606"
                                        color: wc.modelData.fav ? "#ffd60a" : "white"
                                        font.family: Fonts.forWeight(Font.Normal, pal.fam); font.pixelSize: 15
                                    }
                                    MouseArea {
                                        id: wcStarMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.wpToggleFav(wc.modelData.path)
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        id: wpTrack
                        visible: wpGrid.contentHeight > wpGrid.height + 1
                        x: parent.width - 16; y: wpGrid.y + 2
                        width: 10; height: wpGrid.height - 4
                        readonly property real ratio: Math.min(1, wpGrid.visibleArea.heightRatio)
                        readonly property real thumbH: Math.max(32, ratio * height)
                        readonly property real maxY: Math.max(1, height - thumbH)
                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 4; height: parent.height; radius: 2; color: pal.track; opacity: 0.6 }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: mouse => wpTrack.jumpTo(mouse.y - wpTrack.thumbH / 2)
                        }
                        function jumpTo(ty) {
                            var f = Math.max(0, Math.min(1, ty / wpTrack.maxY));
                            wpGrid.contentY = wpGrid.originY + f * Math.max(0, wpGrid.contentHeight - wpGrid.height);
                        }
                        Rectangle {
                            id: wpThumb
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: wpThumbMa.containsMouse || wpThumbMa.drag.active ? 7 : 5
                            height: wpTrack.thumbH
                            radius: width / 2
                            color: wpThumbMa.drag.active ? pal.fg2 : pal.fg3
                            Behavior on width { NumberAnimation { duration: 100 } }
                            Binding {
                                target: wpThumb; property: "y"
                                when: !wpThumbMa.drag.active
                                value: (1 - wpTrack.ratio) > 0.0001 ? Math.max(0, Math.min(wpTrack.maxY, wpGrid.visibleArea.yPosition / (1 - wpTrack.ratio) * wpTrack.maxY)) : 0
                            }
                            MouseArea {
                                id: wpThumbMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                drag.target: wpThumb
                                drag.axis: Drag.YAxis
                                drag.minimumY: 0
                                drag.maximumY: wpTrack.maxY
                                onPositionChanged: if (drag.active) wpTrack.jumpTo(wpThumb.y)
                            }
                        }
                    }
                    Text {
                        visible: root.wpShown.length === 0
                        anchors.centerIn: parent
                        width: parent.width - 80
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.wpQuery !== "" ? I18n.tr("No wallpapers match \u201c") + root.wpQuery + "\u201d"
                              : I18n.tr("No images in your wallpaper folders.\nDrop some in, or add a folder with Add Folder\u2026")
                        color: pal.fg2
                        font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: 13
                    }
                }
            }
        }

        PanelWindow {
            id: spotWin
            screen: perScreen.modelData
            visible: root.spotlightEnabled
            readonly property bool openish: ui.pop === "spot" || spot.vis > 0
            onOpenishChanged: root.popCount += (openish ? 1 : -1)
            mask: Region { item: spotWin.openish ? spotRoot : spotNoInput }
            Item { id: spotNoInput; width: 0; height: 0 }
            function panelRect() {
                if (ui.pop === "spot") return Qt.rect(perScreen.modelData.x + spot.x, perScreen.modelData.y + spot.y, spot.width, spot.height);
                var r = ui.glassRect;
                if (r.width <= 128) return null;
                return Qt.rect(perScreen.modelData.x + r.x + 64, perScreen.modelData.y + r.y + 64, r.width - 128, r.height - 128);
            }
            function measureLive() {
                if (!root.toneMeasuring || ui.pop === "" || !ui.toastScreen) return;
                var pr = panelRect();
                if (pr) root.measureAround(perScreen.modelData, pr, false);
            }
            Timer { interval: 700; repeat: true; running: root.toneMeasuring && ui.pop !== "" && ui.toastScreen; onTriggered: spotWin.measureLive() }
            Timer { id: liveKick; interval: 180; onTriggered: spotWin.measureLive() }
            Connections { target: root; function onGlassClientsChanged() { if (ui.pop !== "") liveKick.restart(); } }
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "yukispot"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: ui.pop === "spot" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: spotRoot
                anchors.fill: parent

                Loader {
                    id: spotBackdrop
                    active: root.liquidBase
                    sourceComponent: backdropComp
                    onLoaded: { item.onDemand = true; item.hostShown = Qt.binding(function () { return !root.gaming && spotWin.openish; });
                                item.region = Qt.binding(function () { return Qt.rect(spot.x - 128, spot.y - 128, spot.width + 256, spot.height + 256); }); }
                }

                Item {
                    id: clipGhost
                    z: 50
                    property var en: null
                    property real px: 0
                    property real py: 0
                    property real zoom: 1
                    property real wob: 0
                    property real homeX: 0
                    property real homeY: 0
                    visible: en !== null
                    width: 220; height: en && en.kind === "image" ? 150 : 64
                    x: px - width / 2; y: py - height / 2
                    scale: zoom; rotation: wob
                    function start(e) { en = e; zoom = 1.06; opacity = 1; homeX = px; homeY = py; wiggleClip.restart(); }
                    function drop(out) {
                        wiggleClip.stop();
                        if (out) { clipLaunch.restart(); }
                        else { clipBack.restart(); }
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 14
                        color: spotPal.dark ? Qt.rgba(0.16, 0.16, 0.18, 0.92) : Qt.rgba(0.97, 0.97, 0.98, 0.95)
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                    }
                    Image {
                        visible: clipGhost.en && clipGhost.en.kind === "image"
                        anchors.fill: parent; anchors.margins: 6
                        source: clipGhost.en && clipGhost.en.thumb ? clipGhost.en.thumb : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                    Text {
                        visible: !(clipGhost.en && clipGhost.en.kind === "image")
                        anchors.fill: parent; anchors.margins: 12
                        text: clipGhost.en ? clipGhost.en.text : ""
                        wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2
                        color: "white"; font.family: root.fontForWeight(Font.Normal, root.fontFamily); font.pixelSize: 13
                    }
                    SequentialAnimation {
                        id: wiggleClip; loops: Animation.Infinite
                        NumberAnimation { target: clipGhost; property: "wob"; to: 3; duration: 90; easing.type: Easing.InOutSine }
                        NumberAnimation { target: clipGhost; property: "wob"; to: -3; duration: 180; easing.type: Easing.InOutSine }
                        NumberAnimation { target: clipGhost; property: "wob"; to: 0; duration: 90; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation {
                        id: clipLaunch
                        ParallelAnimation {
                            NumberAnimation { target: clipGhost; property: "zoom"; to: 2.2; duration: 460; easing.type: Easing.OutQuint }
                            NumberAnimation { target: clipGhost; property: "opacity"; to: 0; duration: 460; easing.type: Easing.OutCubic }
                            NumberAnimation { target: clipGhost; property: "wob"; to: 0; duration: 200 }
                        }
                        ScriptAction { script: { var e = clipGhost.en; clipGhost.en = null; ui.pop = ""; if (e) root.clipOpen(e); } }
                    }
                    SequentialAnimation {
                        id: clipBack
                        ParallelAnimation {
                            NumberAnimation { target: clipGhost; property: "px"; to: clipGhost.homeX; duration: 380; easing.type: Easing.OutQuint }
                            NumberAnimation { target: clipGhost; property: "py"; to: clipGhost.homeY; duration: 380; easing.type: Easing.OutQuint }
                            NumberAnimation { target: clipGhost; property: "wob"; to: 0; duration: 200 }
                            NumberAnimation { target: clipGhost; property: "opacity"; to: 0; duration: 380; easing.type: Easing.InCubic }
                        }
                        ScriptAction { script: clipGhost.en = null }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onPressed: ui.pop = ""
                }

                readonly property rect spCapLocal: Qt.rect(spot.x - 128, spot.y - 128, spot.width + 256, 684)
                readonly property real spCapS: root.barPopupScale
                readonly property rect spCapScreen: {
                    var cx = spot.x + spot.width / 2, cy = spot.y + spot.height / 2, k = spCapS, l = spCapLocal;
                    return Qt.rect(cx + (l.x - cx) * k, cy + (l.y - cy) * k, l.width * k, l.height * k);
                }
                ShaderEffectSource {
                    id: spSrc
                    sourceItem: spotBackdrop.item
                    hideSource: true
                    live: spotWin.openish
                    visible: false
                    sourceRect: spotRoot.spCapScreen
                }
                MultiEffect {
                    id: spBlurFx
                    source: spSrc
                    width: spSrc.sourceRect.width; height: spSrc.sourceRect.height
                    blurEnabled: true
                    blurMax: 64
                    blur: Math.min(1.0, (spg.blur * spg.blurMul) * 1.4 / 64.0)
                    autoPaddingEnabled: false
                    visible: false
                }
                ShaderEffectSource {
                    id: spBlur
                    sourceItem: spBlurFx
                    live: spotWin.openish
                    mipmap: true
                    visible: false
                }
                GlassCtx {
                    id: spg
                    src: spBlur
                    srcRect: spotRoot.spCapLocal
                    frame: spotRoot
                    liquid: root.liquidActive
                    shaderUrl: root.glassShaderUrl
                    dark: spotPal.dark
                    tint: root.glassOpacity
                    strength: root.glassLiquidEff
                    rim: root.glassRimEff
                    rimTint: 1
                    ringW: 0.9
                    whiteEdge: false
                    grain: root.glassGrain
                    blur: root.glassBlurEff
                    blurMul: 2.0
                    debug: root.glassDebug
                    onFailed: root.glassState = "failed"
                }

                Item {
                    id: spot
                    z: 10
                    width: 640
                    readonly property var curPanel: ui.spMode === "apps" ? appsPanel : (ui.spMode === "clip" ? clipPanel : emojiPanel)
                    height: ui.spFull ? curPanel.height : (resPanel.visible ? resPanel.y + resPanel.height : spRow.height)
                    x: Math.round((spotRoot.width - width) / 2)
                    y: Math.round(spotRoot.height * 0.4 - (ui.spFull ? curPanel.height / 2 : 24))
                    Behavior on y { enabled: spot.vis > 0.99; NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
                    property real vis: 0
                    opacity: vis
                    visible: vis > 0.001
                    readonly property real uiS: root.barPopupScale
                    scale: uiS * (ui.spCalm ? 0.98 : 0.93)
                    transformOrigin: Item.Center
                    states: State {
                        name: "open"
                        when: ui.pop === "spot"
                        PropertyChanges { target: spot; vis: 1; scale: spot.uiS }
                    }
                    transitions: [
                        Transition {
                            from: ""; to: "open"
                            ParallelAnimation {
                                NumberAnimation { property: "vis"; duration: root.reduceMotion ? 0 : 260; easing.type: Easing.OutQuint }
                                NumberAnimation { property: "scale"; duration: root.reduceMotion ? 0 : 420; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
                            }
                        },
                        Transition {
                            from: "open"; to: ""
                            ParallelAnimation {
                                NumberAnimation { property: "vis"; duration: root.reduceMotion ? 0 : 180; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "scale"; to: spot.uiS * 0.96; duration: root.reduceMotion ? 0 : 180; easing.type: Easing.OutCubic }
                            }
                        }
                    ]

                    Timer { id: spHoverClear; interval: 350; onTriggered: ui.spHoverLabel = "" }
                    Timer {
                        id: spFocusTimer
                        interval: 60
                        onTriggered: (ui.spMode === "apps" ? appsInput : (ui.spMode === "clip" ? clipInput : (ui.spMode === "emoji" ? emojiInput : spInput))).forceActiveFocus()
                    }

                    Row {
                        id: spRow
                        spacing: 12
                        opacity: !ui.spFull ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Item {
                            id: spPill
                            width: spot.width - 5 * 60
                            height: 48
                            GGlass { anchors.fill: parent; gx: spg; cornerR: 24; thickness: 22; strengthMul: 1.0; shadowAmt: 0.08 }
                            HoverHandler { id: pillHover }
                            ContourGlow { cornerR: 24; hovered: pillHover.hovered; at: pillHover.point.position; glowColor: spotPal.dark ? "white" : root.accent }
                            MenuBorder { amount: 0.5; anchors.fill: parent; cornerR: 24; dark: spotPal.dark; tint: root.menuBorderColor }
                            Glyph {
                                x: 18; anchors.verticalCenter: parent.verticalCenter
                                width: 18; height: 18
                                kind: "search"; color: spotPal.fg2
                            }
                            MorphText {
                                x: spInput.x + 3
                                width: spInput.width
                                anchors.verticalCenter: parent.verticalCenter
                                visible: spInput.text === ""
                                animateWidth: false
                                duration: 460
                                blurMax: 48
                                text: ui.spHoverLabel !== "" ? ui.spHoverLabel : I18n.tr("Search")
                                color: spotPal.fg2
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 17
                                elide: Text.ElideRight
                            }
                            TextInput {
                                id: spInput
                                x: 46
                                width: parent.width - 46 - 44
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                color: spotPal.fg
                                selectionColor: root.accent
                                selectedTextColor: "white"
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 17
                                horizontalAlignment: /[\u0590-\u08ff]/.test(text) ? Text.AlignRight : Text.AlignLeft
                                onTextChanged: { if (!ui.spFull) { ui.spQuery = text; ui.spSel = 0; ui.armed = ""; if (/^(file|find)\s+/i.test(text)) root.updateFileSearch(text.replace(/^(file|find)\s+/i, "").trim()); } }
                                Keys.onPressed: event => ui.spKey(event)
                            }
                            Item {
                                id: spClear
                                anchors.right: parent.right; anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22
                                opacity: spInput.text !== "" && !ui.spFull ? 1 : 0
                                visible: opacity > 0
                                scale: 0.8 + 0.2 * opacity
                                Behavior on opacity { NumberAnimation { duration: root.reduceMotion ? 0 : 140; easing.type: Easing.OutCubic } }
                                Rectangle {
                                    anchors.fill: parent; radius: 11
                                    color: spotPal.dark ? Qt.rgba(1, 1, 1, clearMa.containsMouse ? 0.24 : 0.14) : Qt.rgba(0, 0, 0, clearMa.containsMouse ? 0.16 : 0.09)
                                    Behavior on color { ColorAnimation { duration: root.reduceMotion ? 0 : 120 } }
                                }
                                Glyph { anchors.centerIn: parent; width: 14; height: 14; kind: "close"; color: spotPal.fg2 }
                                MouseArea {
                                    id: clearMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { spInput.text = ""; spInput.forceActiveFocus(); }
                                }
                            }
                        }
                        Repeater {
                            model: [
                                { k: "appstore", id: "apps", label: I18n.tr("Apps") }, { k: "folder", id: "files", label: I18n.tr("Files") },
                                { k: "layers", id: "actions", label: I18n.tr("Actions") }, { k: "clipboard", id: "clip", label: I18n.tr("Clipboard") }, { k: "smile", id: "emoji", label: I18n.tr("Emoji") }
                            ]
                            delegate: CCBtn {
                                id: navBtn
                                required property var modelData
                                required property int index
                                t: pal; gx: spg
                                d: 48
                                matchMenuBorder: true
                                property real inT: 1
                                opacity: inT
                                transform: [
                                    Translate { y: (1 - navBtn.inT) * 4 },
                                    Scale { origin.x: navBtn.d / 2; origin.y: navBtn.d / 2; xScale: 0.88 + 0.12 * navBtn.inT; yScale: 0.88 + 0.12 * navBtn.inT }
                                ]
                                SequentialAnimation {
                                    id: navEnter
                                    PropertyAction { target: navBtn; property: "inT"; value: 0 }
                                    PauseAnimation { duration: navBtn.index * 24 }
                                    NumberAnimation { target: navBtn; property: "inT"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                                }
                                Connections {
                                    target: ui
                                    function onPopChanged() { if (ui.pop === "spot" && !root.reduceMotion && !ui.spCalm) navEnter.restart(); }
                                }
                                bounce: true
                                shadow: 0.18
                                kind: modelData.k
                                on: ui.spMode === modelData.id
                                HoverHandler {
                                    id: btnHover
                                    onHoveredChanged: {
                                        if (hovered) { spHoverClear.stop(); ui.spHoverLabel = modelData.label; }
                                        else if (ui.spHoverLabel === modelData.label) spHoverClear.restart();
                                    }
                                }
                                ContourGlow { cornerR: 24; hovered: btnHover.hovered; at: btnHover.point.position; glowColor: spotPal.dark ? "white" : root.accent }
                                onClicked: {
                                    if (modelData.id === "apps") ui.spSetMode(ui.spMode === "apps" ? "home" : "apps");
                                    else if (modelData.id === "actions") ui.spSetMode(ui.spMode === "actions" ? "home" : "actions");
                                    else if (modelData.id === "files") {
                                        if (ui.spMode !== "home") ui.spSetMode("home");
                                        if (/^(file|find)\s/i.test(spInput.text)) { spInput.text = ""; }
                                        else { spInput.text = "file "; spInput.cursorPosition = spInput.text.length; }
                                        spInput.forceActiveFocus();
                                    }
                                    else if (modelData.id === "clip") ui.spSetMode(ui.spMode === "clip" ? "home" : "clip");
                                    else ui.spSetMode(ui.spMode === "emoji" ? "home" : "emoji");
                                }
                            }
                        }
                    }

                    Item {
                        id: resPanel
                        y: spRow.height + 10
                        width: spot.width
                        readonly property var items: ui.spFull ? [] : ui.spResults
                        property int keep: 1
                        onItemsChanged: if (items.length > 0) keep = items.length
                        onSelIdxChanged: {
                            if (ui.spHover) { ui.spHover = false; return; }
                            var top = selIdx * 46, vh = resFlick.height;
                            if (top < resFlick.contentY) resFlick.contentY = top;
                            else if (top + 46 > resFlick.contentY + vh) resFlick.contentY = top + 46 - vh;
                        }
                        readonly property int selIdx: Math.max(0, Math.min(ui.spSel, items.length - 1))
                        opacity: (!ui.spFull && items.length > 0) ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: root.reduceMotion ? 0 : 160; easing.type: Easing.OutCubic } }
                        readonly property int maxRows: /^(file|find)\s+/i.test(ui.spQuery) ? 5 : 99
                        height: Math.min(items.length > 0 ? items.length : keep, maxRows) * 46 + 16
                        Behavior on height { NumberAnimation { duration: root.reduceMotion ? 0 : 220; easing.type: Easing.OutCubic } }
                        GGlass { anchors.fill: parent; gx: spg; cornerR: 26; thickness: 26; strengthMul: 1.0; shadowAmt: 0.10 }
                        MenuBorder { amount: 0.5; anchors.fill: parent; cornerR: 26; dark: spotPal.dark; tint: root.menuBorderColor }
                        Item {
                            x: 8; y: 8
                            width: parent.width - 16
                            height: parent.height - 16
                            clip: true
                        Flickable {
                            id: resFlick
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: resPanel.items.length * 46
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: contentHeight > height
                            flickableDirection: Flickable.VerticalFlick
                            Behavior on contentY { enabled: !resFlick.moving && !resFlick.dragging; NumberAnimation { duration: root.reduceMotion ? 0 : 120; easing.type: Easing.OutCubic } }
                            Rectangle {
                                y: resPanel.selIdx * 46
                                width: parent.width; height: 46; radius: 16
                                color: (resPanel.items[resPanel.selIdx] && resPanel.items[resPanel.selIdx].confirm === true
                                        && ui.armed === resPanel.items[resPanel.selIdx].title) ? "#FF453A" : root.accent
                                Behavior on y { NumberAnimation { duration: root.reduceMotion ? 0 : 120; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: root.reduceMotion ? 0 : 120 } }
                            }
                        Column {
                            width: parent.width
                            Repeater {
                                model: resPanel.items
                                delegate: Item {
                                    id: rr
                                    required property var modelData
                                    required property int index
                                    readonly property string ico: (modelData && modelData.icon) ? String(modelData.icon) : ""
                                    readonly property bool twoLine: !!(modelData && modelData.path)
                                    readonly property bool sel: index === Math.min(ui.spSel, resPanel.items.length - 1)
                                    readonly property bool armedNow: modelData.confirm === true && ui.armed === modelData.title
                                    width: parent.width
                                    height: 46
                                    property real enterY: 0
                                    transform: Translate { y: rr.enterY }
                                    Component.onCompleted: {
                                        if (!root.reduceMotion && resPanel.opacity < 0.5) { rr.opacity = 0; rr.enterY = 4; rowEnter.start(); }
                                    }
                                    SequentialAnimation {
                                        id: rowEnter
                                        PauseAnimation { duration: Math.min(rr.index, 7) * 16 }
                                        ParallelAnimation {
                                            NumberAnimation { target: rr; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
                                            NumberAnimation { target: rr; property: "enterY"; to: 0; duration: 160; easing.type: Easing.OutCubic }
                                        }
                                    }
                                    Item {
                                        x: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 30; height: 30
                                        Image {
                                            visible: rr.ico !== ""
                                            anchors.fill: parent
                                            source: rr.ico
                                            sourceSize: Qt.size(64, 64)
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            smooth: true
                                        }
                                        Glyph {
                                            visible: rr.ico === ""
                                            anchors.centerIn: parent
                                            width: 20; height: 20
                                            kind: (rr.modelData && rr.modelData.glyph) ? rr.modelData.glyph : ""
                                            color: rr.sel ? "white" : spotPal.fg
                                        }
                                    }
                                    Text {
                                        x: 54
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: rr.twoLine ? -8 : 0
                                        width: rr.twoLine ? parent.width - 54 - 16
                                               : parent.width - 54 - 16 - Math.min(rowSub.implicitWidth, parent.width * 0.4) - 12
                                        elide: Text.ElideRight
                                        text: rr.armedNow ? I18n.tr("Press Return again to confirm") : (rr.modelData ? rr.modelData.title : "")
                                        color: rr.sel ? "white" : spotPal.fg
                                        font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 14
                                    }
                                    Text {
                                        id: rowSub
                                        x: rr.twoLine ? 54 : parent.width - 16 - width
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: rr.twoLine ? 9 : 0
                                        width: rr.twoLine ? parent.width - 54 - 16 : Math.min(implicitWidth, parent.width * 0.4)
                                        elide: rr.twoLine ? Text.ElideMiddle : Text.ElideRight
                                        text: rr.modelData ? rr.modelData.sub : ""
                                        color: rr.sel ? Qt.rgba(1, 1, 1, 0.8) : spotPal.fg2
                                        font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: rr.twoLine ? 11 : 12
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onPositionChanged: mouse => { if (ui.spPointerMoved(parent, mouse.x, mouse.y) && ui.spSel !== rr.index) { ui.spHover = true; ui.spSel = rr.index; } }
                                        onClicked: mouse => ui.spActivate(rr.index, (mouse.modifiers & Qt.ShiftModifier) !== 0)
                                    }
                                }
                            }
                        }
                        }
                        LiquidScrollBar { flick: resFlick; compact: true; alwaysVisible: true; anchors.right: parent.right; anchors.rightMargin: 2; anchors.top: parent.top; anchors.topMargin: 6; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; dark: spotPal.dark }
                        }
                    }

                    Item {
                        id: clipPanel
                        opacity: ui.spMode === "clip" ? 1 : 0
                        visible: opacity > 0
                        scale: ui.spMode === "clip" ? 1 : 0.96
                        transformOrigin: Item.Top
                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        width: spot.width
                        readonly property var items: ui.spMode === "clip" ? ui.spResults : []
                        readonly property int rowH: 56
                        readonly property int shown: Math.min(items.length, 7)
                        readonly property string emptyTitle: root.clipState === "missing" ? I18n.tr("Clipboard history isn't set up")
                            : (!root.clipHistory ? I18n.tr("Clipboard history is off")
                            : (root.clipLoading && root.clipEntries.length === 0 ? I18n.tr("Loading\u2026")
                            : (ui.spQuery.trim() !== "" ? I18n.tr("No Results") : I18n.tr("Nothing copied yet"))))
                        readonly property string emptySub: root.clipState === "missing" ? I18n.tr("Install cliphist and wl-clipboard, then open this tab again")
                            : (!root.clipHistory ? I18n.tr("Turn it on in System Settings \u2192 Menu Bar")
                            : (ui.spQuery.trim() === "" && !root.clipLoading ? I18n.tr("Copy some text or an image and it will show up here") : ""))
                        height: 64 + (items.length > 0 ? shown * rowH + 14 : 118)
                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        GGlass { anchors.fill: parent; gx: spg; cornerR: 32; thickness: 34; strengthMul: 1.0; shadowAmt: 0.22 }
                        MenuBorder { amount: 0.5; anchors.fill: parent; cornerR: 32; dark: spotPal.dark; tint: root.menuBorderColor }

                        Item {
                            id: clipHeader
                            x: 20
                            width: parent.width - 40
                            height: 64
                            Rectangle {
                                id: clipChip
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34; height: 34; radius: 10
                                color: root.accent
                                Glyph { anchors.centerIn: parent; width: 20; height: 20; kind: "clipboard"; color: "white" }
                            }
                            Text {
                                id: clipLabel
                                x: 46
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Clipboard")
                                color: spotPal.fg
                                font.family: root.fontForWeight(Font.Medium, spotPal.fam); font.pixelSize: 24; font.weight: Font.Medium
                            }
                            TextInput {
                                id: clipInput
                                x: clipLabel.x + clipLabel.width + 14
                                width: parent.width - x - 48
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                color: spotPal.fg
                                selectionColor: root.accent
                                selectedTextColor: "white"
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 24
                                onTextChanged: { if (ui.spMode === "clip") { ui.spQuery = text; ui.spSel = 0; } }
                                Keys.onPressed: event => ui.spKey(event)
                            }
                            CCBtn {
                                t: pal; gx: spg
                                d: 34
                                bounce: true
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "dots"
                                on: ui.clipMenu
                                onClicked: ui.clipMenu = !ui.clipMenu
                            }
                        }

                        ListView {
                            id: clipListView
                            x: 8; y: 64
                            width: parent.width - 16
                            height: clipPanel.shown * clipPanel.rowH
                            visible: clipPanel.items.length > 0
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: clipPanel.items
                            Connections {
                                target: ui
                                function onSpSelChanged() {
                                    if (ui.spHover) { ui.spHover = false; return; }
                                    if (ui.spMode === "clip" && clipPanel.items.length > 0)
                                        clipListView.positionViewAtIndex(Math.min(ui.spSel, clipPanel.items.length - 1), ListView.Contain);
                                }
                            }
                            delegate: Item {
                                id: cr
                                required property var modelData
                                required property int index
                                readonly property bool sel: index === Math.min(ui.spSel, clipPanel.items.length - 1)
                                width: ListView.view.width
                                height: clipPanel.rowH
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 2; anchors.bottomMargin: 2
                                    radius: 16
                                    color: root.accent
                                    opacity: cr.sel ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 90 } }
                                }
                                Item {
                                    x: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 36; height: 36
                                    Rectangle {
                                        visible: cr.modelData.kind === "text" || cr.modelData.kind === "url"
                                        anchors.fill: parent
                                        radius: 10
                                        color: cr.sel ? Qt.rgba(1, 1, 1, 0.22) : (spotPal.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
                                        Glyph {
                                            anchors.centerIn: parent
                                            width: 20; height: 20
                                            kind: cr.modelData.kind === "url" ? "link" : "doc"
                                            color: cr.sel ? "white" : spotPal.fg2
                                        }
                                    }
                                    Rectangle {
                                        visible: cr.modelData.kind === "color"
                                        anchors.fill: parent
                                        radius: 10
                                        color: cr.modelData.kind === "color" ? cr.modelData.color : "transparent"
                                        border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.25)
                                    }
                                    Item {
                                        visible: cr.modelData.kind === "image"
                                        anchors.fill: parent
                                        Rectangle { anchors.fill: parent; radius: 10; color: spotPal.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06) }
                                        Image {
                                            anchors.fill: parent
                                            source: cr.modelData.kind === "image" ? cr.modelData.thumb : ""
                                            sourceSize: Qt.size(72, 72)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: thMask
                                                maskThresholdMin: 0.5
                                                maskSpreadAtMin: 1.0
                                            }
                                        }
                                        Item {
                                            id: thMask
                                            anchors.fill: parent
                                            visible: false
                                            layer.enabled: true
                                            Rectangle { anchors.fill: parent; radius: 10; color: "black" }
                                        }
                                    }
                                }
                                Text {
                                    x: 62; y: 9
                                    width: parent.width - 62 - 56
                                    elide: Text.ElideRight
                                    text: cr.modelData ? cr.modelData.title : ""
                                    color: cr.sel ? "white" : spotPal.fg
                                    font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 14
                                }
                                Text {
                                    x: 62; y: 31
                                    width: parent.width - 62 - 56
                                    elide: Text.ElideRight
                                    text: cr.modelData ? cr.modelData.sub : ""
                                    color: cr.sel ? Qt.rgba(1, 1, 1, 0.8) : spotPal.fg2
                                    font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 12
                                }
                                Glyph {
                                    visible: cr.sel
                                    anchors.right: parent.right
                                    anchors.rightMargin: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18; height: 18
                                    kind: "return"; color: "white"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    property point press: Qt.point(0, 0)
                                    property bool dragged: false
                                    onPressed: mouse => { press = mapToItem(spotRoot, mouse.x, mouse.y); dragged = false; }
                                    onPositionChanged: mouse => {
                                        if (!pressed) {
                                            if (ui.spPointerMoved(parent, mouse.x, mouse.y) && ui.spSel !== cr.index) { ui.spHover = true; ui.spSel = cr.index; }
                                            return;
                                        }
                                        var p = mapToItem(spotRoot, mouse.x, mouse.y);
                                        if (!dragged && Math.abs(p.x - press.x) + Math.abs(p.y - press.y) > 14) { dragged = true; clipGhost.start(cr.modelData); }
                                        if (dragged) { clipGhost.px = p.x; clipGhost.py = p.y; }
                                    }
                                    onReleased: mouse => {
                                        if (!dragged) return;
                                        var p = mapToItem(spotRoot, mouse.x, mouse.y);
                                        var out = p.x < spot.x || p.x > spot.x + spot.width || p.y < spot.y || p.y > spot.y + spot.height;
                                        clipGhost.drop(out);
                                    }
                                    onClicked: mouse => { if (!dragged) ui.spActivate(cr.index, (mouse.modifiers & Qt.ShiftModifier) !== 0); }
                                }
                            }
                        }

                        Column {
                            visible: clipPanel.items.length === 0
                            x: 20; y: 64
                            width: parent.width - 40
                            height: 118
                            spacing: 6
                            topPadding: 30
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: clipPanel.emptyTitle
                                color: spotPal.fg
                                font.family: root.fontForWeight(Font.Medium, spotPal.fam); font.pixelSize: 15; font.weight: Font.Medium
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: clipPanel.emptySub
                                color: spotPal.fg2
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 12
                            }
                        }

                        MouseArea { anchors.fill: parent; z: 4; visible: ui.clipMenu; onClicked: ui.clipMenu = false }
                        Item {
                            id: clipMenuPop
                            z: 5
                            visible: ui.clipMenu
                            x: parent.width - width - 20
                            y: 58
                            width: 250
                            height: 3 * 40 + 12
                            GGlass { anchors.fill: parent; gx: spg; cornerR: 20; thickness: 26; strengthMul: 1.0; shadowAmt: 0.26 }
                            MenuBorder { amount: 0.5; anchors.fill: parent; cornerR: 20; dark: spotPal.dark; tint: root.menuBorderColor }
                            Column {
                                x: 6; y: 6
                                width: parent.width - 12
                                Repeater {
                                    model: ["auto", "del", "clear"]
                                    delegate: Item {
                                        id: cm
                                        required property string modelData
                                        width: parent.width; height: 40
                                        readonly property bool armedNow: modelData === "clear" && ui.armed === "clipclear"
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 14
                                            color: cm.armedNow ? "#FF453A" : root.accent
                                            opacity: cmMa.containsMouse ? 1 : 0
                                        }
                                        Glyph {
                                            visible: cm.modelData === "auto" && root.clipAutoPaste
                                            x: 12; anchors.verticalCenter: parent.verticalCenter
                                            width: 16; height: 16
                                            kind: "check"; color: cmMa.containsMouse ? "white" : spotPal.fg
                                        }
                                        Text {
                                            x: 38
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: cm.modelData === "auto" ? I18n.tr("Paste Automatically")
                                                  : (cm.modelData === "del" ? I18n.tr("Delete Selected")
                                                  : (cm.armedNow ? I18n.tr("Click again to confirm") : I18n.tr("Clear History")))
                                            color: cmMa.containsMouse ? "white" : ((cm.modelData === "clear") ? "#FF453A" : spotPal.fg)
                                            font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 14
                                        }
                                        MouseArea {
                                            id: cmMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                if (cm.modelData === "auto") root.clipAutoPaste = !root.clipAutoPaste;
                                                else if (cm.modelData === "del") {
                                                    var n = clipPanel.items.length;
                                                    if (n > 0) root.clipDelete(clipPanel.items[Math.min(ui.spSel, n - 1)]);
                                                    ui.clipMenu = false;
                                                } else {
                                                    if (ui.armed === "clipclear") { ui.armed = ""; root.clipClear(); ui.clipMenu = false; }
                                                    else ui.armed = "clipclear";
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: emojiPanel
                        opacity: ui.spMode === "emoji" ? 1 : 0
                        visible: opacity > 0
                        scale: ui.spMode === "emoji" ? 1 : 0.96
                        transformOrigin: Item.Top
                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        width: spot.width
                        readonly property int cell: 50
                        readonly property int gridRows: 6
                        readonly property var items: ui.spMode === "emoji" ? ui.spResults : []
                        readonly property var cur: items[Math.min(ui.spSel, items.length - 1)]
                        height: 64 + 42 + gridRows * cell + 46
                        GGlass { anchors.fill: parent; gx: spg; cornerR: 32; thickness: 34; strengthMul: 1.0; shadowAmt: 0.22 }
                        MenuBorder { amount: 0.5; anchors.fill: parent; cornerR: 32; dark: spotPal.dark; tint: root.menuBorderColor }

                        Item {
                            x: 20
                            width: parent.width - 40
                            height: 64
                            Rectangle {
                                id: emojiChip
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34; height: 34; radius: 10
                                color: root.accent
                                Glyph { anchors.centerIn: parent; width: 20; height: 20; kind: "smile"; color: "white" }
                            }
                            Text {
                                id: emojiLabel
                                x: 46
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Emoji")
                                color: spotPal.fg
                                font.family: root.fontForWeight(Font.Medium, spotPal.fam); font.pixelSize: 24; font.weight: Font.Medium
                            }
                            TextInput {
                                id: emojiInput
                                x: emojiLabel.x + emojiLabel.width + 14
                                width: parent.width - x
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                color: spotPal.fg
                                selectionColor: root.accent
                                selectedTextColor: "white"
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 24
                                onTextChanged: { if (ui.spMode === "emoji") { ui.spQuery = text; ui.spSel = 0; } }
                                Keys.onPressed: event => ui.spKey(event)
                            }
                        }

                        Row {
                            x: 20; y: 64
                            opacity: ui.spQuery.trim() === "" ? 1 : 0.35
                            Repeater {
                                model: ["\uD83D\uDD58", "\uD83D\uDE00", "\uD83E\uDDD1", "\uD83D\uDC3B", "\uD83C\uDF54", "\u2708\uFE0F", "\u26BD", "\uD83D\uDCA1", "\uD83D\uDD23", "\uD83C\uDFF3\uFE0F"]
                                delegate: Item {
                                    id: tab
                                    required property string modelData
                                    required property int index
                                    width: 60; height: 36
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 48; height: 32; radius: 12
                                        color: root.accent
                                        opacity: (ui.emCat === tab.index && ui.spQuery.trim() === "") ? 0.9 : (tabMa.containsMouse ? 0.25 : 0)
                                        Behavior on opacity { NumberAnimation { duration: 100 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: tab.modelData
                                        font.family: root.emojiFont; font.pixelSize: 22
                                    }
                                    MouseArea {
                                        id: tabMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            emojiInput.text = "";
                                            ui.emCat = tab.index; ui.spSel = 0;
                                            emojiInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }

                        GridView {
                            id: emojiGrid
                            x: 20; y: 64 + 42
                            width: ui.emCols * emojiPanel.cell
                            height: emojiPanel.gridRows * emojiPanel.cell
                            cellWidth: emojiPanel.cell
                            cellHeight: emojiPanel.cell
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: emojiPanel.items
                            Connections {
                                target: ui
                                function onSpSelChanged() {
                                    if (ui.spHover) { ui.spHover = false; return; }
                                    if (ui.spMode === "emoji" && emojiPanel.items.length > 0)
                                        emojiGrid.positionViewAtIndex(Math.min(ui.spSel, emojiPanel.items.length - 1), GridView.Contain);
                                }
                            }
                            delegate: Item {
                                id: ec
                                required property var modelData
                                required property int index
                                readonly property bool sel: index === Math.min(ui.spSel, emojiPanel.items.length - 1)
                                width: emojiPanel.cell; height: emojiPanel.cell
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 4; height: parent.height - 4
                                    radius: 14
                                    color: root.accent
                                    opacity: ec.sel ? 1 : 0
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: ec.modelData ? ec.modelData[0] : ""
                                    font.family: root.emojiFont; font.pixelSize: 36
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onPositionChanged: mouse => { if (ui.spPointerMoved(parent, mouse.x, mouse.y) && ui.spSel !== ec.index) { ui.spHover = true; ui.spSel = ec.index; } }
                                    onClicked: { ui.pop = ""; root.emojiPick(ec.modelData); }
                                }
                            }
                        }
                        Text {
                            visible: emojiPanel.items.length === 0
                            x: 20; y: 64 + 42
                            width: parent.width - 40
                            height: emojiPanel.gridRows * emojiPanel.cell
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: ui.spQuery.trim() !== "" ? I18n.tr("No Results") : I18n.tr("No recently used emoji")
                            color: spotPal.fg2
                            font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 14
                        }

                        Item {
                            x: 20; y: parent.height - 46
                            width: parent.width - 40; height: 46
                            Rectangle { width: parent.width; height: 1; color: spotPal.sep }
                            Text {
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 180
                                elide: Text.ElideRight
                                text: emojiPanel.cur ? (emojiPanel.cur[0] + "  " + emojiPanel.cur[1]) : ""
                                color: spotPal.fg2
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 13
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.clipAutoPaste ? I18n.tr("Return to insert") : I18n.tr("Return to copy")
                                color: spotPal.fg3
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 12
                            }
                        }
                    }

                    Item {
                        id: appsPanel
                        opacity: ui.spMode === "apps" ? 1 : 0
                        visible: opacity > 0
                        scale: ui.spMode === "apps" ? 1 : 0.96
                        transformOrigin: Item.Top
                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        width: spot.width
                        height: Math.min(64 + appsCol.height + 14, 520)
                        GGlass { anchors.fill: parent; gx: spg; cornerR: 32; thickness: 34; strengthMul: 1.0; shadowAmt: 0.22 }
                        MenuBorder { amount: 0.5; anchors.fill: parent; cornerR: 32; dark: spotPal.dark; tint: root.menuBorderColor }

                        Item {
                            id: appsHeader
                            x: 24
                            width: parent.width - 48
                            height: 64
                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24; height: 24
                                kind: "appstore"; color: spotPal.fg2
                            }
                            Text {
                                x: 40 + 3
                                anchors.verticalCenter: parent.verticalCenter
                                visible: appsInput.text === ""
                                text: I18n.tr("Applications")
                                color: spotPal.fg3
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 24
                            }
                            TextInput {
                                id: appsInput
                                x: 40
                                width: parent.width - 40 - 48
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                color: spotPal.fg
                                selectionColor: root.accent
                                selectedTextColor: "white"
                                font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 24
                                onTextChanged: { if (ui.spMode === "apps") { ui.spQuery = text; ui.spSel = 0; } }
                                Keys.onPressed: event => ui.spKey(event)
                            }
                            CCBtn {
                                t: pal; gx: spg
                                d: 34
                                bounce: true
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                kind: "dots"
                                onClicked: ui.spSetMode("home")
                            }
                        }

                        Flickable {
                            id: appsFlick
                            y: 64
                            width: parent.width
                            height: parent.height - 64 - 6
                            contentWidth: width
                            contentHeight: appsCol.height + 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: appsCol
                                x: 24
                                width: appsFlick.width - 48

                                Repeater {
                                    id: appsRep
                                    model: ui.spQuery.trim() === "" ? root.appSections : root.appSearchSection(ui.spQuery)
                                    delegate: Column {
                                        id: sec
                                        required property var modelData
                                        readonly property bool searching: ui.spQuery.trim() !== ""
                                        readonly property bool expanded: searching || ui.spExpanded[modelData.name] === true
                                        readonly property int shown: expanded ? modelData.apps.length : Math.min(5, modelData.apps.length)
                                        width: appsCol.width

                                        Rectangle { width: parent.width; height: 1; color: spotPal.sep }
                                        Item {
                                            width: parent.width
                                            height: 38
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: I18n.tr(sec.modelData.name)
                                                color: spotPal.fg
                                                font.family: root.fontForWeight(Font.Bold, spotPal.fam); font.pixelSize: 13; font.weight: Font.Bold
                                            }
                                            Text {
                                                visible: !sec.searching && sec.modelData.apps.length > 5
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: sec.expanded ? I18n.tr("Show Less") : I18n.tr("Show More")
                                                color: root.accent
                                                font.family: root.fontForWeight(Font.Bold, spotPal.fam); font.pixelSize: 12; font.weight: Font.Bold
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -6
                                                    onClicked: ui.spToggleSection(sec.modelData.name)
                                                }
                                            }
                                        }
                                        Grid {
                                            columns: 5
                                            Repeater {
                                                model: sec.shown
                                                delegate: Item {
                                                    id: cell
                                                    required property int index
                                                    readonly property var e: sec.modelData.apps[index]
                                                    width: appsCol.width / 5
                                                    height: 96
                                                                                                                                                            Rectangle {
                                                        anchors.fill: parent
                                                        anchors.margins: 2
                                                        radius: 16
                                                        color: cma.containsMouse ? spotPal.hover : "transparent"
                                                    }
                                                    Image {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        y: 10
                                                        width: 56; height: 56
                                                        source: root.iconSrc(cell.e.icon)
                                                        sourceSize: Qt.size(128, 128)
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: true
                                                        smooth: true
                                                    }
                                                    Text {
                                                        y: 72
                                                        width: parent.width - 8
                                                        x: 4
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                        text: cell.e.name
                                                        color: spotPal.fg
                                                        font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 12
                                                    }
                                                    MouseArea {
                                                        id: cma
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: mouse => { ui.pop = ""; root.launchApp(cell.e, (mouse.modifiers & Qt.ShiftModifier) !== 0); }
                                                    }
                                                }
                                            }
                                        }
                                        Item { width: 1; height: 10 }
                                    }
                                }
                                Text {
                                    visible: ui.spQuery.trim() !== "" && appsRep.count === 0
                                    width: parent.width
                                    height: 90
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: I18n.tr("No Results")
                                    color: spotPal.fg2
                                    font.family: root.fontForWeight(Font.Normal, spotPal.fam); font.pixelSize: 14
                                }
                            }
                        }
                    }
                }

            }
        }
        }
    }
}
