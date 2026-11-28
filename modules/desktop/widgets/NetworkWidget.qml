pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../services"
import "../../../style"

WidgetCard {
    id: root

    readonly property bool online: Net.icon === "signal_cellular_alt" || Net.icon === "lan"
    readonly property bool wifi: Net.icon === "signal_cellular_alt"
    readonly property string bigIcon: root.wifi ? "wifi" : Net.icon === "lan" ? "lan" : "wifi_off"
    readonly property string typeText: !Net.available ? "Недоступно"
        : root.wifi ? "Wi-Fi"
        : Net.icon === "lan" ? "Ethernet" : "Офлайн"
    readonly property string stateText: !Net.available ? "nmcli не отвечает"
        : root.online ? "Подключено" : "Нет подключения"
    readonly property color accentColor: root.online ? Theme.primary : Theme.outline

    title: "Сеть"
    icon: root.bigIcon
    accent: root.accentColor
    cardWidth: 280
    badge: root.online ? "Онлайн" : "Офлайн"

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Rectangle {
            width: 64
            height: 64
            radius: 20
            color: Theme.alpha(root.accentColor, 0.12)

            Text {
                anchors.centerIn: parent
                text: root.bigIcon
                color: root.accentColor
                font.family: Theme.iconFont
                font.pixelSize: 30
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.typeText
                color: root.online ? Theme.surfaceText : Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 24
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: root.online ? Theme.secondary : Theme.outline
                }

                Text {
                    Layout.fillWidth: true
                    text: root.stateText
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
    }
}
