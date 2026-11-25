pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../style"
import "widgets"

// Desktop layer: wallpaper drops, desktop widgets, and right-click widget menu.
PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell:desktop"
    WlrLayershell.keyboardFocus: menu.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property bool menuVisible: false
    property real menuX: 0
    property real menuY: 0
    property string menuMode: "desktop" // desktop | widget
    property string menuWidgetId: ""

    function closeMenu(): void {
        root.menuVisible = false;
        root.menuWidgetId = "";
        root.menuMode = "desktop";
    }

    function openDesktopMenu(x: real, y: real): void {
        root.menuMode = "desktop";
        root.menuWidgetId = "";
        root.menuX = x;
        root.menuY = y;
        root.menuVisible = true;
    }

    function openWidgetMenu(id: string, x: real, y: real): void {
        root.menuMode = "widget";
        root.menuWidgetId = id;
        root.menuX = x;
        root.menuY = y;
        root.menuVisible = true;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.openDesktopMenu(mouse.x, mouse.y);
                mouse.accepted = true;
            } else if (root.menuVisible) {
                root.closeMenu();
            }
        }
    }

    // Wallpaper drop target, kept from DesktopDrop.
    DropArea {
        anchors.fill: parent
        z: 1
        onDropped: drop => {
            if (drop.hasUrls)
                Wallpaper.install(drop.urls[0]);
        }
    }

    Repeater {
        model: DesktopWidgets.items

        delegate: Item {
            id: widgetWrap

            required property var modelData
            readonly property string widgetType: String(modelData.type ?? "")
            readonly property string widgetId: String(modelData.id ?? "")

            x: Number(modelData.x ?? 40)
            y: Number(modelData.y ?? 40)
            width: loader.implicitWidth
            height: loader.implicitHeight
            z: 2

            Loader {
                id: loader
                sourceComponent: widgetWrap.widgetType === "clock" ? clockComp
                    : widgetWrap.widgetType === "media" ? mediaComp
                    : null
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: mouse => {
                    const p = widgetWrap.mapToItem(root, mouse.x, mouse.y);
                    root.openWidgetMenu(widgetWrap.widgetId, p.x, p.y);
                    mouse.accepted = true;
                }
            }
        }
    }

    Component {
        id: clockComp
        ClockWidget {}
    }

    Component {
        id: mediaComp
        MediaWidget {}
    }

    Rectangle {
        id: menu

        readonly property var addOptions: root.menuMode === "desktop" ? DesktopWidgets.availableToAdd() : []
        readonly property bool emptyDesktop: root.menuMode === "desktop" && addOptions.length === 0
        readonly property int menuWidth: 220

        visible: root.menuVisible
        z: 20
        width: menuWidth
        height: menuCol.implicitHeight + 12
        radius: Theme.radiusMD
        color: Theme.plateStrong
        border.width: 1
        border.color: Theme.plateBorder

        x: Math.min(root.menuX, Math.max(8, root.width - width - 8))
        y: Math.min(root.menuY, Math.max(8, root.height - height - 8))

        Column {
            id: menuCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 6
            }
            spacing: 2

            Text {
                visible: root.menuMode === "desktop"
                width: parent.width
                leftPadding: 10
                rightPadding: 10
                topPadding: 6
                bottomPadding: 4
                text: "Виджеты"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Repeater {
                model: root.menuMode === "widget" ? [{ action: "remove", label: "Удалить виджет", icon: "delete" }] : []

                delegate: MenuRow {
                    required property var modelData
                    width: menuCol.width
                    label: modelData.label
                    icon: modelData.icon
                    danger: modelData.action === "remove"
                    onClicked: {
                        if (modelData.action === "remove")
                            DesktopWidgets.remove(root.menuWidgetId);
                        root.closeMenu();
                    }
                }
            }

            Repeater {
                model: root.menuMode === "desktop" ? menu.addOptions : []

                delegate: MenuRow {
                    required property var modelData
                    width: menuCol.width
                    label: "Добавить: " + modelData.label
                    icon: modelData.icon
                    onClicked: {
                        DesktopWidgets.add(modelData.type);
                        root.closeMenu();
                    }
                }
            }

            Text {
                visible: menu.emptyDesktop
                width: parent.width
                leftPadding: 10
                rightPadding: 10
                topPadding: 8
                bottomPadding: 8
                text: "Все виджеты выбраны"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }
    }

    component MenuRow: Rectangle {
        id: row

        required property string label
        property string icon: ""
        property bool danger: false
        signal clicked()

        height: 34
        radius: Theme.radiusMD
        color: rowArea.containsMouse ? (danger ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16) : Theme.surfaceContainerHigh) : "transparent"

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 8

            Text {
                visible: row.icon !== ""
                text: row.icon
                color: row.danger ? Theme.error : Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: 16
            }

            Text {
                Layout.fillWidth: true
                text: row.label
                color: row.danger ? Theme.error : Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: row.clicked()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.menuVisible
        onActivated: root.closeMenu()
    }
}
