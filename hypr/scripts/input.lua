hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        focus_on_close = 1,
        sensitivity  = 0,
        repeat_rate  = 40,
        repeat_delay = 250,
        touchpad = { natural_scroll = true, tap_to_click = true },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Shake the pointer to find it: it grows for a moment, as on macOS. Settings → Cursor switches it (SHAKE_TO_FIND).
local Shake = require("scripts.shake")
local shake = { x = Shake.new(), y = Shake.new(), t = 0, quiet = -1000, size = 0, base = 24, theme = "" }
local function cursorLook()   -- what Settings last applied (assets/cursors.py writes it), as look.lua reads it
    local theme, size = "Bibata-Modern-Classic", 24
    local f = io.open((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/yukishell/cursor", "r")
    if f then
        local t, s = f:read("l"), f:read("l")
        f:close()
        if t and t ~= "" then theme = t end
        size = tonumber(s) or size
    end
    return theme, size
end
local function setSize(n) hl.exec_cmd(string.format("hyprctl setcursor '%s' %d", shake.theme, n)) end
local function shakeTick()
    local c = hl.get_cursor_pos()
    if not c then return end
    shake.t = shake.t + 30
    local now = shake.t
    local hit = Shake.feed(shake.x, c.x, now)
    hit = Shake.feed(shake.y, c.y, now) or hit
    if hit then
        shake.quiet = now
        if shake.size == 0 then shake.theme, shake.base = cursorLook(); shake.size = shake.base end
    end
    if shake.size == 0 then return end
    -- grow to three times the size in a few steps, and shrink back the same way once the shaking stops
    local target = now - shake.quiet < 250 and shake.base * 3 or shake.base
    local n = target > shake.size and math.min(target, math.floor(shake.size * 1.5)) or math.max(target, math.floor(shake.size / 1.5))
    if n ~= shake.size then shake.size = n; setSize(n) end
    if n == shake.base and target == shake.base then shake.size = 0 end
end
function SHAKE_TO_FIND(on)
    if on and not shake.timer then shake.timer = hl.timer(shakeTick, { timeout = 30, type = "repeat" }) return end
    if shake.timer then shake.timer:set_enabled(on) end
    if not on and shake.size > 0 then shake.size = 0; setSize(shake.base) end
end
SHAKE_TO_FIND(true)
