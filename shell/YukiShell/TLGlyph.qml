import QtQuick

Canvas {
    id: g
    property string kind: "×"
    antialiasing: true
    renderTarget: Canvas.Image
    onKindChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d");
        c.reset();
        var w = width, h = height;
        if (w <= 0 || h <= 0) return;
        c.lineCap = "round";
        c.lineWidth = Math.max(1.1, w * 0.095);
        if (kind === "×") {
            c.strokeStyle = Qt.rgba(0.30, 0.0, 0.0, 0.85);
            c.beginPath();
            c.moveTo(w * 0.32, h * 0.32); c.lineTo(w * 0.68, h * 0.68);
            c.moveTo(w * 0.68, h * 0.32); c.lineTo(w * 0.32, h * 0.68);
            c.stroke();
        } else if (kind === "−") {
            c.strokeStyle = Qt.rgba(0.60, 0.34, 0.0, 0.9);
            c.beginPath();
            c.moveTo(w * 0.27, h * 0.5); c.lineTo(w * 0.73, h * 0.5);
            c.stroke();
        } else {
            c.fillStyle = Qt.rgba(0.0, 0.40, 0.0, 0.9);
            c.beginPath();
            c.moveTo(w * 0.43, h * 0.28); c.lineTo(w * 0.72, h * 0.28); c.lineTo(w * 0.72, h * 0.57);
            c.closePath(); c.fill();
            c.beginPath();
            c.moveTo(w * 0.28, h * 0.43); c.lineTo(w * 0.28, h * 0.72); c.lineTo(w * 0.57, h * 0.72);
            c.closePath(); c.fill();
        }
    }
}
