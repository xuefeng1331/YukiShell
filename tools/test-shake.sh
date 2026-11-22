#!/bin/sh
# tools/test-shake.sh : checks hypr/scripts/shake.lua (skipped without lua)
command -v lua >/dev/null || { echo "shake skipped"; exit 0; }
cd "$(dirname "$0")/../hypr" && lua - <<'LUA' || exit 1
package.path = "./?.lua;" .. package.path
local S = require("scripts.shake")
local function run(xs, dt)
    local s, hit = S.new(), false
    for i, x in ipairs(xs) do hit = S.feed(s, x, i * dt) or hit end
    return hit
end
-- a shake: 120 px swings back and forth, a turn every ~100 ms (30 ms ticks)
local shake = {}
for i = 0, 40 do local p = i % 8; shake[#shake + 1] = 500 + (p < 4 and p or 8 - p) * 40 end
assert(run(shake, 30), "a shake was missed")
-- a long straight move, and a slow back-and-forth (one turn a second), are not shakes
local line, slow = {}, {}
for i = 0, 60 do line[#line + 1] = 100 + i * 25 end
for i = 0, 200 do local p = i % 66; slow[#slow + 1] = 500 + (p < 33 and p or 66 - p) * 6 end
assert(not run(line, 30), "a straight move counted as a shake")
assert(not run(slow, 30), "a slow back-and-forth counted as a shake")
-- small jitter is not a shake
local jit = {}
for i = 0, 60 do jit[#jit + 1] = 500 + (i % 2) * 6 end
assert(not run(jit, 30), "jitter counted as a shake")
print("shake ok")
LUA
