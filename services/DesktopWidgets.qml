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
        { type: "media", label: "Медиа", icon: "music_note" }
    ]

    property var items: []
    property bool _loaded: false

    function hasType(type: string): bool {
        return root.items.some(w => w.type === type);
    }

    function availableToAdd(): var {
        return root.available.filter(w => !root.hasType(w.type));
    }

    function add(type: string): void {
        if (root.hasType(type))
            return;
        const spec = root.available.find(w => w.type === type);
        if (!spec)
            return;
        const idx = root.items.length;
        const item = {
            id: type + "-" + Date.now(),
            type: type,
            x: 40,
            y: 40 + idx * 140
        };
        root.items = root.items.concat([item]);
        root._persist();
    }

    function remove(id: string): void {
        root.items = root.items.filter(w => w.id !== id);
        root._persist();
    }

    function move(id: string, x: real, y: real): void {
        root.items = root.items.map(w => w.id === id ? Object.assign({}, w, { x: x, y: y }) : w);
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
