pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import "../style"

// Visibility of the bar plates. Mod+P (`qs ipc call bar toggle`) hides them on
// every output; unmapping also releases the exclusive zone, so windows reclaim
// the space. Panels are drawn inside the bar, so opening one while hidden
// brings the bar back (see Bar.qml) and closing it hides the bar again.
Singleton {
    id: root

    property bool shown: true

    // Bar outline style, persisted in bar.json: "notch" sits flush with the top
    // edge (flare wings), "island" floats with a gap above and rounded corners
    // all around. Panels morph out of the same plate either way. The adapter
    // lives below; the root copy keeps bindings valid before it is created.
    property string persistedStyle: "notch"

    readonly property bool island: root.persistedStyle === "island"
    readonly property string style: root.island ? "island" : "notch"

    // Screen gap above the island; 0 for the notch.
    readonly property int topMargin: root.island ? Theme.barIslandMargin : 0

    function setStyle(style: string): void {
        props.style = style === "island" ? "island" : "notch";
    }

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

    FileView {
        path: Qt.resolvedUrl("../bar.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: props

            property string style: "notch"

            onStyleChanged: root.persistedStyle = style
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void { root.toggle() }
        function setStyle(style: string): void { root.setStyle(style) }
        function getStyle(): string { return root.style }
    }
}
