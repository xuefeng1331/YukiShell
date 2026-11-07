import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "I18n.js" as I18n
import "Fonts.js" as Fonts

Window {
    id: win

    title: "YukiShell Picker"
    width: 1120
    height: 740
    minimumWidth: 780
    minimumHeight: 500
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    property bool dark: true
    property string fam: "Open Runde"
    property color accent: "#0A84FF"
    property int thumbSize: 220
    property string lastDir: ""
    signal thumbSizeEdited(int size)

    property string mode: "image"
    property string heading: ""
    property string curDir: ""
    property string query: ""
    property var callback: null
    readonly property bool folderMode: mode === "folder"
    readonly property string home: Quickshell.env("HOME")

    property bool frost: true
    readonly property color cBg: dark ? Qt.rgba(0.118, 0.118, 0.125, frost ? 0.86 : 1) : Qt.rgba(0.961, 0.961, 0.969, frost ? 0.88 : 1)
    readonly property color cSide: dark ? "#29292B" : "#E9E9EC"
    readonly property color cText: dark ? "#F5F5F7" : "#1D1D1F"
    readonly property color cText2: dark ? Qt.rgba(1, 1, 1, 0.58) : Qt.rgba(0, 0, 0, 0.54)
    readonly property color cText3: dark ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(0, 0, 0, 0.32)
    readonly property color cLine: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color cField: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color cTile: dark ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(0, 0, 0, 0.045)
    readonly property color cFolder: dark ? "#8E98B5" : "#6E7AA5"

    function ff(weight) { return Fonts.forWeight(weight, win.fam); }
    function toUrl(p) { return "file://" + p.split("/").map(encodeURIComponent).join("/"); }
    function shortName(p) { var i = p.lastIndexOf("/"); return i >= 0 && p.length > 1 ? p.substring(i + 1) : p; }
    function parentOf(p) { var i = p.lastIndexOf("/"); return i <= 0 ? "/" : p.substring(0, i); }

    property var backStack: []
    function pick(opts, cb) {
        if (win.callback) win.finish("");
        opts = opts || {};
        win.mode = opts.mode === "folder" ? "folder" : "image";
        win.heading = opts.title || (win.folderMode ? I18n.tr("Choose a folder") : I18n.tr("Choose a picture"));
        win.callback = cb || null;
        win.query = "";
        searchInput.text = "";
        win.backStack = [];
        var start = String(opts.startDir || win.lastDir || (win.home + "/Pictures")).replace(/^~(?=\/|$)/, win.home);
        win.goTo(start, true);
        win.show();
        win.raise();
        win.requestActivate();
        grid.forceActiveFocus();
    }
    function finish(path) {
        var cb = win.callback;
        win.callback = null;
        if (path !== "" && win.curDir !== "") win.lastDir = win.folderMode ? path : win.parentOf(path);
        win.visible = false;
        if (cb) cb(path);
    }

    function goTo(path, fresh) {
        var p = String(path || "/");
        while (p.length > 1 && p.charAt(p.length - 1) === "/") p = p.substring(0, p.length - 1);
        if (!fresh && win.curDir !== "" && p !== win.curDir) win.backStack = win.backStack.concat([win.curDir]).slice(-30);
        win.curDir = p;
        grid.currentIndex = -1;
        grid.positionViewAtBeginning();
    }
    function goBack() {
        if (win.backStack.length === 0) return;
        var b = win.backStack.slice(), p = b.pop();
        win.backStack = b;
        win.curDir = p;
        grid.currentIndex = -1;
    }
    function goUp() { if (win.curDir !== "/") win.goTo(win.parentOf(win.curDir)); }

    readonly property var imageExts: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif", "tif", "tiff"]
    readonly property var nameFilters: {
        var q = win.query.trim().replace(/[\[\]*?\\]/g, ""), out = [];
        for (var i = 0; i < win.imageExts.length; i++) out.push("*" + q + "*." + win.imageExts[i]);
        return out;
    }
    FolderListModel {
        id: fm
        folder: win.curDir === "" ? "" : win.toUrl(win.curDir)
        showDirs: true
        showFiles: !win.folderMode
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        caseSensitive: false
        sortCaseSensitive: false
        nameFilters: win.folderMode ? ["*"] : win.nameFilters
    }

    readonly property int cellThumb: folderMode ? 130 : thumbSize
    readonly property int sel: grid.currentIndex
    readonly property bool hasSel: sel >= 0 && sel < fm.count
    readonly property string selPath: hasSel ? String(fm.get(sel, "filePath")) : ""
    readonly property bool selIsDir: hasSel && fm.get(sel, "fileIsDir") === true
    property int hoverIdx: -1
    readonly property int prevIdx: (hoverIdx >= 0 && hoverIdx < fm.count) ? hoverIdx : sel
    readonly property string prevPath: (prevIdx >= 0 && prevIdx < fm.count) ? String(fm.get(prevIdx, "filePath")) : ""
    readonly property bool prevIsDir: prevIdx >= 0 && prevIdx < fm.count && fm.get(prevIdx, "fileIsDir") === true
    function sizeText(b) {
        if (b < 1024) return b + " B";
        if (b < 1048576) return (b / 1024).toFixed(0) + " KB";
        return (b / 1048576).toFixed(1) + " MB";
    }

    function activate(idx) {
        if (idx < 0 || idx >= fm.count) return;
        var p = String(fm.get(idx, "filePath"));
        if (fm.get(idx, "fileIsDir") === true) win.goTo(p);
        else if (!win.folderMode) win.finish(p);
    }
    function choose() {
        if (win.folderMode) win.finish(win.hasSel && win.selIsDir ? win.selPath : win.curDir);
        else if (win.hasSel && !win.selIsDir) win.finish(win.selPath);
    }
    readonly property bool canChoose: win.folderMode ? win.curDir !== "" : (win.hasSel && !win.selIsDir)

    property var places: []
    Process {
        id: placesProc
        command: ["sh", "-c",
            "for n in DESKTOP DOCUMENTS DOWNLOAD PICTURES VIDEOS MUSIC; do "
            + "d=$(xdg-user-dir $n 2>/dev/null); [ -n \"$d\" ] && [ -d \"$d\" ] && [ \"$d\" != \"$HOME\" ] && printf '%s\\n' \"$d\"; done; "
            + "for d in /mnt/* /run/media/$USER/*; do [ -d \"$d\" ] && printf '%s\\n' \"$d\"; done; exit 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [{ label: I18n.tr("Home"), path: win.home }], seen = {};
                seen[win.home] = true;
                var l = text.split("\n");
                for (var i = 0; i < l.length; i++) {
                    var p = l[i].trim();
                    if (p === "" || seen[p]) continue;
                    seen[p] = true;
                    out.push({ label: win.shortName(p), path: p });
                }
                win.places = out;
            }
        }
    }
    onVisibleChanged: {
        if (visible) placesProc.running = true;
        else if (callback) finish("");
    }
    property var extraPlaces: []

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 14
        color: win.cBg
        border.width: 1
        border.color: win.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.20)

        Shortcut { sequences: ["Escape"]; enabled: win.visible; onActivated: { if (searchInput.activeFocus && searchInput.text !== "") searchInput.text = ""; else win.finish(""); } }
        Shortcut { sequences: ["Ctrl+W"]; enabled: win.visible; onActivated: win.finish("") }
        Shortcut { sequences: ["Ctrl+F"]; enabled: win.visible; onActivated: searchInput.forceActiveFocus() }
        Shortcut { sequences: ["Alt+Up", "Backspace"]; enabled: win.visible && !searchInput.activeFocus && !pathInput.activeFocus; onActivated: win.goUp() }
        Shortcut { sequences: ["Alt+Left"]; enabled: win.visible; onActivated: win.goBack() }
        Shortcut { sequences: ["Ctrl+L"]; enabled: win.visible; onActivated: { pathEdit.editing = true; pathInput.text = win.curDir; pathInput.forceActiveFocus(); pathInput.selectAll(); } }

        Rectangle {
            id: side
            x: 1; y: 1
            width: 214; height: parent.height - 2
            radius: 13
            color: win.cSide
            Rectangle { anchors.right: parent.right; width: 14; height: parent.height; color: parent.color }
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: win.cLine }

            Rectangle {
                x: 16; y: 16; width: 13; height: 13; radius: 7
                color: closeMa.containsMouse ? "#FF5F57" : (win.active ? "#FF5F57" : win.cText3)
                Text { visible: closeMa.containsMouse; anchors.centerIn: parent; text: "×"; color: Qt.rgba(0, 0, 0, 0.6); font.pixelSize: 11; font.weight: Font.Bold }
                MouseArea { id: closeMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: win.finish("") }
            }

            Text {
                x: 18; y: 50
                text: I18n.tr("Places")
                color: win.cText3
                font.family: win.ff(Font.DemiBold); font.pixelSize: 11; font.weight: Font.DemiBold
            }
            ListView {
                id: placeList
                x: 8; y: 72
                width: parent.width - 16
                height: parent.height - 72 - 12
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.places.concat(win.extraPlaces)
                delegate: Item {
                    id: pl
                    required property var modelData
                    required property int index
                    readonly property bool here: win.curDir === modelData.path
                    readonly property bool firstExtra: index === win.places.length && win.extraPlaces.length > 0
                    width: placeList.width
                    height: 34 + (firstExtra ? 22 : 0)
                    Text {
                        visible: pl.firstExtra
                        x: 10; y: 0
                        text: I18n.tr("Wallpaper folders")
                        color: win.cText3
                        font.family: win.ff(Font.DemiBold); font.pixelSize: 11; font.weight: Font.DemiBold
                    }
                    Rectangle {
                        y: pl.firstExtra ? 22 : 0
                        width: parent.width; height: 34; radius: 9
                        color: pl.here ? (win.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10)) : (plMa.containsMouse ? (win.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)) : "transparent")
                        FolderIcon { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 16; tone: pl.index === 0 ? win.accent : win.cFolder }
                        Text {
                            x: 40; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 50
                            elide: Text.ElideRight
                            text: pl.modelData.label
                            color: win.cText
                            font.family: win.ff(pl.here ? Font.DemiBold : Font.Normal); font.pixelSize: 13; font.weight: pl.here ? Font.DemiBold : Font.Normal
                        }
                        MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.goTo(pl.modelData.path) }
                    }
                }
            }
        }

        Item {
            id: head
            x: side.width + 1; y: 0
            width: parent.width - x; height: 58
            DragHandler { target: null; onActiveChanged: if (active) win.startSystemMove() }

            Row {
                id: navBtns
                x: 14; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [{ g: "‹", act: "back" }, { g: "↑", act: "up" }]
                    delegate: Rectangle {
                        id: nb
                        required property var modelData
                        readonly property bool ok: modelData.act === "back" ? win.backStack.length > 0 : win.curDir !== "/"
                        width: 32; height: 30; radius: 9
                        color: nbMa.containsMouse && ok ? (win.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: nb.modelData.act === "back" ? -2 : 0
                            text: nb.modelData.g
                            color: nb.ok ? win.cText : win.cText3
                            font.family: win.ff(Font.Normal); font.pixelSize: nb.modelData.act === "back" ? 26 : 18
                        }
                        MouseArea { id: nbMa; anchors.fill: parent; hoverEnabled: true; enabled: nb.ok; onClicked: nb.modelData.act === "back" ? win.goBack() : win.goUp() }
                    }
                }
            }

            Rectangle {
                id: pathEdit
                property bool editing: false
                anchors.left: navBtns.right; anchors.leftMargin: 10
                anchors.right: searchBox.left; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 32; radius: 10
                color: win.cField
                border.width: pathEdit.editing ? 2 : 0
                border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.55)
                clip: true

                readonly property var parts: {
                    var p = win.curDir, out = [];
                    if (p === "") return out;
                    var base = "", rest = p;
                    if (p === win.home || p.indexOf(win.home + "/") === 0) {
                        out.push({ label: I18n.tr("Home"), path: win.home });
                        base = win.home; rest = p.substring(win.home.length);
                    } else {
                        out.push({ label: "/", path: "/" });
                    }
                    var segs = rest.split("/").filter(function (x) { return x !== ""; }), acc = base === "" ? "" : base;
                    for (var i = 0; i < segs.length; i++) { acc += "/" + segs[i]; out.push({ label: segs[i], path: acc }); }
                    return out;
                }
                Flickable {
                    id: crumbFlick
                    visible: !pathEdit.editing
                    anchors.fill: parent
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    contentWidth: crumbRow.width
                    contentX: Math.max(0, crumbRow.width - width)
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: false
                    Row {
                        id: crumbRow
                        height: crumbFlick.height
                        Repeater {
                            model: pathEdit.parts
                            delegate: Row {
                                id: cr
                                required property var modelData
                                required property int index
                                height: crumbRow.height
                                Text {
                                    visible: cr.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "›"
                                    color: win.cText3
                                    font.family: win.ff(Font.Normal); font.pixelSize: 15
                                    leftPadding: 2; rightPadding: 2
                                }
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: crTxt.implicitWidth + 14; height: 24; radius: 7
                                    color: crMa.containsMouse ? (win.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"
                                    Text {
                                        id: crTxt
                                        anchors.centerIn: parent
                                        text: cr.modelData.label
                                        color: win.cText
                                        font.family: win.ff(cr.index === pathEdit.parts.length - 1 ? Font.DemiBold : Font.Normal)
                                        font.pixelSize: 13
                                        font.weight: cr.index === pathEdit.parts.length - 1 ? Font.DemiBold : Font.Normal
                                    }
                                    MouseArea { id: crMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.goTo(cr.modelData.path) }
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    visible: !pathEdit.editing
                    anchors.fill: parent
                    z: -1
                    onClicked: { pathEdit.editing = true; pathInput.text = win.curDir; pathInput.forceActiveFocus(); pathInput.selectAll(); }
                }
                TextInput {
                    id: pathInput
                    visible: pathEdit.editing
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true; selectByMouse: true
                    color: win.cText
                    selectionColor: win.accent
                    font.family: win.ff(Font.Normal); font.pixelSize: 13
                    onActiveFocusChanged: if (!activeFocus) pathEdit.editing = false
                    onAccepted: { dirCheck.want = text.trim().replace(/^~(?=\/|$)/, win.home); dirCheck.running = true; }
                    Keys.onEscapePressed: { pathEdit.editing = false; grid.forceActiveFocus(); }
                }
                Process {
                    id: dirCheck
                    property string want: ""
                    command: ["sh", "-c", "[ -d \"$1\" ] && echo ok", "sh", want]
                    stdout: StdioCollector { onStreamFinished: { if (text.indexOf("ok") >= 0) win.goTo(dirCheck.want); pathEdit.editing = false; grid.forceActiveFocus(); } }
                }
            }

            Rectangle {
                id: searchBox
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 220; height: 32; radius: 10
                color: win.cField
                border.width: searchInput.activeFocus ? 2 : 0
                border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.55)
                Text { x: 11; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: win.cText3; font.family: win.ff(Font.Normal); font.pixelSize: 17 }
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 32; anchors.rightMargin: 26
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true; selectByMouse: true
                    color: win.cText
                    selectionColor: win.accent
                    font.family: win.ff(Font.Normal); font.pixelSize: 13
                    onTextChanged: { win.query = text; grid.currentIndex = -1; }
                    Keys.onDownPressed: { grid.forceActiveFocus(); if (fm.count > 0) grid.currentIndex = 0; }
                    Keys.onReturnPressed: { grid.forceActiveFocus(); if (fm.count > 0) { grid.currentIndex = 0; } }
                    Text {
                        visible: searchInput.text === "" && !searchInput.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Search")
                        color: win.cText3
                        font: searchInput.font
                    }
                }
                Text {
                    visible: searchInput.text !== ""
                    anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                    text: "×"; color: win.cText2; font.family: win.ff(Font.Normal); font.pixelSize: 18
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: searchInput.text = "" }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: win.cLine }
        }

        Item {
            id: body
            x: side.width + 1; y: head.height
            width: parent.width - x
            height: parent.height - head.height - foot.height
            readonly property real previewW: (!win.folderMode && win.width >= 960) ? 330 : 0

            GridView {
                id: grid
                x: 10; y: 8
                width: parent.width - body.previewW - 20
                height: parent.height - 16
                clip: true
                focus: true
                model: fm
                keyNavigationEnabled: true
                currentIndex: -1
                boundsBehavior: Flickable.StopAtBounds
                readonly property int cols: Math.max(1, Math.floor(width / (win.cellThumb + 24)))
                cellWidth: Math.floor((width - 10) / cols)
                cellHeight: Math.round(win.cellThumb * 0.78) + 52
                cacheBuffer: cellHeight * 3
                Keys.onReturnPressed: win.activate(currentIndex)
                Keys.onEnterPressed: win.activate(currentIndex)
                Keys.onPressed: event => {
                    if (event.text !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier)) && event.key !== Qt.Key_Space
                        && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Backspace && event.text.charCodeAt(0) >= 32) {
                        searchInput.forceActiveFocus();
                        searchInput.text = searchInput.text + event.text;
                        searchInput.cursorPosition = searchInput.text.length;
                        event.accepted = true;
                    }
                }
                ScrollBar.vertical: ScrollBar {
                    policy: grid.contentHeight > grid.height + 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    width: 8
                    background: Item {}
                    contentItem: Rectangle { implicitWidth: 6; radius: 3; color: win.cText3 }
                }

                delegate: Item {
                    id: cell
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool isCur: GridView.isCurrentItem
                    readonly property real tileW: grid.cellWidth - 18
                    readonly property real tileH: Math.round(win.cellThumb * 0.78)

                    GlassHover {
                        x: 4; y: 2
                        width: grid.cellWidth - 8; height: cell.tileH + 48
                        radius: 14
                        dark: win.dark
                        hot: cellMa.containsMouse && !cell.isCur
                        open: cell.isCur
                        pressed: cellMa.pressed
                        area: cellMa
                    }
                    Item {
                        id: tile
                        x: 9; y: 8
                        width: cell.tileW; height: cell.tileH
                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            visible: !cell.fileIsDir
                            color: win.cTile
                        }
                        Image {
                            id: thumb
                            anchors.fill: parent
                            anchors.margins: 3
                            visible: !cell.fileIsDir
                            source: cell.fileIsDir ? "" : win.toUrl(cell.filePath)
                            sourceSize.width: Math.round(win.thumbSize * 1.5)
                            sourceSize.height: Math.round(win.thumbSize * 1.2)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }
                        FolderIcon {
                            visible: cell.fileIsDir
                            anchors.centerIn: parent
                            width: Math.min(parent.width * 0.62, 150); height: width * 0.8
                            tone: win.cFolder
                        }
                        Text {
                            visible: !cell.fileIsDir && thumb.status === Image.Error
                            anchors.centerIn: parent
                            text: I18n.tr("Can't show this picture")
                            color: win.cText3
                            font.family: win.ff(Font.Normal); font.pixelSize: 11
                        }
                    }
                    Text {
                        x: 9; y: tile.y + tile.height + 8
                        width: cell.tileW
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        text: cell.fileName
                        color: cell.isCur ? win.cText : win.cText2
                        font.family: win.ff(cell.isCur ? Font.DemiBold : Font.Normal); font.pixelSize: 12; font.weight: cell.isCur ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.hoverIdx = cell.index
                        onExited: if (win.hoverIdx === cell.index) win.hoverIdx = -1
                        onClicked: { grid.currentIndex = cell.index; grid.forceActiveFocus(); }
                        onDoubleClicked: win.activate(cell.index)
                    }
                }

                Text {
                    visible: fm.count === 0
                    anchors.centerIn: parent
                    width: parent.width - 60
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: win.query.trim() !== "" ? I18n.tr("Nothing matches your search.")
                          : (win.folderMode ? I18n.tr("No folders in here.") : I18n.tr("No pictures in this folder."))
                    color: win.cText3
                    font.family: win.ff(Font.Normal); font.pixelSize: 14
                }
            }

            Rectangle {
                visible: body.previewW > 0
                x: parent.width - body.previewW; y: 8
                width: body.previewW - 12; height: parent.height - 16
                radius: 12
                color: win.cTile
                border.width: 1; border.color: win.cLine
                Image {
                    id: bigPic
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.bottomMargin: 74
                    source: (win.prevPath !== "" && !win.prevIsDir) ? win.toUrl(win.prevPath) : ""
                    sourceSize.width: 900
                    sourceSize.height: 900
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true; smooth: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                Text {
                    visible: win.prevPath === "" || win.prevIsDir
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (parent.height - 74) / 2 - height / 2
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: win.prevIsDir ? I18n.tr("Double-click to open the folder") : I18n.tr("Point at a picture to see it big")
                    color: win.cText3
                    font.family: win.ff(Font.Normal); font.pixelSize: 13
                }
                Column {
                    x: 14; y: parent.height - 66
                    width: parent.width - 28
                    spacing: 3
                    Text {
                        width: parent.width; elide: Text.ElideMiddle
                        text: win.prevPath === "" ? "" : win.shortName(win.prevPath)
                        color: win.cText
                        font.family: win.ff(Font.DemiBold); font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width; elide: Text.ElideRight
                        text: (win.prevPath === "" || win.prevIsDir) ? "" : win.sizeText(fm.get(win.prevIdx, "fileSize")) + "   ·   " + Qt.formatDate(fm.get(win.prevIdx, "fileModified"), "d MMM yyyy")
                        color: win.cText2
                        font.family: win.ff(Font.Normal); font.pixelSize: 12
                    }
                    Text {
                        width: parent.width; elide: Text.ElideMiddle
                        text: win.prevPath === "" ? "" : win.parentOf(win.prevPath).replace(win.home, "~")
                        color: win.cText3
                        font.family: win.ff(Font.Normal); font.pixelSize: 11
                    }
                }
            }
        }

        Item {
            id: foot
            x: side.width + 1; y: parent.height - height
            width: parent.width - x; height: 62
            Rectangle { width: parent.width; height: 1; color: win.cLine }

            Item {
                id: sizer
                x: 18; anchors.verticalCenter: parent.verticalCenter
                width: 190; height: 30
                visible: !win.folderMode
                Rectangle { x: 0; y: 11; width: 9; height: 8; radius: 2; color: win.cText3 }
                Rectangle { x: parent.width - 16; y: 6; width: 16; height: 16; radius: 3; color: win.cText3 }
                Rectangle {
                    id: sTrack
                    x: 22; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 22 - 28; height: 4; radius: 2
                    color: win.dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.14)
                    readonly property real frac: (win.thumbSize - 110) / (340 - 110)
                    Rectangle { width: parent.width * sTrack.frac; height: parent.height; radius: 2; color: win.cText2 }
                    Rectangle {
                        x: parent.width * sTrack.frac - width / 2; anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18; radius: 9
                        color: "white"
                        border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.18)
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.topMargin: -12; anchors.bottomMargin: -12
                        preventStealing: true
                        function setFrom(mx) {
                            var f = Math.max(0, Math.min(1, mx / sTrack.width));
                            win.thumbSize = Math.round((110 + f * (340 - 110)) / 10) * 10;
                            win.thumbSizeEdited(win.thumbSize);
                        }
                        onPressed: mouse => setFrom(mouse.x)
                        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x); }
                    }
                }
            }
            Text {
                x: sizer.visible ? 226 : 18
                anchors.verticalCenter: parent.verticalCenter
                text: fm.count + " " + (fm.count === 1 ? I18n.tr("item") : I18n.tr("items"))
                color: win.cText3
                font.family: win.ff(Font.Normal); font.pixelSize: 12
            }

            Row {
                anchors.right: parent.right; anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle {
                    width: cancelTxt.implicitWidth + 36; height: 32; radius: 10
                    color: cancelMa.pressed ? (win.dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.14)) : (win.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.07))
                    Text { id: cancelTxt; anchors.centerIn: parent; text: I18n.tr("Cancel"); color: win.cText; font.family: win.ff(Font.Medium); font.pixelSize: 13; font.weight: Font.Medium }
                    MouseArea { id: cancelMa; anchors.fill: parent; onClicked: win.finish("") }
                }
                Rectangle {
                    width: okTxt.implicitWidth + 36; height: 32; radius: 10
                    opacity: win.canChoose ? 1 : 0.4
                    color: okMa.pressed ? Qt.darker(win.accent, 1.2) : win.accent
                    Text {
                        id: okTxt
                        anchors.centerIn: parent
                        text: win.folderMode ? I18n.tr("Choose This Folder") : I18n.tr("Choose")
                        color: "white"; font.family: win.ff(Font.DemiBold); font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    MouseArea { id: okMa; anchors.fill: parent; enabled: win.canChoose; onClicked: win.choose() }
                }
            }
        }

        component FolderIcon: Item {
            property color tone: "#8E98B5"
            Rectangle { x: 0; y: 0; width: parent.width * 0.42; height: parent.height * 0.34; radius: parent.height * 0.12; color: Qt.darker(parent.tone, 1.18) }
            Rectangle {
                x: 0; y: parent.height * 0.14
                width: parent.width; height: parent.height * 0.86
                radius: parent.height * 0.14
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(tone, 1.18) }
                    GradientStop { position: 1.0; color: tone }
                }
            }
        }
    }
}
