pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool enabled: state.enabled

    property bool _loaded: false

    function toggle(): void {
        state.enabled = !state.enabled;
        root._persist();
    }

    function _persist(): void {
        if (!root._loaded)
            return;
        store.setText(JSON.stringify({ enabled: state.enabled }));
    }

    QtObject {
        id: state

        property bool enabled: false
    }

    FileView {
        id: store

        path: Qt.resolvedUrl("../caffeine.json")

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (typeof data?.enabled === "boolean")
                    state.enabled = data.enabled;
            } catch (e) {
            }
            root._loaded = true;
        }

        onLoadFailed: {
            root._loaded = true;
            root._persist();
        }
    }

    Process {
        id: inhibit

        command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickshell", "--why=Caffeine mode", "--mode=block", "sleep", "infinity"]
        running: root.enabled

        onExited: {
            if (root.enabled) {
                state.enabled = false;
                root._persist();
            }
        }
    }
}
