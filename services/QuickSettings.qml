pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import "../style"

// Open state of the quick settings panel. Same plate-morph contract as
// LauncherState: the per-monitor bars bind to this, the one whose screen
// name matches morphs into the panel. Driven by a click on the bar's empty
// space or by `qs ipc call quicksettings toggleOn <output>`.
Singleton {
    id: root

    property bool shown: false
    property string screen: ""

    // Width of the morphed plate; Bar.qml binds to this so the panel scrim
    // (NotifCenter.qml) can cut its click-through hole without duplicating
    // the constants.
    readonly property int plateWidth: Math.min(640,
        ((Quickshell.screens.find(s => s.name === root.screen)?.width ?? 1920)
         - Theme.barSideMargin * 2) - 160)

    function toggle(screenName: string): void {
        if (root.shown) {
            root.shown = false;
            return;
        }
        // all bar plates and the notif sheet share one morph
        LauncherState.shown = false;
        Wallpaper.shown = false;
        Clipboard.shown = false;
        Notifs.shown = false;
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
        target: "quicksettings"

        function toggle(): void { root.toggle("") }
        function toggleOn(screenName: string): void { root.toggle(screenName) }
        function close(): void { root.close() }
    }
}
