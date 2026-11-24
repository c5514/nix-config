import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../theme-switcher"

// Input-method selector, opened from the bar's EN / あ / 中 indicator.
// A small overlay panel in the same style as the calendar and quick settings,
// placed under the indicator. Also scriptable for key bindings:
//
//   qs ipc call inputmethod next          # English -> Japanese -> Chinese -> ...
//   qs ipc call inputmethod set ja        # en | ja | zh
//
// In the panel: click, or Up/Down + Enter, or 1 / 2 / 3. Esc closes.
Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property int barHeight: 32

    // Where the bar asked for the panel: which screen, and the x of the indicator
    property string screenName: ""
    property real anchorX: 0
    property int selectedIndex: 0
    property bool open: false

    readonly property var targetScreen: Quickshell.screens.find(s => s.name === root.screenName) ?? Quickshell.screens[0]

    IpcHandler {
        target: "inputmethod"

        // Called by the bar. Clicking the indicator again closes the panel.
        function toggle(screen: string, x: int): void {
            if (root.open) {
                root.open = false;
                return;
            }
            root.screenName = screen;
            root.anchorX = x;
            root.selectedIndex = InputMethodService.modeIndex(InputMethodService.mode);
            root.open = true;
        }

        function next(): void {
            InputMethodService.next();
        }

        function set(mode: string): void {
            InputMethodService.setMode(mode);
        }
    }

    function choose(key) {
        InputMethodService.setMode(key);
        root.open = false;
    }

    // Created on open, destroyed on close: a closed panel keeps no window,
    // scene graph or item tree alive.
    LazyLoader {
        active: root.open

        PanelWindow {
            id: panel
            Component.onCompleted: {
                keys.forceActiveFocus();
            }

            // Blur only the visible card, not the whole layer.
            BackgroundEffect.blurRegion: Region {
                item: list
                radius: 12
            }

            focusable: true
            color: "transparent"
            screen: root.targetScreen

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-input-method"

            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Transparent click-catcher: clicking outside closes the panel
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    const count = InputMethodService.modes.length;
                    if (event.key === Qt.Key_Escape) {
                        root.open = false;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                        root.selectedIndex = (root.selectedIndex + 1) % count;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                        root.selectedIndex = (root.selectedIndex + count - 1) % count;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.choose(InputMethodService.modes[root.selectedIndex].key);
                    } else if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + count) {
                        root.choose(InputMethodService.modes[event.key - Qt.Key_1].key);
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
            }

            InputMethodList {
                id: list
                theme: root.theme
                font: root.font
                currentMode: InputMethodService.mode
                selectedIndex: root.selectedIndex
                x: Math.max(8, Math.min(parent.width - width - 8, root.anchorX - width / 2))
                y: root.barHeight + 6

                onHovered: index => root.selectedIndex = index
                onChosen: key => root.choose(key)
            }
        }
    }
}
