import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A single display's card: identity + enable switch, scale, layout (extend / mirror / only), mode.
// Stateless/presentational — all mutations are signalled up to DisplayManager,
// which owns the monitor list and talks to niri.
Rectangle {
    id: card

    required property var theme
    required property string font
    required property var monitor       // one entry from DisplayManager.monitors
    required property var allMonitors   // full list, used to compute Extend/Only state

    signal enableToggled(bool enabled)
    signal scaleSelected(real scale)
    signal extendSelected
    signal onlySelected
    signal mirrorToggled
    signal modeSelected(int w, int h, string rate)

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 28
    radius: 12
    color: card.theme.bgSurface
    border.color: card.theme.bgBorder
    border.width: 1

    readonly property int othersEnabledCount: (allMonitors || []).filter(m => m.name !== monitor.name && !m.disabled).length
    readonly property bool isOnly: !monitor.disabled && othersEnabledCount === 0
    readonly property bool isExtend: !monitor.disabled && othersEnabledCount > 0

    // Mirror (done by DisplayManager with wl-mirror). This card is the display
    // that would SHOW the mirror; the display being mirrored is the focused
    // one, so the focused display can't be a target. "" = off,
    // "starting" = window not placed yet, "active" = mirroring.
    property string mirrorState: ""
    property string mirrorNote: ""
    readonly property bool canMirror: !monitor.disabled && !monitor.focused && othersEnabledCount > 0

    // Scale chips: a couple of sensible defaults, plus whatever the monitor is
    // actually running at right now so the current value is never missing.
    readonly property var scaleOptions: {
        const set = new Set(["1.00", "1.25", "1.50", "2.00"]);
        set.add(((monitor.scale ?? 1) * 1).toFixed(2));
        return Array.from(set).map(parseFloat).sort((a, b) => a - b);
    }

    // One chip per resolution this display supports (largest first), each
    // carrying its highest refresh rate. Picking one switches to that mode.
    readonly property var resolutionOptions: {
        const byRes = {};
        for (const m of monitor.modes || []) {
            const key = `${m.w}x${m.h}`;
            if (!byRes[key] || m.rate > byRes[key].rate)
                byRes[key] = m;
        }
        return Object.values(byRes).sort((a, b) => (b.w * b.h) - (a.w * a.h)).slice(0, 10);
    }

    // Refresh rates available at the resolution currently in use.
    readonly property var refreshOptions: {
        const seen = {};
        const list = [];
        for (const m of monitor.modes || []) {
            if (m.w !== monitor.width || m.h !== monitor.height || seen[m.rateStr])
                continue;
            seen[m.rateStr] = true;
            list.push(m);
        }
        return list.sort((a, b) => b.rate - a.rate);
    }

    function formatRate(rate) {
        return parseFloat(Number(rate).toFixed(2)).toString();
    }

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 14
        }
        spacing: 10

        // Header: icon + name/description on the left, enable switch on the right
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "󰍹"
                color: card.monitor.disabled ? card.theme.textMuted : card.theme.accentPrimary
                font {
                    pixelSize: 18
                    family: card.font
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                RowLayout {
                    spacing: 6
                    Text {
                        text: card.monitor.description && card.monitor.description.length > 0 ? card.monitor.description : card.monitor.name
                        color: card.theme.textPrimary
                        elide: Text.ElideRight
                        Layout.maximumWidth: 240
                        font {
                            pixelSize: 13
                            bold: true
                            family: card.font
                        }
                    }
                    Text {
                        visible: card.monitor.focused === true
                        text: "· active"
                        color: card.theme.accentCyan
                        font {
                            pixelSize: 10
                            family: card.font
                        }
                    }
                }

                Text {
                    text: {
                        if (card.monitor.disabled)
                            return card.monitor.name + " · off";
                        const parts = [card.monitor.name, `${card.monitor.width}×${card.monitor.height}`, `${card.formatRate(card.monitor.refreshRate)} Hz`, `${Math.round(card.monitor.scale * 100)}%`];
                        return parts.join(" · ");
                    }
                    color: card.theme.textMuted
                    font {
                        pixelSize: 10
                        family: card.font
                    }
                }
            }

            // Enable / disable pill switch
            Rectangle {
                id: enableSwitch
                width: 40
                height: 22
                radius: 11
                color: card.monitor.disabled ? card.theme.bgHover : card.theme.accentGreen
                border.color: card.theme.bgBorder
                border.width: 1

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    y: 2
                    x: card.monitor.disabled ? 3 : parent.width - width - 3
                    color: card.monitor.disabled ? card.theme.textMuted : card.theme.textOnAccent
                    Behavior on x {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.enableToggled(card.monitor.disabled)
                }
            }
        }

        // Everything below only makes sense for an enabled display
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: !card.monitor.disabled
            opacity: visible ? 1 : 0

            // Scale
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Scale"
                    color: card.theme.textSecondary
                    font {
                        pixelSize: 10
                        family: card.font
                    }
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: card.scaleOptions
                        Rectangle {
                            required property real modelData
                            width: 48
                            height: 26
                            radius: 6
                            readonly property bool active: Math.abs(card.monitor.scale - modelData) < 0.01
                            color: active ? card.theme.accentPrimary : card.theme.bgBase
                            border.color: card.theme.bgBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(modelData * 100) + "%"
                                color: parent.active ? card.theme.textOnAccent : card.theme.textPrimary
                                font {
                                    pixelSize: 10
                                    bold: parent.active
                                    family: card.font
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.scaleSelected(modelData)
                            }
                        }
                    }
                }
            }

            // Layout
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Layout"
                    color: card.theme.textSecondary
                    font {
                        pixelSize: 10
                        family: card.font
                    }
                }
                Row {
                    spacing: 6

                    Repeater {
                        model: [
                            {
                                key: "extend",
                                icon: "󰍹󰍺",
                                label: "Extend",
                                active: card.isExtend && card.mirrorState === "",
                                enabled: card.allMonitors.length > 1
                            },
                            {
                                key: "mirror",
                                icon: "󰍹󰍹",
                                label: card.mirrorState === "starting" ? "Starting…" : "Mirror",
                                active: card.mirrorState !== "",
                                enabled: card.canMirror || card.mirrorState !== ""
                            },
                            {
                                key: "only",
                                icon: "󰍹",
                                label: "Only",
                                active: card.isOnly,
                                enabled: true
                            },
                        ]

                        Rectangle {
                            required property var modelData
                            width: 72
                            height: 40
                            radius: 8
                            color: modelData.active ? card.theme.accentPrimary : card.theme.bgBase
                            border.color: modelData.active ? card.theme.accentPrimary : card.theme.bgBorder
                            border.width: 1
                            opacity: modelData.enabled ? 1 : 0.4

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    color: modelData.active ? card.theme.textOnAccent : card.theme.textPrimary
                                    font {
                                        pixelSize: 12
                                        family: card.font
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    color: modelData.active ? card.theme.textOnAccent : card.theme.textMuted
                                    font {
                                        pixelSize: 9
                                        family: card.font
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: modelData.enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.key === "extend")
                                        card.extendSelected();
                                    else if (modelData.key === "mirror")
                                        card.mirrorToggled();
                                    else
                                        card.onlySelected();
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: card.mirrorNote !== ""
                    text: card.mirrorNote
                    textFormat: Text.PlainText
                    color: card.theme.accentCyan
                    font {
                        pixelSize: 10
                        family: card.font
                    }
                }
            }

            // Resolution - one chip per supported resolution, always available
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: card.resolutionOptions.length > 0

                Text {
                    text: "Resolution"
                    color: card.theme.textSecondary
                    font {
                        pixelSize: 10
                        family: card.font
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: card.resolutionOptions
                        Rectangle {
                            required property var modelData
                            readonly property bool active: modelData.w === card.monitor.width && modelData.h === card.monitor.height
                            width: resLabel.implicitWidth + 16
                            height: 24
                            radius: 6
                            color: active ? card.theme.accentCyan : card.theme.bgBase
                            border.color: card.theme.bgBorder
                            border.width: 1

                            Text {
                                id: resLabel
                                anchors.centerIn: parent
                                text: `${modelData.w}×${modelData.h}`
                                color: parent.active ? card.theme.textOnAccent : card.theme.textPrimary
                                font {
                                    pixelSize: 10
                                    family: card.font
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.modeSelected(modelData.w, modelData.h, modelData.rateStr)
                            }
                        }
                    }
                }
            }

            // Refresh rate - rates available at the current resolution
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: card.refreshOptions.length > 1

                Text {
                    text: "Refresh rate"
                    color: card.theme.textSecondary
                    font {
                        pixelSize: 10
                        family: card.font
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: card.refreshOptions
                        Rectangle {
                            required property var modelData
                            readonly property bool active: Math.abs(modelData.rate - card.monitor.refreshRate) < 0.01
                            width: rateLabel.implicitWidth + 16
                            height: 24
                            radius: 6
                            color: active ? card.theme.accentCyan : card.theme.bgBase
                            border.color: card.theme.bgBorder
                            border.width: 1

                            Text {
                                id: rateLabel
                                anchors.centerIn: parent
                                text: card.formatRate(modelData.rate) + " Hz"
                                color: parent.active ? card.theme.textOnAccent : card.theme.textPrimary
                                font {
                                    pixelSize: 10
                                    family: card.font
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.modeSelected(modelData.w, modelData.h, modelData.rateStr)
                            }
                        }
                    }
                }
            }
        }
    }
}
