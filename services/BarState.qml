pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io

// Visibility of the bar plates. Mod+P (`qs ipc call bar toggle`) hides them on
// every output; unmapping also releases the exclusive zone, so windows reclaim
// the space. Panels are drawn inside the bar, so opening one while hidden
// brings the bar back (see Bar.qml) and closing it hides the bar again.
Singleton {
    id: root

    property bool shown: true

    function toggle(): void {
        if (root.shown || LauncherState.shown || Wallpaper.shown
                || Clipboard.shown || QuickSettings.shown) {
            LauncherState.close();
            Wallpaper.close();
            Clipboard.close();
            QuickSettings.close();
            root.shown = false;
        } else {
            root.shown = true;
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void { root.toggle() }
    }
}
