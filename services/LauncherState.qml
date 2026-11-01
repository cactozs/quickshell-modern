pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import "../style"

// Open state of the launcher. The per-monitor bars bind to this: the one
// whose screen name matches morphs into the launcher. Driven by the niri
// keybind (`qs ipc call launcher toggleOn <output>`) or plain IPC.
Singleton {
    id: root

    property bool shown: false
    property string screen: ""

    // Width of the morphed plate; Bar.qml binds to this so the panel scrim
    // (PanelScrim.qml) can cut its click-through hole without duplicating
    // the constants.
    readonly property int plateWidth: Math.min(860,
        ((Quickshell.screens.find(s => s.name === root.screen)?.width ?? 1920)
         - Theme.barSideMargin * 2) - 160)

    function toggle(screenName: string): void {
        if (root.shown) {
            root.shown = false;
            return;
        }
        Wallpaper.shown = false; // the two bar plates share one morph
        Clipboard.shown = false;
        QuickSettings.shown = false;
        // Empty target keeps the last used output; default to the first one.
        if (screenName !== "")
            root.screen = screenName;
        else if (root.screen === "")
            root.screen = Quickshell.screens[0]?.name ?? "";
        root.shown = true;
    }

    function close(): void {
        root.shown = false;
    }

    // Launch counts per desktop entry id, persisted so the launcher can sort
    // by how often apps are opened (ties go alphabetical in Launcher.qml).
    readonly property var counts: JSON.parse(countsJson.counts || "{}")

    function bump(entryId: string): void {
        if (entryId === "")
            return;
        const c = root.counts;
        c[entryId] = (c[entryId] ?? 0) + 1;
        countsJson.counts = JSON.stringify(c);
    }

    FileView {
        path: Qt.resolvedUrl("LauncherCounts.json")
        printErrors: false

        JsonAdapter {
            id: countsJson

            // Dynamic keys aren't supported, so the map rides in one string.
            property string counts: "{}"
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle("") }
        function toggleOn(screenName: string): void { root.toggle(screenName) }
        function close(): void { root.close() }
    }
}
