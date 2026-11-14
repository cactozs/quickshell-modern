pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "../../style"
import "../../services"

// Right status row: the keyboard layout chip, the network icon and a custom
// battery pill. The notification center lives on behind the notifs IPC
// (`qs ipc call notifs toggleCenter`), not on the bar.
RowLayout {
    id: root

    property string screenName: ""

    spacing: 14

    // ---- keyboard layout ----

    // Same globe + short-name pair as the layout OSD; hidden until niri
    // reports layouts. Click cycles to the next layout — the switch event
    // comes back through the Niri event stream and flashes the OSD.
    Item {
        id: lang

        visible: Niri.currentLayout !== ""
        implicitWidth: langRow.implicitWidth
        implicitHeight: langRow.implicitHeight
        Layout.alignment: Qt.AlignVCenter

        Row {
            id: langRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "language"
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 17
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Niri.currentLayout.toUpperCase()
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
        }
    }

    // ---- network ----

    // State lives in the Net singleton — one `nmcli monitor` daemon serves
    // every StatusRight copy (bar + the quick settings mirror).

    Text {
        visible: Net.available
        Layout.alignment: Qt.AlignVCenter
        text: Net.icon
        color: Theme.primary
        opacity: Net.icon === "signal_cellular_off" ? 0.6 : 1
        font.family: Theme.iconFont
        font.pixelSize: 17

        Behavior on opacity {
            NumberAnimation { duration: 70; easing.type: Easing.OutCubic }
        }
    }

    // ---- battery ----

    readonly property bool hasBattery: UPower.displayDevice !== null
    readonly property real battPct: Math.max(0, Math.min(1, UPower.displayDevice?.percentage ?? 1))
    readonly property bool battCharging: UPower.displayDevice?.state === UPowerDeviceState.Charging
    readonly property bool battLow: !battCharging && battPct <= 0.15

    // battery_android_0 .. battery_android_6 tracks the charge level
    readonly property string battIcon: {
        if (battCharging) return "battery_android_full";
        if (battLow) return "battery_alert";
        return ["battery_android_0", "battery_android_1", "battery_android_2", "battery_android_3",
                "battery_android_4", "battery_android_5", "battery_android_6"][Math.round(battPct * 6)];
    }

    Row {
        visible: root.hasBattery
        Layout.alignment: Qt.AlignVCenter
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.battIcon
            color: root.battLow ? Theme.error : Theme.primary
            font.family: Theme.iconFont
            font.pixelSize: 17
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.battPct * 100) + "%"
            color: root.battLow ? Theme.error : Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
}
