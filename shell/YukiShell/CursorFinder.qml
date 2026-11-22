// Shake to find: hypr/scripts/input.lua says when the pointer is being shaken. An overlay takes the pointer, blanks the real
// cursor (instantly, unlike Hyprland's cursor:invisible, which lags ~450 ms) and draws the theme's arrow growing to three times
// the size, then shrinks it back and goes. It takes over at exactly the real cursor's size and spot: no jump, no blink.
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
    property bool big: false             // input.lua: the pointer is being shaken
    property bool mapped: false          // the overlay is up
    property bool live: false            // the pointer has been seen on it: the big cursor is drawn

    Spring {   // 0 = the real cursor's size, 1 = three times; a little bounce growing, none shrinking
        id: zoom
        target: root.big && root.live ? 1 : 0
        response: 0.32
        damping: root.big ? 0.72 : 1.0
        epsilon: 0.015   // within a pixel or so of the real size: hand over
    }
    readonly property bool shrunk: !zoom.running && zoom.value === 0
    onShrunkChanged: if (shrunk && mapped && !big) handBack()
    function handBack() { mapped = false; live = false; }   // the app under the pointer shows its own cursor again
    function seen() { if (big) live = true; }

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
        function grow(): void {
            if (!root.art.png) return;   // a theme without an Xcursor arrow: leave the real cursor alone
            root.big = true;   // shaken again while shrinking: it grows back from where it is
            root.mapped = true;
        }
        function shrink(): void {
            root.big = false;
            if (root.shrunk && root.mapped) root.handBack();   // never drawn, or already small
        }
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

            MouseArea {   // the overlay has the pointer while it's up, to follow it; a click means "found it"
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                cursorShape: Qt.BlankCursor
                onEntered: root.seen()
                onPositionChanged: root.seen()
                onPressed: root.big = false
            }
            Image {
                readonly property real s: root.base / Math.max(1, root.art.size || 1) * (1 + 2 * zoom.value)
                visible: root.live && ma.containsMouse
                source: root.art.png ? "file://" + root.art.png : ""
                cache: false
                smooth: true
                mipmap: true
                x: ma.mouseX - (root.art.x || 0) * s
                y: ma.mouseY - (root.art.y || 0) * s
                width: implicitWidth * s
                height: implicitHeight * s
            }
        }
    }
}
