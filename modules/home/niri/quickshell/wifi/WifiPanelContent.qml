import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme-switcher"
import "../components"

// Pure presentation over WifiService — no window, no state of its own.
// Sized to live inside Quick Settings' expandable Wi-Fi section rather
// than a full standalone panel, so the network list is capped shorter
// and scrolls instead of growing tall.
ColumnLayout {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    spacing: 10

    // The service only scans the radio while a list like this one exists.
    Component.onCompleted: WifiService.attachView()
    Component.onDestruction: WifiService.detachView()

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ToggleSwitch {
            theme: root.theme
            checked: WifiService.radioEnabled
            onToggled: WifiService.toggleRadio()
        }

        Item {
            Layout.fillWidth: true
        }

        Button {
            width: 22
            height: 22
            visible: WifiService.radioEnabled
            background: Rectangle {
                radius: 6
                color: parent.hovered ? root.theme.bgHover : "transparent"
            }
            contentItem: Text {
                text: "⟳"
                color: root.theme.textPrimary
                font.pixelSize: 16
                font.family: root.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                RotationAnimation on rotation {
                    running: WifiService.scanning
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                }
            }
            onClicked: WifiService.scanWifi()
        }
    }

    Text {
        visible: !WifiService.radioEnabled
        Layout.fillWidth: true
        text: "Wi-Fi is off."
        color: root.theme.textMuted
        font.pixelSize: 12
        font.family: root.font
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        visible: WifiService.errorMessage.length > 0
        text: WifiService.errorMessage
        color: "#e06c75"
        font.pixelSize: 11
        font.family: root.font
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // Password entry, shown when a secured/unknown network is tapped
    ColumnLayout {
        visible: WifiService.radioEnabled && WifiService.passwordPromptSsid.length > 0
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: "Password for \u201c" + WifiService.passwordPromptSsid + "\u201d"
            color: root.theme.textPrimary
            font.pixelSize: 12
            font.family: root.font
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: passwordField
                Layout.fillWidth: true
                echoMode: passwordVisibleButton.checked ? TextInput.Normal : TextInput.Password
                font.family: root.font
                placeholderText: "Enter password"
                Connections {
                    target: WifiService
                    function onPasswordPromptSsidChanged() {
                        passwordField.text = "";
                    }
                }
                onAccepted: WifiService.connectToNetwork(WifiService.passwordPromptSsid, passwordField.text)
            }

            Button {
                id: passwordVisibleButton
                checkable: true
                width: 28
                height: 28
                background: Rectangle {
                    radius: 6
                    color: parent.hovered ? root.theme.bgHover : "transparent"
                }
                contentItem: Text {
                    text: passwordVisibleButton.checked ? "" : "\ud83d\udc41"
                    color: root.theme.textPrimary
                    font.pixelSize: 12
                    font.family: root.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: "Cancel"
                font.family: root.font
                onClicked: WifiService.cancelPasswordPrompt()
            }

            Button {
                text: "Join"
                font.family: root.font
                onClicked: WifiService.connectToNetwork(WifiService.passwordPromptSsid, passwordField.text)
            }
        }
    }

    ListView {
        id: wifiListView
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 220)
        clip: true
        model: WifiService.wifiModel
        spacing: 2
        visible: WifiService.radioEnabled && WifiService.passwordPromptSsid.length === 0

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 5
            contentItem: Rectangle {
                radius: 2.5
                color: root.theme.bgHover
            }
            background: Item {}
        }

        delegate: Rectangle {
            id: networkRow
            width: wifiListView.width - 8
            height: 44
            radius: 8
            color: networkMouseArea.containsMouse ? root.theme.bgHover : "transparent"

            property bool known: WifiService.isKnown(model.ssid)
            property int bars: WifiService.signalBars(model.signal)
            property bool secure: WifiService.isSecure(model.security)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Item {
                    implicitWidth: 18
                    implicitHeight: 14
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            x: index * 5
                            width: 3
                            height: (index + 1) * 3
                            y: 14 - height
                            color: index < networkRow.bars ? root.theme.accentPrimary : root.theme.textMuted
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: model.ssid
                        color: root.theme.textPrimary
                        font.pixelSize: 13
                        font.family: root.font
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            let parts = [];
                            if (model.inUse)
                                parts.push("Connected");
                            else if (known)
                                parts.push("Saved");
                            parts.push(secure ? "Secured" : "Open");
                            return parts.join(" \u00b7 ");
                        }
                        color: root.theme.textMuted
                        font.pixelSize: 10
                        font.family: root.font
                    }
                }

                Text {
                    visible: secure
                    text: "\ud83d\udd12"
                    font.pixelSize: 11
                    color: root.theme.textMuted
                }

                Text {
                    visible: WifiService.connectingSsid === model.ssid
                    text: "\u27f3"
                    font.pixelSize: 13
                    color: root.theme.accentPrimary
                }

                Text {
                    visible: model.inUse
                    text: "\u2713"
                    font.pixelSize: 13
                    color: root.theme.accentPrimary
                }
            }

            MouseArea {
                id: networkMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: WifiService.onNetworkClicked(model.ssid, model.security, model.inUse)
            }
        }
    }

    Text {
        visible: WifiService.radioEnabled && WifiService.wifiModel.count === 0
        text: WifiService.scanning ? "Scanning\u2026" : "No networks found"
        color: root.theme.textMuted
        font.pixelSize: 12
        font.family: root.font
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
    }
}
