import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A single display's card: identity + enable switch, scale selector, layout selector.
// Stateless/presentational — all mutations are signalled up to DisplayManager,
// which owns the monitor list and talks to Hyprland.
Rectangle {
    id: card

    required property var theme
    required property string font
    required property var monitor       // one entry from DisplayManager.monitors
    required property var allMonitors   // full list, used to compute Extend/Mirror/Only state

    signal enableToggled(bool enabled)
    signal scaleSelected(real scale)
    signal extendSelected
    signal mirrorSelected
    signal onlySelected
    signal mirrorModeSelected(int w, int h, string rate)

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 28
    radius: 12
    color: card.theme.bgSurface
    border.color: card.theme.bgBorder
    border.width: 1

    readonly property bool isMirroring: (monitor.mirrorOf ?? "") !== ""
    readonly property int othersEnabledCount: (allMonitors || []).filter(m => m.name !== monitor.name && !m.disabled).length
    readonly property bool isOnly: !monitor.disabled && !isMirroring && othersEnabledCount === 0
    readonly property bool isExtend: !monitor.disabled && !isMirroring && othersEnabledCount > 0

    // Scale chips: a couple of sensible defaults, plus whatever the monitor is
    // actually running at right now so the current value is never missing.
    readonly property var scaleOptions: {
        const set = new Set(["1.00", "1.25", "1.50"]);
        set.add(((monitor.scale ?? 1) * 1).toFixed(2));
        return Array.from(set).map(parseFloat).sort((a, b) => a - b);
    }

    // Unique resolutions available on THIS monitor (own panel, not the mirror source's),
    // highest refresh rate kept per resolution. Used only in Mirror mode, so the
    // projector/external display can run its own native-friendly mode instead of
    // blindly inheriting the laptop's geometry.
    function parseModeStr(modeStr) {
        const match = (modeStr || "").match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
        if (!match)
            return null;
        return {
            w: parseInt(match[1]),
            h: parseInt(match[2]),
            rate: match[3]
        };
    }
    readonly property var resolutionOptions: {
        const byRes = {};
        for (const modeStr of monitor.availableModes || []) {
            const p = card.parseModeStr(modeStr);
            if (!p)
                continue;
            const key = `${p.w}x${p.h}`;
            const rateNum = parseFloat(p.rate);
            if (!byRes[key] || rateNum > byRes[key].rateNum)
                byRes[key] = {
                    w: p.w,
                    h: p.h,
                    rate: p.rate,
                    rateNum
                };
        }
        return Object.values(byRes).sort((a, b) => (b.w * b.h) - (a.w * a.h));
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
                        const parts = [card.monitor.name, `${card.monitor.width}×${card.monitor.height}`, `${Math.round(card.monitor.refreshRate)} Hz`, `${Math.round(card.monitor.scale * 100)}%`];
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
                    color: card.monitor.disabled ? card.theme.textMuted : card.theme.bgBase
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
                                color: parent.active ? card.theme.bgBase : card.theme.textPrimary
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
                                active: card.isExtend,
                                enabled: card.allMonitors.length > 0
                            },
                            {
                                key: "mirror",
                                icon: "󰍹 󰍹",
                                label: "Mirror",
                                active: card.isMirroring,
                                enabled: card.othersEnabledCount > 0 || card.allMonitors.length > 1
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
                                    color: modelData.active ? card.theme.bgBase : card.theme.textPrimary
                                    font {
                                        pixelSize: 12
                                        family: card.font
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                    color: modelData.active ? card.theme.bgBase : card.theme.textMuted
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
                                        card.mirrorSelected();
                                    else
                                        card.onlySelected();
                                }
                            }
                        }
                    }
                }
            }

            // Mirror resolution picker — only relevant while this display is mirroring
            // another one, since the projector's native modes rarely match the laptop's.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: card.isMirroring && card.resolutionOptions.length > 0

                Text {
                    text: "Mirror resolution (this display)"
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
                            width: label.implicitWidth + 16
                            height: 24
                            radius: 6
                            color: active ? card.theme.accentCyan : card.theme.bgBase
                            border.color: card.theme.bgBorder
                            border.width: 1

                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: `${modelData.w}×${modelData.h}`
                                color: parent.active ? card.theme.bgBase : card.theme.textPrimary
                                font {
                                    pixelSize: 10
                                    family: card.font
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.mirrorModeSelected(modelData.w, modelData.h, modelData.rate)
                            }
                        }
                    }
                }
            }
        }
    }
}


