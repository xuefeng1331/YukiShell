// macOS Tahoe style Weather widget.
//   size:  "small" 158x158 · "medium" 338x158 · "large" 338x354   (macOS point sizes, times scaleF)
//   style: "liquid" - Liquid Glass: the wallpaper behind the widget is blurred + refracted by liquidglass.frag, using the
//                     Appearance sliders (Translucency / Blur / Liquid strength)
//          "normal" - solid card (same as the Calendar widget)
//   The look (glass, tint, text colours, border) is the same as the Clock and Calendar widgets: it follows the shell's
//   Dark / Light setting.
//
// The item's own x / y are its position on the screen, which is how the glass knows which part of the wallpaper
// sits behind it (it follows the widget while it is dragged).
import QtQuick
import QtQuick.Effects
import "Fonts.js" as Fonts

Item {
    id: w

    // --- look ---
    property string style: "liquid"
    property string size: "small"
    property real scaleF: 1.0
    property string fam: "Open Runde"
    property real screenX: x
    property real screenY: y

    // --- data (from YukiWidgets) ---
    property string city: "—"
    property bool located: true         // show the little location arrow (automatic location)
    property bool hasData: false
    property int temp: 0
    property int hi: 0
    property int lo: 0
    property string cond: "Loading…"
    property string kind: "sun"         // WeatherIcon kind
    property bool isDay: true
    property string unitSuffix: "°"
    property var hourly: []             // [{ h: "Now", t: 58, k: "sun" }, ...]
    property var daily: []              // [{ d: "Today", lo: 56, hi: 79, k: "sun" }, ...]

    // --- liquid glass inputs (the Appearance sliders) ---
    property bool glassReady: false     // liquidglass.frag.qsb compiled
    property url shaderUrl: ""
    property url wallUrl: ""
    property string wallVideo: ""        // animated wallpaper to play behind the glass ("" = none / real-time glass off)
    property bool wallPaused: false      // desktop covered / Game Mode: keep the decoder idle
    property Item wallItem: null         // a LiveWall shared by the whole window: show a slice of it instead of a decoder of our own
    property real screenW: 1920
    property real screenH: 1080
    property real glassOpacity: 0.42    // Translucency
    property real glassBlur: 5          // Blur
    property real glassLiquid: 1.0      // Liquid strength
    property real glassRim: 0.45
    property color borderTint: "#8A9AB5"      // Control Center border colour
    property vector4d accentTint: Qt.vector4d(0, 0, 0, 0)   // "Tint the interface" (rgb = accent, a = on) for the glass shader
    property real glassGrain: 0.03
    property bool darkGlass: true
    property bool preview: false        // inside the Settings gallery: no wallpaper, simplified glass

    // --- desktop edit mode ---
    property bool editing: false

    signal glassFailed()                // the shader did not compile / load -> YukiWidgets falls back to the frosted card

    readonly property bool isSmall: size === "small"
    readonly property bool isMedium: size === "medium"
    readonly property bool isLarge: size === "large"
    // the design for its grid shape: the three classic ones, or one of the designs in WeatherAlt.qml (tall | strip | hero)
    property string lay: size
    readonly property bool alt: lay === "tall" || lay === "strip" || lay === "hero"
    // a bigger grid block (Settings: drag the corner while editing): `fit` = how much bigger than this design's own block, given
    // by the desktop. The contents are drawn that much larger (natively, not stretched) in the block bw x bh, placed at ox, oy.
    property real fit: 1
    readonly property real aspect: isSmall ? 1 : (isMedium ? 395 / 185 : 395 / 385)
    // the weather uses the room instead: the whole width (more hours), and the whole height when Large (more days)
    readonly property real bw: width
    readonly property real bh: isLarge ? height : Math.min(height, width / aspect)
    readonly property real ox: 0
    readonly property real oy: Math.round((height - bh) / 2)
    // how many hours fit across (each column about as wide as in the original design)
    readonly property int hoursMedium: Math.max(4, Math.min(hourly.length || 4, Math.floor((bw - 172 * s - pad + 4 * s) / (44 * s))))
    readonly property int hoursLarge: Math.max(6, Math.min(hourly.length || 6, Math.floor((bw - 2 * pad) / (54 * s))))
    // Small / Medium are slightly enlarged; Large shares the widened footprint without stretching its vertical content.
    readonly property real s: scaleF * fit * (isSmall ? 168 / 158 : (isMedium ? 358 / 338 : 1.0))
    readonly property real radiusPx: 28 * s / fit
    readonly property bool glassOn: style === "liquid" && glassReady && !preview && wallUrl != ""
    // the glass is made at once but only shown once its backdrop holds the wallpaper (an empty backdrop refracts as black):
    // until then it sits at 1% opacity (so it still renders and fills its textures) over the plain card, then fades in
    property bool glassShown: false
    property bool glassFull: false          // the fade-in is over: the plain card underneath can go
    onGlassOnChanged: if (!glassOn) { glassShown = false; glassFull = false; }
    onGlassShownChanged: if (glassShown) fullT.restart()
    Timer { id: fullT; interval: 250; onTriggered: w.glassFull = w.glassShown }
    width: (isSmall ? 158 : (isLarge ? 358 : 338)) * s
    height: (isLarge ? 354 : 168) * scaleF

    // every condition has its glyph (WeatherIcon.qml): sun, moon, partly cloudy (day / night), cloud, fog, rain, snow, storm
    readonly property var iconKinds: ["sun", "moon", "partly", "partlyNight", "cloud", "fog", "rain", "snow", "storm"]
    function showIcon(k) { return iconKinds.indexOf(k) >= 0; }

    // --- light / dark (same rules as the Clock and Calendar widgets) ---
    readonly property bool dark: darkGlass
    readonly property color fg: dark ? Qt.rgba(1, 1, 1, 0.96) : Qt.rgba(0, 0, 0, 0.86)
    readonly property color fgSub: dark ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(0, 0, 0, 0.52)
    readonly property color fgHour: dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.70)
    readonly property color line: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color barTrack: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)
    readonly property color barFill: dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.62)
    // glass tint: the same as Clock / Calendar, so dark (light mode) / white (dark mode) text stays readable on any wallpaper
    readonly property real tint: Math.min(0.92, dark ? 0.25 + glassOpacity * 0.8 : 0.45 + glassOpacity * 0.9)

    // --- background ---
    // Normal: solid card
    Rectangle {
        anchors.fill: parent
        visible: w.style === "normal"
        radius: w.radiusPx
        gradient: Gradient {
            GradientStop { position: 0.0; color: w.dark ? "#3A3A3D" : "#FFFFFF" }
            GradientStop { position: 1.0; color: w.dark ? "#2A2A2D" : "#EFEFF3" }
        }
    }

    // Liquid fallback / gallery preview: frosted card (while the shader builds, if it fails, and in Settings)
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

    // Liquid Glass: wallpaper crop -> blur -> refraction shader (the same maths as the Dock)
    Loader {
        id: glassLoader
        anchors.fill: parent
        active: w.glassOn
        opacity: w.glassShown ? 1 : 0.01
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        sourceComponent: Item {
            id: gl
            // the backdrop has the wallpaper (or the live video slice); one more moment for the blur to render it, then show
            readonly property bool filled: wallImg.status === Image.Ready || wallImg.status === Image.Error || wslice.ready
            onFilledChanged: if (filled) showT.restart()
            Component.onCompleted: if (filled) showT.restart()
            Timer { id: showT; interval: 100; onTriggered: w.glassShown = true }
            readonly property real margin: 72           // backdrop captured around the widget (blur + refraction reach)
            readonly property real padPx: 10            // shader item padding (soft shadow)
            readonly property real ds: w.glassBlur >= 8 ? 0.5 : 1.0
            readonly property real bn: Math.min(1.0, w.glassBlur * 1.5 * ds / 64.0)

            // the part of the wallpaper behind the widget, laid out exactly like the screen
            Item {
                id: backdrop
                width: w.width + 2 * (gl.padPx + gl.margin)
                height: w.height + 2 * (gl.padPx + gl.margin)
                // the placeholder only shows when the wallpaper can't be loaded (while it loads, the glass stays clear instead of
                // flashing these colours after every restart)
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
            // the window's shared video (WallSlice), straight into the blur while it plays: the backdrop (gradient + still picture) is
            // not captured at all then, since the full-screen video covers it anyway
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
                property real grain: w.glassGrain * 0.3     // the Dock's glass
                property real blurPx: 1.5            // tiny residual smoothing; the real blur is the MultiEffect pre-pass
                property real tintMix: w.glassOpacity * 0.55     // the Dock's light, adaptive tint (no heavy widget tint)
                property vector4d accentTint: w.accentTint
                property real saturation: 1.25
                property real dark: w.dark ? 1 : 0
                property real debug: 0
                property real shadowAmt: 0           // no drop shadow
                property real flatInner: 1           // no darker inner edge (needs the rebuilt liquidglass shader)
                property real rimTint: 1             // rim + border follow the glass's own colour
                property real ringW: 0               // the border is the Control Center CornerBorder below
            }
        }
    }

    // Control Center border (the solid styles; Liquid Glass has the Dock's edge light from the shader instead)
    CornerBorder {
        z: 2
        visible: w.style !== "liquid"
        anchors.fill: parent
        cornerR: w.radiusPx
        dark: w.dark
        tint: w.borderTint
        lineW: 0.8
    }

    // --- content ---
    readonly property real pad: 15 * s

    // city (+ location arrow)
    Row {
        visible: !w.alt
        x: w.ox + (w.pad)
        y: w.oy + (w.pad - 1 * w.s)
        spacing: 4 * w.s
        Text {
            id: cityText
            text: w.city
            width: Math.min(implicitWidth, 158 * w.s - 2 * w.pad - (w.located ? 14 * w.s : 0))
            elide: Text.ElideRight
            color: w.fg
            font.family: Fonts.forWeight(Font.DemiBold, w.fam)
            font.pixelSize: 15 * w.s
            font.weight: Font.DemiBold
        }
        Canvas {
            visible: w.located
            anchors.verticalCenter: cityText.verticalCenter
            anchors.verticalCenterOffset: 1 * w.s
            width: 9 * w.s
            height: 9 * w.s
            onWidthChanged: requestPaint()
            Connections { target: w; function onDarkChanged() { loc.requestPaint(); } }
            id: loc
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = w.dark ? "white" : "#1c1c1e";
                ctx.beginPath();            // location arrow, pointing up-right
                ctx.moveTo(width, 0);
                ctx.lineTo(0.05 * width, 0.42 * height);
                ctx.lineTo(0.58 * width, 0.46 * height);
                ctx.lineTo(0.62 * width, 1.0 * height);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    // big temperature
    Text {
        visible: !w.alt
        x: w.ox + (w.pad - 1 * w.s)
        y: w.oy + (30 * w.s)
        text: w.hasData ? (w.temp + w.unitSuffix) : "–°"
        color: w.fg
        font.family: w.fam
        font.pixelSize: 46 * w.s
        font.weight: Font.Light
    }

    // condition + high / low (bottom-left; top-right in the large widget)
    Column {
        visible: !w.alt
        id: condCol
        width: w.isLarge ? 150 * w.s : 158 * w.s - 2 * w.pad
        x: w.ox + (w.isLarge ? w.bw - w.pad - width : w.pad)
        y: w.oy + (w.isLarge ? 36 * w.s : 158 * w.s - w.pad + 1 * w.s - implicitHeight)
        spacing: 1 * w.s

        Item {
            visible: w.showIcon(w.kind)
            width: parent.width
            height: visible ? 23 * w.s : 0
            WeatherIcon { light: !w.dark;
                x: w.isLarge ? parent.width - width : 0
                kind: w.kind
                size: 20 * w.s
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: w.isLarge ? Text.AlignRight : Text.AlignLeft
            text: w.cond
            elide: Text.ElideRight
            color: w.fg
            font.family: Fonts.forWeight(Font.DemiBold, w.fam)
            font.pixelSize: 14 * w.s
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            horizontalAlignment: w.isLarge ? Text.AlignRight : Text.AlignLeft
            text: w.hasData ? ("H:" + w.hi + w.unitSuffix + " L:" + w.lo + w.unitSuffix) : " "
            color: w.fg
            font.family: Fonts.forWeight(Font.DemiBold, w.fam)
            font.pixelSize: 14 * w.s
            font.weight: Font.DemiBold
        }
    }


    // --- medium: hourly forecast on the right ---
    Rectangle {   // divider
        visible: !w.alt && (w.isMedium)
        x: w.ox + (164 * w.s); y: w.oy + (16 * w.s)
        width: 1; height: w.bh - 32 * w.s
        color: w.line
    }
    Row {
        visible: !w.alt && (w.isMedium)
        x: w.ox + (172 * w.s)
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: w.isMedium ? w.hourly.slice(0, w.hoursMedium) : []
            delegate: WeatherHourCol {
                required property var modelData
                info: modelData
                wd: w
                colW: (w.bw - 172 * w.s - w.pad + 4 * w.s) / w.hoursMedium
            }
        }
    }

    // --- large: hourly strip + 5-day list ---
    Rectangle { visible: !w.alt && w.isLarge; x: w.ox + (w.pad); y: w.oy + (134 * w.s); width: w.bw - 2 * w.pad; height: 1; color: w.line }
    Row {
        visible: !w.alt && (w.isLarge)
        x: w.ox + (w.pad)
        y: w.oy + (142 * w.s)
        Repeater {
            model: w.isLarge ? w.hourly.slice(0, w.hoursLarge) : []
            delegate: WeatherHourCol {
                required property var modelData
                info: modelData
                wd: w
                colW: (w.bw - 2 * w.pad) / w.hoursLarge
            }
        }
    }
    Rectangle { visible: !w.alt && w.isLarge; x: w.ox + (w.pad); y: w.oy + (206 * w.s); width: w.bw - 2 * w.pad; height: 1; color: w.line }
    Column {
        id: dailyCol
        visible: !w.alt && (w.isLarge)
        x: w.ox + (w.pad)
        y: w.oy + (210 * w.s)
        width: w.bw - 2 * w.pad
        readonly property var days: w.daily.slice(0, Math.max(5, Math.min(w.daily.length, Math.floor((w.bh - 210 * w.s - w.pad) / (27 * w.s)))))
        readonly property real minT: { var m = 1e9; for (var i = 0; i < days.length; i++) m = Math.min(m, days[i].lo); return m; }
        readonly property real maxT: { var m = -1e9; for (var i = 0; i < days.length; i++) m = Math.max(m, days[i].hi); return m; }
        Repeater {
            model: dailyCol.days
            delegate: Item {
                id: dr
                required property var modelData
                width: dailyCol.width
                height: 27 * w.s
                readonly property real span: Math.max(1, dailyCol.maxT - dailyCol.minT)
                Text {
                    x: 0
                    width: 66 * w.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: dr.modelData.d
                    color: w.fg
                    font.family: Fonts.forWeight(Font.DemiBold, w.fam)
                    font.pixelSize: 14 * w.s
                    font.weight: Font.DemiBold
                }
                WeatherIcon { light: !w.dark;
                    x: 72 * w.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: w.showIcon(dr.modelData.k)
                    kind: dr.modelData.k
                    size: 18 * w.s
                }
                Text {
                    x: 104 * w.s
                    width: 32 * w.s
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    text: dr.modelData.lo + w.unitSuffix
                    color: w.fgSub
                    font.family: Fonts.forWeight(Font.DemiBold, w.fam)
                    font.pixelSize: 14 * w.s
                    font.weight: Font.DemiBold
                }
                Rectangle {   // temperature range bar
                    id: track
                    x: 144 * w.s
                    width: dr.width - 144 * w.s - 38 * w.s
                    height: 4 * w.s
                    radius: height / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: w.barTrack
                    Rectangle {
                        x: track.width * (dr.modelData.lo - dailyCol.minT) / dr.span
                        width: Math.max(track.height, track.width * (dr.modelData.hi - dr.modelData.lo) / dr.span)
                        height: parent.height
                        radius: height / 2
                        color: w.barFill
                    }
                }
                Text {
                    x: dr.width - 32 * w.s
                    width: 32 * w.s
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    text: dr.modelData.hi + w.unitSuffix
                    color: w.fg
                    font.family: Fonts.forWeight(Font.DemiBold, w.fam)
                    font.pixelSize: 14 * w.s
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // --- the designs of the other grid shapes ---
    Loader {
        anchors.fill: parent
        z: 3
        active: w.alt
        sourceComponent: Component { WeatherAlt { wd: w; lay: w.lay } }
    }
}
