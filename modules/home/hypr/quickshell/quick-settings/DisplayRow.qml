import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme-switcher"

// Compact status + entry point. DisplayManager.qml owns all real monitor
// configuration and isn't a singleton (it's a Scope instantiated once in
// shell.qml), so this card can't bind to its live state directly. Instead
// it does its own lightweight, one-shot `hyprctl monitors -j` just for a
// count — read-only, fired once when Quick Settings opens (never on a
// timer, never a hotplug watcher), which is the same "query when opened"
// convention DisplayManager itself already follows. Clicking opens the
// real DisplayManager panel for actual configuration.
Rectangle {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    implicitHeight: 70
    radius: 12
    color: root.theme.bgSurface

    property int monitorCount: 0

    function refresh() {
        countProc.running = true;
    }

    Process {
        id: countProc
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitorCount = JSON.parse(text).length;
                } catch (e) {
                    root.monitorCount = 0;
                }
            }
        }
    }

    Process {
        id: openDisplays
        command: ["qs", "ipc", "call", "displays", "toggle"]
    }

    Component.onCompleted: root.refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        Text {
            text: "\uf26c"
            color: root.theme.accentPrimary
            font.pixelSize: 18
            font.family: root.font
            style: Text.Raised
            styleColor: "#80000000"
        }

        Text {
            text: "Display"
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.bold: true
            font.family: root.font
        }

        Text {
            Layout.fillWidth: true
            text: root.monitorCount === 1 ? "1 monitor" : root.monitorCount + " monitors"
            color: root.theme.textMuted
            font.pixelSize: 10
            font.family: root.font
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: openDisplays.running = true
    }
}
