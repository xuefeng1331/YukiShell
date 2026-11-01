-- YukiShell owns (see shell.lua): SUPER+Z/V/G/L/Space/period/comma, ALT+TAB, CTRL+ALT+W, PRINT (+SHIFT/CTRL) and the hardware keys. Don't rebind those here.
local mod = "SUPER"

-- Every bind with a description is listed, translated, in System Settings -> Keyboard -> Keyboard Shortcuts, where most of them can be changed
-- (scripts/keys.lua has the details). A bind that belongs to a group of keys passes { fixed = true } and stays as it is.
local bind = require("scripts.keys").bind

bind(mod .. " + Return",         hl.dsp.exec_cmd("kitty"), "Open Terminal")
bind(mod .. " + E",              hl.dsp.exec_cmd("dolphin", { tile = true }), "Open Files")   -- tiled: fills an empty workspace, shares the space with other windows (new windows float otherwise) un-maximizes
bind(mod .. " + W",              hl.dsp.exec_cmd("chromium"), "Open Browser")
bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty", { float = true, center = true, size = "900 560" }), "Open a Floating Terminal")   -- floating terminal
bind(mod .. " + SHIFT + E",      hl.dsp.exec_cmd("dolphin", { float = true, center = true, size = "1100 700" }), "Open a Floating Files Explorer")   -- floating file manager
bind(mod .. " + SHIFT + W",      hl.dsp.exec_cmd("~/.config/hypr/bin/float-chromium"), "Open a Floating Browser")                             -- floating browser window (script: a running Chromium ignores exec rules)
bind(mod .. " + Q",              hl.dsp.window.close(), "Close Window")
bind(mod .. " + SHIFT + Q",      hl.dsp.window.kill(),  "Force Quit Window")   -- kills the app (SIGKILL), for one that stopped responding
bind(mod .. " + F",              hl.dsp.window.fullscreen(), "Full Screen")
bind(mod .. " + ALT + space",    hl.dsp.window.float({ action = "toggle" }), "Toggle Floating")     -- the only key for it (Super+T was a leftover of the first rice commit)
bind(mod .. " + ALT + D",      hl.dsp.exec_cmd("~/.config/hypr/bin/dashboard"), "Dashboard")
bind(mod .. " + SHIFT + Tab",   hl.dsp.exec_cmd("~/.config/hypr/bin/toggle-opacity"), "Terminal Transparency")
hl.bind(mod .. " + P",              hl.dsp.window.pseudo())
bind(mod .. " + J",              hl.dsp.layout("togglesplit"), "Toggle Split Direction")

bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }), "Move Focus", { fixed = true })
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + H",     hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + K",     hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + N",     hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }),       i == 1 and "Go to Workspace 1–10 (0 = 10)" or nil, { fixed = true })
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), i == 1 and "Move Window to Workspace 1–10" or nil, { fixed = true })
    bind(mod .. " + ALT + " .. key,   hl.dsp.window.move({ workspace = i, follow = false }), i == 1 and "Send Window to Workspace 1–10" or nil, { fixed = true })
end

-- the Window menu's actions (the menu bar shows these keys next to them)
bind(mod .. " + M",              hl.dsp.window.move({ workspace = "special:minimized", follow = false }), "Minimize Window")
bind(mod .. " + SHIFT + M",      hl.dsp.workspace.toggle_special("minimized"), "Show Minimized Windows")
-- one key: hides the focused window; with none focused (or the pointer on the desktop) brings them all back as they were (bin/hide-window)
bind(mod .. " + ALT + S",        hl.dsp.exec_cmd("~/.config/hypr/bin/hide-window"), "Hide or Show Window")
bind(mod .. " + SHIFT + F",      hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "Maximize Window")
bind(mod .. " + SHIFT + P",      hl.dsp.window.pin({ action = "toggle" }), "Pin Window to All Workspaces")
bind(mod .. " + C",              hl.dsp.window.center(), "Center Window")
bind(mod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "+1" }), "Move Window to Next Workspace")
bind(mod .. " + SHIFT + Page_Up",   hl.dsp.window.move({ workspace = "-1" }), "Move Window to Previous Workspace")
bind(mod .. " + SHIFT + O",      hl.dsp.window.move({ monitor = "+1" }), "Move Window to Next Monitor")

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- move a tiled window through the layout (swaps it with its neighbour)
for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
    bind(mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = dir }), key == "left" and "Swap Window with Neighbour" or nil, { fixed = true })
end

-- housekeeping: restart the shell cleanly (yuki-restart), reload this Hyprland config
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("sh ~/.local/bin/yuki-restart"), "Restart YukiShell")
bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"), "Reload Hyprland Config")

-- resize the focused window from the keyboard (hold to keep going); tiled windows move the split, floating ones grow/shrink
for key, d in pairs({ left = { -40, 0 }, right = { 40, 0 }, up = { 0, -40 }, down = { 0, 40 } }) do
    bind(mod .. " + CTRL + " .. key, hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }), key == "left" and "Resize Window" or nil, { repeating = true, fixed = true })
end
