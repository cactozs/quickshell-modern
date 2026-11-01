pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Network state for the status icon, as a singleton: every StatusRight copy
// (per-monitor bar + the mirror inside quick settings) used to run its own
// `nmcli monitor` daemon (~12 MB each). One daemon serves them all.
Singleton {
    id: root

    // false = nmcli missing or broken; the icon hides.
    property bool available: true
    property bool queried: false
    property string icon: "signal_cellular_off"

    // Parse `nmcli -t` output: "wifi:connected:wlan0" style lines. Wi-Fi wins
    // over ethernet; no connected device shows the off glyph.
    function applyState(output: string): void {
        const connected = output.trim().split("\n")
            .filter(l => l.endsWith(":connected") || l.includes(":connected:"))
            .map(l => l.split(":")[0]);
        if (connected.includes("wifi"))
            root.icon = "signal_cellular_alt";
        else if (connected.includes("ethernet"))
            root.icon = "lan";
        else
            root.icon = "wifi_off";
    }

    function refresh(): void {
        if (query.running)
            query.running = false;
        query.running = true;
    }

    Process {
        id: query
        command: ["nmcli", "-t", "-f", "TYPE,STATE,DEVICE", "device", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.queried = true;
                root.applyState(text);
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.available = false;
        }
    }

    // nmcli emits a line per state change; each one re-runs the one-shot query.
    // stdbuf -oL: nmcli block-buffers stdout, so a daemon orphaned by a shell
    // kill would linger forever (~12 MB); line-buffered it dies of EPIPE on
    // the next event instead.
    Process {
        id: monitor
        command: ["stdbuf", "-oL", "nmcli", "monitor"]
        running: true

        stdout: SplitParser {
            onRead: () => root.refresh()
        }
    }

    // QProcess never emits onExited for a missing binary; if nothing answered
    // in the first seconds, assume nmcli is absent and hide the icon.
    // One-shot: a live answer makes the check moot.
    Timer {
        interval: 4000
        running: true
        onTriggered: {
            if (!root.queried)
                root.available = false;
        }
    }

    Component.onCompleted: refresh()
}
