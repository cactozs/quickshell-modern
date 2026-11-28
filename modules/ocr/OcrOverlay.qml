pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services"
import "../../style"

// Fullscreen region selector for Ocr. The screenshot was captured by grim
// before this window mapped, so the frozen image is clean. A drag selects the
// rectangle; Ocr.select() maps it back to screenshot pixels.
PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool target: Ocr.active && Ocr.screen === modelData.name
    readonly property bool shown: root.target
        && (Ocr.phase === "select" || Ocr.phase === "ocr")
    readonly property bool selecting: Ocr.phase === "select"
    readonly property bool processing: Ocr.phase === "ocr"
    readonly property bool imageReady: image.status === Image.Ready

    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    property real startX: 0
    property real startY: 0
    property real pointerX: 0
    property real pointerY: 0
    property bool dragging: false
    property int dots: 0

    readonly property real scaleX: root.imageReady && root.width > 0
        ? image.sourceSize.width / root.width : 1
    readonly property real scaleY: root.imageReady && root.height > 0
        ? image.sourceSize.height / root.height : 1

    function clampX(value: real): real {
        return Math.max(0, Math.min(root.width, value));
    }

    function clampY(value: real): real {
        return Math.max(0, Math.min(root.height, value));
    }

    function resetSelection(): void {
        root.dragging = false;
        root.selX = 0;
        root.selY = 0;
        root.selW = 0;
        root.selH = 0;
        root.pointerX = root.width / 2;
        root.pointerY = root.height / 2;
    }

    function commitSelection(): void {
        if (!root.imageReady || root.selW < Ocr.minSelection
            || root.selH < Ocr.minSelection)
            return;
        Ocr.select(root.selX, root.selY, root.selW, root.selH,
            root.scaleX, root.scaleY);
    }

    screen: modelData
    visible: root.shown
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:ocr"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shown
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        root.resetSelection();
        if (root.visible)
            focusTimer.restart();
        else
            focusTimer.stop();
    }

    onWidthChanged: root.resetSelection()
    onHeightChanged: root.resetSelection()

    Image {
        id: image

        anchors.fill: parent
        source: root.target && (Ocr.phase === "select" || Ocr.phase === "ocr")
            && Ocr.imagePath !== "" ? "file://" + Ocr.imagePath : ""
        fillMode: Image.Stretch
        asynchronous: false
        cache: false
        smooth: true

        onStatusChanged: {
            if (status === Image.Error && Ocr.phase === "select")
                Ocr.fail("Could not load the screenshot");
        }
    }

    // Full dim until the first drag creates a cutout.
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        visible: root.selW <= 0 || root.selH <= 0
    }

    Rectangle {
        x: 0
        y: 0
        width: root.width
        height: root.selY
        color: Theme.scrim
        visible: root.selW > 0 && root.selH > 0
    }

    Rectangle {
        x: 0
        y: root.selY
        width: root.selX
        height: root.selH
        color: Theme.scrim
        visible: root.selW > 0 && root.selH > 0
    }

    Rectangle {
        x: root.selX + root.selW
        y: root.selY
        width: Math.max(0, root.width - root.selX - root.selW)
        height: root.selH
        color: Theme.scrim
        visible: root.selW > 0 && root.selH > 0
    }

    Rectangle {
        x: 0
        y: root.selY + root.selH
        width: root.width
        height: Math.max(0, root.height - root.selY - root.selH)
        color: Theme.scrim
        visible: root.selW > 0 && root.selH > 0
    }

    Rectangle {
        x: root.selX
        y: root.selY
        width: root.selW
        height: root.selH
        color: "transparent"
        border.width: 1
        border.color: Theme.primary
        visible: root.selW > 0 && root.selH > 0
    }

    Repeater {
        model: [
            { x: 0, y: 0 },
            { x: 1, y: 0 },
            { x: 0, y: 1 },
            { x: 1, y: 1 }
        ]

        Rectangle {
            required property var modelData

            width: 8
            height: 8
            radius: 2
            color: Theme.primary
            border.width: 1
            border.color: Theme.primaryText
            x: root.selX + (modelData.x ? root.selW : 0) - width / 2
            y: root.selY + (modelData.y ? root.selH : 0) - height / 2
            visible: root.selW > 0 && root.selH > 0
        }
    }

    Rectangle {
        visible: root.selecting && !root.dragging && root.imageReady
        x: root.pointerX
        y: 0
        width: 1
        height: root.height
        color: Qt.rgba(1, 1, 1, 0.65)
    }

    Rectangle {
        visible: root.selecting && !root.dragging && root.imageReady
        x: 0
        y: root.pointerY
        width: root.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.65)
    }

    Rectangle {
        id: hint

        visible: root.selecting && !root.dragging && root.imageReady
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barHeight + 20
        width: hintText.implicitWidth + 28
        height: 32
        radius: 16
        color: Theme.plate
        border.width: 1
        border.color: Theme.plateBorder

        Text {
            id: hintText

            anchors.centerIn: parent
            text: "Select a region · Esc to cancel"
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    Rectangle {
        id: sizeLabel

        visible: root.dragging && root.selW > 20
        width: sizeText.implicitWidth + 16
        height: 26
        radius: 6
        color: Theme.plate
        border.width: 1
        border.color: Theme.plateBorder
        x: Math.max(8, Math.min(root.width - width - 8,
            root.selX + root.selW / 2 - width / 2))
        y: root.selY > height + 12
            ? root.selY - height - 8
            : Math.min(root.height - height - 8, root.selY + root.selH + 8)

        Text {
            id: sizeText

            anchors.centerIn: parent
            text: Math.round(root.selW) + " × " + Math.round(root.selH)
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Rectangle {
        visible: root.processing
        anchors.centerIn: parent
        width: processingText.implicitWidth + 36
        height: 40
        radius: 20
        color: Theme.plate
        border.width: 1
        border.color: Theme.plateBorder

        Text {
            id: processingText

            anchors.centerIn: parent
            text: "Recognizing" + "....".substring(0, root.dots)
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
    }

    Timer {
        interval: 350
        repeat: true
        running: root.processing
        onTriggered: root.dots = (root.dots + 1) % 4
    }

    Timer {
        id: focusTimer

        interval: 50
        onTriggered: keyLayer.forceActiveFocus()
    }

    // Layer-shell windows are not Qt-active, so window-level Shortcuts do not
    // fire; keep an explicitly focused item for Esc instead.
    Item {
        id: keyLayer

        anchors.fill: parent
        focus: root.shown
        Keys.onEscapePressed: Ocr.cancel()
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: root.selecting && root.imageReady
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Ocr.cancel();
                return;
            }
            root.dragging = true;
            root.startX = root.clampX(mouse.x);
            root.startY = root.clampY(mouse.y);
            root.selX = root.startX;
            root.selY = root.startY;
            root.selW = 0;
            root.selH = 0;
            root.pointerX = root.startX;
            root.pointerY = root.startY;
        }

        onPositionChanged: (mouse) => {
            const x = root.clampX(mouse.x);
            const y = root.clampY(mouse.y);
            root.pointerX = x;
            root.pointerY = y;
            if (!root.dragging)
                return;
            root.selX = Math.min(root.startX, x);
            root.selY = Math.min(root.startY, y);
            root.selW = Math.abs(x - root.startX);
            root.selH = Math.abs(y - root.startY);
        }

        onReleased: (mouse) => {
            if (mouse.button !== Qt.LeftButton)
                return;
            root.dragging = false;
            if (root.selW >= Ocr.minSelection && root.selH >= Ocr.minSelection)
                root.commitSelection();
            else
                root.resetSelection();
        }

        onCanceled: root.resetSelection()
    }
}
