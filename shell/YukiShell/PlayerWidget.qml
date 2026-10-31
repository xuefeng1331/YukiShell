// macOS Tahoe "Now Playing" widget (MPRIS: Spotify, Firefox, mpv, VLC, ...).
//   size:  "small"  - art, play / pause, title + scrolling artist line
//          "medium" - the wide Now Playing card: art, title, scrolling subtitle, waves, progress + times, shuffle / back / play / forward / repeat
//          "large"  - the same card, taller, with big artwork
//   Everything is drawn in "reference units" (RU): the wide card scales to the shell's 358 x 168 Medium footprint.
//   style: "light"  - plain light card (same face as the Clock widget), dark text
//          "dark"   - plain dark card (same face as the Clock widget), white text
//          "liquid" - normal Liquid Glass (Appearance sliders), exactly like the Clock / Calendar / Weather widgets
//
// The light and dark cards take their colour from the artwork (a pale / deep version of it). The liquid card never does.
//
// This file only draws. YukiWidgets.qml owns the MPRIS player and feeds the data properties; the buttons emit
// togglePlaying() / nextTrack() / previousTrack().
import QtQuick
import QtQuick.Effects
import "I18n.js" as I18n
import "Fonts.js" as Fonts

Item {
    id: w

    // --- look ---
    property string style: "dark"            // "light" | "dark" | "liquid"
    property string size: "small"
    property real scaleF: 1.0
    property real contentScale: 1.0          // scales art / text / buttons; the card itself keeps the widget's full size
    property string fam: "Open Runde"
    property real screenX: x
    property real screenY: y
    property bool preview: false             // inside the Settings gallery: sample data, no wallpaper, not clickable
    property bool editing: false

    // --- data (from YukiWidgets) ---
    property bool hasPlayer: false
    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string appName: ""              // the player's own name ("Chromium", "Spotify"): fallback text
    property string appIcon: ""              // its icon (file path): fallback artwork when the track has no cover
    property bool playing: false
    property bool paused: false              // paused (not stopped): the visualizer stays frozen where the song stopped
    property real position: 0                // seconds
    property real length: 0                  // seconds (0 = unknown)

    property bool shuffle: false
    property int loop: 0                     // 0 = off, 1 = repeat song, 2 = repeat all
    property bool canShuffle: true
    property bool canLoop: true

    property bool canSeek: false

    // audio visualizer: bars rising from the bottom of the card, behind the controls (spectrum from the shell's AudioVis)
    property var visSrc: null
    property bool visOn: false
    property string visStyle: "bars"         // bars | mirror | wave
    property string visColor: "white"        // art | white | accent
    property real visGain: 1.0
    property int visCount: 24                // columns (Settings -> Widgets -> Audio Visualizer)
    property real visWidth: 0.62             // bar width as a share of its column
    property color visAccent: "#0A84FF"
    // Settings -> Widgets -> Music Widget
    property real glowAmt: 0.6               // cover glow: the album art lights the card from behind (0 = off)
    property bool motion: true               // living artwork (off with Reduce Motion)
    property string barStyle: "slim"         // progress bar: slim | bold
    property string visMode: "ambient"       // visualizer: ambient (soft glowing wave along the bottom) | strip (bars behind the controls)

    signal seek(real seconds)
    signal raiseRequested()                  // click on the artwork: bring the player's window forward
    signal togglePlaying()
    signal nextTrack()
    signal previousTrack()
    signal toggleShuffle()
    signal cycleLoop()

    // --- liquid glass inputs (the Appearance sliders), same as the other widgets ---
    property bool glassReady: false
    property url shaderUrl: ""
    property url wallUrl: ""
    property string wallVideo: ""        // animated wallpaper to play behind the glass ("" = none / real-time glass off)
    property bool wallPaused: false      // desktop covered / Game Mode: keep the decoder idle
    property Item wallItem: null         // a LiveWall shared by the whole window: show a slice of it instead of a decoder of our own
    property real screenW: 1920
    property real screenH: 1080
    property real glassOpacity: 0.42
    property real glassBlur: 5
    property real glassLiquid: 1.0
    property real glassRim: 0.45
    property color borderTint: "#8A9AB5"      // Control Center border colour
    property vector4d accentTint: Qt.vector4d(0, 0, 0, 0)   // "Tint the interface" (rgb = accent, a = on) for the glass shader
    property real glassGrain: 0.03
    property bool darkGlass: true

    signal glassFailed()

    // the design for its grid shape: the three classic ones (size), or tall (one column, 2+ rows: a portrait card), strip
    // (4 x 1: everything on one line) or hero (4 columns, 2+ rows: a big cover and a Now Playing column). The isSmall / isMedium /
    // isLarge flags only mean the classic designs.
    property string lay: size
    readonly property bool isTall: lay === "tall"
    readonly property bool isStrip: lay === "strip"
    readonly property bool isHero: lay === "hero"
    readonly property bool alt: isTall || isStrip || isHero
    readonly property bool isSmall: size === "small" && !alt
    readonly property bool isMedium: size === "medium" && !alt
    readonly property bool isLarge: size === "large" && !alt

    // RU -> px. It follows the real size of the widget, so it still fits if the host stretches it.
    // On a bigger grid block the side that runs out first decides, and the layout stretches along the other one.
    readonly property real k0: isSmall ? Math.min(width, height) / 202
                             : isTall ? width / 202
                             : (isMedium || isStrip) ? Math.min(height / 202, width / 430)
                             : isHero ? height / 376
                             : Math.min(width / 446, height / 441)
    readonly property real k: contentScale * k0        // RU -> px for the contents
    readonly property real wr: width / k               // card size in RU: the layout stretches to fill the whole card
    readonly property real hr: height / k
    readonly property real radiusPx: 28 * scaleF * (size === "small" ? 168 / 158 : (size === "medium" ? 358 / 338 : 1))

    width: (isSmall ? 158 : (isMedium ? 338 : 358)) * scaleF
           * (isSmall ? 168 / 158 : (isMedium ? 358 / 338 : 1.0))
    height: (isLarge ? 354 : 168) * scaleF

    readonly property bool glassOn: style === "liquid" && glassReady && !preview && wallUrl != ""
    // the glass is made at once but only shown once its backdrop holds the wallpaper (an empty backdrop refracts as black):
    // until then it sits at 1% opacity (so it still renders and fills its textures) over the plain card, then fades in
    property bool glassShown: false
    property bool glassFull: false          // the fade-in is over: the plain card underneath can go
    onGlassOnChanged: if (!glassOn) { glassShown = false; glassFull = false; }
    onGlassShownChanged: if (glassShown) fullT.restart()
    Timer { id: fullT; interval: 250; onTriggered: w.glassFull = w.glassShown }
    readonly property bool dark: style === "dark" || (style === "liquid" && darkGlass)
    readonly property real tint: Math.min(0.92, dark ? 0.25 + glassOpacity * 0.8 : 0.45 + glassOpacity * 0.9)

    // --- colours ---
    function fileUrl(p) {
        if (!p) return "";
        if (p.indexOf("/") === 0) return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F");
        return p;
    }
    readonly property url artSrc: fileUrl(artUrl)

    function fa(a) { return dark ? Qt.rgba(1, 1, 1, a) : Qt.rgba(0, 0, 0, a); }
    // "Tint the interface": buttons and the progress bar take a shade of the accent (text stays white / black)
    readonly property bool accentUi: accentTint.w > 0
    readonly property color inkC: dark ? Qt.tint(visAccent, Qt.rgba(1, 1, 1, 0.18)) : Qt.tint(visAccent, Qt.rgba(0, 0, 0, 0.25))
    function ia(a) { return accentUi ? Qt.rgba(inkC.r, inkC.g, inkC.b, Math.min(1, a + 0.2)) : fa(a); }
    readonly property color fg: fa(dark ? 0.90 : 0.86)          // title
    readonly property color fg2: fa(dark ? 0.52 : 0.50)         // subtitle, times
    readonly property color fgBtn: ia(dark ? 0.78 : 0.72)       // back / play / forward
    readonly property color fgDim: ia(dark ? 0.52 : 0.48)       // shuffle / repeat when off
    readonly property color trackCol: fa(dark ? 0.12 : 0.10)
    readonly property color fillCol: ia(dark ? 0.58 : 0.50)

    // --- artwork colour --- (ArtTint.qml; the Control Center's visualizer uses the same one)
    readonly property bool tintKnown: artTint.known
    readonly property real tintH: artTint.h
    readonly property real tintS: artTint.s
    ArtTint { id: artTint; source: w.artSrc }
    readonly property bool faceTint: tintKnown && !preview && hasPlayer
    function tintFace(l, satMul) { return Qt.hsla(tintH, Math.min(0.7, tintS * satMul), l, 1); }

    // --- background ---
    // Light face
    Rectangle {
        anchors.fill: parent
        visible: w.style === "light"
        radius: w.radiusPx
        gradient: Gradient {
            GradientStop { position: 0.0; color: w.faceTint ? w.tintFace(0.92, 0.85) : "#E9EAEB"; Behavior on color { ColorAnimation { duration: 400 } } }
            GradientStop { position: 0.55; color: w.faceTint ? w.tintFace(0.88, 0.85) : "#DFE0E2"; Behavior on color { ColorAnimation { duration: 400 } } }
            GradientStop { position: 1.0; color: w.faceTint ? w.tintFace(0.83, 0.85) : "#D6D7DA"; Behavior on color { ColorAnimation { duration: 400 } } }
        }
    }

    // Dark face
    Rectangle {
        anchors.fill: parent
        visible: w.style === "dark"
        radius: w.radiusPx
        gradient: Gradient {
            GradientStop { position: 0.0; color: w.faceTint ? w.tintFace(0.29, 0.75) : "#38393D"; Behavior on color { ColorAnimation { duration: 400 } } }
            GradientStop { position: 0.55; color: w.faceTint ? w.tintFace(0.23, 0.75) : "#303135"; Behavior on color { ColorAnimation { duration: 400 } } }
            GradientStop { position: 1.0; color: w.faceTint ? w.tintFace(0.15, 0.75) : "#242529"; Behavior on color { ColorAnimation { duration: 400 } } }
        }
    }

    // Liquid fallback / gallery preview: frosted card
    Rectangle {
        anchors.fill: parent
        visible: w.style === "liquid" && !(w.glassOn && w.glassFull)
        radius: w.radiusPx
        gradient: Gradient {
            GradientStop { position: 0.0; color: w.dark ? Qt.rgba(0.22, 0.22, 0.25, 0.82) : Qt.rgba(1.0, 1.0, 1.0, 0.88) }
            GradientStop { position: 1.0; color: w.dark ? Qt.rgba(0.13, 0.13, 0.15, 0.82) : Qt.rgba(0.92, 0.92, 0.95, 0.88) }
        }
    }

    // Liquid Glass: wallpaper crop -> blur -> refraction shader (same maths as the Dock and the other widgets)
    Loader {
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
            readonly property real margin: 72
            readonly property real padPx: 10
            // the Dock's glass: the same blur (glassBlur here is the Dock's, see WidgetVisual.qml)
            readonly property real ds: w.glassBlur >= 8 ? 0.5 : 1.0
            readonly property real bn: Math.min(1.0, w.glassBlur * 1.5 * ds / 64.0)

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
                // the Dock's glass: its light, adaptive tint (no heavy widget tint), grain and residual blur
                property real grain: w.glassGrain * 0.3
                property real blurPx: 1.5
                property real tintMix: w.glassOpacity * 0.55
                property vector4d accentTint: w.accentTint
                property real saturation: 1.25
                property real dark: w.dark ? 1 : 0
                property real debug: 0
                property real shadowAmt: 0           // no drop shadow
                property real flatInner: 1           // no darker inner edge (needs the rebuilt liquidglass shader)
                property real rimTint: 1
                property real ringW: 0
            }
        }
    }

    // --- ambience: the cover's colours fill the card from behind (a small, heavily blurred copy of the art scaled up, so it costs
    //     next to nothing), and the ambient visualizer glows along the bottom; both are clipped to the card's rounded shape.
    //     A new song fades the glow out and back in with the new colours; while playing (Living artwork) it drifts slowly. ---
    property url glowSrc: ""
    property real glowT: 0                   // the glow's own fade (track changes)
    readonly property bool glowWanted: glowAmt > 0.01 && hasPlayer && !preview && artSrc != ""
    onArtSrcChanged: glowSwap.restart()
    Component.onCompleted: { w.glowSrc = w.artSrc; w.dispTitle = w.shownTitle; w.dispSub = w.shownSub; }
    SequentialAnimation {
        id: glowSwap
        NumberAnimation { target: w; property: "glowT"; to: 0; duration: 260; easing.type: Easing.InQuad }
        ScriptAction { script: w.glowSrc = w.artSrc }
    }
    NumberAnimation { id: glowIn; target: w; property: "glowT"; to: 1; duration: 900; easing.type: Easing.OutCubic }
    Item {
        id: amb
        anchors.fill: parent
        visible: glowFx.opacity > 0.01 || ambVis.opacity > 0.01
        layer.enabled: visible
        layer.effect: MultiEffect { maskEnabled: true; maskSource: ambMask }
        Rectangle { id: ambMask; anchors.fill: parent; radius: w.radiusPx; visible: false; layer.enabled: true }

        Image {
            id: ambArt
            source: w.glowSrc
            sourceSize.width: 64
            sourceSize.height: 64
            asynchronous: true
            visible: false
            onStatusChanged: if (status === Image.Ready) glowIn.restart()
        }
        // rendered at a quarter size and scaled up: the blur ends up four times wider for the same cost
        MultiEffect {
            id: glowFx
            readonly property real big: Math.max(amb.width, amb.height) * 1.6
            width: big / 4; height: width
            x: (amb.width - width) / 2
            y: (amb.height - height) / 2
            scale: 4 * glowDrift.zoom
            rotation: glowDrift.turn
            source: ambArt
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 32
            blur: 1.0
            saturation: 0.35
            brightness: w.dark ? -0.08 : 0.12
            // Liquid Glass shows the glass itself, like the Dock: no wash of the cover's colours over it (the other styles keep it)
            opacity: (w.glowWanted && ambArt.status === Image.Ready && w.style !== "liquid") ? w.glowT * w.glowAmt * (w.dark ? 0.85 : 0.7) : 0
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        }
        // the slow drift while music plays (Living artwork): a lazy turn and a gentle breathe
        QtObject {
            id: glowDrift
            property real turn: 0
            property real zoom: 1
        }
        NumberAnimation {
            target: glowDrift; property: "turn"; from: 0; to: 360; duration: 90000; loops: Animation.Infinite
            running: w.motion && w.playing && amb.visible && !w.editing
        }
        SequentialAnimation {
            loops: Animation.Infinite
            running: w.motion && w.playing && amb.visible && !w.editing
            NumberAnimation { target: glowDrift; property: "zoom"; to: 1.18; duration: 7000; easing.type: Easing.InOutSine }
            NumberAnimation { target: glowDrift; property: "zoom"; to: 1.0; duration: 7000; easing.type: Easing.InOutSine }
        }

        // ambient visualizer: crisp bars along the bottom of the card, in the room under the time labels (around the controls),
        // so they never run through the title, the progress bar or the times; small: beside the cover. Silent columns vanish
        // instead of leaving a row of dots, and both ends fade out.
        VisBars {
            id: ambVis
            x: w.ambL * w.k
            width: (w.ambR - w.ambL) * w.k
            y: w.ambT * w.k
            height: (w.ambB - w.ambT) * w.k
            soft: true
            src: w.visSrc
            active: w.visOn && w.visMode === "ambient" && w.hasPlayer && (w.playing || w.paused || w.preview) && !w.editing
            hold: !w.playing && !w.preview          // paused: frozen where the music stopped
            demo: w.preview
            style: w.visStyle
            gain: w.visGain
            count: w.isSmall ? Math.max(4, Math.round(w.visCount / 2)) : w.visCount
            barFill: w.visWidth
            readonly property color base: visual.base
            // faint, so the buttons in front of it stay easy to read
            colorTop: Qt.rgba(base.r, base.g, base.b, w.dark ? 0.34 : 0.28)
            colorBottom: Qt.rgba(base.r, base.g, base.b, 0.04)
        }
    }

    // --- audio visualizer: under the content, over the glass / face. Medium / large: a strip behind the control row, below the
    //    time labels. Small: a little equaliser to the right of the artwork, under the play button.
    VisBars {
        id: visual
        readonly property real sx0: (w.artX + w.artS + 14)                 // RU, small only
        // behind the controls row: the classic designs as before, the other shapes centred on their own row of controls
        x: (w.isSmall ? sx0 : (w.alt ? w.ctlL + 14 : w.mx)) * w.k
        width: (w.isSmall ? w.wr - w.mx - sx0 : (w.alt ? w.ctlR - w.ctlL - 28 : w.wr - 2 * w.mx)) * w.k
        y: (w.isSmall ? 77 : (w.alt ? w.ctlCY - 23 : w.hr - 58)) * w.k
        height: (w.isSmall ? w.artY + w.artS - 77 : 46) * w.k
        src: w.visSrc
        active: w.visOn && w.visMode === "strip" && w.hasPlayer && (w.playing || w.paused || w.preview) && !w.editing
        hold: !w.playing && !w.preview
        demo: w.preview
        style: w.visStyle
        gain: w.visGain
        count: w.isSmall ? 5 : w.visCount
        barFill: w.visWidth
        readonly property color base: (w.visColor === "accent" || w.accentUi) ? w.inkC
                                       : (w.visColor === "art" && w.faceTint ? Qt.hsla(w.tintH, Math.min(0.95, w.tintS * 1.15 + 0.2), w.dark ? 0.70 : 0.42, 1)
                                          : (w.dark ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)))
        colorTop: Qt.rgba(base.r, base.g, base.b, w.isSmall ? 0.55 : (w.dark ? 0.34 : 0.28))
        colorBottom: Qt.rgba(base.r, base.g, base.b, w.isSmall ? 0.12 : 0.03)
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
    // m:ss, or h:mm:ss once the track / video is an hour or longer (decided by its length, so elapsed and remaining match;
    // with no known length, by the value itself)
    function fmt(sec) {
        var s = Math.max(0, Math.floor(sec)), m = Math.floor(s / 60), ss = ("0" + (s % 60)).slice(-2);
        if (Math.max(length, sec) < 3600) return m + ":" + ss;
        return Math.floor(m / 60) + ":" + ("0" + (m % 60)).slice(-2) + ":" + ss;
    }
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    // while the bar is dragged (and a moment after, until the player reports the new position) show the dragged value
    property bool seeking: false
    property bool seekHold: false
    property real seekFrac: 0
    readonly property bool seekShown: seeking || seekHold
    readonly property real shownFrac: seekShown ? seekFrac : progress
    readonly property real shownPos: seekShown ? seekFrac * length : position
    Timer { id: seekHoldTimer; interval: 900; onTriggered: w.seekHold = false }
    // The player only reports its position about once a second, so the bar is glided between two reports (linear, same speed
    // as the song) instead of stepping. Seeks, pauses, a new song and dragging move it straight away.
    property real dispFrac: 0
    onShownFracChanged: {
        var d = shownFrac - dispFrac;
        if (playing && !seekShown && length > 0 && d > 0 && d * length < 2.5) {
            fracAnim.stop();
            fracAnim.from = dispFrac;
            fracAnim.to = shownFrac;
            fracAnim.duration = Math.max(120, Math.min(1100, d * length * 1000 * 1.05));
            fracAnim.start();
        } else {
            fracAnim.stop();
            dispFrac = shownFrac;
        }
    }
    onPlayingChanged: if (!playing) { fracAnim.stop(); dispFrac = shownFrac; }
    NumberAnimation { id: fracAnim; target: w; property: "dispFrac"; easing.type: Easing.Linear }
    // Browsers report the tab title: drop the unread-count prefix "(3) " and the site suffix " - YouTube" / " - Chromium"
    function cleanTitle(t) {
        return t.replace(/^\(\d+\)\s+/, "").replace(/\s+[-\u2013\u2014|]\s+(YouTube( Music)?|Chromium|Google Chrome|Brave|Mozilla Firefox|Firefox|Vivaldi|Opera|Microsoft Edge)$/, "");
    }
    // What is shown when the player gives little or nothing:
    //   no player at all        -> "No Music Playing" / "Open a music app", a plain white note (no tile)
    //   player open, no track   -> "Not Playing" / the player's name, its icon as artwork
    //   no artist and no album  -> the player's name under the title
    //   no cover                -> the player's icon on the placeholder tile
    readonly property bool hasTrack: hasPlayer && (title !== "" || artist !== "" || album !== "" || playing)
    readonly property string shownTitle: !hasPlayer ? I18n.tr("No Music Playing")
                                       : (title !== "" ? cleanTitle(title)
                                          : (hasTrack ? (artist !== "" ? artist : I18n.tr("Unknown Title")) : I18n.tr("Not Playing")))
    readonly property string shownSub: !hasPlayer ? I18n.tr("Open a music app")
                                     : (!hasTrack ? appName
                                        : ((title !== "" && artist !== "") ? (album !== "" ? artist + " \u2014 " + album : artist)
                                           : (title !== "" && album !== "" ? album : (title !== "" ? appName : album))))
    readonly property bool live: hasPlayer && playing && length <= 0         // a stream: no length, so no bar to fill




    // --- a new song: the title and artist slip out and the new ones slide in (instead of the text just changing) ---
    property string dispTitle: ""
    property string dispSub: ""
    property real txtT: 1                    // 0 = between two songs, 1 = shown
    function txtSwap() {
        if (dispTitle === shownTitle && dispSub === shownSub) return;
        if (preview || !visible) { dispTitle = shownTitle; dispSub = shownSub; return; }
        txtAnim.restart();
    }
    onShownTitleChanged: txtSwap()
    onShownSubChanged: txtSwap()
    SequentialAnimation {
        id: txtAnim
        NumberAnimation { target: w; property: "txtT"; to: 0; duration: 170; easing.type: Easing.InCubic }
        ScriptAction { script: { w.dispTitle = w.shownTitle; w.dispSub = w.shownSub; } }
        NumberAnimation { target: w; property: "txtT"; to: 1; duration: 420; easing.type: Easing.OutCubic }
    }
    readonly property real textVis: 1
    // Living artwork: the cover sinks back a little while paused and springs forward when the music starts
    readonly property real artRest: (motion && hasPlayer && !playing && !preview) ? 0.88 : 1
    property real artB: artRest
    Behavior on artB { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

    // --- layout numbers (RU), per size ---
    readonly property real mx: 23                                     // side margin
    readonly property real artX: isLarge ? (wr - artS) / 2 : w.mx
    readonly property real artY: 23
    readonly property real artS: isSmall ? 110 : (isMedium ? hr - 142 : (alt ? (isTall ? wr - 2 * mx : hr - 46) : Math.min(hr - 218, wr - 2 * mx)))
    // strip / hero: the column right of the cover
    readonly property real sideX: artX + artS + (isHero ? 40 : 26)
    readonly property real textX: isSmall || isTall ? w.mx : ((isMedium || alt) ? (isMedium ? w.mx + artS + 18 : sideX) : w.mx)
    // right edge of the title / subtitle
    // (scrolling text fades out within the card's margins, the same distance from either edge)
    readonly property real textR: isStrip ? textX + Math.min(330, wr * 0.3) : (isHero ? wr - mx - 50 : wr - (mx - mqPad) - (isMedium ? 50 : 0))
    // room left of the text where scrolling text fades out: beside the cover (medium) it stays clear of the art
    readonly property real mqPad: (isMedium || isStrip || isHero) ? 4 : 12
    // tall: the title block sits half way between the cover and the progress bar
    readonly property real tallMid: (artY + artS + barCY) / 2
    readonly property real titleCY: isSmall ? hr - 60 : isMedium ? artY + artS / 2 - 16 : isTall ? tallMid - 15
                                  : isStrip ? hr / 2 - 16 : isHero ? 112 : hr - 165
    readonly property real subCY: isSmall ? hr - 31 : isMedium ? artY + artS / 2 + 16 : isTall ? tallMid + 15
                                : isStrip ? hr / 2 + 16 : isHero ? 160 : hr - 137.5
    readonly property real barCY: isTall ? hr - 118 : isStrip ? hr / 2 + 40 : isHero ? hr - 150 : hr - 95.5
    readonly property real timeCY: isTall ? hr - 98 : isStrip ? hr / 2 + 60 : isHero ? hr - 128 : hr - 75.2
    readonly property real ctlCY: isTall ? hr - 50 : isStrip ? hr / 2 - 26 : isHero ? hr - 62 : hr - 44
    // the progress bar and the controls row: from / to (RU); the controls keep shuffle and repeat at their ends unless narrow
    readonly property real barL: isStrip ? textR + 34 : (isHero ? sideX : mx)
    readonly property real barR: wr - mx
    readonly property real ctlL: isStrip ? textR + 10 : (isHero ? sideX - 25 : 0)
    readonly property real ctlR: isStrip ? wr - 50 : wr
    readonly property bool ctlSides: !isTall
    // the ambient visualizer's room (RU): under the time labels down to the bottom edge, right of the cover where the cover
    // reaches that low (strip / hero); small (no times): beside the cover, under the play button
    readonly property real ambT: isSmall ? 77 : timeCY + 12
    readonly property real ambB: isSmall ? artY + artS : hr
    readonly property real ambL: isSmall ? artX + artS + 14 : (isStrip ? barL - 12 : (isHero ? sideX - 25 : 0))
    readonly property real ambR: isSmall ? wr - mx : wr
    readonly property real titlePx: isSmall ? 21 : isTall ? 20 : isHero ? 36 : 24
    readonly property real subPx: isSmall ? 18 : isTall ? 17 : isHero ? 24 : 21

    // the contents (artwork, title, controls) fill the card edge to edge
    Item {
        id: content
        anchors.fill: parent

        // --- artwork: a soft shadow in the cover's own colour lifts it off the card ---
        RectangularShadow {
            x: artItem.x; y: artItem.y + 7 * w.k * w.artB
            width: artItem.width; height: artItem.height
            radius: artItem.r
            blur: 28 * w.k
            spread: -2 * w.k
            color: w.faceTint ? Qt.hsla(w.tintH, Math.min(0.75, w.tintS), w.dark ? 0.06 : 0.25, 0.75) : Qt.rgba(0, 0, 0, w.dark ? 0.55 : 0.28)
            opacity: artItem.bare ? 0 : artItem.opacity * (w.hasPlayer ? 0.55 + 3.5 * (w.artB - 0.88) : 0.35)
            transform: Scale { origin.x: artItem.width / 2; origin.y: artItem.height / 2; xScale: w.artB; yScale: w.artB }
        }
        PlayerArt {
            id: artItem
            transform: Scale { origin.x: artItem.width / 2; origin.y: artItem.height / 2; xScale: w.artB; yScale: w.artB }
            wd: w
            x: w.artX * w.k
            y: w.artY * w.k
            width: w.artS * w.k
            height: width
            r: (w.isLarge ? 11 : (w.isSmall ? 11 : 12)) * w.k
        }

        // click the artwork: bring the player (browser tab, Spotify, ...) to the front
        MouseArea {
            x: artItem.x; y: artItem.y; width: artItem.width; height: artItem.height
            enabled: w.hasPlayer && !w.preview && !w.editing
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: w.raiseRequested()
        }

        // --- title: scrolls like the subtitle when it does not fit ---
        MarqueeText {
            id: titleItem
            x: (w.textX - w.mqPad) * w.k
            y: w.titleCY * w.k - height / 2 + (1 - w.txtT) * 10 * w.k
            width: (w.textR - (w.textX - w.mqPad)) * w.k
            opacity: w.textVis * w.txtT
            visible: opacity > 0
            layer.enabled: opacity > 0 && opacity < 0.999
            layer.sourceRect: Qt.rect(-12, -8, width + 24, height + 16)
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: Math.min(1, (1 - titleItem.opacity) * 0.9) }
            text: w.dispTitle
            color: w.fg
            fam: Fonts.forWeight(Font.DemiBold, w.fam)
            pixelSize: w.titlePx * w.k
            weight: Font.DemiBold
            fade: (w.mqPad < 10 ? 14 : 20) * w.k
            startPad: w.mqPad * w.k
            animate: !w.preview && w.playing
        }

        // --- subtitle: artist - album, scrolling when it does not fit ---
        MarqueeText {
            id: subItem
            x: (w.textX - w.mqPad) * w.k
            y: w.subCY * w.k - height / 2 + (1 - w.txtT) * 14 * w.k
            width: (w.textR - (w.textX - w.mqPad)) * w.k
            opacity: w.textVis * w.txtT
            visible: opacity > 0
            layer.enabled: opacity > 0 && opacity < 0.999
            layer.sourceRect: Qt.rect(-12, -8, width + 24, height + 16)
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: Math.min(1, (1 - subItem.opacity) * 0.9) }
            text: w.dispSub
            color: w.fg2
            fam: w.fam
            pixelSize: w.subPx * w.k
            weight: Font.Medium
            fade: (w.mqPad < 10 ? 14 : 20) * w.k
            startPad: w.mqPad * w.k
            animate: !w.preview && w.playing
        }

        // --- hero: a small "Now Playing" heading over the title, with the player's name ---
        Text {
            visible: w.isHero && w.hasPlayer
            x: w.textX * w.k
            y: 52 * w.k
            opacity: w.textVis
            text: I18n.tr("Now Playing").toUpperCase() + (w.appName !== "" ? "  ·  " + w.appName.toUpperCase() : "")
            color: w.fgDim
            font.family: Fonts.forWeight(Font.Bold, w.fam)
            font.pixelSize: 13 * w.k
            font.weight: Font.Bold
            font.letterSpacing: 1.2 * w.k
        }

        // --- small: play / pause at the top right ---
        PlayerBtn {
            visible: w.isSmall
            wd: w
            x: (w.wr - w.mx - 46) * w.k
            y: 23 * w.k
            width: 46 * w.k
            height: width
            kind: w.playing ? "pause" : "play"
            col: w.fgBtn
            gw: 22 * w.k
            gh: 26 * w.k
            on: true
            onClicked: w.togglePlaying()
        }

        // --- progress bar: click or drag to seek ---
        Rectangle {
            id: bar
            visible: !w.isSmall && opacity > 0
            opacity: w.textVis
            layer.enabled: opacity > 0 && opacity < 0.999
            layer.sourceRect: Qt.rect(-12, -16, width + 24, height + 32)
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: Math.min(1, (1 - bar.opacity) * 0.9) }
            x: w.barL * w.k
            y: w.barCY * w.k - height / 2
            width: (w.barR - w.barL) * w.k
            readonly property bool hot: seekMa.pressed || seekMa.containsMouse
            height: (w.barStyle === "bold" ? (hot ? 14 : 10) : (hot ? 10 : 6)) * w.k
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
            radius: height / 2
            color: w.trackCol
            // a soft glow of the played part, so the bar reads as lit rather than painted
            RectangularShadow {
                anchors.fill: barFill
                radius: barFill.radius
                blur: 10 * w.k
                color: barFill.color
                opacity: w.hasPlayer && w.length > 0 ? (w.playing ? 0.55 : 0.25) : 0
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }
            Rectangle {
                id: barFill
                width: w.hasPlayer && w.length > 0 ? Math.max(parent.height, parent.width * w.dispFrac) : (w.live ? parent.width : 0)
                opacity: w.live ? 0.35 : 1
                height: parent.height
                radius: height / 2
                color: bar.hot ? w.ia(w.dark ? 0.86 : 0.70) : w.fillCol
                Behavior on color { ColorAnimation { duration: 160 } }
            }
            // the knob: grows in at the end of the played part while the bar is hovered or dragged
            Rectangle {
                readonly property real d: bar.height + 8 * w.k
                width: d; height: d; radius: d / 2
                x: Math.max(0, Math.min(bar.width, barFill.width)) - d / 2
                anchors.verticalCenter: parent.verticalCenter
                color: w.dark ? "#FFFFFF" : "#2A2A2E"
                visible: w.hasPlayer && w.length > 0 && scale > 0.01
                scale: bar.hot ? (seekMa.pressed ? 1.15 : 1) : 0
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                layer.enabled: visible
                layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.5; shadowOpacity: 0.35; shadowVerticalOffset: 1 }
            }
            MouseArea {
                id: seekMa
                anchors.fill: parent
                anchors.topMargin: -14 * w.k          // taller touch area than the thin bar
                anchors.bottomMargin: -14 * w.k
                hoverEnabled: true
                preventStealing: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: !w.preview && !w.editing && w.hasPlayer && w.canSeek && w.length > 0
                function frac(mx) { return Math.max(0, Math.min(1, mapToItem(bar, mx, 0).x / bar.width)); }
                onPressed: mouse => { seekHoldTimer.stop(); w.seekHold = false; w.seekFrac = frac(mouse.x); w.seeking = true; }
                onPositionChanged: mouse => { if (pressed) w.seekFrac = frac(mouse.x); }
                onReleased: {
                    w.seeking = false;
                    w.seekHold = true;
                    seekHoldTimer.restart();
                    w.seek(w.seekFrac * w.length);
                }
                onCanceled: w.seeking = false
            }
        }
        Text {
            id: timeL
            visible: !w.isSmall
            x: w.barL * w.k
            y: w.timeCY * w.k - height / 2
            height: 18 * w.k
            verticalAlignment: Text.AlignVCenter
            text: (w.hasPlayer && (w.length > 0 || w.shownPos >= 1)) ? w.fmt(w.shownPos) : ""
            color: w.fg2
            font.family: w.fam
            font.pixelSize: 13 * w.k
            font.weight: Font.Medium
        }
        Text {
            id: timeR
            visible: !w.isSmall && (w.length > 0 || w.live)
            x: w.barR * w.k - width
            y: w.timeCY * w.k - height / 2
            height: 18 * w.k
            verticalAlignment: Text.AlignVCenter
            text: w.live ? "LIVE" : "\u2212" + w.fmt(Math.max(0, w.length - w.shownPos))
            color: w.fg2
            font.family: w.fam
            font.pixelSize: 13 * w.k
            font.weight: Font.Medium
        }

        // --- controls: shuffle · back · play · forward · repeat ---
        PlayerBtn {
            visible: !w.isSmall && w.ctlSides
            wd: w
            x: (w.ctlL + 25) * w.k
            y: w.ctlCY * w.k - height / 2
            width: 44 * w.k
            height: width
            kind: "shuffle"
            col: w.shuffle ? w.fgBtn : w.fgDim
            gw: 26 * w.k
            gh: 21 * w.k
            on: w.shuffle
            enabledBtn: w.canShuffle
            onClicked: w.toggleShuffle()
        }
        PlayerBtn {
            visible: !w.isSmall
            wd: w
            x: (w.ctlL + (w.ctlSides ? 0.30 : 0.2) * (w.ctlR - w.ctlL)) * w.k - width / 2
            y: w.ctlCY * w.k - height / 2
            width: 56 * w.k
            height: 44 * w.k
            kind: "prev"
            col: w.fgBtn
            gw: 44 * w.k
            gh: 25 * w.k
            onClicked: w.previousTrack()
        }
        PlayerBtn {
            visible: !w.isSmall
            wd: w
            x: (w.ctlL + 0.50 * (w.ctlR - w.ctlL)) * w.k - width / 2
            y: w.ctlCY * w.k - height / 2
            width: 56 * w.k
            height: 52 * w.k
            kind: w.playing ? "pause" : "play"
            col: w.ia(w.dark ? 0.84 : 0.78)
            gw: (w.playing ? 30 : 32) * w.k
            gh: 38 * w.k
            onClicked: w.togglePlaying()
        }
        PlayerBtn {
            visible: !w.isSmall
            wd: w
            x: (w.ctlL + (w.ctlSides ? 0.70 : 0.8) * (w.ctlR - w.ctlL)) * w.k - width / 2
            y: w.ctlCY * w.k - height / 2
            width: 56 * w.k
            height: 44 * w.k
            kind: "next"
            col: w.fgBtn
            gw: 44 * w.k
            gh: 25 * w.k
            onClicked: w.nextTrack()
        }
        PlayerBtn {
            visible: !w.isSmall && w.ctlSides
            wd: w
            x: (w.ctlR - 25 - 44) * w.k
            y: w.ctlCY * w.k - height / 2
            width: 44 * w.k
            height: width
            kind: "repeat"
            col: w.loop > 0 ? w.fgBtn : w.fgDim
            gw: 26 * w.k
            gh: 22 * w.k
            on: w.loop > 0
            badge: w.loop === 1 ? "1" : ""
            enabledBtn: w.canLoop
            onClicked: w.cycleLoop()
        }
    }
}
