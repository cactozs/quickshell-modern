pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// Wallpaper picker state. The list is a recursive scan of ~/Pictures/Wallpapers;
// `current` comes from `awww query` at startup and is tracked as the user picks.
// Applying = `awww img <file>`, whose shim also reruns matugen, so Theme.qml
// recolors the whole shell live. Open state mirrors Notifs/LauncherState.
Singleton {
    id: root

    property list<string> list: []
    property string current: ""

    property bool shown: false
    property string screen: ""

    // Width of the morphed ribbon; Bar.qml binds to this so the panel scrim
    // (PanelScrim.qml) can cut its click-through hole without duplicating
    // the constants.
    readonly property int plateWidth: Math.min(860,
        ((Quickshell.screens.find(s => s.name === root.screen)?.width ?? 1920)
         - Theme.barSideMargin * 2) - 160)

    function toggleCenter(screenName: string): void {
        if (root.shown) {
            root.shown = false;
            return;
        }
        LauncherState.shown = false;
        Clipboard.shown = false;
        QuickSettings.shown = false;
        if (screenName !== "")
            root.screen = screenName;
        else if (root.screen === "")
            root.screen = Quickshell.screens[0]?.name ?? "";
        root.shown = true;
    }

    function close(): void {
        root.shown = false;
    }

    function set(path: string): void {
        root.current = path;
        Quickshell.execDetached(["awww", "img", path]);
        root.close(); // the pick is done — fold the ribbon away
    }

    function refresh(): void {
        if (scan.running)
            scan.running = false;
        scan.running = true;
    }

    // Desktop drag-and-drop entry: a file:// url (DropArea.urls[0]) is copied
    // into ~/Pictures/Wallpapers and applied. shortcut: same-name drops
    // overwrite the stored copy — the source file stays where it was dragged
    // from. Non-file urls and non-image extensions are ignored, so a stray
    // PDF can't land in the collection.
    function install(url: string): void {
        const urlStr = url.toString();
        if (!urlStr.startsWith("file://"))
            return;
        const src = decodeURIComponent(urlStr.slice("file://".length));
        const name = src.slice(src.lastIndexOf("/") + 1).toLowerCase();
        if (!["jpg", "jpeg", "png", "webp"].includes(name.slice(name.lastIndexOf(".") + 1)))
            return;
        const dest = Quickshell.env("HOME") + "/Pictures/Wallpapers/" + src.slice(src.lastIndexOf("/") + 1);
        // dropping a file that's already in the collection: cp would fail
        // copying onto itself — just re-apply it
        if (src === dest) {
            root.set(dest);
            return;
        }
        cp.dest = dest;
        cp.command = ["cp", src, dest];
        cp.running = true;
    }

    Process {
        id: cp

        property string dest: ""

        onExited: (exitCode, exitStatus) => {
            // a failed cp (source vanished mid-drag) applies nothing
            if (exitCode === 0 && cp.dest !== "") {
                root.refresh();
                root.set(cp.dest);
            }
            cp.dest = "";
        }
    }

    // Recursive scan; the JS sort keeps the grid stable across rescans.
    Process {
        id: scan

        command: ["find", Quickshell.env("HOME") + "/Pictures/Wallpapers", "-type", "f",
                  "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png",
                  "-o", "-iname", "*.webp", ")"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.trim().split("\n").filter(l => l !== "").sort();
                root.current = "";
                query.running = true;
            }
        }
    }

    // `query` passes through the shim to the real awww; parse the first
    // "currently displaying: image: <path>" line to highlight the wallpaper.
    Process {
        id: query

        command: ["awww", "query"]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.includes("image: "));
                if (line)
                    root.current = line.slice(line.lastIndexOf("image: ") + 7).trim();
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void { root.toggleCenter("") }
        function toggleOn(screenName: string): void { root.toggleCenter(screenName) }
        function close(): void { root.close() }
        function set(path: string): void { root.set(path) }
        function refresh(): void { root.refresh() }
    }

    Component.onCompleted: refresh()
}
