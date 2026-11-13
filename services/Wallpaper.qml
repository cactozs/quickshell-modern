pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// Wallpaper picker state. `dir` is scanned recursively for images;
// `current` comes from `awww query` at startup and is tracked as the user picks.
// Applying = `awww img <file>`, whose shim may also rerun matugen. Open state
// mirrors Notifs/LauncherState.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("QS_WALLPAPERS_DIR")
        || (Quickshell.env("HOME") + "/Pictures/Wallpapers")

    property list<string> list: []
    property string current: ""
    property bool scanning: false
    property string error: ""

    property bool shown: false
    property string screen: ""

    // Width of the morphed ribbon; Bar.qml binds to this so the panel scrim
    // (PanelScrim.qml) can cut its click-through hole without duplicating
    // the constants.
    readonly property int plateWidth: Math.min(860,
        ((Quickshell.screens.find(s => s.name === root.screen)?.width ?? 1920)
         - Theme.barSideMargin * 2) - 160)

    // Height of the morphed plate, mirrored from Bar.qml so the panel scrim
    // (PanelScrim.qml) can cut the hole to the panel itself, not the column.
    property int plateHeight: Theme.barHeight

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
        root.refresh();
    }

    function close(): void {
        root.shown = false;
    }

    function set(path: string): void {
        if (path === "")
            return;
        root.error = "";
        root.current = path;
        setProc.command = ["awww", "img", path];
        setProc.running = true;
        root.close(); // the pick is done — fold the ribbon away
    }

    function refresh(): void {
        if (ensureDir.running)
            return;
        root.scanning = true;
        scanTimeout.restart();
        ensureDir.running = true;
    }

    // Desktop drag-and-drop entry: a file:// url (DropArea.urls[0]) is copied
    // into `dir` and applied. shortcut: same-name drops overwrite the stored
    // copy — the source file stays where it was dragged from.
    function install(url: string): void {
        const urlStr = url.toString();
        if (!urlStr.startsWith("file://"))
            return;
        const src = decodeURIComponent(urlStr.slice("file://".length));
        const name = src.slice(src.lastIndexOf("/") + 1).toLowerCase();
        if (!["jpg", "jpeg", "png", "webp"].includes(name.slice(name.lastIndexOf(".") + 1)))
            return;
        ensureDir.destAfter = "";
        ensureDir.installSrc = src;
        ensureDir.installName = src.slice(src.lastIndexOf("/") + 1);
        ensureDir.running = true;
    }

    Process {
        id: ensureDir

        property string installSrc: ""
        property string installName: ""
        property string destAfter: ""

        command: ["mkdir", "-p", root.dir]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = "Could not create wallpaper folder";
                installSrc = "";
                installName = "";
                root.scanning = false;
                return;
            }
            if (installSrc !== "") {
                const dest = root.dir + "/" + installName;
                if (installSrc === dest) {
                    installSrc = "";
                    installName = "";
                    root.set(dest);
                    return;
                }
                cp.dest = dest;
                cp.command = ["cp", installSrc, dest];
                installSrc = "";
                installName = "";
                cp.running = true;
                return;
            }
            scan.running = true;
        }
    }

    Process {
        id: cp

        property string dest: ""

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && cp.dest !== "") {
                root.set(cp.dest);
                root.refresh();
            } else if (cp.dest !== "")
                root.error = "Could not copy image into wallpaper folder";
            cp.dest = "";
        }
    }

    // Recursive scan; the JS sort keeps the grid stable across rescans.
    Process {
        id: scan

        command: ["fd", "-H", "-I", "-t", "f",
                  "-e", "jpg", "-e", "jpeg", "-e", "png", "-e", "webp",
                  ".", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.trim().split("\n").filter(l => l !== "").sort();
                root.current = "";
                if (root.error.startsWith("Wallpaper scan failed"))
                    root.error = "";
                query.running = true;
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !query.running) {
                root.list = [];
                root.scanning = false;
                root.error = "Wallpaper scan failed — install fd or check the folder";
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

        onExited: (exitCode, exitStatus) => {
            root.scanning = false;
            scanTimeout.stop();
            if (exitCode !== 0)
                root.error = "awww is unavailable — start awww-daemon";
        }
    }

    // Bound loading when a missing command prevents Process.onExited from firing.
    Timer {
        id: scanTimeout

        interval: 10000
        onTriggered: {
            if (!root.scanning)
                return;
            root.scanning = false;
            root.error = "Wallpaper tools did not respond — check fd and awww";
        }
    }

    Process {
        id: setProc

        onRunningChanged: if (running) applyTimeout.restart()

        onExited: (exitCode, exitStatus) => {
            applyTimeout.stop();
            if (exitCode !== 0)
                root.error = "Could not apply wallpaper — check that awww is running";
        }
    }

    Timer {
        id: applyTimeout

        interval: 10000
        onTriggered: root.error = "Wallpaper command did not respond — check that awww is running"
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
