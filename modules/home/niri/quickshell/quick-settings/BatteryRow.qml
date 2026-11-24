import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../bar"

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
    visible: SystemInfo.batteryPresent
    implicitHeight: 60
    radius: 12
    color: root.theme.bgSurface

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Text {
            text: SystemInfo.batteryIcon
            color: root.batteryColor
            font.pixelSize: 18
            font.family: root.font
            style: Text.Raised
            styleColor: "#80000000"
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
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
}
