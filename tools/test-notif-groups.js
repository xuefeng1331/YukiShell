// node tools/test-notif-groups.js : checks NotifGroups.gather / runs (run by tools/check)
const fs = require("fs"), assert = require("assert");
const src = fs.readFileSync(__dirname + "/../shell/YukiShell/NotifGroups.js", "utf8").replace(/^\.pragma.*$/m, "");
const G = new Function(src + "; return { gather, runs };")();

// a ListModel stand-in
function model(apps) {
    const a = apps.map((app, i) => ({ nid: i + 1, app }));
    return { a, get count() { return a.length; }, get: i => a[i], move: (f, t, n) => a.splice(t, 0, ...a.splice(f, n)) };
}
const m = model(["chat", "mail", "chat", "web", "chat"]);
m.a.unshift({ nid: 9, app: "chat" });
G.gather(m);
assert.deepStrictEqual(m.a.map(r => r.nid), [9, 1, 3, 5, 2, 4]);   // chat's run keeps newest-first order
const g = G.runs(m);
assert.deepStrictEqual(g[9], { head: true, n: 4 });
assert.deepStrictEqual(g[5], { head: false, n: 4 });
assert.deepStrictEqual(g[2], { head: true, n: 1 });
const one = model(["solo"]); G.gather(one);
assert.deepStrictEqual(G.runs(one), { 1: { head: true, n: 1 } });
console.log("notif groups ok");
