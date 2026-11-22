// node tools/test-tile.js : checks Tile.area / Tile.rect (run by tools/check)
const fs = require("fs"), assert = require("assert");
const src = fs.readFileSync(__dirname + "/../shell/YukiShell/Tile.js", "utf8").replace(/^\.pragma.*$/m, "");
const T = new Function(src + "; return { area, rect, kinds };")();

// 1920x1080 with a 28 px bar, gaps 12, border 1: tiled windows sit at (13, 41), as Hyprland places them
const a = T.area({ x: 0, y: 0, width: 1920, height: 1080, scale: 1, transform: 0, reserved: [0, 28, 0, 0] }, 12, 1);
assert.deepStrictEqual(a, { x: 13, y: 41, w: 1894, h: 1026 });
// a scaled, rotated monitor to the right of it
assert.deepStrictEqual(T.area({ x: 1920, y: 0, width: 2160, height: 3840, scale: 2, transform: 1, reserved: [0, 0, 0, 0] }, 0, 0),
                       { x: 1920, y: 0, w: 1920, h: 1080 });

const gap = 26, inside = r => r.x >= a.x && r.y >= a.y && r.x + r.w <= a.x + a.w + 1 && r.y + r.h <= a.y + a.h + 1;
for (const k of T.kinds) assert.ok(inside(T.rect(k, a, gap, { w: 900, h: 560 })), k + " leaves the area");
const L = T.rect("left", a, gap), R = T.rect("right", a, gap);
assert.strictEqual(R.x - (L.x + L.w), gap);
assert.strictEqual(R.x + R.w, a.x + a.w);
const q = ["topleft", "topright", "bottomleft", "bottomright"].map(k => T.rect(k, a, gap));
assert.strictEqual(q[2].y - (q[0].y + q[0].h), gap);
assert.deepStrictEqual(T.rect("center", a, gap, { w: 900, h: 560 }), { x: 510, y: 274, w: 900, h: 560 });
assert.deepStrictEqual(T.rect("center", a, gap, { w: 5000, h: 5000 }), a);
assert.strictEqual(T.rect("nope", a, gap), null);
console.log("tile ok");
