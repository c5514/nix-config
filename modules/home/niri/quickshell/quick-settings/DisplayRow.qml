import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme-switcher"

Rectangle {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    implicitHeight: 60
    radius: 12
    color: root.theme.bgSurface
    property int monitorCount: 0
    function refresh() {
        countProc.running = true;
    }
    Process {
        id: countProc
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.monitorCount = Array.isArray(parsed) ? parsed.length : Object.keys(parsed).length;
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
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Text {
            text: "\uf26c"
            color: root.theme.accentPrimary
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
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: openDisplays.running = true
    }
}
