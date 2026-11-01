pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Caps Lock state for the OSD, polled from the kernel LED nodes (niri has no
// caps event). The glob covers every keyboard device; on = any LED lit.
Singleton {
    id: root

    property bool capsOn: false

    // The first sample after startup must not pop an OSD.
    property bool started: false

    Timer {
        interval: 500
        running: true
        onTriggered: root.started = true
    }

    Process {
        id: ledPoll

        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness"]

        stdout: StdioCollector {
            onStreamFinished: {
                let on = false;
                for (const line of text.split("\n")) {
                    if (parseInt(line.trim()) > 0) {
                        on = true;
                        break;
                    }
                }
                if (!root.started) {
                    root.capsOn = on;
                    return;
                }
                if (on === root.capsOn)
                    return;
                root.capsOn = on;
                Osd.show("keyboard_capslock", -1, on ? "CAPS ON" : "CAPS OFF");
            }
        }
    }

    Timer {
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            if (!ledPoll.running)
                ledPoll.running = true;
        }
    }
}
