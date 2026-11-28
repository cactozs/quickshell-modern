import "modules/bar"
import "modules/desktop"
import "modules/lock"
import "modules/notifs"
import "modules/ocr"
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

    // OCR region selector: one fullscreen overlay per output, shown only while
    // a selection is active.
    Variants {
        model: Quickshell.screens

        OcrOverlay {}
    }

    NotifToasts {}
    PanelScrim {}
    LockScreen {}
}
