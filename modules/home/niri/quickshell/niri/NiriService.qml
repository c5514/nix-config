pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Single source of truth for niri's window/workspace state.
//
// Bar and Dock each used to run their own `niri msg event-stream` plus two
// fetch processes per event. This keeps exactly one stream and one pair of
// fetches, and only publishes a new value when the JSON actually changed, so
// downstream bindings (dock items, workspace pills) don't re-evaluate for
// events that didn't change anything they display.
Singleton {
    id: root

    // Raw `niri msg -j windows` / `workspaces` output, parsed.
    property var windows: []
    property var workspaces: []

    property string _windowsText: ""
    property string _workspacesText: ""
    property bool _windowsAgain: false
    property bool _workspacesAgain: false

    // Events that fire constantly but change nothing either consumer shows.
    function _relevant(line) {
        if (!/Window|Workspace/.test(line))
            return false;
        if (line.startsWith("{\"WindowFocusTimestampChanged\"") || line.startsWith("{\"WorkspaceActiveWindowChanged\""))
            return false;
        return true;
    }

    function refresh() {
        if (windowsProc.running)
            root._windowsAgain = true;
        else
            windowsProc.running = true;
        if (workspacesProc.running)
            root._workspacesAgain = true;
        else
            workspacesProc.running = true;
    }

    Process {
        id: eventStream
        running: true
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                if (root._relevant(data))
                    debounce.restart();
            }
        }
        onRunningChanged: if (!running)
            restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: eventStream.running = true
    }

    Timer {
        id: debounce
        interval: 50
        onTriggered: root.refresh()
    }

    Process {
        id: windowsProc
        running: true
        command: ["niri", "msg", "-j", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === root._windowsText)
                    return;
                try {
                    const parsed = JSON.parse(text);
                    root._windowsText = text;
                    root.windows = parsed;
                } catch (e) {}
            }
        }
        onExited: {
            if (root._windowsAgain) {
                root._windowsAgain = false;
                running = true;
            }
        }
    }

    Process {
        id: workspacesProc
        running: true
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === root._workspacesText)
                    return;
                try {
                    const parsed = JSON.parse(text);
                    root._workspacesText = text;
                    root.workspaces = parsed;
                } catch (e) {}
            }
        }
        onExited: {
            if (root._workspacesAgain) {
                root._workspacesAgain = false;
                running = true;
            }
        }
    }
}
