pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import "../style"

// Clipboard history picker over cliphist — the store side already runs as
// `wl-paste --watch cliphist store` daemons from niri's autostart; this only
// lists, re-copies and deletes. `list` holds the raw `cliphist list` lines
// (id + tabs + preview) and rows are passed around verbatim: `cliphist
// decode`/`delete` parse the id out of the line themselves. Open state
// mirrors LauncherState/Wallpaper.
Singleton {
    id: root

    property list<string> list: []
    property bool shown: false
    property string screen: ""

    // Width of the morphed plate; Bar.qml binds to this so the panel scrim
    // (PanelScrim.qml) can cut its click-through hole without duplicating
    // the constants.
    readonly property int plateWidth: Math.min(600,
        ((Quickshell.screens.find(s => s.name === root.screen)?.width ?? 1920)
         - Theme.barSideMargin * 2) - 160)

    // Height of the morphed plate, mirrored from Bar.qml so the panel scrim
    // (PanelScrim.qml) can cut the hole to the panel itself, not the column.
    property int plateHeight: Theme.barHeight

    // Binary rows decode to one file per cliphist id here; wiped at startup
    // so ids reused after `cliphist wipe` can't show stale previews.
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/quickshell-clip"

    Component.onCompleted: Quickshell.execDetached(["rm", "-rf", root.thumbDir])

    function toggleCenter(screenName: string): void {
        if (root.shown) {
            root.shown = false;
            return;
        }
        LauncherState.shown = false;
        Wallpaper.shown = false;
        QuickSettings.shown = false;
        if (screenName !== "")
            root.screen = screenName;
        else if (root.screen === "")
            root.screen = Quickshell.screens[0]?.name ?? "";
        root.refresh();
        root.shown = true;
    }

    function close(): void {
        root.shown = false;
    }

    function refresh(): void {
        if (listProc.running)
            listProc.running = false;
        listProc.running = true;
    }

    // Re-copy a history entry and fold the panel so Ctrl+V lands in the app.
    // The line goes in as an argv element (never through the shell string),
    // so any preview text is safe to pass.
    function activate(line: string): void {
        copyProc.command = ["sh", "-c",
            'printf %s\\n "$1" | cliphist decode | wl-copy', "sh", line];
        copyProc.running = true;
        root.close();
    }

    // Delete a history entry (the X on the row / Ctrl+Z on the selection).
    function remove(line: string): void {
        delProc.command = ["sh", "-c",
            'printf %s\\n "$1" | cliphist delete', "sh", line];
        delProc.running = true;
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.trim().split("\n").filter(l => l !== "");
            }
        }
    }

    // wl-copy forks and keeps holding the selection after sh exits.
    Process {
        id: copyProc
    }

    Process {
        id: delProc

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.refresh();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void { root.toggleCenter("") }
        function toggleOn(screenName: string): void { root.toggleCenter(screenName) }
        function close(): void { root.close() }
    }
}
