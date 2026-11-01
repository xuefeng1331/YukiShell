import QtQuick

ShaderEffectSource {
    id: ws
    property Item wall: null
    property real sx: 0
    property real sy: 0
    sourceItem: wall
    sourceRect: Qt.rect(sx, sy, width, height)
    live: false
    Connections {
        target: ws.wall
        function onNewFrame() { ws.scheduleUpdate(); }
    }
    onWallChanged: scheduleUpdate()
    onSxChanged: scheduleUpdate()
    onSyChanged: scheduleUpdate()
    onWidthChanged: scheduleUpdate()
    onHeightChanged: scheduleUpdate()
    hideSource: false
    visible: false
    readonly property bool ready: wall !== null && wall.showing
}
