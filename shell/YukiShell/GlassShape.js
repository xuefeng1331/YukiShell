.pragma library

function cmds(ox, oy, W, H, r, tx, tw, th, tr) {
    var c = Math.max(0.5, Math.min(r * 1.12, W / 2, H / 2));
    var ck = c * 0.66;
    var o = [];
    o.push(["M", ox + c, oy]);
    o.push(["L", ox + W - c, oy]);
    o.push(["C", ox + W - c + ck, oy, ox + W, oy + c - ck, ox + W, oy + c]);
    o.push(["L", ox + W, oy + H - c]);
    o.push(["C", ox + W, oy + H - c + ck, ox + W - c + ck, oy + H, ox + W - c, oy + H]);

    if (th > 0 && tw > 0) {
        var hb = tw / 2;
        var hw0 = hb * 0.68;
        var f = hb - hw0;
        var g = Math.max(tr, 0.5) * 1.5;
        var thA = th, L = 1, ux = 0, uy = 1;
        for (var it = 0; it < 4; it++) {
            L = Math.sqrt(hw0 * hw0 + thA * thA);
            uy = thA / L;
            thA = th + 0.5 * g * uy;
        }
        L = Math.sqrt(hw0 * hw0 + thA * thA);
        ux = hw0 / L;
        uy = thA / L;
        var cx = ox + Math.max(c + hb, Math.min(W - c - hb, tx));
        var by = oy + H;
        o.push(["L", cx + hb, by]);
        o.push(["Q", cx + hw0, by, cx + hw0 - ux * f, by + uy * f]);
        o.push(["L", cx + ux * g, by + thA - uy * g]);
        o.push(["Q", cx, by + thA, cx - ux * g, by + thA - uy * g]);
        o.push(["L", cx - hw0 + ux * f, by + uy * f]);
        o.push(["Q", cx - hw0, by, cx - hb, by]);
    }

    o.push(["L", ox + c, oy + H]);
    o.push(["C", ox + c - ck, oy + H, ox, oy + H - c + ck, ox, oy + H - c]);
    o.push(["L", ox, oy + c]);
    o.push(["C", ox, oy + c - ck, ox + c - ck, oy, ox + c, oy]);
    o.push(["Z"]);
    return o;
}

function build(ctx, ox, oy, W, H, r, tx, tw, th, tr) {
    var a = cmds(ox, oy, W, H, r, tx, tw, th, tr);
    ctx.beginPath();
    for (var i = 0; i < a.length; i++) {
        var s = a[i];
        if (s[0] === "M") ctx.moveTo(s[1], s[2]);
        else if (s[0] === "L") ctx.lineTo(s[1], s[2]);
        else if (s[0] === "C") ctx.bezierCurveTo(s[1], s[2], s[3], s[4], s[5], s[6]);
        else if (s[0] === "Q") ctx.quadraticCurveTo(s[1], s[2], s[3], s[4]);
        else ctx.closePath();
    }
}

function svg(ox, oy, W, H, r, tx, tw, th, tr) {
    var a = cmds(ox, oy, W, H, r, tx, tw, th, tr), out = "";
    for (var i = 0; i < a.length; i++) {
        var s = a[i];
        out += s[0];
        for (var j = 1; j < s.length; j++) out += (j > 1 ? " " : "") + s[j].toFixed(2);
        out += " ";
    }
    return out;
}
