pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../style"

Item {
    id: root

    property var settings: ({})
    readonly property string colorRole: String(settings.colorRole ?? "surfaceText")
    readonly property bool shadow: settings.shadow !== false
    readonly property color clockColor: {
        switch (root.colorRole) {
        case "primary":
            return Theme.primary;
        case "secondary":
            return Theme.secondary;
        case "tertiary":
            return Theme.tertiary;
        case "error":
            return Theme.error;
        case "syntaxKeyword":
            return Theme.syntaxKeyword;
        case "outline":
            return Theme.outline;
        case "inverseSurface":
            return Theme.inverseSurface;
        case "containerText":
            return Theme.containerText;
        case "surfaceVariantText":
            return Theme.surfaceVariantText;
        case "surfaceText":
        default:
            return Theme.surfaceText;
        }
    }

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: col

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 2

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: timeText.implicitWidth
            implicitHeight: timeText.implicitHeight

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 3
                visible: root.shadow
                text: timeText.text
                color: Qt.rgba(0, 0, 0, 0.35)
                font.family: "SF Pro Rounded"
                font.pixelSize: 138
                font.weight: Font.Bold
            }

            Text {
                id: timeText
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.clockColor
                font.family: "SF Pro Rounded"
                font.pixelSize: 138
                font.weight: Font.Bold
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: Theme.alpha(root.clockColor, 0.68)
            font.family: "SF Pro Rounded"
            font.pixelSize: 29
            font.weight: Font.Bold
        }
    }
}
