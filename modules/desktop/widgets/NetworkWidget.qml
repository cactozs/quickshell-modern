pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../services"
import "../../../style"

WidgetCard {
    id: root

    readonly property string statusText: {
        if (!Net.available) return "Недоступно";
        if (Net.icon === "signal_cellular_alt") return "Wi-Fi подключён";
        if (Net.icon === "lan") return "Ethernet подключён";
        return "Нет подключения";
    }

    title: "Сеть"
    icon: Net.icon
    cardWidth: 220

    Text {
        Layout.fillWidth: true
        text: Net.icon === "wifi_off" || Net.icon === "signal_cellular_off" ? "Офлайн" : "Онлайн"
        color: Net.icon === "wifi_off" || Net.icon === "signal_cellular_off" ? Theme.surfaceVariantText : Qt.lighter(Theme.primary, 1.2)
        font.family: Theme.fontFamily
        font.pixelSize: 30
        font.weight: Font.DemiBold
    }

    Text {
        Layout.fillWidth: true
        text: root.statusText
        color: Theme.surfaceVariantText
        font.family: Theme.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
