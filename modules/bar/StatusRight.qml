pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "../../style"
import "../../services"

// Right status row: the notification bell, the network icon and a custom
// battery pill.
RowLayout {
    id: root

    property string screenName: ""

    spacing: 14

    // ---- notifications ----

    Item {
        id: bell

        implicitWidth: bellRow.implicitWidth
        implicitHeight: bellRow.implicitHeight

        Row {
            id: bellRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.dnd ? "notifications_off" : "notifications"
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 17
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifs.unread > 0
                text: Notifs.unread
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Notifs.toggleCenter(root.screenName)
        }
    }

    // ---- network ----

    property bool nmcliOk: true
    property bool netQueried: false
    property string netIcon: "signal_cellular_off"

    Text {
        visible: root.nmcliOk
        Layout.alignment: Qt.AlignVCenter
        text: root.netIcon
        color: Theme.primary
        opacity: root.netIcon === "signal_cellular_off" ? 0.6 : 1
        font.family: Theme.iconFont
        font.pixelSize: 17

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    // Parse `nmcli -t` output: "wifi:connected:wlan0" style lines. Wi-Fi wins
    // over ethernet; no connected device shows the off glyph.
    function applyNetState(output: string): void {
        const connected = output.trim().split("\n")
            .filter(l => l.endsWith(":connected") || l.includes(":connected:"))
            .map(l => l.split(":")[0]);
        if (connected.includes("wifi"))
            root.netIcon = "signal_cellular_alt";
        else if (connected.includes("ethernet"))
            root.netIcon = "lan";
        else
            root.netIcon = "wifi_off";
    }

    function refreshNet(): void {
        if (netQuery.running)
            netQuery.running = false;
        netQuery.running = true;
    }

    Process {
        id: netQuery
        command: ["nmcli", "-t", "-f", "TYPE,STATE,DEVICE", "device", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.netQueried = true;
                root.applyNetState(text);
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.nmcliOk = false;
        }
    }

    // nmcli emits a line per state change; each one re-runs the one-shot query.
    Process {
        id: netMonitor
        command: ["nmcli", "monitor"]
        running: true

        stdout: SplitParser {
            onRead: () => root.refreshNet()
        }
    }

    // QProcess never emits onExited for a missing binary; if nothing answered
    // in the first seconds, assume nmcli is absent and hide the icon.
    Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: {
            if (!root.netQueried)
                root.nmcliOk = false;
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

    Text {
        visible: root.hasBattery
        Layout.alignment: Qt.AlignVCenter
        text: root.battIcon
        color: root.battLow ? Theme.error : Theme.primary
        font.family: Theme.iconFont
        font.pixelSize: 17
    }

    Component.onCompleted: refreshNet()
}
