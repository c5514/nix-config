import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../brightness"
import "../components"

RowLayout {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    spacing: 8

    Text {
        text: "󰃠"
        color: root.theme.accentPrimary
        font.pixelSize: 16
        font.family: root.font
        style: Text.Raised
        styleColor: "#80000000"
    }
    Slider {
        id: brightnessSlider
        Layout.fillWidth: true
        from: 0
        to: 1
        enabled: BrightnessService.ready

        trackColor: root.theme.bgHover
        fillColor: root.theme.accentPrimary
        handleColor: root.theme.textPrimary

        Component.onCompleted: value = BrightnessService.value
        Connections {
            target: BrightnessService
            function onValueChanged() {
                if (!brightnessSlider.pressed)
                    brightnessSlider.value = BrightnessService.value;
            }
        }
        onMoved: BrightnessService.setBrightness(value)
    }
    Text {
        text: BrightnessService.ready ? Math.round(BrightnessService.value * 100) + "%" : "--"
        color: root.theme.textMuted
        font.pixelSize: 11
        font.family: root.font
        Layout.preferredWidth: 32
    }
}
