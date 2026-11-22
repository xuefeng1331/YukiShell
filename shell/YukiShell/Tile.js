.pragma library
// Move & Resize (the green button's menu, the Window menu, Super+Ctrl+arrows): where a window goes for each layout.

var kinds = ["fill", "center", "left", "right", "top", "bottom", "topleft", "topright", "bottomleft", "bottomright"];

// the part of a monitor (a hyprctl monitor: x, y, width, height, scale, transform, reserved [left, top, right, bottom]) a tiled
// window may use, in layout coordinates: inside the bar and the outer gaps, minus the border around the window
function area(mon, gaps, border) {
    var s = mon.scale || 1, turned = (mon.transform || 0) % 2 === 1, r = mon.reserved || [0, 0, 0, 0];
    var W = (turned ? mon.height : mon.width) / s, H = (turned ? mon.width : mon.height) / s, in_ = gaps + border;
    return { x: mon.x + r[0] + in_, y: mon.y + r[1] + in_, w: W - r[0] - r[2] - 2 * in_, h: H - r[1] - r[3] - 2 * in_ };
}

// the window rectangle for `kind` in area `a`; `gap` is the space between two tiles, `cur` the window's size now ({w, h}, for center)
function rect(kind, a, gap, cur) {
    var hw = (a.w - gap) / 2, hh = (a.h - gap) / 2, r = null;
    if (kind === "fill") r = { x: a.x, y: a.y, w: a.w, h: a.h };
    else if (kind === "center") {
        var w = Math.min(cur.w, a.w), h = Math.min(cur.h, a.h);
        r = { x: a.x + (a.w - w) / 2, y: a.y + (a.h - h) / 2, w: w, h: h };
    }
    else if (kind === "left") r = { x: a.x, y: a.y, w: hw, h: a.h };
    else if (kind === "right") r = { x: a.x + hw + gap, y: a.y, w: hw, h: a.h };
    else if (kind === "top") r = { x: a.x, y: a.y, w: a.w, h: hh };
    else if (kind === "bottom") r = { x: a.x, y: a.y + hh + gap, w: a.w, h: hh };
    else if (kind === "topleft") r = { x: a.x, y: a.y, w: hw, h: hh };
    else if (kind === "topright") r = { x: a.x + hw + gap, y: a.y, w: hw, h: hh };
    else if (kind === "bottomleft") r = { x: a.x, y: a.y + hh + gap, w: hw, h: hh };
    else if (kind === "bottomright") r = { x: a.x + hw + gap, y: a.y + hh + gap, w: hw, h: hh };
    return r ? { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.w), h: Math.round(r.h) } : null;
}
