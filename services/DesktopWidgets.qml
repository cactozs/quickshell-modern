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
        { type: "transparentClock", label: "Часы (прозрачные)", icon: "schedule" },
        { type: "media", label: "Медиа", icon: "music_note" },
        { type: "battery", label: "Батарея", icon: "battery_full" },
        { type: "network", label: "Сеть", icon: "wifi" },
        { type: "system", label: "Система", icon: "memory" },
        { type: "weather", label: "Погода", icon: "partly_cloudy_day" }
    ]

    readonly property var _colorRoles: [
        { key: "surfaceText", label: "Текст" },
        { key: "primary", label: "Основной" },
        { key: "secondary", label: "Вторичный" },
        { key: "tertiary", label: "Третичный" },
        { key: "error", label: "Ошибка" },
        { key: "syntaxKeyword", label: "Ключевой" },
        { key: "outline", label: "Контур" },
        { key: "inverseSurface", label: "Инверсный" },
        { key: "containerText", label: "Белый" },
        { key: "surfaceVariantText", label: "Приглушённый" }
    ]

    function colorRoles(): var {
        return root._colorRoles;
    }

    function defaultSettings(type: string): var {
        if (type === "transparentClock")
            return { colorRole: "surfaceText", shadow: true };
        return ({});
    }

    property var items: []
    property bool _loaded: false

    signal itemChanged(string id)

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
            y: pos.y,
            scale: 1,
            settings: root.defaultSettings(type)
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
        const nx = Math.round(x);
        const ny = Math.round(y);
        if (Math.round(cur.x) === nx && Math.round(cur.y) === ny)
            return;
        // Mutate in place to avoid Repeater recreating all delegates on drag.
        cur.x = nx;
        cur.y = ny;
        root._persist();
    }

    function resetPosition(id: string): void {
        const idx = root.items.findIndex(w => w.id === id);
        if (idx < 0)
            return;
        const pos = root.defaultPos(idx);
        const cur = root.items[idx];
        if (Math.round(cur.x) === pos.x && Math.round(cur.y) === pos.y)
            return;
        cur.x = pos.x;
        cur.y = pos.y;
        root._persist();
        root.itemChanged(id);
    }

    // Lay every widget out in a tidy shelf sized for the current screen. Widths
    // and heights are the card maxima plus room for scaled hero widgets, so a
    // reset never stacks one widget on another.
    function resetLayout(viewportWidth: real): void {
        const margin = 24;
        const gap = 24;
        const widths = {
            media: 340, system: 340, battery: 300, transparentClock: 280,
            clock: 280, weather: 280, network: 280
        };
        const heights = {
            media: 190, system: 210, battery: 190, transparentClock: 160,
            clock: 190, weather: 175, network: 160
        };
        let x = margin;
        let y = margin;
        let rowHeight = 0;
        root.items.forEach(w => {
            const scale = Number(w.scale ?? 1);
            const cw = (widths[w.type] ?? 280) * scale;
            const ch = (heights[w.type] ?? 190) * scale;
            if (x > margin && x + cw > viewportWidth - margin) {
                x = margin;
                y += rowHeight + gap;
                rowHeight = 0;
            }
            w.x = Math.round(x);
            w.y = Math.round(y);
            x += cw + gap;
            rowHeight = Math.max(rowHeight, ch);
        });
        root._persist();
        for (const w of root.items)
            root.itemChanged(w.id);
    }

    function setScale(id: string, scale: real): void {
        const idx = root.items.findIndex(w => w.id === id);
        if (idx < 0)
            return;
        const cur = root.items[idx];
        const s = Math.round(Math.max(0.7, Math.min(1.6, scale)) * 10) / 10;
        if (Number(cur.scale ?? 1) === s)
            return;
        cur.scale = s;
        root._persist();
        root.itemChanged(id);
    }

    function setSetting(id: string, key: string, value: var): void {
        const idx = root.items.findIndex(w => w.id === id);
        if (idx < 0)
            return;
        const cur = root.items[idx];
        const curSettings = (cur.settings && typeof cur.settings === "object") ? cur.settings : root.defaultSettings(cur.type);
        if (curSettings[key] === value)
            return;
        const nextSettings = Object.assign({}, curSettings);
        nextSettings[key] = value;
        cur.settings = nextSettings;
        root._persist();
        root.itemChanged(id);
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
                    root.items = data.filter(w => known.includes(w?.type)).map((w, i) => {
                        const type = String(w.type);
                        const defaults = root.defaultSettings(type);
                        const stored = (w.settings && typeof w.settings === "object") ? w.settings : ({});
                        return {
                            id: String(w.id ?? (type + "-" + i)),
                            type: type,
                            x: Number.isFinite(w.x) ? w.x : 40,
                            y: Number.isFinite(w.y) ? w.y : 40 + i * 140,
                            scale: Number.isFinite(w.scale) ? Math.round(Math.max(0.7, Math.min(1.6, w.scale)) * 10) / 10 : 1,
                            settings: Object.assign({}, defaults, stored)
                        };
                    });
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
