// Small hand-drawn weather glyphs (no icon font / image files needed).
//   kind: sun | moon | partly | partlyNight | cloud | fog | rain | snow | storm
//   light: drawn on a light background (the Light widget style): the white clouds would vanish there, so they get deeper
//          blue-grey tones and a faint outline
import QtQuick

Canvas {
    id: ic
    property string kind: "sun"
    property real size: 18
    property bool light: false
    width: size
    height: size
    antialiasing: true

    onKindChanged: requestPaint()
    onSizeChanged: requestPaint()
    onWidthChanged: requestPaint()
    onLightChanged: requestPaint()
    // a canvas that was hidden or not ready when its kind was set has nothing drawn: paint it the moment it can be seen
    onAvailableChanged: if (available) requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    // a darker version of a cloud colour for light backgrounds
    function deep(c) {
        var q = Qt.color(c);
        return "rgb(" + Math.round(q.r * 255 * 0.58) + "," + Math.round(q.g * 255 * 0.63) + "," + Math.round(q.b * 255 * 0.72) + ")";
    }

    function cloud(ctx, cx, cy, w, c1, c2) {
        if (ic.light) { c1 = deep(c1); c2 = deep(c2); }
        var g = ctx.createLinearGradient(0, cy - 0.3 * w, 0, cy + 0.22 * w);
        g.addColorStop(0, c1);
        g.addColorStop(1, c2);
        // every part is its own fill (three puffs, then the pill-shaped base): in one path the canvas joins one circle to the next
        // with a straight line and fills overlaps even-odd, which cut a notch and holes into the cloud
        var puffList = [[-0.22, 0.02, 0.20], [-0.02, -0.10, 0.26], [0.26, 0.03, 0.18]];
        function puffs() {
            for (var i = 0; i < puffList.length; i++) {
                ctx.beginPath();
                ctx.arc(cx + puffList[i][0] * w, cy + puffList[i][1] * w, puffList[i][2] * w, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
        function base() {
            var l = cx - 0.42 * w, r = cx + 0.44 * w, t = cy - 0.02 * w, b = cy + 0.20 * w, rad = (b - t) / 2;
            ctx.beginPath();
            ctx.moveTo(l + rad, t);
            ctx.lineTo(r - rad, t);
            ctx.arc(r - rad, t + rad, rad, -Math.PI / 2, Math.PI / 2, false);
            ctx.lineTo(l + rad, b);
            ctx.arc(l + rad, t + rad, rad, Math.PI / 2, 3 * Math.PI / 2, false);
            ctx.closePath();
        }
        ctx.fillStyle = g;
        if (ic.light) {         // a faint soft edge first, so the cloud reads against a white card
            ctx.save();
            ctx.shadowColor = "rgba(0,0,0,0.22)";
            ctx.shadowBlur = Math.max(1.5, 0.06 * w);
            puffs();
            base(); ctx.fill();
            ctx.restore();
            ctx.fillStyle = g;
        }
        puffs();
        base(); ctx.fill();
    }

    function sun(ctx, cx, cy, s, withRays) {
        var r = 0.26 * s;
        if (withRays) {
            ctx.strokeStyle = "#FFD23F";
            ctx.lineWidth = Math.max(1, 0.075 * s);
            ctx.lineCap = "round";
            for (var i = 0; i < 8; i++) {
                var a = i * Math.PI / 4;
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(a) * (r + 0.09 * s), cy + Math.sin(a) * (r + 0.09 * s));
                ctx.lineTo(cx + Math.cos(a) * (r + 0.20 * s), cy + Math.sin(a) * (r + 0.20 * s));
                ctx.stroke();
            }
        }
        var g = ctx.createLinearGradient(cx, cy - r, cx, cy + r);
        g.addColorStop(0, "#FFE066");
        g.addColorStop(1, "#FFB800");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.fill();
    }

    function moon(ctx, cx, cy, s) {
        var r = 0.34 * s;
        var g = ctx.createLinearGradient(cx - r, cy - r, cx + r, cy + r);
        g.addColorStop(0, ic.light ? "#E3D9A6" : "#F4F1DE");
        g.addColorStop(1, ic.light ? "#B3A874" : "#C9C6B0");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.fill();
        // bite out of the disc -> crescent
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath();
        ctx.arc(cx + 0.55 * r, cy - 0.35 * r, 0.82 * r, 0, 2 * Math.PI);
        ctx.fill();
        ctx.globalCompositeOperation = "source-over";
    }

    onPaint: {
        var ctx = getContext("2d");
        var s = Math.min(width, height);
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        var c = s / 2;
        switch (ic.kind) {
        case "sun":
            sun(ctx, c, c, s, true);
            break;
        case "moon":
            moon(ctx, c, c, s);
            break;
        case "partly":
            sun(ctx, 0.38 * s, 0.36 * s, s * 0.9, true);
            cloud(ctx, 0.56 * s, 0.66 * s, 0.82 * s, "#FFFFFF", "#D5DCE8");
            break;
        case "partlyNight":
            moon(ctx, 0.36 * s, 0.34 * s, s * 0.9);
            cloud(ctx, 0.56 * s, 0.66 * s, 0.82 * s, "#F2F5FA", "#B9C3D3");
            break;
        case "cloud":
            cloud(ctx, c, 0.55 * s, 0.94 * s, "#FFFFFF", "#CBD3E0");
            break;
        case "fog":
            cloud(ctx, c, 0.40 * s, 0.84 * s, "#F2F5FA", "#C4CCDA");
            ctx.strokeStyle = ic.light ? "rgba(110,124,148,0.85)" : "rgba(255,255,255,0.85)";
            ctx.lineWidth = Math.max(1, 0.075 * s);
            ctx.lineCap = "round";
            for (var f = 0; f < 2; f++) {
                ctx.beginPath();
                ctx.moveTo(0.18 * s, (0.72 + f * 0.16) * s);
                ctx.lineTo(0.82 * s, (0.72 + f * 0.16) * s);
                ctx.stroke();
            }
            break;
        case "rain":
            cloud(ctx, c, 0.38 * s, 0.88 * s, "#E6EBF3", "#A9B4C6");
            ctx.strokeStyle = "#6EC1FF";
            ctx.lineWidth = Math.max(1, 0.08 * s);
            ctx.lineCap = "round";
            for (var d = 0; d < 3; d++) {
                ctx.beginPath();
                ctx.moveTo((0.30 + d * 0.20) * s, 0.68 * s);
                ctx.lineTo((0.25 + d * 0.20) * s, 0.90 * s);
                ctx.stroke();
            }
            break;
        case "snow":
            cloud(ctx, c, 0.38 * s, 0.88 * s, "#E6EBF3", "#A9B4C6");
            ctx.fillStyle = ic.light ? "#7E8DA6" : "#FFFFFF";
            for (var n = 0; n < 3; n++) {
                ctx.beginPath();
                ctx.arc((0.30 + n * 0.20) * s, (0.76 + (n % 2) * 0.10) * s, 0.055 * s, 0, 2 * Math.PI);
                ctx.fill();
            }
            break;
        case "storm":
            cloud(ctx, c, 0.36 * s, 0.88 * s, "#C9D0DC", "#8A94A6");
            ctx.fillStyle = "#FFD23F";
            ctx.beginPath();
            ctx.moveTo(0.54 * s, 0.56 * s);
            ctx.lineTo(0.38 * s, 0.80 * s);
            ctx.lineTo(0.50 * s, 0.80 * s);
            ctx.lineTo(0.44 * s, 0.98 * s);
            ctx.lineTo(0.66 * s, 0.70 * s);
            ctx.lineTo(0.54 * s, 0.70 * s);
            ctx.closePath();
            ctx.fill();
            break;
        }
    }
}
