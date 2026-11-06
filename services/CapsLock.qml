pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Caps Lock state for the OSD, polled from the kernel LED nodes (niri has no
// caps event). The glob covers every keyboard device; on = any LED lit.
// FileView reads instead of a shell fork per tick; the glob is resolved once
// at startup — shortcut: keyboards plugged in later need a shell restart.
Singleton {
    id: root

    property bool capsOn: false

    // The first sample after startup must not pop an OSD.
    property bool started: false

    // Expanded LED paths, filled by the startup probe.
    property var ledPaths: []

    Timer {
        interval: 500
        running: true
        onTriggered: root.started = true
    }

    // one-shot: expand the LED glob into concrete sysfs paths
    Process {
        id: ledProbe

        command: ["sh", "-c", "printf '%s\\n' /sys/class/leds/*::capslock/brightness"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                root.ledPaths = text.split("\n")
                    .filter(p => p !== "" && !p.includes("*"));
            }
        }
    }

    Instantiator {
        id: ledViews

        model: root.ledPaths

        FileView {
            required property string modelData

            path: modelData
            preload: false
            blockAllReads: true
            printErrors: false

            onTextChanged: root.evalLeds()
        }
    }

    // on = any LED lit
    function evalLeds(): void {
        let on = false;
        for (let i = 0; i < ledViews.count; i++) {
            const view = ledViews.objectAt(i);
            if (view && parseInt(view.text().trim()) > 0) {
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

    Timer {
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            for (let i = 0; i < ledViews.count; i++)
                ledViews.objectAt(i)?.reload();
        }
    }
}
