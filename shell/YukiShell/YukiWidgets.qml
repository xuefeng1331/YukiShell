// Desktop widgets (macOS Tahoe style) for yukishell.
//
//   * one full-screen layer window on the first monitor, BELOW normal windows (WlrLayer.Bottom, namespace "yukiwidgets")
//   * click-through while you are not editing; edit mode shows free grid slots and snaps widget moves / sizes without overlap
//   * Weather data from Open-Meteo, a local-date Calendar, a live local-time Clock, and a Music player (MPRIS) widget
//   * settings + placed widgets are saved to ~/.config/yukiwidgets/settings.json
//
//   qs -c YukiShell ipc call widgets refresh        re-fetch the weather now
//   qs -c YukiShell ipc call widgets edit true      start / stop editing
//   qs -c YukiShell ipc call widgets span 0 4 2   make widget 0 cover 4 x 2 grid cells (drag its corner while editing)
//   qs -c YukiShell ipc call widgets move 0 40 60  move widget 0 to the free slot nearest to x 40, y 60
//   qs -c YukiShell ipc call widgets add clock liquid small   /   ... remove 2    add a widget / remove widget 2
//
// Hyprland: nothing is required. (No blur layerrule is needed, the Liquid Glass style blurs the wallpaper itself.)

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "I18n.js" as I18n

