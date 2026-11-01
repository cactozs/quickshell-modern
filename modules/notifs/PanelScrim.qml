pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../style"
import "../../services"

// Click-outside scrim for the launcher, wallpaper ribbon, clipboard picker
// and quick settings panel (all mutually exclusive). Covers everything below
// the bar strip — the bar window keeps its own input — and is fully
// transparent; a click anywhere on it closes whichever panel is open. Lives
// in modules/notifs for want of a better home: it used to host the
// notification center too, before that became a quick settings tab.
PanelWindow {
    id: root

    visible: LauncherState.shown || Wallpaper.shown || Clipboard.shown
        || QuickSettings.shown
    screen: Quickshell.screens.find(s => s.name === (Clipboard.shown ? Clipboard.screen
        : Wallpaper.shown ? Wallpaper.screen
        : LauncherState.shown ? LauncherState.screen : QuickSettings.screen)) ?? null

    anchors {
        left: true
        right: true
        bottom: true
    }

    // Height stops at the bar strip: the bar's exclusive zone pushes the
    // top edge down to exactly that line.
    implicitHeight: (root.screen?.height ?? 900) - Theme.barHeight

    color: "transparent"
    WlrLayershell.namespace: "quickshell:panel-scrim"

    // A transparent overlay must not reserve space, or niri squeezes every
    // normal window into the strip between the bar and the scrim.
    exclusionMode: ExclusionMode.Ignore

    // The vertical strip under the morphed BAR panel (launcher, wallpaper
    // ribbon, clipboard picker or quick settings, all centered on the plate)
    // is subtracted from the input mask: the scrim maps after the bar, so
    // without the hole it would sit on top of the grown plate and swallow
    // its clicks. The panels are mutually exclusive, so only one width
    // applies at a time.
    readonly property int holeW: LauncherState.shown ? LauncherState.plateWidth
        : Wallpaper.shown ? Wallpaper.plateWidth
        : Clipboard.shown ? Clipboard.plateWidth : QuickSettings.plateWidth
    readonly property int holeX: root.holeW > 0
        ? Math.round((root.width - root.holeW) / 2) : 0

    mask: Region {
        id: scrimMask

        width: root.width
        height: root.height

        Region {
            x: root.holeX
            y: 0
            width: root.holeW
            height: scrimMask.height
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
