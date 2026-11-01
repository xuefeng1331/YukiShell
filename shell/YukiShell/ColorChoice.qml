import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "I18n.js" as I18n
import "ColorUtil.js" as ColorUtil

Item {
    id: cc
    required property var t
    property var presets: []
    property string current: ""
    property string defaultColor: "#ffffff"
    property bool active: true
    signal picked(string hex)

    readonly property string cur: ColorUtil.parse(current)
    readonly property bool curIsPreset: {
        for (var i = 0; i < presets.length; i++)
            if (String(presets[i]) === "" ? String(current) === "" : ColorUtil.parse(presets[i]) === cur) return true;
        return false;
    }
    readonly property bool customChosen: cur !== "" && !curIsPreset

    width: row.width
    height: 26
    opacity: active ? 1 : 0.45

    function apply(hex) { if (active) cc.picked(hex); }

    Row {
        id: row
        spacing: 6
        Repeater {
            model: cc.presets
            delegate: Item {
                id: sw
                required property var modelData
                readonly property string hex: String(modelData)
                readonly property bool sel: hex === "" ? cc.current === "" : ColorUtil.parse(hex) === cc.cur
                width: 26; height: 26
                Rectangle {
                    x: 4; y: 4; width: 18; height: 18; radius: 9
                    color: sw.hex === "" ? cc.defaultColor : sw.hex
                    border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.18)
                }
                GlassRing { x: 0; y: 0; width: 26; height: 26; radius: 13; ringW: 2; on: sw.sel; dark: cc.t.dark }
                MouseArea {
                    anchors.fill: parent
                    enabled: cc.active
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cc.apply(sw.hex)
                }
            }
        }
        Item {
            id: custom
            width: 26; height: 26
            Rectangle {
                x: 4; y: 4; width: 18; height: 18; radius: 9
                color: cc.customChosen ? cc.cur : "transparent"
                border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.18)
                gradient: cc.customChosen ? null : rainbow
                Gradient {
                    id: rainbow
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "#ff453a" }
                    GradientStop { position: 0.20; color: "#ff9f0a" }
                    GradientStop { position: 0.40; color: "#ffd60a" }
                    GradientStop { position: 0.60; color: "#30d158" }
                    GradientStop { position: 0.80; color: "#0a84ff" }
                    GradientStop { position: 1.00; color: "#bf5af2" }
                }
            }
            GlassRing { x: 0; y: 0; width: 26; height: 26; radius: 13; ringW: 2; on: cc.customChosen || pop.visible; dark: cc.t.dark }
            MouseArea {
                anchors.fill: parent
                enabled: cc.active
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (pop.visible) pop.close(); else pop.open(); }
            }
        }
    }

    Popup {
        id: pop
        readonly property int cell: 16
        readonly property int gap: 3
        x: cc.width - width
        y: cc.height + 6
        margins: 8
        padding: 12
        modal: false; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: { field.text = cc.cur !== "" ? cc.cur : ""; }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 300; easing.type: Easing.OutQuint }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; to: 0.97; duration: 150; easing.type: Easing.OutCubic }
            }
        }
        background: MenuGlass { t: cc.t; from: cc; open: pop.visible; cornerR: 12 }
        contentItem: Column {
            spacing: 10
            Grid {
                columns: 12
                spacing: pop.gap
                Repeater {
                    model: ColorUtil.palette()
                    delegate: Rectangle {
                        id: pc
                        required property string modelData
                        width: pop.cell; height: pop.cell; radius: 4
                        color: modelData
                        border.width: pc.modelData === cc.cur ? 2 : 1
                        border.color: pc.modelData === cc.cur ? cc.t.text : Qt.rgba(0, 0, 0, 0.16)
                        scale: pcMa.containsMouse ? 1.18 : 1
                        z: pcMa.containsMouse ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        MouseArea {
                            id: pcMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { field.text = pc.modelData; cc.apply(pc.modelData); }
                        }
                    }
                }
            }
            Row {
                spacing: 8
                Rectangle {
                    id: preview
                    readonly property string typed: ColorUtil.parse(field.text)
                    width: 30; height: 24; radius: 6
                    color: typed !== "" ? typed : (cc.cur !== "" ? cc.cur : cc.defaultColor)
                    border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.2)
                }
                Rectangle {
                    width: hint.width - 38; height: 24; radius: 6
                    color: cc.t.field
                    border.width: 1
                    border.color: (field.text.trim() !== "" && preview.typed === "") ? "#ff453a" : cc.t.cardBorder
                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        selectByMouse: true
                        maximumLength: 40
                        color: cc.t.text
                        selectionColor: cc.t.accent
                        font.family: cc.t.fam; font.pixelSize: 12
                        function commit() {
                            var h = ColorUtil.parse(text);
                            if (h !== "") { if (h !== cc.cur) cc.apply(h); text = h; }
                            else text = cc.cur;
                        }
                        onAccepted: commit()
                        onEditingFinished: commit()
                        Text {
                            visible: field.text === "" && !field.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                            text: "#0A84FF"
                            color: cc.t.text3
                            font: field.font
                        }
                    }
                }
            }
            Text {
                id: hint
                width: pop.cell * 12 + pop.gap * 11
                text: I18n.tr("Type a hex code (#0A84FF) or an RGB code (10, 132, 255), or pick a color above.")
                wrapMode: Text.WordWrap
                color: cc.t.text2
                font.family: cc.t.fam; font.pixelSize: 11
            }
        }
    }
}
