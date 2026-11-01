pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
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

    // Rounded viewport for the strip: cut-off tiles end on a curve instead
    // of a hard straight edge. Wraps the ListView in a ClippingRectangle.
    ClippingRectangle {
        id: stripClip

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 12
        }
        height: root.thumbH
        radius: Theme.radiusMD
        color: "transparent"

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

                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Text {
                anchors.centerIn: parent
                visible: strip.count === 0
                text: "No wallpapers found"
                color: Theme.onSurfaceVariant
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }

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
    component Thumb: ClippingRectangle {
        id: tile

        required property string modelData

        width: root.thumbW
        height: root.thumbH
        radius: Theme.radiusMD
        color: Theme.surfaceContainerHigh
        border.width: Wallpaper.current === tile.modelData ? 2 : 0
        border.color: Theme.primary

        Behavior on border.width {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Image {
            anchors.fill: parent
            source: tile.modelData
            sourceSize: Qt.size(root.thumbW * 2, root.thumbH * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Wallpaper.set(tile.modelData)
        }
    }
}
