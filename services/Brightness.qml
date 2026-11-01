pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Backlight state for the OSD. Reads the sysfs brightness file on a fast
// poll; writes happen outside the shell (the niri keys call brightnessctl),
// so every polled change pops the OSD.
Singleton {
    id: root

    property int percent: 0

    // sysfs backlight path (".../brightness"); empty means no backlight.
    property string brightnessPath: ""
    property int maxBrightness: 0
    property bool hasReadBrightness: false

    // The first sample after startup must not pop an OSD; later changes are
    // external (the niri brightness keys call brightnessctl directly).
    property bool started: false
    property int lastPercent: 0

    readonly property string icon: root.percent <= 33
        ? "brightness_low"
        : (root.percent <= 66 ? "brightness_medium" : "brightness_high")

    onPercentChanged: {
        if (!root.started || root.percent === root.lastPercent)
            return;
        root.lastPercent = root.percent;
        Osd.show(root.icon, root.percent / 100, "");
    }

    Timer {
        interval: 500
        running: true

        onTriggered: {
            root.started = true;
            root.lastPercent = root.percent;
        }
    }

    // One-shot probe for a readable sysfs backlight.
    Process {
        id: sysfsProbe

        command: [
            "sh", "-c",
            "for b in /sys/class/backlight/*; do " +
            "[ -r \"$b/brightness\" ] || continue; " +
            "m=$(cat \"$b/max_brightness\" 2>/dev/null) || continue; " +
            "[ \"$m\" -gt 0 ] 2>/dev/null || continue; " +
            "echo \"$b/brightness|$m\"; exit 0; " +
            "done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                if (parts.length < 2)
                    return;
                const max = parseInt(parts[1]);
                if (parts[0] === "" || isNaN(max) || max <= 0)
                    return;
                root.brightnessPath = parts[0];
                root.maxBrightness = max;
                brightnessFile.reload();
            }
        }
    }

    FileView {
        id: brightnessFile

        path: root.brightnessPath
        preload: false
        blockAllReads: true
        printErrors: false

        onTextChanged: {
            const value = parseInt(text().trim());
            if (isNaN(value) || root.maxBrightness <= 0)
                return;
            const p = Math.round(100 * value / root.maxBrightness);
            // The first sysfs sample is the startup baseline, not a change.
            if (!root.hasReadBrightness) {
                root.hasReadBrightness = true;
                root.lastPercent = p;
            }
            root.percent = p;
        }
    }

    Timer {
        interval: 300
        repeat: true
        running: true
        onTriggered: brightnessFile.reload()
    }

    Component.onCompleted: sysfsProbe.running = true
}