Scope {
    id: root

    property var hub: null
    readonly property var dock: hub ? hub.dock : null

    // --- state ---
    property bool editing: false
    property bool ready: false

    // saved settings
    property string tempUnit: "C"          // "C" | "F"
    property string locMode: "auto"        // "auto" (IP) | "city"
    property string cityName: ""
    property real widgetScale: 0.9         // the "Widget size" slider: scales every widget and the grid (0.6 - 1.5)

    readonly property string fontFamily: dock ? dock.fontFamily : "Open Runde"
    readonly property string boldFontFamily: hub && hub.boldFontFamily ? hub.boldFontFamily : "Open Runde Semibold"
    readonly property string configDir: Quickshell.env("HOME") + "/.config/yukiwidgets"

    // Liquid Glass look = the Appearance sliders (Translucency / Blur / Liquid strength) of the Dock + Menu Bar
    readonly property real glassOpacity: dock ? dock.glassOpacity : 0.42
    readonly property real glassBlur: dock ? dock.glassBlur + dock.dockBlurBoost : 5   // the Dock's blur (Blur slider + dockBlurBoost): every glass widget uses the Dock's glass
    readonly property real glassLiquid: dock ? dock.glassLiquid : 1.0
    readonly property real glassRim: dock ? dock.glassRim : 0.45
    readonly property real glassGrain: dock ? dock.glassGrain : 0.03
    readonly property bool darkGlass: dock ? dock.darkMode : true
    // Control Center border colour (follows the wallpaper's dominant colour)
    readonly property color borderTint: (hub && hub.bar) ? hub.bar.menuBorderColor : "#8A9AB5"

    // placed widgets: roles wid, wtype (weather | calendar | clock | player), wstyle, wsize, wmode (calendar: auto | light | dark), wx, wy
    property alias model: wmodel
    ListModel { id: wmodel }
    readonly property int widgetCount: wmodel.count
    property bool anyLiquid: false
    property int rev: 0                    // bumped on every change to the list, so Settings bindings can re-evaluate count()

    readonly property var styleNames: ({ liquid: "Liquid Glass", normal: "Normal", light: "Light", dark: "Dark" })
    readonly property var typeNames: ({ weather: "Weather", calendar: "Calendar", clock: "Clock", player: "Player", image: "Image" })
    readonly property var sizeNames: ({ small: "Small", medium: "Medium", large: "Large" })
    // Every widget covers a block of grid cells, its span: columns x rows, 1x1 up to 4x4 ("1x1", "2x1", "2x2", "4x1", "4x2", ...),
    // changed by dragging its corner while editing. A span also accepts the old size names: small 1x1, medium 2x1, large 2x2.
    readonly property int maxCols: 4
    readonly property int maxRows: 4
    function spanArr(x) {
        if (Array.isArray(x)) return [x[0], x[1]];
        if (x === "large") return [2, 2];
        if (x === "medium") return [2, 1];
        var m = /^(\d)x(\d)$/.exec(String(x));
        return m ? [Math.max(1, Math.min(maxCols, +m[1])), Math.max(1, Math.min(maxRows, +m[2]))] : [1, 1];
    }
    function spanStr(c, r) { return c + "x" + r; }
    // which of the three designs a span uses: one column = small (square, or a tall card), at least twice as wide as tall = the
    // wide (medium) one, anything else = large; the design then grows to fill the card (see the widgets' `fit`). The weather
    // takes its large design (hours + days) whenever it is two rows or taller: it spreads out instead of growing.
    function sizeClass(x, type) {
        var sp = spanArr(x);
        if (sp[0] === 1) return "small";
        if (type === "weather" && sp[1] >= 2) return "large";
        return sp[0] >= 2 * sp[1] ? "medium" : "large";
    }
    // the design a widget shows for its span: besides the three classic ones, every widget has its own design for a tall card
    // (one column, two or more rows), a strip (4 x 1) and a hero card (4 columns, two or more rows)
    function layoutOf(x, type) {
        var sp = spanArr(x), c = sp[0], r = sp[1];
        if (c === 1) return r === 1 ? "small" : "tall";
        if (r === 1) return c >= 4 ? "strip" : "medium";
        if (c >= 4) return "hero";
        return sizeClass(x, type);
    }
    function dims(x) {
        var sp = spanArr(x), c = sp[0], r = sp[1];
        var b = [c === 1 ? 185 : c * 179 + (c - 1) * 28 + 9, r === 1 ? 185 : r * 179 + (r - 1) * 23 + 4];
        return [Math.round(b[0] * widgetScale), Math.round(b[1] * widgetScale)];
    }
    // Size of the Player's contents (art, text, buttons) relative to the original design. The card itself fills the
    // normal widget footprint, like every other widget. 1.0 = original size.
    property real playerScale: 0.8
    // audio visualizer of the Player card (the settings live in the Menu Bar's settings, the spectrum comes from the shell's AudioVis)
    readonly property var visSrc: hub ? hub.vis : null
    readonly property bool visOn: (hub && hub.bar) ? hub.bar.visOn : false
    readonly property string visStyle: (hub && hub.bar) ? hub.bar.visStyle : "bars"
    readonly property string visColor: (hub && hub.bar) ? hub.bar.visColor : "white"
    readonly property real visGain: (hub && hub.bar) ? hub.bar.visGain : 1.0
    readonly property int visCount: (hub && hub.bar) ? hub.bar.visCount : 24
    readonly property real visWidth: (hub && hub.bar) ? hub.bar.visWidth : 0.62
    readonly property real mwGlow: (hub && hub.bar) ? hub.bar.mwGlow : 0.6
    readonly property bool mwMotion: (hub && hub.bar) ? hub.bar.mwMotion && !hub.bar.reduceMotion : true
    readonly property string mwBar: (hub && hub.bar) ? hub.bar.mwBar : "slim"
    readonly property string mwVisMode: (hub && hub.bar) ? hub.bar.mwVisMode : "ambient"
    readonly property color visAccent: (hub && hub.bar) ? hub.bar.accent : "#0A84FF"
    readonly property vector4d accentTintVec: (hub && hub.bar) ? hub.bar.accentTintVec : Qt.vector4d(0, 0, 0, 0)
    readonly property int gridCell: Math.round(179 * widgetScale)
    readonly property int gridGapX: Math.round(28 * widgetScale)
    readonly property int gridGapY: Math.round(23 * widgetScale)
    readonly property int gridLeft: 21
    readonly property int gridTop: 56
    readonly property int gridRight: 21
    readonly property int gridBottom: 24
    function screenSize() {
        var scr = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        return [scr ? scr.width : 1920, scr ? scr.height : 1080];
    }
    function gridInfo(screenW, screenH) {
        var availW = screenW - gridLeft - gridRight;
        var availH = screenH - gridTop - gridBottom;
        var cols = Math.max(1, Math.floor((availW + gridGapX) / (gridCell + gridGapX)));
        var rows = Math.max(1, Math.floor((availH + gridGapY) / (gridCell + gridGapY)));
        var usedW = cols * gridCell + (cols - 1) * gridGapX;
        var spareW = Math.max(0, availW - usedW);
        return { cols: cols, rows: rows, left: gridLeft + Math.floor(spareW / 2), top: gridTop,
                 pitchX: gridCell + gridGapX, pitchY: gridCell + gridGapY };
    }
    function spans(x) { return spanArr(x); }

    function recount() {
        var l = false;
        for (var i = 0; i < wmodel.count; i++) if (wmodel.get(i).wstyle === "liquid") l = true;
        anyLiquid = l;
        rev++;
    }
    function count(type, style, size) {
        var n = 0;
        for (var i = 0; i < wmodel.count; i++) {
            var m = wmodel.get(i);
            if (m.wtype === type && (style === undefined || m.wstyle === style) && (size === undefined || m.wsize === size)) n++;
        }
        return n;
    }
    function overlaps(x, y, d, skipId) {
        for (var i = 0; i < wmodel.count; i++) {
            var m = wmodel.get(i);
            if (m.wid === skipId) continue;
            var md = dims(m.wspan);
            if (x < m.wx + md[0] && x + d[0] > m.wx && y < m.wy + md[1] && y + d[1] > m.wy) return true;
        }
        return false;
    }
    function validSlot(span, col, row, skipId, g, screenW, screenH) {
        var d = dims(span), p = [g.left + col * g.pitchX, g.top + row * g.pitchY];
        return p[0] >= gridLeft && p[1] >= gridTop
            && p[0] + d[0] <= screenW - gridRight && p[1] + d[1] <= screenH - gridBottom
            && !overlaps(p[0], p[1], d, skipId) ? p : null;
    }
    function firstFreeSlot(size, skipId) {
        var ss = screenSize(), g = gridInfo(ss[0], ss[1]), span = spans(size);
        for (var row = 0; row <= g.rows - span[1]; row++)
            for (var col = g.cols - span[0]; col >= 0; col--) {
                var p = validSlot(size, col, row, skipId, g, ss[0], ss[1]);
                if (p) return p;
            }
        return null;
    }
    function nearestFreeSlot(id, x, y, size) {
        var ss = screenSize(), g = gridInfo(ss[0], ss[1]), span = spans(size);
        var best = null, bestDistance = Infinity;
        for (var row = 0; row <= g.rows - span[1]; row++)
            for (var col = 0; col <= g.cols - span[0]; col++) {
                var p = validSlot(size, col, row, id, g, ss[0], ss[1]);
                if (!p) continue;
                var dx = p[0] - x, dy = p[1] - y, distance = dx * dx + dy * dy;
                if (distance < bestDistance) { best = p; bestDistance = distance; }
            }
        return best;
    }
    function gridSlots(screenW, screenH) {
        var g = gridInfo(screenW, screenH), slots = [];
        for (var row = 0; row < g.rows; row++)
            for (var col = 0; col < g.cols; col++) {
                var p = validSlot("small", col, row, "", g, screenW, screenH);
                if (p) slots.push({ x: p[0], y: p[1] });
            }
        return slots;
    }
    function normalizePositions() {
        var old = [];
        for (var i = 0; i < wmodel.count; i++) {
            var m = wmodel.get(i);
            old.push({ id: m.wid, x: m.wx, y: m.wy, size: m.wspan });
            wmodel.setProperty(i, "wx", -100000);
            wmodel.setProperty(i, "wy", -100000);
        }
        var ss = screenSize();
        for (var j = 0; j < old.length; j++) {
            var item = old[j], p = nearestFreeSlot(item.id, item.x, item.y, item.size);
            if (!p) p = firstFreeSlot(item.size, item.id);
            if (!p) p = [Math.max(gridLeft, Math.min(ss[0] - gridRight - dims(item.size)[0], item.x)),
                         Math.max(gridTop, Math.min(ss[1] - gridBottom - dims(item.size)[1], item.y))];
            for (var k = 0; k < wmodel.count; k++)
                if (wmodel.get(k).wid === item.id) { wmodel.setProperty(k, "wx", p[0]); wmodel.setProperty(k, "wy", p[1]); break; }
        }
    }
    function addWidget(type, style, size, src) {
        var sz = size || "small";
        var p = firstFreeSlot(sz, "");
        if (!p) return false;
        wmodel.append({ wid: "w" + Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36),
                        wtype: type, wstyle: style, wsize: sz, wmode: "auto", wsrc: src || "", wx: p[0], wy: p[1], wspan: spanStr(spanArr(sz)[0], spanArr(sz)[1]) });
        recount(); scheduleSave();
        if (type === "weather") refreshSoon();
        return true;
    }
    function removeWidget(id) {
        for (var i = 0; i < wmodel.count; i++)
            if (wmodel.get(i).wid === id) { wmodel.remove(i); break; }
        recount(); scheduleSave();
    }
    // minus button in the Settings gallery: removes the most recently added widget of that kind
    function removeLast(type, style, size) {
        for (var i = wmodel.count - 1; i >= 0; i--) {
            var m = wmodel.get(i);
            if (m.wtype === type && m.wstyle === style && m.wsize === size) { wmodel.remove(i); break; }
        }
        recount(); scheduleSave();
    }
    function setStyle(id, style) {
        for (var i = 0; i < wmodel.count; i++)
            if (wmodel.get(i).wid === id) { wmodel.setProperty(i, "wstyle", style); break; }
        recount(); scheduleSave();
    }
    function setSource(id, src) {
        for (var i = 0; i < wmodel.count; i++)
            if (wmodel.get(i).wid === id) { wmodel.setProperty(i, "wsrc", src); break; }
        scheduleSave();
    }
    function setMode(id, mode) {
        var m = (mode === "light" || mode === "dark") ? mode : "auto";
        for (var i = 0; i < wmodel.count; i++)
            if (wmodel.get(i).wid === id) { wmodel.setProperty(i, "wmode", m); break; }
        scheduleSave();
    }
    // resize only onto a valid grid footprint; never let widgets overlap or sit between slots
    function setSize(id, size) {
        for (var i = 0; i < wmodel.count; i++) {
            if (wmodel.get(i).wid !== id) continue;
            var p = nearestFreeSlot(id, wmodel.get(i).wx, wmodel.get(i).wy, size);
            if (!p) return;
            wmodel.setProperty(i, "wsize", size);
            wmodel.setProperty(i, "wspan", spanStr(spanArr(size)[0], spanArr(size)[1]));
            wmodel.setProperty(i, "wx", p[0]);
            wmodel.setProperty(i, "wy", p[1]);
            break;
        }
        recount(); scheduleSave();
    }
    function moveWidget(id, x, y) {
        for (var i = 0; i < wmodel.count; i++)
            if (wmodel.get(i).wid === id) {
                var p = nearestFreeSlot(id, x, y, wmodel.get(i).wspan);
                if (!p) return;
                wmodel.setProperty(i, "wx", p[0]);
                wmodel.setProperty(i, "wy", p[1]);
                break;
            }
        recount(); scheduleSave();
    }
    // resize by the corner handle to c x r cells: keeps the widget where it is (or the nearest free spot); false if it does not fit
    function canSpan(id, c, r) {
        for (var i = 0; i < wmodel.count; i++)
            if (wmodel.get(i).wid === id) return nearestFreeSlot(id, wmodel.get(i).wx, wmodel.get(i).wy, [c, r]) !== null;
        return false;
    }
    function setSpan(id, c, r) {
        for (var i = 0; i < wmodel.count; i++) {
            if (wmodel.get(i).wid !== id) continue;
            var m = wmodel.get(i), p = nearestFreeSlot(id, m.wx, m.wy, [c, r]);
            if (!p) return false;
            wmodel.setProperty(i, "wspan", spanStr(c, r));
            wmodel.setProperty(i, "wsize", sizeClass([c, r], m.wtype));
            wmodel.setProperty(i, "wx", p[0]);
            wmodel.setProperty(i, "wy", p[1]);
            break;
        }
        recount(); scheduleSave();
        return true;
    }

    // --- image widgets ---
    // pickImage("", size) adds a new Image widget with the chosen picture; pickImage(id) changes the picture of widget id.
    // The chosen file is copied into ~/.config/yukiwidgets/images so the widget keeps working if the original moves.
    property string pickTargetId: ""
    property string pickTargetSize: "small"
    property string pickError: ""
    function pickImage(id, size) {
        if (imgPick.running) return;
        var fp = root.hub && root.hub.dock ? root.hub.dock.filePicker : null;
        pickTargetId = id || "";
        pickTargetSize = size || "small";
        pickError = "";
        if (!fp) { pickError = "The picture chooser is not ready yet."; return; }
        fp.pick({ mode: "image", title: I18n.tr("Choose a picture") }, function (f) {
            if (f === "") return;
            imgPick.command = ["sh", "-c",
                "f=\"$2\"; [ -f \"$f\" ] || exit 0; "
                + "d=\"$1/images\"; mkdir -p \"$d\" || { echo 'ERR:cannot create the images folder'; exit 0; }; "
                + "n=\"$(date +%s)-$(printf '%s' \"$(basename \"$f\")\" | tr -c 'A-Za-z0-9._-' '_')\"; "
                + "cp -f \"$f\" \"$d/$n\" && echo \"OK:$d/$n\" || echo 'ERR:could not copy the picture'",
                "sh", root.configDir, f];
            imgPick.running = true;
        });
    }
    Process {
        id: imgPick
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.indexOf("OK:") === 0) {
                    var p = t.substring(3);
                    if (root.pickTargetId === "") { if (!root.addWidget("image", "normal", root.pickTargetSize, p)) root.pickError = I18n.tr("No free space on the desktop for another widget."); }
                    else root.setSource(root.pickTargetId, p);
                } else if (t.indexOf("ERR:") === 0) {
                    root.pickError = t.substring(4);
                    console.log("[yukiwidgets] image:", root.pickError);
                }
            }
        }
    }

    // --- persistence ---
    function scheduleSave() { if (ready) saveTimer.restart(); }
    onTempUnitChanged: { scheduleSave(); refreshSoon(); }
    onLocModeChanged: { scheduleSave(); refreshSoon(); }
    onCityNameChanged: { scheduleSave(); refreshSoon(); }
    onWidgetScaleChanged: { scheduleSave(); if (ready) rescaleTimer.restart(); }
    // after the slider settles, snap every widget onto the new grid
    Timer { id: rescaleTimer; interval: 300; onTriggered: { root.normalizePositions(); root.recount(); root.scheduleSave(); } }

    function saveSettings() {
        var list = [];
        for (var i = 0; i < wmodel.count; i++) {
            var m = wmodel.get(i);
            list.push({ id: m.wid, type: m.wtype, style: m.wstyle, size: m.wsize, span: m.wspan, mode: m.wmode || "auto", src: m.wsrc || "", x: m.wx, y: m.wy });
        }
        store.setText(JSON.stringify({ tempUnit: tempUnit, locMode: locMode, cityName: cityName, widgetScale: widgetScale, widgets: list }, null, 2));
    }
    function applySettings(o) {
        if (!o || typeof o !== "object") return;
        if (o.tempUnit === "C" || o.tempUnit === "F") tempUnit = o.tempUnit;
        if (o.locMode === "auto" || o.locMode === "city") locMode = o.locMode;
        if (typeof o.cityName === "string") cityName = o.cityName;
        if (typeof o.widgetScale === "number" && isFinite(o.widgetScale)) widgetScale = Math.max(0.6, Math.min(1.5, o.widgetScale));
        if (Array.isArray(o.widgets)) {
            wmodel.clear();
            for (var i = 0; i < o.widgets.length; i++) {
                var w = o.widgets[i];
                if (!w || (w.type !== "weather" && w.type !== "calendar" && w.type !== "clock" && w.type !== "player" && w.type !== "image")) continue;
                wmodel.append({ wid: String(w.id || ("w" + i)), wtype: w.type,
                                wstyle: w.type === "image" ? "normal" : (w.type === "clock" || w.type === "player")
                                    ? ((w.style === "light" || w.style === "dark") ? w.style : "liquid")
                                    : (w.style === "normal" ? "normal" : "liquid"),
                                wsize: (w.size === "medium" || w.size === "large") ? w.size : "small",
                                wmode: (w.mode === "light" || w.mode === "dark") ? w.mode : "auto",
                                wsrc: typeof w.src === "string" ? w.src : "",
                                wx: Number(w.x) || 0, wy: Number(w.y) || 0,
                                wspan: spanStr.apply(null, spanArr(/^\dx\d$/.test(String(w.span)) ? w.span : w.size)) });
                wmodel.setProperty(wmodel.count - 1, "wsize", sizeClass(wmodel.get(wmodel.count - 1).wspan, w.type));
            }
        }
        normalizePositions();
        recount();
    }
    Process { command: ["mkdir", "-p", root.configDir]; running: true }
    FileView {
        id: store
        path: root.configDir + "/settings.json"
        printErrors: false
        onLoaded: {
            try { root.applySettings(JSON.parse(text())); } catch (err) { }
            root.ready = true;
            root.scheduleSave();
            root.refresh();
        }
        // first start (no settings yet): a wide Now Playing widget top-left and the weather top-right, both Liquid Glass
        onLoadFailed: {
            var ss = root.screenSize();
            root.applySettings({ widgets: [
                { id: "wplayer", type: "player", style: "liquid", size: "medium", span: "3x1", x: root.gridLeft, y: root.gridTop },
                { id: "wweather", type: "weather", style: "liquid", size: "medium", span: "2x1",
                  x: ss[0] - root.gridRight - root.dims("2x1")[0], y: root.gridTop } ] });
            root.ready = true;
            root.scheduleSave();
            root.refresh();
        }
    }
    Timer { id: saveTimer; interval: 400; onTriggered: root.saveSettings() }

    // --- music player (MPRIS) ---
    // which player to show: see PlayerPicker.qml (same rule as the Menu Bar's media widget)
    PlayerPicker { id: playerPick }
    readonly property var player: playerPick.player
    // MPRIS does not announce the playback position; ask for it once a second while something plays and a Player widget exists
    Timer {
        interval: 1000
        repeat: true
        running: root.player !== null && root.player.isPlaying && root.count("player") > 0
        onTriggered: { try { root.player.positionChanged(); } catch (err) { } }
    }
    // screen rectangles of the Player widgets: they stay clickable while the rest of the layer is click-through
    readonly property var playerRects: {
        var r = rev, out = [];
        for (var i = 0; i < wmodel.count; i++) {
            var m = wmodel.get(i);
            if (m.wtype !== "player") continue;
            var d = dims(m.wspan);
            out.push([m.wx, m.wy, d[0], d[1]]);
        }
        return out;
    }
    function pr(i, k) { var r = playerRects[i]; return r ? r[k] : 0; }

    // --- weather data (Open-Meteo) ---
    property bool wxReady: false
    property string wxCity: "—"
    property bool wxLocated: true
    property int wxTemp: 0
    property int wxHi: 0
    property int wxLo: 0
    property int wxCode: 0
    property bool wxDay: true
    property string wxError: ""
    property real wxLat: 0
    property real wxLon: 0
    property string wxPlace: ""
    property var wxHourly: []
    property var wxDaily: []
    property string wxCoordsFor: ""          // wxKey the coordinates above belong to

    // The last good forecast (and the city's coordinates) are kept in ~/.cache/yukishell/weather.json: after a restart the widget
    // shows them at once and refreshes in the background, instead of "Loading..." and, when the first request of the session
    // failed (no network yet, a DNS hiccup), "Unavailable" for the next 15 minutes.
    readonly property string wxKey: (locMode === "city" ? "city:" + cityName.trim().toLowerCase() : "auto") + ":" + tempUnit
    FileView {
        id: wxCacheFile
        path: Quickshell.env("HOME") + "/.cache/yukishell/weather.json"
        printErrors: false
        onLoaded: root.wxFromCache()
    }
    function wxFromCache() {
        try {
            var c = JSON.parse(wxCacheFile.text());
            if (!c || c.key !== wxKey || wxReady) return;
            wxCoordsFor = c.key;
            wxLat = c.lat; wxLon = c.lon; wxPlace = c.place; wxLocated = c.located;
            wxTemp = c.temp; wxCode = c.code; wxDay = c.day; wxHi = c.hi; wxLo = c.lo;
            wxHourly = c.hourly || []; wxDaily = c.daily || [];
            wxCity = c.place; wxReady = true; wxError = "";
        } catch (e) {}
    }
    function wxSave() {
        wxCacheFile.setText(JSON.stringify({ key: wxKey, at: Date.now(), lat: wxLat, lon: wxLon, place: wxPlace, located: wxLocated,
            temp: wxTemp, code: wxCode, day: wxDay, hi: wxHi, lo: wxLo, hourly: wxHourly, daily: wxDaily }));
    }
    // a failed lookup is tried again soon (5 s, 15 s, 30 s, 1 min, then every 2 min) rather than at the next 15-minute refresh;
    // meanwhile a forecast we already have stays on screen
    property int wxFails: 0
    function wxFailed(why) {
        if (!wxReady) wxError = why;
        wxRetry.interval = [5000, 15000, 30000, 60000][Math.min(wxFails, 3)] || 120000;
        if (wxFails >= 4) wxRetry.interval = 120000;
        wxFails++;
        wxRetry.restart();
    }
    Timer { id: wxRetry; onTriggered: root.refresh() }

    function wmo(code, day) {
        switch (code) {
        case 0:  return day ? { t: I18n.tr("Sunny"), k: "sun" } : { t: I18n.tr("Clear Sky"), k: "moon" };
        case 1:  return day ? { t: I18n.tr("Mostly Sunny"), k: "sun" } : { t: I18n.tr("Mostly Clear"), k: "moon" };
        case 2:  return { t: I18n.tr("Partly Cloudy"), k: day ? "partly" : "partlyNight" };
        case 3:  return { t: I18n.tr("Cloudy"), k: "cloud" };
        case 45: case 48: return { t: I18n.tr("Foggy"), k: "fog" };
        case 51: case 53: case 55: return { t: I18n.tr("Drizzle"), k: "rain" };
        case 56: case 57: return { t: I18n.tr("Freezing Drizzle"), k: "rain" };
        case 61: return { t: I18n.tr("Light Rain"), k: "rain" };
        case 63: return { t: I18n.tr("Rain"), k: "rain" };
        case 65: return { t: I18n.tr("Heavy Rain"), k: "rain" };
        case 66: case 67: return { t: I18n.tr("Freezing Rain"), k: "rain" };
        case 71: return { t: I18n.tr("Light Snow"), k: "snow" };
        case 73: return { t: I18n.tr("Snow"), k: "snow" };
        case 75: case 77: return { t: I18n.tr("Heavy Snow"), k: "snow" };
        case 80: case 81: return { t: I18n.tr("Showers"), k: "rain" };
        case 82: return { t: I18n.tr("Heavy Showers"), k: "rain" };
        case 85: case 86: return { t: I18n.tr("Snow Showers"), k: "snow" };
        case 95: case 96: case 99: return { t: I18n.tr("Thunderstorms"), k: "storm" };
        }
        return { t: I18n.tr("Cloudy"), k: "cloud" };
    }
    readonly property var wxInfo: wmo(wxCode, wxDay)
    function hourLabel(iso, first) {
        if (first) return I18n.tr("Now");
        var h = parseInt(iso.substr(11, 2));
        return (h % 12 === 0 ? 12 : h % 12) + (h < 12 ? "AM" : "PM");
    }
    function dayLabel(iso, i) {
        if (i === 0) return "Today";
        var d = new Date(parseInt(iso.substr(0, 4)), parseInt(iso.substr(5, 2)) - 1, parseInt(iso.substr(8, 2)));
        return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()];
    }

    function refresh() {
        if (!ready || count("weather") === 0) return;
        if (locProc.running || geoProc.running || wxProc.running) return;
        if (locMode === "city" && cityName.trim() !== "") {
            // the city's position doesn't change: once known (cache or an earlier lookup), go straight to the forecast
            if (wxPlace !== "" && !wxLocated && wxCoordsFor === wxKey) wxProc.running = true;
            else geoProc.running = true;
        }
        else { locProc.running = true; }
    }
    function refreshSoon() { if (ready) refreshDebounce.restart(); }
    Timer { id: refreshDebounce; interval: 700; onTriggered: root.refresh() }
    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.ready && root.count("weather") > 0
        onTriggered: root.refresh()
    }
    onWidgetCountChanged: if (count("weather") > 0 && !wxReady) refreshSoon()

    // automatic location (IP): ipwho.is, falling back to ipapi.co
    Process {
        id: locProc
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[yukiwidgets] location curl:", text.trim().substring(0, 200)) }
        command: ["sh", "-c",
            "o=$(curl -fsS --max-time 8 https://ipwho.is/ 2>/dev/null); "
            + "case \"$o\" in *'\"latitude\"'*) printf '%s' \"$o\";; *) curl -fsS --max-time 8 https://ipapi.co/json/;; esac"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(text);
                    if (o.latitude === undefined) throw "no position";
                    root.wxLat = Number(o.latitude); root.wxLon = Number(o.longitude);
                    root.wxPlace = o.city || o.region || o.country || I18n.tr("Current Location");
                    root.wxLocated = true;
                    wxProc.running = true;
                } catch (err) { root.wxFailed("location lookup failed"); console.log("[yukiwidgets] location:", err, text.substring(0, 120)); }
            }
        }
    }
    // a city typed in Settings
    Process {
        id: geoProc
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[yukiwidgets] geocoding curl:", text.trim().substring(0, 200)) }
        command: ["curl", "-fsS", "--max-time", "8", "-G", "https://geocoding-api.open-meteo.com/v1/search",
                  "--data-urlencode", "name=" + root.cityName.trim(), "-d", "count=1", "-d", "language=en", "-d", "format=json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var r = JSON.parse(text).results[0];
                    root.wxLat = Number(r.latitude); root.wxLon = Number(r.longitude);
                    root.wxPlace = r.name;
                    root.wxLocated = false;
                    root.wxCoordsFor = root.wxKey;
                    wxProc.running = true;
                } catch (err) {
                    // an empty answer is a network problem (try again soon); an answer without results is a city that doesn't exist
                    if (text.trim() !== "" && text.indexOf("results") < 0) { root.wxError = "city not found"; root.wxReady = false; }
                    else root.wxFailed("location lookup failed");
                    console.log("[yukiwidgets] geocoding:", err);
                }
            }
        }
    }
    Process {
        id: wxProc
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[yukiwidgets] forecast curl:", text.trim().substring(0, 200)) }
        command: ["curl", "-fsS", "--max-time", "10", "-G", "https://api.open-meteo.com/v1/forecast",
                  "-d", "latitude=" + root.wxLat, "-d", "longitude=" + root.wxLon,
                  "-d", "current=temperature_2m,weather_code,is_day",
                  "-d", "hourly=temperature_2m,weather_code,is_day",
                  "-d", "daily=temperature_2m_max,temperature_2m_min,weather_code",
                  "-d", "temperature_unit=" + (root.tempUnit === "F" ? "fahrenheit" : "celsius"),
                  "-d", "timezone=auto", "-d", "forecast_days=6"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(text);
                    root.wxTemp = Math.round(o.current.temperature_2m);
                    root.wxCode = o.current.weather_code;
                    root.wxDay = o.current.is_day === 1;
                    root.wxHi = Math.round(o.daily.temperature_2m_max[0]);
                    root.wxLo = Math.round(o.daily.temperature_2m_min[0]);
                    // next hours (starting with the current one) and the coming days
                    var hrs = [], ht = o.hourly.time, cur = String(o.current.time).substring(0, 13), start = 0, i;
                    for (i = 0; i < ht.length; i++) if (ht[i].substring(0, 13) === cur) { start = i; break; }
                    for (i = start; i < ht.length && hrs.length < 6; i++)
                        hrs.push({ h: root.hourLabel(ht[i], hrs.length === 0), t: Math.round(o.hourly.temperature_2m[i]),
                                   k: root.wmo(o.hourly.weather_code[i], o.hourly.is_day[i] === 1).k });
                    var dys = [], dt = o.daily.time;
                    for (i = 0; i < dt.length && i < 5; i++)
                        dys.push({ d: root.dayLabel(dt[i], i), lo: Math.round(o.daily.temperature_2m_min[i]),
                                   hi: Math.round(o.daily.temperature_2m_max[i]), k: root.wmo(o.daily.weather_code[i], true).k });
                    root.wxHourly = hrs; root.wxDaily = dys;
                    root.wxCity = root.wxPlace;
                    root.wxReady = true;
                    root.wxError = "";
                    root.wxFails = 0;
                    root.wxSave();
                } catch (err) { root.wxFailed("weather lookup failed"); console.log("[yukiwidgets] forecast:", err, text.substring(0, 120)); }
            }
        }
    }

    // --- Liquid Glass backend ---
    // Same shader as the Dock / Menu Bar (liquidglass.frag), compiled with qsb into ~/.config/yukiwidgets/.
    property string glassState: "idle"                     // idle -> building -> ready | failed
    readonly property string glassShaderSrc: decodeURIComponent(Qt.resolvedUrl("liquidglass.frag").toString().replace("file://", ""))
    readonly property string glassShaderOut: configDir + "/liquidglass.frag.qsb"
    onAnyLiquidChanged: if (anyLiquid) startGlass()
    onReadyChanged: { if (ready) wxFromCache(); if (ready && anyLiquid) startGlass(); }
    function startGlass() {
        if (!ready || glassState === "ready" || glassState === "building" || glassState === "failed") return;
        glassState = "building";
        qsbProc.running = true;
        if (hub) hub.refreshWallpaper();
    }
    Process {
        id: qsbProc
        command: ["sh", "-c",
            "mkdir -p \"$(dirname \"$2\")\"; "
            // already compiled from this very source (it is newer than the .frag): nothing to do, the glass is ready at once
            + "[ -s \"$2\" ] && [ \"$2\" -nt \"$1\" ] && exit 0; "
            + "for q in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb /usr/lib/qt/bin/qsb; do "
            + "  if command -v \"$q\" >/dev/null 2>&1; then \"$q\" --qt6 -o \"$2\" \"$1\" && exit 0; fi; "
            + "done; "
            + "[ -f \"$1.qsb\" ] && cp \"$1.qsb\" \"$2\" && exit 0; "
            + "exit 1",
            "sh", root.glassShaderSrc, root.glassShaderOut]
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[yukiwidgets-glass] qsb:", text.trim()) }
        onExited: (code, status) => root.glassState = (code === 0 ? "ready" : "failed")
    }
    Binding { target: root.hub; property: "widgetsWantWallpaper"; value: root.anyLiquid }

    // animated wallpaper the widget glass plays behind itself: only while the Dock's "Real-time glass" AND "Animated wallpaper in glass" are on
    readonly property string liveWallVideo: (dock && dock.glassLive && hub && hub.bar) ? hub.bar.glassVideo : ""
    // the widgets sit on the first screen's desktop: their video pauses with the wallpaper (Game Mode, the menu bar button, "Pause behind windows")
    readonly property bool liveWallPaused: {
        if (!hub || !hub.bar) return false;
        return Quickshell.screens.length > 0 ? hub.bar.wallIdle(Quickshell.screens[0].name) : hub.bar.gaming;
    }
    // wallpaper behind the widgets (same lookup as the Dock's Liquid Glass)
    readonly property var wallpaperMap: hub ? hub.wallpaperMap : ({})
    function wallpaperFor(screenName) {
        var p = (dock && dock.wallpaperPath !== "") ? dock.wallpaperPath
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

    // --- the desktop layer ---
    Variants {
        model: (root.ready && Quickshell.screens.length > 0 && (root.widgetCount > 0 || root.editing)) ? [Quickshell.screens[0]] : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { left: true; right: true; top: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "yukiwidgets"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // click-through unless editing; only the Player widgets (up to 4) take clicks, for their buttons
            mask: Region {
                item: root.editing ? ui : null
                regions: [ Region { item: hit0 }, Region { item: hit1 }, Region { item: hit2 }, Region { item: hit3 } ]
            }

            Item {
                id: ui
                anchors.fill: parent

                Item { id: hit0; x: root.pr(0, 0); y: root.pr(0, 1); width: root.pr(0, 2); height: root.pr(0, 3) }
                Item { id: hit1; x: root.pr(1, 0); y: root.pr(1, 1); width: root.pr(1, 2); height: root.pr(1, 3) }
                Item { id: hit2; x: root.pr(2, 0); y: root.pr(2, 1); width: root.pr(2, 2); height: root.pr(2, 3) }
                Item { id: hit3; x: root.pr(3, 0); y: root.pr(3, 1); width: root.pr(3, 2); height: root.pr(3, 3) }

                // ONE video player for every widget's glass: each widget shows its part of it through a WallSlice (it used to be one
                // player per widget). It is never drawn itself, only through the slices.
                LiveWall {
                    id: sharedWall
                    opacity: 0          // never drawn itself (a ShaderEffectSource ignores its source's own opacity)
                    x: 0; y: 0
                    width: win.modelData.width; height: win.modelData.height
                    video: root.liveWallVideo
                    live: root.liveWallVideo !== ""
                    paused: root.liveWallPaused
                    clock: root.hub && root.hub.bar ? root.hub.bar.wallClock : null
                }

                Rectangle {   // slight dim while editing
                    anchors.fill: parent
                    color: "black"
                    opacity: root.editing ? 0.16 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                Repeater {   // free Small-sized grid cells; Medium and Large snap across 2-cell footprints
                    model: {
                        var revision = root.rev;
                        return root.editing ? root.gridSlots(win.modelData.width, win.modelData.height) : [];
                    }
                    delegate: Rectangle {
                        required property var modelData
                        x: modelData.x
                        y: modelData.y
                        width: root.gridCell
                        height: root.gridCell
                        radius: 28
                        color: Qt.rgba(1, 1, 1, 0.018)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                    }
                }

                Repeater {
                    model: root.model
                    delegate: Item {
                        id: ww
                        required property string wid
                        required property string wtype
                        required property string wstyle
                        required property string wsize
                        required property string wmode
                        required property string wsrc
                        required property real wx
                        required property real wy
                        required property string wspan

                        // while the corner is dragged the widget snaps live to the grid block under the pointer ("" = not resizing)
                        property string liveSpan: ""
                        property bool liveFits: true
                        readonly property string effSpan: liveSpan !== "" ? liveSpan : wspan
                        readonly property string effClass: root.sizeClass(effSpan, wtype)
                        property real dragDX: 0
                        property real dragDY: 0
                        x: wx + dragDX
                        y: wy + dragDY
                        readonly property var baseDims: root.dims(effSpan)
                        readonly property real radiusPx: 28 * root.widgetScale * (effClass === "small" ? 168 / 158 : (effClass === "medium" ? 358 / 338 : 1))
                        width: baseDims[0]
                        height: baseDims[1]

                        WidgetVisual {
                            id: visual
                            anchors.fill: parent
                            host: root
                            wallItem: sharedWall
                            wtype: ww.wtype; wstyle: ww.wstyle; wsize: ww.effClass; wmode: ww.wmode; wsrc: ww.wsrc
                            wlay: root.layoutOf(ww.effSpan, ww.wtype)
                            sx: ww.x; sy: ww.y
                            sname: win.modelData.name; sw: win.modelData.width; sh: win.modelData.height
                        }

                        scale: dragArea.pressed ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        z: dragArea.pressed || gripMa.pressed ? 10 : 1

                        // edit mode: outline + drag + remove
                        Rectangle {
                            anchors.fill: parent
                            visible: root.editing
                            radius: ww.radiusPx
                            color: "transparent"
                            border.width: 2
                            border.color: ww.liveFits ? Qt.rgba(1, 1, 1, 0.55) : "#FF453A"
                        }
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            enabled: root.editing
                            cursorShape: root.editing ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                            property real px: 0
                            property real py: 0
                            onPressed: mouse => { var p = mapToItem(ui, mouse.x, mouse.y); px = p.x; py = p.y; }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                var p = mapToItem(ui, mouse.x, mouse.y);
                                var nx = Math.max(0, Math.min(ui.width - ww.width, ww.wx + (p.x - px)));
                                var ny = Math.max(0, Math.min(ui.height - ww.height, ww.wy + (p.y - py)));
                                ww.dragDX = nx - ww.wx;
                                ww.dragDY = ny - ww.wy;
                            }
                            onReleased: {
                                root.moveWidget(ww.wid, ww.wx + ww.dragDX, ww.wy + ww.dragDY);
                                ww.dragDX = 0; ww.dragDY = 0;
                            }
                        }
                        Rectangle {   // image widget: choose another picture
                            visible: root.editing && ww.wtype === "image"
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                            width: chooseText.width + 22; height: 26; radius: 13
                            color: chooseMa.pressed ? "#D8D8DC" : "#F2F2F5"
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.18)
                            Text { id: chooseText; anchors.centerIn: parent; text: I18n.tr("Choose Image\u2026"); color: "#3A3A3C"; font.family: root.fontFamily; font.pixelSize: 12 }
                            MouseArea { id: chooseMa; anchors.fill: parent; onClicked: root.pickImage(ww.wid, "small") }
                        }
                        // resize handle (bottom-right corner): drag it to make the widget cover more or fewer grid cells (2x1, 2x2, 4x1, 4x2...)
                        Rectangle {
                            id: sizeGrip
                            visible: root.editing
                            x: parent.width - width + 8; y: parent.height - height + 8
                            width: 26; height: 26; radius: 13
                            color: gripMa.pressed ? "#D8D8DC" : "#F2F2F5"
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.18)
                            z: 20
                            Canvas {   // two diagonal arrow heads
                                anchors.fill: parent
                                onPaint: {
                                    var c = getContext("2d"); c.reset();
                                    c.strokeStyle = "#3A3A3C"; c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round";
                                    c.beginPath(); c.moveTo(8, 18); c.lineTo(18, 8); c.stroke();
                                    c.beginPath(); c.moveTo(8, 13); c.lineTo(8, 18); c.lineTo(13, 18); c.stroke();
                                    c.beginPath(); c.moveTo(13, 8); c.lineTo(18, 8); c.lineTo(18, 13); c.stroke();
                                }
                            }
                            MouseArea {
                                id: gripMa
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.SizeFDiagCursor
                                preventStealing: true
                                onPositionChanged: mouse => {
                                    if (!pressed) return;
                                    var p = mapToItem(ui, mouse.x, mouse.y);
                                    var g = root.gridInfo(ui.width, ui.height);
                                    // the cell under the pointer becomes the bottom-right cell of the widget
                                    var c = Math.max(1, Math.min(root.maxCols, Math.ceil((p.x - ww.wx + root.gridGapX / 2) / g.pitchX)));
                                    var r = Math.max(1, Math.min(root.maxRows, Math.ceil((p.y - ww.wy + root.gridGapY / 2) / g.pitchY)));
                                    var sp = root.spanStr(c, r);
                                    if (sp === ww.liveSpan) return;
                                    ww.liveFits = root.canSpan(ww.wid, c, r);
                                    ww.liveSpan = sp;
                                }
                                onReleased: {
                                    if (ww.liveSpan !== "" && ww.liveFits) {
                                        var sp = root.spanArr(ww.liveSpan);
                                        root.setSpan(ww.wid, sp[0], sp[1]);
                                    }
                                    ww.liveSpan = ""; ww.liveFits = true;   // no room for that block: it springs back
                                }
                                onCanceled: { ww.liveSpan = ""; ww.liveFits = true; }
                            }
                        }
                        Rectangle {   // the block being picked, while resizing
                            visible: gripMa.pressed && ww.liveSpan !== ""
                            anchors.centerIn: parent
                            width: spanText.width + 24; height: 30; radius: 15
                            color: ww.liveFits ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0.75, 0.12, 0.1, 0.85)
                            z: 20
                            Text { id: spanText; anchors.centerIn: parent; text: ww.liveSpan.replace("x", " \u00D7 "); color: "white"; font.family: root.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold }
                        }
                        Rectangle {   // "−" remove badge
                            visible: root.editing
                            x: -8; y: -8
                            width: 24; height: 24; radius: 12
                            color: minusMa.pressed ? "#D8D8DC" : "#F2F2F5"
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.18)
                            Rectangle { anchors.centerIn: parent; width: 10; height: 2; radius: 1; color: "#3A3A3C" }
                            MouseArea { id: minusMa; anchors.fill: parent; onClicked: root.removeWidget(ww.wid) }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "widgets"
        function refresh(): void { root.refresh(); }
        function edit(on: bool): void { root.editing = on; }
        // add a widget (type: weather | calendar | clock | player; style: liquid | normal | light | dark; size: small | medium | large)
        // in the first free slot, or remove the widget at `index`
        function add(type: string, style: string, size: string): bool { return root.addWidget(type, style, size, ""); }
        function remove(index: int): void { if (index >= 0 && index < wmodel.count) root.removeWidget(wmodel.get(index).wid); }
        // move the widget at `index` to the free grid slot nearest to x, y (screen pixels)
        function move(index: int, x: int, y: int): void {
            if (index >= 0 && index < wmodel.count) root.moveWidget(wmodel.get(index).wid, x, y);
        }
        // grid block of the widget at `index` (0 = the first one placed): cols x rows, 1..4 each; false if it does not fit
        function span(index: int, cols: int, rows: int): bool {
            if (index < 0 || index >= wmodel.count) return false;
            return root.setSpan(wmodel.get(index).wid, Math.max(1, Math.min(root.maxCols, cols)), Math.max(1, Math.min(root.maxRows, rows)));
        }
    }
}
