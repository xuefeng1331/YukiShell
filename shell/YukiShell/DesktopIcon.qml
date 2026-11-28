// DesktopIcon — one file / folder / app on the desktop. Purely visual: all mouse handling lives in Desktop.qml.
//
// Selected look: a frosted, translucent grey rounded square behind the icon with a light rim (no accent colour).
import QtQuick

Item {
    id: ic

    property var item: null              // { name, path, isDir, isApp, kind }
    property string source: ""           // resolved icon image
    property string fam: "Open Runde"
    property int iconSize: 48
    property int labelLines: 2           // 1 when the grid is too tight for two
    property bool expanded: false        // the only selected icon: its whole name shows, like Finder's
    property color accent: "#0A84FF"
    property bool selected: false
    property bool dropTarget: false      // another icon is being dragged over this one
    property bool dragging: false
    property string emoji: ""            // emoji shown on a folder ("" = none)
    property string fallback: ""         // shown when source won't load (a folder's own picture that was deleted or moved)
    property bool failed: false
    onSourceChanged: failed = false

    readonly property int pad: 6
    readonly property int boxSize: iconSize + 2 * pad
    // pictures (screenshots) are shown as a short landscape thumbnail instead of a square one
    readonly property bool isPicture: item !== null && item.kind === "Image"
    readonly property int iconH: isPicture ? Math.round(iconSize * 0.6) : iconSize
    readonly property int boxH: iconH + 2 * pad

    opacity: dragging ? 0.82 : 1.0

    // ── selection / drop highlight ──
    Item {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: ic.boxSize; height: ic.boxH
        opacity: (ic.selected || ic.dropTarget) ? 1 : 0

        // soft dark hairline just outside the rim, so the highlight stays readable on bright wallpapers
        Rectangle {
            anchors.fill: parent; anchors.margins: -1
            radius: 15
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.16)
        }
        // frosted grey body
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: ic.selected ? Qt.rgba(0.80, 0.82, 0.82, 0.32) : Qt.rgba(0.80, 0.82, 0.82, 0.22)
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, ic.selected ? 0.42 : 0.30)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.00) }
            }
        }
    }

    // ── the icon itself: app icon, folder, image thumbnail or a plain document ──
    Image {
        id: img
        anchors.horizontalCenter: parent.horizontalCenter
        y: ic.pad
        width: ic.iconSize; height: ic.iconH
        asynchronous: true; cache: true; smooth: true; mipmap: true
        fillMode: ic.item && ic.item.kind === "Image" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        sourceSize: Qt.size(ic.iconSize * 2, ic.iconSize * 2)
        source: ic.failed && ic.fallback !== "" ? ic.fallback : ic.source
        onStatusChanged: if (status === Image.Error) ic.failed = true
    }

    // ── emoji set on a folder: drawn on the folder's body ──
    Text {
        visible: ic.emoji !== ""
        anchors.horizontalCenter: img.horizontalCenter
        y: ic.pad + Math.round(ic.iconH * 0.34)
        text: ic.emoji
        font.pixelSize: Math.round(ic.iconSize * 0.42)
        renderType: Text.QtRendering
    }

    // ── name, like Finder's: wrapped onto the lines there are, the last one cut in the middle so the end (the extension) stays;
    //    the only selected icon shows its whole name. Selected names sit on an accent pill. ──
    readonly property string label: item ? (item.isApp ? item.name.replace(/\.desktop$/i, "") : item.name) : ""
    readonly property real labelW: width - 6
    FontMetrics { id: fm; font.family: ic.fam; font.pixelSize: 11 }
    // the first line: the longest start that fits, broken after a space, "-", "_" or "." when there is one in its second half
    readonly property var lines: {
        var s = label, w = labelW - 2;
        if (labelLines < 2 || fm.advanceWidth(s) <= w) return [s];
        var k = 1;
        while (k < s.length && fm.advanceWidth(s.slice(0, k + 1)) <= w) k++;
        var head = s.slice(0, k), b = Math.max(head.lastIndexOf(" "), head.lastIndexOf("-"), head.lastIndexOf("_"), head.lastIndexOf("."));
        if (b >= k / 2) k = b + 1;
        return [s.slice(0, k).replace(/ +$/, ""), s.slice(k).replace(/^ +/, "")];
    }
    Rectangle {
        visible: ic.selected
        anchors.horizontalCenter: parent.horizontalCenter
        y: ic.boxH + 2
        width: (ic.expanded ? fullName.contentWidth : shortName.width) + 10
        height: (ic.expanded ? fullName.contentHeight : shortName.height) + 2
        radius: 5
        color: Qt.darker(ic.accent, 1.3)   // white text stays readable on light accents
    }
    Column {
        id: shortName
        visible: !ic.expanded
        anchors.horizontalCenter: parent.horizontalCenter
        y: ic.boxH + 3
        Repeater {
            model: ic.lines
            Text {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, ic.labelW)
                elide: Text.ElideMiddle
                text: modelData
                color: "white"; font.family: ic.fam; font.pixelSize: 11
                style: ic.selected ? Text.Normal : Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.55)
            }
        }
    }
    Text {
        id: fullName
        visible: ic.expanded
        anchors.horizontalCenter: parent.horizontalCenter
        y: ic.boxH + 3
        width: ic.labelW
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: ic.label.replace(/([_-])/g, "$1\u200B")   // may also break after _ and -, not mid-word (never before the extension)
        color: "white"; font.family: ic.fam; font.pixelSize: 11
    }
}
