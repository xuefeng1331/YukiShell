import QtQuick
import QtQuick.Effects
import "Fonts.js" as Fonts
import "I18n.js" as I18n

Item {
    id: w

    property string style: "liquid"
    property string size: "small"
    property string mode: "auto"
    property real scaleF: 1.0
    property string fam: "Open Runde"
    property real screenX: x
    property real screenY: y
    property int weekStart: 0

    property bool glassReady: false
    property url shaderUrl: ""
    property url wallUrl: ""
    property string wallVideo: ""
    property bool wallPaused: false
    property Item wallItem: null
    property real screenW: 1920
    property real screenH: 1080
    property real glassOpacity: 0.42
    property real glassBlur: 5
    property real glassLiquid: 1.0
    property real glassRim: 0.45
    property color borderTint: "#8A9AB5"
    property vector4d accentTint: Qt.vector4d(0, 0, 0, 0)
    property real glassGrain: 0.03
    property bool darkGlass: true
    property bool preview: false

    property bool editing: false

    signal glassFailed()

    readonly property bool isSmall: size === "small"
    readonly property bool isMedium: size === "medium"
    readonly property bool isLarge: size === "large"
    property string lay: size
    readonly property bool alt: lay === "tall" || lay === "strip" || lay === "hero"
    property real fit: 1
    readonly property real aspect: isSmall ? 1 : (isMedium ? 395 / 185 : 395 / 385)
    readonly property real bw: Math.min(width, height * aspect)
    readonly property real bh: Math.min(height, width / aspect)
    readonly property real ox: Math.round((width - bw) / 2)
    readonly property real oy: Math.round((height - bh) / 2)
    readonly property real s: scaleF * fit * (isSmall ? 168 / 158 : (isMedium ? 358 / 338 : 1.0))
    readonly property real radiusPx: 28 * s / fit
    readonly property bool glassOn: style === "liquid" && glassReady && !preview && wallUrl != ""
    property bool glassShown: false
    property bool glassFull: false
    onGlassOnChanged: if (!glassOn) { glassShown = false; glassFull = false; }
    onGlassShownChanged: if (glassShown) fullT.restart()
    Timer { id: fullT; interval: 250; onTriggered: w.glassFull = w.glassShown }
    width: (isSmall ? 158 : (isLarge ? 358 : 338)) * s
    height: (isLarge ? 354 : 168) * scaleF

    readonly property bool dark: mode === "dark" || (mode !== "light" && darkGlass)
    readonly property color fg: dark ? Qt.rgba(1, 1, 1, 0.96) : Qt.rgba(0, 0, 0, 0.86)
    readonly property color fgSub: dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.45)
    readonly property color red: dark ? "#FF453A" : "#FF3B30"
    readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
    readonly property real tint: Math.min(0.92, dark ? 0.25 + glassOpacity * 0.8 : 0.45 + glassOpacity * 0.9)

    property var now: new Date()
    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: { var d = new Date(); if (d.toDateString() !== w.now.toDateString()) w.now = d; }
    }
    readonly property var monthNames: { var l = I18n.locale(), a = []; for (var i = 0; i < 12; i++) a.push(l.monthName(i, Locale.LongFormat)); return a; }
    readonly property var dayNames: { var l = I18n.locale(), a = []; for (var i = 0; i < 7; i++) a.push(l.dayName(i, Locale.LongFormat)); return a; }
    readonly property var letters: { var l = I18n.locale(), a = []; for (var i = 0; i < 7; i++) a.push(l.dayName(i, Locale.NarrowFormat)); return a; }
    readonly property var cal: {
        var d = w.now, y = d.getFullYear(), m = d.getMonth();
        var first = new Date(y, m, 1).getDay();
        return { year: y, month: m, today: d.getDate(), weekday: d.getDay(),
                 lead: (first - w.weekStart + 7) % 7, days: new Date(y, m + 1, 0).getDate() };
    }

    Rectangle {
        anchors.fill: parent
        visible: w.style === "normal"
        radius: w.radiusPx
        gradient: Gradient {
            GradientStop { position: 0.0; color: w.dark ? "#3A3A3D" : "#FFFFFF" }
            GradientStop { position: 1.0; color: w.dark ? "#2A2A2D" : "#EFEFF3" }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: w.style === "liquid" && !(w.glassOn && w.glassFull)
        radius: w.radiusPx
        gradient: Gradient {
            GradientStop { position: 0.0; color: w.dark ? Qt.rgba(0.22, 0.22, 0.25, 0.82) : Qt.rgba(1.0, 1.0, 1.0, 0.88) }
            GradientStop { position: 1.0; color: w.dark ? Qt.rgba(0.13, 0.13, 0.15, 0.82) : Qt.rgba(0.92, 0.92, 0.95, 0.88) }
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, w.dark ? 0.10 : 0.35) }
                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    Loader {
        id: glassLoader
        anchors.fill: parent
        active: w.glassOn
        opacity: w.glassShown ? 1 : 0.01
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        sourceComponent: Item {
            id: gl
            readonly property bool filled: wallImg.status === Image.Ready || wallImg.status === Image.Error || wslice.ready
            onFilledChanged: if (filled) showT.restart()
            Component.onCompleted: if (filled) showT.restart()
            Timer { id: showT; interval: 100; onTriggered: w.glassShown = true }
            readonly property real margin: 72
            readonly property real padPx: 10
            readonly property real ds: w.glassBlur >= 8 ? 0.5 : 1.0
            readonly property real bn: Math.min(1.0, w.glassBlur * 1.5 * ds / 64.0)

            Item {
                id: backdrop
                width: w.width + 2 * (gl.padPx + gl.margin)
                height: w.height + 2 * (gl.padPx + gl.margin)
                Rectangle {
                    anchors.fill: parent
                    visible: wallImg.status === Image.Error
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#2f6bff" }
                        GradientStop { position: 0.5; color: "#b44cff" }
                        GradientStop { position: 1.0; color: "#ff8a3d" }
                    }
                }
                Image {
                    id: wallImg
                    x: -(w.screenX - gl.padPx - gl.margin)
                    y: -(w.screenY - gl.padPx - gl.margin)
                    width: w.screenW
                    height: w.screenH
                    source: w.wallUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: w.screenW
                    smooth: true
                }
                LiveWall {
                    x: -(w.screenX - gl.padPx - gl.margin)
                    y: -(w.screenY - gl.padPx - gl.margin)
                    width: w.screenW
                    height: w.screenH
                    video: w.wallVideo
                    live: w.wallVideo !== "" && !w.wallItem
                    paused: w.wallPaused
                }
            }
            WallSlice {
                id: wslice
                wall: w.wallItem
                sx: w.screenX - gl.padPx - gl.margin
                sy: w.screenY - gl.padPx - gl.margin
                width: backdrop.width
                height: backdrop.height
                textureSize: Qt.size(Math.max(1, Math.round(backdrop.width * gl.ds)), Math.max(1, Math.round(backdrop.height * gl.ds)))
            }
            ShaderEffectSource {
                id: bsrc
                sourceItem: backdrop
                hideSource: true
                live: !wslice.ready
                visible: false
                textureSize: Qt.size(Math.max(1, Math.round(backdrop.width * gl.ds)),
                                     Math.max(1, Math.round(backdrop.height * gl.ds)))
            }
            MultiEffect {
                id: blurFx
                source: wslice.ready ? wslice : bsrc
                width: backdrop.width * gl.ds
                height: backdrop.height * gl.ds
                blurEnabled: true
                blurMax: 64
                blur: gl.bn
                autoPaddingEnabled: false
                visible: false
            }
            ShaderEffectSource {
                id: blurred
                sourceItem: blurFx
                live: true
                visible: false
            }
            ShaderEffect {
                x: -gl.padPx
                y: -gl.padPx
                width: w.width + 2 * gl.padPx
                height: w.height + 2 * gl.padPx
                fragmentShader: w.shaderUrl
                onStatusChanged: if (status === ShaderEffect.Error) w.glassFailed()

                property variant src: blurred
                property vector2d itemSize: Qt.vector2d(width, height)
                property vector2d glassSize: Qt.vector2d(w.width, w.height)
                property vector2d srcSize: Qt.vector2d(backdrop.width, backdrop.height)
                property vector2d srcOffset: Qt.vector2d(gl.margin, gl.margin)
                property real pad: gl.padPx
                property real radius: w.radiusPx
                property real bezel: Math.min(Math.min(w.width, w.height) * 0.36, 26)
                property real thickness: 30 * w.glassLiquid
                property real dispersion: 0.06 * w.glassLiquid
                property real magnify: 0.08 * w.glassLiquid * Math.min(1, 90 / w.height)
                property real rim: w.glassRim
                property real grain: w.glassGrain * 0.3
                property real blurPx: 1.5
                property real tintMix: w.glassOpacity * 0.55
                property vector4d accentTint: w.accentTint
                property real saturation: 1.25
                property real dark: w.dark ? 1 : 0
                property real debug: 0
                property real shadowAmt: 0
                property real flatInner: 1
                property real rimTint: 1
                property real ringW: 0
            }
        }
    }

    CornerBorder {
        z: 2
        visible: w.style !== "liquid"
        anchors.fill: parent
        cornerR: w.radiusPx
        dark: w.dark
        tint: w.borderTint
        lineW: 0.8
    }

    readonly property real pad: 15 * s

    readonly property var gridSpec: isSmall ? { x: 12, y: 32, w: 134, wdH: 16, rowH: 16.7, wdPx: 10.5, dayPx: 11.5, circ: 17 }
                                  : (isMedium ? { x: 172, y: 11, w: 152, wdH: 18, rowH: 19.5, wdPx: 11, dayPx: 12.5, circ: 18 }
                                              : { x: 15, y: 58, w: 308, wdH: 24, rowH: 44, wdPx: 13, dayPx: 19, circ: 33 })
    Item {
        visible: !w.alt
        id: grid
        x: w.ox + (Math.round(w.gridSpec.x * w.s))
        y: w.oy + (Math.round(w.gridSpec.y * w.s))
        width: Math.round(w.gridSpec.w * w.s)
        height: wdH + 6 * rowH
        readonly property real cw: width / 7
        readonly property int wdH: Math.round(w.gridSpec.wdH * w.s)
        readonly property int rowH: Math.round(w.gridSpec.rowH * w.s)
        readonly property real wdPx: w.gridSpec.wdPx * w.s
        readonly property real dayPx: w.gridSpec.dayPx * w.s
        readonly property int circ: 2 * Math.round(w.gridSpec.circ * w.s / 2)

        Repeater {
            model: 7
            delegate: Text {
                required property int index
                x: Math.round((index + 0.5) * grid.cw - implicitWidth / 2)
                y: Math.round((grid.wdH - implicitHeight) / 2)
                text: w.letters[(index + w.weekStart) % 7]
                color: w.fgSub
                font.family: Fonts.forWeight(Font.DemiBold, w.fam)
                font.pixelSize: grid.wdPx
                font.weight: Font.DemiBold
            }
        }
        Repeater {
            model: 42
            delegate: Item {
                id: cell
                required property int index
                readonly property int day: index - w.cal.lead + 1
                readonly property bool valid: day >= 1 && day <= w.cal.days
                readonly property bool isToday: valid && day === w.cal.today
                visible: valid
                x: Math.round((index % 7 + 0.5) * grid.cw) - grid.circ / 2
                y: grid.wdH + Math.floor(index / 7) * grid.rowH + Math.round((grid.rowH - grid.circ) / 2)
                width: grid.circ
                height: grid.circ
                Rectangle {
                    visible: cell.isToday
                    anchors.fill: parent
                    radius: width / 2
                    color: w.red
                }
                Text {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: cell.day
                    color: cell.isToday ? "white" : w.fg
                    font.family: Fonts.forWeight(cell.isToday ? Font.Bold : Font.DemiBold, w.fam)
                    font.pixelSize: grid.dayPx
                    font.weight: cell.isToday ? Font.Bold : Font.DemiBold
                }
            }
        }
    }

    Text {
        visible: !w.alt && (w.isSmall)
        x: w.ox + (13 * w.s)
        y: w.oy + (10 * w.s)
        text: w.monthNames[w.cal.month].toUpperCase()
        color: w.red
        font.family: Fonts.forWeight(Font.Bold, w.fam)
        font.pixelSize: 13 * w.s
        font.weight: Font.Bold
    }

    Rectangle {
        visible: !w.alt && (w.isMedium)
        x: w.ox + (164 * w.s); y: w.oy + (16 * w.s)
        width: 1; height: w.bh - 32 * w.s
        color: w.line
    }
    Text {
        visible: !w.alt && (w.isMedium)
        x: w.ox + (w.pad)
        y: w.oy + (14 * w.s)
        width: 142 * w.s
        elide: Text.ElideRight
        text: w.dayNames[w.cal.weekday].toUpperCase()
        color: w.red
        font.family: Fonts.forWeight(Font.Bold, w.fam)
        font.pixelSize: 13 * w.s
        font.weight: Font.Bold
    }
    Text {
        visible: !w.alt && (w.isMedium)
        x: w.ox + (w.pad - 1 * w.s)
        y: w.oy + (30 * w.s)
        text: w.cal.today
        color: w.fg
        font.family: w.fam
        font.pixelSize: 58 * w.s
        font.weight: Font.Light
    }
    Text {
        visible: !w.alt && (w.isMedium)
        x: w.ox + (w.pad)
        y: w.oy + (w.bh - w.pad + 1 * w.s - implicitHeight)
        width: 142 * w.s
        elide: Text.ElideRight
        text: w.monthNames[w.cal.month] + " " + w.cal.year
        color: w.fgSub
        font.family: Fonts.forWeight(Font.DemiBold, w.fam)
        font.pixelSize: 14 * w.s
        font.weight: Font.DemiBold
    }

    Row {
        visible: !w.alt && (w.isLarge)
        x: w.ox + (w.pad)
        y: w.oy + (13 * w.s)
        spacing: 7 * w.s
        Text {
            text: w.monthNames[w.cal.month]
            color: w.red
            font.family: Fonts.forWeight(Font.DemiBold, w.fam)
            font.pixelSize: 26 * w.s
            font.weight: Font.DemiBold
        }
        Text {
            text: w.cal.year
            color: w.fgSub
            font.family: Fonts.forWeight(Font.DemiBold, w.fam)
            font.pixelSize: 26 * w.s
            font.weight: Font.DemiBold
        }
    }
    Rectangle {
        visible: !w.alt && (w.isLarge)
        x: w.ox + (w.pad)
        y: grid.y + grid.wdH
        width: w.bw - 2 * w.pad
        height: 1
        color: w.line
    }

    Loader {
        anchors.fill: parent
        z: 3
        active: w.alt
        sourceComponent: Component { CalendarAlt { wd: w; lay: w.lay } }
    }
}
