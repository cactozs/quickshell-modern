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
    WlrLayershell.keyboardFocus: (menu.visible || root.anyWidgetDragging || root.anyWidgetPressed) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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

    readonly property int edgeInset: 7
    readonly property int snapThreshold: 8
    property bool anyWidgetDragging: false
    property bool anyWidgetPressed: false

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

    function snapCoord(value: real, size: real, total: real): real {
        let best = value;
        let bestDist = root.snapThreshold + 1;
        const targets = [value, value + size / 2, value + size];
        const lines = [root.edgeInset, total / 2, total - root.edgeInset];
        for (const t of targets) {
            for (const line of lines) {
                const dist = Math.abs(t - line);
                if (dist < bestDist) {
                    bestDist = dist;
                    best = value + (line - t);
                }
            }
        }
        return bestDist <= root.snapThreshold ? best : value;
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
            if (mouse.button === Qt.RightButton) {
                root.openDesktopMenu(mouse.x, mouse.y);
                mouse.accepted = true;
            } else if (root.menuVisible) {
                root.closeMenu();
            }
        }
    }

    Canvas {
        id: dragGrid
        anchors.fill: parent
        z: 1
        visible: root.anyWidgetDragging
        enabled: false
        opacity: 0.45

        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.18);
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 6]);
            const xs = [root.edgeInset, width / 2, width - root.edgeInset];
            const ys = [root.edgeInset, height / 2, height - root.edgeInset];
            for (const x of xs) {
                const px = Math.round(x) + 0.5;
                ctx.beginPath();
                ctx.moveTo(px, 0);
                ctx.lineTo(px, height);
                ctx.stroke();
            }
            for (const y of ys) {
                const py = Math.round(y) + 0.5;
                ctx.beginPath();
                ctx.moveTo(0, py);
                ctx.lineTo(width, py);
                ctx.stroke();
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
            property real widgetScale: Number(modelData.scale ?? 1)
            property real wx: Number(modelData.x ?? 40)
            property real wy: Number(modelData.y ?? 40)
            readonly property bool dragging: dragArea.pressed && dragArea.moved

            function syncFromModel(): void {
                // modelData is a snapshot for array models, so read the live
                // item by id; otherwise a drag followed by any menu action
                // snaps the widget back to its position at load time.
                const item = DesktopWidgets.items.find(w => w.id === widgetWrap.widgetId);
                if (!item)
                    return;
                if (!(dragArea.pressed && dragArea.moved)) {
                    wx = Number(item.x ?? 40);
                    wy = Number(item.y ?? 40);
                }
                widgetScale = Number(item.scale ?? 1);
                if (loader.item && "settings" in loader.item)
                    loader.item.settings = item.settings ?? ({});
            }

            x: wx
            y: wy
            width: loader.implicitWidth
            height: loader.implicitHeight
            z: dragging ? 10 : 2
            transformOrigin: Item.TopLeft
            scale: widgetWrap.widgetScale * (dragging ? 1.02 : 1)

            Behavior on scale {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }

            onModelDataChanged: syncFromModel()

            Connections {
                target: DesktopWidgets
                function onItemChanged(id: string): void {
                    if (id === widgetWrap.widgetId)
                        widgetWrap.syncFromModel();
                }
            }

            Rectangle {
                x: 6
                y: 10
                width: loader.width
                height: loader.height
                radius: Theme.radiusWidget
                color: Qt.rgba(0, 0, 0, 0.4)
                visible: widgetWrap.dragging
            }

            Loader {
                id: loader
                sourceComponent: widgetWrap.widgetType === "clock" ? clockComp
                    : widgetWrap.widgetType === "transparentClock" ? transparentClockComp
                    : widgetWrap.widgetType === "media" ? mediaComp
                    : widgetWrap.widgetType === "battery" ? batteryComp
                    : widgetWrap.widgetType === "network" ? networkComp
                    : widgetWrap.widgetType === "system" ? systemComp
                    : widgetWrap.widgetType === "weather" ? weatherComp
                    : null

                onLoaded: {
                    if (item && "settings" in item)
                        item.settings = widgetWrap.modelData.settings ?? ({});
                    if (item && "hovered" in item)
                        item.hovered = Qt.binding(() => dragArea.containsMouse);
                    if (item && "dragging" in item)
                        item.dragging = Qt.binding(() => widgetWrap.dragging);
                }
            }

            MouseArea {
                id: dragArea

                property real pressX: 0
                property real pressY: 0
                property real startWx: 0
                property real startWy: 0
                property bool moved: false
                property bool modSnapOff: false

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: pressed && moved ? Qt.ClosedHandCursor : Qt.SizeAllCursor

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
                    modSnapOff = (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
                    root.anyWidgetPressed = true;
                    dragArea.forceActiveFocus();
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control) {
                        modSnapOff = true;
                        event.accepted = false;
                    }
                }

                Keys.onReleased: event => {
                    if (event.isAutoRepeat)
                        return;
                    if (event.key === Qt.Key_Shift || event.key === Qt.Key_Control)
                        modSnapOff = (event.key !== Qt.Key_Shift && (event.modifiers & Qt.ShiftModifier))
                            || (event.key !== Qt.Key_Control && (event.modifiers & Qt.ControlModifier));
                }

                onPositionChanged: mouse => {
                    if (!(pressedButtons & Qt.LeftButton))
                        return;
                    const p = widgetWrap.mapToItem(root.contentItem, mouse.x, mouse.y);
                    const dx = p.x - pressX;
                    const dy = p.y - pressY;
                    if (!moved && Math.abs(dx) < 6 && Math.abs(dy) < 6)
                        return;
                    if (!moved) {
                        root.anyWidgetDragging = true;
                        dragArea.forceActiveFocus();
                    }
                    moved = true;
                    const sw = widgetWrap.width * widgetWrap.widgetScale;
                    const sh = widgetWrap.height * widgetWrap.widgetScale;
                    let nx = startWx + dx;
                    let ny = startWy + dy;
                    const snapOff = modSnapOff || (mouse.modifiers & Qt.ShiftModifier) || (mouse.modifiers & Qt.ControlModifier);
                    if (!snapOff) {
                        nx = root.snapCoord(nx, sw, root.width);
                        ny = root.snapCoord(ny, sh, root.height);
                    }
                    widgetWrap.wx = Math.round(Math.max(0, Math.min(root.width - sw, nx)));
                    widgetWrap.wy = Math.round(Math.max(0, Math.min(root.height - sh, ny)));
                }

                onReleased: {
                    if (moved)
                        DesktopWidgets.move(widgetWrap.widgetId, widgetWrap.wx, widgetWrap.wy);
                    modSnapOff = false;
                    root.anyWidgetPressed = false;
                    root.anyWidgetDragging = false;
                }

                onCanceled: {
                    modSnapOff = false;
                    root.anyWidgetPressed = false;
                    root.anyWidgetDragging = false;
                }
            }
        }
    }

    Component { id: clockComp; ClockWidget {} }
    Component { id: transparentClockComp; TransparentClockWidget {} }
    Component { id: mediaComp; MediaWidget {} }
    Component { id: batteryComp; BatteryWidget {} }
    Component { id: networkComp; NetworkWidget {} }
    Component { id: systemComp; SystemWidget {} }
    Component { id: weatherComp; WeatherWidget {} }

    Rectangle {
        id: menu

        readonly property var addOptions: root.menuMode === "desktop" ? DesktopWidgets.availableToAdd() : []
        readonly property bool emptyDesktop: root.menuMode === "desktop" && addOptions.length === 0
        property int revision: 0
        // Return a fresh object on every itemChanged so the rows re-read
        // scale/settings while the menu stays open. In-place model mutations
        // do not notify bindings otherwise.
        readonly property var menuItem: {
            menu.revision;
            const item = DesktopWidgets.items.find(w => w.id === root.menuWidgetId);
            return item ? Object.assign({}, item) : null;
        }
        readonly property var menuSpec: menuItem ? DesktopWidgets.spec(menuItem.type) : null
        readonly property bool shadowOn: menu.menuItem?.settings?.shadow !== false
        readonly property bool isTransparentClock: root.menuMode === "widget" && menu.menuItem?.type === "transparentClock"
        readonly property int menuWidth: 252

        Connections {
            target: DesktopWidgets

            function onItemChanged(id: string): void {
                if (id === root.menuWidgetId)
                    menu.revision++;
            }
        }

        visible: root.menuVisible
        z: 20
        width: menuWidth
        height: menuCol.implicitHeight + 12
        radius: 22
        color: Theme.plateStrong
        border.width: 1
        border.color: Theme.plateBorder
        scale: root.menuVisible ? 1 : 0.96
        opacity: root.menuVisible ? 1 : 0
        transformOrigin: Item.TopLeft

        Behavior on scale {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }

        x: Math.min(root.menuX, Math.max(8, root.width - width - 8))
        y: Math.min(root.menuY, Math.max(8, root.height - height - 8))

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 0.6; color: "transparent" }
            }
        }

        Rectangle {
            x: 18
            y: 0
            width: parent.width - 36
            height: 1
            color: Theme.widgetHighlight
        }

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

            Item {
                visible: root.menuMode === "widget"
                width: menuCol.width
                height: visible ? 38 : 0

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 8
                    }
                    spacing: 6

                    Text {
                        text: "Размер"
                        color: Theme.surfaceVariantText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    Item { Layout.fillWidth: true }

                    StepButton {
                        glyph: "remove"
                        onClicked: DesktopWidgets.setScale(root.menuWidgetId, Number(menu.menuItem?.scale ?? 1) - 0.1)
                    }

                    Text {
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignHCenter
                        text: Math.round(Number(menu.menuItem?.scale ?? 1) * 100) + "%"
                        color: Theme.surfaceText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }

                    StepButton {
                        glyph: "add"
                        onClicked: DesktopWidgets.setScale(root.menuWidgetId, Number(menu.menuItem?.scale ?? 1) + 0.1)
                    }
                }
            }

            MenuRow {
                visible: menu.isTransparentClock
                width: menuCol.width
                label: "Тень текста"
                icon: "shadow"
                trailingIcon: menu.shadowOn ? "check" : ""
                onClicked: DesktopWidgets.setSetting(root.menuWidgetId, "shadow", !menu.shadowOn)
            }

            Rectangle {
                visible: root.menuMode === "widget"
                x: 10
                width: parent.width - 20
                height: 1
                color: Theme.plateBorder
            }

            MenuRow {
                visible: root.menuMode === "widget"
                width: menuCol.width
                label: "Сбросить позицию"
                icon: "restart_alt"
                onClicked: {
                    DesktopWidgets.resetPosition(root.menuWidgetId);
                    root.closeMenu();
                }
            }

            MenuRow {
                visible: root.menuMode === "widget"
                width: menuCol.width
                label: "Удалить виджет"
                icon: "delete"
                danger: true
                onClicked: {
                    DesktopWidgets.remove(root.menuWidgetId);
                    root.closeMenu();
                }
            }

            Column {
                visible: menu.isTransparentClock
                width: menuCol.width
                spacing: 6
                topPadding: 4
                bottomPadding: 4

                Rectangle {
                    x: 10
                    width: parent.width - 20
                    height: 1
                    color: Theme.plateBorder
                }

                Text {
                    leftPadding: 10
                    rightPadding: 10
                    text: "Цвет"
                    color: Theme.surfaceVariantText
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                Flow {
                    x: 10
                    width: parent.width - 20
                    spacing: 9

                    Repeater {
                        model: DesktopWidgets.colorRoles()

                        delegate: Rectangle {
                            required property var modelData
                            readonly property string roleKey: String(modelData.key ?? "")
                            readonly property bool selected: String(menu.menuItem?.settings?.colorRole ?? "surfaceText") === roleKey
                            readonly property color swatchColor: {
                                switch (roleKey) {
                                case "primary": return Theme.primary;
                                case "secondary": return Theme.secondary;
                                case "tertiary": return Theme.tertiary;
                                case "error": return Theme.error;
                                case "syntaxKeyword": return Theme.syntaxKeyword;
                                case "outline": return Theme.outline;
                                case "inverseSurface": return Theme.inverseSurface;
                                case "containerText": return Theme.containerText;
                                case "surfaceVariantText": return Theme.surfaceVariantText;
                                case "surfaceText":
                                default: return Theme.surfaceText;
                                }
                            }
                            readonly property bool lightSwatch: 0.299 * swatchColor.r + 0.587 * swatchColor.g + 0.114 * swatchColor.b > 0.55

                            width: 24
                            height: 24
                            radius: 12
                            color: swatchColor
                            border.width: selected ? 2 : 1
                            border.color: selected ? Theme.containerText : Theme.plateBorder

                            Text {
                                anchors.centerIn: parent
                                visible: parent.selected
                                text: "check"
                                color: parent.lightSwatch ? "#000000" : "#ffffff"
                                font.family: Theme.iconFont
                                font.pixelSize: 14
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DesktopWidgets.setSetting(root.menuWidgetId, "colorRole", roleKey)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.menuMode === "desktop" && menu.addOptions.length > 0
                width: parent.width
                leftPadding: 10
                rightPadding: 10
                topPadding: 6
                bottomPadding: 2
                text: "Добавить"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            Repeater {
                model: root.menuMode === "desktop" ? menu.addOptions : []

                delegate: MenuRow {
                    required property var modelData
                    width: menuCol.width
                    label: modelData.label
                    icon: modelData.icon
                    onClicked: {
                        DesktopWidgets.add(modelData.type);
                        root.closeMenu();
                    }
                }
            }

            Rectangle {
                visible: root.menuMode === "desktop" && DesktopWidgets.items.length > 0
                x: 10
                width: parent.width - 20
                height: 1
                color: Theme.plateBorder
            }

            MenuRow {
                visible: root.menuMode === "desktop" && DesktopWidgets.items.length > 0
                width: menuCol.width
                label: "Сбросить раскладку"
                icon: "grid_view"
                onClicked: {
                    DesktopWidgets.resetLayout(root.width);
                    root.closeMenu();
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
        property string trailingIcon: ""
        property string trailingText: ""
        property bool danger: false
        signal clicked()

        height: 38
        radius: 10
        color: rowArea.containsMouse ? (row.danger ? Theme.alpha(Theme.error, 0.14) : Theme.surfaceContainerHigh) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 80; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 10
            }
            spacing: 8

            Rectangle {
                visible: row.icon !== ""
                width: 26
                height: 26
                radius: 8
                color: row.danger ? Theme.alpha(Theme.error, 0.12) : Theme.alpha(Theme.primary, 0.10)

                Text {
                    anchors.centerIn: parent
                    text: row.icon
                    color: row.danger ? Theme.error : Theme.primary
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                }
            }

            Text {
                Layout.fillWidth: true
                text: row.label
                color: row.danger ? Theme.error : Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                visible: row.trailingText !== ""
                text: row.trailingText
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Text {
                visible: row.trailingIcon !== ""
                text: row.trailingIcon
                color: Theme.surfaceVariantText
                font.family: Theme.iconFont
                font.pixelSize: 16
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    component StepButton: Rectangle {
        id: step

        required property string glyph
        signal clicked()

        width: 26
        height: 26
        radius: 8
        color: stepArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

        Behavior on color {
            ColorAnimation { duration: 80; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            text: step.glyph
            color: Theme.surfaceText
            font.family: Theme.iconFont
            font.pixelSize: 15
        }

        MouseArea {
            id: stepArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: step.clicked()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.menuVisible
        onActivated: root.closeMenu()
    }
}
