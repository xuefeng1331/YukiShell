import QtQuick

Canvas {
    id: ts
    property url source: ""
    property bool known: false
    property real h: 0
    property real s: 0

    width: 16; height: 16
    visible: false
    renderTarget: Canvas.Image
    property url loaded: ""
    property int tries: 0
    function startLoad() {
        if (loaded != "") { try { unloadImage(loaded); } catch (e) {} loaded = ""; }
        if (source == "") { known = false; retry.stop(); return; }
        loaded = source;
        if (isImageLoaded(source)) requestPaint(); else { loadImage(source); retry.restart(); }
    }
    onSourceChanged: { known = false; tries = 0; retry.stop(); startLoad(); }
    Component.onCompleted: startLoad()
    onImageLoaded: { retry.stop(); requestPaint(); }
    Timer {
        id: retry
        interval: 600
        onTriggered: { if (ts.loaded !== "" && !ts.isImageLoaded(ts.loaded) && ++ts.tries <= 8) ts.startLoad(); }
    }
    onPaint: {
        if (source === "" || loaded !== source || !isImageLoaded(source)) return;
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, 16, 16);
        ctx.drawImage(source, 0, 0, 16, 16);
        var d = ctx.getImageData(0, 0, 16, 16).data;
        var sr = 0, sg = 0, sb = 0, sw = 0;
        for (var i = 0; i < d.length; i += 4) {
            var r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255;
            var mx = Math.max(r, g, b), mn = Math.min(r, g, b);
            var wt = 0.05 + (mx - mn) * (mx - mn) * 4;
            sr += r * wt; sg += g * wt; sb += b * wt; sw += wt;
        }
        if (sw <= 0) { known = false; return; }
        var c = Qt.rgba(sr / sw, sg / sw, sb / sw, 1);
        h = c.hslHue < 0 ? 0 : c.hslHue;
        s = c.hslSaturation;
        known = true;
    }
}
