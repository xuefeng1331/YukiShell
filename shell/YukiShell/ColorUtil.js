.pragma library

function hex2(n) {
    n = Math.max(0, Math.min(255, Math.round(n)));
    return (n < 16 ? "0" : "") + n.toString(16);
}

function fromRgb(r, g, b) { return "#" + hex2(r) + hex2(g) + hex2(b); }

function parse(text) {
    var s = String(text === undefined || text === null ? "" : text).trim().toLowerCase();
    if (s === "") return "";
    var m = /^#?([0-9a-f]{3})$/.exec(s);
    if (m) return "#" + m[1][0] + m[1][0] + m[1][1] + m[1][1] + m[1][2] + m[1][2];
    m = /^#?([0-9a-f]{6})([0-9a-f]{2})?$/.exec(s);
    if (m) return "#" + m[1];
    m = /^(?:rgba?)?\s*\(?\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})(?:\s*[,\/ ]\s*[\d.]+%?)?\s*\)?$/.exec(s);
    if (m) {
        var r = parseInt(m[1]), g = parseInt(m[2]), b = parseInt(m[3]);
        if (r > 255 || g > 255 || b > 255) return "";
        return fromRgb(r, g, b);
    }
    return "";
}

function rgbText(hex) {
    var h = parse(hex);
    if (h === "") return "";
    return parseInt(h.substr(1, 2), 16) + ", " + parseInt(h.substr(3, 2), 16) + ", " + parseInt(h.substr(5, 2), 16);
}

function fromHsl(h, s, l) {
    var c = (1 - Math.abs(2 * l - 1)) * s, hp = (((h % 360) + 360) % 360) / 60;
    var x = c * (1 - Math.abs(hp % 2 - 1)), r = 0, g = 0, b = 0;
    if (hp < 1) { r = c; g = x; } else if (hp < 2) { r = x; g = c; } else if (hp < 3) { g = c; b = x; }
    else if (hp < 4) { g = x; b = c; } else if (hp < 5) { r = x; b = c; } else { r = c; b = x; }
    var m = l - c / 2;
    return fromRgb((r + m) * 255, (g + m) * 255, (b + m) * 255);
}

function palette() {
    var shades = [[0.80, 0.82], [0.85, 0.68], [0.85, 0.52], [0.78, 0.38], [0.70, 0.26]], out = [];
    for (var r = 0; r < shades.length; r++)
        for (var c = 0; c < 12; c++) out.push(fromHsl(c * 30, shades[r][0], shades[r][1]));
    for (var g = 0; g < 12; g++) out.push(fromHsl(0, 0, g / 11));
    return out;
}
