pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Desktop widget state: which widgets are placed, where, and which types are
// still available to add. Persisted to desktop-widgets.json.
Singleton {
    id: root

    readonly property var available: [
        { type: "clock", label: "Часы", icon: "schedule" },
        { type: "media", label: "Медиа", icon: "music_note" },
        { type: "battery", label: "Батарея", icon: "battery_full" },
        { type: "network", label: "Сеть", icon: "wifi" },
        { type: "system", label: "Система", icon: "memory" },
        { type: "weather", label: "Погода", icon: "partly_cloudy_day" }
    ]

    property var items: []
    property bool _loaded: false

    function hasType(type: string): bool {
        return root.items.some(w => w.type === type);
    }

    function availableToAdd(): var {
        return root.available.filter(w => !root.hasType(w.type));
    }

    function spec(type: string): var {
        return root.available.find(w => w.type === type) ?? null;
    }

    function defaultPos(idx: int): var {
        const col = Math.floor(idx / 4);
        const row = idx % 4;
        return { x: 40 + col * 300, y: 40 + row * 150 };
    }

    function add(type: string): void {
        if (root.hasType(type))
            return;
        const s = root.spec(type);
        if (!s)
            return;
        const pos = root.defaultPos(root.items.length);
        const item = {
            id: type + "-" + Date.now(),
            type: type,
            x: pos.x,
            y: pos.y
        };
        root.items = root.items.concat([item]);
        root._persist();
    }

    function remove(id: string): void {
        root.items = root.items.filter(w => w.id !== id);
        root._persist();
    }

    function move(id: string, x: real, y: real): void {
        const idx = root.items.findIndex(w => w.id === id);
        if (idx < 0)
            return;
        const cur = root.items[idx];
        if (Math.round(cur.x) === Math.round(x) && Math.round(cur.y) === Math.round(y))
            return;
        const next = root.items.slice();
        next[idx] = Object.assign({}, cur, { x: Math.round(x), y: Math.round(y) });
        root.items = next;
        root._persist();
    }

    function resetPosition(id: string): void {
        const idx = root.items.findIndex(w => w.id === id);
        if (idx < 0)
            return;
        const pos = root.defaultPos(idx);
        const next = root.items.slice();
        next[idx] = Object.assign({}, root.items[idx], { x: pos.x, y: pos.y });
        root.items = next;
        root._persist();
    }

    function _persist(): void {
        if (!root._loaded)
            return;
        store.setText(JSON.stringify(root.items));
    }

    FileView {
        id: store

        path: Qt.resolvedUrl("../desktop-widgets.json")

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (Array.isArray(data)) {
                    const known = root.available.map(w => w.type);
                    root.items = data.filter(w => known.includes(w?.type)).map((w, i) => ({
                        id: String(w.id ?? (w.type + "-" + i)),
                        type: w.type,
                        x: Number.isFinite(w.x) ? w.x : 40,
                        y: Number.isFinite(w.y) ? w.y : 40 + i * 140
                    }));
                }
            } catch (e) {
            }
            root._loaded = true;
        }

        onLoadFailed: {
            root._loaded = true;
        }
    }
}
