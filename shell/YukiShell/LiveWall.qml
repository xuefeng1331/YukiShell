import QtQuick
import QtMultimedia

Item {
    id: lw
    property string video: ""
    property bool live: false
    property bool paused: false
    property var clock: null
    property int startDelay: -1
    signal newFrame()
    property bool showing: false
    readonly property bool available: live && video !== ""
    readonly property bool wanted: available && !paused
    property bool active: false
    readonly property real born: Date.now()
    function startSoon() {
        var d = startDelay >= 0 ? Math.max(1, startDelay) : Math.max(300 + Math.random() * 4700, born + 3000 - Date.now());
        startT.interval = d;
        startT.restart();
    }
    Component.onCompleted: if (wanted) startSoon()
    onWantedChanged: {
        if (wanted) {
            stopT.stop();
            if (!active) startSoon();
        } else if (active) {
            startT.stop();
            if (!available) active = false;
            else { stopT.interval = 30000 + Math.random() * 30000; stopT.restart(); }
        }
    }
    Timer { id: stopT; onTriggered: lw.active = false }
    Timer { id: startT; onTriggered: lw.active = lw.wanted }

    readonly property bool shared: feed.status !== Loader.Error
    Loader {
        id: feed
        anchors.fill: parent
        active: lw.available
        Component.onCompleted: setSource(Qt.resolvedUrl("LiveWallFeed.qml"), { lw: lw })
    }

    Loader {
        anchors.fill: parent
        active: lw.active && !lw.shared
        sourceComponent: Item {
            id: box
            readonly property bool hold: lw.paused
            onHoldChanged: { if (hold) mp.pause(); else { mp.play(); syncT.restart(); } }
            MediaPlayer {
                id: mp
                source: "file://" + lw.video
                loops: MediaPlayer.Infinite
                videoOutput: vo
                Component.onCompleted: play()
                onMediaStatusChanged: { if (mediaStatus === MediaPlayer.BufferedMedia || mediaStatus === MediaPlayer.LoadedMedia) syncT.restart(); }
            }
            property real lead: 40
            property real lastSeek: 0
            function clockMs() {
                var c = lw.clock;
                if (!c || !c.ok || Date.now() - c.at > 2500 || mp.duration <= 0) return -1;
                return ((c.pos * 1000 + (Date.now() - c.at)) % mp.duration + mp.duration) % mp.duration;
            }
            function resync() {
                if (lw.paused || mp.playbackState !== MediaPlayer.PlayingState || !mp.seekable) return;
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
                running: !!lw.clock && !lw.paused
                onTriggered: box.resync()
            }
            VideoOutput {
                id: vo
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                visible: mp.playbackState !== MediaPlayer.StoppedState && mp.hasVideo
                onVisibleChanged: lw.showing = visible
                Component.onDestruction: lw.showing = false
            }
            Connections {
                target: vo.videoSink
                function onVideoFrameChanged() { lw.newFrame(); }
            }
        }
    }
}
