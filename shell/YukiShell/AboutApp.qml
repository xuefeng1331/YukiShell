import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "Version.js" as Version
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "I18n.js" as I18n
import "Fonts.js" as Fonts

Scope {
    id: root
    property var hub: null
    property var dock: hub ? hub.dock : null
    property var bar: hub ? hub.bar : null
    readonly property bool darkMode: true

    readonly property string fam: dock ? dock.fontFamily : "Open Runde"
    readonly property string boldFontFamily: hub && hub.boldFontFamily ? hub.boldFontFamily : "Open Runde Semibold"
    function fontForWeight(weight, regularFamily) { return (Number(weight) >= Font.DemiBold && regularFamily === "Open Runde") ? boldFontFamily : regularFamily; }

    property var info: ({})
    readonly property string scriptPath: decodeURIComponent(String(Qt.resolvedUrl("assets/about-info.sh")).replace(/^file:\/\//, ""))

    function syncTheme() { }

    function open() { syncTheme(); win.visible = true; win.raise(); win.requestActivate(); }
    function close() { win.visible = false; }
    function toggle() { if (win.visible) close(); else open(); }

    function parse(text) {
        var o = {}, ls = text.split("\n");
        for (var i = 0; i < ls.length; i++) {
            var p = ls[i].indexOf("=");
            if (p > 0) o[ls[i].substring(0, p)] = ls[i].substring(p + 1);
        }
        info = o;
    }
    function refresh() { if (!infoProc.running) infoProc.running = true; }
    Process {
        id: infoProc
        command: ["sh", root.scriptPath]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    readonly property var rows: {
        var o = info, r = [];
        if (!o.cpu) return r;
        r.push({ k: I18n.tr("Processor"), v: o.cpu, s: o.cpusub || "" });
        r.push({ k: I18n.tr("Graphics"), v: (o.gpu || "").split("|").join("\n"), s: "" });
        r.push({ k: I18n.tr("Memory"), v: o.mem || "", s: "" });
        r.push({ k: I18n.tr("Storage"), v: o.disk || "", s: o.disksub || "" });
        r.push({ k: I18n.tr("Kernel"), v: o.kernel || "", s: "" });
        r.push({ k: o.osname || "Linux", v: o.osver || "", s: "" });
        return r;
    }

    Window {
        id: win
        title: "About This Linux"
        readonly property real uiS: root.bar ? root.bar.uiScale : 1
        readonly property int wantH: Math.round((Math.ceil(content.implicitHeight) + 40 + 26) * uiS)
        readonly property int wantW: Math.round(300 * uiS)
        width: wantW
        height: wantH
        minimumWidth: wantW; maximumWidth: wantW
        minimumHeight: wantH; maximumHeight: wantH
        visible: false
        color: "transparent"
        flags: Qt.Window | Qt.FramelessWindowHint

        onVisibleChanged: if (visible) { root.refresh(); floatTries = 0; floatTimer.restart(); }
        property int floatTries: 0
        onWidthChanged: if (visible) { floatTries = 0; floatTimer.restart(); }
        onHeightChanged: if (visible) { floatTries = 0; floatTimer.restart(); }
        Timer {
            id: floatTimer
            interval: 60
            repeat: true
            onTriggered: {
                var sel = 'window = "title:^(' + win.title + ')$"';
                Hyprland.dispatch('hl.dsp.window.float({ action = "enable", ' + sel + ' })');
                Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", ' + sel + ' })');
                Hyprland.dispatch('hl.dsp.window.set_prop({ prop = "border_size", value = "0", ' + sel + ' })');
                Hyprland.dispatch('hl.dsp.window.set_prop({ prop = "rounding", value = "' + Math.round(frame.radius * win.uiS) + '", ' + sel + ' })');
                if (win.floatTries >= 2) {
                    Hyprland.dispatch('hl.dsp.window.resize({ x = ' + win.width + ', y = ' + win.height + ', "exact", ' + sel + ' })');
                    Hyprland.dispatch('hl.dsp.window.center({ ' + sel + ' })');
                }
                if (++win.floatTries >= 12) stop();
            }
        }
        Shortcut { sequences: ["Escape", "Ctrl+W"]; onActivated: win.visible = false }

        QtObject {
            id: pal
            readonly property bool dark: root.darkMode
            readonly property real bgA: (root.hub && root.hub.bar && root.hub.bar.barStyle === "normal") ? 0.97 : 0.86
            readonly property color bg: dark ? Qt.rgba(0.17, 0.17, 0.18, bgA) : Qt.rgba(0.88, 0.87, 0.86, bgA)
            readonly property color text: dark ? "#F5F5F7" : "#1D1D1F"
            readonly property color text2: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
            readonly property color text3: dark ? Qt.rgba(1, 1, 1, 0.38) : Qt.rgba(0, 0, 0, 0.42)
            readonly property color border: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.18)
            readonly property color edgeOuter: Qt.rgba(1, 1, 1, 0.50)
            readonly property color edgeInner: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.65)
            function lightBorder(active, c) { return active ? Qt.darker(c, dark ? 1.12 : 1.22) : "transparent"; }
            readonly property color lightOff: dark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.15)
            readonly property color btn: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.75)
            readonly property color btnDown: dark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.5)
        }

        Rectangle {
            id: frame
            width: parent.width / win.uiS; height: parent.height / win.uiS
            scale: win.uiS; transformOrigin: Item.TopLeft
            radius: 18
            color: pal.bg
            border.width: 1; border.color: pal.edgeOuter
            clip: true

            Rectangle {
                anchors.fill: parent; anchors.margins: 1
                radius: frame.radius - 1
                color: "transparent"
                border.width: 1; border.color: pal.edgeInner
                z: 50
            }

            DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }

            Item {
                x: 15; y: 12
                width: 58; height: 14
                Row {
                    scale: 0.93; transformOrigin: Item.TopLeft
                    spacing: 8
                    Repeater {
                        model: [{ c: "#FF5F57", on: true }, { c: "#FEBC2E", on: false }, { c: "#28C840", on: false }]
                        delegate: Rectangle {
                            required property var modelData
                            width: 14; height: 14; radius: 7
                            color: (modelData.on && (win.active || tl.containsMouse)) ? modelData.c : pal.lightOff
                            border.width: 1; border.color: pal.lightBorder(modelData.on && (win.active || tl.containsMouse), modelData.c)
                            Canvas {
                                anchors.fill: parent
                                visible: tl.containsMouse && parent.modelData.on
                                onVisibleChanged: if (visible) requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.strokeStyle = "rgba(0,0,0,0.58)";
                                    ctx.lineWidth = 1.2;
                                    ctx.lineCap = "round";
                                    ctx.beginPath();
                                    ctx.moveTo(4.9, 4.9); ctx.lineTo(9.1, 9.1);
                                    ctx.moveTo(9.1, 4.9); ctx.lineTo(4.9, 9.1);
                                    ctx.stroke();
                                }
                            }
                        }
                    }
                }
                MouseArea { id: tl; anchors.fill: parent; hoverEnabled: true; onClicked: mouse => { if (mouse.x < 22) win.visible = false; } }
            }

            Column {
                id: content
                x: 20; y: 40
                width: parent.width - 40
                spacing: 0

                Item {
                    width: parent.width; height: 118
                    Image {
                        id: userLogo
                        anchors.centerIn: parent
                        width: 112; height: 112
                        visible: status === Image.Ready
                        source: root.info.userlogo ? "file://" + root.info.userlogo : Qt.resolvedUrl("assets/yukishell-logo.png")
                        sourceSize.width: 224; sourceSize.height: 224
                        fillMode: Image.PreserveAspectFit
                        smooth: true; mipmap: true
                    }
                }
                Item { width: 1; height: 20 }

                Item {
                    width: parent.width; height: nameRow.height
                    Row {
                        id: nameRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Text {
                            id: nameTxt
                            text: "YukiShell"
                            color: pal.text
                            font.family: root.fontForWeight(Font.Bold, root.fam); font.pixelSize: 24; font.weight: Font.Bold
                        }
                        Text {
                            anchors.baseline: nameTxt.baseline
                            text: Version.label
                            color: pal.text3
                            font.family: root.fontForWeight(Font.Normal, root.fam); font.pixelSize: 24; font.weight: Font.Normal
                        }
                    }
                }
                Item { width: 1; height: 3 }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.info.sub || ""
                    color: pal.text3
                    font.family: root.fontForWeight(Font.Normal, root.fam); font.pixelSize: 12
                }
                Item { width: 1; height: 22 }

                Column {
                    width: parent.width
                    spacing: 5
                    Repeater {
                        model: root.rows
                        delegate: Row {
                            required property var modelData
                            width: parent.width
                            spacing: 8
                            Text {
                                width: 96
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.Wrap
                                text: modelData.k
                                color: pal.text
                                font.family: root.fontForWeight(Font.DemiBold, root.fam); font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            Column {
                                width: parent.width - 104
                                Text {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: modelData.v
                                    color: pal.text
                                    font.family: root.fontForWeight(Font.Normal, root.fam); font.pixelSize: 12
                                }
                                Text {
                                    visible: modelData.s !== ""
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: modelData.s
                                    color: pal.text2
                                    font.family: root.fontForWeight(Font.Normal, root.fam); font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
                Item { width: 1; height: 18 }

                Item {
                    width: parent.width; height: 24
                    Rectangle {
                        anchors.centerIn: parent
                        width: moreTxt.implicitWidth + 30; height: 24; radius: 7
                        color: moreMa.pressed ? pal.btnDown : pal.btn
                        border.width: 1; border.color: pal.border
                        Text { id: moreTxt; anchors.centerIn: parent; text: I18n.tr("More Info\u2026"); color: pal.text; font.family: root.fontForWeight(Font.Normal, root.fam); font.pixelSize: 12 }
                        MouseArea {
                            id: moreMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cmd = (root.bar ? root.bar.terminal : "kitty") + " -e sh -c 'fastfetch || neofetch; echo; read -p \"Press Enter\" _'";
                                Quickshell.execDetached(["sh", "-c", cmd]);
                            }
                        }
                    }
                }
                Item { width: 1; height: 20 }

                Item {
                    width: parent.width; height: siteTxt.implicitHeight
                    Text {
                        id: siteTxt
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (root.info.osname || "Linux") + " " + I18n.tr("Website")
                        color: pal.text2
                        font.family: root.fontForWeight(Font.Normal, root.fam); font.pixelSize: 11; font.underline: true
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: (root.bar && root.bar.openUrl ? root.bar.openUrl(root.info.home || "https://www.kernel.org") : Quickshell.execDetached(["xdg-open", root.info.home || "https://www.kernel.org"])) }
                    }
                }
                Item { width: 1; height: 10 }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Linux® is a registered trademark of Linus Torvalds.\nYukiShell " + Version.label + ", based on MacShell 0.3.9"
                    color: pal.text3
                    font.family: root.fontForWeight(Font.Normal, root.fam); font.pixelSize: 10
                    lineHeight: 1.1
                }
            }
        }
    }
}
