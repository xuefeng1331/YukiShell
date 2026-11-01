import QtQuick

Item {
    id: m

    property string text: ""
    property color color: "white"
    property string fam: "Open Runde"
    property real pixelSize: 16
    property int weight: Font.Medium
    property real fade: 18
    property real startPad: 0
    property real speed: 34
    property bool animate: true

    height: Math.ceil(pixelSize * 1.3)
    readonly property real gap: pixelSize * 3
    readonly property bool overflow: probe.implicitWidth > width - startPad
    property real scrollX: 0

    Text {
        id: probe
        visible: false
        text: m.text
        font.family: m.fam
        font.pixelSize: m.pixelSize
        font.weight: m.weight
    }

    Item {
        id: strip
        anchors.fill: parent
        visible: false
        clip: true
        layer.enabled: true
        Row {
            x: m.startPad + m.scrollX
            spacing: m.gap
            Text {
                text: m.text
                color: m.color
                height: strip.height
                verticalAlignment: Text.AlignVCenter
                font.family: m.fam
                font.pixelSize: m.pixelSize
                font.weight: m.weight
            }
            Text {
                visible: m.overflow
                text: m.text
                color: m.color
                height: strip.height
                verticalAlignment: Text.AlignVCenter
                font.family: m.fam
                font.pixelSize: m.pixelSize
                font.weight: m.weight
            }
        }
    }

    ShaderEffect {
        anchors.fill: parent
        readonly property Item source: strip
        readonly property real fadeLeft: m.overflow ? Math.min(0.45, m.fade / Math.max(1, m.width)) : 0
        readonly property real fadeRight: m.overflow ? Math.min(0.45, m.fade / Math.max(1, m.width)) : 0
        fragmentShader: Qt.resolvedUrl("hfade.frag.qsb")
    }

    onTextChanged: scrollX = 0
    SequentialAnimation {
        running: m.overflow && m.animate && m.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running) m.scrollX = 0
        PauseAnimation { duration: 2400 }
        NumberAnimation {
            target: m
            property: "scrollX"
            from: 0
            to: -(probe.implicitWidth + m.gap)
            duration: Math.max(1, (probe.implicitWidth + m.gap) / m.speed * 1000)
            easing.type: Easing.Linear
        }
    }
}
