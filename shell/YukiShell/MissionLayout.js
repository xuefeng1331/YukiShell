.pragma library
// Mission Control: places windows (sizes [{w, h}], in reading order) in a W x H area, macOS style: an even grid whose row count
// gives the windows the biggest total size, short last row centred, never larger than maxScale. Returns [{x, y, w, h}].
function grid(sizes, W, H, gap, maxScale) {
    var n = sizes.length, best = null, i, r, c;
    if (n === 0 || W <= 0 || H <= 0) return [];
    for (var rows = 1; rows <= n; rows++) {
        var cols = Math.ceil(n / rows);
        var cw = (W - gap * (cols - 1)) / cols, ch = (H - gap * (rows - 1)) / rows;
        if (cw <= 0 || ch <= 0) continue;
        var tot = 0;
        for (i = 0; i < n; i++) tot += Math.min(maxScale, cw / sizes[i].w, ch / sizes[i].h);
        if (!best || tot > best.tot + 1e-6) best = { rows: Math.ceil(n / cols), cols: cols, cw: cw, ch: ch, tot: tot };
    }
    if (!best) return [];
    var out = [], gridH = best.rows * best.ch + (best.rows - 1) * gap;
    for (i = 0; i < n; i++) {
        r = Math.floor(i / best.cols); c = i % best.cols;
        var inRow = Math.min(best.cols, n - r * best.cols);
        var x0 = (W - (inRow * best.cw + (inRow - 1) * gap)) / 2 + c * (best.cw + gap);
        var y0 = (H - gridH) / 2 + r * (best.ch + gap);
        var s = Math.min(maxScale, best.cw / sizes[i].w, best.ch / sizes[i].h);
        out.push({ x: x0 + (best.cw - sizes[i].w * s) / 2, y: y0 + (best.ch - sizes[i].h * s) / 2, w: sizes[i].w * s, h: sizes[i].h * s });
    }
    return out;
}
