import QtQuick

// Minimal drag/click slider built directly on MouseArea rather than
// QtQuick.Controls.Slider. QtQuick.Controls' own drag handling depends on
// a configured Controls style being available at runtime to do anything
// with pointer input beyond rendering — in Quickshell's minimal QML
// environment that wasn't dragging at all, regardless of how the external
// value binding was wired up. Handling the mouse ourselves sidesteps that
// entirely.
//
// Used the same "don't bind value: continuously" way as before: seed once,
// resync from the source only while not pressed, and let `moved(value)`
// tell the caller what to do with a live drag.
Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property bool enabled: true
    readonly property bool pressed: mouseArea.pressed

    property color trackColor: "#3a3a3a"
    property color fillColor: "#49a0e6"
    property color handleColor: "#ffffff"
    property real trackHeight: 6
    property real handleSize: 14

    signal moved(real value)

    implicitHeight: Math.max(handleSize, trackHeight)

    readonly property real _range: to - from
    readonly property real _fraction: _range > 0 ? Math.max(0, Math.min(1, (value - from) / _range)) : 0

    function _setFromX(x) {
        if (!root.enabled || root.width <= 0)
            return;
        const fraction = Math.max(0, Math.min(1, x / root.width));
        const newValue = root.from + fraction * root._range;
        root.value = newValue;
        root.moved(newValue);
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: root.enabled ? root.trackColor : Qt.darker(root.trackColor, 1.2)

        Rectangle {
            width: parent.width * root._fraction
            height: parent.height
            radius: parent.radius
            color: root.enabled ? root.fillColor : root.trackColor
        }
    }

    Rectangle {
        id: handle
        width: root.handleSize
        height: root.handleSize
        radius: width / 2
        color: root.enabled ? root.handleColor : root.trackColor
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(root.width - width, root._fraction * root.width - width / 2))
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -4 // easier to grab than the visual track alone
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => root._setFromX(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root._setFromX(mouse.x);
        }
    }
}
