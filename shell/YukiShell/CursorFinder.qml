// Shake to find: hypr/scripts/input.lua says when the pointer is being shaken. This hides Hyprland's cursor and draws the
// theme's arrow three times as big, following the pointer, then shrinks it back and shows the real one again.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property var hub: null
    readonly property var bar: hub ? hub.bar : null
    readonly property string theme: bar ? bar.cursorTheme : ""
    readonly property int base: bar ? bar.cursorSize : 24
    readonly property string script: decodeURIComponent(String(Qt.resolvedUrl("assets/cursors.py")).replace(/^file:\/\//, ""))
    property var art: ({})               // the theme's arrow: {png, size (nominal), x, y (hotspot)}
    property bool big: false
    property bool mapped: false
    property point at: Qt.point(0, 0)    // where the shake started, in global coordinates
    property real k: big ? 1 : 0         // 0 = normal size, 1 = three times
    Behavior on k { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    onKChanged: if (k === 0 && mapped && !big) { hideReal(false); unmapT.restart(); }

    function hideReal(on) { Quickshell.execDetached(["hyprctl", "eval", "hl.config({ cursor = { invisible = " + on + " } })"]); }
    Timer { id: unmapT; interval: 40; onTriggered: if (!root.big) root.mapped = false }   // the real cursor is back first: no blink

    function loadArt() { if (theme !== "") { artProc.running = false; artProc.running = true; } }
    onThemeChanged: loadArt()
    Component.onCompleted: loadArt()
    Process {
        id: artProc
        command: ["python3", root.script, "arrow", root.theme]
        stdout: StdioCollector { onStreamFinished: { try { root.art = JSON.parse(text); } catch (e) { root.art = {}; } } }
    }

    IpcHandler {
        target: "cursor"
        function grow(x: int, y: int): void {
            if (!root.art.png) return;   // a theme without an Xcursor arrow: leave the real cursor alone
            unmapT.stop();
            root.at = Qt.point(x, y);
            root.mapped = true;
            root.big = true;
            root.hideReal(true);
        }
        function shrink(): void { root.big = false; }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: w
            required property var modelData
            screen: modelData
            visible: root.mapped
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "yukicursor"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            property point p: Qt.point(0, 0)
            property bool here: false
            onVisibleChanged: if (visible) {
                p = Qt.point(root.at.x - modelData.x, root.at.y - modelData.y);
                here = p.x >= 0 && p.y >= 0 && p.x < modelData.width && p.y < modelData.height;
            }
            MouseArea {   // the overlay has the pointer while it's up, to follow it; a click means "found it"
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                onPositionChanged: m => { w.p = Qt.point(m.x, m.y); w.here = true; }
                onExited: w.here = false
                onPressed: root.big = false
            }
            Image {
                readonly property real s: root.base / Math.max(1, root.art.size || 1) * (1 + 2 * root.k)
                visible: w.here
                source: root.art.png ? "file://" + root.art.png : ""
                cache: false
                smooth: true
                mipmap: true
                x: w.p.x - (root.art.x || 0) * s
                y: w.p.y - (root.art.y || 0) * s
                width: implicitWidth * s
                height: implicitHeight * s
            }
        }
    }
}
