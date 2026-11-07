import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "I18n.js" as I18n
import "Version.js" as Version
import "Launch.js" as Launch
import "Fonts.js" as Fonts

Scope {
    id: root

    property var hub: null
    property bool dockEnabled: true
    property bool settingsEnabled: true
    property var bar: hub ? hub.bar : null
    Connections {
        target: root.bar
    }
    property string userName: Quickshell.env("USER") || ""

    property var displays: ({ primary: "" })
    property var monList: []
    FileView {
        id: dispFile
        path: Quickshell.env("HOME") + "/.config/yukishell/displays.json"
        printErrors: false
        onLoaded: { try { root.displays = JSON.parse(text()); } catch (e) {} root.applySavedPrimary(); }
    }
    function saveDisplays() { dispFile.setText(JSON.stringify(root.displays, null, 2)); }
    function refreshMons() { if (!monListProc.running) monListProc.running = true; }
    Process {
        id: monListProc
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector { onStreamFinished: { try { root.monList = JSON.parse(text); } catch (e) {} } }
    }
    function applySavedPrimary() {
        if (displays.primary) root.monitorPrimary = displays.primary;
        refreshMons();
    }
    property string monitorPrimary: ""
    property var modePending: null
    property int modeLeft: 0
    function evalMode(name, mode, pos, scale) {
        Quickshell.execDetached(["hyprctl", "eval", 'hl.monitor({ output = "' + name + '", mode = "' + mode + '", position = "' + pos + '", scale = ' + scale + ' })']);
        monRefreshT.restart();
    }
    Timer { id: monRefreshT; interval: 800; onTriggered: root.refreshMons() }
    function setMode(m, mode) {
        var prev = (modePending && modePending.name === m.name) ? modePending.prev : m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2);
        modePending = { name: m.name, mode: mode, prev: prev, pos: m.x + "x" + m.y, scale: m.scale };
        modeLeft = 15;
        modeT.restart();
        evalMode(m.name, mode, m.x + "x" + m.y, m.scale);
    }
    Timer { id: modeT; interval: 1000; repeat: true; onTriggered: { root.modeLeft--; if (root.modeLeft <= 0) root.revertMode(); } }
    function revertMode() {
        modeT.stop();
        var p = modePending; modePending = null;
        if (p) evalMode(p.name, p.prev, p.pos, p.scale);
    }
    function keepMode() {
        modeT.stop();
        var p = modePending; modePending = null;
        if (!p) return;
        Quickshell.execDetached(["sh", "-c", 'f="${XDG_CONFIG_HOME:-$HOME/.config}/yukishell/monitor-modes.tsv"; mkdir -p "$(dirname "$f")"; '
            + '{ [ -f "$f" ] && grep -v "^$1$(printf "\\t")" "$f"; printf "%s\\t%s\\n" "$1" "$2"; } > "$f.tmp" && mv -f "$f.tmp" "$f"', "sh", p.name, p.mode]);
    }
    function setPrimary(name) {
        var d = displays;
        displays = { primary: name };
        saveDisplays();
        monitorPrimary = name;
        root.monitor = name;
    }
    Process {
        running: true
        command: ["sh", "-c", "n=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1); printf '%s' \"${n:-$USER}\""]
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") root.userName = text.trim() }
    }
    readonly property bool captureCut: hub ? hub.captureCut : false
    readonly property bool glassHold: hub ? hub.glassHold : false
    readonly property bool previewHold: hub ? hub.previewHold : false
    readonly property bool captureHold: hub ? hub.captureHold : false
    function setLook(k, v) { root[k] = v; if (bar) bar[k] = v; }
    property string monitor: ""
    property int iconSize: 48
    readonly property real labelK: Math.max(0.7, Math.min(2.2, iconSize / 52))
    property real magnification: 1.5
    property int spacing: 4
    property int hPad: 10
    property int topPad: 8
    property int bottomPad: 9
    property int cornerRadius: 32
    readonly property real uiS: bar ? bar.uiScale : 1
    property int margin: 8
    readonly property bool darkMode: true
    readonly property bool dockDark: true
    property string dockStyle: "liquid"
    property real glassRim: 0.45
    property real glassGrain: 0.03
    property real glassLiquid: 1.5
    property bool glassLive: true
    readonly property bool glassRT: glassLive
    property real glassBlur: 5
    readonly property real dockBlurBoost: 0
    property bool glassDebug: false
    property string wallpaperPath: ""
    property real glassOpacity: 0.42
    property string hideMode: "windows"
    property int faceVer: 0
    property bool showSettings: true
    property string fontFamily: "Open Runde"
    readonly property string boldFontFamily: hub && hub.boldFontFamily ? hub.boldFontFamily : "Open Runde Semibold"
    function fontForWeight(weight, regularFamily) { return (Number(weight) >= Font.DemiBold && regularFamily === "Open Runde") ? boldFontFamily : regularFamily; }
    onFontFamilyChanged: if (fontFamily.indexOf("Inter") === 0) fontFamily = "Open Runde"
    property bool magnificationEnabled: true
    property bool showLabels: true
    property bool showIndicators: true
    property bool bounceOnLaunch: true
    property bool showThumbs: true
    property int pickerThumb: 220
    property bool windowCapture: true
    property int hideDelay: 500
    readonly property var accentChoices: [
        { name: "Blue",     c: "#0a84ff" }, { name: "Purple", c: "#bf5af2" },
        { name: "Pink",     c: "#ff375f" }, { name: "Red",    c: "#ff453a" },
        { name: "Orange",   c: "#ff9f0a" }, { name: "Yellow", c: "#ffd60a" },
        { name: "Green",    c: "#30d158" }, { name: "Graphite", c: "#8e8e93" }
    ]
    property color accent: "#eeacbe"
    readonly property bool prefsOpen: prefsWindow.visible
    property bool accentUi: false
    readonly property vector4d accentTintVec: Qt.vector4d(accent.r, accent.g, accent.b, accentUi ? 1 : 0)
    function accentWash(c, k, dark) {
        if (!accentUi) return c;
        var a = accent, t = dark ? Qt.rgba(a.r * 0.40, a.g * 0.40, a.b * 0.40, 1) : Qt.rgba(a.r + (1 - a.r) * 0.70, a.g + (1 - a.g) * 0.70, a.b + (1 - a.b) * 0.70, 1);
        return Qt.rgba(c.r + (t.r - c.r) * k, c.g + (t.g - c.g) * k, c.b + (t.b - c.b) * k, c.a);
    }
    property bool iconTint: false
    property string iconTintColor: "#eeacbe"
    property real iconTintStrength: 1.0
    readonly property var tintChoices: [
        { name: "Blue",     c: "#0a84ff" }, { name: "Purple", c: "#bf5af2" }, { name: "Pink",  c: "#ff375f" },
        { name: "Red",      c: "#ff453a" }, { name: "Orange", c: "#ff9f0a" }, { name: "Yellow", c: "#ffd60a" },
        { name: "Green",    c: "#30d158" }, { name: "Teal",   c: "#40c8e0" }, { name: "Graphite", c: "#8e8e93" },
        { name: "White",    c: "#ffffff" }, { name: "Black",  c: "#1c1c1e" }
    ]
    readonly property var defaultPinned: [
        "org.gnome.Nautilus", "thunar", "firefox", "zen", "google-chrome",
        "com.mitchellh.ghostty", "foot", "code", "spotify", "obsidian",
        "com.spotify.Client", "com.microsoft.VSCode", "org.polymc.PolyMC", "com.obsproject.Studio"
    ]
    property var pinned: defaultPinned

    component SCard: Rectangle {
        id: card
        required property var t
        default property alias content: col.data
        width: parent ? parent.width : 0
        height: col.implicitHeight
        radius: 12
        color: t.card
        border.width: 1
        border.color: t.cardBorder
        Column { id: col; width: parent.width }
    }

    component SRow: Item {
        id: r
        required property var t
        property string title: ""
        property string subtitle: ""
        property url iconSource: ""
        property bool wrapTitle: false
        default property alias control: slot.data
        width: parent ? parent.width : 0
        readonly property bool stacked: slot.width > 0 && (r.width - (r.iconSource != "" ? 56 : 16) - slot.width - 32) < 160
        height: Math.ceil(stacked ? textCol.height + slot.height + 40 : Math.max(48, textCol.height + 24, slot.height + 24))

        Rectangle {
            visible: r.y > 0.5
            x: 16
            width: parent.width - 32
            height: 1
            color: r.t.sep
        }
        Image {
            id: ic
            visible: r.iconSource != ""
            source: r.iconSource
            x: 16
            y: Math.round((r.height - height) / 2)
            width: 28; height: 28
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        Column {
            id: textCol
            x: ic.visible ? 56 : 16
            y: r.stacked ? 16 : Math.round((r.height - height) / 2)
            width: r.stacked ? Math.max(0, r.width - x - 16) : Math.max(0, r.width - x - slot.width - 32)
            spacing: 2
            Text {
                width: parent.width
                text: r.title
                elide: r.wrapTitle ? Text.ElideNone : Text.ElideRight
                wrapMode: r.wrapTitle ? Text.WordWrap : Text.NoWrap
                color: r.t.text
                font.family: root.fontForWeight(r.t.fw.title, r.t.fam)
                font.pixelSize: r.t.fs.title
            }
            Text {
                visible: r.subtitle !== ""
                width: parent.width
                text: r.subtitle
                wrapMode: Text.WordWrap
                color: r.t.text2
                font.family: root.fontForWeight(r.t.fw.desc, r.t.fam)
                font.pixelSize: r.t.fs.desc
            }
        }
        Item {
            id: slot
            x: Math.round(r.width - 16 - width)
            y: r.stacked ? textCol.y + textCol.height + 8 : Math.round((r.height - height) / 2)
            width: Math.ceil(childrenRect.width)
            height: Math.ceil(childrenRect.height)
            scale: width > 0 ? Math.min(1, (r.width - 32) / width) : 1
            transformOrigin: Item.TopRight
        }
    }

    component KCap: Rectangle {
        required property var t
        property string label: ""
        property bool hot: false
        height: 24; width: Math.max(24, Math.ceil(kcText.implicitWidth) + 12); radius: 6
        color: t.dark ? Qt.rgba(1, 1, 1, hot ? 0.16 : 0.10) : Qt.rgba(0, 0, 0, hot ? 0.10 : 0.06)
        border.width: 1; border.color: t.cardBorder
        Text {
            id: kcText
            anchors.centerIn: parent
            text: parent.label
            color: parent.t.text
            font.family: root.fontForWeight(Font.Medium, parent.t.fam)
            font.pixelSize: parent.t.fs.control
        }
    }

    component SLabel: Text {
        required property var t
        property bool header: false
        width: parent ? parent.width : 0
        leftPadding: 16
        rightPadding: 16
        topPadding: header ? 12 : -4
        height: implicitHeight - 4
        wrapMode: Text.WordWrap
        color: header ? t.text : t.text2
        font.family: root.fontForWeight(header ? t.fw.heading : t.fw.desc, t.fam)
        font.pixelSize: header ? t.fs.heading : t.fs.desc
        font.weight: header ? t.fw.heading : t.fw.desc
    }

    component SSwitch: GlassSwitch {
        required property var t
        accentColor: t.accent
        offColor: t.switchOff
        knobColor: t.dark ? "#DCDDDA" : "white"
        dark: t.dark
        baseColor: t.dark ? "#2B2B2D" : "#FFFFFF"
        glass: root.settingsGlass
        shaderUrl: root.glassShaderUrl
        glassLiquid: root.glassLiquid
        glassRim: root.glassRim
        glassGrain: root.glassGrain
        glassTint: root.glassOpacity
        borderTint: root.bar ? root.bar.menuBorderColor : "#8A9AB5"
        onGlassFailed: root.glassState = "failed"
    }

    component SSlider: GlassSlider {
        required property var t
        fg: t.text
        fillColor: t.accent
        knobColor: "white"
        knobSize: 8 / 7
        pressGrow: 0.8
        trackColor: t.track
        labelColor: t.text2
        fontFamily: t.fam
        labelSize: t.fs.caption
        dark: t.dark
        baseColor: t.dark ? "#2B2B2D" : "#FFFFFF"
        glass: root.settingsGlass
        shaderUrl: root.glassShaderUrl
        glassLiquid: root.glassLiquid
        glassRim: root.glassRim
        glassGrain: root.glassGrain
        glassTint: root.glassOpacity
        borderTint: root.bar ? root.bar.menuBorderColor : "#8A9AB5"
        onGlassFailed: root.glassState = "failed"
        showValue: true
        bubbleColor: t.dark ? "#4A4A4E" : "#FFFFFF"
        bubbleText: t.text

        property var resetValue: undefined
        readonly property bool canReset: resetValue !== undefined && Math.abs(value - Number(resetValue)) > Math.max(1e-6, Math.abs(to - from) * 0.004)
        Rectangle {
            id: resetBtn
            visible: opacity > 0
            opacity: parent.canReset ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            x: -24; y: parent.cy - 10
            width: 20; height: 20; radius: 10
            color: resetMa.containsMouse ? parent.t.ctrl : "transparent"
            WGlyph { anchors.centerIn: parent; width: 16; height: 16; kind: "reset"; color: resetMa.containsMouse ? parent.parent.t.text : parent.parent.t.text2 }
            MouseArea {
                id: resetMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: parent.parent.canReset
                cursorShape: Qt.PointingHandCursor
                onClicked: parent.parent.moved(Number(parent.parent.resetValue))
            }
        }
    }

    component SSegmented: GlassSegmented {
        required property var t
        segWidth: -1
        labelPad: 12
        dark: t.dark
        textColor: t.text
        fontFamily: t.fam
        fontSize: t.fs.control
        trackColor: t.ctrl
        pillColor: t.ctrlSel
        baseColor: t.dark ? "#2B2B2D" : "#FFFFFF"
        glass: root.settingsGlass
        shaderUrl: root.glassShaderUrl
        glassLiquid: root.glassLiquid
        glassRim: root.glassRim
        glassGrain: root.glassGrain
        glassTint: root.glassOpacity
        borderTint: root.bar ? root.bar.menuBorderColor : "#8A9AB5"
        onGlassFailed: root.glassState = "failed"
    }

    component SButton: Rectangle {
        id: b
        required property var t
        property string text: ""
        property bool destructive: false
        property bool prominent: false
        property string glyph: ""
        property string tip: ""
        signal clicked()
        width: (b.glyph !== "" || b.text.length <= 1) ? 28 : Math.max(64, Math.ceil(lbl.implicitWidth) + 24)
        height: 28
        radius: 8
        opacity: enabled ? 1 : 0.4
        color: prominent ? (ma.pressed ? Qt.darker(t.accent, 1.2) : (ma.containsMouse ? Qt.lighter(t.accent, 1.08) : t.accent))
                         : (ma.pressed ? t.buttonPressed : (ma.containsMouse ? Qt.tint(t.button, t.hover) : t.button))
        border.width: prominent ? 0 : 1
        border.color: t.buttonBorder
        Text {
            id: lbl
            visible: b.glyph === ""
            anchors.centerIn: parent
            text: b.text
            color: b.prominent ? "white" : (b.destructive ? b.t.danger : b.t.text)
            font.family: root.fontForWeight(b.prominent ? Font.DemiBold : b.t.fw.control, b.t.fam)
            font.weight: b.prominent ? Font.DemiBold : b.t.fw.control
            font.pixelSize: b.t.fs.control
        }
        WGlyph {
            visible: b.glyph !== ""
            anchors.centerIn: parent
            width: 16; height: 16
            kind: b.glyph
            color: b.destructive ? b.t.danger : (ma.containsMouse ? b.t.text : b.t.text2)
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
        ToolTip.visible: b.tip !== "" && ma.containsMouse
        ToolTip.delay: 600
        ToolTip.text: b.tip
    }

    component SGlyph: Rectangle {
        id: gl
        property string kind: ""
        property string fam: "Open Runde"
        property string wg: ""
        property color c1: "#4FA8FF"
        property color c2: "#0A6CFF"
        width: 24; height: 24; radius: 6
        gradient: Gradient {
            GradientStop { position: 0.0; color: gl.c1 }
            GradientStop { position: 1.0; color: gl.c2 }
        }
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.14)

        WGlyph { visible: gl.wg !== ""; anchors.centerIn: parent; width: 16; height: 16; kind: gl.wg; color: "white" }
        Item {
            anchors.centerIn: parent
            width: 16; height: 16
            visible: gl.wg === ""

            Item {
                visible: gl.kind === "dock"; anchors.fill: parent
                Rectangle { x: 1; y: 11; width: 14; height: 4; radius: 2; color: "white" }
                Rectangle { x: 2;    y: 4.5; width: 3.4; height: 3.4; radius: 1; color: "white" }
                Rectangle { x: 6.3;  y: 4.5; width: 3.4; height: 3.4; radius: 1; color: "white" }
                Rectangle { x: 10.6; y: 4.5; width: 3.4; height: 3.4; radius: 1; color: "white" }
            }
            Item {
                visible: gl.kind === "appearance"; anchors.fill: parent
                Rectangle {
                    x: 1.5; y: 1.5; width: 13; height: 13; radius: 6.5
                    color: "transparent"; border.width: 2; border.color: "white"
                }
                Item {
                    x: 8; y: 1.5; width: 6.5; height: 13; clip: true
                    Rectangle { x: -6.5; width: 13; height: 13; radius: 6.5; color: "white" }
                }
            }
            Item {
                visible: gl.kind === "behavior"; anchors.fill: parent
                Rectangle { x: 1; y: 2; width: 14; height: 5.5; radius: 2.75; color: "white" }
                Rectangle { x: 10.2; y: 3.2; width: 3.1; height: 3.1; radius: 1.55; color: gl.c2 }
                Rectangle {
                    x: 1; y: 9.5; width: 14; height: 5.5; radius: 2.75
                    color: "transparent"; border.width: 1; border.color: "white"
                }
                Rectangle { x: 2.7; y: 10.7; width: 3.1; height: 3.1; radius: 1.55; color: "white" }
            }
            Item {
                visible: gl.kind === "widgets"; anchors.fill: parent
                Rectangle { x: 1.5; y: 1.5; width: 5.6; height: 5.6; radius: 1.6; color: "white" }
                Rectangle { x: 8.9; y: 1.5; width: 5.6; height: 5.6; radius: 1.6; color: "white" }
                Rectangle { x: 1.5; y: 8.9; width: 5.6; height: 5.6; radius: 1.6; color: "white" }
                Rectangle { x: 8.9; y: 8.9; width: 5.6; height: 5.6; radius: 1.6; color: "transparent"; border.width: 1.2; border.color: "white" }
            }
            Item {
                visible: gl.kind === "apps"; anchors.fill: parent
                Rectangle { x: 1.5; y: 1.5; width: 5.6; height: 5.6; radius: 1.6; color: "white" }
                Rectangle { x: 8.9; y: 1.5; width: 5.6; height: 5.6; radius: 1.6; color: "white" }
                Rectangle { x: 1.5; y: 8.9; width: 5.6; height: 5.6; radius: 1.6; color: "white" }
                Rectangle { x: 8.9; y: 8.9; width: 5.6; height: 5.6; radius: 1.6; color: "white" }
            }
            Item {
                visible: gl.kind === "menubar"; anchors.fill: parent
                Rectangle { x: 1; y: 2; width: 14; height: 4.5; radius: 1.5; color: "white" }
                Rectangle { x: 2.5; y: 3.4; width: 4; height: 1.6; radius: 0.8; color: gl.c2 }
                Rectangle {
                    x: 1; y: 8.5; width: 14; height: 6.5; radius: 2
                    color: "transparent"; border.width: 1; border.color: "white"
                }
            }
            Item {
                visible: gl.kind === "wallpaper"; anchors.fill: parent
                Rectangle {
                    x: 1; y: 2.5; width: 14; height: 11; radius: 2
                    color: "transparent"; border.width: 1.5; border.color: "white"
                }
                Rectangle { x: 9.5; y: 4.6; width: 2.8; height: 2.8; radius: 1.4; color: "white" }
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var c = getContext("2d"); c.reset(); c.fillStyle = "white";
                        c.beginPath(); c.moveTo(2.5, 12.5); c.lineTo(6.2, 7.6); c.lineTo(9.2, 11); c.lineTo(10.8, 9.4); c.lineTo(13.5, 12.5); c.closePath(); c.fill();
                    }
                }
            }
            Item {
                visible: gl.kind === "about"; anchors.fill: parent
                Rectangle {
                    x: 1; y: 1; width: 14; height: 14; radius: 7
                    color: "transparent"; border.width: 2; border.color: "white"
                }
                Text {
                    anchors.centerIn: parent
                    text: "i"
                    color: "white"
                    font.family: Fonts.forWeight(Font.Bold, gl.fam); font.pixelSize: 10
                    font.bold: true
                }
            }
        }
    }

    readonly property var filePicker: filePickerWin
    FilePicker {
        id: filePickerWin
        dark: root.darkMode
        fam: root.fontFamily
        accent: root.accent
        thumbSize: root.pickerThumb
        onThumbSizeEdited: size => root.pickerThumb = size
        extraPlaces: root.bar ? root.bar.wpDirsEff.map(function (d) { return { label: d.replace(Quickshell.env("HOME"), "~"), path: d }; }) : []
    }

    Window {
        id: prefsWindow
        title: "YukiShell Settings"
        width: 800
        height: 880
        minimumWidth: Math.max(640, sidebar.minW + 480)
        minimumHeight: 480
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint

        QtObject {
            id: prefsGlassGeo
            readonly property var g: {
                var cs = root.glassClients || [], ms = root.hub ? (root.hub.monData || []) : [];
                for (var i = 0; i < cs.length; i++) {
                    var c = cs[i];
                    if (c.title !== prefsWindow.title || !c.mapped) continue;
                    for (var j = 0; j < ms.length; j++) {
                        var mm = ms[j];
                        if (mm.id !== c.monitor) continue;
                        var sc = mm.scale || 1;
                        return { x: c.at[0] - mm.x, y: c.at[1] - mm.y, mw: mm.width / sc, mh: mm.height / sc, mon: mm.name };
                    }
                }
                return null;
            }
            readonly property bool ok: g !== null
            readonly property real x: ok ? g.x / root.uiS : 0
            readonly property real y: ok ? g.y / root.uiS : 0
            readonly property real mw: ok ? g.mw / root.uiS : 1
            readonly property real mh: ok ? g.mh / root.uiS : 1
            readonly property string mon: ok ? g.mon : ""
        }

        property int cur: Math.max(0, paneIndex("general"))
        property var backStack: []
        property var fwdStack: []
        property string query: ""

        readonly property var panes: [
            { id: "wifi",       sec: 1, name: "Wi-Fi",           wg: "wifi",       c1: "#3D9BFF", c2: "#0A6CFF", keys: "wireless network internet ssid join" },
            { id: "bluetooth",  sec: 1, name: "Bluetooth",       wg: "bluetooth",  c1: "#3D9BFF", c2: "#0A6CFF", keys: "devices pair headphones mouse keyboard" },
            { id: "network",    sec: 1, name: "Network",         wg: "ethernet",   c1: "#3D9BFF", c2: "#0A6CFF", keys: "ethernet ip address vpn tailscale connection" },
            { id: "general",    sec: 2, name: "General",         glyph: "behavior", c1: "#8E8E93", c2: "#636366", keys: "language shell enable disable dock menu bar panel show hide off on" },
            { id: "appearance", sec: 2, name: "Appearance",      glyph: "appearance", c1: "#3A3A3C", c2: "#1C1C1E", keys: "theme accent color glass liquid apple style blur font spotlight top bar menus" },
            { id: "wallpaper",  sec: 2, name: "Wallpaper",       glyph: "wallpaper", c1: "#5AC8FA", c2: "#007AFF", keys: "wallpaper background picture image video animated live motion desktop dynamic" },
            { id: "displays",   sec: 2, name: "Displays",        wg: "sun",        c1: "#3D9BFF", c2: "#0A6CFF", keys: "brightness night shift monitor resolution refresh scale" },
            { id: "battery",    sec: 2, name: (root.bar && !root.bar.hasBattery) ? "Power" : "Battery",         wg: "bolt",       c1: "#4CD964", c2: "#28A745", keys: "power energy charge profile performance game mode gaming fullscreen" },
            { id: "dock",       sec: 3, name: "Desktop & Dock",  glyph: "dock",     c1: "#2C2C2E", c2: "#1C1C1E", keys: "window border thickness outline size icon magnification zoom spacing margin distance corner radius round square edge hide auto labels indicators bounce settings gear monitor preview app switcher alt tab" },
            { id: "menubar",    sec: 3, name: "Menu Bar",        glyph: "menubar",  c1: "#3D9BFF", c2: "#0A6CFF", keys: "panel bar height clock date seconds 24 hour battery tray search spotlight week monday style liquid bluetooth screenshots" },
            { id: "controlcenter", sec: 3, name: "Control Center", wg: "cc",       c1: "#8E8E93", c2: "#636366", keys: "modules tiles controls" },
            { id: "widgets",    sec: 3, name: "Widgets",         glyph: "widgets",  c1: "#FF9F0A", c2: "#FF7A00", keys: "desktop widgets weather clock calendar player image photo add remove arrange edit size temperature fahrenheit celsius city location" },
            { id: "notifications", sec: 4, name: "Notifications", wg: "bell",      c1: "#FF5E57", c2: "#E8342A", keys: "alerts banners popups do not disturb screenshot" },
            { id: "sound",      sec: 4, name: "Sound",           wg: "speaker",    c1: "#FF5E7E", c2: "#E8344F", keys: "volume output input microphone speakers headphones effects ui sounds" },
            { id: "focus",      sec: 4, name: "Focus",           wg: "moon",       c1: "#7D7AFF", c2: "#5856D6", keys: "do not disturb keep awake sleep" },
            { id: "lockscreen", sec: 5, name: "Lock Screen",     wg: "lock",       c1: "#3A3A3C", c2: "#1C1C1E", keys: "lock password album lyrics media clock" },
            { id: "users",      sec: 5, name: "Users & Groups",  wg: "smile",      c1: "#3D9BFF", c2: "#0A6CFF", keys: "account user name picture avatar" },
            { id: "keyboard",   sec: 6, name: "Keyboard",        wg: "keyboard",   c1: "#A7A7AD", c2: "#7C7C82", keys: "repeat rate delay layout typing" },
            { id: "mouse",      sec: 6, name: "Mouse",           wg: "mouse",      c1: "#A7A7AD", c2: "#7C7C82", keys: "tracking speed scroll natural acceleration" },
            { id: "cursor",     sec: 6, name: "Cursor",          wg: "cursor",     c1: "#A7A7AD", c2: "#7C7C82", keys: "pointer mouse theme size hide typing idle focus follows magnify zoom warp custom" },
            { id: "trackpad",   sec: 6, name: "Trackpad",        wg: "trackpad",   c1: "#A7A7AD", c2: "#7C7C82", keys: "tap click natural scroll touchpad gestures" },
            { id: "apps",       sec: 7, name: "Applications",    glyph: "apps",     c1: "#FFB340", c2: "#FF9500", keys: "pinned apps keep remove add custom dock" },
            { id: "about",      sec: 7, name: "About",           glyph: "about",    c1: "#A7A7AD", c2: "#7C7C82", keys: "version github profile source author credits config folder yukidock yukishell" }
        ]

        property var shortcuts: []
        property var kbBinds: []
        property var kbManifest: []
        property var kbOverrides: ({})
        property string kbCapturing: ""
        property string kbMessage: ""
        readonly property bool kbCanEdit: kbManifest.length > 0
        function loadShortcuts() { if (!bindsProc.running) bindsProc.running = true; }

        readonly property var kbKeyNames: ({ "return": "Return", "space": "Space", "left": "←", "right": "→", "up": "↑", "down": "↓", "period": ".", "comma": ",", "print": "Print", "tab": "Tab",
                                             "minus": "-", "equal": "=", "slash": "/", "backslash": "\\", "semicolon": ";", "apostrophe": "'", "grave": "`", "bracketleft": "[", "bracketright": "]",
                                             "prior": "Page Up", "next": "Page Down", "page_up": "Page Up", "page_down": "Page Down",
                                             "backspace": "⌫", "escape": "Esc", "delete": "Del", "insert": "Ins",
                                             "mouse_down": "Wheel", "mouse_up": "Wheel", "mouse:272": "Left Button", "mouse:273": "Right Button",
                                             "xf86audioraisevolume": "Vol +", "xf86audiolowervolume": "Vol −", "xf86audiomute": "Mute", "xf86audiomicmute": "Mic Mute",
                                             "xf86monbrightnessup": "Bright +", "xf86monbrightnessdown": "Bright −", "xf86kbdbrightnessup": "Kbd +", "xf86kbdbrightnessdown": "Kbd −",
                                             "xf86audioplay": "Play", "xf86audiopause": "Pause", "xf86audionext": "Next", "xf86audioprev": "Prev" })
        function kbCaps(spec) {
            var out = [], parts = String(spec).split("+");
            for (var i = 0; i < parts.length; i++) {
                var w = parts[i].trim(); if (w === "") continue;
                var u = w.toUpperCase();
                if (u === "SUPER") out.push("Super"); else if (u === "CTRL") out.push("Ctrl"); else if (u === "ALT") out.push("Alt"); else if (u === "SHIFT") out.push("Shift");
                else out.push(kbKeyNames[w.toLowerCase()] !== undefined ? kbKeyNames[w.toLowerCase()] : (w.length === 1 ? w.toUpperCase() : w));
            }
            return out;
        }
        function kbNorm(spec) {
            var parts = String(spec).split("+"), mods = [], key = "";
            for (var i = 0; i < parts.length; i++) {
                var w = parts[i].trim().toUpperCase(); if (w === "") continue;
                if (w === "SUPER" || w === "CTRL" || w === "ALT" || w === "SHIFT") mods.push(w); else key = parts[i].trim().toLowerCase();
            }
            mods.sort();
            return mods.join("+") + "|" + key;
        }
        function parseBinds(text) {
            var b; try { b = JSON.parse(text); } catch (e) { return []; }
            var mods = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]], out = [];
            for (var i = 0; i < b.length; i++) {
                var x = b[i];
                if ((x.submap || "") !== "" || x.catch_all) continue;
                var parts = [];
                for (var m = 0; m < mods.length; m++) if (x.modmask & mods[m][0]) parts.push(mods[m][1]);
                parts.push(x.key);
                var spec = parts.join(" + ");
                out.push({ desc: x.has_description ? x.description : "", spec: spec, norm: kbNorm(spec) });
            }
            return out;
        }
        function parseFiles(text) {
            var man = [], ov = {}, inOv = false, lines = String(text).split("\n");
            for (var i = 0; i < lines.length; i++) {
                var ln = lines[i].replace(/\r$/, "");
                if (ln === "@@OVERRIDES") { inOv = true; continue; }
                if (ln === "") continue;
                var f = ln.split("\t");
                if (inOv) { if (f.length >= 2) ov[f[0]] = f[1]; }
                else if (f.length >= 3) man.push({ desc: f[0], def: f[1], editable: f[2] === "1", sec: f.length >= 4 ? f[3] : "" });
            }
            kbOverrides = ov; kbManifest = man;
        }
        // the binds that share a description as one row: the modifiers of the first, then every key once,
        // with the usual sets shortened ("1 – 0", "← → ↑ ↓", "H K N")
        function kbGroup(specs) {
            var mods = [], fin = [], isMod = { Super: 1, Ctrl: 1, Alt: 1, Shift: 1 };
            for (var i = 0; i < specs.length; i++) {
                var caps = kbCaps(specs[i]), m = caps.filter(c => isMod[c]), k = caps.filter(c => !isMod[c]);
                if (i === 0) mods = m;
                for (var j = 0; j < k.length; j++) if (fin.indexOf(k[j]) < 0) fin.push(k[j]);
            }
            if (fin.length > 2 && fin.every(k => /^[0-9]$/.test(k))) fin = [fin[0] + " – " + fin[fin.length - 1]];
            var arrows = ["←", "→", "↑", "↓"];
            if (arrows.every(a => fin.indexOf(a) >= 0)) fin = [arrows.join(" ")].concat(fin.filter(k => arrows.indexOf(k) < 0));
            var letters = fin.filter(k => /^[A-Z]$/.test(k));
            if (letters.length > 1) fin = fin.filter(k => !/^[A-Z]$/.test(k)).concat([letters.join(" ")]);
            return { mods: mods, keys: fin };
        }
        property var shortcutGroups: []
        property var kbColW: [0, 0, 0]
        TextMetrics { id: kbTm; font.family: root.fontForWeight(Font.Medium, pal.fam); font.pixelSize: pal.fs.control }
        function kbCapW(s) { kbTm.text = s; return Math.max(24, Math.ceil(kbTm.advanceWidth) + 12); }
        function kbRunW(a) { var w = 0; for (var i = 0; i < a.length; i++) w += kbCapW(a[i]); return w + Math.max(0, a.length - 1) * 4; }
        function composeShortcuts() {
            var specs = {}, order = [], rows = [], seen = {};
            for (var i = 0; i < kbBinds.length; i++) {
                var b = kbBinds[i]; if (b.desc === "") continue;
                if (!specs[b.desc]) { specs[b.desc] = []; order.push(b.desc); }
                specs[b.desc].push(b.spec);
            }
            function row(desc, sec, def, editable) {
                var s = specs[desc] || [], g = s.length > 0 ? kbGroup(s) : { mods: [], keys: [] };
                rows.push({ desc: desc, sec: sec, mods: g.mods, keys: g.keys, def: def, editable: editable, changed: kbOverrides[desc] !== undefined });
            }
            for (var j = 0; j < kbManifest.length; j++) {
                var m = kbManifest[j]; if (seen[m.desc]) continue;
                seen[m.desc] = true; row(m.desc, m.sec, m.def, m.editable);
            }
            for (var d = 0; d < order.length; d++) if (!seen[order[d]]) row(order[d], "", (specs[order[d]] || [""])[0], false);
            var secs = [], byName = {}, w = [0, 0, 0];
            for (var r = 0; r < rows.length; r++) {
                var x = rows[r], name = x.sec !== "" ? x.sec : "Other";
                if (!byName[name]) { byName[name] = { name: name, rows: [] }; secs.push(byName[name]); }
                byName[name].rows.push(x);
                w[0] = Math.max(w[0], x.mods.length > 0 ? kbCapW(x.mods[0]) : 0);
                w[1] = Math.max(w[1], kbRunW(x.mods.slice(1)));
                w[2] = Math.max(w[2], kbRunW(x.keys));
            }
            ["System", "Other"].forEach(n => { if (byName[n]) { secs.splice(secs.indexOf(byName[n]), 1); secs.push(byName[n]); } });
            kbColW = w; shortcutGroups = secs; shortcuts = rows;
        }
        Process {
            id: bindsProc
            command: ["hyprctl", "-j", "binds"]
            stdout: StdioCollector { onStreamFinished: { prefsWindow.kbBinds = prefsWindow.parseBinds(text); kbFilesProc.running = true; } }
        }
        Process {
            id: kbFilesProc
            command: ["sh", "-c", "cat \"${XDG_CACHE_HOME:-$HOME/.cache}/yukishell/keybinds.tsv\" 2>/dev/null; printf '\\n@@OVERRIDES\\n'; cat \"${XDG_CONFIG_HOME:-$HOME/.config}/yukishell/keybinds.tsv\" 2>/dev/null; true"]
            stdout: StdioCollector { onStreamFinished: { prefsWindow.parseFiles(text); prefsWindow.composeShortcuts(); } }
        }

        function kbStart(desc) {
            if (!kbCanEdit) return;
            if (kbCapturing !== "") kbStop();
            kbCapturing = desc; kbMessage = "";
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap('yuki-capture')"]);
            kbCap.forceActiveFocus();
            kbTimer.restart();
        }
        function kbStop() {
            if (kbCapturing === "") return;
            kbCapturing = ""; kbMessage = "";
            kbTimer.stop();
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap('reset')"]);
        }
        Timer { id: kbTimer; interval: 20000; onTriggered: prefsWindow.kbStop() }
        onActiveChanged: if (!active) kbStop()

        readonly property var kbEvdev: ({ 1: "Escape", 2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6", 8: "7", 9: "8", 10: "9", 11: "0", 12: "minus", 13: "equal", 14: "BackSpace", 15: "Tab",
            16: "Q", 17: "W", 18: "E", 19: "R", 20: "T", 21: "Y", 22: "U", 23: "I", 24: "O", 25: "P", 26: "bracketleft", 27: "bracketright", 28: "Return",
            30: "A", 31: "S", 32: "D", 33: "F", 34: "G", 35: "H", 36: "J", 37: "K", 38: "L", 39: "semicolon", 40: "apostrophe", 41: "grave", 43: "backslash",
            44: "Z", 45: "X", 46: "C", 47: "V", 48: "B", 49: "N", 50: "M", 51: "comma", 52: "period", 53: "slash", 57: "space",
            59: "F1", 60: "F2", 61: "F3", 62: "F4", 63: "F5", 64: "F6", 65: "F7", 66: "F8", 67: "F9", 68: "F10", 87: "F11", 88: "F12",
            99: "Print", 102: "Home", 103: "up", 104: "Prior", 105: "left", 106: "right", 107: "End", 108: "down", 109: "Next", 110: "Insert", 111: "Delete" })
        function kbKeyName(ev) {
            var n = ev.nativeScanCode > 8 ? kbEvdev[ev.nativeScanCode - 8] : undefined;
            if (n !== undefined) return n;
            if (ev.key >= Qt.Key_A && ev.key <= Qt.Key_Z) return String.fromCharCode(ev.key);
            if (ev.key >= Qt.Key_0 && ev.key <= Qt.Key_9) return String.fromCharCode(ev.key);
            if (ev.key >= Qt.Key_F1 && ev.key <= Qt.Key_F12) return "F" + (ev.key - Qt.Key_F1 + 1);
            return "";
        }
        function kbKey(ev) {
            ev.accepted = true;
            if (kbCapturing === "" || ev.isAutoRepeat) return;
            var k = ev.key;
            if (k === Qt.Key_Control || k === Qt.Key_Shift || k === Qt.Key_Alt || k === Qt.Key_AltGr || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R
                || k === Qt.Key_CapsLock || k === Qt.Key_NumLock) return;
            var m = ev.modifiers, mods = [];
            if (m & Qt.MetaModifier) mods.push("SUPER");
            if (m & Qt.ControlModifier) mods.push("CTRL");
            if (m & Qt.AltModifier) mods.push("ALT");
            if (m & Qt.ShiftModifier) mods.push("SHIFT");
            if (mods.length === 0 && k === Qt.Key_Escape) { kbStop(); return; }
            if (mods.length === 0 && (k === Qt.Key_Backspace || k === Qt.Key_Delete)) { kbCommit(""); return; }
            var name = kbKeyName(ev);
            if (name === "") { kbMessage = I18n.tr("That key can't be used"); return; }
            var bare = !(m & (Qt.MetaModifier | Qt.ControlModifier | Qt.AltModifier));
            if (bare && !/^F([1-9]|1[0-2])$/.test(name) && name !== "Print") { kbMessage = I18n.tr("Add Super, Ctrl or Alt to that key"); return; }
            var spec = mods.concat([name]).join(" + "), norm = kbNorm(spec);
            for (var i = 0; i < kbBinds.length; i++) {
                if (kbBinds[i].norm !== norm || kbBinds[i].desc === kbCapturing) continue;
                kbMessage = kbBinds[i].desc !== "" ? I18n.tr("Already used by") + " “" + I18n.tr(kbBinds[i].desc) + "”" : I18n.tr("Already used by another shortcut");
                return;
            }
            kbCommit(spec);
        }
        function kbCommit(spec) {
            var desc = kbCapturing, def = "";
            kbStop();
            for (var i = 0; i < kbManifest.length; i++) if (kbManifest[i].desc === desc) def = kbManifest[i].def;
            var ov = {}; for (var k in kbOverrides) ov[k] = kbOverrides[k];
            if (spec !== "" && kbNorm(spec) === kbNorm(def)) delete ov[desc]; else ov[desc] = spec;
            kbWrite(ov);
        }
        function kbReset(desc) { var ov = {}; for (var k in kbOverrides) if (k !== desc) ov[k] = kbOverrides[k]; kbWrite(ov); }
        function kbWrite(ov) {
            var text = "";
            for (var k in ov) text += k + "\t" + ov[k] + "\n";
            kbOverrides = ov;
            composeShortcuts();
            kbSaveProc.command = ["sh", "-c", "f=\"${XDG_CONFIG_HOME:-$HOME/.config}/yukishell/keybinds.tsv\"; mkdir -p \"$(dirname \"$f\")\" && printf '%s' \"$1\" > \"$f\" && hyprctl reload >/dev/null 2>&1; sleep 0.3", "sh", text];
            kbSaveProc.running = true;
        }
        Process { id: kbSaveProc; onExited: prefsWindow.loadShortcuts() }
        Item {
            id: kbCap
            width: 0; height: 0
            Keys.onShortcutOverride: ev => { if (prefsWindow.kbCapturing !== "") ev.accepted = true; }
            Keys.onPressed: ev => prefsWindow.kbKey(ev)
        }

        property bool hasTouchpad: false
        Process {
            running: true
            command: ["sh", "-c", "hyprctl -j devices 2>/dev/null | grep -qi touchpad && echo yes || echo no"]
            stdout: StdioCollector { onStreamFinished: prefsWindow.hasTouchpad = text.trim() === "yes" }
        }

        function paneIndex(id) { for (var i = 0; i < panes.length; i++) if (panes[i].id === id) return i; return -1; }
        function available(i) {
            var p = panes[i];
            if (!p) return false;
            if (p.id === "trackpad" && !hasTouchpad) return false;
            if (p.id === "wifi" && root.bar && !root.bar.hasWifi) return false;
            if (p.id === "bluetooth" && root.bar && !root.bar.hasBt) return false;
            return true;
        }
        readonly property var filtered: {
            var q = query.trim().toLowerCase();
            var out = [];
            for (var i = 0; i < panes.length; i++) {
                if (panes[i].id === "trackpad" && !hasTouchpad) continue;
                if (panes[i].id === "wifi" && root.bar && !root.bar.hasWifi) continue;
                if (panes[i].id === "bluetooth" && root.bar && !root.bar.hasBt) continue;
                var hay = (panes[i].name + " " + panes[i].keys).toLowerCase();
                if (q === "" || hay.indexOf(q) >= 0) out.push(i);
            }
            return out;
        }

        function start(i) {
            backStack = [];
            fwdStack = [];
            cur = available(i) ? i : Math.max(0, paneIndex("general"));
        }
        function go(i) {
            if (i === cur || !available(i)) return;
            if (available(cur)) backStack = backStack.concat([cur]);
            fwdStack = [];
            cur = i;
        }
        function back() {
            var b = backStack.filter(available);
            if (b.length === 0) { backStack = []; return; }
            var p = b.pop();
            if (available(cur)) fwdStack = fwdStack.filter(available).concat([cur]);
            backStack = b;
            cur = p;
        }
        function forward() {
            var f = fwdStack.filter(available);
            if (f.length === 0) { fwdStack = []; return; }
            var p = f.pop();
            if (available(cur)) backStack = backStack.filter(available).concat([cur]);
            fwdStack = f;
            cur = p;
        }
        onCurChanged: flick.contentY = 0

        Shortcut { sequences: ["Escape", "Ctrl+W"]; onActivated: { if (appSheet.open) appSheet.open = false; else if (cropSheet.open) cropSheet.open = false; else prefsWindow.visible = false; } }

        onVisibleChanged: { if (!visible) kbStop(); if (visible) { showNormal(); applyScaledSize(); floatTries = 0; floatTimer.restart(); if (root.glassState === "idle") root.startGlass(); } }
        property int floatTries: 0
        readonly property int preferredWidth: Math.round(800 * root.uiS)
        readonly property int preferredHeight: Math.round(880 * root.uiS)
        property var rs: null
        function rsBegin(edges, p) { rs = { e: edges, x: p.x, y: p.y, w: width, h: height }; }
        function rsEnd(p) {
            if (!rs) return;
            var e = rs.e, dx = p.x - rs.x, dy = p.y - rs.y;
            rs = null;
            var minW = Math.round(560 * root.uiS), minH = Math.round(380 * root.uiS);
            var nw = width, nh = height;
            if (e & Qt.RightEdge)  nw = width + dx;
            if (e & Qt.LeftEdge)   nw = width - dx;
            if (e & Qt.BottomEdge) nh = height + dy;
            if (e & Qt.TopEdge)    nh = height - dy;
            nw = Math.max(minW, Math.round(nw)); nh = Math.max(minH, Math.round(nh));
            console.log('[yukishell-settings] resize on release:', width + 'x' + height, '->', nw + 'x' + nh);
            if (nw === width && nh === height) return;
            var sel = 'window = "title:^(' + title + ')$"';
            var ox = null, oy = null, cs = root.glassClients || [];
            for (var i = 0; i < cs.length; i++) if (cs[i].title === title && cs[i].mapped) { ox = cs[i].at[0]; oy = cs[i].at[1]; break; }
            Hyprland.dispatch('hl.dsp.window.resize({ x = ' + nw + ', y = ' + nh + ', "exact", ' + sel + ' })');
            if (ox !== null && ((e & Qt.LeftEdge) || (e & Qt.TopEdge))) {
                var nx = (e & Qt.LeftEdge) ? ox + (width - nw) : ox;
                var ny = (e & Qt.TopEdge) ? oy + (height - nh) : oy;
                Hyprland.dispatch('hl.dsp.window.move({ x = ' + nx + ', y = ' + ny + ', ' + sel + ' })');
            }
        }

        function applyScaledSize() {
            minimumWidth = Math.round(560 * root.uiS); minimumHeight = Math.round(380 * root.uiS);
            width = preferredWidth; height = preferredHeight;
        }
        Component.onCompleted: applyScaledSize()
        Connections {
            target: root
            function onUiSChanged() { prefsWindow.applyScaledSize(); if (prefsWindow.visible) { prefsWindow.floatTries = 0; floatTimer.restart(); } }
        }
        Timer {
            id: floatTimer
            interval: 60
            repeat: true
            onTriggered: {
                var sel = 'window = "title:^(' + prefsWindow.title + ')$"';
                Hyprland.dispatch('hl.dsp.window.set_prop({ prop = "rounding", value = "' + Math.round(frame.radius * root.uiS) + '", ' + sel + ' })');
                if (prefsWindow.floatTries >= 2) {
                    Hyprland.dispatch('hl.dsp.window.resize({ x = ' + prefsWindow.preferredWidth + ', y = ' + prefsWindow.preferredHeight + ', "exact", ' + sel + ' })');
                }
                if (++prefsWindow.floatTries >= 12) stop();
            }
        }

        QtObject {
            id: pal
            readonly property bool dark: root.darkMode
            readonly property string fam: root.fontFamily
            readonly property color accent: root.accent
            readonly property bool glass: root.liquidActive
            readonly property bool glassReady: root.settingsGlass
            readonly property url shaderUrl: root.glassShaderUrl
            readonly property real gLiquid: root.glassLiquid
            readonly property real gRim: root.glassRim
            readonly property real gGrain: root.glassGrain
            readonly property real gTint: root.glassOpacity
            readonly property real gBlur: root.glassBlur
            readonly property color content: root.accentWash(glass ? (dark ? Qt.rgba(0.09, 0.09, 0.10, 0.58) : Qt.rgba(0.97, 0.97, 0.98, 0.62))
                                                   : Qt.color(dark ? "#1E1E1E" : "#F5F5F7"), 0.30, dark)
            readonly property color sidebar: root.accentWash(dark ? Qt.color("#292929") : Qt.color("#E9E9EC"), 0.30, dark)
            readonly property color contentSolid: root.accentWash(dark ? Qt.color("#1E1E1E") : Qt.color("#F5F5F7"), 0.30, dark)
            readonly property color sidebarGlass: root.accentWash(dark ? Qt.rgba(0.17, 0.17, 0.18, 0.55) : Qt.rgba(0.94, 0.94, 0.96, 0.60), 0.35, dark)
            readonly property color card: root.accentWash(dark ? Qt.color("#2B2B2D") : Qt.color("#FFFFFF"), 0.30, dark)
            readonly property color cardBorder: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.12)
            readonly property color windowBorder: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.22)
            readonly property color edgeOuter: Qt.rgba(1, 1, 1, 0.50)
            readonly property color edgeInner: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.65)
            readonly property color sep: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.12)
            readonly property var fs: ({ display: 20, page: 17, heading: 15, title: 14, text: 13, control: 13, desc: 12, caption: 11 })
            readonly property var fw: ({ display: Font.DemiBold, page: Font.DemiBold, heading: Font.DemiBold, title: Font.Normal,
                                         text: Font.Normal, control: Font.Medium, desc: Font.Normal, caption: Font.Normal })
            readonly property color text: dark ? "#F5F5F7" : "#1D1D1F"
            readonly property color text2: dark ? Qt.rgba(1, 1, 1, 0.56) : Qt.rgba(0, 0, 0, 0.52)
            readonly property color text3: dark ? Qt.rgba(1, 1, 1, 0.32) : Qt.rgba(0, 0, 0, 0.30)
            readonly property color track: dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.13)
            readonly property color switchOff: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)
            readonly property color ctrl: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
            readonly property color ctrlSel: dark ? "#636366" : "#FFFFFF"
            readonly property color button: dark ? Qt.rgba(1, 1, 1, 0.13) : "#FFFFFF"
            readonly property color buttonPressed: dark ? Qt.rgba(1, 1, 1, 0.24) : "#E4E4E7"
            readonly property color buttonBorder: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.20)
            readonly property color field: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)
            readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)
            readonly property color selInactive: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)
            function lightBorder(active, c) { return active ? Qt.darker(c, dark ? 1.12 : 1.22) : "transparent"; }
            readonly property color lightOff: dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.15)
            readonly property color danger: "#FF453A"
        }

        NumberAnimation { id: fadeIn; target: paneLoader; property: "opacity"; from: 0; to: 1; duration: 160 }

        Rectangle {
            id: frame
            width: parent.width / root.uiS; height: parent.height / root.uiS
            scale: root.uiS; transformOrigin: Item.TopLeft
            radius: 12
            color: "transparent"
            border.width: 1
            border.color: pal.edgeOuter

            Rectangle {
                anchors.fill: parent; anchors.margins: 1
                radius: frame.radius - 1
                color: "transparent"
                border.width: 1; border.color: pal.edgeInner
                z: 900
            }

            Item {
                x: sidebar.x + sidebar.width; y: 1
                width: parent.width - x - 1; height: parent.height - 2
                layer.enabled: true
                opacity: pal.sidebarGlass.a
                Rectangle { anchors.fill: parent; radius: 11; color: Qt.rgba(pal.sidebarGlass.r, pal.sidebarGlass.g, pal.sidebarGlass.b, 1) }
                Rectangle { anchors.left: parent.left; width: 12; height: parent.height; color: Qt.rgba(pal.sidebarGlass.r, pal.sidebarGlass.g, pal.sidebarGlass.b, 1) }
            }

            MouseArea { x: 12; y: 0; width: parent.width - 24; height: 6; z: 1000; cursorShape: Qt.SizeVerCursor; onPressed: m => { prefsWindow.rsBegin(Qt.TopEdge, mapToItem(null, m.x, m.y)); }; preventStealing: true; onReleased: m => { prefsWindow.rsEnd(mapToItem(null, m.x, m.y)); }; }
            MouseArea { x: 12; y: parent.height - 6; width: parent.width - 24; height: 6; z: 1000; cursorShape: Qt.SizeVerCursor; onPressed: m => { prefsWindow.rsBegin(Qt.BottomEdge, mapToItem(null, m.x, m.y)); }; preventStealing: true; onReleased: m => { prefsWindow.rsEnd(mapToItem(null, m.x, m.y)); }; }
            MouseArea { x: 0; y: 12; width: 6; height: parent.height - 24; z: 1000; cursorShape: Qt.SizeHorCursor; onPressed: m => { prefsWindow.rsBegin(Qt.LeftEdge, mapToItem(null, m.x, m.y)); }; preventStealing: true; onReleased: m => { prefsWindow.rsEnd(mapToItem(null, m.x, m.y)); }; }
            MouseArea { x: parent.width - 6; y: 12; width: 6; height: parent.height - 24; z: 1000; cursorShape: Qt.SizeHorCursor; onPressed: m => { prefsWindow.rsBegin(Qt.RightEdge, mapToItem(null, m.x, m.y)); }; preventStealing: true; onReleased: m => { prefsWindow.rsEnd(mapToItem(null, m.x, m.y)); }; }
            MouseArea { x: 0; y: 0; width: 12; height: 12; z: 1001; cursorShape: Qt.SizeFDiagCursor; onPressed: m => { prefsWindow.rsBegin(Qt.TopEdge | Qt.LeftEdge, mapToItem(null, m.x, m.y)); }; preventStealing: true; onReleased: m => { prefsWindow.rsEnd(mapToItem(null, m.x, m.y)); }; }
            MouseArea { x: parent.width - 12; y: 0; width: 12; height: 12; z: 1001; cursorShape: Qt.SizeBDiagCursor; onPressed: m => { prefsWindow.rsBegin(Qt.TopEdge | Qt.RightEdge, mapToItem(null, m.x, m.y)); }; preventStealing: true; onReleased: m => { prefsWindow.rsEnd(mapToItem(null, m.x, m.y)); }; }
            MouseArea { x: 0; y: parent.height - 12; width: 12; height: 12; z: 1001; cursorShape: Qt.SizeBDiagCursor; onPressed: m => { prefsWindow.rsBegin(Qt.BottomEdge | Qt.LeftEdge, mapToItem(null, m.x, m.y)); }; preventStealing: true; onReleased: m => { prefsWindow.rsEnd(mapToItem(null, m.x, m.y)); }; }
            MouseArea { x: parent.width - 12; y: parent.height - 12; width: 12; height: 12; z: 1001; cursorShape: Qt.SizeFDiagCursor; onPressed: m => { prefsWindow.rsBegin(Qt.BottomEdge | Qt.RightEdge, mapToItem(null, m.x, m.y)); }; preventStealing: true; onReleased: m => { prefsWindow.rsEnd(mapToItem(null, m.x, m.y)); }; }

            Item {
                z: 3
                width: parent.width
                height: 56
                DragHandler {
                    target: null
                    onActiveChanged: if (active) prefsWindow.startSystemMove()
                }
            }

            Rectangle {
                id: sidebar
                z: 4
                readonly property bool floating: false
                x: sidebar.floating ? 8 : 1; y: sidebar.floating ? 8 : 1
                FontMetrics {
                    id: navFm
                    font.family: root.fontForWeight(Font.DemiBold, pal.fam)
                    font.weight: Font.DemiBold
                    font.pixelSize: pal.fs.title
                }
                readonly property real minW: {
                    var m = 0, ps = prefsWindow.panes;
                    for (var i = 0; i < ps.length; i++) m = Math.max(m, navFm.advanceWidth(I18n.tr(ps[i].name)));
                    return Math.ceil(m) + 72;
                }
                width: Math.round(Math.max(minW, Math.min(280, prefsWindow.width * 0.30))) - (sidebar.floating ? 16 : 0)
                height: parent.height - (sidebar.floating ? 16 : 2)
                radius: sidebar.floating ? 18 : 11
                color: sidebar.floating ? (pal.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.35)) : "transparent"
                border.width: sidebar.floating ? 1 : 0
                border.color: pal.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
                Item {
                    visible: !sidebar.floating
                    anchors.fill: parent
                    z: -1
                    layer.enabled: true
                    opacity: pal.sidebarGlass.a
                    Rectangle { anchors.fill: parent; radius: sidebar.radius; color: Qt.rgba(pal.sidebarGlass.r, pal.sidebarGlass.g, pal.sidebarGlass.b, 1) }
                    Rectangle { anchors.right: parent.right; width: 14; height: parent.height; color: Qt.rgba(pal.sidebarGlass.r, pal.sidebarGlass.g, pal.sidebarGlass.b, 1) }
                }
                Rectangle { visible: !sidebar.floating; anchors.right: parent.right; width: 1; height: parent.height; color: pal.sep }

                Item {
                    id: lights
                    x: 20; y: 22
                    width: 52; height: 12
                    Row {
                        scale: 12 / 14; transformOrigin: Item.TopLeft
                        spacing: 28 / 3
                        Repeater {
                            model: [
                                { c: "#FF5F57", g: "\u00D7", on: true },
                                { c: "#FEBC2E", g: "\u2212", on: false },
                                { c: "#28C840", g: "↗", on: true }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 14; height: 14; radius: 7
                                color: (modelData.on && (prefsWindow.active || lightsMa.containsMouse))
                                       ? modelData.c : pal.lightOff
                                border.width: 1
                                border.color: pal.lightBorder(modelData.on && (prefsWindow.active || lightsMa.containsMouse), modelData.c)
                                Canvas {
                                    anchors.fill: parent
                                    visible: lightsMa.containsMouse && parent.modelData.on
                                    onVisibleChanged: if (visible) requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        if (parent.modelData.g === "\u00D7") {
                                            ctx.strokeStyle = "rgba(0,0,0,0.58)";
                                            ctx.lineWidth = 1.1;
                                            ctx.lineCap = "round";
                                            ctx.beginPath();
                                            ctx.moveTo(4.9, 4.9); ctx.lineTo(9.1, 9.1);
                                            ctx.moveTo(9.1, 4.9); ctx.lineTo(4.9, 9.1);
                                            ctx.stroke();
                                        } else if (parent.modelData.g === "\u2212") {
                                            ctx.strokeStyle = "rgba(0,0,0,0.58)";
                                            ctx.lineWidth = 1.2;
                                            ctx.lineCap = "round";
                                            ctx.beginPath();
                                            ctx.moveTo(3.5, 7.0); ctx.lineTo(10.5, 7.0);
                                            ctx.stroke();
                                        } else if (parent.modelData.g === "↗") {
                                            ctx.fillStyle = "rgba(0,0,0,0.58)";
                                            ctx.beginPath();
                                            ctx.moveTo(6, 4); ctx.lineTo(10, 4); ctx.lineTo(10, 8);
                                            ctx.closePath();
                                            ctx.fill();
                                            ctx.beginPath();
                                            ctx.moveTo(8, 10); ctx.lineTo(4, 10); ctx.lineTo(4, 6);
                                            ctx.closePath();
                                            ctx.fill();
                                        }
                                    }
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: lightsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: mouse => {
                            if (mouse.x < 16) prefsWindow.visible = false;
                            else if (mouse.x < 36) { }
                            else if (mouse.x < 52) {
                                if (prefsWindow.visibility === Window.FullScreen) prefsWindow.showNormal();
                                else prefsWindow.showFullScreen();
                            }
                        }
                    }
                }

                Rectangle {
                    id: search
                    x: 12; y: 56
                    width: parent.width - 24
                    height: 32
                    radius: 8
                    color: pal.field

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: 10
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.5)
                        visible: searchInput.activeFocus
                    }
                    WGlyph {
                        x: 8; y: 8
                        width: 16; height: 16
                        kind: "search"
                        color: pal.text3
                    }
                    TextInput {
                        id: searchInput
                        x: 32
                        width: parent.width - 56
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        selectByMouse: true
                        color: pal.text
                        selectionColor: pal.accent
                        font.family: root.fontForWeight(Font.Normal, pal.fam)
                        font.pixelSize: pal.fs.text
                        onTextChanged: prefsWindow.query = text
                    }
                    Text {
                        x: 32
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: I18n.tr("Search")
                        color: pal.text3
                        font.family: root.fontForWeight(Font.Normal, pal.fam)
                        font.pixelSize: pal.fs.text
                    }
                    Rectangle {
                        visible: searchInput.text !== ""
                        x: parent.width - 24; y: 8
                        width: 16; height: 16; radius: 8
                        color: pal.text3
                        Text {
                            anchors.centerIn: parent
                            text: "\u00D7"
                            color: pal.sidebar
                            font.family: Fonts.forWeight(Font.Bold, pal.fam); font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: searchInput.text = "" }
                    }
                }

                Rectangle {
                    id: acct
                    x: 12; y: 100; width: parent.width - 24; height: 56; radius: 12
                    visible: prefsWindow.query === ""
                    readonly property int idx: { for (var i = 0; i < prefsWindow.panes.length; i++) if (prefsWindow.panes[i].id === "users") return i; return 0; }
                    color: prefsWindow.cur === idx ? "transparent" : (acctMa.containsMouse ? pal.hover : "transparent")
                    GlassHover {
                        anchors.fill: parent
                        radius: parent.radius
                        dark: pal.dark
                        open: prefsWindow.cur === acct.idx
                        opacity: prefsWindow.active ? 1 : 0.55
                    }
                    Item {
                        id: acctPic
                        x: 8; y: 8; width: 40; height: 40
                        Item { id: acctMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
                        Rectangle { anchors.fill: parent; radius: width / 2; color: pal.ctrl }
                        Image {
                            anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face?" + root.faceVer; sourceSize: Qt.size(96, 96)
                            fillMode: Image.PreserveAspectCrop; cache: false
                            layer.enabled: true; layer.effect: MultiEffect { maskEnabled: true; maskSource: acctMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                        }
                    }
                    Column {
                        x: 56; y: Math.round((parent.height - height) / 2)
                        Text { text: root.userName; color: pal.text; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.heading; font.weight: Font.DemiBold }
                        Text { text: I18n.tr("Local Account"); color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc }
                    }
                    MouseArea { id: acctMa; anchors.fill: parent; hoverEnabled: true; onClicked: prefsWindow.go(acct.idx) }
                }

                Item {
                    id: navFeather
                    visible: false; layer.enabled: true
                    width: navFlick.width; height: navFlick.height
                    readonly property real size: 26
                    readonly property real topFade: Math.max(0, Math.min(1, navFlick.contentY / 18))
                    readonly property real bottomFade: Math.max(0, Math.min(1, (navFlick.contentHeight - navFlick.height - navFlick.contentY) / 18))
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 1 - navFeather.topFade) }
                            GradientStop { position: Math.min(0.49, navFeather.size / Math.max(1, navFeather.height)); color: "black" }
                            GradientStop { position: Math.max(0.51, 1 - navFeather.size / Math.max(1, navFeather.height)); color: "black" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 1 - navFeather.bottomFade) }
                        }
                    }
                }
                Flickable {
                    id: navFlick
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: navFeather }
                    x: 12; y: acct.visible ? 164 : 100
                    width: parent.width - 24
                    height: parent.height - y - 12
                    contentHeight: navCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    function reveal() {
                        var pos = prefsWindow.filtered.indexOf(prefsWindow.cur), it = pos >= 0 ? navRep.itemAt(pos) : null;
                        if (!it || contentHeight <= height) return;
                        var top = it.y + (it.gap ? 16 : 0), bot = it.y + it.height;
                        if (top < contentY + 16) contentY = Math.max(0, top - 16);
                        else if (bot > contentY + height - 16) contentY = Math.min(contentHeight - height, bot - height + 16);
                    }
                    Connections {
                        target: prefsWindow
                        function onCurChanged() { Qt.callLater(navFlick.reveal); }
                    }
                GlassHover {
                    id: navMark
                    readonly property int pos: prefsWindow.filtered.indexOf(prefsWindow.cur)
                    readonly property Item row: { navRep.count; return pos >= 0 ? navRep.itemAt(pos) : null; }
                    z: 0
                    x: 0; width: navCol.width; height: 32; radius: 8
                    y: row ? row.y + (row.gap ? 16 : 0) : 0
                    visible: row !== null && amt > 0.005
                    dark: pal.dark
                    open: row !== null
                    opacity: prefsWindow.active ? 1 : 0.55
                    Behavior on y { enabled: navMark.shown; NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    property bool shown: false
                    Component.onCompleted: Qt.callLater(function () { navMark.shown = true; })
                }
                Column {
                    id: navCol
                    width: parent.width
                    spacing: 4

                    Repeater {
                        id: navRep
                        model: prefsWindow.filtered
                        delegate: Item {
                            id: navItem
                            required property int modelData
                            required property int index
                            readonly property bool gap: index > 0 && prefsWindow.panes[prefsWindow.filtered[index - 1]].sec !== prefsWindow.panes[modelData].sec
                            width: parent.width
                            height: 32 + (gap ? 16 : 0)
                        Rectangle {
                            id: navRow
                            readonly property int modelData: navItem.modelData
                            readonly property var p: prefsWindow.panes[modelData]
                            readonly property bool sel: prefsWindow.cur === modelData
                            y: navItem.gap ? 16 : 0
                            width: parent.width
                            height: 32
                            radius: 8
                            color: sel ? "transparent" : (navMa.containsMouse ? pal.hover : "transparent")

                            SGlyph {

                                fam: pal.fam
                                x: 4; y: 4
                                kind: navRow.p.glyph || ""
                                wg: navRow.p.wg || ""
                                c1: navRow.p.c1
                                c2: navRow.p.c2
                            }
                            Text {
                                x: 36
                                y: Math.round((parent.height - height) / 2)
                                text: I18n.tr(navRow.p.name)
                                color: pal.text
                                font.family: root.fontForWeight(navRow.sel ? Font.DemiBold : Font.Normal, pal.fam)
                                font.weight: navRow.sel ? Font.DemiBold : Font.Normal
                                font.pixelSize: pal.fs.title
                            }
                            MouseArea {
                                id: navMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: prefsWindow.go(navRow.modelData)
                            }
                        }
                        }
                    }

                    Text {
                        visible: prefsWindow.filtered.length === 0
                        width: parent.width
                        topPadding: 14
                        horizontalAlignment: Text.AlignHCenter
                        text: I18n.tr("No Results")
                        color: pal.text2
                        font.family: root.fontForWeight(Font.Normal, pal.fam)
                        font.pixelSize: pal.fs.desc
                    }
                }
                }
            }

            Item {
                id: header
                z: 6
                x: sidebar.x + sidebar.width + 1
                width: parent.width - sidebar.x - sidebar.width - 2
                height: 56
                GlassSlab {
                    id: navPill
                    x: 24; y: 12
                    width: 64; height: 32
                    cornerR: 16
                    glass: root.settingsGlass
                    shaderUrl: root.glassShaderUrl
                    dark: pal.dark
                    baseColor: pal.dark ? "#3C3C40" : "#FBFBFD"
                    thickness: 14; strengthMul: 0.6
                    liquid: root.glassLiquid
                    rim: root.glassRim
                    grain: root.glassGrain
                    tint: root.glassOpacity
                    shadowAmt: 0; flatInner: 1
                    onFailed: root.glassState = "failed"
                    CornerBorder {
                        z: 2; anchors.fill: parent
                        cornerR: 16; dark: pal.dark
                        tint: root.bar ? root.bar.menuBorderColor : "#8A9AB5"
                        amount: 1; lineW: 0.8
                    }
                }

                Row {
                    x: navPill.x + 4; y: navPill.y + 2
                    spacing: 0
                    Repeater {
                        model: [ { g: "\u2039", dir: -1 }, { g: "\u203A", dir: 1 } ]
                        delegate: Item {
                            id: navBtn
                            required property var modelData
                            readonly property bool ok: modelData.dir < 0 ? prefsWindow.backStack.length > 0
                                                                           : prefsWindow.fwdStack.length > 0
                            width: 28; height: 28
                            Rectangle {
                                anchors.fill: parent; radius: 14
                                color: (navBtn.ok && navBtnMa.containsMouse) ? (pal.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.5)) : "transparent"
                                Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }
                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -2
                                text: navBtn.modelData.g
                                font.family: Fonts.forWeight(Font.Normal, pal.fam); font.pixelSize: 28
                                color: navBtn.ok ? pal.text : pal.text3
                                opacity: navBtn.ok ? 1 : 0.5
                                scale: (navBtn.ok && navBtnMa.pressed) ? 0.86 : 1
                                Behavior on scale { NumberAnimation { duration: 230; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
                            }
                            MouseArea {
                                id: navBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: navBtn.ok
                                onClicked: {
                                    if (navBtn.modelData.dir < 0) prefsWindow.back();
                                    else prefsWindow.forward();
                                }
                            }
                        }
                    }
                }
                Text {
                    x: navPill.x + navPill.width + 16
                    y: Math.round((header.height - height) / 2)
                    text: I18n.tr(prefsWindow.panes[prefsWindow.cur].name)
                    color: pal.text
                    font.family: root.fontForWeight(Font.DemiBold, pal.fam)
                    font.pixelSize: pal.fs.page
                    font.weight: Font.DemiBold
                }
            }

            Item {
                id: flickFeather
                visible: false; layer.enabled: true
                width: flick.width; height: flick.height
                readonly property real fp: Math.min(0.32, 46 / Math.max(1, height))
                readonly property real amt: Math.max(0, Math.min(1, flick.contentY / 18))
                function a(base) { return 1 - amt * (1 - base); }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0;                    color: Qt.rgba(0, 0, 0, flickFeather.a(0.0)) }
                        GradientStop { position: flickFeather.fp * 0.25; color: Qt.rgba(0, 0, 0, flickFeather.a(0.04)) }
                        GradientStop { position: flickFeather.fp * 0.50; color: Qt.rgba(0, 0, 0, flickFeather.a(0.30)) }
                        GradientStop { position: flickFeather.fp * 0.75; color: Qt.rgba(0, 0, 0, flickFeather.a(0.72)) }
                        GradientStop { position: flickFeather.fp;        color: "black" }
                        GradientStop { position: 1.0;                    color: "black" }
                    }
                }
            }
            Flickable {
                id: flick
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: flickFeather }
                x: sidebar.x + sidebar.width + 1
                y: 1
                width: parent.width - sidebar.x - sidebar.width - 2
                height: parent.height - 2
                contentWidth: width
                contentHeight: paneLoader.height + 64 + 24
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Loader {
                    id: paneLoader
                    active: prefsWindow.visible
                    x: 24
                    y: 64
                    width: flick.width - 48
                    sourceComponent: ({
                        wifi: paneWifi, bluetooth: paneBt, network: paneNetwork, battery: paneBattery,
                        general: paneGeneral, appearance: paneAppearance, controlcenter: paneCC, dock: paneDesktopDock,
                        displays: paneDisplays, menubar: paneMenuBar, wallpaper: paneWallpaper,
                        notifications: paneNotif, sound: paneSound, focus: paneFocus,
                        widgets: paneWidgets, lockscreen: paneLock, users: paneUsers, keyboard: paneKeyboard, mouse: paneMouse, cursor: paneCursor, trackpad: paneTrackpad,
                        apps: paneApps, about: paneAbout
                    })[prefsWindow.panes[prefsWindow.cur].id]
                    onLoaded: fadeIn.restart()
                }
            }
            Rectangle {
                visible: flick.contentHeight > flick.height + 1
                x: frame.width - 8
                y: 56 + flick.visibleArea.yPosition * (flick.height - 56)
                width: 4
                height: Math.max(28, flick.visibleArea.heightRatio * (flick.height - 56))
                radius: 2
                color: pal.text3
                opacity: flick.moving ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }

            Item {
                id: appSheet
                anchors.fill: parent
                z: 61
                visible: opacity > 0.01
                opacity: open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                property bool open: false
                property string mode: "list"
                property string query: ""
                property var apps: []
                property string cName: ""
                property string cCmd: ""
                property string cIcon: ""
                property bool cTerm: false
                readonly property bool canAdd: cName.trim() !== "" && cCmd.trim() !== ""

                function begin(m) {
                    mode = m; query = ""; cName = ""; cCmd = ""; cIcon = ""; cTerm = false;
                    refresh(); open = true;
                    Qt.callLater(function () { if (m === "list") searchField.forceActiveFocus(); else nameField.forceActiveFocus(); });
                }
                function refresh() {
                    var out = [], vals = DesktopEntries.applications.values, q = query.trim().toLowerCase();
                    for (var i = 0; i < vals.length; i++) {
                        var e = vals[i];
                        if (!e || e.noDisplay) continue;
                        var nm = String(e.name || "");
                        if (q !== "" && nm.toLowerCase().indexOf(q) < 0 && String(e.genericName || "").toLowerCase().indexOf(q) < 0 && String(e.id).toLowerCase().indexOf(q) < 0) continue;
                        out.push({ id: String(e.id), name: nm, icon: String(e.icon || "") });
                    }
                    out.sort(function (a, b) { return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1; });
                    apps = out;
                }
                onQueryChanged: refresh()
                function addCustom() {
                    if (!canAdd) return;
                    root.addCustomApp(cName.trim(), cCmd.trim(), cIcon.trim(), cTerm);
                    open = false;
                }
                Connections { target: DesktopEntries.applications; function onValuesChanged() { if (appSheet.open) appSheet.refresh(); } }
                Connections { target: prefsWindow; function onVisibleChanged() { if (!prefsWindow.visible) appSheet.open = false; } }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.5)
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: w => w.accepted = true; onClicked: appSheet.open = false }
                }
                Rectangle {
                    id: appCard
                    anchors.centerIn: parent
                    width: Math.min(460, parent.width - 40)
                    height: Math.min(appSheet.mode === "list" ? 600 : 392, parent.height - 40)
                    radius: 16
                    color: pal.card
                    border.width: 1
                    border.color: pal.windowBorder
                    MouseArea { anchors.fill: parent }
                    Text {
                        y: 18; anchors.horizontalCenter: parent.horizontalCenter
                        text: appSheet.mode === "list" ? I18n.tr("Choose an App") : I18n.tr("Custom App")
                        color: pal.text
                        font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.page; font.weight: Font.DemiBold
                    }

                    Item {
                        visible: appSheet.mode === "list"
                        x: 16; y: 54; width: parent.width - 32; height: parent.height - 54 - 16
                        Rectangle {
                            id: searchBox
                            width: parent.width; height: 28; radius: 8
                            color: pal.field
                            border.width: 1; border.color: pal.cardBorder
                            TextInput {
                                id: searchField
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true; selectByMouse: true
                                color: pal.text; selectionColor: pal.accent
                                font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text
                                text: appSheet.query
                                onTextChanged: appSheet.query = text
                                Text {
                                    visible: searchField.text === ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.tr("Search")
                                    color: pal.text3; font: searchField.font
                                }
                            }
                        }
                        ListView {
                            id: appList
                            y: searchBox.height + 10
                            width: parent.width; height: parent.height - y - 44
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: appSheet.apps
                            delegate: Rectangle {
                                id: ar
                                required property var modelData
                                readonly property bool inDock: root.isPinned(modelData.id)
                                width: appList.width; height: 44; radius: 8
                                color: arMa.containsMouse && !inDock ? pal.hover : "transparent"
                                Image {
                                    x: 8; anchors.verticalCenter: parent.verticalCenter
                                    width: 28; height: 28
                                    source: root.iconSrc(ar.modelData.icon)
                                    sourceSize: Qt.size(56, 56)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true; mipmap: true
                                }
                                Text {
                                    x: 48; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 48 - 84
                                    elide: Text.ElideRight
                                    text: ar.modelData.name
                                    color: pal.text
                                    font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.title
                                }
                                Text {
                                    visible: ar.inDock
                                    anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                    text: "✓ " + I18n.tr("In Dock")
                                    color: pal.text2
                                    font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                                }
                                SButton {
                                    visible: !ar.inDock
                                    t: pal
                                    anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.tr("Add")
                                    onClicked: root.pinId(ar.modelData.id)
                                }
                                MouseArea { id: arMa; anchors.fill: parent; hoverEnabled: true; z: -1; onClicked: if (!ar.inDock) root.pinId(ar.modelData.id) }
                            }
                        }
                        SButton { t: pal; anchors.right: parent.right; anchors.bottom: parent.bottom; text: I18n.tr("Done"); onClicked: appSheet.open = false }
                    }

                    Column {
                        visible: appSheet.mode === "custom"
                        x: 20; y: 56; width: parent.width - 40
                        spacing: 12
                        Column {
                            width: parent.width; spacing: 5
                            Text { text: I18n.tr("Name"); color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc }
                            Rectangle {
                                width: parent.width; height: 28; radius: 8; color: pal.field
                                border.width: 1; border.color: pal.cardBorder
                                TextInput {
                                    id: nameField
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true; selectByMouse: true; maximumLength: 60
                                    color: pal.text; selectionColor: pal.accent
                                    font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text
                                    text: appSheet.cName
                                    onTextChanged: appSheet.cName = text
                                    KeyNavigation.tab: cmdField
                                    onAccepted: cmdField.forceActiveFocus()
                                }
                            }
                        }
                        Column {
                            width: parent.width; spacing: 5
                            Text { text: I18n.tr("Command"); color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc }
                            Rectangle {
                                width: parent.width; height: 28; radius: 8; color: pal.field
                                border.width: 1; border.color: pal.cardBorder
                                TextInput {
                                    id: cmdField
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true; selectByMouse: true; maximumLength: 400
                                    color: pal.text; selectionColor: pal.accent
                                    font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text
                                    text: appSheet.cCmd
                                    onTextChanged: appSheet.cCmd = text
                                    KeyNavigation.tab: iconField
                                    onAccepted: appSheet.addCustom()
                                }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: I18n.tr("As typed in a terminal. Quote paths that contain spaces.")
                                color: pal.text3
                                font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                            }
                        }
                        Column {
                            width: parent.width; spacing: 5
                            Text { text: I18n.tr("Icon"); color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc }
                            Row {
                                width: parent.width; spacing: 8
                                Image {
                                    width: 28; height: 28
                                    source: root.iconSrc(appSheet.cIcon.trim())
                                    sourceSize: Qt.size(56, 56)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true; mipmap: true
                                }
                                Rectangle {
                                    width: parent.width - 28 - 8 - chooseIcon.width - 8; height: 28; radius: 8; color: pal.field
                                    border.width: 1; border.color: pal.cardBorder
                                    TextInput {
                                        id: iconField
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true; selectByMouse: true; maximumLength: 400
                                        color: pal.text; selectionColor: pal.accent
                                        font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text
                                        text: appSheet.cIcon
                                        onTextChanged: appSheet.cIcon = text
                                        KeyNavigation.tab: nameField
                                        onAccepted: appSheet.addCustom()
                                    }
                                }
                                SButton {
                                    id: chooseIcon
                                    t: pal; y: 2
                                    text: I18n.tr("Choose…")
                                    onClicked: root.filePicker.pick({ mode: "image", title: I18n.tr("Choose a picture") }, function (f) { if (f !== "") appSheet.cIcon = f; })
                                }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: I18n.tr("An icon name, like firefox, or a picture.")
                                color: pal.text3
                                font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                            }
                        }
                        Item {
                            width: parent.width; height: 30
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("Run in a terminal")
                                color: pal.text
                                font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text
                            }
                            SSwitch { t: pal; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; checked: appSheet.cTerm; onToggled: v => appSheet.cTerm = v }
                        }
                        Row {
                            anchors.right: parent.right
                            spacing: 8
                            SButton { t: pal; text: I18n.tr("Cancel"); onClicked: appSheet.open = false }
                            SButton { t: pal; prominent: true; text: I18n.tr("Add to Dock"); enabled: appSheet.canAdd; onClicked: appSheet.addCustom() }
                        }
                    }
                }
            }

            Item {
                id: cropSheet
                anchors.fill: parent
                z: 60
                visible: opacity > 0.01
                opacity: open ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                property bool open: false
                property string src: ""
                property int ver: 0
                property real zoom: 1
                property real cx: 0
                property real cy: 0
                readonly property real iw: Math.max(1, cimg.implicitWidth)
                readonly property real ih: Math.max(1, cimg.implicitHeight)
                readonly property real side: Math.min(iw, ih) / zoom
                readonly property real k: cropVp.width / side

                function begin(path) { src = path; ver++; zoom = 1; open = true; }
                function clampPos() {
                    var h = side / 2;
                    cx = Math.max(h, Math.min(iw - h, cx));
                    cy = Math.max(h, Math.min(ih - h, cy));
                }
                function setZoom(z) { zoom = Math.max(1, Math.min(8, z)); clampPos(); }
                function save() {
                    var sd = Math.max(1, Math.round(side));
                    var x0 = Math.max(0, Math.round(cx - side / 2)), y0 = Math.max(0, Math.round(cy - side / 2));
                    cropProc.command = ["sh", "-c",
                        "magick \"$1[0]\" -auto-orient -crop \"${2}x${2}+${3}+${4}\" +repage -resize 512x512^ -gravity center -extent 512x512 png:\"$HOME/.face.new\" "
                        + "&& mv -f \"$HOME/.face.new\" \"$HOME/.face\" && echo ok", "sh", src, "" + sd, "" + x0, "" + y0];
                    cropProc.running = true;
                }
                Process {
                    id: cropProc
                    stdout: StdioCollector { onStreamFinished: if (text.indexOf("ok") >= 0) { root.faceVer++; cropSheet.open = false; } }
                }
                Connections { target: prefsWindow; function onVisibleChanged() { if (!prefsWindow.visible) cropSheet.open = false; } }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.5)
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: w => w.accepted = true }
                }
                Rectangle {
                    id: cropCard
                    anchors.centerIn: parent
                    width: 400; height: 532
                    radius: 16
                    color: pal.card
                    border.width: 1
                    border.color: pal.windowBorder
                    MouseArea { anchors.fill: parent }
                    Text {
                        y: 20; anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("Crop Picture")
                        color: pal.text
                        font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.page; font.weight: Font.DemiBold
                    }
                    Item {
                        id: cropVp
                        x: 40; y: 60
                        width: 320; height: 320
                        clip: true
                        Rectangle { anchors.fill: parent; color: "black" }
                        Image {
                            id: cimg
                            source: cropSheet.src === "" ? "" : "file://" + cropSheet.src.split("/").map(encodeURIComponent).join("/") + "?v=" + cropSheet.ver
                            cache: false; asynchronous: true; autoTransform: true; smooth: true; mipmap: true
                            fillMode: Image.Stretch
                            width: cropSheet.iw * cropSheet.k; height: cropSheet.ih * cropSheet.k
                            x: cropVp.width / 2 - cropSheet.cx * cropSheet.k
                            y: cropVp.height / 2 - cropSheet.cy * cropSheet.k
                            onStatusChanged: if (status === Image.Ready) { cropSheet.zoom = 1; cropSheet.cx = implicitWidth / 2; cropSheet.cy = implicitHeight / 2; }
                        }
                        Item { id: cropHole; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.62)
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: cropHole; maskInverted: true; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                        }
                        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.9) }
                        MouseArea {
                            anchors.fill: parent
                            property real lx: 0
                            property real ly: 0
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: m => { lx = m.x; ly = m.y; }
                            onPositionChanged: m => {
                                if (!pressed) return;
                                cropSheet.cx -= (m.x - lx) / cropSheet.k;
                                cropSheet.cy -= (m.y - ly) / cropSheet.k;
                                lx = m.x; ly = m.y;
                                cropSheet.clampPos();
                            }
                            onWheel: w => cropSheet.setZoom(cropSheet.zoom * Math.pow(1.0015, w.angleDelta.y))
                        }
                    }
                    Row {
                        x: 40; y: 392; spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Zoom"); color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text }
                        SSlider { t: pal; width: 250; from: 1; to: 8; value: cropSheet.zoom; onMoved: v => cropSheet.setZoom(v) }
                    }
                    Text {
                        x: 40; y: 428; width: 320
                        text: I18n.tr("Drag to move the picture. Scroll or use the slider to zoom.")
                        color: pal.text3; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                        font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 24
                        y: parent.height - 56
                        spacing: 8
                        SButton { t: pal; text: I18n.tr("Cancel"); onClicked: cropSheet.open = false }
                        SButton { t: pal; prominent: true; text: I18n.tr("Save"); enabled: cimg.status === Image.Ready && !cropProc.running; onClicked: cropSheet.save() }
                    }
                }
            }
        }

        Component {
            id: paneGeneral
            Column {
                spacing: 12

                SCard {
                    t: pal
                    id: langCard
                    readonly property string current: root.bar ? root.bar.language : "auto"
                    readonly property var options: [{ code: "auto", name: "", english: "" }].concat(I18n.languages)
                    Repeater {
                        model: langCard.options
                        delegate: Item {
                            id: lr
                            required property var modelData
                            required property int index
                            readonly property bool picked: langCard.current === modelData.code
                            width: parent.width; height: 48
                            Rectangle { visible: lr.index > 0; x: 14; width: parent.width - 14; height: 1; color: pal.sep }
                            Rectangle { anchors.fill: parent; color: pal.text; opacity: lrMa.pressed ? 0.08 : (lrMa.containsMouse ? 0.04 : 0) }
                            Column {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28 - 30
                                spacing: 2
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: lr.modelData.code === "auto" ? I18n.tr("Automatic") : lr.modelData.name
                                    color: pal.text; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.title
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: lr.modelData.code === "auto" ? I18n.tr("Automatic follows the system language") : lr.modelData.english
                                    color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                                }
                            }
                            Text {
                                visible: lr.picked
                                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                                text: "\u2713"; color: pal.accent
                                font.pixelSize: 16; font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: lrMa
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (root.bar) root.bar.language = lr.modelData.code; }
                            }
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Shell") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Dock")
                        subtitle: I18n.tr("Show the Dock at the bottom of the screen")
                        SSwitch { t: pal; checked: root.dockEnabled; onToggled: v => root.dockEnabled = v }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Menu Bar")
                        subtitle: I18n.tr("Includes Spotlight, Control Center and the calendar.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.barEnabled : true
                            onToggled: v => { if (root.bar) root.bar.barEnabled = v; }
                        }
                    }
                }
                SLabel {
                    t: pal
                    text: I18n.tr("With both off, reopen Settings with: qs -c YukiShell ipc call settings open")
                }
            }
        }

        Component {
            id: paneMenuBar
            Column {
                spacing: 12

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Menu Bar style")
                        subtitle: (root.bar && root.bar.barStyle === "liquid" && root.bar.glassState === "failed")
                                  ? I18n.tr("Liquid Glass couldn't start (details in the shell's log)")
                                  : I18n.tr("Style of the menus and popovers")
                        SSegmented {
                            t: pal
                            model: ["Normal Blur", "Liquid Glass"]
                            current: (root.bar && root.bar.barStyle === "liquid") ? 1 : 0
                            onPicked: i => { if (root.bar) root.bar.barStyle = (i === 1 ? "liquid" : "blur"); }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Liquid Glass bar")
                        subtitle: I18n.tr("The bar refracts what's under it. Needs the Liquid Glass style.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.barGlass : true
                            onToggled: v => { if (root.bar) root.bar.barGlass = v; }
                        }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Menu Bar size")
                        subtitle: I18n.tr("Scales the bar, its menus and Control Center.")
                        SSlider {
                            t: pal; from: 18; to: 48; stepSize: 1
                            value: root.bar ? root.bar.barHeight : 28
                            leftLabel: I18n.tr("Compact"); rightLabel: I18n.tr("Large")
                            resetValue: 28
                            onMoved: v => { if (root.bar) root.bar.barHeight = Math.round(v); }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Automatic scaling")
                        subtitle: I18n.tr("Shrinks the interface on screens smaller than 1920×1080.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.uiScaleAuto : true
                            onToggled: v => { if (root.bar) root.bar.uiScaleAuto = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("UI scale")
                        subtitle: I18n.tr("Your own multiplier, applied on top of automatic scaling (") + Math.round((root.bar ? root.bar.uiScale : 1) * 100) + "%)"
                        SSlider {
                            id: scaleSlider
                            property real pend: 1
                            t: pal; from: 0.5; to: 1.25; stepSize: 0.05
                            resetValue: 1.0
                            value: pressed ? pend : (root.bar ? root.bar.uiScaleManual : 1)
                            leftLabel: I18n.tr("Smaller"); rightLabel: I18n.tr("Larger")
                            onMoved: v => {
                                var r = Math.round(v * 100) / 100;
                                if (pressed) pend = r;
                                else if (root.bar) root.bar.uiScaleManual = r;
                            }
                            onReleased: { if (root.bar) root.bar.uiScaleManual = Math.round(pend * 100) / 100; }
                        }
                    }
                }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Menu Bar logo")
                        subtitle: I18n.tr("Choose the Arch mark, Apple logo, or a custom image")
                        SSegmented {
                            t: pal
                            model: ["Arch", "Apple", "Custom"]
                            current: !root.bar || root.bar.barLogoMode === "arch" ? 0 : (root.bar.barLogoMode === "apple" ? 1 : 2)
                            onPicked: i => {
                                if (root.bar) root.bar.barLogoMode = ["arch", "apple", "custom"][i];
                            }
                        }
                    }
                    SRow {
                        t: pal
                        visible: root.bar && root.bar.barLogoMode === "custom"
                        title: I18n.tr("Custom image path")
                        subtitle: I18n.tr("Enter a local image path (PNG, SVG, or other supported format)")
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 208; height: 28; radius: 8
                                color: pal.ctrl
                                border.width: 1
                                border.color: pal.cardBorder
                                TextInput {
                                    id: barLogoPathInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    selectByMouse: true
                                    color: pal.text
                                    selectionColor: pal.accent
                                    font.family: root.fontForWeight(Font.Normal, pal.fam)
                                    font.pixelSize: pal.fs.text
                                    text: root.bar ? root.bar.barCustomLogoPath : ""
                                    onTextEdited: { if (root.bar) root.bar.barCustomLogoPath = text; }
                                    Connections {
                                        target: root.bar
                                        function onBarCustomLogoPathChanged() {
                                            if (root.bar && barLogoPathInput.text !== root.bar.barCustomLogoPath)
                                                barLogoPathInput.text = root.bar.barCustomLogoPath;
                                        }
                                    }
                                }
                                Text {
                                    visible: barLogoPathInput.text === ""
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "~/Pictures/logo.png"
                                    color: pal.text3
                                    font.family: root.fontForWeight(Font.Normal, pal.fam)
                                    font.pixelSize: pal.fs.text
                                }
                            }
                            SButton {
                                t: pal; text: I18n.tr("Clear")
                                onClicked: { if (root.bar) root.bar.barCustomLogoPath = ""; }
                            }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Bar background")
                        subtitle: I18n.tr("Needs the Hyprland rule: layerrule = blur, yukibarbg")
                        SSlider {
                            t: pal
                            from: 0; to: 0.6; stepSize: 0.01
                            value: root.bar ? root.bar.barBgOpacity : 0.10
                            leftLabel: I18n.tr("Hidden"); rightLabel: I18n.tr("Tinted")
                            resetValue: 0.10
                            onMoved: v => { if (root.bar) root.bar.barBgOpacity = v; }
                        }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("24-hour clock")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.use24h : false
                            onToggled: v => { if (root.bar) root.bar.use24h = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Show date")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.showDate : false
                            onToggled: v => { if (root.bar) root.bar.showDate = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Show seconds")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.showSeconds : false
                            onToggled: v => { if (root.bar) root.bar.showSeconds = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Week starts on Monday")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.weekStartsMonday : false
                            onToggled: v => { if (root.bar) root.bar.weekStartsMonday = v; }
                        }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        visible: !root.bar || root.bar.hasBattery
                        title: I18n.tr("Battery percentage")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.showBatteryPercent : false
                            onToggled: v => { if (root.bar) root.bar.showBatteryPercent = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Real-time glass")
                        subtitle: I18n.tr("Popovers, Spotlight and the Dock always show what's behind them. Off saves GPU.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.glassRealtime : true
                            onToggled: v => { if (root.bar) root.bar.glassRealtime = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Animated wallpaper in glass")
                        subtitle: root.bar && root.bar.wallpaperVideo !== "" ? I18n.tr("Plays a video wallpaper inside the glass. Off uses a still frame.")
                                                                           : I18n.tr("Only for a live or animated wallpaper. Set one to change this.")
                        SSwitch {
                            t: pal
                            enabled: root.bar ? root.bar.wallpaperVideo !== "" : false
                            checked: root.bar ? root.bar.liveWallGlass : false
                            onToggled: v => { if (root.bar) root.bar.liveWallGlass = v; }
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Top Bar Widgets") }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Apple menu")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("appleMenu") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("appleMenu", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Application menus")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("appMenus") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("appMenus", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Workspace switcher")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("workspaces") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("workspaces", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Workspace numbers")
                        visible: !root.bar || root.bar.barWidgetEnabled("workspaces")
                        SPopUp {
                            t: pal
                            readonly property var keys: ["auto", "han", "katakana", "hangul", "roman", "numbers"]
                            model: [I18n.tr("Match the language"), I18n.tr("Han") + "  \u4e00 \u4e8c \u4e09", I18n.tr("Japanese") + "  \u30a4\u30c1 \u30cb \u30b5\u30f3",
                                    I18n.tr("Korean") + "  \uc77c \uc774 \uc0bc", I18n.tr("Roman") + "  I II III", I18n.tr("Numbers") + "  1 2 3"]
                            current: Math.max(0, keys.indexOf(root.bar ? root.bar.wsNumerals : "han"))
                            onPicked: i => { if (root.bar) root.bar.wsNumerals = keys[i]; }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("System tray")
                        SSwitch { t: pal; checked: root.bar ? root.bar.showTray : true; onToggled: v => { if (root.bar) root.bar.showTray = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Volume")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("volume") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("volume", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Bluetooth")
                        subtitle: I18n.tr("Show the Bluetooth status icon, even while Bluetooth is off")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("bluetooth") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("bluetooth", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Keyboard layout")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("keyboard") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("keyboard", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Notifications")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("notifications") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("notifications", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Live wallpaper button")
                        subtitle: I18n.tr("Shown while the wallpaper is a video.")
                        SSwitch { t: pal; checked: root.bar ? root.bar.showWallButton : true; onToggled: v => { if (root.bar) root.bar.showWallButton = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Wi-Fi and network")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("wifi") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("wifi", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Spotlight search")
                        SSwitch { t: pal; checked: root.bar ? root.bar.showSearch : true; onToggled: v => { if (root.bar) root.bar.showSearch = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Privacy indicators")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("privacy") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("privacy", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Control Center")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("controlCenter") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("controlCenter", v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Clock and calendar")
                        SSwitch { t: pal; checked: root.bar ? root.bar.barWidgetEnabled("clock") : true; onToggled: v => { if (root.bar) root.bar.setBarWidget("clock", v); } }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Keep clipboard history")
                        subtitle: I18n.tr("Keeps what you copy for Spotlight. Needs wl-clipboard and cliphist.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.clipHistory : false
                            onToggled: v => { if (root.bar) root.bar.clipHistory = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Paste after choosing")
                        subtitle: I18n.tr("Types the chosen item into the focused app. Shift+Return only copies.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.clipAutoPaste : false
                            onToggled: v => { if (root.bar) root.bar.clipAutoPaste = v; }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Screenshots") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Save to a folder")
                        subtitle: I18n.tr("Print selects an area. Off only copies it to the clipboard.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.screenshotSave : true
                            onToggled: v => { if (root.bar) root.bar.screenshotSave = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Save location")
                        subtitle: I18n.tr("Leave empty for ~/Pictures/Screenshots")
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 208; height: 28; radius: 8
                                color: pal.ctrl
                                border.width: 1
                                border.color: pal.cardBorder
                                TextInput {
                                    id: shotDirInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8; anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    selectByMouse: true
                                    color: pal.text
                                    selectionColor: pal.accent
                                    font.family: root.fontForWeight(Font.Normal, pal.fam)
                                    font.pixelSize: pal.fs.text
                                    text: root.bar ? root.bar.screenshotDir : ""
                                    onTextEdited: { if (root.bar) root.bar.screenshotDir = text; }
                                }
                                Text {
                                    visible: shotDirInput.text === ""
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "~/Pictures/Screenshots"
                                    color: pal.text3
                                    font.family: root.fontForWeight(Font.Normal, pal.fam)
                                    font.pixelSize: pal.fs.text
                                }
                            }
                            SButton { t: pal; text: I18n.tr("Choose\u2026"); onClicked: root.filePicker.pick({ mode: "folder", title: I18n.tr("Screenshot folder"), startDir: root.bar ? root.bar.screenshotDir : "" }, function (d) { if (d !== "" && root.bar) root.bar.screenshotDir = d; }) }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Quick folders")
                        SSegmented {
                            t: pal
                            property var dirs: ["~/Pictures/Screenshots", "~/Pictures", "~/Desktop", "~/Downloads"]
                            model: ["Screenshots", "Pictures", "Desktop", "Downloads"]
                            current: {
                                var d = root.bar ? root.bar.screenshotDir.replace(/\/+$/, "") : "";
                                return dirs.indexOf(d === "" ? dirs[0] : d);
                            }
                            onPicked: i => { if (root.bar) root.bar.screenshotDir = dirs[i]; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Copy to clipboard")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.screenshotClipboard : true
                            onToggled: v => { if (root.bar) root.bar.screenshotClipboard = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Show a notification")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.screenshotNotify : true
                            onToggled: v => { if (root.bar) root.bar.screenshotNotify = v; }
                        }
                    }
                }
                SLabel {
                    t: pal
                    text: I18n.tr("Bind the Print key:  bind = , Print, exec, qs -c YukiShell ipc call screenshot region.  Screenshots need grim.")
                }
                SLabel {
                    t: pal
                    text: I18n.tr("The terminal, launcher, files and clipboard commands are in ~/.config/yukibar/settings.json.")
                }
            }
        }

        Component {
            id: paneDock
            Column {
                spacing: 12

                Rectangle {
                    id: pv
                    width: parent.width
                    height: 150
                    radius: 10
                    clip: true
                    border.width: 1
                    border.color: pal.cardBorder
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#4158D0" }
                        GradientStop { position: 0.55; color: "#9B59D0" }
                        GradientStop { position: 1.0; color: "#F3805A" }
                    }
                    readonly property real base: root.iconSize * 0.5
                    readonly property var apps: root.items.filter(function (i) {
                        return i.kind === "app" && !i.special;
                    }).slice(0, 6)

                    Rectangle {
                        id: pbar
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10 + root.margin * 0.5
                        width: prow.width + 16
                        height: pv.base + 14
                        radius: root.cornerRadius * 0.6
                        color: root.dockDark ? Qt.rgba(0.10, 0.10, 0.11, root.glassOpacity)
                                             : Qt.rgba(1, 1, 1, root.glassOpacity * 0.55)
                        border.width: 1
                        border.color: root.dockDark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.45)
                    }
                    Row {
                        id: prow
                        anchors.horizontalCenter: pbar.horizontalCenter
                        anchors.bottom: pbar.bottom
                        anchors.bottomMargin: 7
                        spacing: root.spacing * 0.5
                        Repeater {
                            model: pv.apps
                            delegate: Item {
                                id: pi
                                required property var modelData
                                required property int index
                                width: pv.base
                                height: pv.base
                                readonly property int mid: Math.min(2, pv.apps.length - 1)
                                readonly property int d: Math.abs(index - mid)
                                readonly property real f: d === 0 ? 1 : (d === 1 ? 0.5 : (d === 2 ? 0.12 : 0))
                                Image {
                                    id: pimg
                                    anchors.fill: parent
                                    visible: false
                                    source: root.iconSrc(pi.modelData.icon)
                                    sourceSize: Qt.size(96, 96)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                }
                                MultiEffect {
                                    anchors.fill: pimg
                                    source: pimg
                                    saturation: root.iconTint ? -0.75 * root.iconTintStrength : 0.0
                                    colorization: root.iconTint ? 1.0 * root.iconTintStrength : 0.0
                                    brightness: root.iconTint ? 0.14 * root.iconTintStrength : 0.0
                                    contrast: root.iconTint ? 0.04 * root.iconTintStrength : 0.0
                                    colorizationColor: root.iconTintColor
                                    transformOrigin: Item.Bottom
                                    scale: root.magnificationEnabled ? 1 + (root.magnification - 1) * pi.f : 1
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                }
                            }
                        }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Size")
                        SSlider {
                            t: pal
                            from: 32; to: 128; stepSize: 1
                            value: root.iconSize
                            leftLabel: I18n.tr("Small"); rightLabel: I18n.tr("Large")
                            resetValue: 48
                            onMoved: v => root.iconSize = Math.round(v)
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Magnification")
                        subtitle: I18n.tr("Enlarge icons as the pointer moves over them")
                        SSwitch {
                            t: pal
                            checked: root.magnificationEnabled
                            onToggled: v => root.magnificationEnabled = v
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Magnification amount")
                        opacity: root.magnificationEnabled ? 1 : 0.45
                        SSlider {
                            t: pal
                            enabled: root.magnificationEnabled
                            from: 1.1; to: 2.5; stepSize: 0.05
                            value: root.magnification
                            leftLabel: I18n.tr("Min"); rightLabel: I18n.tr("Max")
                            resetValue: 1.5
                            onMoved: v => root.magnification = v
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Icon Tint") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Tint Dock icons")
                        subtitle: I18n.tr("Re-colours every icon with one colour. Works with any icon pack.")
                        SSwitch { t: pal; checked: root.iconTint; onToggled: v => root.iconTint = v }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Colour")
                        ColorChoice {
                            t: pal
                            active: root.iconTint
                            presets: root.tintChoices.map(function (a) { return a.c; })
                            current: String(root.iconTintColor)
                            onPicked: hex => root.iconTintColor = hex
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Strength")
                        subtitle: I18n.tr("Lower values keep some of the original icon colours")
                        opacity: root.iconTint ? 1 : 0.45
                        SSlider {
                            t: pal
                            enabled: root.iconTint
                            from: 0.1; to: 1.0; stepSize: 0.05
                            value: root.iconTintStrength
                            leftLabel: I18n.tr("Subtle"); rightLabel: I18n.tr("Full")
                            resetValue: 1.0
                            onMoved: v => root.iconTintStrength = Math.round(v * 100) / 100
                        }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Icon spacing")
                        SSlider {
                            t: pal
                            from: 0; to: 20; stepSize: 1
                            value: root.spacing
                            leftLabel: I18n.tr("Tight"); rightLabel: I18n.tr("Loose")
                            resetValue: 4
                            onMoved: v => root.spacing = Math.round(v)
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Distance from screen edge")
                        SSlider {
                            t: pal
                            from: 0; to: 40; stepSize: 1
                            value: root.margin
                            leftLabel: I18n.tr("Flush"); rightLabel: I18n.tr("Floating")
                            resetValue: 8
                            onMoved: v => root.margin = Math.round(v)
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Corner radius")
                        SSlider {
                            t: pal
                            from: 0; to: 32; stepSize: 1
                            value: root.cornerRadius
                            leftLabel: I18n.tr("Square"); rightLabel: I18n.tr("Round")
                            resetValue: 32
                            onMoved: v => root.cornerRadius = Math.round(v)
                        }
                    }
                }
                SLabel { t: pal; text: I18n.tr("Changes apply to the Dock immediately.") }
            }
        }

        Component {
            id: paneAppearance
            Column {
                spacing: 12

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Accent color")
                        subtitle: I18n.tr("Highlights in the Dock menu and this window")
                        ColorChoice {
                            t: pal
                            presets: root.accentChoices.map(function (a) { return a.c; })
                            current: String(root.accent)
                            onPicked: hex => root.setLook("accent", hex)
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Tint the interface")
                        subtitle: I18n.tr("Panels and cards take a shade of the accent color.")
                        SSwitch { t: pal; checked: root.accentUi; onToggled: v => root.setLook("accentUi", v) }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Font")
                        subtitle: I18n.tr("Used for labels and menus")
                        SSegmented {
                            t: pal
                            model: ["Open Runde", "Noto Sans", "System"]
                            current: root.fontFamily === "Open Runde" ? 0 : (root.fontFamily === "Noto Sans" ? 1 : 2)
                            onPicked: i => root.setLook("fontFamily", ["Open Runde", "Noto Sans", "sans-serif"][i])
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Dock") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Dock style")
                        subtitle: root.dockStyle === "liquid" && root.glassState === "failed"
                                  ? I18n.tr("Liquid Glass couldn't start (details in the shell's log) – using Normal Blur")
                                  : (root.dockStyle === "liquid" && root.glassState === "building"
                                     ? I18n.tr("Preparing the Liquid Glass shader…")
                                     : I18n.tr("Blur of the desktop, or refracting Liquid Glass"))
                        SSegmented {
                            t: pal
                            model: ["Normal Blur", "Liquid Glass"]
                            current: root.dockStyle === "liquid" ? 1 : 0
                            onPicked: i => root.dockStyle = (i === 1 ? "liquid" : "blur")
                        }
                    }
                    SRow {
                        t: pal
                        visible: root.dockStyle === "liquid"
                        title: I18n.tr("Blur")
                        subtitle: I18n.tr("How strongly the glass blurs what's behind it")
                        SSlider {
                            t: pal
                            from: 0; to: 80; stepSize: 1
                            value: root.glassBlur
                            leftLabel: I18n.tr("Sharp"); rightLabel: I18n.tr("Very blurry")
                            resetValue: 5
                            onMoved: v => root.setLook("glassBlur", Math.round(v))
                        }
                    }
                    SRow {
                        t: pal
                        visible: root.dockStyle === "liquid"
                        title: I18n.tr("Liquid strength")
                        subtitle: I18n.tr("Refraction, magnification and colour fringing of the glass")
                        SSlider {
                            t: pal
                            from: 0.5; to: 2.5; stepSize: 0.05
                            value: root.glassLiquid
                            leftLabel: I18n.tr("Subtle"); rightLabel: I18n.tr("Very liquid")
                            resetValue: 1.5
                            onMoved: v => root.setLook("glassLiquid", v)
                        }
                    }
                    SRow {
                        t: pal
                        visible: root.dockStyle === "liquid"
                        title: I18n.tr("Real-time glass")
                        subtitle: I18n.tr("Windows behind the Dock show through live.")
                        SSwitch { t: pal; checked: root.glassLive; onToggled: v => root.glassLive = v }
                    }
                }
                SLabel { t: pal; text: root.dockStyle === "liquid"
                                       ? I18n.tr("Corner radius in Desktop & Dock also shapes the glass.")
                                       : I18n.tr("The blur behind the Dock comes from your Hyprland layer rule.") }
            }
        }

        Component {
            id: paneBehavior
            Column {
                spacing: 12

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Automatically hide and show the Dock")
                        subtitle: root.hideMode === "smart" ? I18n.tr("Hides only while a tiled window needs the space")
                                : root.hideMode === "windows" ? I18n.tr("Hides whenever the workspace has a window open")
                                : (root.hideMode === "always" ? "Always hidden until the pointer touches the screen edge"
                                                              : I18n.tr("Always visible and reserves screen space"))
                        SSegmented {
                            t: pal
                            model: ["Smart", I18n.tr("Windows"), "Always", "Never"]
                            current: ["smart", "windows", "always", "never"].indexOf(root.hideMode)
                            onPicked: i => root.hideMode = ["smart", "windows", "always", "never"][i]
                        }
                    }
                    SRow {
                        t: pal
                        visible: root.hideMode !== "never"
                        title: I18n.tr("Hide delay")
                        SSlider {
                            t: pal
                            from: 0; to: 1500; stepSize: 50
                            value: root.hideDelay
                            leftLabel: I18n.tr("Instant"); rightLabel: "1.5 s"
                            resetValue: 500
                            onMoved: v => root.hideDelay = Math.round(v)
                        }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Show Dock on")
                        SSegmented {
                            t: pal
                            model: ["All Displays", "Primary Only"]
                            current: root.monitor === "" ? 0 : 1
                            onPicked: i => {
                                if (i === 0) root.monitor = "";
                                else if (Quickshell.screens.length > 0) root.monitor = Quickshell.screens[0].name;
                            }
                        }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Show labels")
                        subtitle: I18n.tr("Display an app's name when you hover its icon")
                        SSwitch { t: pal; checked: root.showLabels; onToggled: v => root.showLabels = v }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Show window previews")
                        subtitle: I18n.tr("Previews of open windows next to the Settings button.")
                        SSwitch { t: pal; checked: root.showThumbs; onToggled: v => root.showThumbs = v }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Live window capture")
                        subtitle: I18n.tr("Off shows app icons instead of window previews.")
                        SSwitch { t: pal; checked: root.windowCapture; onToggled: v => root.windowCapture = v }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Show indicators for open applications")
                        SSwitch { t: pal; checked: root.showIndicators; onToggled: v => root.showIndicators = v }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Animate opening applications")
                        subtitle: I18n.tr("Icons bounce while an app is launching")
                        SSwitch { t: pal; checked: root.bounceOnLaunch; onToggled: v => root.bounceOnLaunch = v }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Show Settings in the Dock")
                        SSwitch { t: pal; checked: root.showSettings; onToggled: v => root.showSettings = v }
                    }
                }
            }
        }

        Component {
            id: paneApps
            Column {
                id: appsCol
                spacing: 12
                readonly property int pinCount: root.items.filter(function (i) {
                    return i.kind === "app" && i.pinned && !i.special;
                }).length

                SLabel { t: pal; header: true; text: I18n.tr("Kept in Dock") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        visible: appsCol.pinCount === 0
                        title: I18n.tr("No apps are kept in the Dock")
                        subtitle: I18n.tr("Right-click a running app and choose Keep in Dock.")
                    }
                    Repeater {
                        model: root.items
                        delegate: SRow {
                            id: appRow
                            required property var modelData
                            t: pal
                            visible: modelData.kind === "app" && modelData.pinned === true && !modelData.special
                            title: modelData.name || ""
                            iconSource: modelData.icon ? root.iconSrc(modelData.icon) : ""
                            SButton {
                                t: pal
                                text: I18n.tr("Remove")
                                onClicked: root.togglePin(appRow.modelData)
                            }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Add to Dock") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Choose an app")
                        subtitle: I18n.tr("Pick any installed app to keep in the Dock.")
                        SButton { t: pal; text: I18n.tr("Choose App\u2026"); onClicked: appSheet.begin("list") }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Add a custom app")
                        subtitle: I18n.tr("Your own program or script.")
                        SButton { t: pal; text: I18n.tr("Custom App\u2026"); onClicked: appSheet.begin("custom") }
                    }
                }
                SLabel { t: pal; text: I18n.tr("Drag icons in the Dock to reorder them.") }
            }
        }

        Component {
            id: paneWifi
            Column {
                id: wifiPane
                spacing: 12
                property string ethInfo: ""
                Component.onCompleted: { if (root.bar) root.bar.scanWifi(); ethProc.running = true; }
                Timer { interval: 4000; repeat: true; running: prefsWindow.visible; onTriggered: if (!ethProc.running) ethProc.running = true }
                Process {
                    id: ethProc
                    command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$2==\"ethernet\"' | head -1 | while IFS=: read -r d t st c; do ip=$(ip -4 -o addr show \"$d\" 2>/dev/null | awk '{print $4}' | head -1); sp=$(cat /sys/class/net/$d/speed 2>/dev/null); printf '%s\t%s\t%s\t%s\t%s' \"$d\" \"$st\" \"$c\" \"$ip\" \"$sp\"; done"]
                    stdout: StdioCollector { onStreamFinished: wifiPane.ethInfo = text.trim() }
                }
                readonly property var eth: { var f = ethInfo.split("\t"); return f.length >= 2 ? { dev: f[0], up: f[1].indexOf("connected") === 0, con: f[2] || "", ip: f[3] || "", speed: f[4] || "" } : null; }
                SCard {
                    t: pal
                    visible: wifiPane.eth !== null
                    SRow {
                        t: pal; title: I18n.tr("Ethernet")
                        subtitle: !wifiPane.eth ? "" : (wifiPane.eth.up
                                  ? I18n.tr("Connected") + (wifiPane.eth.ip !== "" ? " · " + wifiPane.eth.ip : "") + (parseInt(wifiPane.eth.speed) > 0 ? " · " + wifiPane.eth.speed + I18n.tr(" Mb/s") : "")
                                  : I18n.tr("Cable unplugged"))
                        Row {
                            spacing: 8
                            WGlyph { width: 18; height: 18; kind: "ethernet"; color: pal.text; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle { width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter; color: wifiPane.eth && wifiPane.eth.up ? "#30D158" : pal.text3 }
                        }
                    }
                }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Wi-Fi")
                        subtitle: !root.bar ? "" : (!root.bar.wifiOn ? I18n.tr("Off") : (root.bar.wifiSsid !== "" ? I18n.tr("Connected to ") + root.bar.wifiSsid : I18n.tr("Not connected")))
                        SSwitch { t: pal; enabled: !!root.bar && root.bar.hasWifi; opacity: enabled ? 1 : 0.4; checked: root.bar ? root.bar.wifiOn : false; onToggled: v => { if (root.bar && root.bar.wifiOn !== v) root.bar.toggleWifi(); } }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Known Networks & Other Networks"); visible: root.bar && root.bar.wifiOn }
                SCard {
                    t: pal
                    visible: root.bar && root.bar.wifiOn
                    Repeater {
                        model: root.bar ? root.bar.wifiNets : []
                        delegate: SRow {
                            required property var modelData
                            t: pal
                            title: modelData.ssid + (modelData.inUse ? "  ✓" : "")
                            subtitle: (modelData.secure ? I18n.tr("Secured") : I18n.tr("Open")) + (modelData.saved ? I18n.tr(" · Saved") : "") + " · " + modelData.signal + "%"
                            SButton {
                                t: pal
                                text: modelData.inUse ? I18n.tr("Connected") : (modelData.saved || !modelData.secure ? I18n.tr("Connect") : I18n.tr("Join…"))
                                onClicked: {
                                    if (modelData.inUse) return;
                                    if (modelData.saved || !modelData.secure) root.bar.connectWifi(modelData.ssid, "");
                                    else { prefsWindow.visible = false; root.bar.wifiJoin ? root.bar.wifiJoin(modelData.ssid) : null; }
                                }
                            }
                        }
                    }
                }
                Row {
                    x: parent.width - width
                    spacing: 8
                    SButton { t: pal; text: I18n.tr("Scan Again"); onClicked: if (root.bar) root.bar.scanWifi() }
                }
            }
        }

        Component {
            id: paneBt
            Column {
                id: btPane
                spacing: 12
                readonly property var bar: root.bar
                readonly property var allDevs: bar ? bar.btDevices : []
                readonly property var myDevs: allDevs.filter(function (d) { return d.paired || d.connected; })
                readonly property var nearby: allDevs.filter(function (d) { return !d.paired && !d.connected; })
                Component.onCompleted: { if (bar) { bar.refreshBt(); bar.scanBt(); } }
                Timer { interval: 4000; repeat: true; running: prefsWindow.visible; onTriggered: if (btPane.bar) btPane.bar.refreshBt() }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Bluetooth")
                        subtitle: root.bar && root.bar.btOn ? I18n.tr("This computer is discoverable as \"") + root.userName + "\"" : I18n.tr("Off")
                        SSwitch { t: pal; checked: root.bar ? root.bar.btOn : false; onToggled: v => { if (root.bar && root.bar.btOn !== v) root.bar.toggleBt(); } }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("My Devices"); visible: btPane.myDevs.length > 0 }
                SCard {
                    t: pal
                    visible: btPane.myDevs.length > 0
                    Repeater {
                        model: btPane.myDevs
                        delegate: SRow {
                            required property var modelData
                            t: pal
                            title: modelData.name
                            subtitle: (root.bar && root.bar.btBusy === modelData.mac ? (modelData.connected ? I18n.tr("Disconnecting\u2026") : I18n.tr("Connecting\u2026"))
                                       : (modelData.connected ? "Connected" : "Not Connected")) + (modelData.bat !== "" ? " \u00B7 " + modelData.bat + "%" : "")
                            SButton {
                                t: pal; text: modelData.connected ? I18n.tr("Disconnect") : I18n.tr("Connect")
                                enabled: !(root.bar && root.bar.btBusy !== "")
                                onClicked: { if (root.bar) root.bar.connectBt(modelData.mac, modelData.connected); }
                            }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: (root.bar && root.bar.btScanning) ? I18n.tr("Nearby Devices \u2014 searching\u2026") : I18n.tr("Nearby Devices"); visible: root.bar && root.bar.btOn }
                SCard {
                    t: pal
                    visible: root.bar && root.bar.btOn
                    Repeater {
                        model: btPane.nearby
                        delegate: SRow {
                            required property var modelData
                            t: pal
                            title: modelData.name
                            subtitle: root.bar && root.bar.btBusy === modelData.mac ? I18n.tr("Pairing\u2026") : I18n.tr("Not paired")
                            SButton {
                                t: pal; text: I18n.tr("Connect")
                                enabled: !(root.bar && root.bar.btBusy !== "")
                                onClicked: { if (root.bar) root.bar.connectBt(modelData.mac, false); }
                            }
                        }
                    }
                    SRow {
                        t: pal
                        visible: btPane.nearby.length === 0
                        title: root.bar && root.bar.btScanning ? I18n.tr("Searching for devices\u2026") : I18n.tr("No new devices found")
                        subtitle: I18n.tr("Put the device in pairing mode, then scan again")
                        SButton { t: pal; text: I18n.tr("Scan Again"); enabled: !(root.bar && root.bar.btScanning); onClicked: { if (root.bar) root.bar.scanBt(); } }
                    }
                }
                SLabel { t: pal; text: root.bar ? root.bar.btError : ""; visible: root.bar && root.bar.btError !== "" }
            }
        }

        Component {
            id: paneNetwork
            Column {
                id: netPane
                spacing: 12
                property var info: ({})
                property var others: []
                property string dev: ""
                property string publicIp: ""
                property bool publicBusy: false
                readonly property bool up: info.state !== undefined && info.state.indexOf("connected") === 0
                readonly property string kind: info.type || ""
                function v(k) { return info[k] !== undefined ? info[k] : ""; }
                function mask(prefix) {
                    var n = parseInt(prefix); if (isNaN(n)) return "";
                    var out = [];
                    for (var i = 0; i < 4; i++) { var bits = Math.max(0, Math.min(8, n - i * 8)); out.push(256 - Math.pow(2, 8 - bits)); }
                    return out.join(".");
                }
                function since(ts) {
                    var sec = Math.floor(Date.now() / 1000) - parseInt(ts);
                    if (isNaN(sec) || sec < 0) return "";
                    var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
                    return d > 0 ? d + I18n.tr(" d ") + h + I18n.tr(" h") : (h > 0 ? h + I18n.tr(" h ") + m + I18n.tr(" min") : m + I18n.tr(" min"));
                }
                function copy(t) { if (t !== "") Quickshell.execDetached(["wl-copy", t]); }
                readonly property string ip4: (v("IP4.ADDRESS[1]").split("/")[0]) || ""
                readonly property string summary: [I18n.tr("Interface") + ": " + dev, I18n.tr("IP address") + ": " + ip4,
                    I18n.tr("Subnet mask") + ": " + mask(v("IP4.ADDRESS[1]").split("/")[1]), I18n.tr("Router") + ": " + v("IP4.GATEWAY"),
                    I18n.tr("DNS servers") + ": " + [v("IP4.DNS[1]"), v("IP4.DNS[2]"), v("IP4.DNS[3]")].filter(function (x) { return x !== ""; }).join(", "),
                    "IPv6: " + v("IP6.ADDRESS[1]").split("/")[0], I18n.tr("MAC address") + ": " + v("GENERAL.HWADDR")].join("\n")

                Component.onCompleted: netProc.running = true
                Timer { interval: 4000; repeat: true; running: prefsWindow.visible; onTriggered: if (!netProc.running) netProc.running = true }
                Process {
                    id: netProc
                    command: ["sh", "-c",
                        "d=$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}'); "
                        + "[ -n \"$d\" ] || d=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | awk -F: '$3 ~ /^connected/ && $2 != \"loopback\" {print $1; exit}'); "
                        + "[ -n \"$d\" ] || d=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2 == \"ethernet\" || $2 == \"wifi\" {print $1; exit}'); "
                        + "echo \"DEV:$d\"; [ -n \"$d\" ] || exit 0; "
                        + "nmcli -t -f GENERAL.TYPE,GENERAL.STATE,GENERAL.HWADDR,GENERAL.MTU,GENERAL.CONNECTION,GENERAL.VENDOR,GENERAL.PRODUCT,GENERAL.DRIVER,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY dev show \"$d\" 2>/dev/null; "
                        + "nmcli -t -f DHCP4.OPTION dev show \"$d\" 2>/dev/null | sed -n 's/.*dhcp_lease_time = \\([0-9]*\\).*/LEASE:\\1/p'; "
                        + "echo \"SPEED:$(cat /sys/class/net/$d/speed 2>/dev/null)\"; echo \"DUPLEX:$(cat /sys/class/net/$d/duplex 2>/dev/null)\"; "
                        + "c=$(nmcli -t -f GENERAL.CONNECTION dev show \"$d\" 2>/dev/null | cut -d: -f2-); "
                        + "nmcli -t -f NAME,TIMESTAMP con show --active 2>/dev/null | while IFS= read -r l; do [ \"${l%:*}\" = \"$c\" ] && echo \"SINCE:${l##*:}\"; done; "
                        + "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null | grep -vE ':(loopback|wifi-p2p|bridge):' | while IFS=: read -r od ot os oc; do "
                        + "[ \"$od\" = \"$d\" ] && continue; oi=$(ip -4 -o addr show \"$od\" 2>/dev/null | awk '{print $4}' | head -1); printf 'OTHER:%s\\t%s\\t%s\\t%s\\t%s\\n' \"$od\" \"$ot\" \"$os\" \"$oc\" \"$oi\"; done"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            var m = {}, o = [], l = text.split("\n");
                            for (var i = 0; i < l.length; i++) {
                                var k = l[i].indexOf(":"); if (k < 0) continue;
                                var key = l[i].substring(0, k), val = l[i].substring(k + 1).trim();
                                if (key === "OTHER") { var f = val.split("\t"); o.push({ dev: f[0], type: f[1] || "", state: f[2] || "", con: f[3] || "", ip: f[4] || "" }); }
                                else if (key === "DEV") netPane.dev = val;
                                else if (key === "GENERAL.TYPE") m.type = val;
                                else if (key === "GENERAL.STATE") m.state = val.replace(/^[0-9]+ \(|\)$/g, "");
                                else m[key] = val;
                            }
                            netPane.info = m; netPane.others = o;
                        }
                    }
                }
                Process {
                    id: pubProc
                    command: ["sh", "-c", "curl -fsS --max-time 6 https://api.ipify.org 2>/dev/null || echo ?"]
                    stdout: StdioCollector { onStreamFinished: { netPane.publicIp = text.trim() === "?" ? I18n.tr("Couldn't reach the lookup service") : text.trim(); netPane.publicBusy = false; } }
                }

                SCard {
                    t: pal
                    Item {
                        width: parent.width; height: 96
                        Rectangle {
                            id: netBadge
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 56; height: 56; radius: 28
                            gradient: Gradient {
                                GradientStop { position: 0; color: netPane.up ? "#3D9BFF" : "#8E8E93" }
                                GradientStop { position: 1; color: netPane.up ? "#0A6CFF" : "#636366" }
                            }
                            WGlyph { anchors.centerIn: parent; width: 28; height: 28; kind: netPane.kind === "wifi" ? "wifi" : "ethernet"; color: "white" }
                        }
                        Column {
                            x: 86; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - statusPill.width - 30
                            spacing: 2
                            Text {
                                text: netPane.dev === "" ? I18n.tr("No network adapter") : (netPane.kind === "wifi" ? I18n.tr("Wi-Fi") : (netPane.kind === "ethernet" ? I18n.tr("Ethernet") : netPane.dev))
                                color: pal.text; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.heading; font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: netPane.up ? I18n.tr("Connected") + (netPane.v("GENERAL.CONNECTION") !== "" ? " · " + netPane.v("GENERAL.CONNECTION") : "")
                                                 : (netPane.kind === "ethernet" ? I18n.tr("Cable unplugged") : I18n.tr("Not Connected"))
                                color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                            }
                            Text {
                                visible: netPane.up
                                width: parent.width; elide: Text.ElideRight
                                text: [parseInt(netPane.v("SPEED")) >= 1000 ? (parseInt(netPane.v("SPEED")) / 1000) + " Gb/s" : (parseInt(netPane.v("SPEED")) > 0 ? netPane.v("SPEED") + " Mb/s" : ""),
                                       netPane.v("DUPLEX") === "full" ? I18n.tr("full duplex") : "",
                                       netPane.v("SINCE") !== "" ? I18n.tr("connected for ") + netPane.since(netPane.v("SINCE")) : ""].filter(function (x) { return x !== ""; }).join(" · ")
                                color: pal.text3; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.caption
                            }
                        }
                        Rectangle {
                            id: statusPill
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: pillText.implicitWidth + 22; height: 24; radius: 12
                            color: netPane.up ? Qt.rgba(0.19, 0.82, 0.35, 0.16) : Qt.rgba(0.56, 0.56, 0.58, 0.16)
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 7; height: 7; radius: 3.5; anchors.verticalCenter: parent.verticalCenter; color: netPane.up ? "#30D158" : pal.text3 }
                                Text { id: pillText; text: netPane.up ? I18n.tr("Online") : I18n.tr("Offline"); color: netPane.up ? "#30D158" : pal.text2; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.caption; font.weight: Font.DemiBold }
                            }
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Details"); visible: netPane.dev !== "" }
                SCard {
                    t: pal
                    visible: netPane.dev !== ""
                    SRow {
                        t: pal; title: I18n.tr("IP address"); subtitle: netPane.ip4 !== "" ? netPane.ip4 : I18n.tr("None")
                        SButton { t: pal; text: I18n.tr("Copy"); visible: netPane.ip4 !== ""; onClicked: netPane.copy(netPane.ip4) }
                    }
                    SRow { t: pal; visible: netPane.ip4 !== ""; title: I18n.tr("Subnet mask"); subtitle: netPane.mask(netPane.v("IP4.ADDRESS[1]").split("/")[1]) + "  (/" + (netPane.v("IP4.ADDRESS[1]").split("/")[1] || "") + ")" }
                    SRow { t: pal; visible: netPane.v("IP4.GATEWAY") !== ""; title: I18n.tr("Router"); subtitle: netPane.v("IP4.GATEWAY") }
                    SRow {
                        t: pal; visible: netPane.v("IP4.DNS[1]") !== ""; title: I18n.tr("DNS servers")
                        subtitle: [netPane.v("IP4.DNS[1]"), netPane.v("IP4.DNS[2]"), netPane.v("IP4.DNS[3]")].filter(function (x) { return x !== ""; }).join(", ")
                    }
                    SRow {
                        t: pal; visible: netPane.v("IP6.ADDRESS[1]") !== ""; title: "IPv6"
                        subtitle: [netPane.v("IP6.ADDRESS[1]"), netPane.v("IP6.ADDRESS[2]")].filter(function (x) { return x !== ""; }).map(function (x) { return x.split("/")[0]; }).join("\n")
                        SButton { t: pal; text: I18n.tr("Copy"); onClicked: netPane.copy(netPane.v("IP6.ADDRESS[1]").split("/")[0]) }
                    }
                    SRow {
                        t: pal; visible: netPane.v("LEASE") !== ""; title: I18n.tr("DHCP lease time")
                        subtitle: netPane.since(Math.floor(Date.now() / 1000) - parseInt(netPane.v("LEASE")))
                    }
                    SRow {
                        t: pal; title: I18n.tr("Public IP address")
                        subtitle: netPane.publicIp !== "" ? netPane.publicIp : I18n.tr("Asks api.ipify.org, only when you press Look Up")
                        Row {
                            spacing: 6
                            SButton { t: pal; text: I18n.tr("Copy"); visible: /^[0-9a-f.:]+$/i.test(netPane.publicIp); onClicked: netPane.copy(netPane.publicIp) }
                            SButton {
                                t: pal; text: netPane.publicBusy ? I18n.tr("Looking up…") : I18n.tr("Look Up")
                                onClicked: { if (netPane.publicBusy) return; netPane.publicBusy = true; pubProc.running = true; }
                            }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Hardware"); visible: netPane.dev !== "" }
                SCard {
                    t: pal
                    visible: netPane.dev !== ""
                    SRow {
                        t: pal; title: I18n.tr("MAC address"); subtitle: netPane.v("GENERAL.HWADDR")
                        SButton { t: pal; text: I18n.tr("Copy"); onClicked: netPane.copy(netPane.v("GENERAL.HWADDR")) }
                    }
                    SRow { t: pal; title: I18n.tr("Adapter"); subtitle: (netPane.v("GENERAL.PRODUCT").replace(/\s*\(.*\)\s*$/, "") || netPane.dev) + (netPane.v("GENERAL.VENDOR") !== "" ? "\n" + netPane.v("GENERAL.VENDOR") : "") }
                    SRow { t: pal; title: I18n.tr("Interface"); subtitle: netPane.dev + (netPane.v("GENERAL.DRIVER") !== "" ? " · " + I18n.tr("driver ") + netPane.v("GENERAL.DRIVER") : "") + (netPane.v("GENERAL.MTU") !== "" ? " · MTU " + netPane.v("GENERAL.MTU") : "") }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Other Connections"); visible: netPane.others.length > 0 }
                SCard {
                    t: pal
                    visible: netPane.others.length > 0
                    Repeater {
                        model: netPane.others
                        delegate: SRow {
                            id: oRow
                            required property var modelData
                            t: pal
                            readonly property bool up: modelData.state.indexOf("connected") === 0
                            title: ({ ethernet: I18n.tr("Ethernet"), wifi: I18n.tr("Wi-Fi"), tun: modelData.dev === "tailscale0" ? I18n.tr("Tailscale") : I18n.tr("VPN"), wireguard: "WireGuard" })[modelData.type] || modelData.dev
                            subtitle: (up ? I18n.tr("Connected") : I18n.tr("Not Connected")) + (modelData.ip !== "" ? " · " + modelData.ip.split("/")[0] : "") + " · " + modelData.dev
                            Rectangle { width: 10; height: 10; radius: 5; color: oRow.up ? "#30D158" : pal.text3 }
                        }
                    }
                }

                Row {
                    x: parent.width - width
                    spacing: 8
                    visible: netPane.dev !== ""
                    SButton { t: pal; text: I18n.tr("Copy All Details"); onClicked: netPane.copy(netPane.summary) }
                    SButton {
                        t: pal; text: I18n.tr("Edit Connections…")
                        onClicked: { prefsWindow.visible = false; Quickshell.execDetached(["sh", "-c", ((root.bar && root.bar.terminal) || "kitty") + " -e nmtui"]); }
                    }
                }
            }
        }

        Component {
            id: paneBattery
            Column {
                id: batPane
                spacing: 12
                readonly property var dev: UPower.displayDevice
                readonly property real pct: dev ? Math.round(dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
                readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)
                property string profile: ""
                Component.onCompleted: ppGet.running = true
                Process { id: ppGet; command: ["powerprofilesctl", "get"]; stdout: StdioCollector { onStreamFinished: batPane.profile = text.trim() } }
                SCard {
                    t: pal
                    SRow {
                        visible: root.bar && root.bar.hasBattery
                        t: pal; title: I18n.tr("Battery Level")
                        subtitle: batPane.charging ? I18n.tr("Charging") : (batPane.dev && batPane.dev.timeToEmpty > 0 ? Math.floor(batPane.dev.timeToEmpty / 3600) + " h " + Math.round(batPane.dev.timeToEmpty % 3600 / 60) + I18n.tr(" min remaining") : I18n.tr("On battery"))
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 120; height: 10; radius: 5; color: pal.track; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: parent.width * batPane.pct / 100; height: parent.height; radius: 5; color: batPane.pct <= 20 && !batPane.charging ? "#FF453A" : "#30D158" }
                            }
                            Text { text: batPane.pct + "%"; color: pal.text; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Energy Mode")
                        subtitle: I18n.tr("Power profile used by the system")
                        SSegmented {
                            t: pal; model: ["Low Power", "Automatic", "High Power"]
                            current: ["power-saver", "balanced", "performance"].indexOf(batPane.profile)
                            onPicked: i => { var p = ["power-saver", "balanced", "performance"][i]; Quickshell.execDetached(["powerprofilesctl", "set", p]); batPane.profile = p; }
                        }
                    }
                }
                property var hw: ({})
                Timer { interval: 2000; repeat: true; triggeredOnStart: true; running: prefsWindow.visible; onTriggered: if (!hwProc.running) hwProc.running = true }
                Process {
                    id: hwProc
                    command: ["sh", "-c",
                        "echo \"CPU:$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)\"; echo \"CORES:$(nproc)\"; "
                        + "echo \"GOV:$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)\"; "
                        + "echo \"FREQ:$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | awk '{s+=$1;n++} END {if (n) printf \"%d\", s/n/1000}')\"; "
                        + "echo \"MAXF:$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)\"; "
                        + "t=''; for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name 2>/dev/null) in coretemp|k10temp|zenpower) t=$(cat $h/temp1_input 2>/dev/null); break;; esac; done; "
                        + "[ -n \"$t\" ] || t=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1); echo \"CTEMP:$t\"; "
                        + "echo \"STAT:$(head -1 /proc/stat)\"; echo \"UP:$(cut -d' ' -f1 /proc/uptime)\"; echo \"LOAD:$(cut -d' ' -f1-3 /proc/loadavg)\"; "
                        + "command -v nvidia-smi >/dev/null && echo \"GPU:$(nvidia-smi --query-gpu=name,temperature.gpu,power.draw,power.limit,utilization.gpu,clocks.gr,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)\"; "
                        + "for c in /sys/class/drm/card*/device; do [ -f $c/gpu_busy_percent ] && echo \"AGPU:$(cat $c/gpu_busy_percent)\" && break; done; true"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            var m = {}, l = text.split("\n");
                            for (var i = 0; i < l.length; i++) { var k = l[i].indexOf(":"); if (k > 0) m[l[i].substring(0, k)] = l[i].substring(k + 1).trim(); }
                            var f = (m.STAT || "").split(/\s+/).slice(1).map(Number);
                            if (f.length >= 4) {
                                var idle = f[3] + (f[4] || 0), tot = f.reduce(function (a, b) { return a + b; }, 0), o = batPane.hw;
                                m.busy = (o.tot !== undefined && tot > o.tot) ? Math.round(100 * (1 - (idle - o.idle) / (tot - o.tot))) : -1;
                                m.idle = idle; m.tot = tot;
                            }
                            batPane.hw = m;
                        }
                    }
                }
                readonly property var gpu: (hw.GPU || "").split(",").map(function (x) { return x.trim(); })
                function upText(sec) {
                    var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
                    return (d > 0 ? d + I18n.tr(" d ") : "") + (d > 0 || h > 0 ? h + I18n.tr(" h ") : "") + m + I18n.tr(" min");
                }
                function tempColor(c) { return c >= 85 ? "#FF453A" : (c >= 70 ? "#FF9F0A" : "#30D158"); }
                SLabel { t: pal; header: true; text: I18n.tr("Power Use") }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Processor")
                        subtitle: (batPane.hw.CPU || "").replace(/\s+/g, " ") + (batPane.hw.CORES ? " · " + batPane.hw.CORES + I18n.tr(" threads") : "")
                                  + (batPane.hw.GOV ? "\n" + I18n.tr("Governor: ") + batPane.hw.GOV : "")
                                  + (batPane.hw.FREQ ? " · " + (batPane.hw.FREQ / 1000).toFixed(2) + " GHz" + (batPane.hw.MAXF ? " / " + (batPane.hw.MAXF / 1e6).toFixed(1) + " GHz" : "") : "")
                    }
                    SRow {
                        t: pal; title: I18n.tr("Processor load"); visible: batPane.hw.busy !== undefined && batPane.hw.busy >= 0
                        subtitle: I18n.tr("Load average ") + (batPane.hw.LOAD || "").split(" ").join(" · ")
                        Row {
                            spacing: 8
                            Rectangle {
                                width: 120; height: 8; radius: 4; color: pal.track; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: parent.width * Math.max(0, batPane.hw.busy || 0) / 100; height: parent.height; radius: 4; color: pal.accent; Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
                            }
                            Text { width: 40; horizontalAlignment: Text.AlignRight; text: Math.max(0, batPane.hw.busy || 0) + "%"; color: pal.text; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    SRow {
                        id: cpuTempRow
                        t: pal; title: I18n.tr("Processor temperature"); visible: parseInt(batPane.hw.CTEMP) > 0
                        readonly property int c: Math.round(parseInt(batPane.hw.CTEMP) / 1000)
                        Row {
                            spacing: 6
                            Rectangle { width: 8; height: 8; radius: 4; color: batPane.tempColor(cpuTempRow.c); anchors.verticalCenter: parent.verticalCenter }
                            Text { text: cpuTempRow.c + " °C"; color: pal.text; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text }
                        }
                    }
                    SRow {
                        id: gpuRow
                        t: pal; title: I18n.tr("Graphics"); visible: batPane.gpu.length >= 5 && batPane.gpu[0] !== ""
                        subtitle: batPane.gpu[0] + (batPane.gpu.length >= 8 ? " · " + (batPane.gpu[6] / 1024).toFixed(1) + " / " + (batPane.gpu[7] / 1024).toFixed(1) + I18n.tr(" GB memory") : "")
                                  + "\n" + I18n.tr("Load ") + batPane.gpu[4] + "% · " + batPane.gpu[5] + " MHz · " + Math.round(parseFloat(batPane.gpu[2])) + " W / " + Math.round(parseFloat(batPane.gpu[3])) + " W"
                        Row {
                            spacing: 6
                            Rectangle { width: 8; height: 8; radius: 4; color: batPane.tempColor(parseInt(batPane.gpu[1])); anchors.verticalCenter: parent.verticalCenter }
                            Text { text: batPane.gpu[1] + " °C"; color: pal.text; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Graphics load"); visible: !gpuRow.visible && batPane.hw.AGPU !== undefined
                        subtitle: (batPane.hw.AGPU || "0") + "%"
                    }
                    SRow {
                        t: pal; title: I18n.tr("Up time"); visible: parseFloat(batPane.hw.UP) > 0
                        subtitle: batPane.upText(parseFloat(batPane.hw.UP)) + I18n.tr(" since you turned it on")
                    }
                }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Keep Awake")
                        subtitle: I18n.tr("Stop the computer from going to sleep or locking")
                        SSwitch { t: pal; checked: root.bar ? root.bar.keepAwake : false; onToggled: v => { if (root.bar) root.bar.keepAwake = v; } }
                    }
                }
                property string armed: ""
                Timer { id: armT; interval: 4000; onTriggered: batPane.armed = "" }
                function powerAct(id, cmd) {
                    if (armed !== id) { armed = id; armT.restart(); return; }
                    armed = ""; prefsWindow.visible = false;
                    Quickshell.execDetached(["systemctl", cmd]);
                }
                Row {
                    x: parent.width - width
                    spacing: 8
                    SButton { t: pal; text: I18n.tr("Sleep"); onClicked: { prefsWindow.visible = false; if (root.bar) root.bar.sleepMachine(); else Quickshell.execDetached(["systemctl", "suspend"]); } }
                    SButton { t: pal; text: batPane.armed === "restart" ? I18n.tr("Click Again to Restart") : I18n.tr("Restart\u2026"); onClicked: batPane.powerAct("restart", "reboot") }
                    SButton { t: pal; text: batPane.armed === "off" ? I18n.tr("Click Again to Shut Down") : I18n.tr("Shut Down\u2026"); onClicked: batPane.powerAct("off", "poweroff") }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Game Mode") }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Game Mode")
                        subtitle: I18n.tr("Turns off effects and animations, pauses a video wallpaper and uses the performance profile.")
                        SSwitch { t: pal; checked: root.bar ? root.bar.gamingMode : false; onToggled: v => { if (root.bar) root.bar.gamingMode = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Turn on automatically for fullscreen games")
                        subtitle: root.bar && root.bar.gamingAutoActive ? I18n.tr("On now: a game is fullscreen") : I18n.tr("Steam, Sober (Roblox), Minecraft, Lutris, Heroic and Windows games")
                        SSwitch { t: pal; checked: root.bar ? root.bar.gamingAuto : true; onToggled: v => { if (root.bar) root.bar.gamingAuto = v; } }
                    }
                }
            }
        }

        Component {
            id: paneCC
            Column {
                spacing: 12
                SLabel { t: pal; text: I18n.tr("Choose the controls and their sizes. Control Center → Edit Controls also lets you move and resize them.") }
                SLabel { t: pal; header: true; text: I18n.tr("Appearance") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Tile size")
                        subtitle: I18n.tr("How tall each row of controls is") + " (" + Math.round(root.bar ? root.bar.ccRowH : 66) + " px)"
                        SSlider {
                            t: pal
                            from: 44; to: 100; stepSize: 1
                            value: root.bar ? root.bar.ccRowH : 68
                            leftLabel: I18n.tr("Compact"); rightLabel: I18n.tr("Large")
                            resetValue: 68
                            onMoved: v => { if (root.bar) root.bar.ccRowH = Math.round(v); }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Spacing")
                        subtitle: I18n.tr("The gap between controls") + " (" + Math.round(root.bar ? root.bar.ccGapPx : 6) + " px)"
                        SSlider {
                            t: pal
                            from: 2; to: 16; stepSize: 1
                            value: root.bar ? root.bar.ccGapPx : 8
                            leftLabel: I18n.tr("Tight"); rightLabel: I18n.tr("Loose")
                            resetValue: 8
                            onMoved: v => { if (root.bar) root.bar.ccGapPx = Math.round(v); }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Highlight color")
                        subtitle: I18n.tr("The color a switched-on control turns")
                        ColorChoice {
                            t: pal
                            presets: ["", "#0A84FF", "#30D158", "#FFD60A", "#FF9F0A", "#FF453A", "#FF375F", "#64D2FF"]
                            current: root.bar ? root.bar.ccOnColor : ""
                            onPicked: hex => { if (root.bar) root.bar.ccOnColor = hex; }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Controls") }
                SCard {
                    t: pal
                    Repeater {
                        model: root.bar ? root.bar.ccCatalog : []
                        delegate: SRow {
                            id: ccRow
                            required property var modelData
                            readonly property bool enabledHere: root.bar ? root.bar.ccControls.indexOf(modelData.id) >= 0 : false
                            readonly property bool resizable: (modelData.sizes || []).length > 1
                            readonly property bool usable: root.bar ? root.bar.ccAvailable(modelData.id) : true
                            t: pal
                            title: I18n.tr(modelData.label)
                            subtitle: usable ? "" : I18n.tr("Not available on this computer")
                            opacity: usable ? 1 : 0.5
                            Row {
                                spacing: 12
                                SSegmented {
                                    visible: ccRow.resizable && ccRow.usable
                                    opacity: ccRow.enabledHere ? 1 : 0.45
                                    t: pal
                                    model: (ccRow.modelData.sizes || []).map(function (z) { return z[0] + "\u00D7" + z[1]; })
                                    current: {
                                        var cur = root.bar ? root.bar.ccSizeFor(ccRow.modelData.id) : [0, 0], l = ccRow.modelData.sizes || [];
                                        for (var i = 0; i < l.length; i++) if (l[i][0] === cur[0] && l[i][1] === cur[1]) return i;
                                        return -1;
                                    }
                                    onPicked: i => { if (root.bar) root.bar.ccResizeTo(ccRow.modelData.id, ccRow.modelData.sizes[i][0], ccRow.modelData.sizes[i][1]); }
                                }
                                SSwitch {
                                    t: pal
                                    enabled: ccRow.usable
                                    checked: ccRow.enabledHere && ccRow.usable
                                    onToggled: v => {
                                        if (!root.bar) return;
                                        var cl = root.bar.ccControls.filter(function (x) { return x !== ccRow.modelData.id; });
                                        if (v) cl.push(ccRow.modelData.id);
                                        root.bar.ccControls = cl;
                                    }
                                }
                            }
                        }
                    }
                }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        visible: root.bar ? root.bar.ccFree : false
                        title: I18n.tr("Tidy Up")
                        subtitle: I18n.tr("You placed some controls by hand. Pack them together again, in order")
                        SButton { t: pal; text: I18n.tr("Tidy Up"); onClicked: { if (root.bar) root.bar.ccTidy(); } }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Reset Control Center")
                        subtitle: I18n.tr("Back to the default controls, sizes and looks")
                        SButton { t: pal; glyph: "reset"; tip: I18n.tr("Reset"); onClicked: { if (root.bar) root.bar.ccResetAll(); } }
                    }
                }
            }
        }

        Component {
            id: paneDesktopDock
            Column {
                spacing: 12
                Loader { width: parent.width; sourceComponent: paneDock }
                SLabel { t: pal; header: true; text: I18n.tr("App Switcher (Alt + Tab)") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Style")
                        subtitle: I18n.tr("Liquid Glass refracts, Frosted blurs, Opaque is solid.")
                        SSegmented {
                            t: pal
                            model: ["Liquid Glass", "Frosted", "Opaque"]
                            current: Math.max(0, ["glass", "frosted", "opaque"].indexOf(root.bar ? root.bar.switcherStyle : "glass"))
                            onPicked: i => { if (root.bar) root.bar.switcherStyle = ["glass", "frosted", "opaque"][i]; }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Windows") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Border thickness")
                        subtitle: I18n.tr("The outline around every window, in the accent colour")
                        SSlider {
                            t: pal
                            from: 0; to: 8; stepSize: 1
                            value: root.bar ? root.bar.windowBorder : 1
                            leftLabel: I18n.tr("Off"); rightLabel: "8 px"
                            valueSuffix: " px"
                            resetValue: 1
                            onMoved: v => { if (root.bar) root.bar.windowBorder = Math.round(v); }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Open windows floating")
                        subtitle: I18n.tr("New windows float, centred, instead of tiling. Super + Alt + Space switches one window.")
                        SSwitch { t: pal; checked: root.bar ? root.bar.floatNewWindows : true; onToggled: v => { if (root.bar) root.bar.floatNewWindows = v; } }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Behavior") }
                Loader { width: parent.width; sourceComponent: paneBehavior }
            }
        }

        Component {
            id: paneWidgets
            Column {
                id: wgPane
                spacing: 12
                readonly property var wdg: root.hub ? root.hub.widgets : null
                readonly property int total: (wdg && wdg.rev >= 0) ? wdg.widgetCount : 0
                readonly property bool editing: wdg ? wdg.editing : false
                function removeAll() {
                    if (!wdg) return;
                    var ids = [];
                    for (var i = 0; i < wdg.model.count; i++) ids.push(wdg.model.get(i).wid);
                    for (var k = 0; k < ids.length; k++) wdg.removeWidget(ids[k]);
                }
                function removeOne(type) {
                    if (!wdg) return;
                    for (var i = wdg.model.count - 1; i >= 0; i--)
                        if (wdg.model.get(i).wtype === type) { wdg.removeWidget(wdg.model.get(i).wid); return; }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Arrange widgets")
                        subtitle: wgPane.editing
                                  ? I18n.tr("Editing is on: drag a widget to move it, use the \u2212 badge to remove it, then click Stop Editing.")
                                  : I18n.tr("Drag a widget to move it, or − to remove it.")
                        SButton {
                            t: pal
                            text: wgPane.editing ? I18n.tr("Stop Editing") : I18n.tr("Edit on Desktop")
                            onClicked: { if (wgPane.wdg) wgPane.wdg.editing = !wgPane.wdg.editing; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Widget size")
                        subtitle: I18n.tr("Makes every desktop widget smaller or larger (") + Math.round((wgPane.wdg ? wgPane.wdg.widgetScale : 1) * 100) + "%)"
                        SSlider {
                            t: pal
                            from: 0.6; to: 1.5; stepSize: 0.05
                            value: wgPane.wdg ? wgPane.wdg.widgetScale : 0.9
                            leftLabel: I18n.tr("Small"); rightLabel: I18n.tr("Large")
                            resetValue: 0.9
                            onMoved: v => { if (wgPane.wdg) wgPane.wdg.widgetScale = Math.round(v * 100) / 100; }
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Music Widget") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Cover glow")
                        subtitle: I18n.tr("The album art lights up the card from behind, in its own colours")
                        SSlider {
                            t: pal
                            from: 0; to: 1; stepSize: 0.05
                            value: root.bar ? root.bar.mwGlow : 0.6
                            leftLabel: I18n.tr("Off"); rightLabel: I18n.tr("Vivid")
                            resetValue: 0.6
                            onMoved: v => { if (root.bar) root.bar.mwGlow = Math.round(v * 100) / 100; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Living artwork")
                        subtitle: I18n.tr("The cover moves with playback. Off with Reduce Motion.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.mwMotion : true
                            onToggled: v => { if (root.bar) root.bar.mwMotion = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Progress bar")
                        SSegmented {
                            t: pal
                            model: ["Slim", "Bold"]
                            current: ["slim", "bold"].indexOf(root.bar ? root.bar.mwBar : "slim")
                            onPicked: i => { if (root.bar) root.bar.mwBar = ["slim", "bold"][i]; }
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Audio Visualizer") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Show audio visualizer")
                        subtitle: I18n.tr("Bars that move with the music. Needs cava.")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.visOn : true
                            onToggled: v => { if (root.bar) root.bar.visOn = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Placement")
                        subtitle: I18n.tr("Ambient fills the bottom of the widget; Strip sits behind the controls.")
                        SSegmented {
                            t: pal
                            model: ["Ambient", "Strip"]
                            current: ["ambient", "strip"].indexOf(root.bar ? root.bar.mwVisMode : "ambient")
                            onPicked: i => { if (root.bar) root.bar.mwVisMode = ["ambient", "strip"][i]; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Style")
                        SSegmented {
                            t: pal
                            model: ["Bars", "Mirror", "Wave"]
                            current: ["bars", "mirror", "wave"].indexOf(root.bar ? root.bar.visStyle : "bars")
                            onPicked: i => { if (root.bar) root.bar.visStyle = ["bars", "mirror", "wave"][i]; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Color")
                        subtitle: I18n.tr("Cover takes the colour of the album art")
                        SSegmented {
                            t: pal
                            model: ["Cover", "White", "Accent"]
                            current: ["art", "white", "accent"].indexOf(root.bar ? root.bar.visColor : "white")
                            onPicked: i => { if (root.bar) root.bar.visColor = ["art", "white", "accent"][i]; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Height")
                        SSlider {
                            t: pal
                            from: 0.5; to: 2; stepSize: 0.05
                            value: root.bar ? root.bar.visGain : 2
                            leftLabel: I18n.tr("Low"); rightLabel: I18n.tr("High")
                            resetValue: 2.0
                            onMoved: v => { if (root.bar) root.bar.visGain = Math.round(v * 100) / 100; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Columns")
                        SSlider {
                            t: pal
                            from: 8; to: 128; stepSize: 1
                            value: root.bar ? root.bar.visCount : 128
                            leftLabel: "8"; rightLabel: "128"
                            resetValue: 128
                            onMoved: v => { if (root.bar) root.bar.visCount = Math.round(v); }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Bar width")
                        SSlider {
                            t: pal
                            from: 0.2; to: 1; stepSize: 0.02
                            value: root.bar ? root.bar.visWidth : 0.7
                            leftLabel: I18n.tr("Thin"); rightLabel: I18n.tr("Wide")
                            resetValue: 0.7
                            onMoved: v => { if (root.bar) root.bar.visWidth = Math.round(v * 100) / 100; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Also in the Control Center")
                        subtitle: I18n.tr("Next to the cover of the Now Playing tile")
                        SSwitch {
                            t: pal
                            checked: root.bar ? root.bar.visInCC : true
                            onToggled: v => { if (root.bar) root.bar.visInCC = v; }
                        }
                    }
                    Item {
                        width: parent.width; height: 92
                        Rectangle { visible: parent.y > 0.5; x: 14; width: parent.width - 14; height: 1; color: pal.sep }
                        VisBars {
                            x: 18; y: 14
                            width: parent.width - 36; height: 64
                            src: root.hub ? root.hub.vis : null
                            active: !!root.bar && root.bar.visOn && prefsWindow.visible
                            demo: !(root.bar && root.bar.player && root.bar.player.isPlaying)
                            style: root.bar ? root.bar.visStyle : "bars"
                            gain: root.bar ? root.bar.visGain : 2
                            count: root.bar ? root.bar.visCount : 128
                            barFill: root.bar ? root.bar.visWidth : 0.7
                            readonly property color base: (root.bar && root.bar.visColor === "accent") ? pal.accent : pal.text
                            colorTop: Qt.rgba(base.r, base.g, base.b, 0.75)
                            colorBottom: Qt.rgba(base.r, base.g, base.b, 0.12)
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Add a Widget") }
                SCard {
                    t: pal
                    Repeater {
                        model: [
                            { type: "weather",  name: I18n.tr("Weather"),  hint: I18n.tr("Current conditions, hourly and daily forecast"), styles: [["liquid", I18n.tr("Liquid Glass")], ["normal", I18n.tr("Normal")]] },
                            { type: "calendar", name: I18n.tr("Calendar"), hint: I18n.tr("Today's date and the month"), styles: [["liquid", I18n.tr("Liquid Glass")], ["normal", I18n.tr("Normal")]] },
                            { type: "clock",    name: I18n.tr("Clock"),    hint: I18n.tr("Analog clock face"), styles: [["liquid", I18n.tr("Liquid Glass")], ["light", I18n.tr("Light")], ["dark", I18n.tr("Dark")]] },
                            { type: "player",   name: I18n.tr("Player"),   hint: I18n.tr("Now Playing with controls"), styles: [["liquid", I18n.tr("Liquid Glass")], ["light", I18n.tr("Light")], ["dark", I18n.tr("Dark")]] },
                            { type: "image",    name: I18n.tr("Image"),    hint: I18n.tr("Your own picture (you choose the file)"), styles: [["normal", I18n.tr("Photo")]] }
                        ]
                        delegate: Item {
                            id: addRow
                            required property var modelData
                            required property int index
                            property int styleIdx: 0
                            property int sizeIdx: 1
                            readonly property var sizeKeys: ["small", "medium", "large"]
                            readonly property int onDesktop: (wgPane.wdg && wgPane.wdg.rev >= 0) ? wgPane.wdg.count(modelData.type) : 0
                            width: parent ? parent.width : 0
                            height: 12 + head.height + 10 + ctl.height + 14

                            Rectangle { visible: addRow.index > 0; x: 14; width: parent.width - 14; height: 1; color: pal.sep }

                            Item {
                                id: head
                                x: 14; y: 12
                                width: parent.width - 28
                                height: Math.max(nameCol.height, badge.height)
                                Column {
                                    id: nameCol
                                    width: parent.width - badge.width - 12
                                    spacing: 2
                                    Text { width: parent.width; text: addRow.modelData.name; elide: Text.ElideRight; color: pal.text; font.family: root.fontForWeight(pal.fw.title, pal.fam); font.pixelSize: pal.fs.title }
                                    Text { width: parent.width; text: addRow.modelData.hint; wrapMode: Text.WordWrap; color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc }
                                }
                                Row {
                                    id: badge
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    spacing: 8
                                    visible: addRow.onDesktop > 0
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: addRow.onDesktop + I18n.tr(" on desktop")
                                        color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.caption
                                    }
                                    SButton { t: pal; text: "\u2212"; onClicked: wgPane.removeOne(addRow.modelData.type) }
                                }
                            }

                            Flow {
                                id: ctl
                                x: 14; y: 12 + head.height + 10
                                width: parent.width - 28
                                spacing: 10
                                SSegmented {
                                    t: pal
                                    visible: addRow.modelData.styles.length > 1
                                    model: addRow.modelData.styles.map(function (s) { return s[1]; })
                                    current: addRow.styleIdx
                                    onPicked: i => addRow.styleIdx = i
                                }
                                SSegmented {
                                    t: pal
                                    model: [I18n.tr("Small"), I18n.tr("Medium"), I18n.tr("Large")]
                                    current: addRow.sizeIdx
                                    onPicked: i => addRow.sizeIdx = i
                                }
                                SButton {
                                    t: pal
                                    text: "+ " + I18n.tr("Add")
                                    onClicked: {
                                        if (!wgPane.wdg) return;
                                        var sz = addRow.sizeKeys[addRow.sizeIdx];
                                        if (addRow.modelData.type === "image") wgPane.wdg.pickImage("", sz);
                                        else wgPane.wdg.addWidget(addRow.modelData.type, addRow.modelData.styles[addRow.styleIdx][0], sz);
                                    }
                                }
                            }
                        }
                    }
                }
                SLabel {
                    t: pal
                    visible: wgPane.wdg && wgPane.wdg.pickError !== ""
                    text: wgPane.wdg ? wgPane.wdg.pickError : ""
                    color: pal.danger
                }
                SLabel {
                    t: pal
                    text: I18n.tr("To change a picture later, use Edit on Desktop → Choose Image.")
                }

                SLabel { t: pal; header: true; text: I18n.tr("On Your Desktop") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        visible: wgPane.total === 0
                        title: I18n.tr("No widgets yet")
                        subtitle: I18n.tr("Add one above and it appears on the desktop.")
                    }
                    Repeater {
                        model: wgPane.wdg ? wgPane.wdg.model : null
                        delegate: SRow {
                            id: placedRow
                            required property string wid
                            required property string wtype
                            required property string wstyle
                            required property string wsize
                            required property string wspan
                            t: pal
                            title: (wgPane.wdg ? (wgPane.wdg.typeNames[wtype] || wtype) : wtype)
                            subtitle: wspan.replace("x", " \u00D7 ") + "  \u00B7  " + (wgPane.wdg ? (wgPane.wdg.styleNames[wstyle] || wstyle) : wstyle)
                            SButton { t: pal; text: I18n.tr("Remove"); onClicked: { if (wgPane.wdg) wgPane.wdg.removeWidget(placedRow.wid); } }
                        }
                    }
                    SRow {
                        t: pal
                        visible: wgPane.total > 1
                        title: I18n.tr("Remove all widgets")
                        SButton { t: pal; text: I18n.tr("Remove All"); onClicked: wgPane.removeAll() }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Weather") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Temperature unit")
                        subtitle: I18n.tr("Used by the Weather widget")
                        SSegmented {
                            t: pal
                            model: ["\u00B0C", "\u00B0F"]
                            current: wgPane.wdg && wgPane.wdg.tempUnit === "F" ? 1 : 0
                            onPicked: i => { if (wgPane.wdg) wgPane.wdg.tempUnit = (i === 1 ? "F" : "C"); }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Location")
                        subtitle: I18n.tr("Automatic uses your IP address; or type a city name")
                        SSegmented {
                            t: pal
                            model: ["Automatic", "City"]
                            current: wgPane.wdg && wgPane.wdg.locMode === "city" ? 1 : 0
                            onPicked: i => { if (wgPane.wdg) wgPane.wdg.locMode = (i === 1 ? "city" : "auto"); }
                        }
                    }
                    SRow {
                        t: pal
                        visible: wgPane.wdg && wgPane.wdg.locMode === "city"
                        title: I18n.tr("City")
                        subtitle: I18n.tr("For example: Riyadh, Dubai, London")
                        Rectangle {
                            width: 208; height: 28; radius: 8
                            color: pal.ctrl
                            border.width: 1
                            border.color: pal.cardBorder
                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                selectByMouse: true
                                color: pal.text
                                selectionColor: pal.accent
                                font.family: root.fontForWeight(Font.Normal, pal.fam)
                                font.pixelSize: pal.fs.text
                                text: wgPane.wdg ? wgPane.wdg.cityName : ""
                                onEditingFinished: { if (wgPane.wdg) wgPane.wdg.cityName = text; }
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: paneDisplays
            Column {
                id: dispPane
                spacing: 12
                Component.onCompleted: root.refreshMons()
                function hzText(hz) { return Math.abs(hz - Math.round(hz)) < 0.05 ? String(Math.round(hz)) : hz.toFixed(2); }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Brightness")
                        SSlider { t: pal; resetValue: 0.5; value: root.bar ? root.bar.brightness : 0.5; onMoved: v => { if (root.bar) root.bar.setBrightness(v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Night Shift")
                        subtitle: I18n.tr("Warmer colours to reduce blue light")
                        SSwitch { t: pal; checked: root.bar ? root.bar.nightOn : false; onToggled: v => { if (root.bar) root.bar.nightOn = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Colour Temperature"); visible: root.bar && root.bar.nightOn
                        SSlider {
                            t: pal; resetValue: 0.571; leftLabel: I18n.tr("Less Warm"); rightLabel: I18n.tr("More Warm")
                            value: root.bar ? 1 - (root.bar.nightTemp - 2500) / 3500 : 0.5
                            onMoved: v => { if (root.bar) root.bar.nightTemp = Math.round(2500 + (1 - v) * 3500); }
                        }
                    }
                }
                SCard {
                    t: pal
                    visible: root.modePending !== null
                    SRow {
                        t: pal; title: I18n.tr("Keep these display settings?")
                        subtitle: I18n.tr("Going back to the previous settings in ") + root.modeLeft + I18n.tr(" s")
                        Row {
                            spacing: 6
                            SButton { t: pal; text: I18n.tr("Revert"); onClicked: root.revertMode() }
                            SButton { t: pal; text: I18n.tr("Keep"); onClicked: root.keepMode() }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Displays") }
                SCard {
                    t: pal
                    visible: root.monList.length > 1
                    SRow {
                        t: pal; title: I18n.tr("Main display")
                        subtitle: I18n.tr("The Dock, the lock screen controls and new widgets go here")
                        SSegmented {
                            t: pal
                            model: root.monList.map(function (m) { return m.name; })
                            current: { var p = root.monitorPrimary || root.monitor; for (var i = 0; i < root.monList.length; i++) if (root.monList[i].name === p) return i; return -1; }
                            onPicked: i => root.setPrimary(root.monList[i].name)
                        }
                    }
                }
                Repeater {
                    model: root.monList
                    delegate: SCard {
                        id: monCard
                        required property var modelData
                        t: pal
                        readonly property string res: modelData.width + "x" + modelData.height
                        readonly property var modes: (modelData.availableModes || []).map(function (x) {
                            var m = String(x).match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
                            return m ? { res: m[1] + "x" + m[2], px: m[1] * m[2], hz: parseFloat(m[3]) } : null;
                        }).filter(function (x) { return x !== null; })
                        readonly property var resList: {
                            var out = [], sorted = modes.slice().sort(function (a, b) { return b.px - a.px; });
                            for (var i = 0; i < sorted.length; i++) if (out.indexOf(sorted[i].res) < 0) out.push(sorted[i].res);
                            return out;
                        }
                        readonly property var hzList: {
                            var out = [];
                            for (var i = 0; i < modes.length; i++) if (modes[i].res === res && out.indexOf(modes[i].hz) < 0) out.push(modes[i].hz);
                            return out.sort(function (a, b) { return b - a; });
                        }
                        function bestHz(r) { var b = 0; for (var i = 0; i < modes.length; i++) if (modes[i].res === r) b = Math.max(b, modes[i].hz); return b; }
                        SRow {
                            t: pal
                            title: (modelData.description || modelData.name).replace(/\s*\(.*\)$/, "")
                            subtitle: modelData.name + " · " + modelData.width + " × " + modelData.height + " @ " + dispPane.hzText(modelData.refreshRate) + I18n.tr(" Hz · Scale ") + modelData.scale
                        }
                        SRow {
                            t: pal; title: I18n.tr("Resolution"); visible: monCard.resList.length > 0
                            SPopUp {
                                t: pal
                                model: monCard.resList.map(function (r) { return r.replace("x", " × "); })
                                current: Math.max(0, monCard.resList.indexOf(monCard.res))
                                onPicked: i => { var r = monCard.resList[i]; if (r !== monCard.res) root.setMode(monCard.modelData, r + "@" + monCard.bestHz(r).toFixed(2)); }
                            }
                        }
                        SRow {
                            t: pal; title: I18n.tr("Refresh rate"); visible: monCard.hzList.length > 0
                            subtitle: monCard.hzList.length > 1 ? I18n.tr("Higher is smoother; the highest your screen offers at this resolution is ") + dispPane.hzText(monCard.hzList[0]) + " Hz" : ""
                            SPopUp {
                                t: pal
                                model: monCard.hzList.map(function (h) { return dispPane.hzText(h) + " Hz"; })
                                current: { var c = 0, d = 1e9; for (var i = 0; i < monCard.hzList.length; i++) { var x = Math.abs(monCard.hzList[i] - monCard.modelData.refreshRate); if (x < d) { d = x; c = i; } } return c; }
                                onPicked: i => root.setMode(monCard.modelData, monCard.res + "@" + monCard.hzList[i].toFixed(2))
                            }
                        }
                    }
                }
                SLabel { t: pal; text: I18n.tr("Kept modes are saved in ~/.config/yukishell/monitor-modes.tsv and applied at every start.") }
            }
        }

        Component {
            id: paneNotif
            Column {
                id: notifPane
                spacing: 12
                readonly property var apps: root.bar ? root.bar.notifAppsSeen.slice().sort(function (a, b) { return a.toLowerCase() < b.toLowerCase() ? -1 : 1; }) : []
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Show notification banners")
                        subtitle: I18n.tr("Off: no banners. Notifications still collect in Notification Center.")
                        SSwitch { t: pal; checked: root.bar ? !root.bar.notifDnd : true; onToggled: v => { if (root.bar) root.bar.notifDnd = !v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Banner duration")
                        subtitle: (root.bar ? root.bar.notifBannerSecs : 6) + I18n.tr(" seconds, unless the app asks for something else (urgent ones stay 10 s)")
                        SSlider {
                            t: pal; from: 3; to: 15; stepSize: 1; resetValue: 6
                            leftLabel: "3 s"; rightLabel: "15 s"
                            value: root.bar ? root.bar.notifBannerSecs : 6
                            onMoved: v => { if (root.bar) root.bar.notifBannerSecs = Math.round(v); }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Play sound for notifications")
                        SSwitch { t: pal; checked: root.bar ? root.bar.uiSounds : true; onToggled: v => { if (root.bar) root.bar.uiSounds = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Screenshot notifications")
                        SSwitch { t: pal; checked: root.bar ? root.bar.screenshotNotify : true; onToggled: v => { if (root.bar) root.bar.screenshotNotify = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Show on the lock screen")
                        subtitle: I18n.tr("Only the app and the time, never the message")
                        SSwitch { t: pal; checked: root.bar ? root.bar.lockShowNotifs : true; onToggled: v => { if (root.bar) root.bar.lockShowNotifs = v; } }
                    }
                }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Notification Center")
                        subtitle: !root.bar ? "" : (root.bar.notifHistCount === 0 ? I18n.tr("Empty")
                                  : root.bar.notifHistCount + (root.bar.notifHistCount === 1 ? I18n.tr(" notification") : I18n.tr(" notifications")) + " · " + root.bar.notifUnread + I18n.tr(" unread"))
                        SButton { t: pal; text: I18n.tr("Open"); onClicked: { prefsWindow.visible = false; Quickshell.execDetached(["qs", "-c", "YukiShell", "ipc", "call", "notifications", "open"]); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Do Not Disturb")
                        subtitle: root.bar && root.bar.dndActive ? (root.bar.notifDnd ? I18n.tr("On") : I18n.tr("On now from Focus (schedule or fullscreen)")) : I18n.tr("Off")
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Apps"); visible: notifPane.apps.length > 0 }
                SCard {
                    t: pal
                    visible: notifPane.apps.length > 0
                    Repeater {
                        model: notifPane.apps
                        delegate: SRow {
                            id: appRow
                            required property var modelData
                            t: pal
                            readonly property bool allowed: root.bar ? root.bar.notifMutedApps.indexOf(modelData) < 0 : true
                            title: modelData
                            subtitle: allowed ? I18n.tr("Banners and sounds") : I18n.tr("Notification Center only")
                            iconSource: { var p = Quickshell.iconPath(String(modelData).toLowerCase(), true); return p ? p : ""; }
                            SSwitch {
                                t: pal; checked: appRow.allowed
                                onToggled: v => {
                                    if (!root.bar) return;
                                    var m = root.bar.notifMutedApps.filter(function (a) { return a !== appRow.modelData; });
                                    if (!v) m.push(appRow.modelData);
                                    root.bar.notifMutedApps = m;
                                }
                            }
                        }
                    }
                }
                SLabel { t: pal; text: I18n.tr("Apps appear here after their first notification."); visible: notifPane.apps.length > 0 }
                Row {
                    x: parent.width - width
                    spacing: 8
                    SButton { t: pal; text: I18n.tr("Send Test Notification"); onClicked: Quickshell.execDetached(["notify-send", "-a", I18n.tr("Settings"), I18n.tr("Test notification"), I18n.tr("Notifications are working")]) }
                    SButton { t: pal; text: I18n.tr("Clear Notification Center"); onClicked: if (root.bar) root.bar.notifClearAnimated() }
                }
            }
        }

        Component {
            id: paneSound
            Column {
                id: sndPane
                spacing: 12
                readonly property var outs: Pipewire.nodes.values.filter(function (n) { return n.isSink && !n.isStream && n.audio; })
                readonly property var ins: Pipewire.nodes.values.filter(function (n) { return !n.isSink && !n.isStream && n.audio && (n.name || "").indexOf("monitor") < 0; })
                readonly property var apps: Pipewire.nodes.values.filter(function (n) { return n.isStream && !n.isSink && n.audio; })
                readonly property var src: Pipewire.defaultAudioSource
                readonly property var sounds: [{ id: "glass", name: "Glass" }, { id: "tink", name: "Tink" }, { id: "pop", name: "Pop" }, { id: "timer", name: "Chime" }, { id: "charge", name: "Bloom" }]
                function appName(n) {
                    var p = n.properties || {};
                    return p["application.name"] || n.description || n.nickname || n.name || I18n.tr("App");
                }
                PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].concat(sndPane.apps) }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Play user interface sound effects")
                        SSwitch { t: pal; checked: root.bar ? root.bar.uiSounds : true; onToggled: v => { if (root.bar) root.bar.uiSounds = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Alert sound"); visible: root.bar && root.bar.uiSounds
                        subtitle: I18n.tr("Played for notifications")
                        Row {
                            spacing: 6
                            SPopUp {
                                t: pal
                                model: sndPane.sounds.map(function (x) { return x.name; })
                                current: Math.max(0, sndPane.sounds.map(function (x) { return x.id; }).indexOf(root.bar ? root.bar.alertSound : "glass"))
                                onPicked: i => { if (!root.bar) return; root.bar.alertSound = sndPane.sounds[i].id; root.bar.playSound(sndPane.sounds[i].id, 0.7); }
                            }
                            SButton { t: pal; text: "▶"; onClicked: if (root.bar) root.bar.playSound(root.bar.alertSound, 0.7) }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Alert volume"); visible: root.bar && root.bar.uiSounds
                        SSlider {
                            t: pal; resetValue: 1; leftLabel: I18n.tr("Quiet"); rightLabel: I18n.tr("Loud")
                            value: root.bar ? root.bar.uiSoundVolume : 1
                            onMoved: v => { if (root.bar) root.bar.uiSoundVolume = v; }
                            onPressedChanged: if (!pressed && root.bar) root.bar.playSound(root.bar.alertSound, 0.7)
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Output") }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Output volume")
                        subtitle: root.bar ? (root.bar.muted ? I18n.tr("Muted") : Math.round(root.bar.volume * 100) + "%") : ""
                        SSlider { t: pal; resetValue: 0.5; value: root.bar ? (root.bar.muted ? 0 : root.bar.volume) : 0; onMoved: v => { if (root.bar) root.bar.setVolume(v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Mute")
                        SSwitch { t: pal; checked: root.bar ? root.bar.muted : false; onToggled: v => { if (root.bar && root.bar.muted !== v) root.bar.toggleMute(); } }
                    }
                    Repeater {
                        model: sndPane.outs
                        delegate: SRow {
                            required property var modelData
                            t: pal
                            title: modelData.description || modelData.nickname || modelData.name
                            id: devRowSink
                            readonly property bool cur: Pipewire.defaultAudioSink === modelData
                            subtitle: cur ? I18n.tr("Selected") : ""
                            SButton { t: pal; text: devRowSink.cur ? I18n.tr("In Use") : I18n.tr("Use"); onClicked: Pipewire.preferredDefaultAudioSink = devRowSink.modelData }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Apps"); visible: sndPane.apps.length > 0 }
                SCard {
                    t: pal
                    visible: sndPane.apps.length > 0
                    Repeater {
                        model: sndPane.apps
                        delegate: SRow {
                            id: appSnd
                            required property var modelData
                            t: pal
                            title: sndPane.appName(modelData)
                            subtitle: modelData.audio ? (modelData.audio.muted ? I18n.tr("Muted") : Math.round(modelData.audio.volume * 100) + "%") : ""
                            iconSource: { var p = modelData.properties || {}, ic = p["application.icon-name"] || String(p["application.process.binary"] || "").toLowerCase(); var q = ic ? Quickshell.iconPath(ic, true) : ""; return q ? q : ""; }
                            SSlider {
                                t: pal; resetValue: 1
                                value: appSnd.modelData.audio ? Math.min(1, appSnd.modelData.audio.volume) : 0
                                onMoved: v => { if (appSnd.modelData.audio) { appSnd.modelData.audio.muted = false; appSnd.modelData.audio.volume = v; } }
                            }
                        }
                    }
                }
                SLabel { t: pal; text: I18n.tr("Apps that are playing sound show up here with their own volume."); visible: sndPane.apps.length > 0 }
                SLabel { t: pal; header: true; text: I18n.tr("Input") }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Input volume")
                        subtitle: sndPane.src && sndPane.src.audio ? (sndPane.src.audio.muted ? I18n.tr("Muted") : Math.round(sndPane.src.audio.volume * 100) + "%") : ""
                        SSlider { t: pal; resetValue: 1.0; value: sndPane.src && sndPane.src.audio ? sndPane.src.audio.volume : 0; onMoved: v => { if (sndPane.src && sndPane.src.audio) sndPane.src.audio.volume = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Mute microphone")
                        SSwitch { t: pal; checked: root.bar ? root.bar.micMuted : false; onToggled: v => { if (sndPane.src && sndPane.src.audio) sndPane.src.audio.muted = v; } }
                    }
                    Repeater {
                        model: sndPane.ins
                        delegate: SRow {
                            required property var modelData
                            t: pal
                            title: modelData.description || modelData.nickname || modelData.name
                            id: devRowSource
                            readonly property bool cur: Pipewire.defaultAudioSource === modelData
                            subtitle: cur ? I18n.tr("Selected") : ""
                            SButton { t: pal; text: devRowSource.cur ? I18n.tr("In Use") : I18n.tr("Use"); onClicked: Pipewire.preferredDefaultAudioSource = devRowSource.modelData }
                        }
                    }
                }
            }
        }

        Component {
            id: paneFocus
            Column {
                id: focusPane
                spacing: 12
                readonly property var times: { var out = []; for (var h = 0; h < 24; h++) for (var m = 0; m < 60; m += 30) out.push(h * 60 + m); return out; }
                function hm(min) { var h = Math.floor(min / 60), m = min % 60; return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m; }
                SCard {
                    t: pal
                    Item {
                        width: parent.width; height: 72
                        Rectangle {
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 44; height: 44; radius: 22
                            color: root.bar && root.bar.dndActive ? "#5E5CE6" : pal.track
                            WGlyph { anchors.centerIn: parent; width: 22; height: 22; kind: "moon"; color: root.bar && root.bar.dndActive ? "white" : pal.text2 }
                        }
                        Column {
                            x: 72; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { text: I18n.tr("Do Not Disturb"); color: pal.text; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.heading; font.weight: Font.DemiBold }
                            Text {
                                color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                                text: !root.bar ? "" : (root.bar.notifDnd ? I18n.tr("On until you turn it off")
                                      : (root.bar.focusSchedule && root.bar.scheduleNow ? I18n.tr("On by schedule until ") + focusPane.hm(root.bar.focusTo)
                                      : (root.bar.focusFullscreen && root.bar.fullscreenNow ? I18n.tr("On while an app is fullscreen") : I18n.tr("Off"))))
                            }
                        }
                        SSwitch {
                            t: pal
                            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            checked: root.bar ? root.bar.notifDnd : false
                            onToggled: v => { if (root.bar) root.bar.notifDnd = v; }
                        }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("Turn On Automatically") }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("On a schedule")
                        subtitle: root.bar ? I18n.tr("Every day from ") + focusPane.hm(root.bar.focusFrom) + I18n.tr(" to ") + focusPane.hm(root.bar.focusTo) : ""
                        SSwitch { t: pal; checked: root.bar ? root.bar.focusSchedule : false; onToggled: v => { if (root.bar) root.bar.focusSchedule = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("From"); visible: root.bar && root.bar.focusSchedule
                        SPopUp { t: pal; model: focusPane.times.map(focusPane.hm); current: Math.max(0, focusPane.times.indexOf(root.bar ? root.bar.focusFrom : 1320)); onPicked: i => { if (root.bar) root.bar.focusFrom = focusPane.times[i]; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("To"); visible: root.bar && root.bar.focusSchedule
                        SPopUp { t: pal; model: focusPane.times.map(focusPane.hm); current: Math.max(0, focusPane.times.indexOf(root.bar ? root.bar.focusTo : 420)); onPicked: i => { if (root.bar) root.bar.focusTo = focusPane.times[i]; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("While an app is fullscreen")
                        subtitle: I18n.tr("Games, videos, presentations")
                        SSwitch { t: pal; checked: root.bar ? root.bar.focusFullscreen : false; onToggled: v => { if (root.bar) root.bar.focusFullscreen = v; } }
                    }
                }
                SLabel { t: pal; header: true; text: I18n.tr("While Do Not Disturb Is On") }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Let urgent notifications through")
                        subtitle: I18n.tr("Alarms, low battery and other critical alerts still show a banner")
                        SSwitch { t: pal; checked: root.bar ? root.bar.focusAllowUrgent : true; onToggled: v => { if (root.bar) root.bar.focusAllowUrgent = v; } }
                    }
                }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Keep Awake")
                        subtitle: I18n.tr("Stop the computer from going to sleep or locking")
                        SSwitch { t: pal; checked: root.bar ? root.bar.keepAwake : false; onToggled: v => { if (root.bar) root.bar.keepAwake = v; } }
                    }
                }
            }
        }

        Component {
            id: paneLock
            Column {
                id: lockPane
                spacing: 12
                property string slot: "top"
                Component.onCompleted: slotGet.running = true
                readonly property string ownWall: root.bar ? root.bar.lockWallpaper : ""
                readonly property string shownWall: ownWall !== "" ? ownWall : (root.bar ? root.bar.wallpaperPath : "")
                SCard {
                    t: pal
                    Item {
                        width: parent.width; height: 150
                        Rectangle {
                            id: lockThumb
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 208; height: 117; radius: 10; clip: true
                            color: pal.track
                            Image {
                                anchors.fill: parent
                                source: lockPane.shownWall !== "" ? "file://" + lockPane.shownWall : ""
                                fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 416; smooth: true
                                layer.enabled: true
                                layer.effect: MultiEffect { maskEnabled: true; maskSource: thumbMask }
                            }
                            Item { id: thumbMask; anchors.fill: parent; layer.enabled: true; visible: false; Rectangle { anchors.fill: parent; radius: 10 } }
                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter; y: 16; spacing: -2
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.locale().toString(new Date(), I18n.tr("dddd, MMMM d")); color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 8; font.weight: Font.DemiBold }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(new Date(), root.bar && !root.bar.use24h ? "h:mm" : "HH:mm"); color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 34; font.weight: Font.Bold }
                            }
                            Rectangle { anchors.fill: parent; radius: 10; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12) }
                        }
                        Column {
                            x: lockThumb.x + lockThumb.width + 18; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 16; spacing: 8
                            Text { text: I18n.tr("Wallpaper"); color: pal.text; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.heading; font.weight: Font.DemiBold }
                            Text {
                                width: parent.width; elide: Text.ElideMiddle
                                text: lockPane.ownWall !== "" ? lockPane.ownWall.split("/").pop() : I18n.tr("Same as the desktop")
                                color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                            }
                            Row {
                                spacing: 6
                                SButton {
                                    t: pal; text: I18n.tr("Choose\u2026")
                                    onClicked: root.filePicker.pick({ mode: "image", title: I18n.tr("Lock screen wallpaper"), startDir: lockPane.ownWall !== "" ? lockPane.ownWall.substring(0, lockPane.ownWall.lastIndexOf("/")) : "" },
                                                                    function (f) { if (f !== "" && root.bar) root.bar.lockWallpaper = f; })
                                }
                                SButton { t: pal; text: I18n.tr("Use Desktop Wallpaper"); visible: lockPane.ownWall !== ""; onClicked: if (root.bar) root.bar.lockWallpaper = "" }
                            }
                        }
                    }
                }
                SLabel { t: pal; text: I18n.tr("Its own picture stays when the desktop changes. Videos play only with the desktop wallpaper."); }
                Process { id: slotGet; command: ["sh", "-c", "jq -r '.mediaSlot // \"top\"' \"$HOME/.config/yukilock/settings.json\" 2>/dev/null || echo top"]
                          stdout: StdioCollector { onStreamFinished: lockPane.slot = text.trim() === "bottom" ? "bottom" : "top" } }
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Now Playing position")
                        subtitle: I18n.tr("You can also drag it on the lock screen")
                        SSegmented {
                            t: pal; model: ["Under Clock", "Above Password"]
                            current: lockPane.slot === "bottom" ? 1 : 0
                            onPicked: i => {
                                lockPane.slot = i === 1 ? "bottom" : "top";
                                Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/yukilock\" && printf '{\\n  \"mediaSlot\": \"%s\"\\n}\\n' \"$1\" > \"$HOME/.config/yukilock/settings.json\"", "sh", lockPane.slot]);
                            }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Album background when the cover is enlarged")
                        SSwitch { t: pal; checked: root.bar ? root.bar.lockArtBackground : true; onToggled: v => { if (root.bar) root.bar.lockArtBackground = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Show notifications")
                        subtitle: I18n.tr("Only the app and the time, never the message")
                        SSwitch { t: pal; checked: root.bar ? root.bar.lockShowNotifs : true; onToggled: v => { if (root.bar) root.bar.lockShowNotifs = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("24-hour clock")
                        subtitle: I18n.tr("Shared with the menu bar clock")
                        SSwitch { t: pal; checked: root.bar ? root.bar.use24h : true; onToggled: v => { if (root.bar) root.bar.use24h = v; } }
                    }
                }
                readonly property string roundedFam: (typeof Qt.fontFamilies === "function" && Qt.fontFamilies().indexOf("Nunito") >= 0) ? "Nunito" : "Open Runde"
                SLabel { t: pal; text: I18n.tr("Clock"); font.weight: Font.DemiBold; topPadding: 6 }
                SCard {
                    t: pal
                    Item {
                        width: parent.width; height: 132
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Repeater {
                                model: [
                                    { id: "glass",   name: "Glass",   fam: roundedFam, w: 680, tall: false, liquid: false },
                                    { id: "classic", name: "Classic", fam: roundedFam,             w: 640, tall: false, liquid: false },
                                    { id: "serif",   name: "Serif",   fam: "Noto Serif Display", w: 560, tall: false, liquid: false },
                                    { id: "liquid",  name: "Liquid",  fam: roundedFam, w: 560, tall: false, liquid: true },
                                    { id: "thin",    name: "Thin",    fam: roundedFam,             w: 220, tall: false, liquid: true }
                                ]
                                delegate: Column {
                                    id: tile
                                    required property var modelData
                                    readonly property bool sel: root.bar && root.bar.lockClockStyle === modelData.id
                                    spacing: 6
                                    Rectangle {
                                        width: 92; height: 92; radius: 14
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: "#8C7A6B" }
                                            GradientStop { position: 1; color: "#3E3530" }
                                        }
                                        GlassRing { anchors.fill: parent; anchors.margins: -1; radius: 15; on: tile.sel; dark: pal.dark }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "9:41"
                                            font.family: Fonts.forWeight(Math.max(100, Math.min(900, tile.modelData.w)), tile.modelData.fam); font.pixelSize: tile.modelData.tall ? 40 : 30
                                            font.weight: Math.max(100, Math.min(900, tile.modelData.w))
                                            font.variableAxes: ({ "wght": tile.modelData.w })
                                            color: tile.modelData.liquid ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.78)
                                            style: tile.modelData.liquid ? Text.Outline : Text.Normal
                                            styleColor: Qt.rgba(1, 1, 1, 0.85)
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.bar) root.bar.applyLockClockPreset(tile.modelData.id) }
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr(tile.modelData.name); color: pal.text; font.family: root.fontForWeight(tile.sel ? Font.DemiBold : Font.Normal, pal.fam); font.pixelSize: pal.fs.desc; font.weight: tile.sel ? Font.DemiBold : Font.Normal }
                                }
                            }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Font")
                        SPopUp {
                            t: pal
                            model: ["Rounded", "Serif", "Default"]
                            readonly property var ids: ["rounded", "serif", "inter"]
                            current: Math.max(0, ids.indexOf(root.bar ? root.bar.lockClockFont : "rounded"))
                            onPicked: i => { if (root.bar) { root.bar.lockClockFont = ids[i]; root.bar.lockClockStyle = "custom"; } }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Weight")
                        SSlider {
                            t: pal; resetValue: 1000; width: 220; from: 100; to: 1000; stepSize: 10
                            leftLabel: I18n.tr("Thin"); rightLabel: I18n.tr("Heavy")
                            value: root.bar ? root.bar.lockClockWeight : 1000
                            onMoved: v => { if (root.bar) { root.bar.lockClockWeight = Math.round(v); root.bar.lockClockStyle = "custom"; } }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Style")
                        subtitle: I18n.tr("Solid takes a hint of the wallpaper; Glass is Liquid Glass.")
                        SSegmented {
                            t: pal; model: ["Solid", "Glass"]
                            current: root.bar && root.bar.lockClockMaterial === "solid" ? 0 : 1
                            onPicked: i => { if (root.bar) { root.bar.lockClockMaterial = i === 0 ? "solid" : "glass"; root.bar.lockClockStyle = "custom"; } }
                        }
                    }
                    SRow {
                        t: pal; title: root.bar && root.bar.lockClockMaterial === "solid" ? I18n.tr("Brightness") : I18n.tr("Glass")
                        SSlider {
                            t: pal; resetValue: 0.099; width: 220; from: 0; to: 1
                            leftLabel: root.bar && root.bar.lockClockMaterial === "solid" ? I18n.tr("Subtle") : I18n.tr("Clear")
                            rightLabel: root.bar && root.bar.lockClockMaterial === "solid" ? I18n.tr("Bright") : I18n.tr("Frosted")
                            value: root.bar ? root.bar.lockClockIntensity : 0.099
                            onMoved: v => { if (root.bar) { root.bar.lockClockIntensity = v; root.bar.lockClockStyle = "custom"; } }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Color")
                        ColorChoice {
                            t: pal
                            presets: ["#FFFFFF", "#FFE7C2", "#FFC2D6", "#D9C8FF", "#BFE3FF", "#C6F2D6", "#FFF3A8"]
                            current: root.bar ? root.bar.lockClockTint : "#FFFFFF"
                            onPicked: hex => { if (root.bar) root.bar.lockClockTint = hex.toUpperCase(); }
                        }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Date")
                        SSegmented {
                            t: pal
                            model: { var d = new Date(); return [I18n.locale().toString(d, I18n.tr("dddd, MMMM d")), I18n.locale().toString(d, I18n.tr("ddd MMM d"))]; }
                            current: root.bar && root.bar.lockClockDate === "short" ? 1 : 0
                            onPicked: i => { if (root.bar) { root.bar.lockClockDate = i === 1 ? "short" : "long"; root.bar.lockClockStyle = "custom"; } }
                        }
                    }
                }
                Row {
                    x: parent.width - width
                    spacing: 8
                    SButton {
                        t: pal; text: I18n.tr("Preview")
                        onClicked: {
                            var b = root.bar;
                            var cfg = JSON.stringify({ f: b.lockClockFont, w: b.lockClockWeight, m: b.lockClockMaterial, i: b.lockClockIntensity, c: b.lockClockTint, d: b.lockClockDate });
                            Quickshell.execDetached(["sh", "-c", "YUKILOCK_PREVIEW=1 YUKILOCK_CLOCK=\"$1\" timeout 6 qs -c YukiLock >/dev/null 2>&1", "sh", cfg]);
                        }
                    }
                    SButton { t: pal; text: I18n.tr("Lock Screen Now"); onClicked: { prefsWindow.visible = false; Quickshell.execDetached(["sh", "-c", "pgrep -f -- \"-c [Y]ukiLock\" >/dev/null 2>&1 || qs -c YukiLock"]); } }
                }
            }
        }

        Component {
            id: paneUsers
            Column {
                spacing: 12
                Item {
                    width: parent.width; height: 120
                    Item {
                        id: upic
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 84; height: 84
                        Item { id: upMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
                        Rectangle { anchors.fill: parent; radius: width / 2; color: pal.ctrl }
                        Image {
                            anchors.fill: parent; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(200, 200)
                            source: "file://" + Quickshell.env("HOME") + "/.face?" + root.faceVer
                            layer.enabled: true; layer.effect: MultiEffect { maskEnabled: true; maskSource: upMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                        }
                    }
                    Text { anchors.top: upic.bottom; anchors.topMargin: 8; anchors.horizontalCenter: parent.horizontalCenter; text: root.userName; color: pal.text; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.heading; font.weight: Font.DemiBold }
                }
                SCard {
                    t: pal
                    SRow { t: pal; title: I18n.tr("Full name"); Text { text: root.userName; color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text } }
                    SRow { t: pal; title: I18n.tr("Account name"); Text { text: Quickshell.env("USER"); color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text } }
                    SRow { t: pal; title: I18n.tr("Home folder"); Text { text: Quickshell.env("HOME"); color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.text } }
                    SRow {
                        t: pal; title: I18n.tr("Picture")
                        subtitle: I18n.tr("Used on the lock screen and here")
                        SButton {
                            t: pal; text: I18n.tr("Change…")
                            onClicked: root.filePicker.pick({ mode: "image", title: I18n.tr("Choose a picture") }, function (f) { if (f !== "") cropSheet.begin(f); })
                        }
                    }
                }
            }
        }

        Component {
            id: paneKeyboard
            Column {
                spacing: 12
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Key repeat rate")
                        SSlider { t: pal; resetValue: 35; leftLabel: I18n.tr("Slow"); rightLabel: I18n.tr("Fast"); from: 10; to: 80; value: root.bar ? root.bar.kbRepeatRate : 35; onMoved: v => { if (root.bar) root.bar.kbRepeatRate = Math.round(v); } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Delay until repeat")
                        SSlider { t: pal; resetValue: 0.846; leftLabel: I18n.tr("Long"); rightLabel: I18n.tr("Short"); from: 0; to: 1; valueText: v => Math.round(150 + (1 - v) * 650) + " ms"; value: root.bar ? 1 - (root.bar.kbRepeatDelay - 150) / 650 : 0.6; onMoved: v => { if (root.bar) root.bar.kbRepeatDelay = Math.round(150 + (1 - v) * 650); } }
                    }
                }
                SLabel { t: pal; text: I18n.tr("Layout: ") + "us" + ". Changes apply right away." }
                Repeater {
                    model: prefsWindow.shortcutGroups
                    Column {
                        id: scSec
                        required property var modelData
                        width: parent ? parent.width : 0
                        spacing: 12
                        SLabel { t: pal; header: true; text: I18n.tr(scSec.modelData.name) }
                        SCard {
                            t: pal
                            Repeater {
                                model: scSec.modelData.rows
                                SRow {
                                    id: scRow
                                    required property var modelData
                                    readonly property bool recording: prefsWindow.kbCapturing === modelData.desc
                                    readonly property bool canEdit: modelData.editable && prefsWindow.kbCanEdit
                                    t: pal; title: I18n.tr(scRow.modelData.desc); wrapTitle: true
                                    subtitle: scRow.recording ? (prefsWindow.kbMessage !== "" ? prefsWindow.kbMessage : I18n.tr("Press the new shortcut. Esc cancels, Backspace removes it.")) : ""
                                    Row {
                                        spacing: 8
                                        SButton {
                                            visible: scRow.modelData.changed && !scRow.recording
                                            t: pal; glyph: "reset"; tip: I18n.tr("Reset")
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: prefsWindow.kbReset(scRow.modelData.desc)
                                        }
                                        Item {
                                            id: capBox
                                            width: scRow.recording ? recPill.width : capRow.width
                                            height: 28
                                            anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            id: recPill
                                            visible: scRow.recording
                                            height: 28; width: Math.ceil(recText.implicitWidth) + 24; radius: 8
                                            color: pal.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
                                            border.width: 2; border.color: pal.accent
                                            Text {
                                                id: recText
                                                anchors.centerIn: parent
                                                text: I18n.tr("Type the new shortcut…")
                                                color: pal.accent
                                                font.family: root.fontForWeight(Font.Medium, pal.fam); font.pixelSize: pal.fs.control
                                            }
                                        }
                                            // three columns as wide as their widest cap in the whole list (first modifier,
                                            // second modifier, keys), so the caps line up from row to row
                                            Row {
                                                id: capRow
                                                visible: !scRow.recording
                                                spacing: 6
                                                anchors.verticalCenter: parent.verticalCenter
                                                Item {
                                                    width: prefsWindow.kbColW[0]; height: 24
                                                    KCap { t: pal; hot: capMa.containsMouse; label: scRow.modelData.mods.length > 0 ? scRow.modelData.mods[0] : ""; visible: label !== "" }
                                                }
                                                Item {
                                                    width: prefsWindow.kbColW[1]; height: 24
                                                    Row { spacing: 4; Repeater { model: scRow.modelData.mods.slice(1); KCap { required property string modelData; t: pal; hot: capMa.containsMouse; label: modelData } } }
                                                }
                                                Item {
                                                    width: Math.max(prefsWindow.kbColW[2], noneCap.visible ? noneCap.width : 0); height: 24
                                                    Row { spacing: 4; Repeater { model: scRow.modelData.keys; KCap { required property string modelData; t: pal; hot: capMa.containsMouse; label: modelData } } }
                                                    Rectangle {
                                                        id: noneCap
                                                        visible: scRow.modelData.keys.length === 0
                                                        height: 24; width: Math.ceil(noneText.implicitWidth) + 16; radius: 6
                                                        color: "transparent"
                                                        border.width: 1; border.color: pal.cardBorder
                                                        Text { id: noneText; anchors.centerIn: parent; text: I18n.tr("Not set"); color: pal.text3; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc }
                                                    }
                                                }
                                            }
                                        MouseArea {
                                            id: capMa
                                            anchors.fill: parent; anchors.margins: -4
                                            enabled: scRow.canEdit && !scRow.recording
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: prefsWindow.kbStart(scRow.modelData.desc)
                                        }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                SCard {
                    t: pal
                    visible: prefsWindow.kbCanEdit && Object.keys(prefsWindow.kbOverrides).length > 0
                    SRow {
                        t: pal
                        title: I18n.tr("Reset All Shortcuts")
                        subtitle: I18n.tr("Back to the shortcuts this rice comes with")
                        SButton { t: pal; glyph: "reset"; tip: I18n.tr("Reset"); onClicked: prefsWindow.kbWrite({}) }
                    }
                }
                SLabel {
                    t: pal; visible: prefsWindow.shortcuts.length > 0
                    text: prefsWindow.kbCanEdit ? I18n.tr("Click a shortcut to change it. Shortcuts that belong to a group of keys (the workspace numbers, the arrows) and Alt + Tab stay as they are.")
                                                : I18n.tr("Read from Hyprland as it is running. Change them in ~/hypr-yukishell/hypr/scripts/binds.lua and shell.lua.")
                }
                Component.onCompleted: prefsWindow.loadShortcuts()
            }
        }

        Component {
            id: paneMouse
            Column {
                spacing: 12
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Tracking speed")
                        SSlider { t: pal; resetValue: 0; leftLabel: I18n.tr("Slow"); rightLabel: I18n.tr("Fast"); from: -1; to: 1; value: root.bar ? root.bar.mouseSens : 0; onMoved: v => { if (root.bar) root.bar.mouseSens = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Natural scrolling")
                        subtitle: I18n.tr("Content tracks finger movement")
                        SSwitch { t: pal; checked: root.bar ? root.bar.mouseNatural : false; onToggled: v => { if (root.bar) root.bar.mouseNatural = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Mouse acceleration")
                        subtitle: I18n.tr("Faster movements carry the pointer further.")
                        SSwitch { t: pal; checked: root.bar ? root.bar.mouseAccel : true; onToggled: v => { if (root.bar) root.bar.mouseAccel = v; } }
                    }
                }
            }
        }

        Component {
            id: paneCursor
            Column {
                id: curPane
                spacing: 12
                property var themes: []
                property string msg: ""
                readonly property string script: root.bar ? root.bar.cursorScript : ""
                function reload() { curList.running = false; curList.running = true; }
                Process {
                    id: curList
                    command: [curPane.script, "list"]
                    stdout: StdioCollector { onStreamFinished: { try { curPane.themes = JSON.parse(text); } catch (e) {} } }
                }
                Process {
                    id: curInstall
                    property string dir: ""
                    command: [curPane.script, "install", dir]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            var id = text.trim();
                            if (id !== "" && root.bar) { root.bar.cursorTheme = id; curPane.msg = ""; }
                            curPane.reload();
                        }
                    }
                    stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") curPane.msg = I18n.tr("That folder has no cursor theme in it.") }
                }
                Component.onCompleted: reload()

                SLabel { t: pal; header: true; text: I18n.tr("Cursor Theme") }
                SCard {
                    t: pal
                    Flow {
                        id: curFlow
                        width: parent.width
                        padding: 16
                        spacing: 12
                        readonly property int cols: Math.max(1, Math.floor((width - 32 + 12) / (96 + 12)))
                        readonly property int tileW: Math.floor((width - 32 - (cols - 1) * 12) / cols)
                        readonly property int boxH: 2 * Math.round(tileW * 0.36)
                        Repeater {
                            model: curPane.themes
                            delegate: Item {
                                id: ct
                                required property var modelData
                                readonly property bool sel: root.bar && root.bar.cursorTheme === modelData.id
                                width: curFlow.tileW; height: curFlow.boxH + 28
                                Rectangle {
                                    width: parent.width; height: curFlow.boxH
                                    radius: 12
                                    color: ctMa.containsMouse ? pal.buttonPressed : pal.button
                                    border.width: 1
                                    border.color: pal.sep
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Image {
                                        anchors.centerIn: parent
                                        width: 40; height: 40
                                        source: ct.modelData.preview ? "file://" + ct.modelData.preview : ""
                                        visible: source != ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true; mipmap: true
                                        cache: false
                                        scale: ctMa.containsMouse ? 1.12 : 1
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    WGlyph {
                                        anchors.centerIn: parent
                                        visible: !ct.modelData.preview
                                        width: 30; height: 30
                                        kind: "cursor"
                                        color: pal.text2
                                    }
                                }
                                GlassRing { x: -2; y: -2; width: parent.width + 4; height: curFlow.boxH + 4; radius: 14; on: ct.sel; dark: pal.dark }
                                Text {
                                    y: curFlow.boxH + 8
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: ct.modelData.name
                                    elide: Text.ElideRight
                                    color: ct.sel ? pal.text : pal.text2
                                    font.family: root.fontForWeight(ct.sel ? Font.DemiBold : Font.Normal, pal.fam)
                                    font.pixelSize: pal.fs.desc
                                }
                                MouseArea {
                                    id: ctMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: if (root.bar) root.bar.cursorTheme = ct.modelData.id
                                }
                            }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Use a custom cursor")
                        subtitle: curPane.msg !== "" ? curPane.msg : I18n.tr("A downloaded theme folder, or a Windows cursor pack (.cur, .ani, GIF).")
                        SButton {
                            t: pal
                            text: I18n.tr("Add Cursor Theme…")
                            onClicked: root.filePicker.pick({ mode: "folder", title: I18n.tr("Choose a cursor theme folder"), startDir: Quickshell.env("HOME") + "/Downloads" }, function (path) {
                                if (path === "") return;
                                curInstall.dir = path;
                                curInstall.running = true;
                            })
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Size")
                        subtitle: I18n.tr("Apps that are already open pick up the new size when they restart")
                        SSlider {
                            t: pal
                            from: 16; to: 64; stepSize: 4
                            value: root.bar ? root.bar.cursorSize : 24
                            leftLabel: I18n.tr("Small"); rightLabel: I18n.tr("Large")
                            resetValue: 24
                            onMoved: v => { if (root.bar) root.bar.cursorSize = Math.round(v / 4) * 4; }
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Behavior") }
                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Hide while typing")
                        SSwitch { t: pal; checked: root.bar ? root.bar.cursorHideTyping : true; onToggled: v => { if (root.bar) root.bar.cursorHideTyping = v; } }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Hide when idle")
                        subtitle: !root.bar || root.bar.cursorHideIdle < 0.5 ? I18n.tr("Never") : I18n.tr("After %1 s without moving").arg(Math.round(root.bar.cursorHideIdle))
                        SSlider {
                            t: pal
                            from: 0; to: 30; stepSize: 1
                            value: root.bar ? root.bar.cursorHideIdle : 10
                            leftLabel: I18n.tr("Never"); rightLabel: "30 s"
                            resetValue: 10
                            onMoved: v => { if (root.bar) root.bar.cursorHideIdle = Math.round(v); }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Focus follows the mouse")
                        subtitle: I18n.tr("Hovering a window focuses it. Off: click to focus.")
                        SSwitch { t: pal; checked: root.bar ? root.bar.cursorFollowFocus : true; onToggled: v => { if (root.bar) root.bar.cursorFollowFocus = v; } }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Jump to the focused window")
                        subtitle: I18n.tr("Switching workspace moves the pointer onto the window that gets the focus")
                        SSwitch { t: pal; checked: root.bar ? root.bar.cursorWarpWs : false; onToggled: v => { if (root.bar) root.bar.cursorWarpWs = v; } }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Magnifier")
                        subtitle: I18n.tr("Zooms the screen in around the pointer")
                        SSlider {
                            t: pal
                            from: 1; to: 4; stepSize: 0.25
                            value: root.bar ? root.bar.cursorZoom : 1
                            leftLabel: I18n.tr("Off"); rightLabel: "4×"
                            valueSuffix: "×"
                            resetValue: 1
                            onMoved: v => { if (root.bar) root.bar.cursorZoom = Math.round(v * 4) / 4; }
                        }
                    }
                }
            }
        }

        Component {
            id: paneTrackpad
            Column {
                spacing: 12
                SCard {
                    t: pal
                    SRow {
                        t: pal; title: I18n.tr("Tap to click")
                        SSwitch { t: pal; checked: root.bar ? root.bar.tpTap : true; onToggled: v => { if (root.bar) root.bar.tpTap = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Natural scrolling")
                        SSwitch { t: pal; checked: root.bar ? root.bar.tpNatural : true; onToggled: v => { if (root.bar) root.bar.tpNatural = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Ignore trackpad while typing")
                        SSwitch { t: pal; checked: root.bar ? root.bar.tpDwt : true; onToggled: v => { if (root.bar) root.bar.tpDwt = v; } }
                    }
                    SRow {
                        t: pal; title: I18n.tr("Scrolling speed")
                        SSlider { t: pal; resetValue: 0.7; leftLabel: I18n.tr("Slow"); rightLabel: I18n.tr("Fast"); from: 0.2; to: 2; value: root.bar ? root.bar.tpScroll : 0.7; onMoved: v => { if (root.bar) root.bar.tpScroll = v; } }
                    }
                }
            }
        }

        Component {
            id: paneWallpaper
            Column {
                id: wpPane
                spacing: 12
                property int filter: 0
                property string searchText: ""
                readonly property var files: root.bar ? root.bar.wpFiles : []
                readonly property var shown: {
                    var out = [], f = files, q = searchText.trim().toLowerCase();
                    for (var i = 0; i < f.length; i++) {
                        var typeMatch = filter === 0 || (filter === 1 && !f[i].video) || (filter === 2 && f[i].video) || (filter === 3 && f[i].fav);
                        var textMatch = q === "" || f[i].name.toLowerCase().indexOf(q) >= 0;
                        if (typeMatch && textMatch) out.push(f[i]);
                    }
                    return out;
                }
                readonly property string curVideo: root.bar ? root.bar.wallpaperVideo : ""
                readonly property string curStill: root.bar ? root.bar.wallpaperPath : root.wallpaperPath
                readonly property string curPath: curVideo !== "" ? curVideo : curStill
                readonly property string curPreview: (root.bar && curVideo !== "") ? (root.bar.wpPreviews[curVideo] || "") : ""
                function nameOf(p) { var n = p.substring(p.lastIndexOf("/") + 1); var k = n.lastIndexOf("."); return k > 0 ? n.substring(0, k) : n; }
                Component.onCompleted: { if (root.bar) { root.bar.wpPaneOpen = true; root.bar.wpRefresh(); } }
                Component.onDestruction: { if (root.bar) root.bar.wpPaneOpen = false; }

                SCard {
                    t: pal
                    Item {
                        width: parent.width
                        height: 190
                        Item {
                            id: curBox
                            x: 14; y: 14
                            width: 256; height: 160
                            Item {
                                id: curMask
                                anchors.fill: parent; visible: false
                                layer.enabled: true; layer.smooth: true
                                Rectangle { anchors.fill: parent; radius: 10; color: "black" }
                            }
                            Item {
                                anchors.fill: parent
                                layer.enabled: true; layer.smooth: true
                                layer.effect: MultiEffect { maskEnabled: true; maskSource: curMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                                Rectangle { anchors.fill: parent; color: pal.ctrl }
                                Image {
                                    anchors.fill: parent
                                    source: wpPane.curStill !== "" ? "file://" + wpPane.curStill : ""
                                    sourceSize.width: 520
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; smooth: true
                                }
                                Loader {
                                    anchors.fill: parent
                                    active: wpPane.curVideo !== "" && prefsWindow.visible && wpPane.curPreview !== ""
                                    sourceComponent: AnimatedImage {
                                        source: "file://" + wpPane.curPreview
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true; cache: false; playing: true
                                    }
                                }
                            }
                            Rectangle { anchors.fill: parent; radius: 10; color: "transparent"; border.width: 1; border.color: pal.cardBorder }
                        }
                        Column {
                            x: curBox.x + curBox.width + 18
                            anchors.verticalCenter: curBox.verticalCenter
                            width: parent.width - x - 14
                            spacing: 6
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: wpPane.curPath !== "" ? wpPane.nameOf(wpPane.curPath) : I18n.tr("No wallpaper")
                                color: pal.text; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.heading; font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: wpPane.curVideo !== "" ? I18n.tr("Animated wallpaper") : I18n.tr("Picture")
                                color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                visible: wpPane.curVideo !== ""
                                text: I18n.tr("Plays on every display, in the Liquid Glass and on the lock screen.")
                                color: pal.text3; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.caption
                            }
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Wallpaper folders") }
                SCard {
                    t: pal
                    Repeater {
                        model: root.bar ? root.bar.wpDirsEff : []
                        SRow {
                            id: fRow
                            required property string modelData
                            readonly property int n: root.bar && root.bar.wpDirCount[modelData] !== undefined ? root.bar.wpDirCount[modelData] : 0
                            readonly property bool exists: root.bar ? root.bar.wpFolders.indexOf(modelData) >= 0 : false
                            t: pal
                            title: modelData.replace(Quickshell.env("HOME"), "~")
                            subtitle: !exists ? I18n.tr("Folder not found") : n + (n === 1 ? I18n.tr(" image") : I18n.tr(" images"))
                            Row {
                                spacing: 8
                                SButton { t: pal; text: I18n.tr("Open"); onClicked: Quickshell.execDetached(["xdg-open", fRow.modelData]) }
                                SButton {
                                    visible: root.bar && root.bar.wpDirsEff.length > 1
                                    t: pal; text: I18n.tr("Remove")
                                    onClicked: if (root.bar) root.bar.wpRemoveDir(fRow.modelData)
                                }
                            }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Add a folder")
                        subtitle: I18n.tr("Pictures and videos in it and its subfolders are added automatically.")
                        SButton { t: pal; text: I18n.tr("Add Folder\u2026"); onClicked: if (root.bar) root.bar.wpPickFolder() }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Pause behind windows")
                        subtitle: wpPane.curVideo !== "" ? I18n.tr("Stops a video wallpaper while windows cover the desktop.")
                                                         : I18n.tr("Only for a live or animated wallpaper. Set one to change this.")
                        SSwitch {
                            t: pal
                            enabled: wpPane.curVideo !== ""
                            checked: root.bar ? root.bar.wallPauseCovered : false
                            onToggled: v => { if (root.bar) root.bar.wallPauseCovered = v; }
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Animated wallpaper in glass")
                        subtitle: root.bar && root.bar.wallpaperVideo !== "" ? I18n.tr("Plays a video wallpaper inside the glass. Off uses a still frame.")
                                                                           : I18n.tr("Only for a live or animated wallpaper. Set one to change this.")
                        SSwitch {
                            t: pal
                            enabled: root.bar ? root.bar.wallpaperVideo !== "" : false
                            checked: root.bar ? root.bar.liveWallGlass : false
                            onToggled: v => { if (root.bar) root.bar.liveWallGlass = v; }
                        }
                    }
                }

                SCard {
                    t: pal
                    visible: root.bar && root.bar.wpHasPair
                    SRow {
                        t: pal
                        title: I18n.tr("Appearance")
                        subtitle: {
                            var a = root.bar ? root.bar.wallpaperAppearance : "auto";
                            return a === "dynamic" ? I18n.tr("Changes through the day: light by day, dark at night, blending at sunrise and sunset")
                                 : a === "light" ? I18n.tr("Always the light version") : I18n.tr("Always the dark version");
                        }
                        SSegmented {
                            t: pal
                            model: ["Light", "Dark", "Dynamic"]
                            current: ["light", "dark", "dynamic"].indexOf(root.bar && root.bar.wallpaperAppearance !== "auto" ? root.bar.wallpaperAppearance : "dark")
                            onPicked: i => { if (root.bar) root.bar.wallpaperAppearance = ["light", "dark", "dynamic"][i]; }
                        }
                    }
                }

                Item {
                    id: wpHead
                    width: parent.width
                    readonly property real natural: wpFilter.eqWidth * wpFilter.count + 2 * wpFilter.inset
                    readonly property bool stack: wpHeadLbl.implicitWidth + 16 + natural > width
                    height: stack ? wpHeadLbl.height + 8 + wpFilter.height : Math.max(wpHeadLbl.height, wpFilter.height)
                    SLabel {
                        id: wpHeadLbl
                        t: pal; header: true; topPadding: 0
                        width: implicitWidth
                        y: wpHead.stack ? 0 : Math.round((wpHead.height - height) / 2)
                        text: I18n.tr("Wallpapers")
                    }
                    SSegmented {
                        id: wpFilter
                        t: pal
                        // own line: equal segments spanning the page; next to the heading: its natural size, flush right
                        segWidth: wpHead.stack ? Math.max(eqWidth, (wpHead.width - 2 * inset) / count) : -1
                        anchors.right: parent.right
                        y: wpHead.stack ? wpHeadLbl.height + 8 : Math.round((wpHead.height - height) / 2)
                        scale: width > wpHead.width ? wpHead.width / width : 1
                        transformOrigin: Item.TopRight
                        model: ["All", "Pictures", "Animated", "★ Favourites"]
                        current: wpPane.filter
                        onPicked: i => wpPane.filter = i
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 10
                    color: pal.ctrl
                    border.width: 1
                    border.color: wpSearchInput.activeFocus ? pal.accent : pal.cardBorder
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⌕"
                            color: pal.text3
                            font.family: Fonts.forWeight(Font.Normal, pal.fam); font.pixelSize: 19
                        }
                        Item {
                            width: parent.width - 52
                            height: parent.height
                            TextInput {
                                id: wpSearchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: pal.text
                                selectionColor: pal.accent
                                font.family: root.fontForWeight(Font.Normal, pal.fam)
                                font.pixelSize: pal.fs.text
                                clip: true
                                selectByMouse: true
                                onTextChanged: wpPane.searchText = text
                            }
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: I18n.tr("Search wallpapers")
                                color: pal.text3
                                font.family: root.fontForWeight(Font.Normal, pal.fam)
                                font.pixelSize: pal.fs.text
                                visible: wpSearchInput.text === "" && !wpSearchInput.activeFocus
                                MouseArea { anchors.fill: parent; onClicked: wpSearchInput.forceActiveFocus() }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: wpSearchInput.text !== ""
                            text: "×"
                            color: pal.text2
                            font.family: Fonts.forWeight(Font.Normal, pal.fam); font.pixelSize: 18
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                onClicked: { wpSearchInput.clear(); wpSearchInput.forceActiveFocus(); }
                            }
                        }
                    }
                }

                GridView {
                    id: wpFlow
                    width: parent.width
                    cellWidth: Math.floor((width - 20) / 3)
                    cellHeight: Math.round(cellWidth * 0.625) + 32
                    height: Math.min(contentHeight, cellHeight * 3)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: wpPane.shown
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 6
                        background: Rectangle {
                            color: pal.cardBorder
                            radius: 3
                            opacity: 0.45
                        }
                        contentItem: Rectangle {
                            color: pal.text3
                            radius: 3
                        }
                    }
                    delegate: Item {
                            id: wt
                            required property var modelData
                            width: wpFlow.cellWidth
                            height: wpFlow.cellHeight
                            readonly property bool cur: modelData.video ? wpPane.curVideo === modelData.path
                                                                        : (wpPane.curVideo === "" && wpPane.curStill === modelData.path)
                            Item {
                                id: wtBox
                                x: 5; y: 5
                                width: parent.width - 10; height: parent.height - 32
                                scale: wtMa.pressed ? 0.98 : 1
                                Item {
                                    id: wtMask
                                    anchors.fill: parent; visible: false
                                    layer.enabled: true; layer.smooth: true
                                    Rectangle { anchors.fill: parent; radius: 9; color: "black" }
                                }
                                Item {
                                    anchors.fill: parent
                                    layer.enabled: true; layer.smooth: true
                                    layer.effect: MultiEffect { maskEnabled: true; maskSource: wtMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                                    Rectangle { anchors.fill: parent; color: pal.ctrl }
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + (wt.modelData.video ? wt.modelData.thumb : wt.modelData.path)
                                        sourceSize.width: 260
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true; smooth: true
                                        opacity: status === Image.Ready ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                    }
                                    Loader {
                                        anchors.fill: parent
                                        active: wt.modelData.video && wt.modelData.preview !== "" && wtMa.containsMouse
                                        sourceComponent: AnimatedImage {
                                            source: "file://" + wt.modelData.preview
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true; cache: false; playing: true
                                        }
                                    }
                                    Rectangle {
                                        visible: wt.modelData.video
                                        x: 6; y: 6
                                        width: wtBadge.implicitWidth + 12; height: 18; radius: 9
                                        color: Qt.rgba(0, 0, 0, 0.5)
                                        Text {
                                            id: wtBadge
                                            anchors.centerIn: parent
                                            text: I18n.tr("\u25B6  Animated")
                                            color: "white"; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: 9; font.weight: Font.DemiBold
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9
                                    color: "transparent"
                                    border.width: 1
                                    border.color: pal.cardBorder
                                }
                                GlassRing { anchors.fill: parent; anchors.margins: -3; radius: 12; on: wt.cur; dark: pal.dark }
                                MouseArea {
                                    id: wtMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.bar) root.bar.wpApply(wt.modelData.path)
                                }
                                    Rectangle {
                                        anchors.right: parent.right; anchors.top: parent.top
                                        anchors.margins: 8
                                        width: 28; height: 28; radius: 14
                                        visible: wt.modelData.fav || wtMa.containsMouse || wtFavMa.containsMouse
                                        color: Qt.rgba(0, 0, 0, wtFavMa.containsMouse ? 0.72 : 0.52)
                                        Text {
                                            anchors.centerIn: parent
                                            text: wt.modelData.fav ? "★" : "☆"
                                            color: wt.modelData.fav ? "#ffd60a" : "white"
                                            font.family: Fonts.forWeight(Font.Normal, pal.fam); font.pixelSize: 16
                                        }
                                        MouseArea {
                                            id: wtFavMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: if (root.bar) root.bar.wpToggleFav(wt.modelData.path)
                                        }
                                    }
                            }
                            Text {
                                anchors.bottom: parent.bottom
                                x: 5
                                width: parent.width - 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideMiddle
                                text: wt.modelData.name
                                color: wt.cur ? pal.text : pal.text2
                                font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.caption
                            }
                    }
                }
                SLabel {
                    t: pal
                    visible: wpPane.shown.length === 0
                    text: wpPane.searchText.trim() !== "" ? I18n.tr("No wallpapers match “") + wpPane.searchText + "”."
                        : wpPane.filter === 2 ? I18n.tr("No animated wallpapers yet. Drop .mp4 / .webm videos into ") + (root.bar ? root.bar.wpDirEff : "~/Pictures/Wallpapers") + "."
                                              : I18n.tr("Nothing here yet.")
                }
                SLabel { t: pal; text: I18n.tr("Ctrl+Alt+W opens the quick wallpaper picker.") }
            }
        }

        Component {
            id: paneAbout
            Column {
                id: aboutCol
                spacing: 12
                readonly property string ghUser: "xuefeng1331"
                readonly property string ghName: "雪風"
                readonly property string repoUrl: "https://github.com/" + ghUser + "/YukiShell"

                SCard {
                    t: pal
                    Item {
                        width: parent.width
                        height: 176
                        Image {
                            x: (parent.width - width) / 2
                            y: 18
                            width: 80; height: 80
                            source: Qt.resolvedUrl("assets/yukishell-logo.png")
                            sourceSize: Qt.size(240, 240)
                            smooth: true; mipmap: true
                        }
                        Text {
                            y: 110
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "YukiShell " + Version.label
                            color: pal.text
                            font.family: root.fontForWeight(Font.DemiBold, pal.fam)
                            font.pixelSize: pal.fs.display
                            font.weight: Font.DemiBold
                        }
                        Text {
                            y: 140
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: I18n.tr("Hyprland \u2022 Quickshell \u2022 Catppuccin Mocha")
                            color: pal.text2
                            font.family: root.fontForWeight(Font.Normal, pal.fam)
                            font.pixelSize: pal.fs.desc
                        }
                    }
                }

                SLabel { t: pal; header: true; text: I18n.tr("Forked by") }
                SCard {
                    t: pal
                    Item {
                        width: parent.width; height: 88
                        Item {
                            id: gpPic
                            x: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 56; height: 56
                            Item { id: gpMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
                            Image {
                                anchors.fill: parent
                                source: Qt.resolvedUrl("assets/credits/xuefeng1331.jpg")
                                sourceSize: Qt.size(112, 112)
                                fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true
                                layer.enabled: true
                                layer.effect: MultiEffect { maskEnabled: true; maskSource: gpMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                            }
                            Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1; border.color: pal.cardBorder }
                        }
                        Column {
                            x: 86; anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { text: aboutCol.ghName; color: pal.text; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.heading; font.weight: Font.DemiBold }
                            Text { text: "@" + aboutCol.ghUser; color: pal.accent; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc }
                            Text { text: "github.com/" + aboutCol.ghUser; color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.caption }
                        }
                        SButton {
                            t: pal
                            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("View Profile")
                            onClicked: root.openUrl("https://github.com/" + aboutCol.ghUser)
                        }
                    }
                }

                SCard {
                    t: pal
                    SRow {
                        t: pal
                        title: I18n.tr("Source code")
                        subtitle: "github.com/" + aboutCol.ghUser + "/YukiShell"
                        SButton {
                            t: pal
                            text: I18n.tr("Open")
                            onClicked: root.openUrl(aboutCol.repoUrl)
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Rice")
                        subtitle: "~/hypr-yukishell"
                        SButton {
                            t: pal
                            text: I18n.tr("Open")
                            onClicked: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/hypr-yukishell"])
                        }
                    }
                    SRow {
                        t: pal
                        title: I18n.tr("Shell settings")
                        subtitle: "~/.config/yukidock"
                        SButton {
                            t: pal
                            text: I18n.tr("Open")
                            onClicked: Quickshell.execDetached(["xdg-open", root.configDir])
                        }
                    }
                }

                // --- Credits: YukiShell is a fork of MacShell ---
                SLabel { t: pal; header: true; text: I18n.tr("Based on MacShell") }
                SCard {
                    t: pal
                    Repeater {
                        model: [
                            { img: "assets/credits/0-ss.jpg", name: "Rickky", gh: "0-ss",
                              role: "Original author of MacShell: the menu bar, the Dock, the Liquid Glass and the widgets" },
                            { img: "assets/credits/vsoultann.png", name: "vSuol", gh: "vsoultann",
                              role: "Contributor to MacShell: the Settings app" }
                        ]
                        delegate: Item {
                            id: cr
                            required property var modelData
                            width: parent.width; height: Math.max(88, crCol.height + 28)
                            Rectangle { visible: cr.y > 0.5; x: 16; width: parent.width - 16; height: 1; color: pal.sep }
                            Item {
                                id: crPic
                                x: 16; anchors.verticalCenter: parent.verticalCenter
                                width: 56; height: 56
                                Item { id: crMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: width / 2; color: "black" } }
                                Image {
                                    anchors.fill: parent
                                    source: Qt.resolvedUrl(cr.modelData.img)
                                    sourceSize: Qt.size(112, 112)
                                    fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true
                                    layer.enabled: true
                                    layer.effect: MultiEffect { maskEnabled: true; maskSource: crMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                                }
                                Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1; border.color: pal.cardBorder }
                            }
                            Column {
                                id: crCol
                                x: 86; anchors.verticalCenter: parent.verticalCenter
                                width: crBtn.x - 14 - x
                                spacing: 2
                                Text { text: cr.modelData.name; color: pal.text; font.family: root.fontForWeight(Font.DemiBold, pal.fam); font.pixelSize: pal.fs.heading; font.weight: Font.DemiBold }
                                Text { text: "@" + cr.modelData.gh; color: pal.accent; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.desc }
                                Text { width: parent.width; text: I18n.tr(cr.modelData.role); wrapMode: Text.WordWrap; color: pal.text2; font.family: root.fontForWeight(Font.Normal, pal.fam); font.pixelSize: pal.fs.caption }
                            }
                            SButton {
                                id: crBtn
                                t: pal
                                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("View Profile")
                                onClicked: root.openUrl("https://github.com/" + cr.modelData.gh)
                            }
                        }
                    }
                    SRow {
                        t: pal
                        title: "MacShell"
                        subtitle: I18n.tr("MIT licence \u2022 github.com/0-ss/MacShell")
                        SButton {
                            t: pal
                            text: I18n.tr("Open")
                            onClicked: root.openUrl("https://github.com/0-ss/MacShell")
                        }
                    }
                }
            }
        }
    }

    function openUrl(u) { if (bar && bar.openUrl) bar.openUrl(u); else Quickshell.execDetached(["xdg-open", u]); }
    readonly property real effMag: magnificationEnabled ? magnification : 1
    readonly property int bgHeight: iconSize + topPad + bottomPad
    readonly property int sepWidth: 9
    readonly property real magRadius: (iconSize + spacing) * 2.6
    readonly property int menuRoom: 300
    readonly property int windowHeight: Math.ceil(margin + bgHeight + iconSize * (effMag - 1) + 72 + menuRoom)
    readonly property string configDir: Quickshell.env("HOME") + "/.config/yukidock"

    property var items: []
    property int appCount: 0
    property int sepCount: 0
    readonly property real totalW0: Math.max(0, appCount * (iconSize + spacing) + sepCount * (sepWidth + spacing) - spacing)
    property var launching: ({})
    property var knownKeys: ({})
    property var itemMap: ({})
    ListModel { id: dockModel }
    function syncModel(list) {
        var m = dockModel;
        for (var i = 0; i < list.length; i++) {
            var k = list[i].key;
            if (i < m.count && m.get(i).key === k) continue;
            var j = -1;
            for (var x = i + 1; x < m.count; x++) if (m.get(x).key === k) { j = x; break; }
            if (j >= 0) m.move(j, i, 1); else m.insert(i, { key: k });
        }
        while (m.count > list.length) m.remove(m.count - 1);
    }
    property var leaving: ({})
    readonly property int leaveMs: 340
    Timer { id: leaveTimer; interval: root.leaveMs + 30; onTriggered: root.rebuild() }
    property string lastSig: ""

    function openPrefs(pane) {
        if (!settingsEnabled) return;
        var i = prefsWindow.paneIndex(pane !== undefined && pane !== "" ? pane : "general");
        if (!prefsWindow.visible) prefsWindow.start(i >= 0 ? i : prefsWindow.paneIndex("general"));
        else if (i >= 0) prefsWindow.go(i);
        prefsWindow.visible = true;
        prefsWindow.requestActivate();
    }

    function shotPrefs(path) {
        var f = prefsWindow.contentItem;
        if (!prefsWindow.visible || !f) return;
        f.grabToImage(function (img) { img.saveToFile(path); });
    }

    function togglePrefs(pane) {
        if (prefsWindow.visible) prefsWindow.visible = false;
        else openPrefs(pane);
    }

    function isPinned(id) {
        var k = String(id).replace(/\.desktop$/, "").toLowerCase();
        for (var i = 0; i < pinned.length; i++)
            if (String(pinned[i]).replace(/\.desktop$/, "").toLowerCase() === k) return true;
        return false;
    }
    function pinId(id) {
        if (!id || isPinned(id)) return;
        var out = pinned.slice();
        out.push(String(id));
        pinned = out;
        store.setText(JSON.stringify(out, null, 2));
        rebuild();
    }

    function addCustomApp(name, cmd, icon, term) {
        customApp.command = ["sh", "-c", [
            'd="${XDG_DATA_HOME:-$HOME/.local/share}/applications"; mkdir -p "$d" || exit 1',
            'name=$(printf %s "$1" | tr -d "\r\n"); cmd=$(printf %s "$2" | tr -d "\r\n" | sed "s/%/%%/g"); icon=$(printf %s "$3" | tr -d "\r\n")',
            'slug=$(printf %s "$name" | tr "A-Z" "a-z" | tr -c "a-z0-9" "-" | sed "s/--*/-/g; s/^-//; s/-$//" | cut -c1-32)',
            '[ -n "$slug" ] || slug=app',
            'id="yuki-custom-$slug"; n=2; while [ -e "$d/$id.desktop" ]; do id="yuki-custom-$slug-$n"; n=$((n + 1)); done',
            '{ printf "[Desktop Entry]\nType=Application\nName=%s\nExec=%s\n" "$name" "$cmd"; [ -n "$icon" ] && printf "Icon=%s\n" "$icon"; printf "Terminal=%s\nCategories=Utility;\nX-YukiShell-Custom=true\n" "$4"; } > "$d/$id.desktop.tmp" \\',
            '  && mv -f "$d/$id.desktop.tmp" "$d/$id.desktop" && echo "$id"'
        ].join("\n"), "sh", name, cmd, icon, term ? "true" : "false"];
        customApp.running = true;
    }
    Process {
        id: customApp
        stdout: StdioCollector { onStreamFinished: { var id = text.trim(); if (/^yuki-custom-[a-z0-9-]+$/.test(id)) root.pinId(id); } }
    }

    readonly property string settingsSig: [dockEnabled, settingsEnabled, iconSize, magnification, magnificationEnabled, spacing, margin,
        cornerRadius, glassOpacity, glassBlur, glassLiquid, dockStyle, wallpaperPath, String(accent), accentUi, fontFamily, hideMode, hideDelay, monitor,
        showSettings, showLabels, showIndicators, bounceOnLaunch, showThumbs, windowCapture, glassLive, iconTint, iconTintColor, iconTintStrength, pickerThumb].join("|")
    property bool settingsReady: false
    onSettingsSigChanged: if (settingsReady) saveTimer.restart()
    onShowSettingsChanged: rebuild()
    onSettingsEnabledChanged: rebuild()
    onShowThumbsChanged: rebuild()
    onWindowCaptureChanged: rebuild()

    function saveSettings() {
        var o = {
            dockEnabled: dockEnabled, settingsEnabled: settingsEnabled, iconSize: iconSize, magnification: magnification, magnificationEnabled: magnificationEnabled,
            spacing: spacing, margin: margin, cornerRadius: cornerRadius,
            glassOpacity: glassOpacity, dockStyle: dockStyle, wallpaperPath: wallpaperPath, glassDebug: glassDebug,
            glassRim: glassRim, glassGrain: glassGrain, glassLiquid: glassLiquid, glassBlur: glassBlur,
            accent: String(accent), accentUi: accentUi, fontFamily: fontFamily,
            hideMode: hideMode, hideDelay: hideDelay, monitor: monitor,
            showSettings: showSettings, showLabels: showLabels, showIndicators: showIndicators,
            bounceOnLaunch: bounceOnLaunch, showThumbs: showThumbs, windowCapture: windowCapture, glassLive: glassLive,
            iconTint: iconTint, iconTintColor: iconTintColor, iconTintStrength: iconTintStrength, pickerThumb: pickerThumb
        };
        settingsStore.setText(JSON.stringify(o, null, 2));
    }

    function applySettings(o) {
        if (!o || typeof o !== "object") return;
        var keys = ["dockEnabled", "settingsEnabled", "iconSize", "magnification", "magnificationEnabled", "spacing", "margin", "cornerRadius",
                    "glassOpacity", "dockStyle", "wallpaperPath", "glassDebug", "glassRim", "glassGrain", "glassLiquid", "glassBlur", "accent", "accentUi", "fontFamily", "hideMode", "hideDelay", "monitor",
                    "showSettings", "showLabels", "showIndicators", "bounceOnLaunch", "showThumbs", "windowCapture", "glassLive", "iconTint", "iconTintColor", "iconTintStrength", "pickerThumb"];
        for (var i = 0; i < keys.length; i++) {
            if (o[keys[i]] === undefined) continue;
            try { root[keys[i]] = o[keys[i]]; } catch (err) { }
        }
    }

    FileView {
        id: settingsStore
        path: root.configDir + "/settings.json"
        printErrors: false
        onLoaded: {
            try { root.applySettings(JSON.parse(text())); } catch (err) { }
            root.settingsReady = true;
            if (root.dockStyle === "liquid") root.startGlass();
        }
        onLoadFailed: root.settingsReady = true
    }
    Timer { id: saveTimer; interval: 400; onTriggered: root.saveSettings() }

    readonly property string logoPath: decodeURIComponent(String(Qt.resolvedUrl("assets/yukishell-logo.png")).replace(/^file:\/\//, ""))
    function isShellApp(appId) { return appId === "org.quickshell"; }

    function lookup(appId) {
        if (!appId) return null;
        var e = (root.hub && root.hub.steamEntry(appId)) || DesktopEntries.byId(appId);
        if (!e && DesktopEntries.heuristicLookup) e = DesktopEntries.heuristicLookup(appId);
        return e;
    }

    function keyOf(appId) {
        var e = lookup(appId);
        return (e ? e.id : appId).toLowerCase();
    }

    property var winIdList: []
    property int winIdNext: 1
    function winIdFor(tl) {
        for (var i = 0; i < winIdList.length; i++) if (winIdList[i].tl === tl) return winIdList[i].id;
        var id = winIdNext++;
        winIdList.push({ tl: tl, id: id, born: Date.now() });
        return id;
    }
    function winAge(tl) {
        for (var i = 0; i < winIdList.length; i++) if (winIdList[i].tl === tl) return Date.now() - winIdList[i].born;
        return 0;
    }
    Timer { id: youngWin; interval: 250; onTriggered: root.rebuild() }

    function iconSrc(icon) {
        if (!icon) return Quickshell.iconPath("application-x-executable");
        if (icon.charAt(0) === "/") return "file://" + icon;
        return Quickshell.iconPath(icon, "application-x-executable");
    }
    function cellIconSrc(it) { return iconSrc(it ? it.icon : ""); }

    property int windowTick: 0
    Timer { id: tickDebounce; interval: 120; onTriggered: root.windowTick++ }

    function thumbWindow(key) {
        var w = windowsFor(key);
        for (var i = 0; i < w.length; i++) if (w[i].activated) return w[i];
        return w.length > 0 ? w[0] : null;
    }

    function appOf(tl) { return (tl.appId === "org.quickshell" && tl.title === "Clock") ? "yukishell-clock" : tl.appId; }
    function windowsFor(key) {
        var out = [];
        var tls = ToplevelManager.toplevels.values;
        for (var i = 0; i < tls.length; i++) {
            if (tls[i].appId && keyOf(appOf(tls[i])) === key) out.push(tls[i]);
        }
        return out;
    }

    function activate(item, forceNew, floating) {
        if (item.kind === "win") { if (item.tl) item.tl.activate(); return; }
        if (item.special === "settings") { root.openPrefs("general"); return; }
        var wins = windowsFor(item.key);
        if (wins.length > 0 && !forceNew) {
            var idx = -1;
            for (var i = 0; i < wins.length; i++) if (wins[i].activated) idx = i;
            wins[(idx + 1) % wins.length].activate();
            return;
        }
        if (item.entry || item.key) {
            var L = {};
            for (var k in launching) L[k] = launching[k];
            L[item.key] = Date.now();
            launching = L;
            var ent = null;
            var rid = item.appId || item.key;
            try { ent = DesktopEntries.byId(rid); } catch (err) { ent = null; }
            if (!ent) { try { ent = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(item.key) : null; } catch (err2) { ent = null; } }
            var ok = false;
            var la = ent ? Launch.argv(ent, floating === true, root.bar ? root.bar.terminal : "kitty") : null;
            if (la) { Quickshell.execDetached(la); ok = true; }
            else if (ent && typeof ent.execute === "function") { try { ent.execute(); ok = true; } catch (err3) { ok = false; } }
            if (!ok) {
                var id = rid;
                console.log("[yukidock] launching", id, "via gtk-launch (desktop entry unavailable)");
                Quickshell.execDetached(["sh", "-c", 'gtk-launch "$1" 2>/dev/null || gtk-launch "$1.desktop" 2>/dev/null || exec "$1"', "sh", id]);
            }
            pruneTimer.restart();
        }
    }

    function togglePin(item) {
        var out = [], found = false;
        for (var i = 0; i < pinned.length; i++) {
            var id = String(pinned[i]).replace(/\.desktop$/, "");
            if (id.toLowerCase() === item.key) { found = true; continue; }
            out.push(pinned[i]);
        }
        if (!found && item.entry) out.push(item.entry.id);
        pinned = out;
        store.setText(JSON.stringify(out, null, 2));
        rebuild();
        if (found && item.entry && /^yuki-custom-[a-z0-9-]+$/.test(String(item.entry.id)))
            Quickshell.execDetached(["sh", "-c", 'rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$1.desktop"', "sh", String(item.entry.id)]);
    }

    function reorderPinned(from, to) {
        var vis = [];
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            if (it.kind === "app" && it.pinned && !it.special) vis.push(it);
            else break;
        }
        if (from < 0 || from >= vis.length) return;
        var moved = vis.splice(from, 1)[0];
        vis.splice(Math.max(0, Math.min(to, vis.length)), 0, moved);

        var out = [], have = {};
        for (var v = 0; v < vis.length; v++) { out.push(vis[v].entry.id); have[vis[v].key] = true; }
        for (var p = 0; p < pinned.length; p++) {
            var id = String(pinned[p]).replace(/\.desktop$/, "");
            if (!have[id.toLowerCase()]) out.push(pinned[p]);
        }
        pinned = out;
        store.setText(JSON.stringify(out, null, 2));
        rebuild();
    }

    function menuFor(item) {
        var m = [];
        if (item.kind === "win") {
            m.push({ kind: "item", label: I18n.tr("Show"), run: function () { activate(item, false); } });
            m.push({ kind: "item", label: I18n.tr("Close"), run: function () { if (item.tl) item.tl.close(); } });
            m.push({ kind: "sep" });
            m.push({ kind: "item", label: I18n.tr("Settings\u2026"), run: function() { root.openPrefs(); } });
            return m;
        }
        if (item.special === "settings") {
            m.push({ kind: "item", label: I18n.tr("Open"), run: function () { activate(item, false); } });
            m.push({ kind: "item", label: I18n.tr("Desktop & Dock") + "\u2026", run: function () { root.openPrefs("dock"); } });
            return m;
        }
        var wins = windowsFor(item.key);
        if (wins.length > 0) {
            for (var i = 0; i < wins.length && i < 8; i++) {
                (function (w) {
                    var t = w.title && w.title.length > 0 ? w.title : item.name;
                    m.push({ kind: "item", label: (w.activated ? "\u2713  " : "") + t,
                             run: function () { w.activate(); } });
                })(wins[i]);
            }
            m.push({ kind: "sep" });
        }
        if (item.entry) {
            m.push({ kind: "item", label: item.pinned ? I18n.tr("Remove from Dock") : I18n.tr("Keep in Dock"),
                     run: function () { togglePin(item); } });
            m.push({ kind: "item", label: wins.length > 0 ? I18n.tr("New Window") : I18n.tr("Open"),
                     run: function () { activate(item, true); } });
            m.push({ kind: "item", label: wins.length > 0 ? I18n.tr("New Floating Window") : I18n.tr("Open Floating"),
                     run: function () { activate(item, true, true); } });
        }
        if (wins.length > 0) {
            m.push({ kind: "sep" });
            m.push({ kind: "item", label: I18n.tr("Quit"), run: function () {
                var ws = windowsFor(item.key);
                for (var j = 0; j < ws.length; j++) ws[j].close();
            } });
        }
        
        m.push({ kind: "sep" });
        m.push({ kind: "item", label: I18n.tr("Settings\u2026"), run: function() { root.openPrefs(); } });

        return m;
    }

    function rebuild() {
        var tls = ToplevelManager.toplevels.values;
        var running = {};
        var runOrder = [];
        for (var i = 0; i < tls.length; i++) {
            var id = appOf(tls[i]);
            if (!id) continue;
            var k = keyOf(id);
            if (!running[k]) { running[k] = true; runOrder.push({ key: k, appId: id }); }
        }

        var L = {}, now = Date.now(), changed = false;
        for (var lk in launching) {
            if (!running[lk] && now - launching[lk] < 8000) L[lk] = launching[lk];
            else changed = true;
        }
        if (changed) launching = L;

        var list = [], seen = {};
        for (var p = 0; p < pinned.length; p++) {
            var e = DesktopEntries.byId(String(pinned[p]).replace(/\.desktop$/, ""));
            if (!e) continue;
            var ek = e.id.toLowerCase();
            if (seen[ek]) continue;
            seen[ek] = true;
            list.push({ kind: "app", key: ek, appId: e.id, name: e.name, icon: e.icon, entry: e,
                        running: !!running[ek], pinned: true });
        }

        var extras = [];
        for (var r = 0; r < runOrder.length; r++) if (!seen[runOrder[r].key]) extras.push(runOrder[r]);
        if (extras.length > 0 && list.length > 0) list.push({ kind: "sep", key: "sep:run" });
        for (var x = 0; x < extras.length; x++) {
            var e2 = lookup(extras[x].appId);
            var own = isShellApp(extras[x].appId);
            list.push({ kind: "app", key: extras[x].key, appId: e2 ? e2.id : extras[x].appId,
                        name: own ? "YukiShell" : (e2 ? e2.name : extras[x].appId),
                        icon: own ? logoPath : (e2 ? e2.icon : extras[x].appId.toLowerCase()),
                        entry: e2, running: true, pinned: false });
        }

        var winItems = [], liveWins = [];
        if (showThumbs) {
            for (var w = 0; w < tls.length; w++) {
                var tl = tls[w];
                if (!tl.appId || tl.title === "YukiShell Settings") continue;
                if (!windowCapture && seen[keyOf(appOf(tl))]) continue;
                var e3 = lookup(appOf(tl));
                var wid = winIdFor(tl);
                liveWins.push(tl);
                if (winAge(tl) < 200) { if (!youngWin.running) youngWin.start(); continue; }
                var own3 = isShellApp(tl.appId);
                winItems.push({ kind: "win", key: "win:" + wid, tl: tl,
                                name: own3 ? (tl.title || "YukiShell") : (e3 ? e3.name : tl.appId),
                                icon: own3 ? logoPath : (e3 ? e3.icon : tl.appId.toLowerCase()),
                                entry: null, running: false, pinned: false });
            }
        }
        var keep = [];
        for (var wi = 0; wi < winIdList.length; wi++) if (liveWins.indexOf(winIdList[wi].tl) >= 0) keep.push(winIdList[wi]);
        winIdList = keep;

        if (showSettings || winItems.length > 0) {
            list.push({ kind: "sep", key: "sep:win" });
            for (var wj = 0; wj < winItems.length; wj++) list.push(winItems[wj]);
        }
        if (showSettings && winItems.length > 0) list.push({ kind: "sep", key: "sep:settings" });
        if (showSettings && settingsEnabled) {
            list.push({ kind: "app", key: "__settings", name: "YukiShell", icon: logoPath,
                        entry: null, running: false, pinned: true, special: "settings" });
        }

        var firstBuild = (lastSig === "");
        var liveKeys = {};
        for (var lq = 0; lq < list.length; lq++) if (list[lq].key) liveKeys[list[lq].key] = true;
        var LV = {};
        for (var lk2 in leaving) if (!liveKeys[lk2] && now - leaving[lk2] < leaveMs) LV[lk2] = leaving[lk2];
        if (!firstBuild) {
            var prev = items || [];
            for (var pv = 0; pv < prev.length; pv++) {
                var po = prev[pv];
                if (!po.key || liveKeys[po.key]) continue;
                if (LV[po.key] === undefined) { if (po.leaving) continue; LV[po.key] = now; }
                var at = 0;
                for (var pb = pv - 1; pb >= 0; pb--) {
                    var ix = -1;
                    for (var q = 0; q < list.length; q++) if (list[q].key === prev[pb].key) { ix = q; break; }
                    if (ix >= 0) { at = ix + 1; break; }
                }
                var cp = {};
                for (var f in po) cp[f] = po[f];
                cp.leaving = true; cp.leaveAt = LV[po.key]; cp.fresh = false;
                cp.tl = null;
                list.splice(at, 0, cp);
            }
        }
        leaving = LV;
        var anyLeaving = false;
        for (var lk3 in LV) { anyLeaving = true; break; }
        if (anyLeaving) leaveTimer.restart();

        var nowKeys = {}, nA = 0, nS = 0, sig = [];
        for (var n = 0; n < list.length; n++) {
            var it = list[n];
            it.nA = nA; it.nS = nS;
            if (it.kind === "sep") nS++; else nA++;
            if (it.key && !it.leaving) {
                it.fresh = !firstBuild && !knownKeys[it.key];
                nowKeys[it.key] = true;
            }
            sig.push(it.kind + ":" + (it.key || "") + ":" + it.running + ":" + (it.icon || "") + (it.leaving ? ":L" : ""));
        }
        appCount = nA;
        sepCount = nS;
        knownKeys = nowKeys;

        var s = sig.join("|");
        if (s !== lastSig) {
            lastSig = s;
            var map = {};
            for (var mi = 0; mi < list.length; mi++) map[list[mi].key] = list[mi];
            itemMap = map;
            items = list;
            syncModel(list);
        }
    }

    property string glassState: "idle"
    readonly property bool liquidBase: dockStyle === "liquid" && glassState === "ready" && !(bar && bar.gaming)
    property bool glassWarm: false
    readonly property bool glassWarmWanted: liquidBase && (!hub || hub.wallpaperReady)
    onGlassWarmWantedChanged: { if (glassWarmWanted) glassWarmT.restart(); else { glassWarmT.stop(); glassWarm = false; } }
    Timer { id: glassWarmT; interval: 350; onTriggered: root.glassWarm = true }
    readonly property bool liquidActive: liquidBase && glassWarm
    readonly property bool settingsGlass: glassState === "ready" && !(bar && bar.gaming)
    readonly property string glassShaderSrc: decodeURIComponent(Qt.resolvedUrl("liquidglass.frag").toString().replace("file://", ""))
    readonly property string glassShaderOut: configDir + "/liquidglass.frag.qsb"
    readonly property url glassShaderUrl: "file://" + glassShaderOut

    onDockStyleChanged: if (dockStyle === "liquid") startGlass()
    onGlassStateChanged: console.log("[yukidock-glass] state:", glassState)
    function startGlass() {
        if (dockGlassState === "idle" || dockGlassState === "failed") {
            dockGlassState = "building";
            dockQsbProc.running = true;
        }
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
            + "exit 1",
            "sh", root.glassShaderSrc, root.glassShaderOut]
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[yukidock-glass] qsb:", text.trim()) }
        onExited: (code, status) => root.glassState = (code === 0 ? "ready" : "failed")
    }

    property string dockGlassState: "idle"
    readonly property bool dockGlassNew: dockGlassState === "ready"
    readonly property string dockGlassSrc: decodeURIComponent(Qt.resolvedUrl("dockglass.frag").toString().replace("file://", ""))
    readonly property string dockGlassOut: configDir + "/dockglass.frag.qsb"
    readonly property url dockGlassUrl: dockGlassNew ? "file://" + dockGlassOut : glassShaderUrl
    Process {
        id: dockQsbProc
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\"; "
            + "[ -s \"$2\" ] && [ \"$2\" -nt \"$1\" ] && exit 0; "
            + "for q in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb /usr/lib/qt/bin/qsb; do "
            + "  if command -v \"$q\" >/dev/null 2>&1; then \"$q\" --qt6 -o \"$2\" \"$1\" && exit 0; fi; "
            + "done; "
            + "[ -f \"$1.qsb\" ] && cp \"$1.qsb\" \"$2\" && exit 0; "
            + "exit 1",
            "sh", root.dockGlassSrc, root.dockGlassOut]
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[yukidock-glass] dockglass qsb:", text.trim()) }
        onExited: (code, status) => root.dockGlassState = (code === 0 ? "ready" : "failed")
    }

    readonly property var wallpaperMap: hub ? hub.wallpaperMap : ({})
    Binding { target: root.hub; property: "dockWantsWallpaper"; value: root.liquidBase }
    onWallpaperMapChanged: console.log("[yukidock-glass] wallpaper sources:", JSON.stringify(wallpaperMap))
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

    readonly property var glassClients: hub ? hub.glassClients : []
    Binding { target: root.hub; property: "dockWantsGeo"; value: root.dockEnabled || prefsWindow.visible }

    readonly property var monData: hub ? hub.monData : []
    function computeBusy(mons, clients, anyWin) {
        var busy = {};
        if (!Array.isArray(mons) || !Array.isArray(clients)) return busy;
        for (var m = 0; m < mons.length; m++) {
            var mon = mons[m];
            if (!mon || mon.id === undefined || !mon.name) continue;
            var ids = [mon.activeWorkspace && mon.activeWorkspace.id !== undefined ? mon.activeWorkspace.id : -999];
            if (mon.specialWorkspace && mon.specialWorkspace.id !== undefined && mon.specialWorkspace.id !== 0) ids.push(mon.specialWorkspace.id);
            for (var c = 0; c < clients.length; c++) {
                var cl = clients[c];
                if (!cl || (cl.floating && !anyWin) || !cl.mapped || cl.hidden) continue;
                if (cl.monitor !== mon.id) continue;
                if (!cl.workspace || cl.workspace.id === undefined) continue;
                if (ids.indexOf(cl.workspace.id) >= 0) { busy[mon.name] = true; break; }
            }
        }
        return busy;
    }
    readonly property var busyMonitors: computeBusy(hub ? hub.monData : [], hub ? hub.glassClients : [], hideMode === "windows")
    Connections {
        target: Hyprland
        function onRawEvent(event) { tickDebounce.restart(); }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", configDir]);
        rebuild();
    }

    FileView {
        id: store
        path: root.configDir + "/pinned.json"
        printErrors: false
        onLoaded: {
            try {
                var a = JSON.parse(text());
                if (Array.isArray(a)) { root.pinned = a; root.rebuild(); }
            } catch (err) { }
        }
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { root.rebuild(); settle.restart(); tickDebounce.restart(); }
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.rebuild(); }
    }
    Timer { id: settle; interval: 350; onTriggered: root.rebuild() }
    Timer { id: pruneTimer; interval: 8200; onTriggered: root.rebuild() }

    Variants {
        model: (root.settingsReady && root.dockEnabled) ? Quickshell.screens : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.monitor === "" || modelData.name === root.monitor

            anchors { left: true; right: true; bottom: true }
            implicitHeight: root.windowHeight
            color: "transparent"

            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.hideMode === "never" ? root.bgHeight + root.margin : 0

            WlrLayershell.namespace: "yukidock"
            WlrLayershell.layer: WlrLayer.Top

            mask: Region { item: maskItem }

            PanelWindow {
                id: tearWin
                screen: win.modelData
                visible: ui.tearing || tearLaunch.running || tearHome.running || ghostFade.running || oldOut.running
                anchors { left: true; right: true; top: true; bottom: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                mask: Region {}
                WlrLayershell.namespace: "yukidock-drag"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                Item {
                    id: oldSnap
                    property bool shown: false
                    visible: shown && opacity > 0.01
                    opacity: 0
                    transformOrigin: Item.Center
                    RectangularShadow { anchors.fill: parent; radius: 10; blur: 30; offset.y: 8; color: Qt.rgba(0, 0, 0, 0.30) }
                    Rectangle { anchors.fill: parent; radius: 10; color: Qt.rgba(0.09, 0.08, 0.09, 0.88) }
                    ScreencopyView {
                        id: oldSv
                        anchors.fill: parent
                        live: false
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: oldMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                    }
                    Item { id: oldMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: 10; color: "black" } }
                    ParallelAnimation {
                        id: oldOut
                        NumberAnimation { target: oldSnap; property: "opacity"; from: 1; to: 0; duration: 340; easing.type: Easing.OutCubic }
                        NumberAnimation { target: oldSnap; property: "scale"; from: 1; to: 0.94; duration: 420; easing.type: Easing.OutQuint }
                        onFinished: { oldSnap.shown = false; oldSv.captureSource = null; }
                    }
                }
                Item {
                    id: tearGhost
                    property real zoom: 1
                    property real wob: 0
                    readonly property bool isWin: ui.tearItem !== null && ui.tearItem.kind === "win"
                    readonly property real liftRaw: isWin ? Math.max(0, Math.min(1, (ui.activeTop - ui.tearY) / 240)) : 0
                    property real lift: 1 - Math.pow(1 - liftRaw, 3)
                    Behavior on lift { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    readonly property real thumbW: 170
                    readonly property real liftW: thumbW + (ui.tearW - thumbW) * lift
                    readonly property real grabFy: 0.5 + (0.035 - 0.5) * lift
                    readonly property real offY: tearWin.height - win.height
                    visible: opacity > 0.01
                    width: isWin ? liftW : root.iconSize * 1.12
                    height: isWin ? liftW * ui.tearH / ui.tearW : width
                    x: ui.tearX - width / 2
                    y: offY + ui.tearY - height * (isWin ? grabFy : 0.5)
                    scale: zoom
                    rotation: isWin ? 0 : wob
                    Image {
                        visible: !tearGhost.isWin
                        anchors.fill: parent
                        source: ui.tearSrc
                        sourceSize: Qt.size(256, 256)
                        smooth: true; mipmap: true
                    }
                    RectangularShadow {
                        visible: tearGhost.isWin
                        anchors.fill: parent; radius: 10
                        offset.y: 6 + 14 * tearGhost.lift; blur: 18 + 32 * tearGhost.lift; spread: 0
                        color: Qt.rgba(0, 0, 0, 0.30 + 0.15 * tearGhost.lift)
                    }
                    Rectangle {
                        visible: tearGhost.isWin
                        anchors.fill: parent; radius: 10
                        color: Qt.rgba(0.09, 0.08, 0.09, 0.88)
                    }
                    ScreencopyView {
                        id: gsv
                        visible: tearGhost.isWin
                        anchors.fill: parent
                        captureSource: tearGhost.isWin && tearWin.visible ? ui.tearItem.tl : null
                        Timer {
                            interval: 33; repeat: true; triggeredOnStart: true
                            running: tearGhost.isWin && tearWin.visible && tearGhost.visible && gsv.captureSource !== null
                            onTriggered: if (typeof gsv.captureFrame === "function") gsv.captureFrame()
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect { maskEnabled: true; maskSource: gsvMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                    }
                    Item { id: gsvMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: 10; color: "black" } }
                    Rectangle {
                        visible: tearGhost.isWin
                        anchors.fill: parent; radius: 10; color: "transparent"
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                    }
                    SequentialAnimation on wob {
                        running: ui.tearing
                        loops: Animation.Infinite
                        NumberAnimation { to: 2.5; duration: 90; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -2.5; duration: 180; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 90; easing.type: Easing.InOutSine }
                    }
                }
            }

            Item {
                id: ui
                anchors.fill: parent

                property real mxT: 0
                readonly property real mx: mxSpring.value
                Spring { id: mxSpring; target: ui.mxT; response: 0.13; damping: 0.92; epsilon: 0.05 }
                property bool revealed: false
                property var menuItem: null
                property var menuModel: []
                property string armed: ""
                onMenuItemChanged: armed = ""
                property real menuCx: 0
                readonly property bool menuOpen: menuItem !== null
                readonly property bool wantsHide: root.hideMode === "always"
                    || ((root.hideMode === "smart" || root.hideMode === "windows") && root.busyMonitors[win.modelData.name] === true)
                property bool dragging: false
                property int dragIndex: -1
                property int dragTarget: -1
                property string dragKey: ""
                property real dragPressX: 0
                property real dragDelta: 0
                property real dragShiftW: 0
                property bool justDragged: false
                property bool tearing: false
                property var tearItem: null
                property string tearSrc: ""
                property real tearX: 0
                property real tearY: 0
                property real tearHomeX: 0
                property real tearHomeY: 0
                property real tearW: 900
                property real tearH: 600
                property string tearAddr: ""
                property bool following: false
                property bool oldVisible: false
                NumberAnimation { id: ghostFade; target: tearGhost; property: "opacity"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                onTearXChanged: if (following) Qt.callLater(moveReal)
                onTearYChanged: {
                    if (following) Qt.callLater(moveReal);
                    else if (tearing && tearAddr && tearGhost.liftRaw >= 1) handoff();
                }
                function wsel() { return 'window = "address:' + tearAddr + '"'; }
                function realPos() {
                    return { x: Math.round(win.modelData.x + tearX - tearW / 2),
                             y: Math.round(win.modelData.y + tearGhost.offY + tearY - tearH * 0.035) };
                }
                function moveReal() {
                    if (!following || !tearAddr) return;
                    var p = realPos();
                    Hyprland.dispatch('hl.dsp.window.move({ x = ' + p.x + ', y = ' + p.y + ', "exact", ' + wsel() + ' })');
                }
                function handoff() {
                    if (following || !tearAddr) return;
                    following = true;
                    var mon = Hyprland.monitorFor(win.modelData);
                    var ws = (mon && mon.activeWorkspace) ? String(mon.activeWorkspace.name) : "";
                    var p = realPos(), sel = wsel();
                    if (ws) Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + ws + '", follow = false, ' + sel + ' })');
                    Hyprland.dispatch('hl.dsp.window.fullscreen_state({ internal = 0, client = 0, ' + sel + ' })');
                    Hyprland.dispatch('hl.dsp.window.float({ action = "enable", ' + sel + ' })');
                    Hyprland.dispatch('hl.dsp.window.set_prop({ prop = "no_anim", value = "1", ' + sel + ' })');
                    Hyprland.dispatch('hl.dsp.window.resize({ x = ' + Math.round(tearW) + ', y = ' + Math.round(tearH) + ', "exact", ' + sel + ' })');
                    Hyprland.dispatch('hl.dsp.window.move({ x = ' + p.x + ', y = ' + p.y + ', "exact", ' + sel + ' })');
                    if (tearItem && tearItem.tl) tearItem.tl.activate();
                    if (oldVisible) { oldSnap.scale = 1; oldSnap.opacity = 1; oldSnap.shown = true; oldOut.restart(); }
                    ghostFade.restart();
                }
                function finishFollow() {
                    following = false;
                    tearing = false;
                    if (tearAddr) Hyprland.dispatch('hl.dsp.window.set_prop({ prop = "no_anim", value = "0", ' + wsel() + ' })');
                    tearAddr = "";
                    if (!ghostFade.running) tearItem = null;
                    else ghostFade.finished.connect(function () { if (!ui.tearing) ui.tearItem = null; });
                }
                function hyprOf(tl) {
                    var v = Hyprland.toplevels.values;
                    for (var i = 0; i < v.length; i++) if (v[i].wayland === tl) return v[i];
                    return null;
                }
                function beginTear(item, src, homeX, homeY) {
                    if (dragging) { dragTarget = dragIndex; endDrag(); }
                    menuItem = null;
                    tearItem = item; tearSrc = src; tearHomeX = homeX; tearHomeY = homeY;
                    tearGhost.opacity = 1; tearGhost.zoom = 1;
                    following = false; ghostFade.stop();
                    tearAddr = "";
                    if (item.kind === "win") {
                        var h = hyprOf(item.tl), o = h ? h.lastIpcObject : null;
                        tearAddr = h ? ("0x" + h.address.replace(/^0x/, "")) : "";
                        var sw = win.modelData.width, sh = win.modelData.height;
                        var w = (o && o.size) ? o.size[0] : (gsv.implicitWidth || 900);
                        var hh = (o && o.size) ? o.size[1] : (gsv.implicitHeight || 600);
                        var k = Math.min(1, (sw * 0.78) / w, (sh * 0.78) / hh);
                        tearW = Math.round(w * k); tearH = Math.round(hh * k);
                        var mon0 = Hyprland.monitorFor(win.modelData);
                        oldSnap.shown = false; oldOut.stop();
                        oldVisible = !!(o && o.at && o.workspace && mon0 && mon0.activeWorkspace && o.workspace.id === mon0.activeWorkspace.id);
                        if (oldVisible) {
                            oldSnap.x = o.at[0] - win.modelData.x; oldSnap.y = o.at[1] - win.modelData.y;
                            oldSnap.width = o.size[0]; oldSnap.height = o.size[1];
                            oldSv.captureSource = item.tl;
                        }
                    }
                    tearing = true;
                }
                function endTear() {
                    if (!tearing) return;
                    if (tearAddr && (following || tearY < activeTop - 30)) {
                        if (!following) handoff();
                        finishFollow();
                        justDragged = true;
                        Qt.callLater(function () { ui.justDragged = false; });
                        return;
                    }
                    tearing = false;
                    justDragged = true;
                    Qt.callLater(function () { ui.justDragged = false; });
                    if (tearY < activeTop - 30) {
                        tearLaunch.item = tearItem;
                        tearLaunch.restart();
                    } else {
                        tearHome.restart();
                    }
                }

                function pinnedCount() {
                    var n = 0;
                    for (var i = 0; i < root.items.length; i++) {
                        var it = root.items[i];
                        if (it.kind === "app" && it.pinned && !it.special) n++;
                        else break;
                    }
                    return n;
                }
                function naturalCenter(i) {
                    var c = rep.itemAt(i);
                    return c ? row.mapToItem(ui, c.x + c.width / 2, 0).x : 0;
                }
                function beginDrag(index, key, pressX, shiftW) {
                    menuItem = null;
                    dragIndex = index;
                    dragTarget = index;
                    dragKey = key;
                    dragPressX = pressX;
                    dragDelta = 0;
                    dragShiftW = shiftW;
                    dragging = true;
                }
                function dragUpdate(absX) {
                    dragDelta = absX - dragPressX;
                    var center = naturalCenter(dragIndex) + dragDelta;
                    var P = pinnedCount(), t = 0;
                    for (var j = 0; j < P; j++) {
                        if (j === dragIndex) continue;
                        if (naturalCenter(j) < center) t++;
                    }
                    dragTarget = t;
                }
                function shiftFor(i) {
                    if (dragIndex < i && i <= dragTarget) return -dragShiftW;
                    if (dragTarget <= i && i < dragIndex) return dragShiftW;
                    return 0;
                }
                function endDrag() {
                    var from = dragIndex, to = dragTarget;
                    dragging = false;
                    dragKey = "";
                    dragIndex = -1;
                    dragTarget = -1;
                    dragDelta = 0;
                    justDragged = true;
                    Qt.callLater(function () { ui.justDragged = false; });
                    if (to !== from) root.reorderPinned(from, to);
                }

                SequentialAnimation {
                    id: tearLaunch
                    property var item: null
                    ParallelAnimation {
                        NumberAnimation { target: tearGhost; property: "zoom"; to: tearGhost.isWin ? 2.0 : 2.6; duration: 460; easing.type: Easing.OutQuint }
                        NumberAnimation { target: tearGhost; property: "opacity"; to: 0; duration: 460; easing.type: Easing.OutCubic }
                        NumberAnimation { target: tearGhost; property: "wob"; to: 0; duration: 200 }
                    }
                    ScriptAction { script: { if (tearLaunch.item) root.activate(tearLaunch.item, false); ui.tearItem = null; } }
                }
                ParallelAnimation {
                    id: tearHome
                    NumberAnimation { target: ui; property: "tearX"; to: ui.tearHomeX; duration: 420; easing.type: Easing.OutQuint }
                    NumberAnimation { target: ui; property: "tearY"; to: ui.tearHomeY; duration: 420; easing.type: Easing.OutQuint }
                    NumberAnimation { target: tearGhost; property: "wob"; to: 0; duration: 200 }
                    onFinished: { ui.tearItem = null; ui.tearAddr = ""; }
                }

                readonly property bool tucked: wantsHide && !revealed && !menuOpen && !dragging && !tearing
                readonly property real refLeft: (width - root.totalW0) / 2
                readonly property real activeTop: height - root.margin - root.bgHeight
                                                  - root.iconSize * (root.effMag - 1) - 12
                readonly property bool active: dragging || (hh.hovered && hh.point.position.y > activeTop && !tucked)
                readonly property real strength: Math.max(0, Math.min(1, strSpring.value))
                Spring { id: strSpring; target: ui.active ? 1 : 0; response: 0.2; damping: 1.0; epsilon: 0.002 }

                HoverHandler {
                    id: hh
                    onPointChanged: if (hovered && !ui.dragging) { ui.mxT = point.position.x; if (ui.strength < 0.02) mxSpring.snap(); }
                    onHoveredChanged: {
                        if (hovered) { hideTimer.stop(); ui.revealed = true; }
                        else hideTimer.restart();
                    }
                }
                Timer { id: hideTimer; interval: root.hideDelay; onTriggered: if (!ui.dragging) ui.revealed = false }

                Loader {
                    id: glassBackdrop
                    active: root.liquidBase
                    sourceComponent: Item {
                        id: bd
                        visible: root.liquidActive
                        x: 0
                        y: -(win.modelData.height - ui.height)
                        width: win.modelData.width
                        height: win.modelData.height

                        Rectangle {
                            anchors.fill: parent
                            visible: wpShown.status !== Image.Ready
                                     && (wpNext.status === Image.Error || (wpNext.source == "" && !!root.hub && root.hub.wallpaperReady))
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#2f6bff" }
                                GradientStop { position: 0.5; color: "#b44cff" }
                                GradientStop { position: 1.0; color: "#ff8a3d" }
                            }
                        }
                        Image {
                            id: wpShown
                            anchors.fill: parent
                            visible: status === Image.Ready
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: bd.width
                            smooth: true
                        }
                        Image {
                            id: wpNext
                            visible: false
                            width: 1; height: 1
                            onStatusChanged: {
                                console.log("[yukidock-glass] wallpaper image status:", status, "(1 = ready, 2 = loading, 3 = error)", source);
                                if (status === Image.Ready) wpShown.source = source;
                            }
                            source: root.fileUrl(root.wallpaperFor(win.modelData.name))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: bd.width
                        }
                        LiveWall {
                            anchors.fill: parent
                            video: root.bar ? root.bar.glassVideo : ""
                            live: root.glassLive
                            paused: !!root.bar && root.bar.wallIdle(win.modelData.name)
                            clock: root.bar ? root.bar.wallClock : null
                        }

                        ListModel { id: wm }
                        Repeater {
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
                                x: wx; y: wy; width: ww; height: wh; z: wz
                                visible: !gone
                                property bool released: false
                                onGoneChanged: { if (gone) relTimer.restart(); else { relTimer.stop(); released = false; } }
                                Timer { id: relTimer; interval: 300; onTriggered: gw.released = true }
                                readonly property bool closing: !!root.hub && root.hub.closingWins[String(addr).replace(/^0x/, "")] === true
                                readonly property var tl: { if (!root.hub || released || closing) return null; var t = root.hub.tlTick; return root.hub.tlFor(addr); }
                                readonly property real dockTop: dock.y + bd.height - ui.height
                                readonly property bool overlap: x < dock.x + dock.width + 100 && x + width > dock.x - 100
                                    && y < dockTop + dock.height + 100 && y + height > dockTop - 100
                                readonly property bool nearNow: root.glassRT || (!ui.tucked
                                    && x < dock.x + dock.width + 48 && x + width > dock.x - 48
                                    && y < dockTop + dock.height + 48
                                    && y + height > dockTop - 48)
                                property bool near: false
                                onNearNowChanged: { if (nearNow) { nearHold.stop(); near = true; } else nearHold.restart(); }
                                Component.onCompleted: near = nearNow
                                Timer { id: nearHold; interval: 2500; onTriggered: gw.near = gw.nearNow }
                                Loader {
                                    anchors.fill: parent
                                    active: gw.near && !gw.released
                                    sourceComponent: ScreencopyView {
                                        id: sc
                                        captureSource: gw.tl
                                        readonly property var wa: root.hub ? root.hub.winAlpha(gw.addr) : ({ bg: 1, win: 1 })
                                        opacity: wa.win
                                        layer.enabled: wa.bg < 0.999
                                        layer.effect: ShaderEffect { property real bgAlpha: sc.wa.bg; fragmentShader: Qt.resolvedUrl("capalpha.frag.qsb") }
                                        readonly property bool canRun: root.glassRT
                                            ? !(root.hub && root.hub.captureQuiet) && !(root.bar && root.bar.gaming) && !gw.gone && !gw.closing
                                            : (!root.glassHold && !ui.tucked)
                                        readonly property bool wanted: sc.canRun && gw.overlap && !ui.tucked
                                        onWantedChanged: { if (wanted && captureSource !== null && typeof captureFrame === "function") captureFrame(); }
                                        Timer {
                                            interval: root.glassRT ? 16 : 66
                                            repeat: true
                                            running: sc.wanted && sc.captureSource !== null
                                            onTriggered: if (typeof sc.captureFrame === "function") sc.captureFrame()
                                        }
                                        onCaptureSourceChanged: { if (captureSource !== null && sc.wanted) firstShot.restart(); }
                                        Timer {
                                            id: firstShot
                                            interval: 60
                                            onTriggered: { if (sc.captureSource !== null && sc.wanted && typeof sc.captureFrame === "function") sc.captureFrame(); }
                                        }
                                    }
                                }
                            }
                        }

                        function sync() {
                            var mon = null;
                            for (var i = 0; i < root.monData.length; i++)
                                if (root.monData[i].name === win.modelData.name) mon = root.monData[i];
                            if (!mon) return;
                            var ws = [mon.activeWorkspace && mon.activeWorkspace.name ? mon.activeWorkspace.name : "\u0000none"];
                            if (mon.specialWorkspace && mon.specialWorkspace.name) ws.push(mon.specialWorkspace.name);
                            var zoneTop = bd.height - win.height;
                            var want = {};
                            var cs = root.glassClients;
                            for (var c = 0; c < cs.length; c++) {
                                var cl = cs[c];
                                if (!cl.mapped || cl.hidden || cl.monitor !== mon.id || !cl.workspace || ws.indexOf(cl.workspace.name) < 0) continue;
                                var x = cl.at[0] - mon.x, y = cl.at[1] - mon.y, w = cl.size[0], h = cl.size[1];
                                if (x + w <= 0 || x >= bd.width || y + h <= zoneTop || y >= bd.height) continue;
                                var z = cl.floating ? 100 - Math.min(cl.focusHistoryID, 90) : 0;
                                want[cl.address] = { addr: cl.address, wx: x, wy: y, ww: w, wh: h, wz: z, gone: false };
                            }
                            for (var j = wm.count - 1; j >= 0; j--) {
                                var a = wm.get(j).addr;
                                if (want[a] === undefined) { if (!wm.get(j).gone) { wm.setProperty(j, "gone", true); sweep.restart(); } }
                                else { wm.set(j, want[a]); delete want[a]; }
                            }
                            for (var k in want) wm.append(want[k]);
                            bd.lastCount = wm.count;
                        }
                        Timer {
                            id: sweep
                            interval: 600
                            onTriggered: { for (var q = wm.count - 1; q >= 0; q--) if (wm.get(q).gone) wm.remove(q); bd.lastCount = wm.count; }
                        }
                        property int lastCount: -1
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
                    x: ui.menuOpen ? 0 : dock.x
                    width: ui.menuOpen ? ui.width : dock.width
                    y: ui.menuOpen ? 0 : (ui.tucked ? ui.height - 3 : (hh.hovered ? ui.activeTop : dock.y))
                    height: ui.height - y
                }

                Item {
                    id: dock
                    width: row.width + root.hPad * 2
                    height: root.bgHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: ui.height - root.margin - height + (ui.tucked ? height + root.margin + 6 : 0)
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Loader {
                        id: glassLayer
                        anchors.fill: parent
                        active: root.liquidActive
                        sourceComponent: Item {
                            id: dg
                            property color edgeCol: root.bar ? root.bar.menuBorderColor : "#8A9AB5"
                            Behavior on edgeCol { ColorAnimation { duration: 450; easing.type: Easing.OutCubic } }
                            readonly property real eb: root.glassBlur + root.dockBlurBoost
                            readonly property real ds: eb >= 8 ? 0.5 : 1.0
                            readonly property real bn: eb * 1.5 * ds / 64.0
                            readonly property real margin: 72
                            readonly property real padPx: root.dockGlassNew ? 30 : 10
                            ShaderEffectSource {
                                id: bsrc
                                sourceItem: glassBackdrop.item
                                hideSource: true
                                live: !ui.tucked
                                visible: false
                                sourceRect: Qt.rect(dock.x - parent.padPx - parent.margin,
                                                    dock.y + (win.modelData.height - ui.height) - parent.padPx - parent.margin,
                                                    dock.width + 2 * (parent.padPx + parent.margin),
                                                    dock.height + 2 * (parent.padPx + parent.margin))
                                textureSize: Qt.size(Math.max(1, Math.round(sourceRect.width * dg.ds)), Math.max(1, Math.round(sourceRect.height * dg.ds)))
                            }
                            MultiEffect {
                                id: bblurFx
                                source: bsrc
                                width: bsrc.sourceRect.width * dg.ds; height: bsrc.sourceRect.height * dg.ds
                                blurEnabled: true
                                blurMax: 64
                                blur: Math.min(1.0, dg.bn)
                                autoPaddingEnabled: false
                                visible: false
                            }
                            ShaderEffectSource {
                                id: bblur
                                sourceItem: bblurFx
                                live: !ui.tucked
                                visible: false
                            }
                            MultiEffect {
                                id: bblur2Fx
                                source: bblur
                                width: bsrc.sourceRect.width * dg.ds; height: bsrc.sourceRect.height * dg.ds
                                blurEnabled: dg.bn > 1.0
                                blurMax: 64
                                blur: Math.max(0.0, Math.min(1.0, dg.bn - 1.0))
                                autoPaddingEnabled: false
                                visible: false
                            }
                            ShaderEffectSource {
                                id: bblur2
                                sourceItem: dg.bn > 1.0 ? bblur2Fx : null
                                live: !ui.tucked
                                visible: false
                            }
                            ShaderEffect {
                                id: glassFx
                                x: -padPx; y: -padPx
                                width: dock.width + 2 * padPx
                                height: dock.height + 2 * padPx
                                fragmentShader: root.dockGlassUrl
                                onStatusChanged: {
                                    console.log("[yukidock-glass] shader status:", status, "(0 = compiled, 1 = uncompiled, 2 = error)", log);
                                    if (status === ShaderEffect.Error) {
                                        if (root.dockGlassNew) root.dockGlassState = "failed";
                                        else root.glassState = "failed";
                                    }
                                }
                                property vector4d edgeTint: Qt.vector4d(dg.edgeCol.r, dg.edgeCol.g, dg.edgeCol.b, root.dockGlassNew ? 0.5 : 0)

                                property variant src: dg.bn > 1.0 ? bblur2 : bblur
                                property real padPx: parent.padPx
                                property vector2d itemSize: Qt.vector2d(width, height)
                                property vector2d glassSize: Qt.vector2d(dock.width, dock.height)
                                property vector2d srcSize: Qt.vector2d(bsrc.sourceRect.width, bsrc.sourceRect.height)
                                property vector2d srcOffset: Qt.vector2d(parent.margin, parent.margin)
                                property real pad: padPx
                                property real radius: root.cornerRadius
                                property real bezel: Math.min(dock.height * 0.36, 26)
                                property real thickness: 30 * root.glassLiquid
                                property real dispersion: 0.06 * root.glassLiquid
                                property real magnify: 0.08 * root.glassLiquid
                                property real rim: root.glassRim * 0.20
                                property real grain: root.glassGrain * 0.3
                                property real blurPx: 1.5
                                property real tintMix: root.glassOpacity * 0.55
                                property vector4d accentTint: root.accentTintVec
                                property real saturation: 1.25
                                property real dark: root.dockDark ? 1 : 0
                                property real debug: root.glassDebug ? 1 : 0
                                property real shadowAmt: 0
                                property real rimTint: 0
                                property real ringW: 0
                            }
                        }
                    }

                    Rectangle {
                        visible: !root.liquidActive
                        anchors.fill: parent
                        radius: root.cornerRadius
                        color: root.dockDark ? Qt.rgba(0.10, 0.10, 0.11, root.glassOpacity)
                                             : Qt.rgba(1, 1, 1, root.glassOpacity * 0.55)
                        border.width: 0

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 0
                            radius: parent.radius - 0.35
                            color: "transparent"
                            border.width: 0.25
                            border.color: root.dockDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.12)
                        }
                    }

                    MenuBorder {
                        anchors.fill: parent
                        cornerR: root.cornerRadius
                        dark: root.dockDark
                        tint: root.bar ? root.bar.menuBorderColor : "#8A9AB5"
                        outline: false
                    }

                    Canvas {
                        id: sideBorder
                        anchors.fill: parent
                        anchors.margins: -3
                        antialiasing: true
                        readonly property real strength: root.dockDark ? 0.14 : 0.12
                        onStrengthChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Connections { target: root; function onCornerRadiusChanged() { sideBorder.requestPaint(); } }
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var m = 3, W = width, H = height;
                            var w = W - 2 * m, h = H - 2 * m;
                            if (w < 4 || h < 4) return;
                            var r = Math.max(2, Math.min(root.cornerRadius, h / 2, w / 2));
                            var fade = Math.min(w / 2, r * 1.05);
                            var g = ctx.createLinearGradient(m, 0, m + w, 0);
                            var N = 24;
                            for (var k = 0; k <= N; k++) {
                                var u = k / N, sm = u * u * u * (u * (u * 6 - 15) + 10), al = (strength * (1 - sm)).toFixed(4);
                                g.addColorStop(u * fade / w, "rgba(0,0,0," + al + ")");
                                g.addColorStop(1 - u * fade / w, "rgba(0,0,0," + al + ")");
                            }
                            ctx.strokeStyle = g;
                            ctx.lineWidth = 1.6;
                            ctx.beginPath();
                            ctx.moveTo(m + r, m);
                            ctx.lineTo(m + w - r, m);
                            ctx.arc(m + w - r, m + r, r, 1.5 * Math.PI, 2 * Math.PI, false);
                            ctx.lineTo(m + w, m + h - r);
                            ctx.arc(m + w - r, m + h - r, r, 0, 0.5 * Math.PI, false);
                            ctx.lineTo(m + r, m + h);
                            ctx.arc(m + r, m + h - r, r, 0.5 * Math.PI, Math.PI, false);
                            ctx.lineTo(m, m + r);
                            ctx.arc(m + r, m + r, r, Math.PI, 1.5 * Math.PI, false);
                            ctx.closePath();
                            ctx.stroke();
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: !(root.liquidActive && root.dockGlassNew)
                        sourceComponent: CornerBorder {
                            anchors.fill: parent
                            cornerR: root.cornerRadius
                            dark: root.dockDark
                            tint: root.bar ? root.bar.menuBorderColor : "#8A9AB5"
                            amount: 0.12
                            lineW: 0.35
                            fade: false
                        }
                    }

                    Row {
                        id: row
                        spacing: root.spacing
                        height: root.iconSize
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.bottomPad

                        Repeater {
                            id: rep
                            model: dockModel

                            delegate: Item {
                                id: cell
                                required property string key
                                required property int index
                                readonly property var modelData: root.itemMap[key] || ({ kind: "sep", key: key, nA: 0, nS: 0 })
                                readonly property bool isSep: modelData.kind === "sep"
                                readonly property bool canDrag: !isSep && modelData.pinned === true && !modelData.special
                                readonly property bool isActiveApp: {
                                    if (isSep || modelData.kind !== "app" || !modelData.running) return false;
                                    var w = root.windowsFor(modelData.key);
                                    for (var i = 0; i < w.length; i++) if (w[i].activated) return true;
                                    return false;
                                }
                                readonly property real hoverTarget: (!isSep && ma.containsMouse && !ui.dragging && !ui.tearing && !ui.menuOpen) ? root.iconSize * 0.09 : 0
                                property real hoverUp: hoverTarget
                                Behavior on hoverUp { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.8 } }
                                readonly property bool torn: ui.tearing && ui.tearItem && !isSep && ui.tearItem.key === modelData.key
                                opacity: (torn ? 0.3 : (isDragged ? 0.92 : 1)) * (leavingCell ? appear : 1)
                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                readonly property bool isDragged: ui.dragging && modelData.key === ui.dragKey

                                readonly property var thumbWin: (!isSep && modelData.kind === "win") ? modelData.tl : null
                                property var heldTl: null
                                readonly property string winAddr: { if (!thumbWin) return ""; var h = ui.hyprOf(thumbWin); return h ? String(h.address).replace(/^0x/, "") : ""; }
                                readonly property bool closingWin: winAddr !== "" && root.hub && root.hub.closingWins[winAddr] === true
                                onThumbWinChanged: if (thumbWin !== heldTl) heldTl = thumbWin
                                readonly property bool useThumb: thumbWin !== null
                                readonly property bool thumbReady: useThumb && (sv.hasContent === undefined || sv.hasContent === true)

                                property real dx: {
                                    if (!ui.dragging || isSep) return 0;
                                    if (isDragged) return ui.dragDelta;
                                    return ui.shiftFor(index);
                                }
                                Behavior on dx {
                                    enabled: !cell.isDragged
                                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }
                                transform: Translate { x: cell.dx }
                                z: isDragged ? 100 : 0

                                readonly property bool leavingCell: modelData.leaving === true
                                property real appear: modelData.fresh ? 0 : 1
                                Behavior on appear { NumberAnimation { duration: cell.leavingCell ? root.leaveMs : 320; easing.type: cell.leavingCell ? Easing.InOutCubic : Easing.OutCubic } }
                                Component.onCompleted: { heldTl = thumbWin; Qt.callLater(function () { cell.appear = cell.leavingCell ? 0 : 1; cell.bounceStep(); }); }
                                onLeavingCellChanged: appear = leavingCell ? 0 : 1
                                enabled: !leavingCell

                                readonly property real c0: modelData.nA * (root.iconSize + root.spacing)
                                                           + modelData.nS * (root.sepWidth + root.spacing)
                                                           + (isSep ? root.sepWidth : root.iconSize) / 2
                                readonly property real s: {
                                    if (isSep) return 1;
                                    var dist = Math.abs(ui.mx - ui.refLeft - cell.c0);
                                    var R = root.magRadius;
                                    var f = dist < R ? 0.5 * (1 + Math.cos(Math.PI * dist / R)) : 0;
                                    return 1 + (root.effMag - 1) * f * ui.strength;
                                }

                                width: isSep ? root.sepWidth * appear : root.iconSize * s * appear
                                height: root.iconSize

                                Rectangle {
                                    visible: cell.isSep
                                    width: 1
                                    height: root.iconSize * 0.85
                                    anchors.centerIn: parent
                                    color: root.dockDark ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(0, 0, 0, 0.22)
                                }

                                Item {
                                    id: face
                                    anchors.fill: parent
                                    transformOrigin: Item.Bottom
                                    scale: (ma.pressed && !ui.dragging && !ui.tearing) ? 0.86 : 1
                                    Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 3.2 } }
                                    Image {
                                        id: img
                                        visible: false
                                        property real lift: 0
                                        width: root.iconSize * 0.99 * cell.s * cell.appear
                                        height: width
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: lift + cell.hoverUp
                                        source: cell.isSep ? "" : root.cellIconSrc(cell.modelData)
                                        sourceSize: Qt.size(Math.ceil(root.iconSize * root.magnification * 1.25),
                                                            Math.ceil(root.iconSize * root.magnification * 1.25))
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                        asynchronous: true
                                    }
                                    MultiEffect {
                                        visible: !cell.isSep && !cell.thumbReady
                                        source: img
                                        anchors.fill: img
                                        shadowEnabled: true
                                        shadowColor: "black"
                                        shadowOpacity: 0.32
                                        shadowBlur: 0.55
                                        shadowVerticalOffset: 3
                                        saturation: root.iconTint ? -0.75 * root.iconTintStrength : 0.0
                                        colorization: root.iconTint ? 1.0 * root.iconTintStrength : 0.0
                                        brightness: (ma.pressed ? -0.3 : 0.0) + (root.iconTint ? 0.14 * root.iconTintStrength : 0.0)
                                        contrast: root.iconTint ? 0.04 * root.iconTintStrength : 0.0
                                        colorizationColor: root.iconTintColor
                                    }

                                    Item {
                                        id: th
                                        anchors.fill: img
                                        visible: cell.useThumb
                                        opacity: cell.thumbReady ? 1 : 0.01

                                        Rectangle {
                                            x: sv.x
                                            y: sv.y + 3
                                            width: sv.width
                                            height: sv.height
                                            radius: 5
                                            color: Qt.rgba(0, 0, 0, 0.32)
                                        }
                                        ScreencopyView {
                                            id: sv
                                            anchors.centerIn: parent
                                            captureSource: (root.hub && !root.hub.windowCapture) ? null : cell.heldTl
                                            Timer {
                                                interval: hh.hovered ? 100 : 6000; repeat: true
                                                running: !ui.tucked && !root.previewHold && !cell.closingWin && sv.captureSource !== null
                                                onTriggered: if (typeof sv.captureFrame === "function") sv.captureFrame()
                                            }
                                            Timer {
                                                id: settleShot
                                                interval: 450
                                                onTriggered: if (!ui.tucked && !cell.closingWin && sv.captureSource !== null && typeof sv.captureFrame === "function") sv.captureFrame()
                                            }
                                            Connections {
                                                target: ui
                                                function onTuckedChanged() { if (ui.tucked) settleShot.stop(); else settleShot.restart(); }
                                            }
                                            readonly property real ar: (implicitWidth > 0 && implicitHeight > 0)
                                                                       ? implicitWidth / implicitHeight : 4 / 3
                                            width: Math.min(th.width, th.height * ar)
                                            height: width / ar
                                        }
                                        Rectangle {
                                            anchors.fill: sv
                                            radius: 3
                                            color: ma.pressed ? Qt.rgba(0, 0, 0, 0.3) : "transparent"
                                            border.width: 1
                                            border.color: root.dockDark ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(0, 0, 0, 0.28)
                                        }
                                    }
                                    // small app icon in the corner, so you can tell which app the window belongs to
                                    Image {
                                        id: badge
                                        visible: cell.thumbReady
                                        width: img.width * 0.46
                                        height: width
                                        x: img.x + img.width - width + 3
                                        y: img.y + img.height - height + 3
                                        source: img.source
                                        sourceSize: Qt.size(Math.ceil(root.iconSize * root.magnification * 0.6),
                                                            Math.ceil(root.iconSize * root.magnification * 0.6))
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                    }

                                    Rectangle {
                                        id: pill
                                        visible: !cell.isSep && cell.modelData.running && root.showIndicators
                                        readonly property bool act: cell.isActiveApp
                                        width: act ? 16 : 5; height: 5; radius: 2.5
                                        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                        color: act ? root.accent : (root.dockDark ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(0, 0, 0, 0.5))
                                        Behavior on color { ColorAnimation { duration: 220 } }
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: cell.height + 3
                                        Rectangle {
                                            z: -1
                                            anchors.centerIn: parent
                                            width: parent.width + 8; height: 11; radius: 5.5
                                            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)
                                            opacity: pill.act ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 260 } }
                                        }
                                    }
                                }

                                readonly property bool wantBounce: !cell.isSep && root.bounceOnLaunch && root.launching[cell.modelData.key] !== undefined
                                property bool bounceShown: false
                                function bounceStep() {
                                    if (ui.tucked) return;
                                    if (cell.wantBounce) { cell.bounceShown = true; if (!bounceAnim.running && !settleAnim.running) bounceAnim.start(); }
                                    else if (cell.bounceShown && !bounceAnim.running && !settleAnim.running) { cell.bounceShown = false; settleAnim.start(); }
                                }
                                onWantBounceChanged: bounceStep()
                                Connections {
                                    target: ui
                                    function onTuckedChanged() {
                                        if (ui.tucked) {
                                            bounceAnim.stop(); settleAnim.stop(); hopAnim.stop(); img.lift = 0; cell.bounceShown = false;
                                        } else cell.bounceStep();
                                    }
                                }
                                SequentialAnimation {
                                    id: hopAnim
                                    NumberAnimation { target: img; property: "lift"; to: root.iconSize * 0.2
                                                      duration: 130; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: img; property: "lift"; to: 0
                                                      duration: 260; easing.type: Easing.OutBounce }
                                }
                                function hop() { if (!ui.tucked && !bounceAnim.running && !settleAnim.running && !cell.wantBounce) hopAnim.restart(); }
                                SequentialAnimation {
                                    id: bounceAnim
                                    NumberAnimation { target: img; property: "lift"; to: root.iconSize * 0.42
                                                      duration: 280; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: img; property: "lift"; to: 0
                                                      duration: 280; easing.type: Easing.InCubic }
                                    onFinished: cell.bounceStep()
                                }
                                SequentialAnimation {
                                    id: settleAnim
                                    NumberAnimation { target: img; property: "lift"; to: root.iconSize * 0.16
                                                      duration: 170; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: img; property: "lift"; to: 0
                                                      duration: 170; easing.type: Easing.InQuad }
                                    NumberAnimation { target: img; property: "lift"; to: root.iconSize * 0.06
                                                      duration: 120; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: img; property: "lift"; to: 0
                                                      duration: 120; easing.type: Easing.InQuad }
                                    onFinished: cell.bounceStep()
                                }

                                readonly property bool tipOn: root.showLabels && !cell.isSep && ma.containsMouse && !ma.pressed && !ui.menuOpen && !ui.dragging
                                Loader {
                                    id: tip
                                    z: 10
                                    opacity: cell.tipOn ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                    active: cell.tipOn || opacity > 0
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.round(cell.height - img.height - img.lift - cell.hoverUp - height - 8 * root.labelK)
                                    sourceComponent: DockGlassPanel {
                                        id: lp
                                        readonly property string title: cell.isSep ? "" : ((cell.modelData.kind === "win" && cell.modelData.tl && cell.modelData.tl.title) ? cell.modelData.tl.title : (cell.modelData.special ? I18n.tr(cell.modelData.name) : cell.modelData.name))
                                        backdrop: glassBackdrop.item
                                        live: root.liquidActive && glassBackdrop.item !== null
                                        dark: root.darkMode
                                        tinted: root.accentUi
                                        accent: root.accent
                                        k: root.labelK
                                        radius: Math.round(12 * k)
                                        bodyH: Math.round(28 * k)
                                        tailW: Math.round(20 * k)
                                        tailH: Math.round(6 * k)
                                        tailTipR: 2.4 * k
                                        width: Math.ceil(tt.width) + 2 * Math.round(12 * k)
                                        Text {
                                            id: tt
                                            text: lp.title
                                            width: Math.min(implicitWidth, Math.round(320 * lp.k))
                                            elide: Text.ElideRight
                                            anchors.centerIn: parent
                                            color: lp.dark ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(0, 0, 0, 0.86)
                                            font.pixelSize: Math.max(10, Math.round(13 * lp.k))
                                            font.family: root.fontForWeight(Font.Normal, root.fontFamily)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: ma
                                    visible: !cell.isSep
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -root.bottomPad
                                    width: cell.width
                                    height: img.height + root.bottomPad
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                    property real pressX: 0

                                    property real pressY: 0
                                    onPressed: mouse => {
                                        if (mouse.button === Qt.LeftButton) {
                                            var pp = ma.mapToItem(ui, mouse.x, mouse.y);
                                            pressX = pp.x; pressY = pp.y;
                                        }
                                    }
                                    onPositionChanged: mouse => {
                                        if (!(pressedButtons & Qt.LeftButton) || cell.isSep) return;
                                        var ap = ma.mapToItem(ui, mouse.x, mouse.y);
                                        if (ui.tearing) { ui.tearX = ap.x; ui.tearY = ap.y; return; }
                                        if (pressY - ap.y > 56 && (cell.modelData.kind === "app" || cell.modelData.kind === "win") && !cell.modelData.special) {
                                            var home = img.mapToItem(ui, img.width / 2, img.height / 2);
                                            ui.tearX = ap.x; ui.tearY = ap.y;
                                            ui.beginTear(cell.modelData, root.cellIconSrc(cell.modelData), home.x, home.y);
                                            return;
                                        }
                                        if (!cell.canDrag) return;
                                        var ax = ap.x;
                                        if (!ui.dragging) {
                                            if (Math.abs(ax - pressX) < 8) return;
                                            ui.beginDrag(cell.index, cell.modelData.key, pressX, cell.width + root.spacing);
                                        }
                                        if (cell.isDragged) ui.dragUpdate(ax);
                                    }
                                    onReleased: mouse => {
                                        if (ui.tearing) { ui.endTear(); return; }
                                        if (ui.dragging && cell.isDragged) ui.endDrag();
                                    }
                                    onClicked: mouse => {
                                        if (ui.justDragged) return;
                                        if (mouse.button === Qt.RightButton) {
                                            ui.menuCx = cell.mapToItem(ui, cell.width / 2, 0).x;
                                            ui.menuModel = root.menuFor(cell.modelData);
                                            ui.menuItem = cell.modelData;
                                        } else {
                                            cell.hop();
                                            var fl = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                                            root.activate(cell.modelData, mouse.button === Qt.MiddleButton || fl, fl);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 50
                    visible: ui.menuOpen
                    enabled: ui.menuOpen
                    acceptedButtons: Qt.AllButtons
                    onPressed: ui.menuItem = null
                }

                Item {
                    id: menu
                    z: 60
                    readonly property bool dk: root.darkMode
                    readonly property color ink: dk ? "#F5F5F7" : "#1D1D1F"
                    visible: opacity > 0
                    opacity: ui.menuOpen ? 1 : 0
                    scale: ui.menuOpen ? 1 : 0.97
                    transformOrigin: Item.Bottom
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    width: 224
                    height: menuCol.height + 12
                    x: Math.round(Math.max(8, Math.min(ui.width - width - 8, ui.menuCx - width / 2)))
                    y: Math.round(ui.height - root.margin - root.bgHeight - root.iconSize * (root.effMag - 1) - 12 - height)
                    readonly property point bpos: glassBackdrop.item ? glassBackdrop.item.mapFromItem(ui, x, y) : Qt.point(x, y)

                    LiquidPane {
                        anchors.fill: parent
                        backdrop: glassBackdrop.item
                        shaderUrl: root.glassShaderUrl
                        liquid: root.liquidActive && glassBackdrop.item !== null
                        dark: menu.dk
                        bx: menu.bpos.x; by: menu.bpos.y
                        shadowAmt: 0
                        flatInner: 1
                        rimTint: 1
                        ringW: 0
                        cornerR: 14
                        tint: root.glassOpacity
                        thickness: 22
                        strength: root.glassLiquid
                        rim: root.glassRim
                        grain: root.glassGrain
                        blur: root.glassBlur
                        accentTint: root.accentTintVec
                        onShaderError: root.glassState = "failed"
                    }
                    MenuBorder {
                        z: 2
                        anchors.fill: parent
                        cornerR: 14
                        dark: menu.dk
                        tint: root.bar ? root.bar.menuBorderColor : "#8A9AB5"
                    }

                    Column {
                        id: menuCol
                        x: 6
                        y: 6
                        width: parent.width - 12

                        Repeater {
                            model: ui.menuModel

                            delegate: Item {
                                id: mi
                                required property var modelData
                                readonly property bool isSep: modelData.kind === "sep"
                                readonly property bool off: !isSep && modelData.disabled === true
                                readonly property bool armedNow: !isSep && modelData.confirm === true && ui.armed === modelData.label
                                readonly property bool hot: !isSep && !off && mia.containsMouse
                                width: menuCol.width
                                height: isSep ? 8 : 28

                                Rectangle {
                                    visible: mi.isSep
                                    x: 8; y: 4
                                    width: parent.width - 16
                                    height: 1
                                    color: menu.dk ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: mi.armedNow ? "#FF453A" : root.accent
                                    opacity: mi.hot ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 90 } }
                                }
                                Text {
                                    visible: !mi.isSep
                                    x: 12
                                    y: Math.round((parent.height - height) / 2)
                                    width: parent.width - 24
                                    elide: Text.ElideRight
                                    text: mi.isSep ? "" : (mi.armedNow ? I18n.tr("Click again to confirm") : I18n.tr(mi.modelData.label))
                                    color: mi.hot ? "white" : menu.ink
                                    opacity: mi.off ? 0.4 : 1
                                    font.pixelSize: 14
                                    font.family: root.fontForWeight(Font.Normal, root.fontFamily)
                                }
                                MouseArea {
                                    id: mia
                                    anchors.fill: parent
                                    enabled: !mi.isSep && !mi.off
                                    hoverEnabled: true
                                    onContainsMouseChanged: if (!containsMouse && ui.armed === mi.modelData.label) ui.armed = ""
                                    onClicked: {
                                        if (mi.modelData.confirm === true && ui.armed !== mi.modelData.label) { ui.armed = mi.modelData.label; return; }
                                        var run = mi.modelData.run;
                                        ui.menuItem = null;
                                        if (run) run();
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
