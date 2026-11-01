pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Default sink/source state through wpctl: `pactl subscribe` flags changes
// (including ones made outside the shell — the niri volume keys call wpctl
// directly), a coalesced `wpctl get-volume` brings fresh values, the OSD
// pops on every actual change. Deliberately not Quickshell.Services.Pipewire:
// its node events miss changes made during the first seconds after startup.
Singleton {
    id: root

    property real volume: 0
    property bool muted: false
    property bool micMuted: false

    readonly property int percent: Math.round(root.volume * 100)
    readonly property bool effectiveMuted: root.muted || root.percent === 0
    readonly property string icon: root.effectiveMuted
        ? "volume_off"
        : (root.percent < 66 ? "volume_down" : "volume_up")

    // The first sample after startup must not pop an OSD.
    property bool started: false
    property real lastVolume: -1
    property bool lastMuted: false
    property bool lastMicMuted: false

    Timer {
        interval: 500
        running: true

        onTriggered: {
            root.started = true;
            root.lastVolume = root.volume;
            root.lastMuted = root.muted;
            root.lastMicMuted = root.micMuted;
        }
    }

    // Coalesce pactl's event bursts into one query pair.
    Timer {
        id: coalesce

        interval: 30
        onTriggered: {
            volProc.running = true;
            micProc.running = true;
        }
    }

    function showSinkOsd(): void {
        if (!root.started)
            return;
        if (root.volume === root.lastVolume && root.muted === root.lastMuted)
            return;
        root.lastVolume = root.volume;
        root.lastMuted = root.muted;
        Osd.show(root.icon, root.effectiveMuted ? 0 : root.volume, "");
    }

    function showMicOsd(): void {
        if (!root.started)
            return;
        if (root.micMuted === root.lastMicMuted)
            return;
        root.lastMicMuted = root.micMuted;
        Osd.show(root.micMuted ? "mic_off" : "mic", -1, root.micMuted ? "MIC OFF" : "MIC ON");
    }

    Process {
        id: events

        // stdbuf -oL: pactl block-buffers stdout, so a daemon orphaned by a
        // shell kill would linger forever; line-buffered it dies of EPIPE on
        // the next audio event instead.
        command: ["stdbuf", "-oL", "pactl", "subscribe"]
        running: true

        stdout: SplitParser {
            onRead: coalesce.restart()
        }

        onExited: retryTimer.restart()
    }

    Timer {
        id: retryTimer

        interval: 2000
        onTriggered: events.running = true
    }

    Process {
        id: volProc

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            onStreamFinished: {
                // "Volume: 0.850" plus a " [MUTED]" suffix when muted.
                for (const line of text.split("\n")) {
                    if (line.startsWith("Volume:")) {
                        root.volume = parseFloat(line.slice(8)) || 0;
                        root.muted = line.includes("[MUTED]");
                    }
                }
                root.showSinkOsd();
            }
        }
    }

    Process {
        id: micProc

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    if (line.startsWith("Volume:"))
                        root.micMuted = line.includes("[MUTED]");
                }
                root.showMicOsd();
            }
        }
    }

    Component.onCompleted: coalesce.restart()
}
