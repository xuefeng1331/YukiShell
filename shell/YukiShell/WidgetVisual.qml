import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "I18n.js" as I18n

Item {
    id: v
    required property var host

    property string wtype: "weather"
    property string wstyle: "liquid"
    property string wsize: "small"
    property string wmode: "auto"
    property string wsrc: ""
    property string wlay: wsize
    property real sx: 0
    property real sy: 0
    property string sname: ""
    property real sw: 1920
    property real sh: 1080
    readonly property real fit: {
        if (width <= 0 || height <= 0 || !host || !host.dims) return 1;
        var d = host.dims(wsize);
        return Math.max(0.5, Math.min(width / d[0], height / d[1]));
    }
    property Item wallItem: null
        Component {
            id: weatherVisual
            WeatherWidget {
                accentTint: host.accentTintVec
                scaleF: host.widgetScale
                style: wstyle
                fit: v.fit
                lay: v.wlay
                size: wsize
                fam: host.fontFamily
                screenX: v.sx; screenY: v.sy
                city: host.wxCity
                located: host.wxLocated
                hasData: host.wxReady
                temp: host.wxTemp
                hi: host.wxHi
                lo: host.wxLo
                cond: host.wxReady ? host.wxInfo.t : (host.wxError !== "" ? I18n.tr("Unavailable") : I18n.tr("Loading…"))
                kind: host.wxReady ? host.wxInfo.k : "cloud"
                isDay: host.wxDay
                hourly: host.wxHourly
                daily: host.wxDaily
                glassReady: host.glassState === "ready" && (!host.hub || host.hub.wallpaperReady)
                shaderUrl: "file://" + host.glassShaderOut
                wallUrl: host.fileUrl(host.wallpaperFor(v.sname))
                wallVideo: host.liveWallVideo
                wallItem: v.wallItem
                wallPaused: host.liveWallPaused
                screenW: v.sw
                screenH: v.sh
                glassOpacity: host.glassOpacity
                glassBlur: host.glassBlur
                glassLiquid: host.glassLiquid
                glassRim: host.glassRim
                borderTint: host.borderTint
                glassGrain: host.glassGrain
                darkGlass: host.darkGlass
                editing: host.editing
                onGlassFailed: host.glassState = "failed"
            }
        }
        Component {
            id: calendarVisual
            CalendarWidget {
                accentTint: host.accentTintVec
                scaleF: host.widgetScale
                style: wstyle
                fit: v.fit
                lay: v.wlay
                size: wsize
                mode: wmode
                fam: host.fontFamily
                screenX: v.sx; screenY: v.sy
                weekStart: 0
                glassReady: host.glassState === "ready" && (!host.hub || host.hub.wallpaperReady)
                shaderUrl: "file://" + host.glassShaderOut
                wallUrl: host.fileUrl(host.wallpaperFor(v.sname))
                wallVideo: host.liveWallVideo
                wallItem: v.wallItem
                wallPaused: host.liveWallPaused
                screenW: v.sw
                screenH: v.sh
                glassOpacity: host.glassOpacity
                glassBlur: host.glassBlur
                glassLiquid: host.glassLiquid
                glassRim: host.glassRim
                borderTint: host.borderTint
                glassGrain: host.glassGrain
                darkGlass: host.darkGlass
                editing: host.editing
                onGlassFailed: host.glassState = "failed"
            }
        }
        Component {
            id: clockVisual
            ClockWidget {
                accentTint: host.accentTintVec
                cityCode: host.cityCode
                use24h: host.hub && host.hub.bar ? host.hub.bar.use24h === true : false
                scaleF: host.widgetScale
                style: wstyle
                lay: v.wlay
                size: wsize
                fam: host.fontFamily
                boldFam: host.boldFontFamily
                screenX: v.sx; screenY: v.sy
                glassReady: host.glassState === "ready" && (!host.hub || host.hub.wallpaperReady)
                shaderUrl: "file://" + host.glassShaderOut
                wallUrl: host.fileUrl(host.wallpaperFor(v.sname))
                wallVideo: host.liveWallVideo
                wallItem: v.wallItem
                wallPaused: host.liveWallPaused
                screenW: v.sw
                screenH: v.sh
                glassOpacity: host.glassOpacity
                glassBlur: host.glassBlur
                glassLiquid: host.glassLiquid
                glassRim: host.glassRim
                borderTint: host.borderTint
                glassGrain: host.glassGrain
                darkGlass: host.darkGlass
                preview: false
                editing: host.editing
                onGlassFailed: host.glassState = "failed"
            }
        }
        Component {
            id: playerVisual
            PlayerWidget {
                accentTint: host.accentTintVec
                scaleF: host.widgetScale
                style: wstyle
                lay: v.wlay
                size: wsize
                contentScale: host.playerScale
                fam: host.fontFamily
                screenX: v.sx; screenY: v.sy
                hasPlayer: host.player !== null
                title: host.player ? host.player.trackTitle : ""
                artist: host.player ? host.player.trackArtist : ""
                album: host.player ? host.player.trackAlbum : ""
                artUrl: host.player ? host.player.trackArtUrl : ""
                appName: host.player ? host.player.identity : ""
                playing: host.player ? host.player.isPlaying : false
                paused: host.player ? host.player.playbackState === MprisPlaybackState.Paused : false
                shuffle: (host.player && host.player.shuffleSupported) ? host.player.shuffle : false
                canShuffle: host.player !== null && host.player.shuffleSupported
                loop: (host.player && host.player.loopSupported)
                      ? (host.player.loopState === MprisLoopState.Track ? 1 : (host.player.loopState === MprisLoopState.Playlist ? 2 : 0)) : 0
                canLoop: host.player !== null && host.player.loopSupported
                position: (host.player && host.player.positionSupported) ? host.player.position : 0
                length: (host.player && host.player.lengthSupported) ? host.player.length : 0
                canSeek: host.player !== null && host.player.canSeek && host.player.positionSupported && host.player.lengthSupported
                visSrc: host.visSrc
                visOn: host.visOn
                visStyle: host.visStyle
                visColor: host.visColor
                visGain: host.visGain
                visCount: host.visCount
                visWidth: host.visWidth
                visAccent: host.visAccent
                glowAmt: host.mwGlow
                motion: host.mwMotion
                barStyle: host.mwBar
                visMode: host.mwVisMode
                glassReady: host.glassState === "ready" && (!host.hub || host.hub.wallpaperReady)
                shaderUrl: "file://" + host.glassShaderOut
                wallUrl: host.fileUrl(host.wallpaperFor(v.sname))
                wallVideo: host.liveWallVideo
                wallItem: v.wallItem
                wallPaused: host.liveWallPaused
                screenW: v.sw
                screenH: v.sh
                glassOpacity: host.glassOpacity
                glassBlur: host.glassBlur
                glassLiquid: host.glassLiquid
                glassRim: host.glassRim
                borderTint: host.borderTint
                glassGrain: host.glassGrain
                darkGlass: host.darkGlass
                editing: host.editing
                onSeek: seconds => { if (host.player && host.player.canSeek) host.player.position = seconds; }
                onRaiseRequested: { if (host.player && host.player.canRaise) host.player.raise(); }
                onTogglePlaying: { if (host.player && host.player.canTogglePlaying) host.player.togglePlaying(); }
                onNextTrack: { if (host.player && host.player.canGoNext) host.player.next(); }
                onPreviousTrack: { if (host.player && host.player.canGoPrevious) host.player.previous(); }
                onToggleShuffle: { if (host.player && host.player.shuffleSupported) host.player.shuffle = !host.player.shuffle; }
                onCycleLoop: {
                    if (!host.player || !host.player.loopSupported) return;
                    var ls = host.player.loopState;
                    host.player.loopState = ls === MprisLoopState.None ? MprisLoopState.Playlist
                                          : (ls === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
                }
                onGlassFailed: host.glassState = "failed"
            }
        }
        Component {
            id: imageVisual
            ImageWidget {
                size: wsize
                borderTint: host.borderTint
                scaleF: host.widgetScale
                fam: host.fontFamily
                screenX: v.sx; screenY: v.sy
                source: host.fileUrl(v.wsrc)
                darkGlass: host.darkGlass
                editing: host.editing
            }
        }
        Loader {
            id: visual
            anchors.fill: parent
            sourceComponent: wtype === "calendar" ? calendarVisual
                           : (wtype === "clock" ? clockVisual
                           : (wtype === "player" ? playerVisual
                           : (wtype === "image" ? imageVisual : weatherVisual)))
        }
}
