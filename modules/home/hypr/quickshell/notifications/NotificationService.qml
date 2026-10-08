pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property list<var> notifications: []
    property bool doNotDisturb: false
    readonly property int count: notifications.length
    property int _seqCounter: 0

    property list<var> history: []
    readonly property int unreadCount: history.filter(h => !h.read).length

    function clearHistory(): void {
        root.history = [];
    }

    function markAllRead(): void {
        root.history = root.history.map(h => Object.assign({}, h, {
                read: true
            }));
    }

    function removeHistoryEntry(id): void {
        root.history = root.history.filter(h => h.id !== id);
    }

    Component {
        id: notifDataComp
        NotificationData {}
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        keepOnReload: false

        onNotification: function (notification) {
            if (!notification.appName && !notification.summary && !notification.body && !notification.image)
                return;

            const seq = root._seqCounter++;

            root.history = [
                {
                    id: seq,
                    appName: notification.appName || "",
                    appIcon: notification.appIcon || "",
                    summary: notification.summary || "",
                    body: notification.body || "",
                    image: notification.image || "",
                    urgency: notification.urgency,
                    timestamp: Date.now(),
                    read: false
                },
                ...root.history].slice(0, 50);

            if (root.doNotDisturb)
                return;

            notification.tracked = true;

            const idStr = String(notification.id || "");
            if (idStr !== "") {
                const existing = root.notifications.find(function (n) {
                    return n.notifId === idStr;
                });
                if (existing && !existing.closed) {
                    existing.closed = true;
                    root.notifications = root.notifications.filter(function (n) {
                        return n !== existing;
                    });
                    existing.destroy();
                }
            }

            const data = notifDataComp.createObject(root, {
                notification: notification,
                seqId: String(seq)
            });

            root.notifications = [data, ...root.notifications];

            if (root.notifications.length > 5) {
                root.notifications[root.notifications.length - 1].dismiss();
            }
        }
    }

    function _remove(notifData): void {
        root.notifications = root.notifications.filter(function (n) {
            return n !== notifData;
        });
    }

    function dismiss(notifData): void {
        if (notifData)
            notifData.dismiss();
    }

    function dismissAll(): void {
        const toRemove = [...root.notifications];
        root.notifications = [];
        for (const n of toRemove) {
            if (!n.closed) {
                n.closed = true;
                if (n.notification)
                    try {
                        n.notification.dismiss();
                    } catch (e) {}
                n.destroy();
            }
        }
    }
}
