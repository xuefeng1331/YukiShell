import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "I18n.js" as I18n
import "Fonts.js" as Fonts
import "Tile.js" as Tile

Scope {
    id: root
    property var hub: null
    readonly property var dock: hub ? hub.dock : null
    readonly property var bar: hub ? hub.bar : null
    readonly property string fam: dock ? dock.fontFamily : "Open Runde"
    readonly property bool darkMode: dock ? dock.darkMode : true

    readonly property bool enabled: bar ? bar.windowBar : false
    readonly property bool showTitle: bar ? bar.windowBarTitle : true
    readonly property var tileNames: ({ left: "Left Half", right: "Right Half", top: "Top Half", bottom: "Bottom Half", fill: "Fill",
                                        topleft: "Top Left Quarter", topright: "Top Right Quarter", bottomleft: "Bottom Left Quarter",
                                        bottomright: "Bottom Right Quarter", center: "Center" })

    readonly property var clients: hub ? (hub.glassClients || []) : []
    readonly property var activeTl: ToplevelManager.activeToplevel
    readonly property string activeAddr: {
        if (!activeTl) return "";
        var ts = Hyprland.toplevels.values;
        for (var i = 0; i < ts.length; i++)
            if (ts[i].wayland === activeTl) return "0x" + String(ts[i].address).replace(/^0x/, "");
        return "";
    }
    readonly property var active: {
        for (var i = 0; i < clients.length; i++) {
            var c = clients[i];
            if (("0x" + String(c.address).replace(/^0x/, "")) !== activeAddr && String(c.address) !== activeAddr) continue;
            if (!c.mapped || c.hidden || c.fullscreen) return null;
            if (c.class === "org.quickshell" || c.class === "quickshell") return null;
            if (c.size && (c.size[0] < 220 || c.size[1] < 120)) return null;
            return c;
        }
        return null;
    }
    Binding { target: root.hub; property: "winBarWantsGeo"; value: root.enabled; when: root.hub !== null }
    function dispatch(d) { Hyprland.dispatch(d + "({ window = \"address:" + activeAddr + "\" })"); }
    function close() { Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + activeAddr + '" })'); }
    function minimize() { Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:' + activeAddr + '" })'); }
    function zoom() { Hyprland.dispatch('hl.dsp.window.fullscreen_state({ internal = 2, client = 0, window = "address:' + activeAddr + '" })'); }

    Variants {
        model: root.enabled ? Quickshell.screens : []
        PanelWindow {
            id: w
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "yukiwinbar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region { item: cluster; regions: [ Region { item: tileMenu.open ? tileMenu : null } ] }

            readonly property var c: root.active
            readonly property bool here: c && c.monitor !== undefined && modelData && Hyprland.monitorFor(modelData) && Hyprland.monitorFor(modelData).id === c.monitor
            readonly property real wx: c ? c.at[0] - modelData.x : 0
            readonly property real wy: c ? c.at[1] - modelData.y : 0

            Item {
                id: cluster
                visible: w.here && opacity > 0.01
                opacity: w.here ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                x: w.wx + 12
                y: w.wy + 10
                width: lights.width + (root.showTitle ? titleRow.width + 12 : 0)
                height: 20
                Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: 11
                    color: root.darkMode ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(1, 1, 1, 0.3)
                    opacity: hover.hovered ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
                HoverHandler { id: hover }

                Row {
                    id: lights
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Repeater {
                        model: [{ c: "#FF5F57", g: "×" }, { c: "#FEBC2E", g: "−" }, { c: "#28C840", g: "↗" }]
                        delegate: Rectangle {
                            id: light
                            required property var modelData
                            required property int index
                            width: 13; height: 13; radius: 6.5
                            color: modelData.c
                            border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.14)
                            scale: lMa.pressed ? 0.86 : 1
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                            TLGlyph {
                                anchors.fill: parent
                                kind: parent.modelData.g
                                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            }
                            MouseArea {
                                id: lMa
                                anchors.fill: parent; anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: light.index === 2
                                onContainsMouseChanged: tileMenu.want(containsMouse)
                                onClicked: {
                                    if (light.index === 0) root.close();
                                    else if (light.index === 1) root.minimize();
                                    else { tileMenu.close(); root.zoom(); }
                                    if (root.bar) root.bar.playSound("tink", 0.4);
                                }
                            }
                        }
                    }
                }
                Row {
                    id: titleRow
                    visible: root.showTitle
                    anchors.left: lights.right; anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14; height: 14
                        sourceSize: Qt.size(32, 32)
                        asynchronous: true; smooth: true
                        source: {
                            var cl = w.c;
                            if (!cl) return "";
                            var e = cl.class ? ((hub && hub.steamEntry(cl.class)) || DesktopEntries.heuristicLookup(cl.class)) : null;
                            return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
                        }
                    }
                    MorphText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var cl = w.c;
                            if (!cl) return "";
                            var e = cl.class ? ((hub && hub.steamEntry(cl.class)) || DesktopEntries.heuristicLookup(cl.class)) : null;
                            return e && e.name ? e.name : (cl.class || "");
                        }
                        duration: 260
                        color: root.darkMode ? "white" : "#1D1D1F"
                        font.family: Fonts.forWeight(Font.DemiBold, root.fam); font.pixelSize: 11; font.weight: Font.DemiBold
                    }
                }
            }

            // hover the green light: Move & Resize, like macOS
            Rectangle {
                id: tileMenu
                property bool open: false
                function want(on) { if (on) { closeT.stop(); if (!open) openT.restart(); } else { openT.stop(); closeT.restart(); } }
                function close() { openT.stop(); closeT.stop(); open = false; }
                Timer { id: openT; interval: 450; onTriggered: if (w.here) tileMenu.open = true }
                Timer { id: closeT; interval: 300; onTriggered: tileMenu.open = false }
                Connections { target: w; function onCChanged() { if (!w.c) tileMenu.close(); } }
                HoverHandler { onHoveredChanged: tileMenu.want(hovered) }

                visible: opacity > 0.01
                opacity: open ? 1 : 0
                scale: open ? 1 : 0.94
                transformOrigin: Item.TopLeft
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                x: cluster.x + 2 * 21 - 5
                y: cluster.y + cluster.height + 8
                width: col.width + 20; height: col.height + 18
                radius: 12
                color: root.darkMode ? Qt.rgba(0.16, 0.16, 0.17, 0.97) : Qt.rgba(0.97, 0.97, 0.97, 0.97)
                border.width: 1; border.color: root.darkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
                readonly property color ink: root.darkMode ? "white" : "#1D1D1F"
                property string hot: ""

                Column {
                    id: col
                    x: 10; y: 9
                    spacing: 6
                    Text {
                        text: tileMenu.hot ? I18n.tr(root.tileNames[tileMenu.hot]) : I18n.tr("Move & Resize")
                        color: tileMenu.ink; opacity: 0.6
                        font.family: Fonts.forWeight(Font.DemiBold, root.fam); font.pixelSize: 11; font.weight: Font.DemiBold
                    }
                    Grid {
                        columns: 5; spacing: 4
                        Repeater {
                            model: ["left", "right", "top", "bottom", "fill", "topleft", "topright", "bottomleft", "bottomright", "center"]
                            delegate: Rectangle {
                                id: tb
                                required property string modelData
                                readonly property var r: Tile.rect(modelData, { x: 3, y: 3, w: 24, h: 16 }, 2, { w: 14, h: 9 })
                                width: 34; height: 26; radius: 6
                                color: tbMa.containsMouse ? (root.darkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30; height: 22; radius: 4
                                    color: "transparent"
                                    border.width: 1.2; border.color: Qt.rgba(tileMenu.ink.r, tileMenu.ink.g, tileMenu.ink.b, 0.45)
                                    Rectangle {
                                        x: tb.r.x; y: tb.r.y; width: tb.r.w; height: tb.r.h; radius: 2
                                        color: tbMa.containsMouse && root.dock ? root.dock.accent : tileMenu.ink
                                        opacity: tbMa.containsMouse ? 1 : 0.7
                                    }
                                }
                                MouseArea {
                                    id: tbMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: tileMenu.hot = containsMouse ? tb.modelData : (tileMenu.hot === tb.modelData ? "" : tileMenu.hot)
                                    onClicked: { if (root.bar) root.bar.tile(tb.modelData, root.activeAddr); tileMenu.close(); }
                                }
                            }
                        }
                    }
                    Text {
                        visible: !!(root.bar && root.activeAddr && root.bar.tilePrev[root.activeAddr])
                        text: I18n.tr("Return to Previous Size")
                        color: backMa.containsMouse && root.dock ? root.dock.accent : tileMenu.ink
                        font.family: Fonts.forWeight(Font.Medium, root.fam); font.pixelSize: 12; font.weight: Font.Medium
                        MouseArea {
                            id: backMa
                            anchors.fill: parent; anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.bar) root.bar.tile("restore", root.activeAddr); tileMenu.close(); }
                        }
                    }
                }
            }
        }
    }
}
