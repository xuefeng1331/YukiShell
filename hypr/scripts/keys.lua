local M = {}

local home = os.getenv("HOME") or ""
local conf = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/yukishell/keybinds.tsv"
local cache = (os.getenv("XDG_CACHE_HOME") or (home .. "/.cache")) .. "/yukishell/keybinds.tsv"

local overrides, rows = {}, {}

local f = io.open(conf, "r")
if f then
    for line in f:lines() do
        local desc, keys = line:gsub("\r$", ""):match("^([^\t]+)\t(.*)$")
        if desc then overrides[desc] = keys end
    end
    f:close()
end

function M.bind(keys, dispatcher, description, opts)
    opts = opts or {}
    local fixed = opts.fixed
    opts.fixed = nil
    if description then
        rows[#rows + 1] = description .. "\t" .. keys .. "\t" .. (fixed and "0" or "1")
        opts.description = description
        if not fixed and overrides[description] ~= nil then keys = overrides[description] end
    end
    if keys ~= "" then hl.bind(keys, dispatcher, opts) end
end

function M.flush()
    pcall(os.execute, "mkdir -p '" .. cache:match("^(.*)/[^/]*$") .. "'")
    local out = io.open(cache, "w")
    if not out then return end
    out:write(table.concat(rows, "\n"), "\n")
    out:close()
end

hl.define_submap("yuki-capture", function()
    hl.bind("SUPER + F24", hl.dsp.no_op())
end)

return M
