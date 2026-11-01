import QtQuick
import "Fonts.js" as Fonts

Item {
    id: a
    property Item wd
    property string lay: "tall"

    readonly property real u: lay === "tall" ? Math.min(width / 185, height / 385)
                            : (lay === "strip" ? Math.min(width / 809, height / 185) : Math.min(width / 809, height / 385))
    readonly property real pad: 16 * u
    readonly property string unit: wd ? wd.unitSuffix : "°"
    function deg(t) { return wd && wd.hasData ? t + unit : "–" + unit; }
    readonly property var hours: wd ? wd.hourly : []
    readonly property var days: wd ? wd.daily : []

    component Label: Text {
        property real px: 13
        property int weight: Font.DemiBold
        color: a.wd.fg
        font.family: Fonts.forWeight(weight, a.wd.fam)
        font.pixelSize: px * a.u
        font.weight: weight
        elide: Text.ElideRight
    }
    readonly property real wkMin: { var m = 1e9; for (var i = 0; i < days.length; i++) m = Math.min(m, days[i].lo); return m; }
    readonly property real wkMax: { var m = -1e9; for (var i = 0; i < days.length; i++) m = Math.max(m, days[i].hi); return m; }
    readonly property real wkSpan: Math.max(1, wkMax - wkMin)

    Item {
        anchors.fill: parent
        visible: a.lay === "tall"
        Label { x: a.pad; y: a.pad - 2 * a.u; width: parent.width - 2 * a.pad; text: a.wd.city; px: 15 }
        Label { id: tTemp; x: a.pad - 2 * a.u; y: 34 * a.u; text: a.deg(a.wd.temp); px: 52; weight: Font.Light }
        WeatherIcon { light: !a.wd.dark;
            visible: a.wd.showIcon(a.wd.kind)
            x: parent.width - a.pad - size; y: 46 * a.u
            kind: a.wd.kind; size: 26 * a.u
        }
        Label { id: tCond; x: a.pad; y: tTemp.y + tTemp.height; width: parent.width - 2 * a.pad; text: a.wd.cond; px: 13 }
        Label { x: a.pad; y: tCond.y + tCond.height + 1 * a.u; text: a.wd.hasData ? "H:" + a.deg(a.wd.hi) + "  L:" + a.deg(a.wd.lo) : ""; px: 13; color: a.wd.fgSub }
        Rectangle { id: tLine; x: a.pad; y: 164 * a.u; width: parent.width - 2 * a.pad; height: 1; color: a.wd.line }
        Column {
            x: a.pad; y: tLine.y + 8 * a.u
            width: parent.width - 2 * a.pad
            Repeater {
                model: a.hours.slice(0, Math.max(1, Math.floor((a.height - (164 + 8) * a.u - a.pad) / (31 * a.u))))
                delegate: Item {
                    required property var modelData
                    width: parent.width; height: 31 * a.u
                    Label { anchors.verticalCenter: parent.verticalCenter; text: modelData.h; px: 13; color: a.wd.fgHour }
                    WeatherIcon { light: !a.wd.dark;
                        visible: a.wd.showIcon(modelData.k)
                        anchors.centerIn: parent
                        kind: modelData.k; size: 16 * a.u
                    }
                    Label { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: a.deg(modelData.t); px: 15 }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: a.lay === "strip"
        Column {
            x: 20 * a.u; anchors.verticalCenter: parent.verticalCenter
            width: 190 * a.u
            Label { width: parent.width; text: a.wd.city; px: 14 }
            Label { text: a.deg(a.wd.temp); px: 50; weight: Font.Light }
            Label { width: parent.width; text: a.wd.cond + (a.wd.hasData ? "  ·  H:" + a.deg(a.wd.hi) + " L:" + a.deg(a.wd.lo) : ""); px: 12; color: a.wd.fgSub }
        }
        Rectangle { x: 222 * a.u; y: 22 * a.u; width: 1; height: parent.height - 44 * a.u; color: a.wd.line }
        Row {
            id: sDays
            x: 234 * a.u; y: 0
            height: parent.height
            readonly property int n: Math.max(1, Math.min(a.days.length, 7))
            Repeater {
                model: a.days.slice(0, sDays.n)
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: (a.width - 234 * a.u - 14 * a.u) / sDays.n
                    height: sDays.height
                    Label { id: dn; anchors.horizontalCenter: parent.horizontalCenter; y: 20 * a.u; text: modelData.d; px: 13; color: index === 0 ? a.wd.fg : a.wd.fgHour }
                    WeatherIcon { light: !a.wd.dark;
                        visible: a.wd.showIcon(modelData.k)
                        anchors.horizontalCenter: parent.horizontalCenter; y: 44 * a.u
                        kind: modelData.k; size: 20 * a.u
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 76 * a.u; width: 5 * a.u; height: 54 * a.u; radius: width / 2
                        color: a.wd.barTrack
                        Rectangle {
                            width: parent.width; radius: width / 2
                            y: parent.height * (a.wkMax - modelData.hi) / a.wkSpan
                            height: Math.max(width, parent.height * (modelData.hi - modelData.lo) / a.wkSpan)
                            color: a.wd.barFill
                        }
                    }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; y: 136 * a.u; text: a.deg(modelData.hi); px: 14 }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; y: 154 * a.u; text: a.deg(modelData.lo); px: 12; color: a.wd.fgSub }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: a.lay === "hero"
        readonly property real panelW: 290 * a.u
        Label { x: 26 * a.u; y: 24 * a.u; width: 250 * a.u; text: a.wd.city; px: 18 }
        Label { id: hTemp; x: 20 * a.u; y: 50 * a.u; text: a.deg(a.wd.temp); px: 104; weight: Font.Light }
        WeatherIcon { light: !a.wd.dark;
            visible: a.wd.showIcon(a.wd.kind)
            x: 222 * a.u; y: 30 * a.u
            kind: a.wd.kind; size: 44 * a.u
        }
        Label { x: 26 * a.u; y: hTemp.y + hTemp.height + 6 * a.u; width: 250 * a.u; text: a.wd.cond; px: 20 }
        Label { x: 26 * a.u; y: hTemp.y + hTemp.height + 34 * a.u; text: a.wd.hasData ? "H:" + a.deg(a.wd.hi) + "   L:" + a.deg(a.wd.lo) : ""; px: 16; color: a.wd.fgSub }
        Rectangle { x: parent.panelW; y: 24 * a.u; width: 1; height: parent.height - 48 * a.u; color: a.wd.line }
        Row {
            id: hHours
            x: parent.panelW + 20 * a.u; y: 22 * a.u
            readonly property real avail: a.width - x - 22 * a.u
            readonly property int n: Math.max(1, Math.min(a.hours.length, Math.floor(avail / (58 * a.u))))
            Repeater {
                model: a.hours.slice(0, hHours.n)
                delegate: Column {
                    required property var modelData
                    width: hHours.avail / hHours.n
                    spacing: 4 * a.u
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.h; px: 13; color: a.wd.fgHour }
                    Item {
                        width: parent.width; height: 22 * a.u
                        WeatherIcon { light: !a.wd.dark; visible: a.wd.showIcon(modelData.k); anchors.centerIn: parent; kind: modelData.k; size: 20 * a.u }
                    }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: a.deg(modelData.t); px: 17 }
                }
            }
        }
        Rectangle { id: hLine; x: parent.panelW + 20 * a.u; y: 116 * a.u; width: a.width - x - 22 * a.u; height: 1; color: a.wd.line }
        Column {
            x: parent.panelW + 20 * a.u; y: hLine.y + 6 * a.u
            width: a.width - x - 22 * a.u
            Repeater {
                model: a.days.slice(0, Math.max(1, Math.min(a.days.length, Math.floor((a.height - hLine.y - 6 * a.u - 18 * a.u) / (34 * a.u)))))
                delegate: Item {
                    required property var modelData
                    width: parent.width; height: 34 * a.u
                    Label { width: 90 * a.u; anchors.verticalCenter: parent.verticalCenter; text: modelData.d; px: 15 }
                    WeatherIcon { light: !a.wd.dark; visible: a.wd.showIcon(modelData.k); x: 96 * a.u; anchors.verticalCenter: parent.verticalCenter; kind: modelData.k; size: 18 * a.u }
                    Label { x: 130 * a.u; width: 44 * a.u; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: a.deg(modelData.lo); px: 15; color: a.wd.fgSub }
                    Rectangle {
                        id: hTrack
                        x: 186 * a.u; width: parent.width - x - 60 * a.u; height: 5 * a.u; radius: height / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: a.wd.barTrack
                        Rectangle {
                            height: parent.height; radius: height / 2
                            x: parent.width * (modelData.lo - a.wkMin) / a.wkSpan
                            width: Math.max(height, parent.width * (modelData.hi - modelData.lo) / a.wkSpan)
                            color: a.wd.barFill
                        }
                    }
                    Label { anchors.right: parent.right; width: 48 * a.u; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: a.deg(modelData.hi); px: 15 }
                }
            }
        }
    }
}
