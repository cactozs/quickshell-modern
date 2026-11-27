pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../style"

Item {
    id: root

    property var settings: ({})
    readonly property string colorRole: String(settings.colorRole ?? "surfaceText")
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

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.clockColor
            font.family: "SF Pro Rounded"
            font.pixelSize: 144
            font.weight: Font.Bold
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            color: root.clockColor
            font.family: "SF Pro Rounded"
            font.pixelSize: 30
            font.weight: Font.Bold
        }
    }
}
