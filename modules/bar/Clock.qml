pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../style"

// Center clock: large 24-hour time, like "21:14" on the reference
// screenshots.
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
        color: Qt.lighter(Theme.primary, 1.35)
        font.family: Theme.fontFamily
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }
}
