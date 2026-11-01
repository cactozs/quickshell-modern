pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

// Transient on-screen display shared by the volume, brightness, mic and caps
// state services: they call show(); every OsdPill window renders it and fades
// out after a short delay. value < 0 means the pill shows `label` instead of
// the level bar.
Singleton {
    id: root

    readonly property int showDuration: 1200

    property string icon: ""
    property real value: 0
    property string label: ""
    property bool shown: false

    function show(icon: string, value: real, label: string): void {
        root.icon = icon;
        root.value = value < 0 ? -1 : Math.max(0, Math.min(1, value));
        root.label = label;
        root.shown = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer

        interval: root.showDuration
        onTriggered: root.shown = false
    }
}
