import QtQuick

Item {
    id: root

    property real value: 0
    property bool enabled: true

    signal userMoved(real value)

    implicitHeight: 24
    implicitWidth: 160

    // Keep the value in the valid volume range.
    function setFromMouse(x) {
        if (!root.enabled)
            return;

        const v = Math.max(0, Math.min(1, x / width));

        root.value = v;
        root.userMoved(v);
    }

    Rectangle {
        id: track

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        height: 6
        radius: 3
        color: root.enabled ? root.themeBgHover : root.themeBgDisabled

        Rectangle {
            width: track.width * root.value
            height: parent.height
            radius: parent.radius
            color: root.enabled ? root.themeAccent : root.themeBgDisabled
        }
    }

    Rectangle {
        id: handle

        width: 14
        height: 14
        radius: 7

        x: Math.max(0, Math.min(root.width - width, root.value * root.width - width / 2))

        anchors.verticalCenter: parent.verticalCenter

        color: root.enabled ? root.themeText : root.themeTextDisabled
    }

    MouseArea {
        anchors.fill: parent

        enabled: root.enabled
        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => root.setFromMouse(mouse.x)

        onPositionChanged: mouse => {
            if (pressed)
                root.setFromMouse(mouse.x);
        }
    }

    // These are supplied by the parent so the component doesn't need
    // to know anything about your Theme singleton.
    property color themeBgHover: "#333333"
    property color themeBgDisabled: "#252525"
    property color themeAccent: "#49A0E6"
    property color themeText: "#ffffff"
    property color themeTextDisabled: "#666666"
}
