-- Shake detection for "shake the pointer to find it" (input.lua): feed it one pointer coordinate at a time.
local M = {}

-- turns: direction changes needed, within `window` ms, each after a swing of at least `swing` px
function M.new(turns, window, swing)
    return { last = nil, dir = 0, run = 0, at = {}, turns = turns or 4, window = window or 900, swing = swing or 60 }
end

-- true while the pointer is being shaken along this axis
function M.feed(s, v, now)
    if s.last then
        local d = v - s.last
        if math.abs(d) >= 2 then   -- ignore a hand resting on the mouse
            local dir = d > 0 and 1 or -1
            if dir ~= s.dir then
                if s.dir ~= 0 and s.run >= s.swing then s.at[#s.at + 1] = now end
                s.dir, s.run = dir, 0
            end
            s.run = s.run + math.abs(d)
        end
    end
    s.last = v
    while s.at[1] and now - s.at[1] > s.window do table.remove(s.at, 1) end
    return #s.at >= s.turns
end

return M
