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
    readonly property int ws: wd ? wd.weekStart : 0
    readonly property var weekStart: { var d = new Date(now.getFullYear(), now.getMonth(), now.getDate()); d.setDate(d.getDate() - ((d.getDay() - ws + 7) % 7)); return d; }
    function dayAt(i) { var d = new Date(weekStart); d.setDate(d.getDate() + i); return d; }
    function same(d, e) { return d.getFullYear() === e.getFullYear() && d.getMonth() === e.getMonth() && d.getDate() === e.getDate(); }
    function shortDay(d) { return wd.dayNames[d.getDay()].slice(0, 3); }

    component Label: Text {
        property real px: 13
        property int weight: Font.DemiBold
        color: a.wd.fg
        font.family: Fonts.forWeight(weight, a.wd.fam)
        font.pixelSize: px * a.u
        font.weight: weight
        elide: Text.ElideRight
    }
    component MonthGrid: Item {
        id: mg
        property int year
        property int month
        property real cell: 30 * a.u
        readonly property int lead: (new Date(year, month, 1).getDay() - a.ws + 7) % 7
        readonly property int days: new Date(year, month + 1, 0).getDate()
        width: cell * 7
        height: cell * 7.6
        Label { text: a.wd.monthNames[mg.month]; px: 15; color: a.wd.red }
        Repeater {
            model: 7
            delegate: Label {
                required property int index
                x: index * mg.cell; y: 26 * a.u; width: mg.cell
                horizontalAlignment: Text.AlignHCenter
                text: a.wd.letters[(index + a.ws) % 7]; px: 11; color: a.wd.fgSub
            }
        }
        Repeater {
            model: mg.days
            delegate: Item {
                required property int index
                readonly property int slot: index + mg.lead
                readonly property bool today: a.same(new Date(mg.year, mg.month, index + 1), a.now)
                x: (slot % 7) * mg.cell; y: 46 * a.u + Math.floor(slot / 7) * mg.cell * 0.92
                width: mg.cell; height: mg.cell * 0.92
                Rectangle { anchors.centerIn: parent; width: parent.height * 0.92; height: width; radius: width / 2; color: a.wd.red; visible: parent.today }
                Label {
                    anchors.centerIn: parent
                    text: index + 1; px: 13
                    color: parent.today ? "white" : ((parent.slot + a.ws) % 7 === 0 || (parent.slot + a.ws) % 7 === 6 ? a.wd.fgSub : a.wd.fg)
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: a.lay === "tall"
        Label { x: 18 * a.u; y: 16 * a.u; text: a.wd.dayNames[a.now.getDay()].toUpperCase(); px: 12; color: a.wd.red; font.letterSpacing: 0.6 * a.u }
        Label { id: tNum; x: 15 * a.u; y: 28 * a.u; text: a.now.getDate(); px: 70; weight: Font.Light }
        Label { x: 18 * a.u; y: tNum.y + tNum.height - 6 * a.u; text: a.wd.monthNames[a.now.getMonth()] + " " + a.now.getFullYear(); px: 14; color: a.wd.fgSub }
        Rectangle { id: tLine; x: 18 * a.u; y: 150 * a.u; width: parent.width - 36 * a.u; height: 1; color: a.wd.line }
        Column {
            x: 12 * a.u; y: tLine.y + 8 * a.u
            width: parent.width - 24 * a.u
            Repeater {
                model: 7
                delegate: Item {
                    required property int index
                    readonly property var d: a.dayAt(index)
                    readonly property bool today: a.same(d, a.now)
                    width: parent.width; height: Math.min(31 * a.u, (a.height - 166 * a.u - 10 * a.u) / 7)
                    Rectangle { anchors.fill: parent; radius: height / 2; color: a.wd.red; visible: parent.today }
                    Label { x: 10 * a.u; anchors.verticalCenter: parent.verticalCenter; text: a.shortDay(parent.d); px: 13; color: parent.today ? "white" : a.wd.fgSub }
                    Label { anchors.right: parent.right; anchors.rightMargin: 12 * a.u; anchors.verticalCenter: parent.verticalCenter; text: parent.d.getDate(); px: 15; color: parent.today ? "white" : a.wd.fg }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: a.lay === "strip"
        Column {
            x: 22 * a.u; anchors.verticalCenter: parent.verticalCenter
            Label { text: a.wd.dayNames[a.now.getDay()].toUpperCase(); px: 12; color: a.wd.red; font.letterSpacing: 0.6 * a.u }
            Label { text: a.now.getDate(); px: 62; weight: Font.Light }
            Label { text: a.wd.monthNames[a.now.getMonth()] + " " + a.now.getFullYear(); px: 13; color: a.wd.fgSub }
        }
        Rectangle { x: 190 * a.u; y: 22 * a.u; width: 1; height: parent.height - 44 * a.u; color: a.wd.line }
        Row {
            id: sRow
            x: 204 * a.u; y: 0; height: parent.height
            readonly property real cw: (a.width - x - 16 * a.u) / 14
            Repeater {
                model: 14
                delegate: Item {
                    required property int index
                    readonly property var d: a.dayAt(index)
                    readonly property bool today: a.same(d, a.now)
                    readonly property bool past: d < new Date(a.now.getFullYear(), a.now.getMonth(), a.now.getDate())
                    width: sRow.cw; height: sRow.height
                    Label { anchors.horizontalCenter: parent.horizontalCenter; y: 44 * a.u; text: a.wd.letters[parent.d.getDay()]; px: 12; color: a.wd.fgSub }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 72 * a.u
                        width: Math.min(parent.width - 4 * a.u, 38 * a.u); height: width; radius: width / 2
                        color: parent.today ? a.wd.red : "transparent"
                        Label { anchors.centerIn: parent; text: parent.parent.d.getDate(); px: 17; color: parent.parent.today ? "white" : a.wd.fg; opacity: parent.parent.past ? 0.4 : 1 }
                    }
                    Label {
                        visible: parent.d.getDate() === 1
                        anchors.horizontalCenter: parent.horizontalCenter; y: 120 * a.u
                        text: a.wd.monthNames[parent.d.getMonth()].slice(0, 3); px: 11; color: a.wd.red
                    }
                    Rectangle {
                        visible: index === 7
                        x: 0; y: 46 * a.u; width: 1; height: 70 * a.u; color: a.wd.line
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: a.lay === "hero"
        Label { x: 28 * a.u; y: 26 * a.u; text: a.wd.dayNames[a.now.getDay()].toUpperCase(); px: 15; color: a.wd.red; font.letterSpacing: 0.8 * a.u }
        Label { id: hNum; x: 22 * a.u; y: 40 * a.u; text: a.now.getDate(); px: 140; weight: Font.Light }
        Label { x: 28 * a.u; y: hNum.y + hNum.height - 14 * a.u; text: a.wd.monthNames[a.now.getMonth()] + " " + a.now.getFullYear(); px: 18; color: a.wd.fgSub }
        Label {
            x: 28 * a.u; y: parent.height - 42 * a.u
            readonly property int doy: Math.floor((new Date(a.now.getFullYear(), a.now.getMonth(), a.now.getDate()) - new Date(a.now.getFullYear(), 0, 1)) / 86400000) + 1
            text: I18n.tr("Day %1 · Week %2").arg(doy).arg(Math.ceil((doy + new Date(a.now.getFullYear(), 0, 1).getDay()) / 7))
            px: 13; color: a.wd.fgSub
        }
        Rectangle { x: 270 * a.u; y: 26 * a.u; width: 1; height: parent.height - 52 * a.u; color: a.wd.line }
        Row {
            x: 296 * a.u; y: 24 * a.u
            spacing: 26 * a.u
            MonthGrid { year: a.now.getFullYear(); month: a.now.getMonth(); cell: (a.width - 296 * a.u - 26 * a.u - 26 * a.u) / 14 }
            MonthGrid {
                year: a.now.getMonth() === 11 ? a.now.getFullYear() + 1 : a.now.getFullYear()
                month: (a.now.getMonth() + 1) % 12
                cell: (a.width - 296 * a.u - 26 * a.u - 26 * a.u) / 14
            }
        }
    }
}
