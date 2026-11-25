pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    title: "Часы"
    icon: "schedule"
    cardWidth: 230

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        Layout.fillWidth: true
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Qt.lighter(Theme.primary, 1.35)
        font.family: Theme.fontFamily
        font.pixelSize: 44
        font.weight: Font.DemiBold
    }

    Text {
        Layout.fillWidth: true
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
        color: Theme.surfaceVariantText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }
}
