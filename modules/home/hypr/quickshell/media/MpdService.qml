pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Minimal MPD client speaking the raw MPD line protocol directly over its
// Unix socket. There's no Quickshell.Services.Mpd module (MPD predates and
// doesn't use MPRIS/DBus — it's its own line-based text protocol), so this
// is hand-rolled using Quickshell.Io.Socket + SplitParser.
//
// Two separate connections are used, matching how real MPD clients (mpc,
// ncmpcpp, mpDris2) do it:
//   - `cmdSocket` for request/response commands (currentsong, status,
//     play/pause/next/previous).
//   - `idleSocket` permanently blocked on MPD's `idle` command, which only
//     returns when something actually changes server-side. This is what
//     gives event-driven updates with zero polling — the socket just sits
//     there until MPD itself wakes it up.
Singleton {
    id: root

    property string socketPath: "/tmp/mpd_socket"

    property bool connected: false
    property string state: "stop" // "play" | "pause" | "stop"
    property string title: ""
    property string artist: ""
    property string album: ""
    property string file: ""
    property real elapsed: 0
    property real duration: 0

    readonly property bool hasSong: title.length > 0 || file.length > 0
    readonly property bool isPlaying: state === "play"

    // ---- Position (client-side interpolation) ---------------------------
    //
    // MPD's `idle` only notifies on real changes (song, state, playlist,
    // ...), not once a second — asking it for `status` every second just
    // to animate a progress bar would be exactly the polling this is meant
    // to avoid. Instead: anchor elapsed time + wall clock whenever a real
    // status arrives, and interpolate locally between anchors while
    // playing. `_tick` exists purely so `position`'s binding has something
    // to depend on that changes once a second — reading Date.now() alone
    // inside a binding doesn't create a dependency QML can watch.
    property real _posAnchorElapsed: 0
    property double _posAnchorWallClock: 0
    property int _tick: 0

    Timer {
        interval: 1000
        repeat: true
        running: root.state === "play"
        onTriggered: root._tick++
    }

    readonly property real position: {
        const tickDependency = root._tick; // forces re-eval every second while playing
        return root.state !== "play" ? root.elapsed : root._posAnchorElapsed + (Date.now() - root._posAnchorWallClock) / 1000;
    }

    // ---- Artwork (best-effort, convention-based) -----------------------
    //
    // MPD's own artwork commands (`albumart` / `readpicture`) transfer
    // embedded art as base64 chunks over the same line protocol used
    // above — implementing that chunked binary transfer robustly is a
    // meaningfully bigger, fragile undertaking for a payoff most libraries
    // don't need. Instead: assume the common convention of a cover.jpg
    // sitting next to the album's tracks in ~/Music, which covers the
    // common case. If it's not there, the UI's own Image error handling
    // falls back to the placeholder — nothing breaks either way.
    property string homeDir: ""

    Process {
        id: _homeDirProc
        command: ["sh", "-c", "echo $HOME"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.homeDir = this.text.trim()
        }
    }

    readonly property string artworkGuess: {
        if (!file || homeDir.length === 0)
            return "";
        const idx = file.lastIndexOf("/");
        const dir = idx >= 0 ? file.slice(0, idx) : "";
        return "file://" + homeDir + "/Music/" + dir + "/cover.jpg";
    }

    // ---- Protocol helpers ---------------------------------------------

    function _parseKV(lines) {
        const obj = {};
        for (const line of lines) {
            const idx = line.indexOf(": ");
            if (idx === -1)
                continue;
            obj[line.slice(0, idx)] = line.slice(idx + 2);
        }
        return obj;
    }

    function _applyCurrentSong(lines) {
        const obj = root._parseKV(lines);
        root.title = obj["Title"] || "";
        root.artist = obj["Artist"] || "";
        root.album = obj["Album"] || "";
        root.file = obj["file"] || "";
    }

    function _applyStatus(lines) {
        const obj = root._parseKV(lines);
        root.state = obj["state"] || "stop";
        root.duration = parseFloat(obj["duration"] || "0");
        const newElapsed = parseFloat(obj["elapsed"] || "0");
        root.elapsed = newElapsed;
        root._posAnchorElapsed = newElapsed;
        root._posAnchorWallClock = Date.now();
    }

    function refresh() {
        _cmd.send("currentsong", root._applyCurrentSong);
        _cmd.send("status", root._applyStatus);
    }

    // ---- Playback controls ----------------------------------------------

    function play() {
        _cmd.send("play", () => {});
    }

    function pause() {
        _cmd.send("pause 1", () => root.refresh());
    }

    function resume() {
        _cmd.send("pause 0", () => root.refresh());
    }

    function togglePlay() {
        if (root.state === "play")
            root.pause();
        else
            root.resume();
    }

    function next() {
        _cmd.send("next", () => root.refresh());
    }

    function previous() {
        _cmd.send("previous", () => root.refresh());
    }

    // seekcur accepts fractional seconds and works whether playing or
    // paused. Refresh afterward so elapsed/duration reflect the jump
    // immediately rather than waiting for the next idle event.
    function seek(seconds) {
        _cmd.send("seekcur " + Math.max(0, seconds), () => root.refresh());
    }

    // ---- Command connection (request/response, one at a time) -----------
    //
    // MPD only allows one in-flight command per connection, so this is a
    // simple FIFO queue: send the head, wait for its terminating "OK" (or
    // "ACK ..." on error), fire its callback, then send the next.
    QtObject {
        id: _cmd
        property var queue: []
        property bool busy: false
        property bool greeted: false
        property var pendingLines: []

        function send(command, callback) {
            queue.push({
                command: command,
                callback: callback
            });
            _pump();
        }

        function _pump() {
            if (busy || queue.length === 0 || !greeted || !cmdSocket.connected)
                return;
            busy = true;
            pendingLines = [];
            cmdSocket.write(queue[0].command + "\n");
            cmdSocket.flush();
        }

        function onLine(line) {
            if (!greeted) {
                if (line.indexOf("OK MPD") === 0) {
                    greeted = true;
                    root.connected = true;
                    root.refresh();
                }
                return;
            }
            if (line === "OK" || line.indexOf("ACK") === 0) {
                const job = queue.shift();
                busy = false;
                pendingLines = [];
                if (job && job.callback)
                    job.callback(job.lines || []);
                _pump();
            } else {
                pendingLines.push(line);
                if (queue.length > 0)
                    queue[0].lines = pendingLines;
            }
        }
    }

    Socket {
        id: cmdSocket
        path: root.socketPath
        connected: true

        parser: SplitParser {
            splitMarker: "\n"
            onRead: line => _cmd.onLine(line)
        }

        onConnectedChanged: {
            if (!connected) {
                root.connected = false;
                _cmd.greeted = false;
                _cmd.busy = false;
                _cmd.queue = [];
                _reconnectTimer.restart();
            }
        }

        onError: error => {
            root.connected = false;
            _reconnectTimer.restart();
        }
    }

    Timer {
        id: _reconnectTimer
        interval: 3000
        onTriggered: {
            cmdSocket.connected = false;
            cmdSocket.connected = true;
            idleSocket.connected = false;
            idleSocket.connected = true;
        }
    }

    // ---- Idle connection (push notifications, no polling) ----------------
    QtObject {
        id: _idle
        property bool greeted: false
        property bool waiting: false

        function onLine(line) {
            if (!greeted) {
                if (line.indexOf("OK MPD") === 0) {
                    greeted = true;
                    _startIdle();
                }
                return;
            }
            if (line === "OK") {
                waiting = false;
                _startIdle();
            } else if (line.indexOf("changed:") === 0) {
                // Something changed server-side (song, playback state,
                // volume, playlist, ...) — re-sync. The idle command
                // itself terminates with its own "OK" right after this,
                // which restarts the idle loop above.
                root.refresh();
            } else if (line.indexOf("ACK") === 0) {
                waiting = false;
                _startIdle();
            }
        }

        function _startIdle() {
            if (waiting)
                return;
            waiting = true;
            idleSocket.write("idle player mixer options playlist\n");
            idleSocket.flush();
        }
    }

    Socket {
        id: idleSocket
        path: root.socketPath
        connected: true

        parser: SplitParser {
            splitMarker: "\n"
            onRead: line => _idle.onLine(line)
        }

        onConnectedChanged: {
            if (!connected) {
                _idle.greeted = false;
                _idle.waiting = false;
            }
        }
    }
}

