import "modules/bar"
import "modules/desktop"
import "modules/lock"
import "modules/notifs"
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

    // Desktop layer: wallpaper drops, widgets and right-click widget menu.
    Variants {
        model: Quickshell.screens

        DesktopLayer {}
    }

    NotifToasts {}
    PanelScrim {}
    LockScreen {}
}
