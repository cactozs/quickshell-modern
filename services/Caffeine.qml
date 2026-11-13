pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool enabled: state.enabled

    function toggle(): void {
        state.enabled = !state.enabled;
    }

    PersistentProperties {
        id: state

        reloadableId: "caffeine"

        property bool enabled: false
    }

    Process {
        id: inhibit

        command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickshell", "--why=Caffeine mode", "--mode=block", "sleep", "infinity"]
        running: root.enabled

        onExited: {
            if (root.enabled)
                state.enabled = false;
        }
    }
}
