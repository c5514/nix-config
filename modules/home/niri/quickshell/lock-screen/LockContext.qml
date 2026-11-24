import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick

// State and authentication shared by the lock surfaces on every screen.
// Owns the PAM conversation so the password only ever travels:
// text field -> submit() -> PAM, and is not kept anywhere afterwards.
Scope {
    id: root

    // PAM service used to check the password. "login" exists on every NixOS
    // system. A dedicated service also works:
    //     security.pam.services.quickshell = {};
    // and then set this to "quickshell".
    property string pamConfig: "login"

    // false = the clock "curtain", true = the password dialog
    property bool authMode: false
    property bool busy: false
    property string errorText: ""
    property int failCount: 0
    property string pendingSecret: ""

    // Deliberately no user name here: the lock screen doesn't show who you are.
    property bool hasFace: false

    signal unlocked

    // GNOME-style: the dialog falls back to the clock after a quiet spell.
    Timer {
        id: idleTimer
        interval: 30000
        onTriggered: if (!root.busy)
            root.showCurtain()
    }

    function showLogin() {
        root.authMode = true;
        idleTimer.restart();
    }

    function showCurtain() {
        root.authMode = false;
        root.errorText = "";
        idleTimer.stop();
    }

    // Any activity on the dialog keeps it from timing out.
    function poke() {
        if (root.authMode)
            idleTimer.restart();
    }

    function reset() {
        pam.abort();
        root.pendingSecret = "";
        root.busy = false;
        root.errorText = "";
        root.authMode = false;
        idleTimer.stop();
        faceCheck.running = true;
    }

    function submit(secret) {
        if (root.busy || secret === "")
            return;
        root.busy = true;
        root.errorText = "";
        root.pendingSecret = secret;
        idleTimer.stop();
        pam.start();
    }

    PamContext {
        id: pam
        config: root.pamConfig

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(root.pendingSecret);
                root.pendingSecret = "";
            }
        }

        onCompleted: result => {
            root.pendingSecret = "";
            root.busy = false;
            if (result === PamResult.Success) {
                root.unlocked();
                return;
            }
            root.failCount++;
            if (result === PamResult.MaxTries)
                root.errorText = "Too many attempts";
            else if (result === PamResult.Error)
                root.errorText = "Authentication error";
            else
                root.errorText = "Wrong password";
            idleTimer.restart();
        }

        onError: error => console.warn("LockContext: PAM error:", error)
    }

    // Only load ~/.face if it exists, so there is no warning when it doesn't.
    Process {
        id: faceCheck
        running: true
        command: ["test", "-r", Quickshell.env("HOME") + "/.face"]
        onExited: (exitCode, exitStatus) => root.hasFace = exitCode === 0
    }
}
