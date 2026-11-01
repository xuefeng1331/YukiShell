import QtQuick
import Quickshell.Io

Process {
    id: op
    property var cmd: []
    command: (op.cmd && op.cmd.length) ? ["setpriv", "--pdeathsig", "TERM", "--"].concat(op.cmd) : []
    Component.onDestruction: if (op.running) op.signal(15)
}
