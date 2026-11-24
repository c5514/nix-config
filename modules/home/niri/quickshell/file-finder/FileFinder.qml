import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme-switcher"
import "../components"
import "finder.js" as Finder

// Fuzzy file finder, toggled with `qs ipc call files toggle` (bind it to
// Super+Space in niri, see the README snippet in the commit notes).
//
// Nothing is indexed: every query runs `fd` over $HOME with a fuzzy regex on
// the file name, streams the matches back and ranks them in JS (finder.js).
// A new query cancels the previous `fd` first, so results never mix.
//
// Enter        PDFs/images/audio/video/other files -> xdg-open
//              folders                             -> Yazi in that folder
//              source/text (.tex .md .sh ...)      -> Yazi in the parent folder
// Alt+Enter    Yazi in the item's parent folder, whatever it is
// Selected files are never executed.
Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property int selectedIndex: 0
    property bool open: false

    // Mirrored from the window's TextInput so the search logic doesn't reach
    // into a window that only exists while the finder is open.
    property string query: ""
    property var resultsView: null

    // Closing drops the result/buffer arrays instead of holding them forever.
    onOpenChanged: {
        if (!open) {
            results = [];
            buffer = [];
        }
    }

    readonly property string home: Quickshell.env("HOME")

    // ── Configuration ────────────────────────────────────────────────────────
    property string fdBinary: "fd"       // "fdfind" on Debian/Ubuntu
    property int searchLimit: 300        // fd stops after this many matches
    property int resultLimit: 100        // rows kept after ranking
    property var excludes: Finder.EXCLUDES

    // argv to open Yazi in a terminal at `dir` (no shell involved, so any path
    // is safe). Wezterm matches the dock; swap in your terminal if different,
    // e.g. kitty: ["kitty", "--directory", dir, "yazi"]
    //       foot: ["foot", "--working-directory", dir, "yazi"]
    //["wezterm", "start", "--cwd", dir, "--", "yazi"]
    property var yaziCommand: dir => ["foot", "--working-directory", dir, "yazi"]

    // ── State ────────────────────────────────────────────────────────────────
    property var results: []
    property var buffer: []
    property string runQuery: ""
    property bool searching: false
    property bool fresh: false           // no line received yet for the current run
    property bool restartPending: false

    IpcHandler {
        target: "files"

        function toggle(): void {
            root.open = !root.open;
        }
    }

    // ── Search plumbing ──────────────────────────────────────────────────────

    function requestSearch() {
        if (fdProc.running) {
            // Wait for the old fd to exit before starting the next one, so a
            // late line from the old run can't land in the new run's results.
            root.restartPending = true;
            fdProc.running = false;
        } else {
            root.startSearch();
        }
    }

    function startSearch() {
        root.runQuery = root.query;
        root.buffer = [];
        root.fresh = true;
        root.searching = true;
        fdProc.command = Finder.fdCommand({
            fd: root.fdBinary,
            home: root.home,
            query: root.runQuery,
            limit: root.searchLimit,
            excludes: root.excludes
        });
        fdProc.running = true;
    }

    function cancelSearch() {
        debounce.stop();
        publishTimer.stop();
        root.restartPending = false;
        fdProc.running = false;
    }

    function publish() {
        root.results = Finder.rank(root.buffer, root.runQuery, root.home, root.resultLimit);
        root.selectedIndex = Math.min(root.selectedIndex, Math.max(0, root.results.length - 1));
    }

    Process {
        id: fdProc
        running: false

        stdout: SplitParser {
            onRead: line => {
                if (line === "")
                    return;
                // Keep showing the previous results until the new run
                // produces something, so typing doesn't flash an empty list.
                if (root.fresh) {
                    root.buffer = [];
                    root.fresh = false;
                }
                root.buffer.push(line);
                if (!publishTimer.running)
                    publishTimer.start();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("FileFinder fd:", text.trim());
            }
        }

        onExited: {
            if (root.restartPending) {
                root.restartPending = false;
                root.startSearch();
                return;
            }
            publishTimer.stop();
            if (root.fresh)
                root.results = [];
            else
                root.publish();
            root.fresh = false;
            root.searching = false;
        }
    }

    // Batches streamed lines so a large result set isn't re-ranked per line.
    Timer {
        id: publishTimer
        interval: 70
        onTriggered: root.publish()
    }

    Timer {
        id: debounce
        interval: 90
        onTriggered: root.requestSearch()
    }

    ScriptModel {
        id: resultsModel
        objectProp: "path"
        values: root.results
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    // Enter routes by type; `browseParent` (Alt+Enter) forces Yazi in the
    // parent folder. Everything is passed as argv, never through a shell.
    function activate(item, browseParent) {
        if (!item)
            return;
        const route = browseParent ? "browse-parent" : item.route;
        if (route === "open")
            Quickshell.execDetached(["xdg-open", item.path]);
        else
            Quickshell.execDetached(root.yaziCommand(route === "browse-self" ? item.path : item.parent));
        root.open = false;
    }

    function move(delta) {
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex + delta, root.results.length - 1));
        if (root.resultsView)
            root.resultsView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
    }

    function kindColor(key) {
        switch (key) {
        case "folder":
            return root.theme.accentPrimary;
        case "pdf":
            return root.theme.accentRed;
        case "image":
            return root.theme.accentGreen;
        case "media":
            return root.theme.accentOrange;
        case "code":
            return root.theme.accentCyan;
        default:
            return root.theme.textSecondary;
        }
    }

    // Created on open, destroyed on close: a closed panel keeps no window,
    // scene graph or item tree alive.
    LazyLoader {
        active: root.open

        PanelWindow {
            id: finderPanel
            Component.onCompleted: {
                root.query = "";
                root.selectedIndex = 0;
                root.results = [];
                root.resultsView = resultsList;
                debounce.stop();
                root.requestSearch();
                searchInput.forceActiveFocus();
            }

            // Blur only the visible panel (niri ext-background-effect), not the whole layer.
            BackgroundEffect.blurRegion: Region {
                item: finderBox
                radius: 16
            }

            focusable: true
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-files"

            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Component.onDestruction: {
                root.cancelSearch();
                root.resultsView = null;
            }

            // Transparent click-catcher: clicking outside closes the finder
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            Rectangle {
                id: finderBox
                anchors.centerIn: parent
                width: 620
                height: 470
                radius: 16
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1

                // Swallow clicks on empty areas so they don't reach the click-catcher.
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    // Search bar
                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 10
                        color: root.theme.bgSurface
                        border.color: searchInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
                        border.width: 1

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 10

                            Text {
                                text: "\uf002"
                                color: root.theme.accentPrimary
                                font.pixelSize: 15
                                font.family: root.font
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                color: root.theme.textPrimary
                                font.pixelSize: 15
                                font.family: root.font
                                clip: true
                                focus: true
                                Accessible.role: Accessible.EditableText
                                Accessible.name: "Search files"

                                Text {
                                    anchors.fill: parent
                                    text: "Search files…"
                                    color: root.theme.textMuted
                                    font: parent.font
                                    visible: !parent.text && !parent.activeFocus
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onTextChanged: {
                                    root.query = text;
                                    root.selectedIndex = 0;
                                    resultsList.positionViewAtIndex(0, ListView.Beginning);
                                    if (finderPanel.visible)
                                        debounce.restart();
                                }

                                Keys.onEscapePressed: root.open = false

                                Keys.onPressed: event => {
                                    const ctrl = event.modifiers & Qt.ControlModifier;
                                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                                        event.accepted = true;
                                        root.move(1);
                                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                                        event.accepted = true;
                                        root.move(-1);
                                    } else if (event.key === Qt.Key_PageDown) {
                                        event.accepted = true;
                                        root.move(6);
                                    } else if (event.key === Qt.Key_PageUp) {
                                        event.accepted = true;
                                        root.move(-6);
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        event.accepted = true;
                                        root.activate(resultsModel.values[root.selectedIndex], !!(event.modifiers & Qt.AltModifier));
                                    }
                                }
                            }

                            KeyHint {
                                theme: root.theme
                                font: root.font
                                key: "Esc"
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.theme.bgBorder
                    }

                    // Results
                    ListView {
                        id: resultsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: resultsModel
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: root.selectedIndex

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index

                            readonly property bool selected: root.selectedIndex === row.index

                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.name + ", " + modelData.label

                            width: resultsList.width
                            height: 50
                            radius: 8
                            color: row.selected ? root.theme.bgSelected : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            // Left vertical indicator
                            Rectangle {
                                width: 3
                                height: 24
                                radius: 2
                                color: root.theme.accentPrimary
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.selected
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // File-type icon
                                Text {
                                    Layout.preferredWidth: 24
                                    Layout.alignment: Qt.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: row.modelData.icon
                                    color: root.kindColor(row.modelData.colorKey)
                                    font.pixelSize: 20
                                    font.family: root.font
                                }

                                // Name and relative path. PlainText so a file called
                                // "<b>x</b>" is shown as written, not rendered.
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.name
                                        textFormat: Text.PlainText
                                        color: row.selected ? root.theme.textPrimary : root.theme.textSecondary
                                        font.pixelSize: 13
                                        font.family: root.font
                                        font.bold: row.selected
                                        elide: Text.ElideMiddle
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.rel
                                        textFormat: Text.PlainText
                                        color: root.theme.textMuted
                                        font.pixelSize: 11
                                        font.family: root.font
                                        elide: Text.ElideMiddle
                                    }
                                }

                                // Type label
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: row.modelData.label
                                    textFormat: Text.PlainText
                                    color: root.theme.textMuted
                                    font.pixelSize: 10
                                    font.family: root.font
                                    font.letterSpacing: 0.5
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activate(row.modelData, false)
                                onEntered: root.selectedIndex = row.index
                            }
                        }

                        // Empty states
                        Text {
                            anchors.centerIn: parent
                            visible: resultsList.count === 0
                            text: root.searching ? "Searching…" : "No matching files"
                            color: root.theme.textMuted
                            font.pixelSize: 14
                            font.family: root.font
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.theme.bgBorder
                    }

                    // Footer hints
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        KeyHint {
                            theme: root.theme
                            font: root.font
                            key: "↵"
                            label: "Open"
                        }

                        KeyHint {
                            theme: root.theme
                            font: root.font
                            key: "Alt+↵"
                            label: "Browse in Yazi"
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
