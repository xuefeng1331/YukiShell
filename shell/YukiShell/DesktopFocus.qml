import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: df
    property bool enabled: true
    property bool cycling: false
    property bool focused: false
    property bool hovered: false
    property bool grab: false
    property string lastActive: ""

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openlayer" && event.data.indexOf("yuki") !== 0 && event.data !== "quickshell") cycleT.restart();
            // the window you last used closed or left the workspace (minimize, hide, send), or a Super+number/scroll workspace
            // switch (binds.lua sends "yukiws"): Hyprland hands the keyboard to some window even with the pointer on the desktop
            else if ((event.name === "closewindow" && event.data === df.lastActive)
                     || (event.name === "movewindowv2" && event.data.split(",")[0] === df.lastActive)
                     || (event.name === "custom" && event.data === "yukiws")) reclaimT.restart();
            else if (event.name === "activewindowv2") df.lastActive = event.data;
            // Hyprland gives a new window no keyboard while the desktop holds it: hand it over (nameless XWayland drag popups stay
            // unfocused, see rules.lua; a window opened on another workspace does not pull you there)
            else if (event.name === "openwindow" && df.focused) {
                var p = event.data.split(","), ws = Hyprland.focusedWorkspace;
                if (ws && p[1] === ws.name && (p[2] !== "" || p.slice(3).join(",") !== ""))
                    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:0x" + p[0] + "\" })"]);
            }
        }
    }
    Timer { id: cycleT; interval: 400; onTriggered: { df.cycling = true; df.cycling = false; } }
    Timer { id: reclaimT; interval: 90; onTriggered: if (df.enabled && df.hovered && !df.focused) { df.grab = true; grabT.restart(); } }
    Timer { id: grabT; interval: 120; onTriggered: df.grab = false }

    Variants {
        model: (df.enabled && !df.cycling) ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { left: true; right: true; top: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "yukidesktop"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: df.grab ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
            Item {
                anchors.fill: parent
                focus: true
                onActiveFocusChanged: df.focused = activeFocus
                HoverHandler { onHoveredChanged: df.hovered = hovered }
                Component.onDestruction: { df.focused = false; df.hovered = false; }
            }
        }
    }
}
