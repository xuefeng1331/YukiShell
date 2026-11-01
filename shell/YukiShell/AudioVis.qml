import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: av

    readonly property int count: 128
    property var bars: av.zeros()
    property bool available: true
    readonly property bool wanted: nwant > 0

    function zeros() { var z = []; for (var i = 0; i < av.count; i++) z.push(0); return z; }

    property var wanters: ({})
    property int nwant: 0
    function want(key, on) {
        var had = av.wanters[key] === true;
        if (on === had) return;
        if (on) av.wanters[key] = true; else delete av.wanters[key];
        av.nwant = Object.keys(av.wanters).length;
    }

    property string lastLine: ""
    function feed(line) {
        if (line === av.lastLine) return;
        av.lastLine = line;
        var p = line.split(";"), out = [], n = Math.min(av.count, p.length);
        for (var i = 0; i < av.count; i++) {
            var v = i < n ? parseInt(p[i]) : 0;
            out.push(isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 100)));
        }
        av.fails = 0;
        av.bars = out;
    }

    property int fails: 0
    Process {
        id: check
        running: true
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector { onStreamFinished: av.available = text.indexOf("yes") >= 0 }
    }
    Timer { id: retry; interval: 4000 }
    // cava takes a moment to start and reach PipeWire: keep it a while after the last user lets go (a pause), so resuming is instant
    Timer { id: linger; interval: 120000 }
    onWantedChanged: if (wanted) linger.stop(); else linger.restart()
    OwnedProcess {
        id: cava
        running: (av.wanted || linger.running) && av.available && !retry.running
        cmd: ["sh", "-c",
            "cfg=\"${XDG_RUNTIME_DIR:-/tmp}/yukishell-cava.conf\"; "
            + "printf '%s\\n' '[general]' \"bars = $1\" 'framerate = 60' '[input]' 'method = pipewire' '[output]' 'method = raw' 'channels = mono' 'mono_option = average' "
            + "'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'bar_delimiter = 59' 'frame_delimiter = 10' '[smoothing]' 'noise_reduction = 25' > \"$cfg\"; "
            + "exec cava -p \"$cfg\"", "sh", String(av.count)]
        stdout: SplitParser { onRead: line => av.feed(line) }
        onExited: {
            av.bars = av.zeros();
            av.lastLine = "";
            if (!av.wanted) return;
            if (++av.fails >= 4) av.available = false;
            else retry.restart();
        }
    }
}
