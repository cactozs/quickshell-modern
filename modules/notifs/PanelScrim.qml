pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services"

// Click-outside scrim for the launcher, wallpaper ribbon, clipboard picker
// and quick settings panel (all mutually exclusive). Covers the whole output
// and is fully transparent; the morphed plate is cut out of the input mask,
// so a click anywhere outside the panel closes it. Lives in modules/notifs
// for want of a better home: it used to host the notification center too,
// before that became a quick settings tab.
PanelWindow {
    id: root

    visible: LauncherState.shown || Wallpaper.shown || Clipboard.shown
        || QuickSettings.shown
    screen: Quickshell.screens.find(s => s.name === (Clipboard.shown ? Clipboard.screen
        : Wallpaper.shown ? Wallpaper.screen
        : LauncherState.shown ? LauncherState.screen : QuickSettings.screen)) ?? null

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    WlrLayershell.namespace: "quickshell:panel-scrim"

    // A transparent overlay must not reserve space, or niri squeezes every
    // normal window into the strip between the bar and the scrim. Ignore also
    // lets it cover the bar strip, so clicks above the panel close it too.
    exclusionMode: ExclusionMode.Ignore

    // The morphed BAR panel's rect (launcher, wallpaper ribbon, clipboard
    // picker or quick settings, all centered on the plate and pinned to the
    // top) is subtracted from the input mask: the scrim maps after the bar,
    // so without the hole it would sit on top of the grown plate and swallow
    // its clicks. The panels are mutually exclusive, so only one width/height
    // applies at a time. Width lives with each panel's state; height is
    // content-driven and mirrored from Bar.qml.
    readonly property int holeW: LauncherState.shown ? LauncherState.plateWidth
        : Wallpaper.shown ? Wallpaper.plateWidth
        : Clipboard.shown ? Clipboard.plateWidth : QuickSettings.plateWidth
    readonly property int holeH: LauncherState.shown ? LauncherState.plateHeight
        : Wallpaper.shown ? Wallpaper.plateHeight
        : Clipboard.shown ? Clipboard.plateHeight : QuickSettings.plateHeight
    readonly property int holeX: root.holeW > 0
        ? Math.round((root.width - root.holeW) / 2) : 0

    mask: Region {
        width: root.width
        height: root.height

        Region {
            x: root.holeX
            y: 0
            width: root.holeW
            height: root.holeH
            intersection: Intersection.Subtract
        }
    }

    MouseArea {
        anchors.fill: parent

        onClicked: {
            if (LauncherState.shown)
                LauncherState.close();
            else if (Clipboard.shown)
                Clipboard.close();
            else if (QuickSettings.shown)
                QuickSettings.close();
            else
                Wallpaper.close();
        }
    }
}
