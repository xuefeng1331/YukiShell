import QtQuick
import "Fonts.js" as Fonts
import "I18n.js" as I18n

Item {
    id: a
    property Item wd
    property string lay: "tall"

    readonly property real u: lay === "tall" ? Math.min(width / 185, height / 385)
                            : (lay === "strip" ? Math.min(width / 809, height / 185) : Math.min(width / 809, height / 385))
    readonly property var now: wd ? wd.now : new Date()
    readonly property color ink: wd && wd.dark ? "#FFFFFF" : "#0C0D0F"
    readonly property color ink2: wd && wd.dark ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.5)
    readonly property color tile: wd && wd.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color hand: "#FF9F0A"
    readonly property string hh: wd ? wd.hourText : String(now.getHours() % 12 || 12)
    readonly property string mm: ("0" + now.getMinutes()).slice(-2)
    readonly property string ampm: wd && wd.use24h ? "" : (now.getHours() < 12 ? "AM" : "PM")
    readonly property real secs: wd ? wd.secs : 0
    readonly property string dateText: I18n.locale().toString(now, "dddd, d MMMM")

    component Label: Text {
        property real px: 13
        property int weight: Font.DemiBold
        color: a.ink
        font.family: Fonts.forWeight(weight, a.wd.fam)
        font.pixelSize: px * a.u
        font.weight: weight
        font.features: { "tnum": 1 }
    }
    component Tile: Rectangle {
        property string txt
        radius: 18 * a.u
        color: a.tile
        Text {
            anchors.centerIn: parent
            text: parent.txt
            color: a.ink
            font.family: a.wd.boldFam
            font.pixelSize: parent.height * 0.62
            font.features: { "tnum": 1 }
        }
        Rectangle { width: parent.width; height: Math.max(1, 1.2 * a.u); y: parent.height / 2; color: a.wd.dark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.7) }
    }

    Item {
        anchors.fill: parent
        visible: a.lay === "tall"
        Label { anchors.horizontalCenter: parent.horizontalCenter; y: 16 * a.u; text: a.wd.cityCode; px: 12; weight: Font.Bold; color: a.ink2; font.letterSpacing: 0.6 * a.u }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 42 * a.u
            spacing: 10 * a.u
            Tile { width: a.width - 34 * a.u; height: width * 0.86; txt: a.hh }
            Tile { width: a.width - 34 * a.u; height: width * 0.86; txt: a.mm }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 66 * a.u
            spacing: 4 * a.u
            Repeater {
                model: 12
                delegate: Rectangle {
                    required property int index
                    width: 6 * a.u; height: width; radius: width / 2
                    color: index < Math.floor(a.secs / 5) ? a.hand : a.tile
                }
            }
        }
        Label { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 46 * a.u; width: parent.width - 20 * a.u; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: a.dateText; px: 12; color: a.ink2 }
    }

    Item {
        anchors.fill: parent
        visible: a.lay === "strip"
        Row {
            x: 26 * a.u; anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * a.u
            Text {
                text: a.wd.preview ? a.wd.previewTime : a.hh + ":" + a.mm
                color: a.ink
                font.family: a.wd.boldFam
                font.pixelSize: 84 * a.u
                font.letterSpacing: -2.5 * a.u
                font.features: { "tnum": 1 }
            }
            Label { anchors.baseline: parent.children[0].baseline; text: a.ampm; px: 20; color: a.ink2 }
        }
        Item {
            id: sBar
            x: 330 * a.u; width: a.width - x - 260 * a.u; height: 8 * a.u
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors.fill: parent; radius: height / 2; color: a.tile }
            Rectangle { width: Math.max(parent.height, parent.width * a.secs / 60); height: parent.height; radius: height / 2; color: a.hand }
            Label { y: -24 * a.u; text: a.wd.cityCode; px: 12; weight: Font.Bold; color: a.ink2; font.letterSpacing: 0.6 * a.u }
            Label { anchors.right: parent.right; y: -24 * a.u; text: Math.floor(a.secs) + "s"; px: 12; color: a.ink2 }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 28 * a.u; anchors.verticalCenter: parent.verticalCenter
            Label { anchors.right: parent.right; text: I18n.locale().dayName(a.now.getDay(), Locale.LongFormat); px: 22 }
            Label { anchors.right: parent.right; text: I18n.locale().toString(a.now, "d MMMM yyyy"); px: 15; color: a.ink2 }
        }
    }

    Item {
        anchors.fill: parent
        visible: a.lay === "hero"
        Item {
            id: face
            readonly property real d: a.height - 48 * a.u
            x: 30 * a.u; y: 24 * a.u
            width: d; height: d
            Rectangle { anchors.fill: parent; radius: width / 2; color: a.tile }
            Repeater {
                model: 60
                delegate: Item {
                    required property int index
                    anchors.fill: parent
                    rotation: index * 6
                    Rectangle {
                        readonly property bool major: index % 5 === 0
                        x: (face.width - width) / 2; y: 8 * a.u
                        width: (major ? 3.2 : 1.4) * a.u; height: (major ? 14 : 7) * a.u; radius: width / 2
                        color: major ? a.ink : a.ink2
                        opacity: major ? 0.9 : 0.5
                    }
                }
            }
            Repeater {
                model: 12
                delegate: Label {
                    required property int index
                    readonly property real ang: (index + 1) * 30 * Math.PI / 180
                    readonly property real rr: face.width / 2 - 40 * a.u
                    x: face.width / 2 + rr * Math.sin(ang) - width / 2
                    y: face.height / 2 - rr * Math.cos(ang) - height / 2
                    text: index + 1; px: 18; color: a.ink
                }
            }
            component Hand: Rectangle {
                id: hd
                property real angle
                property real len
                property real back: 0
                x: (face.width - width) / 2; y: face.height / 2 - len
                height: len + back
                radius: width / 2
                transform: Rotation { origin.x: hd.width / 2; origin.y: hd.len; angle: hd.angle }
                antialiasing: true
            }
            Hand { angle: (a.now.getHours() % 12 + a.now.getMinutes() / 60) * 30; len: face.width * 0.26; width: 7 * a.u; color: a.ink }
            Hand { angle: (a.now.getMinutes() + a.secs / 60) * 6; len: face.width * 0.38; width: 5 * a.u; color: a.ink }
            Hand { angle: a.secs * 6; len: face.width * 0.42; back: 18 * a.u; width: 2 * a.u; color: a.hand }
            Rectangle { anchors.centerIn: parent; width: 10 * a.u; height: width; radius: width / 2; color: a.hand; border.width: 2 * a.u; border.color: a.ink }
        }
        Column {
            x: face.x + face.width + 44 * a.u; anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * a.u
            Label { text: a.wd.cityCode; px: 15; weight: Font.Bold; color: a.hand; font.letterSpacing: 1 * a.u }
            Row {
                spacing: 10 * a.u
                Text {
                    id: hTime
                    text: a.wd.preview ? a.wd.previewTime : a.hh + ":" + a.mm
                    color: a.ink
                    font.family: a.wd.boldFam
                    font.pixelSize: 112 * a.u
                    font.letterSpacing: -3.5 * a.u
                    font.features: { "tnum": 1 }
                }
                Label { anchors.baseline: hTime.baseline; text: a.ampm; px: 26; color: a.ink2 }
            }
            Label { text: I18n.locale().dayName(a.now.getDay(), Locale.LongFormat); px: 26 }
            Label { text: I18n.locale().toString(a.now, "d MMMM yyyy"); px: 18; color: a.ink2 }
        }
    }
}
