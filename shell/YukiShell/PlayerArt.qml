import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: art
    required property var wd
    property real r: 7
    // no player, or a track without a cover: just the note, no tile, rim, border or shadow
    readonly property bool bare: !wd.preview && (!wd.hasPlayer || String(wd.artSrc) === "" || artImg.status === Image.Error)

    property color idleBgTop: "#3b3b40"
    property color idleBgBottom: "#27272b"
    property color noteTop: "#e9e9ed"
    property color noteBottom: "#e0e0e5"
    property real noteScale: 0.62
    readonly property real noteSc: bare ? 1.18 : noteScale
    property real dropOpacity: 0.28
    property real dropBlur: 0.24
    property real dropDown: 4
    property real rimOpacity: 0.42
    property real rimBlur: 0.2
    readonly property string notePath: "M 389.5 142.3 C 387.3 141.2 385.8 139.9 383.2 139.8 C 374.9 139.5 365.7 142.6 357.6 144.3 C 337.1 148.4 316.5 152.6 295.9 156.6 C 282.5 159.3 205.3 172.8 199.7 178.1 C 192.7 184.9 195.2 209.5 195.3 219.1 C 195.5 259.1 195.2 299.1 195.2 339.1 C 195.3 359.9 196.9 381.5 195.0 402.1 C 194.3 409.9 192.7 418.2 189.2 425.3 C 175.8 452.4 139.2 462.0 111.1 457.6 C 105.1 456.7 99.4 454.7 94.2 451.7 C 83.3 445.2 75.3 434.1 73.0 421.6 C 71.1 411.1 73.9 402.9 79.7 394.4 C 93.0 375.1 117.0 368.5 138.7 364.4 C 145.1 363.2 152.2 362.7 158.3 360.3 C 162.7 358.6 167.3 355.0 169.2 350.6 C 174.1 339.3 171.7 292.0 171.7 276.9 C 171.7 234.3 171.8 191.6 171.8 148.9 C 171.8 137.4 169.7 111.9 173.1 102.0 C 174.5 97.9 178.7 94.2 182.4 91.9 C 193.1 85.2 207.8 84.6 219.9 82.0 C 256.0 74.2 292.6 68.1 328.7 60.0 C 344.3 56.5 360.0 53.4 375.7 50.4 C 383.1 49.0 390.7 46.7 398.3 46.5 C 402.5 46.4 408.3 47.3 411.6 50.1 C 414.3 52.4 416.5 55.7 417.0 59.3 C 418.3 71.0 417.1 83.5 417.2 95.3 C 417.2 124.0 417.1 152.6 417.2 181.3 C 417.3 220.0 417.1 258.7 417.1 297.3 C 417.1 319.9 418.4 342.9 416.2 365.3 C 415.5 372.9 413.2 380.5 409.7 387.2 C 396.1 413.6 356.0 425.3 328.3 418.8 C 312.8 415.1 300.0 404.3 293.9 389.5 C 288.9 377.5 289.3 364.2 297.2 353.5 C 311.9 333.7 335.6 326.5 358.9 322.4 C 367.1 321.0 376.6 320.1 384.0 315.9 C 385.7 314.9 387.1 313.6 388.5 312.1 C 392.2 307.8 392.7 302.7 393.3 297.2 C 394.1 289.0 393.5 280.5 393.4 272.2 C 393.4 255.9 393.4 239.6 393.4 223.2 C 393.5 208.2 393.4 193.2 393.5 178.2 C 393.5 168.6 394.2 158.8 392.9 149.2 C 392.5 146.1 391.2 144.7 389.5 142.3 Z"
    Rectangle {
        id: artMask
        anchors.fill: parent
        radius: art.r
        visible: false
        layer.enabled: true
    }
    Item {
        id: idle
        anchors.fill: parent
        visible: artImg.status !== Image.Ready && art.oldT < 0.01
        layer.enabled: visible
        layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask }

        Item {
            id: cv
            width: 512; height: 512
            scale: idle.width / 512
            transformOrigin: Item.TopLeft

            Rectangle {
                visible: !art.bare
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: art.idleBgTop }
                    GradientStop { position: 1.0; color: art.idleBgBottom }
                }
            }

            Item {
                id: noteSrc
                width: 512; height: 512
                visible: false
                layer.enabled: true
                layer.samples: 4
                Shape {
                    anchors.fill: parent
                    transform: Scale { origin.x: 245; origin.y: 252; xScale: art.noteSc; yScale: art.noteSc }
                    // without a tile the note fills the box and lines up with the text margin (centred where the art is centred)
                    x: art.bare && !art.wd.isLarge ? 172 * art.noteSc - 245 : 11; y: 4
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0; x2: 0; y2: 512
                            GradientStop { position: 0.0; color: art.bare ? art.wd.fg : art.noteTop }
                            GradientStop { position: 1.0; color: art.bare ? art.wd.fg : art.noteBottom }
                        }
                        PathSvg { path: art.notePath }
                    }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: noteSrc
                autoPaddingEnabled: false
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: art.dropOpacity
                shadowBlur: art.dropBlur
                shadowHorizontalOffset: 0
                shadowVerticalOffset: art.dropDown
            }

            Item {
                id: rimSrc
                width: 512; height: 512
                visible: false
                layer.enabled: true
                Shape {
                    x: 10; y: 2
                    width: 512; height: 512
                    transform: Scale { origin.x: 245; origin.y: 252; xScale: art.noteScale; yScale: art.noteScale }
                    ShapePath {
                        fillColor: "black"
                        strokeColor: "transparent"
                        fillRule: ShapePath.OddEvenFill
                        PathSvg { path: "M -600 -600 L 1100 -600 L 1100 1100 L -600 1100 Z " + art.notePath }
                    }
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: rimSrc
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 32
                blur: art.rimBlur
                maskEnabled: true
                maskSource: noteSrc
                visible: !art.bare
                opacity: art.rimOpacity
            }
        }
    }
    property real newT: 1
    property real oldT: 0
    function swapCover() {
        if (artImg.status === Image.Ready && String(artImg.source) !== "" && String(artImg.source) !== String(art.wd.artSrc)) {
            artOld.source = artImg.source;
            oldT = 1;
        }
        artImg.source = art.wd.artSrc;
        if (artImg.status === Image.Ready) { newT = 1; oldOut.restart(); }
        else { newT = 0; if (String(art.wd.artSrc) === "") oldOut.restart(); }
    }
    Connections { target: art.wd; function onArtSrcChanged() { art.swapCover(); } }
    Component.onCompleted: artImg.source = art.wd.artSrc
    NumberAnimation { id: newIn; target: art; property: "newT"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
    NumberAnimation { id: oldOut; target: art; property: "oldT"; to: 0; duration: 520; easing.type: Easing.InOutQuad }
    Image {
        id: artOld
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 400
        sourceSize.height: 400
        visible: false
        onStatusChanged: if (status === Image.Error) art.oldT = 0
    }
    Image {
        id: artImg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 400
        sourceSize.height: 400
        visible: false
        onStatusChanged: {
            if (status === Image.Ready) { newIn.restart(); oldOut.restart(); }
            else if (status === Image.Error) oldOut.restart();
        }
    }
    MultiEffect {
        anchors.fill: parent
        visible: art.oldT > 0.01 && artOld.status === Image.Ready
        opacity: art.oldT
        source: artOld
        maskEnabled: true
        maskSource: artMask
    }
    MultiEffect {
        anchors.fill: parent
        visible: artImg.status === Image.Ready
        opacity: art.newT
        scale: 1.06 - 0.06 * art.newT
        source: artImg
        maskEnabled: true
        maskSource: artMask
    }
    Rectangle {
        visible: !art.bare
        anchors.fill: parent
        radius: art.r
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
    }
}
