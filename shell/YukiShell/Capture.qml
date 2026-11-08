import QtQuick
import Quickshell.Wayland

// A ScreencopyView that recovers: a failed capture (the window resized or went full screen) ends recording for good otherwise
ScreencopyView {
    id: v
    property var source: null
    property bool kicked: false
    captureSource: kicked ? null : source
    onHasContentChanged: if (!hasContent && source !== null && !kicked) { kicked = true; rearm.restart(); }
    Timer { id: rearm; interval: 250; onTriggered: v.kicked = false }
}
