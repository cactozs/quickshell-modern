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

    // Tab the morphed panel shows; QuickSettingsPanel mirrors its currentTab
    // here so services/IPC can open the panel straight onto a tab.
    property int tab: 0

    // Set by the panel while its wifi password input is visible: the bar
    // grabs the keyboard only then, so niri's own binds keep working.
    property bool wantsKeyboard: false

    // Width of the morphed plate; Bar.qml binds to this so the panel scrim
    // (PanelScrim.qml) can cut its click-through hole without duplicating
    // the constants.
    readonly property int plateWidth: Math.min(640,
        ((Quickshell.screens.find(s => s.name === root.screen)?.width ?? 1920)
         - Theme.barSideMargin * 2) - 160)

    // Height of the morphed plate, mirrored from Bar.qml so the panel scrim
    // (PanelScrim.qml) can cut the hole to the panel itself, not the column.
    property int plateHeight: Theme.barHeight

    function toggle(screenName: string): void {
        if (root.shown) {
            root.shown = false;
            return;
        }
        // all bar plates share one morph
        LauncherState.shown = false;
        Wallpaper.shown = false;
        Clipboard.shown = false;
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

    // Open onto a specific tab (7 = the chip's wifi networks view); also the
    // test hook for driving views without a pointer.
    function openTab(screenName: string, i: int): void {
        if (root.shown)
            root.shown = false; // toggle() would only close it
        root.tab = i;
        root.toggle(screenName);
    }

    IpcHandler {
        target: "quicksettings"

        function toggle(): void { root.toggle("") }
        function toggleOn(screenName: string): void { root.toggle(screenName) }
        function close(): void { root.close() }
        function openTab(screenName: string, i: int): void { root.openTab(screenName, i) }
    }
}
