pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Tracks and switches the Fcitx5 input method: English / Japanese / Chinese.
// Fcitx5 does the real work (Mozc for Japanese, Pinyin for Chinese); this just
// reads its state and sends it commands through `fcitx5-remote`.
//
// Nothing here is shown unless Fcitx5 is installed and running, so the shell
// behaves exactly as before on a machine without it.
Singleton {
    id: root

    // Fcitx5 input-method names. If one doesn't match, check what yours is
    // called with `fcitx5-remote -n` while that input method is active.
    property string japaneseIm: "mozc"
    property string chineseIm: "pinyin"
    // "English" is whichever keyboard layout is active (keyboard-us,
    // keyboard-us-altgr-intl, ...). It is remembered from Fcitx5 as soon as it
    // is seen, so your altgr-intl layout is used without naming it here.
    // This is only the fallback if Fcitx5 has never reported a keyboard.
    property string englishIm: "keyboard-us"

    property bool installed: false      // `fcitx5-remote` exists
    property bool available: false      // ...and the Fcitx5 daemon answered
    property string current: ""         // e.g. "mozc"

    // Entries of the selector menu, in cycling order.
    readonly property var modes: [
        {
            key: "en",
            glyph: "EN",
            name: "English",
            detail: "Keyboard layout"
        },
        {
            key: "ja",
            glyph: "あ",
            name: "日本語",
            detail: "Japanese (Mozc)"
        },
        {
            key: "zh",
            glyph: "中",
            name: "中文",
            detail: "Chinese (Pinyin)"
        }
    ]

    // "en" | "ja" | "zh" | "other"
    readonly property string mode: {
        if (current === "" || current.startsWith("keyboard-"))
            return "en";
        if (current === japaneseIm)
            return "ja";
        if (current === chineseIm)
            return "zh";
        return "other";
    }

    // Short text for the bar
    readonly property string label: {
        switch (mode) {
        case "en":
            return "EN";
        case "ja":
            return "あ";
        case "zh":
            return "中";
        default:
            return current.slice(0, 2).toUpperCase();
        }
    }

    function modeIndex(key) {
        const i = root.modes.findIndex(m => m.key === key);
        return i < 0 ? 0 : i;
    }

    function setMode(key) {
        let name = root.englishIm;
        if (key === "ja")
            name = root.japaneseIm;
        else if (key === "zh")
            name = root.chineseIm;
        root.switchTo(name);
    }

    // English -> Japanese -> Chinese -> English
    function next() {
        const i = root.modeIndex(root.mode);
        root.setMode(root.modes[(i + 1) % root.modes.length].key);
    }

    function switchTo(name) {
        // argv, not a shell string; the name is never interpreted.
        Quickshell.execDetached(["fcitx5-remote", "-s", name]);
        root.current = name;    // show it at once, confirmed by the next poll
        confirmTimer.restart();
    }

    // Fcitx5 can also be switched with its own hotkey (Ctrl+Space by default),
    // so the bar polls instead of assuming it knows. One tiny process a second.
    function poll() {
        if (root.installed && !currentProc.running)
            currentProc.running = true;
    }

    Process {
        id: installCheck
        running: true
        command: ["sh", "-c", "command -v fcitx5-remote >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            root.installed = exitCode === 0;
            root.poll();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.installed
        onTriggered: root.poll()
    }

    Timer {
        id: confirmTimer
        interval: 200
        onTriggered: root.poll()
    }

    Process {
        id: currentProc
        running: false
        command: ["fcitx5-remote", "-n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim();
                if (name === "") {
                    root.available = false;
                    return;
                }
                root.available = true;
                root.current = name;
                if (name.startsWith("keyboard-"))
                    root.englishIm = name;
            }
        }
    }
}
