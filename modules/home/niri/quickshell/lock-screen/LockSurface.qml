import Quickshell
import QtQuick
import QtQuick.Effects
import "../theme-switcher"
import "../bar"
import "../media"

Item {
    id: root
    required property var context
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property string wallpaper: ""
    readonly property bool authMode: context.authMode
    property bool reveal: false
    focus: true
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    function wallpaperUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    onAuthModeChanged: {
        passwordInput.forceActiveFocus();
        if (!authMode) {
            passwordInput.text = "";
            root.reveal = false;
        }
    }
    Connections {
        target: root.context
        function onFailCountChanged() {
            passwordInput.text = "";
            shake.restart();
        }
    }
    Component.onCompleted: passwordInput.forceActiveFocus()
    Rectangle {
        anchors.fill: parent
        color: "#0d0d0f"
    }
    Item {
        anchors.fill: parent
        clip: true
        Image {
            id: wallpaperImage
            anchors.fill: parent
            anchors.margins: -64
            source: root.wallpaper !== "" ? root.wallpaperUrl(root.wallpaper) : ""
            fillMode: Image.PreserveAspectCrop
            // Decode at the surface size (plus the blur margin) rather than the
            // file's native resolution; one copy of this exists per screen.
            sourceSize.width: width
            sourceSize.height: height
            asynchronous: true
            smooth: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: root.authMode ? 1.0 : 0.6
                Behavior on blur {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.authMode ? 0.4 : 0.22
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.context.showLogin()
        onPositionChanged: root.context.poke()
    }
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 18
        anchors.rightMargin: 24
        spacing: 16
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (SystemInfo.networkType === "ethernet")
                    return "󰈀";
                if (SystemInfo.networkType === "wifi")
                    return "";
                return "󰖪";
            }
            color: root.theme.textPrimary
            opacity: SystemInfo.networkType === "disconnected" ? 0.5 : 1
            font.pixelSize: 14
            font.family: root.font
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: SystemInfo.batteryPresent
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemInfo.batteryIcon
                color: root.theme.textPrimary
                font.pixelSize: 18
                font.family: root.font
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemInfo.batteryLevel
                color: root.theme.textPrimary
                font.pixelSize: 14
                font.family: root.font
            }
        }
    }
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 18
        text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
        color: root.theme.textPrimary
        font.pixelSize: 15
        font.family: root.font
        opacity: root.authMode ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }
    Item {
        id: curtain
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.authMode ? -parent.height * 0.22 : -parent.height * 0.08
        width: curtainColumn.implicitWidth
        height: curtainColumn.implicitHeight
        opacity: root.authMode ? 0 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
        Column {
            id: curtainColumn
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: "white"
                font.pixelSize: 128
                font.family: root.font
                style: Text.Raised
                styleColor: "#66000000"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                color: "white"
                font.pixelSize: 26
                font.family: root.font
                style: Text.Raised
                styleColor: "#66000000"
            }
            Item {
                width: 1
                height: 28
                visible: MediaService.hasMedia
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                visible: MediaService.hasMedia
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: MediaService.isPlaying ? "󰏤" : "󰐊"
                    color: root.theme.accentPrimary
                    font.pixelSize: 22
                    font.family: root.font
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaService.playPause()
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 420)
                    text: {
                        const artist = MediaService.artist || "";
                        const title = MediaService.title || "";
                        return artist ? artist + " - " + title : title;
                    }
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.theme.textPrimary
                    font.pixelSize: 15
                    font.family: root.font
                }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        text: "Press any key or click to unlock"
        color: root.theme.textPrimary
        opacity: root.authMode ? 0 : 0.7
        font.pixelSize: 13
        font.family: root.font

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }
    Item {
        id: dialog
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.authMode ? 0 : 50
        width: 320
        height: dialogColumn.implicitHeight
        opacity: root.authMode ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
        transform: Translate {
            id: shiftX
            x: 0
        }
        SequentialAnimation {
            id: shake
            NumberAnimation {
                target: shiftX
                property: "x"
                to: -14
                duration: 50
            }
            NumberAnimation {
                target: shiftX
                property: "x"
                to: 14
                duration: 70
            }
            NumberAnimation {
                target: shiftX
                property: "x"
                to: -9
                duration: 60
            }
            NumberAnimation {
                target: shiftX
                property: "x"
                to: 9
                duration: 60
            }
            NumberAnimation {
                target: shiftX
                property: "x"
                to: 0
                duration: 50
            }
        }
        Column {
            id: dialogColumn
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Item {
                id: avatar
                anchors.horizontalCenter: parent.horizontalCenter
                width: 104
                height: 104
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.theme.accentPrimary
                    visible: !root.context.hasFace || face.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text: "\uf007"
                        color: root.theme.textOnAccent
                        font.pixelSize: 46
                        font.family: root.font
                    }
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: root.context.hasFace ? "file://" + Quickshell.env("HOME") + "/.face" : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 256
                    sourceSize.height: 256
                    asynchronous: true
                    visible: status === Image.Ready

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: avatarMask
                    }
                }
                Item {
                    id: avatarMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                    }
                }
            }
            Rectangle {
                id: entry
                anchors.horizontalCenter: parent.horizontalCenter
                width: 300
                height: 46
                radius: height / 2
                color: root.theme.bgSurface
                border.color: passwordInput.activeFocus ? root.theme.accentPrimary : root.theme.bgBorder
                border.width: 1
                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                TextInput {
                    id: passwordInput
                    anchors.left: parent.left
                    anchors.right: eye.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 20
                    anchors.rightMargin: 6
                    color: root.theme.textPrimary
                    font.pixelSize: 15
                    font.family: root.font
                    echoMode: root.reveal ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    clip: true
                    focus: true
                    readOnly: root.context.busy
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Password"
                    Text {
                        anchors.fill: parent
                        text: "Password"
                        color: root.theme.textMuted
                        font: parent.font
                        visible: !parent.text
                        verticalAlignment: Text.AlignVCenter
                    }
                    onTextChanged: {
                        if (text.length > 0) {
                            if (!root.authMode)
                                root.context.showLogin();
                            else
                                root.context.poke();
                        }
                    }
                    Keys.onPressed: event => {
                        if (!root.authMode && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                            event.accepted = true;
                            root.context.showLogin();
                        }
                    }
                    Keys.onEscapePressed: {
                        text = "";
                        root.context.showCurtain();
                    }
                    onAccepted: {
                        const secret = text;
                        text = "";
                        root.context.submit(secret);
                    }
                }
                Text {
                    id: eye
                    anchors.right: submit.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10
                    text: root.reveal ? "\uf070" : "\uf06e"
                    color: root.theme.textMuted
                    font.pixelSize: 15
                    font.family: root.font
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.authMode
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.reveal = !root.reveal;
                            root.context.poke();
                            passwordInput.forceActiveFocus();
                        }
                    }
                }
                Rectangle {
                    id: submit
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 7
                    width: 32
                    height: 32
                    radius: 16
                    color: root.theme.accentPrimary
                    opacity: passwordInput.text.length > 0 && !root.context.busy ? 1 : 0.45
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf061"
                        color: root.theme.textOnAccent
                        font.pixelSize: 14
                        font.family: root.font
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.authMode
                        cursorShape: Qt.PointingHandCursor
                        onClicked: passwordInput.accepted()
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 18
                text: root.context.busy ? "Checking…" : root.context.errorText
                color: root.context.busy ? root.theme.textPrimary : Qt.lighter(root.theme.accentRed, 1.9)
                font.pixelSize: 13
                font.family: root.font
                style: Text.Raised
                styleColor: "#99000000"
            }
        }
    }
}
