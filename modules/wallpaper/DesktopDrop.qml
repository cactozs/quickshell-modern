pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services"

// Invisible fullscreen catcher: dropping an image file on empty desktop
// installs it into the wallpaper directory and applies it (Wallpaper.install).
// Sits on the Bottom layer so every window stays above it — drops over real
// windows go to that window, only empty-desktop drops land here.
PanelWindow {
    required property ShellScreen modelData

    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell:wallpaper-drop"

    DropArea {
        anchors.fill: parent

        onDropped: drop => {
            // one wallpaper per drop — extra urls are ignored
            if (drop.hasUrls)
                Wallpaper.install(drop.urls[0]);
        }
    }
}
