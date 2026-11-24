import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme-switcher"

Scope {
    id: root

    property var theme: Theme
    property string font: "JetBrainsMono NF"

    property int selectedIndex: 0
    property var historyItems: []
    property bool open: false

    // Ctrl+I / the chip next to the item count: show only image entries.
    property bool imagesOnly: false

    // The filter text lives here (mirrored from the window's TextInput) so the
    // filtered model and selection logic don't have to reach into a window
    // that only exists while the panel is open.
    property string query: ""
    property var resultsView: null

    // Closing frees the history (up to 200 entries, incl. multi-line previews)
    // and removes the decoded image previews, which are written to /tmp.
    onOpenChanged: {
        if (!open) {
            historyItems = [];
            imagePreviewId = "";
            thumbs = ({});
            _thumbQueue = [];
            Quickshell.execDetached(["sh", "-c", "rm -f /tmp/quickshell-clipboard-*"]);
        }
    }

    // Image thumbnails: id -> decoded file in /tmp. Decoded one at a time, only
    // for rows that are actually on screen (plus the selected one).
    property string imagePreviewId: ""
    property var thumbs: ({})
    property var _thumbQueue: []
    property string _thumbBusyId: ""
    property string _thumbBusyPath: ""

    function isImageEntry(item) {
        if (!item || !item.preview)
            return false;

        return /\[\[\s*binary data.*\b(png|jpe?g|webp|gif|bmp)\b/i.test(item.preview);
    }

    function imageExtension(item) {
        const match = item.preview.match(/\[\[\s*binary data.*?\b(png|jpe?g|webp|gif|bmp)\b/i);

        if (!match)
            return "img";

        return match[1].toLowerCase();
    }

    // Selected row: make sure its image is decoded (jumping the queue).
    function prepareImagePreview(item) {
        if (!isImageEntry(item)) {
            imagePreviewId = "";
            return;
        }

        imagePreviewId = item.id;
        requestThumb(item, true);
    }

    function requestThumb(item, priority) {
        if (!isImageEntry(item))
            return;

        if (thumbs[item.id] !== undefined || _thumbBusyId === item.id)
            return;

        const rest = _thumbQueue.filter(q => q.id !== item.id);
        const entry = {
            id: item.id,
            path: "/tmp/quickshell-clipboard-" + item.id.replace(/[^a-zA-Z0-9_-]/g, "_") + "." + imageExtension(item)
        };

        _thumbQueue = priority ? [entry].concat(rest) : rest.concat([entry]);
        pumpThumbs();
    }

    function pumpThumbs() {
        if (thumbProcess.running || _thumbQueue.length === 0)
            return;

        const next = _thumbQueue[0];
        _thumbQueue = _thumbQueue.slice(1);
        _thumbBusyId = next.id;
        _thumbBusyPath = next.path;

        thumbProcess.command = ["sh", "-c", 'cliphist decode "$1" > "$2"', "clipboard-preview", next.id, next.path];
        thumbProcess.running = true;
    }

    function refreshHistory() {
        historyItems = [];
        listProcess.pendingItems = [];
        listProcess.currentEntry = null;

        listProcess.command = ["sh", "-c", "cliphist list -preview-lines 3 | head -200"];

        listProcess.running = true;
    }

    function copyItem(item) {
        if (!item)
            return;

        copyProcess.command = ["sh", "-c", 'cliphist decode "$1" | wl-copy', "clipboard-copy", item.id];

        copyProcess.running = true;
        root.open = false;
    }

    function toggleImagesOnly() {
        imagesOnly = !imagesOnly;
        selectedIndex = 0;
        if (resultsView)
            resultsView.positionViewAtIndex(0, ListView.Beginning);
        prepareImagePreview(filteredModel.values[0]);
    }

    // Removes the entry from cliphist itself (not just from this list) and
    // keeps the panel open so several entries can be cleaned up in a row.
    function deleteItem(item) {
        if (!item)
            return;

        deleteProcess.command = ["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "clipboard-delete", item.id];
        deleteProcess.running = true;

        if (imagePreviewId === item.id)
            imagePreviewId = "";

        _thumbQueue = _thumbQueue.filter(q => q.id !== item.id);

        historyItems = historyItems.filter(h => h.id !== item.id);
        selectedIndex = Math.max(0, Math.min(selectedIndex, filteredModel.values.length - 1));
        prepareImagePreview(filteredModel.values[selectedIndex]);
    }

    function selectIndex(index) {
        if (filteredModel.values.length === 0) {
            selectedIndex = 0;
            return;
        }

        selectedIndex = Math.max(0, Math.min(index, filteredModel.values.length - 1));

        if (resultsView)
            resultsView.positionViewAtIndex(selectedIndex, ListView.Contain);

        prepareImagePreview(filteredModel.values[selectedIndex]);
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            root.open = !root.open;
        }
    }

    ScriptModel {
        id: filteredModel

        objectProp: "id"

        values: {
            const q = root.query.trim().toLowerCase();
            const base = root.imagesOnly ? root.historyItems.filter(item => root.isImageEntry(item)) : root.historyItems;

            if (q === "")
                return base;

            return base.filter(item => item.preview.toLowerCase().includes(q));
        }
    }

    Process {
        id: listProcess

        running: false

        property var pendingItems: []
        property var currentEntry: null

        stdout: SplitParser {
            onRead: line => {
                const trimmed = line.trim();

                if (trimmed === "")
                    return;

                const hexWith0x = trimmed.match(/^0x[0-9a-fA-F]+\s+/);

                const hexWithout0x = trimmed.match(/^[0-9a-fA-F]+\s+/);

                const decimal = trimmed.match(/^[0-9]+\s+/);

                const idMatch = hexWith0x || hexWithout0x || decimal;

                if (idMatch) {
                    if (listProcess.currentEntry) {
                        listProcess.pendingItems.push(listProcess.currentEntry);
                    }

                    const id = idMatch[0].trim();

                    const preview = trimmed.substring(idMatch[0].length) || "";

                    listProcess.currentEntry = {
                        id: id,
                        preview: preview
                    };
                } else {
                    if (listProcess.currentEntry) {
                        listProcess.currentEntry.preview += "\n" + trimmed;
                    }
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                if (listProcess.currentEntry) {
                    listProcess.pendingItems.push(listProcess.currentEntry);

                    listProcess.currentEntry = null;
                }

                root.historyItems = listProcess.pendingItems;
                listProcess.pendingItems = [];

                root.selectedIndex = 0;

                if (root.historyItems.length > 0) {
                    root.prepareImagePreview(filteredModel.values[0]);
                }
            }
        }
    }

    Process {
        id: thumbProcess

        running: false

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root._thumbBusyId !== "") {
                const next = Object.assign({}, root.thumbs);
                next[root._thumbBusyId] = root._thumbBusyPath;
                root.thumbs = next;
            }

            root._thumbBusyId = "";
            root._thumbBusyPath = "";
            root.pumpThumbs();
        }
    }

    Process {
        id: deleteProcess

        running: false
    }

    Process {
        id: copyProcess

        running: false
    }

    // Created on open, destroyed on close: a closed panel keeps no window,
    // scene graph or item tree alive.
    LazyLoader {
        active: root.open

        PanelWindow {
            id: clipboardPanel
            Component.onDestruction: root.resultsView = null
            Component.onCompleted: {
                root.query = "";
                root.imagesOnly = false;
                root.selectedIndex = 0;
                root.resultsView = resultsList;
                root.refreshHistory();
                searchInput.forceActiveFocus();
            }

            focusable: true
            color: "transparent"

            BackgroundEffect.blurRegion: Region {
                item: popupBox
                radius: 16
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-clipboard"

            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent

                onClicked: root.open = false
            }

            Rectangle {
                id: popupBox

                anchors.centerIn: parent

                width: 580
                height: 480

                radius: 16
                color: root.theme.bgBase

                border.color: root.theme.bgBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: " Clipboard History"

                        color: root.theme.accentPrimary

                        font.pixelSize: 14
                        font.family: root.font
                        font.bold: true

                        style: Text.Raised
                        styleColor: "#80000000"
                    }

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
                            anchors.rightMargin: 14
                            spacing: 10

                            TextInput {
                                id: searchInput

                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                color: root.theme.textPrimary

                                font.pixelSize: 15
                                font.family: root.font

                                clip: true
                                focus: true

                                Text {
                                    anchors.fill: parent

                                    text: "Filter history..."

                                    color: root.theme.textMuted
                                    font: parent.font

                                    visible: !parent.text && !parent.activeFocus

                                    verticalAlignment: Text.AlignVCenter
                                }

                                onTextChanged: {
                                    root.query = text;
                                    root.selectedIndex = 0;

                                    if (filteredModel.values.length > 0) {
                                        root.prepareImagePreview(filteredModel.values[0]);
                                    } else {
                                        root.imagePreviewId = "";
                                    }
                                }

                                Keys.onEscapePressed: {
                                    root.open = false;
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Down) {
                                        event.accepted = true;
                                        root.selectIndex(root.selectedIndex + 1);
                                    } else if (event.key === Qt.Key_Up) {
                                        event.accepted = true;
                                        root.selectIndex(root.selectedIndex - 1);
                                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.AltModifier)) {
                                        event.accepted = true;
                                        root.deleteItem(filteredModel.values[root.selectedIndex]);
                                    } else if (event.key === Qt.Key_I && (event.modifiers & Qt.ControlModifier)) {
                                        event.accepted = true;
                                        root.toggleImagesOnly();
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        event.accepted = true;

                                        if (filteredModel.values.length > 0) {
                                            const item = filteredModel.values[root.selectedIndex];

                                            if (item)
                                                root.copyItem(item);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: resultsList.count + " item" + (resultsList.count !== 1 ? "s" : "")

                            color: root.theme.textMuted

                            font.pixelSize: 11
                            font.family: root.font
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            implicitWidth: imagesChipText.implicitWidth + 16
                            implicitHeight: 20
                            radius: 10

                            color: root.imagesOnly ? root.theme.accentPrimary : (chipMouse.containsMouse ? root.theme.bgHover : root.theme.bgSurface)

                            Text {
                                id: imagesChipText

                                anchors.centerIn: parent
                                text: "\uf03e  Images"

                                color: root.imagesOnly ? root.theme.textOnAccent : root.theme.textMuted

                                font.pixelSize: 11
                                font.family: root.font
                            }

                            MouseArea {
                                id: chipMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.toggleImagesOnly();
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    ListView {
                        id: resultsList

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        model: filteredModel
                        clip: true
                        spacing: 2

                        boundsBehavior: Flickable.StopAtBounds

                        currentIndex: root.selectedIndex

                        highlightMoveDuration: 150
                        highlightMoveVelocity: -1

                        highlight: Rectangle {
                            radius: 8
                            color: root.theme.bgSelected

                            Rectangle {
                                width: 3
                                height: 24
                                radius: 2

                                color: root.theme.accentPrimary

                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        delegate: Rectangle {
                            id: entryDelegate

                            required property var modelData
                            required property int index

                            width: resultsList.width

                            height: Math.max(44, entryLayout.implicitHeight + 16)

                            radius: 8

                            color: hoverArea.containsMouse && root.selectedIndex !== index ? root.theme.bgHover : "transparent"

                            border.color: root.theme.bgBorder

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            RowLayout {
                                id: entryLayout

                                anchors.fill: parent

                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                spacing: 12

                                Image {
                                    id: imageThumbnail

                                    readonly property bool imageEntry: root.isImageEntry(entryDelegate.modelData)
                                    readonly property string thumbFile: root.thumbs[entryDelegate.modelData.id] ?? ""

                                    // Images mode: every image row shows its thumbnail,
                                    // larger. Otherwise only the selected row does.
                                    readonly property bool wantThumb: imageEntry && root.imagesOnly

                                    onWantThumbChanged: if (wantThumb)
                                        root.requestThumb(entryDelegate.modelData, false)

                                    Component.onCompleted: if (wantThumb)
                                        root.requestThumb(entryDelegate.modelData, false)

                                    visible: imageEntry && thumbFile !== "" && (root.imagesOnly || root.imagePreviewId === entryDelegate.modelData.id)

                                    source: visible ? "file://" + thumbFile : ""

                                    sourceSize.width: root.imagesOnly ? 400 : 192
                                    sourceSize.height: root.imagesOnly ? 240 : 128

                                    Layout.preferredWidth: visible ? (root.imagesOnly ? 200 : 96) : 0

                                    Layout.preferredHeight: visible ? (root.imagesOnly ? 120 : 64) : 0

                                    Layout.alignment: Qt.AlignVCenter

                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false

                                    Rectangle {
                                        anchors.fill: parent

                                        color: "transparent"
                                        radius: 6

                                        border.color: root.theme.bgBorder
                                        border.width: 1

                                        visible: imageThumbnail.status === Image.Ready
                                    }
                                }

                                Text {
                                    id: previewText

                                    text: root.isImageEntry(entryDelegate.modelData) ? entryDelegate.modelData.preview.replace(/\[\[\s*binary data[^\]]*\]\]/, "Image") : (entryDelegate.modelData.preview || " ")

                                    color: root.selectedIndex === index ? root.theme.textPrimary : root.theme.textSecondary

                                    font.pixelSize: 13
                                    font.family: root.font

                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight

                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: hoverArea

                                anchors.fill: parent

                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.copyItem(entryDelegate.modelData);
                                }

                                onEntered: {
                                    root.selectIndex(index);
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: (searchInput.text || root.imagesOnly) ? "No matches" : "No history items"

                            color: root.theme.textMuted

                            font.pixelSize: 14
                            font.family: root.font

                            visible: resultsList.count === 0
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Row {
                            spacing: 4

                            Rectangle {
                                width: hintUp.width + 8
                                height: 18
                                radius: 4

                                color: root.theme.bgSurface

                                Text {
                                    id: hintUp

                                    anchors.centerIn: parent

                                    text: "↑↓"

                                    color: root.theme.textMuted

                                    font.pixelSize: 10
                                    font.family: root.font
                                }
                            }

                            Text {
                                text: "navigate"

                                color: root.theme.textMuted

                                font.pixelSize: 10
                                font.family: root.font

                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 4

                            Rectangle {
                                width: hintEnter.width + 8
                                height: 18
                                radius: 4

                                color: root.theme.bgSurface

                                Text {
                                    id: hintEnter

                                    anchors.centerIn: parent

                                    text: "⏎"

                                    color: root.theme.textMuted

                                    font.pixelSize: 10
                                    font.family: root.font
                                }
                            }

                            Text {
                                text: "copy"

                                color: root.theme.textMuted

                                font.pixelSize: 10
                                font.family: root.font

                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 4

                            Rectangle {
                                width: hintEsc.width + 8
                                height: 18
                                radius: 4

                                color: root.theme.bgSurface

                                Text {
                                    id: hintEsc

                                    anchors.centerIn: parent

                                    text: "esc"

                                    color: root.theme.textMuted

                                    font.pixelSize: 10
                                    font.family: root.font
                                }
                            }

                            Text {
                                text: "close"

                                color: root.theme.textMuted

                                font.pixelSize: 10
                                font.family: root.font

                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 4

                            Rectangle {
                                width: hintDeleteText.width + 8
                                height: 18
                                radius: 4

                                color: root.theme.bgSurface

                                Text {
                                    id: hintDeleteText

                                    anchors.centerIn: parent

                                    text: "alt+⏎"

                                    color: root.theme.textMuted

                                    font.pixelSize: 10
                                    font.family: root.font
                                }
                            }

                            Text {
                                text: "delete"

                                color: root.theme.textMuted

                                font.pixelSize: 10
                                font.family: root.font

                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            spacing: 4

                            Rectangle {
                                width: hintImagesText.width + 8
                                height: 18
                                radius: 4

                                color: root.theme.bgSurface

                                Text {
                                    id: hintImagesText

                                    anchors.centerIn: parent

                                    text: "ctrl+i"

                                    color: root.theme.textMuted

                                    font.pixelSize: 10
                                    font.family: root.font
                                }
                            }

                            Text {
                                text: "images"

                                color: root.theme.textMuted

                                font.pixelSize: 10
                                font.family: root.font

                                anchors.verticalCenter: parent.verticalCenter
                            }
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
