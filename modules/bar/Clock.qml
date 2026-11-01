pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../style"

// Center clock: large 24-hour time with a small muted date next to it, like
// "21:14  Sun, Oct 25" on the reference screenshots.
RowLayout {
    id: root

    spacing: 10

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: clock.date.toLocaleDateString(Qt.locale("en_US"), "ddd, MMM d")
        color: Theme.onSurfaceVariant
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
