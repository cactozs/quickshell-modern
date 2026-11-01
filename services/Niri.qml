pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Niri IPC bridge: workspace state from `niri msg event-stream` + one-shot
// queries. Trimmed-down port of the quickshell-old service of the same name.
Singleton {
    id: root

    // niri can be absent (first login, a compositor restart). Retry with
    // backoff instead of spawning a process every second forever; a parsed
    // event proves the stream is alive again.
    property int reconnectDelay: 1000
    readonly property int maxReconnectDelay: 10000

    // Raw workspace objects straight from niri IPC (JSON).
    property var workspaces: []

    function workspacesFor(output: string): var {
        return workspaces
            .filter(w => w.output === output)
            .sort((a, b) => a.idx - b.idx);
    }

    // niri reads a bare index against the focused output, so clicking a chip
    // on another monitor's bar must focus that monitor first.
    function focusWorkspace(idx: number, output: string): void {
        Quickshell.execDetached(["sh", "-c",
            "niri msg action focus-monitor \"$0\" && niri msg action focus-workspace \"$1\"",
            output, String(idx)]);
    }

    function handleLine(line: string): void {
        if (line === "") return;
        let ev = null;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!ev || typeof ev !== "object") return;
        root.reconnectDelay = 1000;

        if (ev.WorkspacesChanged) {
            root.workspaces = ev.WorkspacesChanged.workspaces;
        } else if (ev.WorkspaceActivated || ev.WorkspaceUrgencyChanged) {
            // The activation/urgency events carry no full state; re-query.
            root.refreshWorkspaces();
        }
    }

    function refreshWorkspaces(): void {
        if (!wsProc.running) wsProc.running = true;
    }

    function scheduleReconnect(): void {
        // onExited and the watchdog can race for one outage; restarting the
        // armed timer must not double the delay.
        if (restartTimer.running) {
            restartTimer.restart();
            return;
        }
        restartTimer.interval = root.reconnectDelay;
        restartTimer.restart();
        root.reconnectDelay = Math.min(root.reconnectDelay * 2, root.maxReconnectDelay);
    }

    Process {
        id: streamProc
        command: ["niri", "msg", "-j", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }

        onExited: root.scheduleReconnect()
        onRunningChanged: {
            if (!streamProc.running && !restartTimer.running)
                root.scheduleReconnect();
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: streamProc.running = true
    }

    // QProcess reports a failed start through its C++ error handler, not a QML
    // signal, so a missing niri would otherwise never emit onExited. This cheap
    // one-second check catches that case; it only acts when the stream is down.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (!streamProc.running && !restartTimer.running)
                root.scheduleReconnect();
        }
    }

    Process {
        id: wsProc
        command: ["niri", "msg", "-j", "workspaces"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(text);
                } catch (e) {
                    console.warn("niri workspaces parse failed:", e);
                }
            }
        }
    }

    Component.onCompleted: refreshWorkspaces()
}
