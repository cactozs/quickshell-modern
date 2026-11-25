pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../style"

Rectangle {
    id: root

    implicitWidth: 220
    implicitHeight: content.implicitHeight + 28
    radius: Theme.radiusXL
    color: Theme.plate
    border.width: 1
    border.color: Theme.plateBorder

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: content

        anchors {
            fill: parent
            margins: 14
        }
        spacing: 2

        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Qt.lighter(Theme.primary, 1.35)
            font.family: Theme.fontFamily
            font.pixelSize: 42
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
}
