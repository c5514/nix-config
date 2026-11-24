import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../theme-switcher"
import "../wallpaper"

// Session lock screen (ext-session-lock) in the style of the GNOME lock
// screen, over a blurred copy of the wallpaper chosen in the wallpaper
// selector.
//
//   qs ipc call lock lock
//
// There is deliberately no IPC call to unlock: anything that could call it
// could unlock your session. The only way out is the password, checked by PAM.
// If this shell crashes while locked, the compositor stays locked.
Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    LockContext {
        id: lockContext

        onUnlocked: {
            sessionLock.locked = false;
            lockContext.reset();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.requestLock();
        }
    }

    // Refuse to lock if the password could never be checked: the PAM service
    // file has to exist, otherwise there would be no way back in.
    function requestLock() {
        if (sessionLock.locked || pamCheck.running)
            return;
        pamCheck.running = true;
    }

    Process {
        id: pamCheck
        running: false
        command: ["test", "-r", "/etc/pam.d/" + lockContext.pamConfig]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const msg = "PAM service '" + lockContext.pamConfig + "' not found in /etc/pam.d, so the screen was not locked (it could never be unlocked).";
                console.warn("LockScreen:", msg);
                Quickshell.execDetached(["notify-send", "-u", "critical", "Lock screen", msg]);
                return;
            }
            lockContext.reset();
            sessionLock.locked = true;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        // One surface per screen, created by WlSessionLock when it locks.
        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: lockContext
                theme: root.theme
                font: root.font
                wallpaper: WallpaperService.currentWallpaper
            }
        }
    }
}
