import "modules/bar"
import "modules/notifs"
import "modules/wallpaper"
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Invisible fullscreen catcher for image drops on empty desktop.
    Variants {
        model: Quickshell.screens

        DesktopDrop {}
    }

    NotifToasts {}
    NotifCenter {}
}
