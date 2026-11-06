pragma ComponentBehavior: Bound

import QtQuick
import "../../services"
import "."

// Keyed pool of NotifCards shared by the toast column and the center list.
// A Repeater over the rebuilt notif arrays would recreate every delegate on
// each change — too fast for any Behavior to play (the same trap the
// workspace dots solve, see Workspaces.qml). Cards are pooled by their Notif
// object (a Map: object keys don't survive in a plain {} map), synced in
// place, and re-appended in model order so a new notification lands on top
// and grows in while the rest glide down.
Column {
    id: root

    property var model: []
    property bool compact: false

    // While deferred, pooled cards are torn down and not rebuilt. The notif
    // center sets this from the panel's active state so a full history
    // doesn't sit in RAM while the panel is closed.
    property bool deferSync: false

    // Notif object -> NotifCard
    property var pool: new Map()

    // The first sync (shell start, first open of the center) settles cards
    // in place; only later arrivals grow in.
    property bool primed: false

    Component {
        id: cardComp

        NotifCard {}
    }

    onModelChanged: sync()
    Component.onCompleted: sync()
    onDeferSyncChanged: {
        if (root.deferSync)
            releaseAll();
        else
            sync();
    }

    function releaseAll(): void {
        for (const [, card] of pool)
            card.destroy();
        pool.clear();
        // next open settles the whole list in place, like a fresh start
        root.primed = false;
    }

    function sync(): void {
        if (root.deferSync)
            return;
        for (let i = 0; i < model.length; i++) {
            const n = model[i];
            if (!pool.has(n)) {
                const card = cardComp.createObject(root, {
                    model: n,
                    compact: root.compact,
                    width: Qt.binding(() => root.width),
                    shown: !root.primed
                });
                pool.set(n, card);
                if (root.primed)
                    card.shown = true;
            }
        }

        // keep child order matching the model (newest on top); re-appending
        // the same order is a no-op. Exiting cards are out of the pool and
        // keep their slot while they collapse.
        for (const [, card] of pool)
            card.parent = null;
        for (const n of model)
            pool.get(n).parent = root;

        for (const [n, card] of [...pool]) {
            if (model.includes(n))
                continue;
            pool.delete(n);
            // object still alive: a toast timed out — collapse it; destroyed
            // by Notifs.dismiss/clear: drop it at once
            if (Notifs.list.includes(n) && !card.exiting)
                card.exitAnimated();
            else
                card.destroy();
        }

        root.primed = true;
    }
}
