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
                color: Notifs.unread > 0 ? Theme.onSurface : Theme.onSurfaceVariant
                font.family: Theme.iconFont
                font.pixelSize: 15
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifs.unread > 0
                text: Notifs.unread
                color: Theme.onSurfaceVariant
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
    property string netIcon: "wifi_off"

    Text {
        visible: root.nmcliOk
        Layout.alignment: Qt.AlignVCenter
        text: root.netIcon
        color: Theme.onSurfaceVariant
        opacity: root.netIcon === "wifi_off" ? 0.6 : 1
        font.family: Theme.iconFont
        font.pixelSize: 15
    }

    // Parse `nmcli -t` output: "wifi:connected:wlan0" style lines. Wi-Fi wins
    // over ethernet; no connected device shows the off glyph.
    function applyNetState(output: string): void {
        const connected = output.trim().split("\n")
            .filter(l => l.endsWith(":connected") || l.includes(":connected:"))
            .map(l => l.split(":")[0]);
        if (connected.includes("wifi"))
            root.netIcon = "wifi";
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

    Item {
        id: batt

        readonly property real pct: Math.max(0, Math.min(1, UPower.displayDevice?.percentage ?? 1))
        readonly property bool charging: UPower.displayDevice?.state === UPowerDeviceState.Charging
        readonly property bool low: !charging && pct <= 0.15

        visible: root.hasBattery
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 28
        implicitHeight: 14

        // tip
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 6
            radius: 1
            color: batt.low ? Theme.error : Theme.onSurfaceVariant
        }

        Rectangle {
            id: body

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 5
            height: parent.height
            radius: 4
            color: "transparent"
            border.width: 1.5
            border.color: batt.low ? Theme.error : Theme.onSurfaceVariant

            Rectangle {
                id: fill

                x: 2.5
                y: 2.5
                width: Math.max(0, (body.width - 5) * batt.pct)
                height: body.height - 5
                radius: 2
                color: batt.low ? Theme.error : batt.charging ? Theme.primary : Theme.onSurface

                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: batt.charging
                text: "bolt"
                color: Theme.primary
                font.family: Theme.iconFont
                font.pixelSize: 11
            }
        }
    }

    Component.onCompleted: refreshNet()
}
