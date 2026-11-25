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
    WlrLayershell.keyboardFocus: menu.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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

    // Wallpaper drop target.
    DropArea {
        anchors.fill: parent
        z: 0
        onDropped: drop => {
            if (drop.hasUrls)
                Wallpaper.install(drop.urls[0]);
        }
    }

    // Desktop background clicks.
    MouseArea {
        anchors.fill: parent
        z: 1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            console.log("DesktopLayer: background press", mouse.button, mouse.x, mouse.y);
            if (mouse.button === Qt.RightButton) {
                root.openDesktopMenu(mouse.x, mouse.y);
                mouse.accepted = true;
            } else if (root.menuVisible) {
                root.closeMenu();
            }
        }
    }

    Repeater {
        model: DesktopWidgets.items

        delegate: Item {
            id: widgetWrap

            required property var modelData
            readonly property string widgetType: String(modelData.type ?? "")
            readonly property string widgetId: String(modelData.id ?? "")
            property real wx: Number(modelData.x ?? 40)
            property real wy: Number(modelData.y ?? 40)
            readonly property bool dragging: dragArea.pressed && dragArea.moved

            x: wx
            y: wy
            width: loader.implicitWidth
            height: loader.implicitHeight
            z: dragging ? 10 : 2
            scale: dragging ? 1.02 : 1

            Behavior on scale {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }

            onModelDataChanged: {
                if (dragArea.pressed && dragArea.moved)
                    return;
                wx = Number(modelData.x ?? 40);
                wy = Number(modelData.y ?? 40);
            }

            Loader {
                id: loader
                sourceComponent: widgetWrap.widgetType === "clock" ? clockComp
                    : widgetWrap.widgetType === "media" ? mediaComp
                    : widgetWrap.widgetType === "battery" ? batteryComp
                    : widgetWrap.widgetType === "network" ? networkComp
                    : widgetWrap.widgetType === "system" ? systemComp
                    : widgetWrap.widgetType === "weather" ? weatherComp
                    : null
            }

            MouseArea {
                id: dragArea

                property real pressX: 0
                property real pressY: 0
                property real startWx: 0
                property real startWy: 0
                property bool moved: false

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: pressed && moved ? Qt.ClosedHandCursor : Qt.ArrowCursor

                onPressed: mouse => {
                    const p = widgetWrap.mapToItem(root.contentItem, mouse.x, mouse.y);
                    if (mouse.button === Qt.RightButton) {
                        root.openWidgetMenu(widgetWrap.widgetId, p.x, p.y);
                        mouse.accepted = true;
                        return;
                    }
                    if (root.menuVisible)
                        root.closeMenu();
                    pressX = p.x;
                    pressY = p.y;
                    startWx = widgetWrap.wx;
                    startWy = widgetWrap.wy;
                    moved = false;
                }

                onPositionChanged: mouse => {
                    if (!(pressedButtons & Qt.LeftButton))
                        return;
                    const p = widgetWrap.mapToItem(root.contentItem, mouse.x, mouse.y);
                    const dx = p.x - pressX;
                    const dy = p.y - pressY;
                    if (!moved && Math.abs(dx) < 6 && Math.abs(dy) < 6)
                        return;
                    moved = true;
                    widgetWrap.wx = Math.round(Math.max(0, Math.min(root.width - widgetWrap.width, startWx + dx)));
                    widgetWrap.wy = Math.round(Math.max(0, Math.min(root.height - widgetWrap.height, startWy + dy)));
                }

                onReleased: {
                    if (!moved)
                        return;
                    DesktopWidgets.move(widgetWrap.widgetId, widgetWrap.wx, widgetWrap.wy);
                }
            }
        }
    }

    Component { id: clockComp; ClockWidget {} }
    Component { id: mediaComp; MediaWidget {} }
    Component { id: batteryComp; BatteryWidget {} }
    Component { id: networkComp; NetworkWidget {} }
    Component { id: systemComp; SystemWidget {} }
    Component { id: weatherComp; WeatherWidget {} }

    Rectangle {
        id: menu

        readonly property var addOptions: root.menuMode === "desktop" ? DesktopWidgets.availableToAdd() : []
        readonly property bool emptyDesktop: root.menuMode === "desktop" && addOptions.length === 0
        readonly property var menuItem: DesktopWidgets.items.find(w => w.id === root.menuWidgetId) ?? null
        readonly property var menuSpec: menuItem ? DesktopWidgets.spec(menuItem.type) : null
        readonly property int menuWidth: 230

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
                width: parent.width
                leftPadding: 10
                rightPadding: 10
                topPadding: 6
                bottomPadding: 4
                text: root.menuMode === "desktop" ? "Виджеты" : (menu.menuSpec?.label ?? "Виджет")
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Repeater {
                model: root.menuMode === "widget" ? [
                    { action: "reset", label: "Сбросить позицию", icon: "restart_alt", danger: false },
                    { action: "remove", label: "Удалить виджет", icon: "delete", danger: true }
                ] : []

                delegate: MenuRow {
                    required property var modelData
                    width: menuCol.width
                    label: modelData.label
                    icon: modelData.icon
                    danger: modelData.danger === true
                    onClicked: {
                        if (modelData.action === "reset")
                            DesktopWidgets.resetPosition(root.menuWidgetId);
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
