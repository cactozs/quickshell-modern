pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    title: "Часы"
    icon: "schedule"
    cardWidth: 280

    readonly property date now: clock.date
    readonly property real dayProgress: {
        const d = clock.date;
        return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: Qt.lighter(Theme.primary, 1.35)
            font.family: Theme.fontFamily
            font.pixelSize: 46
            font.weight: Font.DemiBold
        }

        Text {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 7
            text: Qt.formatDateTime(root.now, "ss")
            color: Theme.alpha(Theme.primary, 0.7)
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.Medium
        }
    }

    Text {
        Layout.fillWidth: true
        text: Qt.formatDateTime(root.now, "dddd, d MMMM")
        color: Theme.surfaceVariantText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Layout.topMargin: 2

        Text {
            text: "День"
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 3
            radius: 2
            color: Theme.surfaceContainerHigh

            Rectangle {
                width: parent.width * root.dayProgress
                height: parent.height
                radius: parent.radius
                color: Theme.primary
            }
        }

        Text {
            text: Math.round(root.dayProgress * 100) + "%"
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
