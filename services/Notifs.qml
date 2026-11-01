pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Notification server + state: history list, popup toasts, DND. The toasts
// window binds to this; the history lives in the quick settings panel's
// notifications tab. History is RAM-only (max 50) and resets on reload —
// nothing on disk.
Singleton {
    id: root

    property list<Notif> list: []
    readonly property list<Notif> popups: list.filter(n => n.popup)
    readonly property int unread: list.length

    readonly property bool dnd: state.dnd

    // Index of the notifications tab in QuickSettingsPanel's tab strip —
    // must match the order there.
    readonly property int notifsTab: 5

    component Notif: QtObject {
        property var src
        property real time
        property real timeout
        property string appName
        property string appIcon
        property string image
        property string summary
        property string body
        property int urgency
        property var actions: []
        property bool popup

        readonly property bool critical: urgency === NotificationUrgency.Critical
    }

    Component {
        id: notifComp

        Notif {}
    }

    PersistentProperties {
        id: state

        reloadableId: "notifs"

        property bool dnd: false
    }

    // The manager is the quick settings panel's notifications tab: toggling
    // opens the panel on it, closes it if it's already there, or just jumps
    // to it if the panel is open elsewhere.
    function toggleCenter(screenName: string): void {
        if (QuickSettings.shown) {
            if (QuickSettings.tab === root.notifsTab)
                QuickSettings.close();
            else
                QuickSettings.tab = root.notifsTab;
            return;
        }
        QuickSettings.tab = root.notifsTab;
        QuickSettings.toggle(screenName);
    }

    function toggleDnd(): void {
        state.dnd = !state.dnd;
    }

    function dismiss(n: var): void {
        n.src?.dismiss();
        root.list = root.list.filter(x => x !== n);
        n.destroy();
    }

    function clear(): void {
        for (const n of root.list.slice())
            root.dismiss(n);
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        imageSupported: true

        onNotification: notif => {
            notif.tracked = true;
            const obj = notifComp.createObject(root, {
                src: notif,
                time: Date.now(),
                // expireTimeout is milliseconds per the spec; -1 means the
                // client didn't care, fall back to our own default.
                timeout: notif.expireTimeout > 0 ? notif.expireTimeout : 6000,
                appName: notif.appName,
                appIcon: notif.appIcon,
                image: notif.image,
                summary: notif.summary,
                body: notif.body,
                urgency: notif.urgency,
                actions: notif.actions.map(a => ({
                    text: a.text,
                    invoke: () => a.invoke()
                })),
                popup: !state.dnd || notif.urgency === NotificationUrgency.Critical
            });
            root.list = [obj, ...root.list].slice(0, 50);
        }
    }

    // Popups older than their timeout stop popping; critical ones never do.
    Timer {
        interval: 500
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            const now = Date.now();
            for (const n of root.list)
                if (n.popup && !n.critical && now - n.time > n.timeout)
                    n.popup = false;
        }
    }

    IpcHandler {
        target: "notifs"

        function toggle(): void {
            root.toggleCenter("")
        }

        function toggleOn(screenName: string): void {
            root.toggleCenter(screenName)
        }

        function close(): void {
            if (QuickSettings.tab === root.notifsTab)
                QuickSettings.close()
        }

        function clearAll(): void {
            root.clear()
        }

        function toggleDnd(): void {
            root.toggleDnd()
        }

        function listActive(): string {
            return root.list.map(n => n.summary).join("\n");
        }
    }
}
