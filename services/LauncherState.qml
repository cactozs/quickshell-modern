pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io

// Open state of the launcher. The per-monitor bars bind to this: the one
// whose screen name matches morphs into the launcher. Driven by the niri
// keybind (`qs ipc call launcher toggleOn <output>`) or plain IPC.
Singleton {
    id: root

    property bool shown: false
    property string screen: ""

    function toggle(screenName: string): void {
        if (root.shown) {
            root.shown = false;
            return;
        }
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

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle("") }
        function toggleOn(screenName: string): void { root.toggle(screenName) }
        function close(): void { root.close() }
    }
}
