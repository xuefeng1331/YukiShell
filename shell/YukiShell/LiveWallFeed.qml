import QtQuick
import QtMultimedia
import YukiVideo

Item {
    id: f
    required property Item lw
    readonly property string key: "lw" + Math.floor(Math.random() * 1e9) + "-" + Date.now()
    readonly property bool playing: lw.wanted
    property bool got: false

    Component.onCompleted: WallFeed.want(key, playing)
    Component.onDestruction: { WallFeed.release(key); if (f.lw) f.lw.showing = false; }

    VideoOutput {
        id: vo
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: f.got
        onVisibleChanged: if (f.lw) f.lw.showing = visible
    }
    WallFeedOutput {
        target: vo.videoSink
        enabled: f.playing || !f.got
    }
    Connections {
        target: vo.videoSink
        function onVideoFrameChanged() { f.got = true; f.lw.newFrame(); }
    }
}
