// node tools/test-mission-layout.js : checks MissionLayout.grid (run by tools/check)
const fs = require("fs"), assert = require("assert");
const src = fs.readFileSync(__dirname + "/../shell/YukiShell/MissionLayout.js", "utf8").replace(/^\.pragma.*$/m, "");
const grid = new Function(src + "; return grid;")();

const overlap = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
for (const n of [1, 2, 3, 5, 8, 13]) {
    const sizes = Array.from({ length: n }, (_, i) => ({ w: 800 + 97 * i, h: 500 + 61 * (i % 3) }));
    const out = grid(sizes, 1800, 860, 40, 0.85);
    assert.strictEqual(out.length, n);
    out.forEach((r, i) => {
        assert.ok(r.x >= -0.01 && r.y >= -0.01 && r.x + r.w <= 1800.01 && r.y + r.h <= 860.01, `n=${n} #${i} outside`);
        assert.ok(Math.abs(r.w / r.h - sizes[i].w / sizes[i].h) < 1e-6, `n=${n} #${i} aspect changed`);
        assert.ok(r.w <= sizes[i].w * 0.85 + 1e-6, `n=${n} #${i} too big`);
        out.forEach((o, j) => { if (j > i) assert.ok(!overlap(r, o), `n=${n} #${i} overlaps #${j}`); });
    });
}
assert.deepStrictEqual(grid([], 100, 100, 10, 1), []);
console.log("mission layout ok");
