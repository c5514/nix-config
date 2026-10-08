import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../bar"

// Compact status tile, styled to match DisplayRow. Reads the battery data
// SystemInfo already polls from /sys/class/power_supply/ for the bar (2s
// timer, no dedicated battery service, no powerprofilesctl) — this tile
// adds no new process and no new polling of its own.
Rectangle {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    readonly property color batteryColor: {
        if (SystemInfo.batteryCharging)
            return root.theme.accentGreen;
        if (SystemInfo.batteryLevelRaw > 20)
            return root.theme.batteryGood;
        if (SystemInfo.batteryLevelRaw > 10)
            return root.theme.batteryWarning;
        return root.theme.batteryCritical;
    }

    readonly property string stateLabel: {
        if (SystemInfo.batteryStatus === "Full")
            return "Fully charged";
        if (SystemInfo.batteryCharging)
            return "Charging";
        return "On battery";
    }

    implicitHeight: 70
    radius: 12
    color: root.theme.bgSurface

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        Text {
            text: SystemInfo.batteryIcon
            color: root.batteryColor
            font.pixelSize: 18
            font.family: root.font
            style: Text.Raised
            styleColor: "#80000000"
        }

        Text {
            text: "Battery"
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.bold: true
            font.family: root.font
        }

        Text {
            Layout.fillWidth: true
            text: SystemInfo.batteryLevel + " \u00b7 " + root.stateLabel
            color: root.theme.textMuted
            font.pixelSize: 10
            font.family: root.font
            elide: Text.ElideRight
        }
    }
}
