import Quickshell
import Quickshell.Io
import QtQuick
import "bar"
import "app-launcher"
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
    // Intentionally not passed a theme: the clock is visually isolated
    // from the rest of the shell and does not use Theme/Matugen.
    DesktopClock {}

    // Same isolation applies to the dock.
    Dock {}

    Bar {
        theme: Theme
    }
    AppLauncher {
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
