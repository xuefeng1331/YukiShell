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

-- no rule means Hyprland uses each monitor's preferred mode; Settings -> Displays saves a chosen one here
for out, mode in pairs(picked) do
    hl.monitor({ output = out, mode = mode, position = "auto", scale = 1 })
end
