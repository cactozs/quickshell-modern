pragma ComponentBehavior: Bound

import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    readonly property bool hasBattery: UPower.displayDevice !== null
    readonly property real pct: Math.max(0, Math.min(1, UPower.displayDevice?.percentage ?? 0))
    readonly property int state: UPower.displayDevice?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: root.state === UPowerDeviceState.Charging
    readonly property bool low: root.hasBattery && !root.charging && root.pct <= 0.15
    readonly property color ringColor: !root.hasBattery ? Theme.outline
        : root.low ? Theme.error
        : root.charging ? Theme.tertiary : Theme.primary
    readonly property string battIcon: {
        if (!root.hasBattery)
            return "battery_unknown";
        if (root.charging)
            return "battery_charging_full";
        if (root.low)
            return "battery_alert";
        return ["battery_android_0", "battery_android_1", "battery_android_2", "battery_android_3",
                "battery_android_4", "battery_android_5", "battery_android_6"][Math.round(root.pct * 6)];
    }
    readonly property string stateText: {
        if (!root.hasBattery)
            return "Нет батареи";
        if (root.charging)
            return "Заряжается";
        if (root.state === UPowerDeviceState.FullyCharged)
            return "Заряжено";
        if (root.low)
            return "Низкий заряд";
        return "От батареи";
    }
    readonly property string timeText: {
        if (!root.hasBattery)
            return "";
        const seconds = root.charging ? (UPower.displayDevice?.timeToFull ?? 0)
            : (UPower.displayDevice?.timeToEmpty ?? 0);
        if (!(seconds > 0))
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        const prefix = root.charging ? "До заряда " : "Осталось ";
        return h > 0 ? prefix + h + " ч " + m + " мин" : prefix + m + " мин";
    }

    title: "Батарея"
    icon: root.battIcon
    accent: root.ringColor
    cardWidth: 300

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        WidgetRing {
            value: root.hasBattery ? root.pct : 0
            thickness: 7
            fillColor: root.ringColor
            icon: root.battIcon
            iconColor: root.ringColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.hasBattery ? Math.round(root.pct * 100) + "%" : "—"
                color: root.ringColor
                font.family: Theme.fontFamily
                font.pixelSize: 34
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: root.stateText
                color: root.low ? Theme.error : Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.timeText !== ""
                text: root.timeText
                color: Theme.outline
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }
}
