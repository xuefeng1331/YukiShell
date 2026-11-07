local mod = "SUPER"

local keys = require("scripts.keys")
local bind, section = keys.bind, keys.section

section("Apps")

bind(mod .. " + Return",         hl.dsp.exec_cmd("kitty", { tile = true }), "Open Terminal")
bind(mod .. " + E",              hl.dsp.exec_cmd("dolphin", { tile = true }), "Open Files")
bind(mod .. " + W",              hl.dsp.exec_cmd("chromium"), "Open Browser")
bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty", { float = true, center = true, size = "900 560" }), "Open a Floating Terminal")
bind(mod .. " + SHIFT + E",      hl.dsp.exec_cmd("dolphin", { float = true, center = true, size = "900 560" }), "Open a Floating Files Explorer")
bind(mod .. " + SHIFT + W",      hl.dsp.exec_cmd("~/.config/hypr/bin/float-chromium"), "Open a Floating Browser")
bind(mod .. " + ALT + D",        hl.dsp.exec_cmd("~/.config/hypr/bin/dashboard"), "Dashboard")
bind(mod .. " + SHIFT + Tab",    hl.dsp.exec_cmd("~/.config/hypr/bin/toggle-opacity"), "Terminal Transparency")

section("Windows")
bind(mod .. " + Q",              hl.dsp.window.close(), "Close Window")
bind(mod .. " + SHIFT + Q",      hl.dsp.window.kill(),  "Force Quit Window")
bind(mod .. " + F",              hl.dsp.window.fullscreen(), "Full Screen")
bind(mod .. " + ALT + space",    hl.dsp.exec_cmd("~/.config/hypr/bin/toggle-float"), "Toggle Floating")
bind(mod .. " + P",              hl.dsp.window.pseudo(), "Pseudo-tile Window")
bind(mod .. " + J",              hl.dsp.layout("togglesplit"), "Toggle Split Direction")

section("Focus and Workspaces")
bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }), "Move Focus", { fixed = true })
bind(mod .. " + right", hl.dsp.focus({ direction = "right" }), "Move Focus", { fixed = true })
bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }), "Move Focus", { fixed = true })
bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }), "Move Focus", { fixed = true })
bind(mod .. " + H",     hl.dsp.focus({ direction = "left" }), "Move Focus", { fixed = true })
bind(mod .. " + K",     hl.dsp.focus({ direction = "up" }), "Move Focus", { fixed = true })
bind(mod .. " + N",     hl.dsp.focus({ direction = "down" }), "Move Focus", { fixed = true })

-- "yukiws" tells YukiShell's DesktopFocus to keep the keyboard on the desktop when the pointer rests on it after the switch
local function toWorkspace(ws)
    return function()
        hl.dispatch(hl.dsp.focus({ workspace = ws }))
        hl.dispatch(hl.dsp.event("yukiws"))
    end
end

for i = 1, 10 do
    local key = i % 10
    bind(mod .. " + " .. key,         toWorkspace(i),       "Go to Workspace 1–10 (0 = 10)", { fixed = true })
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), "Move Window to Workspace 1–10", { fixed = true })
    bind(mod .. " + ALT + " .. key,   hl.dsp.window.move({ workspace = i, follow = false }), "Send Window to Workspace 1–10", { fixed = true })
end

bind(mod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "+1" }), "Move Window to Next Workspace")
bind(mod .. " + SHIFT + Page_Up",   hl.dsp.window.move({ workspace = "-1" }), "Move Window to Previous Workspace")
bind(mod .. " + SHIFT + O",      hl.dsp.window.move({ monitor = "+1" }), "Move Window to Next Monitor")
bind(mod .. " + mouse_down", toWorkspace("e+1"), "Switch Workspace with the Scroll Wheel", { fixed = true })
bind(mod .. " + mouse_up",   toWorkspace("e-1"), "Switch Workspace with the Scroll Wheel", { fixed = true })

section("Windows")
bind(mod .. " + M",              hl.dsp.window.move({ workspace = "special:minimized", follow = false }), "Minimize Window")
bind(mod .. " + SHIFT + M",      hl.dsp.workspace.toggle_special("minimized"), "Show Minimized Windows")
bind(mod .. " + ALT + S",        hl.dsp.exec_cmd("~/.config/hypr/bin/hide-window"), "Hide or Show Window")
bind(mod .. " + SHIFT + F",      hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "Maximize Window")
bind(mod .. " + SHIFT + P",      hl.dsp.window.pin({ action = "toggle" }), "Pin Window to All Workspaces")
bind(mod .. " + C",              hl.dsp.window.center(), "Center Window")
-- Dragging a window (Super + left button) onto a workspace number in the menu bar sends it there:
-- Lua reports the drag to YukiShell as "yukidrag" events, the shell owns the drop targets and the drop
local drag = {}
local function windowAt(c)
    local best
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and w.visible and not w.hidden and c.x >= w.at.x and c.y >= w.at.y and c.x < w.at.x + w.size.x and c.y < w.at.y + w.size.y
            and (not best or (w.floating and not best.floating)
                 or (w.floating == best.floating and w.focus_history_id < best.focus_history_id)) then
            best = w
        end
    end
    return best
end
local function dragTick()
    local c = hl.get_cursor_pos()
    if drag.addr and c then hl.dispatch(hl.dsp.event(string.format("yukidrag move %d %d", math.floor(c.x), math.floor(c.y)))) end
end
local function dragStart()
    local c = hl.get_cursor_pos()
    local w = c and windowAt(c)
    if not w then return end
    drag.addr = w.address
    hl.dispatch(hl.dsp.event(string.format("yukidrag start %s %d %d %d %d %d %d %d %d %s", w.address, math.floor(w.at.x), math.floor(w.at.y),
        w.floating and 1 or 0, w.workspace and w.workspace.id or 0, math.floor(w.size.x), math.floor(w.size.y),
        math.floor(c.x), math.floor(c.y), w.class)))
    if drag.timer then drag.timer:set_enabled(true) else drag.timer = hl.timer(dragTick, { timeout = 33, type = "repeat" }) end
end
local function dragEnd()
    if not drag.addr then return end
    drag.addr = nil
    if drag.timer then drag.timer:set_enabled(false) end
    hl.dispatch(hl.dsp.event("yukidrag end"))
end
hl.bind(mod .. " + mouse:272", dragStart, { non_consuming = true })
hl.bind(mod .. " + mouse:272", dragEnd, { release = true, non_consuming = true })
hl.bind("mouse:272", dragEnd, { release = true, non_consuming = true })   -- Super let go before the button

bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   "Move Window with the Mouse", { mouse = true, fixed = true })
bind(mod .. " + mouse:273",  hl.dsp.window.resize(), "Resize Window with the Mouse", { mouse = true, fixed = true })

for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }), "Swap Window with Neighbour", { fixed = true })
end

for key, d in pairs({ left = { -40, 0 }, right = { 40, 0 }, up = { 0, -40 }, down = { 0, 40 } }) do
    bind(mod .. " + CTRL + " .. key, hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }), "Resize Window", { repeating = true, fixed = true })
end

section("System")
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("sh ~/.local/bin/yuki-restart"), "Restart YukiShell")
bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"), "Reload Hyprland Config")
