import Quickshell
import Quickshell.Io
import QtQuick
import "bar"
import "app-launcher"
import "file-finder"
import "lock-screen"
import "input-method"
import "notifications"
import "theme-switcher"
import "wallpaper"
import "osd"
import "monitor-manager"
import "display-manager"
import "utils"
import "powermenu"
import "clipboard"
import "calendar"
import "audio"
import "media"
import "brightness"
import "quick-settings"
import "desktop-clock"
import "dock"

Scope {
    DesktopClock {}
    Dock {}
    Bar {
        theme: Theme
    }
    AppLauncher {
        theme: Theme
    }
    FileFinder {
        theme: Theme
    }
    LockScreen {
        theme: Theme
    }
    InputMethodMenu {
        theme: Theme
    }
    NotificationPopup {
        theme: Theme
    }
    WallpaperManager {
        theme: Theme
    }
    OSD {
        theme: Theme
    }
    MonitorManager {
        theme: Theme
    }
    DisplayManager {
        theme: Theme
    }
    Utils {
        theme: Theme
    }
    Powermenu {
        theme: Theme
    }
    Clipboard {
        theme: Theme
    }
    Calendar {
        theme: Theme
    }
    AudioInputTest {
        theme: Theme
    }
    MediaPlayerTest {
        theme: Theme
    }
    QuickSettings {
        theme: Theme
    }
}
