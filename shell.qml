import "modules/bar"
import "modules/lock"
import "modules/notifs"
import "modules/wallpaper"
import "services"
import Quickshell
import QtQuick

ShellRoot {
    // Singletons are lazy: touch SystemTheme so the app configs are generated
    // at startup, before any settings panel is opened.
    Component.onCompleted: SystemTheme.applyAll()

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
    PanelScrim {}
    LockScreen {}
}
