pragma ComponentBehavior: Bound

import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "../../../style"

WidgetCard {
    id: root

    readonly property bool hasBattery: UPower.displayDevice !== null
    readonly property real pct: Math.max(0, Math.min(1, UPower.displayDevice?.percentage ?? 0))
    readonly property bool charging: UPower.displayDevice?.state === UPowerDeviceState.Charging
    readonly property bool low: !charging && pct <= 0.15
    readonly property string battIcon: {
        if (charging) return "battery_charging_full";
        if (low) return "battery_alert";
        return ["battery_android_0", "battery_android_1", "battery_android_2", "battery_android_3",
                "battery_android_4", "battery_android_5", "battery_android_6"][Math.round(pct * 6)];
    }

    title: "Батарея"
    icon: root.battIcon
    cardWidth: 220

    Text {
        Layout.fillWidth: true
        text: root.hasBattery ? Math.round(root.pct * 100) + "%" : "Нет батареи"
        color: root.low ? Theme.error : Qt.lighter(Theme.primary, 1.2)
        font.family: Theme.fontFamily
        font.pixelSize: 34
        font.weight: Font.DemiBold
    }

    Text {
        Layout.fillWidth: true
        text: !root.hasBattery ? "Устройство без батареи"
            : root.charging ? "Заряжается"
            : root.low ? "Низкий заряд" : "От батареи"
        color: root.low ? Theme.error : Theme.surfaceVariantText
        font.family: Theme.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
