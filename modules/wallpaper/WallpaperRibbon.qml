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
    implicitHeight: thumbH + 24

    onActiveChanged: {
        if (root.active) {
            scrollKick.restart();
            focusKick.restart();
        }
    }

    // Esc closes, like the launcher.
    Keys.onEscapePressed: Wallpaper.close()

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
        onTriggered: {
            const i = Wallpaper.list.indexOf(Wallpaper.current);
            if (i >= 0)
                strip.positionViewAtIndex(i, ListView.Contain);
        }
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
    Rectangle {
        id: stripClip

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 12
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

            delegate: Thumb {}

            // wheel glides instead of jumping; disabled while the user is
            // dragging or a flick is decelerating so those stay 1:1
            Behavior on contentX {
                enabled: !strip.dragging && !strip.flicking

                NumberAnimation { duration: 90; easing.type: Easing.OutQuint }
            }

            Text {
                anchors.centerIn: parent
                visible: strip.count === 0
                text: "No wallpapers found"
                color: Theme.surfaceVariantText
                font.family: Theme.fontFamily
                font.pixelSize: 13
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
        readonly property bool current: Wallpaper.current === tile.modelData

        width: root.thumbW
        height: root.thumbH
        radius: Theme.radiusMD
        color: Theme.surfaceContainerHigh
        scale: tileArea.pressed ? 0.985 : (tileArea.containsMouse ? 1.02 : 1)

        Behavior on scale {
            NumberAnimation { duration: tileArea.pressed ? 40 : 90; easing.type: Easing.OutCubic }
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
            border.width: tile.current ? 2 : 0
            border.color: Theme.primary

            Behavior on border.width {
                NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Wallpaper.set(tile.modelData)
        }
    }
}
