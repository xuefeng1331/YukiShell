import QtQuick
import QtMultimedia
import YukiVideo

Item {
    id: wp
    required property var host
    readonly property string video: host.glassVideo
    readonly property bool wanted: video !== "" && WallFeed.watching > 0
    readonly property bool held: video !== "" && WallFeed.holding > 0
    property bool active: false
    readonly property real born: Date.now()

    function update() {
        if (wanted) {
            stopT.stop();
            if (!active && !startT.running) {
                startT.interval = Math.max(1, born + 3000 - Date.now());
                startT.restart();
            }
        } else {
            startT.stop();
            if (active) { stopT.interval = held ? 60000 : 30000; stopT.restart(); }
        }
    }
    onWantedChanged: update()
    onHeldChanged: update()
    onVideoChanged: { active = false; WallFeed.clear(); update(); }
    Component.onCompleted: update()
    Timer { id: startT; onTriggered: wp.active = wp.wanted }
    Timer { id: stopT; onTriggered: { wp.active = false; WallFeed.clear(); } }

    Loader {
        active: wp.active && wp.video !== ""
        sourceComponent: Item {
            id: box
            readonly property bool hold: !wp.wanted
            onHoldChanged: { if (hold) mp.pause(); else { mp.play(); syncT.restart(); } }
            MediaPlayer {
                id: mp
                source: "file://" + wp.video
                loops: MediaPlayer.Infinite
                videoOutput: WallFeed.sink
                Component.onCompleted: play()
                onMediaStatusChanged: { if (mediaStatus === MediaPlayer.BufferedMedia || mediaStatus === MediaPlayer.LoadedMedia) syncT.restart(); }
            }
            property real lead: 40
            property real lastSeek: 0
            function clockMs() {
                var c = wp.host.wallClock;
                if (!c || !c.ok || Date.now() - c.at > 2500 || mp.duration <= 0) return -1;
                return ((c.pos * 1000 + (Date.now() - c.at)) % mp.duration + mp.duration) % mp.duration;
            }
            function resync() {
                if (box.hold || mp.playbackState !== MediaPlayer.PlayingState || !mp.seekable) return;
                var want = clockMs();
                if (want < 0) return;
                var d = mp.position - want;
                if (d > mp.duration / 2) d -= mp.duration; else if (d < -mp.duration / 2) d += mp.duration;
                if (box.lastSeek > 0 && Date.now() - box.lastSeek < 4000) box.lead = Math.max(0, Math.min(400, box.lead - d * 0.7));
                if (Math.abs(d) <= 50) return;
                box.lastSeek = Date.now();
                mp.position = (want + box.lead) % mp.duration;
            }
            Timer {
                id: syncT
                interval: 1500
                repeat: true
                running: !box.hold
                onTriggered: box.resync()
            }
        }
    }
}
