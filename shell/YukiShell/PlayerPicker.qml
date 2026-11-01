import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Scope {
    id: pk

    property string lastPlayed: ""

    function isWallpaper(p) {
        var u = "";
        try { u = String((p.metadata && p.metadata["xesam:url"]) || ""); } catch (e) { }
        return u.indexOf("/.cache/yukishell/") >= 0 || p.identity === "mpvpaper";
    }
    function score(p) {
        var s = 0;
        if (p.isPlaying) s += 100;
        if (p.trackArtUrl !== "") s += 8;
        if (p.trackArtist !== "") s += 4;
        if (p.trackTitle !== "") s += 2;
        if (p.lengthSupported && p.length > 0) s += 1;
        if (p.dbusName === lastPlayed) s += 6;
        return s;
    }

    readonly property var player: {
        var ps = Mpris.players.values, best = null, bs = -1;
        for (var i = 0; i < ps.length; i++) {
            if (ps[i].dbusName === "org.mpris.MediaPlayer2.playerctld" || isWallpaper(ps[i])) continue;
            var s = score(ps[i]);
            if (s > bs) { bs = s; best = ps[i]; }
        }
        return best;
    }

    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            id: watch
            required property var modelData
            readonly property bool playing: modelData.isPlaying
            onPlayingChanged: if (playing) pk.lastPlayed = modelData.dbusName
            Component.onCompleted: if (playing && pk.lastPlayed === "") pk.lastPlayed = modelData.dbusName
        }
    }
}
