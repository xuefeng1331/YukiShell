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

-- Shake the pointer to find it, as on macOS. Settings → Cursor switches it (SHAKE_TO_FIND). The shell (CursorFinder.qml) hides
-- the real cursor and draws a big one: resizing the real one reloads the whole cursor theme, which froze everything each time.
local Shake = require("scripts.shake")
local shake = { x = Shake.new(), y = Shake.new(), t = 0, big = false, unhide = 0 }
local function tell(what) hl.exec_cmd("qs -c YukiShell ipc call cursor " .. what) end
local function shakeTick()
    local c = hl.get_cursor_pos()
    if not c then return end
    shake.t = shake.t + 30
    local now = shake.t
    local hit = Shake.feed(shake.x, c.x, now)
    hit = Shake.feed(shake.y, c.y, now) or hit
    if hit and not shake.big then
        local w = hl.get_active_window()
        if w and (w.fullscreen or 0) > 0 then hit = false end   -- a game or a video: the shaking is meant for it
    end
    if hit and not shake.big then
        shake.big, shake.unhide = true, 0
        tell(string.format("grow %d %d", math.floor(c.x), math.floor(c.y)))
    elseif shake.big and now - math.max(shake.x.at[#shake.x.at] or 0, shake.y.at[#shake.y.at] or 0) > 350 then
        -- no turn for a moment: the shaking stopped. Forget the old turns, or it would grow again straight away
        shake.big, shake.unhide = false, now + 700
        shake.x.at, shake.y.at = {}, {}
        tell("shrink")
    end
    -- the shell shows the real cursor again once its big one has shrunk; this is for when the shell is gone
    if shake.unhide > 0 and now >= shake.unhide then shake.unhide = 0; hl.config({ cursor = { invisible = false } }) end
end
function SHAKE_TO_FIND(on)
    if on and not shake.timer then shake.timer = hl.timer(shakeTick, { timeout = 30, type = "repeat" }) return end
    if shake.timer then shake.timer:set_enabled(on) end
    if not on and shake.big then shake.big = false; tell("shrink"); hl.config({ cursor = { invisible = false } }) end
end
