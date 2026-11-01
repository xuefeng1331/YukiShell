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
            else if (event.name === "closewindow" && event.data === df.lastActive) closeT.restart();
            else if (event.name === "activewindowv2") df.lastActive = event.data;
        }
    }
    Timer { id: cycleT; interval: 400; onTriggered: { df.cycling = true; df.cycling = false; } }
    Timer { id: closeT; interval: 90; onTriggered: if (df.enabled && df.hovered && !df.focused) { df.grab = true; grabT.restart(); } }
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
