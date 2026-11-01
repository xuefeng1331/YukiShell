local home = os.getenv("HOME") or ""
local picked = {}
local f = io.open((os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/yukishell/monitor-modes.tsv", "r")
if f then
    for line in f:lines() do
        local out, mode = line:gsub("\r$", ""):match("^([^\t]+)\t(%d+x%d+@[%d.]+)$")
        if out then picked[out] = mode end
    end
    f:close()
end

local pinned = {
    { output = "HDMI-A-1", mode = "1920x1080@100", position = "0x0", scale = 1 },
}
local seen = {}
for _, m in ipairs(pinned) do
    seen[m.output] = true
    hl.monitor({ output = m.output, mode = picked[m.output] or m.mode, position = m.position, scale = m.scale })
end
for out, mode in pairs(picked) do
    if not seen[out] then hl.monitor({ output = out, mode = mode, position = "auto", scale = 1 }) end
end
