pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../style"
import "../../services"

// Wallpaper ribbon content: one horizontal filmstrip of thumbnails. Not a
// window of its own — the bar embeds this item and morphs into it, same as
// Launcher.qml. A click applies via `awww img` (matugen recolors the shell
// along); the current wallpaper carries the accent outline. Wheel scrolls
// the strip.
Item {
    id: root

    // Set by the embedding bar: this monitor's plate is currently the ribbon.
    property bool active: false

    readonly property int thumbW: 192
    readonly property int thumbH: 108

    // The embedding bar sizes its plate height from this.
    implicitHeight: thumbH + (Wallpaper.error !== "" && strip.count > 0 ? 46 : 24)

    property bool keyNav: false

    function syncSelection(): void {
        const i = Wallpaper.list.indexOf(Wallpaper.current);
        strip.currentIndex = i >= 0 ? i : (strip.count > 0 ? 0 : -1);
        if (strip.currentIndex >= 0)
            strip.positionViewAtIndex(strip.currentIndex, ListView.Contain);
    }

    function moveSelection(delta: int): void {
        if (strip.count === 0)
            return;
        root.keyNav = true;
        strip.currentIndex = Math.max(0, Math.min(strip.count - 1, strip.currentIndex + delta));
        strip.positionViewAtIndex(strip.currentIndex, ListView.Contain);
    }

    onActiveChanged: {
        if (root.active) {
            root.keyNav = false;
            scrollKick.restart();
            focusKick.restart();
        }
    }

    // Esc closes, like the launcher.
    Keys.onEscapePressed: Wallpaper.close()
    Keys.onLeftPressed: root.moveSelection(-1)
    Keys.onRightPressed: root.moveSelection(1)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_H) {
            root.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_L) {
            root.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (strip.currentIndex >= 0 && strip.currentIndex < Wallpaper.list.length) {
                Wallpaper.set(Wallpaper.list[strip.currentIndex]);
                event.accepted = true;
            }
        }
    }

    // Layer surfaces take a moment to gain keyboard focus; make sure Esc
    // works either way.
    focus: root.active

    Timer {
        id: focusKick

        interval: 50
        onTriggered: root.forceActiveFocus()
    }

    // Open on the current wallpaper's tile, once the plate has laid out.
    Timer {
        id: scrollKick

        interval: 150
        onTriggered: root.syncSelection()
    }

    // Software rendering can't curve-clip (ClippingRectangle is a shader), so
    // paint the four corner slivers outside the rounded rect with the plate
    // color. Only valid because the ribbon always sits on the opaque black
    // plate (Theme.plate).
    component RoundedMask: Shape {
        id: mask

        property real radius: Theme.radiusMD

        anchors.fill: parent
        antialiasing: true

        ShapePath {
            fillColor: Theme.plate
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill

            startX: 0
            startY: 0
            PathLine { x: mask.width; y: 0 }
            PathLine { x: mask.width; y: mask.height }
            PathLine { x: 0; y: mask.height }
            PathLine { x: 0; y: 0 }

            // Inner rounded rect: the hole through which the image shows.
            PathMove { x: mask.radius; y: 0 }
            PathLine { x: mask.width - mask.radius; y: 0 }
            PathArc {
                x: mask.width
                y: mask.radius
                radiusX: mask.radius
                radiusY: mask.radius
                direction: PathArc.Clockwise
            }
            PathLine { x: mask.width; y: mask.height - mask.radius }
            PathArc {
                x: mask.width - mask.radius
                y: mask.height
                radiusX: mask.radius
                radiusY: mask.radius
                direction: PathArc.Clockwise
            }
            PathLine { x: mask.radius; y: mask.height }
            PathArc {
                x: 0
                y: mask.height - mask.radius
                radiusX: mask.radius
                radiusY: mask.radius
                direction: PathArc.Clockwise
            }
            PathLine { x: 0; y: mask.radius }
            PathArc {
                x: mask.radius
                y: 0
                radiusX: mask.radius
                radiusY: mask.radius
                direction: PathArc.Clockwise
            }
        }
    }

    // Viewport for the strip: cut-off tiles end at the plate's side margins.
    // Plain Rectangle, not Quickshell's ClippingRectangle: that one is a
    // ShaderEffect and the shell runs on the software backend.
    Text {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 8
            leftMargin: 12
            rightMargin: 12
        }
        visible: Wallpaper.error !== "" && strip.count > 0
        text: Wallpaper.error
        color: Theme.error
        font.family: Theme.fontFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    Rectangle {
        id: stripClip

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            leftMargin: 12
            rightMargin: 12
            topMargin: Wallpaper.error !== "" && strip.count > 0 ? 30 : 12
        }
        height: root.thumbH
        color: "transparent"
        clip: true

        ListView {
            id: strip

            anchors.fill: parent

            boundsBehavior: Flickable.StopAtBounds
            orientation: ListView.Horizontal
            spacing: 10
            model: Wallpaper.list
            currentIndex: -1
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 90

            delegate: Thumb {}

            // wheel glides instead of jumping; disabled while the user is
            // dragging or a flick is decelerating so those stay 1:1
            Behavior on contentX {
                enabled: !strip.dragging && !strip.flicking

                NumberAnimation { duration: 65; easing.type: Easing.OutQuint }
            }

            Text {
                anchors.centerIn: parent
                visible: strip.count === 0
                text: Wallpaper.error !== "" ? Wallpaper.error
                    : Wallpaper.scanning ? "Scanning wallpapers…"
                    : "No wallpapers in " + Wallpaper.dir + "\nDrop an image on the desktop to add one"
                horizontalAlignment: Text.AlignHCenter
                color: Wallpaper.error !== "" ? Theme.error : Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 13
                wrapMode: Text.Wrap
                width: parent.width - 24
            }
        }

        // Round the viewport's corners without a shader (see RoundedMask).
        RoundedMask {}

        // Wheel scrolling. acceptedButtons: NoButton keeps tile clicks
        // working; a WheelHandler fights the ListView's own wheel handling,
        // a MouseArea simply takes the events first.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton

            onWheel: wheel => {
                const max = Math.max(0, strip.contentWidth - strip.width);
                strip.contentX = Math.max(0, Math.min(max, strip.contentX - wheel.angleDelta.y));
            }
        }
    }

    // One wallpaper tile: thumbnail with the accent outline on the current one.
    component Thumb: Rectangle {
        id: tile

        required property string modelData
        required property int index
        readonly property bool current: Wallpaper.current === tile.modelData
        readonly property bool selected: root.keyNav && strip.currentIndex === index

        width: root.thumbW
        height: root.thumbH
        radius: Theme.radiusMD
        color: Theme.surfaceContainerHigh
        scale: tileArea.pressed ? 0.985 : (tileArea.containsMouse ? 1.02 : 1)

        Behavior on scale {
            NumberAnimation { duration: tileArea.pressed ? 30 : 65; easing.type: Easing.OutCubic }
        }

        Image {
            anchors.fill: parent
            source: tile.modelData
            sourceSize: Qt.size(root.thumbW * 2, root.thumbH * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        RoundedMask { radius: tile.radius }

        Rectangle {
            anchors.fill: parent
            radius: tile.radius
            color: tileArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
            border.width: tile.selected ? 3 : (tile.current ? 2 : 0)
            border.color: tile.selected ? Theme.tertiary : Theme.primary

            Behavior on border.width {
                NumberAnimation { duration: 55; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 70; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.keyNav = false
            onClicked: Wallpaper.set(tile.modelData)
        }
    }
}
